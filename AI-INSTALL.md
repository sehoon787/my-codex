# my-codex AI Installation Guide

You are an AI agent setting up a Codex CLI multi-agent orchestration environment.
The bundle includes 319 agents (104 core + 215 domain agent-packs), 108 skills, 50 rules, and 1 MCP server.
Only 2-3 steps are needed.

---

## Step 1: Install agents and assets

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

This installs:
- 104 core agents in `~/.codex/agents/` (always loaded by Codex CLI via `spawn_agent`)
- 215 domain agent-packs in `~/.codex/agent-packs/` (on-demand via symlink)
- 108 skills in `~/.codex/skills/` (from Everything Claude Code)
- 50 rules in project scope (9 common + 8 languages × ~5)
- Global `AGENTS.md` instructions
- `config.toml` with `multi_agent = true`
- 1 MCP server (Context7 — real-time library documentation)

## Step 1b: Manual install (if install.sh unavailable)

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
mkdir -p ~/.codex/agents ~/.codex/agent-packs ~/.codex/skills

# Core agents (always loaded)
cp /tmp/my-codex/codex-agents/core/*.toml ~/.codex/agents/

# Awesome core agents (add to core)
for d in 01-core-development 03-infrastructure 04-quality-security 09-meta-orchestration; do
  cp /tmp/my-codex/codex-agents/awesome/$d/*.toml ~/.codex/agents/ 2>/dev/null
done

# Domain agent-packs (on-demand)
cp -r /tmp/my-codex/codex-agents/agent-packs/* ~/.codex/agent-packs/

# Skills and rules
cp -r /tmp/my-codex/skills/ecc/* ~/.codex/skills/
cp /tmp/my-codex/AGENTS.md ~/.codex/AGENTS.md
cp /tmp/my-codex/config.toml ~/.codex/config.toml

# MCP server
codex mcp add context7 -- npx -y @anthropic/context7-mcp 2>/dev/null || true

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
- Core agents: 100+
- Agent packs: 210+
- Skills: 100+
- AGENTS.md: OK
- config.toml: OK

Setup complete. Multi-agent orchestration is ready.

## Also Available

[![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same agents as Claude Code plugin with Boss meta-orchestrator
