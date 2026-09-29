// Learning store: suggestions the learning loop detected, the rules/skills the
// user approved from them, and a ledger of every mutation. Ported from
// my-claude's hooks/learning-store.js; the shared files and their row schema
// are the same (my-claude writes harness "claude", this harness "codex").
//
// Shared directory (same as the adoption store):
//   ~/.config/agent-harness/learning-suggestions.jsonl  {id, kind, status, key, ...}
//   ~/.config/agent-harness/learning-items.json         {items: {slug: item}, last_curate_at}
//   ~/.config/agent-harness/learning-audit.jsonl        one row per mutation (id A<n>)
//   ~/.config/agent-harness/learned-archive/            files moved out by curate/rollback
// Approved files live only in the user-owned layer, which install.sh never
// manages:
//   ~/.codex/learned-rules/learned-*.md   one file per approved rule
//   ~/.codex/skills/learned-*/SKILL.md    approved workflows (Codex loads these)
// Codex has no instruction-rules directory (~/.codex/rules/ holds execpolicy
// .rules files), so the live rules are rendered into a marked section at the
// end of the global ~/.codex/AGENTS.md, which Codex reads every session; see
// syncAgentsSection().
//
// Suggestion status: pending | approved | dismissed. Item status: active |
// stale | archived. Nothing is ever deleted: files move to learned-archive/.
'use strict';
const fs = require('fs');
const path = require('path');
const adoption = require('./adoption-store.js');

const HARNESS = 'codex';
// Rows written before the harness field existed are my-claude's.
const LEGACY_HARNESS = 'claude';
const MAX_PENDING = 5;
const MAX_ACTIVE_ITEMS = 20;
const LEARNED_PREFIX = 'learned-';
const DAY_MS = 24 * 60 * 60 * 1000;

function learningPaths(home) {
  const base = adoption.storePaths(home);
  const h = path.dirname(path.dirname(base.shared));
  return {
    shared: base.shared,
    ledger: base.ledger,
    suggestions: path.join(base.shared, 'learning-suggestions.jsonl'),
    items: path.join(base.shared, 'learning-items.json'),
    audit: path.join(base.shared, 'learning-audit.jsonl'),
    archive: path.join(base.shared, 'learned-archive'),
    rulesDir: path.join(h, '.codex', 'learned-rules'),
    skillsDir: path.join(h, '.codex', 'skills'),
    agentsMd: path.join(h, '.codex', 'AGENTS.md'),
    scratch: path.join(h, '.codex', '.learning'),
  };
}

function iso(now) {
  return new Date(now).toISOString();
}

// ---------------------------------------------------------------- keys

// Case, punctuation, and spacing never make two suggestions different.
function normalizeText(text) {
  return String(text || '').toLowerCase().replace(/[\p{P}\p{S}]+/gu, ' ').replace(/\s+/g, ' ').trim();
}

function suggestionKey(s) {
  if (s.kind === 'skill') return `skill:${(s.steps || []).map((st) => st.id).join('>')}`;
  return `rule:${normalizeText(s.text)}`;
}

// ASCII words joined by '-', cut at a word boundary within maxLen.
function slugify(text, maxLen) {
  const max = maxLen || 48;
  const slug = String(text || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  if (slug.length <= max) return slug;
  const cut = slug.slice(0, max + 1);
  const at = cut.lastIndexOf('-');
  return (at > 0 ? cut.slice(0, at) : slug.slice(0, max)).replace(/-+$/, '');
}

// ---------------------------------------------------------------- suggestions

function isOurs(row) {
  return !!row && (row.harness || LEGACY_HARNESS) === HARNESS;
}

function readSuggestions(home) {
  return adoption.readJsonl(learningPaths(home).suggestions)
    .filter((s) => s && typeof s.id === 'string' && (s.kind === 'rule' || s.kind === 'skill'));
}

function writeSuggestions(home, rows) {
  adoption.writeJsonl(learningPaths(home).suggestions, rows);
}

function nextSuggestionId(rows) {
  const n = rows.reduce((max, s) => Math.max(max, parseInt(String(s.id).slice(1), 10) || 0), 0);
  return `L${n + 1}`;
}

// ---------------------------------------------------------------- items

function readState(home) {
  const j = adoption.readJson(learningPaths(home).items, null);
  const items = j && j.items && typeof j.items === 'object' ? j.items : {};
  return { items, last_curate_at: (j && j.last_curate_at) || null };
}

function writeState(home, state) {
  adoption.writeJson(learningPaths(home).items, state);
}

function exists(p) {
  try { fs.statSync(p); return true; } catch { return false; }
}

// Items that count toward the cap: not archived, file still in place.
function liveItems(state) {
  return Object.values(state.items).filter((it) => isOurs(it) && it.status !== 'archived' && exists(it.path));
}

function mtimeOf(p) {
  try { return fs.statSync(p).mtimeMs; } catch { return 0; }
}

// Latest sign of use: approval, a recorded use ($learned-* skill use, the same
// correction repeated), a ledger event for the skill, or an edit to the file.
function lastUseMs(item, ledgerEvents) {
  const file = item.kind === 'skill' ? path.join(item.path, 'SKILL.md') : item.path;
  const times = [Date.parse(item.approved_at), Date.parse(item.last_used_at), mtimeOf(file)];
  for (const e of ledgerEvents || []) if (String(e.id).replace(/^\$/, '') === item.slug) times.push(Date.parse(e.ts));
  return Math.max(0, ...times.filter(Number.isFinite));
}

// ---------------------------------------------------------------- AGENTS.md

const AGENTS_HEADING = '## Learned Rules (approved by you)';
const AGENTS_MARKER = '<!-- my-codex:learned -->';

// The rule a learned file states: its "- " imperative line, else the quoted
// original sentence.
function ruleLine(text) {
  const body = String(text).replace(/^---\n[\s\S]*?\n---\n/, '');
  const bullet = body.match(/^- (.+)$/m);
  if (bullet) return bullet[1].trim();
  const quote = body.match(/^> (.+)$/m);
  return quote ? `Follow the user's instruction: "${quote[1].trim()}"` : null;
}

function renderAgentsSection(rules) {
  return [
    AGENTS_HEADING,
    AGENTS_MARKER,
    '',
    'Standing instructions the user approved through the learning loop (`~/.codex/bin/my-codex-learn list`). Follow them in every session.',
    '',
    ...rules.map((r) => `- ${r.line} (\`${r.slug}\`)`),
    '',
  ].join('\n');
}

// Drop the learned section (heading through the next "## " heading or EOF).
function stripAgentsSection(text) {
  const lines = text.split('\n');
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    if (lines[i] === AGENTS_HEADING && lines[i + 1] === AGENTS_MARKER) {
      i += 2;
      while (i < lines.length && !lines[i].startsWith('## ')) i++;
      i--;
      continue;
    }
    out.push(lines[i]);
  }
  return out.join('\n');
}

// Re-render the learned section from the live rule files, always last in
// ~/.codex/AGENTS.md. Everything outside the section is kept byte for byte,
// and the file is written through (mode kept) only when the text changes.
// No live rules -> no section. Returns true when the file changed.
function syncAgentsSection(home) {
  const p = learningPaths(home);
  const state = readState(home);
  const rules = Object.values(state.items)
    .filter((it) => isOurs(it) && it.kind === 'rule' && it.status !== 'archived' && exists(it.path))
    .sort((a, b) => String(a.approved_at).localeCompare(String(b.approved_at)) || a.slug.localeCompare(b.slug))
    .map((it) => ({ slug: it.slug, line: ruleLine(fs.readFileSync(it.path, 'utf8')) }))
    .filter((r) => r.line);
  let current = null;
  try { current = fs.readFileSync(p.agentsMd, 'utf8'); } catch { /* no AGENTS.md yet */ }
  if (current === null && !rules.length) return false;
  const base = stripAgentsSection(current || '').replace(/\n+$/, '');
  const next = rules.length ? `${base ? `${base}\n\n` : ''}${renderAgentsSection(rules)}` : (base ? `${base}\n` : '');
  if (next === current) return false;
  fs.mkdirSync(path.dirname(p.agentsMd), { recursive: true });
  fs.writeFileSync(p.agentsMd, next);
  return true;
}

// ---------------------------------------------------------------- audit

function readAudit(home) {
  return adoption.readJsonl(learningPaths(home).audit).filter((r) => r && typeof r.id === 'string');
}

// Appends one audit row and returns its id (A1, A2, ...).
function audit(home, now, action, fields) {
  const rows = readAudit(home);
  const n = rows.reduce((max, r) => Math.max(max, parseInt(r.id.slice(1), 10) || 0), 0);
  const id = `A${n + 1}`;
  adoption.appendJsonl(learningPaths(home).audit, [Object.assign({ id, ts: iso(now), harness: HARNESS, action }, fields)]);
  return id;
}

// ---------------------------------------------------------------- files

function writeAtomic(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, text);
  fs.renameSync(tmp, file);
}

// Move a rule file or skill directory into learned-archive/; returns the
// archive path. Never deletes.
function moveToArchive(home, src, now) {
  const stamp = iso(now).replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z');
  const dir = path.join(learningPaths(home).archive, stamp);
  let dest = path.join(dir, path.basename(src));
  for (let i = 2; exists(dest); i++) dest = path.join(dir, `${i}-${path.basename(src)}`);
  fs.mkdirSync(dir, { recursive: true });
  fs.renameSync(src, dest);
  return dest;
}

function moveBack(src, dest) {
  if (exists(dest)) throw new Error(`${dest} already exists; move it away first`);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.renameSync(src, dest);
}

module.exports = {
  AGENTS_HEADING,
  AGENTS_MARKER,
  DAY_MS,
  HARNESS,
  LEARNED_PREFIX,
  MAX_ACTIVE_ITEMS,
  MAX_PENDING,
  audit,
  exists,
  iso,
  isOurs,
  lastUseMs,
  learningPaths,
  liveItems,
  moveBack,
  moveToArchive,
  nextSuggestionId,
  normalizeText,
  readAudit,
  readState,
  readSuggestions,
  slugify,
  stripAgentsSection,
  suggestionKey,
  syncAgentsSection,
  writeAtomic,
  writeState,
  writeSuggestions,
};
