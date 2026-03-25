[English](./README.md) | [한국어](./docs/i18n/README.ko.md) | [日本語](./docs/i18n/README.ja.md) | [中文](./docs/i18n/README.zh.md) | [Deutsch](./docs/i18n/README.de.md) | [Français](./docs/i18n/README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same agents as Claude Code plugin with Boss meta-orchestrator

> **If you are an LLM agent**, install directly with one command:
>
> macOS / Linux / WSL / Git Bash
> ```bash
> curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/bootstrap.sh | bash
> ```
> Windows PowerShell
> ```powershell
> irm https://raw.githubusercontent.com/sehoon787/my-codex/main/bootstrap.ps1 | iex
> ```
> `AI-INSTALL.md` remains available as the manual fallback and audit-friendly guide.

---

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-444-blue)
![Skills](https://img.shields.io/badge/skills-125-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)
![Codex Attribution](https://img.shields.io/badge/Codex_attribution-enabled-black)

All-in-one multi-agent orchestration for OpenAI Codex CLI — install once, get everything.

Bundles **444 installed agent files** (80 auto-loaded + 364 agent-packs) and **125 skills** from 4 upstream sources into native TOML format. The repo currently contains 589 TOML source definitions; install-time deduplication resolves overlapping destination filenames into the final installed footprint. Codex CLI auto-discovers agents via `spawn_agent` and routes tasks to the optimal specialist. GitHub Actions CI syncs upstream changes weekly.

Based on the official [Codex Subagents](https://developers.openai.com/codex/subagents) specification.

---

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Native TOML** | All agents in Codex CLI's native `.toml` format — no runtime conversion, no compatibility issues |
| **Multi-Source Curation** | 4 upstream sources aggregated, deduplicated, and quality-checked into a single collection |
| **Zero Configuration** | Install once, get 444 ready-to-use agent files. `config.toml` auto-configured with `multi_agent = true` |

## Quick Start

### If you are a human

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

> **Agent Packs**: Domain specialist agents (marketing, sales, gamedev, etc.) are installed to `~/.codex/agent-packs/` and can be activated by symlinking to `~/.codex/agents/` when needed.

### Skills only (cross-platform)

```bash
npx skills add sehoon787/my-codex -y -g
```

Installs 125 cross-tool skills to `~/.agents/skills/` with auto-symlinks to Codex CLI, Claude Code, Cursor, and other tools. Does **not** install agents, rules, or `config.toml` — use `install.sh` for the full 125-skill Codex bundle.

### If you are an LLM agent

Install directly with one command.

macOS / Linux / WSL / Git Bash

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/bootstrap.sh | bash
```

Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/sehoon787/my-codex/main/bootstrap.ps1 | iex
```

`AI-INSTALL.md` remains available as the manual fallback and audit-friendly guide.

---

## Key Features

### Multi-Agent Orchestration
- **spawn_agent**: Codex CLI auto-discovers agents from `~/.codex/agents/` and spawns them in parallel for complex tasks
- **send_input**: Parent-to-child agent communication for iterative workflows
- **Agent Packs**: Activate domain specialists on-demand via symlinks — no restart needed

### Model-Optimized Routing
- **o3 (high reasoning)**: Complex architecture, deep analysis — mapped from Claude Opus equivalents
- **o3 (medium)**: Standard implementation, code review — mapped from Claude Sonnet equivalents
- **o4-mini (low)**: Quick lookups, exploration — mapped from Claude Haiku equivalents

### All-in-One Bundle
- Install provides **444 installed agent files and 125 skills** instantly
- Bundles 4 upstream sources (agency-agents, everything-claude-code, oh-my-codex, awesome-codex-subagents)
- Weekly CI auto-sync keeps bundled content up-to-date with upstream
- MD-to-TOML conversion handled automatically for non-native sources
- Installs a default git attribution flow so commits touched by real Codex sessions automatically receive `AI-Contributed-By: Codex`

### Codex Attribution
- `install.sh` installs a `codex` wrapper plus global `commit-msg` and `post-commit` hooks in `~/.codex/git-hooks/`
- The wrapper records only files that changed during a real Codex session in the current git repository
- Codex-authored commits also get `🤖 Generated with [Codex CLI](https://github.com/openai/codex)` in the commit body
- The commit hook adds `AI-Contributed-By: Codex` only when staged files intersect that recorded change set
- To add a Claude-style `Co-authored-by:` trailer as well, set `git config --global my-codex.codexContributorEmail '<github-linked-email>'`
- Local git commits cannot summon GitHub's official `@codex` agent identity directly; GitHub only recognizes co-authors by linked email
- To disable attribution entirely, set `git config --global my-codex.codexAttribution false`

---

## Core Agents

37 core agents providing orchestration infrastructure are installed to `~/.codex/agents/`. These are the foundation agents that orchestrate, plan, review, and verify work. Domain specialists are in agent-packs. Awesome agents add additional coverage, but overlapping filenames collapse the final auto-loaded set to 80 installed files.

### Orchestrators (5)
boss, sisyphus, atlas, hephaestus, prometheus

### Advisors (5)
metis, momus, oracle, analyst, critic

### General Workers (6)
executor, explore, planner, verifier, tracer, debugger

### Orchestration Support (8)
agent-organizer, multi-agent-coordinator, workflow-orchestrator, error-coordinator, task-distributor, context-manager, agent-installer, knowledge-synthesizer

### Utility Workers (5)
writer, librarian, scientist, document-specialist, git-master

### Code Quality (5)
code-reviewer, code-simplifier, code-mapper, security-reviewer, architect

### Testing & Media (3)
test-engineer, qa-tester, multimodal-looker

---

## Agent Packs (Domain Specialists)

364 installed pack files across 21 categories are written to `~/.codex/agent-packs/` — **not** loaded by default. Those files come from `agent-packs/`, `agency/`, and non-core awesome categories after install-time deduplication. Activate a pack by symlinking:

```bash
# Activate a single pack
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# Deactivate
rm ~/.codex/agents/<agent-name>.toml
```

| Pack | Count | Examples |
|------|-------|---------|
| engineering | 32 | Backend, Frontend, Mobile, DevOps, AI, Data |
| marketing | 27 | Douyin, Xiaohongshu, WeChat OA, TikTok, SEO |
| language-specialists | 27 | Python, Go, Rust, Swift, Kotlin, Java |
| specialized | 31 | Legal, Finance, Healthcare, Workflow |
| game-development | 20 | Unity, Unreal, Godot, Roblox, Blender |
| infrastructure | 19 | Cloud, K8s, Terraform, Docker, SRE |
| developer-experience | 13 | MCP Builder, LSP, Terminal, Rapid Prototyper |
| data-ai | 13 | Data Engineer, ML, Database, ClickHouse |
| specialized-domains | 12 | Supply Chain, Logistics, E-Commerce |
| design | 11 | Brand, UI, UX, Visual Storytelling |
| business-product | 11 | Product Manager, Growth, Analytics |
| testing | 11 | API, Accessibility, Performance, E2E, QA |
| sales | 8 | Deal strategy, pipeline, outbound |
| paid-media | 7 | Google Ads, Meta Ads, Programmatic |
| research-analysis | 7 | Trend, Market, Competitive Analysis |
| project-management | 6 | Agile, Jira, workflows |
| spatial-computing | 6 | XR, WebXR, AR/VR, visionOS |
| support | 6 | Customer support, developer advocacy |
| academic | 5 | Study abroad, corporate training |
| product | 5 | Product management, UX research |
| security | 5 | Penetration testing, compliance, audit |

---

## Installed Components

| Category | Count | Source | Location |
|------|------|------|------|
| Auto-loaded Agents | 80 installed files | `core/`, `omo/`, `omc/`, `awesome-core/`, awesome core categories | `~/.codex/agents/` |
| Agent Packs | 364 installed files | `agent-packs/`, `agency/`, awesome non-core categories | `~/.codex/agent-packs/` |
| Skills | 125 | ECC | `~/.codex/skills/` |
| config.toml | 1 | my-codex | `~/.codex/config.toml` |
| AGENTS.md | 1 | my-codex | `~/.codex/AGENTS.md` |

The repository source inventory is larger than the install footprint because multiple upstreams ship the same destination filename. `install.sh` verifies the installed counts above, not the raw source totals.

<details>
<summary>Awesome Core Agents (52) — From awesome-codex-subagents</summary>

4 core categories installed to `~/.codex/agents/`:

**01-core-development (12)**
accessibility-tester, ad-security-reviewer, agent-installer, api-designer, code-documenter, code-reviewer, dependency-manager, full-stack-developer, monorepo-specialist, performance-optimizer, refactoring-specialist, tech-debt-analyzer

**03-infrastructure (16)**
azure-infra-engineer, cloud-architect, container-orchestrator, database-architect, disaster-recovery-planner, edge-computing-specialist, infrastructure-as-code, kubernetes-operator, load-balancer-specialist, message-queue-designer, microservices-architect, monitoring-specialist, network-engineer, serverless-architect, service-mesh-designer, storage-architect

**04-quality-security (16)**
api-security-tester, chaos-engineer, compliance-auditor, contract-tester, data-privacy-officer, e2e-test-architect, incident-responder, load-tester, mutation-tester, penetration-tester, regression-tester, security-scanner, soc-analyst, static-analyzer, threat-modeler, vulnerability-assessor

**09-meta-orchestration (10)**
agent-organizer, capability-assessor, conflict-resolver, context-manager, execution-planner, multi-agent-coordinator, priority-manager, resource-allocator, task-decomposer, workflow-orchestrator

</details>

<details>
<summary>Skills (125) — From Everything Claude Code</summary>

Key skills include:

| Skill | Description |
|-------|-------------|
| autopilot | Autonomous execution mode |
| tdd-workflow | Test-driven development enforcement |
| security-review | Security checklist and analysis |
| trace | Evidence-driven debugging |
| pdf | PDF reading, merging, splitting, OCR |
| docx | Word document creation and editing |
| pptx | PowerPoint creation and editing |
| xlsx | Excel file creation and editing |
| team | Multi-agent team orchestration |
| backend-patterns | Backend architecture patterns |
| frontend-patterns | React/Next.js patterns |
| postgres-patterns | PostgreSQL optimization |
| coding-standards | TypeScript/React coding standards |
| eval-harness | Evaluation-driven development |
| strategic-compact | Strategic context compression |
| iterative-retrieval | Incremental context retrieval |
| continuous-learning | Automatic pattern extraction from sessions |

</details>

---

## Full Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Request                          │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Codex CLI (spawn_agent / send_input / wait_agent)      │
│  Auto-discovers ~/.codex/agents/*.toml at runtime       │
│  Routes to optimal specialist based on task description │
└──┬──────────┬──────────┬──────────┬─────────────────────┘
   ↓          ↓          ↓          ↓
┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐
│Single│ │Parallel│ │Parent- │ │Config  │
│Agent │ │Spawn   │ │Child   │ │Control │
│      │ │(multi) │ │Comms   │ │        │
│spawn │ │spawn × │ │send_   │ │config. │
│_agent│ │N       │ │input   │ │toml    │
└──────┘ └────────┘ └────────┘ └────────┘
┌─────────────────────────────────────────────────────────┐
│  Agent Layer (444 installed TOML files)                  │
│    ├── Auto-loaded (80): final installed footprint       │
│    └── Agent Packs (364): final installed footprint      │
├─────────────────────────────────────────────────────────┤
│  Skills Layer (125 from ECC)                            │
│    ├── tdd-workflow, security-review, autopilot         │
│    └── pdf, docx, pptx, xlsx, team                     │
└─────────────────────────────────────────────────────────┘
```

---

## How Codex Multi-Agent Works

### Codex Subagents Specification

Codex CLI provides a native multi-agent protocol based on the [Codex Subagents](https://developers.openai.com/codex/subagents) specification. The protocol defines five core operations:

| Operation | Description |
|-----------|-------------|
| **spawn_agent** | Create a sub-agent with a specific role, model, and instructions |
| **send_input** | Send a message to a running sub-agent for iterative communication |
| **wait_agent** | Wait for a sub-agent to complete its work and return results |
| **close_agent** | Terminate a running sub-agent |
| **resume_agent** | Continue a paused sub-agent |

Codex CLI auto-discovers all `.toml` files in `~/.codex/agents/` at runtime. When a task requires specialist expertise, the CLI spawns the matching agent by name and passes it the relevant context.

### Agent TOML Format

Every agent is defined as a native TOML file:

```toml
name = "debugger"
description = "Focused debugging specialist"
model = "o3"
model_reasoning_effort = "medium"

[developer_instructions]
content = "You are a debugging specialist..."
```

Key fields:
- `name` — Agent identifier used by `spawn_agent`
- `description` — Used for capability matching
- `model` — OpenAI model to use (`o3`, `o4-mini`)
- `model_reasoning_effort` — Reasoning level (`high`, `medium`, `low`)
- `[developer_instructions].content` — The agent's system prompt

### Configuration (config.toml)

Global multi-agent settings are defined in `~/.codex/config.toml`:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — Maximum number of concurrent sub-agents
- `max_depth` — Maximum nesting depth for agent-spawns-agent chains

---

## Multi-Agent Usage Examples

### Single Agent Delegation

```
> Analyze the auth module for security vulnerabilities

Codex → spawn_agent("security-reviewer")
→ Agent analyzes src/auth/
→ Returns: 2 critical, 1 medium vulnerability
```

### Parallel Spawn

```
> Run a multi-agent pass: refactor auth, add tests, review security

Codex → spawn_agent("executor") × refactoring
      → spawn_agent("test-engineer") × test writing
      → spawn_agent("security-reviewer") × security audit
→ All 3 run in parallel (max_threads = 8)
→ Results collected and merged
```

### Parent-Child Communication

```
> Implement payment module, then have it reviewed

Codex → spawn_agent("executor")
      → executor completes implementation
      → send_input(executor, "review needed")
      → spawn_agent("code-reviewer")
      → code-reviewer reviews executor's changes
```

### Complex Orchestration

```
> Plan the migration, execute it, then verify

Codex → spawn_agent("planner")
      → planner produces migration plan
      → wait_agent(planner)
      → spawn_agent("executor") with plan as context
      → executor performs migration
      → wait_agent(executor)
      → spawn_agent("verifier")
      → verifier checks all migrations applied correctly
```

---

## Open-Source Tools Used

### 1. [Agency Agents](https://github.com/msitarzewski/agency-agents)

A library of 156 business specialist agent personas. Provides specialist perspectives across 14 categories — UX architects, data engineers, security auditors, and more. Converted from Markdown to native TOML via automated `md-to-toml.sh` pipeline.

### 2. [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)

A development framework originally built for Claude Code, providing 125 skills. 13 Claude Code-specific skills were removed; the remaining skills contain generic coding guidance usable across any LLM agent. The rules/ directory is included in the repo as reference material but is not read by Codex CLI.

### 3. [Awesome Codex Subagents](https://github.com/VoltAgent/awesome-codex-subagents)

136 production-grade agents in native TOML format. Already Codex-compatible — no conversion needed. Organized across 10 categories from core development to meta-orchestration.

### 4. [Oh My Codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex)

Codex CLI multi-agent orchestration framework by Yeachan Heo. A Rust/TypeScript runtime providing 36 skills, hooks, HUD, and team pipelines for Codex CLI. Referenced as architectural inspiration for my-codex's orchestration patterns. Does not provide agent TOML files directly.

### 5. [Oh My OpenAgent (omo)](https://github.com/code-yeongyu/oh-my-openagent)

A multi-platform agent harness by code-yeongyu. The 9 orchestration agents in this repository (atlas, hephaestus, metis, momus, oracle, prometheus, sisyphus, librarian, multimodal-looker) are adapted from omo agents, converted to Codex-native TOML format.

### 6. [OpenAI Official Skills](https://github.com/openai/skills)

The official Skills Catalog for Codex provided by OpenAI. Includes specialist skills for document processing, code generation, and development workflows. Can be installed via `$skill-installer` in Codex CLI.

---

## Contributing

Issues and PRs are welcome. When adding a new agent, add a `.toml` file to the `agents/` directory and update the agent list in `SETUP.md`.
See [CONTRIBUTING.md](./CONTRIBUTING.md) for PR validation steps and Codex commit attribution behavior.

---

## Bundled Upstream Versions

Updated weekly by CI auto-sync. No SOURCES.json yet — versions tracked via sync-upstream.yml.

| Source | Sync |
|--------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | Weekly CI |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | Weekly CI |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | Weekly CI |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | Weekly CI |

---

## Credits

This repository builds on the work of the following open-source projects:

- [agency-agents](https://github.com/msitarzewski/agency-agents) — msitarzewski
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — affaan-m
- [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) — Yeachan Heo
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) — code-yeongyu
- [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) — VoltAgent
- [openai/skills](https://github.com/openai/skills) — OpenAI
- [Codex Subagents Spec](https://developers.openai.com/codex/subagents) — OpenAI

---

## License

MIT License. See the [LICENSE](./LICENSE) file for details.
