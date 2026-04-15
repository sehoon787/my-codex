#!/usr/bin/env node
// Stop hook: enforce follow-up session summaries and learnings.
// Blocks session end if meaningful work happened but only the auto scaffolds exist.
'use strict';

try {
  const fs = require('fs');
  const path = require('path');
  const runtime = require('./briefing-runtime');

  const BRIEFING_DIR = runtime.BRIEFING_DIR;
  const SESSIONS_DIR = path.join(BRIEFING_DIR, 'sessions');
  const LEARNINGS_DIR = path.join(BRIEFING_DIR, 'learnings');
  const DECISIONS_DIR = path.join(BRIEFING_DIR, 'decisions');
  const INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');

  if (!fs.existsSync(INDEX_FILE)) {
    process.exit(0);
  }

  const todayStr = runtime.currentDate();
  const sessionState = runtime.readState();

  const meaningfulWork =
    (sessionState.workCounter || 0) > 0 ||
    (sessionState.promptCount || 0) >= 3 ||
    (sessionState.searchCount || 0) > 0 ||
    (sessionState.changedFiles || []).length > 0 ||
    (sessionState.links || []).length > 0;

  if (!meaningfulWork) {
    process.exit(0);
  }

  function promptTexts() {
    return (sessionState.prompts || [])
      .map((entry) => (entry && (entry.excerpt || entry.text) || '').trim().toLowerCase())
      .filter(Boolean);
  }

  function hasPromptKeyword(keywords) {
    const texts = promptTexts();
    for (const text of texts) {
      for (const keyword of keywords) {
        if (text.indexOf(keyword) !== -1) {
          return true;
        }
      }
    }
    return false;
  }

  let lang = 'en';
  try {
    const indexContent = fs.readFileSync(INDEX_FILE, 'utf8');
    const langMatch = indexContent.match(/^language:\s*(\S+)/m);
    if (langMatch) {
      lang = langMatch[1].trim();
    }
  } catch {}

  const isKo = lang === 'ko' || lang === 'kr';

  let hasProperSummary = false;
  try {
    if (fs.existsSync(SESSIONS_DIR)) {
      for (const file of fs.readdirSync(SESSIONS_DIR)) {
        if (file.slice(0, 10) === todayStr && file.indexOf('-auto') === -1) {
          hasProperSummary = true;
          break;
        }
      }
    }
  } catch {}

  let hasProperLearning = false;
  try {
    if (fs.existsSync(LEARNINGS_DIR)) {
      for (const file of fs.readdirSync(LEARNINGS_DIR)) {
        if (file.slice(0, 10) === todayStr && file.indexOf('-auto-session') === -1) {
          hasProperLearning = true;
          break;
        }
      }
    }
  } catch {}

  let hasProperDecision = false;
  try {
    if (fs.existsSync(DECISIONS_DIR)) {
      for (const file of fs.readdirSync(DECISIONS_DIR)) {
        if (file.slice(0, 10) === todayStr && file.indexOf('-auto') === -1) {
          hasProperDecision = true;
          break;
        }
      }
    }
  } catch {}

  const policy = runtime.readPersonaPolicy();
  const decisionNeeded =
    hasPromptKeyword([
      'decision', 'decisions', 'choose', 'chosen', 'choice', 'policy', 'routing',
      'route', 'prefer', 'install path', 'consolidate', 'replace', 'switch', 'adopt'
    ]) ||
    Object.keys(policy.preferences || {}).length > 0;
  const learningNeeded =
    hasPromptKeyword([
      'learning', 'learnings', 'reusable', 'pattern', 'patterns', 'why', 'worked',
      'works', 'gotcha', 'warning', 'avoid', 'fix', 'solution', 'problem'
    ]);

  if (!hasProperSummary) {
    const reason = isKo
      ? `[BriefingVault] 실제 세션 요약이 없습니다. .briefing/sessions/${todayStr}-<topic>.md 에 목표, 작업, 결과를 적으세요.`
      : `[BriefingVault] No follow-up session summary. Write .briefing/sessions/${todayStr}-<topic>.md with the goal, work completed, and results.`;

    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason
    }) + '\n');
    process.exit(0);
  }

  if (hasProperSummary && learningNeeded && !hasProperLearning) {
    const learningReason = isKo
      ? `[BriefingVault] 작업량이 많았지만 학습 노트가 없습니다. .briefing/learnings/${todayStr}-<topic>.md 에 재사용할 패턴이나 주의점을 남기세요.`
      : `[BriefingVault] No follow-up learning despite significant work. Write .briefing/learnings/${todayStr}-<topic>.md with the reusable pattern or warning.`;

    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: learningReason
    }) + '\n');
    process.exit(0);
  }

  if (hasProperSummary && decisionNeeded && !hasProperDecision) {
    const decisionReason = isKo
      ? `[BriefingVault] 파일 변경이 많지만 후속 decision note가 없습니다. .briefing/decisions/${todayStr}-<topic>.md 에 왜 이런 구조를 택했는지 적으세요.`
      : `[BriefingVault] Significant file changes were made without a follow-up decision note. Write .briefing/decisions/${todayStr}-<topic>.md with the choice and rationale.`;

    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: decisionReason
    }) + '\n');
    process.exit(0);
  }

  process.exit(0);
} catch {
  process.exit(0);
}
