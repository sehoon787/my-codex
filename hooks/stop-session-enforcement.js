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

var todayStr = new Date().toISOString().slice(0, 10);

// Check session activity — enforce if ANY meaningful activity happened
var workCounter = 0;
try {
  var wcPath = path.join(BRIEFING_DIR, '.work-counter');
  if (fs.existsSync(wcPath)) {
    workCounter = parseInt(fs.readFileSync(wcPath, 'utf8').trim(), 10) || 0;
  }
} catch (e) {}

// Check agent-log for today's entries
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

// Check if user sent messages (profile-update-counter exists and modified today)
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

// Check session message count (incremented by UserPromptSubmit hook)
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

// Skip only if NO activity at all (empty session)
if (workCounter === 0 && !hasAgentActivity && !hasUserMessages && !hasMessageCount) {
  process.exit(0);
}

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

var LEARNINGS_DIR = path.join(BRIEFING_DIR, 'learnings');

// Check for proper (non-auto) learning file modified today
var hasProperLearning = false;
try {
  if (fs.existsSync(LEARNINGS_DIR)) {
    var learningFiles = fs.readdirSync(LEARNINGS_DIR);
    for (var j = 0; j < learningFiles.length; j++) {
      var lf = learningFiles[j];
      // Must start with today's date and NOT be an auto-session file
      if (lf.slice(0, 10) === todayStr && lf.indexOf('-auto-session') === -1) {
        // Also verify it was actually modified today (mtime check)
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

if (hasProperSummary) {
  // Session summary exists — now check learnings (only if workCounter >= 5)
  if (workCounter < 5 || hasProperLearning) {
    process.exit(0);
  }

  // Read auto-gen learning scaffold for context
  var learningScaffold = '';
  try {
    var autoLearningFile = path.join(LEARNINGS_DIR, todayStr + '-auto-session.md');
    if (fs.existsSync(autoLearningFile)) {
      learningScaffold = fs.readFileSync(autoLearningFile, 'utf8');
    }
  } catch (e) {}

  // Detect lang from INDEX.md
  var learningLang = 'en';
  try {
    var lIndexContent = fs.readFileSync(INDEX_FILE, 'utf8');
    var lLangMatch = lIndexContent.match(/^language:\s*(\S+)/m);
    if (lLangMatch) {
      learningLang = lLangMatch[1].trim();
    }
  } catch (e) {}

  var learningTemplate;
  if (learningLang === 'ko' || learningLang === 'kr') {
    learningTemplate = '[BriefingVault] 학습 기록을 작성하세요.\n\n' +
      '파일: .briefing/learnings/' + todayStr + '-<주제>.md\n\n' +
      '필수 포함:\n' +
      '---\ndate: ' + todayStr + '\ntype: learning\ntags: [관련, 태그]\n---\n\n' +
      '# 학습: <주제>\n\n' +
      '## 배운 점\n(이번 세션에서 발견한 패턴, 해결법, 주의사항)\n\n' +
      '## 적용 방법\n(향후 어떻게 활용할 수 있는지)\n';
  } else {
    learningTemplate = '[BriefingVault] Write a learning entry.\n\n' +
      'File: .briefing/learnings/' + todayStr + '-<topic>.md\n\n' +
      'Required format:\n' +
      '---\ndate: ' + todayStr + '\ntype: learning\ntags: [relevant, tags]\n---\n\n' +
      '# Learning: <Topic>\n\n' +
      '## What was learned\n(Patterns, solutions, gotchas discovered this session)\n\n' +
      '## How to apply\n(How this can be used going forward)\n';
  }

  if (learningScaffold) {
    learningTemplate += '\n---\nAuto-collected data (use as reference):\n```\n' + learningScaffold + '\n```';
  }

  var learningOutput = {
    decision: 'block',
    reason: learningLang === 'ko' || learningLang === 'kr'
      ? '학습 기록 미작성 (' + workCounter + '개 파일 수정됨). .briefing/learnings/' + todayStr + '-<topic>.md를 작성하세요.'
      : 'No learning entry written (' + workCounter + ' files edited). Write .briefing/learnings/' + todayStr + '-<topic>.md.',
    systemMessage: learningTemplate
  };

  process.stdout.write(JSON.stringify(learningOutput) + '\n');
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
