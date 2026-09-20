#!/usr/bin/env node

const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const CJK_PATTERN = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u;

// These replacements are deliberately exact and limited to known upstream text.
// They preserve support for non-English requests while keeping skill instructions
// and examples authored in English.
const EXACT_REPLACEMENTS = new Map([
  ["UTF-8 for Chinese (繁體/簡體), Japanese, Korean, or any non-ASCII text; never", "UTF-8 for Chinese (Traditional/Simplified), Japanese, Korean, or any non-ASCII text; never"],
  ['Also triggers on Chinese\n  equivalents: "优化prompt", "改进prompt", "怎么写prompt", "帮我优化这个指令".', 'Also triggers when a user asks in another language to optimize or improve a prompt.'],
  ['  "just do it" / "直接做". DO NOT TRIGGER when user says "优化代码",\n  "优化性能", "optimize performance", "optimize this code" — those are', '  "just do it" in English or another language. DO NOT TRIGGER when the user asks\n  to optimize code or performance — those are'],
  ['- User says "优化prompt", "改进prompt", "怎么写prompt", "帮我优化这个指令"', '- User asks in another language to optimize, improve, or help write a prompt'],
  ['- User says "优化代码", "优化性能", "optimize this code", "optimize performance" — these are refactoring tasks, not prompt optimization', '- User asks to optimize code or performance in English or another language — these are refactoring tasks, not prompt optimization'],
  ['- User says "just do it" or "直接做"', '- User says "just do it" in English or another language'],
  ['If the user says "just do it", "直接做", or "don\'t optimize, just execute",', 'If the user says "just do it" in English or another language, or says "don\'t optimize, just execute",'],
  ['| New Feature | build, create, add, implement, 创建, 实现, 添加 | "Build a login page" |', '| New Feature | build, create, add, implement, or their non-English equivalents | "Build a login page" |'],
  ['| Bug Fix | fix, broken, not working, error, 修复, 报错 | "Fix the auth flow" |', '| Bug Fix | fix, broken, not working, error, or their non-English equivalents | "Fix the auth flow" |'],
  ['| Refactor | refactor, clean up, restructure, 重构, 整理 | "Refactor the API layer" |', '| Refactor | refactor, clean up, restructure, or their non-English equivalents | "Refactor the API layer" |'],
  ['| Research | how to, what is, explore, investigate, 怎么, 如何 | "How to add SSO" |', '| Research | how to, what is, explore, investigate, or their non-English equivalents | "How to add SSO" |'],
  ['| Testing | test, coverage, verify, 测试, 覆盖率 | "Add tests for the cart" |', '| Testing | test, coverage, verify, or their non-English equivalents | "Add tests for the cart" |'],
  ['| Review | review, audit, check, 审查, 检查 | "Review my PR" |', '| Review | review, audit, check, or their non-English equivalents | "Review my PR" |'],
  ['| Documentation | document, update docs, 文档 | "Update the API docs" |', '| Documentation | document, update docs, or their non-English equivalents | "Update the API docs" |'],
  ['| Infrastructure | deploy, CI, docker, database, 部署, 数据库 | "Set up CI/CD pipeline" |', '| Infrastructure | deploy, CI, docker, database, or their non-English equivalents | "Set up CI/CD pipeline" |'],
  ['| Design | design, architecture, plan, 设计, 架构 | "Design the data model" |', '| Design | design, architecture, plan, or their non-English equivalents | "Design the data model" |'],
  ['- "帮我优化这个指令"', '- A non-English request meaning "Help me optimize this instruction"'],
  ['### Example 1: Vague Chinese Prompt (Project Detected)', '### Example 1: Vague Non-English Prompt (Project Detected)'],
  ['帮我写一个用户登录页面', 'Help me build a user login page'],
  ['使用项目现有技术栈（Next.js 15 + TypeScript + Tailwind CSS）实现用户登录页面。\n\n技术要求：\n- 沿用项目现有的组件结构和路由约定\n- 表单验证使用项目中已有的验证方案（检查是否已用 Zod/Yup/其他）\n- 认证方式：沿用项目现有认证方案（如无，默认 JWT）\n- 包含：邮箱/密码登录表单、表单验证、错误提示、加载状态、响应式布局\n\n工作流：\n1. /plan 先规划组件结构和认证流程，参考现有页面的模式\n2. /tdd 测试先行：编写登录表单的单元测试和认证流程的集成测试\n3. 实现登录页面和认证逻辑\n4. /code-review 审查实现\n5. /verify 验证所有测试通过且页面正常渲染\n\n安全要求：\n- 密码不明文传输\n- 防止暴力破解（rate limiting）\n- XSS 防护\n- CSRF token\n\n验收标准：\n- 所有测试通过，覆盖率 80%+\n- 页面在移动端和桌面端正常渲染\n- 登录成功跳转到 dashboard，失败显示错误信息\n\n不要做：\n- 不要实现注册页面\n- 不要实现忘记密码功能\n- 不要修改现有的路由结构', 'Build a user login page using the project\'s existing stack (Next.js 15 + TypeScript + Tailwind CSS).\n\nTechnical requirements:\n- Follow the project\'s existing component structure and routing conventions\n- Use the project\'s existing form validation solution (check for Zod, Yup, or another library)\n- Reuse the project\'s existing authentication approach; if none exists, default to JWT\n- Include an email/password form, validation, error messages, loading state, and responsive layout\n\nWorkflow:\n1. Use /plan to design the component structure and authentication flow based on existing pages\n2. Use /tdd to write unit tests for the form and integration tests for authentication first\n3. Implement the login page and authentication logic\n4. Use /code-review to review the implementation\n5. Use /verify to confirm every test passes and the page renders correctly\n\nSecurity requirements:\n- Never transmit passwords as plaintext\n- Prevent brute-force attacks with rate limiting\n- Protect against XSS\n- Use a CSRF token\n\nAcceptance criteria:\n- Every test passes with at least 80% coverage\n- The page renders correctly on mobile and desktop\n- Successful login redirects to the dashboard; failure displays an error\n\nDo not:\n- Implement registration\n- Implement password recovery\n- Change the existing route structure'],
  ['rg "must.*tool|必须.*工具|required.*call" --type md', 'rg "must.*tool|required.*call" --type md'],
  ['User: "バグチェックして" (or "/bug-check")', 'User: asks to check for bugs (or uses "/bug-check")'],
  ['alert("削除に失敗しました");', 'alert("Failed to delete the item");'],
  ['- Bank deposit certificates (存款证明)', '- Bank deposit certificates'],
  ['- Income certificates (收入证明)', '- Income certificates'],
  ['- Employment certificates (在职证明)', '- Employment certificates'],
  ['- Retirement certificates (退休证明)', '- Retirement certificates'],
  ['- Property certificates (房产证明)', '- Property certificates'],
  ['- Business licenses (营业执照)', '- Business licenses'],
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
