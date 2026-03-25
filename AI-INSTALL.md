# my-codex AI Installation Guide

You are an AI agent setting up a Codex CLI multi-agent orchestration environment.
The bundle installs 444 agent files (80 auto-loaded + 364 agent-packs), 125 skills, and 3 MCP servers.
The repository currently contains 589 TOML definitions from overlapping upstream sources; install-time deduplication reduces that to the final installed footprint.
Only 2-3 steps are needed.

---

## Step 1: Install agents and assets

Direct install:

macOS / Linux / WSL / Git Bash

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/bootstrap.sh | bash
```

Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/sehoon787/my-codex/main/bootstrap.ps1 | iex
```

Manual equivalent:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

This installs:
- 80 auto-loaded agents in `~/.codex/agents/` (always loaded by Codex CLI via `spawn_agent`)
- 364 domain agent-packs in `~/.codex/agent-packs/` (on-demand via symlink)
- 125 skills in `~/.codex/skills/` (from Everything Claude Code)
- Global `AGENTS.md` instructions
- `config.toml` with `multi_agent = true`
- `~/.codex/bin/codex` wrapper plus git hooks for Codex-only commit attribution
- 3 MCP servers (Context7 — real-time library docs, Exa — web search, grep_app — GitHub code search)

Why the numbers are lower than raw source totals:
- Several upstream sources ship the same destination filename.
- `install.sh` merges those sources into `~/.codex/agents/` and category folders under `~/.codex/agent-packs/`.
- When filenames overlap, later copies replace earlier ones. The final installed counts above are the correct verification target.

## Step 1b: Manual install (if install.sh unavailable)

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
mkdir -p ~/.codex/agents ~/.codex/agent-packs ~/.codex/skills

# Core agents (always loaded)
cp /tmp/my-codex/codex-agents/core/*.toml ~/.codex/agents/
cp /tmp/my-codex/codex-agents/omo/*.toml ~/.codex/agents/
cp /tmp/my-codex/codex-agents/omc/*.toml ~/.codex/agents/
cp /tmp/my-codex/codex-agents/awesome-core/*.toml ~/.codex/agents/

# Awesome core categories (add to core)
for d in 01-core-development 03-infrastructure 04-quality-security 09-meta-orchestration; do
  cp /tmp/my-codex/codex-agents/awesome/$d/*.toml ~/.codex/agents/ 2>/dev/null
done

# Domain agent-packs (on-demand)
cp -r /tmp/my-codex/codex-agents/agent-packs/* ~/.codex/agent-packs/

# Agency agents (domain specialists → agent-packs)
for d in /tmp/my-codex/codex-agents/agency/*/; do
  cat_name=$(basename "$d")
  mkdir -p ~/.codex/agent-packs/$cat_name
  cp "$d"*.toml ~/.codex/agent-packs/$cat_name/ 2>/dev/null
done

# Awesome remaining categories → agent-packs
for d in /tmp/my-codex/codex-agents/awesome/*/; do
  cat_name=$(basename "$d")
  case "$cat_name" in 01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration) continue ;; esac
  mkdir -p ~/.codex/agent-packs/$cat_name
  cp "$d"*.toml ~/.codex/agent-packs/$cat_name/ 2>/dev/null
done

# Skills
cp -R /tmp/my-codex/skills/ecc/. ~/.codex/skills/
cp /tmp/my-codex/templates/codex-AGENTS.md ~/.codex/AGENTS.md

# Create config.toml
cat >> ~/.codex/config.toml << 'TOML'
[features]
multi_agent = true
child_agents_md = true

[agents]
max_threads = 8
TOML

# MCP servers (skip names that already exist to avoid re-triggering auth flows)
codex mcp list 2>/dev/null | grep -qE '^context7[[:space:]]' || codex mcp add context7 --url https://mcp.context7.com/mcp 2>/dev/null || true
codex mcp list 2>/dev/null | grep -qE '^exa[[:space:]]' || codex mcp add exa --url "https://mcp.exa.ai/mcp?tools=web_search_exa" 2>/dev/null || true
codex mcp list 2>/dev/null | grep -qE '^grep_app[[:space:]]' || codex mcp add grep_app --url https://mcp.grep.app 2>/dev/null || true

rm -rf /tmp/my-codex
```

## Step 2: Install companion tools (optional)

```bash
# AST tools for code intelligence
npm i -g @ast-grep/cli@0.42.0
```

## Step 3: Activate agent packs (optional)

```bash
# Example: activate marketing agents
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# Example: activate game development agents
ln -s ~/.codex/agent-packs/game-development/*.toml ~/.codex/agents/
```

## Verify

```bash
echo "Core agents:   $(find ~/.codex/agents -name '*.toml' 2>/dev/null | wc -l)"
echo "Agent packs:   $(find ~/.codex/agent-packs -name '*.toml' 2>/dev/null | wc -l)"
echo "Skills:        $(find ~/.codex/skills -name 'SKILL.md' 2>/dev/null | wc -l)"
echo "AGENTS.md:     $(test -f ~/.codex/AGENTS.md && echo 'OK' || echo 'MISSING')"
echo "config.toml:   $(grep -q 'multi_agent' ~/.codex/config.toml 2>/dev/null && echo 'OK' || echo 'NEEDS CONFIG')"
```

Expected:
- Core agents: 80
- Agent packs: 364
- Skills: 125
- AGENTS.md: OK
- config.toml: OK

Setup complete. Multi-agent orchestration is ready.

## Codex Attribution Defaults

Full install also configures a default Codex attribution flow:
- `~/.codex/bin/codex` wraps the real Codex CLI and records which files changed during a Codex session
- `git config --global core.hooksPath ~/.codex/git-hooks` installs `commit-msg` and `post-commit` hooks
- Commits that include recorded Codex-touched files get `🤖 Generated with [Codex CLI](https://github.com/openai/codex)` in the commit body
- commits only receive `AI-Contributed-By: Codex` when staged files overlap that recorded Codex change set
- `my-codex` does not modify `git user.name`, `git user.email`, commit author, or committer identity

Optional `Co-authored-by:` trailer:

```bash
git config --global my-codex.codexContributorName "Pair Programmer"
git config --global my-codex.codexContributorEmail "your-verified-email@example.com"
```

Local git commits cannot attach GitHub's official `@codex` agent identity directly. GitHub only recognizes co-authors when the configured email is linked to a real GitHub account, and no co-author is added unless you opt in with both settings.

Disable attribution entirely:

```bash
git config --global my-codex.codexAttribution false
```

## Skills-Only Alternative

To install only the 125 cross-tool skills exposed by `npx skills add` (no agents, no rules, no config):

```bash
npx skills add sehoon787/my-codex -y -g
```

Installs SKILL.md files to `~/.agents/skills/` and auto-symlinks to Codex CLI, Claude Code, Cursor, and other supported tools. Use this when you only need skills and already have agents configured elsewhere. The full `install.sh` bundle still installs 125 skills into `~/.codex/skills/`.

## Also Available

[![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same agents as Claude Code plugin with Boss meta-orchestrator
