#!/usr/bin/env node
'use strict';

const cp = require('child_process');
const path = require('path');
const runtime = require('./briefing-runtime');

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

function ensureIndex(projectName) {
  const indexPath = path.join(runtime.BRIEFING_DIR, 'INDEX.md');
  if (runtime.exists(indexPath)) {
    return false;
  }

  runtime.writeText(indexPath, [
    '---',
    `date: ${runtime.currentDate()}`,
    'type: index',
    'tags: [project, index]',
    'language: en',
    '---',
    '',
    `# ${projectName} Knowledge Base`,
    '',
    '## Overview',
    'Project knowledge base. Auto-created by SessionStart hook.',
    '',
    '## Recent Decisions',
    '',
    '## Recent Sessions',
    '',
    '## Recent Learnings',
    '',
    '## Open Questions',
    '',
    '## Key Links',
    '- [[sessions/]] Session logs',
    '- [[decisions/]] Architecture decisions',
    '- [[learnings/]] Patterns and solutions',
    '- [[agents/]] Agent execution logs',
    '- [[references/]] Reference materials',
    ''
  ].join('\n'));

  return true;
}

function main() {
  runtime.mkdirp(runtime.BRIEFING_DIR);
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'sessions'));
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'decisions'));
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'learnings'));
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'agents'));
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'references'));
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'persona', 'rules'));
  runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'persona', 'skills'));

  const projectName = path.basename(process.cwd());
  const indexCreated = ensureIndex(projectName);
  const repoRoot = run('git', ['rev-parse', '--show-toplevel']);
  const startHead = run('git', ['rev-parse', 'HEAD']);
  const startStatus = runtime.parseStatusOutput(runRaw('git', ['status', '--short', '--untracked-files=all']));
  const sessionId = startHead || `${runtime.currentDate()}:${process.cwd()}`;
  const state = runtime.readState();

  let gitignoreChanged = false;
  try {
    const gitignorePath = '.gitignore';
    if (runtime.exists(gitignorePath)) {
      const content = runtime.readText(gitignorePath);
      if (!content.includes('.briefing/')) {
        runtime.writeText(gitignorePath, content + (content.endsWith('\n') || !content ? '' : '\n') + '.briefing/\n');
        gitignoreChanged = true;
      }
    } else {
      runtime.writeText(gitignorePath, '.briefing/\n');
      gitignoreChanged = true;
    }
  } catch {}

  const nextNoise = gitignoreChanged ? runtime.uniquePaths([].concat(state.sessionHookNoise || [], '.gitignore')) : [];

  runtime.writeState(Object.assign(state, {
    sessionStartHead: startHead,
    sessionStartStatus: startStatus,
    sessionMessageCount: 0,
    profileUpdateCounter: 0,
    workCounter: 0,
    prevEntryCount: 0,
    sessionHookNoise: nextNoise,
    sessionId: sessionId,
    date: runtime.currentDate(),
    startedAt: runtime.isoNow(),
    projectName: projectName,
    cwd: process.cwd(),
    repoRoot: repoRoot,
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
    lastUpdatedBy: 'session-start',
    latestSummaryHint: '',
    lastSearchQuery: '',
    lastSearchUrl: ''
  }));

  runtime.cleanupLegacyRuntimeFiles();

  const message = indexCreated
    ? '[BriefingVault] Auto-created .briefing/ and initialized .briefing/state.json.'
    : '[BriefingVault] Loaded .briefing/ and reset .briefing/state.json for this session.';

  process.stdout.write(message);
}

main();
