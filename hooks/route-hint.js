#!/usr/bin/env node
// UserPromptSubmit hook: classify the prompt against routing-map.json and
// remind Boss which ranked specialists fit, marking Advisor Group members.
//
// Emits exactly one JSON document
//   {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[RouteHint] ..."}}
// or nothing (no match, slash/skill command, subagent prompt, any error).
// Codex parses it as UserPromptSubmitCommandOutputWire (deny_unknown_fields),
// see codex-rs/hooks/src/schema.rs.
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { defaultRegistryPath, formatPick, keywordRegex } = require('./build-registry');

const ROUTING_MAP_FILE = path.join(__dirname, 'routing-map.json');
const HINT_TOP = 3;

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return null;
  }
}

// Longer matched phrases are more specific, so the score is the total length
// of matched keywords plus the intent's score_bonus (Trivial uses it to beat
// Document on "fix the typo in the README"); map priority breaks ties.
function classify(prompt, map) {
  const text = String(prompt || '').toLowerCase();
  let best = null;
  for (const [intent, def] of Object.entries((map && map.intents) || {})) {
    let score = (def.prompt_keywords || [])
      .filter((k) => keywordRegex(k).test(text))
      .reduce((sum, k) => sum + k.length, 0);
    if (!score) continue;
    score += def.score_bonus || 0;
    const priority = def.priority || 0;
    if (!best || score > best.score || (score === best.score && priority > best.priority)) {
      best = { intent, score, priority };
    }
  }
  return best && best.intent;
}

// Prefer the ranked registry; fall back to the raw map members when it is
// missing so a fresh install still gets hints.
function picksFor(intent, map, registry, cwd) {
  const ranked = registry && registry.version === 2 && registry.intents && registry.intents[intent];
  // The registry is shared across projects; another project's local picks do not apply here.
  const usable = Array.isArray(ranked)
    ? ranked.filter((p) => p.scope !== 'project' || registry.project_root === cwd)
    : [];
  if (usable.length) return usable.slice(0, HINT_TOP);
  return ((map.intents[intent] || {}).members || [])
    .slice(0, HINT_TOP)
    .map((m) => ({ name: m.name, kind: m.kind, advisor: Boolean(m.advisor), active: true }));
}

function hintFor(input, { map, registry } = {}) {
  const prompt = String((input && input.prompt) || '').trim();
  if (!prompt || prompt.startsWith('/') || prompt.startsWith('$')) return null;
  if (input.agent_id) return null;
  const routing = map || readJson(ROUTING_MAP_FILE);
  if (!routing) return null;
  const intent = classify(prompt, routing);
  if (!intent) return null;
  const picks = picksFor(intent, routing, registry === undefined ? readJson(defaultRegistryPath(os.homedir())) : registry,
    input.cwd || process.cwd());
  if (!picks.length) return null;
  // Only name the Advisor Group when one of its members is actually suggested.
  const advice = picks.some((p) => p.advisor) ? ' Consult the Advisor Group when the intent calls for it.' : '';
  return `[RouteHint] intent=${intent} → ${picks.map(formatPick).join(', ')}.${advice}`;
}

// Advisor Group members the intent names in routing-map.json; the Stop-hook
// Advisor Gate (advisor-gate.js) enforces a spawn of one of them.
function turnIntent(input, map) {
  const prompt = String((input && input.prompt) || '').trim();
  if (!map || !prompt || prompt.startsWith('/') || prompt.startsWith('$')) return { intent: null, advisors: [] };
  const intent = classify(prompt, map);
  const members = (intent && (map.intents[intent] || {}).members) || [];
  return { intent, advisors: members.filter((m) => m.advisor).map((m) => m.name) };
}

module.exports = { classify, hintFor, turnIntent };

if (require.main === module) {
  let input = {};
  let map = null;
  try {
    const raw = fs.readFileSync(0, 'utf8');
    input = raw.trim() ? JSON.parse(raw) : {};
    map = readJson(ROUTING_MAP_FILE);
    const hint = hintFor(input, { map });
    if (hint) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: { hookEventName: 'UserPromptSubmit', additionalContext: hint }
      }) + '\n');
    }
  } catch {
    // A routing hint is advisory; never fail the user's prompt over it.
  }
  try {
    const { intent, advisors } = turnIntent(input, map);
    require('./advisor-gate').recordTurnIntent(input, intent, advisors);
  } catch {
    // The gate record is a backstop; a write failure only disables it.
  }
}
