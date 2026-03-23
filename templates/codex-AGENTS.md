# my-codex — Multi-Agent Orchestration for Codex CLI

You are running with my-codex, a multi-agent orchestration layer for OpenAI Codex CLI.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

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
