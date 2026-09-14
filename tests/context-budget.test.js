#!/usr/bin/env node
// ContextBudget compaction reminder: hooks/session-sync.js must nudge toward
// /compact every MY_CODEX_COMPACT_EVERY prompts and reset that counter on the
// PostCompact hook. A long transcript is the largest fixed cost in every later
// request, so the nudge has to be periodic but never chatty.
// `node tests/context-budget.test.js`
'use strict';
const assert = require('assert');
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const SYNC = path.resolve(__dirname, '..', 'hooks', 'session-sync.js');

function makeWorkspace(withVault) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'my-codex-ctxbudget-'));
  if (withVault) {
    fs.mkdirSync(path.join(dir, '.briefing'), { recursive: true });
    fs.writeFileSync(path.join(dir, '.briefing', 'INDEX.md'), '---\nlanguage: en\n---\n');
  }
  return dir;
}

function writeState(dir, state) {
  fs.writeFileSync(
    path.join(dir, '.briefing', 'state.json'),
    JSON.stringify(Object.assign({ version: 2, sessionId: 'test:session' }, state), null, 2) + '\n'
  );
}

function readState(dir) {
  const file = path.join(dir, '.briefing', 'state.json');
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function runSync(dir, mode, every) {
  const result = cp.spawnSync(process.execPath, [SYNC, mode], {
    cwd: dir,
    input: '{}',
    encoding: 'utf8',
    env: Object.assign({}, process.env, {
      HOME: dir,                       // no ~/.codex hooks => scaffolds no-op
      USERPROFILE: dir,
      MY_CODEX_COMPACT_EVERY: String(every)
    })
  });
  return result.stdout || '';
}

function budgetLines(stdout) {
  return stdout
    .split('\n')
    .filter((line) => line.trim())
    .map((line) => JSON.parse(line))
    .map((payload) => (payload.hookSpecificOutput || {}).additionalContext || '')
    .join('\n')
    .split('\n')
    .filter((line) => line.startsWith('[ContextBudget]'));
}

function run(name, fn) {
  let ok = false;
  let detail = '';
  try {
    fn();
    ok = true;
  } catch (err) {
    detail = ` (${err.message})`;
  }
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail}`);
  return ok;
}

const results = [];

results.push(run('1. below threshold emits no ContextBudget line', () => {
  const dir = makeWorkspace(true);
  writeState(dir, { promptsSinceCompaction: 1 });
  const lines = budgetLines(runSync(dir, 'prompt', 5));
  assert.strictEqual(lines.length, 0, `expected none, got ${JSON.stringify(lines)}`);
  assert.strictEqual(readState(dir).promptsSinceCompaction, 2);
}));

results.push(run('2. at threshold emits exactly one ContextBudget line', () => {
  const dir = makeWorkspace(true);
  writeState(dir, { promptsSinceCompaction: 4 });
  const lines = budgetLines(runSync(dir, 'prompt', 5));
  assert.strictEqual(lines.length, 1, `expected 1, got ${JSON.stringify(lines)}`);
  assert.ok(lines[0].includes('5 prompts since the last compaction'), lines[0]);
  assert.ok(lines[0].includes('/compact'), lines[0]);
}));

results.push(run('3. PostCompact resets the counter and stays silent', () => {
  const dir = makeWorkspace(true);
  writeState(dir, { promptsSinceCompaction: 37 });
  const stdout = runSync(dir, 'compact', 5);
  assert.strictEqual(stdout.trim(), '', `expected no output, got ${stdout}`);
  assert.strictEqual(readState(dir).promptsSinceCompaction, 0);
}));

results.push(run('4. after a reset the next prompt is below threshold again', () => {
  const dir = makeWorkspace(true);
  writeState(dir, { promptsSinceCompaction: 4 });
  assert.strictEqual(budgetLines(runSync(dir, 'prompt', 5)).length, 1);
  runSync(dir, 'compact', 5);
  assert.strictEqual(budgetLines(runSync(dir, 'prompt', 5)).length, 0);
}));

results.push(run('5. no .briefing vault is a no-op for both modes', () => {
  const dir = makeWorkspace(false);
  assert.strictEqual(runSync(dir, 'prompt', 1).trim(), '');
  assert.strictEqual(runSync(dir, 'compact', 1).trim(), '');
  assert.ok(!fs.existsSync(path.join(dir, '.briefing')), '.briefing must not be created');
}));

results.push(run('6. hooks.json registers PostCompact against session-sync compact', () => {
  const hooks = JSON.parse(
    fs.readFileSync(path.resolve(__dirname, '..', 'hooks', 'hooks.json'), 'utf8')
  ).hooks || {};
  const entries = hooks.PostCompact || [];
  const commands = entries.flatMap((matcher) => (matcher.hooks || []).map((h) => h.command || ''));
  assert.ok(
    commands.some((c) => c.includes('session-sync.js') && /\bcompact\b/.test(c)),
    `PostCompact commands: ${JSON.stringify(commands)}`
  );
}));

results.push(run('7. ContextBudget line carries hookEventName UserPromptSubmit', () => {
  const dir = makeWorkspace(true);
  writeState(dir, { promptsSinceCompaction: 4 });
  const stdout = runSync(dir, 'prompt', 5);
  const lines = stdout.split('\n').filter((line) => line.trim());
  assert.strictEqual(lines.length, 1, `expected exactly one JSON document, got ${JSON.stringify(stdout)}`);
  const payload = JSON.parse(lines[0]);
  assert.strictEqual(
    payload.hookSpecificOutput.hookEventName,
    'UserPromptSubmit',
    `missing/wrong hookEventName: ${JSON.stringify(payload)}`
  );
}));

const failed = results.filter((ok) => !ok).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
