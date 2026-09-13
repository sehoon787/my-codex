#!/usr/bin/env node
// Regression guard: hooks/hooks.json must not carry leader-facing
// additionalContext hooks on SubagentStop, TeammateIdle, or TaskCompleted.
// Those events fire in the STOPPING subagent's own turn (not the leader's),
// so any additionalContext they emit re-prompts the subagent itself instead
// of informing the leader — see sehoon787/my-claude#214 for the mirrored
// bug (26-82 re-prompts per subagent, 18 empty turns from a no-op agent).
// Stop is included too since it is the analogous leader-facing event for
// the session as a whole.
// `node tests/hooks-no-self-context.test.js`
'use strict';
const fs = require('fs');
const path = require('path');

const HOOKS_PATH = path.resolve(__dirname, '..', 'hooks', 'hooks.json');
const WATCHED_EVENTS = ['SubagentStop', 'TeammateIdle', 'TaskCompleted', 'Stop'];

function run(name, fn) {
  let ok = false;
  let detail = '';
  try {
    ok = fn();
  } catch (err) {
    detail = ` (${err.message})`;
  }
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail}`);
  return ok;
}

const raw = fs.readFileSync(HOOKS_PATH, 'utf8');
const results = [];

results.push(run('1. hooks.json parses as valid JSON', () => {
  JSON.parse(raw);
  return true;
}));

const config = JSON.parse(raw);
const hooks = config.hooks || {};

results.push(run('2. TeammateIdle and TaskCompleted events are absent entirely', () => {
  return !('TeammateIdle' in hooks) && !('TaskCompleted' in hooks);
}));

for (const eventName of WATCHED_EVENTS) {
  results.push(run(`3. no ${eventName} hook command contains "additionalContext"`, () => {
    const matchers = hooks[eventName] || [];
    for (const matcher of matchers) {
      for (const hook of matcher.hooks || []) {
        if (typeof hook.command === 'string' && hook.command.includes('additionalContext')) {
          throw new Error(`found in command: ${hook.command.slice(0, 80)}…`);
        }
      }
    }
    return true;
  }));
}

const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
