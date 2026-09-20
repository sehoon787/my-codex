#!/usr/bin/env node
// Unit tests for hooks/stop-final-report.js — runs the hook against a fake
// .briefing vault and fake Codex rollout transcripts.
// `node tests/stop-final-report.test.js`
//
// Codex rollout (.jsonl) record shapes these fixtures mirror, observed on
// codex-cli 0.153.4 in ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl:
//
//   turn start (every turn, whatever triggered it):
//     {"timestamp":"…","ordinal":1,"type":"event_msg",
//      "payload":{"type":"task_started","turn_id":"01a05ce8-…","started_at":…}}
//
//   the human prompt (the only reliable "a user started this turn" marker;
//   role:"user" response_item records also carry harness-injected text such
//   as <recommended_plugins>, so they are NOT used):
//     {"…","type":"event_msg","payload":{"type":"item_completed",
//      "turn_id":"01a05ce8-…","item":{"type":"UserMessage",
//      "content":[{"type":"text","text":"do x","text_elements":[]}]}}}
//
//   a tool call (name is what identifies subagent launches; the observed
//   collaboration-namespace names are spawn_agent / wait_agent / list_agents /
//   interrupt_agent, plus exec_command for shell):
//     {"…","type":"response_item","payload":{"type":"function_call",
//      "id":"fc_…","name":"spawn_agent","namespace":"collaboration",
//      "arguments":"{\"agent_type\":\"boss\",…}","call_id":"call_…"}}
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.resolve(__dirname, '..', 'hooks', 'stop-final-report.js');
const NO_REPORT = '\uC791\uC5C5\uC744 \uB9C8\uCCE4\uC2B5\uB2C8\uB2E4. \uACB0\uACFC\uAC00 \uC624\uBA74 \uC774\uC5B4\uC11C \uC9C4\uD589\uD558\uACA0\uC2B5\uB2C8\uB2E4.';
const REPORT_EN = 'Done.\n\n## Work summary\n\n| Item | Result | Evidence |\n|---|---|---|\n| a | b | c |\n';
const REPORT_KO = '\uC644\uB8CC.\n\n## \uC791\uC5C5 \uC694\uC57D\n\n| \uD56D\uBAA9 | \uACB0\uACFC | \uADFC\uAC70 |\n|---|---|---|\n| a | b | c |\n';

const started = (turnId) => ({ timestamp: 't', type: 'event_msg', payload: { type: 'task_started', turn_id: turnId, started_at: 1 } });
const user = (turnId, text) => ({ timestamp: 't', type: 'event_msg', payload: { type: 'item_completed', turn_id: turnId, item: { type: 'UserMessage', id: 'i1', content: [{ type: 'text', text, text_elements: [] }] } } });
const call = (turnId, name) => ({ timestamp: 't', type: 'response_item', payload: { type: 'function_call', id: 'fc_1', name, namespace: 'collaboration', arguments: '{}', call_id: 'call_1', internal_chat_message_metadata_passthrough: { turn_id: turnId } } });
const asst = (turnId, text) => ({ timestamp: 't', type: 'event_msg', payload: { type: 'item_completed', turn_id: turnId, item: { type: 'AgentMessage', id: 'm1', content: [{ type: 'Text', text }] } } });

function run(name, opts, expect) {
  const {
    entries, lam, workCounter = 5, acked = 0, blockedTurnId,
    turnId = 't1', stopHookActive = false, transcript = 'jsonl', language = 'ko'
  } = opts;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfr-'));
  fs.mkdirSync(path.join(dir, '.briefing'));
  fs.writeFileSync(path.join(dir, '.briefing', 'INDEX.md'), `---\nlanguage: ${language}\n---\n# x\n`);
  fs.writeFileSync(path.join(dir, '.briefing', 'state.json'), JSON.stringify({ workCounter, finalReport: { ackWorkCounter: acked, blockedTurnId } }));

  let tp = null;
  if (transcript === 'jsonl') {
    tp = path.join(dir, 'rollout.jsonl');
    fs.writeFileSync(tp, (entries || []).map((e) => JSON.stringify(e)).join('\n') + '\n');
  } else if (transcript === 'garbage') {
    tp = path.join(dir, 'rollout.jsonl');
    fs.writeFileSync(tp, 'not json at all\n{{{ broken\n');
  } else if (transcript === 'missing') {
    tp = path.join(dir, 'does-not-exist.jsonl');
  }

  const payload = {
    session_id: 's1', turn_id: turnId, transcript_path: tp, cwd: dir,
    hook_event_name: 'Stop', model: 'm', permission_mode: 'auto',
    stop_hook_active: stopHookActive, last_assistant_message: lam
  };
  const out = cp.spawnSync('node', [HOOK], { cwd: dir, input: JSON.stringify(payload), encoding: 'utf8' });
  const blocked = /"decision":"block"/.test(out.stdout);
  const reason = blocked ? JSON.parse(out.stdout).reason || '' : '';
  const hasReason = !!reason.length;
  const state = JSON.parse(fs.readFileSync(path.join(dir, '.briefing', 'state.json'), 'utf8'));
  const ack = (state.finalReport || {}).ackWorkCounter || 0;
  const ok = blocked === expect.blocked
    && (expect.ack === undefined || ack === expect.ack)
    && (expect.reason === undefined || hasReason === expect.reason)
    && (expect.englishReason === undefined || (/[\uac00-\ud7a3]/.test(reason) === !expect.englishReason))
    && (expect.silent === undefined || (out.stdout === '') === expect.silent);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}  (blocked=${blocked}, ack=${ack})`);
  fs.rmSync(dir, { recursive: true, force: true });
  return ok;
}

const turn = (id, text) => [started(id), user(id, text)];

const results = [
  run('1. human turn, work, no report → block once with a reason',
    { entries: [...turn('t1', 'do x'), call('t1', 'exec_command'), asst('t1', 'ok')], lam: NO_REPORT, language: 'ko' },
    { blocked: true, ack: 0, reason: true, englishReason: true }),

  run('1b. kr vault locale also emits English enforcement instructions',
    { entries: [...turn('t1', 'do x'), asst('t1', 'ok')], lam: NO_REPORT, language: 'kr' },
    { blocked: true, ack: 0, englishReason: true }),

  run('2. report present (English headers) → pass + ack',
    { entries: [...turn('t1', 'do x'), asst('t1', 'ok')], lam: REPORT_EN },
    { blocked: false, ack: 5 }),

  run('2b. report present (Korean table header) → pass + ack',
    { entries: [...turn('t1', 'do x'), asst('t1', 'ok')], lam: REPORT_KO },
    { blocked: false, ack: 5 }),

  run('3. no new work → pass, no output',
    { entries: [...turn('t1', 'hi'), asst('t1', 'ok')], lam: NO_REPORT, workCounter: 5, acked: 5 },
    { blocked: false, ack: 5, silent: true }),

  run('4. stop_hook_active=true → pass even with work pending',
    { entries: [...turn('t1', 'do x'), asst('t1', 'ok')], lam: NO_REPORT, stopHookActive: true },
    { blocked: false, ack: 0, silent: true }),

  run('5. second Stop for the same turn_id (loop guard) → pass + ack',
    { entries: [...turn('t1', 'do x'), asst('t1', 'ok')], lam: NO_REPORT, blockedTurnId: 't1' },
    { blocked: false, ack: 5 }),

  run('6. missing transcript → block (parity with my-claude)',
    { lam: NO_REPORT, transcript: 'missing' },
    { blocked: true }),

  run('7. current turn contains a spawn_agent call → pass (mid-request)',
    { entries: [...turn('t1', 'do x'), call('t1', 'spawn_agent'), call('t1', 'wait_agent'), asst('t1', 'ok')], lam: NO_REPORT },
    { blocked: false, ack: 0 }),

  run('7b. spawn_agent in a PREVIOUS turn only → block',
    { entries: [...turn('t1', 'do x'), call('t1', 'spawn_agent'), asst('t1', 'ok'), ...turn('t2', 'now y'), asst('t2', 'ok')], lam: NO_REPORT, turnId: 't2' },
    { blocked: true, ack: 0 }),

  run('8. transcript exists but is unparseable → pass (fail open)',
    { lam: NO_REPORT, transcript: 'garbage' },
    { blocked: false, ack: 0, silent: true }),

  run('9. normal user turn, no agent calls → block',
    { entries: [...turn('t1', 'do x'), call('t1', 'exec_command'), asst('t1', 'ok')], lam: NO_REPORT },
    { blocked: true, ack: 0 }),

  // Observed in real rollouts: a spawned subagent's own session has no
  // UserMessage item — its turn was started by the parent, so it is never
  // the end of a human request.
  run('9b. turn with no UserMessage (subagent session) → pass',
    { entries: [started('t1'), call('t1', 'exec_command'), asst('t1', 'ok')], lam: NO_REPORT },
    { blocked: false, ack: 0, silent: true }),
];
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
