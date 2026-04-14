#!/usr/bin/env node
// Stop hook: profile auto-update.
// Runs synchronously; failures are non-fatal.

const fs = require('fs');
const path = require('path');

const BRIEFING_DIR = '.briefing';
const INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');
const AGENT_LOG = path.join(BRIEFING_DIR, 'agents', 'agent-log.jsonl');
const PERSONA_DIR = path.join(BRIEFING_DIR, 'persona');
const PROFILE_FILE = path.join(PERSONA_DIR, 'profile.md');
const SUGGESTIONS_FILE = path.join(PERSONA_DIR, 'suggestions.jsonl');

function resolveAgentType(entry) {
  var agentType = entry.agent_type || entry.agent || 'unknown';
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
    agentType !== 'throttled-update';
}

function countByType(entries, predicate) {
  var counts = {};
  for (var i = 0; i < entries.length; i++) {
    var agentType = resolveAgentType(entries[i]);
    if (!predicate(agentType)) continue;
    counts[agentType] = (counts[agentType] || 0) + 1;
  }
  return counts;
}

function sortedCounts(counts) {
  return Object.keys(counts).map(function(type) {
    return { type: type, count: counts[type] };
  }).sort(function(a, b) {
    return b.count - a.count;
  });
}

function totalCount(counts) {
  return Object.keys(counts).reduce(function(sum, key) {
    return sum + counts[key];
  }, 0);
}

function labelForSignal(agentType) {
  if (agentType === 'wrapper') return 'wrapper-managed session stop';
  if (agentType === 'throttled-update') return 'throttled profile update';
  return agentType;
}

function eventWord(count) {
  return count === 1 ? 'event' : 'events';
}

function readJsonl(filePath) {
  var entries = [];
  if (!fs.existsSync(filePath)) return entries;

  try {
    var raw = fs.readFileSync(filePath, 'utf8');
    var lines = raw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line) continue;
      try {
        var entry = JSON.parse(line);
        if (entry && entry.ts) {
          entries.push(entry);
        }
      } catch (e) {
        // skip malformed lines
      }
    }
  } catch (e) {
    process.stderr.write('stop-profile-update: failed to read ' + filePath + ': ' + e.message + '\n');
  }

  return entries;
}

if (!fs.existsSync(INDEX_FILE)) {
  process.exit(0);
}

try {
  fs.mkdirSync(path.join(PERSONA_DIR, 'rules'), { recursive: true });
  fs.mkdirSync(path.join(PERSONA_DIR, 'skills'), { recursive: true });
} catch (e) {
  process.stderr.write('stop-profile-update: failed to create persona dirs: ' + e.message + '\n');
  process.exit(0);
}

var logEntries = readJsonl(AGENT_LOG);

var now = new Date();
var ms30d = 30 * 24 * 60 * 60 * 1000;
var ms7d = 7 * 24 * 60 * 60 * 1000;

var entries30d = logEntries.filter(function(entry) {
  try {
    return (now - new Date(entry.ts)) <= ms30d;
  } catch (err) {
    return false;
  }
});
var entries7d = logEntries.filter(function(entry) {
  try {
    return (now - new Date(entry.ts)) <= ms7d;
  } catch (err) {
    return false;
  }
});

var signalCounts30d = countByType(entries30d, isKnownSignal);
var specialistCounts30d = countByType(entries30d, isSpecialistSignal);
var signalList = sortedCounts(signalCounts30d).slice(0, 10);
var specialistList = sortedCounts(specialistCounts30d).slice(0, 10);
var totalSignals30d = totalCount(signalCounts30d);
var totalSpecialistSignals30d = totalCount(specialistCounts30d);
var wrapperSignals30d = signalCounts30d.wrapper || 0;
var pattern7d = countByType(entries7d, isSpecialistSignal);

var existingSuggestions = readJsonl(SUGGESTIONS_FILE);

var newSuggestions = [];
var patternTypes = Object.keys(pattern7d);
for (var i = 0; i < patternTypes.length; i++) {
  var agentType = patternTypes[i];
  var count = pattern7d[agentType];
  if (count < 3) continue;

  var hasCooldown = false;
  var hasPending = false;
  var hasAccepted = false;
  for (var j = 0; j < existingSuggestions.length; j++) {
    var suggestion = existingSuggestions[j];
    if (suggestion.agent_type !== agentType) continue;
    if (suggestion.type === 'rejected' && suggestion.cooldown_until) {
      try {
        if (new Date(suggestion.cooldown_until) > now) {
          hasCooldown = true;
          break;
        }
      } catch (e) {}
    }
    if (suggestion.type === 'pending') {
      hasPending = true;
      break;
    }
    if (suggestion.type === 'accepted') {
      hasAccepted = true;
      break;
    }
  }

  if (hasCooldown || hasPending || hasAccepted) continue;

  newSuggestions.push({
    type: 'pending',
    pattern: agentType + '>=3',
    agent_type: agentType,
    count: count,
    ts: now.toISOString(),
    message: 'You logged ' + agentType + ' ' + count + ' times in 7 days. Create an auto-rule to prefer ' + agentType + ' for matching tasks?'
  });
}

if (newSuggestions.length > 0) {
  try {
    var appendStr = newSuggestions.map(function(suggestion) {
      return JSON.stringify(suggestion);
    }).join('\n') + '\n';
    fs.appendFileSync(SUGGESTIONS_FILE, appendStr);
  } catch (e) {
    process.stderr.write('stop-profile-update: failed to write suggestions: ' + e.message + '\n');
  }
}

var sessionCount = 0;
var existingHistory = '';
try {
  if (fs.existsSync(PROFILE_FILE)) {
    var profileRaw = fs.readFileSync(PROFILE_FILE, 'utf8');
    var scMatch = profileRaw.match(/^session_count:\s*(\d+)/m);
    if (scMatch) {
      sessionCount = parseInt(scMatch[1], 10) || 0;
    }
    var histMatch = profileRaw.match(/## History\n([\s\S]*)$/);
    if (histMatch) {
      existingHistory = histMatch[1].trim();
    }
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to read profile: ' + e.message + '\n');
}

var shouldIncrement = true;
try {
  var sessionIdFile = path.join(BRIEFING_DIR, '.session-start-head');
  var lastCountedFile = path.join(BRIEFING_DIR, '.last-counted-session');
  if (fs.existsSync(sessionIdFile)) {
    var currentSessionId = fs.readFileSync(sessionIdFile, 'utf8').trim();
    if (fs.existsSync(lastCountedFile)) {
      var lastCounted = fs.readFileSync(lastCountedFile, 'utf8').trim();
      if (lastCounted === currentSessionId) {
        shouldIncrement = false;
      }
    }
    if (shouldIncrement) {
      fs.writeFileSync(lastCountedFile, currentSessionId);
    }
  }
} catch (e) {}

if (shouldIncrement) {
  sessionCount += 1;
}

var newHistoryEntry = '';
if (sessionCount >= 5 && sessionCount % 5 === 0) {
  var topSignals = specialistList.length > 0 ? specialistList.slice(0, 3) : signalList.slice(0, 3);
  var historyTotal = specialistList.length > 0 ? totalSpecialistSignals30d : totalSignals30d;
  if (topSignals.length > 0 && historyTotal > 0) {
    var parts = topSignals.map(function(signal) {
      var pct = Math.round(signal.count / historyTotal * 100);
      return labelForSignal(signal.type) + ':' + pct + '%';
    });
    var dateStr = now.toISOString().slice(0, 10);
    newHistoryEntry = '- Session ' + sessionCount + ' (' + dateStr + '): Top logged signals -- ' + parts.join(', ');
  }
}

var historySection = '';
if (newHistoryEntry && existingHistory) {
  historySection = newHistoryEntry + '\n' + existingHistory;
} else if (newHistoryEntry) {
  historySection = newHistoryEntry;
} else {
  historySection = existingHistory;
}

var signalLines = '';
if (signalList.length > 0 && totalSignals30d > 0) {
  signalLines = signalList.map(function(signal) {
    var pct = Math.round(signal.count / totalSignals30d * 100);
    var suffix = signal.type === 'wrapper' ? ' (session-level)' : '';
    return '- ' + labelForSignal(signal.type) + ': ' + pct + '% (' + signal.count + '/' + totalSignals30d + ' logged ' + eventWord(signal.count) + ', rolling 30d)' + suffix;
  }).join('\n');
} else {
  signalLines = '(no data yet)';
}

var specialistLines = '';
if (specialistList.length > 0 && totalSpecialistSignals30d > 0) {
  specialistLines = specialistList.map(function(signal) {
    var pct = Math.round(signal.count / totalSpecialistSignals30d * 100);
    return '- ' + signal.type + ': ' + pct + '% (' + signal.count + '/' + totalSpecialistSignals30d + ' specialist signals, rolling 30d)';
  }).join('\n');
} else if (totalSignals30d > 0) {
  specialistLines = '(no specialist-level signals yet; only wrapper/session events recorded)';
} else {
  specialistLines = '(no data yet)';
}

var mostActiveSpecialist = specialistList.length > 0 ? specialistList[0].type : 'none';
var todayStr = now.toISOString().slice(0, 10);

var philosophyContent = '(insufficient data)';
if (specialistList.length >= 1 && totalSpecialistSignals30d >= 3) {
  var topAgent = specialistList[0].type;
  var topPct = Math.round(specialistList[0].count / totalSpecialistSignals30d * 100);
  var style = topPct > 40 ? 'heavily ' + topAgent + '-driven' :
    topPct > 25 ? topAgent + '-preferred with balanced delegation' :
      'balanced multi-agent orchestration';
  philosophyContent = 'Workflow style: ' + style + ' (' + totalSpecialistSignals30d + ' specialist signals over 30d).\n' +
    'Primary specialists: ' + specialistList.slice(0, 3).map(function(signal) { return signal.type; }).join(', ') + '.';
} else if (totalSignals30d > 0) {
  philosophyContent = 'Only wrapper/session-level signals have been observed so far.\n' +
    'The profile will become more specific once richer agent events are logged.';
}

var profileContent = '---\n' +
  'date: ' + todayStr + '\n' +
  'type: persona\n' +
  'version: 1\n' +
  'session_count: ' + sessionCount + '\n' +
  '---\n' +
  '# User Profile\n' +
  '\n' +
  '## Philosophy\n' +
  philosophyContent + '\n' +
  '\n' +
  '## Workflow Patterns\n' +
  '- Total logged signals (30d): ' + totalSignals30d + '\n' +
  '- Wrapper/session signals (30d): ' + wrapperSignals30d + '\n' +
  '- Most active specialist: ' + mostActiveSpecialist + '\n' +
  '\n' +
  '## Logged Signals\n' +
  signalLines + '\n' +
  '\n' +
  '## Specialist Preferences\n' +
  specialistLines + '\n' +
  '\n' +
  '## Active Persona Rules\n' +
  '(none yet)\n' +
  '\n' +
  '## History\n' +
  historySection + '\n';

try {
  fs.writeFileSync(PROFILE_FILE, profileContent);
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write profile.md: ' + e.message + '\n');
  process.exit(0);
}

var todayEntries = [];
for (var k = 0; k < logEntries.length; k++) {
  if (logEntries[k].ts && logEntries[k].ts.slice(0, 10) === todayStr) {
    todayEntries.push(logEntries[k]);
  }
}

var dayCounts = countByType(todayEntries, isKnownSignal);
var dayTotal = totalCount(dayCounts);
var daySpecialistCounts = countByType(todayEntries, isSpecialistSignal);
var dayMostActive = 'none';
var dayMostCount = 0;
var specialistTypes = Object.keys(daySpecialistCounts);
for (var m = 0; m < specialistTypes.length; m++) {
  var type = specialistTypes[m];
  if (daySpecialistCounts[type] > dayMostCount) {
    dayMostCount = daySpecialistCounts[type];
    dayMostActive = type;
  }
}

var dayTypes = Object.keys(dayCounts);
var agentLines = '';
for (var n = 0; n < dayTypes.length; n++) {
  agentLines += '- ' + labelForSignal(dayTypes[n]) + ': ' + dayCounts[dayTypes[n]] + ' logged ' + eventWord(dayCounts[dayTypes[n]]) + '\n';
}
if (!agentLines) agentLines = '(no signals logged)\n';

var summaryContent = '---\ndate: ' + todayStr + '\ntype: agent-log\nsession_count: ' + sessionCount +
  '\ntotal_calls: ' + dayTotal + '\n---\n# Session Signal Summary -- ' + todayStr + '\n\n## Logged Signals\n' +
  agentLines + '\n## Session Stats\n- Total logged signals today: ' + dayTotal + '\n- Most active specialist: ' + dayMostActive + '\n';

try {
  var agentsDir = path.join(BRIEFING_DIR, 'agents');
  fs.mkdirSync(agentsDir, { recursive: true });
  fs.writeFileSync(path.join(agentsDir, todayStr + '-summary.md'), summaryContent);
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write agent summary: ' + e.message + '\n');
}

try {
  var indexPath = path.join(BRIEFING_DIR, 'INDEX.md');
  if (fs.existsSync(indexPath)) {
    var indexContent = fs.readFileSync(indexPath, 'utf8');

    function recentFiles(subdir, limit) {
      var dir = path.join(BRIEFING_DIR, subdir);
      if (!fs.existsSync(dir)) return [];
      var files = fs.readdirSync(dir)
        .filter(function(file) { return file.endsWith('.md') && file !== '.gitkeep'; });
      var dated = files.filter(function(file) { return /^\d{4}-\d{2}-\d{2}/.test(file); }).sort().reverse();
      var undated = files.filter(function(file) { return !/^\d{4}-\d{2}-\d{2}/.test(file); }).sort();
      return dated.concat(undated)
        .slice(0, limit)
        .map(function(file) { return '- [[' + subdir + '/' + file.replace('.md', '') + ']]'; });
    }

    var sections = {
      'Recent Sessions': recentFiles('sessions', 5),
      'Recent Decisions': recentFiles('decisions', 5),
      'Recent Learnings': recentFiles('learnings', 3)
    };

    Object.keys(sections).forEach(function(heading) {
      var lines = sections[heading];
      if (lines.length === 0) return;
      var pattern = new RegExp('(## ' + heading + '\\n)([\\s\\S]*?)(?=\\n## |$)');
      var replacement = '$1' + lines.join('\n') + '\n\n';
      if (pattern.test(indexContent)) {
        indexContent = indexContent.replace(pattern, replacement);
      }
    });

    fs.writeFileSync(indexPath, indexContent);
  }
} catch (e) {
  process.stderr.write('INDEX.md update failed: ' + e.message + '\n');
}

process.exit(0);
