#!/usr/bin/env node
// Stop hook: profile auto-update
// Runs synchronously — no async/await

const fs = require('fs');
const path = require('path');

const BRIEFING_DIR = '.briefing';
const INDEX_FILE = path.join(BRIEFING_DIR, 'INDEX.md');
const AGENT_LOG = path.join(BRIEFING_DIR, 'agents', 'agent-log.jsonl');
const PERSONA_DIR = path.join(BRIEFING_DIR, 'persona');
const PROFILE_FILE = path.join(PERSONA_DIR, 'profile.md');
const SUGGESTIONS_FILE = path.join(PERSONA_DIR, 'suggestions.jsonl');

// Guard: no vault = nothing to do
if (!fs.existsSync(INDEX_FILE)) {
  process.exit(0);
}

// Ensure persona directories exist
try {
  fs.mkdirSync(path.join(PERSONA_DIR, 'rules'), { recursive: true });
  fs.mkdirSync(path.join(PERSONA_DIR, 'skills'), { recursive: true });
} catch (e) {
  process.stderr.write('stop-profile-update: failed to create persona dirs: ' + e.message + '\n');
  process.exit(0);
}

// Parse agent-log.jsonl
var logEntries = [];
try {
  if (fs.existsSync(AGENT_LOG)) {
    var raw = fs.readFileSync(AGENT_LOG, 'utf8');
    var lines = raw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line) continue;
      try {
        var entry = JSON.parse(line);
        if (entry && entry.ts) {
          logEntries.push(entry);
        }
      } catch (e) {
        // skip malformed lines
      }
    }
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to read agent-log: ' + e.message + '\n');
}

var now = new Date();
var ms30d = 30 * 24 * 60 * 60 * 1000;
var ms7d = 7 * 24 * 60 * 60 * 1000;

// Filter to rolling windows
var entries30d = logEntries.filter(function(e) {
  try {
    return (now - new Date(e.ts)) <= ms30d;
  } catch (err) {
    return false;
  }
});
var entries7d = logEntries.filter(function(e) {
  try {
    return (now - new Date(e.ts)) <= ms7d;
  } catch (err) {
    return false;
  }
});

// Compute Agent Affinity (30-day rolling)
var affinityCounts = {};
for (var i = 0; i < entries30d.length; i++) {
  var agentType = entries30d[i].agent_type || entries30d[i].agent;
  if (!agentType) continue;
  affinityCounts[agentType] = (affinityCounts[agentType] || 0) + 1;
}
var total30d = entries30d.filter(function(e) { return !!(e.agent_type || e.agent); }).length;

var affinityList = Object.keys(affinityCounts).map(function(t) {
  return { type: t, count: affinityCounts[t] };
});
affinityList.sort(function(a, b) { return b.count - a.count; });
affinityList = affinityList.slice(0, 10);

// Detect Patterns (7-day rolling)
var pattern7d = {};
for (var i = 0; i < entries7d.length; i++) {
  var agentType = entries7d[i].agent_type || entries7d[i].agent;
  if (!agentType) continue;
  pattern7d[agentType] = (pattern7d[agentType] || 0) + 1;
}

// Read existing suggestions
var existingSuggestions = [];
try {
  if (fs.existsSync(SUGGESTIONS_FILE)) {
    var sugRaw = fs.readFileSync(SUGGESTIONS_FILE, 'utf8');
    var sugLines = sugRaw.split('\n');
    for (var i = 0; i < sugLines.length; i++) {
      var line = sugLines[i].trim();
      if (!line) continue;
      try {
        existingSuggestions.push(JSON.parse(line));
      } catch (e) {
        // skip malformed
      }
    }
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to read suggestions: ' + e.message + '\n');
}

// Write new pending suggestions for patterns >= 3 in 7 days
var newSuggestions = [];
var patternTypes = Object.keys(pattern7d);
for (var i = 0; i < patternTypes.length; i++) {
  var agentType = patternTypes[i];
  var count = pattern7d[agentType];
  if (count < 3) continue;

  // Check cooldown, pending, or already accepted
  var hasCooldown = false;
  var hasPending = false;
  var hasAccepted = false;
  for (var j = 0; j < existingSuggestions.length; j++) {
    var s = existingSuggestions[j];
    if (s.agent_type !== agentType) continue;
    if (s.type === 'rejected' && s.cooldown_until) {
      try {
        if (new Date(s.cooldown_until) > now) {
          hasCooldown = true;
          break;
        }
      } catch (e) {}
    }
    if (s.type === 'pending') {
      hasPending = true;
      break;
    }
    if (s.type === 'accepted') {
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
    message: 'You used ' + agentType + ' ' + count + ' times in 7 days. Create an auto-rule to prefer ' + agentType + ' for matching tasks?'
  });
}

// Append new suggestions
if (newSuggestions.length > 0) {
  try {
    var appendStr = newSuggestions.map(function(s) { return JSON.stringify(s); }).join('\n') + '\n';
    fs.appendFileSync(SUGGESTIONS_FILE, appendStr);
  } catch (e) {
    process.stderr.write('stop-profile-update: failed to write suggestions: ' + e.message + '\n');
  }
}

// Read existing profile.md for session_count
var sessionCount = 0;
var existingHistory = '';
try {
  if (fs.existsSync(PROFILE_FILE)) {
    var profileRaw = fs.readFileSync(PROFILE_FILE, 'utf8');
    var scMatch = profileRaw.match(/^session_count:\s*(\d+)/m);
    if (scMatch) {
      sessionCount = parseInt(scMatch[1], 10) || 0;
    }
    // Extract history section
    var histMatch = profileRaw.match(/## History\n([\s\S]*)$/);
    if (histMatch) {
      existingHistory = histMatch[1].trim();
    }
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to read profile: ' + e.message + '\n');
}

// Increment session_count
sessionCount += 1;

// Philosophy Diff (every 5 sessions)
var newHistoryEntry = '';
if (sessionCount >= 5 && sessionCount % 5 === 0) {
  var top3 = affinityList.slice(0, 3);
  if (top3.length > 0 && total30d > 0) {
    var parts = top3.map(function(a) {
      var pct = Math.round(a.count / total30d * 100);
      return a.type + ':' + pct + '%';
    });
    var dateStr = now.toISOString().slice(0, 10);
    newHistoryEntry = '- Session ' + sessionCount + ' (' + dateStr + '): Top agents — ' + parts.join(', ');
  }
}

// Build History section
var historySection = '';
if (newHistoryEntry && existingHistory) {
  historySection = newHistoryEntry + '\n' + existingHistory;
} else if (newHistoryEntry) {
  historySection = newHistoryEntry;
} else {
  historySection = existingHistory;
}

// Build Agent Affinity section lines
var affinityLines = '';
if (affinityList.length > 0 && total30d > 0) {
  affinityLines = affinityList.map(function(a) {
    var pct = Math.round(a.count / total30d * 100);
    return '- ' + a.type + ': ' + pct + '% (' + a.count + '/' + total30d + ' calls, rolling 30d)';
  }).join('\n');
} else {
  affinityLines = '(no data yet)';
}

// Most active agent
var mostActive = affinityList.length > 0 ? affinityList[0].type : 'none';

// Date string
var todayStr = now.toISOString().slice(0, 10);

// Build profile.md content
var profileContent = '---\n' +
  'date: ' + todayStr + '\n' +
  'type: persona\n' +
  'version: 1\n' +
  'session_count: ' + sessionCount + '\n' +
  '---\n' +
  '# User Profile\n' +
  '\n' +
  '## Philosophy\n' +
  '(auto-populated after pattern analysis)\n' +
  '\n' +
  '## Workflow Patterns\n' +
  '- Total agent calls (30d): ' + total30d + '\n' +
  '- Most active: ' + mostActive + '\n' +
  '\n' +
  '## Agent Affinity\n' +
  affinityLines + '\n' +
  '\n' +
  '## Active Persona Rules\n' +
  '(none yet)\n' +
  '\n' +
  '## History\n' +
  historySection + '\n';

// Write profile.md
try {
  fs.writeFileSync(PROFILE_FILE, profileContent);
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write profile.md: ' + e.message + '\n');
  process.exit(0);
}

// Write daily agent execution summary
var todayEntries = [];
for (var i = 0; i < logEntries.length; i++) {
  if (logEntries[i].ts && logEntries[i].ts.slice(0, 10) === todayStr) todayEntries.push(logEntries[i]);
}
if (todayEntries.length > 0) {
  var dayCounts = {}, dayTotal = 0, dayMostActive = '', dayMostCount = 0;
  for (var i = 0; i < todayEntries.length; i++) {
    var at = todayEntries[i].agent_type || todayEntries[i].agent;
    if (!at) continue;
    dayCounts[at] = (dayCounts[at] || 0) + 1;
  }
  var dayTypes = Object.keys(dayCounts);
  var agentLines = '';
  for (var i = 0; i < dayTypes.length; i++) {
    dayTotal += dayCounts[dayTypes[i]];
    if (dayCounts[dayTypes[i]] > dayMostCount) { dayMostCount = dayCounts[dayTypes[i]]; dayMostActive = dayTypes[i]; }
    agentLines += '- ' + dayTypes[i] + ': ' + dayCounts[dayTypes[i]] + ' calls\n';
  }
  var summaryContent = '---\ndate: ' + todayStr + '\ntype: agent-log\nsession_count: ' + sessionCount +
    '\ntotal_calls: ' + dayTotal + '\n---\n# Agent Execution Summary — ' + todayStr + '\n\n## Agents Used\n' +
    agentLines + '\n## Session Stats\n- Total calls today: ' + dayTotal + '\n- Most active: ' + dayMostActive + '\n';
  try {
    var agentsDir = path.join(BRIEFING_DIR, 'agents');
    fs.mkdirSync(agentsDir, { recursive: true });
    fs.writeFileSync(path.join(agentsDir, todayStr + '-summary.md'), summaryContent);
  } catch (e) {
    process.stderr.write('stop-profile-update: failed to write agent summary: ' + e.message + '\n');
  }
}

process.exit(0);
