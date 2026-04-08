#!/usr/bin/env bash
# my-codex SessionStart hook
# Mechanism A: Auto-create .knowledge/ vault if missing
# Mechanism: Read vault context into hook output
set -euo pipefail

_kv_dir=".knowledge"
_kv_msg=""

# ── 1. Knowledge Vault Auto-Create ──
if [ ! -f "$_kv_dir/INDEX.md" ]; then
  mkdir -p "$_kv_dir/sessions" "$_kv_dir/decisions" "$_kv_dir/learnings" "$_kv_dir/agents" "$_kv_dir/references"
  _proj_name=$(basename "$(pwd)")
  cat > "$_kv_dir/INDEX.md" <<KVEOF
---
date: $(date +%Y-%m-%d)
type: index
tags: [project, index]
language: en
---

# ${_proj_name} Knowledge Base

## Overview
Project knowledge base. Auto-created by SessionStart hook.

## Recent Decisions

## Recent Sessions

## Open Questions

## Key Links
- [[sessions/]] — Session logs
- [[decisions/]] — Architecture decisions
- [[learnings/]] — Patterns and solutions
- [[agents/]] — Agent execution logs
- [[references/]] — Reference materials
KVEOF

  # Add .knowledge/ to .gitignore
  if [ -f ".gitignore" ] && ! grep -q '\.knowledge/' ".gitignore" 2>/dev/null; then
    echo '.knowledge/' >> ".gitignore"
  elif [ ! -f ".gitignore" ]; then
    echo '.knowledge/' > ".gitignore"
  fi

  _kv_msg="[KnowledgeVault] Auto-created .knowledge/ structure for ${_proj_name}. Read INDEX.md for project context."
else
  # ── 2. Read existing vault context ──
  _index_content=$(head -30 "$_kv_dir/INDEX.md" 2>/dev/null || true)
  _recent_sessions=""
  if [ -d "$_kv_dir/sessions" ]; then
    _recent_sessions=$(ls -t "$_kv_dir/sessions/"*.md 2>/dev/null | head -3 | xargs -I{} basename {} 2>/dev/null || true)
  fi
  _kv_msg="[KnowledgeVault] Project vault loaded. Recent sessions: ${_recent_sessions:-none}"
fi

# ── 3. Output context ──
if [ -n "$_kv_msg" ]; then
  node -e "console.log(JSON.stringify({hookSpecificOutput:{additionalContext:'$_kv_msg'}}))" 2>/dev/null || true
fi
