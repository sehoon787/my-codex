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
var dayCounts = {}, dayTotal = 0, dayMostActive = 'none', dayMostCount = 0;
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
if (!agentLines) agentLines = '(no agents used)\n';
var summaryContent = '---\ndate: ' + todayStr + '\ntype: agent-log\nsession_count: ' + sessionCount +
  '\ntotal_calls: ' + dayTotal + '\n---\n# Agent Execution Summary \u2014 ' + todayStr + '\n\n## Agents Used\n' +
  agentLines + '\n## Session Stats\n- Total calls today: ' + dayTotal + '\n- Most active: ' + dayMostActive + '\n';
try {
  var agentsDir = path.join(BRIEFING_DIR, 'agents');
  fs.mkdirSync(agentsDir, { recursive: true });
  fs.writeFileSync(path.join(agentsDir, todayStr + '-summary.md'), summaryContent);
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write agent summary: ' + e.message + '\n');
}

// === Auto-generate session summary ===
try {
  var SESSIONS_DIR = path.join(BRIEFING_DIR, 'sessions');
  fs.mkdirSync(SESSIONS_DIR, { recursive: true });

  // Skip if a session file for today already exists (AI wrote one)
  var sessionFiles = fs.readdirSync(SESSIONS_DIR);
  var sessionExistsToday = false;
  for (var i = 0; i < sessionFiles.length; i++) {
    if (sessionFiles[i].slice(0, 10) === todayStr && sessionFiles[i].indexOf('-auto') === -1) {
      sessionExistsToday = true;
      break;
    }
  }

  if (!sessionExistsToday) {
    // Read work counter
    var workCounter = 0;
    try {
      var wcPath = path.join(BRIEFING_DIR, '.work-counter');
      if (fs.existsSync(wcPath)) {
        workCounter = parseInt(fs.readFileSync(wcPath, 'utf8').trim(), 10) || 0;
      }
    } catch (e) {}

    // Run session-specific git diff
    var gitDiffStat = '(no git changes detected)';
    try {
      var spawnSync = require('child_process').spawnSync;
      var sessionHead = '';
      var headFile = path.join(BRIEFING_DIR, '.session-start-head');
      if (fs.existsSync(headFile)) {
        sessionHead = fs.readFileSync(headFile, 'utf8').trim();
      }

      if (sessionHead) {
        // Session-specific: committed changes since session start
        var committedResult = spawnSync('git', ['diff', '--stat', sessionHead + '..HEAD'], { timeout: 5000 });
        var committedOut = '';
        if (committedResult.status === 0 && committedResult.stdout) {
          committedOut = committedResult.stdout.toString().trim();
        }
        // Plus any uncommitted changes
        var uncommittedResult = spawnSync('git', ['diff', '--stat'], { timeout: 5000 });
        var uncommittedOut = '';
        if (uncommittedResult.status === 0 && uncommittedResult.stdout) {
          uncommittedOut = uncommittedResult.stdout.toString().trim();
        }
        var parts = [];
        if (committedOut) parts.push('### Committed\n' + committedOut);
        if (uncommittedOut) parts.push('### Uncommitted\n' + uncommittedOut);
        if (parts.length > 0) gitDiffStat = parts.join('\n\n');
      } else {
        // Fallback: all uncommitted changes
        var gitResult = spawnSync('git', ['diff', '--stat', 'HEAD'], { timeout: 5000 });
        if (gitResult.status === 0 && gitResult.stdout) {
          var gitOut = gitResult.stdout.toString().trim();
          if (gitOut) gitDiffStat = gitOut;
        }
      }
    } catch (e) {}

    // Build agent lines for session summary
    var sessionAgentLines = '(no agents used)';
    var sessionDayTotal = 0;
    if (todayEntries.length > 0) {
      var sdc = {}, sdLines = '';
      for (var i = 0; i < todayEntries.length; i++) {
        var sat = todayEntries[i].agent_type || todayEntries[i].agent;
        if (!sat) continue;
        sdc[sat] = (sdc[sat] || 0) + 1;
      }
      var sdTypes = Object.keys(sdc);
      for (var i = 0; i < sdTypes.length; i++) {
        sessionDayTotal += sdc[sdTypes[i]];
        sdLines += '- ' + sdTypes[i] + ': ' + sdc[sdTypes[i]] + ' calls\n';
      }
      if (sdLines) sessionAgentLines = sdLines.trimRight();
    }

    var sessionMd = '---\n' +
      'date: ' + todayStr + '\n' +
      'type: session\n' +
      'auto-generated: true\n' +
      'session_count: ' + sessionCount + '\n' +
      '---\n' +
      '# Session Summary \u2014 ' + todayStr + ' (Auto-generated)\n' +
      '\n' +
      '## Agent Usage\n' +
      sessionAgentLines + '\n' +
      'Total: ' + sessionDayTotal + ' calls\n' +
      '\n' +
      '## Work Stats\n' +
      '- File edits: ' + workCounter + '\n' +
      '- Session number: ' + sessionCount + '\n' +
      '\n' +
      '## Files Changed\n' +
      gitDiffStat + '\n';

    fs.writeFileSync(path.join(SESSIONS_DIR, todayStr + '-auto.md'), sessionMd);
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write session summary: ' + e.message + '\n');
}

// === Auto-generate learning draft ===
try {
  var LEARNINGS_DIR = path.join(BRIEFING_DIR, 'learnings');
  fs.mkdirSync(LEARNINGS_DIR, { recursive: true });

  // Skip if any learning file was modified today
  var learningFiles = fs.readdirSync(LEARNINGS_DIR);
  var learningExistsToday = false;
  for (var i = 0; i < learningFiles.length; i++) {
    if (learningFiles[i].indexOf('-auto-session') !== -1) continue;
    try {
      var lStat = fs.statSync(path.join(LEARNINGS_DIR, learningFiles[i]));
      if (lStat.mtime.toISOString().slice(0, 10) === todayStr) {
        learningExistsToday = true;
        break;
      }
    } catch (e) {}
  }

  if (!learningExistsToday) {
    // Read work counter — skip if no meaningful work
    var lwc = 0;
    try {
      var lwcPath = path.join(BRIEFING_DIR, '.work-counter');
      if (fs.existsSync(lwcPath)) {
        lwc = parseInt(fs.readFileSync(lwcPath, 'utf8').trim(), 10) || 0;
      }
    } catch (e) {}

    if (lwc > 0) {
      // Run session-specific git diff --name-only
      var changedFiles = '(no files detected)';
      try {
        var spawnSync2 = require('child_process').spawnSync;
        var sessionHead2 = '';
        var headFile2 = path.join(BRIEFING_DIR, '.session-start-head');
        if (fs.existsSync(headFile2)) {
          sessionHead2 = fs.readFileSync(headFile2, 'utf8').trim();
        }

        var fileSet = {};
        if (sessionHead2) {
          // Committed files since session start
          var cf = spawnSync2('git', ['diff', '--name-only', sessionHead2 + '..HEAD'], { timeout: 5000 });
          if (cf.status === 0 && cf.stdout) {
            cf.stdout.toString().trim().split('\n').forEach(function(f) { if (f) fileSet[f] = true; });
          }
        }
        // Uncommitted files
        var uf = spawnSync2('git', ['diff', '--name-only'], { timeout: 5000 });
        if (uf.status === 0 && uf.stdout) {
          uf.stdout.toString().trim().split('\n').forEach(function(f) { if (f) fileSet[f] = true; });
        }
        // Staged files
        var sf = spawnSync2('git', ['diff', '--name-only', '--cached'], { timeout: 5000 });
        if (sf.status === 0 && sf.stdout) {
          sf.stdout.toString().trim().split('\n').forEach(function(f) { if (f) fileSet[f] = true; });
        }
        var allFiles = Object.keys(fileSet);
        if (allFiles.length > 0) {
          changedFiles = allFiles.map(function(f) { return '- ' + f; }).join('\n');
        }
      } catch (e) {}

      // Build agent lines for learning draft
      var learnAgentLines = '(no agents used)';
      if (todayEntries.length > 0) {
        var lac = {}, laLines = '';
        for (var i = 0; i < todayEntries.length; i++) {
          var lat = todayEntries[i].agent_type || todayEntries[i].agent;
          if (!lat) continue;
          lac[lat] = (lac[lat] || 0) + 1;
        }
        var laTypes = Object.keys(lac);
        for (var i = 0; i < laTypes.length; i++) {
          laLines += '- ' + laTypes[i] + ': ' + lac[laTypes[i]] + ' calls\n';
        }
        if (laLines) learnAgentLines = laLines.trimRight();
      }

      var learningMd = '---\n' +
        'date: ' + todayStr + '\n' +
        'type: learning\n' +
        'auto-generated: true\n' +
        'tags: [auto-session-capture]\n' +
        '---\n' +
        '# Session Work Log (Auto-generated)\n' +
        '\n' +
        '## Agents Used\n' +
        learnAgentLines + '\n' +
        '\n' +
        '## Files Modified\n' +
        changedFiles + '\n' +
        '\n' +
        '> This entry was auto-generated at session end. Enrich with specific learnings or delete if not needed.\n';

      fs.writeFileSync(path.join(LEARNINGS_DIR, todayStr + '-auto-session.md'), learningMd);
    }
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write learning draft: ' + e.message + '\n');
}

// === Auto-generate decision draft ===
try {
  var decDir = path.join(BRIEFING_DIR, 'decisions');
  fs.mkdirSync(decDir, { recursive: true });

  // Skip if any decision file was modified today
  var decFiles = fs.readdirSync(decDir);
  var decExistsToday = false;
  for (var i = 0; i < decFiles.length; i++) {
    if (decFiles[i].indexOf('-auto.md') !== -1) continue;
    try {
      var dStat = fs.statSync(path.join(decDir, decFiles[i]));
      if (dStat.mtime.toISOString().slice(0, 10) === todayStr) {
        decExistsToday = true;
        break;
      }
    } catch (e) {}
  }

  if (!decExistsToday) {
    // Read work counter — skip if no meaningful work
    var dwc = 0;
    try {
      var dwcPath = path.join(BRIEFING_DIR, '.work-counter');
      if (fs.existsSync(dwcPath)) {
        dwc = parseInt(fs.readFileSync(dwcPath, 'utf8').trim(), 10) || 0;
      }
    } catch (e) {}

    if (dwc > 0) {
      // Run git log --oneline --since="midnight"
      var gitCommits = '(no commits today)';
      try {
        var spawnSync3 = require('child_process').spawnSync;
        var gitLog = spawnSync3('git', ['log', '--oneline', '--since=midnight'], { timeout: 5000 });
        if (gitLog.status === 0 && gitLog.stdout) {
          var gitLogOut = gitLog.stdout.toString().trim();
          if (gitLogOut) gitCommits = gitLogOut;
        }
      } catch (e) {}

      // Run session-specific git diff --name-only
      var decChangedFiles = '(no files detected)';
      try {
        var spawnSync4 = require('child_process').spawnSync;
        var sessionHead4 = '';
        var headFile4 = path.join(BRIEFING_DIR, '.session-start-head');
        if (fs.existsSync(headFile4)) {
          sessionHead4 = fs.readFileSync(headFile4, 'utf8').trim();
        }

        var decFileSet = {};
        if (sessionHead4) {
          // Committed files since session start
          var dcf = spawnSync4('git', ['diff', '--name-only', sessionHead4 + '..HEAD'], { timeout: 5000 });
          if (dcf.status === 0 && dcf.stdout) {
            dcf.stdout.toString().trim().split('\n').forEach(function(f) { if (f) decFileSet[f] = true; });
          }
        }
        // Uncommitted files
        var duf = spawnSync4('git', ['diff', '--name-only'], { timeout: 5000 });
        if (duf.status === 0 && duf.stdout) {
          duf.stdout.toString().trim().split('\n').forEach(function(f) { if (f) decFileSet[f] = true; });
        }
        // Staged files
        var dsf = spawnSync4('git', ['diff', '--name-only', '--cached'], { timeout: 5000 });
        if (dsf.status === 0 && dsf.stdout) {
          dsf.stdout.toString().trim().split('\n').forEach(function(f) { if (f) decFileSet[f] = true; });
        }
        var decAllFiles = Object.keys(decFileSet);
        if (decAllFiles.length > 0) {
          decChangedFiles = decAllFiles.map(function(f) { return '- ' + f; }).join('\n');
        }
      } catch (e) {}

      var decisionMd = '---\n' +
        'date: ' + todayStr + '\n' +
        'type: decision\n' +
        'auto-generated: true\n' +
        'tags: [auto-session-capture]\n' +
        '---\n' +
        '# Session Decisions (Auto-generated)\n' +
        '\n' +
        '## Commits Today\n' +
        gitCommits + '\n' +
        '\n' +
        '## Files Changed\n' +
        decChangedFiles + '\n' +
        '\n' +
        '> This entry was auto-generated. Enrich with actual decision rationale or delete if not needed.\n';

      fs.writeFileSync(path.join(decDir, todayStr + '-auto.md'), decisionMd);
    }
  }
} catch (e) {
  process.stderr.write('stop-profile-update: failed to write decision draft: ' + e.message + '\n');
}

process.exit(0);
