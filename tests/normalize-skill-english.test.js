#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { CJK_PATTERN, normalize } = require("../scripts/normalize-skill-english.js");

const CHINESE_PROMPT_TRIGGER = '- User says "\u4f18\u5316prompt", "\u6539\u8fdbprompt", "\u600e\u4e48\u5199prompt", "\u5e2e\u6211\u4f18\u5316\u8fd9\u4e2a\u6307\u4ee4"\n';
const CHINESE_LEGACY_DESCRIPTION = "\u65e7\u8bf4\u660e\n";
const KOREAN_EXTERNAL_SOURCE = "\uc678\ubd80 \uc6d0\ubcf8\n";
const KOREAN_EXTERNAL_FILE_SOURCE = "\uc678\ubd80 \ud30c\uc77c \uc6d0\ubcf8\n";

const temp = fs.mkdtempSync(path.join(os.tmpdir(), "my-codex-english-skills-"));
try {
  const root = path.join(temp, "skills");
  const backupRoot = path.join(temp, "backups");
  const overrides = path.join(temp, "overrides");
  const promptDir = path.join(root, "prompt-optimizer");
  const aliasDir = path.join(root, "prompt-alias");
  const installerDir = path.join(root, "generating-python-installer");
  const externalDir = path.join(temp, "external-skill");
  const linkedFileDir = path.join(root, "linked-file-skill");
  fs.mkdirSync(promptDir, { recursive: true });
  fs.mkdirSync(path.join(overrides, "generating-python-installer"), { recursive: true });
  fs.mkdirSync(installerDir, { recursive: true });
  fs.mkdirSync(externalDir, { recursive: true });
  fs.mkdirSync(linkedFileDir, { recursive: true });
  fs.writeFileSync(path.join(promptDir, "SKILL.md"), CHINESE_PROMPT_TRIGGER);
  fs.symlinkSync(promptDir, aliasDir, "dir");
  fs.writeFileSync(path.join(installerDir, "SKILL.md"), CHINESE_LEGACY_DESCRIPTION);
  fs.writeFileSync(path.join(overrides, "generating-python-installer", "SKILL.md"), "English override\n");
  fs.writeFileSync(path.join(externalDir, "SKILL.md"), KOREAN_EXTERNAL_SOURCE);
  fs.symlinkSync(externalDir, path.join(root, "external-alias"), "dir");
  const externalFile = path.join(temp, "external-file.md");
  fs.writeFileSync(externalFile, KOREAN_EXTERNAL_FILE_SOURCE);
  fs.symlinkSync(externalFile, path.join(linkedFileDir, "SKILL.md"), "file");

  const first = normalize({ roots: [root], backupRoot, overrides });
  assert.equal(first.scanned, 2, "canonical skill files are scanned once despite aliases");
  assert.equal(first.changed.length, 2);
  assert.deepEqual(first.residual, []);
  assert.deepEqual(first.skippedExternal, [fs.realpathSync(externalFile), fs.realpathSync(externalDir)].sort());
  assert.equal(fs.readFileSync(path.join(externalDir, "SKILL.md"), "utf8"), KOREAN_EXTERNAL_SOURCE, "external symlink source is untouched");
  assert.equal(fs.readFileSync(externalFile, "utf8"), KOREAN_EXTERNAL_FILE_SOURCE, "external file symlink source is untouched");
  assert.equal(CJK_PATTERN.test(fs.readFileSync(path.join(promptDir, "SKILL.md"), "utf8")), false);
  assert.equal(fs.readFileSync(path.join(installerDir, "SKILL.md"), "utf8"), "English override\n");
  assert.equal(fs.readdirSync(backupRoot).length, 2, "each changed source is backed up once");

  fs.writeFileSync(path.join(installerDir, "SKILL.md"), "Custom English instructions\n");
  const second = normalize({ roots: [root], backupRoot, overrides });
  assert.equal(second.changed.length, 0, "normalization is idempotent");
  assert.deepEqual(second.residual, []);
  assert.deepEqual(second.skippedExternal, [fs.realpathSync(externalFile), fs.realpathSync(externalDir)].sort());
  assert.equal(fs.readFileSync(path.join(installerDir, "SKILL.md"), "utf8"), "Custom English instructions\n", "an English customization is preserved");
  assert.equal(fs.readdirSync(backupRoot).length, 2, "idempotent runs do not create extra backups");
  console.log("normalize-skill-english: PASS (2 files changed once, aliases deduplicated, 0 residual CJK)");
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
