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
const codexRoot = path.join(os.homedir(), '.codex');
const targetDir = path.join(codexRoot, 'hooks');
// Codex reads the registry only from $CODEX_HOME/hooks.json. It must not be
// copied into hooks/ with the scripts, or this sync would restore the stale
// path the installer removes.
const REGISTRY = 'hooks.json';

if (!fs.existsSync(sourceDir)) {
  process.exit(0);
}

fs.mkdirSync(targetDir, { recursive: true });

for (const entry of fs.readdirSync(sourceDir)) {
  if (!/\.(json|js|sh)$/.test(entry)) continue;
  if (entry === REGISTRY) continue;
  fs.copyFileSync(path.join(sourceDir, entry), path.join(targetDir, entry));
}

const registrySource = path.join(sourceDir, REGISTRY);
if (fs.existsSync(registrySource)) {
  fs.copyFileSync(registrySource, path.join(codexRoot, REGISTRY));
  fs.rmSync(path.join(targetDir, REGISTRY), { force: true });
}

process.stdout.write('codex hooks synced\n');
