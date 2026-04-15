#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const BRIEFING_DIR = '.briefing';
const STATE_FILE = path.join(BRIEFING_DIR, 'state.json');

function exists(filePath) {
  try {
    return fs.existsSync(filePath);
  } catch {
    return false;
  }
}

function mkdirp(dirPath) {
  try {
    fs.mkdirSync(dirPath, { recursive: true });
  } catch {}
}

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
}

function writeText(filePath, content) {
  mkdirp(path.dirname(filePath));
  fs.writeFileSync(filePath, content, 'utf8');
}

function tryParseJson(text) {
  if (!text || !text.trim()) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function isoNow() {
  return new Date().toISOString();
}

function currentDate() {
  return isoNow().slice(0, 10);
}

function normalizeRepoPath(filePath) {
  return String(filePath || '')
    .replace(/^\uFEFF/, '')
    .replace(/\\/g, '/')
    .replace(/^\.\//, '')
    .trim();
}

function uniquePaths(paths) {
  return Array.from(
    new Set((paths || []).map((filePath) => normalizeRepoPath(filePath)).filter(Boolean))
  ).sort();
}

function defaultState() {
  return {
    version: 2,
    sessionStartHead: '',
    sessionStartStatus: [],
    lastCountedSession: '',
    sessionMessageCount: 0,
    profileUpdateCounter: 0,
    workCounter: 0,
    prevEntryCount: 0,
    sessionHookNoise: [],
    sessionId: '',
    date: currentDate(),
    startedAt: '',
    updatedAt: '',
    projectName: '',
    cwd: '',
    repoRoot: '',
    promptCount: 0,
    editCount: 0,
    searchCount: 0,
    subagentCount: 0,
    wrapperStopCount: 0,
    prompts: [],
    links: [],
    changedFiles: [],
    agentEvents: [],
    lastPromptExcerpt: '',
    lastUpdatedBy: '',
    latestSummaryHint: '',
    lastSearchQuery: '',
    lastSearchUrl: '',
    lastProfileUpdateAt: '',
    sessionCount: 0
  };
}

function readState() {
  const parsed = tryParseJson(readText(STATE_FILE));
  if (!parsed || typeof parsed !== 'object') {
    return defaultState();
  }
  return Object.assign(defaultState(), parsed);
}

function writeState(state) {
  const next = Object.assign(defaultState(), state || {});
  next.updatedAt = isoNow();
  next.changedFiles = uniquePaths(next.changedFiles || []);
  next.sessionHookNoise = uniquePaths(next.sessionHookNoise || []);
  writeText(STATE_FILE, JSON.stringify(next, null, 2) + '\n');
  return next;
}

function appendUniqueEntry(list, entry, key, maxItems) {
  const items = Array.isArray(list) ? list.slice() : [];
  const normalizedKey = key ? String(entry[key] || '') : '';
  if (normalizedKey) {
    const existingIndex = items.findIndex((item) => String(item[key] || '') === normalizedKey);
    if (existingIndex !== -1) {
      items.splice(existingIndex, 1);
    }
  }
  items.push(entry);
  if (maxItems && items.length > maxItems) {
    return items.slice(items.length - maxItems);
  }
  return items;
}

function truncateLine(text, limit) {
  const raw = String(text || '').replace(/\s+/g, ' ').trim();
  if (!raw) return '';
  if (raw.length <= limit) return raw;
  return raw.slice(0, Math.max(0, limit - 3)).trimEnd() + '...';
}

function parseStatusOutput(output) {
  if (!output) return [];
  return output.split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(.{1,2})\s+(.*)$/);
      const rawStatus = match ? match[1].padEnd(2, ' ') : line.slice(0, 2);
      let filePath = match ? match[2].trim() : line.slice(3).trim();
      if (filePath.includes(' -> ')) {
        filePath = filePath.slice(filePath.lastIndexOf(' -> ') + 4);
      }
      return {
        path: normalizeRepoPath(filePath),
        status: rawStatus,
        line
      };
    })
    .filter((record) => record.path);
}

function cleanupLegacyRuntimeFiles() {
  [
    path.join(BRIEFING_DIR, '.last-counted-session'),
    path.join(BRIEFING_DIR, '.profile-update-counter'),
    path.join(BRIEFING_DIR, '.session-hook-noise'),
    path.join(BRIEFING_DIR, '.session-message-count'),
    path.join(BRIEFING_DIR, '.work-counter'),
    path.join(BRIEFING_DIR, '.session-start-head'),
    path.join(BRIEFING_DIR, '.session-start-status')
  ].forEach((filePath) => {
    try {
      if (exists(filePath)) {
        fs.rmSync(filePath, { force: true });
      }
    } catch {}
  });
}

function extractPromptText(payload) {
  if (!payload || typeof payload !== 'object') return '';

  const directKeys = ['prompt', 'text', 'message', 'input', 'user_prompt'];
  for (const key of directKeys) {
    if (typeof payload[key] === 'string' && payload[key].trim()) {
      return payload[key].trim();
    }
  }

  if (payload.tool_input && typeof payload.tool_input === 'object') {
    for (const key of directKeys) {
      if (typeof payload.tool_input[key] === 'string' && payload.tool_input[key].trim()) {
        return payload.tool_input[key].trim();
      }
    }
  }

  return '';
}

function summarizePaths(paths) {
  const items = uniquePaths(paths || []);
  if (items.length === 0) return '';

  const groups = {};
  items.forEach((filePath) => {
    const root = filePath.includes('/') ? filePath.split('/')[0] : '(root)';
    groups[root] = (groups[root] || 0) + 1;
  });

  return Object.keys(groups).sort().map((name) => {
    if (name === '(root)') {
      return `${groups[name]} root-level file(s)`;
    }
    return `${groups[name]} file(s) under ${name}/`;
  }).join(', ');
}

module.exports = {
  BRIEFING_DIR,
  STATE_FILE,
  appendUniqueEntry,
  cleanupLegacyRuntimeFiles,
  currentDate,
  defaultState,
  exists,
  extractPromptText,
  isoNow,
  mkdirp,
  normalizeRepoPath,
  parseStatusOutput,
  readState,
  readText,
  summarizePaths,
  truncateLine,
  uniquePaths,
  writeState,
  writeText
};
