#!/usr/bin/env node
// Stop hook: enforce follow-up session summaries and learnings.
// Blocks session end if meaningful work happened but only the auto scaffolds exist.
'use strict';

try {
  var fs = require('fs');
  var path = require('path');

  var BRIEFING_DIR = '.briefing';
  var SESSIONS_DIR = path.join(BRIEFING_DIR, 'sessions');
  var LEARNINGS_DIR = path.join(BRIEFING_DIR, 'learnings');
  var INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');

  if (!fs.existsSync(INDEX_FILE)) {
    process.exit(0);
  }

  var todayStr = new Date().toISOString().slice(0, 10);

  var workCounter = 0;
  try {
    var wcPath = path.join(BRIEFING_DIR, '.work-counter');
    if (fs.existsSync(wcPath)) {
      workCounter = parseInt(fs.readFileSync(wcPath, 'utf8').trim(), 10) || 0;
    }
  } catch (e) {}

  var hasAgentActivity = false;
  try {
    var agentLogPath = path.join(BRIEFING_DIR, 'agents', 'agent-log.jsonl');
    if (fs.existsSync(agentLogPath)) {
      var logStat = fs.statSync(agentLogPath);
      if (logStat.mtime.toISOString().slice(0, 10) === todayStr) {
        hasAgentActivity = true;
      }
    }
  } catch (e) {}

  var hasUserMessages = false;
  try {
    var pucPath = path.join(BRIEFING_DIR, '.profile-update-counter');
    if (fs.existsSync(pucPath)) {
      var pucStat = fs.statSync(pucPath);
      if (pucStat.mtime.toISOString().slice(0, 10) === todayStr) {
        hasUserMessages = true;
      }
    }
  } catch (e) {}

  var hasMessageCount = false;
  try {
    var smcPath = path.join(BRIEFING_DIR, '.session-message-count');
    if (fs.existsSync(smcPath)) {
      var smcVal = parseInt(fs.readFileSync(smcPath, 'utf8').trim(), 10) || 0;
      if (smcVal > 0) {
        hasMessageCount = true;
      }
    }
  } catch (e) {}

  if (workCounter === 0 && !hasAgentActivity && !hasUserMessages && !hasMessageCount) {
    process.exit(0);
  }

  var lang = 'en';
  try {
    var indexContent = fs.readFileSync(INDEX_FILE, 'utf8');
    var langMatch = indexContent.match(/^language:\s*(\S+)/m);
    if (langMatch) {
      lang = langMatch[1].trim();
    }
  } catch (e) {}

  var isKo = (lang === 'ko' || lang === 'kr');

  var hasProperSummary = false;
  try {
    if (fs.existsSync(SESSIONS_DIR)) {
      var files = fs.readdirSync(SESSIONS_DIR);
      for (var i = 0; i < files.length; i++) {
        if (files[i].slice(0, 10) === todayStr && files[i].indexOf('-auto') === -1) {
          hasProperSummary = true;
          break;
        }
      }
    }
  } catch (e) {}

  var hasProperLearning = false;
  try {
    if (fs.existsSync(LEARNINGS_DIR)) {
      var learningFiles = fs.readdirSync(LEARNINGS_DIR);
      for (var j = 0; j < learningFiles.length; j++) {
        var lf = learningFiles[j];
        if (lf.slice(0, 10) === todayStr && lf.indexOf('-auto-session') === -1) {
          try {
            var lfStat = fs.statSync(path.join(LEARNINGS_DIR, lf));
            if (lfStat.mtime.toISOString().slice(0, 10) === todayStr) {
              hasProperLearning = true;
              break;
            }
          } catch (e) {}
        }
      }
    }
  } catch (e) {}

  if (!hasProperSummary) {
    var reason = isKo
      ? '[BriefingVault] ?몄뀡 ?붿빟 誘몄옉?? .briefing/sessions/' + todayStr + '-<topic>.md ?묒꽦 ?꾩슂.'
      : '[BriefingVault] No follow-up session summary. Write .briefing/sessions/' + todayStr + '-<topic>.md';

    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: reason
    }) + '\n');
    process.exit(0);
  }

  if (hasProperSummary && workCounter >= 5 && !hasProperLearning) {
    var learningReason = isKo
      ? '[BriefingVault] learning 誘몄옉??(' + workCounter + '媛??섏젙). .briefing/learnings/' + todayStr + '-<topic>.md ?묒꽦 ?꾩슂.'
      : '[BriefingVault] No follow-up learning (' + workCounter + ' edits). Write .briefing/learnings/' + todayStr + '-<topic>.md';

    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: learningReason
    }) + '\n');
    process.exit(0);
  }

  process.exit(0);
} catch (e) {
  process.exit(0);
}
