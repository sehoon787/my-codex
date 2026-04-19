[English](./README.md) | [한국어](./docs/i18n/README.ko.md) | [日本語](./docs/i18n/README.ja.md) | [中文](./docs/i18n/README.zh.md) | [Deutsch](./docs/i18n/README.de.md) | [Français](./docs/i18n/README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same Boss orchestration in native Claude `.md` agent format

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-330%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

**All-in-one agent harness for OpenAI Codex CLI.**
**Install once, 330+ agents ready.**

Boss auto-discovers every agent and skill at runtime,
then routes your task to the right specialist via `spawn_agent`. No config. No boilerplate.

<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## Installation

### For Humans

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

Clone-based install:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Windows note:
- `install.sh` patches the npm-managed `codex`, `codex.cmd`, and `codex.ps1` shims when they exist, so the my-codex vault pipeline still has wrapper fallback coverage even if `%APPDATA%\npm` resolves before `~/.codex/bin`.

### For AI Agents

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

---

## How Boss Works

Boss is the meta-orchestrator at the core of my-codex. It never writes code — it discovers, classifies, matches, delegates, and verifies.

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

### Priority Routing

Boss cascades every request through a priority chain until the best match is found:

| Priority | Match Type | When | Example |
|:--------:|-----------|------|---------|
| **P1** | Skill match | Task maps to a self-contained skill | `"merge PDFs"` → pdf skill |
| **P2** | Specialist agent | Domain-specific agent exists | `"security audit"` → security-reviewer |
| **P3a** | Boss direct | 2–4 independent agents | `"fix 3 bugs"` → parallel spawn |
| **P3b** | Sub-orchestrator | Complex multi-step workflow | `"refactor + test"` → Sisyphus |
| **P4** | Fallback | No specialist matches | `"explain this"` → general agent |

### Model Routing

| Complexity | Model | Used For |
|-----------|-------|----------|
| Deep analysis, architecture | o3 (high reasoning) | Boss, Oracle, Sisyphus, Atlas |
| Standard implementation | o3 (medium) | executor, debugger, security-reviewer |
| Quick lookup, exploration | o4-mini (low) | explore, simple advisory |

### 3-Phase Sprint Workflow

For end-to-end feature implementation, Boss orchestrates a structured sprint:

```
Phase 1: DESIGN         Phase 2: EXECUTE        Phase 3: REVIEW
(interactive)            (autonomous)             (interactive)
─────────────────────   ─────────────────────   ─────────────────────
User decides scope      executor runs tasks     Compare vs design doc
Engineering review      Auto code review        Present comparison table
Confirm "design done"   Architect verification  User: approve / improve
```

---

## Architecture

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

## What's Inside

| Category | Count | Source |
|----------|------:|--------|
| **Core agents** (always loaded) | 98 | Boss 1 + OMO 9 + OMX 33 + Awesome Core 54 + Superpowers 1 |
| **Agent packs** (on-demand) | 220+ | 20 domain categories from agency-agents + awesome-codex-subagents |
| **Skills** | 200+ | ECC 180+ · gstack 40 · OMX 36 · Superpowers 14 · Core 1 |
| **MCP Servers** | 3 | Context7, Exa, grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>Core Agent — Boss meta-orchestrator (1)</strong></summary>

| Agent | Model | Role | Source |
|-------|-------|------|--------|
| Boss | o3 high | Dynamic runtime discovery → capability matching → optimal routing. Never writes code. | my-codex |

</details>

<details>
<summary><strong>OMO Agents — Sub-orchestrators and specialists (9)</strong></summary>

| Agent | Model | Role | Source |
|-------|-------|------|--------|
| Sisyphus | o3 high | Intent classification → specialist delegation → verification | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | o3 high | Autonomous explore → plan → execute → verify | oh-my-openagent |
| Atlas | o3 high | Task decomposition + 4-stage QA verification | oh-my-openagent |
| Oracle | o3 high | Strategic technical consulting (read-only) | oh-my-openagent |
| Metis | o3 high | Intent analysis, ambiguity detection | oh-my-openagent |
| Momus | o3 high | Plan feasibility review | oh-my-openagent |
| Prometheus | o3 high | Interview-based detailed planning | oh-my-openagent |
| Librarian | o3 medium | Open-source documentation search via MCP | oh-my-openagent |
| Multimodal-Looker | o3 medium | Image/screenshot/diagram analysis | oh-my-openagent |

</details>

<details>
<summary><strong>OMC Agents — Specialist workers (19)</strong></summary>

| Agent | Role | Source |
|-------|------|--------|
| analyst | Pre-analysis before planning | [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) |
| architect | System design and architecture | oh-my-claudecode |
| code-reviewer | Focused code review | oh-my-claudecode |
| code-simplifier | Code simplification and cleanup | oh-my-claudecode |
| critic | Critical analysis, alternative proposals | oh-my-claudecode |
| debugger | Focused debugging | oh-my-claudecode |
| designer | UI/UX design guidance | oh-my-claudecode |
| document-specialist | Documentation writing | oh-my-claudecode |
| executor | Task execution | oh-my-claudecode |
| explore | Codebase exploration | oh-my-claudecode |
| git-master | Git workflow management | oh-my-claudecode |
| planner | Rapid planning | oh-my-claudecode |
| qa-tester | Quality assurance testing | oh-my-claudecode |
| scientist | Research and experimentation | oh-my-claudecode |
| security-reviewer | Security review | oh-my-claudecode |
| test-engineer | Test writing and maintenance | oh-my-claudecode |
| tracer | Execution tracing and analysis | oh-my-claudecode |
| verifier | Final verification | oh-my-claudecode |
| writer | Content and documentation | oh-my-claudecode |

</details>

<details>
<summary><strong>Awesome Core Agents (54) — From awesome-codex-subagents</strong></summary>

4 categories installed to `~/.codex/agents/`:

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
<summary><strong>Superpowers Agent (1) — From obra/superpowers</strong></summary>

| Agent | Role | Source |
|-------|------|--------|
| superpowers-code-reviewer | Comprehensive code review with brainstorming and TDD verification | [superpowers](https://github.com/obra/superpowers) |

</details>

<details>
<summary><strong>Agent Packs — On-demand domain specialists (21 categories)</strong></summary>

Installed to `~/.codex/agent-packs/`. Managed via:

```bash
# View current state
~/.codex/bin/my-codex-packs status

# Enable a pack immediately
~/.codex/bin/my-codex-packs enable marketing

# Switch profiles at install time
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
```

| Pack | Count | Examples |
|------|------:|---------|
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

</details>

<details>
<summary><strong>Skills — 200+ from 5 sources</strong></summary>

| Source | Count | Key Skills |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 180+ | tdd-workflow, autopilot, security-review, coding-standards |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 36 | plan, team, trace, deep-dive, blueprint, ultrawork |
| [gstack](https://github.com/garrytan/gstack) | 40 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 14 | brainstorming, systematic-debugging, TDD, parallel-agents |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 1 | boss-advanced |

</details>

<details>
<summary><strong>MCP Servers (3)</strong></summary>

| Server | Purpose | Cost |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://mcp.context7.com) | Real-time library documentation | Free |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://mcp.exa.ai) | Semantic web search | Free 1k req/month |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://mcp.grep.app) | GitHub code search | Free |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian-compatible persistent memory. Every project maintains a `.briefing/` directory that updates during Codex sessions via native plugin hooks, with wrapper fallback for session start/end continuity.

```
.briefing/
├── INDEX.md                          ← Project context (auto-created once)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← Human/agent-written follow-up session summary
│   └── YYYY-MM-DD-auto.md           ← Auto-generated scaffold (recorded files, filtered status, follow-up)
├── decisions/
│   └── YYYY-MM-DD-<decision>.md     ← Human/agent-written decision record
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← Human/agent-written learning note
│   └── YYYY-MM-DD-auto-session.md   ← Auto-generated scaffold (files, wrapper activity, prompts)
├── references/
│   └── auto-links.md                ← Reserved for collected research links
├── agents/
│   ├── agent-log.jsonl              ← Wrapper/session log
│   └── YYYY-MM-DD-summary.md        ← Daily logged-signal breakdown
└── persona/
    ├── profile.md                   ← Routing/profile summary from logged signals
    ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
    └── persona-policy.json          ← Accepted soft routing preferences for Boss
```

### Sub-Vaults

| Path | Description |
|------|-------------|
| `INDEX.md` | Project overview with links to recent decisions and learnings. Auto-created on first session, refreshed periodically. |
| `sessions/` | **Session summaries.** `*-auto.md` — auto-generated scaffold refreshed during the session and finalized at stop using recorded session files, filtered status, and logged signals. `<topic>.md` — human or agent-written follow-up session summary prompted by the vault reminders. |
| `decisions/` | **Architecture and design decisions** with rationale. Write these as durable notes when a decision is important enough to keep. |
| `learnings/` | **Patterns, gotchas, non-obvious solutions.** `*-auto-session.md` — auto-generated scaffold refreshed during the session with the session's recorded file list, logged signals, and prompts for follow-up notes. `<topic>.md` — human or agent-written learning note. |
| `references/` | **Web research URLs.** `references/auto-links.md` is updated from `WebSearch`/`WebFetch` hook activity when those native Codex hooks are available. |
| `agents/` | **Logged session signals.** `agent-log.jsonl` — wrapper/session log plus richer hook payloads when available. `YYYY-MM-DD-summary.md` — daily logged-signal breakdown derived from that log. |
| `persona/` | **User work style profile.** `profile.md` — routing/profile summary derived from logged signals. `suggestions.jsonl` — routing recommendations. `persona-policy.json` — accepted soft routing preferences that Boss can use as tie-breakers when capabilities already match. |

### Session-Specific Diffs

At session start, my-codex saves the current git HEAD and a snapshot of the working tree state. During the session, native Codex hooks refresh `.briefing` scaffolds after prompts, edits, searches, and subagent completions. At session end, the final scaffold summarizes diff and status only for recorded paths, while filtering hook-created noise such as `.briefing/` artifacts and session-start `.gitignore` edits.

This keeps the scaffold focused on session-owned work instead of dumping the entire repository status.

### Using with Obsidian

1. Open Obsidian → **Open folder as vault** → select `.briefing/`
2. Notes appear in graph view, linked by `[[wiki-links]]`
3. YAML frontmatter (`date`, `type`, `tags`) enables structured search
4. Timeline scaffolds for sessions and learnings build automatically; follow-up summaries, decisions, and learning notes accumulate as you write them

---

## Upstream Open-Source Sources

my-codex bundles content from 8 upstream repositories:

| # | Source | What It Provides |
|---|--------|-----------------|
| 1 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | Sister project. Same Boss orchestration in native Claude `.md` agent format. Skills, rules, and briefing vault shared across both projects. |
| 2 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 136 production-grade agents in native TOML format. Already Codex-compatible, no conversion needed. 54 core agents auto-loaded. |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 36 skills, hooks, HUD, and team pipelines for Codex CLI. Referenced as architectural inspiration. |
| 4 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 180+ business specialist agent personas across 14 categories. Converted from Markdown to native TOML via automated pipeline. |
| 5 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 180+ skills across development workflows. Claude Code-specific content stripped; generic coding skills retained. |
| 6 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 skills + 1 agent covering brainstorming, TDD, parallel agents, and code review. |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 OMO agents (Sisyphus, Atlas, Oracle, etc.). Adapted to Codex-native TOML format. |
| 8 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 40 skills for code review, QA, security audit, deployment. Includes Playwright browser daemon. |

---

## GitHub Actions

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **CI** | push, PR | Validates TOML agent files, skill existence, and upstream file counts |
| **Update Upstream** | weekly (Monday) / manual | Runs `git submodule update --remote` and creates auto-merge PR |
| **Auto Tag** | push to main | Reads version from `config.toml` and creates git tag if new |
| **Pages** | push to main | Deploys `docs/index.html` to GitHub Pages |
| **CLA** | PR | Contributor License Agreement check |
| **Lint Workflows** | push, PR | Validates GitHub Actions workflow YAML syntax |

---

## my-codex Originals

Features built specifically for this project, beyond what upstream sources provide:

| Feature | Description |
|---------|-------------|
| **Boss Meta-Orchestrator** | Dynamic capability discovery → intent classification → 4-priority routing → delegation → verification |
| **3-Phase Sprint** | Design (interactive) → Execute (autonomous via executor) → Review (interactive vs design doc) |
| **Agent Tier Priority** | core > omo > omc > awesome-core deduplication. Most specialized agent wins. |
| **Cost Optimization** | o4-mini for advisory, o3 for implementation — automatic model routing for 330+ agents |
| **Briefing Signals** | Wrapper/session logging feeds `.briefing/agents/agent-log.jsonl`, daily summaries, and routing/profile hints |
| **Smart Packs** | Project-type detection recommends relevant agent packs at session start |
| **Agent Pack System** | On-demand domain specialist activation via `--profile` and `my-codex-packs` helper |
| **Codex Attribution** | git hooks record Codex-touched files and append `AI-Contributed-By: Codex` to commit messages |
| **CI Dedup Detection** | Automated duplicate TOML agent detection across upstream syncs |

---

## Installation Options

### Quick Install

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Re-running the same command refreshes to the latest `main` build, replaces only my-codex-managed files in `~/.codex/`, and removes stale skill copies from `~/.agents/skills/`.

### Agent Pack Profiles

On first install, my-codex auto-activates a recommended `dev` set (`engineering`, `design`, `testing`, `marketing`, `support`) and records it in `~/.codex/enabled-agent-packs.txt`.

```bash
# Minimal profile (core agents only, no packs)
bash /tmp/my-codex/install.sh --profile minimal

# Full profile (all 21 pack categories enabled)
bash /tmp/my-codex/install.sh --profile full
```

### Codex Attribution System

`install.sh` installs a `codex` wrapper plus global git hooks in `~/.codex/git-hooks/`:

- **`prepare-commit-msg`** — Records files changed during a real Codex session
- **`commit-msg`** — Appends `Generated with Codex CLI: https://github.com/openai/codex` when staged files intersect the recorded change set
- **`post-commit`** — Adds `AI-Contributed-By: Codex` trailer to qualifying commits

Opt-in `Co-authored-by` trailer: set both `git config --global my-codex.codexContributorName '<label>'` and `my-codex.codexContributorEmail '<github-linked-email>'`. Disable entirely: `git config --global my-codex.codexAttribution false`. my-codex does **not** change `git user.name`, `git user.email`, or commit author identity.

### Agent TOML Format

Every agent is a native TOML file in `~/.codex/agents/`:

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

Global Codex settings in `~/.codex/config.toml`:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — Maximum concurrent sub-agents
- `max_depth` — Maximum nesting depth for agent-spawns-agent chains

---

## Bundled Upstream Versions

Upstream sources managed as git submodules. Pinned commits tracked in `.gitmodules`.

| Source | Sync |
|--------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | submodule |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | submodule |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | submodule |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | submodule |
| [gstack](https://github.com/garrytan/gstack) | submodule |
| [superpowers](https://github.com/obra/superpowers) | submodule |

---

## FAQ

<details>
<summary><strong>How is my-codex different from my-claude?</strong></summary>

my-codex and my-claude share the same Boss orchestration architecture and upstream skill sources. The key difference is the runtime: my-codex targets OpenAI Codex CLI with native `.toml` agent format and `spawn_agent` delegation, while my-claude targets Claude Code with `.md` agent format and the Agent tool.

</details>

<details>
<summary><strong>Can I use both my-codex and my-claude?</strong></summary>

Yes. They install to separate directories (`~/.codex/` and `~/.claude/`) and do not conflict. Skills from shared upstream sources are adapted for each platform.

</details>

<details>
<summary><strong>How do agent packs work?</strong></summary>

Agent packs are domain-specific agent collections installed to `~/.codex/agent-packs/`. On first install, a `dev` profile is auto-activated. Use `my-codex-packs enable <pack>` to activate additional packs, or reinstall with `--profile full` to enable all 21 categories.

</details>

<details>
<summary><strong>How does upstream sync work?</strong></summary>

A GitHub Actions workflow runs every Monday, pulling the latest commits from all upstream submodules and creating an auto-merge PR. You can also trigger it manually from the Actions tab.

</details>

<details>
<summary><strong>What models does my-codex use?</strong></summary>

Boss and sub-orchestrators (Sisyphus, Atlas, Oracle) use o3 with high reasoning effort. Standard workers use o3 with medium reasoning. Lightweight advisory agents use o4-mini.

</details>

---

## Troubleshooting

### Skills-only recovery

If a tool reports invalid `SKILL.md` files under `~/.agents/skills/`, the most common cause is a stale local copy or stale symlink target from an older install.

Remove the affected directories from `~/.agents/skills/` and matching entries under `~/.claude/skills/`, then reinstall:

```bash
npx skills add sehoon787/my-codex -y -g
```

If you use the full Codex bundle, rerun `install.sh` once as well. The full installer refreshes `~/.codex/skills/` and removes stale my-codex-managed copies under `~/.agents/skills/`.

---

## Contributing

Issues and PRs are welcome. When adding a new agent, add a `.toml` file to `codex-agents/core/` or `codex-agents/omo/` and update the agent list in `SETUP.md`. See [CONTRIBUTING.md](./CONTRIBUTING.md) for PR validation steps and Codex commit attribution behavior.

## Credits

Built on the work of: [my-claude](https://github.com/sehoon787/my-claude) (sehoon787), [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo), [agency-agents](https://github.com/msitarzewski/agency-agents) (msitarzewski), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m), [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu), [gstack](https://github.com/garrytan/gstack) (garrytan), [superpowers](https://github.com/obra/superpowers) (Jesse Vincent), [openai/skills](https://github.com/openai/skills) (OpenAI).

## License

MIT License. See the [LICENSE](./LICENSE) file for details.
