---
name: knowledge-vault
description: Initialize, manage, and search the per-project .knowledge/ vault. Obsidian-compatible persistent knowledge base with optional basic-memory RAG.
---

# Knowledge Vault Skill

Manage the `.knowledge/` directory as a persistent, Obsidian-compatible knowledge base.

## Initialize Vault

When starting a new vault (first time in a project):

1. Create directory structure:
```
.knowledge/
├── INDEX.md
├── sessions/
├── decisions/
├── learnings/
└── agents/
```

2. Create `.knowledge/INDEX.md`:
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

3. Add `.knowledge/` to `.gitignore`

4. If `basic-memory` MCP is available, initialize:
```bash
basic-memory init <project-name> --path .knowledge
```

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

## Search Vault

### With basic-memory MCP (semantic RAG):
Use `search_notes` tool — finds semantically similar content.

### Without MCP (keyword search):
```bash
# Search by content
grep -r "keyword" .knowledge/ --include="*.md"

# Search by tag
grep -r "tags:.*architecture" .knowledge/ --include="*.md"

# Search by type
grep -r "type: decision" .knowledge/ --include="*.md"
```

## Obsidian Tips

- Open `.knowledge/` as an Obsidian vault
- Graph View shows note connections via `[[wiki-links]]`
- Use tags for filtering (#decision, #learning, #session)
- Install "Dataview" plugin for dynamic tables of decisions/learnings
