#!/usr/bin/env node
// Codex session-end synthesis for Briefing Vault.
// Wrappers and mid-session hooks both call this file.

'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const runtime = require('./briefing-runtime');

const INDEX_FILE = path.join(runtime.BRIEFING_DIR, 'INDEX.md');

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

function gitRoot() {
  return run('git', ['rev-parse', '--show-toplevel']);
}

function gitPath(relativePath) {
  return run('git', ['rev-parse', '--git-path', relativePath]);
}

function isBriefingArtifact(filePath) {
  return filePath === runtime.BRIEFING_DIR || filePath.startsWith(`${runtime.BRIEFING_DIR}/`);
}

function shouldIgnoreSessionPath(filePath, noisePaths) {
  const normalized = runtime.normalizeRepoPath(filePath);
  return !normalized ||
    normalized === '.gitignore' ||
    isBriefingArtifact(normalized) ||
    (noisePaths || []).includes(normalized);
}

function sessionChangedFiles() {
  const stateDir = gitPath('my-codex-attribution');
  if (!stateDir) return [];
  const changedPath = path.join(stateDir, 'changed-files.txt');
  if (!runtime.exists(changedPath)) return [];
  return runtime.uniquePaths(runtime.readText(changedPath)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean));
}

function gitStatusRecords(paths) {
  const args = ['status', '--short', '--untracked-files=all'];
  if (paths.length > 0) {
    args.push('--', ...paths);
  }
  return runtime.parseStatusOutput(runRaw('git', args));
}

function fallbackChangedFilesFromStatus(startRecords, endRecords, noisePaths) {
  const startMap = new Map((startRecords || []).map((record) => [record.path, record.line]));
  const endMap = new Map((endRecords || []).map((record) => [record.path, record.line]));
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

function changedFilesSummary(changedFiles) {
  if (changedFiles.length === 0) {
    return ['- No code or tracked file changes were recorded for this session.'];
  }
  return changedFiles.map((filePath) => `- ${filePath}`);
}

function changedFilesInline(changedFiles) {
  if (!changedFiles || changedFiles.length === 0) return '(none)';
  return changedFiles.join(', ');
}

function promptSummaryLines(prompts) {
  if (!prompts || prompts.length === 0) {
    return ['- No prompt text was captured for this session.'];
  }
  return prompts.slice(-5).map((entry, index) => {
    const prefix = index === prompts.slice(-5).length - 1 ? 'latest' : `prompt ${index + 1}`;
    return `- ${prefix}: ${entry.excerpt || entry.text}`;
  });
}

function meaningfulPromptTexts(state) {
  return (state.prompts || [])
    .map((entry) => (entry.excerpt || entry.text || '').trim())
    .filter(Boolean);
}

function promptSignal(promptTexts, keywords) {
  const hits = [];
  for (const text of promptTexts || []) {
    const lower = text.toLowerCase();
    for (const keyword of keywords) {
      if (lower.includes(keyword)) {
        hits.push(text);
        break;
      }
    }
  }
  return hits;
}

function slugifyTopic(text, fallback) {
  const stopwords = new Set([
    'the', 'and', 'for', 'with', 'from', 'this', 'that', 'into', 'about', 'should', 'would',
    'could', 'have', 'has', 'had', 'feel', 'like', 'real', 'note', 'notes', 'session',
    'summary', 'summaries', 'work', 'done', 'capture', 'finalize', 'list', 'check',
    'guide', 'implementation', 'remaining', 'follow', 'followups', 'follow-up', 'quality'
  ]);
  const words = String(text || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, ' ')
    .split(/\s+/)
    .map((word) => word.trim())
    .filter(Boolean)
    .filter((word) => word.length > 2 && !stopwords.has(word));
  const picked = [];
  for (const word of words) {
    if (!picked.includes(word)) picked.push(word);
    if (picked.length >= 5) break;
  }
  if (picked.length === 0) {
    return fallback;
  }
  return picked.join('-');
}

function deriveTopicSlug(state, changedFiles, kind) {
  const prompts = meaningfulPromptTexts(state);
  const first = prompts[0] || '';
  const latest = prompts[prompts.length - 1] || first || '';
  const allPromptText = prompts.join(' ');
  const fileHint = (changedFiles[0] || '').split('/').pop() || '';

  if (kind === 'session') {
    return slugifyTopic(first || allPromptText || fileHint, 'session-work');
  }
  if (kind === 'decision') {
    return slugifyTopic(allPromptText || latest || fileHint, 'decision-rationale');
  }
  if (kind === 'learning') {
    return slugifyTopic(latest || allPromptText || fileHint, 'reusable-pattern');
  }
  return slugifyTopic(latest || fileHint, 'briefing-note');
}

function decisionSignal(state, changedFiles) {
  const prompts = meaningfulPromptTexts(state);
  const keywords = [
    'decision', 'decisions', 'choose', 'chosen', 'choice', 'policy', 'routing',
    'route', 'prefer', 'install path', 'consolidate', 'replace', 'switch', 'adopt'
  ];
  const matchedPrompts = promptSignal(prompts, keywords);
  const policy = runtime.readPersonaPolicy();
  const hasPolicy = Object.keys(policy.preferences || {}).length > 0;
  const shouldPromote = matchedPrompts.length > 0 || hasPolicy;

  return {
    shouldPromote,
    matchedPrompts,
    hasPolicy,
    slug: slugifyTopic((matchedPrompts[0] || prompts[0] || changedFiles[0] || ''), 'decision-rationale')
  };
}

function learningSignal(state, changedFiles) {
  const prompts = meaningfulPromptTexts(state);
  const keywords = [
    'learning', 'learnings', 'reusable', 'pattern', 'patterns', 'why', 'worked',
    'works', 'gotcha', 'warning', 'avoid', 'fix', 'solution', 'problem'
  ];
  const matchedPrompts = promptSignal(prompts, keywords);
  const shouldPromote = matchedPrompts.length > 0;

  return {
    shouldPromote,
    matchedPrompts,
    slug: slugifyTopic((matchedPrompts[matchedPrompts.length - 1] || changedFiles[0] || prompts[prompts.length - 1] || ''), 'reusable-pattern')
  };
}

function topicNotePath(subdir, today, slug) {
  return path.join(runtime.BRIEFING_DIR, subdir, `${today}-${slug}.md`);
}

function firstExistingTopicNote(subdir, today) {
  const dir = path.join(runtime.BRIEFING_DIR, subdir);
  if (!runtime.exists(dir)) return '';
  const names = fs.readdirSync(dir)
    .filter((name) => name.startsWith(`${today}-`) && !name.includes('-auto'))
    .sort();
  return names.length > 0 ? path.join(dir, names[0]) : '';
}

function actionLines(state, diffSummary, signalLines) {
  const lines = [];
  const workBits = [];

  if ((state.editCount || 0) > 0) workBits.push(`${state.editCount} edit hook event(s)`);
  if ((state.searchCount || 0) > 0) workBits.push(`${state.searchCount} search event(s)`);
  if ((state.subagentCount || 0) > 0) workBits.push(`${state.subagentCount} subagent event(s)`);
  if ((state.promptCount || 0) > 0) workBits.push(`${state.promptCount} prompt(s)`);

  if (workBits.length > 0) {
    lines.push(`- Recorded activity: ${workBits.join(', ')}.`);
  }
  if (diffSummary) {
    lines.push(`- Diff summary: ${diffSummary}.`);
  }
  if ((state.changedFiles || []).length > 0) {
    lines.push(`- Changed area summary: ${runtime.summarizePaths(state.changedFiles) || `${state.changedFiles.length} file(s)`}.`);
  }
  if ((state.links || []).length > 0) {
    lines.push(`- Gathered ${state.links.length} reference link(s) during the session.`);
  }
  if (signalLines.length > 0) {
    lines.push(`- Logged signals: ${signalLines.map((line) => line.replace(/^- /, '')).join('; ')}.`);
  }
  return lines.length > 0 ? lines : ['- No meaningful work signals were recorded.'];
}

function inferDecisionCandidates(state, changedFiles) {
  const candidates = [];
  const promptTexts = (state.prompts || []).map((entry) => entry.excerpt || entry.text).filter(Boolean);
  const promptBlob = promptTexts.join(' ').toLowerCase();

  if ((state.changedFiles || []).length > 0) {
    candidates.push(`- State and hook wiring changed across ${changedFilesInline(changedFiles)}.`);
  }
  if ((state.searchCount || 0) > 0) {
    candidates.push('- External references were used, so any adopted pattern should be captured with rationale.');
  }
  if (promptBlob.includes('policy') || promptBlob.includes('routing') || promptBlob.includes('persona')) {
    candidates.push('- Persona or routing behavior changed; capture the new policy boundary and why it exists.');
  }
  if (promptBlob.includes('windows') || promptBlob.includes('install')) {
    candidates.push('- Installation behavior changed; document the expected platform-specific path handling.');
  }
  if (promptBlob.includes('vault') || promptBlob.includes('briefing')) {
    candidates.push('- Vault structure or note-generation behavior changed; capture the intended note contract.');
  }

  return Array.from(new Set(candidates));
}

function referenceLines(links) {
  if (!links || links.length === 0) {
    return ['- No external references were captured.'];
  }
  return links.slice(-10).map((entry) => {
    const label = entry.url || entry.query || '(unknown reference)';
    const context = entry.context ? ` -- ${entry.context}` : '';
    return `- ${label}${context}`;
  });
}

function nextStepLines(changedFiles, enforcementReason, state) {
  const lines = [];
  if (enforcementReason) {
    lines.push(`- ${enforcementReason}`);
  } else {
    lines.push(`- Write .briefing/sessions/${runtime.currentDate()}-<topic>.md if this work should survive beyond the auto scaffold.`);
  }
  if (changedFiles.length > 0) {
    lines.push('- Review the changed files and convert any durable decision into a note under `.briefing/decisions/`.');
  }
  if ((state.links || []).length > 0) {
    lines.push('- Promote any durable external source into a dedicated note under `.briefing/references/` if it will matter again.');
  }
  if ((state.changedFiles || []).length > 0) {
    lines.push(`- If one concrete choice was made, turn it into \`.briefing/decisions/${runtime.currentDate()}-<topic>.md\`.`);
  }
  return lines;
}

function learningCandidateLines(state, changedFiles) {
  const lines = [];
  if (changedFiles.length > 0) {
    lines.push(`- Files worth mining for reusable patterns: ${changedFiles.join(', ')}.`);
  }
  if ((state.links || []).length > 0) {
    const recent = state.links.slice(-3).map((entry) => entry.url || entry.query).filter(Boolean);
    if (recent.length > 0) {
      lines.push(`- External references consulted: ${recent.join(', ')}.`);
    }
  }
  if ((state.prompts || []).length > 0) {
    const lastPrompt = state.prompts[state.prompts.length - 1];
    lines.push(`- Latest user intent: ${lastPrompt.excerpt || lastPrompt.text}.`);
  }
  if ((state.editCount || 0) > 0) {
    lines.push(`- Candidate pattern to capture: workflow that required ${state.editCount} edit cycle(s).`);
  }
  return lines.length > 0 ? lines : ['- No strong learning candidate yet; leave this scaffold thin or delete it.'];
}

function todaySignalLines(agentLogPath, today) {
  if (!runtime.exists(agentLogPath)) return [];
  const counts = {};
  runtime.readText(agentLogPath).split(/\r?\n/).forEach((line) => {
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

function appendWrapperAgentEvent(agentLogPath, payload, state) {
  runtime.mkdirp(path.dirname(agentLogPath));

  const wrapper = (payload && payload.agent_type) || process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper';
  const wrapperId = (payload && payload.agent_id) || process.env.MY_CODEX_SESSION_END_AGENT_ID || 'codex-wrapper-stop';
  const event = {
    ts: new Date().toISOString(),
    agent_id: wrapperId,
    agent_type: wrapper,
    cwd: process.cwd(),
    repo_root: gitRoot() || '',
    changed_files: (state.changedFiles || []).length
  };

  try {
    fs.appendFileSync(agentLogPath, JSON.stringify(event) + '\n', 'utf8');
  } catch {}
}

function writeAutoLinks(linksFile, links) {
  if (!links || links.length === 0) return;
  runtime.mkdirp(path.dirname(linksFile));
  const lines = [
    '---',
    `date: ${runtime.currentDate()}`,
    'type: reference-index',
    'tags: [briefing-vault, references, auto]',
    '---',
    '',
    '# Auto Links',
    ''
  ];

  links.slice(-20).forEach((entry) => {
    const target = entry.url || entry.query || '(unknown reference)';
    const context = entry.context ? ` -- ${entry.context}` : '';
    lines.push(`- ${entry.ts.slice(0, 10)} ${target}${context}`);
  });

  runtime.writeText(linksFile, lines.join('\n') + '\n');
}

function sessionAutoContent(today, state, changedFiles, statusLines, signalLines, enforcementReason, diffSummary) {
  const objectiveLines = promptSummaryLines(state.prompts || []);
  const actionSection = actionLines(state, diffSummary, signalLines);
  const changedSection = changedFilesSummary(changedFiles);
  const referenceSection = referenceLines(state.links || []);
  const nextSteps = nextStepLines(changedFiles, enforcementReason, state);

  return [
    '---',
    `date: ${today}`,
    'type: session-auto',
    'tags: [briefing-vault, codex, auto]',
    '---',
    '',
    `# Session Scaffold: ${today}`,
    '',
    '## Goal',
    ...objectiveLines,
    '',
    '## Work Completed',
    ...actionSection,
    '',
    '## Files Changed',
    ...changedSection,
    '',
    '## References Consulted',
    ...referenceSection,
    '',
    '## Current Working Tree',
    ...statusLines,
    '',
    '## Next Steps',
    ...nextSteps,
    ''
  ].join('\n');
}

function sessionTopicContent(today, slug, state, changedFiles, diffSummary, references) {
  const prompts = meaningfulPromptTexts(state);
  const title = slug.split('-').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
  return [
    '---',
    `date: ${today}`,
    'type: session',
    'tags: [session, codex]',
    'related: []',
    '---',
    '',
    `# Session: ${title}`,
    '',
    '## Goal',
    ...(prompts.length > 0 ? [`- ${prompts[0]}`] : ['- Goal was inferred from the captured session context.']),
    '',
    '## Actions',
    ...actionLines(state, diffSummary, []),
    '',
    '## Results',
    ...(changedFiles.length > 0 ? [`- Changed files: ${changedFilesInline(changedFiles)}.`] : ['- No tracked file changes were recorded.']),
    ...((state.links || []).length > 0 ? [`- Consulted ${state.links.length} reference link(s) while shaping the result.`] : []),
    '',
    '## References',
    ...(references.length > 0 ? references : ['- No external references were captured.']),
    '',
    '## Next Steps',
    '- Promote any durable architectural choice into a dedicated decision note.',
    '- Promote any reusable technique or warning into a dedicated learning note.',
    ''
  ].join('\n');
}

function learningAutoContent(today, state, changedFiles, statusLines, signalLines) {
  const candidates = learningCandidateLines(state, changedFiles);
  return [
    '---',
    `date: ${today}`,
    'type: learning-auto',
    'tags: [briefing-vault, codex, auto]',
    '---',
    '',
    `# Learning Scaffold: ${today}`,
    '',
    '## What Seems Reusable',
    ...candidates,
    '',
    '## Supporting Signals',
    ...(signalLines.length > 0 ? signalLines : ['- No strong specialist or wrapper signal was logged yet.']),
    '',
    '## Files To Revisit',
    ...changedFilesSummary(changedFiles),
    '',
    '## Current Working Tree',
    ...statusLines,
    '',
    '## Suggested Follow-Up',
    '- Turn one durable pattern into `.briefing/learnings/YYYY-MM-DD-<topic>.md`.',
    '- Delete this scaffold if the session did not produce a real reusable lesson.',
    ''
  ].join('\n');
}

function learningTopicContent(today, slug, state, changedFiles, learningInfo) {
  const title = slug.split('-').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
  const matched = (learningInfo && learningInfo.matchedPrompts) || [];
  const latestPrompt = matched.slice(-1)[0] || meaningfulPromptTexts(state).slice(-1)[0] || 'The session surfaced a reusable pattern.';
  return [
    '---',
    `date: ${today}`,
    'type: learning',
    'tags: [pattern, codex]',
    'related: []',
    '---',
    '',
    `# Learning: ${title}`,
    '',
    '## Problem',
    `- ${latestPrompt}`,
    '',
    '## Solution',
    ...(learningCandidateLines(state, changedFiles).map((line) => line.replace(/^- /, '- '))),
    '',
    '## Why It Works',
    ...(changedFiles.length > 0
      ? [`- The pattern was grounded in changes across ${changedFilesInline(changedFiles)}.`]
      : ['- This learning was inferred from the captured prompts and references.']),
    ''
  ].join('\n');
}

function decisionAutoContent(today, state, changedFiles, signalLines, references) {
  const candidates = inferDecisionCandidates(state, changedFiles);
  return [
    '---',
    `date: ${today}`,
    'type: decision-auto',
    'tags: [briefing-vault, codex, auto]',
    '---',
    '',
    `# Decision Scaffold: ${today}`,
    '',
    '## Candidate Decisions',
    ...(candidates.length > 0 ? candidates : ['- No durable architectural or workflow decision was confidently detected yet.']),
    '',
    '## Why This Might Matter',
    `- Changed files: ${changedFilesInline(changedFiles)}.`,
    `- Prompt/edit/search counts: ${state.promptCount || 0}/${state.editCount || 0}/${state.searchCount || 0}.`,
    '',
    '## Supporting Signals',
    ...(signalLines.length > 0 ? signalLines : ['- No strong routing or wrapper signal was logged yet.']),
    '',
    '## References In Play',
    ...(references.length > 0 ? references : ['- No external references were captured.']),
    '',
    '## Suggested Follow-Up',
    `- If a real decision was made, write \`.briefing/decisions/${today}-<topic>.md\` with context, choice, and consequences.`,
    '- Delete this scaffold if the session contained implementation churn but no durable decision.',
    ''
  ].join('\n');
}

function decisionTopicContent(today, slug, state, changedFiles, references, decisionInfo) {
  const title = slug.split('-').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
  const candidates = inferDecisionCandidates(state, changedFiles);
  const matched = (decisionInfo && decisionInfo.matchedPrompts) || [];
  const policy = runtime.readPersonaPolicy();
  const policyAgents = Object.keys(policy.preferences || {});
  return [
    '---',
    `date: ${today}`,
    'type: decision',
    'tags: [architecture, codex]',
    'status: accepted',
    'related: []',
    '---',
    '',
    `# Decision: ${title}`,
    '',
    '## Context',
    ...(candidates.length > 0 ? candidates : ['- A durable decision was inferred from the session context.']),
    ...(matched.length > 0 ? [`- Prompt evidence: ${matched[0]}.`] : []),
    ...(policyAgents.length > 0 ? [`- Active persona policy in scope: ${policyAgents.join(', ')}.`] : []),
    '',
    '## Options Considered',
    '- Keep the previous behavior and continue relying on the auto scaffold only.',
    '- Promote the durable choice into a named project note for future sessions.',
    '',
    '## Decision',
    '- Promote this session outcome into a named note so future sessions can reuse it without re-reading the scaffold.',
    '',
    '## Consequences',
    ...(references.length > 0
      ? ['- Supporting references were captured and can be revisited if the decision is questioned later.']
      : ['- This decision currently rests on local session evidence only.']),
    ...(changedFiles.length > 0 ? [`- Affected files: ${changedFilesInline(changedFiles)}.`] : []),
    ''
  ].join('\n');
}

function writePromotedNote(subdir, today, slug, contentBuilder) {
  const existing = firstExistingTopicNote(subdir, today);
  if (existing) return existing;
  const filePath = topicNotePath(subdir, today, slug);
  runtime.writeText(filePath, contentBuilder(filePath));
  return filePath;
}

function runNodeHook(scriptName, payload) {
  const scriptPath = path.join(process.env.HOME || process.env.USERPROFILE || '', '.codex', 'hooks', scriptName);
  if (!runtime.exists(scriptPath)) return '';

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

if (!runtime.exists(INDEX_FILE)) {
  process.exit(0);
}

runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'sessions'));
runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'learnings'));
runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'decisions'));
runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'agents'));
runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'references'));
runtime.mkdirp(path.join(runtime.BRIEFING_DIR, 'persona'));
const today = runtime.currentDate();
const rawInput = readStdin();
const payload = tryParseJson(rawInput);
const agentLogPath = path.join(runtime.BRIEFING_DIR, 'agents', 'agent-log.jsonl');
const syncOnly = process.env.MY_CODEX_SESSION_SYNC_ONLY === '1';
const sessionState = runtime.readState();
const startStatusRecords = Array.isArray(sessionState.sessionStartStatus) ? sessionState.sessionStartStatus : [];

const attributionChangedFiles = sessionChangedFiles()
  .filter((filePath) => !shouldIgnoreSessionPath(filePath, sessionState.sessionHookNoise));
const endStatusSnapshot = gitStatusRecords([]);
const fallbackFiles = fallbackChangedFilesFromStatus(startStatusRecords, endStatusSnapshot, sessionState.sessionHookNoise);

sessionState.changedFiles = runtime.uniquePaths([]
  .concat(sessionState.changedFiles || [], attributionChangedFiles, fallbackFiles)
  .filter((filePath) => !shouldIgnoreSessionPath(filePath, sessionState.sessionHookNoise)));

if (!syncOnly) {
  sessionState.wrapperStopCount = (sessionState.wrapperStopCount || 0) + 1;
  sessionState.lastUpdatedBy = 'wrapper-stop';
  runtime.writeState(sessionState);
  appendWrapperAgentEvent(agentLogPath, payload, sessionState);
}

const statusRecords = gitStatusRecords(sessionState.changedFiles || [])
  .filter((record) => !shouldIgnoreSessionPath(record.path, sessionState.sessionHookNoise));
const statusLines = endStatusLines(statusRecords);
const diffSummary = gitTrackedDiffSummary(sessionState.sessionStartHead, sessionState.changedFiles || []);
const preProfileSignalLines = todaySignalLines(agentLogPath, today);
const linksFile = path.join(runtime.BRIEFING_DIR, 'references', 'auto-links.md');
const decisionAutoPath = path.join(runtime.BRIEFING_DIR, 'decisions', `${today}-auto.md`);
const referenceSection = referenceLines(sessionState.links || []);

writeAutoLinks(linksFile, sessionState.links || []);

const sessionAutoPath = path.join(runtime.BRIEFING_DIR, 'sessions', `${today}-auto.md`);
const learningAutoPath = path.join(runtime.BRIEFING_DIR, 'learnings', `${today}-auto-session.md`);

runtime.writeText(
  sessionAutoPath,
  sessionAutoContent(today, sessionState, sessionState.changedFiles || [], statusLines, preProfileSignalLines, '', diffSummary)
);
runtime.writeText(
  learningAutoPath,
  learningAutoContent(today, sessionState, sessionState.changedFiles || [], statusLines, preProfileSignalLines)
);
runtime.writeText(
  decisionAutoPath,
  decisionAutoContent(today, sessionState, sessionState.changedFiles || [], preProfileSignalLines, referenceSection)
);

if (!syncOnly) {
  runNodeHook('stop-profile-update.js', payload || {
    agent_id: 'codex-wrapper-stop',
    agent_type: process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper'
  });
}

if (!syncOnly) {
  const sessionSlug = deriveTopicSlug(sessionState, sessionState.changedFiles || [], 'session');
  const changedFiles = sessionState.changedFiles || [];
  const learningInfo = learningSignal(sessionState, changedFiles);
  const decisionInfo = decisionSignal(sessionState, changedFiles);
  const learningSlug = learningInfo.slug;
  const decisionSlug = decisionInfo.slug;

  if ((sessionState.promptCount || 0) > 0 || changedFiles.length > 0 || (sessionState.links || []).length > 0) {
    writePromotedNote('sessions', today, sessionSlug, function() {
      return sessionTopicContent(today, sessionSlug, sessionState, changedFiles, diffSummary, referenceSection);
    });
  }
  if (learningInfo.shouldPromote) {
    writePromotedNote('learnings', today, learningSlug, function() {
      return learningTopicContent(today, learningSlug, sessionState, changedFiles, learningInfo);
    });
  }
  if (decisionInfo.shouldPromote) {
    writePromotedNote('decisions', today, decisionSlug, function() {
      return decisionTopicContent(today, decisionSlug, sessionState, changedFiles, referenceSection, decisionInfo);
    });
  }
}

const enforcementOutput = runNodeHook('stop-session-enforcement.js', payload || {
  agent_id: 'codex-wrapper-stop',
  agent_type: process.env.MY_CODEX_SESSION_END_AGENT_TYPE || 'wrapper'
});
const enforcement = tryParseJson(enforcementOutput);
const enforcementReason = enforcement && enforcement.reason ? enforcement.reason : '';
const postProfileSignalLines = todaySignalLines(agentLogPath, today);

runtime.writeText(
  sessionAutoPath,
  sessionAutoContent(today, sessionState, sessionState.changedFiles || [], statusLines, postProfileSignalLines, enforcementReason, diffSummary)
);
runtime.writeText(
  learningAutoPath,
  learningAutoContent(today, sessionState, sessionState.changedFiles || [], statusLines, postProfileSignalLines)
);
runtime.writeText(
  decisionAutoPath,
  decisionAutoContent(today, sessionState, sessionState.changedFiles || [], postProfileSignalLines, referenceSection)
);

if (enforcementReason) {
  process.stderr.write(enforcementReason + '\n');
}
