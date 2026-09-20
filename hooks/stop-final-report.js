#!/usr/bin/env node
'use strict';
// stop-final-report.js — require a structured final report when a request ends.
//
// AGENTS.md (§ Final Report) defines WHAT the report looks like; this hook is
// the enforcement half: a prompt rule alone is advisory and the model can skip
// it, so the Stop hook checks the turn's actual final text and blocks once when
// the report is missing.
//
// Judgment inputs come straight from the Codex Stop payload:
//   - `last_assistant_message` is the final assistant text.
//   - "did work happen" is the delta of .briefing/state.json's workCounter
//     (incremented by the PostToolUse Edit|Write hook) since the last
//     acknowledged report, so a session-long counter doesn't re-trigger on
//     later chat-only turns.
//   - "is this the end of the request" comes from the rollout transcript: a
//     turn that launched subagent work (spawn_agent / wait_agent) is
//     mid-request by definition — the hook never blocks there; it only records
//     a report if one is present.
//
// Loop safety (there is no built-in circuit breaker for Stop blocks):
//   - blocks at most ONCE per turn_id, and never when `stop_hook_active` is
//     set (Codex's own re-entry flag for the retry Stop).
//   - fails open on any error — a broken hook must never trap the session.
try {
  var runtime = require('./briefing-runtime');
  var fs = require('fs');
  var path = require('path');

  var INDEX_FILE = path.join(runtime.BRIEFING_DIR, 'INDEX.md');
  if (!runtime.exists(INDEX_FILE)) { process.exit(0); }

  var input = {};
  try { input = JSON.parse(fs.readFileSync(0, 'utf8')); } catch (e) { process.exit(0); }

  var lam = input.last_assistant_message;
  if (typeof lam !== 'string' || lam.length === 0) { process.exit(0); }

  var turnId = String(input.turn_id || input.session_id || '');

  function saveFinalReport(update) {
    try {
      var s = runtime.readState();
      s.finalReport = Object.assign({}, s.finalReport || {}, update);
      runtime.writeState(s);
    } catch (e) {}
  }

  // Walk the rollout backwards to the record that started this turn.
  //   humanTurn         — the turn began with a UserMessage item.
  //   launchedBackground— a function_call in this turn launched subagent work.
  //   parsed            — at least one recognisable record was found; when the
  //                       file exists but is unreadable we fail open instead.
  function inspectTurn(transcriptPath) {
    var res = { humanTurn: true, launchedBackground: false, parsed: true };
    try {
      if (!transcriptPath || !runtime.exists(transcriptPath)) { return res; }
      var lines = fs.readFileSync(transcriptPath, 'utf8').split('\n');
      var agentCall = /^(spawn_agent|wait_agent)$/;
      var seen = false;
      res.humanTurn = false;
      for (var i = lines.length - 1; i >= 0; i--) {
        if (!lines[i]) { continue; }
        var r; try { r = JSON.parse(lines[i]); } catch (e) { continue; }
        var p = (r && r.payload) || {};
        if (typeof r.type !== 'string' || typeof p.type !== 'string') { continue; }
        seen = true;
        if (p.type === 'function_call' && agentCall.test(String(p.name || ''))) {
          res.launchedBackground = true;
          continue;
        }
        if (p.type === 'item_completed' && p.item && p.item.type === 'UserMessage') {
          res.humanTurn = true;
          break;
        }
        if (p.type === 'task_started') { break; }
      }
      res.parsed = seen;
    } catch (e) {}
    return res;
  }

  var state = runtime.readState();
  var wc = parseInt(state.workCounter, 10) || 0;
  var fr = state.finalReport || {};
  var acked = parseInt(fr.ackWorkCounter, 10) || 0;

  // No NEW work since the last acknowledged report → chat-only turn, pass.
  if (wc <= acked) { process.exit(0); }

  // Report present? Markdown table rows (at least a header + one data row)
  // or an explicit final-report heading — matching the AGENTS.md spec.
  var tableRows = (lam.match(/^\s*\|.*\|\s*$/gm) || []).length;
  var hasHeading = /(^|\n)#{1,4}\s*.{0,24}(\uCD5C\uC885 \uBCF4\uACE0|Final Report)/i.test(lam);
  if (tableRows >= 2 || hasHeading) {
    saveFinalReport({ ackWorkCounter: wc });
    process.exit(0);
  }

  // Codex already re-entered Stop after our block → let the turn end.
  if (input.stop_hook_active === true) { process.exit(0); }

  // Mid-request turn (subagent work just launched), or a transcript we cannot
  // read → never block; fail open.
  var turn = inspectTurn(input.transcript_path);
  if (!turn.parsed || !turn.humanTurn || turn.launchedBackground) { process.exit(0); }

  // Already blocked once this turn → give up gracefully (loop guard).
  if (turnId && fr.blockedTurnId === turnId) {
    saveFinalReport({ ackWorkCounter: wc });
    process.exit(0);
  }

  var reason = '[FinalReport] Work happened for this request but the final report is missing. End your reply with the FINAL REPORT spec from AGENTS.md: include only the applicable tables — Changes (Target/Before/After/Rationale), Work summary (Item/Result/Evidence), Verification (Item/Expected/Actual/Verdict), Deliverables (PR/Repo/Content/Status), Remaining (Item/Status/Next step). Match the user\'s language for the prose, table names, and headers. No empty tables.';

  saveFinalReport({ blockedTurnId: turnId });
  process.stdout.write(JSON.stringify({ decision: 'block', reason: reason }) + '\n');
  process.exit(0);
} catch (e) { process.exit(0); }
