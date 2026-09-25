[英语](../../README.md) | [韩语](./README.ko.md) | [日语](./README.ja.md) | [中文](./README.zh.md) | [德语](./README.de.md) | [法语](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) 在找 Claude Code？→ **my-claude** — 以原生 Claude `.md` Agent 格式提供同样的 Boss 编排

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-30_default_%2F_110_installed-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**面向 Codex CLI 的一体化 Agent 框架。**
**安装一次，17 个核心 Agent 即刻可用。**

Boss 在运行时发现每一个 Agent、Skill 和 MCP 工具，<br>
再通过 `spawn_agent` 把任务路由给合适的专家。无需配置文件，无需样板代码。

<img src="../../assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## 安装

### 面向用户

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

也可以先克隆，再在检出目录里运行安装脚本：

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

默认安装只暴露精简的 Skill 集合，这是有意为之：Codex 在超出 Skill 预算后会截断
Skill 描述，因此默认的 `core` 配置只向 Codex 展示已安装的 110 个 Skill 条目中的 30 个，
其余的只需一个参数即可开启：

```bash
bash install.sh --skills=web          # 增加 18 个 Web/UI 车道 Skill
bash install.sh --full-skills         # 全部可选车道，并切换到 full 暴露配置
bash install.sh --skill-profile=core  # 回到默认暴露范围
```

所选结果会被保存，之后直接运行 `bash install.sh` 也会保留。全部配置、车道以及 `my-codex-skills` 命令见[Skill 配置与车道](#skill-配置与车道)。

交互式终端会显示三个 companion 工具 —— Serena、Headroom、codeburn —— 的复选框选择器，默认三个全选。用 ↑/↓ 或 `j`/`k` 移动，用 Space 切换，`a` 全选、`n` 全不选，Enter 或 Ctrl-D/EOF 确认当前选择。若 `TERM` 为空或为 `dumb`，或 `stty` 不可用，则回退到编号方式：Enter、`all`、`a`、`y`、`yes` 表示全选；`none`、`n`、`no`、`0` 表示都不装；也可以混用编号和名称，例如 `1,3` 或 `serena codeburn`。自动化场景默认全选：

```bash
bash install.sh --tools=headroom   # 明确指定子集
bash install.sh --yes              # 三个全装，不提示
bash install.sh --skip-tools       # 都不装
```

在 Windows 上，`install.sh` 会在 npm 管理的 `codex`、`codex.cmd`、`codex.ps1` 垫片存在时对其打补丁，这样即使 `%APPDATA%\npm` 先于 `~/.codex/bin` 被解析，my-codex 的知识库管线仍有包装器兜底。

### 面向 AI Agent

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

由于复选框选择器只会在交互式终端中出现，代理会在运行安装程序之前询问要安装哪些配套工具（Serena、Headroom、codeburn）。

---

## 使用的开源工具

my-codex 所依托的每一个项目、它带来的能力，以及它的引入方式。只有这张表会描述各个项目，README 的其余部分只列清单、命令和版本锁定。

| # | 项目 | my-codex 取用的内容 | 引入方式 |
|---|------|---------------------|----------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 61 个白名单 Skill：技术栈模式（TypeScript、React、Python/Django/FastAPI、Spring Boot/Kotlin、SQL/Redis/Prisma、Docker/Kubernetes）、AI 与 Agent 工程，以及上手引导、代码导览、ADR 等通用代码库工具。Claude Code 专有内容已剥离，18 个 Web/UI Skill 车道不在默认安装中。 | 子模块 `upstream/ecc`；`install.sh` 只复制 `scripts/skill-allowlists.sh` 中列出的名称 |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 30 个冲刺流程 Skill 条目 —— 浏览器 QA（`qa`）、范围漂移代码评审（`review`）、安全审计（`cso`），以及完整的计划 → 评审 → 发布流程 —— 外加已编译的 Playwright 浏览器守护进程。 | 子模块 `upstream/gstack`，内置到 `~/.codex/vendor/gstack`，在那里用 bun 运行它自己的 `./setup --host codex`，并在 `~/.codex/skills/` 下创建 29 个符号链接，与 `gstack` 根路由器目录并列；被它取代的 7 个 ECC Skill（`benchmark`、`canary-watch`、`safety-guard`、`browser-qa`、`verification-loop`、`security-review`、`design-system`）会被移除，只保留 gstack 版本可路由 |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 7 个白名单工作型 Agent：`executor`、`planner`、`architect`、`test-engineer`、`security-reviewer`、`code-reviewer`、`debugger`。其余提示词与 Skill 与本仓库已有的 Agent 重复，因此刻意不安装。 | 子模块 `upstream/omx`；`scripts/md-to-toml.sh` 把白名单提示词从 Markdown 转换为 `~/.codex/agents/*.toml` |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 个开发流程 Skill：头脑风暴、系统化调试、测试驱动开发、计划编写与执行、worktree 操作、代码评审礼仪。不取用任何 Agent —— 它唯一的 `code-reviewer` 提示词与 oh-my-codex 的重叠。 | 子模块 `upstream/superpowers`；15 个 Skill 目录中，除与 Boss 委派路径重复的 `dispatching-parallel-agents` 外全部安装 |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | 1 个图表 Skill，把架构、工作流、时序、数据流和生命周期描述变成一个自包含 HTML 文件，内含内联 SVG、明暗主题切换以及 PNG/JPEG/WebP/SVG 导出。 | 子模块 `upstream/archify`，锁定在标签 `v2.9.0`，因此同步任务不会动它；只把仓库顶层的 `archify/` 目录复制到 `~/.codex/skills/archify`，安装时不会执行 `npx skills add` |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 17 个 Codex 原生 TOML Agent，以两个可选包 `data-ai`（13）和 `llmops`（4）提供。全新安装不会启用任何一个包。 | 以 MIT 归属内置到 `codex-agents/packs/` 并安装到 `~/.codex/agent-packs/`；子模块已于 2026-07-27 移除。用 `~/.codex/bin/my-codex-packs enable data-ai` 或 `install.sh --profile dev` 启用 |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 个 Agent —— `sisyphus`、`atlas`、`prometheus`、`oracle`、`metis`、`momus`、`hephaestus`、`librarian`、`multimodal-looker` —— 覆盖端到端编排、计划执行与评审、深度第二意见、有出处的库查询，以及读取媒体文件。 | 已适配为 Codex 原生 TOML 并在仓库内 `codex-agents/omo/` 下维护，因此无需上游检出即可安装 |
| 8 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 无。本仓库从未调用过这些包中的 Agent，因此没有内置任何内容。 | 已移除（MIT）—— 子模块于 2026-07-27 下线，记录仍保留在 `upstream/SOURCES.json` |
| 9 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 以原生 Claude `.md` Agent 格式提供同样的 Boss 编排，同时也是编辑基准：`scripts/skill-allowlists.sh` 原样沿用 my-claude 的 ECC、gstack、superpowers 列表，使两个框架暴露相同的上游面。 | 仅作为姐妹项目链接 —— `install.sh` 不会克隆、下载或复制其中任何内容，因此没有内置内容，也没有需要跟踪的锁定版本。并存安装时，两个安装脚本通过同一个用户级锁和状态目录协调 codeburn 与 Headroom，而不是争抢固定端口 |
| 10 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | 本地优先的 token 与成本统计，直接读取 Codex 本就写入 `~/.codex/sessions` 的会话文件，无代理、无 API Key、无 Codex 钩子。 | `npm i -g codeburn@0.9.23`；`install.sh` 启动或复用一个共享的 `codeburn web --provider all --port 4747 --no-open` 进程 |
| 11 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | 基于语法树而非原始文本匹配的结构化搜索与改写，让 Agent 不依赖脆弱的正则表达式也能改变代码形态。 | `npm i -g @ast-grep/cli@0.42.0`；若 `PATH` 中已有 `ast-grep` 二进制则跳过 |
| 12 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | 通过 MCP 提供语言服务器的符号图 —— `get_symbols_overview`、`find_symbol`、`find_referencing_symbols`、`replace_symbol_body`、`insert_after_symbol` —— 使 token 消耗随符号而非整个文件增长。发行包整体为 GPL-3.0-or-later（PyPI 的 MIT 元数据不准确），因此不内置任何代码。 | `uv tool install --python 3.13 serena-agent==1.7.0`，注册为 `[mcp_servers.serena]`（stdio：`serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False`，`startup_timeout_sec = 15`） |
| 13 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | Apache-2.0 的 MCP 上下文压缩：`headroom_compress`、`headroom_retrieve`、`headroom_stats`。代理模式 `headroom wrap` 仍是有文档的手动可选项。 | `uv tool install --python 3.13 "headroom-ai[all]==0.37.0"`；由于该服务器不发布 MCP 注解，注册为带 `default_tools_approval_mode = "approve"` 的 `[mcp_servers.headroom]`（`headroom mcp serve`）；安装脚本在 8787 端口启动或复用共享的 `agent-harness-shared` 配置，且从不设置 `ANTHROPIC_BASE_URL` 或 `OPENAI_BASE_URL` |
| 14 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | 用最新的上游文档而非模型记忆来回答库、框架和 SDK 的问题。它是 `documentation-lookup` Skill 所指向的后端。 | 托管 MCP 服务器 `https://mcp.context7.com/mcp` |
| 15 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | 神经网络网页搜索。注册 URL 只启用 `web_search_exa`，把调研路径收敛到单一工具而非 Exa 的全部能力。 | 托管 MCP 服务器 `https://mcp.exa.ai/mcp?tools=web_search_exa` |
| 16 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | 跨公开 GitHub 仓库的代码搜索，让 Agent 在写代码前先看到多个仓库中真实的调用位置。 | 托管 MCP 服务器 `https://mcp.grep.app` |

---

## Boss 的工作原理

Boss 是 my-codex 核心的元编排器。它从不写代码 —— 它负责发现、分类、匹配、委派和验证。Codex 主会话通过安装好的 `AGENTS.md` 承担 Boss 角色，因此会直接委派给专家，而不是先再起一个 Boss。它的原生会话身份仍是 Codex/root；重新安装会刷新受管指令，同时保留自定义段落。

| 阶段 | 行为 |
|-------|--------------|
| **0 · 发现** | 运行时扫描 `~/.codex/agents/*.toml`，构建实时能力注册表 |
| **1 · 意图闸门** | 对请求分类（trivial、build、refactor、mid-sized、architecture、research 等），若有更合适的 Skill 则反向建议 |
| **2 · 能力匹配** | 依次走下面的优先级链（P1 精确 Skill → P2 专家 Agent → P3 多 Agent 编排 → P4 通用兜底） |
| **3 · 委派** | 以 6 段式结构化提示词调用 `spawn_agent`：TASK / OUTCOME / TOOLS / DO / DON'T / CTX |
| **4 · 验证** | 独立读取变更文件，运行测试、lint 和构建，与原始意图交叉核对，失败最多重试 3 次 |

### 优先级路由

Boss 会把每个请求沿优先级链依次处理，直到找到最合适的匹配：

| 优先级 | 匹配类型 | 条件 | 示例 |
|:--------:|-----------|------|---------|
| **P1** | Skill 匹配 | 任务对应一个自包含 Skill | `"review this diff"` → /review Skill |
| **P2** | 专家 Agent | 存在领域专属 Agent | `"security audit"` → security-reviewer |
| **P3a** | Boss 直接处理 | 2~4 个独立 Agent | `"fix 3 bugs"` → 并行派生 |
| **P3b** | 子编排器 | 复杂多步工作流 | `"refactor + test"` → Sisyphus |
| **P4** | 兜底 | 没有匹配的专家 | `"explain this"` → 通用 Agent |

### 模型路由

| 复杂度 | 模型 | 适用对象 |
|-----------|-------|----------|
| 顶层编排 | `gpt-6-astra` | Boss |
| 深度分析、架构、评审 | `gpt-6-astra` | Oracle、Prometheus、Sisyphus、Hephaestus、Atlas、Metis、Momus、architect、planner、code-reviewer、security-reviewer |
| 标准实现 | `gpt-5.6-sol` | Librarian、Multimodal-Looker、executor、test-engineer、debugger，以及 17 个包 Agent 中的 15 个 |
| 快速查询、轻量分析 | `gpt-5.6-terra` | data-analyst、prompt-regression-tester |

三个层级的模型 ID 只存在于单一文件 `scripts/model-tiers.sh`；`scripts/md-to-toml.sh` 和 `install.sh` 都会引用它，若脚本中其他地方硬编码了模型 ID，`scripts/check-model-drift.sh` 会让构建失败。

### 推理强度层级

模型选择决定由*哪个*大脑执行任务，而同一个 TOML 中紧挨 `model` 的 `model_reasoning_effort` 决定它*思考多深*。Boss 和 9 个 OMO Agent 在 `codex-agents/` 下已提交的文件中直接声明，7 个 oh-my-codex 工作型 Agent 在转换时从 `scripts/md-to-toml.sh` 的角色表取值，而包 Agent 各自携带自己的取值：

| 推理强度 | Agent |
|--------|--------|
| `xhigh` | Boss、Oracle、Prometheus、architect |
| `high` | Sisyphus、Hephaestus、Atlas、Metis、Momus、planner、code-reviewer、security-reviewer，以及 17 个包 Agent 中的 15 个 |
| `medium` | Librarian、Multimodal-Looker、executor、test-engineer、debugger、data-analyst、prompt-regression-tester |

### 三阶段冲刺工作流

对于端到端的功能实现，Boss 会编排一个结构化冲刺：

| 阶段 | 模式 | 行为 |
|-------|------|--------------|
| **1 · 设计** | 交互式 | 用户确定范围 · 工程评审 · 确认「设计完成」 |
| **2 · 执行** | 自主 | executor 执行任务 · 自动代码评审 · architect 验证 |
| **3 · 评审** | 交互式 | 与设计文档对照 · 给出对比表 · 用户批准或要求改进 |

### 结构化最终报告

Boss 会为每个有实际工作的回合 —— 编辑了文件、产生提交/PR、改动配置或运行了验证的回合 —— 收尾一份无需打开 diff 即可通读的结构化最终报告。报告由固定的 5 张表组成，每张表只在对应情况真实发生时才输出（绝不输出空表）：

| 情况 | 表 | 列 |
|-----------|-------|---------|
| 文件/配置变更 | Changes | 对象 / Before / After / 理由 |
| 完成多项任务 | Work summary | 条目 / 结果 / 证据 |
| 运行了验证 | Verification | 条目 / 期望 / 实际 / 判定 |
| 产生提交/PR | Deliverables | PR / 仓库 / 内容 / 状态 |
| 仍有未决事项 | Remaining | 条目 / 状态 / 下一步 |

它只在请求的最末尾触发 —— 绝不出现在启动或转达后台工作的回合，也不作为任务中途的进度汇报 —— 纯问答回合正常结束、不带报告。规范同时写在 `boss.toml` 的 developer instructions 和 `~/.codex/AGENTS.md` 中，因此主会话也能看到。一个 Stop 钩子（`hooks/stop-final-report.js`）负责强制执行：当某回合改变了状态却没有输出报告表时，钩子会拦截该回合一次并要求补上报告。

---

## 内容一览

| 类别 | 数量 | 来源 |
|----------|------:|--------|
| **核心 Agent**（始终加载） | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Agent 包**（可选，默认全部不启用） | 17 | 2 个内置类别：data-ai 13 + llmops 4 |
| **暴露的 Skill**（默认 `core` 配置） | 30 | 始终开启的集合；其余只需一个车道参数即可加入 |
| **已安装的 Skill**（`~/.codex/skills/` 下的条目） | 110 | ECC 61 · gstack 30 · Superpowers 14 · Core 4 · archify 1 |
| **MCP 服务器** | 5 | Context7、Exa、grep.app、Serena、Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

以上所有 Agent 和 Skill 都列在 [`scripts/skill-allowlists.sh`](../../scripts/skill-allowlists.sh) 的白名单中，该文件是「装什么」的唯一依据。本捆绑包本身不提供 `pdf`、`docx`、`pptx`、`xlsx`；外部安装的同类 Skill 会被原样保留。

<details>
<summary><strong>核心 Agent —— Boss 元编排器 (1)</strong></summary>

| Agent | 模型 | 职责 | 来源 |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | 动态运行时发现 → 能力匹配 → 最优路由。从不写代码。 | my-codex |

</details>

<details>
<summary><strong>OMO Agent —— 子编排器与专家 (9)</strong></summary>

| Agent | 模型 | 职责 | 来源 |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | 意图分类 → 专家委派 → 验证 | oh-my-openagent |
| Hephaestus | gpt-6-astra high | 自主探索 → 计划 → 执行 → 验证 | oh-my-openagent |
| Atlas | gpt-6-astra high | 任务拆解 + 四阶段 QA 验证 | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | 战略技术咨询（只读） | oh-my-openagent |
| Metis | gpt-6-astra high | 意图分析、歧义检测 | oh-my-openagent |
| Momus | gpt-6-astra high | 计划可行性评审 | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | 基于访谈的详细规划 | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | 通过 MCP 检索开源文档 | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | 图片/截图/图表分析 | oh-my-openagent |

</details>

<details>
<summary><strong>OMX Agent —— 专家工作者 (7)</strong></summary>

| Agent | 沙箱 | 职责 | 来源 |
|-------|---------|------|--------|
| executor | workspace-write | 代码实现 | oh-my-codex |
| planner | read-only | 实现规划 | oh-my-codex |
| architect | read-only | 系统设计与架构 | oh-my-codex |
| test-engineer | workspace-write | 测试策略与覆盖率 | oh-my-codex |
| security-reviewer | read-only | 安全分析 | oh-my-codex |
| code-reviewer | read-only | 聚焦式代码评审 | oh-my-codex |
| debugger | workspace-write | 根因分析 | oh-my-codex |

</details>

<details>
<summary><strong>Agent 包 —— 可选 AI 专家 (2 个包，17 个 Agent)</strong></summary>

| 包 | 数量 | Agent |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

安装到 `~/.codex/agent-packs/`，在你主动启用之前保持关闭 —— 见 [Agent 包配置](#agent-包配置)。

</details>

<details>
<summary><strong>Skill —— 默认暴露 30 个，来自 5 个来源共安装 110 个</strong></summary>

| 来源 | 已安装 | 主要 Skill |
|--------|------:|------------|
| everything-claude-code | 61 | coding-standards, python-testing, api-design, deep-research |
| gstack | 30 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| superpowers | 14 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| archify | 1 | archify（架构 / 工作流 / 时序 / 数据流 / 生命周期图） |

gstack 的条目是 `gstack` 根路由器目录，加上指向 `~/.codex/vendor/gstack/.agents/skills/` 的 29 个符号链接。这些链接由 gstack 自己的 `./setup` 创建：`GSTACK_SKILL_ALLOWLIST` 中的 26 个，再加上它始终安装的另外 3 个（`gstack-upgrade`、`hackernews-frontpage`、`codex`）。29 个全部在受管目录中，因此没有「仅链接」的条目，每个都可以由 `core` 或某条车道暴露。110 个条目中 81 个是真实目录、29 个是上述符号链接；`find ~/.codex/skills -name SKILL.md | wc -l` 在没有 `-L` 时不会跟随链接，因此返回 83。无论启用哪个配置，Skill 文件都保持安装状态，变化的只是暴露范围。参见 [Skill 配置与车道](#skill-配置与车道)。

</details>

<details>
<summary><strong>托管 MCP 服务器（5 个中的 3 个）</strong></summary>

另外两个是 Serena 和 Headroom，二者都是本地 stdio 服务器。

| 服务器 | 用途 | 费用 |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | 实时库文档 | 免费 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | 语义网页搜索 | 每月 1000 次免费 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | GitHub 代码搜索 | 免费 |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

与 Obsidian 兼容的持久化记忆。每个项目都会维护一个 `.briefing/` 目录，它在 Codex 会话期间由原生插件钩子更新，会话起止的连续性由包装器兜底：

```
.briefing/
├── INDEX.md                          ← 项目上下文（首次自动创建）
├── state.json                        ← 会话元数据、计数器、lastVaultSync（自动维护）
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← 人类/Agent 撰写的后续会话小结
│   └── YYYY-MM-DD-auto.md           ← 自动生成脚手架（记录的文件、过滤后的状态、后续事项）
├── decisions/
│   └── YYYY-MM-DD-<decision>.md     ← 人类/Agent 撰写的决策记录
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← 人类/Agent 撰写的经验笔记
│   └── YYYY-MM-DD-auto-session.md   ← 自动生成脚手架（文件、包装器活动、提示）
├── references/
│   └── auto-links.md                ← 预留给收集到的调研链接
├── archives/                         ← PARA：已完成/不活跃笔记（平铺）
├── wiki/                             ← LLM-wiki：概念页面
│   └── _schema.md
├── agents/
│   ├── agent-log.jsonl              ← 包装器/会话日志
│   └── YYYY-MM-DD-summary.md        ← 每日信号汇总
└── persona/
    ├── profile.md                   ← 由记录信号得出的路由/画像小结
    ├── suggestions.jsonl            ← 路由建议（自动生成）
    ├── persona-policy.json          ← Boss 已接受的软路由偏好
    └── rules/                       ← 工作流模式规则（workflow-*.md）
```

### 知识管理 (v2)

BriefingVault v2 融合了三种知识管理方法论：

| 方法论 | 应用方式 |
|------------|-----------|
| **PARA**（Tiago Forte） | 目录结构：sessions=项目，decisions=领域，references=资源，archives=归档 |
| **Zettelkasten**（Luhmann） | `learnings/` 中的原子笔记、唯一 ID（`YYYYMMDDHHMMSS`）、强制 `[[wiki-links]]` |
| **LLM-wiki**（Karpathy） | `wiki/` 中的概念页面 —— 关键词出现 3 次以上即自动建议 |

Codex CLI 的会话结束钩子会自动：

- 建议归档超过 30 天的笔记
- 为高频概念提议 wiki 页面
- 为新笔记生成唯一的 Zettelkasten ID

### 会话专属差异

会话开始时，my-codex 会保存当前 git HEAD 以及工作树状态快照。会话期间，原生 Codex 钩子会在提示、编辑、搜索和子 Agent 完成后刷新 `.briefing` 脚手架。会话结束时，最终脚手架只针对记录到的路径汇总 diff 与状态，并过滤钩子自身产生的噪声，例如 `.briefing/` 产物和会话开始时的 `.gitignore` 修改。

这让脚手架聚焦于本次会话真正做的事，而不是倾倒整个仓库的状态。对于非 git 项目，回退使用 `YYYY-MM-DD:cwd` 标识。

### 与 Obsidian 配合使用

1. 打开 Obsidian → **将文件夹作为仓库打开** → 选择 `.briefing/`
2. 笔记会出现在图谱视图中，通过 `[[wiki-links]]` 相连
3. YAML 前置元数据（`date`、`type`、`tags`）支持结构化检索
4. 会话与经验的时间线脚手架会自动积累；后续小结、决策和经验笔记则随你书写而沉淀

### /boss-briefing

在会话中或收尾时运行 `/boss-briefing` 可以：

- **同步知识库**：更新 profile.md、INDEX.md 和 Agent 汇总
- **识别工作流模式**：分析跨会话的时序 Agent 调用序列
- **弥补中断**：若距上次会话已过去数天，生成恢复性小结
- **提议画像规则**：给出基于工作流（而不仅是频率）的路由偏好
- **校验会话笔记**：检查今天的会话是否已有像样的小结

Stop 钩子会检查今天是否运行过 `/boss-briefing`。若没有，它会以提醒的形式拦截会话结束。既有的 `stop-profile-update.js` 继续作为兜底运行。

### 子知识库

| 路径 | 说明 |
|------|-------------|
| `INDEX.md` | 项目概览，链接到近期的决策与经验。首次会话自动创建，并定期刷新。 |
| `sessions/` | **会话小结。** `*-auto.md` —— 会话期间刷新、结束时依据记录的会话文件、过滤后的状态和信号定稿的自动脚手架。`<topic>.md` —— 由知识库提醒促成、人类或 Agent 撰写的后续小结。 |
| `decisions/` | **架构与设计决策**及其理由。值得留存的决定请写成持久笔记。 |
| `learnings/` | **模式、坑点、非显而易见的解法。** `*-auto-session.md` —— 会话期间用本次记录的文件清单、信号和后续提示刷新的自动脚手架。`<topic>.md` —— 人类或 Agent 撰写的经验笔记。 |
| `references/` | **网页调研 URL。** 当原生 Codex 钩子可用时，`references/auto-links.md` 会依据 `WebSearch`/`WebFetch` 的钩子活动更新。 |
| `agents/` | **记录的会话信号。** `agent-log.jsonl` —— 含 `{ts, agent_id, agent_type, phase, seq, task_hint}` 的条目。`YYYY-MM-DD-summary.md` —— 由该日志得出的每日汇总。 |
| `persona/` | **用户工作风格画像。** `profile.md` —— 由记录信号得出的路由/画像小结。`suggestions.jsonl` —— 路由建议。`persona-policy.json` —— 已接受的软路由偏好。`rules/workflow-*.md` —— 由 `/boss-briefing` 提议的工作流序列规则。 |
| `state.json` | 会话元数据：计数器、lastVaultSync、sessionStartHead。由钩子自动维护。 |
| `archives/` | PARA 归档 —— 已完成会话（30 天以上）、被取代的决策、不活跃的经验 |
| `wiki/` | LLM-wiki 概念页面 —— 从多次会话中提炼的知识 |

### 行为钩子

| 钩子 | 事件 | 行为 |
|------|-------|----------|
| Session Setup | SessionStart | 自动检测工具 + 注入 Briefing Vault 上下文 |
| Delegation Guard | PreToolUse | 提醒处于 Boss 模式的会话把文件修改委派出去，而不是自己直接改 |
| Agent Telemetry | PostToolUse | 把 Agent 使用情况记录到 `~/.gstack/analytics/agent-usage.jsonl` |
| Vault Enforcer | PostToolUse | 统计编辑次数并在会话中刷新自动脚手架 |
| Link Collector | PostToolUse | 把 `WebSearch`/`WebFetch` 结果追加到 `references/auto-links.md` |
| Subagent Logger | SubagentStop | 把 Agent 执行记录到 Briefing Vault |
| Vault Reminder | UserPromptSubmit | 消息达到 5 条以上时建议 /boss-briefing；记录到足够工作量后建议写真正的会话笔记 |
| Context Budget | UserPromptSubmit | 自上次压缩起每 40 条提示（`MY_CODEX_COMPACT_EVERY`）建议在下一个任务边界运行 `/compact` |
| Context Budget reset | PostCompact | 压缩后把该计数器清零 |
| Completion Check | Stop | 执行画像兜底 + 检查 /boss-briefing |
| Final Report Gate | Stop | 若有实际工作却没有最终报告表，拦截该回合一次 |

只有当 `features.hooks = true` 时，Codex 才会从 `~/.codex/hooks.json` 加载这些钩子，因此 `install.sh` 会把文件写到该路径，并在 `config.toml` 的 `[features]` 下设置该标志。下一次交互式启动 Codex 时会询问一次是否审阅并信任这些钩子 —— 请选择「Trust all and continue」。在此之前，任何钩子都不会运行。

---

## 在哪里查看结果

每个已安装的工具都会把输出写到某处。这里就是那些位置。

| 工具 | 打开 | 运行方式 | 查看位置 |
|------|------|------------|----------------------|
| **codeburn** | <http://127.0.0.1:4747/> | 安装脚本会启动 `codeburn web --provider all --port 4747 --no-open`；`codeburn` 打开交互式面板；非交互可用 `codeburn report --format json --period week --provider codex`（也支持 `--day`、`--from`/`--to`） | 共享浏览器面板、终端 TUI，或 stdout 上的 JSON。会话文件只读，金额是按公开价目表估算的结果，不是账单。 |
| **Serena** | <http://localhost:24282/dashboard/index.html> | 由 Codex 依据 `[mcp_servers.serena]` 启动；工具呈现为 `get_symbols_overview`、`find_symbol`、`find_referencing_symbols`、`replace_symbol_body`、`insert_after_symbol` | 服务器运行期间可查看面板和工具调用统计。按项目的索引与记忆位于 `<repo>/.serena/`；浏览器不会自动打开（`--open-web-dashboard False`）。 |
| **Headroom** | <http://127.0.0.1:8787/stats> | Codex 依据 `[mcp_servers.headroom]`（`headroom mcp serve`）启动 MCP 服务器；安装脚本应用共享配置 `agent-harness-shared`（命令见下） | 代理统计，在用 `headroom wrap` 或 base URL 显式路由客户端之前一直为空。 |
| **Archify** | `<output>.html` | 在 `~/.codex/skills/archify` 中运行 `node bin/archify.mjs render <type> <input>.json <output>.html`，然后 `node bin/archify.mjs check <output>.html` | 你指定的文件 —— 用任意浏览器打开即可。Skill 自带的 `examples/*.json` 是可直接照抄的输入示例。 |

安装脚本用下面的命令应用 Headroom 服务配置：

```bash
headroom install apply --profile agent-harness-shared --preset persistent-service \
  --runtime python --providers manual --port 8787 --no-telemetry \
  --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1
```

---

## GitHub Actions

| 工作流 | 触发 | 目的 |
|----------|---------|---------|
| **CI** | push, PR | 校验 TOML Agent 文件、Skill 是否存在、上游文件数量 |
| **Smoke Tests** | push, PR | `hooks`、`shell`、`drift`、`routing-refs` 作业 —— 钩子接线、Shell 语法、模型漂移、AGENTS.md 路由引用 |
| **Update Upstream** | 每 3 天 / 手动 | 对 4 个跟踪分支的子模块执行带安全闸门的 `git submodule update --remote`，刷新 `upstream/SOURCES.json` 的锁定版本，并创建自动合并 PR |
| **Auto Tag** | 推送到 main | 从 `config.toml` 读取版本号，若为新版本则创建 git 标签 |
| **Pages** | 推送到 main | 将 `docs/index.html` 部署到 GitHub Pages |
| **CLA** | PR | 贡献者许可协议检查 |
| **Lint Workflows** | push, PR | 校验 GitHub Actions 工作流 YAML 语法 |

---

## my-codex 原创功能

在上游提供的能力之外，专为本项目构建的特性：

| 特性 | 说明 |
|---------|-------------|
| **Boss 元编排器** | 动态能力发现 → 意图分类 → 四级优先路由 → 委派 → 验证 |
| **三阶段冲刺** | 设计（交互式）→ 执行（通过 executor 自主）→ 评审（与设计文档交互式对照） |
| **Agent 层级优先** | core > omo > omx > 可选包 的去重顺序。若包内 Agent 与已安装 Agent 重名则跳过。最专精的 Agent 胜出。 |
| **成本优化** | 由单一文件（`scripts/model-tiers.sh`）管理的三档模型，应用于安装脚本提供的全部 34 个 Agent |
| **Skill 暴露配置** | 一份 210 条目的目录，默认暴露 30 条、13 条可选车道，并支持快照与回滚 —— 让 Skill 预算花在这次会话真正需要的地方 |
| **简报信号** | 包装器/会话日志填充 `.briefing/agents/agent-log.jsonl`、每日汇总以及路由/画像提示 |
| **Smart Packs** | 通过项目类型检测，在会话开始时推荐相关的 Agent 包 |
| **Agent 包系统** | 通过 `--profile` 和 `my-codex-packs` 助手按需启用领域专家 |
| **Codex 归属** | git 钩子记录 Codex 触碰过的文件，并在提交信息中追加 `AI-Contributed-By: Codex` |
| **CI 重复检测** | 在上游同步中自动检测重复的 TOML Agent |

---

## 捆绑的上游版本

通过 git 子模块链接。锁定的提交由 `.gitmodules` 原生跟踪，并以 AI-BOM 形式镜像到 [`upstream/SOURCES.json`](../../upstream/SOURCES.json)，该文件同时锁定 companion CLI 和 MCP 服务器的版本，并记录两个已移除的子模块；`install.sh` 会检出下面这些确切的 SHA，而不是跟踪 `main`。

| 来源 | SHA | 日期 | 差异 |
|--------|-----|------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `e482e57` | 2026-09-25 | [compare](https://github.com/affaan-m/everything-claude-code/compare/e482e57...HEAD) |
| [gstack](https://github.com/garrytan/gstack) | `730a101` | 2026-09-25 | [compare](https://github.com/garrytan/gstack/compare/730a101...HEAD) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | `cdc24a7` | 2026-09-22 | [compare](https://github.com/Yeachan-Heo/oh-my-codex/compare/cdc24a7...HEAD) |
| [superpowers](https://github.com/obra/superpowers) | `5bf4e78` | 2026-09-19 | [compare](https://github.com/obra/superpowers/compare/5bf4e78...HEAD) |
| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |

---

## 安装选项

重复运行同一条命令会更新到最新的 `main` 构建，只替换 `~/.codex/` 中由 my-codex 管理的文件，并清除 `~/.agents/skills/` 下过时的 Skill 副本。

### Skill 配置与车道

my-claude 安装一份固定白名单；my-codex 则先安装 110 个 Skill 条目，再控制其中有多少真正呈现给 Codex。Codex 在超出 Skill 预算后会截断 Skill 描述，因此一份没有重点的目录会让每条描述都变得不那么有用。当所有捆绑 Skill 来源都被选中时，全新安装的默认配置 `core` 暴露 30 个 Skill，各车道在其之上叠加：

| 配置 / 车道 | 新增内容 | 数量 | 启用方式 |
|----------------|--------------|------:|---------------|
| `core` | 始终开启的集合：my-codex 核心 Skill、superpowers 开发流程车道、gstack 发布/QA/评审路由器，以及 ECC 规范 | 30 | 默认；用 `--skill-profile=core` 回到该配置 |
| `legacy` | 迁移前的暴露范围；当 `--skip-ecc`、`--skip-gstack`、`--skip-superpowers` 或 `--skip-archify` 省略了某个核心来源且未显式指定配置时自动选用 | 视情况 | `--skill-profile=legacy` |
| `full` | 一次启用全部车道 —— 已安装的全部 110 个条目；目录共收录 210 个名称，尚未安装的会按需补齐。可能超出上下文预算 | 110 | `--skill-profile=full` 或 `--full-skills` |
| `workflow-advanced` | 进阶规划、仓库操作与 worktree 工作流 | 13 | `--skills=workflow-advanced` |
| `qa-operations` | QA、浏览器检查、发布、部署与运维安全 | 20 | `--skills=qa-operations` |
| `ai-engineering` | Agent 系统、评估、提示词、检索与 MCP | 18 | `--skills=ai-engineering` |
| `backend-data` | 后端架构、数据库、缓存、容器与 API | 13 | `--skills=backend-data` |
| `python` | Python、Django、FastAPI 的实现与测试 | 9 | `--skills=python` |
| `jvm` | Java、Kotlin、JPA、Spring 的实现与测试 | 11 | `--skills=jvm` |
| `web` | Web 框架、无障碍、性能与端到端测试 | 18 | `--skills=web` |
| `mobile` | Android、Flutter、Swift、SwiftUI 工程 | 9 | `--skills=mobile` |
| `other-languages` | C++、Go、Laravel、Perl、Rust 工程 | 13 | `--skills=other-languages` |
| `research-content` | 调研、技术内容、市场工作与对外沟通 | 11 | `--skills=research-content` |
| `media-documents` | 媒体生成、文档处理、OCR 与翻译 | 7 | `--skills=media-documents` |
| `business-domains` | 物流、质量、生产、采购与贸易 | 8 | `--skills=business-domains` |
| `alternative-workflows` | 可选的编排、TDD、评审与验证体系 | 30 | `--skills=alternative-workflows` |

所选结果保存在 `~/.codex/my-codex/skill-catalog-state.json`，兼容记录写入 `~/.codex/enabled-skill-lanes.txt`，因此之后直接运行 `bash install.sh` 也会保留；`MY_CODEX_SKILLS=web` 等同于 `--skills=web`，没有状态的既有非交互安装会维持当前暴露范围。切换配置不会删除任何实际的 Skill 文件 —— 可选条目通过 Codex 支持的按路径 Skill 配置隐藏，未知 Skill 以及 `~/.agents/skills/` 和 `~/.claude/skills/` 下的文件都不会被触碰。

安装完成后，用 `my-codex-skills` CLI 管理暴露范围：

```bash
my-codex-skills list                     # 所有目录条目及其车道
my-codex-skills status                   # 当前配置与已启用车道
my-codex-skills doctor                   # 报告目录/状态漂移
my-codex-skills enable python web        # 增加车道
my-codex-skills disable web              # 移除车道
my-codex-skills set-profile core         # core | legacy | full
my-codex-skills source benchmark gstack  # 当两个来源提供同名 Skill 时选择其一
my-codex-skills restore latest           # 回滚到快照
```

目录文件是 `~/.codex/lib/my-codex/skill-catalog.json`，快照位于 `~/.codex/my-codex/skill-catalog-snapshots/<id>.json`。启用车道时可能会从锁定的本地 vendor 补齐缺失内容；若无法获取，状态与配置保持不变，CLI 会引导你运行 `install.sh --skills=<lane>`。

### Agent 包配置

这些包会被安装，但**默认不启用** —— 全新安装不会启用任何包，并把空集合记录到 `~/.codex/enabled-agent-packs.txt`。可以按包启用，也可以选择一个 profile：

```bash
# 查看当前状态
~/.codex/bin/my-codex-packs status
# 立即启用某个包
~/.codex/bin/my-codex-packs enable data-ai
# 最小 profile（仅核心 Agent，无包 —— 默认）
bash /tmp/my-codex/install.sh --profile minimal
# dev profile（data-ai + llmops）
bash /tmp/my-codex/install.sh --profile dev
# 完整 profile（启用已安装的全部 2 个包类别）
bash /tmp/my-codex/install.sh --profile full
```

### Codex 归属系统

`install.sh` 会安装一个 `codex` 包装器，以及位于 `~/.codex/git-hooks/` 的全局 git 钩子：

- **`prepare-commit-msg`** —— 记录真实 Codex 会话期间变更的文件
- **`commit-msg`** —— 当暂存文件与记录的变更集合有交集时，追加 `Generated with Codex CLI: https://github.com/openai/codex`
- **`post-commit`** —— 为符合条件的提交添加 `AI-Contributed-By: Codex` 尾注

可选的 `Co-authored-by` 尾注：同时设置 `git config --global my-codex.codexContributorName '<label>'` 和 `my-codex.codexContributorEmail '<github-linked-email>'`。完全关闭：`git config --global my-codex.codexAttribution false`。my-codex **不会**修改 `git user.name`、`git user.email` 或提交作者身份。

### Agent TOML 格式

每个 Agent 都是 `~/.codex/agents/` 下的原生 TOML 文件：

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

- `max_threads` —— 子 Agent 的最大并发数
- `max_depth` —— Agent 派生 Agent 链条的最大嵌套深度

---

## 常见问题

<details>
<summary><strong>my-codex 和 my-claude 有什么不同？</strong></summary>

Boss 编排相同，运行时不同。my-codex 面向 OpenAI Codex CLI，使用原生 `.toml` Agent 格式和 `spawn_agent` 委派；my-claude 面向 Claude Code，使用 `.md` Agent 格式和 Agent 工具。此外 my-codex 通过配置与车道控制 Skill 暴露，而 my-claude 安装一份固定白名单。

</details>

<details>
<summary><strong>可以同时使用 my-codex 和 my-claude 吗？</strong></summary>

可以。它们安装到不同目录（`~/.codex/` 和 `~/.claude/`）。两个安装脚本通过 `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services` 下的用户级锁和状态目录协调 codeburn 与 Headroom：健康的服务会被复用，占用固定端口的外部进程只会被报告而不会被终止。

</details>

<details>
<summary><strong>Agent 包是怎么工作的？</strong></summary>

参见 [Agent 包配置](#agent-包配置)。

</details>

<details>
<summary><strong>上游同步是怎么进行的？</strong></summary>

参见 [GitHub Actions](#github-actions) 中的 **Update Upstream** 一行。`upstream/archify` 是标签锁定、只在需要时手动提升，因此该作业只处理其余 4 个子模块；你也可以在 Actions 选项卡手动触发。

</details>

<details>
<summary><strong>my-codex 使用哪些模型？</strong></summary>

参见[模型路由](#模型路由)和[推理强度层级](#推理强度层级)。Skill 直接沿用 SKILL.md 标准、不做任何转换，只有 Agent 会被转换为 Codex TOML，而该转换使用的模型层级由单一文件 `scripts/model-tiers.sh` 管理。

</details>

---

## 故障排查

### 仅恢复 Skills

如果某个工具报告 `~/.agents/skills/` 下的 `SKILL.md` 无效，最常见的原因是旧安装遗留的本地副本或失效的符号链接目标。删除 `~/.agents/skills/` 中相关目录以及 `~/.claude/skills/` 中对应条目，然后重新安装：

```bash
npx skills add sehoon787/my-codex -y -g
```

如果你使用完整的 Codex 捆绑包，请再运行一次 `install.sh`。完整安装脚本会刷新 `~/.codex/skills/`，并移除 `~/.agents/skills/` 下由 my-codex 管理的过时副本。

---

## 贡献

欢迎提交 Issue 和 PR。新增 Agent 时，请在 `codex-agents/core/` 或 `codex-agents/omo/` 添加一个 `.toml` 文件，并更新 `SETUP.md` 中的 Agent 列表。PR 校验步骤与 Codex 提交归属行为参见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 致谢

构建于[使用的开源工具](#使用的开源工具)中列出的项目之上；感谢每一位作者。同样感谢本框架所面向的运行时 [OpenAI Codex CLI](https://github.com/openai/codex)，以及提供 `npx skills` CLI、用于安装纯 Skill 捆绑包的 [openai/skills](https://github.com/openai/skills)。

## 许可证

MIT 许可证。详情参见 [LICENSE](../../LICENSE) 文件。
