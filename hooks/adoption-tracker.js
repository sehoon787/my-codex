#!/usr/bin/env node
// Adoption tracker: did the user adopt what an agent or skill just produced?
// Codex port of my-claude's hooks/adoption-tracker.js; same verdict rules,
// same ledger (adoption-store.js).
//
//   verdict  UserPromptSubmit. Classifies the user's reply as accept, reject
//            (wins when both match), or neutral, and appends one ledger event
//            per judged offer (none when neutral).
//
// Offers come from the session rollout at transcript_path (the root thread's
// own file; subagents write their own), not from a PostToolUse hook: skills
// selected with a $mention never make a tool call, and spawn_agent reaches
// PostToolUse as "collaborationspawn_agent" under multi-agent v2
// (codex-rs core/src/tools/registry.rs function_hook_tool_name). An offer is
//   - spawn_agent: agent_type (or "default"). A v2 agent (task_name) counts
//     once its result reaches the root -- SubAgentActivity "completed" or a
//     FINAL_ANSWER agent_message -- because before that the user has not seen
//     it; a v1 agent counts at spawn.
//   - a skill: a "<skill><name>X</name>" injection ($X mention) or a read of
//     an installed skill's SKILL.md (.codex/skills, .agents/skills, plugin
//     cache), recorded as "$X" with X its frontmatter name, as the registry
//     names it.
// Ids in the registry's adoption_ignore (from routing-map.json: process
// skills such as using-superpowers that run regardless of advice quality)
// and skills under a .system/ folder are never offers.
// The rollout is split into turns at each UserMessage. Judged: the latest
// turn with offers since the last routable user prompt, one per item, 5 max.
// Slash commands and $skill prompts are not replies (nothing is judged), so
// their turns stay in the window. Each offer is filed under the intent
// route-hint.js recorded for the prompt that ran it.
//
// Prints nothing (no context is added) and never throws.
//   node adoption-tracker.js verdict
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const store = require('./adoption-store.js');
const { isRoutable } = require('./route-hint.js');
const { defaultRegistryPath, parseSkillFrontmatter } = require('./build-registry.js');

const MAX_OFFERS = 5;
const EVIDENCE_MAX = 120;
const DEFAULT_AGENT = 'default';

// Same lists as my-claude. Latin phrases match as whole words; Korean ones
// match anywhere (particles attach to the stem), with guards where a common
// phrase shares the stem.
const ACCEPT = [
  /(^|[^a-z0-9])(go ahead|yes|yep|lgtm|apply it|ship it|sounds good|looks good|approved?|do it|merge it)($|[^a-z0-9])/,
  /진행해|진행 해|진행하자|반영해|반영 해|(?<!안\s?)좋아(?!하)|좋습니다|좋네요|그렇게 해|그렇게 하자|승인|머지해|머지 해|적용해/,
];
const REVERT = [
  /(^|[^a-z0-9])(revert|roll ?back)($|[^a-z0-9])/,
  /되돌려|롤백/,
];
const REJECT = [
  ...REVERT,
  /(^|[^a-z0-9])(wrong|redo|nope)($|[^a-z0-9])/,
  /(^|[^a-z0-9])(?<!don't |non-)stop($|[^a-z0-9])/,
  /(^|[^a-z0-9])no,/,
  /^\s*no[.!]?\s*$/,
  /아니(?!면)|틀렸|틀려|다시 해|다시해|그만(?!큼)|그렇게 하지 ?마/,
];
// Bare "하지 마"/"하지마" is a scope instruction as often as a rejection
// ("파일은 수정하지 마" while accepting the plan), so it only counts as a
// reject when no ACCEPT pattern also matches.
const WEAK_REJECT = [/하지 마|하지마/];
// "진행해도 될까?", "yes or no?": a question is not an accept.
const QUESTION = /\?\s*$/;
const SKILL_INJECTION = /^<skill>\s*<name>([^<]+)<\/name>\s*(?:<path>([^<]*)<\/path>)?/;
const SYSTEM_SKILL = /[\\/]\.system[\\/]/;
// Where Codex loads skills from; a SKILL.md elsewhere (a repo being edited)
// is not a skill in use.
const SKILL_FILE = /\/\.(?:codex|agents)\/skills\/([^/.][^/]*)\/SKILL\.md$/;
const PLUGIN_SKILL_FILE = /\/\.codex\/plugins\/cache\/[^/]+\/([^/]+)\/[^/]+\/skills\/([^/]+)\/SKILL\.md$/;
const FINAL_ANSWER = /^Message Type: FINAL_ANSWER/;

function matchesAny(text, patterns) {
  return patterns.some((re) => re.test(text));
}

// -> {verdict, signal} or null (neutral)
function classifyVerdict(prompt) {
  const text = String(prompt || '').toLowerCase().trim();
  if (matchesAny(text, REJECT)) return { verdict: 'reject', signal: matchesAny(text, REVERT) ? 'revert' : 'reply' };
  if (!QUESTION.test(text) && matchesAny(text, ACCEPT)) return { verdict: 'accept', signal: 'reply' };
  if (matchesAny(text, WEAK_REJECT)) return { verdict: 'reject', signal: 'reply' };
  return null;
}

function parseJson(text) {
  try { return JSON.parse(text); } catch { return null; }
}

function firstText(content) {
  const c = Array.isArray(content) ? content.find((x) => x && typeof x.text === 'string') : null;
  return c ? c.text : '';
}

// Registry skill name for a SKILL.md path: its frontmatter name (the folder
// name when unreadable); plugin skills are "<plugin>:<name>".
function skillFromPath(file) {
  const p = String(file || '').replace(/\\/g, '/');
  const plugin = p.match(PLUGIN_SKILL_FILE);
  const m = plugin || p.match(SKILL_FILE);
  if (!m) return null;
  let name = m[m.length - 1];
  try { name = parseSkillFrontmatter(fs.readFileSync(file, 'utf8')).name || name; } catch { /* keep the folder name */ }
  return plugin ? `${plugin[1]}:${name}` : name;
}

// Rollout records -> [{text, offers: [{kind, id, ts}]}]. turns[0] holds what
// ran before the first user message.
function extractTurns(records, ignore = new Set()) {
  const turns = [{ text: null, offers: [] }];
  const offer = (kind, id, ts) => {
    if (!ignore.has(id)) turns[turns.length - 1].offers.push({ kind, id, ts });
  };
  const skillNames = new Map(); // SKILL.md path -> skill name (a skill is often re-read)
  const spawns = new Map(); // call_id -> v2 agent offer not placed yet
  const running = new Map(); // agent path -> v2 agent offer awaiting its result
  const track = (callId, agentPath) => {
    const o = spawns.get(callId);
    if (o && agentPath) running.set(agentPath, o);
  };
  const land = (agentPath) => {
    const o = running.get(agentPath);
    if (!o) return;
    running.delete(agentPath);
    offer(o.kind, o.id, o.ts);
  };
  for (const r of records) {
    const p = (r && r.payload) || {};
    const item = p.item || {};
    if ((p.type === 'item_completed' && item.type === 'UserMessage') || p.type === 'user_message') {
      turns.push({ text: p.type === 'user_message' ? String(p.message || '') : firstText(item.content), offers: [] });
    } else if (p.type === 'function_call' && p.name === 'spawn_agent') {
      const args = parseJson(p.arguments) || {};
      const o = { kind: 'agent', id: String(args.agent_type || DEFAULT_AGENT), ts: r.timestamp };
      if (args.task_name) spawns.set(p.call_id, o);
      else offer(o.kind, o.id, o.ts);
    } else if (p.type === 'function_call_output' && spawns.has(p.call_id)) {
      track(p.call_id, (parseJson(p.output) || {}).task_name);
    } else if (p.type === 'item_completed' && item.type === 'SubAgentActivity') {
      if (item.kind === 'started') track(item.id, item.agent_path);
      else if (item.kind === 'completed') land(item.agent_path);
    } else if (p.type === 'agent_message' && FINAL_ANSWER.test(firstText(p.content))) {
      land(p.author);
    } else if (p.type === 'message' && p.role === 'user') {
      const m = firstText(p.content).match(SKILL_INJECTION);
      if (m && !SYSTEM_SKILL.test(m[2] || '')) offer('skill', `$${m[1].trim()}`, r.timestamp);
    } else if (p.type === 'item_completed' && item.type === 'CommandExecution') {
      for (const c of Array.isArray(item.parsed_cmd) ? item.parsed_cmd : []) {
        if (!c || c.type !== 'read' || !c.path) continue;
        if (!skillNames.has(c.path)) skillNames.set(c.path, skillFromPath(c.path));
        const name = skillNames.get(c.path);
        if (name) offer('skill', `$${name}`, r.timestamp);
      }
    }
  }
  return turns;
}

// Only lines that can matter are parsed; rollouts carry large encrypted blobs.
const RELEVANT = /"(UserMessage|user_message|spawn_agent|function_call_output|SubAgentActivity|agent_message|CommandExecution|message)"/;

function readRollout(file) {
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch { return []; }
  const rows = [];
  for (const line of text.split('\n')) {
    if (!line || !RELEVANT.test(line)) continue;
    const r = parseJson(line);
    if (r) rows.push(r);
  }
  return rows;
}

// Turns -> offers to judge for the next reply. The rollout does not hold the
// prompt being submitted yet (Codex 0.158 writes it after UserPromptSubmit),
// so the last turn is the one the user is replying to.
function judgedOffers(turns) {
  const end = turns.length;
  let start = 0;
  for (let i = end - 1; i >= 1; i--) {
    if (isRoutable({ prompt: turns[i].text })) { start = i; break; }
  }
  let k = end - 1;
  while (k >= start && !turns[k].offers.length) k--;
  if (k < start) return [];
  const byItem = new Map();
  for (const o of turns[k].offers) {
    byItem.delete(`${o.kind}:${o.id}`);
    byItem.set(`${o.kind}:${o.id}`, o);
  }
  return [...byItem.values()].slice(-MAX_OFFERS);
}

// adoption_ignore as copied into the registry at build time; the routing
// map itself until the registry has been rebuilt with it.
function adoptionIgnore(home) {
  const fromFile = (file) => {
    try {
      const list = JSON.parse(fs.readFileSync(file, 'utf8')).adoption_ignore;
      return Array.isArray(list) ? list : null;
    } catch { return null; }
  };
  return new Set(fromFile(defaultRegistryPath(home || os.homedir())) || fromFile(path.join(__dirname, 'routing-map.json')) || []);
}

function recordVerdict(input, home, now) {
  if (!isRoutable(input) || !input.transcript_path) return;
  const verdict = classifyVerdict(input.prompt);
  if (!verdict) return;
  const judged = judgedOffers(extractTurns(readRollout(input.transcript_path), adoptionIgnore(home)));
  if (!judged.length) return;
  const session = String(input.session_id || 'unknown');
  const ts = new Date(now).toISOString();
  const evidence = String(input.prompt).replace(/\s+/g, ' ').trim().slice(0, EVIDENCE_MAX);
  store.appendJsonl(store.storePaths(home).ledger, judged.map((o) => ({
    ts,
    harness: store.HARNESS,
    session,
    kind: o.kind,
    id: o.id,
    intent: store.intentAt(home, session, o.ts),
    verdict: verdict.verdict,
    signal: verdict.signal,
    evidence,
  })));
}

function main(mode) {
  let input = {};
  try { input = JSON.parse(fs.readFileSync(0, 'utf8') || '{}'); } catch { return; }
  if (mode === 'verdict') recordVerdict(input, null, Date.now());
}

module.exports = { RELEVANT, adoptionIgnore, classifyVerdict, extractTurns, judgedOffers, readRollout, recordVerdict, skillFromPath };

if (require.main === module) {
  try { main(process.argv[2]); } catch { /* fail open: never block a prompt */ }
}
