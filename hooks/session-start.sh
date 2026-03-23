#!/usr/bin/env bash
# SessionStart hook: detect missing companion tools and auto-install
# Failures are non-blocking (set +e)
set +e

MISSING=()
INSTALLED=()

# 1. Anthropic Skills
if [ ! -d "$HOME/.claude/skills/pdf" ] && [ ! -d "$HOME/.claude/skills/docx" ]; then
  cd /tmp && git clone --depth 1 https://github.com/anthropics/skills.git 2>/dev/null
  if [ -d /tmp/skills/skills ]; then
    mkdir -p "$HOME/.claude/skills"
    cp -r /tmp/skills/skills/* "$HOME/.claude/skills/" 2>/dev/null
    rm -rf /tmp/skills
    INSTALLED+=("anthropic-skills")
  else
    MISSING+=("anthropic-skills")
  fi
fi

# 2. OMC CLI
if ! command -v omc >/dev/null 2>&1; then
  npm i -g oh-my-claude-sisyphus@latest 2>/dev/null && INSTALLED+=("omc") || MISSING+=("omc")
fi

# 3. omo CLI
if ! command -v oh-my-opencode >/dev/null 2>&1; then
  npm i -g oh-my-opencode@latest 2>/dev/null && INSTALLED+=("omo") || MISSING+=("omo")
fi

# 4. ast-grep
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
