#!/usr/bin/env node
// Codex session-end synthesis for Briefing Vault.
// Codex does not expose Claude-style hook events, so wrappers call this
// script after the real Codex process exits.

'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const BRIEFING_DIR = '.briefing';
const INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');
const SESSION_START_STATUS_FILE = path.join(BRIEFING_DIR, '.session-start-status');
const SESSION_HOOK_NOISE_FILE = path.join(BRIEFING_DIR, '.session-hook-noise');

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
  try {
    fs.writeFileSync(filePath, content, 'utf8');
    return true;
  } catch {
    return false;
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

function runRaw(command, args) {
  try {
    return cp.execFileSync(command, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    });
  } catch {
    return '';
  }
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
    return fs.readFileSync(0, 'utf8').trim();
  } catch {
    return '';
  }
}

function currentDate() {
  return new Date().toISOString().slice(0, 10);
}

function gitRoot() {
  return run('git', ['rev-parse', '--show-toplevel']);
}

function gitPath(relativePath) {
  return run('git', ['rev-parse', '--git-path', relativePath]);
}

function normalizeRepoPath(filePath) {
  return (filePath || '')
    .replace(/^\uFEFF/, '')
    .replace(/\\/g, '/')
    .replace(/^\.\//, '')
    .trim();
}

function parseStatusOutput(output) {
  if (!output) return [];

  return output.split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .map((line) => {
      const rawStatus = line.slice(0, 2);
      let filePath = line.slice(3).trim();
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

function readHookNoisePaths() {
  return new Set(
    readText(SESSION_HOOK_NOISE_FILE)
      .split(/\r?\n/)
      .map((line) => normalizeRepoPath(line))
      .filter(Boolean)
  );
}

function isBriefingArtifact(filePath) {
  return filePath === BRIEFING_DIR || filePath.startsWith(`${BRIEFING_DIR}/`);
}

function shouldIgnoreSessionPath(filePath, noisePaths) {
  const normalized = normalizeRepoPath(filePath);
  return !normalized ||
    normalized === '.gitignore' ||
    isBriefingArtifact(normalized) ||
    noisePaths.has(normalized);
}

function uniquePaths(paths) {
  return Array.from(new Set(paths.map((filePath) => normalizeRepoPath(filePath)).filter(Boolean))).sort();
}

function sessionChangedFiles() {
  const stateDir = gitPath('my-codex-attribution');
  if (!stateDir) return [];
  const changedPath = path.join(stateDir, 'changed-files.txt');
  if (!exists(changedPath)) return [];
  return uniquePaths(readText(changedPath)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean));
}

function readStatusSnapshot() {
  return parseStatusOutput(readText(SESSION_START_STATUS_FILE));
}

function gitStatusRecords(paths) {
  const args = ['status', '--short', '--untracked-files=all'];
  if (paths.length > 0) {
    args.push('--', ...paths);
  }
  return parseStatusOutput(runRaw('git', args));
}

function fallbackChangedFilesFromStatus(startRecords, endRecords, noisePaths) {
  const startMap = new Map(startRecords.map((record) => [record.path, record.line]));
  const endMap = new Map(endRecords.map((record) => [record.path, record.line]));
  const changed = [];

  Array.from(new Set([...startMap.keys(), ...endMap.keys()]))
    .sort()
    .forEach((filePath) => {
      if (shouldIgnoreSessionPath(filePath, noisePaths)) return;
      if ((startMap.get(filePath) || '') !== (endMap.get(filePath) || '')) {
        changed.push(filePath);
      }
    });

  return changed;
}

function gitTrackedDiffSummary(baseRef, paths) {
  if (paths.length === 0) return '';
  const args = baseRef
    ? ['diff', '--shortstat', baseRef, '--', ...paths]
    : ['diff', '--shortstat', '--', ...paths];
  return run('git', args);
}

function endStatusLines(records) {
  if (records.length === 0) {
    return ['- clean at session end for recorded files'];
  }
  return records.map((record) => `- ${record.line.trimStart()}`);
}

function sessionDiffLines(baseRef, paths, statusRecords) {
  if (paths.length === 0) {
    return ['- no files recorded for this Codex session'];
  }

  const summary = [];
  const trackedDiff = gitTrackedDiffSummary(baseRef, paths);
  if (trackedDiff) {
    summary.push(`- tracked diff vs ${baseRef ? 'session-start HEAD' : 'current HEAD'} for recorded files: ${trackedDiff}`);
  }

  const untrackedPaths = statusRecords
    .filter((record) => record.status === '??')
    .map((record) => record.path);
  if (untrackedPaths.length > 0) {
    summary.push(`- untracked files recorded this session: ${untrackedPaths.join(', ')}`);
  }

  if (summary.length === 0) {
    summary.push(`- recorded files match ${baseRef ? 'session-start HEAD' : 'current HEAD'} at session end`);
  }

  return summary;
}

function todaySignalLines(agentLogPath, today) {
  if (!exists(agentLogPath)) return [];
  const counts = {};
  readText(agentLogPath).split(/\r?\n/).forEach((line) => {
    const entry = tryParseJson(line);
    if (!entry || !entry.ts || entry.ts.slice(0, 10) !== today) return;
    const agentType = entry.agent_type || entry.agent || 'unknown';
    counts[agentType] = (counts[agentType] || 0) + 1;
  });

  return Object.keys(counts)
    .sort()
    .map((name) => {
      const count = counts[name];
      const suffix = count === 1 ? 'event' : 'events';
      if (name === 'wrapper') {
        return `- wrapper-managed session stop: ${count} logged ${suffix}`;
      }
      if (name === 'throttled-update') {
        return `- throttled profile update: ${count} logged ${suffix}`;
      }
      return `- ${name}: ${count} logged ${suffix}`;
    });
}

function appendWrapperAgentEvent(agentLogPath, payload) {
  mkdirp(path.dirname(agentLogPath));

  const wrapper = (payload && payload.agent_type) || process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper';
  const wrapperId = (payload && payload.agent_id) || process.env.MY_CODEX_SESSION_END_AGENT_ID || 'codex-wrapper-stop';
  const repoRoot = gitRoot();
  const changed = sessionChangedFiles();

  const event = {
    ts: new Date().toISOString(),
    agent_id: wrapperId,
    agent_type: wrapper,
    cwd: process.cwd(),
    repo_root: repoRoot || '',
    changed_files: changed.length
  };

  try {
    fs.appendFileSync(agentLogPath, JSON.stringify(event) + '\n', 'utf8');
  } catch {}

  return changed;
}

function sessionAutoContent(today, baseRef, changedFiles, statusRecords, statusLines, signalLines, enforcementReason) {
  const changedSection = changedFiles.length > 0
    ? changedFiles.map((file) => `- ${file}`).join('\n')
    : '- (no files recorded for this Codex session)';
  const statusSection = statusLines.length > 0
    ? statusLines.join('\n')
    : '- clean at session end for recorded files';
  const diffSection = sessionDiffLines(baseRef, changedFiles, statusRecords).join('\n');
  const signalSection = signalLines.length > 0
    ? signalLines.join('\n')
    : '- wrapper-managed session stop: 1 logged event';
  const followUp = enforcementReason
    ? `## Follow-Up Required\n${enforcementReason}\n`
    : '## Follow-Up Required\n- Write a human-readable session summary in `.briefing/sessions/YYYY-MM-DD-<topic>.md`.\n';

  return (
    `---\n` +
    `date: ${today}\n` +
    `type: session-auto\n` +
    `tags: [briefing-vault, codex, auto]\n` +
    `---\n\n` +
    `# Session Scaffold: ${today}\n\n` +
    `## Session Diff\n` +
    `${diffSection}\n\n` +
    `## Files Recorded This Session\n` +
    `${changedSection}\n\n` +
    `## End-of-Session Status For Recorded Files\n` +
    `${statusSection}\n\n` +
    `## Logged Session Signals\n` +
    `${signalSection}\n\n` +
    `${followUp}`
  );
}

function learningAutoContent(today, changedFiles, statusLines, signalLines) {
  const changedSection = changedFiles.length > 0
    ? changedFiles.map((file) => `- ${file}`).join('\n')
    : '- (no files recorded for this Codex session)';
  const statusSection = statusLines.length > 0
    ? statusLines.join('\n')
    : '- clean at session end for recorded files';
  const signalSection = signalLines.length > 0
    ? signalLines.join('\n')
    : '- wrapper-managed session stop: 1 logged event';

  return (
    `---\n` +
    `date: ${today}\n` +
    `type: learning-auto\n` +
    `tags: [briefing-vault, codex, auto]\n` +
    `---\n\n` +
    `# Learning Scaffold: ${today}\n\n` +
    `## Candidate Files To Review\n` +
    `${changedSection}\n\n` +
    `## End-of-Session Status For Recorded Files\n` +
    `${statusSection}\n\n` +
    `## Logged Session Signals\n` +
    `${signalSection}\n\n` +
    `## Candidate Learnings\n` +
    `- Non-obvious behavior encountered:\n` +
    `- Fixes or patterns worth reusing:\n` +
    `- Follow-up risks to capture:\n`
  );
}

function runNodeHook(scriptName, payload) {
  const scriptPath = path.join(process.env.HOME || process.env.USERPROFILE || '', '.codex', 'hooks', scriptName);
  if (!exists(scriptPath)) return '';

  try {
    const result = cp.spawnSync(process.execPath, [scriptPath], {
      input: payload ? JSON.stringify(payload) : '',
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });
    return (result.stdout || '').trim();
  } catch {
    return '';
  }
}

if (!exists(INDEX_FILE)) {
  process.exit(0);
}

mkdirp(path.join(BRIEFING_DIR, 'sessions'));
mkdirp(path.join(BRIEFING_DIR, 'learnings'));
mkdirp(path.join(BRIEFING_DIR, 'agents'));
mkdirp(path.join(BRIEFING_DIR, 'references'));
mkdirp(path.join(BRIEFING_DIR, 'persona', 'rules'));
mkdirp(path.join(BRIEFING_DIR, 'persona', 'skills'));

const today = currentDate();
const sessionHeadPath = path.join(BRIEFING_DIR, '.session-start-head');
const baseRef = readText(sessionHeadPath).trim();
const rawInput = readStdin();
const payload = tryParseJson(rawInput);
const agentLogPath = path.join(BRIEFING_DIR, 'agents', 'agent-log.jsonl');
const noisePaths = readHookNoisePaths();
const startStatusRecords = readStatusSnapshot();
const syncOnly = process.env.MY_CODEX_SESSION_SYNC_ONLY === '1';

const appendedChangedFiles = syncOnly ? sessionChangedFiles() : appendWrapperAgentEvent(agentLogPath, payload);
const endStatusSnapshot = gitStatusRecords([]);
const changedFiles = uniquePaths(
  appendedChangedFiles
    .filter((filePath) => !shouldIgnoreSessionPath(filePath, noisePaths))
    .concat(fallbackChangedFilesFromStatus(startStatusRecords, endStatusSnapshot, noisePaths))
);
const statusRecords = gitStatusRecords(changedFiles);
const statusLines = endStatusLines(statusRecords);
const preProfileSignalLines = todaySignalLines(agentLogPath, today);

const sessionAutoPath = path.join(BRIEFING_DIR, 'sessions', `${today}-auto.md`);
const learningAutoPath = path.join(BRIEFING_DIR, 'learnings', `${today}-auto-session.md`);

writeText(sessionAutoPath, sessionAutoContent(today, baseRef, changedFiles, statusRecords, statusLines, preProfileSignalLines, ''));
writeText(learningAutoPath, learningAutoContent(today, changedFiles, statusLines, preProfileSignalLines));

if (!syncOnly) {
  runNodeHook('stop-profile-update.js', payload || {
    agent_id: 'codex-wrapper-stop',
    agent_type: process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper'
  });
}

const enforcementOutput = runNodeHook('stop-session-enforcement.js', payload || {
  agent_id: 'codex-wrapper-stop',
  agent_type: process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper'
});
const enforcement = tryParseJson(enforcementOutput);
const enforcementReason = enforcement && enforcement.reason ? `- ${enforcement.reason}` : '';
const postProfileSignalLines = todaySignalLines(agentLogPath, today);

writeText(
  sessionAutoPath,
  sessionAutoContent(today, baseRef, changedFiles, statusRecords, statusLines, postProfileSignalLines, enforcementReason)
);
writeText(
  learningAutoPath,
  learningAutoContent(today, changedFiles, statusLines, postProfileSignalLines)
);

if (enforcementReason) {
  process.stderr.write(enforcementReason + '\n');
}
