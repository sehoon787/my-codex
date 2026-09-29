// Learning loop CLI (Codex port of my-claude's hooks/learning-cli.js),
// reached through ~/.codex/bin/my-codex-learn:
//
//   learn list                      pending suggestions + learned items
//   learn show <id|slug>            one suggestion or item in full
//   learn approve <id> [--as "<imperative English>"]
//                                   write the rule/skill (user-owned layer only)
//   learn dismiss <id>              never suggest this key again
//   learn pin <slug> / unpin <slug> exempt an item from the curator
//   learn curate [--dry-run]        active -> stale (30 d unused) -> archived (90 d)
//   learn rollback <audit-id>       undo one mutation from learning-audit.jsonl
//   learn session-start             (SessionStart) weekly silent curate + <= 2 [Learn] lines
//   learn sync-agents               re-render the learned section of ~/.codex/AGENTS.md
//
// Nothing reaches ~/.codex/learned-rules, the learned section of
// ~/.codex/AGENTS.md, or ~/.codex/skills except through `approve`. Nothing is
// deleted: curate and rollback move files into
// ~/.config/agent-harness/learned-archive/. Every mutation is audited, and
// every command leaves the AGENTS.md section matching the live rule files.
'use strict';
const path = require('path');
const store = require('./learning-store.js');
const adoption = require('./adoption-store.js');

const STALE_DAYS = 30;
const ARCHIVE_DAYS = 90;
const CURATE_EVERY_DAYS = 7;
const SURFACE_MAX = 2;
const SHORT_TEXT_MAX = 80;
const SKILL_DESC_MAX = 200;
const CMD = '~/.codex/bin/my-codex-learn';
const USAGE = `Usage: my-codex-learn <list | show <id> | approve <id> [--as "<rule in English>"] | dismiss <id> | pin <slug> | unpin <slug> | curate [--dry-run] | rollback <audit-id>>\n`;

function day(now) {
  return store.iso(now).slice(0, 10);
}

function findSuggestion(rows, id) {
  return rows.find((s) => store.isOurs(s) && s.id.toLowerCase() === String(id || '').toLowerCase()) || null;
}

function replaceRow(rows, next) {
  return rows.map((r) => (r.id === next.id && store.isOurs(r) ? next : r));
}

// Codex skill ids already carry their "$" mention.
function stepLabel(st) {
  return st.id;
}

function shortText(s) {
  if (s.kind === 'skill') return `${s.name} = ${s.steps.map(stepLabel).join(' → ')} (adopted in ${(s.evidence || []).length} sessions)`;
  const t = s.text.length > SHORT_TEXT_MAX ? `${s.text.slice(0, SHORT_TEXT_MAX - 1)}…` : s.text;
  return `"${t}"${s.context ? ` (after ${s.context.id})` : ''}`;
}

// ---------------------------------------------------------------- rendering

// A slug is taken while its file exists or any item (archived too) holds it.
function uniqueTarget(dir, base, suffix, items) {
  const taken = (name) => store.exists(path.join(dir, name + suffix)) || !!items[name];
  let name = base;
  for (let i = 2; taken(name); i++) name = `${base}-${i}`;
  return name;
}

function renderRule(s, slug, asText, now) {
  const imperative = asText
    ? `- ${asText.trim()}`
    : 'Follow the user\'s standing instruction quoted below, as written, in every session.';
  const context = s.context ? `\nStated right after the \`${s.context.id}\` ${s.context.kind} returned a result.` : '';
  return [
    '---',
    `date: ${day(now)}`,
    'source: learning-loop',
    `suggestion: ${s.id}`,
    `evidence: ${JSON.stringify(s.evidence || [])}`,
    '---',
    '',
    `# Learned rule: ${slug}`,
    '',
    imperative,
    '',
    `> ${s.text}`,
    context,
    '',
    `Approved by the user on ${day(now)} through the learning loop. Review or roll back: \`${CMD} list\`.`,
    '',
  ].join('\n');
}

function intentKeywords(intents) {
  const map = adoption.readJson(path.join(__dirname, 'routing-map.json'), null);
  const byName = new Map(Object.entries((map && map.intents) || {}).map(([name, i]) => [name, i.description_keywords || []]));
  return [...new Set(intents.flatMap((name) => byName.get(name) || []))].slice(0, 4);
}

// The registry routes a skill by its description, so it names the intent
// and that intent's description keywords.
function skillDescription(s) {
  const intents = s.intents || [];
  const keywords = intentKeywords(intents);
  const flow = s.steps.map(stepLabel).join(' then ');
  let d = `Learned ${intents[0] ? `${intents[0]} ` : ''}workflow the user adopted: ${flow}.`;
  if (keywords.length) d += ` Use for ${keywords.join(', ')} tasks.`;
  return d.length > SKILL_DESC_MAX ? `${d.slice(0, SKILL_DESC_MAX - 1)}…` : d;
}

function renderSkill(s, name, now) {
  const steps = s.steps.map((st, i) => {
    const how = st.kind === 'skill' ? `the \`${st.id}\` skill (mention \`${st.id}\`)` : `the \`${st.id}\` agent (spawn_agent, agent_type \`${st.id}\`)`;
    return `${i + 1}. Use ${how}${i ? ', giving it the result of the previous step' : ''}.`;
  });
  return [
    '---',
    `name: ${name}`,
    `description: ${JSON.stringify(skillDescription(s))}`,
    '---',
    '',
    `# Learned workflow: ${s.steps.map(stepLabel).join(' → ')}`,
    '',
    `The user accepted these results back to back in ${(s.evidence || []).length} sessions${(s.intents || []).length ? ` (${s.intents.join(', ')})` : ''}. When a task matches, run them as one procedure:`,
    '',
    ...steps,
    '',
    '## Provenance',
    '',
    '- source: learning-loop',
    `- suggestion: ${s.id}`,
    `- approved: ${day(now)}`,
    `- evidence sessions: ${(s.evidence || []).join(', ')}`,
    `- review or roll back: \`${CMD} list\``,
    '',
  ].join('\n');
}

// ---------------------------------------------------------------- commands

function list(args, ctx) {
  const rows = store.readSuggestions(ctx.home).filter(store.isOurs);
  const pending = rows.filter((s) => s.status === 'pending');
  const state = store.readState(ctx.home);
  const items = Object.values(state.items).filter(store.isOurs);
  ctx.out(pending.length ? `Pending suggestions (${pending.length}/${store.MAX_PENDING}):\n` : 'No pending suggestions.\n');
  for (const s of pending) ctx.out(`  ${s.id}  ${s.kind.padEnd(5)}  ${day(Date.parse(s.created_at))}  ${shortText(s)}\n`);
  const live = store.liveItems(state).length;
  ctx.out(items.length ? `Learned items (${live}/${store.MAX_ACTIVE_ITEMS} live):\n` : 'No learned items yet.\n');
  const ledger = adoption.readLedger(ctx.home);
  for (const it of items) {
    const last = day(store.lastUseMs(it, ledger) || Date.parse(it.approved_at));
    ctx.out(`  ${it.slug}  ${it.kind.padEnd(5)}  ${it.status.padEnd(8)}  last use ${last}${it.pinned ? '  pinned' : ''}  ${it.status === 'archived' ? it.archived_path : it.path}\n`);
  }
  return 0;
}

function show(args, ctx) {
  const s = findSuggestion(store.readSuggestions(ctx.home), args[0]);
  const item = store.readState(ctx.home).items[args[0]];
  if (!s && !item) { ctx.out(`No suggestion or learned item: ${args[0] || '(none)'}\n`); return 1; }
  ctx.out(JSON.stringify(s || item, null, 2) + '\n');
  return 0;
}

function approve(args, ctx) {
  const at = args.indexOf('--as');
  const asText = at >= 0 ? args[at + 1] : null;
  const rows = store.readSuggestions(ctx.home);
  const s = findSuggestion(rows, args[0]);
  if (!s) { ctx.out(`No suggestion ${args[0] || '(none)'}. See: ${CMD} list\n`); return 1; }
  if (s.status !== 'pending') { ctx.out(`${s.id} is ${s.status}, not pending.\n`); return 1; }
  const state = store.readState(ctx.home);
  if (store.liveItems(state).length >= store.MAX_ACTIVE_ITEMS) {
    store.audit(ctx.home, ctx.now, 'cap_refused', { suggestion: s.id, key: s.key, reason: `${store.MAX_ACTIVE_ITEMS} learned items already live` });
    ctx.out(`Refused: ${store.MAX_ACTIVE_ITEMS} learned items are already live. Run \`${CMD} curate\` or roll back an approval first, then approve again.\n`);
    return 1;
  }
  const p = store.learningPaths(ctx.home);
  let slug;
  let target;
  if (s.kind === 'rule') {
    const words = store.slugify(asText || s.text, 40);
    slug = uniqueTarget(p.rulesDir, `${store.LEARNED_PREFIX}${words || `rule-${s.id.toLowerCase()}`}`, '.md', state.items);
    target = path.join(p.rulesDir, `${slug}.md`);
    store.writeAtomic(target, renderRule(s, slug, asText, ctx.now));
  } else {
    slug = uniqueTarget(p.skillsDir, s.name, '', state.items);
    target = path.join(p.skillsDir, slug);
    store.writeAtomic(path.join(target, 'SKILL.md'), renderSkill(s, slug, ctx.now));
  }
  const approvedAt = store.iso(ctx.now);
  store.writeState(ctx.home, Object.assign({}, state, {
    items: Object.assign({}, state.items, {
      [slug]: { slug, kind: s.kind, status: 'active', pinned: false, path: target, suggestion: s.id, approved_at: approvedAt, last_used_at: null, harness: store.HARNESS },
    }),
  }));
  store.writeSuggestions(ctx.home, replaceRow(rows, Object.assign({}, s, { status: 'approved', approved_at: approvedAt, slug })));
  const auditId = store.audit(ctx.home, ctx.now, 'approve', { suggestion: s.id, slug, before: { status: 'pending', path: null }, after: { status: 'active', path: target } });
  ctx.out(`Approved ${s.id} -> ${s.kind === 'skill' ? path.join(target, 'SKILL.md') : target} (audit ${auditId}; undo: ${CMD} rollback ${auditId})\n`);
  return 0;
}

function dismiss(args, ctx) {
  const rows = store.readSuggestions(ctx.home);
  const s = findSuggestion(rows, args[0]);
  if (!s) { ctx.out(`No suggestion ${args[0] || '(none)'}.\n`); return 1; }
  if (s.status !== 'pending') { ctx.out(`${s.id} is ${s.status}, not pending.\n`); return 1; }
  store.writeSuggestions(ctx.home, replaceRow(rows, Object.assign({}, s, { status: 'dismissed', dismissed_at: store.iso(ctx.now) })));
  const auditId = store.audit(ctx.home, ctx.now, 'dismiss', { suggestion: s.id, before: { status: 'pending' }, after: { status: 'dismissed' } });
  ctx.out(`Dismissed ${s.id}; it will not be suggested again (audit ${auditId}).\n`);
  return 0;
}

function setPinned(args, ctx, pinned) {
  const state = store.readState(ctx.home);
  const item = state.items[args[0]];
  if (!item || !store.isOurs(item) || item.status === 'archived') { ctx.out(`No live learned item: ${args[0] || '(none)'}\n`); return 1; }
  if (!!item.pinned === pinned) { ctx.out(`${item.slug} is already ${pinned ? 'pinned' : 'unpinned'}.\n`); return 0; }
  store.writeState(ctx.home, Object.assign({}, state, { items: Object.assign({}, state.items, { [item.slug]: Object.assign({}, item, { pinned }) }) }));
  const auditId = store.audit(ctx.home, ctx.now, pinned ? 'pin' : 'unpin', { slug: item.slug, before: { pinned: !pinned }, after: { pinned } });
  ctx.out(`${pinned ? 'Pinned' : 'Unpinned'} ${item.slug} (audit ${auditId}).\n`);
  return 0;
}

// Ages items by last use only; use counts never keep or remove anything.
function curate(args, ctx, quiet) {
  const dryRun = args.includes('--dry-run');
  const state = store.readState(ctx.home);
  const ledger = adoption.readLedger(ctx.home);
  const items = Object.assign({}, state.items);
  const lines = [];
  for (const item of Object.values(state.items)) {
    if (!store.isOurs(item) || item.status === 'archived' || item.pinned || !store.exists(item.path)) continue;
    const idleDays = (ctx.now - store.lastUseMs(item, ledger)) / store.DAY_MS;
    let next = null;
    if (idleDays >= ARCHIVE_DAYS) next = 'archived';
    else if (idleDays >= STALE_DAYS && item.status === 'active') next = 'stale';
    else if (idleDays < STALE_DAYS && item.status === 'stale') next = 'active';
    if (!next) continue;
    lines.push(`${item.slug}: ${item.status} -> ${next} (unused ${Math.floor(idleDays)} days)`);
    if (dryRun) continue;
    if (next === 'archived') {
      const dest = store.moveToArchive(ctx.home, item.path, ctx.now);
      items[item.slug] = Object.assign({}, item, { status: 'archived', archived_path: dest });
      store.writeState(ctx.home, Object.assign({}, state, { items })); // state follows the move before anything else can fail
      store.audit(ctx.home, ctx.now, 'archive', { slug: item.slug, before: { status: item.status, path: item.path }, after: { status: 'archived', path: dest } });
    } else {
      items[item.slug] = Object.assign({}, item, { status: next });
      store.writeState(ctx.home, Object.assign({}, state, { items }));
      store.audit(ctx.home, ctx.now, next === 'stale' ? 'stale' : 'reactivate', { slug: item.slug, before: { status: item.status }, after: { status: next } });
    }
  }
  if (!dryRun) store.writeState(ctx.home, Object.assign({}, state, { items, last_curate_at: store.iso(ctx.now) }));
  if (!quiet) ctx.out(lines.length ? `${dryRun ? 'Would change' : 'Changed'}:\n${lines.map((l) => `  ${l}\n`).join('')}` : 'Nothing to curate.\n');
  return 0;
}

// ---------------------------------------------------------------- rollback

const NOT_ROLLBACKABLE = { cap_refused: 'a refusal changed nothing', rollback: 'roll back the original mutation\'s effect by hand', suggest: `use \`${CMD} dismiss\`` };

function rollbackApprove(row, ctx, state) {
  const item = state.items[row.slug];
  if (!item || item.suggestion !== row.suggestion || item.path !== row.after.path || item.status === 'archived' || !store.exists(row.after.path)) throw new Error(`${row.slug} is no longer in place; roll back the later mutation first`);
  const dest = store.moveToArchive(ctx.home, row.after.path, ctx.now);
  const items = Object.assign({}, state.items);
  delete items[row.slug];
  store.writeState(ctx.home, Object.assign({}, state, { items }));
  const rows = store.readSuggestions(ctx.home);
  const s = findSuggestion(rows, row.suggestion);
  if (s) {
    const { approved_at, slug, ...rest } = s; // eslint-disable-line no-unused-vars
    store.writeSuggestions(ctx.home, replaceRow(rows, Object.assign(rest, { status: 'pending' })));
  }
  return { before: { path: row.after.path }, after: { path: dest, suggestion_status: 'pending' } };
}

function rollbackDismiss(row, ctx) {
  const rows = store.readSuggestions(ctx.home);
  const s = findSuggestion(rows, row.suggestion);
  if (!s || s.status !== 'dismissed') throw new Error(`${row.suggestion} is not dismissed any more`);
  const { dismissed_at, ...rest } = s; // eslint-disable-line no-unused-vars
  store.writeSuggestions(ctx.home, replaceRow(rows, Object.assign(rest, { status: 'pending' })));
  return { before: { status: 'dismissed' }, after: { status: 'pending' } };
}

function rollbackItem(row, ctx, state) {
  const item = state.items[row.slug];
  if (!item) throw new Error(`no learned item ${row.slug}`);
  let next;
  if (row.action === 'pin' || row.action === 'unpin') {
    if (!!item.pinned !== row.after.pinned) throw new Error(`${row.slug} pin state changed since`);
    next = Object.assign({}, item, { pinned: row.before.pinned });
  } else if (row.action === 'archive') {
    if (item.status !== 'archived' || item.archived_path !== row.after.path) throw new Error(`${row.slug} is not in that archive any more`);
    store.moveBack(row.after.path, row.before.path);
    const { archived_path, ...rest } = item; // eslint-disable-line no-unused-vars
    // Restored with a fresh use, so the next curate does not archive it again.
    next = Object.assign(rest, { status: row.before.status, last_used_at: store.iso(ctx.now) });
  } else {
    if (item.status !== row.after.status) throw new Error(`${row.slug} status changed since`);
    next = Object.assign({}, item, { status: row.before.status });
  }
  store.writeState(ctx.home, Object.assign({}, state, { items: Object.assign({}, state.items, { [row.slug]: next }) }));
  return { before: row.after, after: row.before };
}

function rollback(args, ctx) {
  const rows = store.readAudit(ctx.home);
  const row = rows.find((r) => r.id.toLowerCase() === String(args[0] || '').toLowerCase());
  if (!row) { ctx.out(`No audit entry ${args[0] || '(none)'}. See ${store.learningPaths(ctx.home).audit}\n`); return 1; }
  if (NOT_ROLLBACKABLE[row.action]) { ctx.out(`${row.id} (${row.action}) cannot be rolled back: ${NOT_ROLLBACKABLE[row.action]}.\n`); return 1; }
  const rolledBack = new Set(rows.filter((r) => r.action === 'rollback').map((r) => r.target));
  if (rolledBack.has(row.id)) { ctx.out(`${row.id} was already rolled back.\n`); return 1; }
  // Last in, first out per item: a later live mutation of it must go first.
  const seq = (r) => parseInt(r.id.slice(1), 10) || 0;
  const later = row.slug && rows.find((r) => seq(r) > seq(row) && r.slug === row.slug && !NOT_ROLLBACKABLE[r.action] && !rolledBack.has(r.id));
  if (later) { ctx.out(`${row.id} cannot be rolled back yet: roll back ${later.id} (${later.action}) first.\n`); return 1; }
  const state = store.readState(ctx.home);
  let change;
  if (row.action === 'approve') change = rollbackApprove(row, ctx, state);
  else if (row.action === 'dismiss') change = rollbackDismiss(row, ctx);
  else change = rollbackItem(row, ctx, state);
  const auditId = store.audit(ctx.home, ctx.now, 'rollback', Object.assign({ target: row.id, target_action: row.action, slug: row.slug, suggestion: row.suggestion }, change));
  ctx.out(`Rolled back ${row.id} (${row.action}${row.slug ? ` ${row.slug}` : ''}${row.suggestion ? ` ${row.suggestion}` : ''}) (audit ${auditId}).\n`);
  return 0;
}

// ---------------------------------------------------------------- session start

function sessionStart(args, ctx) {
  const state = store.readState(ctx.home);
  const last = Date.parse(state.last_curate_at);
  if (!Number.isFinite(last) || ctx.now - last >= CURATE_EVERY_DAYS * store.DAY_MS) {
    try { curate([], ctx, true); } catch { /* next session retries */ }
  }
  try { store.syncAgentsSection(ctx.home); } catch { /* retried next session */ }
  const pending = store.readSuggestions(ctx.home).filter((s) => store.isOurs(s) && s.status === 'pending');
  const lines = pending.slice(0, SURFACE_MAX).map((s) => `[Learn] ${s.id}: ${s.kind} — ${shortText(s)}. Approve: ${CMD} approve ${s.id} / dismiss: ${CMD} dismiss ${s.id}`);
  if (pending.length > SURFACE_MAX) lines[lines.length - 1] += ` (+${pending.length - SURFACE_MAX} more: ${CMD} list)`;
  if (lines.length) ctx.out(lines.join('\n') + '\n');
  return 0;
}

const COMMANDS = {
  list,
  show,
  approve,
  dismiss,
  pin: (a, c) => setPinned(a, c, true),
  unpin: (a, c) => setPinned(a, c, false),
  curate: (a, c) => curate(a, c, false),
  rollback,
  'session-start': sessionStart,
  'sync-agents': (a, c) => { if (store.syncAgentsSection(c.home)) c.out(`Updated the learned section of ${store.learningPaths(c.home).agentsMd}\n`); return 0; },
};

// Commands whose success can add, move, or restore a rule file.
const RULE_MUTATIONS = new Set(['approve', 'curate', 'rollback']);

// Returns the process exit code. opts (tests): {home, now, out}.
function main(argv, opts) {
  const o = opts || {};
  const ctx = { home: o.home || null, now: o.now || Date.now(), out: o.out || ((s) => process.stdout.write(s)) };
  const cmd = COMMANDS[argv[0]];
  if (!cmd) { ctx.out(USAGE); return argv[0] ? 1 : 0; }
  try {
    const code = cmd(argv.slice(1), ctx);
    if (code === 0 && RULE_MUTATIONS.has(argv[0])) store.syncAgentsSection(ctx.home);
    return code;
  } catch (e) {
    ctx.out(`learn ${argv[0]} failed: ${e.message}\n`);
    return 1;
  }
}

module.exports = { main, skillDescription };

if (require.main === module) process.exitCode = main(process.argv.slice(2));
