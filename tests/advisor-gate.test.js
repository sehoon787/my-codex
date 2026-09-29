#!/usr/bin/env node
// Tests for hooks/advisor-gate.js (the Stop-hook Advisor Gate) and the turn
// intent record route-hint.js writes for it. Every run uses a synthetic $HOME
// and fake Codex rollouts; the real ~/.codex is never read or written.
// `node tests/advisor-gate.test.js`
//
// Rollout shapes mirror codex-cli rollouts (see tests/stop-final-report.test.js):
// a turn starts with event_msg/task_started, and a subagent launch is a
// response_item/function_call named spawn_agent whose JSON `arguments` carry
// the `agent_type`.
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOKS = path.resolve(__dirname, '..', 'hooks');
const GATE = path.join(HOOKS, 'advisor-gate.js');
const ROUTE_HINT = path.join(HOOKS, 'route-hint.js');
const gate = require(GATE);

const started = (turnId) => ({ type: 'event_msg', payload: { type: 'task_started', turn_id: turnId } });
const spawn = (agentType) => ({ type: 'response_item', payload: { type: 'function_call', name: 'spawn_agent', namespace: 'collaboration', arguments: JSON.stringify({ task_name: 'x', agent_type: agentType, message: 'm' }) } });
const shell = () => ({ type: 'response_item', payload: { type: 'function_call', name: 'exec_command', arguments: '{"cmd":"ls"}' } });

let failures = 0;
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok || detail === undefined ? '' : `  (${detail})`}`);
  if (!ok) failures++;
}

function freshHome() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'advisor-gate-home-'));
}

function writeRollout(home, entries) {
  const file = path.join(home, 'rollout.jsonl');
  fs.writeFileSync(file, entries.map((e) => JSON.stringify(e)).join('\n') + '\n');
  return file;
}

function runHook(script, home, payload) {
  const r = cp.spawnSync('node', [script], {
    input: typeof payload === 'string' ? payload : JSON.stringify(payload),
    encoding: 'utf8',
    env: Object.assign({}, process.env, { HOME: home, USERPROFILE: home })
  });
  let doc = null;
  try { doc = JSON.parse(r.stdout); } catch { /* not JSON */ }
  return { r, doc, blocked: Boolean(doc && doc.decision === 'block') };
}

// Stop scenario: record an intent for turn `t1`, then fire Stop for `turnId`.
function stop({ intent = 'Architecture', advisors = ['oracle'], recordTurn = 't1', turnId = 't1',
  entries = [started('t1')], lam = 'Recommendation: keep hooks.json.', extra = {}, home = freshHome() } = {}) {
  gate.recordTurnIntent({ session_id: 's1', turn_id: recordTurn }, intent, advisors, home);
  const transcript = entries === null ? path.join(home, 'missing.jsonl') : writeRollout(home, entries);
  const payload = Object.assign({
    session_id: 's1', turn_id: turnId, transcript_path: transcript, cwd: home,
    hook_event_name: 'Stop', model: 'm', permission_mode: 'auto', stop_hook_active: false,
    last_assistant_message: lam
  }, extra);
  return Object.assign(runHook(GATE, home, payload), { home, payload });
}

// ---------------------------------------------------------------- Stop gate

{
  const res = stop();
  check('1. advisor intent, no spawn -> block once', res.blocked && res.r.status === 0);
  check('1b. block reason names the intent and the advisor',
    res.blocked && /Architecture/.test(res.doc.reason) && /agent_type="oracle"/.test(res.doc.reason) && /Advisor skipped:/.test(res.doc.reason));
  check('1c. output is exactly {decision, reason}', res.doc && Object.keys(res.doc).sort().join() === 'decision,reason');
  const again = runHook(GATE, res.home, res.payload);
  check('1d. second Stop for the same turn -> pass (never blocks twice)', !again.blocked && again.r.stdout === '');
}
check('2. oracle spawned this turn -> pass', !stop({ entries: [started('t1'), shell(), spawn('oracle')] }).blocked);
check('3. any advisor (momus) spawned -> pass', !stop({ entries: [started('t1'), spawn('momus')] }).blocked);
check('4. only a non-advisor (architect) spawned -> block', stop({ entries: [started('t1'), spawn('architect')] }).blocked);
check('5. advisor spawned in an EARLIER turn only -> block',
  stop({ entries: [started('t0'), spawn('oracle'), started('t1'), shell()] }).blocked);
check('6. "Advisor skipped: <reason>" in the final answer -> pass',
  !stop({ lam: 'Answer.\nAdvisor skipped: the user already chose REST.' }).blocked);
check('7. stop_hook_active -> pass', !stop({ extra: { stop_hook_active: true } }).blocked);
check('8. subagent Stop (agent_id) -> pass', !stop({ extra: { agent_id: 'a1', agent_type: 'oracle' } }).blocked);
check('9. intent recorded for another turn -> pass', !stop({ recordTurn: 't0' }).blocked);
check('10. intent without advisors (Debug) -> pass', !stop({ intent: 'Debug', advisors: [] }).blocked);
check('11. rollout missing -> fail open', !stop({ entries: null }).blocked);
{
  const home = freshHome();
  gate.recordTurnIntent({ session_id: 's1', turn_id: 't1' }, 'PlanReview', ['momus'], home);
  const tp = path.join(home, 'garbage.jsonl');
  fs.writeFileSync(tp, 'not json\n{{{\n');
  const r = runHook(GATE, home, { session_id: 's1', turn_id: 't1', transcript_path: tp, last_assistant_message: 'x' });
  check('12. unreadable rollout (no task_started) -> fail open', !r.blocked);
}
check('13. no intent record for the session -> pass',
  !runHook(GATE, freshHome(), { session_id: 'none', turn_id: 't1', last_assistant_message: 'x' }).blocked);
for (const bad of ['', 'not json', '42']) {
  const r = runHook(GATE, freshHome(), bad);
  check(`14. malformed input ${JSON.stringify(bad)} -> silent exit 0`, r.r.status === 0 && r.r.stdout === '' && r.r.stderr === '');
}

// ------------------------------------------------- route-hint intent record

{
  const home = freshHome();
  const prompt = (text, extra) => runHook(ROUTE_HINT, home, Object.assign({
    session_id: 'sess/1', turn_id: 'turn-a', hook_event_name: 'UserPromptSubmit', cwd: home, prompt: text
  }, extra || {}));
  const file = gate.intentFile('sess/1', home);
  const read = () => JSON.parse(fs.readFileSync(file, 'utf8'));

  const arch = prompt('Should we move from REST to gRPC for our internal services?');
  check('15. route-hint still emits exactly one RouteHint document',
    arch.r.status === 0 && arch.r.stdout.trim().split('\n').length === 1 && arch.doc && /\[RouteHint\] intent=Architecture/.test(arch.doc.hookSpecificOutput.additionalContext));
  check('15b. Architecture prompt records intent + oracle for this turn',
    read().intent === 'Architecture' && read().advisors.join() === 'oracle' && read().turn_id === 'turn-a');
  check('15c. session id is sanitised into a file name inside route-intent/',
    path.dirname(file) === path.join(home, '.codex', 'my-codex', 'route-intent') && !path.basename(file).includes('/'));

  prompt('이 계획 이대로 실행해도 돼? 1) DB 덤프 2) 테이블 삭제 3) 복원', { turn_id: 'turn-b' });
  check('16. Korean plan-review prompt records PlanReview + momus', read().intent === 'PlanReview' && read().advisors.join() === 'momus');

  prompt('Fix the typo recieve in README.md', { turn_id: 'turn-c' });
  check('17. a later trivial prompt overwrites the record (no stale gate)', read().intent === 'Trivial' && read().advisors.length === 0 && read().turn_id === 'turn-c');

  prompt('/review the plan', { turn_id: 'turn-d' });
  check('18. slash command clears the intent', read().intent === null && read().turn_id === 'turn-d');

  prompt('Should we move to gRPC?', { turn_id: 'turn-e', agent_id: 'sub-1' });
  check('19. subagent prompt leaves the root record untouched', read().turn_id === 'turn-d');

  const noSession = freshHome();
  runHook(ROUTE_HINT, noSession, { prompt: 'Should we move from REST to gRPC?' });
  check('20. no session_id -> nothing written', !fs.existsSync(path.join(noSession, '.codex', 'my-codex', 'route-intent')));
}
{
  // End to end: the record route-hint writes is what the Stop gate reads.
  const home = freshHome();
  runHook(ROUTE_HINT, home, { session_id: 's9', turn_id: 'u1', prompt: 'my-codex 좀 더 좋게 해줘' });
  const tp = writeRollout(home, [started('u1'), shell()]);
  const r = runHook(GATE, home, { session_id: 's9', turn_id: 'u1', transcript_path: tp, stop_hook_active: false, last_assistant_message: 'Here is what I would improve.' });
  check('21. route-hint -> Stop end to end: Ambiguity without metis blocks', r.blocked && /metis/.test(r.doc.reason));
}
{
  const home = freshHome();
  const dir = path.join(home, '.codex', 'my-codex', 'route-intent');
  fs.mkdirSync(dir, { recursive: true });
  const stale = path.join(dir, 'old.json');
  fs.writeFileSync(stale, '{}');
  const old = (Date.now() - 8 * 24 * 60 * 60 * 1000) / 1000;
  fs.utimesSync(stale, old, old);
  gate.recordTurnIntent({ session_id: 'new', turn_id: 't' }, null, [], home);
  check('22. records older than 7 days are pruned on write', !fs.existsSync(stale) && fs.existsSync(gate.intentFile('new', home)));
}

if (failures) {
  console.log(`${failures} FAILED`);
  process.exit(1);
}
console.log('ALL PASSED');
