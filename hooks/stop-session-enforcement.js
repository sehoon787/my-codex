#!/usr/bin/env node
// Stop hook: auto-create session summary and learnings if missing.
// Runs AFTER stop-profile-update.js which generates the auto-gen scaffold.
'use strict';

var fs = require('fs');
var path = require('path');

var BRIEFING_DIR = '.briefing';
var SESSIONS_DIR = path.join(BRIEFING_DIR, 'sessions');
var LEARNINGS_DIR = path.join(BRIEFING_DIR, 'learnings');
var INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');

// Guard: no vault = nothing to enforce
if (!fs.existsSync(INDEX_FILE)) {
  process.exit(0);
}

var todayStr = new Date().toISOString().slice(0, 10);

// Check session activity
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

// Skip if no activity at all
if (workCounter === 0 && !hasAgentActivity && !hasUserMessages && !hasMessageCount) {
  process.exit(0);
}

// Detect project language from INDEX.md
var lang = 'en';
try {
  var indexContent = fs.readFileSync(INDEX_FILE, 'utf8');
  var langMatch = indexContent.match(/^language:\s*(\S+)/m);
  if (langMatch) {
    lang = langMatch[1].trim();
  }
} catch (e) {}

// Check for proper (non-auto) session summary for today
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

// Promote auto scaffold to proper session file if missing
if (!hasProperSummary) {
  try {
    var autoFile = path.join(SESSIONS_DIR, todayStr + '-auto.md');
    var targetFile = path.join(SESSIONS_DIR, todayStr + '-session.md');
    if (fs.existsSync(autoFile)) {
      fs.renameSync(autoFile, targetFile);
    }
  } catch (e) {}
}

// Check for proper (non-auto) learning file modified today
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

// Promote auto learning scaffold to proper learning file if missing
if (workCounter >= 5 && !hasProperLearning) {
  try {
    var autoLearningFile = path.join(LEARNINGS_DIR, todayStr + '-auto-session.md');
    var targetLearningFile = path.join(LEARNINGS_DIR, todayStr + '-learning.md');
    if (fs.existsSync(autoLearningFile)) {
      fs.renameSync(autoLearningFile, targetLearningFile);
    }
  } catch (e) {}
}

// Output brief feedback about what was promoted
var promoted = [];
if (!hasProperSummary) {
  var sessionTarget = path.join(SESSIONS_DIR, todayStr + '-session.md');
  if (fs.existsSync(sessionTarget)) {
    promoted.push('.briefing/sessions/' + todayStr + '-session.md');
  }
}
if (workCounter >= 5 && !hasProperLearning) {
  var learningTarget = path.join(LEARNINGS_DIR, todayStr + '-learning.md');
  if (fs.existsSync(learningTarget)) {
    promoted.push('.briefing/learnings/' + todayStr + '-learning.md');
  }
}

if (promoted.length > 0) {
  var msg = (lang === 'ko' || lang === 'kr')
    ? '[BriefingVault] 세션 기록 저장: ' + promoted.join(', ')
    : '[BriefingVault] Session saved: ' + promoted.join(', ');
  process.stdout.write(JSON.stringify({ reason: msg }) + '\n');
}

process.exit(0);
