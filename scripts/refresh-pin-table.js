#!/usr/bin/env node
/**
 * Refresh the "Bundled Upstream Versions" table in README.md and its
 * translations from upstream/SOURCES.json.
 *
 * upstream/SOURCES.json is the single source of truth for the pins; the table
 * is documentation of the same data and went stale on every scheduled sync
 * because nothing rewrote it. A row is matched by its own structure — first
 * cell links to a "repo" URL in SOURCES.json, second cell is a backticked sha,
 * fourth cell carries a /compare/ link — rather than by the heading above it,
 * so the translated READMEs match on exactly the same rule as the English one
 * and no other table in the file can be hit by accident.
 *
 * Only the sha, date and compare-link base of a matched row are rewritten. An
 * entry that has no row is left alone, never inserted.
 *
 * Usage: node scripts/refresh-pin-table.js [--check]
 *   --check  exit 1 if any row is stale instead of writing
 */

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const SHA_DISPLAY_LENGTH = 7;

// | [name](repo) | `sha` | date | [compare](repo/compare/sha...HEAD) |
const ROW_PATTERN = /^\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|\s*$/;
const FIRST_CELL_LINK = /^\s*\[[^\]]*\]\(([^)\s]+?)\/?\)\s*$/;
const SHA_CELL = /^\s*`([0-9a-f]{7,40})`/;
const COMPARE_BASE = /\/compare\/[0-9a-f]{7,40}(?=\.\.\.)/;

function readPins(sourcesFile) {
  const sources = JSON.parse(fs.readFileSync(sourcesFile, 'utf8'));
  const pins = new Map();
  for (const entry of Object.values(sources)) {
    if (!entry || typeof entry !== 'object') continue;
    if (!entry.repo || !entry.pinned_sha || !entry.pinned_date) continue;
    pins.set(entry.repo.replace(/\/+$/, ''), {
      sha: entry.pinned_sha.slice(0, SHA_DISPLAY_LENGTH),
      date: entry.pinned_date,
      tag: entry.pinned_tag || null,
    });
  }
  return pins;
}

// Keep a hand-written annotation such as (`v2.9.0`) when SOURCES.json does not
// declare a tag and the sha has not moved; an annotation tied to a superseded
// sha is dropped with it.
function shaCell(cell, pin) {
  const current = cell.match(SHA_CELL);
  if (pin.tag) return ` \`${pin.sha}\` (\`${pin.tag}\`) `;
  if (current && current[1] === pin.sha) return cell;
  return ` \`${pin.sha}\` `;
}

function rewriteLine(line, pins) {
  const row = line.match(ROW_PATTERN);
  if (!row) return line;

  const [, first, sha, , diff] = row;
  const link = first.match(FIRST_CELL_LINK);
  if (!link) return line;

  const pin = pins.get(link[1].replace(/\/+$/, ''));
  if (!pin) return line;
  if (!SHA_CELL.test(sha) || !COMPARE_BASE.test(diff)) return line;

  const next = [
    first,
    shaCell(sha, pin),
    ` ${pin.date} `,
    diff.replace(COMPARE_BASE, `/compare/${pin.sha}`),
  ];
  return `|${next.join('|')}|`;
}

function refreshPinTable({ repoRoot = REPO_ROOT, check = false } = {}) {
  const pins = readPins(path.join(repoRoot, 'upstream', 'SOURCES.json'));
  const i18nDir = path.join(repoRoot, 'docs', 'i18n');
  const files = [path.join(repoRoot, 'README.md')];
  if (fs.existsSync(i18nDir)) {
    for (const name of fs.readdirSync(i18nDir).sort()) {
      if (/^README\.[a-z-]+\.md$/.test(name)) files.push(path.join(i18nDir, name));
    }
  }

  const changed = [];
  for (const file of files) {
    if (!fs.existsSync(file)) continue;
    const raw = fs.readFileSync(file, 'utf8');
    const updated = raw
      .split('\n')
      .map((line) => rewriteLine(line, pins))
      .join('\n');
    if (updated === raw) continue;
    changed.push(path.relative(repoRoot, file));
    if (!check) fs.writeFileSync(file, updated);
  }
  return { files: files.map((f) => path.relative(repoRoot, f)), changed };
}

module.exports = { ROW_PATTERN, readPins, refreshPinTable };

if (require.main === module) {
  const check = process.argv.includes('--check');
  const { changed } = refreshPinTable({ check });
  if (!changed.length) {
    console.log('[refresh-pin-table] pin table current in all READMEs');
    process.exit(0);
  }
  if (check) {
    console.error('[refresh-pin-table] stale pin table:\n  ' + changed.join('\n  '));
    process.exit(1);
  }
  console.log('[refresh-pin-table] updated:\n  ' + changed.join('\n  '));
}
