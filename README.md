[English](./README.md) | [한국어](./docs/i18n/README.ko.md) | [日本語](./docs/i18n/README.ja.md) | [中文](./docs/i18n/README.zh.md) | [Deutsch](./docs/i18n/README.de.md) | [Français](./docs/i18n/README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same agents as Claude Code plugin with Boss meta-orchestrator

> **If you are an LLM agent**, run the installer entrypoint directly:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
> ```

---

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-444-blue)
![Skills](https://img.shields.io/badge/skills-133-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)
![Codex Attribution](https://img.shields.io/badge/Codex_attribution-enabled-black)

All-in-one agent harness for OpenAI Codex CLI — install once, get everything.

Bundles **444 installed agent files** (80 auto-loaded + 364 agent-packs) and **133 skills** from 6 upstream sources into native TOML format. The repo currently contains 589 TOML source definitions; install-time deduplication resolves overlapping destination filenames into the final installed footprint. Codex CLI auto-discovers agents via `spawn_agent` and routes tasks to the optimal specialist. GitHub Actions CI syncs upstream changes weekly.

Based on the official [Codex Subagents](https://developers.openai.com/codex/subagents) specification.

---

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Native TOML** | All agents in Codex CLI's native `.toml` format — no runtime conversion, no compatibility issues |
| **Multi-Source Curation** | 6 upstream sources aggregated, deduplicated, and quality-checked into a single collection |
| **Zero Configuration** | Install once, get the harness core plus a default developer specialist profile. `config.toml` auto-configured with `multi_agent = true` |

## 🎯 my-codex Originals

Features built on top of upstream sources — unique to my-codex:

| Feature | Description |
|---------|-------------|
| **Boss Meta-Orchestrator** | Dynamic capability discovery + intent-based routing to 400+ agents |
| **3-Phase Sprint** | Design(interactive) → Execute(autonomous) → Review(interactive) workflow |
| **Agent Tier Priority** | core > omo > omc > agency dedup resolution |
| **Agency Cost Optimization** | Auto-routes simple advisory to Haiku, implementation to Sonnet |
| **Agent Telemetry** | PostToolUse hook logs agent usage to analytics |
| **Smart Packs** | Project-type detection recommends relevant agent packs |
| **Agent Pack System** | On-demand domain specialist activation via `--with-packs` |
| **CI Dedup Detection** | Automated duplicate agent detection across upstream syncs |

## Quick Start

### If you are a human

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Re-running the same install command refreshes to the latest published `main` build, replaces only my-codex-managed files in `~/.codex/`, and removes stale my-codex skill copies from `~/.agents/skills/` and `~/.claude/skills/`.

> **Agent Packs**: Domain specialist agents are installed to `~/.codex/agent-packs/`. On first install, `my-codex` auto-activates a recommended `dev` set (`engineering`, `language-specialists`, `developer-experience`, `data-ai`, `research-analysis`, `testing`) and remembers it in `~/.codex/enabled-agent-packs.txt`.

### Skills only (cross-platform)

```bash
npx skills add sehoon787/my-codex -y -g
```

Installs 126 cross-tool skills to `~/.agents/skills/` with auto-symlinks to Codex CLI, Claude Code, Cursor, and other tools. Does **not** install agents, rules, or `config.toml` — use `install.sh` for the full 133-skill Codex bundle.

### If you are an LLM agent

Run the installer entrypoint directly.

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

`install.sh` is the only installer entrypoint. `AI-INSTALL.md` is reference documentation and does not install anything by itself.

---

## Key Features

### Multi-Agent Orchestration
- **spawn_agent**: Codex CLI auto-discovers agents from `~/.codex/agents/` and spawns them in parallel for complex tasks
- **send_input**: Parent-to-child agent communication for iterative workflows
- **Agent Packs**: Recommended domain specialists auto-activate on first install, and the active set persists across reinstalls

### Model-Optimized Routing
- **o3 (high reasoning)**: Complex architecture, deep analysis — mapped from Claude Opus equivalents
- **o3 (medium)**: Standard implementation, code review — mapped from Claude Sonnet equivalents
- **o4-mini (low)**: Quick lookups, exploration — mapped from Claude Haiku equivalents

### All-in-One Bundle
- Install provides **444 installed agent files and 133 skills** instantly
- Bundles 6 upstream sources (agency-agents, everything-claude-code, oh-my-codex, awesome-codex-subagents, gstack, superpowers)
- Weekly CI auto-sync keeps bundled content up-to-date with upstream
- MD-to-TOML conversion handled automatically for non-native sources
- Installs a default git attribution flow so commits touched by real Codex sessions automatically receive `AI-Contributed-By: Codex`

### Codex Attribution
- `install.sh` installs a `codex` wrapper plus global `prepare-commit-msg`, `commit-msg`, and `post-commit` hooks in `~/.codex/git-hooks/`
- The wrapper records only files that changed during a real Codex session in the current git repository
- Commits that include recorded Codex-touched files get `Generated with Codex CLI: https://github.com/openai/codex` in the commit message
- The commit hook adds `AI-Contributed-By: Codex` only when staged files intersect that recorded change set
- `my-codex` does not change `git user.name`, `git user.email`, commit author, or committer identity
- To add an optional `Co-authored-by:` trailer as well, explicitly set both `git config --global my-codex.codexContributorName '<label>'` and `git config --global my-codex.codexContributorEmail '<github-linked-email>'`
- Local git commits cannot summon GitHub's official `@codex` agent identity directly; GitHub only recognizes co-authors by linked email, and no co-author is added unless you opt in with both settings
- To disable attribution entirely, set `git config --global my-codex.codexAttribution false`
- `my-claude` is a separate repository and is not version-managed or updated by `my-codex`

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

364 installed pack files across 21 categories are written to `~/.codex/agent-packs/`. On first install, `my-codex` writes `~/.codex/enabled-agent-packs.txt` with a recommended `dev` set and materializes those packs into `~/.codex/agents/` as symlinks. The default favors packs that add distinct specialists beyond the core registry, so heavily overlapping packs such as `security` and `infrastructure` remain opt-in. Use the helper to inspect or change the active set:

```bash
# View current state
~/.codex/bin/my-codex-packs status

# Enable another pack immediately
~/.codex/bin/my-codex-packs enable marketing

# Or switch profiles at install time
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
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
| Skills | 133 | ECC, superpowers | `~/.codex/skills/` |
| config.toml | 1 | my-codex | `~/.codex/config.toml` |
| AGENTS.md | 1 | my-codex | `~/.codex/AGENTS.md` |

The repository source inventory is larger than the install footprint because multiple upstreams ship the same destination filename. `install.sh` verifies the installed counts above, not the raw source totals.

<details>
<summary>Awesome Core Agents (54) — From awesome-codex-subagents</summary>

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
<summary>Skills (133) — From Everything Claude Code and superpowers</summary>

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
│  Skills Layer (133 from ECC + superpowers)              │
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

A library of 134 business specialist agent personas. Provides specialist perspectives across 14 categories — UX architects, data engineers, security auditors, and more. Converted from Markdown to native TOML via automated `md-to-toml.sh` pipeline.

### 2. [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)

A development framework originally built for Claude Code, providing 119 skills. 13 Claude Code-specific skills were removed; the remaining skills contain generic coding guidance usable across any LLM agent. The rules/ directory is included in the repo as reference material but is not read by Codex CLI.

### 3. [Awesome Codex Subagents](https://github.com/VoltAgent/awesome-codex-subagents)

136 production-grade agents in native TOML format. Already Codex-compatible — no conversion needed. Organized across 10 categories from core development to meta-orchestration.

### 4. [Oh My Codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex)

Codex CLI multi-agent harness framework by Yeachan Heo. A Rust/TypeScript runtime providing 36 skills, hooks, HUD, and team pipelines for Codex CLI. Referenced as architectural inspiration for my-codex's harness patterns. Does not provide agent TOML files directly.

### 5. [Oh My OpenAgent (omo)](https://github.com/code-yeongyu/oh-my-openagent)

A multi-platform agent harness by code-yeongyu. The 9 orchestration agents in this repository (atlas, hephaestus, metis, momus, oracle, prometheus, sisyphus, librarian, multimodal-looker) are adapted from omo agents, converted to Codex-native TOML format.

### 6. [OpenAI Official Skills](https://github.com/openai/skills)

The official Skills Catalog for Codex provided by OpenAI. Includes specialist skills for document processing, code generation, and development workflows. Can be installed via `$skill-installer` in Codex CLI.

### 7. [gstack](https://github.com/garrytan/gstack)
- garrytan's sprint-process harness with 27 skills
- Code review, QA, debugging, benchmarking, security audit, deployment workflows
- Built-in headless Chromium browser daemon for real browser testing

### 8. [superpowers](https://github.com/obra/superpowers)
- Jesse Vincent's workflow skills library (v5.0.7, MIT)
- 14 skills covering brainstorming, planning, TDD, code review, debugging, and agent orchestration workflows

---

## Troubleshooting

### Skills-only recovery

If a tool reports invalid `SKILL.md` files under `~/.agents/skills/`, the most common cause is a stale local copy or stale symlink target from an older install.

Remove the affected directories from `~/.agents/skills/` and matching entries under `~/.claude/skills/`, then reinstall:

```bash
npx skills add sehoon787/my-codex -y -g
```

If you use the full Codex bundle, rerun `install.sh` once as well. The full installer refreshes `~/.codex/skills/` and removes stale my-codex-managed copies under `~/.agents/skills/` and `~/.claude/skills/`.

---

## Contributing

Issues and PRs are welcome. When adding a new agent, add a `.toml` file to the `agents/` directory and update the agent list in `SETUP.md`.
See [CONTRIBUTING.md](./CONTRIBUTING.md) for PR validation steps and Codex commit attribution behavior.

---

## Bundled Upstream Versions

Updated weekly by CI auto-sync. Pinned SHAs and sync timestamps are recorded in [`upstream/SOURCES.json`](./upstream/SOURCES.json).

| Source | Sync |
|--------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | Weekly CI |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | Weekly CI |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | Weekly CI |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | Weekly CI |
| [gstack](https://github.com/garrytan/gstack) | Weekly CI |
| [superpowers](https://github.com/obra/superpowers) | Weekly CI |

---

## Credits

This repository builds on the work of the following open-source projects:

- [agency-agents](https://github.com/msitarzewski/agency-agents) — msitarzewski
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — affaan-m
- [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) — Yeachan Heo
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) — code-yeongyu
- [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) — VoltAgent
- [openai/skills](https://github.com/openai/skills) — OpenAI
- [gstack](https://github.com/garrytan/gstack) — garrytan
- [superpowers](https://github.com/obra/superpowers) — Jesse Vincent
- [Codex Subagents Spec](https://developers.openai.com/codex/subagents) — OpenAI

---

## License

MIT License. See the [LICENSE](./LICENSE) file for details.
