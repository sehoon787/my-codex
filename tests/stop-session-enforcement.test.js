#!/usr/bin/env node
// Unit tests for hooks/stop-session-enforcement.js — ported from my-claude's
// hooks/stop-session-enforcement.js, which added two safeguards this file's
// older port lacked:
//
//   1. Cooldown: block at most once every 30 minutes (state.lastBlockedAt).
//   2. When a session summary exists for today but boss-briefing was not
//      run, pass silently AND auto-set state.lastVaultSync so later Stop
//      calls this session don't block again.
//
// Observed regression (real `codex exec` run, no cooldown/auto-sync ported):
// the model's first answer already had the required final-report table,
// but this hook still returned {"decision":"block"} every Stop once
// workCounter/sessionMessageCount crossed the threshold, so the model kept
// running /boss-briefing and its "Vault sync completed" message displaced
// the real task report.
//
// `node tests/stop-session-enforcement.test.js`
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.resolve(__dirname, '..', 'hooks', 'stop-session-enforcement.js');

function tmpDir(state, sessionFile) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sse-'));
  fs.mkdirSync(path.join(dir, '.briefing', 'sessions'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.briefing', 'INDEX.md'), '---\nlanguage: en\n---\n# x\n');
  fs.writeFileSync(path.join(dir, '.briefing', 'state.json'), JSON.stringify(state));
  if (sessionFile) {
    const today = new Date().toISOString().slice(0, 10);
    fs.writeFileSync(path.join(dir, '.briefing', 'sessions', `${today}-topic.md`), '# session\n');
  }
  return dir;
}

// Codex-shaped Stop payload; this hook does not read stdin, but every Stop
// consumer in hooks/hooks.json is exercised with a realistic payload so a
// future stdin dependency is caught here too.
function stopPayload(extra) {
  return JSON.stringify(Object.assign({
    session_id: 's1', turn_id: 't1', transcript_path: null, cwd: '.',
    hook_event_name: 'Stop', model: 'm', permission_mode: 'auto',
    stop_hook_active: false, last_assistant_message: 'Done.'
  }, extra || {}));
}

function readState(dir) {
  return JSON.parse(fs.readFileSync(path.join(dir, '.briefing', 'state.json'), 'utf8'));
}

function runHook(dir, input) {
  return cp.spawnSync('node', [HOOK], { cwd: dir, input: input || stopPayload(), encoding: 'utf8' });
}

// Single-JSON-doc-or-empty-stdout shape check, matching what every Stop
// hook consumer in hooks/hooks.json expects (see hook-output-shape.test.js).
function assertShape(out) {
  const trimmed = out.stdout.trim();
  if (trimmed === '') return { blocked: false, doc: null, docCount: 0 };
  let docCount = 0, doc = null;
  try {
    doc = JSON.parse(trimmed);
    docCount = 1;
  } catch (e) {
    docCount = trimmed.split('\n').filter(Boolean).length; // definitely not 1 valid doc
  }
  return { blocked: docCount === 1 && doc && doc.decision === 'block', doc, docCount };
}

const results = [];
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  (' + detail + ')' : ''}`);
  results.push(ok);
}

// --- Scenario A: cooldown ---------------------------------------------
// No session file for today → meaningful work + no vault sync → blocks.
// The immediate next Stop, still with no lastVaultSync, must NOT block
// again because it's inside the 30-minute cooldown window.
{
  const dir = tmpDir({ workCounter: 5, sessionMessageCount: 5 }, false);

  const first = runHook(dir);
  const firstShape = assertShape(first);
  const s1 = readState(dir);
  check('A1. first run with meaningful work, no session, no sync → blocks with exactly one JSON doc',
    firstShape.docCount <= 1 && firstShape.blocked === true, `stdout=${JSON.stringify(first.stdout)}`);
  check('A2. first block writes lastBlockedAt', !!s1.lastBlockedAt);

  const second = runHook(dir);
  const secondShape = assertShape(second);
  check('A3. second run immediately after (cooldown) → does not block',
    secondShape.blocked === false && secondShape.docCount <= 1, `stdout=${JSON.stringify(second.stdout)}`);
  check('A4. second run output is empty or a single non-block JSON doc',
    second.stdout.trim() === '' || (secondShape.doc && secondShape.doc.decision !== 'block'));

  fs.rmSync(dir, { recursive: true, force: true });
}

// --- Scenario B: session-exists auto-sync -------------------------------
// A session summary for today exists (boss-briefing wasn't run, but the
// session-end note was written) → pass silently AND auto-set
// lastVaultSync so this doesn't block on the next Stop either.
{
  const dir = tmpDir({ workCounter: 5, sessionMessageCount: 5 }, true);

  const out = runHook(dir);
  const shape = assertShape(out);
  check('B1. session exists, no sync → passes (no block)', shape.blocked === false);
  check('B2. output is empty or a single valid JSON doc', shape.docCount <= 1);

  const s = readState(dir);
  check('B3. auto-sets lastVaultSync so future Stops this session pass', !!s.lastVaultSync);

  const again = runHook(dir);
  const againShape = assertShape(again);
  check('B4. next Stop (lastVaultSync now set today) → passes again', againShape.blocked === false);

  fs.rmSync(dir, { recursive: true, force: true });
}

const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
