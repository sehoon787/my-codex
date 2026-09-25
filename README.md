[English](./README.md) | [한국어](./docs/i18n/README.ko.md) | [日本語](./docs/i18n/README.ja.md) | [中文](./docs/i18n/README.zh.md) | [Deutsch](./docs/i18n/README.de.md) | [Français](./docs/i18n/README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same Boss orchestration in native Claude `.md` agent format

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-30_default_%2F_110_installed-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**All-in-one agent harness for Codex CLI.**
**One installer, 17 core agents ready.**

Boss discovers every agent, skill, and MCP tool at runtime,<br>
then routes your task to the right specialist through `spawn_agent`. No config files. No boilerplate.

<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## Installation

### For Humans

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

Or clone first and run the installer from the checkout:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

The default install exposes a lean skill set on purpose: Codex truncates skill
descriptions once its skills budget is hit, so the default `core` profile shows
Codex 30 of the 110 installed skill entries and keeps the rest one flag away:

```bash
bash install.sh --skills=web          # add the 18-skill web/UI lane
bash install.sh --full-skills         # every optional lane, plus the full exposure profile
bash install.sh --skill-profile=core  # back to the default exposure
```

The choice is saved and survives a later plain `bash install.sh`. See [Skill Profiles and Lanes](#skill-profiles-and-lanes) for every profile, every lane, and the `my-codex-skills` commands.

Interactive terminals show a checkbox selector for the three companion tools — Serena, Headroom, and codeburn — with all three selected by default. Move with ↑/↓ or `j`/`k`, toggle with Space, use `a` for all or `n` for none, and confirm the current selection with Enter or Ctrl-D/EOF. If `TERM` is empty or `dumb`, or `stty` is unavailable, the numbered fallback accepts Enter, `all`, `a`, `y`, or `yes` for all; `none`, `n`, `no`, or `0` for none; and mixed numbers or names such as `1,3` or `serena codeburn`. Automation selects all by default:

```bash
bash install.sh --tools=headroom   # an explicit subset
bash install.sh --yes              # all three, without prompting
bash install.sh --skip-tools       # none
```

On Windows, `install.sh` patches the npm-managed `codex`, `codex.cmd`, and `codex.ps1` shims when they exist, so the my-codex vault pipeline still has wrapper fallback coverage even if `%APPDATA%\npm` resolves before `~/.codex/bin`.

### For AI Agents

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

The agent will ask which companion tools (Serena, Headroom, codeburn) to install before running the installer, because the checkbox selector only appears in an interactive terminal.

---

## Open-Source Tools Used

Every project my-codex builds on, what it contributes, and exactly how it arrives. This table is the only place each project is described; the rest of this README lists inventories, commands, and pins.

| # | Project | What my-codex takes from it | How it arrives |
|---|---------|-----------------------------|----------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 61 allowlisted skills: stack patterns (TypeScript, React, Python/Django/FastAPI, Spring Boot/Kotlin, SQL/Redis/Prisma, Docker/Kubernetes), AI and agent engineering, and generic codebase tooling such as onboarding, code tours, and ADRs. Claude Code-specific content is stripped, and an 18-skill web/UI lane stays out of the default install. | submodule `upstream/ecc`; `install.sh` copies only the names allowlisted in `scripts/skill-allowlists.sh` |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 30 sprint-process skill entries — browser QA (`qa`), scope-drift code review (`review`), security audit (`cso`), and the full plan → review → ship workflow — plus a compiled Playwright browser daemon. | submodule `upstream/gstack`, vendored to `~/.codex/vendor/gstack` where its own `./setup --host codex` runs under bun and creates the 29 symlinks under `~/.codex/skills/` alongside the `gstack` root router directory; the 7 ECC skills it supersedes (`benchmark`, `canary-watch`, `safety-guard`, `browser-qa`, `verification-loop`, `security-review`, `design-system`) are removed so only the gstack version stays routable |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 7 allowlisted worker agents: `executor`, `planner`, `architect`, `test-engineer`, `security-reviewer`, `code-reviewer`, `debugger`. Its remaining prompts and its skills duplicate agents this repo already ships, so they are deliberately not installed. | submodule `upstream/omx`; `scripts/md-to-toml.sh` converts the allowlisted prompts from Markdown into `~/.codex/agents/*.toml` |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 development-process skills: brainstorming, systematic debugging, test-driven development, plan writing and execution, worktree handling, and code-review etiquette. No agent is taken from it — its single `code-reviewer` prompt overlaps the oh-my-codex one. | submodule `upstream/superpowers`; all 15 skill directories install except `dispatching-parallel-agents`, which duplicates the Boss delegation path this repo already owns |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | 1 diagram skill that turns architecture, workflow, sequence, data-flow, and lifecycle descriptions into one self-contained HTML file with inline SVG, a dark/light toggle, and PNG/JPEG/WebP/SVG export. | submodule `upstream/archify`, pinned to tag `v2.9.0` so the sync job leaves it alone; only the repo's top-level `archify/` directory is copied to `~/.codex/skills/archify`, so no `npx skills add` runs at install time |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 17 Codex-native TOML agents, shipped as the two opt-in packs `data-ai` (13) and `llmops` (4). Neither pack is enabled by a fresh install. | vendored (MIT) into `codex-agents/packs/` and installed to `~/.codex/agent-packs/`; submodule removed 2026-07-27. Enable with `~/.codex/bin/my-codex-packs enable data-ai` or `install.sh --profile dev` |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 agents — `sisyphus`, `atlas`, `prometheus`, `oracle`, `metis`, `momus`, `hephaestus`, `librarian`, `multimodal-looker` — covering end-to-end orchestration, plan execution and review, deep second opinions, source-backed library lookup, and reading media files. | adapted to Codex-native TOML and maintained in-repo under `codex-agents/omo/`, so they install without an upstream checkout |
| 8 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | Nothing. No agent from these packs was ever spawned in this repo, so nothing was vendored. | removed (MIT) — submodule dropped 2026-07-27, still recorded in `upstream/SOURCES.json` |
| 9 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | The same Boss orchestration in native Claude `.md` agent format, and the editorial baseline: `scripts/skill-allowlists.sh` mirrors my-claude's ECC, gstack, and superpowers lists verbatim so both harnesses expose the same upstream surface. | sister project only — `install.sh` never clones, curls, or copies anything from it, so nothing is vendored and there is no pin to track. Installed side by side, the two installers coordinate codeburn and Headroom through one user-wide lock and state directory instead of fighting over the fixed ports |
| 10 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | Local-first token and cost accounting over the session files Codex already writes under `~/.codex/sessions` — no proxy, no API key, no Codex hooks. | `npm i -g codeburn@0.9.23`; `install.sh` starts or reuses one shared `codeburn web --provider all --port 4747 --no-open` process |
| 11 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | Structural search and rewrite that matches on the syntax tree instead of on raw text, so agents can change code shapes without brittle regular expressions. | `npm i -g @ast-grep/cli@0.42.0`, skipped when an `ast-grep` binary is already on `PATH` |
| 12 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | A language server's symbol graph over MCP — `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` — so tokens scale with the symbol rather than the whole file. The distributed package is GPL-3.0-or-later as a whole (PyPI's MIT metadata is inaccurate), so nothing is vendored. | `uv tool install --python 3.13 serena-agent==1.7.0`, registered as `[mcp_servers.serena]` (stdio: `serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False`, `startup_timeout_sec = 15`) |
| 13 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | Apache-2.0 context compression over MCP: `headroom_compress`, `headroom_retrieve`, and `headroom_stats`. The `headroom wrap` proxy mode stays a documented manual opt-in. | `uv tool install --python 3.13 "headroom-ai[all]==0.37.0"`, registered as `[mcp_servers.headroom]` (`headroom mcp serve`, `default_tools_approval_mode = "approve"` because the server publishes no MCP annotations); the installer starts or reuses the shared `agent-harness-shared` profile on port 8787 and never sets `ANTHROPIC_BASE_URL` or `OPENAI_BASE_URL` |
| 14 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | Library, framework, and SDK answers from current upstream documentation instead of from model memory. It is the backend the `documentation-lookup` skill routes to. | hosted MCP server at `https://mcp.context7.com/mcp` |
| 15 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | Neural web search. The registered URL enables only `web_search_exa`, which keeps the research path to a single tool rather than Exa's full surface. | hosted MCP server at `https://mcp.exa.ai/mcp?tools=web_search_exa` |
| 16 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | Cross-repository code search over public GitHub, so an agent can look up real call sites of a library across many repositories before writing code against it. | hosted MCP server at `https://mcp.grep.app` |

---

## How Boss Works

Boss is the meta-orchestrator at the core of my-codex. It never writes code — it discovers, classifies, matches, delegates, and verifies. The main Codex session performs the Boss role through the installed `AGENTS.md`, so it delegates directly to specialists instead of spawning another Boss first. Its native session identity remains Codex/root, and reinstalling refreshes managed instructions while preserving customized sections.

| Phase | What Happens |
|-------|--------------|
| **0 · Discovery** | Scans `~/.codex/agents/*.toml` at runtime into a live capability registry |
| **1 · Intent gate** | Classifies the request (trivial, build, refactor, mid-sized, architecture, research, …) and counter-proposes a skill when one fits better |
| **2 · Capability matching** | Cascades the priority chain below (P1 exact skill → P2 specialist agent → P3 multi-agent orchestration → P4 general-purpose fallback) |
| **3 · Delegation** | Calls `spawn_agent` with a 6-section structured prompt: TASK / OUTCOME / TOOLS / DO / DON'T / CTX |
| **4 · Verification** | Reads the changed files independently, runs tests, lint, and build, cross-references the original intent, retries up to 3× on failure |

### Priority Routing

Boss cascades every request through a priority chain until the best match is found:

| Priority | Match Type | When | Example |
|:--------:|-----------|------|---------|
| **P1** | Skill match | Task maps to a self-contained skill | `"review this diff"` → /review skill |
| **P2** | Specialist agent | Domain-specific agent exists | `"security audit"` → security-reviewer |
| **P3a** | Boss direct | 2–4 independent agents | `"fix 3 bugs"` → parallel spawn |
| **P3b** | Sub-orchestrator | Complex multi-step workflow | `"refactor + test"` → Sisyphus |
| **P4** | Fallback | No specialist matches | `"explain this"` → general agent |

### Model Routing

| Complexity | Model | Used For |
|-----------|-------|----------|
| Top-level orchestration | `gpt-6-astra` | Boss |
| Deep analysis, architecture, review | `gpt-6-astra` | Oracle, Prometheus, Sisyphus, Hephaestus, Atlas, Metis, Momus, architect, planner, code-reviewer, security-reviewer |
| Standard implementation | `gpt-5.6-sol` | Librarian, Multimodal-Looker, executor, test-engineer, debugger, and 15 of the 17 pack agents |
| Quick lookup, light analysis | `gpt-5.6-terra` | data-analyst, prompt-regression-tester |

The three tier IDs live in a single file, `scripts/model-tiers.sh`; `scripts/md-to-toml.sh` and `install.sh` both source it, and `scripts/check-model-drift.sh` fails the build if a model ID is hardcoded anywhere else in the scripts.

### Effort Tiers

Model choice sets *which* brain runs a task; the `model_reasoning_effort` field next to `model` in the same TOML sets *how hard* it thinks. Boss and the nine OMO agents declare it in the committed files under `codex-agents/`, the seven oh-my-codex workers receive theirs from the role table in `scripts/md-to-toml.sh` at conversion time, and each pack agent carries its own:

| Effort | Agents |
|--------|--------|
| `xhigh` | Boss, Oracle, Prometheus, architect |
| `high` | Sisyphus, Hephaestus, Atlas, Metis, Momus, planner, code-reviewer, security-reviewer, and 15 of the 17 pack agents |
| `medium` | Librarian, Multimodal-Looker, executor, test-engineer, debugger, data-analyst, prompt-regression-tester |

### 3-Phase Sprint Workflow

For end-to-end feature implementation, Boss orchestrates a structured sprint:

| Phase | Mode | What Happens |
|-------|------|--------------|
| **1 · Design** | interactive | User decides scope · engineering review · confirm "design done" |
| **2 · Execute** | autonomous | executor runs the tasks · auto code review · architect verification |
| **3 · Review** | interactive | Compare against the design doc · present comparison table · user approves or asks for improvement |

### Structured Final Report

Boss closes every working turn — any turn that edited files, made commits/PRs, changed configuration, or ran verification — with a structured final report the reader can scan without opening a diff. The report is assembled from five fixed tables, each emitted only when its situation actually occurred (never an empty table):

| Situation | Table | Columns |
|-----------|-------|---------|
| Files/settings changed | Changes | Target / Before / After / Rationale |
| Multiple tasks completed | Work summary | Item / Result / Evidence |
| Verification was run | Verification | Item / Expected / Actual / Verdict |
| Commits/PRs produced | Deliverables | PR / Repo / Content / Status |
| Anything unresolved | Remaining | Item / Status / Next step |

It fires only at the very end of the request — never on a turn that launches or relays background work, never as a mid-task progress update — and pure Q&A turns end normally without it. The spec ships in `boss.toml`'s developer instructions and in `~/.codex/AGENTS.md`, so the main session sees it too. A Stop hook (`hooks/stop-final-report.js`) enforces it: when a turn changed state but closed without a report table, the hook blocks that turn once and asks for the report.

---

## What's Inside

| Category | Count | Source |
|----------|------:|--------|
| **Core agents** (always loaded) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Agent packs** (opt-in, none enabled by default) | 17 | 2 vendored categories: data-ai 13 + llmops 4 |
| **Skills exposed** (default `core` profile) | 30 | The always-on set; every other entry is one lane flag away |
| **Skills installed** (entries under `~/.codex/skills/`) | 110 | ECC 61 · gstack 30 · Superpowers 14 · Core 4 · archify 1 |
| **MCP Servers** | 5 | Context7, Exa, grep.app, Serena, Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

Every agent and skill above is allowlisted in [`scripts/skill-allowlists.sh`](./scripts/skill-allowlists.sh) — that file is the authority for what ships. This bundle deliberately does not ship `pdf`, `docx`, `pptx`, or `xlsx`; externally installed skills of that kind are preserved untouched.

<details>
<summary><strong>Core Agent — Boss meta-orchestrator (1)</strong></summary>

| Agent | Model | Role | Source |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | Dynamic runtime discovery → capability matching → optimal routing. Never writes code. | my-codex |

</details>

<details>
<summary><strong>OMO Agents — Sub-orchestrators and specialists (9)</strong></summary>

| Agent | Model | Role | Source |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | Intent classification → specialist delegation → verification | oh-my-openagent |
| Hephaestus | gpt-6-astra high | Autonomous explore → plan → execute → verify | oh-my-openagent |
| Atlas | gpt-6-astra high | Task decomposition + 4-stage QA verification | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | Strategic technical consulting (read-only) | oh-my-openagent |
| Metis | gpt-6-astra high | Intent analysis, ambiguity detection | oh-my-openagent |
| Momus | gpt-6-astra high | Plan feasibility review | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | Interview-based detailed planning | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | Open-source documentation search via MCP | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | Image/screenshot/diagram analysis | oh-my-openagent |

</details>

<details>
<summary><strong>OMX Agents — Specialist workers (7)</strong></summary>

| Agent | Sandbox | Role | Source |
|-------|---------|------|--------|
| executor | workspace-write | Code implementation | oh-my-codex |
| planner | read-only | Implementation planning | oh-my-codex |
| architect | read-only | System design and architecture | oh-my-codex |
| test-engineer | workspace-write | Test strategy and coverage | oh-my-codex |
| security-reviewer | read-only | Security analysis | oh-my-codex |
| code-reviewer | read-only | Focused code review | oh-my-codex |
| debugger | workspace-write | Root cause analysis | oh-my-codex |

</details>

<details>
<summary><strong>Agent Packs — Opt-in AI specialists (2 packs, 17 agents)</strong></summary>

| Pack | Count | Agents |
|------|------:|--------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

Installed to `~/.codex/agent-packs/` and disabled until you opt in — see [Agent Pack Profiles](#agent-pack-profiles).

</details>

<details>
<summary><strong>Skills — 30 exposed by default, 110 installed from 5 sources</strong></summary>

| Source | Installed | Key Skills |
|--------|----------:|------------|
| everything-claude-code | 61 | coding-standards, python-testing, api-design, deep-research |
| gstack | 30 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| superpowers | 14 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| archify | 1 | archify (architecture / workflow / sequence / data-flow / lifecycle diagrams) |

The gstack entries are the `gstack` root router directory plus 29 symlinks into `~/.codex/vendor/gstack/.agents/skills/`, created by gstack’s own `./setup`: the 26 names in `GSTACK_SKILL_ALLOWLIST` and three more it always installs (`gstack-upgrade`, `hackernews-frontpage`, `codex`). All 29 are in the managed catalog, so none of them is link-only — each can be exposed by `core` or by a lane. Of the 110 entries, 81 are real directories and 29 are those symlinks; `find ~/.codex/skills -name SKILL.md | wc -l` reports 83 because `find` does not follow them without `-L`. Skill files stay installed no matter which profile is active — exposure is what changes. See [Skill Profiles and Lanes](#skill-profiles-and-lanes).

</details>

<details>
<summary><strong>Hosted MCP Servers (3 of 5)</strong></summary>

Serena and Headroom are the other two; both are local stdio servers.

| Server | Purpose | Cost |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | Real-time library documentation | Free |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | Semantic web search | Free 1k req/month |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | GitHub code search | Free |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian-compatible persistent memory. Every project maintains a `.briefing/` directory that updates during Codex sessions via native plugin hooks, with wrapper fallback for session start/end continuity:

```
.briefing/
├── INDEX.md                          ← Project context (auto-created once)
├── state.json                        ← Session metadata, counters, lastVaultSync (auto-managed)
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
├── archives/                         ← PARA: completed/inactive notes (flat)
├── wiki/                             ← LLM-wiki: concept pages
│   └── _schema.md
├── agents/
│   ├── agent-log.jsonl              ← Wrapper/session log
│   └── YYYY-MM-DD-summary.md        ← Daily logged-signal breakdown
└── persona/
    ├── profile.md                   ← Routing/profile summary from logged signals
    ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
    ├── persona-policy.json          ← Accepted soft routing preferences for Boss
    └── rules/                       ← Workflow pattern rules (workflow-*.md)
```

### Knowledge Management (v2)

BriefingVault v2 integrates three knowledge management methodologies:

| Methodology | Applied As |
|------------|-----------|
| **PARA** (Tiago Forte) | Directory structure: sessions=Projects, decisions=Areas, references=Resources, archives=Archives |
| **Zettelkasten** (Luhmann) | Atomic notes in `learnings/`, unique IDs (`YYYYMMDDHHMMSS`), enforced `[[wiki-links]]` |
| **LLM-wiki** (Karpathy) | Concept pages in `wiki/` — auto-suggested when keywords appear 3+ times |

Codex CLI session-end hooks automatically:

- Suggest archiving notes older than 30 days
- Propose wiki pages for frequently mentioned concepts
- Generate unique Zettelkasten IDs for new notes

### Session-Specific Diffs

At session start, my-codex saves the current git HEAD and a snapshot of the working tree state. During the session, native Codex hooks refresh `.briefing` scaffolds after prompts, edits, searches, and subagent completions. At session end, the final scaffold summarizes diff and status only for recorded paths, while filtering hook-created noise such as `.briefing/` artifacts and session-start `.gitignore` edits.

This keeps the scaffold focused on session-owned work instead of dumping the entire repository status. For non-git projects, a `YYYY-MM-DD:cwd` identifier is used as fallback.

### Using with Obsidian

1. Open Obsidian → **Open folder as vault** → select `.briefing/`
2. Notes appear in graph view, linked by `[[wiki-links]]`
3. YAML frontmatter (`date`, `type`, `tags`) enables structured search
4. Timeline scaffolds for sessions and learnings build automatically; follow-up summaries, decisions, and learning notes accumulate as you write them

### /boss-briefing

Run `/boss-briefing` during or at the end of a session to:

- **Sync vault**: Update profile.md, INDEX.md, and agent summaries
- **Detect workflow patterns**: Analyze temporal agent call sequences across sessions
- **Recover from gaps**: Generate recovery summaries if days have passed since the last session
- **Propose persona rules**: Suggest workflow-based routing preferences (not just frequency)
- **Validate session notes**: Check that today's session has a proper summary

The Stop hook checks whether `/boss-briefing` has run today. If not, it blocks session end with a reminder. The existing `stop-profile-update.js` continues to run as a fallback.

### Sub-Vaults

| Path | Description |
|------|-------------|
| `INDEX.md` | Project overview with links to recent decisions and learnings. Auto-created on first session, refreshed periodically. |
| `sessions/` | **Session summaries.** `*-auto.md` — auto-generated scaffold refreshed during the session and finalized at stop using recorded session files, filtered status, and logged signals. `<topic>.md` — human or agent-written follow-up session summary prompted by the vault reminders. |
| `decisions/` | **Architecture and design decisions** with rationale. Write these as durable notes when a decision is important enough to keep. |
| `learnings/` | **Patterns, gotchas, non-obvious solutions.** `*-auto-session.md` — auto-generated scaffold refreshed during the session with the session's recorded file list, logged signals, and prompts for follow-up notes. `<topic>.md` — human or agent-written learning note. |
| `references/` | **Web research URLs.** `references/auto-links.md` is updated from `WebSearch`/`WebFetch` hook activity when those native Codex hooks are available. |
| `agents/` | **Logged session signals.** `agent-log.jsonl` — enriched entries with `{ts, agent_id, agent_type, phase, seq, task_hint}`. `YYYY-MM-DD-summary.md` — daily logged-signal breakdown derived from that log. |
| `persona/` | **User work style profile.** `profile.md` — routing/profile summary derived from logged signals. `suggestions.jsonl` — routing recommendations. `persona-policy.json` — accepted soft routing preferences. `rules/workflow-*.md` — workflow sequence pattern rules proposed by `/boss-briefing`. |
| `state.json` | Session metadata: counters, lastVaultSync, sessionStartHead. Auto-managed by hooks. |
| `archives/` | PARA Archives — completed sessions (30+ days), superseded decisions, inactive learnings |
| `wiki/` | LLM-wiki concept pages — distilled knowledge from multiple sessions |

### Behavioral Hooks

| Hook | Event | Behavior |
|------|-------|----------|
| Session Setup | SessionStart | Auto-detects tools + injects Briefing Vault context |
| Delegation Guard | PreToolUse | Reminds the session, while it is in Boss mode, to delegate file edits instead of making them directly |
| Agent Telemetry | PostToolUse | Logs agent usage to `~/.gstack/analytics/agent-usage.jsonl` |
| Vault Enforcer | PostToolUse | Counts edits and refreshes the auto scaffolds mid-session |
| Link Collector | PostToolUse | Appends `WebSearch`/`WebFetch` results to `references/auto-links.md` |
| Subagent Logger | SubagentStop | Logs agent execution to Briefing Vault |
| Vault Reminder | UserPromptSubmit | Suggests /boss-briefing after 5+ messages, and a real session note once the turn has recorded work |
| Context Budget | UserPromptSubmit | Every 40 prompts since the last compaction (`MY_CODEX_COMPACT_EVERY`), suggests `/compact` at the next task boundary |
| Context Budget reset | PostCompact | Zeroes that counter after a compaction |
| Completion Check | Stop | Runs profile fallback + guards /boss-briefing |
| Final Report Gate | Stop | Blocks the turn once if work happened but no final-report table was emitted |

Codex loads these from `~/.codex/hooks.json` and only when `features.hooks = true`, so `install.sh` writes the file at that path and sets the flag under `[features]` in `config.toml`. On the next interactive Codex start you are asked once to review and trust the hooks — choose "Trust all and continue". Until you do, none of them run.

---

## Where to See Results

Every installed tool writes its output somewhere. This is where.

| Tool | Open | How to Run | Where to Look |
|------|------|------------|---------------|
| **codeburn** | <http://127.0.0.1:4747/> | The installer starts `codeburn web --provider all --port 4747 --no-open`; `codeburn` opens the interactive dashboard; non-interactive: `codeburn report --format json --period week --provider codex` (also `--day`, `--from`/`--to`) | Shared browser dashboard, terminal TUI, or JSON on stdout. Session files are read-only and dollar figures are estimates at public list rates, not an invoice. |
| **Serena** | <http://localhost:24282/dashboard/index.html> | Started by Codex from `[mcp_servers.serena]`; tools appear as `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` | Live dashboard and tool-call stats while a server is running. Per-project index and memories are under `<repo>/.serena/`; the browser does not auto-open (`--open-web-dashboard False`). |
| **Headroom** | <http://127.0.0.1:8787/stats> | Codex starts the MCP server from `[mcp_servers.headroom]` (`headroom mcp serve`); the installer applies the shared `agent-harness-shared` profile (command below) | Proxy stats, empty until a client is explicitly routed with `headroom wrap` or a base URL. |
| **Archify** | `<output>.html` | From `~/.codex/skills/archify`: `node bin/archify.mjs render <type> <input>.json <output>.html`, then `node bin/archify.mjs check <output>.html` | The file you named — open it in any browser. The skill's own `examples/*.json` are worked inputs to copy from. |

The installer applies the Headroom service profile with:

```bash
headroom install apply --profile agent-harness-shared --preset persistent-service \
  --runtime python --providers manual --port 8787 --no-telemetry \
  --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1
```

---

## GitHub Actions

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **CI** | push, PR | Validates TOML agent files, skill existence, and upstream file counts |
| **Smoke Tests** | push, PR | `hooks`, `shell`, `drift`, and `routing-refs` jobs — hook wiring, shell syntax, model drift, and AGENTS.md routing references |
| **Update Upstream** | every 3 days / manual | Security-gated `git submodule update --remote` over the 4 branch-tracked submodules, refreshes `upstream/SOURCES.json` pins, and creates an auto-merge PR |
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
| **Agent Tier Priority** | core > omo > omx > opt-in packs. Pack agents are skipped if their name collides with an already-installed agent. Most specialized agent wins. |
| **Cost Optimization** | Three model tiers from one source file (`scripts/model-tiers.sh`), applied to all 34 agents the installer ships |
| **Skill Exposure Profiles** | A managed catalog of 210 entries with a 30-skill default, 13 optional lanes, snapshots, and rollback — so the skills budget is spent on what the session needs |
| **Briefing Signals** | Wrapper/session logging feeds `.briefing/agents/agent-log.jsonl`, daily summaries, and routing/profile hints |
| **Smart Packs** | Project-type detection recommends relevant agent packs at session start |
| **Agent Pack System** | On-demand domain specialist activation via `--profile` and `my-codex-packs` helper |
| **Codex Attribution** | git hooks record Codex-touched files and append `AI-Contributed-By: Codex` to commit messages |
| **CI Dedup Detection** | Automated duplicate TOML agent detection across upstream syncs |

---

## Bundled Upstream Versions

Linked via git submodules. Pinned commits are tracked natively by `.gitmodules` and mirrored as an AI-BOM in [`upstream/SOURCES.json`](./upstream/SOURCES.json), which also version-pins the companion CLIs and MCP servers and records the two removed submodules; `install.sh` checks out these exact SHAs rather than tracking `main`.

| Source | SHA | Date | Diff |
|--------|-----|------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `e482e57` | 2026-09-25 | [compare](https://github.com/affaan-m/everything-claude-code/compare/e482e57...HEAD) |
| [gstack](https://github.com/garrytan/gstack) | `730a101` | 2026-09-25 | [compare](https://github.com/garrytan/gstack/compare/730a101...HEAD) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | `cdc24a7` | 2026-09-22 | [compare](https://github.com/Yeachan-Heo/oh-my-codex/compare/cdc24a7...HEAD) |
| [superpowers](https://github.com/obra/superpowers) | `5bf4e78` | 2026-09-19 | [compare](https://github.com/obra/superpowers/compare/5bf4e78...HEAD) |
| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |

---

## Installation Options

Re-running the same command refreshes to the latest `main` build, replaces only my-codex-managed files in `~/.codex/`, and removes stale skill copies from `~/.agents/skills/`.

### Skill Profiles and Lanes

my-claude installs one fixed allowlist; my-codex installs 110 skill entries and then controls how many of them Codex actually sees. Codex truncates skill descriptions once its skills budget is hit, so an unfocused catalog makes every description less useful. `core` — the default on a fresh install with all bundled skill sources selected — exposes 30 skills, and each lane is added on top of it:

| Profile / lane | What it adds | Count | How to enable |
|----------------|--------------|------:|---------------|
| `core` | The always-on set: my-codex core skills, the superpowers dev-process lane, the gstack ship/QA/review routers, and the ECC standards | 30 | default; `--skill-profile=core` to return to it |
| `legacy` | Pre-migration exposure; chosen automatically when `--skip-ecc`, `--skip-gstack`, `--skip-superpowers`, or `--skip-archify` omits a core source without an explicit profile | varies | `--skill-profile=legacy` |
| `full` | Every lane at once — all 110 installed entries; the catalog names 210, and the ones not installed yet materialize on demand. Can exceed the context budget | 110 | `--skill-profile=full` or `--full-skills` |
| `workflow-advanced` | Advanced planning, repository operations, and worktree workflows | 13 | `--skills=workflow-advanced` |
| `qa-operations` | QA, browser checks, release, deployment, and operational safety | 20 | `--skills=qa-operations` |
| `ai-engineering` | Agent systems, evaluation, prompts, retrieval, and MCP | 18 | `--skills=ai-engineering` |
| `backend-data` | Backend architecture, databases, caching, containers, and APIs | 13 | `--skills=backend-data` |
| `python` | Python, Django, and FastAPI implementation and testing | 9 | `--skills=python` |
| `jvm` | Java, Kotlin, JPA, and Spring implementation and testing | 11 | `--skills=jvm` |
| `web` | Web frameworks, accessibility, performance, and end-to-end testing | 18 | `--skills=web` |
| `mobile` | Android, Flutter, Swift, and SwiftUI engineering | 9 | `--skills=mobile` |
| `other-languages` | C++, Go, Laravel, Perl, and Rust engineering | 13 | `--skills=other-languages` |
| `research-content` | Research, technical content, market work, and outreach | 11 | `--skills=research-content` |
| `media-documents` | Media generation, document processing, OCR, and translation | 7 | `--skills=media-documents` |
| `business-domains` | Logistics, quality, production, procurement, and trade | 8 | `--skills=business-domains` |
| `alternative-workflows` | Optional orchestration, TDD, review, and verification systems | 30 | `--skills=alternative-workflows` |

The choice persists in `~/.codex/my-codex/skill-catalog-state.json`, with a compatibility record in `~/.codex/enabled-skill-lanes.txt`, so a later plain `bash install.sh` keeps it; `MY_CODEX_SKILLS=web` is equivalent to `--skills=web`, and existing noninteractive installs without state retain their current exposure. Physical skill files are never removed by a profile change — optional entries are hidden through Codex's supported path-based skill configuration, and unknown skills or files under `~/.agents/skills/` and `~/.claude/skills/` are left untouched.

After install, manage exposure with the `my-codex-skills` CLI:

```bash
my-codex-skills list                     # every catalog entry and its lane
my-codex-skills status                   # active profile and enabled lanes
my-codex-skills doctor                   # report catalog/state drift
my-codex-skills enable python web        # add lanes
my-codex-skills disable web              # drop a lane
my-codex-skills set-profile core         # core | legacy | full
my-codex-skills source benchmark gstack  # pick a source when two provide the same name
my-codex-skills restore latest           # roll back to a snapshot
```

The catalog is `~/.codex/lib/my-codex/skill-catalog.json` and snapshots are under `~/.codex/my-codex/skill-catalog-snapshots/<id>.json`. Enabling a lane can materialize missing payload from the pinned local vendor; when that payload is unavailable, state and config stay unchanged and the CLI directs you to `install.sh --skills=<lane>`.

### Agent Pack Profiles

Packs are installed but **inactive by default** — a fresh install enables none of them and records the empty set in `~/.codex/enabled-agent-packs.txt`. Opt in per pack, or pick a profile:

```bash
# View current state
~/.codex/bin/my-codex-packs status
# Enable one pack immediately
~/.codex/bin/my-codex-packs enable data-ai
# Minimal profile (core agents only, no packs — the default)
bash /tmp/my-codex/install.sh --profile minimal
# Dev profile (data-ai + llmops)
bash /tmp/my-codex/install.sh --profile dev
# Full profile (all 2 installed pack categories enabled)
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

Global Codex settings in `~/.codex/config.toml`:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — Maximum concurrent sub-agents
- `max_depth` — Maximum nesting depth for agent-spawns-agent chains

---

## FAQ

<details>
<summary><strong>How is my-codex different from my-claude?</strong></summary>

Same Boss orchestration, different runtime. my-codex targets OpenAI Codex CLI with the native `.toml` agent format and `spawn_agent` delegation; my-claude targets Claude Code with the `.md` agent format and the Agent tool. my-codex also controls skill exposure through profiles and lanes, where my-claude installs one fixed allowlist.

</details>

<details>
<summary><strong>Can I use both my-codex and my-claude?</strong></summary>

Yes. They install to separate directories (`~/.codex/` and `~/.claude/`). Their installers coordinate codeburn and Headroom through a user-wide lock and state directory at `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services`: a healthy service is reused, and a foreign process on either fixed port is reported without being killed.

</details>

<details>
<summary><strong>How do agent packs work?</strong></summary>

See [Agent Pack Profiles](#agent-pack-profiles).

</details>

<details>
<summary><strong>How does upstream sync work?</strong></summary>

See the **Update Upstream** row under [GitHub Actions](#github-actions). `upstream/archify` is tag-pinned and bumped deliberately, so the job only touches the other 4 submodules; you can also trigger it manually from the Actions tab.

</details>

<details>
<summary><strong>What models does my-codex use?</strong></summary>

See [Model Routing](#model-routing) and [Effort Tiers](#effort-tiers). Skills consume the SKILL.md standard as-is with no transformation; only agents are converted to Codex TOML, and the model tier for that conversion is managed from a single file, `scripts/model-tiers.sh`.

</details>

---

## Troubleshooting

### Skills-only recovery

If a tool reports invalid `SKILL.md` files under `~/.agents/skills/`, the most common cause is a stale local copy or stale symlink target from an older install. Remove the affected directories from `~/.agents/skills/` and matching entries under `~/.claude/skills/`, then reinstall:

```bash
npx skills add sehoon787/my-codex -y -g
```

If you use the full Codex bundle, rerun `install.sh` once as well. The full installer refreshes `~/.codex/skills/` and removes stale my-codex-managed copies under `~/.agents/skills/`.

---

## Contributing

Issues and PRs are welcome. When adding a new agent, add a `.toml` file to `codex-agents/core/` or `codex-agents/omo/` and update the agent list in `SETUP.md`. See [CONTRIBUTING.md](./CONTRIBUTING.md) for PR validation steps and Codex commit attribution behavior.

## Credits

Built on the projects listed in [Open-Source Tools Used](#open-source-tools-used); thank you to every author. Also thanks to [OpenAI Codex CLI](https://github.com/openai/codex), the runtime this harness targets, and [openai/skills](https://github.com/openai/skills), whose `npx skills` CLI installs the skills-only bundle.

## License

MIT License. See the [LICENSE](./LICENSE) file for details.
