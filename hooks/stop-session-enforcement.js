#!/usr/bin/env node
// Stop hook: enforce meaningful session summary
// Blocks session end if work was done but no proper session summary exists.
// Runs AFTER stop-profile-update.js which generates the auto-gen scaffold.
'use strict';

var fs = require('fs');
var path = require('path');

var BRIEFING_DIR = '.briefing';
var SESSIONS_DIR = path.join(BRIEFING_DIR, 'sessions');
var INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');

// Guard: no vault = nothing to enforce
if (!fs.existsSync(INDEX_FILE)) {
  process.exit(0);
}

// Check work counter — only enforce if meaningful work was done
var workCounter = 0;
try {
  var wcPath = path.join(BRIEFING_DIR, '.work-counter');
  if (fs.existsSync(wcPath)) {
    workCounter = parseInt(fs.readFileSync(wcPath, 'utf8').trim(), 10) || 0;
  }
} catch (e) {}

// Threshold: only enforce if >= 3 file edits
if (workCounter < 3) {
  process.exit(0);
}

var todayStr = new Date().toISOString().slice(0, 10);

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

if (hasProperSummary) {
  // AI already wrote a proper summary, allow session end
  process.exit(0);
}

// Read auto-gen scaffold for context (written by stop-profile-update.js)
var scaffold = '';
try {
  var autoFile = path.join(SESSIONS_DIR, todayStr + '-auto.md');
  if (fs.existsSync(autoFile)) {
    scaffold = fs.readFileSync(autoFile, 'utf8');
  }
} catch (e) {}

// Detect project language from INDEX.md
var lang = 'en';
try {
  var indexContent = fs.readFileSync(INDEX_FILE, 'utf8');
  var langMatch = indexContent.match(/^language:\s*(\S+)/m);
  if (langMatch) {
    lang = langMatch[1].trim();
  }
} catch (e) {}

// Build enforcement message
var template;
if (lang === 'ko' || lang === 'kr') {
  template = '[BriefingVault] 세션 요약을 작성하세요.\n\n' +
    '파일: .briefing/sessions/' + todayStr + '-<토픽명>.md\n\n' +
    '필수 포함:\n' +
    '---\ndate: ' + todayStr + '\ntype: session\ntags: [관련, 태그]\n---\n\n' +
    '# 세션: <토픽명>\n\n' +
    '## 요청 사항\n(이번 세션에서 무엇을 요청받았는지)\n\n' +
    '## 작업 내용\n(무엇을 했는지, 파일명과 변경 내용 포함)\n\n' +
    '## 변경 요약\n| 파일 | 변경 내용 |\n|------|----------|\n\n' +
    '## 검증 상태\n- [ ] 테스트/확인 결과\n';
} else {
  template = '[BriefingVault] Write a session summary.\n\n' +
    'File: .briefing/sessions/' + todayStr + '-<topic>.md\n\n' +
    'Required format:\n' +
    '---\ndate: ' + todayStr + '\ntype: session\ntags: [relevant, tags]\n---\n\n' +
    '# Session: <Topic>\n\n' +
    '## Request\n(What was requested this session)\n\n' +
    '## Work Done\n(What was done, with file names and specific changes)\n\n' +
    '## Change Summary\n| File | Change |\n|------|--------|\n\n' +
    '## Verification\n- [ ] Test/verification results\n';
}

if (scaffold) {
  template += '\n---\nAuto-collected data (use as reference):\n```\n' + scaffold + '\n```';
}

var output = {
  decision: 'block',
  reason: lang === 'ko' || lang === 'kr'
    ? '세션 요약 미작성 (' + workCounter + '개 파일 수정됨). .briefing/sessions/' + todayStr + '-<topic>.md를 작성하세요.'
    : 'No session summary written (' + workCounter + ' files edited). Write .briefing/sessions/' + todayStr + '-<topic>.md.',
  systemMessage: template
};

process.stdout.write(JSON.stringify(output) + '\n');
