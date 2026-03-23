# my-codex

Multi-agent orchestration for OpenAI Codex CLI — 319 agents, 136+ skills, 50 rules.

## Overview

my-codex brings a curated multi-agent system to OpenAI Codex CLI. 104 core agents are always available, 215 domain agent-packs can be activated on demand, and 136+ workflow skills provide structured methodologies for complex development tasks.

Built from 5 upstream sources: [agency-agents](https://github.com/msitarzewski/agency-agents), [everything-claude-code](https://github.com/affaan-m/everything-claude-code), [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex), and [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents).

## Quick Install

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Or for AI agents:
```bash
curl -s https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md
```

## What Gets Installed

| Component | Count | Location |
|-----------|-------|----------|
| Core Agents | 104 | ~/.codex/agents/ |
| Agent Packs | 215 | ~/.codex/agent-packs/ |
| Skills | 136+ | ~/.codex/skills/ |
| AGENTS.md | 1 | ~/.codex/AGENTS.md |
| OMX CLI | 1 | global npm |

## Core Agents (Always Loaded)

These 52 agents are installed to `~/.codex/agents/` and automatically available in every Codex session:

### Orchestration (9 agents)
atlas, hephaestus, metis, momus, oracle, prometheus, sisyphus, librarian, multimodal-looker

### Development (19 agents)
executor, architect, planner, debugger, code-reviewer, code-simplifier, critic, designer, document-specialist, explore, git-master, qa-tester, scientist, security-reviewer, test-engineer, tracer, verifier, writer, analyst

### Engineering (24 agents)
AI Engineer, Backend Architect, Blockchain Security Auditor, Data Engineer, Database Optimizer, DevOps Automator, Embedded Firmware Engineer, Frontend Developer, Incident Response Commander, Infrastructure Maintainer, LSP/Index Engineer, MCP Builder, Performance Benchmarker, Rapid Prototyper, Security Engineer, Senior Developer, Solidity Smart Contract Engineer, SRE, Terminal Integration Specialist, Threat Detection Engineer, visionOS Spatial Engineer, macOS Spatial/Metal Engineer, WeChat Mini Program Developer, Feishu Integration Developer

## Agent Packs (On-Demand)

133 domain agents across 12 categories. Activate with symlinks:

```bash
# Activate a specific pack
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# Deactivate
rm ~/.codex/agents/marketing-*.toml
```

| Pack | Agents | Description |
|------|--------|-------------|
| academic | 5 | Study abroad, corporate training, etc. |
| design | 8 | UI/UX, visual storytelling, brand, etc. |
| game-development | 20 | Unity, Unreal, Godot, Roblox, Blender |
| marketing | 15 | SEO, social media, content, Douyin, Xiaohongshu |
| paid-media | 10 | PPC, programmatic, ad creative |
| product | 10 | Product management, UX research, analytics |
| project-management | 8 | Agile, Jira, workflows |
| sales | 10 | Deal strategy, pipeline, outbound |
| spatial-computing | 3 | XR, WebXR, AR/VR |
| specialized | 20 | Legal, finance, compliance, healthcare, etc. |
| support | 5 | Customer support, developer advocacy |
| testing | 5 | QA, test analysis, API testing |

## Skills

136+ workflow skills for structured development methodologies. Use with `$name` syntax:

- `$autopilot` — Autonomous execution mode
- `$ralph` — Persistent execution loop
- `$team` — Multi-agent team orchestration
- `$tdd` — Test-driven development
- `$code-review` — Structured code review
- `$security-review` — Security analysis
- `$trace` — Evidence-driven debugging
- `$ultrawork` — Deep work mode

## Multi-Agent Usage

```
> Spawn 3 agents: one to refactor auth, one to add tests, one to review security
```

Codex will use `spawn_agent` to create specialized sub-agents from your installed roster.

## Upstream Sources

| Source | What | Sync |
|--------|------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | 156 domain agents | Weekly CI |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 108 skills, 50 rules | Weekly CI |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 19 agents, 28 skills | Weekly CI |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | Codex-native prompts | Weekly CI |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | 136 native TOML agents | Weekly CI |

## Also Available

**Claude Code users**: See [my-claude](https://github.com/sehoon787/my-claude) for the Claude Code version with plugin marketplace support.

## License

MIT
