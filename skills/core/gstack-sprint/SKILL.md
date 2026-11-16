---
name: gstack-sprint
description: 3-Phase Sprint workflow — plan (writing-plans + momus, one approval gate) → execute (executing-plans) → review against the plan
level: 4
user-invocable: true
---

<Purpose>
gstack-sprint wraps the 3-Phase Sprint workflow (design→execute→review) as a structured skill to guarantee deterministic execution. Without this skill, the 3-Phase workflow exists only as prompt instructions in boss.md and may be forgotten during long sessions. This skill is the single entry point for end-to-end feature implementation — it coordinates design, execution, and review with user confirmation at each phase boundary.
</Purpose>

<Use_When>
- End-to-end feature implementation ("build this feature", "design it and implement it")
- Build or Mid-sized intent type with implementation phase included
- User says "sprint", "end-to-end", "e2e implementation"
</Use_When>

<Do_Not_Use_When>
- Pure design/planning/idea review without implementation → use /office-hours or /plan-ceo-review directly
- Architecture intent type (design only, no build)
- "just design it", "just plan it", "review my idea" — these route to /office-hours or /plan-ceo-review
- Single-purpose requests: code review → /review, QA → /qa, deploy → /ship
- Trivial fixes, research, documentation
</Do_Not_Use_When>

<Why_This_Exists>
End-to-end feature work fails silently in three predictable ways:
1. Implementation starts before design is aligned — wrong thing built
2. Execution proceeds without structured iteration — partial implementations declared done
3. Review skips comparison against the design doc — drift goes unnoticed

gstack-sprint enforces the three-phase contract: user-confirmed design → automated execution via executing-plans → user-confirmed review against the design doc. Each phase boundary requires explicit user confirmation before the next phase begins.
</Why_This_Exists>

<Steps>

## Phase 1: Design (interactive — one approval gate)

1. **Recall**: search `.briefing/decisions/`, `.briefing/learnings/` and `.briefing/plans/` for two or three keywords from the request. Read at most the three most relevant notes, and note any earlier decision that the request conflicts with. If `.briefing/` does not exist, skip this step.

2. **Clarify** (only when the request is ambiguous): if the goal or the scope has several plausible readings, call the `metis` advisor once, then ask the user at most two clarifying questions in ONE AskUserQuestion call. If the request is clear, skip this step and ask nothing.

3. **Spec and slice**: the request and any step 2 answers are the spec, so do not invoke the brainstorming skill first. Invoke the `writing-plans` skill with two things already decided:
   - Save path: `.briefing/plans/YYYY-MM-DD-<topic>.md`. Create the directory if it is missing.
   - Execution method: Phase 2 of this skill. `writing-plans` must save the plan and return its path. It must not ask which execution approach to use, and it must not ask the user to review the plan: the approval gate in step 5 replaces both questions.

   The plan lists small tasks with exact file paths, test-first steps, a verification command for each task, and the dependencies between tasks. `/plan-ceo-review`, `/plan-eng-review` and `/autoplan` are optional extra reviews: run one only when the user asks for it.

4. **Plan review**: call the `momus` advisor on the plan file. Fix its blocking issues in the plan, for at most two rounds, then append the final momus verdict to the plan file.

5. **APPROVAL GATE**: ask exactly one AskUserQuestion. It shows the plan path, the momus verdict and every decision that is still open, and it offers three options: approve, revise, stop.
   - approve → start Phase 2.
   - revise → change the plan, repeat step 4, then ask this gate again.
   - stop → end the sprint and keep the plan file.

   Phase 2 never starts without an approve answer at this gate (except under step 6). Do not ask for approval anywhere else in Phase 1.

6. **Skip condition**: if the user's original message already says the design is done ("design is done, just build it"), skip steps 2 and 5 and ask nothing. Steps 3 and 4 still run on the design the user gave, so that Phase 2 and Phase 3 have a reviewed plan file. If the user gave a finished task plan file, copy it to `.briefing/plans/YYYY-MM-DD-<topic>.md`, use the copy as the plan, and skip step 3 as well. If `momus` still reports a blocking issue after its two rounds, do not skip step 5.

7. **Fallback** (`writing-plans` is not installed): delegate the plan to the `prometheus` agent. Give it the request and any step 2 answers, and tell it to skip its interview, its own Momus loop and its plan presentation and to return the whole plan as markdown. Save that plan to the same path yourself. Steps 4 and 5 still apply (step 6 can still skip step 5). If `momus` is not available, say so at the approval gate in place of its verdict.

---

## Phase 2: Execute (autonomous — executing-plans)

1. **Invoke the `executing-plans` skill** on the plan file from Phase 1. Pass the plan's ABSOLUTE path: the plan lives in `.briefing/plans/`, which git ignores, and `executing-plans` works in a separate worktree where a relative path does not resolve.

2. **Do not ask again how to execute.** The approve answer at the Phase 1 approval gate is the user's choice of inline execution, and it also approves an isolated worktree. When you invoke `executing-plans`, state that the worktree preference is already declared (use an isolated worktree), so `using-git-worktrees` does not ask again.

3. **Let `executing-plans` run to its own verification.** It runs the tasks in order, test-first, and finishes with its own whole-branch review and `verification-before-completion`. Do not add another review or verification chain on top.

4. **Stop before the branch hand-off.** `executing-plans` ends by handing off to `finishing-a-development-branch`. Do not follow that hand-off: Phase 3 of this skill replaces it. Carry the worktree path, the branch name and the verification output into Phase 3.

5. **Fallback** (`executing-plans` is not installed): delegate one autonomous end-to-end run of the plan to the `hephaestus` agent. Afterwards run the project's tests, then continue with Phase 3.

6. **On a blocker**: if `executing-plans` stops on something it cannot resolve, report it to the user with the task number and the failing output. Do not move to Phase 3 with unfinished tasks.

---

## Phase 3: Review (interactive/iterative — user confirmation)

1. **Reload the plan from disk** in this order:
   1. the Phase 1 plan file; if its path is not known, the newest `.briefing/plans/*-<topic>.md` for this request
   2. the gstack design doc `~/.gstack/projects/<org>-<repo>/*-design-*.md`
   3. the original request

   The gstack design doc lookup:
   ```bash
   REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
   ORG=$(git remote get-url origin 2>/dev/null | sed 's|.*[:/]\([^/]*\)/.*|\1|' || echo "unknown")
   DESIGN_DOC=$(ls -t ~/.gstack/projects/${ORG}-${REPO}/*-design-*.md 2>/dev/null | head -1)
   ```

2. **Read what step 1 loaded** in full (the plan file, or the gstack design doc when there is no plan file), then read all files implemented during Phase 2

3. **Compare implementation against design**: For each item in what step 1 loaded, determine whether it was implemented, partially implemented, or skipped. Note any implementation that was added beyond the design scope.

4. **Present a comparison table** to the user:

   | Design Item | Status | Notes |
   |---|---|---|
   | Feature A | Implemented | |
   | Feature B | Partial | Missing edge case X |
   | Feature C | Not implemented | Descoped during Phase 2 |
   | Bonus: Feature D | Added (not in design) | Confirm or revert |

5. **AskUserQuestion** with the following options:
   - "approve" — implementation matches design intent, proceed to next step
   - "needs improvement" — significant gaps exist, re-enter Phase 2 with corrections
   - "minor fixes" — minor gaps, specify what to fix before approving

6. **If "needs improvement" or "minor fixes"**: Re-enter Phase 2 with a targeted correction delta. Write the gap tasks to a follow-up plan file `.briefing/plans/YYYY-MM-DD-<topic>-followup.md` and run Phase 2 on it in the same worktree and branch. After correction, return to Phase 3 Step 1.

7. **If "approved"**: Suggest next steps — `/ship` from the Phase 2 worktree, or the `finishing-a-development-branch` skill, so the branch and the worktree are not left unmerged. Do not proceed autonomously.

8. **Optional follow-up chain** (present as options, do not auto-invoke):
   - /land-and-deploy → /canary → /document-release → /retro

9. **Fallback** (gstack not installed): Read the implemented files directly, compare them against what step 1 loaded (the plan file, or the original request when there is no plan file), and present the comparison to the user for their review.

</Steps>

<Escalation_And_Stop_Conditions>
- Stop and report when a fundamental blocker requires user input (missing credentials, unclear requirements, external service down)
- Stop when the user says "stop", "cancel", or "abort"
- Never auto-advance into Phase 2 — it starts only on an approve answer at the Phase 1 approval gate (or under the Phase 1 skip condition)
- If the plan is still not approved after three revise rounds at the approval gate, escalate to the user with a clear statement of what is blocking progress
- If Phase 2 (`executing-plans`, or the `hephaestus` fallback) stops on a blocker it cannot resolve, surface it to the user with the task number and the failing output rather than silently retrying or declaring completion
- If Phase 3 comparison reveals that more than 50% of design items are unimplemented, flag this as a significant implementation gap before asking for user decision
</Escalation_And_Stop_Conditions>

<Examples>
<Good>
Phase 1 — the one approval gate:
```
AskUserQuestion: "Plan saved: .briefing/plans/2026-03-26-auth-tokens.md (6 tasks)
momus: OKAY after round 2; the verdict is appended to the plan.
Open decision: store refresh tokens in Redis or in the database? The plan assumes the database.
approve / revise / stop"
```
Why good: One question shows the plan path, the momus verdict and the open decision; Phase 2 cannot start without an approve answer.
</Good>

<Good>
Phase 3 — comparison table against design doc:
```
Design doc: ~/.gstack/projects/sehoon787-my-claude/sehunkim-main-design-20260326-142559.md

| Design Item | Status | Notes |
|---|---|---|
| User auth via JWT | Implemented | |
| Refresh token rotation | Implemented | |
| Rate limiting (100 req/min) | Partial | Middleware added, limit not configurable |
| Audit log for auth events | Not implemented | Descoped during execution |
| OpenAPI schema update | Implemented | |

3 items fully implemented, 1 partially implemented, 1 not implemented.
How would you like to proceed? (approve / needs improvement / minor fixes)
```
Why good: Reads the actual design doc, presents concrete status per item, asks before proceeding.
</Good>

<Bad>
Skipping Phase 1 and jumping straight to implementation:
```
"Understood, I'll start implementing right away."
[immediately starts writing code without design confirmation]
```
Why bad: Phase 1 exists to align on design before implementation. Skipping it risks building the wrong thing.
</Bad>

<Bad>
Claiming Phase 3 complete without reading the design doc:
```
"Implementation is complete. All features are working well."
```
Why bad: Did not read the design doc, did not produce a comparison table, did not ask the user for confirmation. This is completion theater.
</Bad>
</Examples>

<Final_Checklist>
- [ ] Phase 1: plan file saved under `.briefing/plans/`, momus verdict appended, approve answer at the approval gate (or the gate skipped under the Phase 1 skip condition)
- [ ] Phase 2: `executing-plans` (or the `hephaestus` fallback) ran every plan task with its own verification and stopped before the hand-off to `finishing-a-development-branch`
- [ ] Phase 3: Plan reloaded from disk (Phase 1 plan file, else the gstack design doc, else the original request)
- [ ] Phase 3: Comparison table presented to user
- [ ] Phase 3: User selected "approve", "needs improvement", or "minor fixes"
- [ ] If "needs improvement": gap tasks written to a `-followup.md` plan file, Phase 2 run on it in the same worktree and branch, Phase 3 re-run after correction
- [ ] If "approve": `/ship` from the Phase 2 worktree or `finishing-a-development-branch` suggested, no autonomous action taken
</Final_Checklist>
