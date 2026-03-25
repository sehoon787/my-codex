# my-codex — Multi-Agent Orchestration for Codex CLI

You are running with my-codex, a multi-agent orchestration layer for OpenAI Codex CLI.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

## Boss-First Routing (Default Behavior)

Before executing any task, first scan `~/.codex/agents/*.toml` to discover active specialists and `~/.codex/agent-packs/*/*.toml` to discover installed-but-inactive specialists. For any non-trivial request (multi-file changes, architecture decisions, debugging, refactoring, code review, or unfamiliar domains), route through the Boss meta-orchestrator:

```
spawn_agent(prompt="<user's full request>", agent_type="boss")
```

Boss will classify intent, match the task to the optimal specialist from the discovered registry, delegate with structured prompts, and verify results independently. Only handle trivial single-command tasks (ls, git status, simple questions) directly. If the best specialist is installed only in an inactive pack, activate the smallest matching pack with `~/.codex/bin/my-codex-packs enable <pack>` before delegating.

## Operating Principles
- Delegate specialized work to the most appropriate agent via spawn_agent
- Prefer evidence over assumptions: verify outcomes before final claims
- Choose the lightest-weight path that preserves quality
- Consult official docs before implementing with SDKs/frameworks/APIs

## Available Agents

Use `spawn_agent` with `agent_type` to delegate work:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| executor | Code implementation | Writing/modifying code |
| architect | System design | Architectural decisions |
| planner | Implementation planning | Complex features |
| debugger | Root cause analysis | Bug investigation |
| code-reviewer | Code review | After writing code |
| security-reviewer | Security analysis | Before commits |
| test-engineer | Test strategy | Test creation, coverage |
| explorer | Codebase search | Finding files, understanding code |

## Multi-Agent Workflow

For complex tasks:
1. Spawn a planner agent for analysis
2. Spawn executor agents (parallel) for implementation
3. Spawn code-reviewer for verification
4. Fix issues and confirm tests pass

## Working Agreements
- Run tests after modifying code
- Prefer existing libraries over hand-rolled solutions
- Write minimal code that solves the problem
- Handle errors explicitly at every level
- No hardcoded secrets in source code
- Immutable data patterns preferred
- Small files (200-400 lines), small functions (<50 lines)
- When editing files in a git repository, run `codex-mark-used <path>` before the first write for each file you materially modify so commit attribution only applies to real Codex-authored changes

## Skills

Invoke skills with `$name` syntax:
- `$autopilot` — autonomous execution mode
- `$ralph` — persistent execution loop
- `$ultrawork` — deep work mode
- `$team` — multi-agent team orchestration
- `$tdd` — test-driven development
- `$code-review` — structured code review
- `$security-review` — security analysis
- `$trace` — evidence-driven debugging

## Research & Reuse (mandatory before new implementation)
1. Search GitHub for existing implementations first
2. Check library docs for API behavior
3. Prefer battle-tested libraries over hand-rolled solutions
