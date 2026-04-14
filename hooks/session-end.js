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

function sessionChangedFiles() {
  const stateDir = gitPath('my-codex-attribution');
  if (!stateDir) return [];
  const changedPath = path.join(stateDir, 'changed-files.txt');
  if (!exists(changedPath)) return [];
  return readText(changedPath)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function gitStatusLines() {
  const output = run('git', ['status', '--short']);
  if (!output) return [];
  return output.split(/\r?\n/).filter(Boolean);
}

function gitDiffSummary(baseRef) {
  if (!baseRef) return [];
  const output = run('git', ['diff', '--shortstat', `${baseRef}..HEAD`]);
  return output ? [output] : [];
}

function todayAgentLines(agentLogPath, today) {
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
    .map((name) => `- ${name}: ${counts[name]} calls`);
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

function sessionAutoContent(today, baseRef, changedFiles, statusLines, agentLines, enforcementReason) {
  const diffLines = gitDiffSummary(baseRef);
  const changedSection = changedFiles.length > 0
    ? changedFiles.map((file) => `- ${file}`).join('\n')
    : '- (no files recorded for this Codex session)';
  const statusSection = statusLines.length > 0
    ? statusLines.map((line) => `- ${line}`).join('\n')
    : '- working tree clean at session end';
  const diffSection = diffLines.length > 0
    ? diffLines.map((line) => `- ${line}`).join('\n')
    : '- no committed diff since session start';
  const agentSection = agentLines.length > 0
    ? agentLines.join('\n')
    : '- wrapper: 1 call';
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
    `## Working Tree Snapshot\n` +
    `${statusSection}\n\n` +
    `## Agent Activity\n` +
    `${agentSection}\n\n` +
    `${followUp}`
  );
}

function learningAutoContent(today, changedFiles, statusLines) {
  const changedSection = changedFiles.length > 0
    ? changedFiles.map((file) => `- ${file}`).join('\n')
    : '- (no files recorded for this Codex session)';
  const statusSection = statusLines.length > 0
    ? statusLines.map((line) => `- ${line}`).join('\n')
    : '- working tree clean at session end';

  return (
    `---\n` +
    `date: ${today}\n` +
    `type: learning-auto\n` +
    `tags: [briefing-vault, codex, auto]\n` +
    `---\n\n` +
    `# Learning Scaffold: ${today}\n\n` +
    `## Candidate Files To Review\n` +
    `${changedSection}\n\n` +
    `## Working Tree Snapshot\n` +
    `${statusSection}\n\n` +
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

const changedFiles = appendWrapperAgentEvent(agentLogPath, payload);
const statusLines = gitStatusLines();
const preProfileAgentLines = todayAgentLines(agentLogPath, today);

const sessionAutoPath = path.join(BRIEFING_DIR, 'sessions', `${today}-auto.md`);
const learningAutoPath = path.join(BRIEFING_DIR, 'learnings', `${today}-auto-session.md`);

writeText(sessionAutoPath, sessionAutoContent(today, baseRef, changedFiles, statusLines, preProfileAgentLines, ''));
writeText(learningAutoPath, learningAutoContent(today, changedFiles, statusLines));

runNodeHook('stop-profile-update.js', payload || {
  agent_id: 'codex-wrapper-stop',
  agent_type: process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper'
});

const enforcementOutput = runNodeHook('stop-session-enforcement.js', payload || {
  agent_id: 'codex-wrapper-stop',
  agent_type: process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper'
});
const enforcement = tryParseJson(enforcementOutput);
const enforcementReason = enforcement && enforcement.reason ? `- ${enforcement.reason}` : '';
const postProfileAgentLines = todayAgentLines(agentLogPath, today);

writeText(
  sessionAutoPath,
  sessionAutoContent(today, baseRef, changedFiles, statusLines, postProfileAgentLines, enforcementReason)
);

if (enforcementReason) {
  process.stderr.write(enforcementReason + '\n');
}
