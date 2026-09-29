#!/usr/bin/env node
// Adoption ledger (hooks/adoption-store.js, adoption-tracker.js,
// adoption-cli.js) and its use in registry ranking (hooks/build-registry.js).
// Ported from my-claude's tests/adoption-ledger.test.js to Codex ids ("$name"
// skills) and rollout-based offer capture. Runs against a synthetic $HOME and
// project -- never the developer's real ~/.codex or ~/.config/agent-harness.
// `node tests/adoption-ledger.test.js`
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const HOOKS = path.join(REPO_ROOT, 'hooks');
const FIXTURES = path.join(__dirname, 'fixtures', 'adoption');
const TRACKER = path.join(HOOKS, 'adoption-tracker.js');
const ROUTE_HINT = path.join(HOOKS, 'route-hint.js');
const CLI_BIN = path.join(REPO_ROOT, 'bin', 'my-codex-adoption');
const store = require(path.join(HOOKS, 'adoption-store.js'));
const reg = require(path.join(HOOKS, 'build-registry.js'));
const tracker = require(TRACKER);
const { classifyVerdict } = tracker;
const cli = require(path.join(HOOKS, 'adoption-cli.js'));

const results = [];
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  (' + detail + ')' : ''}`);
  results.push(!!ok);
}

function write(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

function agentToml(name, description) {
  return `name = "${name}"\ndescription = "${description}"\nmodel = "gpt-5.6-sol"\ndeveloper_instructions = "x"\n`;
}

function skillMd(name, description) {
  return `---\nname: ${name}\ndescription: ${description}\n---\n`;
}

// ---------------------------------------------------------------- fixture

const ROOT = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-adoption-'));
const HOME = path.join(ROOT, 'home');
const PROJECT = path.join(ROOT, 'project');
const CODEX = path.join(HOME, '.codex');
const REGISTRY = path.join(CODEX, 'capability-registry.json');
const PATHS = store.storePaths(HOME);
const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();

for (const [name, desc] of [
  ['oracle', 'Read-only second opinion.'],
  ['architect', 'Strategic advisor.'],
  ['metis', 'Pre-planning check.'],
  ['arch-helper', 'Answers architecture questions.'],
  ['security-reviewer', 'Reviews code.'],
  ['vuln-hunter', 'Finds security issues.'],
]) write(path.join(CODEX, 'agents', `${name}.toml`), agentToml(name, desc));
write(path.join(CODEX, 'skills', 'architecture-decision-records', 'SKILL.md'), skillMd('architecture-decision-records', 'ADRs'));
write(path.join(CODEX, 'skills', 'cso', 'SKILL.md'), skillMd('cso', 'Audit.'));
fs.mkdirSync(PROJECT, { recursive: true });

const opts = { home: HOME, cwd: PROJECT, file: REGISTRY };
const env = Object.assign({}, process.env, { HOME, USERPROFILE: HOME, REGISTRY_OUT: REGISTRY });

function ev(id, intent, verdict, daysAgo, kind) {
  return { ts: new Date(NOW - (daysAgo || 0) * DAY).toISOString(), harness: 'codex', session: 's', kind: kind || 'agent', id, intent, verdict, signal: 'reply', evidence: 'x' };
}

function setLedger(events) {
  if (events.length) store.writeJsonl(PATHS.ledger, events);
  else fs.rmSync(PATHS.ledger, { force: true });
}

function repeat(n, fn) {
  return Array.from({ length: n }, (_, i) => fn(i));
}

function run(script, args, input) {
  return cp.spawnSync('node', [script, ...args], { cwd: PROJECT, env, encoding: 'utf8', input: JSON.stringify(input) });
}

function names(registry, intent) {
  return registry.intents[intent].map((c) => c.name);
}

// Rollout lines as Codex 0.158 writes them (see tests/fixtures/adoption).
let clock = Date.parse('2026-09-29T12:00:00.000Z');
function rec(payload, type) {
  clock += 1000;
  return { timestamp: new Date(clock).toISOString(), type: type || (payload.type === 'item_completed' ? 'event_msg' : 'response_item'), payload };
}
const userMsg = (text) => rec({ type: 'item_completed', item: { type: 'UserMessage', content: [{ type: 'text', text }] } });
const spawnV1 = (agentType, callId) => rec({ type: 'function_call', name: 'spawn_agent', call_id: callId, arguments: JSON.stringify(agentType ? { agent_type: agentType, message: 'm' } : { message: 'm' }) });
const spawnV2 = (agentType, task, callId) => rec({ type: 'function_call', name: 'spawn_agent', namespace: 'collaboration', call_id: callId, arguments: JSON.stringify({ agent_type: agentType, task_name: task, message: 'm' }) });
const spawnOut = (task, callId) => rec({ type: 'function_call_output', call_id: callId, output: JSON.stringify({ task_name: `/root/${task}` }) });
const finalAnswer = (task) => rec({ type: 'agent_message', author: `/root/${task}`, recipient: '/root', content: [{ type: 'input_text', text: `Message Type: FINAL_ANSWER\nTask name: /root\nSender: /root/${task}\nPayload:\nok` }] });
const skillInjection = (name) => rec({ type: 'message', role: 'user', content: [{ type: 'input_text', text: `<skill>\n<name>${name}</name>\n<path>/h/.codex/skills/${name}/SKILL.md</path>\nbody\n</skill>` }] });
const skillRead = (file) => rec({ type: 'item_completed', item: { type: 'CommandExecution', parsed_cmd: [{ type: 'read', cmd: `sed -n 1,200p ${file}`, name: 'SKILL.md', path: file }] } });

function writeRollout(file, records) {
  write(file, records.map((r) => JSON.stringify(r)).join('\n') + '\n');
  return file;
}

function readFixture(name) {
  return fs.readFileSync(path.join(FIXTURES, name), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
}

// ---------------------------------------------------------------- verdict classification (same lists as my-claude)

const verdictCases = [
  ['좋아 그렇게 진행해', 'accept'],
  ['좋아 진행해', 'accept'],
  ['반영해줘', 'accept'],
  ['승인, 머지해', 'accept'],
  ['go ahead', 'accept'],
  ['LGTM, ship it', 'accept'],
  ['yes', 'accept'],
  ['아니 틀렸어, 다시 해', 'reject'],
  ['그만하고 되돌려', 'reject'],
  ['No, that is wrong', 'reject'],
  ['redo it', 'reject'],
  ['stop', 'reject'],
  ['좋아 근데 아니 다시 해', 'reject'],
  ['yes, but revert the config change', 'reject'],
  ['좋아 그렇게 진행해. 파일은 수정하지 마.', 'accept'],
  ['진행해, 다른 건 건드리지 마', 'accept'],
  ['하지 마', 'reject'],
  ['그렇게 하지 마', 'reject'],
  ['좋아 근데 그렇게 하지 마', 'reject'],
  ['되돌려', 'reject'],
  ['아니면 다른 방법은?', null],
  ['그만큼 중요한 거야', null],
  ['no problem, what about the tests?', null],
  ['yesterday the build broke', null],
  ['별로 안 좋아', null],
  ['좋아하는 방식이 뭐야', null],
  ['진행해도 될까?', null],
  ['yes or no?', null],
  ["don't stop, keep going", null],
];
for (const [text, want] of verdictCases) {
  const got = classifyVerdict(text);
  check(`verdict ${JSON.stringify(text)} -> ${want || 'neutral'}`, (got ? got.verdict : null) === want, JSON.stringify(got));
}
check('revert keyword -> signal revert', classifyVerdict('되돌려줘').signal === 'revert' && classifyVerdict('please revert it').signal === 'revert' && classifyVerdict('되돌려').signal === 'revert');
check('plain reject -> signal reply', classifyVerdict('틀렸어').signal === 'reply');
{
  // The keyword lists must stay identical to my-claude's (shared ledger semantics).
  const src = fs.readFileSync(TRACKER, 'utf8');
  const mcPath = path.join(os.homedir(), 'my-claude', 'hooks', 'adoption-tracker.js');
  if (fs.existsSync(mcPath)) {
    const block = (text, name) => (text.match(new RegExp(`const ${name} = \\[[\\s\\S]*?\\n\\];`)) || [''])[0];
    const mc = fs.readFileSync(mcPath, 'utf8');
    check('ACCEPT/REVERT/REJECT lists identical to my-claude',
      ['ACCEPT', 'REVERT', 'REJECT'].every((n) => block(src, n) && block(src, n) === block(mc, n)));
  } else {
    console.log('SKIP  ACCEPT/REVERT/REJECT lists identical to my-claude (no ~/my-claude checkout)');
  }
}

// ---------------------------------------------------------------- offers from real rollouts (anonymized fixtures)

{
  const spawnFixture = readFixture('rollout-spawn-agent.jsonl');
  const turns = tracker.extractTurns(spawnFixture);
  check('fixture spawn rollout -> 2 user turns', turns.length === 3, `${turns.length}`);
  const t1 = turns[1].offers.map((o) => `${o.kind}:${o.id}`).join(',');
  check('fixture spawn rollout -> v2 spawn_agent(oracle) offered once its result lands', t1 === 'agent:oracle', t1);
  // The reply that follows: rollout as it stood when the reply was submitted.
  const cut = spawnFixture.findIndex((r) => r.payload.type === 'item_completed' && r.payload.item.type === 'UserMessage' && /좋아/.test(JSON.stringify(r.payload.item.content)));
  const atReply = spawnFixture.slice(0, spawnFixture.slice(0, cut).map((r) => r.payload.type).lastIndexOf('task_started'));
  const judged = tracker.judgedOffers(tracker.extractTurns(atReply));
  check('fixture spawn rollout -> reply judges oracle', judged.map((o) => o.id).join(',') === 'oracle');
  check('fixture spawn rollout -> after that reply nothing is left to judge',
    tracker.judgedOffers(turns).length === 0);

  const skillTurns = tracker.extractTurns(readFixture('rollout-skill-mention.jsonl'));
  const s1 = skillTurns[1].offers.map((o) => o.id);
  check('fixture skill rollout -> <skill> injection and SKILL.md read both seen', s1.length === 2 && s1.every((id) => id === '$demo-greet'), s1.join(','));
  const sj = tracker.judgedOffers(skillTurns);
  check('fixture skill rollout -> "$demo-greet ..." is not a routable prompt, its skill is still judged, once',
    sj.length === 1 && sj[0].kind === 'skill' && sj[0].id === '$demo-greet');
}

{
  const turns = tracker.extractTurns([
    userMsg('plan the migration'),
    spawnV1('metis', 'c1'),
    spawnV1(null, 'c2'),
    spawnV2('oracle', 'bg', 'c3'),
    spawnOut('bg', 'c3'),
    userMsg('also check the ADR'),
    skillRead('/h/.codex/plugins/cache/mk/plug/1.0.0/skills/do-thing/SKILL.md'),
    finalAnswer('bg'),
  ]);
  check('v1 spawn counts at spawn; missing agent_type -> default',
    turns[1].offers.map((o) => o.id).join(',') === 'metis,default', turns[1].offers.map((o) => o.id).join(','));
  check('v2 agent whose result lands in a later turn is offered in that turn',
    turns[2].offers.map((o) => o.id).join(',') === '$plug:do-thing,oracle', turns[2].offers.map((o) => o.id).join(','));
  check('v2 agent still running is not offered', tracker.extractTurns([userMsg('x'), spawnV2('oracle', 't', 'c'), spawnOut('t', 'c')])[1].offers.length === 0);
  check('skillFromPath: global and plugin skills', tracker.skillFromPath('/a/.codex/skills/cso/SKILL.md') === 'cso'
    && tracker.skillFromPath('C:\\u\\.codex\\plugins\\cache\\m\\p\\1\\skills\\s\\SKILL.md') === 'p:s'
    && tracker.skillFromPath('/p/.agents/skills/x/SKILL.md') === 'x');
  check('skillFromPath: a SKILL.md outside the skill roots (a repo being edited) is no skill',
    tracker.skillFromPath('/src/my-codex/skills/cso/SKILL.md') === null && tracker.skillFromPath('/a/.codex/skills/.system/x/SKILL.md') === null);
  const renamed = path.join(ROOT, 'fm', '.codex', 'plugins', 'cache', 'm', 'docs', '1.0', 'skills', 'docs-router', 'SKILL.md');
  write(renamed, skillMd('document', 'Routes documents.'));
  const twice = tracker.extractTurns([userMsg('$docs:document'), skillInjection('docs:document'), skillRead(renamed), skillRead(renamed)]);
  check('skillFromPath: frontmatter name wins over the folder, so injection + read are one item',
    tracker.judgedOffers(twice).map((o) => o.id).join(',') === '$docs:document', tracker.judgedOffers(twice).map((o) => o.id).join(','));

  const many = tracker.extractTurns([userMsg('go'), ...repeat(7, (i) => spawnV1(`a${i}`, `k${i}`)), spawnV1('a3', 'k9')]);
  check('one per item, newest 5 kept', tracker.judgedOffers(many).map((o) => o.id).join(',') === 'a2,a4,a5,a6,a3',
    tracker.judgedOffers(many).map((o) => o.id).join(','));
  const slash = tracker.extractTurns([userMsg('review this'), spawnV1('oracle', 'x1'), userMsg('/compact'), userMsg('$cso')]);
  check('slash / $skill prompts are not boundaries: earlier offers stay judgeable', tracker.judgedOffers(slash).map((o) => o.id).join(',') === 'oracle');
  const later = tracker.extractTurns([userMsg('a'), spawnV1('oracle', 'y1'), userMsg('$cso'), skillInjection('cso')]);
  check('latest turn with offers wins', tracker.judgedOffers(later).map((o) => o.id).join(',') === '$cso');
  const neutralPassed = tracker.extractTurns([userMsg('a'), spawnV1('oracle', 'z1'), userMsg('what about caching')]);
  check('a routable prompt in between closes the window', tracker.judgedOffers(neutralPassed).length === 0);
  const repeated = tracker.extractTurns([userMsg('plan the migration'), spawnV1('oracle', 'e1'), userMsg('yes')]);
  check('the same reply sent twice does not judge the offers again', tracker.judgedOffers(repeated).length === 0);
}

// ---------------------------------------------------------------- route-hint intent -> verdict -> ledger (hooks as spawned)

const reg0 = reg.ensureRegistry(opts);
check('fixture registry builds', reg0.status === 'regenerated', reg0.status);

{
  const SESSION = 'sess-1';
  const rollout = path.join(ROOT, 'rollout-sess-1.jsonl');
  const h = run(ROUTE_HINT, [], { session_id: SESSION, turn_id: 't1', prompt: 'REST에서 gRPC로 옮길까?', cwd: PROJECT });
  check('route-hint still emits its hint', h.stdout.includes('[RouteHint] intent=Architecture'), h.stdout.trim());
  const later = new Date(Date.now() + 60000).toISOString();
  check('route-hint records the intent for the session', store.intentAt(HOME, SESSION, later) === 'Architecture');
  const gateFile = require(path.join(HOOKS, 'advisor-gate.js')).intentFile(SESSION, HOME);
  const first = JSON.parse(fs.readFileSync(gateFile, 'utf8'));
  check('route-intent record keeps the Advisor Gate fields for the current turn',
    first.turn_id === 't1' && first.intent === 'Architecture' && first.advisors.includes('oracle'), JSON.stringify(first));
  run(ROUTE_HINT, [], { session_id: SESSION, prompt: '$cso', cwd: PROJECT });
  run(ROUTE_HINT, [], { session_id: SESSION, prompt: 'x', agent_id: 'sub', cwd: PROJECT });
  const intentRec = JSON.parse(fs.readFileSync(gateFile, 'utf8'));
  check('one route-intent file serves both: current turn for the Advisor Gate, history for adoption',
    intentRec.turn_id === null && intentRec.intent === null && intentRec.history.length === 1 && intentRec.history[0].intent === 'Architecture',
    JSON.stringify(intentRec));
  check('$skill and subagent prompts add no history entry', intentRec.history.length === 1);

  const now = Date.now(); // the turn ran after P1's intent record and well before the reply
  writeRollout(rollout, [
    { timestamp: new Date(now - 5000).toISOString(), type: 'event_msg', payload: { type: 'item_completed', item: { type: 'UserMessage', content: [{ type: 'text', text: 'REST에서 gRPC로 옮길까?' }] } } },
    { timestamp: new Date(now + 10).toISOString(), type: 'response_item', payload: { type: 'function_call', name: 'spawn_agent', namespace: 'collaboration', call_id: 'c1', arguments: '{"agent_type":"oracle","task_name":"rpc","message":"m"}' } },
    { timestamp: new Date(now + 20).toISOString(), type: 'event_msg', payload: { type: 'item_completed', item: { type: 'SubAgentActivity', id: 'c1', kind: 'started', agent_path: '/root/rpc' } } },
    { timestamp: new Date(now + 30).toISOString(), type: 'event_msg', payload: { type: 'item_completed', item: { type: 'SubAgentActivity', id: 'done', kind: 'completed', agent_path: '/root/rpc' } } },
  ]);
  const base = { session_id: SESSION, hook_event_name: 'UserPromptSubmit', transcript_path: rollout, cwd: PROJECT };
  const verdict = (prompt) => run(TRACKER, ['verdict'], Object.assign({ prompt }, base));

  const slash = verdict('/compact');
  check('slash command -> no event', slash.stdout === '' && !fs.existsSync(PATHS.ledger));
  const sub = run(TRACKER, ['verdict'], Object.assign({ prompt: 'yes', agent_id: 'sub-1' }, base));
  check('subagent prompt -> no event', sub.stdout === '' && !fs.existsSync(PATHS.ledger));
  const neutral = verdict('what does the ADR say about caching?');
  check('neutral reply -> no event', neutral.stdout === '' && !fs.existsSync(PATHS.ledger));

  // Codex runs route-hint and the verdict hook concurrently; the reply's own
  // intent record (newer than every offer) must not capture the offers.
  run(ROUTE_HINT, [], { session_id: SESSION, prompt: '좋아 진행해', cwd: PROJECT });
  const v = verdict('좋아 진행해');
  const events = store.readLedger(HOME);
  check('verdict hook prints nothing, exit 0', v.stdout === '' && v.stderr === '' && v.status === 0, JSON.stringify(v.stdout + v.stderr));
  check('accept reply -> one ledger event', events.length === 1, `${events.length}`);
  const e = events[0] || {};
  check('event carries the shared schema with harness codex',
    JSON.stringify(Object.keys(e)) === JSON.stringify(['ts', 'harness', 'session', 'kind', 'id', 'intent', 'verdict', 'signal', 'evidence'])
      && e.harness === 'codex' && e.session === SESSION && e.kind === 'agent' && e.id === 'oracle' && e.intent === 'Architecture'
      && e.verdict === 'accept' && e.signal === 'reply' && e.evidence === '좋아 진행해' && !Number.isNaN(Date.parse(e.ts)), JSON.stringify(e));

  // A turn after the intent was recorded for another prompt keeps its own intent.
  run(ROUTE_HINT, [], { session_id: SESSION, prompt: '이 버그 원인 찾아줘', cwd: PROJECT });
  check('intentAt files an earlier offer under the earlier prompt intent',
    store.intentAt(HOME, SESSION, new Date(now + 10).toISOString()) === 'Architecture'
      && store.intentAt(HOME, SESSION, new Date(Date.now() + 60000).toISOString()) === 'Debug');

  const skillRollout = writeRollout(path.join(ROOT, 'rollout-skill.jsonl'), [userMsg('$cso'), skillInjection('cso')]);
  run(TRACKER, ['verdict'], Object.assign({}, base, { transcript_path: skillRollout, prompt: 'x'.repeat(300) + ' wrong' }));
  const last = store.readLedger(HOME).pop();
  check('skill reject -> kind skill, id "$cso", evidence capped at 120 chars',
    last.kind === 'skill' && last.id === '$cso' && last.verdict === 'reject' && last.evidence.length === 120, JSON.stringify(last).slice(0, 120));

  const missing = run(TRACKER, ['verdict'], Object.assign({}, base, { transcript_path: path.join(ROOT, 'nope.jsonl'), prompt: 'yes' }));
  check('missing transcript -> no output, exit 0', missing.status === 0 && missing.stdout === '' && missing.stderr === '');
  const garbage = cp.spawnSync('node', [TRACKER, 'verdict'], { env, encoding: 'utf8', input: 'not json' });
  check('garbage stdin -> no output, exit 0', garbage.status === 0 && garbage.stdout === '' && garbage.stderr === '');
  const hooks = JSON.parse(fs.readFileSync(path.join(HOOKS, 'hooks.json'), 'utf8')).hooks;
  check('verdict hook registered on UserPromptSubmit',
    hooks.UserPromptSubmit.some((g) => g.hooks.some((x) => x.command.includes('adoption-tracker.js" verdict'))));

  const big = path.join(ROOT, 'rollout-big.jsonl');
  const blob = 'gAAAA' + 'x'.repeat(20000);
  writeRollout(big, [...repeat(400, () => rec({ type: 'reasoning', encrypted_content: blob })), userMsg('go'), spawnV1('oracle', 'b1')]);
  const t0 = process.hrtime.bigint();
  tracker.recordVerdict(Object.assign({}, base, { transcript_path: big, prompt: 'lgtm' }), HOME, NOW);
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  check('8 MB rollout judged in under 500 ms', ms < 500, `${ms.toFixed(1)} ms`);
}

// ---------------------------------------------------------------- adoption_ignore (process skills)

{
  const map = JSON.parse(fs.readFileSync(path.join(HOOKS, 'routing-map.json'), 'utf8'));
  check('routing map lists the process skills to ignore', ['$using-superpowers', '$boss-briefing', '$briefing-vault'].every((id) => map.adoption_ignore.includes(id)));
  const built = JSON.parse(fs.readFileSync(REGISTRY, 'utf8'));
  check('registry carries adoption_ignore from the map', JSON.stringify(built.adoption_ignore) === JSON.stringify(map.adoption_ignore));
  check('tracker reads adoption_ignore from the registry', tracker.adoptionIgnore(HOME).has('$using-superpowers'));
  const saved = fs.readFileSync(REGISTRY, 'utf8');
  fs.writeFileSync(REGISTRY, JSON.stringify(Object.assign(JSON.parse(saved), { adoption_ignore: undefined })));
  check('tracker falls back to the routing map when the registry predates the field', tracker.adoptionIgnore(HOME).has('$boss-briefing'));
  fs.writeFileSync(REGISTRY, saved);

  const ignore = tracker.adoptionIgnore(HOME);
  const sp = path.join(CODEX, 'skills', 'using-superpowers', 'SKILL.md');
  write(sp, skillMd('using-superpowers', 'Meta skill.'));
  const ids = (records) => tracker.judgedOffers(tracker.extractTurns(records, ignore)).map((o) => o.id).join(',');
  check('ignored skills are not offers (SKILL.md read and $mention injection)',
    ids([userMsg('design the cache'), skillRead(sp), skillInjection('boss-briefing'), skillInjection('briefing-vault')]) === '');
  check('a non-ignored skill in the same turn still is', ids([userMsg('design the cache'), skillRead(sp), skillInjection('cso')]) === '$cso');
  check('an ignored-only turn does not hide the earlier turn offers',
    ids([userMsg('design the cache'), spawnV1('oracle', 'i1'), userMsg('$boss-briefing'), skillInjection('boss-briefing')]) === 'oracle');
  const sys = rec({ type: 'message', role: 'user', content: [{ type: 'input_text', text: '<skill>\n<name>imagegen</name>\n<path>/h/.codex/skills/.system/imagegen/SKILL.md</path>\nbody\n</skill>' }] });
  check('.system skills are not offers (injection or read)',
    ids([userMsg('draw it'), sys, skillRead('/h/.codex/skills/.system/imagegen/SKILL.md')]) === '');

  // Through the hook as Codex runs it.
  const S2 = 'sess-ignore';
  run(ROUTE_HINT, [], { session_id: S2, prompt: 'REST에서 gRPC로 옮길까?', cwd: PROJECT });
  const before = store.readLedger(HOME).length;
  const roll = writeRollout(path.join(ROOT, 'rollout-ignore.jsonl'), [userMsg('REST에서 gRPC로 옮길까?'), skillRead(sp), skillInjection('boss-briefing')]);
  run(TRACKER, ['verdict'], { session_id: S2, transcript_path: roll, prompt: '좋아 진행해', cwd: PROJECT });
  check('ignored ids never produce ledger events', store.readLedger(HOME).length === before);
  writeRollout(roll, [userMsg('REST에서 gRPC로 옮길까?'), skillRead(sp), skillInjection('boss-briefing'), skillInjection('cso')]);
  run(TRACKER, ['verdict'], { session_id: S2, transcript_path: roll, prompt: '좋아 진행해', cwd: PROJECT });
  const added = store.readLedger(HOME).slice(before);
  check('a non-ignored skill in that turn still produces its event', added.length === 1 && added[0].id === '$cso', added.map((e) => e.id).join(','));
}

// ---------------------------------------------------------------- ledger compatibility with my-claude

{
  const claudeLine = '{"ts":"2026-09-28T10:00:00.000Z","harness":"claude","session":"c1","kind":"skill","id":"architecture-decision-records","intent":"Architecture","verdict":"accept","signal":"reply","evidence":"좋아 진행해"}';
  setLedger([]);
  write(PATHS.ledger, claudeLine + '\n' + 'not json\n' + JSON.stringify({ ts: 'x', id: 7, intent: ['bad'], verdict: 'accept' }) + '\n');
  const rows = store.readLedger(HOME);
  check('my-claude event line is read without error; malformed rows skipped', rows.length === 1 && rows[0].harness === 'claude' && rows[0].id === 'architecture-decision-records');
  check('my-claude skill id (no "$") never scores a Codex skill',
    reg.adoptionWeight({ name: 'architecture-decision-records', kind: 'skill' }, 'Architecture',
      { stats: store.summarize(repeat(6, () => JSON.parse(claudeLine)), Date.parse('2026-09-29T00:00:00Z')), pins: [] }) === 0);
  const mcStore = path.join(os.homedir(), 'my-claude', 'hooks', 'adoption-store.js');
  if (fs.existsSync(mcStore)) {
    const mc = require(mcStore);
    const mine = store.storePaths(HOME), theirs = mc.storePaths(HOME);
    check('same shared paths as my-claude', ['ledger', 'pins', 'archive', 'audit'].every((k) => mine[k] === theirs[k]));
    check('same weighting as my-claude', [0, 45, 90, 179, 181].every((d) => store.eventWeight(ev('x', 'y', 'accept', d), NOW) === mc.eventWeight(ev('x', 'y', 'accept', d), NOW)));
  } else {
    console.log('SKIP  my-claude store comparison (no ~/my-claude checkout)');
  }
}

// ---------------------------------------------------------------- adoptionWeight + ranking

{
  const oracle = { name: 'oracle', kind: 'agent' };
  const load = (events, pins) => {
    setLedger(events);
    store.writeJson(PATHS.pins, pins || []);
    return store.loadAdoption(HOME, NOW);
  };
  check('no adoption data -> weight 0', reg.adoptionWeight(oracle, 'Architecture') === 0);
  check('n < 5 -> weight 0', reg.adoptionWeight(oracle, 'Architecture', load(repeat(4, () => ev('oracle', 'Architecture', 'accept')))) === 0);
  check('n >= 5 all accepted -> +2 slots', reg.adoptionWeight(oracle, 'Architecture', load(repeat(5, () => ev('oracle', 'Architecture', 'accept')))) === 20);
  check('adoption is per intent', reg.adoptionWeight(oracle, 'Ambiguity', load(repeat(5, () => ev('oracle', 'Architecture', 'accept')))) === 0);
  check('skill rows are keyed "$name"', reg.adoptionWeight({ name: 'cso', kind: 'skill' }, 'Review',
    load(repeat(5, () => ev('$cso', 'Review', 'reject', 0, 'skill')))) === -20);
  check('90-day half-life', Math.abs(store.eventWeight(ev('x', 'y', 'accept', 90), NOW) - 0.5) < 1e-9);
  check('events older than 180 days count for nothing', store.eventWeight(ev('x', 'y', 'accept', 181), NOW) === 0);
  check('6 events 100 days old (effective n < 5) -> weight 0',
    reg.adoptionWeight(oracle, 'Architecture', load(repeat(6, () => ev('oracle', 'Architecture', 'accept', 100)))) === 0);
  check('Security ignores adoption',
    reg.adoptionWeight({ name: 'vuln-hunter', kind: 'agent' }, 'Security', load(repeat(9, () => ev('vuln-hunter', 'Security', 'accept')))) === 0);

  // Map member (architect) fully rejected vs discovered item (arch-helper) fully accepted.
  load([
    ...repeat(10, () => ev('architect', 'Architecture', 'reject')),
    ...repeat(10, () => ev('$architecture-decision-records', 'Architecture', 'reject', 0, 'skill')),
    ...repeat(10, () => ev('arch-helper', 'Architecture', 'accept')),
  ]);
  let ids = names(reg.buildRegistry({ home: HOME, cwd: PROJECT }), 'Architecture');
  const lastMember = Math.max(ids.indexOf('oracle'), ids.indexOf('architect'), ids.indexOf('architecture-decision-records'));
  check('map members never drop below a discovered item', lastMember >= 0 && lastMember < ids.indexOf('arch-helper'), ids.join(','));

  load([...repeat(6, () => ev('architect', 'Architecture', 'accept')), ...repeat(6, () => ev('oracle', 'Architecture', 'reject'))]);
  ids = names(reg.buildRegistry({ home: HOME, cwd: PROJECT }), 'Architecture');
  check('adoption reorders within the member band', ids[0] === 'architect' && ids.indexOf('oracle') > 0
    && ids.indexOf('oracle') < ids.indexOf('arch-helper'), ids.join(','));

  load(repeat(6, () => ev('oracle', 'Architecture', 'accept')), [{ id: 'arch-helper', intent: 'Architecture' }]);
  let r = reg.buildRegistry({ home: HOME, cwd: PROJECT });
  check('pin forces the top of its intent', r.intents.Architecture[0].name === 'arch-helper' && r.intents.Architecture[0].pinned === true, names(r, 'Architecture').join(','));
  check('pin applies to its intent only', r.intents.Ambiguity[0].name === 'metis');
  load(repeat(9, () => ev('oracle', 'Architecture', 'accept')), [{ id: 'architect', intent: 'Architecture' }, { id: 'oracle', intent: 'Architecture' }]);
  ids = names(reg.buildRegistry({ home: HOME, cwd: PROJECT }), 'Architecture');
  check('pins keep the order they were made in', ids[0] === 'architect' && ids[1] === 'oracle', ids.join(','));
  load([], [{ id: '$architecture-decision-records', intent: 'Architecture' }]);
  check('a skill pin uses the "$name" id', names(reg.buildRegistry({ home: HOME, cwd: PROJECT }), 'Architecture')[0] === 'architecture-decision-records');

  load(repeat(9, () => ev('vuln-hunter', 'Security', 'accept')), [{ id: 'vuln-hunter', intent: 'Security' }]);
  const sec = reg.buildRegistry({ home: HOME, cwd: PROJECT }).intents.Security;
  check('Security ignores adoption and pins (map order kept)',
    sec[0].name === 'security-reviewer' && !sec.some((c) => c.pinned || c.adoption), sec.map((c) => c.name).join(','));

  // Active-before-inactive (#124) survives adoption and pins.
  write(path.join(CODEX, 'agent-packs', 'extra', 'pack-arch.toml'), agentToml('pack-arch', 'Architecture tradeoffs.'));
  load(repeat(9, () => ev('pack-arch', 'Architecture', 'accept')), [{ id: 'pack-arch', intent: 'Architecture' }]);
  const act = reg.buildRegistry({ home: HOME, cwd: PROJECT }).intents.Architecture;
  const firstInactive = act.findIndex((c) => !c.active);
  check('active candidates still precede inactive ones (even a pinned inactive one)',
    firstInactive > 0 && act[firstInactive].name === 'pack-arch' && act.slice(firstInactive).every((c) => !c.active), act.map((c) => `${c.name}:${c.active}`).join(','));
  fs.rmSync(path.join(CODEX, 'agent-packs'), { recursive: true, force: true });

  // Summary annotation only once n >= 5.
  load([...repeat(7, () => ev('oracle', 'Architecture', 'accept')), ...repeat(2, () => ev('oracle', 'Architecture', 'reject')),
    ...repeat(4, () => ev('architect', 'Architecture', 'accept'))]);
  r = reg.buildRegistry({ home: HOME, cwd: PROJECT });
  const archLine = (reg.renderSummary(r, REGISTRY).match(/ Architecture: [^.]*\./) || [''])[0];
  check('summary annotates (adopted 7/9) at n >= 5, not below', archLine.includes('oracle[advisor] (adopted 7/9)') && !archLine.includes('architect (adopted'), archLine);
  check('route hint stays unannotated', !reg.formatPick(r.intents.Architecture[0]).includes('adopted'));

  // Registry rebuild when the ledger or pins change, or when it is a day old.
  reg.ensureRegistry(opts);
  check('registry up-to-date when the ledger is unchanged', reg.ensureRegistry(opts).status === 'up-to-date');
  store.appendJsonl(PATHS.ledger, [ev('oracle', 'Architecture', 'accept')]);
  const t1 = new Date(Date.now() + 5000);
  fs.utimesSync(PATHS.ledger, t1, t1);
  check('ledger change triggers a rebuild', reg.ensureRegistry(opts).status === 'regenerated');
  store.writeJson(PATHS.pins, [{ id: 'metis', intent: 'Architecture' }]);
  const t2 = new Date(Date.now() + 9000);
  fs.utimesSync(PATHS.pins, t2, t2);
  check('pins change triggers a rebuild', reg.ensureRegistry(opts).status === 'regenerated');
  const dayOld = JSON.parse(fs.readFileSync(REGISTRY, 'utf8'));
  dayOld.generated_at = new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString();
  fs.writeFileSync(REGISTRY, JSON.stringify(dayOld));
  check('a day-old registry is rebuilt while the ledger has events (decay)', reg.ensureRegistry(opts).status === 'regenerated');
  setLedger([]);
  reg.ensureRegistry(opts);
  const noLedger = JSON.parse(fs.readFileSync(REGISTRY, 'utf8'));
  noLedger.generated_at = new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString();
  fs.writeFileSync(REGISTRY, JSON.stringify(noLedger));
  check('a day-old registry without a ledger stays up-to-date', reg.ensureRegistry(opts).status === 'up-to-date');
  store.writeJson(PATHS.pins, []);
}

// ---------------------------------------------------------------- CLI

{
  const outLines = [];
  const say = (s) => outLines.push(s);
  const run1 = (argv) => { outLines.length = 0; const code = cli.main(argv, { home: HOME, now: NOW, out: say }); return { code, text: outLines.join('') }; };
  setLedger([
    ...repeat(3, () => ev('oracle', 'Architecture', 'accept')),
    Object.assign(ev('metis', 'Ambiguity', 'reject'), { ts: '2026-01-01T00:00:00.000Z' }),
    Object.assign(ev('oracle', 'Ambiguity', 'accept'), { ts: '2026-01-02T00:00:00.000Z' }),
    Object.assign(ev('metis', 'Ambiguity', 'accept'), { ts: '2026-01-02T00:00:00.000Z' }),
  ]);
  fs.rmSync(PATHS.audit, { force: true });
  fs.rmSync(PATHS.archive, { force: true });
  const l = run1(['list']);
  check('list prints an id x intent table', l.code === 0 && /INTENT\s+ID\s+KIND\s+ACCEPT\s+REJECT\s+N/.test(l.text) && /Architecture\s+oracle\s+agent\s+3\.0/.test(l.text), l.text.split('\n')[1]);
  const li = run1(['list', '--intent', 'architecture']);
  check('list --intent filters (case-insensitive)', li.text.includes('oracle') && !li.text.includes('Ambiguity'));
  check('pin with unknown intent is refused', run1(['pin', 'oracle', 'Nope']).code === 1);
  check('pin on a safety intent is refused', run1(['pin', 'vuln-hunter', 'security']).code === 1);
  check('pin writes adoption-pins.json (skill id "$cso")', run1(['pin', '$cso', 'review']).code === 0
    && store.readPins(HOME).some((p) => p.id === '$cso' && p.intent === 'Review'));
  check('list marks the pin', /Review\s+\$cso.*pinned/.test(run1(['list']).text));
  check('unpin removes it', run1(['unpin', '$cso', 'Review']).code === 0 && store.readPins(HOME).length === 0);
  const evl = run1(['list', '--events', '--intent', 'Ambiguity']);
  check('list --events prints ts per event', evl.text.includes('2026-01-02T00:00:00.000Z') && !evl.text.includes('Architecture'), evl.text.split('\n')[0]);
  const amb = run1(['undo', '2026-01-02T00:00:00.000Z']);
  check('undo with a shared ts asks for the id', amb.code === 1 && amb.text.includes('oracle') && amb.text.includes('metis'));
  const u = run1(['undo', '2026-01-02T00:00:00.000Z', 'metis']);
  const archived = store.readJsonl(PATHS.archive);
  check('undo moves exactly one event to the archive', u.code === 0 && store.readLedger(HOME).length === 5
    && archived.length === 1 && archived[0].id === 'metis' && archived[0].archive_reason === 'undo');
  const rs = run1(['reset', 'oracle']);
  check('reset <id> archives only that id', rs.code === 0 && store.readLedger(HOME).every((e) => e.id !== 'oracle') && store.readJsonl(PATHS.archive).length === 5);
  run1(['reset']);
  check('reset archives everything, nothing hard-deleted', store.readLedger(HOME).length === 0 && store.readJsonl(PATHS.archive).length === 6);
  const audits = store.readJsonl(PATHS.audit);
  check('every mutation is audited as harness codex', audits.map((a) => a.action).join(',') === 'pin,unpin,undo,reset,reset'
    && audits.every((a) => a.harness === 'codex'), audits.map((a) => a.action).join(','));
  const viaBin = cp.spawnSync('bash', [CLI_BIN, 'list'], { cwd: ROOT, env, encoding: 'utf8' });
  check('bin/my-codex-adoption dispatches to the CLI', viaBin.status === 0 && viaBin.stdout.includes('No adoption events yet.'), (viaBin.stdout + viaBin.stderr).trim());
  const usage = cp.spawnSync('bash', [CLI_BIN, 'bogus'], { cwd: ROOT, env, encoding: 'utf8' });
  check('unknown subcommand -> usage, exit 1', usage.status === 1 && usage.stdout.startsWith('Usage: my-codex-adoption'));
}

check('nothing was written outside the temp HOME', !fs.existsSync(path.join(os.homedir(), '.config', 'agent-harness', 'adoption-audit.jsonl'))
  || fs.statSync(path.join(os.homedir(), '.config', 'agent-harness', 'adoption-audit.jsonl')).mtimeMs < NOW - 1000);

fs.rmSync(ROOT, { recursive: true, force: true });

const failed = results.filter((ok) => !ok).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
