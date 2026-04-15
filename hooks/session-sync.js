#!/usr/bin/env node
// Codex mid-session Briefing Vault updater.
// Invoked from native Codex hooks such as UserPromptSubmit and PostToolUse.

'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const BRIEFING_DIR = '.briefing';
const INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');

function exists(filePath) {
  try {
    return fs.existsSync(filePath);
  } catch {
    return false;
  }
}

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
}

function writeText(filePath, content) {
  try {
    fs.writeFileSync(filePath, content, 'utf8');
    return true;
  } catch {
    return false;
  }
}

function mkdirp(dirPath) {
  try {
    fs.mkdirSync(dirPath, { recursive: true });
  } catch {}
}

function readCounter(filePath) {
  const raw = readText(filePath).trim();
  return raw ? (parseInt(raw, 10) || 0) : 0;
}

function writeCounter(filePath, value) {
  writeText(filePath, String(value));
}

function tryParseJson(text) {
  if (!text || !text.trim()) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function currentDate() {
  return new Date().toISOString().slice(0, 10);
}

function runNode(scriptPath, payload, env) {
  try {
    return cp.spawnSync(process.execPath, [scriptPath], {
      input: payload ? JSON.stringify(payload) : '',
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore'],
      env: Object.assign({}, process.env, env || {})
    });
  } catch {
    return { stdout: '', status: 0 };
  }
}

function updateScaffolds(payload) {
  const home = process.env.HOME || process.env.USERPROFILE || '';
  const sessionEnd = path.join(home, '.codex', 'hooks', 'session-end.js');
  if (!exists(sessionEnd)) return;
  runNode(sessionEnd, payload, { MY_CODEX_SESSION_SYNC_ONLY: '1' });
}

function updateProfileIfNeeded(payload, force) {
  const home = process.env.HOME || process.env.USERPROFILE || '';
  const stopProfile = path.join(home, '.codex', 'hooks', 'stop-profile-update.js');
  if (!exists(stopProfile)) return;

  const counterFile = path.join(BRIEFING_DIR, '.profile-update-counter');
  let counter = readCounter(counterFile) + 1;
  if (!force && counter < 5) {
    writeCounter(counterFile, counter);
    return;
  }

  writeCounter(counterFile, 0);
  runNode(stopProfile, payload || {
    agent_id: 'user-prompt-submit',
    agent_type: 'throttled-update'
  });
}

function appendAutoLink(payload) {
  const toolInput = payload && payload.tool_input ? payload.tool_input : {};
  const url = toolInput.url || toolInput.query || '';
  if (!url) return;

  const linksFile = path.join(BRIEFING_DIR, 'references', 'auto-links.md');
  mkdirp(path.dirname(linksFile));
  const existing = readText(linksFile);
  if (existing.indexOf(url) !== -1) return;
  fs.appendFileSync(linksFile, `- ${currentDate()} ${url}\n`, 'utf8');
}

function countTodayEntries(subdir) {
  const dir = path.join(BRIEFING_DIR, subdir);
  const today = currentDate();
  if (!exists(dir)) return 0;
  try {
    return fs.readdirSync(dir).filter((file) => {
      if (!file.endsWith('.md')) return false;
      if (file.indexOf('-auto') !== -1) return false;
      try {
        return fs.statSync(path.join(dir, file)).mtime.toISOString().slice(0, 10) === today;
      } catch {
        return false;
      }
    }).length;
  } catch {
    return 0;
  }
}

function buildReminder(messageCount) {
  const today = currentDate();
  const workCounter = readCounter(path.join(BRIEFING_DIR, '.work-counter'));
  const sessionCount = countTodayEntries('sessions');
  const decisionCount = countTodayEntries('decisions');
  const learningCount = countTodayEntries('learnings');
  const totalEntries = sessionCount + decisionCount + learningCount;

  if (messageCount < 3) return '';
  if (workCounter === 0 && totalEntries === 0) return '';
  if (sessionCount > 0) return '';

  if (decisionCount + learningCount > 0) {
    return `[BriefingVault] You have written ${decisionCount + learningCount} decisions/learnings but no session summary yet. Write .briefing/sessions/${today}-<topic>.md to document this conversation.`;
  }

  if (messageCount >= 6) {
    return `[BriefingVault] WARNING: ${messageCount} messages exchanged and ${workCounter} file edits this session, but no follow-up session summary exists yet. Write .briefing/sessions/${today}-<topic>.md or a decision/learning entry in .briefing/.`;
  }

  return `[BriefingVault] REQUIRED: ${messageCount} messages exchanged this session with ${workCounter} file edits. Write at least one entry to .briefing/sessions/, .briefing/decisions/, or .briefing/learnings/.`;
}

function emitAdditionalContext(message) {
  if (!message) return;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      additionalContext: message
    }
  }) + '\n');
}

function main() {
  if (!exists(INDEX_FILE)) return;

  const mode = process.argv[2] || 'prompt';
  const payload = tryParseJson(readStdin()) || {};

  if (mode === 'edit') {
    writeCounter(path.join(BRIEFING_DIR, '.work-counter'), readCounter(path.join(BRIEFING_DIR, '.work-counter')) + 1);
    updateScaffolds({ agent_id: 'post-tool-edit', agent_type: 'mid-session-sync' });
    return;
  }

  if (mode === 'search') {
    appendAutoLink(payload);
    updateScaffolds({ agent_id: 'post-tool-search', agent_type: 'mid-session-sync' });
    return;
  }

  if (mode === 'subagent') {
    updateScaffolds({ agent_id: 'subagent-stop-sync', agent_type: 'mid-session-sync' });
    return;
  }

  const messageCounterFile = path.join(BRIEFING_DIR, '.session-message-count');
  const messageCount = readCounter(messageCounterFile) + 1;
  writeCounter(messageCounterFile, messageCount);
  updateProfileIfNeeded({ agent_id: 'user-prompt-submit', agent_type: 'throttled-update' }, false);
  updateScaffolds({ agent_id: 'user-prompt-submit', agent_type: 'mid-session-sync' });
  emitAdditionalContext(buildReminder(messageCount));
}

main();
