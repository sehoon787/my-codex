[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) 在找 Claude Code？→ **my-claude** — 同样的 Boss 编排架构，原生 Claude `.md` Agent 格式

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-330%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

**OpenAI Codex CLI 的一体化 Agent 框架。**
**安装一次，330+ Agent 随时待命。**

Boss 在运行时自动发现所有 Agent 和 Skill，
并通过 `spawn_agent` 将任务路由到最合适的专家。无需配置，无需样板代码。

<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

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

---

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
| **P1** | Skill 匹配 | 任务对应某个独立 skill | `"merge PDFs"` → pdf skill |
| **P2** | 专家 Agent | 存在领域专属 Agent | `"security audit"` → security-reviewer |
| **P3a** | Boss 直接 | 2–4 个独立 Agent | `"fix 3 bugs"` → parallel spawn |
| **P3b** | 子编排器 | 复杂多步骤工作流 | `"refactor + test"` → Sisyphus |
| **P4** | 回退 | 无专家匹配 | `"explain this"` → general agent |

### 模型路由

| 复杂度 | 模型 | 用途 |
|-----------|-------|----------|
| 深度分析、架构 | o3（high reasoning） | Boss、Oracle、Sisyphus、Atlas |
| 标准实现 | o3（medium） | executor、debugger、security-reviewer |
| 快速查询、探索 | o4-mini（low） | explore、简单咨询 |

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

---

## 架构

```
┌─────────────────────────────────────────────────────┐
│                    User Request                       │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Boss · Meta-Orchestrator (o3 high)                   │
│  Discovery → Classification → Matching → Delegation  │
└──┬──────────┬──────────┬──────────┬─────────────────┘
   │          │          │          │
   ▼          ▼          ▼          ▼
┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ P3a  │ │  P3b   │ │  P1/P2 │ │Config  │
│Direct│ │Sub-orch│ │ Skill/ │ │Control │
│2-4   │ │Sisyphus│ │ Agent  │ │config. │
│spawn │ │Atlas   │ │ Direct │ │toml    │
└──────┘ └────────┘ └────────┘ └────────┘
┌─────────────────────────────────────────────────────┐
│  Agent Layer (330+ installed TOML files)              │
│  OMO 9 · OMX 33 · Awesome Core 54 · Superpowers 1   │
│  + 20 domain agent-packs (on-demand)                  │
├─────────────────────────────────────────────────────┤
│  Skills Layer (200+ from ECC + gstack + OMX + more)  │
│  tdd-workflow · security-review · autopilot           │
│  pdf · docx · pptx · xlsx · team                     │
├─────────────────────────────────────────────────────┤
│  MCP Layer                                            │
│  Context7 · Exa · grep.app                            │
└─────────────────────────────────────────────────────┘
```

---

## 内容一览

| 类别 | 数量 | 来源 |
|----------|------:|--------|
| **核心 Agent**（始终加载） | 98 | Boss 1 + OMO 9 + OMX 33 + Awesome Core 54 + Superpowers 1 |
| **Agent 包**（按需加载） | 220+ | 来自 agency-agents + awesome-codex-subagents 的 20 个领域分类 |
| **Skills** | 200+ | ECC 180+ · gstack 40 · OMX 36 · Superpowers 14 · Core 1 |
| **MCP 服务器** | 3 | Context7、Exa、grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>核心 Agent — Boss 元编排器（1）</strong></summary>

| Agent | 模型 | 角色 | 来源 |
|-------|-------|------|--------|
| Boss | o3 high | 动态运行时发现 → 能力匹配 → 最优路由。从不编写代码。 | my-codex |

</details>

<details>
<summary><strong>OMO Agents — 子编排器与专家（9）</strong></summary>

| Agent | 模型 | 角色 | 来源 |
|-------|-------|------|--------|
| Sisyphus | o3 high | 意图分类 → 专家委派 → 验证 | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | o3 high | 自主探索 → 规划 → 执行 → 验证 | oh-my-openagent |
| Atlas | o3 high | 任务分解 + 四阶段 QA 验证 | oh-my-openagent |
| Oracle | o3 high | 战略技术咨询（只读） | oh-my-openagent |
| Metis | o3 high | 意图分析、歧义检测 | oh-my-openagent |
| Momus | o3 high | 计划可行性评审 | oh-my-openagent |
| Prometheus | o3 high | 基于访谈的详细规划 | oh-my-openagent |
| Librarian | o3 medium | 通过 MCP 搜索开源文档 | oh-my-openagent |
| Multimodal-Looker | o3 medium | 图像 / 截图 / 图表分析 | oh-my-openagent |

</details>

<details>
<summary><strong>OMC Agents — 专家工作者（19）</strong></summary>

| Agent | 角色 | 来源 |
|-------|------|--------|
| analyst | 规划前预分析 | [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) |
| architect | 系统设计与架构 | oh-my-claudecode |
| code-reviewer | 专注代码审查 | oh-my-claudecode |
| code-simplifier | 代码简化与清理 | oh-my-claudecode |
| critic | 批判性分析、替代方案提议 | oh-my-claudecode |
| debugger | 专注调试 | oh-my-claudecode |
| designer | UI/UX 设计指导 | oh-my-claudecode |
| document-specialist | 文档撰写 | oh-my-claudecode |
| executor | 任务执行 | oh-my-claudecode |
| explore | 代码库探索 | oh-my-claudecode |
| git-master | Git 工作流管理 | oh-my-claudecode |
| planner | 快速规划 | oh-my-claudecode |
| qa-tester | 质量保证测试 | oh-my-claudecode |
| scientist | 研究与实验 | oh-my-claudecode |
| security-reviewer | 安全审查 | oh-my-claudecode |
| test-engineer | 测试编写与维护 | oh-my-claudecode |
| tracer | 执行追踪与分析 | oh-my-claudecode |
| verifier | 最终验证 | oh-my-claudecode |
| writer | 内容与文档 | oh-my-claudecode |

</details>

<details>
<summary><strong>Awesome Core Agents（54）— 来自 awesome-codex-subagents</strong></summary>

4 个分类安装至 `~/.codex/agents/`：

**01-core-development（12）**
accessibility-tester, ad-security-reviewer, agent-installer, api-designer, code-documenter, code-reviewer, dependency-manager, full-stack-developer, monorepo-specialist, performance-optimizer, refactoring-specialist, tech-debt-analyzer

**03-infrastructure（16）**
azure-infra-engineer, cloud-architect, container-orchestrator, database-architect, disaster-recovery-planner, edge-computing-specialist, infrastructure-as-code, kubernetes-operator, load-balancer-specialist, message-queue-designer, microservices-architect, monitoring-specialist, network-engineer, serverless-architect, service-mesh-designer, storage-architect

**04-quality-security（16）**
api-security-tester, chaos-engineer, compliance-auditor, contract-tester, data-privacy-officer, e2e-test-architect, incident-responder, load-tester, mutation-tester, penetration-tester, regression-tester, security-scanner, soc-analyst, static-analyzer, threat-modeler, vulnerability-assessor

**09-meta-orchestration（10）**
agent-organizer, capability-assessor, conflict-resolver, context-manager, execution-planner, multi-agent-coordinator, priority-manager, resource-allocator, task-decomposer, workflow-orchestrator

</details>

<details>
<summary><strong>Superpowers Agent（1）— 来自 obra/superpowers</strong></summary>

| Agent | 角色 | 来源 |
|-------|------|--------|
| superpowers-code-reviewer | 全面代码审查，包含头脑风暴和 TDD 验证 | [superpowers](https://github.com/obra/superpowers) |

</details>

<details>
<summary><strong>Agent 包 — 按需领域专家（21 个分类）</strong></summary>

安装至 `~/.codex/agent-packs/`。通过以下命令管理：

```bash
# View current state
~/.codex/bin/my-codex-packs status

# Enable a pack immediately
~/.codex/bin/my-codex-packs enable marketing

# Switch profiles at install time
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
```

| 包 | 数量 | 示例 |
|------|------:|---------|
| engineering | 32 | Backend、Frontend、Mobile、DevOps、AI、Data |
| marketing | 27 | Douyin、Xiaohongshu、WeChat OA、TikTok、SEO |
| language-specialists | 27 | Python、Go、Rust、Swift、Kotlin、Java |
| specialized | 31 | 法律、金融、医疗、工作流 |
| game-development | 20 | Unity、Unreal、Godot、Roblox、Blender |
| infrastructure | 19 | Cloud、K8s、Terraform、Docker、SRE |
| developer-experience | 13 | MCP Builder、LSP、Terminal、Rapid Prototyper |
| data-ai | 13 | Data Engineer、ML、Database、ClickHouse |
| specialized-domains | 12 | 供应链、物流、电商 |
| design | 11 | 品牌、UI、UX、视觉叙事 |
| business-product | 11 | 产品经理、增长、分析 |
| testing | 11 | API、无障碍、性能、E2E、QA |
| sales | 8 | 交易策略、管道、外向销售 |
| paid-media | 7 | Google Ads、Meta Ads、程序化广告 |
| research-analysis | 7 | 趋势、市场、竞争分析 |
| project-management | 6 | 敏捷、Jira、工作流 |
| spatial-computing | 6 | XR、WebXR、AR/VR、visionOS |
| support | 6 | 客户支持、开发者倡导 |
| academic | 5 | 留学、企业培训 |
| product | 5 | 产品管理、UX 研究 |
| security | 5 | 渗透测试、合规、审计 |

</details>

<details>
<summary><strong>Skills — 200+ 来自 5 个来源</strong></summary>

| 来源 | 数量 | 核心 Skills |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 180+ | tdd-workflow、autopilot、security-review、coding-standards |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 36 | plan、team、trace、deep-dive、blueprint、ultrawork |
| [gstack](https://github.com/garrytan/gstack) | 40 | /qa、/review、/ship、/cso、/investigate、/office-hours |
| [superpowers](https://github.com/obra/superpowers) | 14 | brainstorming、systematic-debugging、TDD、parallel-agents |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 1 | boss-advanced |

</details>

<details>
<summary><strong>MCP 服务器（3）</strong></summary>

| 服务器 | 用途 | 费用 |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://mcp.context7.com) | 实时库文档 | 免费 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://mcp.exa.ai) | 语义网页搜索 | 每月免费 1k 次请求 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://mcp.grep.app) | GitHub 代码搜索 | 免费 |

</details>

---

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
└── persona/
    ├── profile.md                   ← Agent affinity stats (auto-updated)
    ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
    ├── rules/                       ← Accepted routing preferences
    └── skills/                      ← Accepted persona skills
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

---

## 上游开源来源

my-codex 捆绑了来自 8 个上游仓库的内容：

| # | 来源 | 提供的内容 |
|---|--------|-----------------|
| 1 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 姊妹项目。同样的 Boss 编排架构，原生 Claude `.md` Agent 格式。Skills、规则和 Briefing Vault 在两个项目间共享。 |
| 2 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 136 个生产级 Agent，原生 TOML 格式。已兼容 Codex，无需转换。54 个核心 Agent 自动加载。 |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 36 个 skills、hooks、HUD 和团队流水线，适用于 Codex CLI。作为架构参考。 |
| 4 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 180+ 个业务专家 Agent 角色，覆盖 14 个分类。通过自动化流水线从 Markdown 转换为原生 TOML。 |
| 5 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 180+ 个跨开发工作流的 skills。移除 Claude Code 专属内容，保留通用编码 skills。 |
| 6 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 个 skills + 1 个 Agent，覆盖头脑风暴、TDD、并行 Agent 和代码审查。 |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 个 OMO Agent（Sisyphus、Atlas、Oracle 等）。适配为 Codex 原生 TOML 格式。 |
| 8 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 40 个用于代码审查、QA、安全审计、部署的 skills。包含 Playwright 浏览器守护进程。 |

---

## GitHub Actions

| 工作流 | 触发条件 | 用途 |
|----------|---------|---------|
| **CI** | push、PR | 验证 TOML Agent 文件、skill 存在性和上游文件数量 |
| **Update Upstream** | 每周（周一）/ 手动 | 运行 `git submodule update --remote` 并创建自动合并 PR |
| **Auto Tag** | push 到 main | 从 `config.toml` 读取版本并在有新版本时创建 git tag |
| **Pages** | push 到 main | 将 `docs/index.html` 部署到 GitHub Pages |
| **CLA** | PR | 贡献者许可协议检查 |
| **Lint Workflows** | push、PR | 验证 GitHub Actions 工作流 YAML 语法 |

---

## my-codex 原创功能

专为本项目构建、超出上游来源的功能：

| 功能 | 描述 |
|---------|-------------|
| **Boss 元编排器** | 动态能力发现 → 意图分类 → 4 级优先路由 → 委派 → 验证 |
| **三阶段冲刺** | 设计（交互式）→ 执行（通过 executor 自主进行）→ 审查（交互式对比设计文档） |
| **Agent 层级优先级** | core > omo > omc > awesome-core 去重。最专业的 Agent 优先。 |
| **成本优化** | 咨询用 o4-mini，实现用 o3——330+ Agent 自动模型路由 |
| **Agent 遥测** | PostToolUse hook 将 Agent 使用情况记录到 `agent-usage.jsonl` |
| **智能包** | 项目类型检测在会话开始时推荐相关 Agent 包 |
| **Agent 包系统** | 通过 `--profile` 和 `my-codex-packs` 助手按需激活领域专家 |
| **Codex 归属** | git hooks 记录 Codex 修改的文件，并在提交信息中追加 `AI-Contributed-By: Codex` |
| **CI 重复检测** | 跨上游同步自动检测重复 TOML Agent |

---

## 安装选项

### 快速安装

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

重新运行相同命令即可刷新到最新的 `main` 构建，仅替换 `~/.codex/` 中由 my-codex 管理的文件，并从 `~/.agents/skills/` 中删除过时的 skill 副本。

### Agent 包配置文件

首次安装时，my-codex 自动激活推荐的 `dev` 集合（`engineering`、`design`、`testing`、`marketing`、`support`），并记录在 `~/.codex/enabled-agent-packs.txt` 中。

```bash
# Minimal profile (core agents only, no packs)
bash /tmp/my-codex/install.sh --profile minimal

# Full profile (all 21 pack categories enabled)
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
model = "o3"
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

---

## 捆绑的上游版本

上游来源以 git 子模块管理。固定提交记录在 `.gitmodules` 中。

| 来源 | 同步方式 |
|--------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | submodule |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | submodule |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | submodule |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | submodule |
| [gstack](https://github.com/garrytan/gstack) | submodule |
| [superpowers](https://github.com/obra/superpowers) | submodule |

---

## 常见问题

<details>
<summary><strong>my-codex 和 my-claude 有什么区别？</strong></summary>

my-codex 和 my-claude 共享相同的 Boss 编排架构和上游 skill 来源。核心区别在于运行时：my-codex 面向 OpenAI Codex CLI，使用原生 `.toml` Agent 格式和 `spawn_agent` 委派；而 my-claude 面向 Claude Code，使用 `.md` Agent 格式和 Agent 工具。

</details>

<details>
<summary><strong>我可以同时使用 my-codex 和 my-claude 吗？</strong></summary>

可以。它们安装到独立目录（`~/.codex/` 和 `~/.claude/`），互不冲突。共享上游来源的 skills 已针对各自平台适配。

</details>

<details>
<summary><strong>Agent 包如何工作？</strong></summary>

Agent 包是安装到 `~/.codex/agent-packs/` 的领域专属 Agent 集合。首次安装时，`dev` 配置文件自动激活。使用 `my-codex-packs enable <pack>` 激活更多包，或以 `--profile full` 重新安装以启用所有 21 个分类。

</details>

<details>
<summary><strong>上游同步如何工作？</strong></summary>

GitHub Actions 工作流每周一运行，从所有上游子模块拉取最新提交并创建自动合并 PR。也可以从 Actions 标签页手动触发。

</details>

<details>
<summary><strong>my-codex 使用哪些模型？</strong></summary>

Boss 和子编排器（Sisyphus、Atlas、Oracle）使用 o3 高推理强度。标准工作者使用 o3 中等推理强度。轻量级咨询 Agent 使用 o4-mini。

</details>

---

## 故障排查

### 仅恢复 Skills

如果工具报告 `~/.agents/skills/` 下存在无效的 `SKILL.md` 文件，最常见的原因是旧安装遗留的过期本地副本或过期软链接目标。

从 `~/.agents/skills/` 中删除受影响目录以及 `~/.claude/skills/` 下的对应条目，然后重新安装：

```bash
npx skills add sehoon787/my-codex -y -g
```

如果你使用完整的 Codex 捆绑包，也需重新运行一次 `install.sh`。完整安装器会刷新 `~/.codex/skills/` 并移除 `~/.agents/skills/` 下过时的 my-codex 管理副本。

---

## 贡献

欢迎提交 Issue 和 PR。添加新 Agent 时，请在 `codex-agents/core/` 或 `codex-agents/omo/` 中添加 `.toml` 文件，并更新 `SETUP.md` 中的 Agent 列表。PR 验证步骤和 Codex 提交归属行为详见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 致谢

本项目基于以下工作构建：[my-claude](https://github.com/sehoon787/my-claude)（sehoon787）、[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)（VoltAgent）、[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)（Yeachan Heo）、[agency-agents](https://github.com/msitarzewski/agency-agents)（msitarzewski）、[everything-claude-code](https://github.com/affaan-m/everything-claude-code)（affaan-m）、[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)（code-yeongyu）、[gstack](https://github.com/garrytan/gstack)（garrytan）、[superpowers](https://github.com/obra/superpowers)（Jesse Vincent）、[openai/skills](https://github.com/openai/skills)（OpenAI）。

## 许可证

MIT 许可证。详情请参阅 [LICENSE](./LICENSE) 文件。
