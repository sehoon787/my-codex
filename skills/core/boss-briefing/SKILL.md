---
name: boss-briefing
description: Vault health check — workflow pattern analysis, profile sync, session gap recovery, persona rule proposals
---

# Boss Briefing Skill

Vault sync, workflow pattern analysis, and persona rule management. Run this skill during or at the end of a session to keep `.briefing/` healthy and up to date.

This skill **replaces the profile update functionality** from `stop-profile-update.js` (which remains as a fallback for sessions where `/boss-briefing` is not run). The existing `briefing-vault` skill handles vault templates and initialization; this skill handles sync, analysis, and persona learning.

The my-codex runtime uses `briefing-runtime.js` for state management. State is stored in `.briefing/state.json` and can be read/written via standard filesystem operations.

---

## Step 1: Read state.json

Read `.briefing/state.json` and extract session metadata:

- `date` — session date (YYYY-MM-DD)
- `workCounter` — number of meaningful work events
- `sessionMessageCount` — total prompts in this session
- `lastVaultSync` — ISO timestamp of last boss-briefing run
- `sessionStartHead` — git HEAD at session start (empty for non-git projects)
- `promptCount` — prompt counter
- `editCount` — edit counter
- `subagentCount` — subagent completion counter
- `subagentSeq` — sequential subagent index for agent-log enrichment

If `state.json` does not exist or is empty, report that and skip to Step 6.

## Step 2: Previous Session Gap Detection

Compare the `date` field in state.json with today's date.

- If the gap is >= 1 day, scan `.briefing/sessions/` for the most recent session file (by filename date prefix, excluding `*-auto*` files).
- Report the gap: "N day(s) since last session on YYYY-MM-DD."
- If sessions exist, summarize the last session file's title/goal section for context recovery.
- If no previous sessions exist, note that this appears to be a fresh vault.

## Step 3: Analyze agent-log.jsonl Sequences

Read `.briefing/agents/agent-log.jsonl`. Parse all entries from the last 30 days.

1. Group entries by date (using the `ts` field, truncated to YYYY-MM-DD).
2. For each day, extract the ordered sequence of `agent_type` values.
3. Look for **recurring sub-sequences** of length >= 2 that appear in >= 2 different sessions (days).
4. Record each detected pattern with:
   - The sub-sequence (e.g., `explore → executor → code-reviewer`)
   - How many sessions it appeared in
   - The `phase` mapping if available (e.g., `research → implement → review`)

Phase mapping for agent_type values:
- `explore` → research
- `executor` → implement
- `code-reviewer` → review
- `tdd-guide` → test
- `planner` → plan
- `debugger` → debug
- All others → (empty string)

If the log file does not exist or has fewer than 2 days of data, skip pattern detection and note the reason.

## Step 4: Update profile.md

Rewrite `.briefing/persona/profile.md` with these sections:

```markdown
---
date: <today>
type: persona-profile
updated_by: boss-briefing
session_count: <N>
---

# Workflow Profile

## Philosophy
<Inferred from session patterns — e.g., "Prefers delegated execution with explicit verification steps.">

## Workflow Patterns
<Top agent types by frequency, with counts>

## Workflow Sequences
<NEW section — detected recurring sub-sequences from Step 3, e.g.:
- explore → executor → code-reviewer (seen in 5 sessions) — research → implement → review>

## Agent Affinity
<Which agents are used most, with relative percentages>

## Active Persona Rules
<List any rules in .briefing/persona/rules/*.md with their status>

## History
<Last 5 session dates with brief topic if available>
```

**Session count idempotency**: Read the existing `session_count` from profile.md frontmatter. Only increment if the current session date differs from the last profile update date. This prevents double-counting when the skill runs multiple times per session.

## Step 5: Propose Persona Rules

For each detected **sequence pattern** from Step 3 that appears in >= 2 sessions and does NOT already have a matching rule in `.briefing/persona/rules/`:

1. Draft a rule proposal describing when Boss should use this workflow sequence.
2. **Ask the user for confirmation** using an interactive prompt (e.g., "Detected pattern: explore → executor → code-reviewer (5 sessions). Create routing rule? [y/n]").
3. If accepted, write the rule to `.briefing/persona/rules/workflow-<slug>.md`:

```markdown
---
date: <today>
type: persona-rule
pattern: [explore, executor, code-reviewer]
phase_sequence: [research, implement, review]
occurrences: <N>
status: active
---

# Workflow Rule: <descriptive name>

## Pattern
<agent_type sequence>

## When to Apply
<Description of when Boss should suggest or follow this sequence>

## Rationale
Detected in <N> sessions over the last 30 days.
```

If no new patterns qualify, skip this step and note why.

## Step 6: Validate Session Summary

Check `.briefing/sessions/` for a file matching today's date (YYYY-MM-DD prefix) that is NOT an `-auto` file.

- If found: report that the session summary exists.
- If not found: remind the user to write one before ending the session.

## Step 7: Sync INDEX.md

Read `.briefing/INDEX.md` and rebuild the dynamic sections:

- **Recent Sessions**: List the last 5 session files (by date) with `[[wiki-links]]`.
- **Recent Decisions**: List the last 5 decision files with `[[wiki-links]]`.
- **Recent Learnings**: List the last 5 learning files with `[[wiki-links]]`.

Preserve all other sections (Overview, Open Questions, Key Links, language frontmatter) unchanged.

## Step 8: Record lastVaultSync

Write the current ISO timestamp to `state.json` field `lastVaultSync`:

```json
{
  "lastVaultSync": "2026-04-21T14:30:00.000Z"
}
```

Read the current state, update only the `lastVaultSync` field, and write back. Do not reset other counters.

## Step 9: No-Git-Repo Handling

If `sessionStartHead` is empty (non-git project), use `YYYY-MM-DD:cwd` as the session identifier fallback. This is already handled by `briefing-runtime.js` in `session-sync.js` `ensureState()`, but verify it during gap detection (Step 2) — do not attempt git operations if the project has no `.git` directory.

---

## Notes

- This skill is invoked via `/boss-briefing` and can be run at any point during a session.
- The Stop hook in `stop-session-enforcement.js` checks `lastVaultSync` to determine if this skill was run today.
- The `UserPromptSubmit` hook in `session-sync.js` suggests running this skill after 5+ messages if it hasn't been run today.
- `stop-profile-update.js` remains as a fallback — it runs on every Stop event and handles basic profile updates for sessions where `/boss-briefing` was not invoked.
