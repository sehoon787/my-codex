#!/usr/bin/env bash
# SessionStart hook: detect missing companion tools and auto-install
# Failures are non-blocking (set +e)
set +e

MISSING=()
INSTALLED=()

# ast-grep
if ! command -v ast-grep >/dev/null 2>&1; then
  npm i -g @ast-grep/cli 2>/dev/null && INSTALLED+=("ast-grep") || MISSING+=("ast-grep")
fi

# Return results as additionalContext
MSG=""
if [ ${#INSTALLED[@]} -gt 0 ]; then
  MSG="[SessionStart] Auto-installed: ${INSTALLED[*]}. "
fi
if [ ${#MISSING[@]} -gt 0 ]; then
  MSG="${MSG}[SessionStart] Missing (run install.sh): ${MISSING[*]}."
fi

if [ -n "$MSG" ]; then
  echo "{\"hookSpecificOutput\":{\"additionalContext\":\"$MSG\"}}"
fi
