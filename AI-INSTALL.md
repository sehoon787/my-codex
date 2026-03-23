# my-codex AI Installation Guide

You are an AI agent setting up a Codex CLI multi-agent orchestration environment.
The bundle includes 319 agents, 130+ skills, 50+ rules, and 3 MCP servers.

---

## Step 1: Install agents and assets

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

This installs:
- Core agents in ~/.codex/agents/ (always loaded by Codex)
- Domain agent-packs in ~/.codex/agent-packs/ (on-demand via symlink)
- Skills in ~/.codex/skills/
- Rules in project scope
- Global AGENTS.md instructions
- OMX CLI (oh-my-codex) for team orchestration
- 3 MCP servers (Context7, Exa, grep.app)

## Step 2: Install companion tools (optional)

```bash
# OMX CLI for team features
npm i -g oh-my-codex && omx setup

# AST tools
npm i -g @ast-grep/cli@0.42.0
```

## Step 3: Activate agent packs (optional)

```bash
# Example: activate marketing agents
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/
```

## Verify

```bash
echo "Core agents:   $(find ~/.codex/agents -name '*.toml' 2>/dev/null | wc -l)"
echo "Agent packs:   $(find ~/.codex/agent-packs -name '*.toml' 2>/dev/null | wc -l)"
echo "Skills:        $(find ~/.codex/skills -name 'SKILL.md' 2>/dev/null | wc -l)"
echo "AGENTS.md:     $(test -f ~/.codex/AGENTS.md && echo 'OK' || echo 'MISSING')"
echo "omx:           $(command -v omx >/dev/null 2>&1 && echo 'OK' || echo 'MISSING')"
```

Expected:
- Core agents: 100+
- Agent packs: 210+
- Skills: 130+
- AGENTS.md: OK

Setup complete. Multi-agent orchestration is ready.

## Also Available

- **Claude Code users**: See [my-claude](https://github.com/sehoon787/my-claude)
