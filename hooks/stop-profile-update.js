#!/usr/bin/env node
// Stop hook: profile auto-update.
// Runs synchronously; failures are non-fatal.

'use strict';

const fs = require('fs');
const path = require('path');
const runtime = require('./briefing-runtime');

const INDEX_FILE = path.join(runtime.BRIEFING_DIR, 'INDEX.md');
const AGENT_LOG = path.join(runtime.BRIEFING_DIR, 'agents', 'agent-log.jsonl');
const PERSONA_DIR = path.join(runtime.BRIEFING_DIR, 'persona');
const PROFILE_FILE = path.join(PERSONA_DIR, 'profile.md');
const SUGGESTIONS_FILE = path.join(PERSONA_DIR, 'suggestions.jsonl');
const PERSONA_POLICY_FILE = runtime.PERSONA_POLICY_FILE;

function resolveAgentType(entry) {
  let agentType = entry.agent_type || entry.agent || 'unknown';
  if (agentType === 'unknown') {
    agentType = entry.name || entry.description || 'unknown';
  }
  return agentType;
}

function isKnownSignal(agentType) {
  return !!agentType && agentType !== 'unknown';
}

function isSpecialistSignal(agentType) {
  return isKnownSignal(agentType) &&
    agentType !== 'wrapper' &&
    agentType !== 'stop' &&
    agentType !== 'throttled-update' &&
    agentType !== 'mid-session-sync';
}

function countByType(entries, predicate) {
  const counts = {};
  for (const entry of entries) {
    const agentType = resolveAgentType(entry);
    if (!predicate(agentType)) continue;
    counts[agentType] = (counts[agentType] || 0) + 1;
  }
  return counts;
}

function sortedCounts(counts) {
  return Object.keys(counts).map((type) => ({ type, count: counts[type] }))
    .sort((a, b) => b.count - a.count);
}

function totalCount(counts) {
  return Object.keys(counts).reduce((sum, key) => sum + counts[key], 0);
}

function labelForSignal(agentType) {
  if (agentType === 'wrapper') return 'wrapper-managed session stop';
  if (agentType === 'throttled-update') return 'profile refresh';
  if (agentType === 'mid-session-sync') return 'mid-session vault sync';
  return agentType;
}

function eventWord(count) {
  return count === 1 ? 'event' : 'events';
}

function readJsonl(filePath) {
  const entries = [];
  if (!fs.existsSync(filePath)) return entries;

  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    for (const line of raw.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        const entry = JSON.parse(trimmed);
        if (entry && entry.ts) {
          entries.push(entry);
        }
      } catch {}
    }
  } catch (error) {
    process.stderr.write(`stop-profile-update: failed to read ${filePath}: ${error.message}\n`);
  }

  return entries;
}

function recentFiles(subdir, limit) {
  const dir = path.join(runtime.BRIEFING_DIR, subdir);
  if (!fs.existsSync(dir)) return [];
  const files = fs.readdirSync(dir)
    .filter((file) => file.endsWith('.md') && file !== '.gitkeep');
  const dated = files.filter((file) => /^\d{4}-\d{2}-\d{2}/.test(file)).sort().reverse();
  const undated = files.filter((file) => !/^\d{4}-\d{2}-\d{2}/.test(file)).sort();
  return dated.concat(undated)
    .slice(0, limit)
    .map((file) => `- [[${subdir}/${file.replace('.md', '')}]]`);
}

function updateIndex() {
  try {
    if (!fs.existsSync(INDEX_FILE)) return;
    let indexContent = fs.readFileSync(INDEX_FILE, 'utf8');
    const sections = {
      'Recent Sessions': recentFiles('sessions', 5),
      'Recent Decisions': recentFiles('decisions', 5),
      'Recent Learnings': recentFiles('learnings', 3)
    };

    Object.keys(sections).forEach((heading) => {
      const lines = sections[heading];
      if (lines.length === 0) return;
      const pattern = new RegExp(`(## ${heading}\\n)([\\s\\S]*?)(?=\\n## |$)`);
      const replacement = `$1${lines.join('\n')}\n\n`;
      if (pattern.test(indexContent)) {
        indexContent = indexContent.replace(pattern, replacement);
      }
    });

    fs.writeFileSync(INDEX_FILE, indexContent);
  } catch (error) {
    process.stderr.write(`INDEX.md update failed: ${error.message}\n`);
  }
}

if (!fs.existsSync(INDEX_FILE)) {
  process.exit(0);
}

try {
  fs.mkdirSync(PERSONA_DIR, { recursive: true });
} catch (error) {
  process.stderr.write(`stop-profile-update: failed to create persona dirs: ${error.message}\n`);
  process.exit(0);
}

const logEntries = readJsonl(AGENT_LOG);
const sessionState = runtime.readState();
const profileState = runtime.readState();
const now = new Date();
const todayStr = now.toISOString().slice(0, 10);
const ms30d = 30 * 24 * 60 * 60 * 1000;
const ms7d = 7 * 24 * 60 * 60 * 1000;

const entries30d = logEntries.filter((entry) => {
  try {
    return (now - new Date(entry.ts)) <= ms30d;
  } catch {
    return false;
  }
});

const entries7d = logEntries.filter((entry) => {
  try {
    return (now - new Date(entry.ts)) <= ms7d;
  } catch {
    return false;
  }
});

const signalCounts30d = countByType(entries30d, isKnownSignal);
const specialistCounts30d = countByType(entries30d, isSpecialistSignal);
const signalList = sortedCounts(signalCounts30d).slice(0, 10);
const specialistList = sortedCounts(specialistCounts30d).slice(0, 10);
const totalSignals30d = totalCount(signalCounts30d);
const totalSpecialistSignals30d = totalCount(specialistCounts30d);
const wrapperSignals30d = signalCounts30d.wrapper || 0;
const pattern7d = countByType(entries7d, isSpecialistSignal);
const existingSuggestions = readJsonl(SUGGESTIONS_FILE);
const personaPolicy = runtime.readPersonaPolicy();

const newSuggestions = [];
for (const agentType of Object.keys(pattern7d)) {
  const count = pattern7d[agentType];
  if (count < 3) continue;

  let blocked = false;
  for (const suggestion of existingSuggestions) {
    if (suggestion.agent_type !== agentType) continue;
    if (suggestion.type === 'pending' || suggestion.type === 'accepted') {
      blocked = true;
      break;
    }
    if (suggestion.type === 'rejected' && suggestion.cooldown_until) {
      try {
        if (new Date(suggestion.cooldown_until) > now) {
          blocked = true;
          break;
        }
      } catch {}
    }
  }

  if (!blocked) {
    newSuggestions.push({
      type: 'pending',
      pattern: `${agentType}>=3`,
      agent_type: agentType,
      count,
      ts: now.toISOString(),
      message: `You logged ${agentType} ${count} times in 7 days. Add a soft routing preference for ${agentType} to persona-policy.json?`
    });
  }
}

if (newSuggestions.length > 0) {
  try {
    const appendStr = newSuggestions.map((entry) => JSON.stringify(entry)).join('\n') + '\n';
    fs.appendFileSync(SUGGESTIONS_FILE, appendStr);
  } catch (error) {
    process.stderr.write(`stop-profile-update: failed to write suggestions: ${error.message}\n`);
  }
}

const currentSessionMarker = sessionState.sessionStartHead || sessionState.sessionId || '';
if (currentSessionMarker && profileState.lastCountedSession !== currentSessionMarker) {
  profileState.sessionCount = (profileState.sessionCount || 0) + 1;
  profileState.lastCountedSession = currentSessionMarker;
}
profileState.lastProfileUpdateAt = now.toISOString();
profileState.profileUpdateCounter = 0;
runtime.writeState(profileState);

const signalLines = signalList.length > 0 && totalSignals30d > 0
  ? signalList.map((signal) => {
    const pct = Math.round(signal.count / totalSignals30d * 100);
    const suffix = signal.type === 'wrapper' ? ' (session-level)' : '';
    return `- ${labelForSignal(signal.type)}: ${pct}% (${signal.count}/${totalSignals30d} logged ${eventWord(signal.count)}, rolling 30d)${suffix}`;
  }).join('\n')
  : '(no data yet)';

const specialistLines = specialistList.length > 0 && totalSpecialistSignals30d > 0
  ? specialistList.map((signal) => {
    const pct = Math.round(signal.count / totalSpecialistSignals30d * 100);
    return `- ${signal.type}: ${pct}% (${signal.count}/${totalSpecialistSignals30d} specialist signals, rolling 30d)`;
  }).join('\n')
  : (totalSignals30d > 0
    ? '(no specialist-level signals yet; only wrapper/session events recorded)'
    : '(no data yet)');

let philosophyContent = 'Insufficient signal. Keep this profile terse until the session history contains clearer patterns.';
if (specialistList.length >= 1 && totalSpecialistSignals30d >= 3) {
  const topAgent = specialistList[0].type;
  const topPct = Math.round(specialistList[0].count / totalSpecialistSignals30d * 100);
  philosophyContent =
    `Observed style: ${topPct > 40 ? 'heavily' : 'moderately'} ${topAgent}-leaning workflow.\n` +
    `Specialist signals over 30d: ${totalSpecialistSignals30d}.`;
} else if (totalSignals30d > 0) {
  philosophyContent =
    'Only wrapper/session-level signals have been observed so far.\n' +
    'Do not overfit specialist preferences until richer signals exist.';
}

const recentPrompts = (sessionState.prompts || []).slice(-3).map((entry) => `- ${entry.excerpt || entry.text}`).join('\n') || '(none captured)';
const recentLinks = (sessionState.links || []).slice(-5).map((entry) => {
  const target = entry.url || entry.query || '(unknown reference)';
  return `- ${target}${entry.context ? ` -- ${entry.context}` : ''}`;
}).join('\n') || '(no captured links)';

const activePreferences = Object.keys(personaPolicy.preferences || {}).sort();
const preferenceLines = activePreferences.length > 0
  ? activePreferences.map((agentType) => {
    const pref = personaPolicy.preferences[agentType] || {};
    const count = pref.observed_count_7d ? ` (${pref.observed_count_7d} calls/7d at acceptance)` : '';
    return `- ${agentType}: ${pref.preference || 'prefer'}${count}`;
  }).join('\n')
  : '(none yet)';

const profileContent = [
  '---',
  `date: ${todayStr}`,
  'type: persona',
  'version: 2',
  `session_count: ${profileState.sessionCount || 0}`,
  '---',
  '# User Profile',
  '',
  '## Philosophy',
  philosophyContent,
  '',
  '## Current Session Snapshot',
  `- Project: ${sessionState.projectName || path.basename(process.cwd())}`,
  `- Prompt count this session: ${sessionState.promptCount || 0}`,
  `- Edit/search/subagent counts: ${sessionState.editCount || 0}/${sessionState.searchCount || 0}/${sessionState.subagentCount || 0}`,
  `- Changed files: ${(sessionState.changedFiles || []).length}`,
  '',
  '## Recent Prompt Themes',
  recentPrompts,
  '',
  '## Recent References',
  recentLinks,
  '',
  '## Logged Signals',
  signalLines,
  '',
  '## Specialist Preferences',
  specialistLines,
  '',
  '## Active Persona Policy',
  preferenceLines,
  ''
].join('\n');

try {
  fs.writeFileSync(PROFILE_FILE, profileContent);
} catch (error) {
  process.stderr.write(`stop-profile-update: failed to write profile.md: ${error.message}\n`);
  process.exit(0);
}

const todayEntries = logEntries.filter((entry) => entry.ts && entry.ts.slice(0, 10) === todayStr);
const dayCounts = countByType(todayEntries, isKnownSignal);
const dayTotal = totalCount(dayCounts);
const daySpecialistCounts = countByType(todayEntries, isSpecialistSignal);
let dayMostActive = 'none';
let dayMostCount = 0;
for (const type of Object.keys(daySpecialistCounts)) {
  if (daySpecialistCounts[type] > dayMostCount) {
    dayMostCount = daySpecialistCounts[type];
    dayMostActive = type;
  }
}

let agentLines = '';
for (const type of Object.keys(dayCounts)) {
  agentLines += `- ${labelForSignal(type)}: ${dayCounts[type]} logged ${eventWord(dayCounts[type])}\n`;
}
if (!agentLines) agentLines = '(no signals logged)\n';

const summaryContent = [
  '---',
  `date: ${todayStr}`,
  'type: agent-log',
  `session_count: ${profileState.sessionCount || 0}`,
  `total_calls: ${dayTotal}`,
  '---',
  `# Session Signal Summary -- ${todayStr}`,
  '',
  '## Logged Signals',
  agentLines.trimEnd(),
  '',
  '## Session Stats',
  `- Total logged signals today: ${dayTotal}`,
  `- Most active specialist: ${dayMostActive}`,
  `- Prompt/edit/search counts: ${sessionState.promptCount || 0}/${sessionState.editCount || 0}/${sessionState.searchCount || 0}`,
  `- Changed files this session: ${(sessionState.changedFiles || []).length}`,
  ''
].join('\n');

try {
  const agentsDir = path.join(runtime.BRIEFING_DIR, 'agents');
  fs.mkdirSync(agentsDir, { recursive: true });
  fs.writeFileSync(path.join(agentsDir, `${todayStr}-summary.md`), summaryContent);
} catch (error) {
  process.stderr.write(`stop-profile-update: failed to write agent summary: ${error.message}\n`);
}

updateIndex();
process.exit(0);
