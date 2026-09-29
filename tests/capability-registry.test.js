#!/usr/bin/env node
// Capability registry v2 + route hints.
//
// Builds the registry against a synthetic $HOME (never the real ~/.codex)
// and checks scopes, inactive pack/plugin marking, ranking, staleness, the
// SessionStart summary, and route-hint.js classification on EN + KO prompts.
//
// `node tests/capability-registry.test.js`
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const HOOKS = path.join(REPO_ROOT, 'hooks');
const registryLib = require(path.join(HOOKS, 'build-registry.js'));
const routeHint = require(path.join(HOOKS, 'route-hint.js'));
const routingMap = JSON.parse(fs.readFileSync(path.join(HOOKS, 'routing-map.json'), 'utf8'));

const results = [];
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  (' + detail + ')' : ''}`);
  results.push(ok);
  return ok;
}

function write(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

function agentToml(name, description, model) {
  return `name = "${name}"\ndescription = "${description}"\nmodel = "${model || 'gpt-5.6-sol'}"\n` +
    'developer_instructions = """\nname = "not-top-level"\n"""\n\n[mcp_servers.x]\nname = "nested"\n';
}

function skillMd(name, description) {
  return `---\nname: ${name}\ndescription: ${description}\n---\n\n# ${name}\n`;
}

// ---------------------------------------------------------------- fixture

const FAKE_HOME = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-registry-home-'));
const PROJECT = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-registry-proj-'));
const CODEX = path.join(FAKE_HOME, '.codex');
const REGISTRY = path.join(CODEX, 'capability-registry.json');

for (const [name, desc] of [
  ['oracle', 'Architecture decisions and stuck bugs; read-only second opinion.'],
  ['metis', 'Classifies intent and surfaces ambiguities before planning.'],
  ['momus', 'Reviews a finished work plan for blocking issues.'],
  ['architect', 'Strategic architecture advisor.'],
  ['executor', 'Implementation executor.'],
  ['ai-engineer', 'AI engineer (enabled pack copy).']
]) write(path.join(CODEX, 'agents', `${name}.toml`), agentToml(name, desc));
write(path.join(CODEX, 'agent-packs', 'data-ai', 'ai-engineer.toml'), agentToml('ai-engineer', 'AI engineer.'));
write(path.join(CODEX, 'agent-packs', 'data-ai', 'postgres-pro.toml'),
  agentToml('postgres-pro', 'Postgres schema design and distributed database architecture tradeoffs.'));

write(path.join(CODEX, 'skills', 'brainstorming', 'SKILL.md'), skillMd('brainstorming', 'Explore intent before building.'));
write(path.join(CODEX, 'skills', 'cso', 'SKILL.md'), skillMd('cso', 'Security audit.'));
// A third-party skill my-codex never installed: it must still be discovered and ranked.
write(path.join(CODEX, 'skills', 'grpc-designer', 'SKILL.md'),
  '---\nname: grpc-designer\ndescription: >\n  System design helper for gRPC service architecture\n  and API tradeoff analysis.\n---\n');
write(path.join(CODEX, 'skills', '.system', 'imagegen', 'SKILL.md'), skillMd('imagegen', 'System skill.'));
// PlanReview: an inactive map member vs. an active skill found by description.
write(path.join(CODEX, 'skills', 'plan-eng-review', 'SKILL.md'), skillMd('plan-eng-review', 'Eng plan review (lane not enabled).'));
write(path.join(CODEX, 'skills', 'rollout-checker', 'SKILL.md'),
  skillMd('rollout-checker', 'Checks a rollout work plan for blocking issues.'));
// Folder name differs from the frontmatter name.
write(path.join(CODEX, 'skills', 'vendor-pubmed-database', 'SKILL.md'), skillMd('pubmed-database', 'PubMed lookups.'));
write(path.join(CODEX, 'agents', 'long-desc.toml'),
  'name = "long-desc"\ndescription = """\nMulti-line agent\ndescription."""\nmodel = "gpt-5.6-sol"\n');
// A skill manager that reports skills by folder name.
write(path.join(CODEX, 'bin', 'my-codex-skills'),
  "#!/bin/sh\nprintf '%s\\n' '{\"activeSkillNames\":[\"brainstorming\",\"cso\",\"grpc-designer\",\"vendor-pubmed-database\",\"outside-skill\",\"rollout-checker\"],\"laneIndex\":{}}'\n");
fs.chmodSync(path.join(CODEX, 'bin', 'my-codex-skills'), 0o755);

write(path.join(CODEX, 'plugins', 'cache', 'mk', 'plug', '1.0.0', 'skills', 'do-thing', 'SKILL.md'),
  skillMd('do-thing', 'Plugin skill.'));
write(path.join(CODEX, 'plugins', 'cache', 'mk', 'off', '0.1.0', 'skills', 'idle', 'SKILL.md'),
  skillMd('idle', 'Disabled plugin skill.'));
write(path.join(CODEX, 'config.toml'), '[plugins."plug@mk"]\nenabled = true\n\n[plugins."off@mk"]\nenabled = false\n');

write(path.join(PROJECT, '.codex', 'agents', 'local-arch.toml'), agentToml('local-arch', 'Project architecture helper.'));
write(path.join(PROJECT, '.codex', 'skills', 'proj-skill', 'SKILL.md'), skillMd('proj-skill', 'Project-only skill.'));

// ---------------------------------------------------------------- registry

const started = Date.now();
const first = registryLib.ensureRegistry({ home: FAKE_HOME, cwd: PROJECT, file: REGISTRY });
const buildMs = Date.now() - started;
check('build -> regenerated', first.status === 'regenerated', first.status);
check(`build -> under 1 s (${buildMs} ms)`, buildMs < 1000);
const reg = JSON.parse(fs.readFileSync(REGISTRY, 'utf8'));
check('registry -> version 2', reg.version === 2);

const agent = (n) => reg.agents.find((a) => a.name === n);
const skill = (n) => reg.skills.find((s) => s.name === n);
check('agents -> global scope active', agent('oracle') && agent('oracle').scope === 'global' && agent('oracle').active);
check('agents -> TOML fields parsed from top level only',
  agent('oracle').description.startsWith('Architecture decisions') && agent('oracle').model === 'gpt-5.6-sol');
check('agents -> project scope', agent('local-arch') && agent('local-arch').scope === 'project');
check('agents -> pack-only agent marked inactive',
  agent('postgres-pro') && agent('postgres-pro').scope === 'pack:data-ai' && agent('postgres-pro').active === false);
check('agents -> enabled pack agent is the active global copy, listed once',
  reg.agents.filter((a) => a.name === 'ai-engineer').length === 1 && agent('ai-engineer').scope === 'global');
check('skills -> global scope', skill('cso') && skill('cso').scope === 'global' && skill('cso').active);
check('skills -> folded description parsed',
  skill('grpc-designer') && skill('grpc-designer').description === 'System design helper for gRPC service architecture and API tradeoff analysis.');
check('skills -> project scope', skill('proj-skill') && skill('proj-skill').scope === 'project');
check('skills -> .system excluded', !skill('imagegen'));
check('skills -> folder/frontmatter name mismatch listed once and active',
  reg.skills.filter((s) => /pubmed/.test(s.name)).length === 1 && skill('pubmed-database').active);
check('skills -> manager-active skill outside ~/.codex/skills listed', skill('outside-skill') && skill('outside-skill').active);
check('agents -> multi-line TOML description parsed', agent('long-desc') && agent('long-desc').description === 'Multi-line agent description.');
check('skills -> enabled plugin skill active', skill('plug:do-thing') && skill('plug:do-thing').active && skill('plug:do-thing').scope === 'plugin:plug');
check('skills -> disabled plugin skill inactive', skill('off:idle') && skill('off:idle').active === false);

const arch = reg.intents.Architecture || [];
check('ranking -> Architecture led by oracle [advisor]', arch[0] && arch[0].name === 'oracle' && arch[0].advisor === true,
  JSON.stringify(arch.slice(0, 3)));
check('ranking -> missing map members are skipped', !arch.some((p) => p.name === 'hexagonal-architecture'));
check('ranking -> unmanaged skill discovered by description', arch.some((p) => p.name === 'grpc-designer'));
const pg = arch.find((p) => p.name === 'postgres-pro');
const grpc = arch.find((p) => p.name === 'grpc-designer');
check('ranking -> inactive pack agent ranks below active candidates', pg && grpc && arch.indexOf(pg) > arch.indexOf(grpc),
  arch.map((p) => p.name).join(','));
check('ranking -> every active candidate precedes every inactive one',
  Object.values(reg.intents).every((list) => list.findIndex((p) => !p.active) === -1 ||
    list.slice(list.findIndex((p) => !p.active)).every((p) => !p.active)));
const planReview = reg.intents.PlanReview.map((p) => `${p.name}:${p.active}`);
check('ranking -> active discovered skill outranks inactive map member',
  JSON.stringify(planReview.slice(0, 3)) === JSON.stringify(['momus:true', 'rollout-checker:true', 'plan-eng-review:false']),
  JSON.stringify(planReview));
check('ranking -> inactive candidates stay in the registry', reg.intents.PlanReview.some((p) => p.name === 'plan-eng-review' && !p.active));
check('ranking -> Ambiguity led by metis [advisor]', reg.intents.Ambiguity[0].name === 'metis' && reg.intents.Ambiguity[0].advisor);
check('ranking -> PlanReview led by momus [advisor]', reg.intents.PlanReview[0].name === 'momus' && reg.intents.PlanReview[0].advisor);
check('adoptionWeight -> stub returns 0', registryLib.adoptionWeight({ name: 'x' }) === 0);

const second = registryLib.ensureRegistry({ home: FAKE_HOME, cwd: PROJECT, file: REGISTRY });
check('staleness -> unchanged inputs stay up-to-date', second.status === 'up-to-date', second.status);
write(path.join(CODEX, 'skills', 'new-skill', 'SKILL.md'), skillMd('new-skill', 'Added later.'));
const future = new Date(Date.now() + 5000);
fs.utimesSync(path.join(CODEX, 'skills'), future, future);
const third = registryLib.ensureRegistry({ home: FAKE_HOME, cwd: PROJECT, file: REGISTRY });
check('staleness -> new skill triggers rebuild', third.status === 'regenerated' && third.registry.skills.some((s) => s.name === 'new-skill'));
check('skills -> physical skill the manager does not report is inactive',
  third.registry.skills.find((s) => s.name === 'new-skill').active === false);
write(path.join(CODEX, 'plugins', 'cache', 'mk', 'plug', '2.0.0', 'skills', 'do-more', 'SKILL.md'), skillMd('do-more', 'New plugin version.'));
const pluginTime = new Date(Date.now() + 10000);
fs.utimesSync(path.join(CODEX, 'plugins', 'cache', 'mk', 'plug', '2.0.0'), pluginTime, pluginTime);
const pluginUpdate = registryLib.ensureRegistry({ home: FAKE_HOME, cwd: PROJECT, file: REGISTRY });
check('staleness -> new plugin version triggers rebuild', pluginUpdate.status === 'regenerated' &&
  pluginUpdate.registry.skills.some((s) => s.name === 'plug:do-more'), pluginUpdate.status);
const otherProject = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-registry-proj2-'));
const fourth = registryLib.ensureRegistry({ home: FAKE_HOME, cwd: otherProject, file: REGISTRY });
check('staleness -> different project triggers rebuild', fourth.status === 'regenerated' && !fourth.registry.agents.some((a) => a.name === 'local-arch'));
{
  // A session started in $HOME must not relabel ~/.codex as a project scope.
  const fromHome = registryLib.buildRegistry({ home: FAKE_HOME, cwd: FAKE_HOME });
  check('scopes -> cwd == $HOME keeps global scope',
    fromHome.agents.find((a) => a.name === 'oracle').scope === 'global' && !fromHome.agents.some((a) => a.scope === 'project'));
}
registryLib.ensureRegistry({ home: FAKE_HOME, cwd: PROJECT, file: REGISTRY });

const summary = registryLib.renderSummary(JSON.parse(fs.readFileSync(REGISTRY, 'utf8')), REGISTRY);
check(`summary -> within ${registryLib.SUMMARY_CHAR_LIMIT} chars (${summary.length})`, summary.length <= registryLib.SUMMARY_CHAR_LIMIT);
check('summary -> names the registry path', summary.includes(REGISTRY));
check('summary -> marks advisors', summary.includes('Architecture: oracle[advisor]'));

// ---------------------------------------------------------------- route hints

const cachedRegistry = JSON.parse(fs.readFileSync(REGISTRY, 'utf8'));
const hint = (prompt, extra) => routeHint.hintFor(Object.assign({ prompt }, extra || {}), { map: routingMap, registry: cachedRegistry });
const cases = [
  ['Should we move from REST to gRPC for 12 internal services?', 'Architecture', 'oracle[advisor]'],
  ['gRPC로 전환할까? 아키텍처 관점에서 봐줘', 'Architecture', 'oracle[advisor]'],
  ['앱 좀 더 좋게', 'Ambiguity', 'metis[advisor]'],
  ['Make the app better somehow', 'Ambiguity', 'metis[advisor]'],
  ['Review this migration plan before we cut over', 'PlanReview', 'momus[advisor]'],
  ['마이그레이션 계획 검토해줘', 'PlanReview', 'momus[advisor]']
];
for (const [prompt, intent, lead] of cases) {
  const out = hint(prompt);
  check(`route-hint "${prompt}" -> ${intent} / ${lead}`,
    Boolean(out) && out.startsWith(`[RouteHint] intent=${intent} → ${lead}`) &&
      out.endsWith('Consult the Advisor Group when the intent calls for it.'),
    JSON.stringify(out));
}
const typo = hint('Fix the typo in the README');
check('route-hint typo in README -> Trivial / executor, no advisor sentence',
  typo === '[RouteHint] intent=Trivial → executor.', JSON.stringify(typo));
for (const prompt of ['README 오타 수정해줘', '이 함수 이름 변경해줘', 'one-line change: bump the version']) {
  check(`route-hint "${prompt}" -> Trivial`, routeHint.classify(prompt, routingMap) === 'Trivial');
}
check('route-hint real documentation work still -> Document',
  routeHint.classify('Update the README and the changelog for the release', routingMap) === 'Document');
check('route-hint -> inactive pick shown only when fewer than 3 active exist',
  hint('Please review this migration plan') === '[RouteHint] intent=PlanReview → momus[advisor], $rollout-checker, ' +
    '$plan-eng-review (inactive global). Consult the Advisor Group when the intent calls for it.',
  JSON.stringify(hint('Please review this migration plan')));
{
  const archHint = hint('Should we move from REST to gRPC?');
  check('route-hint -> no inactive pick while 3 active candidates exist', archHint && !archHint.includes('inactive'), JSON.stringify(archHint));
}
check('route-hint -> skills shown by their $ invocation, agents bare',
  (hint('Run a security audit on the auth flow') || '').startsWith('[RouteHint] intent=Security → $cso'),
  JSON.stringify(hint('Run a security audit on the auth flow')));
check('route-hint slash command -> nothing', hint('/review the plan') === null);
check('route-hint $skill mention -> nothing', hint('$review this pr') === null);
check('route-hint subagent prompt -> nothing', hint('Should we move to gRPC?', { agent_id: 'a1' }) === null);
check('route-hint unmatched -> nothing', hint('hello there') === null);
check('route-hint short keyword needs a whole word', routeHint.classify('trip to qatar', routingMap) === null);
{
  const foreign = Object.assign({}, cachedRegistry, {
    project_root: '/some/other/project',
    intents: { Architecture: [{ name: 'local-arch', kind: 'agent', advisor: false, scope: 'project', active: true },
      { name: 'oracle', kind: 'agent', advisor: true, scope: 'global', active: true }] }
  });
  const out = routeHint.hintFor({ prompt: 'Should we move to gRPC?', cwd: PROJECT }, { map: routingMap, registry: foreign });
  check('route-hint -> drops another project\'s project-scoped picks', out.includes('oracle[advisor]') && !out.includes('local-arch'), out);
}
check('route-hint "rest" needs a word start', routeHint.classify('what is the interest rate', routingMap) === null);
check('route-hint without registry -> falls back to map members',
  routeHint.hintFor({ prompt: 'Should we move to gRPC?' }, { map: routingMap, registry: null })
    .includes('oracle[advisor], architect, $hexagonal-architecture'));

function runHook(input) {
  const t = Date.now();
  const r = cp.spawnSync('node', [path.join(HOOKS, 'route-hint.js')], {
    input, encoding: 'utf8', env: Object.assign({}, process.env, { HOME: FAKE_HOME, USERPROFILE: FAKE_HOME })
  });
  return { r, ms: Date.now() - t };
}
{
  const { r, ms } = runHook(JSON.stringify({ hook_event_name: 'UserPromptSubmit', prompt: 'Should we move from REST to gRPC?' }));
  const lines = r.stdout.trim().split('\n');
  let doc = null;
  try { doc = JSON.parse(r.stdout); } catch { /* asserted below */ }
  check(`route-hint.js process -> one JSON doc with hookEventName (${ms} ms)`,
    r.status === 0 && lines.length === 1 && doc && doc.hookSpecificOutput.hookEventName === 'UserPromptSubmit' &&
      Object.keys(doc).join() === 'hookSpecificOutput' &&
      Object.keys(doc.hookSpecificOutput).sort().join() === 'additionalContext,hookEventName',
    JSON.stringify(r.stdout));
  check('route-hint.js process -> reads the ranked registry',
    doc && doc.hookSpecificOutput.additionalContext.includes('oracle[advisor]'));
}
for (const bad of ['', 'not json', '{"prompt": 42}']) {
  const { r } = runHook(bad);
  check(`route-hint.js process -> silent exit 0 on ${JSON.stringify(bad)}`, r.status === 0 && r.stdout === '' && r.stderr === '',
    JSON.stringify(r.stdout + r.stderr));
}

// ---------------------------------------------------------------- routing map

function sourceNames(script, vars) {
  const out = cp.execFileSync('bash', ['-c', `source "$1"; echo ${vars.map((v) => '$' + v).join(' ')}`, 'x', script], { encoding: 'utf8' });
  return out.split(/\s+/).filter(Boolean);
}
const knownAgents = new Set(sourceNames(path.join(REPO_ROOT, 'scripts', 'skill-allowlists.sh'), ['OMX_AGENT_ALLOWLIST']));
for (const dir of ['core', 'omo']) {
  for (const f of fs.readdirSync(path.join(REPO_ROOT, 'codex-agents', dir))) {
    if (f.endsWith('.toml')) knownAgents.add(f.replace(/\.toml$/, ''));
  }
}
const knownSkills = new Set(sourceNames(path.join(REPO_ROOT, 'scripts', 'skill-allowlists.sh'),
  ['ECC_SKILL_ALLOWLIST', 'ECC_SKILL_OPTIONAL_WEB', 'GSTACK_SKILL_ALLOWLIST', 'ARCHIFY_SKILL_NAME']));
for (const f of fs.readdirSync(path.join(REPO_ROOT, 'skills', 'core'))) knownSkills.add(f);
const superpowers = path.join(REPO_ROOT, 'upstream', 'superpowers', 'skills');
const haveSuperpowers = fs.existsSync(superpowers);
if (haveSuperpowers) for (const f of fs.readdirSync(superpowers)) knownSkills.add(f);
const SUPERPOWERS_MEMBERS = new Set(['brainstorming', 'systematic-debugging', 'test-driven-development',
  'requesting-code-review', 'executing-plans']);
for (const [intent, def] of Object.entries(routingMap.intents)) {
  for (const m of def.members) {
    const known = m.kind === 'agent' ? knownAgents.has(m.name)
      : knownSkills.has(m.name) || (!haveSuperpowers && SUPERPOWERS_MEMBERS.has(m.name));
    check(`routing-map ${intent} member ${m.kind}:${m.name} ships with my-codex`, known);
  }
}
const advisors = Object.entries(routingMap.intents)
  .flatMap(([intent, def]) => def.members.filter((m) => m.advisor).map((m) => `${intent}:${m.name}`)).sort();
check('routing-map -> advisors are oracle/metis/momus on their intents',
  JSON.stringify(advisors) === JSON.stringify(['Ambiguity:metis', 'Architecture:oracle', 'PlanReview:momus']),
  JSON.stringify(advisors));

fs.rmSync(FAKE_HOME, { recursive: true, force: true });
fs.rmSync(PROJECT, { recursive: true, force: true });
fs.rmSync(otherProject, { recursive: true, force: true });

const failed = results.filter((ok) => !ok).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
