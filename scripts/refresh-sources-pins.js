#!/usr/bin/env node
/**
 * Refresh the AI-BOM pins in upstream/SOURCES.json.
 *
 * For every entry that carries a "path" field (the submodule working tree),
 * rewrite "pinned_sha" to the submodule's current HEAD and "pinned_date" to
 * today's UTC date. Editing is line-scoped so the rest of the file — comments,
 * manual array wrapping, key order — stays byte-identical and sync PRs show a
 * two-line diff per bumped submodule instead of a full reformat.
 *
 * Usage: node scripts/refresh-sources-pins.js [--check]
 *   --check  exit 1 if any pin is stale instead of writing
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const SOURCES_FILE = path.join(REPO_ROOT, 'upstream', 'SOURCES.json');
const CHECK_ONLY = process.argv.includes('--check');

function headSha(submodulePath) {
  try {
    return execFileSync('git', ['-C', submodulePath, 'rev-parse', 'HEAD'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
    }).trim();
  } catch {
    return null;
  }
}

const raw = fs.readFileSync(SOURCES_FILE, 'utf8');
const sources = JSON.parse(raw);
const today = new Date().toISOString().slice(0, 10);

// entry name -> resolved HEAD sha, for entries that declare a submodule path
const pins = {};
for (const [name, entry] of Object.entries(sources)) {
  if (!entry || typeof entry !== 'object' || !entry.path) continue;
  const sha = headSha(path.join(REPO_ROOT, entry.path));
  if (!sha) {
    console.warn(`[refresh-sources-pins] skipping ${name}: cannot read HEAD of ${entry.path}`);
    continue;
  }
  pins[name] = sha;
}

const lines = raw.split('\n');
let current = null;
const changed = [];

for (let i = 0; i < lines.length; i++) {
  const entryStart = lines[i].match(/^ {2}"([^"]+)": \{/);
  if (entryStart) {
    current = entryStart[1];
    continue;
  }
  if (!current || !pins[current]) continue;

  const shaLine = lines[i].match(/^(\s*"pinned_sha": ")([^"]*)(".*)$/);
  if (shaLine && shaLine[2] !== pins[current]) {
    lines[i] = shaLine[1] + pins[current] + shaLine[3];
    changed.push(`${current}: ${shaLine[2].slice(0, 12)} -> ${pins[current].slice(0, 12)}`);
    continue;
  }

  const dateLine = lines[i].match(/^(\s*"pinned_date": ")([^"]*)(".*)$/);
  if (dateLine && dateLine[2] !== today && shaChanged(current)) {
    lines[i] = dateLine[1] + today + dateLine[3];
  }
}

// Only stamp a new pinned_date for submodules whose sha actually moved, so
// untouched entries keep the date their pin was last verified.
function shaChanged(name) {
  return changed.some((c) => c.startsWith(`${name}: `));
}

if (!changed.length) {
  console.log('[refresh-sources-pins] all pins current');
  process.exit(0);
}

if (CHECK_ONLY) {
  console.error('[refresh-sources-pins] stale pins:\n  ' + changed.join('\n  '));
  process.exit(1);
}

const updated = lines.join('\n');
JSON.parse(updated); // fail loudly rather than write invalid JSON
fs.writeFileSync(SOURCES_FILE, updated);
console.log('[refresh-sources-pins] updated:\n  ' + changed.join('\n  '));
