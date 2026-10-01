#!/usr/bin/env node
// Learning loop (hooks/learning-store.js, learning-review.js, learning-cli.js),
// Codex port of my-claude's tests/learning-loop.test.js: correction and
// repeated-workflow detection from Codex rollouts, the Stop marker ->
// SessionStart review, the pending queue, approval into the user-owned layer
// (learned-rules + the AGENTS.md learned section, skills/learned-*), the
// curator, rollback, and SessionStart surfacing. Runs against synthetic $HOMEs
// only — never the developer's real ~/.codex or ~/.config/agent-harness.
// `node tests/learning-loop.test.js`
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const HOOKS = path.join(REPO_ROOT, 'hooks');
const REVIEW = path.join(HOOKS, 'learning-review.js');
const BIN = path.join(REPO_ROOT, 'bin', 'my-codex-learn');
const store = require(path.join(HOOKS, 'learning-store.js'));
const review = require(REVIEW);
const cli = require(path.join(HOOKS, 'learning-cli.js'));
const reg = require(path.join(HOOKS, 'build-registry.js'));

const results = [];
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail && !ok ? '  (' + detail + ')' : ''}`);
  results.push(!!ok);
}

const ROOT = fs.mkdtempSync(path.join(os.tmpdir(), 'learning-'));
const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();
let homeSeq = 0;
function newHome() {
  const h = path.join(ROOT, `home${++homeSeq}`);
  fs.mkdirSync(h, { recursive: true });
  return h;
}

function runCli(home, argv, now) {
  let out = '';
  const code = cli.main(argv, { home, now: now || NOW, out: (s) => { out += s; } });
  return { code, out };
}

// ---------------------------------------------------------------- rollouts
// Shapes observed in codex-cli 0.158 rollouts (see tests/adoption-ledger.test.js).

const started = (turn) => JSON.stringify({ type: 'event_msg', payload: { type: 'task_started', turn_id: turn } });
function userLine(text) {
  return JSON.stringify({ type: 'event_msg', payload: { type: 'item_completed', item: { type: 'UserMessage', content: [{ type: 'text', text }] } } });
}
function agentLine(text) {
  return JSON.stringify({ type: 'event_msg', payload: { type: 'item_completed', item: { type: 'AgentMessage', content: [{ type: 'Text', text: text || 'done' }] } } });
}
function spawnLine(agentType) {
  return JSON.stringify({ type: 'response_item', payload: { type: 'function_call', name: 'spawn_agent', arguments: JSON.stringify({ agent_type: agentType, message: 'x' }), call_id: `c${Math.random()}` } });
}
function skillLine(name) {
  return JSON.stringify({ type: 'response_item', payload: { type: 'message', role: 'user', content: [{ type: 'input_text', text: `<skill>\n<name>${name}</name>\n<path>/h/.codex/skills/${name}/SKILL.md</path>\nbody</skill>` }] } });
}
function toolOutputLine(text) {
  return JSON.stringify({ type: 'response_item', payload: { type: 'function_call_output', call_id: 'c0', output: text } });
}
function hookPromptLine(text) {
  return JSON.stringify({ type: 'event_msg', payload: { type: 'item_completed', item: { type: 'HookPrompt', text } } });
}
function writeRollout(lines) {
  const file = path.join(ROOT, `rollout-${Math.random().toString(36).slice(2)}.jsonl`);
  fs.writeFileSync(file, lines.join('\n') + '\n');
  return file;
}

// ---------------------------------------------------------------- correction rule (same cases as my-claude)

const correctionCases = [
  ["Don't use tables in the summary.", true],
  ['Never push to main without asking.', true],
  ['Always write tests first', true],
  ['No, don’t add comments to every line', true],
  ['You should always run the linter before committing', true],
  ['From now on answer in Korean', true],
  ['Stop doing force pushes', true],
  ['Use pnpm instead of npm', true],
  ['표는 항상 한국어로 작성해줘, 영어 헤더 쓰지 마', true],
  ['영어 헤더 쓰지 마세요', true],
  ['다음부터 커밋 전에 테스트 돌려', true],
  ['앞으로 커밋 메시지는 영어로 써줘', true],
  ['npm 말고 pnpm 써', true],
  ['그렇게 하지 말고 파일을 나눠', true],
  ['it always fails on CI', false],
  ["I don't know why it broke", false],
  ['Should I always use pnpm?', false],
  ['Why did you use npm instead of pnpm?', false],
  ['never mind, keep going', false],
  ['Ok, never mind.', false],
  ['No, never mind, keep going', false],
  ["Don't know, you pick", false],
  ["Don't worry about the warnings", false],
  ['항상 그랬잖아', false],
  ['제가 대신 할게요', false],
  ['다음부터 이렇게 할까?', false],
  ['looks good, ship it', false],
];
for (const [text, want] of correctionCases) {
  check(`correction ${JSON.stringify(text)} -> ${want}`, review.isCorrection(text) === want);
}
check('"always" inside a code block is not a correction', review.correctionText('Run this:\n```\n# always run tests\n```') === null);
check('"never" inside inline code is not a correction', review.correctionText('the flag is `--never-fail`, check it') === null);
check('quoted line is not a correction', review.correctionText('> Always use tabs\nthat is what the doc says') === null);
check('slash command is not a correction', review.correctionText('/review never skip tests') === null);
check('$skill prompt is not a correction', review.correctionText('$review never skip tests') === null);
check('tagged block is not a correction', review.correctionText('<environment_context>Always ...</environment_context>') === null);
check('a long pasted brief is not a correction', review.correctionText(`Always do X. ${'context '.repeat(300)}`) === null);
check('correcting sentences are kept, others dropped',
  review.correctionText('Nice work. Don\'t use emojis in commit messages. Thanks') === "Don't use emojis in commit messages.");
check('correction text capped at 200 chars', review.correctionText(`Always ${'x'.repeat(400)}`).length === 200);

// ---------------------------------------------------------------- rollout scan

{
  const HOME = newHome();
  const timeline = review.readTimeline(writeRollout([
    started('t1'),
    userLine('Always use the executor for this. Build the report.'),
    spawnLine('executor'),
    toolOutputLine('Always remember: results here'),
    agentLine(),
    started('t2'),
    userLine('표는 항상 한국어로 작성해줘, 영어 헤더 쓰지 마'),
    skillLine('learned-investigate-then-debugger'),
    agentLine(),
    hookPromptLine('[FinalReport] Always end with the report tables.'),
    started('t3'),
    userLine('what does it do?'),
    agentLine(),
  ]), HOME);
  const scan = review.scanTimeline(timeline);
  check('first prompt of the session is never a correction', scan.rules.length === 1, JSON.stringify(scan.rules));
  check('tool output and hook prompts are not user messages', !scan.rules.some((r) => /remember|report tables/.test(r.text)));
  check('context = the agent that ran just before', scan.rules[0] && scan.rules[0].context && scan.rules[0].context.id === 'executor' && scan.rules[0].context.kind === 'agent');
  check('$learned-* skill use is recorded (without the $)', scan.skillUses.length === 1 && scan.skillUses[0] === 'learned-investigate-then-debugger', JSON.stringify(scan.skillUses));
}

{
  const picked = review.pickRules([
    { text: '수정은 하지마' },
    { text: '앞으로 표는 한국어로 써줘' },
    { text: '멈추지 말고 진행해' },
    { text: '멈추지 말고 진행해!' },
  ]).map((r) => r.text);
  check('per session: at most 2 rules, standing phrasing first, then latest, deduped',
    picked.length === 2 && picked[0] === '앞으로 표는 한국어로 써줘' && picked[1] === '멈추지 말고 진행해!', picked.join(' | '));
}

// ---------------------------------------------------------------- Stop mark -> SessionStart review (spawned)

{
  const HOME = newHome();
  const rollout = writeRollout([
    started('t1'), userLine('Summarize the release notes'), spawnLine('executor'), agentLine(),
    started('t2'), userLine('표는 항상 한국어로 작성해줘, 영어 헤더 쓰지 마'), agentLine(),
  ]);
  const env = Object.assign({}, process.env, { HOME, USERPROFILE: HOME });
  const stop = { hook_event_name: 'Stop', session_id: 'sess-a', turn_id: 't2', transcript_path: rollout, stop_hook_active: false, last_assistant_message: 'ok' };
  const m = cp.spawnSync('node', [REVIEW, 'mark'], { env, encoding: 'utf8', input: JSON.stringify(stop) });
  check('mark: exits 0 and prints nothing', m.status === 0 && m.stdout === '' && m.stderr === '', m.stderr);
  check('mark: one marker for the session, nothing reviewed yet', fs.existsSync(review.markerPath(HOME, 'sess-a')) && store.readSuggestions(HOME).length === 0);
  const sub = cp.spawnSync('node', [REVIEW, 'mark'], { env, encoding: 'utf8', input: JSON.stringify(Object.assign({}, stop, { session_id: 'sub-1', agent_id: 'a1' })) });
  check('mark: a subagent Stop writes no marker', sub.status === 0 && !fs.existsSync(review.markerPath(HOME, 'sub-1')));
  const t0 = Date.now();
  const r = cp.spawnSync('node', [REVIEW, 'pending'], { env, encoding: 'utf8' });
  const ms = Date.now() - t0;
  check('pending: exits 0 and prints nothing', r.status === 0 && r.stdout === '' && r.stderr === '', `stdout=${JSON.stringify(r.stdout)} stderr=${r.stderr}`);
  check('pending: runs under 500 ms (process start included)', ms < 500, `${ms} ms`);
  const rows = store.readSuggestions(HOME);
  check('rule suggestion queued from the correction', rows.length === 1 && rows[0].kind === 'rule' && rows[0].status === 'pending'
    && rows[0].text === '표는 항상 한국어로 작성해줘, 영어 헤더 쓰지 마' && rows[0].context.id === 'executor' && rows[0].scope === 'global'
    && rows[0].session === 'sess-a' && rows[0].harness === 'codex', JSON.stringify(rows));
  check('pending: the marker is consumed (each session reviewed once)', !fs.existsSync(review.markerPath(HOME, 'sess-a')));
  check('nothing written to learned-rules/, skills/ or AGENTS.md before approval',
    !fs.existsSync(path.join(HOME, '.codex', 'learned-rules')) && !fs.existsSync(path.join(HOME, '.codex', 'skills')) && !fs.existsSync(path.join(HOME, '.codex', 'AGENTS.md')));

  // Resumed session: marked again, reviewed again -> nothing queued twice, budget kept.
  fs.appendFileSync(rollout, [started('t3'), userLine("Don't use emojis. Never add a summary table."), agentLine(), started('t4'), userLine('Always answer in English.'), agentLine()].join('\n') + '\n');
  cp.spawnSync('node', [REVIEW, 'mark'], { env, encoding: 'utf8', input: JSON.stringify(stop) });
  cp.spawnSync('node', [REVIEW, 'pending'], { env, encoding: 'utf8' });
  const again = store.readSuggestions(HOME);
  check('re-review of a resumed session: no duplicate, at most 2 rules per session in total', again.length === 2 && again.filter((s) => s.session === 'sess-a').length === 2, JSON.stringify(again.map((s) => s.text)));

  const bad = cp.spawnSync('node', [REVIEW, 'mark'], { env, encoding: 'utf8', input: 'not json' });
  check('malformed payload -> silent exit 0', bad.status === 0 && bad.stdout === '');
  cp.spawnSync('node', [REVIEW, 'mark'], { env, encoding: 'utf8', input: JSON.stringify({ session_id: 'gone', transcript_path: path.join(ROOT, 'nope.jsonl') }) });
  const missing = cp.spawnSync('node', [REVIEW, 'pending'], { env, encoding: 'utf8' });
  check('missing rollout -> silent exit 0, marker dropped', missing.status === 0 && missing.stdout === '' && !fs.existsSync(review.markerPath(HOME, 'gone')));
  const scratch = store.learningPaths(HOME).scratch;
  store.writeAtomic(path.join(scratch, 'review-old.json'), JSON.stringify({ session: 'old', transcript_path: rollout, ts: new Date(NOW - 40 * DAY).toISOString() }));
  review.reviewPending(HOME, NOW);
  check('markers older than 30 days are dropped unreviewed', !fs.existsSync(path.join(scratch, 'review-old.json')));
}

// ---------------------------------------------------------------- workflow detection

function ev(session, id, kind, verdict, daysAgo, minute, intent, harness) {
  return { ts: new Date(NOW - daysAgo * DAY + minute * 60000).toISOString(), harness: harness || 'codex', session, kind, id, intent: intent || 'Debug', verdict, signal: 'reply', evidence: 'x' };
}
function chainSessions(n, daysAgo) {
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(ev(`w${i}`, '$investigate', 'skill', 'accept', daysAgo || 1, 0));
    out.push(ev(`w${i}`, 'debugger', 'agent', 'accept', daysAgo || 1, 1));
  }
  return out;
}
{
  const three = review.workflowCandidates(chainSessions(3), NOW);
  check('chain accepted in 3 sessions -> skill suggestion', three.length === 1 && three[0].name === 'learned-investigate-then-debugger'
    && three[0].steps.map((s) => `${s.kind}:${s.id}`).join(',') === 'skill:$investigate,agent:debugger'
    && three[0].intents[0] === 'Debug' && three[0].evidence.length === 3, JSON.stringify(three));
  check('chain accepted in 2 sessions -> nothing', review.workflowCandidates(chainSessions(2), NOW).length === 0);
  check('sessions older than 30 days do not count', review.workflowCandidates([...chainSessions(2), ...chainSessions(1, 40).map((e) => Object.assign({}, e, { session: 'old' }))], NOW).length === 0);
  const broken = chainSessions(3).flatMap((e) => (e.id === 'debugger' ? [ev(e.session, 'executor', 'agent', 'reject', 1, 0.5), e] : [e]));
  check('a reject between the two breaks the chain', review.workflowCandidates(broken, NOW).length === 0);
  const longer = [];
  for (let i = 0; i < 3; i++) {
    longer.push(ev(`x${i}`, '$investigate', 'skill', 'accept', 1, 0), ev(`x${i}`, 'debugger', 'agent', 'accept', 1, 1), ev(`x${i}`, 'test-engineer', 'agent', 'accept', 1, 2));
  }
  const l = review.workflowCandidates(longer, NOW);
  check('sub-chains of a qualifying longer chain are dropped', l.length === 1 && l[0].steps.length === 3, JSON.stringify(l.map((c) => c.name)));
  check('my-claude ledger rows are not Codex workflows', review.workflowCandidates(chainSessions(3).map((e) => Object.assign({}, e, { harness: 'claude' })), NOW).length === 0);
  check('rows without a harness field are my-claude\'s', review.workflowCandidates(chainSessions(3).map((e) => { const { harness, ...rest } = e; return rest; }), NOW).length === 0); // eslint-disable-line no-unused-vars
  const learned = chainSessions(3).map((e) => (e.id === '$investigate' ? Object.assign({}, e, { id: '$learned-x' }) : e));
  check('a $learned-* skill never starts a new learned chain', review.workflowCandidates(learned, NOW).length === 0);
}

// ---------------------------------------------------------------- dedupe + cap + shared store

{
  const HOME = newHome();
  const rule = (text) => ({ kind: 'rule', text, context: null, scope: 'global', evidence: ['s'] });
  review.queueSuggestions(HOME, [rule("Don't use tables.")], NOW, 's1');
  review.queueSuggestions(HOME, [rule("don't use TABLES")], NOW, 's2');
  check('dedupe: same normalized text queued once', store.readSuggestions(HOME).length === 1);
  runCli(HOME, ['dismiss', 'L1']);
  review.queueSuggestions(HOME, [rule("Don't use tables!")], NOW, 's3');
  check('dismissed key is never re-queued', store.readSuggestions(HOME).length === 1 && store.readSuggestions(HOME)[0].status === 'dismissed');
  review.queueSuggestions(HOME, ['Always a', 'Always b', 'Always c', 'Always d', 'Always e', 'Always f', 'Always g'].map(rule), NOW, 's4');
  const pending = store.readSuggestions(HOME).filter((s) => s.status === 'pending');
  const refused = store.readAudit(HOME).filter((r) => r.action === 'cap_refused');
  check('cap: at most 5 pending', pending.length === 5, `${pending.length}`);
  check('cap: refusals audited as cap_refused', refused.length === 2 && refused.every((r) => r.key && r.reason && r.harness === 'codex'), JSON.stringify(refused));
  review.queueSuggestions(HOME, ['Always f', 'Always g'].map(rule), NOW, 's5');
  check('cap: a key refused before is not re-audited', store.readAudit(HOME).filter((r) => r.action === 'cap_refused').length === 2);
  check('every queued suggestion is audited', store.readAudit(HOME).filter((r) => r.action === 'suggest').length === 6);
}

{
  // Shared with my-claude: its rows (explicit "claude" or legacy without a
  // harness) are neither shown nor counted nor touched, and ids stay unique.
  const HOME = newHome();
  const p = store.learningPaths(HOME);
  const claudeRows = [
    { id: 'L1', kind: 'rule', status: 'pending', key: 'rule:always claude', text: 'Always claude', created_at: new Date(NOW).toISOString(), harness: 'claude', session: 'c' },
    { id: 'L2', kind: 'rule', status: 'pending', key: 'rule:always legacy', text: 'Always legacy', created_at: new Date(NOW).toISOString(), session: 'c' },
  ];
  store.writeAtomic(p.suggestions, claudeRows.map((r) => JSON.stringify(r) + '\n').join(''));
  const before = fs.readFileSync(p.suggestions, 'utf8');
  review.queueSuggestions(HOME, [{ kind: 'rule', text: 'Always claude', context: null, scope: 'global', evidence: [] }], NOW, 's');
  const rows = store.readSuggestions(HOME);
  check('shared store: my-claude rows kept byte for byte', fs.readFileSync(p.suggestions, 'utf8').startsWith(before));
  check('shared store: same text from Codex is its own suggestion with the next id', rows.length === 3 && rows[2].id === 'L3' && rows[2].harness === 'codex', JSON.stringify(rows.map((r) => r.id)));
  const list = runCli(HOME, ['list']).out;
  check('learn list shows only Codex rows', list.includes('L3') && !list.includes('L1 ') && !list.includes('L2 '), list);
  check('approving another harness\'s suggestion is refused', runCli(HOME, ['approve', 'L1']).code === 1);
}

// ---------------------------------------------------------------- approve rule + skill, AGENTS.md, registry

{
  const HOME = newHome();
  const PROJECT = path.join(ROOT, 'project');
  fs.mkdirSync(PROJECT, { recursive: true });
  const agentsMd = path.join(HOME, '.codex', 'AGENTS.md');
  const userAgents = '# my-codex\n\n## Default Agent\n<!-- my-codex:default-agent -->\n\nBoss.\n\n## My own notes\n\nKeep me.\n';
  store.writeAtomic(agentsMd, userAgents);
  fs.chmodSync(agentsMd, 0o640);
  review.queueSuggestions(HOME, [{ kind: 'rule', text: '표는 항상 한국어로 작성해줘, 영어 헤더 쓰지 마', context: { kind: 'agent', id: 'executor' }, scope: 'global', evidence: ['sess-a'] }], NOW, 'sess-a');
  const a = runCli(HOME, ['approve', 'L1', '--as', 'Write tables in Korean, with no English headers.']);
  const ruleFile = path.join(HOME, '.codex', 'learned-rules', 'learned-write-tables-in-korean-with-no-english.md');
  const ruleText = fs.existsSync(ruleFile) ? fs.readFileSync(ruleFile, 'utf8') : '';
  check('approve rule -> ~/.codex/learned-rules/learned-<slug>.md', a.code === 0 && ruleText !== '', a.out);
  const fm = reg.parseSkillFrontmatter(ruleText) || {};
  check('rule frontmatter: date, source, suggestion, evidence', /source: learning-loop/.test(ruleText) && /suggestion: L1/.test(ruleText) && /evidence: \["sess-a"\]/.test(ruleText) && /^date: \d{4}-\d{2}-\d{2}$/m.test(ruleText), JSON.stringify(fm));
  check('rule body: imperative English + original sentence quoted', ruleText.includes('- Write tables in Korean, with no English headers.') && ruleText.includes('> 표는 항상 한국어로 작성해줘, 영어 헤더 쓰지 마') && ruleText.includes('`executor`'));
  const md = fs.readFileSync(agentsMd, 'utf8');
  check('AGENTS.md: learned section appended with the marker', md.includes(`${store.AGENTS_HEADING}\n${store.AGENTS_MARKER}\n`) && md.includes('- Write tables in Korean, with no English headers. (`learned-write-tables-in-korean-with-no-english`)'), md);
  check('AGENTS.md: everything outside the section kept byte for byte', md.startsWith(userAgents.replace(/\n+$/, '')) && store.stripAgentsSection(md).replace(/\n+$/, '') === userAgents.replace(/\n+$/, ''));
  check('AGENTS.md: file mode kept', (fs.statSync(agentsMd).mode & 0o777) === 0o640, (fs.statSync(agentsMd).mode & 0o777).toString(8));
  check('approved suggestion marked approved', store.readSuggestions(HOME)[0].status === 'approved');
  const approveAudit = store.readAudit(HOME).find((r) => r.action === 'approve');
  check('approve audited with before/after paths', approveAudit && approveAudit.before.path === null && approveAudit.after.path === ruleFile && approveAudit.harness === 'codex');
  check('approving twice is refused', runCli(HOME, ['approve', 'L1']).code === 1);

  review.queueSuggestions(HOME, [{ kind: 'rule', text: '항상 존댓말로 답해줘', context: null, scope: 'global', evidence: ['s'] }], NOW, 's');
  runCli(HOME, ['approve', 'L2']);
  check('Korean-only rule without --as gets a stable slug', fs.existsSync(path.join(HOME, '.codex', 'learned-rules', 'learned-rule-l2.md')));
  check('AGENTS.md: a rule without --as is stated with the quoted sentence', fs.readFileSync(agentsMd, 'utf8').includes('Follow the user\'s instruction: "항상 존댓말로 답해줘" (`learned-rule-l2`)'));
  check('sync-agents is idempotent (no rewrite when nothing changed)', store.syncAgentsSection(HOME) === false);

  review.queueSuggestions(HOME, review.workflowCandidates(chainSessions(3), NOW), NOW, 's');
  const b = runCli(HOME, ['approve', 'L3']);
  const skillFile = path.join(HOME, '.codex', 'skills', 'learned-investigate-then-debugger', 'SKILL.md');
  const skillText = fs.existsSync(skillFile) ? fs.readFileSync(skillFile, 'utf8') : '';
  const sfm = reg.parseSkillFrontmatter(skillText) || {};
  check('approve skill -> ~/.codex/skills/learned-<slug>/SKILL.md', b.code === 0 && sfm.name === 'learned-investigate-then-debugger', b.out);
  check('skill description names the intent and its keywords', /Debug/.test(sfm.description) && /Use for .*debug/.test(sfm.description), sfm.description);
  check('skill body is an ordered Codex procedure', skillText.includes('1. Use the `$investigate` skill (mention `$investigate`)') && skillText.includes('2. Use the `debugger` agent (spawn_agent, agent_type `debugger`)') && skillText.includes('## Provenance'), skillText);
  // With the skill manager present, unmanaged skills are normally inactive;
  // learned-* stay active because Codex loads them.
  const managerDir = path.join(HOME, '.codex', 'my-codex');
  store.writeAtomic(path.join(managerDir, 'skill-catalog-state.json'), JSON.stringify({ profile: 'core' }));
  const registry = reg.buildRegistry({ home: HOME, cwd: PROJECT });
  const inReg = (registry.skills || []).find((s) => s.name === 'learned-investigate-then-debugger');
  check('registry picks the learned skill up, active, with its description', inReg && inReg.active === true && /^Learned Debug workflow/.test(inReg.description), JSON.stringify(inReg));
  const debug = ((registry.intents || {}).Debug || []).map((c) => c.name);
  check('registry ranks the learned skill under its intent', debug.includes('learned-investigate-then-debugger'), debug.join(','));

  const list = runCli(HOME, ['list']);
  check('learn list shows learned items', list.out.includes('learned-investigate-then-debugger') && list.out.includes('3/20 live'), list.out);
  check('learn show <id> prints the suggestion', JSON.parse(runCli(HOME, ['show', 'L3']).out).kind === 'skill');
}

// ---------------------------------------------------------------- cap 20

{
  const HOME = newHome();
  const state = { items: {}, last_curate_at: null };
  for (let i = 0; i < 20; i++) {
    const p = path.join(HOME, '.codex', 'learned-rules', `learned-r${i}.md`);
    store.writeAtomic(p, '# r\n\n- Rule r\n');
    state.items[`learned-r${i}`] = { slug: `learned-r${i}`, kind: 'rule', status: i % 2 ? 'stale' : 'active', path: p, approved_at: new Date(NOW).toISOString(), harness: 'codex' };
  }
  store.writeState(HOME, state);
  review.queueSuggestions(HOME, [{ kind: 'rule', text: 'Always one more', context: null, scope: 'global', evidence: [] }], NOW, 's');
  const r = runCli(HOME, ['approve', 'L1']);
  check('approve beyond 20 live items is refused', r.code === 1 && /curate/.test(r.out) && store.readSuggestions(HOME)[0].status === 'pending', r.out);
  check('cap-20 refusal audited', store.readAudit(HOME).some((a) => a.action === 'cap_refused' && a.suggestion === 'L1'));
  check('no file written on refusal', fs.readdirSync(path.join(HOME, '.codex', 'learned-rules')).length === 20);
}

// ---------------------------------------------------------------- curate + pin + rollback

{
  const HOME = newHome();
  const agentsMd = path.join(HOME, '.codex', 'AGENTS.md');
  const rule = (text) => ({ kind: 'rule', text, context: null, scope: 'global', evidence: [] });
  review.queueSuggestions(HOME, [rule('Always alpha'), rule('Always beta'), rule('Always gamma')], NOW, 's');
  runCli(HOME, ['approve', 'L1']);
  runCli(HOME, ['approve', 'L2']);
  runCli(HOME, ['approve', 'L3']);
  const slugs = Object.keys(store.readState(HOME).items).sort();
  check('three rules approved', slugs.join(',') === 'learned-always-alpha,learned-always-beta,learned-always-gamma', slugs.join(','));
  check('pin <slug>', runCli(HOME, ['pin', 'learned-always-gamma']).code === 0 && store.readState(HOME).items['learned-always-gamma'].pinned === true);

  const dry = runCli(HOME, ['curate', '--dry-run'], NOW + 31 * DAY);
  check('curate --dry-run reports but changes nothing', /Would change/.test(dry.out) && store.readState(HOME).items['learned-always-alpha'].status === 'active', dry.out);
  const beta = store.readState(HOME);
  store.writeState(HOME, Object.assign({}, beta, { items: Object.assign({}, beta.items, { 'learned-always-beta': Object.assign({}, beta.items['learned-always-beta'], { last_used_at: new Date(NOW + 20 * DAY).toISOString() }) }) }));
  runCli(HOME, ['curate'], NOW + 31 * DAY);
  let st = store.readState(HOME).items;
  check('curate: 31 days unused -> stale', st['learned-always-alpha'].status === 'stale');
  check('curate: recently used -> stays active', st['learned-always-beta'].status === 'active');
  check('curate: pinned -> exempt', st['learned-always-gamma'].status === 'active');
  check('curate: a stale rule stays in AGENTS.md', fs.readFileSync(agentsMd, 'utf8').includes('learned-always-alpha'));

  const alphaPath = st['learned-always-alpha'].path;
  runCli(HOME, ['curate'], NOW + 100 * DAY);
  st = store.readState(HOME).items;
  check('curate: 100 days unused -> archived (moved, not deleted)', st['learned-always-alpha'].status === 'archived' && !fs.existsSync(alphaPath)
    && fs.existsSync(st['learned-always-alpha'].archived_path) && st['learned-always-alpha'].archived_path.startsWith(store.learningPaths(HOME).archive));
  check('curate: archived rule leaves the AGENTS.md section', !fs.readFileSync(agentsMd, 'utf8').includes('learned-always-alpha') && fs.readFileSync(agentsMd, 'utf8').includes('learned-always-gamma'));
  check('curate: pinned still exempt at 100 days', st['learned-always-gamma'].status === 'active' && fs.existsSync(st['learned-always-gamma'].path));

  const archiveRow = store.readAudit(HOME).filter((r) => r.action === 'archive' && r.slug === 'learned-always-alpha').pop();
  const rb = runCli(HOME, ['rollback', archiveRow.id], NOW + 100 * DAY);
  st = store.readState(HOME).items;
  check('rollback archive -> file back in place, status restored, back in AGENTS.md', rb.code === 0 && fs.existsSync(alphaPath) && st['learned-always-alpha'].status === 'stale'
    && fs.readFileSync(agentsMd, 'utf8').includes('learned-always-alpha'), rb.out);
  check('rolling back the same mutation twice is refused', runCli(HOME, ['rollback', archiveRow.id]).code === 1);
  check('unknown audit id is refused', runCli(HOME, ['rollback', 'nope']).code === 1);

  const approveRow = store.readAudit(HOME).find((r) => r.action === 'approve' && r.suggestion === 'L2');
  const betaPath = approveRow.after.path;
  const blocked = runCli(HOME, ['rollback', approveRow.id]);
  const staleRow = store.readAudit(HOME).find((r) => r.action === 'stale' && r.slug === 'learned-always-beta');
  check('rollback is last-in-first-out per item: a later mutation must go first', blocked.code === 1 && blocked.out.includes(`roll back ${staleRow.id}`) && fs.existsSync(betaPath), blocked.out);
  check('rollback stale -> active', runCli(HOME, ['rollback', staleRow.id]).code === 0 && store.readState(HOME).items['learned-always-beta'].status === 'active');
  const rb2 = runCli(HOME, ['rollback', approveRow.id]);
  check('rollback approve -> file archived, suggestion pending again, gone from AGENTS.md', rb2.code === 0 && !fs.existsSync(betaPath)
    && !store.readState(HOME).items['learned-always-beta'] && store.readSuggestions(HOME).find((s) => s.id === 'L2').status === 'pending'
    && !fs.readFileSync(agentsMd, 'utf8').includes('learned-always-beta'), rb2.out);
  const archived = fs.readdirSync(store.learningPaths(HOME).archive, { recursive: true }).filter((f) => String(f).endsWith('learned-always-beta.md'));
  check('rolled-back approval kept in learned-archive/', archived.length === 1);

  const pinRow = store.readAudit(HOME).find((r) => r.action === 'pin');
  runCli(HOME, ['rollback', pinRow.id]);
  check('rollback pin -> unpinned', store.readState(HOME).items['learned-always-gamma'].pinned === false);

  review.queueSuggestions(HOME, [rule('Always delta')], NOW, 's');
  const dismissOut = runCli(HOME, ['dismiss', 'L4']).out;
  const dismissId = /audit (A\d+)/.exec(dismissOut)[1];
  runCli(HOME, ['rollback', dismissId]);
  check('rollback dismiss -> pending again', store.readSuggestions(HOME).find((s) => s.id === 'L4').status === 'pending');
  const suggestRow = store.readAudit(HOME).find((r) => r.action === 'suggest');
  check('a suggest row is not rollback-able (dismiss instead)', runCli(HOME, ['rollback', suggestRow.id]).code === 1);
  check('every rollback is itself audited', store.readAudit(HOME).filter((r) => r.action === 'rollback').length === 5);

  // Last rule gone -> the section goes too; the rest of AGENTS.md stays.
  for (const slug of Object.keys(store.readState(HOME).items)) {
    const row = store.readAudit(HOME).filter((r) => r.slug === slug && ['approve'].includes(r.action)).pop();
    const later = store.readAudit(HOME).filter((r) => r.slug === slug && r.action !== 'approve' && r.action !== 'rollback');
    for (const l of later.reverse()) runCli(HOME, ['rollback', l.id]);
    runCli(HOME, ['rollback', row.id]);
  }
  const md = fs.existsSync(agentsMd) ? fs.readFileSync(agentsMd, 'utf8') : '';
  check('no live rules -> no learned section left in AGENTS.md', !md.includes(store.AGENTS_MARKER), md);
}

{
  const HOME = newHome();
  const rule = (text) => ({ kind: 'rule', text, context: null, scope: 'global', evidence: [] });
  review.queueSuggestions(HOME, [rule('Always zeta')], NOW, 's');
  runCli(HOME, ['approve', 'L1']);
  runCli(HOME, ['curate'], NOW + 100 * DAY);
  review.queueSuggestions(HOME, [rule('Always zeta!!')], NOW, 's');
  check('an approved key stays deduped after its item is archived', !store.readSuggestions(HOME).find((s) => s.id === 'L2'));
  review.queueSuggestions(HOME, [rule('Always zeta, please')], NOW, 's');
  runCli(HOME, ['approve', 'L2', '--as', 'Always zeta']);
  const items = store.readState(HOME).items;
  check('slug held by an archived item is not reused', items['learned-always-zeta'].status === 'archived' && items['learned-always-zeta-2'] && items['learned-always-zeta-2'].status === 'active', Object.keys(items).join(','));
  const firstApprove = store.readAudit(HOME).find((r) => r.action === 'approve' && r.suggestion === 'L1');
  const r = runCli(HOME, ['rollback', firstApprove.id]);
  check('rolling back the old approval leaves the newer item alone', r.code === 1 && fs.existsSync(items['learned-always-zeta-2'].path) && store.readState(HOME).items['learned-always-zeta-2'].status === 'active', r.out);
}

// ---------------------------------------------------------------- SessionStart surfacing

{
  const HOME = newHome();
  const rule = (text) => ({ kind: 'rule', text, context: null, scope: 'global', evidence: [] });
  check('no pending -> session-start prints nothing', runCli(HOME, ['session-start']).out === '');
  review.queueSuggestions(HOME, [rule('Always one'), rule('Always two'), rule('Always three')], NOW, 's');
  const out = runCli(HOME, ['session-start']).out.trim().split('\n');
  check('session-start: at most 2 [Learn] lines', out.length === 2 && out.every((l) => l.startsWith('[Learn] L')), out.join(' | '));
  check('[Learn] line carries approve and dismiss commands', out[0].includes('~/.codex/bin/my-codex-learn approve L1') && out[0].includes('~/.codex/bin/my-codex-learn dismiss L1'));
  check('[Learn] line notes the rest', out[1].includes('+1 more'));
  const st = store.readState(HOME);
  check('session-start ran the weekly curate', !!st.last_curate_at);
  store.writeState(HOME, Object.assign({}, st, { last_curate_at: new Date(NOW - 3 * DAY).toISOString() }));
  runCli(HOME, ['session-start']);
  check('weekly curate skipped within 7 days', store.readState(HOME).last_curate_at === new Date(NOW - 3 * DAY).toISOString());

  // Through the real session-start.sh, with network installs stubbed; a
  // session marked at Stop is reviewed here and surfaces in the same output.
  const PROJECT = fs.mkdtempSync(path.join(ROOT, 'proj-'));
  const stubBin = fs.mkdtempSync(path.join(ROOT, 'bin-'));
  for (const tool of ['ast-grep']) fs.writeFileSync(path.join(stubBin, tool), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  fs.writeFileSync(path.join(stubBin, 'npm'), '#!/bin/sh\nexit 1\n', { mode: 0o755 });
  fs.mkdirSync(path.join(HOME, '.codex', 'skills', 'pdf'), { recursive: true });
  fs.mkdirSync(path.join(HOME, '.codex', 'skills', 'docx'), { recursive: true });
  fs.writeFileSync(path.join(HOME, '.codex', '.my-codex-update-check'), new Date().toISOString().slice(0, 10) + '\n');
  const HOME2 = newHome();
  for (const dir of ['.codex', '.config']) fs.cpSync(path.join(HOME, dir), path.join(HOME2, dir), { recursive: true });
  const env = Object.assign({}, process.env, { HOME: HOME2, USERPROFILE: HOME2, PATH: `${stubBin}${path.delimiter}${process.env.PATH}` });
  const rollout = writeRollout([started('t1'), userLine('Fix the build'), agentLine(), started('t2'), userLine('From now on run the tests before you commit.'), agentLine()]);
  cp.spawnSync('node', [REVIEW, 'mark'], { env, encoding: 'utf8', input: JSON.stringify({ session_id: 'prev', transcript_path: rollout }) });
  const r = cp.spawnSync('bash', [path.join(HOOKS, 'session-start.sh')], { cwd: PROJECT, env, encoding: 'utf8', input: '{}' });
  const lines = r.stdout.trim().split('\n').filter(Boolean);
  let ctx = '';
  let doc = null;
  try { doc = JSON.parse(r.stdout); ctx = doc.hookSpecificOutput.additionalContext; } catch { /* checked below */ }
  check('session-start.sh stays exactly one JSON document with hookEventName', lines.length === 1 && doc && doc.hookSpecificOutput.hookEventName === 'SessionStart' && ctx !== '', r.stdout.slice(0, 300));
  const learnLines = ctx.split('\n').filter((l) => l.startsWith('[Learn]'));
  check('session-start.sh injects <= 2 [Learn] lines, each on its own line', learnLines.length === 2, JSON.stringify(ctx.slice(-400)));
  check('session-start.sh reviewed the session marked at Stop', store.readSuggestions(HOME2).some((s) => s.text === 'From now on run the tests before you commit.' && s.session === 'prev'));
}

// ---------------------------------------------------------------- CLI entry + hook registration

{
  const HOME = newHome();
  const env = Object.assign({}, process.env, { HOME, USERPROFILE: HOME });
  const r = cp.spawnSync('bash', [BIN, 'list'], { cwd: ROOT, env, encoding: 'utf8' });
  check('bin/my-codex-learn list works', r.status === 0 && r.stdout.includes('No pending suggestions.'), r.stdout + r.stderr);
  const u = cp.spawnSync('bash', [BIN, 'bogus'], { cwd: ROOT, env, encoding: 'utf8' });
  check('unknown command -> usage, exit 1', u.status === 1 && u.stdout.includes('Usage: my-codex-learn'));
  const hooksJson = JSON.parse(fs.readFileSync(path.join(HOOKS, 'hooks.json'), 'utf8')).hooks;
  check('learning-review.js mark registered on Stop', (hooksJson.Stop || []).some((g) => g.hooks.some((h) => h.command === 'node "$HOME/.codex/hooks/learning-review.js" mark')));
  const installSh = fs.readFileSync(path.join(REPO_ROOT, 'install.sh'), 'utf8');
  check('install.sh copies and manifests the learning hooks and the CLI', ['learning-store.js', 'learning-review.js', 'learning-cli.js'].every((f) => new RegExp(`for _loop_hook in [^\\n]*${f}`).test(installSh))
    && installSh.includes('cp "$REPO_ROOT/bin/my-codex-learn" "$CODEX_ROOT/bin/my-codex-learn"') && installSh.includes('add_manifest_entry "bin/my-codex-learn"'));
}

check('nothing was written to the real home', !fs.existsSync(path.join(os.homedir(), '.config', 'agent-harness', 'learning-audit.jsonl'))
  || fs.statSync(path.join(os.homedir(), '.config', 'agent-harness', 'learning-audit.jsonl')).mtimeMs < NOW - 1000);

fs.rmSync(ROOT, { recursive: true, force: true });

const failed = results.filter((ok) => !ok).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
