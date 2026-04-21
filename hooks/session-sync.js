#!/usr/bin/env node
// Codex mid-session Briefing Vault updater.
// Invoked from native Codex hooks such as UserPromptSubmit and PostToolUse.

'use strict';

const cp = require('child_process');
const path = require('path');
const runtime = require('./briefing-runtime');

const INDEX_FILE = path.join(runtime.BRIEFING_DIR, 'INDEX.md');

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
    return process.stdin.isTTY ? '' : require('fs').readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function run(command, args) {
  try {
    return cp.execFileSync(command, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
  } catch {
    return '';
  }
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
  if (!runtime.exists(sessionEnd)) return;
  runNode(sessionEnd, payload, { MY_CODEX_SESSION_SYNC_ONLY: '1' });
}

function updateProfileIfNeeded(payload, force) {
  const home = process.env.HOME || process.env.USERPROFILE || '';
  const stopProfile = path.join(home, '.codex', 'hooks', 'stop-profile-update.js');
  if (!runtime.exists(stopProfile)) return;

  const state = runtime.readState();
  state.profileUpdateCounter = (parseInt(state.profileUpdateCounter, 10) || 0) + 1;
  const shouldRun = force || state.profileUpdateCounter >= 5;
  if (!shouldRun) {
    runtime.writeState(state);
    return;
  }

  state.profileUpdateCounter = 0;
  runtime.writeState(state);
  runNode(stopProfile, payload || {
    agent_id: 'user-prompt-submit',
    agent_type: 'throttled-update'
  });
}

function emitAdditionalContext(message) {
  if (!message) return;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      additionalContext: message
    }
  }) + '\n');
}

function readLanguage() {
  const indexContent = runtime.readText(INDEX_FILE);
  const match = indexContent.match(/^language:\s*(\S+)/m);
  return match ? match[1].trim() : 'en';
}

function reminderText(state) {
  const lang = readLanguage();
  const isKo = lang === 'ko' || lang === 'kr';
  const promptCount = state.promptCount || 0;
  const workCount = state.workCounter || 0;
  const changedCount = (state.changedFiles || []).length;
  const linkCount = (state.links || []).length;

  if (promptCount < 3) return '';
  if (workCount === 0 && changedCount === 0 && linkCount === 0) {
    // Still check if boss-briefing reminder is needed
    var lastSync = state.lastVaultSync || '';
    var syncToday = lastSync && lastSync.slice(0, 10) === runtime.currentDate();
    if (promptCount >= 5 && !syncToday) {
      return '[BriefingVault] Run /boss-briefing to sync vault and analyze workflow patterns.';
    }
    return '';
  }

  if (isKo) {
    if (promptCount >= 6 || changedCount >= 3) {
      return `[BriefingVault] 지금 세션은 작업량이 많습니다. .briefing/sessions/${runtime.currentDate()}-<topic>.md 에 목표, 실제 작업, 남은 TODO를 정리하세요.`;
    }
    return `[BriefingVault] 이 대화 내용을 세션 노트로 남기세요: .briefing/sessions/${runtime.currentDate()}-<topic>.md`;
  }

  if (promptCount >= 6 || changedCount >= 3) {
    return `[BriefingVault] This session now has enough work to justify a real note. Write .briefing/sessions/${runtime.currentDate()}-<topic>.md with the goal, work completed, and follow-ups.`;
  }
  return `[BriefingVault] Capture this conversation in .briefing/sessions/${runtime.currentDate()}-<topic>.md before context drifts.`;
}

function promptEntryFromPayload(payload, count) {
  const promptText = runtime.extractPromptText(payload);
  if (!promptText) return null;
  return {
    ts: runtime.isoNow(),
    index: count,
    text: runtime.truncateLine(promptText, 240),
    excerpt: runtime.truncateLine(promptText, 120)
  };
}

function gatherGitChanges(noisePaths) {
  const status = runtime.parseStatusOutput(
    run('git', ['status', '--short', '--untracked-files=all'])
  );
  return runtime.uniquePaths(status
    .map((record) => record.path)
    .filter((filePath) => {
      const normalized = runtime.normalizeRepoPath(filePath);
      return normalized &&
        normalized !== '.gitignore' &&
        normalized !== runtime.BRIEFING_DIR &&
        !normalized.startsWith(`${runtime.BRIEFING_DIR}/`) &&
        !(noisePaths || []).includes(normalized);
    }));
}

function appendAutoLink(state, payload) {
  const toolInput = payload && payload.tool_input ? payload.tool_input : {};
  const url = toolInput.url || '';
  const query = toolInput.query || toolInput.q || '';
  const contextText = runtime.truncateLine(
    runtime.extractPromptText(payload) || query || url,
    140
  );
  if (!url && !query) return state;

  const entry = {
    ts: runtime.isoNow(),
    url: url || '',
    query: query || '',
    context: contextText || 'search'
  };

  state.links = runtime.appendUniqueEntry(
    state.links || [],
    entry,
    url ? 'url' : 'query',
    20
  );
  state.searchCount = (state.searchCount || 0) + 1;
  state.lastSearchQuery = query || state.lastSearchQuery || '';
  state.lastSearchUrl = url || state.lastSearchUrl || '';
  state.lastUpdatedBy = 'search';
  return state;
}

function ensureState() {
  if (!runtime.exists(INDEX_FILE)) return null;
  const state = runtime.readState();
  if (!state.sessionId) {
    const now = runtime.isoNow();
    return runtime.writeState(Object.assign(state, {
      sessionId: `${runtime.currentDate()}:${process.cwd()}`,
      date: runtime.currentDate(),
      startedAt: now,
      projectName: path.basename(process.cwd()),
      cwd: process.cwd(),
      repoRoot: run('git', ['rev-parse', '--show-toplevel']),
      sessionStartHead: run('git', ['rev-parse', 'HEAD']),
      sessionStartStatus: runtime.parseStatusOutput(run('git', ['status', '--short', '--untracked-files=all']))
    }));
  }
  return state;
}

function main() {
  if (!runtime.exists(INDEX_FILE)) return;

  const mode = process.argv[2] || 'prompt';
  const payload = tryParseJson(readStdin()) || {};
  let state = ensureState();
  if (!state) return;

  state.changedFiles = runtime.uniquePaths([]
    .concat(state.changedFiles || [], gatherGitChanges(state.sessionHookNoise || [])));

  if (mode === 'edit') {
    state.editCount = (state.editCount || 0) + 1;
    state.workCounter = (state.workCounter || 0) + 1;
    state.lastUpdatedBy = 'edit';
    runtime.writeState(state);
    updateScaffolds({ agent_id: 'post-tool-edit', agent_type: 'mid-session-sync' });
    return;
  }

  if (mode === 'search') {
    state = appendAutoLink(state, payload);
    runtime.writeState(state);
    updateScaffolds({ agent_id: 'post-tool-search', agent_type: 'mid-session-sync' });
    return;
  }

  if (mode === 'subagent') {
    state.subagentCount = (state.subagentCount || 0) + 1;
    state.lastUpdatedBy = 'subagent';
    runtime.writeState(state);
    updateScaffolds({ agent_id: 'subagent-stop-sync', agent_type: 'mid-session-sync' });
    return;
  }

  state.promptCount = (state.promptCount || 0) + 1;
  state.sessionMessageCount = (state.sessionMessageCount || 0) + 1;
  const promptEntry = promptEntryFromPayload(payload, state.promptCount);
  if (promptEntry) {
    state.prompts = runtime.appendUniqueEntry(state.prompts || [], promptEntry, 'ts', 12);
    state.lastPromptExcerpt = promptEntry.excerpt;
    state.latestSummaryHint = promptEntry.excerpt;
  }
  state.lastUpdatedBy = 'prompt';
  runtime.writeState(state);
  updateProfileIfNeeded({ agent_id: 'user-prompt-submit', agent_type: 'throttled-update' }, false);
  updateScaffolds({ agent_id: 'user-prompt-submit', agent_type: 'mid-session-sync' });
  emitAdditionalContext(reminderText(runtime.readState()));
}

main();
