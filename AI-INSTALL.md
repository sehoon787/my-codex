# my-codex AI Installation Guide

You are an AI agent setting up a Codex CLI multi-agent orchestration environment.
The bundle includes 444 agents (80 auto-loaded + 364 agent-packs), 125 skills, and 3 MCP servers.
Only 2-3 steps are needed.

---

## Step 1: Install agents and assets

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

This installs:
- ~91 core agents in `~/.codex/agents/` (always loaded by Codex CLI via `spawn_agent`)
- ~498 domain agent-packs in `~/.codex/agent-packs/` (on-demand via symlink)
- 125 skills in `~/.codex/skills/` (from Everything Claude Code)
- Global `AGENTS.md` instructions
- `config.toml` with `multi_agent = true`
- 3 MCP servers (Context7 — real-time library docs, Exa — web search, grep_app — GitHub code search)

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
cp -r /tmp/my-codex/skills/ecc/* ~/.codex/skills/
cp /tmp/my-codex/templates/codex-AGENTS.md ~/.codex/AGENTS.md

# Create config.toml
cat >> ~/.codex/config.toml << 'TOML'
[features]
multi_agent = true
child_agents_md = true

[agents]
max_threads = 8
TOML

# MCP servers
codex mcp add context7  --url https://mcp.context7.com/mcp 2>/dev/null || true
codex mcp add exa       --url "https://mcp.exa.ai/mcp?tools=web_search_exa" 2>/dev/null || true
codex mcp add grep_app  --url https://mcp.grep.app 2>/dev/null || true

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
- Core agents: 90+
- Agent packs: 490+
- Skills: 95+
- AGENTS.md: OK
- config.toml: OK

Setup complete. Multi-agent orchestration is ready.

## Also Available

[![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same agents as Claude Code plugin with Boss meta-orchestrator
