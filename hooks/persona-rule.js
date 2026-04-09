#!/usr/bin/env node
// Persona rule CLI: list/accept/reject suggestions
// Runs synchronously — no async/await, ES5-compatible

var fs = require('fs');
var path = require('path');

var BRIEFING_DIR = '.briefing';
var PERSONA_DIR = path.join(BRIEFING_DIR, 'persona');
var SUGGESTIONS_FILE = path.join(PERSONA_DIR, 'suggestions.jsonl');
var RULES_DIR = path.join(PERSONA_DIR, 'rules');
var SKILLS_DIR = path.join(PERSONA_DIR, 'skills');

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
  var found = false;
  for (var i = 0; i < suggestions.length; i++) {
    if (suggestions[i].type === 'pending' && suggestions[i].agent_type === agentType) {
      suggestions[i].type = 'accepted';
      suggestions[i].accepted_at = new Date().toISOString();
      found = true;

      // Generate rule file
      var todayStr = new Date().toISOString().slice(0, 10);
      var count = suggestions[i].count || 0;
      var ruleContent = '---\n' +
        'date: ' + todayStr + '\n' +
        'type: persona-rule\n' +
        'agent_type: ' + agentType + '\n' +
        'source: auto-generated\n' +
        'status: active\n' +
        '---\n' +
        '# Routing Preference: ' + agentType + '\n' +
        '\n' +
        'When tasks match this agent\'s specialty, prefer delegating to `' + agentType + '`.\n' +
        'Auto-generated from usage pattern: used ' + count + ' times in 7 days.\n';

      try {
        fs.mkdirSync(RULES_DIR, { recursive: true });
        fs.writeFileSync(path.join(RULES_DIR, 'prefer-' + agentType + '.md'), ruleContent);
      } catch (e) {
        process.stderr.write('persona-rule: failed to write rule file: ' + e.message + '\n');
      }

      // Generate companion skill file
      var skillContent = '---\n' +
        'name: persona-' + agentType + '\n' +
        'description: Auto-generated workflow preference for ' + agentType + ' based on usage patterns.\n' +
        '---\n' +
        '# Persona Skill: ' + agentType + '\n' +
        '\n' +
        '## When to Activate\n' +
        'This skill activates when the task matches `' + agentType + '`\'s specialty.\n' +
        '\n' +
        '## Preferred Workflow\n' +
        '- Prefer delegating to `' + agentType + '` agent\n' +
        '- Based on observed usage: ' + count + ' calls in 7 days\n' +
        '\n' +
        '## Source\n' +
        'Auto-generated from persona suggestion accepted on ' + todayStr + '.\n';

      try {
        fs.mkdirSync(SKILLS_DIR, { recursive: true });
        fs.writeFileSync(path.join(SKILLS_DIR, agentType + '.md'), skillContent);
      } catch (e) {
        process.stderr.write('persona-rule: failed to write skill file: ' + e.message + '\n');
      }
      break;
    }
  }
  if (!found) {
    process.stdout.write('No pending suggestion found for agent_type: ' + agentType + '\n');
    process.exit(0);
  }
  writeSuggestions(suggestions);
  process.stdout.write('Accepted: ' + agentType + '. Rule created at persona/rules/prefer-' + agentType + '.md, skill at persona/skills/' + agentType + '.md\n');
  process.exit(0);
}

// REJECT command
if (command === 'reject') {
  if (!agentType) {
    process.stdout.write('Usage: persona-rule.js reject <agent_type>\n');
    process.exit(0);
  }
  var suggestions = readSuggestions();
  var found = false;
  var cooldownDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  for (var i = 0; i < suggestions.length; i++) {
    if (suggestions[i].type === 'pending' && suggestions[i].agent_type === agentType) {
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
  writeSuggestions(suggestions);
  process.stdout.write('Rejected: ' + agentType + '. Cooldown until ' + cooldownDate.toISOString().slice(0, 10) + '\n');
  process.exit(0);
}

// Unknown command or no command
process.stdout.write('Usage: persona-rule.js <list|accept|reject> [agent_type]\n');
process.exit(0);
