#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");
const cp = require("child_process");

const START = "# >>> my-codex skill catalog >>>";
const END = "# <<< my-codex skill catalog <<<";

function fail(message) {
  process.stderr.write(`ERROR: ${message}\n`);
  process.exitCode = 1;
}

function parseArgs(argv) {
  const options = { home: process.env.HOME || os.homedir(), json: false, dryRun: false };
  const args = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--json") options.json = true;
    else if (arg === "--dry-run") options.dryRun = true;
    else if (arg === "--home") options.home = argv[++i];
    else if (arg.startsWith("--home=")) options.home = arg.slice(7);
    else if (arg === "--config-home") options.configHome = argv[++i];
    else if (arg.startsWith("--config-home=")) options.configHome = arg.slice(14);
    else args.push(arg);
  }
  return { options, args };
}

function resolveLayout(options) {
  const home = path.resolve(options.home);
  const codex = path.join(home, ".codex");
  const configHome = path.resolve(options.configHome || codex);
  const configRelative = path.relative(home, configHome);
  if (configRelative.startsWith(`..${path.sep}`) || configRelative === ".." || path.isAbsolute(configRelative)) {
    throw new Error(`config home must stay inside the selected home: ${configHome}`);
  }
  const scriptDir = __dirname;
  const installedCatalog = path.join(scriptDir, "skill-catalog.json");
  const repoCatalog = path.join(scriptDir, "skill-catalog.json");
  return {
    home, codex, configHome,
    config: path.join(configHome, "config.toml"),
    stateDir: path.join(codex, "my-codex"),
    state: path.join(codex, "my-codex", "skill-catalog-state.json"),
    snapshots: path.join(codex, "my-codex", "skill-catalog-snapshots"),
    catalog: fs.existsSync(installedCatalog) ? installedCatalog : repoCatalog
  };
}

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); }
  catch (error) {
    if (error.code === "ENOENT") return fallback;
    throw new Error(`cannot read ${file}: ${error.message}`);
  }
}

function loadCatalog(layout) {
  const catalog = readJson(layout.catalog, null);
  if (!catalog || catalog.version !== 1 || !Array.isArray(catalog.core) || !Array.isArray(catalog.preserve) ||
      !catalog.lanes || typeof catalog.lanes !== "object" ||
      Object.values(catalog.lanes).some((skills) => !Array.isArray(skills) || skills.some((name) => typeof name !== "string"))) {
    throw new Error(`invalid catalog: ${layout.catalog}`);
  }
  const classified = [...catalog.core, ...Object.values(catalog.lanes).flat()];
  if (classified.some((name) => typeof name !== "string") || new Set(classified).size !== classified.length) {
    throw new Error(`catalog has duplicate or invalid skill classifications: ${layout.catalog}`);
  }
  return catalog;
}

function defaultState() {
  return { version: 1, profile: "legacy", enabledLanes: [], selectedSources: {}, updatedAt: null };
}

function validateState(state, file) {
  if (!state || state.version !== 1 || !["core", "legacy", "full"].includes(state.profile) ||
      !Array.isArray(state.enabledLanes) || state.enabledLanes.some((x) => typeof x !== "string") ||
      !state.selectedSources || typeof state.selectedSources !== "object" || Array.isArray(state.selectedSources) ||
      Object.values(state.selectedSources).some((x) => typeof x !== "string")) {
    throw new Error(`invalid skill catalog state: ${file}`);
  }
  return state;
}

function loadState(layout) {
  return validateState(readJson(layout.state, defaultState()), layout.state);
}

function assertSafePath(file, root) {
  const relative = path.relative(root, file);
  if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) throw new Error(`unsafe managed path: ${file}`);
  let current = root;
  for (const part of path.dirname(relative).split(path.sep).filter((x) => x && x !== ".")) {
    current = path.join(current, part);
    let stat;
    try { stat = fs.lstatSync(current); } catch (error) {
      if (error.code !== "ENOENT") throw error;
      fs.mkdirSync(current, { mode: 0o700 });
      stat = fs.lstatSync(current);
    }
    if (stat.isSymbolicLink() || !stat.isDirectory()) throw new Error(`unsafe managed directory: ${current}`);
  }
  try {
    const stat = fs.lstatSync(file);
    if (stat.isSymbolicLink() || !stat.isFile()) throw new Error(`unsafe managed file: ${file}`);
  } catch (error) { if (error.code !== "ENOENT") throw error; }
}

function assertSafeRoot(root) {
  let stat;
  try { stat = fs.lstatSync(root); } catch (error) {
    if (error.code === "ENOENT") throw new Error(`managed root does not exist: ${root}`);
    throw error;
  }
  if (stat.isSymbolicLink() || !stat.isDirectory()) throw new Error(`unsafe managed root: ${root}`);
}

function atomicWrite(file, content, mode, root) {
  if (root) assertSafePath(file, root);
  else fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.${crypto.randomBytes(5).toString("hex")}.tmp`);
  fs.writeFileSync(temp, content, { mode: mode || 0o600 });
  if (fs.existsSync(file)) fs.chmodSync(temp, fs.statSync(file).mode & 0o777);
  fs.renameSync(temp, file);
}

function splitManagedBlock(text) {
  const start = text.indexOf(START);
  const end = text.indexOf(END);
  if (start < 0 && end < 0) return { outside: text, block: "", before: text, after: "" };
  if (start < 0 || end < start) throw new Error("config.toml has an incomplete my-codex skill catalog block");
  let afterIndex = end + END.length;
  if (text[afterIndex] === "\n") afterIndex += 1;
  const before = text.slice(0, start);
  const after = text.slice(afterIndex);
  return { outside: `${before}${after}`, block: text.slice(start, afterIndex), before, after };
}

function parseSkillConfigPaths(text) {
  const helper = path.join(__dirname, "skill-catalog-toml.py");
  const candidates = [process.env.MY_CODEX_PYTHON, process.env.PYTHON, "python3", "python"].filter(Boolean);
  for (const command of candidates) {
    const probe = cp.spawnSync(command, ["-c", "import tomllib"], { encoding: "utf8" });
    if (probe.error && probe.error.code === "ENOENT") continue;
    if (probe.status !== 0) continue;
    const result = cp.spawnSync(command, [helper], { input: text, encoding: "utf8" });
    if (result.error && result.error.code === "ENOENT") continue;
    if (result.status !== 0) throw new Error(`cannot parse config.toml: ${(result.stderr || "TOML parser failed").trim()}`);
    return JSON.parse(result.stdout);
  }
  throw new Error("Python 3.11+ is required to parse config.toml safely");
}

function canonical(file) {
  try { return fs.realpathSync(file); } catch (_) { return path.resolve(file); }
}

function skillFiles(root) {
  if (!fs.existsSync(root)) return [];
  const out = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;
    const file = path.join(root, entry.name, "SKILL.md");
    if (fs.existsSync(file)) out.push({ name: entry.name, file: path.resolve(file), canonical: canonical(file) });
  }
  return out;
}

function sha256(file) {
  try { return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex"); } catch (_) { return null; }
}

function inventory(layout, catalog) {
  const manifestFile = path.join(layout.codex, ".my-codex-manifest.txt");
  const manifest = fs.existsSync(manifestFile)
    ? new Set(fs.readFileSync(manifestFile, "utf8").split(/\r?\n/).filter((x) => x.startsWith("skills/")).map((x) => x.slice(7).split("/")[0]))
    : new Set();
  const lock = readJson(path.join(layout.home, ".agents", ".skill-lock.json"), { skills: {} });
  const repositories = new Set(catalog.managedRepositories || []);
  const lockSkills = lock && lock.skills && typeof lock.skills === "object" ? lock.skills : {};
  const gstackRoot = canonical(path.join(layout.codex, "vendor", "gstack"));
  const codex = skillFiles(path.join(layout.codex, "skills")).map((x) => {
    const fromGstack = x.canonical.startsWith(`${gstackRoot}${path.sep}`);
    const gstackFacade = path.join(layout.codex, "vendor", "gstack", ".agents", "skills", "gstack", "SKILL.md");
    const matchesGstackFacade = x.name === "gstack" && fs.existsSync(gstackFacade) && sha256(x.file) === sha256(gstackFacade);
    const managed = manifest.has(x.name) || fromGstack || matchesGstackFacade;
    return { ...x, source: "codex", managed,
      sourceRepository: fromGstack || matchesGstackFacade ? "garrytan/gstack" : managed ? "sehoon787/my-codex" : null,
      sourceVersion: fromGstack || matchesGstackFacade ? catalog.sourceVersions.gstack : readVersion(path.join(layout.codex, ".my-codex-version")),
      sha256: sha256(x.file) };
  });
  const agents = skillFiles(path.join(layout.home, ".agents", "skills")).map((x) => {
    const locked = lockSkills[x.name] || {};
    const repository = locked.source || String(locked.sourceUrl || "").replace(/^https:\/\/github\.com\//, "").replace(/\.git$/, "");
    const managed = repositories.has(repository);
    return { ...x, source: "agents", managed, sourceRepository: managed ? repository : null,
      sourceVersion: locked.sourceVersion || locked.gitCommit || null, installedAt: locked.updatedAt || locked.installedAt || null,
      sha256: sha256(x.file), skillFolderHash: locked.skillFolderHash || null };
  });
  const system = skillFiles(path.join(layout.codex, "skills", ".system")).map((x) => ({ ...x, source: "system" }));
  const preserve = new Set(catalog.preserve || []);
  const managedNames = new Set([...catalog.core, ...Object.values(catalog.lanes).flat()].filter((name) => !preserve.has(name)));
  const byName = new Map();
  for (const item of [...codex, ...agents, ...system]) {
    if (!byName.has(item.name)) byName.set(item.name, []);
    byName.get(item.name).push(item);
  }
  return { all: [...codex, ...agents, ...system], byName, managedNames, preserve };
}

function readVersion(file) {
  try { return fs.readFileSync(file, "utf8").trim() || null; } catch (_) { return null; }
}

function description(file) {
  try {
    const text = fs.readFileSync(file, "utf8");
    if (!text.startsWith("---")) return "";
    const front = text.split(/^---\s*$/m)[1] || "";
    const lines = front.split(/\r?\n/);
    const index = lines.findIndex((line) => /^description\s*:/.test(line));
    if (index < 0) return "";
    const first = lines[index].replace(/^description\s*:\s*/, "");
    if (/^[>|][-+]?\s*$/.test(first)) {
      const body = [];
      for (let i = index + 1; i < lines.length && (/^\s+/.test(lines[i]) || lines[i] === ""); i += 1) body.push(lines[i].trim());
      return body.join(" ").trim();
    }
    return first.replace(/^['"]|['"]$/g, "").trim();
  } catch (_) { return ""; }
}

function selectedNames(catalog, state) {
  if (state.profile === "legacy" || state.profile === "full") return new Set([...catalog.core, ...Object.values(catalog.lanes).flat()]);
  const selected = new Set(catalog.core);
  for (const lane of state.enabledLanes) for (const name of catalog.lanes[lane] || []) selected.add(name);
  return selected;
}

function chooseSource(name, copies, state, catalog) {
  const owned = copies.filter((x) => x.managed);
  const explicit = state.selectedSources[name];
  const wanted = explicit || catalog.canonicalSources[name] || (owned.some((x) => x.source === "codex") ? "codex" : "agents");
  if (wanted === "gstack") return owned.find((x) => x.source === "codex") || null;
  if (wanted === "codex" || wanted === "agents") return owned.find((x) => x.source === wanted) || null;
  return owned.find((x) => x.file === path.resolve(wanted) || x.canonical === canonical(wanted)) || null;
}

function makePlan(layout, catalog, state, configText) {
  const inv = inventory(layout, catalog);
  const selected = selectedNames(catalog, state);
  const outside = splitManagedBlock(configText).outside;
  const userConfig = new Map();
  for (const entry of parseSkillConfigPaths(outside)) userConfig.set(canonical(entry.path), entry.enabled);
  const userPaths = new Set(userConfig.keys());
  const rows = [];
  const missingSelected = [];
  for (const name of [...inv.managedNames].sort()) {
    const copies = (inv.byName.get(name) || []).filter((copy) => copy.managed);
    if (!copies.length) {
      if (state.profile !== "legacy" && selected.has(name)) missingSelected.push(name);
      continue;
    }
    const chosen = chooseSource(name, copies, state, catalog);
    if (state.profile !== "legacy" && selected.has(name) && !chosen) missingSelected.push(name);
    if (state.profile === "legacy") continue;
    for (const copy of copies) {
      if (userPaths.has(copy.canonical)) continue;
      const enabled = selected.has(name) && chosen && copy.canonical === chosen.canonical;
      rows.push({ ...copy, enabled: Boolean(enabled), userOwned: false });
    }
  }
  return { inv, selected, rows, missingSelected, userPaths, userConfig };
}

function tomlString(value) { return JSON.stringify(value); }

function renderBlock(rows) {
  const lines = [START, "# Managed by my-codex. User entries outside this block take precedence."];
  for (const row of rows.sort((a, b) => a.file.localeCompare(b.file))) {
    lines.push("", "[[skills.config]]", `path = ${tomlString(row.file)}`, `enabled = ${row.enabled ? "true" : "false"}`);
  }
  lines.push(END);
  return `${lines.join("\n")}\n`;
}

function copyTree(source, target) {
  fs.cpSync(source, target, { recursive: true, dereference: false, errorOnExist: true });
}

function materializeSelected(layout, state, names) {
  const vendor = path.join(layout.codex, "vendor", "my-codex");
  const vendorReal = canonical(vendor);
  const roots = [
    path.join(vendor, "skill-overrides"),
    path.join(vendor, "upstream", "ecc", "skills"),
    path.join(vendor, "upstream", "everything-claude-code", "skills"),
    path.join(vendor, "upstream", "superpowers", "skills"),
    path.join(vendor, "upstream", "gstack")
  ];
  const planned = [];
  for (const name of names) {
    if (state.selectedSources[name] && !["codex", "gstack"].includes(state.selectedSources[name])) {
      throw new Error(`selected source is unavailable for ${name}: ${state.selectedSources[name]}`);
    }
    const target = path.join(layout.codex, "skills", name);
    assertSafePath(target, layout.codex);
    try { fs.lstatSync(target); throw new Error(`cannot materialize managed skill over existing unmanaged path: ${target}`); }
    catch (error) { if (error.code !== "ENOENT") throw error; }
    const source = roots.map((root) => path.join(root, name)).find((candidate) => fs.existsSync(path.join(candidate, "SKILL.md")));
    if (!source) throw new Error(`selected skill is unavailable: ${name}. Run install.sh --skills=<lane> to install its pinned payload`);
    const sourceReal = canonical(source);
    if (!sourceReal.startsWith(`${vendorReal}${path.sep}`) || !fs.lstatSync(path.join(sourceReal, "SKILL.md")).isFile()) {
      throw new Error(`untrusted pinned skill payload: ${source}`);
    }
    planned.push({ name, source, target });
  }
  const manifestFile = path.join(layout.codex, ".my-codex-manifest.txt");
  const oldManifest = fs.existsSync(manifestFile) ? fs.readFileSync(manifestFile, "utf8") : null;
  const installed = [];
  try {
    fs.mkdirSync(path.join(layout.codex, "skills"), { recursive: true });
    for (const item of planned) {
      installed.push(item.target);
      copyTree(item.source, item.target);
    }
    const entries = new Set((oldManifest || "").split(/\r?\n/).filter(Boolean));
    for (const item of planned) entries.add(`skills/${item.name}`);
    atomicWrite(manifestFile, `${[...entries].sort().join("\n")}\n`, 0o600, layout.codex);
  } catch (error) {
    for (const target of installed.reverse()) fs.rmSync(target, { recursive: true, force: true });
    if (oldManifest === null) fs.rmSync(manifestFile, { force: true });
    else atomicWrite(manifestFile, oldManifest, 0o600, layout.codex);
    throw error;
  }
  return () => {
    for (const target of installed.reverse()) fs.rmSync(target, { recursive: true, force: true });
    if (oldManifest === null) fs.rmSync(manifestFile, { force: true });
    else atomicWrite(manifestFile, oldManifest, 0o600, layout.codex);
  };
}

function replaceBlock(text, block) {
  const parts = splitManagedBlock(text);
  if (parts.block) return `${parts.before}${block}${parts.after}`;
  if (!block) return text;
  const separator = text.length && !text.endsWith("\n") ? "\n\n" : text.length ? "\n" : "";
  return `${text}${separator}${block}`;
}

function snapshot(layout, state, oldBlock, configText) {
  const id = `${new Date().toISOString().replace(/[:.]/g, "-")}-${crypto.randomBytes(3).toString("hex")}`;
  assertSafePath(path.join(layout.snapshots, ".sentinel"), layout.codex);
  atomicWrite(path.join(layout.snapshots, `${id}.json`), `${JSON.stringify({
    version: 2, id, state, managedBlock: oldBlock, configPath: path.resolve(layout.config),
    configOutside: splitManagedBlock(configText).outside
  }, null, 2)}\n`, 0o600, layout.codex);
  return id;
}

function apply(layout, catalog, state, options) {
  const configText = fs.existsSync(layout.config) ? fs.readFileSync(layout.config, "utf8") : "";
  const parts = splitManagedBlock(configText);
  let plan = makePlan(layout, catalog, state, configText);
  if (options.dryRun) return { ...plan, snapshot: null, changed: true };
  const lanesFile = path.join(layout.codex, "enabled-skill-lanes.txt");
  const manifestFile = path.join(layout.codex, ".my-codex-manifest.txt");
  assertSafeRoot(layout.configHome);
  assertSafePath(layout.config, layout.home);
  assertSafePath(layout.config, layout.configHome);
  for (const target of [layout.state, lanesFile, manifestFile]) assertSafePath(target, layout.codex);
  // Snapshot path safety and writability are verified before payload changes.
  const snapshotId = snapshot(layout, loadState(layout), parts.block, configText);
  const oldState = fs.existsSync(layout.state) ? fs.readFileSync(layout.state, "utf8") : null;
  const oldLanes = fs.existsSync(lanesFile) ? fs.readFileSync(lanesFile, "utf8") : null;
  let undoPayloads = null;
  try {
    if (plan.missingSelected.length) {
      undoPayloads = materializeSelected(layout, state, plan.missingSelected);
      plan = makePlan(layout, catalog, state, configText);
    }
    if (plan.missingSelected.length) throw new Error(`selected skills are unavailable: ${plan.missingSelected.join(", ")}. Run install.sh --skills=<lane> to install their pinned payload`);
    const block = renderBlock(plan.rows);
    const nextConfig = replaceBlock(configText, block);
    parseSkillConfigPaths(nextConfig); // Validate the complete generated TOML before writing.
    atomicWrite(layout.config, nextConfig, 0o600, layout.configHome);
    state.version = 1;
    state.updatedAt = new Date().toISOString();
    atomicWrite(layout.state, `${JSON.stringify(state, null, 2)}\n`, 0o600, layout.codex);
    const lanesText = `# One optional skill lane name per line.\n# Managed by my-codex; skill-catalog-state.json is authoritative.\n${state.enabledLanes.join("\n")}${state.enabledLanes.length ? "\n" : ""}`;
    atomicWrite(lanesFile, lanesText, 0o600, layout.codex);
    return { ...plan, snapshot: snapshotId, changed: parts.block !== block };
  } catch (error) {
    try { if (fs.existsSync(layout.config) && fs.readFileSync(layout.config, "utf8") !== configText) atomicWrite(layout.config, configText, 0o600, layout.configHome); } catch (_) {}
    try { if (oldState === null) fs.rmSync(layout.state, { force: true }); else atomicWrite(layout.state, oldState, 0o600, layout.codex); } catch (_) {}
    try { if (oldLanes === null) fs.rmSync(lanesFile, { force: true }); else atomicWrite(lanesFile, oldLanes, 0o600, layout.codex); } catch (_) {}
    try { if (undoPayloads) undoPayloads(); } catch (_) {}
    try { fs.rmSync(path.join(layout.snapshots, `${snapshotId}.json`), { force: true }); } catch (_) {}
    throw error;
  }
}

function enabledItems(plan) {
  const managed = new Map(plan.rows.map((row) => [row.canonical, row.enabled]));
  const enabledCanonical = new Map();
  for (const item of plan.inv.all) {
    const enabled = plan.userConfig.has(item.canonical)
      ? plan.userConfig.get(item.canonical)
      : managed.has(item.canonical) ? managed.get(item.canonical) : true;
    if (enabled) enabledCanonical.set(item.canonical, item);
  }
  return [...enabledCanonical.values()];
}

function estimate(plan) {
  const enabled = enabledItems(plan);
  let characters = 0;
  for (const row of enabled) characters += row.name.length + description(row.file).length + 8;
  return { enabledPhysicalSkillFiles: enabled.length, descriptionCharacters: characters, estimatedTokens: Math.ceil(characters / 4) };
}

function report(layout, catalog, state) {
  const text = fs.existsSync(layout.config) ? fs.readFileSync(layout.config, "utf8") : "";
  const plan = makePlan(layout, catalog, state, text);
  const actualConfig = new Map();
  for (const entry of parseSkillConfigPaths(text)) actualConfig.set(canonical(entry.path), entry.enabled);
  const actualPlan = { ...plan, rows: [], userConfig: actualConfig };
  const duplicateNames = [...plan.inv.byName].filter(([, copies]) => copies.length > 1).map(([name]) => name).sort();
  const managedPhysical = plan.inv.all.filter((x) => x.managed && plan.inv.managedNames.has(x.name)).length;
  const preservedPhysical = plan.inv.all.length - managedPhysical;
  const provenance = plan.inv.all.filter((x) => x.managed).map((x) => ({
    name: x.name, path: x.file, source_repository: x.sourceRepository || "unknown",
    source_version: x.sourceVersion || "unknown", sha256: x.sha256 || "unknown",
    installed_at: x.installedAt || "unknown", skill_folder_hash: x.skillFolderHash || "unknown",
    alternate_paths: (plan.inv.byName.get(x.name) || []).filter((other) => other.file !== x.file).map((other) => other.file)
  }));
  return {
    configHome: layout.configHome,
    configPath: layout.config,
    profile: state.profile,
    enabledLanes: state.enabledLanes,
    physicalSkillFiles: plan.inv.all.length,
    physicalManagedSkillFiles: managedPhysical,
    physicalPreservedSkillFiles: preservedPhysical,
    configuredManagedEntries: plan.rows.length,
    duplicateNames,
    missingSelectedSources: plan.missingSelected,
    activeSkillNames: [...new Set(enabledItems(actualPlan).map((x) => x.name))].sort(),
    laneIndex: Object.fromEntries(Object.entries(catalog.lanes).map(([lane, skills]) => [lane, { description: catalog.laneDescriptions?.[lane] || "", skills: skills.length }])),
    drift: splitManagedBlock(text).block !== renderBlock(plan.rows),
    estimate: { ...estimate(actualPlan), label: "heuristic: (skill name + full frontmatter description characters) / 4; Codex tokenization may differ" },
    provenance
  };
}

function print(value, json) {
  if (json) process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
  else if (typeof value === "string") process.stdout.write(`${value}\n`);
  else for (const [key, val] of Object.entries(value)) {
    if (key === "provenance" || key === "activeSkillNames") continue;
    if (key === "lanes" && Array.isArray(val)) {
      process.stdout.write("lanes:\n");
      for (const lane of val) process.stdout.write(`  ${lane.lane}: ${lane.skills} skills (${lane.enabled ? "enabled" : "disabled"})\n`);
    } else {
      process.stdout.write(`${key}: ${Array.isArray(val) ? (val.join(", ") || "none") : typeof val === "object" ? JSON.stringify(val) : val}\n`);
    }
  }
}

function help() {
  return `Usage: my-codex-skills <command> [arguments]\n\nCommands:\n  list\n  status\n  doctor\n  apply\n  enable <lane...>\n  disable <lane...>\n  set-profile <core|legacy|full>\n  source <skill> <codex|agents|gstack|SKILL.md path>\n  restore <snapshot-id|latest>\n\nOptions:\n  --json             Machine-readable output\n  --dry-run          Calculate changes without writing\n  --home DIR         Use an alternate home directory (tests/migration preview)\n  --config-home DIR  Write the effective Codex config in this directory\n`;
}

function validateLanes(catalog, lanes) {
  for (const lane of lanes) if (!Object.hasOwn(catalog.lanes, lane)) throw new Error(`unknown skill lane: ${lane}`);
}

function restore(layout, catalog, id, options) {
  if (!fs.existsSync(layout.snapshots)) throw new Error("no skill catalog snapshots found");
  const files = fs.readdirSync(layout.snapshots).filter((x) => x.endsWith(".json")).sort();
  const chosen = id === "latest" ? files.at(-1) : `${id}.json`;
  if (!chosen || !files.includes(chosen)) throw new Error(`snapshot not found: ${id}`);
  const saved = readJson(path.join(layout.snapshots, chosen), null);
  if (!saved || ![1, 2].includes(saved.version)) throw new Error(`invalid snapshot: ${chosen}`);
  if (saved.version === 2 && path.resolve(saved.configPath || "") !== path.resolve(layout.config)) {
    throw new Error(`snapshot config target does not match active config: ${saved.configPath || "unknown"}`);
  }
  if (saved.version === 1 && layout.configHome !== layout.codex) {
    throw new Error("version 1 snapshots can only restore the default ~/.codex/config.toml target");
  }
  const savedState = validateState(saved.state || defaultState(), chosen);
  validateLanes(catalog, savedState.enabledLanes);
  const current = fs.existsSync(layout.config) ? fs.readFileSync(layout.config, "utf8") : "";
  const currentParts = splitManagedBlock(current);
  // An empty pre-migration block must restore to empty so the first overlay
  // migration is genuinely reversible. Once a managed block existed, rebuild
  // it from the saved state and current inventory so payloads materialized
  // later receive explicit disabled rows rather than becoming default-enabled.
  const restoringInitialConfig = saved.version === 2 && !saved.managedBlock;
  const restorePlan = restoringInitialConfig ? null : makePlan(layout, catalog, savedState, current);
  if (restorePlan && restorePlan.missingSelected.length) {
    throw new Error(`snapshot selected skills are unavailable: ${restorePlan.missingSelected.join(", ")}`);
  }
  const restoredBlock = restoringInitialConfig
    ? ""
    : renderBlock(restorePlan.rows);
  let restored = replaceBlock(current, restoredBlock);
  if (restoringInitialConfig && typeof saved.configOutside === "string") {
    const separator = saved.configOutside.length
      ? (saved.configOutside.endsWith("\n") ? "\n" : "\n\n")
      : "";
    const generatedPrefix = `${saved.configOutside}${separator}`;
    if (currentParts.outside.startsWith(generatedPrefix)) {
      restored = `${saved.configOutside}${currentParts.outside.slice(generatedPrefix.length)}`;
    }
  }
  parseSkillConfigPaths(restored);
  if (options.dryRun) return chosen.replace(/\.json$/, "");
  const lanesFile = path.join(layout.codex, "enabled-skill-lanes.txt");
  assertSafeRoot(layout.configHome);
  assertSafePath(layout.config, layout.home);
  assertSafePath(layout.config, layout.configHome);
  for (const target of [layout.state, lanesFile]) assertSafePath(target, layout.codex);
  snapshot(layout, loadState(layout), currentParts.block, current);
  const oldState = fs.existsSync(layout.state) ? fs.readFileSync(layout.state, "utf8") : null;
  const oldLanes = fs.existsSync(lanesFile) ? fs.readFileSync(lanesFile, "utf8") : null;
  try {
    atomicWrite(layout.config, restored, 0o600, layout.configHome);
    atomicWrite(layout.state, `${JSON.stringify(savedState, null, 2)}\n`, 0o600, layout.codex);
    atomicWrite(lanesFile, `# One optional skill lane name per line.\n# Managed by my-codex; skill-catalog-state.json is authoritative.\n${savedState.enabledLanes.join("\n")}${savedState.enabledLanes.length ? "\n" : ""}`, 0o600, layout.codex);
  } catch (error) {
    try { atomicWrite(layout.config, current, 0o600, layout.configHome); } catch (_) {}
    try { if (oldState === null) fs.rmSync(layout.state, { force: true }); else atomicWrite(layout.state, oldState, 0o600, layout.codex); } catch (_) {}
    try { if (oldLanes === null) fs.rmSync(lanesFile, { force: true }); else atomicWrite(lanesFile, oldLanes, 0o600, layout.codex); } catch (_) {}
    throw error;
  }
  return chosen.replace(/\.json$/, "");
}

function main() {
  const { options, args } = parseArgs(process.argv.slice(2));
  const command = args.shift();
  if (!command || command === "help" || command === "--help") return process.stdout.write(help());
  const layout = resolveLayout(options);
  const catalog = loadCatalog(layout);
  const state = loadState(layout);
  validateLanes(catalog, state.enabledLanes);
  if (command === "list") {
    const rows = Object.entries(catalog.lanes).map(([lane, skills]) => ({ lane, skills: skills.length, enabled: state.profile === "full" || state.enabledLanes.includes(lane) }));
    return print({ core: catalog.core, preserve: catalog.preserve, lanes: rows }, options.json);
  }
  if (command === "status") return print(report(layout, catalog, state), options.json);
  if (command === "doctor") {
    const result = report(layout, catalog, state);
    result.ok = result.missingSelectedSources.length === 0 && !result.drift;
    print(result, options.json);
    if (!result.ok) process.exitCode = 2;
    return;
  }
  if (command === "restore") return print({ restored: restore(layout, catalog, args[0] || "latest", options) }, options.json);
  if (command === "apply") {
    const result = apply(layout, catalog, state, options);
    return print({ profile: state.profile, enabledLanes: state.enabledLanes, changed: result.changed, snapshot: result.snapshot }, options.json);
  }
  if (command === "set-profile") {
    const profile = args[0];
    if (!["core", "legacy", "full"].includes(profile)) throw new Error("profile must be core, legacy, or full");
    state.profile = profile;
    state.enabledLanes = profile === "full" ? Object.keys(catalog.lanes) : [];
  } else if (command === "enable" || command === "disable") {
    if (!args.length) throw new Error(`${command} requires at least one lane`);
    validateLanes(catalog, args);
    state.profile = "core";
    const lanes = new Set(state.enabledLanes);
    for (const lane of args) command === "enable" ? lanes.add(lane) : lanes.delete(lane);
    state.enabledLanes = [...lanes].sort();
  } else if (command === "source") {
    if (args.length !== 2) throw new Error("source requires <skill> <source>");
    if (![...catalog.core, ...Object.values(catalog.lanes).flat()].includes(args[0])) throw new Error(`unknown managed skill: ${args[0]}`);
    state.selectedSources[args[0]] = args[1];
  } else throw new Error(`unknown command: ${command}`);
  const result = apply(layout, catalog, state, options);
  print({ profile: state.profile, enabledLanes: state.enabledLanes, changed: result.changed, snapshot: result.snapshot, missingSelectedSources: result.missingSelected, estimate: estimate(result) }, options.json);
}

try { main(); } catch (error) { fail(error.message); }
