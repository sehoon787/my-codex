# my-codex — Multi-Agent Orchestration for Codex CLI

You are running with my-codex, a multi-agent orchestration layer for OpenAI Codex CLI.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

## Default Agent

When starting a new session, always use the **boss** agent as the primary orchestrator.
Boss discovers available agents, classifies user intent, and delegates to the best specialist.
Do not bypass Boss for direct implementation unless the user explicitly requests a specific agent.

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

Use `spawn_agent` with `agent_type` to delegate work. Tier priority when several match: core > omo > omx > opt-in packs.

| Agent | Tier | Purpose | When to Use |
|-------|------|---------|-------------|
| boss | core | Meta-orchestration | Default entry point for any non-trivial request |
| sisyphus | omo | Multi-step orchestration | No plan yet; needs delegation and verification to completion |
| atlas | omo | Plan execution | A plan already exists; each step needs delegating and tracking |
| hephaestus | omo | Autonomous execution | One agent should finish the task end-to-end, no check-ins |
| prometheus | omo | Plan generation | Interview-driven markdown work plan before any code |
| oracle | omo | Deep advisory (read-only) | Architecture decisions, stuck bugs |
| metis | omo | Pre-planning intent analysis | Request may be ambiguous or over-scoped |
| momus | omo | Plan review (read-only) | Check a finished plan for blockers |
| librarian | omo | Open-source source lookup | Library answers backed by GitHub permalinks |
| multimodal-looker | omo | Media reading (read-only) | Images, PDFs, diagrams, screenshots |
| executor | omx | Code implementation | Writing/modifying code |
| architect | omx | System design | Architectural decisions |
| planner | omx | Implementation planning | Complex features |
| debugger | omx | Root cause analysis | Bug investigation |
| code-reviewer | omx | Code review | After writing code |
| security-reviewer | omx | Security analysis | Before commits |
| test-engineer | omx | Test strategy | Test creation, coverage |

Agent packs (data-ai, llmops) are installed but inactive by default — enable the smallest matching pack with `~/.codex/bin/my-codex-packs enable <pack>` before delegating to one.

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
- `$test-driven-development` — test-driven development discipline (superpowers)
- `/review` — structured code review (gstack)
- `/cso` — security audit and threat modeling (gstack)
- `/investigate` — evidence-driven bug root cause investigation (gstack)

Codex CLI 0.128.0+ ships a native `/goal` command (single-thread objective + token budget, self-audited completion) behind the experimental `goals` feature flag, which is off by default (enable with `codex features enable goals`). It has no `codex exec`/CLI equivalent, so Boss and gstack-sprint cannot invoke it as an automated pipeline step. Use `/goal` for simple ad-hoc interactive persistence in a single session; use `$ralph` when you need fresh-context restarts, external architect/critic verification, or orchestration by Boss/gstack-sprint.

## Research & Reuse (mandatory before new implementation)
1. Search GitHub for existing implementations first
2. Check library docs for API behavior
3. Prefer battle-tested libraries over hand-rolled solutions
