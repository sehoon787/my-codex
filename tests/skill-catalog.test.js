#!/usr/bin/env node
"use strict";

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const repo = path.resolve(__dirname, "..");
const cli = path.join(repo, "scripts", "skill-catalog.js");
const START = "# >>> my-codex skill catalog >>>";
const root = fs.mkdtempSync(path.join(os.tmpdir(), "my-codex-skill-catalog-"));

function skill(base, name, description = `${name} description`) {
  const dir = path.join(base, name);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "SKILL.md"), `---\nname: ${name}\ndescription: ${description}\n---\n`);
  return path.join(dir, "SKILL.md");
}

function run(args, expected = 0) {
  return runAt(root, args, expected);
}

function runAt(home, args, expected = 0) {
  const result = cp.spawnSync(process.execPath, [cli, "--home", home, ...args], { encoding: "utf8" });
  assert.strictEqual(result.status, expected, `${args.join(" ")}\nstdout=${result.stdout}\nstderr=${result.stderr}`);
  return result;
}

try {
  const codexSkills = path.join(root, ".codex", "skills");
  const agentSkills = path.join(root, ".agents", "skills");
  fs.mkdirSync(path.join(root, ".codex"), { recursive: true });
  const catalog = JSON.parse(fs.readFileSync(path.join(repo, "scripts", "skill-catalog.json"), "utf8"));
  const preserved = new Set(catalog.preserve);
  const managedNames = [...new Set([...catalog.core, ...Object.values(catalog.lanes).flat()])].filter((name) => !preserved.has(name));
  const files = new Map(managedNames.map((name) => [name, skill(codexSkills, name)]));
  fs.writeFileSync(path.join(root, ".codex", ".my-codex-manifest.txt"), `${managedNames.map((name) => `skills/${name}`).join("\n")}\n`);
  fs.writeFileSync(path.join(root, ".codex", ".my-codex-version"), "test-version\n");
  const core = files.get("boss-advanced");
  const backend = files.get("backend-patterns");
  const user = skill(codexSkills, "nested-malicious-external", "unknown user skill");
  const duplicateTarget = files.get("coding-standards");
  const duplicateLinkDir = path.join(agentSkills, "coding-standards");
  fs.mkdirSync(path.dirname(duplicateLinkDir), { recursive: true });
  fs.symlinkSync(path.dirname(duplicateTarget), duplicateLinkDir);
  fs.writeFileSync(path.join(root, ".agents", ".skill-lock.json"), JSON.stringify({
    version: 1,
    skills: { "coding-standards": { source: "sehoon787/my-codex", updatedAt: "test", skillFolderHash: "hash" } }
  }));

  const config = [
    'model = "user-choice"',
    "",
    "# A directory path has no effect in Codex and must not shadow the file path.",
    "[[skills.config]]",
    `path = ${JSON.stringify(path.dirname(backend))}`,
    "enabled = false",
    "",
    "# This canonical-path match is a user choice and must win over our block.",
    "[[ 'skills'.'config' ]]",
    `path = '${path.join(duplicateLinkDir, "SKILL.md")}'`,
    "enabled = false",
    ""
  ].join("\n");
  fs.writeFileSync(path.join(root, ".codex", "config.toml"), config);

  const coreResult = JSON.parse(run(["set-profile", "core", "--json"]).stdout);
  assert.strictEqual(coreResult.profile, "core");
  const afterCore = fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8");
  assert(afterCore.includes('model = "user-choice"'));
  assert(afterCore.includes(path.dirname(backend)), "directory-shaped user entry was preserved");
  assert.strictEqual((afterCore.match(new RegExp(duplicateTarget.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g")) || []).length, 0,
    "canonical symlink conflict must omit the managed entry");
  assert(afterCore.includes(`${JSON.stringify(core)}\nenabled = true`));
  assert(afterCore.includes(`${JSON.stringify(backend)}\nenabled = false`));
  assert(fs.existsSync(user), "unknown external skill must remain untouched");

  run(["enable", "backend-data"]);
  const afterEnable = fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8");
  assert(afterEnable.includes(`${JSON.stringify(backend)}\nenabled = true`));
  const status = JSON.parse(run(["status", "--json"]).stdout);
  assert.strictEqual(status.profile, "core");
  assert(status.enabledLanes.includes("backend-data"));
  assert(status.physicalSkillFiles > 100);
  assert(status.duplicateNames.includes("coding-standards"));
  assert(Number.isInteger(status.estimate.estimatedTokens));

  const stateBefore = fs.readFileSync(path.join(root, ".codex", "my-codex", "skill-catalog-state.json"), "utf8");
  const snapshots = fs.readdirSync(path.join(root, ".codex", "my-codex", "skill-catalog-snapshots")).sort();
  assert(snapshots.length >= 2);
  fs.writeFileSync(path.join(root, ".codex", "config.toml"), `${afterEnable}\n# user addition after snapshot\nuser_key = true\n`);
  run(["disable", "backend-data"]);
  run(["restore", snapshots.at(-1).replace(/\.json$/, "")]);
  const restored = fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8");
  assert(restored.includes("# user addition after snapshot\nuser_key = true"), "restore must preserve config outside the owned block");
  assert(fs.readFileSync(path.join(root, ".codex", "my-codex", "skill-catalog-state.json"), "utf8").length > 0);
  assert(stateBefore.includes('"profile": "core"'));

  const currentWithOverride = fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8") +
    `\n[[skills.config]]\npath = ${JSON.stringify(backend)}\nenabled = false\n`;
  fs.writeFileSync(path.join(root, ".codex", "config.toml"), currentWithOverride);
  run(["restore", "latest"]);
  const overrideRestored = fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8");
  assert.strictEqual((overrideRestored.match(new RegExp(backend.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g")) || []).length, 1,
    "restore must omit a managed row when the user now configures the canonical path");

  const beforeDryRun = fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8");
  run(["set-profile", "full", "--dry-run"]);
  assert.strictEqual(fs.readFileSync(path.join(root, ".codex", "config.toml"), "utf8"), beforeDryRun);
  run(["enable", "bogus"], 1);
  run(["set-profile", "bogus"], 1);

  fs.unlinkSync(core);
  const doctor = JSON.parse(run(["doctor", "--json"], 2).stdout);
  assert.strictEqual(doctor.ok, false);
  assert(doctor.missingSelectedSources.includes("boss-advanced"));

  const malformed = path.join(root, "malformed-home");
  fs.mkdirSync(path.join(malformed, ".codex", "my-codex"), { recursive: true });
  fs.writeFileSync(path.join(malformed, ".codex", "config.toml"), 'model = "keep"\n');
  fs.writeFileSync(path.join(malformed, ".codex", "my-codex", "skill-catalog-state.json"), '{"version":999,"profile":"garbage","enabledLanes":"bad"}');
  runAt(malformed, ["status"], 1);
  assert.strictEqual(fs.readFileSync(path.join(malformed, ".codex", "config.toml"), "utf8"), 'model = "keep"\n');

  const symlinkHome = path.join(root, "symlink-home");
  const outside = path.join(root, "outside-state");
  fs.mkdirSync(path.join(symlinkHome, ".codex"), { recursive: true });
  fs.mkdirSync(outside);
  fs.writeFileSync(path.join(symlinkHome, ".codex", "config.toml"), "");
  fs.symlinkSync(outside, path.join(symlinkHome, ".codex", "my-codex"));
  runAt(symlinkHome, ["set-profile", "legacy"], 1);
  assert.deepStrictEqual(fs.readdirSync(outside), []);

  const inlineHome = path.join(root, "inline-home");
  fs.mkdirSync(path.join(inlineHome, ".codex"), { recursive: true });
  fs.cpSync(path.join(root, ".codex", "skills"), path.join(inlineHome, ".codex", "skills"), { recursive: true });
  skill(path.join(inlineHome, ".codex", "skills"), "boss-advanced");
  fs.copyFileSync(path.join(root, ".codex", ".my-codex-manifest.txt"), path.join(inlineHome, ".codex", ".my-codex-manifest.txt"));
  fs.writeFileSync(path.join(inlineHome, ".codex", "config.toml"), "skills = { config = [] }\n");
  const inlineBefore = fs.readFileSync(path.join(inlineHome, ".codex", "config.toml"), "utf8");
  runAt(inlineHome, ["set-profile", "core"], 1);
  assert.strictEqual(fs.readFileSync(path.join(inlineHome, ".codex", "config.toml"), "utf8"), inlineBefore);

  const materializeHome = path.join(root, "materialize-home");
  fs.mkdirSync(path.join(materializeHome, ".codex"), { recursive: true });
  fs.cpSync(path.join(root, ".codex", "skills"), path.join(materializeHome, ".codex", "skills"), { recursive: true });
  skill(path.join(materializeHome, ".codex", "skills"), "boss-advanced");
  fs.copyFileSync(path.join(root, ".codex", ".my-codex-manifest.txt"), path.join(materializeHome, ".codex", ".my-codex-manifest.txt"));
  fs.writeFileSync(path.join(materializeHome, ".codex", "config.toml"), "");
  runAt(materializeHome, ["set-profile", "core"]);
  fs.rmSync(path.join(materializeHome, ".codex", "skills", "backend-patterns"), { recursive: true });
  const manifestPath = path.join(materializeHome, ".codex", ".my-codex-manifest.txt");
  fs.writeFileSync(manifestPath, fs.readFileSync(manifestPath, "utf8").replace(/^skills\/backend-patterns\n/m, ""));
  skill(path.join(materializeHome, ".codex", "vendor", "my-codex", "upstream", "ecc", "skills"), "backend-patterns");
  runAt(materializeHome, ["enable", "backend-data"]);
  assert(fs.existsSync(path.join(materializeHome, ".codex", "skills", "backend-patterns", "SKILL.md")));
  runAt(materializeHome, ["disable", "backend-data"]);
  fs.rmSync(path.join(materializeHome, ".codex", "skills", "generating-python-installer"), { recursive: true });
  fs.writeFileSync(manifestPath, fs.readFileSync(manifestPath, "utf8").replace(/^skills\/generating-python-installer\n/m, ""));
  skill(path.join(materializeHome, ".codex", "vendor", "my-codex", "upstream", "ecc", "skills"), "generating-python-installer", "Korean raw payload");
  skill(path.join(materializeHome, ".codex", "vendor", "my-codex", "skill-overrides"), "generating-python-installer", "Maintained English override");
  runAt(materializeHome, ["enable", "python"]);
  assert(fs.readFileSync(path.join(materializeHome, ".codex", "skills", "generating-python-installer", "SKILL.md"), "utf8").includes("Maintained English override"));
  runAt(materializeHome, ["disable", "python"]);
  fs.rmSync(path.join(materializeHome, ".codex", "skills", "backend-patterns"), { recursive: true });
  fs.writeFileSync(manifestPath, fs.readFileSync(manifestPath, "utf8").replace(/^skills\/backend-patterns\n/m, ""));
  const snapshotsPath = path.join(materializeHome, ".codex", "my-codex", "skill-catalog-snapshots");
  fs.rmSync(snapshotsPath, { recursive: true });
  fs.writeFileSync(snapshotsPath, "not a directory");
  const manifestBeforeFailedMaterialize = fs.readFileSync(manifestPath, "utf8");
  runAt(materializeHome, ["enable", "backend-data"], 1);
  assert(!fs.existsSync(path.join(materializeHome, ".codex", "skills", "backend-patterns")));
  assert.strictEqual(fs.readFileSync(manifestPath, "utf8"), manifestBeforeFailedMaterialize);
  fs.rmSync(snapshotsPath);
  fs.mkdirSync(snapshotsPath);
  const lanesPath = path.join(materializeHome, ".codex", "enabled-skill-lanes.txt");
  const outsideLanes = path.join(root, "outside-lanes.txt");
  fs.rmSync(lanesPath);
  fs.writeFileSync(outsideLanes, "outside\n");
  fs.symlinkSync(outsideLanes, lanesPath);
  runAt(materializeHome, ["enable", "backend-data"], 1);
  assert.strictEqual(fs.readFileSync(outsideLanes, "utf8"), "outside\n");
  assert(!fs.existsSync(path.join(materializeHome, ".codex", "skills", "backend-patterns")));
  assert.strictEqual(fs.readFileSync(manifestPath, "utf8"), manifestBeforeFailedMaterialize);

  const driftHome = path.join(root, "drift-home");
  fs.cpSync(path.join(root, ".codex"), path.join(driftHome, ".codex"), { recursive: true });
  fs.mkdirSync(path.join(driftHome, ".agents"), { recursive: true });
  const driftConfig = fs.readFileSync(path.join(driftHome, ".codex", "config.toml"), "utf8");
  const driftParts = driftConfig.replace(/# >>> my-codex skill catalog >>>[\s\S]*?# <<< my-codex skill catalog <<<\n?/, "");
  fs.writeFileSync(path.join(driftHome, ".codex", "config.toml"), driftParts);
  const driftDoctor = JSON.parse(runAt(driftHome, ["doctor", "--json"], 2).stdout);
  assert.strictEqual(driftDoctor.drift, true);
  assert.strictEqual(driftDoctor.ok, false);

  const overlayHome = path.join(root, "overlay-home");
  const overlayConfigHome = path.join(overlayHome, "Library", "Application Support", "orca", "active-home");
  fs.cpSync(path.join(root, ".codex"), path.join(overlayHome, ".codex"), { recursive: true });
  skill(path.join(overlayHome, ".codex", "skills"), "boss-advanced");
  fs.mkdirSync(overlayConfigHome, { recursive: true });
  fs.symlinkSync(path.join(overlayHome, ".codex", "skills"), path.join(overlayConfigHome, "skills"), "dir");
  fs.writeFileSync(path.join(overlayConfigHome, "config.toml"), 'model = "overlay-user-choice"\n');
  fs.writeFileSync(path.join(overlayConfigHome, "auth.json"), '{"token":"untouched"}\n');
  const baseConfigBeforeOverlay = fs.readFileSync(path.join(overlayHome, ".codex", "config.toml"), "utf8");
  const overlayResult = runAt(overlayHome, ["--config-home", overlayConfigHome, "set-profile", "core", "--json"]);
  const overlayApplied = JSON.parse(overlayResult.stdout);
  assert(overlayApplied.snapshot, "overlay apply must create a rollback snapshot");
  const overlayConfig = fs.readFileSync(path.join(overlayConfigHome, "config.toml"), "utf8");
  assert(overlayConfig.includes(START));
  assert(overlayConfig.includes('model = "overlay-user-choice"'));
  assert.strictEqual(fs.readFileSync(path.join(overlayHome, ".codex", "config.toml"), "utf8"), baseConfigBeforeOverlay);
  assert.strictEqual(fs.readFileSync(path.join(overlayConfigHome, "auth.json"), "utf8"), '{"token":"untouched"}\n');
  const overlayStatus = JSON.parse(runAt(overlayHome, ["--config-home", overlayConfigHome, "status", "--json"]).stdout);
  assert.strictEqual(overlayStatus.configHome, overlayConfigHome);
  assert.strictEqual(overlayStatus.configPath, path.join(overlayConfigHome, "config.toml"));
  assert.strictEqual(overlayStatus.drift, false);
  runAt(overlayHome, ["--config-home", path.join(root, "wrong-overlay"), "restore", overlayApplied.snapshot], 1);
  runAt(overlayHome, ["--config-home", overlayConfigHome, "restore", overlayApplied.snapshot]);
  assert.strictEqual(fs.readFileSync(path.join(overlayConfigHome, "config.toml"), "utf8"), 'model = "overlay-user-choice"\n');
  assert.strictEqual(fs.readFileSync(path.join(overlayConfigHome, "auth.json"), "utf8"), '{"token":"untouched"}\n');
  const overlayDoctor = JSON.parse(runAt(overlayHome, ["--config-home", overlayConfigHome, "doctor", "--json"], 2).stdout);
  assert.strictEqual(overlayDoctor.drift, true, "doctor must detect missing active overlay block");
  const outsideConfigParent = path.join(root, "outside-config-parent");
  const linkedConfigParent = path.join(overlayHome, "linked-config-parent");
  fs.mkdirSync(path.join(outsideConfigParent, "active"), { recursive: true });
  fs.writeFileSync(path.join(outsideConfigParent, "active", "config.toml"), 'model = "outside-untouched"\n');
  fs.writeFileSync(path.join(outsideConfigParent, "active", "auth.json"), '{"token":"outside-untouched"}\n');
  fs.symlinkSync(outsideConfigParent, linkedConfigParent, "dir");
  runAt(overlayHome, ["--config-home", path.join(linkedConfigParent, "active"), "set-profile", "core"], 1);
  assert.strictEqual(fs.readFileSync(path.join(outsideConfigParent, "active", "config.toml"), "utf8"), 'model = "outside-untouched"\n');
  assert.strictEqual(fs.readFileSync(path.join(outsideConfigParent, "active", "auth.json"), "utf8"), '{"token":"outside-untouched"}\n');

  const restoreMaterializeHome = path.join(root, "restore-materialize-home");
  fs.cpSync(path.join(root, ".codex"), path.join(restoreMaterializeHome, ".codex"), { recursive: true });
  skill(path.join(restoreMaterializeHome, ".codex", "skills"), "boss-advanced");
  const restoreBackend = path.join(restoreMaterializeHome, ".codex", "skills", "backend-patterns");
  fs.rmSync(restoreBackend, { recursive: true });
  const restoreManifest = path.join(restoreMaterializeHome, ".codex", ".my-codex-manifest.txt");
  fs.writeFileSync(restoreManifest, fs.readFileSync(restoreManifest, "utf8").replace(/^skills\/backend-patterns\n/m, ""));
  skill(path.join(restoreMaterializeHome, ".codex", "vendor", "my-codex", "upstream", "ecc", "skills"), "backend-patterns");
  fs.writeFileSync(path.join(restoreMaterializeHome, ".codex", "config.toml"), "");
  runAt(restoreMaterializeHome, ["set-profile", "core"]);
  const beforeMaterialize = JSON.parse(runAt(restoreMaterializeHome, ["apply", "--json"]).stdout);
  runAt(restoreMaterializeHome, ["enable", "backend-data"]);
  assert(fs.existsSync(path.join(restoreBackend, "SKILL.md")));
  runAt(restoreMaterializeHome, ["restore", beforeMaterialize.snapshot]);
  const restoredMaterializedConfig = fs.readFileSync(path.join(restoreMaterializeHome, ".codex", "config.toml"), "utf8");
  assert(restoredMaterializedConfig.includes(`${JSON.stringify(path.join(restoreBackend, "SKILL.md"))}\nenabled = false`),
    "restore must explicitly disable payloads materialized after the snapshot");
  runAt(restoreMaterializeHome, ["enable", "backend-data"]);
  const selectedSnapshot = JSON.parse(runAt(restoreMaterializeHome, ["apply", "--json"]).stdout).snapshot;
  fs.rmSync(restoreBackend, { recursive: true });
  fs.rmSync(path.join(restoreMaterializeHome, ".codex", "vendor", "my-codex", "upstream", "ecc", "skills", "backend-patterns"), { recursive: true });
  const beforeUnavailableRestore = fs.readFileSync(path.join(restoreMaterializeHome, ".codex", "config.toml"), "utf8");
  runAt(restoreMaterializeHome, ["restore", selectedSnapshot], 1);
  assert.strictEqual(fs.readFileSync(path.join(restoreMaterializeHome, ".codex", "config.toml"), "utf8"), beforeUnavailableRestore,
    "restore with an unavailable selected payload must fail before mutation");

  const installedBin = path.join(overlayHome, ".codex", "bin");
  const installedLib = path.join(overlayHome, ".codex", "lib", "my-codex");
  fs.mkdirSync(installedBin, { recursive: true });
  fs.mkdirSync(installedLib, { recursive: true });
  fs.copyFileSync(path.join(repo, "bin", "my-codex-skills"), path.join(installedBin, "my-codex-skills"));
  fs.chmodSync(path.join(installedBin, "my-codex-skills"), 0o755);
  for (const file of ["skill-catalog.js", "skill-catalog.json", "skill-catalog-toml.py"]) {
    fs.copyFileSync(path.join(repo, "scripts", file), path.join(installedLib, file));
  }
  const wrapperOverlay = cp.spawnSync("bash", [path.join(installedBin, "my-codex-skills"), "status", "--json"], {
    encoding: "utf8", env: { ...process.env, HOME: overlayHome, CODEX_HOME: overlayConfigHome }
  });
  assert.strictEqual(wrapperOverlay.status, 0, wrapperOverlay.stderr);
  assert.strictEqual(JSON.parse(wrapperOverlay.stdout).configHome, overlayConfigHome,
    "wrapper must select an active CODEX_HOME sharing the canonical skills tree");
  const unrelatedConfigHome = path.join(root, "unrelated-config-home");
  fs.mkdirSync(path.join(unrelatedConfigHome, "skills"), { recursive: true });
  fs.writeFileSync(path.join(unrelatedConfigHome, "config.toml"), 'model = "unrelated"\n');
  const wrapperUnrelated = cp.spawnSync("bash", [path.join(installedBin, "my-codex-skills"), "status", "--json"], {
    encoding: "utf8", env: { ...process.env, HOME: overlayHome, CODEX_HOME: unrelatedConfigHome }
  });
  assert.strictEqual(wrapperUnrelated.status, 0, wrapperUnrelated.stderr);
  assert.strictEqual(JSON.parse(wrapperUnrelated.stdout).configHome, path.join(overlayHome, ".codex"));
  assert.strictEqual(fs.readFileSync(path.join(unrelatedConfigHome, "config.toml"), "utf8"), 'model = "unrelated"\n');

  const interpreterHome = path.join(root, "interpreter-home");
  const interpreterBin = path.join(root, "interpreter-bin");
  fs.cpSync(path.join(root, ".codex"), path.join(interpreterHome, ".codex"), { recursive: true });
  fs.mkdirSync(interpreterBin);
  fs.writeFileSync(path.join(interpreterBin, "python3"), "#!/bin/sh\nexit 1\n", { mode: 0o755 });
  fs.writeFileSync(path.join(interpreterBin, "python"), `#!/bin/sh\nexec ${JSON.stringify(cp.spawnSync("which", ["python3"], { encoding: "utf8" }).stdout.trim())} "$@"\n`, { mode: 0o755 });
  const fallbackEnv = { ...process.env, PATH: `${interpreterBin}${path.delimiter}${process.env.PATH}` };
  delete fallbackEnv.MY_CODEX_PYTHON;
  delete fallbackEnv.PYTHON;
  const fallbackResult = cp.spawnSync(process.execPath, [cli, "--home", interpreterHome, "status", "--json"], {
    encoding: "utf8", env: fallbackEnv
  });
  assert.strictEqual(fallbackResult.status, 0, `standalone interpreter fallback failed: ${fallbackResult.stderr}`);
  assert.strictEqual(JSON.parse(fallbackResult.stdout).profile, "core");

  console.log("Skill catalog tests passed");
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
