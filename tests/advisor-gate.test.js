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

// exec tool call + its paired output, as seen in real rollouts
// (~/.codex/sessions/.../*.jsonl): custom_tool_call carries JS glue code with
// a `cmd:"..."` literal, and custom_tool_call_output carries the exit code
// embedded as JSON text inside `output[].text`, matched by call_id.
const execCall = (callId, cmd) => ({ type: 'response_item', payload: { type: 'custom_tool_call', call_id: callId, name: 'exec', input: `text((await tools.exec_command({cmd:"${cmd}",max_output_tokens:1000})).output);` } });
const execOutput = (callId, exitCode) => ({ type: 'response_item', payload: { type: 'custom_tool_call_output', call_id: callId, output: [{ type: 'input_text', text: 'Script completed\nWall time 0.1 seconds\nOutput:\n' }, { type: 'input_text', text: JSON.stringify({ chunk_id: 'x', wall_time_seconds: 0.01, exit_code: exitCode, original_token_count: 1, output: '' }) }] } });
// n failing calls sharing `prefix`, each with a distinct call_id.
const failingRun = (prefix, n) => {
  const entries = [];
  for (let i = 0; i < n; i++) {
    const id = `call_${prefix.replace(/\s+/g, '_')}_${i}`;
    entries.push(execCall(id, `${prefix} arg${i}`));
    entries.push(execOutput(id, 1));
  }
  return entries;
};

// thread_goal_updated, as seen in the one real rollout that carries it
// (~/.codex/sessions/2026/09/29/...): status is the lowercase string
// "active", and the field is goal.objective/goal.status, not top-level.
const goalUpdated = (objective, status = 'active') => ({
  type: 'event_msg',
  payload: { type: 'thread_goal_updated', threadId: 'th1', goal: { threadId: 'th1', objective, status, tokensUsed: 1, timeUsedSeconds: 1, createdAt: 1, updatedAt: 2 } }
});

// A real git repo so computeDiffSig sees actual working-tree changes: tests
// for the no-progress signal use this to tell "a patch landed" (diffSig
// changes) from "nothing changed" (diffSig repeats).
function gitHome() {
  const home = freshHome();
  cp.execSync('git init -q', { cwd: home });
  cp.execSync('git config user.email test@example.com', { cwd: home });
  cp.execSync('git config user.name test', { cwd: home });
  fs.writeFileSync(path.join(home, 'file.txt'), 'v0\n');
  cp.execSync('git add -A && git commit -q -m init', { cwd: home });
  return home;
}

// Stuck scenario: no advisor intent recorded (decide() stays out of the way),
// so only decideStuck() can block.
function stuckStop({ turnId = 't1', entries = [started('t1')], lam = 'Still investigating.', extra = {}, home = freshHome() } = {}) {
  const transcript = entries === null ? path.join(home, 'missing.jsonl') : writeRollout(home, entries);
  const payload = Object.assign({
    session_id: 's-stuck', turn_id: turnId, transcript_path: transcript, cwd: home,
    hook_event_name: 'Stop', model: 'm', permission_mode: 'auto', stop_hook_active: false,
    last_assistant_message: lam
  }, extra);
  return Object.assign(runHook(GATE, home, payload), { home, payload });
}

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

// ------------------------------------------------------------- Stuck trigger

check('23. 3 same-prefix failures -> block',
  stuckStop({ entries: [started('t1'), ...failingRun('npm test', 3)] }).blocked);
check('24. 5 mixed-prefix failures (1 each) -> block', stuckStop({
  entries: [started('t1'),
    ...failingRun('git status', 1), ...failingRun('npm test', 1), ...failingRun('ls -la', 1),
    ...failingRun('cat file', 1), ...failingRun('grep x', 1)]
}).blocked);
check('25. 2 failures -> none',
  !stuckStop({ entries: [started('t1'), ...failingRun('npm test', 2)] }).blocked);
check('26. impossibility claim (EN) -> block',
  stuckStop({ lam: 'Given the current constraints, this is impossible to fix.' }).blocked);
check('27. impossibility claim (KO) -> block',
  stuckStop({ lam: '현재 제약 조건에서는 이 작업이 불가능합니다.' }).blocked);
check('28. claim inside a code fence -> none', !stuckStop({
  lam: 'Here is the log:\n```\nthis is impossible in bash\n```\nLet me look further.'
}).blocked);
check('29. "Blocked on user: <action>" escape line -> none',
  !stuckStop({ lam: 'Blocked on user: approve hook trust before I can continue.' }).blocked);
check('30. "Advisor skipped: <reason>" escape line -> none',
  !stuckStop({ lam: 'Advisor skipped: not needed. This is impossible anyway.' }).blocked);
check('31. oracle spawned this turn -> none', !stuckStop({
  entries: [started('t1'), spawn('oracle')],
  lam: 'This is impossible without additional access.'
}).blocked);
{
  const first = stuckStop({ entries: [started('t1'), ...failingRun('npm test', 3)] });
  check('32. Stuck blocks once', first.blocked);
  const second = runHook(GATE, first.home, first.payload);
  check('33. same episode on a second Stop -> none', !second.blocked);
}
{
  const home = freshHome();
  const ep1 = stuckStop({ home, entries: [started('t1'), ...failingRun('npm test', 3)] });
  check('34. episode 1 -> block', ep1.blocked);
  const ep2 = stuckStop({ home, turnId: 't2', entries: [started('t2'), ...failingRun('go build', 3)] });
  check('35. episode 2 -> block', ep2.blocked);
  const ep3 = stuckStop({ home, turnId: 't3', entries: [started('t3'), ...failingRun('cargo test', 3)] });
  check('36. episode 3 -> none (session cap)', !ep3.blocked);
}
check('37. routing-map Stuck entry is read', gate.stuckAdvisorNames().join() === 'tracer,oracle,architect,metis,debugger');
check('38. spawning architect (not oracle) satisfies the gate', !stuckStop({
  entries: [started('t1'), spawn('architect'), ...failingRun('npm test', 3)]
}).blocked);
check('38b. spawning tracer satisfies the gate', !stuckStop({
  entries: [started('t1'), spawn('tracer'), ...failingRun('npm test', 3)]
}).blocked);
{
  const tomlPath = path.join(HOOKS, '..', 'codex-agents', 'omo', 'tracer.toml');
  const toml = fs.readFileSync(tomlPath, 'utf8');
  check('38c. tracer.toml exists with model gpt-6-astra', /^model = "gpt-6-astra"$/m.test(toml));
}

// -------------------------------------------------- Stuck: no-progress loop

{
  const home = freshHome();
  const loopTurn = (turnId) => stuckStop({
    home, turnId, entries: [started(turnId), ...failingRun('npm test', 1)],
    lam: 'Still investigating the npm test failure.'
  });
  check('39a. loop turn 1 -> none (history too short)', !loopTurn('t1').blocked);
  check('39b. loop turn 2 -> none (history too short)', !loopTurn('t2').blocked);
  const t3 = loopTurn('t3');
  check('39. 3-turn loop without goal mode -> block (no progress)',
    t3.blocked && /no progress/.test(t3.doc.reason), t3.doc && t3.doc.reason);
}
{
  const home = freshHome();
  const objective = 'Ship the refactor end to end';
  const goalTurn = (turnId) => stuckStop({
    home, turnId, entries: [started(turnId), goalUpdated(objective), ...failingRun('go build', 1)],
    lam: 'Still working on the build error.'
  });
  goalTurn('t1');
  goalTurn('t2');
  const t3 = goalTurn('t3');
  check('40. goal-mode loop (3 continuation turns, same failing command) -> block, mentions the /goal objective',
    t3.blocked && t3.doc.reason.includes(objective), t3.doc && t3.doc.reason);
}
{
  const home = gitHome();
  const patchTurn = (turnId, touchFile) => {
    if (touchFile) fs.writeFileSync(path.join(home, 'file.txt'), `v-${turnId}\n`);
    return stuckStop({
      home, turnId, entries: [started(turnId), ...failingRun('npm test', 1)],
      lam: 'Still investigating the npm test failure.'
    });
  };
  check('41a. turn 1 -> none', !patchTurn('t1', false).blocked);
  check('41b. turn 2, a successful patch lands -> none', !patchTurn('t2', true).blocked);
  check('41. successful patch in between -> none (diffSig changed mid-loop)', !patchTurn('t3', false).blocked);
}

// -------------------------------------------------- Escape-line validation

check('42. routed-intent gate: empty "Advisor skipped:" reason -> block',
  stop({ lam: 'Advisor skipped:' }).blocked);
check('43. routed-intent gate: placeholder "Advisor skipped: n/a" -> block',
  stop({ lam: 'Advisor skipped: n/a' }).blocked);
check('44. routed-intent gate: real reason -> none',
  !stop({ lam: 'Advisor skipped: the user already chose REST over gRPC here.' }).blocked);
{
  const r = stuckStop({ entries: [started('t1'), ...failingRun('npm test', 3)], lam: 'Advisor skipped:' });
  check('45. Stuck: empty "Advisor skipped:" reason -> block, asks for a concrete reason',
    r.blocked && /concrete reason/.test(r.doc.reason), r.doc && r.doc.reason);
}
check('46. Stuck: placeholder "Blocked on user: n/a" -> block',
  stuckStop({ entries: [started('t1'), ...failingRun('npm test', 3)], lam: 'Blocked on user: n/a' }).blocked);
check('47. Stuck: real reason -> none', !stuckStop({
  entries: [started('t1'), ...failingRun('npm test', 3)],
  lam: 'Blocked on user: needs the user to approve the GitHub App installation manually.'
}).blocked);

{
  // Not a git repo: computeDiffSig fails open ('nogit'), so repeated text
  // alone is never a no-progress block and the hook must not throw.
  const home = freshHome();
  const results = ['t1', 't2', 't3', 't4'].map((turnId) => stuckStop({
    home, turnId, entries: [started(turnId)], lam: 'Still investigating the same thing.'
  }));
  check('48. non-git cwd: repeated turns -> no no-progress block, no throw',
    results.every((r) => !r.blocked));
}

{
  const claim = (lam) => stuckStop({ entries: [started('t1')], lam });
  check('49. impossibility: bullet that only names the scenario -> none', !claim('- 불가능 주장 → oracle').blocked);
  check('50. impossibility: "이 작업은 불가능합니다." -> block', claim('이 작업은 불가능합니다.').blocked);
  check('51. impossibility: "This is impossible without admin rights." -> block', claim('This is impossible without admin rights.').blocked);
  check('52. impossibility: inline-coded `불가능합니다` -> none', !claim('The gate matches `불가능합니다` in text.').blocked);
  check('53. impossibility: quoted "This is impossible" -> none', !claim('The phrase "this is impossible" is a trigger.').blocked);
}

if (failures) {
  console.log(`${failures} FAILED`);
  process.exit(1);
}
console.log('ALL PASSED');
