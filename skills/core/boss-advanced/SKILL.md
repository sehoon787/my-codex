---
name: boss-advanced
description: Advanced Boss orchestration patterns — Agent Teams leadership, 6-section delegation template, Skill vs Agent conflict resolution, Guardian pattern, and AI-slop detection.
user-invocable: false
---

# Boss Advanced Orchestration Patterns

## Skill vs Agent Conflict Resolution

When both a skill and an agent could handle the request, evaluate three dimensions:

| Dimension | -> Skill | -> Agent |
|-----------|---------|---------|
| **Scope** | Narrow (single file/function/document) | Wide (multi-file, project-wide, cross-module) |
| **Depth** (weighted 2x) | Shallow (template, format, generate, lookup) | Deep (analyze patterns, trace dependencies, investigate, reason about code) |
| **Interactivity** | One-shot (produce output, done) | Iterative (explore -> decide -> act -> verify) |

**Scoring:** Depth counts double. Tally: Skill-points vs Agent-points (max 4). Higher score wins.
- Scope->Skill = 1pt, Depth->Skill = 2pt, Interactivity->Skill = 1pt -> Skill total
- Scope->Agent = 1pt, Depth->Agent = 2pt, Interactivity->Agent = 1pt -> Agent total
- Tie -> ask the user one clarifying question

**Special cases:**
- **File-format deliverable** (the output IS a pdf/docx/xlsx/pptx) -> Skill always wins, regardless of dimensions
- **Methodology + implementation** (e.g. "TDD로 이 기능 구현해줘") -> Skill inside Agent — skill provides methodology, agent executes
- **Chained routing** — when a task requires two distinct steps handled by different capabilities (e.g. "PDF 읽고 보안 분석해줘"), Boss orchestrates as P3a: step 1 (Skill or Agent) -> step 2 (Skill or Agent), each matched independently
- **Ambiguous scope** -> ask the user one clarifying question rather than guessing
- **No candidate exists** -> skip to next Priority level, never force-match a nonexistent skill/agent

---

## Multi-Agent Decision Flowchart

When a task requires multiple agents, use this 2-step decision tree:

```
Q1. Are the subtasks fully independent? (no file overlap)
    |
    +- YES -> Priority 3a (Boss direct parallel) or 3b (delegate to sisyphus)
    |
    +- NO (shared files, common types/utilities, etc.)
        |
        Q2. Is inter-agent communication needed? (feedback, review, cross-referencing)
            |
            +- YES -> Priority 3c-DIRECT (Agent Teams, peer-to-peer SendMessage)
            |
            +- NO  -> Priority 3b (delegate to one sisyphus, handled sequentially internally)
```

---

## Priority 3a: Boss Direct Orchestration (Mid-sized tasks)

When 2-4 agents are needed and dependencies are simple:
- Boss spawns agents directly (parallel where independent, sequential where dependent)
- No sub-orchestrator overhead
- Boss verifies each result directly

Criteria: task can be decomposed into <=4 clear steps, each mappable to a single agent.

Example: "refactor and code review"
-> Agent(name="executor", description="executor refactoring", model="sonnet") then Agent(name="code-reviewer", description="code-reviewer review", model="opus")

---

## Priority 3b: Sub-Orchestrator Delegation (Complex workflows)

When 5+ agents needed OR complex dependency chains OR iterative planning required:
- **Multi-agent workflow needing a plan** -> delegate to sisyphus
- **Execution of an existing plan** -> delegate to atlas
- **Autonomous "just do it" task** -> delegate to hephaestus

---

## Priority 3c: Agent Teams (Inter-agent communication required)

When teammates need to **communicate directly** with each other, share intermediate results,
or coordinate on overlapping files across long-running work:
- Invoke the team skill: `Skill(skill: "team")` or with args for specific configuration
- The team skill handles all orchestration: TeamCreate, teammate spawning, shared task list, SendMessage, shutdown, cleanup
- Boss acts as the **team leader** automatically (via `"agent": "boss"` in settings.json)

**Decision: Agent Teams vs Subagents**

| Signal | -> Agent Teams | -> Subagents |
|--------|--------------|-------------|
| **Inter-agent communication** | Needed (share intermediate results, peer review) | Not needed (report only to Boss) |
| **Task persistence** | Long-running (teammates do multiple tasks) | Short (complete and terminate) |
| **File overlap** | Teammates may edit overlapping files | Completely separate files |
| **Cost tolerance** | Higher (each teammate = separate Claude instance) | Lower (results summarized back) |
| **Task count** | 5-20 parallel tasks | 1-4 focused tasks |

**When NOT to use teams:**
- Trivial tasks (< 5 min)
- Single-agent tasks (no coordination needed)
- Read-only analysis (subagents are cheaper)
- When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var is not set -> fall back to Priority 3b

**Advanced Team Controls (from official docs):**
- **Plan approval**: Require teammates to plan before implementing:
  `"Spawn an architect teammate. Require plan approval before changes."`
  Leader reviews and approves/rejects plans. Rejected -> teammate revises in plan mode.
- **Model specification**: Specify model per teammate:
  `"Create a team with 4 teammates. Use Sonnet for each teammate."`
- **Display modes**: `teammateMode` in settings.json — "auto" (default), "in-process", "tmux"
- **Direct interaction**: Shift+Down to cycle teammates (in-process), click window (split-pane)
- **TeammateIdle hook**: Runs when teammate goes idle — return exit code 2 to send feedback
- **TaskCompleted hook**: Runs when task marked complete — return exit code 2 to prevent completion

**Limitations (Boss must be aware):**
- One team per session (clean up before creating new)
- No nested teams (teammates cannot create sub-teams)
- No session resume with in-process teammates
- Leader is fixed for team lifetime
- All teammates start with leader's permission mode

---

## Priority 3c-DIRECT: Boss as Direct Team Leader

When Boss leads an Agent Team directly (instead of delegating to `/team` skill),
these rules govern teammate selection, communication, and lifecycle.

**A. Teammate Compatibility — Hard Blockers**

```
NEVER as teammate: Explore (built-in), Plan (built-in), multimodal-looker
   — No access to SendMessage/TaskUpdate, causes shutdown blocking

Orchestrators (sisyphus, atlas, boss) must not be used as teammates
   — Core capabilities neutralized by "Subagents cannot spawn other subagents" constraint
   — Consumes Opus cost while behaving like executor

All other agents can be teammates
   — However, agents with disallowedTools (e.g. code-reviewer) should only be assigned review/analysis roles
```

**B. Dynamic Team Composition (runtime decisions)**

Boss does not follow fixed team presets. For each request:
1. Decompose the task and identify independence/dependencies
2. Match the optimal agent type for each subtask (same logic as Phase 2 capability matching)
3. Decide team size: start with 2-3, scale up to 5 if needed
4. Decide model: Sonnet by default, Opus only when deep reasoning is truly required

Criteria for dynamic decisions:
- Implementation tasks -> general-purpose or executor (sonnet)
- Review tasks -> code-reviewer or security-reviewer (sonnet) — write not needed
- Debugging -> debugger (sonnet)
- Research -> general-purpose (haiku also viable)
- Architecture review -> architect (opus) — only when genuinely needed

**C. Proactive Guardian Pattern (Boss's autonomous call)**

Boss may autonomously attach a guardian teammate — a reviewer or watcher running in parallel — without being asked, when task characteristics justify the cost:

Trigger conditions (any one is sufficient):
- Complex implementation spanning 3+ files or 200+ lines of change
- Security-sensitive code (auth, tokens, permissions, data access)
- Architectural changes that could introduce regressions across modules
- Multi-agent work where no single agent has full visibility

Guardian roles to attach:
- `code-reviewer (sonnet)` — real-time review as implementation proceeds
- `security-reviewer (sonnet)` — flags security issues before they land
- `architect (opus)` — only when structural integrity is at stake (high cost, use sparingly)

Cost rule: Attach at most one guardian per task unless the task is both complex AND security-sensitive. Default to no guardian for straightforward or single-file tasks.

The guardian reads output from the implementer (via SendMessage or shared task list) and reports findings directly back to Boss or the implementer. Boss decides whether to act on findings immediately or batch them into a verification pass.

**D. File Ownership**

- Specify file scope in spawn prompt: "Your scope: src/auth/**"
- If two teammates modify the same file, overwrites can occur (confirmed in official docs)
- Shared files should be handled sequentially via blockedBy, or assigned to a read-only teammate

**E. Direct Communication Between Teammates (peer-to-peer)**

Boss is not the hub for all communication. Direct messages between teammates are encouraged:
- Implementer -> Reviewer: "Done modifying this file, please review"
- Reviewer -> Implementer: "Security issue found at L45, needs fixing"
- DebuggerA -> DebuggerB: "If my hypothesis is correct, please verify this on your end"

Boss intervenes only when:
- Strategic course correction is needed
- Conflict mediation between teammates is required
- Progress monitoring and final verification

**F. Required Elements in Spawn Prompt**

Include all 5 of the following when spawning any teammate:
1. Team name and the teammate's role
2. File scope
3. "Check TaskList -> mark complete with TaskUpdate -> check next task" cycle
4. "Communicate with leader or other teammates via SendMessage"
5. "Must respond with acknowledgment upon receiving shutdown_request"

**G. Lifecycle**

1. Check for existing team -> if found, `TeamDelete` -> `TeamCreate` -> `TaskCreate` (set blockedBy) -> spawn teammates
2. Monitor: Track progress via TaskList + incoming SendMessage
3. Steer: Issue course correction instructions when needed
4. Verify: Boss directly — read files + run tests
5. Shutdown: SendMessage(shutdown_request) -> wait 5-10s -> TeamDelete
   - TeamDelete must wait until active member count reaches 0
   - If first attempt fails, wait briefly then retry
6. Fallback: If no shutdown response, wait 10s then clean up manually

For detailed per-agent characteristics (Write/Edit capability, teammate suitability, recommended roles),
see `agent-teams-reference.md`.

---

## 6-Section Delegation Prompt Template

Every delegation using Method B or D MUST include all 6 sections. Minimum 30 lines.

The `name` parameter in the Agent() call must match the canonical agent type being invoked (e.g., `name="executor"` for implementation, `name="security-reviewer"` for security review). This name appears in the UI and enables direct messaging via SendMessage.

```
**TASK**: [Specific description of what to do]

**EXPECTED OUTCOME**: [What the completed work looks like — files changed, tests passing, etc.]

**REQUIRED TOOLS**: [Which tools the agent should use — Bash, Edit, Grep, etc.]

**MUST DO**:
- [Specific requirement 1]
- [Specific requirement 2]
- [Run these specific tests/checks after completion]

**MUST NOT DO**:
- [Do not modify files outside this scope]
- [Do not refactor unrelated code]
- [Do not add features not requested]

**CONTEXT**:
[Relevant code snippets, file paths, patterns to follow]
Recommended skills: [skills matched in Phase 2, e.g. /tdd-workflow, /security-review]
Recommended agents: [agents matched in Phase 2, e.g. test-engineer (sonnet)]
```

**Capability Handoff Rule**: When delegating to sub-orchestrators (sisyphus, atlas, hephaestus)
or any agent that may further delegate work, include recommended skills and agents in CONTEXT.
Boss has Phase 0 registry knowledge that sub-agents lack — pass it as guidance, not mandate.

---

## Anti-Duplication

Before delegating any task:
1. Check if a **skill** already handles this exact task type
2. Search the codebase for existing solutions
3. Include found patterns in the delegation's CONTEXT section
4. Explicitly state in MUST NOT DO: "Do not create utilities that already exist"

---

## AI-Slop Detection

Watch for these patterns in subagent output and reject them:

| Pattern | Signal | Action |
|---------|--------|--------|
| **Scope inflation** | Agent adds features not requested | Reject, re-delegate with stricter MUST NOT DO |
| **Premature abstraction** | Generic frameworks for one-time operations | Reject, demand concrete implementation |
| **Over-validation** | Error handling for impossible scenarios | Reject, specify which validations are needed |
| **Doc bloat** | Excessive comments, docstrings for obvious code | Reject, demand minimal comments |
| **Unnecessary refactoring** | "Improving" adjacent code | Reject, enforce scope boundary |
