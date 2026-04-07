---
name: gstack-sprint
description: 3-Phase Sprint workflow — design → execute → review with user interaction at decision points
level: 4
user-invocable: true
---

<Purpose>
gstack-sprint wraps the 3-Phase Sprint workflow (설계→실행→검수) as a structured skill to guarantee deterministic execution. Without this skill, the 3-Phase workflow exists only as prompt instructions in boss.md and may be forgotten during long sessions. This skill is the single entry point for end-to-end feature implementation — it coordinates design, execution, and review with user confirmation at each phase boundary.
</Purpose>

<Use_When>
- End-to-end feature implementation ("이 기능 만들어줘", "설계하고 구현까지 해줘")
- Build or Mid-sized intent type with implementation phase included
- User says "sprint", "스프린트", "end-to-end", "e2e 구현"
</Use_When>

<Do_Not_Use_When>
- Pure design/planning/idea review without implementation → use /office-hours or /plan-ceo-review directly
- Architecture intent type (design only, no build)
- "설계해줘", "기획해줘", "아이디어 검토해줘" — these route to /office-hours or /plan-ceo-review
- Single-purpose requests: code review → /review, QA → /qa, deploy → /ship
- Trivial fixes, research, documentation
</Do_Not_Use_When>

<Why_This_Exists>
End-to-end feature work fails silently in three predictable ways:
1. Implementation starts before design is aligned — wrong thing built
2. Execution proceeds without structured iteration — partial implementations declared done
3. Review skips comparison against the design doc — drift goes unnoticed

gstack-sprint enforces the three-phase contract: user-confirmed design → automated execution via ralph → user-confirmed review against the design doc. Each phase boundary requires explicit user confirmation before the next phase begins.
</Why_This_Exists>

<Steps>

## Phase 1: 설계 (대화/상호작용 — 사용자 결정)

1. **Determine scale** from the user's request:
   - Large (new feature, cross-system architecture, significant refactor) → invoke /plan-ceo-review first, then proceed to step 2
   - Medium (scoped feature, single-service change) → skip /plan-ceo-review, proceed directly to step 2

2. **Invoke /plan-eng-review** (mandatory for all scales) to produce a structured engineering design document

3. **Surface all key decisions** using AskUserQuestion for each ambiguity:
   - Technology choices with tradeoffs
   - API contract decisions
   - Data model decisions
   - Scope boundary decisions
   - Do not batch decisions silently — each decision that affects implementation requires explicit user input

4. **Wait for user to confirm "설계 완료"** before transitioning to Phase 2. Do not proceed to Phase 2 on your own judgment.

5. **Skip condition**: If the user's original message already confirms design is done ("설계는 이미 했어, 구현만 해줘", "design is done, just build it") → skip Phase 1 entirely and proceed to Phase 2 with the provided design context

6. **Fallback** (gstack not installed): Use the OMC planner agent (opus) to produce a structured plan. Present the plan to the user and wait for their confirmation before proceeding.

---

## Phase 2: 실행 (자율/자동화 — ralph)

Phase 2 runs as an independent skill invocation, not nested within gstack-sprint's prompt context. Boss invokes `Skill(skill: "ralph")` for this phase.

1. **Invoke the ralph skill** — ralph internally selects its execution strategy based on scale:
   - Parallel multi-agent (ultrawork) for large, multi-story work
   - Single executor for simple, well-scoped implementation

2. **ralph Step 7a** (inside ralph): attempts gstack /review for code review — non-blocking, skips silently if gstack is not installed or /review fails

3. **ralph Step 7b** (inside ralph): architect/critic verification — always runs regardless of Step 7a result

4. **Agent teams** for complex work (ralph delegates to executor + code-reviewer + test-engineer in parallel as needed)

5. **Fallback** (gstack not installed): ralph's existing verification flow runs unchanged — no behavior difference from ralph's perspective

6. **Phase 2 completion**: ralph signals completion via its standard cancel/completion flow. After ralph completes, gstack-sprint resumes Phase 3.

---

## Phase 3: 검수 (대화/개선 — 사용자 확인)

1. **Find design doc**: Search `~/.gstack/projects/` for the most recent design file matching the current repo.
   ```bash
   REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
   ORG=$(git remote get-url origin 2>/dev/null | sed 's|.*[:/]\([^/]*\)/.*|\1|' || echo "unknown")
   DESIGN_DOC=$(ls -t ~/.gstack/projects/${ORG}-${REPO}/*-design-*.md 2>/dev/null | head -1)
   ```
   If no design doc is found, fall back to comparing against the original user request and any notes captured during Phase 1.

2. **Read the design doc** in full, then read all files implemented during Phase 2

3. **Compare implementation against design**: For each item in the design doc, determine whether it was implemented, partially implemented, or skipped. Note any implementation that was added beyond the design scope.

4. **Present a comparison table** to the user:

   | Design Item | Status | Notes |
   |---|---|---|
   | Feature A | Implemented | |
   | Feature B | Partial | Missing edge case X |
   | Feature C | Not implemented | Descoped during Phase 2 |
   | Bonus: Feature D | Added (not in design) | Confirm or revert |

5. **AskUserQuestion** with the following options:
   - "승인" — implementation matches design intent, proceed to next step
   - "개선 필요" — significant gaps exist, re-enter Phase 2 with corrections
   - "부분 수정" — minor gaps, specify what to fix before approving

6. **If "개선 필요" or "부분 수정"**: Re-enter Phase 2 with a targeted correction delta. Pass the specific gaps to ralph rather than re-running the full implementation. After correction, return to Phase 3 Step 1.

7. **If "승인"**: Suggest next steps — /ship or manual commit. Do not proceed autonomously.

8. **Optional follow-up chain** (present as options, do not auto-invoke):
   - /land-and-deploy → /canary → /document-release → /retro

9. **Fallback** (gstack not installed): Read the implemented files directly, compare against the original user request and Phase 1 notes, and present the comparison to the user for their review.

</Steps>

<Escalation_And_Stop_Conditions>
- Stop and report when a fundamental blocker requires user input (missing credentials, unclear requirements, external service down)
- Stop when the user says "stop", "cancel", or "abort"
- Never auto-advance phase boundaries — each phase requires explicit user confirmation
- If Phase 1 design decisions cannot be resolved after three rounds of AskUserQuestion, escalate to the user with a clear statement of what is blocking progress
- If Phase 2 (ralph) fails after the maximum retry attempts, surface the blocker to the user rather than silently retrying or declaring completion
- If Phase 3 comparison reveals that more than 50% of design items are unimplemented, flag this as a significant implementation gap before asking for user decision
</Escalation_And_Stop_Conditions>

<Examples>
<Good>
Phase 1 — surfacing decisions before implementation:
```
AskUserQuestion: "설계 검토 중 두 가지 결정이 필요합니다:
1. API 인증: JWT 토큰 방식과 세션 쿠키 방식 중 어느 것을 사용할까요?
2. 데이터 저장: 실시간 조회를 위해 Redis 캐시를 추가할까요, 아니면 DB 직접 조회로 시작할까요?
결정 후 '설계 완료'라고 말씀해 주시면 구현을 시작합니다."
```
Why good: Decisions are explicit, user controls phase transition, implementation cannot start without confirmation.
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

3개 항목 구현 완료, 1개 부분 구현, 1개 미구현입니다.
어떻게 하시겠습니까? (승인 / 개선 필요 / 부분 수정)
```
Why good: Reads the actual design doc, presents concrete status per item, asks before proceeding.
</Good>

<Bad>
Skipping Phase 1 and jumping straight to implementation:
```
"알겠습니다, 바로 구현하겠습니다."
[immediately starts writing code without design confirmation]
```
Why bad: Phase 1 exists to align on design before implementation. Skipping it risks building the wrong thing.
</Bad>

<Bad>
Claiming Phase 3 complete without reading the design doc:
```
"구현이 완료되었습니다. 모든 기능이 잘 동작합니다."
```
Why bad: Did not read the design doc, did not produce a comparison table, did not ask the user for confirmation. This is completion theater.
</Bad>
</Examples>

<Final_Checklist>
- [ ] Phase 1: Design doc produced and user confirmed "설계 완료" (or Phase 1 explicitly skipped per user request)
- [ ] Phase 2: ralph invoked and completed with its own verification (7a + 7b)
- [ ] Phase 3: Design doc located (or fallback to original request)
- [ ] Phase 3: Comparison table presented to user
- [ ] Phase 3: User selected "승인", "개선 필요", or "부분 수정"
- [ ] If "개선 필요": correction delta passed to ralph, Phase 3 re-run after correction
- [ ] If "승인": next steps suggested (/ship or manual commit), no autonomous action taken
</Final_Checklist>
