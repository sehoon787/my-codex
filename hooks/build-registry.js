#!/usr/bin/env node
// Capability registry v2 for Codex.
//
// Discovers every agent and skill visible to this machine -- including ones
// my-codex did not install -- and ranks them per routing intent so Boss can
// route without rescanning the filesystem.
//
// Sources:
//   agents  ~/.codex/agents/*.toml            scope "global", active
//           ~/.codex/agent-packs/<p>/*.toml   scope "pack:<p>", inactive unless
//                                             the same name is also in agents/
//           ./.codex/agents/*.toml            scope "project", active
//   skills  ~/.codex/skills/*/SKILL.md        scope "global" (.system excluded)
//           ./.codex/skills/*/SKILL.md        scope "project"
//           ~/.codex/plugins/cache/<market>/<plugin>/<ver>/skills/*/SKILL.md
//                                             scope "plugin:<plugin>", active
//                                             when config.toml enables it
//   When the my-codex skill manager is installed, its activeSkillNames decide
//   which global skills are active.
//
// Adoption (adoption-store.js, shared with my-claude under
// ~/.config/agent-harness/) reorders candidates within their band: see
// rankIntents. The ledger and pins are fingerprint inputs, and a registry
// built while the ledger has events is rebuilt after a day so decay applies.
//
// The registry is written to ~/.codex/capability-registry.json (REGISTRY_OUT
// overrides). ~/.omc/state/capability-registry.json belongs to my-claude and
// is never touched here.
//
// CLI:
//   node build-registry.js                 rebuild if stale, print the path
//   node build-registry.js --session-start rebuild if stale, print the
//                                          SessionStart context line
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const cp = require('child_process');
const adoptionStore = require('./adoption-store');

const REGISTRY_VERSION = 2;
const DESCRIPTION_CAP = 200;
const RANKED_PER_INTENT = 8;
// Inactive candidates rank after every active one; a few are kept so Boss
// can still suggest enabling them.
const RANKED_INACTIVE_PER_INTENT = 4;
const SUMMARY_TOP = 3;
const SUMMARY_CHAR_LIMIT = 6000;
const MANAGER_TIMEOUT_MS = 10000;
const ROUTING_MAP_FILE = path.join(__dirname, 'routing-map.json');

// Map order dominates: each position below the first costs one step.
const MEMBER_BASE_SCORE = 60;
const MEMBER_STEP = 10;
// Items outside the map can still surface when their description matches.
const DISCOVERED_PER_MATCH = 15;
const DISCOVERED_MAX = 45;
const SCOPE_WEIGHT = { project: 3, global: 2, plugin: 1, pack: 0 };
// Full adoption (every result accepted) is worth two member slots, full
// rejection minus two. Bands keep it from ever crossing member/discovered lines.
const ADOPTION_SCALE = 4 * MEMBER_STEP;
const BAND = { pinned: 3, member: 2, discovered: 1 };
// Adoption decays with age, so a registry built from a non-empty ledger goes
// stale after a day even when no input file changed.
const ADOPTION_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const NO_ADOPTION = { stats: new Map(), pins: [] };

function codexHome(home) {
  return path.join(home, '.codex');
}

// Project-local .codex/ dirs; none when the session runs from $HOME itself,
// where .codex/ is the global tree.
function projectCodexDir(home, cwd) {
  const dir = path.join(cwd, '.codex');
  const real = (p) => { try { return fs.realpathSync(p); } catch { return path.resolve(p); } };
  return real(dir) === real(codexHome(home)) ? null : dir;
}

function defaultRegistryPath(home) {
  return process.env.REGISTRY_OUT || path.join(codexHome(home), 'capability-registry.json');
}

function safeReaddir(dir) {
  try {
    return fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }
}

function safeRead(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return null;
  }
}

function cap(text) {
  const clean = String(text || '').replace(/\s+/g, ' ').trim();
  return clean.length > DESCRIPTION_CAP ? clean.slice(0, DESCRIPTION_CAP - 1) + '…' : clean;
}

// ---------------------------------------------------------------- parsing

function unescapeTomlBasic(value) {
  return value.replace(/\\(["\\nt])/g, (_, ch) => ({ n: '\n', t: '\t' }[ch] || ch));
}

// Only top-level string keys are needed; anything after the first [table]
// header belongs to a nested table.
function parseAgentToml(text) {
  const out = {};
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*\[/.test(line)) break;
    const multi = line.match(/^\s*(name|description|model)\s*=\s*("""|\'\'\')(.*)$/);
    if (multi) {
      // Multi-line string: collect until the closing delimiter.
      const [, key, delim] = multi;
      const parts = [multi[3]];
      while (!parts[parts.length - 1].includes(delim) && i + 1 < lines.length) parts.push(lines[++i]);
      const body = parts.join('\n');
      const value = body.slice(0, body.includes(delim) ? body.indexOf(delim) : body.length);
      if (!(key in out)) out[key] = delim === '"""' ? unescapeTomlBasic(value) : value;
      continue;
    }
    const m = line.match(/^\s*(name|description|model)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|'([^']*)')/);
    if (m && !(m[1] in out)) out[m[1]] = m[2] !== undefined ? unescapeTomlBasic(m[2]) : m[3];
  }
  return out;
}

function stripQuotes(value) {
  const v = value.trim();
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) return v.slice(1, -1);
  return v;
}

function parseSkillFrontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return {};
  const lines = m[1].split(/\r?\n/);
  const out = {};
  for (let i = 0; i < lines.length; i++) {
    const kv = lines[i].match(/^(name|description):\s*(.*)$/);
    if (!kv || kv[1] in out) continue;
    let value = kv[2];
    if (value === '' || /^[>|][-+]?$/.test(value.trim())) {
      const block = [];
      while (i + 1 < lines.length && /^\s+\S/.test(lines[i + 1])) block.push(lines[++i].trim());
      value = block.join(' ');
    }
    out[kv[1]] = stripQuotes(value);
  }
  return out;
}

// ---------------------------------------------------------------- discovery

function tomlFiles(dir) {
  return safeReaddir(dir)
    .filter((e) => (e.isFile() || e.isSymbolicLink()) && e.name.endsWith('.toml'))
    .map((e) => path.join(dir, e.name))
    .sort();
}

function readAgent(file, scope, active) {
  const text = safeRead(file);
  if (text === null) return null;
  const meta = parseAgentToml(text);
  return {
    name: meta.name || path.basename(file, '.toml'),
    description: cap(meta.description),
    model: meta.model || '',
    scope,
    active,
    path: file
  };
}

function discoverAgents(home, cwd) {
  const byName = new Map();
  const add = (agent) => {
    if (agent && !byName.has(agent.name)) byName.set(agent.name, agent);
  };
  const projectDir = projectCodexDir(home, cwd);
  if (projectDir) for (const f of tomlFiles(path.join(projectDir, 'agents'))) add(readAgent(f, 'project', true));
  for (const f of tomlFiles(path.join(codexHome(home), 'agents'))) add(readAgent(f, 'global', true));
  const packsDir = path.join(codexHome(home), 'agent-packs');
  for (const pack of safeReaddir(packsDir).filter((e) => e.isDirectory()).map((e) => e.name).sort()) {
    for (const f of tomlFiles(path.join(packsDir, pack))) add(readAgent(f, `pack:${pack}`, false));
  }
  return [...byName.values()];
}

function skillDirs(root) {
  return safeReaddir(root)
    .filter((e) => (e.isDirectory() || e.isSymbolicLink()) && !e.name.startsWith('.'))
    .map((e) => path.join(root, e.name, 'SKILL.md'))
    .filter((f) => fs.existsSync(f))
    .sort();
}

function readSkill(file, scope, active, namePrefix) {
  const text = safeRead(file);
  if (text === null) return null;
  const meta = parseSkillFrontmatter(text);
  const base = meta.name || path.basename(path.dirname(file));
  return {
    name: namePrefix ? `${namePrefix}:${base}` : base,
    description: cap(meta.description),
    scope,
    active,
    path: file
  };
}

function enabledPlugins(configText) {
  const enabled = new Set();
  let current = null;
  for (const line of (configText || '').split(/\r?\n/)) {
    const header = line.match(/^\s*\[\s*plugins\s*\.\s*"([^"]+)"\s*\]/);
    if (header) {
      current = header[1];
      continue;
    }
    if (/^\s*\[/.test(line)) {
      current = null;
      continue;
    }
    if (current && /^\s*enabled\s*=\s*true\b/.test(line)) enabled.add(current);
  }
  return enabled;
}

// Newest version directory per plugin wins; a marketplace may keep several.
function discoverPluginSkills(home, configText) {
  const enabled = enabledPlugins(configText);
  const cacheDir = path.join(codexHome(home), 'plugins', 'cache');
  const skills = [];
  for (const market of safeReaddir(cacheDir).filter((e) => e.isDirectory())) {
    const marketDir = path.join(cacheDir, market.name);
    for (const plugin of safeReaddir(marketDir).filter((e) => e.isDirectory() && !e.name.startsWith('.'))) {
      const pluginDir = path.join(marketDir, plugin.name);
      const versions = safeReaddir(pluginDir)
        .filter((e) => e.isDirectory() && !e.name.startsWith('.'))
        .map((e) => {
          const dir = path.join(pluginDir, e.name);
          let mtime = 0;
          try { mtime = fs.statSync(dir).mtimeMs; } catch { /* unreadable version dir */ }
          return { dir, mtime };
        })
        .sort((a, b) => b.mtime - a.mtime);
      if (!versions.length) continue;
      const active = enabled.has(`${plugin.name}@${market.name}`);
      for (const f of skillDirs(path.join(versions[0].dir, 'skills'))) {
        const skill = readSkill(f, `plugin:${plugin.name}`, active, plugin.name);
        if (skill) skills.push(skill);
      }
    }
  }
  return skills;
}

function effectiveConfigPath(home) {
  const base = path.join(codexHome(home), 'config.toml');
  const alt = process.env.CODEX_HOME;
  if (!alt) return base;
  try {
    // An overlay CODEX_HOME that shares the canonical skills tree owns the
    // config that decides which of those skills are active.
    const baseSkills = fs.realpathSync(path.join(codexHome(home), 'skills'));
    const altSkills = fs.realpathSync(path.join(alt, 'skills'));
    if (baseSkills === altSkills) return path.join(alt, 'config.toml');
  } catch { /* no shared skills tree */ }
  return base;
}

// Returns { present, ok, activeNames, lanes, diagnostic }.
function readSkillManager(home) {
  const manager = path.join(codexHome(home), 'bin', 'my-codex-skills');
  try {
    fs.accessSync(manager, fs.constants.X_OK);
  } catch {
    return { present: false, ok: true };
  }
  const run = cp.spawnSync(manager, ['status', '--json'], { encoding: 'utf8', timeout: MANAGER_TIMEOUT_MS });
  if (run.status !== 0) {
    const detail = (run.stderr || run.stdout || (run.error && run.error.message) || '').trim();
    return { present: true, ok: false, diagnostic: `[SessionStart] Skill manager status failed (exit ${run.status}): ${detail}` };
  }
  try {
    const j = JSON.parse(run.stdout);
    if (!Array.isArray(j.activeSkillNames) || !j.laneIndex || typeof j.laneIndex !== 'object' || Array.isArray(j.laneIndex)) {
      throw new Error('shape');
    }
    return { present: true, ok: true, activeNames: new Set(j.activeSkillNames), lanes: j.laneIndex };
  } catch {
    return { present: true, ok: false, diagnostic: `[SessionStart] Skill manager returned invalid JSON: ${(run.stdout || '').trim()}` };
  }
}

function discoverSkills(home, cwd, manager, configText) {
  const byName = new Map();
  const add = (skill) => {
    if (skill && !byName.has(skill.name)) byName.set(skill.name, skill);
  };
  const projectDir = projectCodexDir(home, cwd);
  if (projectDir) for (const f of skillDirs(path.join(projectDir, 'skills'))) add(readSkill(f, 'project', true));
  // A skill folder may differ from its frontmatter name; the manager can report either.
  const seen = new Set(byName.keys());
  for (const f of skillDirs(path.join(codexHome(home), 'skills'))) {
    const folder = path.basename(path.dirname(f));
    const skill = readSkill(f, 'global', true);
    if (!skill) continue;
    if (manager.activeNames) skill.active = manager.activeNames.has(folder) || manager.activeNames.has(skill.name);
    seen.add(folder);
    seen.add(skill.name);
    add(skill);
  }
  // The manager may activate skills that live outside ~/.codex/skills.
  if (manager.activeNames) {
    for (const name of manager.activeNames) {
      if (!seen.has(name)) add({ name, description: '', scope: 'global', active: true, path: '' });
    }
  }
  for (const skill of discoverPluginSkills(home, configText)) add(skill);
  return [...byName.values()];
}

function projectMcpServers(cwd) {
  try {
    const j = JSON.parse(fs.readFileSync(path.join(cwd, '.mcp.json'), 'utf8'));
    return Object.keys(j.mcpServers || {});
  } catch {
    return [];
  }
}

function recommendedPacks(cwd) {
  const has = (f) => fs.existsSync(path.join(cwd, f));
  if (['package.json', 'tsconfig.json', 'Cargo.toml', 'requirements.txt', 'pyproject.toml', 'go.mod', 'Gemfile'].some(has)) {
    return ['engineering'];
  }
  if (has('Assets') || safeReaddir(cwd).some((e) => e.name.endsWith('.unity'))) return ['game-development'];
  return [];
}

// ---------------------------------------------------------------- ranking

// Ledger id of a registry item: Codex skills are invoked (and recorded) as $name.
function adoptionId(item) {
  return item.kind === 'skill' ? `$${item.name}` : item.name;
}

// Adoption signal per (item, intent): whether the user adopted this item's
// results for this intent (90-day half-life). 0 until the effective sample
// reaches 5, and always 0 for the safety intents.
function adoptionWeight(item, intent, adoption) {
  const a = adoption || NO_ADOPTION;
  return adoptionStore.adoptionScore(a.stats.get(adoptionStore.statKey(adoptionId(item), intent))) * ADOPTION_SCALE;
}

function adoptionLabel(item, intent, adoption) {
  const s = adoption.stats.get(adoptionStore.statKey(adoptionId(item), intent));
  return adoptionStore.isActive(s) ? { accepted: s.accepted, total: s.total } : null;
}

function scopeWeight(scope) {
  return SCOPE_WEIGHT[String(scope).split(':')[0]] || 0;
}

// Keywords this short must match a whole word ("qa" must not hit "qatar").
const WHOLE_WORD_MAX = 4;

function keywordRegex(keyword) {
  const escaped = keyword.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Word boundaries only make sense for ASCII keywords; Korean is matched as a substring.
  if (!/^[\x00-\x7f]+$/.test(keyword)) return new RegExp(escaped);
  const end = keyword.length <= WHOLE_WORD_MAX ? '(?![a-z0-9])' : '';
  return new RegExp(`(^|[^a-z0-9])${escaped}${end}`);
}

function countMatches(text, keywords) {
  const hay = String(text || '').toLowerCase();
  return (keywords || []).filter((k) => keywordRegex(k).test(hay)).length;
}

// Candidates sort by band first (pinned > map member > discovered), then
// score, so adoption only reorders within a band: a map member is never
// pushed below a discovered item. Pins force an item to the top of its
// intent in the order they were made. Security/Ship ignore adoption and pins.
function rankIntents(map, agents, skills, adoption = NO_ADOPTION) {
  const items = [
    ...agents.map((a) => ({ ...a, kind: 'agent' })),
    ...skills.map((s) => ({ ...s, kind: 'skill' }))
  ];
  const lookup = new Map(items.map((i) => [`${i.kind}:${i.name}`, i]));
  const byAdoptionId = new Map(items.map((i) => [adoptionId(i), i]));
  const intents = {};
  for (const [intent, def] of Object.entries(map.intents || {})) {
    const safety = adoptionStore.SAFETY_INTENTS.has(intent);
    const scored = new Map();
    (def.members || []).forEach((member, idx) => {
      const item = lookup.get(`${member.kind}:${member.name}`);
      if (!item) return;
      const base = MEMBER_BASE_SCORE - idx * MEMBER_STEP;
      scored.set(`${item.kind}:${item.name}`, { item, band: BAND.member, base, advisor: Boolean(member.advisor) });
    });
    for (const item of items) {
      const key = `${item.kind}:${item.name}`;
      if (scored.has(key)) continue;
      const hits = countMatches(`${item.name} ${item.description}`, def.description_keywords);
      if (hits) scored.set(key, { item, band: BAND.discovered, base: Math.min(hits * DISCOVERED_PER_MATCH, DISCOVERED_MAX), advisor: false });
    }
    const pins = safety ? [] : adoption.pins.filter((p) => p.intent === intent);
    pins.forEach((p, i) => {
      const item = byAdoptionId.get(p.id);
      if (!item) return;
      const prev = scored.get(`${item.kind}:${item.name}`);
      scored.set(`${item.kind}:${item.name}`, { item, band: BAND.pinned, base: pins.length - i, advisor: prev ? prev.advisor : false });
    });
    const ranked = [...scored.values()]
      .map(({ item, band, base, advisor }) => {
        const label = safety ? null : adoptionLabel(item, intent, adoption);
        return {
          name: item.name,
          kind: item.kind,
          advisor,
          // Pins keep the order they were made in: no scope or adoption weight.
          score: band === BAND.pinned ? base
            : base + scopeWeight(item.scope) + (safety ? 0 : adoptionWeight(item, intent, adoption)),
          scope: item.scope,
          active: item.active,
          band,
          ...(band === BAND.pinned ? { pinned: true } : {}),
          ...(label ? { adoption: label } : {})
        };
      })
      .sort((a, b) => b.band - a.band || b.score - a.score || a.name.localeCompare(b.name))
      .map(({ band, ...pick }) => pick);
    intents[intent] = [
      ...ranked.filter((p) => p.active).slice(0, RANKED_PER_INTENT),
      ...ranked.filter((p) => !p.active).slice(0, RANKED_INACTIVE_PER_INTENT)
    ];
  }
  return intents;
}

// ---------------------------------------------------------------- staleness

function statMtime(file) {
  try {
    return fs.statSync(file).mtimeMs;
  } catch {
    return 0;
  }
}

function subdirs(dir) {
  return safeReaddir(dir).filter((e) => e.isDirectory() && !e.name.startsWith('.')).map((e) => path.join(dir, e.name));
}

function pluginInputs(cacheDir) {
  const out = [cacheDir];
  for (const market of subdirs(cacheDir)) {
    out.push(market);
    for (const plugin of subdirs(market)) {
      out.push(plugin);
      for (const version of subdirs(plugin)) out.push(version, ...skillDirs(path.join(version, 'skills')));
    }
  }
  return out;
}

// Directory mtimes catch additions and removals; file mtimes catch edits.
function fingerprint(home, cwd) {
  const codex = codexHome(home);
  const paths = [
    path.join(codex, 'agents'),
    path.join(codex, 'agent-packs'),
    path.join(codex, 'skills'),
    ...pluginInputs(path.join(codex, 'plugins', 'cache')),
    path.join(codex, 'my-codex', 'skill-catalog-state.json'),
    effectiveConfigPath(home),
    ROUTING_MAP_FILE,
    adoptionStore.storePaths(home).ledger,
    adoptionStore.storePaths(home).pins,
    path.join(cwd, '.codex', 'agents'),
    path.join(cwd, '.codex', 'skills'),
    path.join(cwd, '.mcp.json')
  ];
  for (const f of tomlFiles(path.join(codex, 'agents'))) paths.push(f);
  for (const pack of safeReaddir(path.join(codex, 'agent-packs')).filter((e) => e.isDirectory())) {
    paths.push(path.join(codex, 'agent-packs', pack.name));
    for (const f of tomlFiles(path.join(codex, 'agent-packs', pack.name))) paths.push(f);
  }
  for (const f of skillDirs(path.join(codex, 'skills'))) paths.push(f);
  for (const f of tomlFiles(path.join(cwd, '.codex', 'agents'))) paths.push(f);
  for (const f of skillDirs(path.join(cwd, '.codex', 'skills'))) paths.push(f);
  let max = 0;
  for (const p of paths) max = Math.max(max, statMtime(p));
  return `${Math.floor(max)}:${paths.length}:${cwd}`;
}

function readRegistry(file) {
  try {
    const j = JSON.parse(fs.readFileSync(file, 'utf8'));
    return j && j.version === REGISTRY_VERSION ? j : null;
  } catch {
    return null;
  }
}

function loadRoutingMap() {
  try {
    return JSON.parse(fs.readFileSync(ROUTING_MAP_FILE, 'utf8'));
  } catch {
    return { intents: {} };
  }
}

// ---------------------------------------------------------------- build

function buildRegistry({ home = os.homedir(), cwd = process.cwd(), manager } = {}) {
  const mgr = manager || readSkillManager(home);
  const configText = safeRead(effectiveConfigPath(home));
  const agents = discoverAgents(home, cwd);
  const skills = discoverSkills(home, cwd, mgr, configText);
  const map = loadRoutingMap();
  return {
    version: REGISTRY_VERSION,
    generated_at: new Date().toISOString(),
    fingerprint: fingerprint(home, cwd),
    project_root: cwd,
    agents,
    skills,
    skill_lanes: mgr.lanes || {},
    mcp_servers: projectMcpServers(cwd),
    recommended_packs: recommendedPacks(cwd),
    // Process skills whose use says nothing about advice quality; the
    // adoption tracker never records them as offers.
    adoption_ignore: Array.isArray(map.adoption_ignore) ? map.adoption_ignore : [],
    intents: rankIntents(map, agents, skills, adoptionStore.loadAdoption(home))
  };
}

function writeAtomic(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.tmp`;
  try {
    fs.writeFileSync(tmp, text);
    fs.renameSync(tmp, file);
  } catch (e) {
    fs.rmSync(tmp, { force: true });
    throw e;
  }
}

function adoptionExpired(registry, home) {
  if (!statMtime(adoptionStore.storePaths(home).ledger)) return false;
  return !(Date.now() - Date.parse(registry.generated_at) < ADOPTION_MAX_AGE_MS);
}

// Returns { status, registry, diagnostic, file }. A skill-manager failure
// leaves any existing cache untouched so the next session retries.
function ensureRegistry({ home = os.homedir(), cwd = process.cwd(), file = defaultRegistryPath(home) } = {}) {
  const existing = readRegistry(file);
  if (existing && existing.fingerprint === fingerprint(home, cwd) && !adoptionExpired(existing, home)) {
    return { status: 'up-to-date', registry: existing, file };
  }
  const manager = readSkillManager(home);
  if (!manager.ok) {
    return { status: 'skill-catalog-error', registry: existing, diagnostic: manager.diagnostic, file };
  }
  const registry = buildRegistry({ home, cwd, manager });
  try {
    writeAtomic(file, JSON.stringify(registry, null, 2) + '\n');
    return { status: 'regenerated', registry, file };
  } catch (e) {
    return { status: 'failed', registry, diagnostic: `[SessionStart] Registry write failed: ${e.message}`, file };
  }
}

// ---------------------------------------------------------------- summary

// Same shape as my-claude's hints: invocable ids ("$" invokes a Codex skill,
// where Claude uses "/"), advisors tagged "[advisor]" with no space.
function formatPick(pick) {
  let label = pick.kind === 'skill' ? `$${pick.name}` : pick.name;
  if (pick.advisor) label += '[advisor]';
  if (!pick.active) label += ` (inactive ${pick.scope})`;
  return label;
}

// Summary-only annotations: [pinned] = user pin, (adopted x/y) = the user
// adopted x of the last y results for this intent (shown once y >= 5).
function formatSummaryPick(pick) {
  let label = formatPick(pick);
  if (pick.pinned) label += '[pinned]';
  if (pick.adoption) label += ` (adopted ${pick.adoption.accepted}/${pick.adoption.total})`;
  return label;
}

function renderSummary(registry, file) {
  if (!registry) return '';
  const count = (list) => `${list.length} (${list.filter((x) => x.active).length} active)`;
  const head = `[CapabilityRegistry v2] ${file} -- agents ${count(registry.agents || [])}, ` +
    `skills ${count(registry.skills || [])}. Per-intent top ${SUMMARY_TOP} ([advisor] = Advisor Group; ` +
    '[pinned] / (adopted x/y) = user pin / adoption record; ' +
    'inactive picks need their skill lane, agent pack or plugin enabled first). Read the registry for the full ranked lists.';
  const parts = [head];
  let length = head.length;
  for (const [intent, picks] of Object.entries(registry.intents || {})) {
    if (!picks.length) continue;
    const line = ` ${intent}: ${picks.slice(0, SUMMARY_TOP).map(formatSummaryPick).join(', ')}.`;
    if (length + line.length > SUMMARY_CHAR_LIMIT) break;
    parts.push(line);
    length += line.length;
  }
  return parts.join('');
}

function sessionStartLine({ home, cwd, file } = {}) {
  const result = ensureRegistry({ home, cwd, file });
  let line = `[SessionStart] Registry cache: ${result.status}.`;
  if (result.diagnostic) line += ` ${result.diagnostic}`;
  const summary = renderSummary(result.registry, result.file);
  if (summary) line += ` ${summary}`;
  // Manager diagnostics may carry ANSI escapes; raw control characters would
  // break the single JSON document session-start.sh emits.
  return line.replace(/[\x00-\x1f\x7f]+/g, ' ');
}

module.exports = {
  REGISTRY_VERSION,
  SUMMARY_CHAR_LIMIT,
  adoptionWeight,
  buildRegistry,
  countMatches,
  keywordRegex,
  defaultRegistryPath,
  formatPick,
  ensureRegistry,
  parseAgentToml,
  parseSkillFrontmatter,
  rankIntents,
  readRegistry,
  renderSummary,
  sessionStartLine
};

if (require.main === module) {
  try {
    if (process.argv.includes('--session-start')) {
      process.stdout.write(sessionStartLine() + '\n');
    } else {
      const result = ensureRegistry();
      process.stdout.write(`${result.status} ${result.file}\n`);
      if (result.diagnostic) process.stderr.write(result.diagnostic + '\n');
    }
  } catch (e) {
    process.stdout.write(`[SessionStart] Registry cache: failed. ${e.message}\n`);
  }
}
