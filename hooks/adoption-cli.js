// Adoption ledger CLI (Codex port of my-claude's hooks/adoption-cli.js),
// reached through ~/.codex/bin/my-codex-adoption:
//
//   list [--intent X]              id x intent table: decayed accept/reject/n
//   list --events [--intent X]     raw events (ts for undo)
//   pin <id> <intent>              force <id> to the top of <intent>
//   unpin <id> <intent>
//   reset [<id>]                   archive every event (or every event of <id>)
//   undo <ts> [<id>]               archive the one event with that ts
//
// Ids are what the ledger records: an agent's name, or "$name" for a Codex
// skill. The ledger is shared with my-claude, so its rows are listed too.
// Nothing is hard-deleted: reset/undo move events to adoption-archive.jsonl.
// Every mutation is appended to adoption-audit.jsonl. The next session's
// registry rebuild picks the change up (ledger and pins are registry sources).
'use strict';
const fs = require('fs');
const path = require('path');
const store = require('./adoption-store.js');

const ARCHIVE_ATTEMPTS = 3;
const USAGE = 'Usage: my-codex-adoption <list [--events] [--intent X] | pin <id> <intent> | unpin <id> <intent> | reset [<id>] | undo <ts> [<id>]>\n';

function intentNames() {
  const map = store.readJson(path.join(__dirname, 'routing-map.json'), null);
  return map && map.intents && typeof map.intents === 'object' ? Object.keys(map.intents) : [];
}

// Canonical intent name (case-insensitive), or null when the map lacks it.
function canonicalIntent(name) {
  const names = intentNames();
  if (!names.length) return name;
  return names.find((n) => n.toLowerCase() === String(name).toLowerCase()) || null;
}

function pad(s, n) {
  const t = String(s);
  return t.length >= n ? t : t + ' '.repeat(n - t.length);
}

function listEvents(only, ctx) {
  const events = store.readLedger(ctx.home).filter((e) => !only || e.intent.toLowerCase() === only);
  if (!events.length) { ctx.out('No adoption events.\n'); return 0; }
  for (const e of events) {
    ctx.out(`${e.ts}  ${pad(e.intent, 12)}  ${pad(e.id, 28)}  ${pad(e.kind || '-', 5)}  ${pad(e.verdict, 6)}  ${e.evidence || ''}\n`);
  }
  return 0;
}

function list(args, ctx) {
  const at = args.indexOf('--intent');
  const only = at >= 0 ? String(args[at + 1] || '').toLowerCase() : '';
  if (args.includes('--events')) return listEvents(only, ctx);
  const pins = store.readPins(ctx.home);
  const isPinned = (id, intent) => pins.some((p) => p.id === id && p.intent === intent);
  const rows = [...store.summarize(store.readLedger(ctx.home), ctx.now).values()];
  for (const p of pins) {
    if (!rows.some((r) => r.id === p.id && r.intent === p.intent)) {
      rows.push({ id: p.id, kind: '', intent: p.intent, accept: 0, reject: 0, n: 0, accepted: 0, total: 0 });
    }
  }
  const shown = rows
    .filter((r) => !only || r.intent.toLowerCase() === only)
    .sort((a, b) => a.intent.localeCompare(b.intent) || b.n - a.n || a.id.localeCompare(b.id));
  if (!shown.length) {
    ctx.out(only ? `No adoption events for intent ${args[at + 1]}.\n` : 'No adoption events yet.\n');
    return 0;
  }
  const idWidth = Math.max(2, ...shown.map((r) => r.id.length));
  const intentWidth = Math.max(6, ...shown.map((r) => r.intent.length));
  const num = (x) => pad(x.toFixed(1), 7);
  ctx.out(`${pad('INTENT', intentWidth)}  ${pad('ID', idWidth)}  ${pad('KIND', 5)}  ACCEPT  REJECT  N       RATE  RAW    ACTIVE  PIN\n`);
  for (const r of shown) {
    const rate = r.n > 0 ? `${Math.round((r.accept / r.n) * 100)}%` : '-';
    const active = store.SAFETY_INTENTS.has(r.intent) ? 'safety' : store.isActive(r) ? 'yes' : 'no';
    ctx.out(`${pad(r.intent, intentWidth)}  ${pad(r.id, idWidth)}  ${pad(r.kind || '-', 5)}  ${num(r.accept)} ${num(r.reject)} ${num(r.n)} ${pad(rate, 5)} ${pad(`${r.accepted}/${r.total}`, 6)} ${pad(active, 7)} ${isPinned(r.id, r.intent) ? 'pinned' : ''}`.trimEnd() + '\n');
  }
  ctx.out(`(decayed weights: 90-day half-life, 180-day window; ranking uses a row once N >= ${store.MIN_EFFECTIVE_N})\n`);
  return 0;
}

function pinArgs(args, ctx) {
  const [id, rawIntent] = args;
  if (!id || !rawIntent) { ctx.out(USAGE); return null; }
  const intent = canonicalIntent(rawIntent);
  if (!intent) {
    ctx.out(`Unknown intent: ${rawIntent}. Known: ${intentNames().join(', ')}\n`);
    return null;
  }
  return { id, intent };
}

function pin(args, ctx) {
  const a = pinArgs(args, ctx);
  if (!a) return 1;
  if (store.SAFETY_INTENTS.has(a.intent)) {
    ctx.out(`${a.intent} is a safety intent: its order is fixed by routing-map.json and ignores pins.\n`);
    return 1;
  }
  const pins = store.readPins(ctx.home);
  if (pins.some((p) => p.id === a.id && p.intent === a.intent)) {
    ctx.out(`Already pinned: ${a.id} for ${a.intent}.\n`);
    return 0;
  }
  store.writeJson(store.storePaths(ctx.home).pins, [...pins, { id: a.id, intent: a.intent, ts: new Date(ctx.now).toISOString() }]);
  store.audit(ctx.home, 'pin', { id: a.id, intent: a.intent });
  ctx.out(`Pinned ${a.id} to the top of ${a.intent}.\n`);
  return 0;
}

function unpin(args, ctx) {
  const pins = store.readPins(ctx.home);
  // A pin whose intent has since left the routing map must still be removable.
  const stored = pins.find((p) => p.id === args[0] && p.intent.toLowerCase() === String(args[1] || '').toLowerCase());
  const a = stored ? { id: stored.id, intent: stored.intent } : pinArgs(args, ctx);
  if (!a) return 1;
  const kept = pins.filter((p) => !(p.id === a.id && p.intent === a.intent));
  if (kept.length === pins.length) {
    ctx.out(`Not pinned: ${a.id} for ${a.intent}.\n`);
    return 1;
  }
  store.writeJson(store.storePaths(ctx.home).pins, kept);
  store.audit(ctx.home, 'unpin', { id: a.id, intent: a.intent });
  ctx.out(`Unpinned ${a.id} from ${a.intent}.\n`);
  return 0;
}

function sizeOf(file) {
  try { return fs.statSync(file).size; } catch { return 0; }
}

// Move the events `pick` selects from the ledger to the archive. If a verdict
// hook appended meanwhile, start over rather than overwrite its event.
function archive(ctx, pick, reason) {
  const paths = store.storePaths(ctx.home);
  for (let attempt = 0; attempt < ARCHIVE_ATTEMPTS; attempt++) {
    const size = sizeOf(paths.ledger);
    const events = store.readJsonl(paths.ledger);
    const moved = events.filter(pick);
    if (!moved.length) return moved;
    if (sizeOf(paths.ledger) !== size) continue;
    const archivedAt = new Date(ctx.now).toISOString();
    store.appendJsonl(paths.archive, moved.map((e) => Object.assign({}, e, { archived_at: archivedAt, archive_reason: reason })));
    store.writeJsonl(paths.ledger, events.filter((e) => !moved.includes(e)));
    return moved;
  }
  throw new Error('adoption ledger kept changing; try again');
}

function reset(args, ctx) {
  const id = args[0] || null;
  const moved = archive(ctx, (e) => !id || e.id === id, id ? `reset ${id}` : 'reset');
  store.audit(ctx.home, 'reset', { id, count: moved.length });
  ctx.out(`Archived ${moved.length} event(s)${id ? ` for ${id}` : ''} to ${store.storePaths(ctx.home).archive}.\n`);
  return 0;
}

function undo(args, ctx) {
  const [ts, id] = args;
  if (!ts) { ctx.out(USAGE); return 1; }
  const pick = (e) => e.ts === ts && (!id || e.id === id);
  const matches = store.readJsonl(store.storePaths(ctx.home).ledger).filter(pick);
  if (!matches.length) {
    ctx.out(`No event with ts ${ts}${id ? ` and id ${id}` : ''}.\n`);
    return 1;
  }
  if (matches.length > 1) {
    ctx.out(`${matches.length} events share ts ${ts} (one reply judges every offer of a turn); add the id: ${matches.map((e) => e.id).join(', ')}\n`);
    return 1;
  }
  const target = matches[0];
  archive(ctx, pick, 'undo');
  store.audit(ctx.home, 'undo', { id: target.id, intent: target.intent, event_ts: ts, count: 1 });
  ctx.out(`Archived 1 event: ${target.id} ${target.intent} ${target.verdict} (${ts}).\n`);
  return 0;
}

const COMMANDS = { list, pin, unpin, reset, undo };

// Returns the process exit code. opts (tests): {home, now, out}.
function main(argv, opts) {
  const o = opts || {};
  const ctx = { home: o.home || null, now: o.now || Date.now(), out: o.out || ((s) => process.stdout.write(s)) };
  const cmd = COMMANDS[argv[0]];
  if (!cmd) { ctx.out(USAGE); return argv[0] ? 1 : 0; }
  try {
    return cmd(argv.slice(1), ctx);
  } catch (e) {
    ctx.out(`adoption ${argv[0]} failed: ${e.message}\n`);
    return 1;
  }
}

module.exports = { main };

if (require.main === module) process.exitCode = main(process.argv.slice(2));
