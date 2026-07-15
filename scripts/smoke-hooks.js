#!/usr/bin/env node
//
// smoke-hooks.js — syntax-check every hook script this repo ships.
//
// Three checks:
//   1. hooks/hooks.json is valid JSON.
//   2. Every inline `node -e "..."` script embedded in hooks.json parses
//      cleanly under `node --check` (catches the class of bracket/paren bugs
//      that only surface at runtime).
//   3. Every standalone hooks/*.js and scripts/*.js file passes `node --check`.
//
// Pure Node (no python), so it runs identically in CI and on a dev box.
// Exit 0 = all good; exit 1 = at least one failure (details on stderr).

'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const failures = [];
const checked = { json: 0, inline: 0, standalone: 0 };

// --- minimal POSIX-ish shell tokenizer -------------------------------------
// Handles single quotes (literal), double quotes (with \" \\ \$ \` escapes),
// backslash escapes outside quotes, and whitespace splitting. Enough to pull
// the argument of `node -e` out of the hook command strings, including those
// nested inside `bash -c '...'`.
function tokenize(str) {
  const tokens = [];
  let cur = '';
  let inTok = false;
  let i = 0;
  const dqEsc = new Set(['"', '\\', '$', '`']);
  while (i < str.length) {
    const c = str[i];
    if (c === "'") {
      inTok = true;
      i++;
      while (i < str.length && str[i] !== "'") { cur += str[i]; i++; }
      i++; // closing '
    } else if (c === '"') {
      inTok = true;
      i++;
      while (i < str.length && str[i] !== '"') {
        if (str[i] === '\\' && i + 1 < str.length && dqEsc.has(str[i + 1])) {
          cur += str[i + 1]; i += 2;
        } else { cur += str[i]; i++; }
      }
      i++; // closing "
    } else if (c === '\\') {
      inTok = true;
      if (i + 1 < str.length) { cur += str[i + 1]; i += 2; } else { i++; }
    } else if (/\s/.test(c)) {
      if (inTok) { tokens.push(cur); cur = ''; inTok = false; }
      i++;
    } else {
      inTok = true; cur += c; i++;
    }
  }
  if (inTok) tokens.push(cur);
  return tokens;
}

// Extract all `node -e <code>` arguments from a command string, descending
// into `bash -c '<script>'` wrappers.
function extractNodeE(command) {
  const codes = [];
  function walk(tokens) {
    for (let k = 0; k < tokens.length; k++) {
      if (tokens[k] === 'node' || tokens[k] === 'nodejs') {
        for (let m = k + 1; m < tokens.length; m++) {
          if (tokens[m] === '-e' || tokens[m] === '--eval') {
            if (m + 1 < tokens.length) codes.push(tokens[m + 1]);
            break;
          }
          if (!tokens[m].startsWith('-')) break;
        }
      }
      if ((tokens[k] === 'bash' || tokens[k] === 'sh') && tokens[k + 1] === '-c' && tokens[k + 2] != null) {
        walk(tokenize(tokens[k + 2]));
      }
    }
  }
  walk(tokenize(command));
  return codes;
}

function nodeCheck(code, label) {
  const tmp = path.join(os.tmpdir(), `smoke-hook-${process.pid}-${Math.random().toString(36).slice(2)}.js`);
  fs.writeFileSync(tmp, code);
  try {
    execFileSync(process.execPath, ['--check', tmp], { stdio: 'pipe' });
  } catch (e) {
    const msg = (e.stderr ? e.stderr.toString() : e.message).trim();
    failures.push(`${label}\n${msg}`);
  } finally {
    try { fs.unlinkSync(tmp); } catch (_) {}
  }
}

// Recursively collect every command string in the hooks tree.
function collectCommands(node, acc) {
  if (Array.isArray(node)) { node.forEach((n) => collectCommands(n, acc)); return; }
  if (node && typeof node === 'object') {
    if (typeof node.command === 'string') acc.push(node.command);
    Object.values(node).forEach((v) => collectCommands(v, acc));
  }
}

// --- check 1 + 2: hooks.json + inline node -e ------------------------------
const hooksJsonPath = path.join(repoRoot, 'hooks', 'hooks.json');
let hooksData;
try {
  hooksData = JSON.parse(fs.readFileSync(hooksJsonPath, 'utf8'));
  checked.json++;
} catch (e) {
  failures.push(`hooks/hooks.json is not valid JSON: ${e.message}`);
}

if (hooksData) {
  const commands = [];
  collectCommands(hooksData, commands);
  commands.forEach((cmd, idx) => {
    const codes = extractNodeE(cmd);
    codes.forEach((code, j) => {
      checked.inline++;
      nodeCheck(code, `inline node -e in hooks.json (command #${idx + 1}, script #${j + 1})`);
    });
  });
}

// --- check 3: standalone .js -----------------------------------------------
for (const dir of ['hooks', 'scripts']) {
  const abs = path.join(repoRoot, dir);
  if (!fs.existsSync(abs)) continue;
  for (const f of fs.readdirSync(abs)) {
    if (!f.endsWith('.js') && !f.endsWith('.mjs') && !f.endsWith('.cjs')) continue;
    const p = path.join(abs, f);
    checked.standalone++;
    try {
      execFileSync(process.execPath, ['--check', p], { stdio: 'pipe' });
    } catch (e) {
      const msg = (e.stderr ? e.stderr.toString() : e.message).trim();
      failures.push(`standalone ${dir}/${f}\n${msg}`);
    }
  }
}

// --- report -----------------------------------------------------------------
console.log(
  `Hooks smoke: hooks.json=${checked.json}, inline node -e scripts=${checked.inline}, standalone .js=${checked.standalone}`
);
if (failures.length) {
  console.error(`\nFAIL: ${failures.length} hook script(s) failed syntax check:\n`);
  failures.forEach((f) => console.error(`  - ${f}\n`));
  process.exit(1);
}
console.log('OK: all hook scripts pass syntax check.');
