#!/usr/bin/env node

const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const CJK_PATTERN = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u;

// These replacements are deliberately exact and limited to known upstream text.
// They preserve support for non-English requests while keeping skill instructions
// and examples authored in English. Unicode escapes keep the repository source
// English-only while evaluating to the original upstream text at runtime.
const EXACT_REPLACEMENTS = new Map([
  ["UTF-8 for Chinese (\u7e41\u9ad4/\u7c21\u9ad4), Japanese, Korean, or any non-ASCII text; never", "UTF-8 for Chinese (Traditional/Simplified), Japanese, Korean, or any non-ASCII text; never"],
  ['Also triggers on Chinese\n  equivalents: "\u4f18\u5316prompt", "\u6539\u8fdbprompt", "\u600e\u4e48\u5199prompt", "\u5e2e\u6211\u4f18\u5316\u8fd9\u4e2a\u6307\u4ee4".', 'Also triggers when a user asks in another language to optimize or improve a prompt.'],
  ['  "just do it" / "\u76f4\u63a5\u505a". DO NOT TRIGGER when user says "\u4f18\u5316\u4ee3\u7801",\n  "\u4f18\u5316\u6027\u80fd", "optimize performance", "optimize this code" — those are', '  "just do it" in English or another language. DO NOT TRIGGER when the user asks\n  to optimize code or performance — those are'],
  ['- User says "\u4f18\u5316prompt", "\u6539\u8fdbprompt", "\u600e\u4e48\u5199prompt", "\u5e2e\u6211\u4f18\u5316\u8fd9\u4e2a\u6307\u4ee4"', '- User asks in another language to optimize, improve, or help write a prompt'],
  ['- User says "\u4f18\u5316\u4ee3\u7801", "\u4f18\u5316\u6027\u80fd", "optimize this code", "optimize performance" — these are refactoring tasks, not prompt optimization', '- User asks to optimize code or performance in English or another language — these are refactoring tasks, not prompt optimization'],
  ['- User says "just do it" or "\u76f4\u63a5\u505a"', '- User says "just do it" in English or another language'],
  ['If the user says "just do it", "\u76f4\u63a5\u505a", or "don\'t optimize, just execute",', 'If the user says "just do it" in English or another language, or says "don\'t optimize, just execute",'],
  ['| New Feature | build, create, add, implement, \u521b\u5efa, \u5b9e\u73b0, \u6dfb\u52a0 | "Build a login page" |', '| New Feature | build, create, add, implement, or their non-English equivalents | "Build a login page" |'],
  ['| Bug Fix | fix, broken, not working, error, \u4fee\u590d, \u62a5\u9519 | "Fix the auth flow" |', '| Bug Fix | fix, broken, not working, error, or their non-English equivalents | "Fix the auth flow" |'],
  ['| Refactor | refactor, clean up, restructure, \u91cd\u6784, \u6574\u7406 | "Refactor the API layer" |', '| Refactor | refactor, clean up, restructure, or their non-English equivalents | "Refactor the API layer" |'],
  ['| Research | how to, what is, explore, investigate, \u600e\u4e48, \u5982\u4f55 | "How to add SSO" |', '| Research | how to, what is, explore, investigate, or their non-English equivalents | "How to add SSO" |'],
  ['| Testing | test, coverage, verify, \u6d4b\u8bd5, \u8986\u76d6\u7387 | "Add tests for the cart" |', '| Testing | test, coverage, verify, or their non-English equivalents | "Add tests for the cart" |'],
  ['| Review | review, audit, check, \u5ba1\u67e5, \u68c0\u67e5 | "Review my PR" |', '| Review | review, audit, check, or their non-English equivalents | "Review my PR" |'],
  ['| Documentation | document, update docs, \u6587\u6863 | "Update the API docs" |', '| Documentation | document, update docs, or their non-English equivalents | "Update the API docs" |'],
  ['| Infrastructure | deploy, CI, docker, database, \u90e8\u7f72, \u6570\u636e\u5e93 | "Set up CI/CD pipeline" |', '| Infrastructure | deploy, CI, docker, database, or their non-English equivalents | "Set up CI/CD pipeline" |'],
  ['| Design | design, architecture, plan, \u8bbe\u8ba1, \u67b6\u6784 | "Design the data model" |', '| Design | design, architecture, plan, or their non-English equivalents | "Design the data model" |'],
  ['- "\u5e2e\u6211\u4f18\u5316\u8fd9\u4e2a\u6307\u4ee4"', '- A non-English request meaning "Help me optimize this instruction"'],
  ['### Example 1: Vague Chinese Prompt (Project Detected)', '### Example 1: Vague Non-English Prompt (Project Detected)'],
  ['\u5e2e\u6211\u5199\u4e00\u4e2a\u7528\u6237\u767b\u5f55\u9875\u9762', 'Help me build a user login page'],
  ['\u4f7f\u7528\u9879\u76ee\u73b0\u6709\u6280\u672f\u6808\uff08Next.js 15 + TypeScript + Tailwind CSS\uff09\u5b9e\u73b0\u7528\u6237\u767b\u5f55\u9875\u9762\u3002\n\n\u6280\u672f\u8981\u6c42\uff1a\n- \u6cbf\u7528\u9879\u76ee\u73b0\u6709\u7684\u7ec4\u4ef6\u7ed3\u6784\u548c\u8def\u7531\u7ea6\u5b9a\n- \u8868\u5355\u9a8c\u8bc1\u4f7f\u7528\u9879\u76ee\u4e2d\u5df2\u6709\u7684\u9a8c\u8bc1\u65b9\u6848\uff08\u68c0\u67e5\u662f\u5426\u5df2\u7528 Zod/Yup/\u5176\u4ed6\uff09\n- \u8ba4\u8bc1\u65b9\u5f0f\uff1a\u6cbf\u7528\u9879\u76ee\u73b0\u6709\u8ba4\u8bc1\u65b9\u6848\uff08\u5982\u65e0\uff0c\u9ed8\u8ba4 JWT\uff09\n- \u5305\u542b\uff1a\u90ae\u7bb1/\u5bc6\u7801\u767b\u5f55\u8868\u5355\u3001\u8868\u5355\u9a8c\u8bc1\u3001\u9519\u8bef\u63d0\u793a\u3001\u52a0\u8f7d\u72b6\u6001\u3001\u54cd\u5e94\u5f0f\u5e03\u5c40\n\n\u5de5\u4f5c\u6d41\uff1a\n1. /plan \u5148\u89c4\u5212\u7ec4\u4ef6\u7ed3\u6784\u548c\u8ba4\u8bc1\u6d41\u7a0b\uff0c\u53c2\u8003\u73b0\u6709\u9875\u9762\u7684\u6a21\u5f0f\n2. /tdd \u6d4b\u8bd5\u5148\u884c\uff1a\u7f16\u5199\u767b\u5f55\u8868\u5355\u7684\u5355\u5143\u6d4b\u8bd5\u548c\u8ba4\u8bc1\u6d41\u7a0b\u7684\u96c6\u6210\u6d4b\u8bd5\n3. \u5b9e\u73b0\u767b\u5f55\u9875\u9762\u548c\u8ba4\u8bc1\u903b\u8f91\n4. /code-review \u5ba1\u67e5\u5b9e\u73b0\n5. /verify \u9a8c\u8bc1\u6240\u6709\u6d4b\u8bd5\u901a\u8fc7\u4e14\u9875\u9762\u6b63\u5e38\u6e32\u67d3\n\n\u5b89\u5168\u8981\u6c42\uff1a\n- \u5bc6\u7801\u4e0d\u660e\u6587\u4f20\u8f93\n- \u9632\u6b62\u66b4\u529b\u7834\u89e3\uff08rate limiting\uff09\n- XSS \u9632\u62a4\n- CSRF token\n\n\u9a8c\u6536\u6807\u51c6\uff1a\n- \u6240\u6709\u6d4b\u8bd5\u901a\u8fc7\uff0c\u8986\u76d6\u7387 80%+\n- \u9875\u9762\u5728\u79fb\u52a8\u7aef\u548c\u684c\u9762\u7aef\u6b63\u5e38\u6e32\u67d3\n- \u767b\u5f55\u6210\u529f\u8df3\u8f6c\u5230 dashboard\uff0c\u5931\u8d25\u663e\u793a\u9519\u8bef\u4fe1\u606f\n\n\u4e0d\u8981\u505a\uff1a\n- \u4e0d\u8981\u5b9e\u73b0\u6ce8\u518c\u9875\u9762\n- \u4e0d\u8981\u5b9e\u73b0\u5fd8\u8bb0\u5bc6\u7801\u529f\u80fd\n- \u4e0d\u8981\u4fee\u6539\u73b0\u6709\u7684\u8def\u7531\u7ed3\u6784', 'Build a user login page using the project\'s existing stack (Next.js 15 + TypeScript + Tailwind CSS).\n\nTechnical requirements:\n- Follow the project\'s existing component structure and routing conventions\n- Use the project\'s existing form validation solution (check for Zod, Yup, or another library)\n- Reuse the project\'s existing authentication approach; if none exists, default to JWT\n- Include an email/password form, validation, error messages, loading state, and responsive layout\n\nWorkflow:\n1. Use /plan to design the component structure and authentication flow based on existing pages\n2. Use /tdd to write unit tests for the form and integration tests for authentication first\n3. Implement the login page and authentication logic\n4. Use /code-review to review the implementation\n5. Use /verify to confirm every test passes and the page renders correctly\n\nSecurity requirements:\n- Never transmit passwords as plaintext\n- Prevent brute-force attacks with rate limiting\n- Protect against XSS\n- Use a CSRF token\n\nAcceptance criteria:\n- Every test passes with at least 80% coverage\n- The page renders correctly on mobile and desktop\n- Successful login redirects to the dashboard; failure displays an error\n\nDo not:\n- Implement registration\n- Implement password recovery\n- Change the existing route structure'],
  ['rg "must.*tool|\u5fc5\u987b.*\u5de5\u5177|required.*call" --type md', 'rg "must.*tool|required.*call" --type md'],
  ['User: "\u30d0\u30b0\u30c1\u30a7\u30c3\u30af\u3057\u3066" (or "/bug-check")', 'User: asks to check for bugs (or uses "/bug-check")'],
  ['alert("\u524a\u9664\u306b\u5931\u6557\u3057\u307e\u3057\u305f");', 'alert("Failed to delete the item");'],
  ['- Bank deposit certificates (\u5b58\u6b3e\u8bc1\u660e)', '- Bank deposit certificates'],
  ['- Income certificates (\u6536\u5165\u8bc1\u660e)', '- Income certificates'],
  ['- Employment certificates (\u5728\u804c\u8bc1\u660e)', '- Employment certificates'],
  ['- Retirement certificates (\u9000\u4f11\u8bc1\u660e)', '- Retirement certificates'],
  ['- Property certificates (\u623f\u4ea7\u8bc1\u660e)', '- Property certificates'],
  ['- Business licenses (\u8425\u4e1a\u6267\u7167)', '- Business licenses'],
]);

function parseArgs(argv) {
  const options = { roots: [], allowedWriteRoots: [], strict: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--root") options.roots.push(path.resolve(argv[++i]));
    else if (arg === "--allowed-write-root") options.allowedWriteRoots.push(path.resolve(argv[++i]));
    else if (arg === "--backup-root") options.backupRoot = path.resolve(argv[++i]);
    else if (arg === "--overrides") options.overrides = path.resolve(argv[++i]);
    else if (arg === "--strict") options.strict = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (options.roots.length === 0) {
    options.roots = [path.join(os.homedir(), ".codex", "skills"), path.join(os.homedir(), ".agents", "skills")];
  }
  if (options.allowedWriteRoots.length === 0) options.allowedWriteRoots = [...options.roots];
  options.backupRoot ||= path.join(os.homedir(), ".codex", "backups", "english-skill-originals");
  options.overrides ||= path.resolve(__dirname, "..", "skill-overrides");
  return options;
}

function isWithin(candidate, root) {
  const relative = path.relative(root, candidate);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== "..");
}

function collectSkillFiles(root, files, visitedDirectories, allowedWriteRoots, skippedExternal) {
  if (!fs.existsSync(root)) return;
  const canonical = fs.realpathSync(root);
  if (!allowedWriteRoots.some((allowedRoot) => isWithin(canonical, allowedRoot))) {
    skippedExternal.add(canonical);
    return;
  }
  const stat = fs.statSync(canonical);
  if (!stat.isDirectory() || visitedDirectories.has(canonical)) return;
  visitedDirectories.add(canonical);
  const skillFile = path.join(canonical, "SKILL.md");
  if (fs.existsSync(skillFile)) {
    const canonicalSkillFile = fs.realpathSync(skillFile);
    if (allowedWriteRoots.some((allowedRoot) => isWithin(canonicalSkillFile, allowedRoot))) files.add(canonicalSkillFile);
    else skippedExternal.add(canonicalSkillFile);
  }
  for (const entry of fs.readdirSync(canonical, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === "node_modules") continue;
    const child = path.join(canonical, entry.name);
    if (entry.isDirectory() || entry.isSymbolicLink()) {
      try { collectSkillFiles(child, files, visitedDirectories, allowedWriteRoots, skippedExternal); } catch { /* ignore broken links */ }
    }
  }
}

function backupFile(file, original, backupRoot) {
  fs.mkdirSync(backupRoot, { recursive: true });
  const digest = crypto.createHash("sha256").update(file).update("\0").update(original).digest("hex").slice(0, 12);
  const target = path.join(backupRoot, `${path.basename(path.dirname(file))}-${digest}-SKILL.md`);
  if (!fs.existsSync(target)) fs.copyFileSync(file, target, fs.constants.COPYFILE_EXCL);
  return target;
}

function normalizedContent(file, original, overrides) {
  if (path.basename(path.dirname(file)) === "generating-python-installer" && CJK_PATTERN.test(original)) {
    const override = path.join(overrides, "generating-python-installer", "SKILL.md");
    if (fs.existsSync(override)) return fs.readFileSync(override, "utf8");
  }
  let updated = original;
  for (const [source, replacement] of EXACT_REPLACEMENTS) updated = updated.split(source).join(replacement);
  return updated;
}

function normalize(options) {
  const files = new Set();
  const visitedDirectories = new Set();
  const skippedExternal = new Set();
  const configuredAllowedRoots = options.allowedWriteRoots || options.roots;
  const allowedWriteRoots = configuredAllowedRoots.filter(fs.existsSync).map((root) => fs.realpathSync(root));
  for (const root of options.roots) collectSkillFiles(root, files, visitedDirectories, allowedWriteRoots, skippedExternal);
  const changed = [];
  const residual = [];
  for (const file of [...files].sort()) {
    const original = fs.readFileSync(file, "utf8");
    const updated = normalizedContent(file, original, options.overrides);
    if (updated !== original) {
      const backup = backupFile(file, original, options.backupRoot);
      fs.writeFileSync(file, updated, { mode: fs.statSync(file).mode });
      changed.push({ file, backup });
    }
    if (CJK_PATTERN.test(updated)) residual.push(file);
  }
  return { scanned: files.size, changed, residual, skippedExternal: [...skippedExternal].sort() };
}

if (require.main === module) {
  try {
    const options = parseArgs(process.argv.slice(2));
    const result = normalize(options);
    console.log(`English skill normalization: ${result.changed.length} changed, ${result.scanned} scanned`);
    for (const item of result.changed) console.log(`  normalized: ${item.file} (backup: ${item.backup})`);
    if (result.residual.length > 0) {
      console.warn("WARNING: Non-English CJK text remains in these skill files:");
      for (const file of result.residual) console.warn(`  ${file}`);
    }
    if (result.skippedExternal.length > 0) {
      console.warn("WARNING: Refusing to follow skill links outside the allowed write roots:");
      for (const file of result.skippedExternal) console.warn(`  ${file}`);
    }
    if (options.strict && (result.residual.length > 0 || result.skippedExternal.length > 0)) process.exitCode = 1;
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = { CJK_PATTERN, EXACT_REPLACEMENTS, normalize, parseArgs };
