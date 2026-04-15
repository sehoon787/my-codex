#!/usr/bin/env node
// Persona rule CLI: list/accept/reject suggestions
// Runs synchronously — no async/await, ES5-compatible

var fs = require('fs');
var path = require('path');

var BRIEFING_DIR = '.briefing';
var PERSONA_DIR = path.join(BRIEFING_DIR, 'persona');
var SUGGESTIONS_FILE = path.join(PERSONA_DIR, 'suggestions.jsonl');
var POLICY_FILE = path.join(PERSONA_DIR, 'persona-policy.json');

var args = process.argv.slice(2);
var command = args[0] || '';
var agentType = args[1] || '';

// Guard: no vault = nothing to do
if (!fs.existsSync(BRIEFING_DIR)) {
  if (command === 'list') {
    process.stdout.write('No .briefing/ vault found.\n');
  }
  process.exit(0);
}

// Read suggestions.jsonl
function readSuggestions() {
  var suggestions = [];
  try {
    if (fs.existsSync(SUGGESTIONS_FILE)) {
      var raw = fs.readFileSync(SUGGESTIONS_FILE, 'utf8');
      var lines = raw.split('\n');
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) continue;
        try {
          suggestions.push(JSON.parse(line));
        } catch (e) {
          // skip malformed
        }
      }
    }
  } catch (e) {
    process.stderr.write('persona-rule: failed to read suggestions: ' + e.message + '\n');
  }
  return suggestions;
}

// Write suggestions back
function writeSuggestions(suggestions) {
  try {
    fs.mkdirSync(PERSONA_DIR, { recursive: true });
    var lines = [];
    for (var i = 0; i < suggestions.length; i++) {
      lines.push(JSON.stringify(suggestions[i]));
    }
    fs.writeFileSync(SUGGESTIONS_FILE, lines.join('\n') + '\n');
  } catch (e) {
    process.stderr.write('persona-rule: failed to write suggestions: ' + e.message + '\n');
  }
}

function readPolicy() {
  var policy = { version: 1, updatedAt: '', preferences: {}, notes: [] };
  try {
    if (fs.existsSync(POLICY_FILE)) {
      var parsed = JSON.parse(fs.readFileSync(POLICY_FILE, 'utf8'));
      if (parsed && typeof parsed === 'object') {
        policy = Object.assign(policy, parsed);
      }
    }
  } catch (e) {
    process.stderr.write('persona-rule: failed to read policy: ' + e.message + '\n');
  }
  if (!policy.preferences || typeof policy.preferences !== 'object') {
    policy.preferences = {};
  }
  if (!Array.isArray(policy.notes)) {
    policy.notes = [];
  }
  return policy;
}

function writePolicy(policy) {
  try {
    fs.mkdirSync(PERSONA_DIR, { recursive: true });
    policy.updatedAt = new Date().toISOString();
    fs.writeFileSync(POLICY_FILE, JSON.stringify(policy, null, 2) + '\n');
  } catch (e) {
    process.stderr.write('persona-rule: failed to write policy: ' + e.message + '\n');
  }
}

// LIST command
if (command === 'list') {
  var suggestions = readSuggestions();
  var pending = [];
  for (var i = 0; i < suggestions.length; i++) {
    if (suggestions[i].type === 'pending') {
      pending.push(suggestions[i]);
    }
  }
  if (pending.length === 0) {
    process.stdout.write('No pending suggestions.\n');
    process.exit(0);
  }
  process.stdout.write('Pending persona suggestions (' + pending.length + '):\n');
  for (var i = 0; i < pending.length; i++) {
    var s = pending[i];
    process.stdout.write('  ' + (i + 1) + '. [' + s.agent_type + '] ' + (s.message || '') + '\n');
  }
  process.exit(0);
}

// ACCEPT command
if (command === 'accept') {
  if (!agentType) {
    process.stdout.write('Usage: persona-rule.js accept <agent_type>\n');
    process.exit(0);
  }
  var suggestions = readSuggestions();
  var policy = readPolicy();
  var found = false;
  for (var i = 0; i < suggestions.length; i++) {
    if (suggestions[i].type === 'pending' && suggestions[i].agent_type === agentType) {
      suggestions[i].type = 'accepted';
      suggestions[i].accepted_at = new Date().toISOString();
      found = true;

      var todayStr = new Date().toISOString().slice(0, 10);
      var count = suggestions[i].count || 0;
      policy.preferences[agentType] = {
        preference: 'prefer',
        source: 'accepted-suggestion',
        accepted_at: suggestions[i].accepted_at,
        observed_count_7d: count,
        rationale: 'Usage pattern crossed the suggestion threshold.'
      };
      policy.notes = (policy.notes || []).filter(function(note) {
        return !note || note.agent_type !== agentType;
      });
      policy.notes.unshift({
        ts: new Date().toISOString(),
        agent_type: agentType,
        action: 'accept',
        count: count,
        message: 'Prefer this agent as a soft routing tie-breaker when capabilities match.'
      });
      while (policy.notes.length > 20) {
        policy.notes.pop();
      }
      break;
    }
  }
  if (!found) {
    process.stdout.write('No pending suggestion found for agent_type: ' + agentType + '\n');
    process.exit(0);
  }
  writeSuggestions(suggestions);
  writePolicy(policy);
  process.stdout.write('Accepted: ' + agentType + '. Policy updated at persona/persona-policy.json\n');
  process.exit(0);
}

// REJECT command
if (command === 'reject') {
  if (!agentType) {
    process.stdout.write('Usage: persona-rule.js reject <agent_type>\n');
    process.exit(0);
  }
  var suggestions = readSuggestions();
  var policy = readPolicy();
  var found = false;
  var cooldownDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  for (var i = 0; i < suggestions.length; i++) {
    if ((suggestions[i].type === 'pending' || suggestions[i].type === 'accepted') && suggestions[i].agent_type === agentType) {
      suggestions[i].type = 'rejected';
      suggestions[i].cooldown_until = cooldownDate.toISOString();
      found = true;
      break;
    }
  }
  if (!found) {
    process.stdout.write('No pending suggestion found for agent_type: ' + agentType + '\n');
    process.exit(0);
  }
  delete policy.preferences[agentType];
  policy.notes = (policy.notes || []).filter(function(note) {
    return !note || note.agent_type !== agentType;
  });
  policy.notes.unshift({
    ts: new Date().toISOString(),
    agent_type: agentType,
    action: 'reject',
    message: 'Removed this soft routing preference and applied cooldown.'
  });
  while (policy.notes.length > 20) {
    policy.notes.pop();
  }
  writeSuggestions(suggestions);
  writePolicy(policy);
  process.stdout.write('Rejected: ' + agentType + '. Cooldown until ' + cooldownDate.toISOString().slice(0, 10) + '\n');
  process.exit(0);
}

// CLEAN command
if (command === 'clean') {
  var suggestions = readSuggestions();
  var kept = [];
  var cleaned = 0;
  var nowMs = Date.now();
  var maxPendingAge = 14 * 24 * 60 * 60 * 1000;

  for (var i = 0; i < suggestions.length; i++) {
    var suggestion = suggestions[i];
    if (!suggestion || typeof suggestion !== 'object') {
      cleaned += 1;
      continue;
    }
    if (!suggestion.agent_type || suggestion.agent_type === 'unknown') {
      cleaned += 1;
      continue;
    }
    if (suggestion.type === 'pending' && suggestion.ts) {
      var tsMs = new Date(suggestion.ts).getTime();
      if (tsMs > 0 && (nowMs - tsMs) > maxPendingAge) {
        cleaned += 1;
        continue;
      }
    }
    if (suggestion.type === 'rejected' && suggestion.cooldown_until) {
      var cooldownMs = new Date(suggestion.cooldown_until).getTime();
      if (cooldownMs > 0 && cooldownMs <= nowMs) {
        cleaned += 1;
        continue;
      }
    }
    kept.push(suggestion);
  }

  writeSuggestions(kept);
  process.stdout.write('Cleaned ' + cleaned + ' stale suggestion(s). ' + kept.length + ' remaining.\n');
  process.exit(0);
}

// Unknown command or no command
process.stdout.write('Usage: persona-rule.js <list|accept|reject|clean> [agent_type]\n');
process.exit(0);
