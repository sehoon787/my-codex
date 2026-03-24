# Contributing to my-codex

Thank you for contributing. This guide covers how to author agents for Codex CLI, meet quality standards, and submit pull requests.

---

## Repository Structure

```
codex-agents/
  core/                   # Core agents — always loaded
  awesome/                # awesome-codex-subagents-sourced agents
  agent-packs/
    {category}/           # Domain agent packs — on-demand
skills/                   # Skill workflows
rules/                    # Coding and workflow rules
```

### Upstream Sources

This repository aggregates agents from four upstream sources:

| Source | Origin | Format |
|--------|--------|--------|
| `agency` | agency-agents (domain agents, MD converted to TOML) | TOML |
| `ecc` | everything-claude-code (skills and rules) | MD |
| `omx` | oh-my-codex (CLI runtime, skills, hooks, HUD — no agent files) | N/A |
| `awesome` | awesome-codex-subagents (native TOML agents) | TOML |

New contributions that originate from this repository go into `codex-agents/core/` (infrastructure) or `codex-agents/agent-packs/{category}/` (domain).

---

## Authoring Agents

### File Format

Agents are TOML files.

**Required fields:**

```toml
name = "my-agent-name"
description = "Use when a task needs X in order to Y."
developer_instructions = """
[Agent instructions here]
"""
```

**Optional fields:**

| Field | Values | Notes |
|-------|--------|-------|
| `model` | `"gpt-5.4"`, `"o4-mini"` | Defaults to `gpt-5.4` if omitted |
| `model_reasoning_effort` | `"high"`, `"medium"`, `"low"` | Applies when model supports reasoning |
| `sandbox_mode` | `"read-only"`, `"workspace-write"` | Use `read-only` for reviewers; `workspace-write` for implementers |
| `nickname_candidates` | array of strings | Short invocation aliases |

**Model guidance:**

| Model | Use For |
|-------|---------|
| `gpt-5.4` | Standard development work, analysis, orchestration |
| `o4-mini` | Fast lookups, lightweight agents, frequent invocation |

**Sandbox mode guidance:**

- `read-only`: Agents that analyze, review, or audit without modifying files
- `workspace-write`: Agents that implement, generate, or modify files

### File Location

- Core/infrastructure agents: `codex-agents/core/{name}.toml`
- Domain agents: `codex-agents/agent-packs/{category}/{name}.toml`
- File name must match the `name` field: `security-reviewer.toml` for `name = "security-reviewer"`

### developer_instructions Structure

Instructions should be task-shaped, not persona-shaped. A well-structured `developer_instructions` block includes:

```toml
developer_instructions = """
[Brief role statement — what this agent owns and why it exists]

Working mode:
1. [First step]
2. [Second step]
3. ...

Focus on:
- [Key area]
- [Key area]

Quality checks:
- verify [criterion]
- confirm [criterion]

Return:
- [What the agent produces and in what format]
"""
```

### Quality Bar

**Descriptions must:**
- Start with "Use when..." followed by a concrete trigger condition
- Name the specific task, not the general domain
- Be one sentence

**developer_instructions must:**
- Be task-shaped, not persona-shaped
- State what the agent does, not just what role it plays
- Include working mode steps, focus areas, and quality checks
- Avoid phrases like "You are a helpful assistant who..."
- Avoid assuming capabilities or tools not available in Codex CLI

**High signal-to-noise:** Remove any instruction that does not change behavior. If a line could be deleted without affecting output, delete it.

---

## Naming Conventions

- Agent names: kebab-case (`security-reviewer`, `backend-architect`)
- File names: `{name}.toml` matching the `name` field exactly
- Category directories: lowercase with hyphens (`game-development`, `paid-media`, `data-ai`)

---

## Pull Request Process

1. **One agent per PR** is preferred. Multiple agents are acceptable when they form a cohesive domain pack.
2. **PR body must include:**
   - The use case that motivated the contribution
   - The agent name and target directory
   - Confirmation that the name is unique across the repository
3. **README updates:** Add the agent to the relevant category table in `README.md` if applicable.
4. **Verify TOML syntax** before submitting. Run `python3 -c "import tomllib; tomllib.load(open('yourfile.toml','rb'))"` or any TOML validator to confirm the file parses without errors.

### Commit Message Format

Follow conventional commits:

```
feat: add security-reviewer agent for pre-commit analysis
fix: correct sandbox_mode in backend-architect.toml
docs: update README table for engineering agents
```

Types: `feat` for new agents/skills, `fix` for corrections, `docs` for documentation updates, `refactor` for restructuring without behavior change.

If you work through an installed my-codex environment, Codex-authored commits may automatically include:

- `🤖 Generated with [Codex CLI](https://github.com/openai/codex)`
- `AI-Contributed-By: Codex`
- optional `Co-authored-by: Codex <...>` if you configured `my-codex.codexContributorEmail`

This is expected.

---

## Pre-submission Checklist

- [ ] TOML parses correctly (no syntax errors)
- [ ] `name` field is unique across all agents in the repository
- [ ] File name matches the `name` field
- [ ] Description starts with "Use when..." and names a concrete trigger
- [ ] `developer_instructions` follows task-shaped structure (working mode, focus areas, quality checks, return spec)
- [ ] No generic roleplay language ("You are a helpful...")
- [ ] `sandbox_mode` is appropriate for the agent's function (`read-only` for reviewers, `workspace-write` for implementers)
- [ ] `model` and `model_reasoning_effort` are appropriate for the agent's workload
- [ ] File is in the correct directory (`core/` vs `agent-packs/{category}/`)
- [ ] README category table updated if applicable
- [ ] PR body describes the use case
- [ ] If Codex authored the change, the PR notes whether commit attribution markers are expected
