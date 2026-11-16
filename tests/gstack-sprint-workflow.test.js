#!/usr/bin/env node
// Static checks on the gstack-sprint workflow text. Phase 1 is recall →
// clarify → writing-plans → momus → one approval gate, and Phase 2 runs on
// executing-plans because Codex has no ralph. The Phase 1 block is pinned by
// sha256: my-claude ships the same block byte for byte.
// `node tests/gstack-sprint-workflow.test.js`
'use strict';
const assert = require('assert');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const SKILL = 'skills/core/gstack-sprint/SKILL.md';
const BOSS = 'codex-agents/core/boss.toml';
const ADVANCED = 'skills/core/boss-advanced/SKILL.md';
const ROUTING_MAP = 'hooks/routing-map.json';

// sha256 of the Phase 1 block (LF line endings, trailing whitespace trimmed,
// one final newline). my-claude pins the same value in its copy of this test.
const PHASE1_SHA256 = 'f437128dad52c3ba7d5ee04fe75d733fd7d1b539da0fc06dd88812125f7f2f3c';
const RALPH = /\b(ralph|ultrawork)\b/i;

function read(rel) {
  return fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\r\n/g, '\n');
}

// From the first line that matches isStart up to, not including, the next
// line that matches isEnd. Anchors are whole lines or prefixes, never
// substrings: other lines in these files mention the same sprint words.
function section(rel, isStart, isEnd) {
  const lines = read(rel).split('\n');
  const start = lines.findIndex(isStart);
  assert(start >= 0, `${rel}: section start not found`);
  const end = lines.findIndex((line, i) => i > start && isEnd(line));
  assert(end > start, `${rel}: section end not found`);
  return lines.slice(start, end).join('\n').trimEnd() + '\n';
}

const phaseBlock = (n) => section(SKILL, (l) => l.startsWith(`## Phase ${n}:`), (l) => l === '---');
const bossSprint = () => section(BOSS, (l) => l === 'gstack 3-Phase Sprint Workflow:', (l) => l === 'MCP Tool Awareness:');
const advancedSprint = () => section(ADVANCED, (l) => l.startsWith('## gstack 3-Phase Sprint'), (l) => l === '---');

function assertNames(text, where, names) {
  const missing = names.filter((name) => !text.includes(name));
  assert(missing.length === 0, `${where} does not name ${missing.join(', ')}`);
}

function assertNoRalph(text, where) {
  const hit = text.split('\n').find((line) => RALPH.test(line));
  assert(!hit, `${where}: ${hit && hit.trim().slice(0, 80)}`);
}

const results = [];
function check(name, fn) {
  let ok = true;
  let detail = '';
  try {
    fn();
  } catch (err) {
    ok = false;
    detail = `  (${err.message})`;
  }
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail}`);
  results.push(ok);
}

check('A1. SKILL.md does not say "mandatory for all scales"', () => {
  assert(!read(SKILL).includes('mandatory for all scales'), 'found "mandatory for all scales"');
});

check('A2. no line makes /plan-eng-review mandatory or required (SKILL.md, boss.toml sprint section)', () => {
  const lines = [...read(SKILL).split('\n'), ...bossSprint().split('\n')];
  const bad = lines.filter((line) => line.includes('/plan-eng-review') && /\b(mandatory|required)\b/i.test(line));
  assert(bad.length === 0, bad.map((line) => line.trim().slice(0, 80)).join(' | '));
});

check('A3. Phase 1 names writing-plans, momus and .briefing/plans/', () => {
  assertNames(phaseBlock(1), 'Phase 1', ['writing-plans', 'momus', '.briefing/plans/']);
});

check('A4. Phase 1 has exactly one APPROVAL GATE and no "for each ambiguity"', () => {
  const block = phaseBlock(1);
  const gates = block.split('APPROVAL GATE').length - 1;
  assert(gates === 1, `APPROVAL GATE appears ${gates} times`);
  assert(!block.includes('for each ambiguity'), 'found "for each ambiguity"');
});

check('A5. Phase 1 block sha256 equals PHASE1_SHA256', () => {
  const actual = crypto.createHash('sha256').update(phaseBlock(1)).digest('hex');
  assert(actual === PHASE1_SHA256,
    `got ${actual}. Phase 1 must stay identical in my-claude and my-codex: make the same change to ` +
    'skills/core/gstack-sprint/SKILL.md in the my-claude repo too, and update PHASE1_SHA256 in both ' +
    "repos' tests/gstack-sprint-workflow.test.js");
});

check('A6. boss.toml sprint section names writing-plans, momus, .briefing/plans/ and one AskUserQuestion', () => {
  assertNames(bossSprint(), 'boss.toml sprint section', ['writing-plans', 'momus', '.briefing/plans/', 'one AskUserQuestion']);
});

check('X1. SKILL.md has no ralph/ultrawork, and Phase 2 names executing-plans and hephaestus', () => {
  assertNoRalph(read(SKILL), SKILL);
  assertNames(phaseBlock(2), 'Phase 2', ['executing-plans', 'hephaestus']);
});

check('X2. boss.toml and boss-advanced sprint sections name executing-plans and hephaestus, no ralph/ultrawork', () => {
  for (const [where, text] of [['boss.toml sprint section', bossSprint()], ['boss-advanced sprint section', advancedSprint()]]) {
    assertNames(text, where, ['executing-plans', 'hephaestus']);
    assertNoRalph(text, where);
  }
});

check('X3. routing-map Build members start with the gstack-sprint skill', () => {
  const first = JSON.parse(read(ROUTING_MAP)).intents.Build.members[0];
  assert(first.name === 'gstack-sprint' && first.kind === 'skill', `members[0] is ${JSON.stringify(first)}`);
});

const failed = results.filter((ok) => !ok).length;
console.log(failed ? `${failed} FAILED` : 'ALL PASSED');
process.exit(failed ? 1 : 0);
