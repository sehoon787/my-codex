#!/usr/bin/env bash
# Validate submodule integrity and/or installation state
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MODE="repo"
[ "${1:-}" = "--installed" ] && MODE="installed"

ERRORS=0

if [ "$MODE" = "repo" ]; then
  echo "=== Repo Validation (submodule-based) ==="

  # 1. Self-owned TOML agents exist
  for f in codex-agents/core/boss.toml; do
    test -f "$f" && echo "OK: $f" || { echo "FAIL: $f missing"; ERRORS=$((ERRORS + 1)); }
  done

  OMO_COUNT=$(find codex-agents/omo -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')
  [ "$OMO_COUNT" -ge 9 ] && echo "OK: codex-agents/omo — $OMO_COUNT agents" || { echo "FAIL: codex-agents/omo has $OMO_COUNT (expected >= 9)"; ERRORS=$((ERRORS + 1)); }

  CORE_SKILL_COUNT=$(find skills/core -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$CORE_SKILL_COUNT" -ge 2 ] && echo "OK: skills/core — $CORE_SKILL_COUNT skills" || { echo "FAIL: skills/core has $CORE_SKILL_COUNT (expected >= 2)"; ERRORS=$((ERRORS + 1)); }

  # 2. Submodules initialized — check each
  echo ""
  echo "=== Submodule Validation ==="
  for sub in agency-agents ecc awesome omx gstack superpowers; do
    subdir="upstream/$sub"
    if [ ! -d "$subdir" ] || [ -z "$(ls -A "$subdir" 2>/dev/null)" ]; then
      echo "SKIP: $subdir not initialized (run: git submodule update --init)"
      continue
    fi
    case "$sub" in
      agency-agents)
        COUNT=$(find "$subdir" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        [ "$COUNT" -ge 100 ] && echo "OK: $sub — $COUNT agents" || { echo "FAIL: $sub has $COUNT agents (expected >= 100)"; ERRORS=$((ERRORS + 1)); }
        ;;
      ecc)
        SKILL_COUNT=$(find "$subdir/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
        [ "$SKILL_COUNT" -ge 30 ] && echo "OK: $sub — $SKILL_COUNT skills" || { echo "FAIL: $sub has $SKILL_COUNT skills (expected >= 30)"; ERRORS=$((ERRORS + 1)); }
        ;;
      awesome)
        TOML_COUNT=$(find "$subdir/categories" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')
        [ "$TOML_COUNT" -ge 30 ] && echo "OK: $sub — $TOML_COUNT .toml files" || { echo "FAIL: $sub has $TOML_COUNT .toml files in categories/ (expected >= 30)"; ERRORS=$((ERRORS + 1)); }
        ;;
      omx)
        PROMPT_COUNT=$(find "$subdir/prompts" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        SKILL_COUNT=$(find "$subdir/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
        [ "$PROMPT_COUNT" -ge 10 ] && echo "OK: $sub — $PROMPT_COUNT prompts" || { echo "FAIL: $sub has $PROMPT_COUNT prompts (expected >= 10)"; ERRORS=$((ERRORS + 1)); }
        [ "$SKILL_COUNT" -ge 10 ] && echo "OK: $sub — $SKILL_COUNT skills" || { echo "FAIL: $sub has $SKILL_COUNT skills (expected >= 10)"; ERRORS=$((ERRORS + 1)); }
        ;;
      gstack)
        SKILL_COUNT=$(find "$subdir" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
        [ "$SKILL_COUNT" -ge 20 ] && echo "OK: $sub — $SKILL_COUNT skills" || { echo "FAIL: $sub has $SKILL_COUNT skills (expected >= 20)"; ERRORS=$((ERRORS + 1)); }
        ;;
      superpowers)
        AGENT_COUNT=$(find "$subdir/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        SKILL_COUNT=$(find "$subdir/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
        [ "$AGENT_COUNT" -ge 1 ] && echo "OK: $sub — $AGENT_COUNT agents" || { echo "FAIL: $sub has $AGENT_COUNT agents (expected >= 1)"; ERRORS=$((ERRORS + 1)); }
        [ "$SKILL_COUNT" -ge 10 ] && echo "OK: $sub — $SKILL_COUNT skills" || { echo "FAIL: $sub has $SKILL_COUNT skills (expected >= 10)"; ERRORS=$((ERRORS + 1)); }
        ;;
    esac
  done

  # 3. SOURCES.json valid
  echo ""
  if [ -f upstream/SOURCES.json ]; then
    node -e "JSON.parse(require('fs').readFileSync('upstream/SOURCES.json','utf8'))" 2>/dev/null \
      && echo "OK: upstream/SOURCES.json is valid JSON" \
      || { echo "FAIL: upstream/SOURCES.json is not valid JSON"; ERRORS=$((ERRORS + 1)); }
  else
    echo "FAIL: upstream/SOURCES.json not found"; ERRORS=$((ERRORS + 1))
  fi

  # 4. No duplicate agent filenames (informational)
  echo ""
  echo "=== Duplicate Check ==="
  ALL_AGENTS=$(mktemp)
  find codex-agents -name '*.toml' -exec basename {} \; 2>/dev/null >> "$ALL_AGENTS"
  for sub in omx superpowers; do
    [ -d "upstream/$sub" ] && find "upstream/$sub" -path '*/agents/*.toml' -exec basename {} \; 2>/dev/null >> "$ALL_AGENTS"
  done
  DUPES=$(sort "$ALL_AGENTS" | uniq -d | wc -l | tr -d ' ')
  [ "$DUPES" -eq 0 ] && echo "OK: No duplicate agent names" || echo "INFO: $DUPES duplicate agent name(s) found"
  rm -f "$ALL_AGENTS"

  # 5. Hooks files exist
  echo ""
  echo "=== Hooks Validation ==="
  if [ -f hooks/hooks.json ]; then
    node -e "JSON.parse(require('fs').readFileSync('hooks/hooks.json','utf8'))" 2>/dev/null \
      && echo "OK: hooks/hooks.json is valid JSON" \
      || { echo "FAIL: hooks/hooks.json is not valid JSON"; ERRORS=$((ERRORS + 1)); }
  else
    echo "FAIL: hooks/hooks.json not found"; ERRORS=$((ERRORS + 1))
  fi
  [ -f hooks/session-start.sh ] && echo "OK: hooks/session-start.sh present" || { echo "FAIL: hooks/session-start.sh missing"; ERRORS=$((ERRORS + 1)); }

elif [ "$MODE" = "installed" ]; then
  echo "=== Install Validation (~/.codex/) ==="

  AGENT_COUNT=$(find "$HOME/.codex/agents" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')
  [ "$AGENT_COUNT" -ge 10 ] && echo "OK: agents — $AGENT_COUNT installed" || { echo "FAIL: agents has $AGENT_COUNT (expected >= 10)"; ERRORS=$((ERRORS + 1)); }

  SKILL_COUNT=$(find "$HOME/.codex/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ "$SKILL_COUNT" -ge 5 ] && echo "OK: skills — $SKILL_COUNT installed" || { echo "FAIL: skills has $SKILL_COUNT (expected >= 5)"; ERRORS=$((ERRORS + 1)); }

  [ -f "$HOME/.codex/hooks/hooks.json" ] && echo "OK: hooks.json present" || { echo "FAIL: hooks.json missing"; ERRORS=$((ERRORS + 1)); }
  [ -f "$HOME/.codex/.my-codex-manifest.txt" ] && echo "OK: manifest present" || { echo "FAIL: manifest missing"; ERRORS=$((ERRORS + 1)); }

  # Agent packs
  PACK_COUNT=$(find "$HOME/.codex/agent-packs" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')
  [ "$PACK_COUNT" -ge 50 ] && echo "OK: agent-packs — $PACK_COUNT .toml files" || { echo "FAIL: agent-packs has $PACK_COUNT (expected >= 50)"; ERRORS=$((ERRORS + 1)); }

  [ -f "$HOME/.codex/config.toml" ] && echo "OK: config.toml present" || { echo "FAIL: config.toml missing"; ERRORS=$((ERRORS + 1)); }
fi

# Summary
echo ""
echo "=== Summary ==="
echo "Errors: $ERRORS"
[ "$ERRORS" -gt 0 ] && { echo "VALIDATION FAILED"; exit 1; } || echo "VALIDATION PASSED"
