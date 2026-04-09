#!/usr/bin/env bash
# my-codex SessionStart hook
# Mechanism A: Auto-create .briefing/ vault if missing
# Mechanism: Read vault context into hook output
set -euo pipefail

_kv_dir=".briefing"
_kv_msg=""

# ── 1. Briefing Vault Auto-Create ──
if [ ! -f "$_kv_dir/INDEX.md" ]; then
  mkdir -p "$_kv_dir/sessions" "$_kv_dir/decisions" "$_kv_dir/learnings" "$_kv_dir/agents" "$_kv_dir/references" "$_kv_dir/persona/rules" "$_kv_dir/persona/skills"
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

  # Add .briefing/ to .gitignore
  if [ -f ".gitignore" ] && ! grep -q '\.briefing/' ".gitignore" 2>/dev/null; then
    echo '.briefing/' >> ".gitignore"
  elif [ ! -f ".gitignore" ]; then
    echo '.briefing/' > ".gitignore"
  fi

  _kv_msg="[BriefingVault] Auto-created .briefing/ structure for ${_proj_name}. Read INDEX.md for project context."
else
  # ── 2. Read existing vault context ──
  _index_content=$(head -30 "$_kv_dir/INDEX.md" 2>/dev/null || true)
  _recent_sessions=""
  if [ -d "$_kv_dir/sessions" ]; then
    _recent_sessions=$(ls -t "$_kv_dir/sessions/"*.md 2>/dev/null | head -3 | xargs -I{} basename {} 2>/dev/null || true)
  fi
  _kv_msg="[BriefingVault] Project vault loaded. Recent sessions: ${_recent_sessions:-none}"
fi

# ── 2b. Persona: Pending Suggestions ──
_sug_file="$_kv_dir/persona/suggestions.jsonl"
if [ -f "$_sug_file" ]; then
  _pending_count=0
  while IFS= read -r _line; do
    case "$_line" in *'"type":"pending"'*|*'"type": "pending"'*) _pending_count=$((_pending_count + 1)) ;; esac
  done < "$_sug_file"
  if [ "$_pending_count" -gt 0 ]; then
    _kv_msg="${_kv_msg} [BriefingVault] ${_pending_count} pending persona suggestion(s). Run: node hooks/persona-rule.js list"
  fi
fi

# ── 2c. Persona: Active Rules ──
_rules_dir="$_kv_dir/persona/rules"
if [ -d "$_rules_dir" ]; then
  _rule_names=""
  for _rf in "$_rules_dir"/*.md; do
    [ -f "$_rf" ] || continue
    _rname=$(basename "$_rf" .md)
    if [ -z "$_rule_names" ]; then
      _rule_names="$_rname"
    else
      _rule_names="$_rule_names, $_rname"
    fi
  done
  if [ -n "$_rule_names" ]; then
    _kv_msg="${_kv_msg} [BriefingVault] Active persona rules: ${_rule_names}"
  fi
fi

# ── 2d. Persona: Active Skills ──
_skills_dir="$_kv_dir/persona/skills"
if [ -d "$_skills_dir" ]; then
  _skill_names=""
  for _sf in "$_skills_dir"/*.md; do
    [ -f "$_sf" ] || continue
    _sname=$(basename "$_sf" .md)
    if [ -z "$_skill_names" ]; then
      _skill_names="$_sname"
    else
      _skill_names="$_skill_names, $_sname"
    fi
  done
  if [ -n "$_skill_names" ]; then
    _kv_msg="${_kv_msg} [BriefingVault] Active persona skills: ${_skill_names}"
  fi
fi

# ── 3. Output context ──
if [ -n "$_kv_msg" ]; then
  node -e "console.log(JSON.stringify({hookSpecificOutput:{additionalContext:'$_kv_msg'}}))" 2>/dev/null || true
fi
