#!/usr/bin/env node
"use strict";

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const repo = path.resolve(__dirname, "..");
const cli = path.join(repo, "scripts", "skill-catalog.js");
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
