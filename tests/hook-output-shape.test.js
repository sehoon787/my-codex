#!/usr/bin/env node
// Regression test for the bug that made Codex reject this repo's hook stdout.
//
// Codex 0.153.x deserializes SessionStart hook output with
// #[serde(deny_unknown_fields)] into
//   SessionStartHookSpecificOutputWire { hook_event_name (REQUIRED), additional_context }
// (codex-rs/hooks/src/schema.rs). hooks/session-start.sh emitted
// hookSpecificOutput WITHOUT hookEventName, so every `codex exec` printed
// "hook: SessionStart Failed" and the context was silently dropped.
//
// For every hook command in hooks/hooks.json that can write stdout, this runs
// the real script against a temp project and a synthetic (never real) $HOME and
// asserts stdout is either empty or exactly one JSON document, and that any
// hookSpecificOutput carries the hookEventName of the firing event.
//
// `node tests/hook-output-shape.test.js`
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const hooksJson = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'hooks', 'hooks.json'), 'utf8'));

const results = [];
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  (' + detail + ')' : ''}`);
  results.push(ok);
  return ok;
}

// Locate a hook's raw command in hooks.json so this test stays tied to the real
// file instead of a hand-copied duplicate.
function findCommand(event, substr) {
  for (const group of hooksJson.hooks[event] || []) {
    for (const hook of group.hooks || []) {
      if ((hook.command && hook.command.includes(substr)) ||
          (hook.description && hook.description.includes(substr))) {
        return hook.command;
      }
    }
  }
  throw new Error(`no ${event} command/description containing: ${substr}`);
}

function tmpProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-hook-shape-'));
  fs.mkdirSync(path.join(dir, '.briefing', 'sessions'), { recursive: true });
  fs.mkdirSync(path.join(dir, '.briefing', 'decisions'), { recursive: true });
  fs.mkdirSync(path.join(dir, '.briefing', 'learnings'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.briefing', 'INDEX.md'), '---\nlanguage: en\n---\n# x\n');
  return dir;
}

function writeState(dir, state) {
  fs.writeFileSync(path.join(dir, '.briefing', 'state.json'), JSON.stringify(state || {}));
}

// A fresh, never-real $HOME so nothing here can touch the developer's actual
// ~/.codex, and a bin dir whose shims make every network path a no-op even if
// one of session-start.sh's own guards regresses.
const FAKE_HOME = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-hook-home-'));
const SHIM_DIR = path.join(FAKE_HOME, 'shim');
fs.mkdirSync(path.join(FAKE_HOME, '.codex', 'hooks'), { recursive: true });
fs.mkdirSync(SHIM_DIR, { recursive: true });
for (const name of ['git', 'npm', 'ast-grep']) {
  fs.writeFileSync(path.join(SHIM_DIR, name), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
}
// Guards that keep session-start.sh offline: skills are "managed", and the
// once-a-day version check already ran today.
fs.writeFileSync(path.join(FAKE_HOME, '.codex', '.skills-managed'), '');
fs.writeFileSync(
  path.join(FAKE_HOME, '.codex', '.my-codex-update-check'),
  new Date().toLocaleDateString('en-CA') + '\n'
);

function baseEnv(extra) {
  return Object.assign({}, process.env, {
    HOME: FAKE_HOME,
    USERPROFILE: FAKE_HOME,
    PATH: SHIM_DIR + path.delimiter + process.env.PATH
  }, extra || {});
}

// Run a `node|bash "$HOME/.codex/hooks/X" [arg]` command against THIS repo's
// copy of X, not whatever happens to be installed on the machine.
function runResolvedFile(rawCommand, opts) {
  const m = rawCommand.match(/\$HOME\/\.codex\/hooks\/([\w.-]+)"?(?:\s+(\w+))?/);
  if (!m) throw new Error('cannot resolve path from: ' + rawCommand);
  const resolved = path.join(REPO_ROOT, 'hooks', m[1]);
  const bin = resolved.endsWith('.sh') ? 'bash' : 'node';
  return cp.spawnSync(bin, [resolved, ...(m[2] ? [m[2]] : [])], {
    cwd: opts.cwd, input: opts.input || '', encoding: 'utf8', env: baseEnv(opts.env)
  });
}

// Run an inline `node -e "..."` command exactly as extracted from hooks.json.
function runInlineNodeE(rawCommand, opts) {
  const m = rawCommand.match(/node -e "([\s\S]*)"$/);
  if (!m) throw new Error('not an inline node -e command: ' + rawCommand);
  return cp.spawnSync('node', ['-e', m[1].replace(/\\"/g, '"')], {
    cwd: opts.cwd, input: opts.input || '{}', encoding: 'utf8', env: baseEnv(opts.env)
  });
}

function runViaBash(rawCommand, opts) {
  return cp.spawnSync('bash', ['-c', rawCommand], {
    cwd: opts.cwd, input: opts.input || '{}', encoding: 'utf8', env: baseEnv(opts.env)
  });
}

// The core assertion: empty stdout, or exactly one JSON document whose
// hookSpecificOutput (if any) names the event that fired it.
function assertShape(label, event, result) {
  const trimmed = (result.stdout || '').trim();
  if (trimmed === '') {
    check(`${label} -> empty stdout ok`, true);
    return;
  }
  const lines = trimmed.split('\n').filter(Boolean);
  let parsed = null, parseOk = true;
  try { parsed = JSON.parse(trimmed); } catch (e) { parseOk = false; }
  const singleDoc = lines.length === 1 && parseOk;
  check(`${label} -> single JSON document`, singleDoc, `stdout=${JSON.stringify(result.stdout)}`);
  if (singleDoc && parsed && parsed.hookSpecificOutput) {
    check(
      `${label} -> hookEventName === ${event}`,
      parsed.hookSpecificOutput.hookEventName === event,
      `got ${JSON.stringify(parsed.hookSpecificOutput.hookEventName)}`
    );
  }
}

// ---------------------------------------------------------------- SessionStart

const SESSION_START_CMD = findCommand('SessionStart', 'session-start.sh');

{
  // The historical repro: session-start.sh always emits a registry-cache line,
  // so hookSpecificOutput is always produced on this path.
  const dir = tmpProject();
  const r = runResolvedFile(SESSION_START_CMD, {
    cwd: dir,
    input: JSON.stringify({ hook_event_name: 'SessionStart', session_id: 't', cwd: dir, source: 'startup' })
  });
  assertShape('SessionStart session-start.sh', 'SessionStart', r);
  check(
    'SessionStart session-start.sh -> emits additionalContext',
    /"additionalContext"/.test(r.stdout || ''),
    `stdout=${JSON.stringify((r.stdout || '').slice(0, 120))}`
  );
  fs.rmSync(dir, { recursive: true, force: true });
}

{
  // session-start.sh splices other hooks' stdout into the JSON string. A helper
  // that emits newlines, double quotes or backslashes (session-start-state.js
  // writes a two-line message whenever it reports a session gap) must not be
  // able to break the single JSON document.
  const dir = tmpProject();
  const helper = path.join(FAKE_HOME, '.codex', 'hooks', 'session-start-state.js');
  fs.writeFileSync(helper,
    'process.stdout.write(\'[BriefingVault] line one "quoted" C:\\\\path\\n[BriefingVault] line two\');\n');
  const r = runResolvedFile(SESSION_START_CMD, {
    cwd: dir,
    input: JSON.stringify({ hook_event_name: 'SessionStart', session_id: 't', cwd: dir, source: 'startup' })
  });
  assertShape('SessionStart with multi-line/quoted helper output', 'SessionStart', r);
  fs.unlinkSync(helper);
  fs.rmSync(dir, { recursive: true, force: true });
}

// ---------------------------------------------------------------- PreToolUse

{
  const dir = tmpProject();
  fs.writeFileSync(path.join(FAKE_HOME, '.codex', '.boss-mode'), '');
  const r = runInlineNodeE(findCommand('PreToolUse', 'BOSS PROTOCOL'), { cwd: dir, input: '{}' });
  assertShape('PreToolUse boss-mode guard (boss mode on)', 'PreToolUse', r);
  check(
    'PreToolUse boss-mode guard -> actually emitted output',
    /"hookSpecificOutput"/.test(r.stdout || ''),
    `stdout=${JSON.stringify(r.stdout)}`
  );
  fs.unlinkSync(path.join(FAKE_HOME, '.codex', '.boss-mode'));
  fs.rmSync(dir, { recursive: true, force: true });
}

// ---------------------------------------------------------------- PostToolUse

{
  const dir = tmpProject();
  const r = runViaBash(findCommand('PostToolUse', 'gstack/analytics'), {
    cwd: dir, input: JSON.stringify({ tool_input: { name: 'executor', model: 'sonnet' } })
  });
  assertShape('PostToolUse Agent analytics logger', 'PostToolUse', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

for (const [mode, input] of [['edit', '{}'], ['search', JSON.stringify({ tool_input: { url: 'https://example.com' } })]]) {
  const dir = tmpProject();
  writeState(dir, { editCount: 9, searchCount: 9, workCounter: 9 });
  const r = runResolvedFile(findCommand('PostToolUse', `session-sync.js" ${mode}`), { cwd: dir, input });
  assertShape(`PostToolUse session-sync.js ${mode}`, 'PostToolUse', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

// ---------------------------------------------------------------- SubagentStop

{
  const dir = tmpProject();
  const r = runInlineNodeE(findCommand('SubagentStop', 'agent-log.jsonl'), {
    cwd: dir, input: JSON.stringify({ agent_id: 'a1', agent_type: 'executor' })
  });
  assertShape('SubagentStop agent-log writer', 'SubagentStop', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

{
  const dir = tmpProject();
  writeState(dir, { subagentCount: 9, workCounter: 9 });
  const r = runResolvedFile(findCommand('SubagentStop', 'session-sync.js" subagent'), { cwd: dir, input: '{}' });
  assertShape('SubagentStop session-sync.js subagent', 'SubagentStop', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

// ---------------------------------------------------------------- PostCompact

{
  const dir = tmpProject();
  writeState(dir, { promptCount: 40 });
  const r = runResolvedFile(findCommand('PostCompact', 'session-sync.js" compact'), { cwd: dir, input: '{}' });
  assertShape('PostCompact session-sync.js compact', 'PostCompact', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

// ---------------------------------------------------------------- UserPromptSubmit

{
  // The reminder branch: enough prompts and work to make session-sync speak up.
  const dir = tmpProject();
  writeState(dir, { promptCount: 5, workCounter: 5, sessionMessageCount: 5, lastVaultSync: '' });
  const r = runResolvedFile(findCommand('UserPromptSubmit', 'session-sync.js" prompt'), {
    cwd: dir, input: '{}', env: { MY_CODEX_COMPACT_EVERY: '1' }
  });
  assertShape('UserPromptSubmit session-sync.js prompt (reminder)', 'UserPromptSubmit', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

// ---------------------------------------------------------------- Stop

{
  const dir = tmpProject();
  const r = runResolvedFile(findCommand('Stop', 'stop-profile-update.js'), { cwd: dir, input: '{}' });
  assertShape('Stop stop-profile-update.js', 'Stop', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

{
  const dir = tmpProject();
  writeState(dir, { workCounter: 5, sessionMessageCount: 5 });
  const r = runResolvedFile(findCommand('Stop', 'stop-session-enforcement.js'), { cwd: dir, input: '{}' });
  assertShape('Stop stop-session-enforcement.js (blocks)', 'Stop', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

{
  const dir = tmpProject();
  writeState(dir, { workCounter: 5, finalReport: { ackWorkCounter: 0 } });
  fs.writeFileSync(path.join(dir, 't.jsonl'), '\n');
  const r = runResolvedFile(findCommand('Stop', 'stop-final-report.js'), {
    cwd: dir,
    input: JSON.stringify({
      hook_event_name: 'Stop',
      prompt_id: 'p1',
      transcript_path: path.join(dir, 't.jsonl'),
      last_assistant_message: 'Done, no report table here.'
    })
  });
  assertShape('Stop stop-final-report.js (blocks)', 'Stop', r);
  fs.rmSync(dir, { recursive: true, force: true });
}

// ------- static sweep: no shipped hook may emit hookSpecificOutput without
// ------- naming its event, wherever that JSON is assembled.

{
  const offenders = [];
  const hookFiles = fs.readdirSync(path.join(REPO_ROOT, 'hooks'))
    .filter((f) => f.endsWith('.js') || f.endsWith('.sh'));
  for (const file of hookFiles) {
    const src = fs.readFileSync(path.join(REPO_ROOT, 'hooks', file), 'utf8');
    if (src.includes('hookSpecificOutput') && !src.includes('hookEventName')) offenders.push(file);
  }
  for (const [event, groups] of Object.entries(hooksJson.hooks)) {
    for (const group of groups) {
      for (const hook of group.hooks || []) {
        const cmd = hook.command || '';
        if (cmd.includes('hookSpecificOutput') && !cmd.includes(`hookEventName:'${event}'`) &&
            !cmd.includes(`hookEventName: '${event}'`) && !cmd.includes(`"hookEventName":"${event}"`)) {
          offenders.push(`hooks.json ${event}`);
        }
      }
    }
  }
  check('every hookSpecificOutput producer names its hookEventName', offenders.length === 0, offenders.join(', '));
}

fs.rmSync(FAKE_HOME, { recursive: true, force: true });

const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
