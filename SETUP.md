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

- **Node.js** v20+
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
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

What gets installed:

| Destination | Contents |
|---|---|
| `~/.codex/agents/` | 80 unique agents (37 core + 54 awesome core, deduplicated) |
| `~/.codex/agent-packs/` | 364 on-demand pack files after upstream overlap is deduplicated during install |
| `~/.codex/skills/` | 125 skills |
| `~/.codex/AGENTS.md` | Agent catalog and routing instructions |
| `~/.codex/config.toml` | `multi_agent = true` + model defaults |
| `~/.codex/git-hooks/` | `commit-msg` + `post-commit` hooks for Codex attribution |
| `~/.codex/bin/codex` | Wrapper that records Codex-touched files for commit attribution |
| `~/.codex/.mcp.json` | 3 MCP servers: context7, exa, grep_app |

---

## 3. Verify Installation

```bash
echo "Core agents:  $(find ~/.codex/agents -name '*.toml' | wc -l)"
echo "Agent packs:  $(find ~/.codex/agent-packs -name '*.toml' | wc -l)"
echo "Skills:       $(find ~/.codex/skills -name 'SKILL.md' | wc -l)"
echo "AGENTS.md:    $(test -f ~/.codex/AGENTS.md && echo OK || echo MISSING)"
echo "config.toml:  $(grep -q multi_agent ~/.codex/config.toml && echo OK || echo MISSING)"
```

Expected output:
```
Core agents:  80
Agent packs:  364
Skills:       125
AGENTS.md:    OK
config.toml:  OK
```

Note: the repository contains more raw TOML files than the final installed counts. `install.sh` verifies the installed footprint above, not the pre-deduped source totals.

---

## 4. Codex Attribution

Full install enables Codex-aware commit attribution by default:

- `~/.codex/bin/codex` wraps the real Codex CLI
- the wrapper records files changed during each Codex session inside the current git repo
- Codex-authored commits get `🤖 Generated with [Codex CLI](https://github.com/openai/codex)` in the commit body
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

Agent packs are stored in `~/.codex/agent-packs/` and activated via symlink.

```bash
# List available packs
ls ~/.codex/agent-packs/

# Activate a pack (e.g., marketing)
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# Deactivate a specific agent
rm ~/.codex/agents/<agent-name>.toml
```

Available packs and agent counts:

| Pack | Agents |
|---|---|
| engineering | 32 |
| marketing | 27 |
| language-specialists | 27 |
| specialized | 31 |
| game-development | 20 |
| infrastructure | 19 |
| developer-experience | 13 |
| data-ai | 13 |
| specialized-domains | 12 |
| design | 11 |
| business-product | 11 |
| testing | 11 |
| sales | 8 |
| paid-media | 7 |
| research-analysis | 7 |
| project-management | 6 |
| spatial-computing | 6 |
| support | 6 |
| academic | 5 |
| product | 5 |
| security | 5 |

---

## 6. MCP Server Configuration

Three MCP servers are registered in `~/.codex/.mcp.json`:

| Server | Purpose |
|---|---|
| **context7** | Library documentation lookup |
| **exa** | Neural web search |
| **grep_app** | GitHub code search |

Verify MCP servers are registered:
```bash
codex mcp list
```

If a server is missing, re-run `install.sh` or add it manually:
```bash
codex mcp add context7 -- npx -y @upstash/context7-mcp
codex mcp add exa -- npx -y exa-mcp-server
codex mcp add grep_app -- npx -y @modelcontextprotocol/server-grep-app
```

---

## 7. Model Understanding

Codex CLI uses OpenAI reasoning models. Route tasks by complexity:

| Model | Reasoning Effort | Use For |
|---|---|---|
| o3 (high) | Deep | Architecture, complex analysis, security review |
| o3 (medium) | Standard | Implementation, code review, debugging |
| o4-mini (low) | Fast | Quick lookups, exploration, trivial changes |

Set default model in `~/.codex/config.toml`:
```toml
model = "o3"
model_reasoning_effort = "medium"
multi_agent = true
```

Override per-session:
```bash
codex --model o3 --reasoning-effort high "Design the auth system"
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
1. Use architect to design the approach (spawn with model=o3, effort=high)
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
# Should be 80+
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
codex mcp add context7 -- npx -y @upstash/context7-mcp
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
