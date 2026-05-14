---
name: briefing-vault
description: Initialize, manage, and search the per-project .briefing/ vault. Obsidian-compatible persistent knowledge base.
---

# Briefing Vault Skill

Manage the `.briefing/` directory as a persistent, Obsidian-compatible knowledge base.

## Initialize Vault

When starting a new vault (first time in a project):

1. Create directory structure:
```
.briefing/
├── INDEX.md
├── sessions/
├── decisions/
├── learnings/
├── references/
└── agents/
```

2. Create `.briefing/INDEX.md`:
```markdown
---
date: <today>
type: index
tags: [project, index]
---

# <Project Name> Knowledge Base

## Overview
<Brief project description>

## Recent Decisions
<!-- Auto-updated by agents -->

## Open Questions
<!-- Track unresolved items -->

## Key Links
- [[sessions/]] — Session logs
- [[decisions/]] — Architecture decisions
- [[learnings/]] — Patterns and solutions
```

3. Add `.briefing/` to `.gitignore`

## Note Templates

### Session Note (`sessions/YYYY-MM-DD-topic.md`)
```markdown
---
date: YYYY-MM-DD
type: session
tags: [session]
related: []
---

# Session: <Topic>

## Goal
<What was requested>

## Actions
- <What was done>

## Results
- <Outcomes>

## Decisions Made
- [[decisions/decision-name]] — <brief>

## Learnings
- [[learnings/learning-name]] — <brief>

## Next Steps
- <Follow-up items>
```

### Decision Note (`decisions/name.md`)
```markdown
---
date: YYYY-MM-DD
type: decision
tags: [architecture|design|tooling]
status: accepted|superseded|deprecated
related: []
---

# Decision: <Title>

## Context
<Why this decision was needed>

## Options Considered
1. <Option A> — pros/cons
2. <Option B> — pros/cons

## Decision
<What was chosen and why>

## Consequences
<Impact of this decision>
```

### Learning Note (`learnings/name.md`)
```markdown
---
date: YYYY-MM-DD
type: learning
tags: [pattern|gotcha|solution]
related: []
---

# <Title>

## Problem
<What went wrong or was non-obvious>

## Solution
<What fixed it>

## Why It Works
<Root cause explanation>
```

### Reference Note (`references/name.md`)
```markdown
---
date: YYYY-MM-DD
type: reference
source: <URL or source description>
tags: [reference, topic]
related: []
---

# <Title>

## Source
<URL or citation>

## Key Points
- <Main finding 1>
- <Main finding 2>

## Context
<Why this reference is relevant>

## Raw Notes
<Verbatim excerpts or detailed notes>
```

## Search Vault

Use Grep to search `.briefing/` by keyword:

```bash
# Search by content
grep -r "keyword" .briefing/ --include="*.md"

# Search by tag
grep -r "tags:.*architecture" .briefing/ --include="*.md"

# Search by type
grep -r "type: decision" .briefing/ --include="*.md"
```

## Obsidian Tips

- Open `.briefing/` as an Obsidian vault
- Graph View shows note connections via `[[wiki-links]]`
- Use tags for filtering (#decision, #learning, #session)
- Install "Dataview" plugin for dynamic tables of decisions/learnings

## Archives (PARA)

The `archives/` directory stores completed or inactive notes following PARA methodology.

### Directory Structure
```
.briefing/archives/       ← flat directory, type: in frontmatter identifies origin
```

### Archiving
- Session-end hooks suggest candidates older than 30 days
- Move manually: `mv .briefing/sessions/old-file.md .briefing/archives/`
- The note's `type:` frontmatter preserves its original category
- Archived notes remain searchable and linkable via `[[wiki-links]]`

## Wiki (LLM-wiki)

The `wiki/` directory stores concept pages — distilled knowledge from multiple sessions.

### Schema
```yaml
---
id: "YYYYMMDDHHMMSS"
date: YYYY-MM-DD
type: wiki
tags: [concept, category]
sources: [sessions/file.md, decisions/file.md]
updated: YYYY-MM-DD
---

# Concept Name

## Definition
One-paragraph summary.

## Key Facts
- Fact 1
- Fact 2

## Related
- [[other-concept]]
```

### Creating Wiki Pages
- Manual: User requests "summarize X as a wiki page"
- Auto-suggest: Session-end hooks detect keywords mentioned 3+ times
- Template: `.briefing/wiki/_schema.md`

## Zettelkasten Note Format

Learnings follow atomic note principles:

```yaml
---
id: "YYYYMMDDHHMMSS"
date: YYYY-MM-DD
type: learning
tags: [pattern, topic]
related: [[other-learning-1], [other-learning-2]]
---

# One Insight Title

Brief description of the pattern or insight (~500 chars recommended).
One file = one idea. Link to at least 2 related notes.
```
