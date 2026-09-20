# Codex CLI Multi-Agent Orchestration — Full Setup Guide

Give this document to an AI coding agent to reproduce the exact same environment.

> **Version Note (2026-03):** This guide was last verified in March 2026.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install my-codex](#2-install-my-codex)
3. [Verify Installation](#3-verify-installation)
4. [Codex Attribution](#4-codex-attribution)
5. [Agent Packs Activation](#5-agent-packs-activation)
6. [MCP Server Configuration](#6-mcp-server-configuration)
7. [Model Understanding](#7-model-understanding)
8. [Multi-Agent Workflow Examples](#8-multi-agent-workflow-examples)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

- **Node.js** v22.13+ (required by codeburn)
- **npm**
- **Git**
- **Codex CLI** — install from [https://github.com/openai/codex](https://github.com/openai/codex) or:
  ```bash
  npm i -g @openai/codex
  ```
- **OpenAI API key** — set `OPENAI_API_KEY` in your environment

Verify Codex is installed:
```bash
codex --version
```

---

## 2. Install my-codex

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

Clone-based install also works:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

What gets installed:

| Destination | Contents |
|---|---|
| `~/.codex/agents/` | 17 core agents (Boss 1 + OMO 9 + OMX 7), deduplicated by tier |
| `~/.codex/agent-packs/` | 17 opt-in pack agents across 2 packs (data-ai 13, llmops 4) |
| `~/.codex/skills/` | 106 skills (ECC 61 + gstack 27 + superpowers 13 + core 4 + archify 1) |
| `~/.codex/AGENTS.md` | Agent catalog and routing instructions |
| `~/.codex/enabled-agent-packs.txt` | Persisted active pack set; first install writes an empty set (packs are opt-in) |
| `~/.codex/enabled-skill-lanes.txt` | Persisted optional skill lanes; first install writes an empty set (default lane only) |
| `~/.codex/config.toml` | `multi_agent = true`, `hooks = true` under `[features]`, + model defaults |
| `~/.codex/hooks.json` | Lifecycle hook registry — Codex reads it only from this path, not from `hooks/` |
| `~/.codex/hooks/` | Hook scripts referenced by `hooks.json` |
| `~/.codex/git-hooks/` | `prepare-commit-msg` + `commit-msg` + `post-commit` hooks for Codex attribution |
| `~/.codex/bin/codex` | Wrapper that records Codex-touched files for commit attribution |
| MCP servers | 5 servers: context7, exa, grep_app via `codex mcp add`; serena and headroom as `[mcp_servers.*]` tables in `config.toml` |

---

## 3. Verify Installation

```bash
echo "Core agents:  $(find ~/.codex/agents -maxdepth 1 -type f -name '*.toml' | wc -l)"
echo "Active packs: $(find ~/.codex/agents -maxdepth 1 -type l -name '*.toml' | wc -l)"
echo "Agent packs:  $(find ~/.codex/agent-packs -name '*.toml' | wc -l)"
echo "Skills:       $(find ~/.codex/skills -name 'SKILL.md' | wc -l)"
echo "AGENTS.md:    $(test -f ~/.codex/AGENTS.md && echo OK || echo MISSING)"
echo "config.toml:  $(grep -q multi_agent ~/.codex/config.toml && echo OK || echo MISSING)"
echo "hooks.json:   $(test -f ~/.codex/hooks.json && echo OK || echo MISSING)"
echo "Enabled set:  $(grep -Ev '^(#|$)' ~/.codex/enabled-agent-packs.txt | paste -sd ', ' -)"
```

Expected output:
```
Core agents:  17
Active packs: 0
Agent packs:  17
Skills:       105
AGENTS.md:    OK
config.toml:  OK
hooks.json:   OK
```

Hooks note: `install.sh` sets `hooks = true` under `[features]` in `config.toml` and writes the registry to `~/.codex/hooks.json`. Codex asks once, on your next interactive start, to review and trust these hooks — choose "Trust all and continue". Until you do, no my-codex hook runs.

Note: agents and skills come from curated allowlists (`scripts/skill-allowlists.sh`), not bulk copies. `install.sh` verifies the installed footprint above.

### Optional skill lanes

Every installed skill costs context in every session — Codex truncates skill descriptions once its skills budget is exceeded. The 18 web/UI front-end skills (React, Vue, Nuxt, Nest, motion, a11y, E2E) are therefore a separate lane that is **off by default**:

```bash
bash install.sh --skills=web     # add the web/UI lane
bash install.sh --full-skills    # add every optional lane
bash install.sh --skills=none    # back to the default 105
```

The choice is written to `~/.codex/enabled-skill-lanes.txt`, so later `install.sh` runs keep it without repeating the flag. `MY_CODEX_SKILLS=web` does the same for a one-off non-interactive install. Turning a lane off removes its skills through the install manifest; lane cleanup does not remove skills you created yourself in `~/.codex/skills/`.

Skill instructions and harness messages are authored in English. Installation
applies maintained translations to known `SKILL.md` text after upstream
generation; the same step runs on reinstall. Each changed original version is backed up under
`~/.codex/backups/english-skill-originals`. This does not change the language of
your requests or the assistant's replies. The normalizer preserves external
symlink targets and reports remaining CJK text. Localized documentation and
language-processing fixtures remain available separately.

The gstack checkout lives in `~/.codex/vendor/gstack`, outside recursive skill
discovery. The installer keeps the runtime entry points and supported skill
names under `~/.codex/skills`, without exposing upstream test fixtures. A large
remaining skill catalog can still cause Codex to shorten descriptions.

---

## 4. Codex Attribution

Full install enables Codex-aware commit attribution by default:

- `~/.codex/bin/codex` wraps the real Codex CLI
- the wrapper records files changed during each Codex session inside the current git repo
- `prepare-commit-msg` adds `Generated with Codex CLI: https://github.com/openai/codex` to Codex-authored commits
- Codex-authored commits get `Generated with Codex CLI: https://github.com/openai/codex` in the commit message
- `commit-msg` adds `AI-Contributed-By: Codex` only when the commit stages one of those files
- `post-commit` clears the marker so unrelated commits are not tagged

Optional Claude-style `Co-authored-by:` trailer:

```bash
git config --global my-codex.codexContributorEmail "your-verified-email@example.com"
```

Local git commits cannot attach GitHub's official `@codex` agent identity directly. GitHub only shows Codex as a co-author/contributor identity when that email is linked to an actual GitHub account.

Disable attribution:

```bash
git config --global my-codex.codexAttribution false
```

---

## 5. Agent Packs Activation

Agent packs are stored in `~/.codex/agent-packs/`. **No pack is enabled on install** — the empty set is persisted in `~/.codex/enabled-agent-packs.txt`, and re-running `install.sh` rehydrates the symlinks from that file. Packs stay opt-in so the core registry of 17 agents is what Boss discovers by default; enable a pack only when a task needs its specialists.

```bash
# Inspect current state
~/.codex/bin/my-codex-packs status

# Enable a pack immediately
~/.codex/bin/my-codex-packs enable data-ai

# Switch profiles during install
bash /tmp/my-codex/install.sh --profile minimal   # no packs (default)
bash /tmp/my-codex/install.sh --profile dev       # data-ai + llmops
bash /tmp/my-codex/install.sh --profile full      # all installed packs
```

Available packs and agent counts (vendored from awesome-codex-subagents, MIT):

| Pack | Agents |
|---|---|
| data-ai | 13 |
| llmops | 4 |

---

## 6. MCP Server Configuration

Five MCP servers are registered. The three hosted ones go through `codex mcp add`; the two stdio ones are written into `~/.codex/config.toml` as tables, because `codex mcp add` has no flag for `startup_timeout_sec` and Serena's first launch needs one.

| Server | Purpose | Registered as |
|---|---|---|
| **context7** | Library documentation lookup | `codex mcp add --url` |
| **exa** | Neural web search | `codex mcp add --url` |
| **grep_app** | GitHub code search | `codex mcp add --url` |
| **serena** | Symbol-level code navigation and editing | `[mcp_servers.serena]` (stdio, `serena start-mcp-server`) |
| **headroom** | Context compression (`headroom_compress` / `headroom_retrieve` / `headroom_stats`) | `[mcp_servers.headroom]` (stdio, `headroom mcp serve`) |

Serena and Headroom are Python tools installed with `uv tool install --python 3.13` (`serena-agent==1.7.0`, `headroom-ai[all]==0.37.0`). `install.sh` installs `uv` first if it is missing; if that fails, the install still completes and the two servers start working once `uv` is available.

Verify MCP servers are registered:
```bash
codex mcp list
grep -E '^\[mcp_servers\.' ~/.codex/config.toml
```

If a server is missing, re-run `install.sh` or add it manually:
```bash
codex mcp add context7 --url https://mcp.context7.com/mcp
codex mcp add exa --url "https://mcp.exa.ai/mcp?tools=web_search_exa"
codex mcp add grep_app --url https://mcp.grep.app
```

---

## 7. Model Understanding

Codex CLI uses OpenAI reasoning models. Route tasks by complexity:

| Model | Reasoning Effort | Use For |
|---|---|---|
| gpt-6-astra (high) | Deep | Architecture, complex analysis, security review |
| gpt-5.6-sol (medium) | Standard | Implementation, code review, debugging |
| gpt-5.6-terra (low) | Light | Quick lookups, exploration, trivial changes |

Set default model in `~/.codex/config.toml`:
```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "medium"
multi_agent = true
```

Override per-session:
```bash
codex --model gpt-6-astra --reasoning-effort high "Design the auth system"
```

---

## 8. Multi-Agent Workflow Examples

### Single Agent

```bash
codex "Fix the null pointer exception in src/auth.ts"
```

### Spawn Parallel Agents

```
You are the boss agent. Spawn 3 agents in parallel:
1. Agent 1 (executor): Implement the login endpoint
2. Agent 2 (test-engineer): Write tests for the login flow
3. Agent 3 (security-reviewer): Review auth for vulnerabilities
Wait for all to complete, then synthesize results.
```

### Parent-Child Orchestration

```
You are planner. Break this feature into tasks, then spawn an executor
agent for each independent task. Verify each result before proceeding
to dependent tasks.
```

### Complex Orchestration

```
You are boss. The goal is to add OAuth2 support.
1. Use architect to design the approach (spawn with model=gpt-6-astra, effort=high)
2. Use planner to create task breakdown
3. Spawn executor agents for each implementation task (parallel where safe)
4. Use code-reviewer to review all changes
5. Use test-engineer to add test coverage
6. Report final status
```

---

## 9. Troubleshooting

**"No agents found" or agent not recognized**
```bash
# Verify agents exist
ls ~/.codex/agents/*.toml | wc -l
# Should be 17 (plus one symlink per enabled pack agent)
```

**`spawn_agent` fails**
```bash
# Verify multi_agent is enabled
grep multi_agent ~/.codex/config.toml
# Must show: multi_agent = true
```

**MCP tool timeout or not available**
```bash
# Check registered servers
codex mcp list
# Re-add if missing
codex mcp add context7 --url https://mcp.context7.com/mcp
```

**Agent ignores instructions**

Ensure `AGENTS.md` is present — Codex auto-loads it as system context:
```bash
test -f ~/.codex/AGENTS.md && echo OK || echo MISSING
```

**Install script fails**

Run with debug output:
```bash
bash -x /tmp/my-codex/install.sh 2>&1 | head -50
```

**Reset to clean state**

```bash
rm -rf ~/.codex/agents ~/.codex/agent-packs ~/.codex/skills
bash /tmp/my-codex/install.sh
```
