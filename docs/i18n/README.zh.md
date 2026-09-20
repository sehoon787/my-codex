[英语](../../README.md) | [韩语](./README.ko.md) | [日语](./README.ja.md) | [中文](./README.zh.md) | [德语](./README.de.md) | [法语](./README.fr.md)
> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) 在找 Claude Code？→ **my-claude** — 同样的 Boss 编排架构，原生 Claude `.md` Agent 格式
<div align="center">

# my-codex
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-106-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)
**OpenAI Codex CLI 的一体化 Agent 框架。**
**安装一次，17 个精选 Agent 随时待命。**
Boss 在运行时自动发现所有 Agent 和 Skill，
并通过 `spawn_agent` 将任务路由到最合适的专家。无需配置，无需样板代码。
<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>
## 安装
### 面向用户
```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```
### 面向 AI Agent
```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```
## Boss 的工作原理
Boss 是 my-codex 的核心元编排器。它从不编写代码——它负责发现、分类、匹配、委派和验证。
```
User Request
     │
     ▼
┌─────────────────────────────────────────────┐
│  Phase 0 · DISCOVERY                        │
│  Scan ~/.codex/agents/*.toml at runtime     │
│  → Build live capability registry           │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 1 · INTENT GATE                      │
│  Classify: trivial | build | refactor |     │
│  mid-sized | architecture | research | ...  │
│  → Counter-propose skill if better fit      │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 2 · CAPABILITY MATCHING              │
│  P1: Exact skill match                      │
│  P2: Specialist agent via spawn_agent       │
│  P3: Multi-agent orchestration              │
│  P4: General-purpose fallback               │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 3 · DELEGATION                       │
│  spawn_agent with structured instructions   │
│  TASK / OUTCOME / TOOLS / DO / DON'T / CTX  │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 4 · VERIFICATION                     │
│  Read changed files independently           │
│  Run tests, lint, build                     │
│  Cross-reference with original intent       │
│  → Retry up to 3× on failure               │
└─────────────────────────────────────────────┘
```
### 优先级路由
Boss 对每个请求按优先级链逐级匹配，直到找到最佳方案：
| 优先级 | 匹配类型 | 触发时机 | 示例 |
|:--------:|-----------|------|---------|
| **P1** | Skill 匹配 | 任务对应某个独立 skill | `"review this diff"` → /review skill |
| **P2** | 专家 Agent | 存在领域专属 Agent | `"security audit"` → security-reviewer |
| **P3a** | Boss 直接 | 2–4 个独立 Agent | `"fix 3 bugs"` → parallel spawn |
| **P3b** | 子编排器 | 复杂多步骤工作流 | `"refactor + test"` → Sisyphus |
| **P4** | 回退 | 无专家匹配 | `"explain this"` → general agent |
### 模型路由
| 复杂度 | 模型 | 用途 |
|-----------|-------|----------|
| 深度分析、架构 | gpt-6-astra （high/xhigh reasoning） | Boss、Oracle、Sisyphus、Atlas |
| 标准实现 | gpt-5.6-sol（medium） | executor、debugger、test-engineer |
| 快速查询、探索 | gpt-5.6-terra（low） | explore、简单咨询 |
### 三阶段冲刺工作流
对于端到端功能实现，Boss 编排结构化冲刺：
```
Phase 1: DESIGN         Phase 2: EXECUTE        Phase 3: REVIEW
(interactive)            (autonomous)             (interactive)
─────────────────────   ─────────────────────   ─────────────────────
User decides scope      executor runs tasks     Compare vs design doc
Engineering review      Auto code review        Present comparison table
Confirm "design done"   Architect verification  User: approve / improve
```
### 结构化最终报告
Boss 会以一份无需打开 diff 即可浏览的结构化最终报告来结束每个有实际工作的回合 — 即编辑/创建了文件、进行了提交/PR/合并、更改了配置或执行了验证的回合。报告由 5 个固定表格组成，每个表格仅在对应情况确实发生时才输出（绝不输出空表）:
| 情况 | 表格 | 列 |
|-----------|-------|---------|
| 文件/设置变更 | 变更对照 | 目标 / 之前 / 之后 / 依据 |
| 完成多项任务 | 工作摘要 | 项目 / 结果 / 证据 |
| 执行了验证 | 验证 | 项目 / 预期 / 实际 / 结论 |
| 产出提交/PR | 交付物 | PR / 仓库 / 内容 / 状态 |
| 存在未解决项 | 剩余事项 | 项目 / 状态 / 下一步 |
该报告仅在请求的最末尾触发 — 绝不会在启动或转达后台任务的回合、或作为任务中途的进度更新输出 — 纯问答回合则正常结束、不生成报告。规范同时随 `boss.toml` 的 developer instructions 和 `~/.codex/AGENTS.md` 提供，因此主会话也能看到。与姊妹项目 [my-claude](https://github.com/sehoon787/my-claude) 一样，一个 Stop 钩子（`hooks/stop-final-report.js`）会强制执行它：当某个回合改变了状态却没有输出报告表格时，钩子会将该回合阻断一次并要求补上报告。
## 内容一览
| 类别 | 数量 | 来源 |
|----------|------:|--------|
| **核心 Agent**（始终加载） | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Agent 包**（可选启用，默认全部关闭） | 17 | 2 个内置分类：data-ai 13 + llmops 4 |
| **Skills** | 106 | ECC 61 · gstack 27 · Superpowers 13 · Core 4 · archify 1 |
| **MCP 服务器** | 5 | Context7、Exa、grep.app、Serena、Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |
<details>
<summary><strong>核心 Agent — Boss 元编排器（1）</strong></summary>

| Agent | 模型 | 角色 | 来源 |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | 动态运行时发现 → 能力匹配 → 最优路由。从不编写代码。 | my-codex |

</details>

<details>
<summary><strong>OMO Agents — 子编排器与专家（9）</strong></summary>

| Agent | 模型 | 角色 | 来源 |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | 意图分类 → 专家委派 → 验证 | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | gpt-6-astra high | 自主探索 → 规划 → 执行 → 验证 | oh-my-openagent |
| Atlas | gpt-6-astra high | 任务分解 + 四阶段 QA 验证 | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | 战略技术咨询（只读） | oh-my-openagent |
| Metis | gpt-6-astra high | 意图分析、歧义检测 | oh-my-openagent |
| Momus | gpt-6-astra high | 计划可行性评审 | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | 基于访谈的详细规划 | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | 通过 MCP 搜索开源文档 | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | 图像 / 截图 / 图表分析 | oh-my-openagent |

</details>

<details>
<summary><strong>OMX Agents — 专家工作者（7）</strong></summary>

由 [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) 的 `prompts/*.md` 转换为 Codex TOML。仅转换 `templates/codex-AGENTS.md` 中列出的通道，允许列表位于 `scripts/skill-allowlists.sh`。
| Agent | 沙箱 | 角色 | 来源 |
|-------|---------|------|--------|
| executor | workspace-write | 代码实现 | oh-my-codex |
| planner | workspace-write | 实现规划 | oh-my-codex |
| architect | read-only | 系统设计与架构 | oh-my-codex |
| test-engineer | workspace-write | 测试策略与覆盖率 | oh-my-codex |
| security-reviewer | read-only | 安全分析 | oh-my-codex |
| code-reviewer | read-only | 专注的代码审查 | oh-my-codex |
| debugger | workspace-write | 根因分析 | oh-my-codex |

</details>

<details>
<summary><strong>Agent 包 — 可选启用的 AI 专家（2 个包，17 个 Agent）</strong></summary>

从 [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)（MIT）内置到 `codex-agents/packs/`，并安装到 `~/.codex/agent-packs/`。**默认不启用任何包** — 需要显式开启：
```bash
# 查看当前状态
~/.codex/bin/my-codex-packs status
# 立即启用某个包
~/.codex/bin/my-codex-packs enable data-ai
# 安装时切换配置档
bash /tmp/my-codex/install.sh --profile minimal   # 不启用任何包
bash /tmp/my-codex/install.sh --profile dev       # data-ai + llmops
bash /tmp/my-codex/install.sh --profile full      # 已安装的全部包
```
| 包 | 数量 | Agent |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

</details>

<details>
<summary><strong>Skills — 106 个，来自 5 个来源</strong></summary>

按技能逐项筛选的允许列表位于 `scripts/skill-allowlists.sh`，该文件决定实际安装内容。
| 来源 | 数量 | 主要 Skills |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 61 | coding-standards, python-testing, api-design, deep-research |
| [gstack](https://github.com/garrytan/gstack) | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 13 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| [archify](https://github.com/tt-a1i/archify) | 1 | archify（架构 / 工作流 / 时序 / 数据流 / 生命周期图） |
gstack 按允许列表的 26 个技能加上仓库根条目计为 27。完整 checkout 位于 `~/.codex/vendor/gstack`；`~/.codex/skills/gstack` 是运行时门面。ECC 另外提供 9 个允许列表规则文件。
Codex **不提供文档类 skill** — 本捆绑包中没有 `pdf`、`docx`、`pptx`、`xlsx` skill。

</details>

<details>
<summary><strong>托管 MCP 服务器（3）</strong></summary>

| 服务器 | 用途 | 费用 |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | 实时库文档 | 免费 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | 语义网页搜索 | 每月免费 1k 次请求 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | GitHub 代码搜索 | 免费 |

</details>

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault
兼容 Obsidian 的持久化记忆。每个项目维护一个 `.briefing/` 目录，跨会话自动填充。
```
.briefing/
├── INDEX.md                          ← Project context (auto-created once)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← AI-written session summary (enforced)
│   └── YYYY-MM-DD-auto.md           ← Auto-generated scaffold (git diff, agent stats)
├── decisions/
│   ├── YYYY-MM-DD-<decision>.md     ← AI-written decision record
│   └── YYYY-MM-DD-auto.md           ← Auto-generated scaffold (commits, files)
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← AI-written learning note
│   └── YYYY-MM-DD-auto-session.md   ← Auto-generated scaffold (agents, files)
├── references/
│   └── auto-links.md                ← Auto-collected URLs from web searches
├── agents/
│   ├── agent-log.jsonl              ← Subagent execution telemetry
│   └── YYYY-MM-DD-summary.md        ← Daily agent usage breakdown
├── persona/
│   ├── profile.md                   ← Agent affinity stats (auto-updated)
│   ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
│   ├── rules/                       ← Accepted routing preferences
│   └── skills/                      ← Accepted persona skills
├── archives/                         ← 已完成/不活跃的笔记 (30天+)
│   ├── sessions/
│   ├── decisions/
│   └── learnings/
└── wiki/                             ← 概念页面 (自动建议)
    └── _schema.md
```
### 自动化生命周期
| 阶段 | Hook 事件 | 发生的事情 |
|-------|-----------|-------------|
| **会话开始** | `SessionStart` | 创建 `.briefing/` 结构，保存 git HEAD 哈希用于会话专属差异 |
| **工作期间** | `PostToolUse` Edit/Write | 追踪文件编辑次数；达到 5 次警告，达到 15 次且未写决策 / 学习时阻止 |
| **工作期间** | `PostToolUse` WebSearch/WebFetch | 自动将 URL 收集到 `references/auto-links.md` |
| **工作期间** | `SubagentStop` | 将 Agent 执行记录到 `agents/agent-log.jsonl` |
| **工作期间** | `UserPromptSubmit`（每 5 次） | 节流更新个性化档案 |
| **会话结束** | `Stop`（第 1 个 hook） | 自动生成脚手架：`sessions/auto.md`、`learnings/auto-session.md`、`decisions/auto.md`、`persona/profile.md` |
| **会话结束** | `Stop`（第 2 个 hook） | 若文件编辑 ≥ 3 次则**强制** AI 撰写会话摘要——以模板阻止会话结束 |
| **archives/** | — | 自动建议将 30 天以上的已完成/不活跃笔记归档。PARA 归档概念。 |
| **wiki/** | — | 概念 wiki 页面。关键词出现 3 次以上时自动建议生成。LLM-wiki 概念。 |
### 自动生成 vs AI 撰写
| 类型 | 文件模式 | 创建者 | 内容 |
|------|-------------|-----------|---------|
| **自动脚手架** | `*-auto.md`、`*-auto-session.md` | Stop hook（Node.js） | Git 差异统计、Agent 使用情况、提交列表——仅数据 |
| **AI 摘要** | `YYYY-MM-DD-<topic>.md` | 会话中的 AI | 有意义的分析，包含上下文、代码引用、理由 |
| **遥测** | `agent-log.jsonl`、`auto-links.md` | Hook 脚本 | 仅追加的结构化日志 |
| **个性化** | `profile.md`、`suggestions.jsonl` | Stop hook | 基于使用的 Agent 偏好和路由建议 |
自动脚手架作为 AI 撰写正式摘要的**参考数据**。强制 hook 在阻止会话结束时提供脚手架内容和结构化模板。
### 会话专属差异
在会话开始时，当前 git HEAD 保存到 `.briefing/.session-start-head`。会话结束时，差异相对于此保存点计算——仅显示当前会话的变更，而非之前会话积累的未提交变更。
### 与 Obsidian 配合使用
1. Open Obsidian → **Open folder as vault** → 选择 `.briefing/`
2. 笔记显示在图谱视图中，通过 `[[wiki-links]]` 关联
3. YAML frontmatter（`date`、`type`、`tags`）支持结构化搜索
4. 决策与学习的时间线跨会话自动积累
### 知识管理 (v2)
BriefingVault v2 整合了三种知识管理方法论：
| 方法论 | 概念 | 在 BriefingVault 中的应用 |
|--------|------|--------------------------|
| **PARA**（Tiago Forte） | 按可行性分类：项目、领域、资源、归档 | sessions/ = 项目，decisions/ = 领域，references/ = 资源，archives/ = 归档 |
| **Zettelkasten**（Luhmann） | 具有唯一 ID 和明确链接的原子笔记 | learnings/ 文件：`YYYYMMDDHHMMSS` ID，`related:` 需至少 2 个链接 |
| **LLM-wiki**（Karpathy） | 由 AI 从原始笔记维护的概念页面 | wiki/ 页面：关键词出现 3 次以上时自动建议 |
## 上游开源来源
my-codex 由 **5 个上游子模块**，加上 1 份内置快照、2 个适配/姊妹项目、2 个 companion CLI 与 4 个 MCP 服务器组成：
| # | 来源 | 方式 | 提供的内容 |
|---|--------|------|-----------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 子模块 | 覆盖开发工作流的 61 个允许列表 skills。移除 Claude Code 专属内容，保留通用编码 skills。 |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 子模块 | 27 个用于代码审查、QA、安全审计、部署的 skills。包含 Playwright 浏览器守护进程。 |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 子模块 | 7 个允许列表工作 Agent（executor、planner、architect、test-engineer、security-reviewer、code-reviewer、debugger），由 Markdown 提示词转换为 Codex TOML。 |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 子模块 | 13 个 skills，覆盖头脑风暴、TDD、系统化调试与计划撰写。不安装任何 Agent。 |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | 子模块（标签 `v2.9.0`） | `archify` 技能：将架构、工作流、时序、数据流与生命周期图渲染为内嵌 SVG 的单文件 HTML。仅安装仓库中的 `archify/` 目录。 |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 内置快照 (MIT) | 17 个 AI/LLM Agent 快照到 `codex-agents/packs/`，作为 2 个可选启用的包（data-ai 13、llmops 4）。子模块已于 2026-07-27 移除。 |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 适配 | 9 个 OMO Agent（Sisyphus、Atlas、Oracle 等）。适配为 Codex 原生 TOML 格式并在本仓库维护。 |
| 8 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 姊妹项目 | 同样的 Boss 编排架构，原生 Claude `.md` Agent 格式。Skills、规则和 Briefing Vault 在两个项目间共享。 |
| 9 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | npm CLI (MIT) | 本地优先的 token/成本追踪器。只读解析 `~/.codex/sessions` — 无代理、不上传。由 `install.sh` 安装（固定 `codeburn@0.9.23`），在 `upstream/SOURCES.json` 中以 `method: npm-cli` 登记。Codex 上没有钩子。 |
| 10 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | uv 工具 + MCP | 通过 MCP 进行符号级代码导航与编辑。以 `serena-agent==1.7.0` 安装，注册为 `[mcp_servers.serena]`。分发的软件包整体为 GPL-3.0-or-later —— 因为它把 GPL 应用与 MIT 的 SolidLSP 组合在一起；PyPI 标注的 MIT 并不准确。仅作为独立工具安装，不做内置。 |
| 11 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | uv 工具 + MCP | 通过 MCP 进行上下文压缩（`headroom_compress`、`headroom_retrieve`、`headroom_stats`）。以 `headroom-ai[all]==0.37.0` 安装，注册为 `[mcp_servers.headroom]`。安装程序启动或复用共享本地代理，但不会自动路由 API 流量。Apache-2.0。 |
| 12 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | npm CLI (MIT) | 结构化代码搜索与重写。由 `install.sh` 安装（固定 `@ast-grep/cli@0.42.0`）。 |
| 13 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | 托管 MCP | 最新库文档。由 `install.sh` 注册到 `https://mcp.context7.com/mcp`。 |
| 14 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | 托管 MCP | 神经网络网页搜索。注册到 `https://mcp.exa.ai/mcp?tools=web_search_exa`。 |
| 15 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | 托管 MCP | 跨仓库代码搜索。注册到 `https://mcp.grep.app`。 |
所有子模块均在 `upstream/SOURCES.json`（AI-BOM）（companion CLI（ast-grep、codeburn）与 MCP 服务器（serena、headroom）也在同一文件中以固定版本登记）中以 SHA 固定，该文件同时记录了两个已移除的子模块（`agency-agents` — 未内置任何内容；`awesome-codex-subagents` — 内置 17 个 Agent）。
## 在哪里查看结果
每个已安装的工具都会把结果写到某个地方。位置如下。
| 工具 | 作用 | 如何运行 | 在哪里查看结果 |
|------|--------------|------------|----------------------|
| **codeburn** | 按任务、工具、模型与项目统计 token 与花费 | 安装程序启动或复用 `codeburn web --provider all --port 4747 --no-open`；终端面板使用 `codeburn` | 共享浏览器面板位于 <http://127.0.0.1:4747/>。它不会修改本地 Agent 会话，并按公开价目表估算费用。 |
| **Serena** | 通过 MCP 进行符号级代码导航与编辑 | 由 Codex 从 `[mcp_servers.serena]` 启动；工具为 `get_symbols_overview`、`find_symbol`、`find_referencing_symbols`、`replace_symbol_body`、`insert_after_symbol` | 服务器运行时可在 <http://localhost:24282/dashboard/index.html> 查看面板与工具调用统计；按项目的索引与记忆位于 `<仓库>/.serena/`。浏览器不会自动打开（`--open-web-dashboard False`）。 |
| **Headroom** | 压缩过大的工具输出，并在需要时取回原文 | Codex 从 `[mcp_servers.headroom]`（`headroom mcp serve`）启动 MCP 服务器；安装程序通过 `headroom install apply --profile agent-harness-shared --preset persistent-service --runtime python --providers manual --port 8787 --no-telemetry --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1` 启动或复用原生 `agent-harness-shared` 配置文件 | 统计位于 <http://127.0.0.1:8787/stats>；在通过 `headroom wrap` 或 Base URL 显式路由客户端前保持为空。安装程序不会设置 `ANTHROPIC_BASE_URL` 或 `OPENAI_BASE_URL`。 |
| **Archify** | 架构 / 工作流 / 时序 / 数据流 / 生命周期图 | 在 `~/.codex/skills/archify` 下执行 `node bin/archify.mjs render <type> <input>.json <output>.html`，再执行 `node bin/archify.mjs check <output>.html` | 你指定的 `<output>.html` —— 单个自包含文件，含内嵌 SVG、明暗主题切换与 PNG/JPEG/WebP/SVG 导出。用浏览器打开。技能自带的 `examples/*.json` 就是可直接照抄的完整输入示例。 |
## GitHub Actions
| 工作流 | 触发条件 | 用途 |
|----------|---------|---------|
| **CI** | push、PR | 验证 TOML Agent 文件、skill 存在性和上游文件数量 |
| **Smoke Tests** | push, PR | `hooks`、`shell`、`drift`、`routing-refs` 作业——校验钩子接线、shell 语法、模型漂移与 AGENTS.md 路由引用 |
| **Update Upstream** | 每 3 天 / 手动 | 带安全门禁的 `git submodule update --remote`，刷新 `upstream/SOURCES.json` 固定值并创建自动合并 PR |
| **Auto Tag** | push 到 main | 从 `config.toml` 读取版本并在有新版本时创建 git tag |
| **Pages** | push 到 main | 将 `docs/index.html` 部署到 GitHub Pages |
| **CLA** | PR | 贡献者许可协议检查 |
| **Lint Workflows** | push、PR | 验证 GitHub Actions 工作流 YAML 语法 |
## my-codex 原创功能
专为本项目构建、超出上游来源的功能：
| 功能 | 描述 |
|---------|-------------|
| **Boss 元编排器** | 动态能力发现 → 意图分类 → 4 级优先路由 → 委派 → 验证 |
| **三阶段冲刺** | 设计（交互式）→ 执行（通过 executor 自主进行）→ 审查（交互式对比设计文档） |
| **Agent 层级优先级** | core > omo > omx > 可选包 依次去重。与已安装 Agent 同名的包内 Agent 会被跳过。最专业的 Agent 优先。 |
| **成本优化** | 查询用 gpt-5.6-terra，实现用 gpt-5.6-sol，架构与评审用 gpt-6-astra——覆盖全部 34 个已安装 Agent 的自动模型路由 |
| **Agent 遥测** | PostToolUse hook 将 Agent 使用情况记录到 `agent-usage.jsonl` |
| **智能包** | 项目类型检测在会话开始时推荐相关 Agent 包 |
| **Agent 包系统** | 通过 `--profile` 和 `my-codex-packs` 助手按需激活领域专家 |
| **Codex 归属** | git hooks 记录 Codex 修改的文件，并在提交信息中追加 `AI-Contributed-By: Codex` |
| **CI 重复检测** | 跨上游同步自动检测重复 TOML Agent |
## 安装选项
### 快速安装
```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```
重新运行相同命令即可刷新到最新的 `main` 构建，仅替换 `~/.codex/` 中由 my-codex 管理的文件，并从 `~/.agents/skills/` 中删除过时的 skill 副本。
### Agent 包配置文件
包会被安装，但**默认不启用**。全新安装会在 `~/.codex/enabled-agent-packs.txt` 中记录一个空集合。按包逐个启用，或选择一个配置档：
```bash
# 立即启用某个包
~/.codex/bin/my-codex-packs enable data-ai
# minimal 配置档（仅核心 Agent，不启用任何包 — 默认）
bash /tmp/my-codex/install.sh --profile minimal
# dev 配置档（data-ai + llmops）
bash /tmp/my-codex/install.sh --profile dev
# full 配置档（启用已安装的 2 个包分类）
bash /tmp/my-codex/install.sh --profile full
```
### Codex 归属系统
`install.sh` 安装 `codex` 包装器以及 `~/.codex/git-hooks/` 中的全局 git hooks：
- **`prepare-commit-msg`** — 记录真实 Codex 会话期间修改的文件
- **`commit-msg`** — 当暂存文件与记录的变更集交集时追加 `Generated with Codex CLI: https://github.com/openai/codex`
- **`post-commit`** — 为符合条件的提交添加 `AI-Contributed-By: Codex` trailer
选择性加入 `Co-authored-by` trailer：同时设置 `git config --global my-codex.codexContributorName '<label>'` 和 `my-codex.codexContributorEmail '<github-linked-email>'`。完全禁用：`git config --global my-codex.codexAttribution false`。my-codex **不会**修改 `git user.name`、`git user.email` 或提交作者身份。
### Agent TOML 格式
每个 Agent 都是 `~/.codex/agents/` 中的原生 TOML 文件：
```toml
name = "debugger"
description = "Focused debugging specialist — traces failures to root cause"
model = "gpt-5.6-sol"
model_reasoning_effort = "medium"
[developer_instructions]
content = """
You are a debugging specialist. Analyze failures systematically:
1. Reproduce the issue
2. Isolate the root cause
3. Propose a minimal fix
4. Verify the fix does not break adjacent behavior
"""
```
### config.toml
`~/.codex/config.toml` 中的全局 Codex 设置：
```toml
[agents]
max_threads = 8
max_depth = 1
```
- `max_threads` — 最大并发子 Agent 数
- `max_depth` — Agent 链式 spawn 的最大嵌套深度
## 捆绑的上游版本
上游来源以 git 子模块管理。固定提交记录在 `.gitmodules` 中。
| 来源 | 同步方式 |
|--------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 子模块 (`upstream/ecc`) |
| [gstack](https://github.com/garrytan/gstack) | 子模块 (`upstream/gstack`) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 子模块 (`upstream/omx`) |
| [superpowers](https://github.com/obra/superpowers) | 子模块 (`upstream/superpowers`) |
| [archify](https://github.com/tt-a1i/archify) | 子模块 (`upstream/archify`, 标签 `v2.9.0`) |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | 内置快照（子模块已于 2026-07-27 移除） |
## 常见问题
<details>
<summary><strong>my-codex 和 my-claude 有什么区别？</strong></summary>

my-codex 和 my-claude 共享相同的 Boss 编排架构和上游 skill 来源。核心区别在于运行时：my-codex 面向 OpenAI Codex CLI，使用原生 `.toml` Agent 格式和 `spawn_agent` 委派；而 my-claude 面向 Claude Code，使用 `.md` Agent 格式和 Agent 工具。

</details>

<details>
<summary><strong>我可以同时使用 my-codex 和 my-claude 吗？</strong></summary>

可以。它们安装到独立目录（`~/.codex/` 和 `~/.claude/`）。两个安装程序通过 `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services` 协调 codeburn 与 Headroom，复用健康服务，并且不会终止占用固定端口的外部进程。共享上游来源的 skills 已针对各自平台适配。

</details>

<details>
<summary><strong>Agent 包如何工作？</strong></summary>

Agent 包是安装到 `~/.codex/agent-packs/` 的领域专属 Agent 集合。目前提供 `data-ai`（13 个）与 `llmops`（4 个）两个包，且**安装时不会启用任何包**。使用 `my-codex-packs enable <pack>` 启用，或以 `--profile full` 重新安装以启用这两个分类。

</details>

<details>
<summary><strong>上游同步如何工作？</strong></summary>

GitHub Actions 工作流每 3 天运行一次，从 4 个按分支跟踪的上游子模块拉取最新提交（`upstream/archify` 固定在标签上，只在需要时手动升级），刷新 `upstream/SOURCES.json` 中的 SHA 固定值，并创建带安全门禁的自动合并 PR。也可以从 Actions 标签页手动触发。

</details>

<details>
<summary><strong>my-codex 使用哪些模型？</strong></summary>

Boss 和子编排器（Sisyphus、Atlas、Oracle）使用 gpt-6-astra 高推理强度。标准工作者使用 gpt-5.6-sol 中等推理强度。轻量级咨询 Agent 使用 gpt-5.6-terra。

</details>

## 故障排查
### 仅恢复 Skills
如果工具报告 `~/.agents/skills/` 下存在无效的 `SKILL.md` 文件，最常见的原因是旧安装遗留的过期本地副本或过期软链接目标。
从 `~/.agents/skills/` 中删除受影响目录以及 `~/.claude/skills/` 下的对应条目，然后重新安装：
```bash
npx skills add sehoon787/my-codex -y -g
```
如果你使用完整的 Codex 捆绑包，也需重新运行一次 `install.sh`。完整安装器会刷新 `~/.codex/skills/` 并移除 `~/.agents/skills/` 下过时的 my-codex 管理副本。
## 贡献
欢迎提交 Issue 和 PR。添加新 Agent 时，请在 `codex-agents/core/` 或 `codex-agents/omo/` 中添加 `.toml` 文件，并更新 `SETUP.md` 中的 Agent 列表。PR 验证步骤和 Codex 提交归属行为详见 [CONTRIBUTING.md](./CONTRIBUTING.md)。
## 致谢
本项目基于以下工作构建：[my-claude](https://github.com/sehoon787/my-claude)（sehoon787）、[everything-claude-code](https://github.com/affaan-m/everything-claude-code)（affaan-m）、[gstack](https://github.com/garrytan/gstack)（garrytan）、[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)（Yeachan Heo）、[superpowers](https://github.com/obra/superpowers)（Jesse Vincent）、[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)（VoltAgent）、[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)（code-yeongyu）、[openai/skills](https://github.com/openai/skills)（OpenAI）。
## 许可证
MIT 许可证。详情请参阅 [LICENSE](./LICENSE) 文件。
