#!/usr/bin/env node
// Sync the current repository hook payload into ~/.codex/hooks.
// Codex does not expose Claude-style hook registration, so this script keeps
// the wrapper-managed hook files up to date during auto-refresh.

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const repoRoot = path.resolve(__dirname, '..');
const sourceDir = path.join(repoRoot, 'hooks');
const targetDir = path.join(os.homedir(), '.codex', 'hooks');

if (!fs.existsSync(sourceDir)) {
  process.exit(0);
}

fs.mkdirSync(targetDir, { recursive: true });

for (const entry of fs.readdirSync(sourceDir)) {
  if (!/\.(json|js|sh)$/.test(entry)) continue;
  fs.copyFileSync(path.join(sourceDir, entry), path.join(targetDir, entry));
}

process.stdout.write('codex hooks synced\n');
