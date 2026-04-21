#!/usr/bin/env node
'use strict';
try {
var runtime = require('./briefing-runtime');
var fs = require('fs');
var path = require('path');

var INDEX_FILE = path.join(runtime.BRIEFING_DIR, 'INDEX.md');
if (!runtime.exists(INDEX_FILE)) { process.exit(0); }

var todayStr = runtime.currentDate();
var state = runtime.readState();

// Check if boss-briefing was run today
var lastSync = state.lastVaultSync || '';
var syncToday = lastSync && lastSync.slice(0, 10) === todayStr;
if (syncToday) { process.exit(0); }

// Check for meaningful activity
var wc = parseInt(state.workCounter, 10) || 0;
var mc = parseInt(state.sessionMessageCount, 10) || parseInt(state.promptCount, 10) || 0;
var hasAgent = false;
try {
  var agentLog = path.join(runtime.BRIEFING_DIR, 'agents', 'agent-log.jsonl');
  if (runtime.exists(agentLog)) {
    hasAgent = fs.statSync(agentLog).mtime.toISOString().slice(0, 10) === todayStr;
  }
} catch(e) {}

if (wc === 0 && mc <= 2 && !hasAgent) { process.exit(0); }

// Detect language
var lang = 'en';
try {
  var idx = runtime.readText(INDEX_FILE);
  var lm = idx.match(/^language:\s*(\S+)/m);
  if (lm) lang = lm[1].trim();
} catch(e) {}
var isKo = (lang === 'ko' || lang === 'kr');

// Check for session summary as safety net
var SESSIONS_DIR = path.join(runtime.BRIEFING_DIR, 'sessions');
var hasSession = false;
try {
  if (runtime.exists(SESSIONS_DIR)) {
    hasSession = fs.readdirSync(SESSIONS_DIR).some(function(f) {
      return f.slice(0, 10) === todayStr && f.indexOf('-auto') === -1;
    });
  }
} catch(e) {}

if (hasSession) {
  // Session exists but boss-briefing not run — pass silently
  // UserPromptSubmit hook already reminds about /boss-briefing during session
  process.exit(0);
}

// Block: meaningful work, no vault sync, no session
var reason = isKo
  ? '[BriefingVault] /boss-briefing 미실행. 세션 종료 전 /boss-briefing을 실행하세요.'
  : '[BriefingVault] Run /boss-briefing before ending the session to sync your vault.';
process.stdout.write(JSON.stringify({ decision: 'block', reason: reason }) + '\n');
process.exit(0);
} catch(e) { process.exit(0); }
