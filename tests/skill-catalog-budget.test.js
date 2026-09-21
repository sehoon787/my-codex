#!/usr/bin/env node
"use strict";

const assert = require("assert");
const fs = require("fs");
const path = require("path");

const repo = path.resolve(__dirname, "..");
const catalog = JSON.parse(fs.readFileSync(path.join(repo, "scripts", "skill-catalog.json"), "utf8"));
const preserved = new Set(catalog.preserve);

function candidates(name) {
  return [
    path.join(repo, "skill-overrides", name, "SKILL.md"),
    path.join(repo, "skills", "core", name, "SKILL.md"),
    path.join(repo, "upstream", "ecc", "skills", name, "SKILL.md"),
    path.join(repo, "upstream", "superpowers", "skills", name, "SKILL.md"),
    path.join(repo, "upstream", "gstack", name, "SKILL.md"),
    path.join(repo, "upstream", "gstack", "browser-skills", name, "SKILL.md"),
    path.join(repo, "upstream", "gstack", ".agents", "skills", name, "SKILL.md"),
    path.join(repo, "upstream", "archify", name, "SKILL.md")
  ];
}

function fullDescription(file) {
  const text = fs.readFileSync(file, "utf8");
  const front = text.startsWith("---") ? (text.split(/^---\s*$/m)[1] || "") : "";
  const lines = front.split(/\r?\n/);
  const index = lines.findIndex((line) => /^description\s*:/.test(line));
  assert(index >= 0, `missing description: ${file}`);
  const first = lines[index].replace(/^description\s*:\s*/, "");
  if (!/^[>|][-+]?\s*$/.test(first)) return first.replace(/^['"]|['"]$/g, "").trim();
  const body = [];
  for (let i = index + 1; i < lines.length && (/^\s+/.test(lines[i]) || lines[i] === ""); i += 1) body.push(lines[i].trim());
  return body.join(" ").trim();
}

function estimatedTokens(names) {
  let characters = 0;
  for (const name of new Set(names.filter((item) => !preserved.has(item)))) {
    const file = candidates(name).find(fs.existsSync);
    const installedPath = `~/.codex/skills/${name}/SKILL.md`;
    if (!file) {
      // Some known-harness alternatives exist only in the preserved
      // ~/.agents inventory, and the root gstack facade is generated at setup.
      // Reserve a conservative allowance when CI has no physical source.
      characters += name.length + 512 + installedPath.length + 24;
      continue;
    }
    characters += name.length + fullDescription(file).length + installedPath.length + 24;
  }
  return Math.ceil(characters / 4);
}

const coreTokens = estimatedTokens(catalog.core);
assert(coreTokens <= 5000, `core managed catalog estimate ${coreTokens} exceeds 5000 tokens`);
for (const [lane, skills] of Object.entries(catalog.lanes)) {
  const tokens = estimatedTokens([...catalog.core, ...skills]);
  assert(tokens <= 7000, `core + ${lane} managed catalog estimate ${tokens} exceeds 7000 tokens`);
}

console.log(`Skill catalog budget tests passed (core managed estimate: ${coreTokens}; heuristic, not Codex tokenizer output)`);
