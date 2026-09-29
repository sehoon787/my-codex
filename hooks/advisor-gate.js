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
//   Stop (this file run directly): also a "Stuck" trigger, independent of
//     the routed intent above:
//       (a) 3+ failed commands sharing the same prefix (or 5+ total) this turn;
//       (b) the final answer claims something is impossible;
//       (c) no progress across the last 3 Stops — every one used a tool, the
//           working tree stayed identical (git diff HEAD + git status), and
//           either the same command kept failing or the answer kept repeating.
//           Applies to Codex goal mode (/goal) continuation turns and to
//           ordinary loops alike; Codex has no PostToolUseFailure or ralph,
//           and its rollouts carry no diff/patch event, so (c) reads the
//           working tree directly instead (confirmed empty across every
//           session on this machine).
//     Blocks once per episode and asks Boss to spawn a Stuck advisor
//     (routing-map.json's Stuck intent) for a reframe, root-cause dig, or
//     fact-check depending on which signal fired.
//
// Loop safety mirrors stop-final-report.js: never block when
// `stop_hook_active` is set, at most once per turn_id, never for a subagent
// Stop, and fail open on any error or unreadable rollout. The Stuck trigger
// adds its own per-episode + per-session caps (see decideStuck).
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

const ADVISORS = ['oracle', 'metis', 'momus'];
// Captures the rest of the marker's line as its reason/action text.
const SKIP_LINE = /Advisor skipped:[ \t]*([^\n]*)/i;
const BLOCKED_ON_USER_LINE = /Blocked on user:[ \t]*([^\n]*)/i;
// An empty line, or one of these placeholders, does not count as a reason —
// the gate treats the marker as absent and blocks (still once per episode).
const PLACEHOLDER_REASONS = new Set(['<reason>', '<action>', 'n/a', 'na', 'none', 'skip', '-', '...']);
const MIN_REASON_CHARS = 8;
const EMPTY_ESCAPE_NOTE = `The escape line needs a concrete reason (at least ${MIN_REASON_CHARS} non-space characters, not a placeholder like "n/a" or "-").`;
const INTENT_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
// Enough to cover the prompts between an adoption offer and the reply that judges it.
const INTENT_HISTORY_MAX = 20;

// True when `text` is a real reason: at least MIN_REASON_CHARS non-space
// characters, and not one of the known placeholders (case-insensitive).
function isConcreteReason(text) {
  const trimmed = String(text || '').trim();
  if (trimmed.replace(/\s+/g, '').length < MIN_REASON_CHARS) return false;
  return !PLACEHOLDER_REASONS.has(trimmed.toLowerCase());
}

// True when the message has a working escape line — "Advisor skipped: <a
// real reason>" or "Blocked on user: <a real action>" — either marker with
// an empty or placeholder reason does not count (see hasEmptyEscape).
function hasValidEscape(message) {
  const text = String(message || '');
  const skip = text.match(SKIP_LINE);
  if (skip && isConcreteReason(skip[1])) return true;
  const blocked = text.match(BLOCKED_ON_USER_LINE);
  if (blocked && isConcreteReason(blocked[1])) return true;
  return false;
}

// True when a marker is present but its reason is empty or a placeholder —
// distinguishes "no escape line at all" from "escape line, but not a real
// reason" so the block message can ask for a concrete one.
function hasEmptyEscape(message) {
  const text = String(message || '');
  const skip = text.match(SKIP_LINE);
  if (skip && !isConcreteReason(skip[1])) return true;
  const blocked = text.match(BLOCKED_ON_USER_LINE);
  if (blocked && !isConcreteReason(blocked[1])) return true;
  return false;
}

// Stuck trigger (a): repeated command failures in the current turn.
const REPEAT_FAILURE_PREFIX_THRESHOLD = 3;
const REPEAT_FAILURE_TOTAL_THRESHOLD = 5;

// Stuck trigger (b): an impossibility claim in the final answer.
const IMPOSSIBLE_EN = /\b(impossible|not possible|cannot be done|can't be done|blocked by|no way to)\b/i;
const IMPOSSIBLE_KO = /(불가능|할\s*수\s*없|막혔|방법이\s*없)/;
const ADDRESSES_USER = /\byou\b|사용자|직접/i;
const USER_ONLY_ACTION = /\b(login|trust|approve|permission|credential|2FA)\b|권한|승인|로그인|신뢰/i;

// Stuck trigger (c): no progress across the last 3 Stops.
const NO_PROGRESS_WINDOW = 3;
const NO_PROGRESS_HISTORY_MAX = 5;
const NO_PROGRESS_ERROR_REPEATS = 2;
const GIT_TIMEOUT_MS = 3000;

// At most 1 block per episode (same failure signature or claim), at most 2
// Stuck blocks per session — this is a nudge, not a lock.
const STUCK_SESSION_CAP = 2;

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

// Every root-thread prompt overwrites the current-turn fields, so an earlier
// turn's advisor intent never gates a later, unrelated turn. Routable prompts
// (not a /command or $skill mention; route-hint.js isRoutable) also append
// {intent, ts} to `history`, which adoption-store.js intentAt() reads to file
// each agent/skill offer under the intent of the prompt that ran it. The
// verdict hook reads this file concurrently, so it is replaced atomically.
function recordTurnIntent(input, intent, advisors, home) {
  if (!input || !input.session_id || input.agent_id) return;
  const dir = intentDir(home);
  fs.mkdirSync(dir, { recursive: true });
  pruneOld(dir);
  const file = intentFile(input.session_id, home);
  const prev = readJson(file);
  const history = prev && Array.isArray(prev.history) ? prev.history : [];
  const prompt = String(input.prompt || '').trim();
  const routable = Boolean(prompt) && !prompt.startsWith('/') && !prompt.startsWith('$');
  const now = Date.now();
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify({
    turn_id: input.turn_id || null,
    intent: intent || null,
    advisors: advisors || [],
    ts: now,
    history: routable
      ? [...history, { intent: intent || 'unknown', ts: new Date(now).toISOString() }].slice(-INTENT_HISTORY_MAX)
      : history
  }) + '\n');
  fs.renameSync(tmp, file);
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

// Finds the line range of the current turn in an already-split rollout: the
// line after the task_started matching turnId (or the last task_started
// when turnId is falsy) through EOF. Mirrors spawnedInTurn's boundary walk.
function turnLineRange(lines, turnId) {
  let startIdx = -1;
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i]) continue;
    let r;
    try { r = JSON.parse(lines[i]); } catch { continue; }
    const p = (r && r.payload) || {};
    if (p.type === 'task_started' && (!turnId || !p.turn_id || p.turn_id === turnId)) {
      startIdx = i;
      break;
    }
  }
  if (startIdx === -1) return null;
  return [startIdx + 1, lines.length - 1];
}

function firstTwoTokens(cmd) {
  const tokens = String(cmd).trim().split(/\s+/).filter(Boolean);
  return tokens.length ? tokens.slice(0, 2).join(' ') : null;
}

function unescapeJsString(s) {
  return s.replace(/\\(.)/g, (_, c) => (c === 'n' ? '\n' : c === 't' ? '\t' : c));
}

// The command a call ran, reduced to its first two tokens for grouping.
// custom_tool_call (the `exec` tool) carries JS-ish glue code with a
// `cmd:"..."` literal; function_call carries a JSON `command` argument
// (string or argv array), shell-tool style.
function extractCommandPrefix(p) {
  if (p.type === 'custom_tool_call') {
    const m = String(p.input || '').match(/cmd\s*:\s*"((?:[^"\\]|\\.)*)"/);
    return m ? firstTwoTokens(unescapeJsString(m[1])) : null;
  }
  if (p.type === 'function_call') {
    let args;
    try { args = JSON.parse(p.arguments || '{}'); } catch { return null; }
    const cmd = args.command || args.cmd;
    if (Array.isArray(cmd)) return firstTwoTokens(cmd.join(' '));
    if (typeof cmd === 'string') return firstTwoTokens(cmd);
    return null;
  }
  return null;
}

function collectOutputText(p) {
  if (typeof p.output === 'string') return p.output;
  if (Array.isArray(p.output)) {
    return p.output.map((o) => (o && typeof o.text === 'string' ? o.text : '')).join('\n');
  }
  return '';
}

// Real rollouts (~/.codex/sessions/.../*.jsonl) carry exit codes only inside
// the exec tool's output text, as one or more embedded `"exit_code":N` JSON
// fields (sometimes wrapped in a Promise.allSettled-style
// {status,value:{...}} or {file,result:{...}} envelope) — never as a
// top-level field on function_call_output/custom_tool_call_output itself.
function outputHasNonzeroExit(p) {
  const text = collectOutputText(p);
  for (const m of text.matchAll(/"exit_code"\s*:\s*(-?\d+)/g)) {
    if (Number(m[1]) !== 0) return true;
  }
  return false;
}

// Scans the current turn for function_call_output/custom_tool_call_output
// items with a nonzero exit_code, grouped by the prefix of the command that
// produced them (looked up by call_id). Also counts every tool call
// (toolCalls, for the no-progress signal) and the single most frequent
// failing prefix regardless of the repeat threshold (topPrefix, its
// errorSig). `found` is false when the turn start is not in the file — the
// caller fails open.
function analyzeTurnExecs(transcriptPath, turnId) {
  const res = { found: false, blockingPrefix: null, totalNonzero: 0, toolCalls: 0, topPrefix: null };
  if (!transcriptPath) return res;
  let lines;
  try {
    lines = fs.readFileSync(transcriptPath, 'utf8').split('\n');
  } catch {
    return res;
  }
  const range = turnLineRange(lines, turnId);
  if (!range) return res;
  res.found = true;

  const callPrefixes = new Map();
  const prefixCounts = new Map();
  for (let i = range[0]; i <= range[1]; i++) {
    if (!lines[i]) continue;
    let r;
    try { r = JSON.parse(lines[i]); } catch { continue; }
    const p = (r && r.payload) || {};
    if (p.type === 'function_call' || p.type === 'custom_tool_call') {
      res.toolCalls += 1;
      const prefix = extractCommandPrefix(p);
      if (prefix && p.call_id) callPrefixes.set(p.call_id, prefix);
      continue;
    }
    if (p.type === 'function_call_output' || p.type === 'custom_tool_call_output') {
      if (!outputHasNonzeroExit(p)) continue;
      res.totalNonzero += 1;
      const prefix = (p.call_id && callPrefixes.get(p.call_id)) || null;
      if (prefix) prefixCounts.set(prefix, (prefixCounts.get(prefix) || 0) + 1);
    }
  }
  let topCount = 0;
  for (const [prefix, count] of prefixCounts) {
    if (count >= REPEAT_FAILURE_PREFIX_THRESHOLD && !res.blockingPrefix) res.blockingPrefix = prefix;
    if (count > topCount) {
      topCount = count;
      res.topPrefix = prefix;
    }
  }
  return res;
}

function stripCodeFences(text) {
  return text.replace(/```[\s\S]*?```/g, '');
}

// Returns a short excerpt around the matched claim, or null. Guards: ignore
// matches inside code fences, and skip a message that ends with '?' and
// addresses the user directly (that's a question, not a claim).
function detectImpossibilityClaim(message) {
  const trimmed = stripCodeFences(String(message || '')).trim();
  if (!trimmed) return null;
  if (trimmed.endsWith('?') && ADDRESSES_USER.test(trimmed)) return null;
  const m = trimmed.match(IMPOSSIBLE_EN) || trimmed.match(IMPOSSIBLE_KO);
  if (!m) return null;
  const idx = m.index || 0;
  return trimmed.slice(Math.max(0, idx - 40), idx + 80).trim();
}

function sha1(text) {
  return crypto.createHash('sha1').update(String(text)).digest('hex').slice(0, 16);
}

// Working-tree fingerprint for the no-progress signal: identical across
// consecutive Stops means no patch landed. Same idea as the my-claude gate,
// applied here since Codex rollouts carry no diff/patch event to read
// instead (confirmed empty across every session on this machine).
function computeDiffSig(cwd) {
  if (!cwd) return 'nogit';
  try {
    const diff = execFileSync('git', ['-C', cwd, 'diff', 'HEAD'], { encoding: 'utf8', timeout: GIT_TIMEOUT_MS, stdio: ['ignore', 'pipe', 'ignore'] });
    const status = execFileSync('git', ['-C', cwd, 'status', '--porcelain', '--untracked-files=all'], { encoding: 'utf8', timeout: GIT_TIMEOUT_MS, stdio: ['ignore', 'pipe', 'ignore'] });
    return sha1(diff + status);
  } catch {
    return 'nogit';
  }
}

// The active /goal (Codex goal mode), read fresh from the rollout each Stop:
// the most recent thread_goal_updated event in the whole transcript, not
// just this turn — a goal set earlier stays active across continuation turns.
function latestGoal(transcriptPath) {
  const none = { active: false, objective: null };
  if (!transcriptPath) return none;
  let lines;
  try {
    lines = fs.readFileSync(transcriptPath, 'utf8').split('\n');
  } catch {
    return none;
  }
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i]) continue;
    let r;
    try { r = JSON.parse(lines[i]); } catch { continue; }
    const p = (r && r.payload) || {};
    if (p.type === 'thread_goal_updated') {
      const goal = p.goal || {};
      return { active: goal.status === 'active', objective: goal.objective || null };
    }
  }
  return none;
}

// Normalized fingerprint of the final answer, for the "near-identical text"
// no-progress clause: lowercased, whitespace-collapsed, first 200 chars.
function textSignature(message) {
  const normalized = String(message || '').toLowerCase().replace(/\s+/g, ' ').trim().slice(0, 200);
  return normalized ? sha1(normalized) : null;
}

function stuckStateFile(sessionId, home) {
  return path.join(intentDir(home), String(sessionId).replace(/[^A-Za-z0-9_.-]/g, '_') + '.stuck.json');
}

function readStuckState(file) {
  const rec = readJson(file);
  return {
    blocked: rec && Array.isArray(rec.blocked) ? rec.blocked : [],
    count: (rec && Number(rec.count)) || 0,
    history: rec && Array.isArray(rec.history) ? rec.history : []
  };
}

function writeStuckState(file, state) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state) + '\n');
  fs.renameSync(tmp, file);
}

const ROUTING_MAP_FILE = path.join(__dirname, 'routing-map.json');

// The advisor names routing-map.json flags for the Stuck intent (data, not
// code, so the roster can change without touching this file). Falls back to
// the base Advisor Group if the map is missing or malformed.
function stuckAdvisorNames() {
  const map = readJson(ROUTING_MAP_FILE);
  const members = map && map.intents && map.intents.Stuck && map.intents.Stuck.members;
  const names = Array.isArray(members) ? members.filter((m) => m.advisor).map((m) => m.name) : [];
  return names.length ? names : ADVISORS;
}

// The oracle "Stuck mode" contract: a one-line claim/failure, up to 5
// assumptions each settled VERIFIED/REFUTED, at least one alternative that
// does not lean on a refuted assumption plus the next step, and a verdict.
const STUCK_MODE_CONTRACT = 'state the claim or failure in one line; list at most 5 assumptions, each marked '
  + 'VERIFIED or REFUTED with the command or source that settled it; give at least 1 alternative approach that '
  + 'does not rely on a refuted assumption, plus the next concrete step; end with a verdict of truly-blocked '
  + '(naming the user-only action) or unblocked.';

// The recommended spawn differs by trigger: repeated failures point at a
// root-cause specialist, an impossibility claim points at an assumption
// audit, a no-progress loop points at a reframe (or metis, when the goal
// itself looks misread). Either way the gate is satisfied by spawning any
// Stuck member (stuckAdvisorNames) this turn, not only the one recommended
// here.
function buildStuckReason(kind, reasonLine, userOnly, goal, emptyEscape) {
  const escapeHint = (userOnly
    ? 'If this truly needs the user (login, approval, trust, credentials, permission), '
      + 'skip the advisor and add one line "Blocked on user: <action>" instead, then repeat the final answer.'
    : 'If an advisor is genuinely unnecessary here, add one line "Advisor skipped: <reason>" and repeat the final answer.')
    + (emptyEscape ? ' ' + EMPTY_ESCAPE_NOTE : '');
  let recommendation;
  if (kind === 'failure') {
    recommendation = 'Spawn tracer now (spawn_agent with agent_type="tracer") for evidence-ranked competing hypotheses on the root cause, '
      + 'or architect if the failure looks structural.';
  } else if (kind === 'noprogress') {
    recommendation = 'Spawn oracle now (spawn_agent with agent_type="oracle") to reframe the approach, or metis if the goal itself looks misread.';
    if (goal && goal.active && goal.objective) recommendation += ` The active /goal objective is: "${goal.objective}".`;
  } else {
    recommendation = `Spawn oracle now (spawn_agent with agent_type="oracle") for an assumption audit in Stuck mode: ${STUCK_MODE_CONTRACT}`;
  }
  return `[AdvisorGate] Stuck: ${reasonLine}. ${recommendation} `
    + 'Then repeat your final answer with a short "Advisor (<name>)" section. '
    + escapeHint;
}

// No progress across the last NO_PROGRESS_WINDOW Stops: every one of them
// did something (toolCalls > 0) yet the working tree never changed
// (identical diffSig), and either the same command kept failing or the
// answer kept repeating itself. Returns { diffSig, errorSig } or null.
function checkNoProgress(history) {
  if (history.length < NO_PROGRESS_WINDOW) return null;
  const window = history.slice(-NO_PROGRESS_WINDOW);
  if (!window.every((r) => r.toolCalls > 0)) return null;
  const diffSig = window[0].diffSig;
  if (!window.every((r) => r.diffSig === diffSig)) return null;

  const errorCounts = new Map();
  for (const r of window) {
    if (r.errorSig) errorCounts.set(r.errorSig, (errorCounts.get(r.errorSig) || 0) + 1);
  }
  const repeatedError = [...errorCounts.entries()].find(([, count]) => count >= NO_PROGRESS_ERROR_REPEATS);

  // A git-less cwd can't distinguish "no patch" from "no file tool used" by
  // diffSig alone, so text repetition only counts as progress-free in a repo.
  const inGitRepo = diffSig !== 'nogit';
  const sameText = inGitRepo && Boolean(window[0].textSig) && window.every((r) => r.textSig === window[0].textSig);

  if (!repeatedError && !sameText) return null;
  return { diffSig, errorSig: repeatedError ? repeatedError[0] : null };
}

// Returns the block reason, or null to let the turn end. Independent of
// decide() above: no routed intent is required, only the Stuck signals.
function decideStuck(input, home) {
  if (!input || input.agent_id || input.stop_hook_active === true || !input.session_id) return null;
  const lastMsg = String(input.last_assistant_message || '');
  if (hasValidEscape(lastMsg)) return null;

  const turn = spawnedInTurn(input.transcript_path, input.turn_id);
  const stuckAdvisors = stuckAdvisorNames();
  if (!turn.found || turn.agentTypes.some((t) => stuckAdvisors.includes(t))) return null;

  const execs = analyzeTurnExecs(input.transcript_path, input.turn_id);
  const claim = detectImpossibilityClaim(lastMsg);
  const goal = latestGoal(input.transcript_path);

  // Every Stop that reaches here (goal-continuation turns included) joins
  // the rolling window the no-progress check reads, whether or not it also
  // trips the failure/claim signals below.
  const file = stuckStateFile(input.session_id, home);
  const state = readStuckState(file);
  const currentRecord = {
    diffSig: computeDiffSig(input.cwd),
    errorSig: execs.topPrefix || null,
    toolCalls: execs.toolCalls,
    goalActive: goal.active,
    textSig: textSignature(lastMsg)
  };
  const history = [...state.history, currentRecord].slice(-NO_PROGRESS_HISTORY_MAX);

  let kind = null;
  let signature = null;
  let reasonLine = null;
  if (execs.blockingPrefix || execs.totalNonzero >= REPEAT_FAILURE_TOTAL_THRESHOLD) {
    kind = 'failure';
    signature = execs.blockingPrefix ? `fail:${execs.blockingPrefix}` : `fail:multi:${execs.totalNonzero}`;
    reasonLine = execs.blockingPrefix
      ? `${REPEAT_FAILURE_PREFIX_THRESHOLD}+ failed commands with the same prefix ("${execs.blockingPrefix}") this turn`
      : `${execs.totalNonzero} failed commands this turn`;
  } else if (claim) {
    kind = 'claim';
    signature = `claim:${sha1(claim)}`;
    reasonLine = `the final answer claims this is impossible ("${claim}")`;
  } else {
    const noProgress = checkNoProgress(history);
    if (noProgress) {
      kind = 'noprogress';
      signature = `noprogress:${noProgress.diffSig}:${noProgress.errorSig || 'none'}`;
      reasonLine = noProgress.errorSig
        ? `no progress across the last ${NO_PROGRESS_WINDOW} Stops (unchanged working tree, repeated "${noProgress.errorSig}" failures)`
        : `no progress across the last ${NO_PROGRESS_WINDOW} Stops (unchanged working tree, near-identical answers)`;
    }
  }

  if (!signature) {
    writeStuckState(file, { blocked: state.blocked, count: state.count, history });
    return null;
  }

  const alreadyBlocked = state.blocked.some((b) => b.signature === signature);
  const overCap = state.count >= STUCK_SESSION_CAP;
  writeStuckState(file, {
    blocked: alreadyBlocked || overCap ? state.blocked : [...state.blocked, { signature, ts: Date.now() }].slice(-20),
    count: alreadyBlocked || overCap ? state.count : state.count + 1,
    history
  });
  if (alreadyBlocked || overCap) return null;

  return buildStuckReason(kind, reasonLine, USER_ONLY_ACTION.test(lastMsg), goal, hasEmptyEscape(lastMsg));
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
  const lastMsg = String(input.last_assistant_message || '');
  const skipMatch = lastMsg.match(SKIP_LINE);
  if (skipMatch && isConcreteReason(skipMatch[1])) return null;
  const turn = spawnedInTurn(input.transcript_path, input.turn_id);
  if (!turn.found || turn.agentTypes.some((t) => ADVISORS.includes(t))) return null;

  fs.writeFileSync(file, JSON.stringify(Object.assign({}, rec, { blocked_turn_id: turnKey })) + '\n');
  const names = rec.advisors.join(' or ');
  return `[AdvisorGate] This request was routed as ${rec.intent}, which requires the Advisor Group, `
    + 'but no advisor was spawned this turn. '
    + `Spawn ${names} now (spawn_agent with agent_type="${rec.advisors[0]}") and pass the context you already gathered, `
    + 'then repeat your final answer with a short "Advisor (<name>)" section. '
    + 'If an advisor is genuinely unnecessary here, add one line "Advisor skipped: <reason>" and repeat the final answer.'
    + (skipMatch && !isConcreteReason(skipMatch[1]) ? ' ' + EMPTY_ESCAPE_NOTE : '');
}

module.exports = {
  ADVISORS, decide, decideStuck, intentFile, recordTurnIntent, spawnedInTurn,
  stuckStateFile, analyzeTurnExecs, detectImpossibilityClaim, stuckAdvisorNames
};

if (require.main === module) {
  try {
    const raw = fs.readFileSync(0, 'utf8');
    const input = raw.trim() ? JSON.parse(raw) : {};
    const reason = decide(input) || decideStuck(input);
    if (reason) process.stdout.write(JSON.stringify({ decision: 'block', reason }) + '\n');
  } catch {
    // A broken gate must never trap the session.
  }
}
