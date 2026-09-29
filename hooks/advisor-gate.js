#!/usr/bin/env node
'use strict';
// advisor-gate.js — deterministic backstop for the Advisor Gate (AGENTS.md,
// boss.toml). The prompt rule alone is advisory: real sessions showed Boss
// receiving an Architecture -> oracle hint and answering by itself with no
// spawn at all.
//
//   UserPromptSubmit: route-hint.js calls recordTurnIntent() with the turn's
//     routing intent and the Advisor Group members that intent names.
//   Stop (this file run directly): when that intent names advisors, the
//     rollout shows no spawn_agent of oracle/metis/momus in this turn, and
//     the final answer has no `Advisor skipped:` line, block once and ask
//     for the advisor.
//
// Loop safety mirrors stop-final-report.js: never block when
// `stop_hook_active` is set, at most once per turn_id, never for a subagent
// Stop, and fail open on any error or unreadable rollout.
const fs = require('fs');
const os = require('os');
const path = require('path');

const ADVISORS = ['oracle', 'metis', 'momus'];
const SKIP_MARKER = /Advisor skipped:/i;
const INTENT_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

function intentDir(home = os.homedir()) {
  return path.join(home, '.codex', 'my-codex', 'route-intent');
}

function intentFile(sessionId, home) {
  return path.join(intentDir(home), String(sessionId).replace(/[^A-Za-z0-9_.-]/g, '_') + '.json');
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return null;
  }
}

// One small file per session; drop the ones no session has touched in a week.
function pruneOld(dir) {
  const cutoff = Date.now() - INTENT_MAX_AGE_MS;
  for (const name of fs.readdirSync(dir)) {
    const file = path.join(dir, name);
    try {
      if (fs.statSync(file).mtimeMs < cutoff) fs.unlinkSync(file);
    } catch {
      // Another session may have removed it first.
    }
  }
}

// Every root-thread prompt overwrites the record, so an earlier turn's
// advisor intent never gates a later, unrelated turn.
function recordTurnIntent(input, intent, advisors, home) {
  if (!input || !input.session_id || input.agent_id) return;
  const dir = intentDir(home);
  fs.mkdirSync(dir, { recursive: true });
  pruneOld(dir);
  fs.writeFileSync(intentFile(input.session_id, home), JSON.stringify({
    turn_id: input.turn_id || null,
    intent: intent || null,
    advisors: advisors || [],
    ts: Date.now()
  }) + '\n');
}

// Walk the rollout back to this turn's task_started and collect the
// agent_type of every spawn_agent call. `found` is false when the turn start
// is not in the file (or the file is unreadable) — the caller fails open.
function spawnedInTurn(transcriptPath, turnId) {
  const res = { found: false, agentTypes: [] };
  if (!transcriptPath) return res;
  let lines;
  try {
    lines = fs.readFileSync(transcriptPath, 'utf8').split('\n');
  } catch {
    return res;
  }
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i]) continue;
    let r;
    try { r = JSON.parse(lines[i]); } catch { continue; }
    const p = (r && r.payload) || {};
    if (p.type === 'function_call' && p.name === 'spawn_agent') {
      let args = {};
      try { args = JSON.parse(p.arguments || '{}'); } catch { /* keep {} */ }
      if (args.agent_type) res.agentTypes.push(String(args.agent_type));
      continue;
    }
    if (p.type === 'task_started' && (!turnId || !p.turn_id || p.turn_id === turnId)) {
      res.found = true;
      break;
    }
  }
  return res;
}

// Returns the block reason, or null to let the turn end.
function decide(input, home) {
  if (!input || input.agent_id || input.stop_hook_active === true || !input.session_id) return null;
  const file = intentFile(input.session_id, home);
  const rec = readJson(file);
  if (!rec || !Array.isArray(rec.advisors) || !rec.advisors.length) return null;
  if (rec.turn_id && input.turn_id && rec.turn_id !== input.turn_id) return null;
  const turnKey = String(input.turn_id || rec.ts);
  if (rec.blocked_turn_id === turnKey) return null;
  if (SKIP_MARKER.test(String(input.last_assistant_message || ''))) return null;
  const turn = spawnedInTurn(input.transcript_path, input.turn_id);
  if (!turn.found || turn.agentTypes.some((t) => ADVISORS.includes(t))) return null;

  fs.writeFileSync(file, JSON.stringify(Object.assign({}, rec, { blocked_turn_id: turnKey })) + '\n');
  const names = rec.advisors.join(' or ');
  return `[AdvisorGate] This request was routed as ${rec.intent}, which requires the Advisor Group, `
    + 'but no advisor was spawned this turn. '
    + `Spawn ${names} now (spawn_agent with agent_type="${rec.advisors[0]}") and pass the context you already gathered, `
    + 'then repeat your final answer with a short "Advisor (<name>)" section. '
    + 'If an advisor is genuinely unnecessary here, add one line "Advisor skipped: <reason>" and repeat the final answer.';
}

module.exports = { ADVISORS, decide, intentFile, recordTurnIntent, spawnedInTurn };

if (require.main === module) {
  try {
    const raw = fs.readFileSync(0, 'utf8');
    const reason = decide(raw.trim() ? JSON.parse(raw) : {});
    if (reason) process.stdout.write(JSON.stringify({ decision: 'block', reason }) + '\n');
  } catch {
    // A broken gate must never trap the session.
  }
}
