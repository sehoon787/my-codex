#!/usr/bin/env bash
# SessionStart hook: detect missing companion tools and auto-install
# Failures are non-blocking (set +e)
set +e

MISSING=()
INSTALLED=()

# 1. Anthropic Skills (pdf + docx only)
if [ ! -f "$HOME/.codex/.skills-managed" ]; then
  if [ ! -d "$HOME/.codex/skills/pdf" ] || [ ! -d "$HOME/.codex/skills/docx" ]; then
    _tmp_dir=$(mktemp -d)
    git clone --depth 1 https://github.com/anthropics/skills.git "$_tmp_dir/skills" 2>/dev/null
    if [ -d "$_tmp_dir/skills/skills" ]; then
      mkdir -p "$HOME/.codex/skills"
      [ ! -d "$HOME/.codex/skills/pdf" ] && [ -d "$_tmp_dir/skills/skills/pdf" ] && \
        cp -r "$_tmp_dir/skills/skills/pdf" "$HOME/.codex/skills/pdf" 2>/dev/null
      [ ! -d "$HOME/.codex/skills/docx" ] && [ -d "$_tmp_dir/skills/skills/docx" ] && \
        cp -r "$_tmp_dir/skills/skills/docx" "$HOME/.codex/skills/docx" 2>/dev/null
      rm -rf "$_tmp_dir"
      INSTALLED+=("anthropic-skills(pdf,docx)")
    else
      rm -rf "$_tmp_dir"
      MISSING+=("anthropic-skills")
    fi
  fi
fi

# 2. ast-grep
if ! command -v ast-grep >/dev/null 2>&1; then
  npm i -g @ast-grep/cli 2>/dev/null && INSTALLED+=("ast-grep") || MISSING+=("ast-grep")
fi

# 5. Capability Registry Cache
REGISTRY_DIR="$HOME/.omc/state"
REGISTRY_FILE="$REGISTRY_DIR/capability-registry.json"
REGISTRY_STATUS="up-to-date"
_registry_diagnostic=""
mkdir -p "$REGISTRY_DIR"
_effective_codex_config="$HOME/.codex/config.toml"
if [ -n "${CODEX_HOME:-}" ] && [ -d "$HOME/.codex/skills" ] && [ -d "$CODEX_HOME/skills" ]; then
  _base_skills=$(cd "$HOME/.codex/skills" 2>/dev/null && pwd -P || true)
  _active_skills=$(cd "$CODEX_HOME/skills" 2>/dev/null && pwd -P || true)
  if [ -n "$_base_skills" ] && [ "$_active_skills" = "$_base_skills" ]; then
    _effective_codex_config="$CODEX_HOME/config.toml"
  fi
fi
_needs_regen=0
if [ ! -f "$REGISTRY_FILE" ]; then
  _needs_regen=1
else
  if find "$HOME/.codex/agents" "$HOME/.codex/skills" -name "*.md" -newer "$REGISTRY_FILE" 2>/dev/null | grep -q .; then
    _needs_regen=1
  elif [ -d ".codex/agents" ] && find ".codex/agents" ".codex/skills" -name "*.md" -newer "$REGISTRY_FILE" 2>/dev/null | grep -q .; then
    _needs_regen=1
  elif [ -f "$HOME/.codex/my-codex/skill-catalog-state.json" ] && [ "$HOME/.codex/my-codex/skill-catalog-state.json" -nt "$REGISTRY_FILE" ]; then
    _needs_regen=1
  elif [ -f "$_effective_codex_config" ] && [ "$_effective_codex_config" -nt "$REGISTRY_FILE" ]; then
    _needs_regen=1
  fi
fi
if [ "$_needs_regen" -eq 1 ]; then
  _registry_write_allowed=1
  _ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Detect project type from current directory
  _recommended_packs="[]"
  if [ -f "package.json" ] || [ -f "tsconfig.json" ] || [ -f "Cargo.toml" ] || \
     [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "go.mod" ] || [ -f "Gemfile" ]; then
    _recommended_packs='["engineering"]'
  elif ls *.unity 2>/dev/null | grep -q . || [ -d "Assets" ]; then
    _recommended_packs='["game-development"]'
  fi

  _agents_json="["
  _first_agent=1
  for _f in "$HOME/.codex/agents/"*.md .codex/agents/*.md; do
    [ -f "$_f" ] || continue
    case "$_f" in "$HOME/.codex/agents/"*) _scope="global" ;; *) _scope="project" ;; esac
    _name=$(sed -n '/^---/,/^---/p' "$_f" 2>/dev/null | grep '^name:' | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"')
    _desc=$(sed -n '/^---/,/^---/p' "$_f" 2>/dev/null | grep '^description:' | head -1 | sed 's/^description:[[:space:]]*//' | tr -d '"')
    _model=$(sed -n '/^---/,/^---/p' "$_f" 2>/dev/null | grep '^model:' | head -1 | sed 's/^model:[[:space:]]*//' | tr -d '"')
    [ -z "$_name" ] && _name=$(basename "$_f" .md)
    [ -z "$_model" ] && _model=""
    if [ "$_first_agent" -eq 1 ]; then _first_agent=0; else _agents_json="${_agents_json},"; fi
    _agents_json="${_agents_json}{\"name\":\"${_name}\",\"description\":\"${_desc}\",\"model\":\"${_model}\",\"scope\":\"${_scope}\"}"
  done
  _agents_json="${_agents_json}]"
  _skills_json=""
  _skill_lanes_json="{}"
  _skill_manager_present=0
  if [ -x "$HOME/.codex/bin/my-codex-skills" ] && command -v node >/dev/null 2>&1; then
    _skill_manager_present=1
    _skill_status_err_file=$(mktemp "${TMPDIR:-/tmp}/my-codex-skill-status.XXXXXX" 2>/dev/null)
    if [ -n "$_skill_status_err_file" ]; then
      _skill_status=$("$HOME/.codex/bin/my-codex-skills" status --json 2>"$_skill_status_err_file")
      _skill_status_exit=$?
      _skill_status_err=$(cat "$_skill_status_err_file" 2>/dev/null)
      rm -f "$_skill_status_err_file"
    else
      _skill_status=$("$HOME/.codex/bin/my-codex-skills" status --json 2>&1)
      _skill_status_exit=$?
      _skill_status_err=""
    fi
    if [ "$_skill_status_exit" -eq 0 ]; then
      _skill_status_parsed=$(printf '%s' "$_skill_status" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);if(!Array.isArray(j.activeSkillNames)||!j.laneIndex||typeof j.laneIndex!=="object"||Array.isArray(j.laneIndex))process.exit(2);process.stdout.write(JSON.stringify({skills:j.activeSkillNames,lanes:j.laneIndex}))}catch(e){process.exit(2)}})')
      _skill_status_parse_exit=$?
    else
      _skill_status_parsed=""
      _skill_status_parse_exit=1
    fi
    if [ "$_skill_status_exit" -eq 0 ] && [ "$_skill_status_parse_exit" -eq 0 ]; then
      _skills_json=$(printf '%s' "$_skill_status_parsed" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.stringify(JSON.parse(s).skills)))')
      _skill_lanes_json=$(printf '%s' "$_skill_status_parsed" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.stringify(JSON.parse(s).lanes)))')
    else
      _registry_write_allowed=0
      REGISTRY_STATUS="skill-catalog-error"
      if [ "$_skill_status_exit" -ne 0 ]; then
        _skill_status_detail=${_skill_status_err:-$_skill_status}
        _registry_diagnostic="[SessionStart] Skill manager status failed (exit ${_skill_status_exit}): ${_skill_status_detail}"
      else
        _registry_diagnostic="[SessionStart] Skill manager returned invalid JSON: ${_skill_status}"
      fi
    fi
  fi
  if [ -z "$_skills_json" ]; then
    if [ "$_skill_manager_present" -eq 1 ]; then
      _skills_json=$(node -e 'const fs=require("fs");try{const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(JSON.stringify(j.skills||[]))}catch(e){process.stdout.write("[]")}' "$REGISTRY_FILE" 2>/dev/null || printf '[]')
      REGISTRY_STATUS="skill-catalog-error"
    else
      _skills_json="["
      _first_skill=1
      for _f in "$HOME/.codex/skills/"*/SKILL.md .codex/skills/*/SKILL.md; do
        [ -f "$_f" ] || continue
        _sname=$(basename "$(dirname "$_f")")
        if [ "$_first_skill" -eq 1 ]; then _first_skill=0; else _skills_json="${_skills_json},"; fi
        _skills_json="${_skills_json}\"${_sname}\""
      done
      _skills_json="${_skills_json}]"
    fi
  fi
  _project_skills_json="["
  _first_project_skill=1
  for _f in .codex/skills/*/SKILL.md; do
    [ -f "$_f" ] || continue
    _sname=$(basename "$(dirname "$_f")")
    if [ "$_first_project_skill" -eq 1 ]; then _first_project_skill=0; else _project_skills_json="${_project_skills_json},"; fi
    _project_skills_json="${_project_skills_json}\"${_sname}\""
  done
  _project_skills_json="${_project_skills_json}]"
  _skills_json=$(node -e 'const a=JSON.parse(process.argv[1]),b=JSON.parse(process.argv[2]);process.stdout.write(JSON.stringify([...new Set([...a,...b])]))' "$_skills_json" "$_project_skills_json" 2>/dev/null || printf '%s' "$_skills_json")
  _mcp_json="["
  _first_mcp=1
  for _sf in ".mcp.json"; do
    [ -f "$_sf" ] || continue
    while IFS= read -r _key; do
      [ -z "$_key" ] && continue
      if [ "$_first_mcp" -eq 1 ]; then _first_mcp=0; else _mcp_json="${_mcp_json},"; fi
      _mcp_json="${_mcp_json}\"${_key}\""
    done <<EOF
$(grep -o '"[^"]*"[[:space:]]*:' "$_sf" 2>/dev/null | sed -n '/mcpServers/,/}/p' | grep -v 'mcpServers' | sed 's/[[:space:]]*"//;s/"[[:space:]]*://' | grep -v '^$' | grep -v '^{' | grep -v '^}' | head -50)
EOF
  done
  _mcp_json="${_mcp_json}]"
  if [ "$_registry_write_allowed" -eq 1 ]; then
    if printf '{"generated_at":"%s","agents":%s,"skills":%s,"skill_lanes":%s,"mcp_servers":%s,"recommended_packs":%s}\n' \
        "$_ts" "$_agents_json" "$_skills_json" "$_skill_lanes_json" "$_mcp_json" "$_recommended_packs" > "$REGISTRY_FILE" 2>/dev/null; then
      [ "$REGISTRY_STATUS" = "skill-catalog-error" ] || REGISTRY_STATUS="regenerated"
    else
      REGISTRY_STATUS="failed"
    fi
  fi
fi

# 5b. .knowledge -> .briefing migration (one-time, backward compat)
if [ -d ".knowledge" ]; then
  if [ ! -d ".briefing" ]; then
    mv ".knowledge" ".briefing"
    mkdir -p ".briefing/persona"
    if [ -f ".briefing/INDEX.md" ] && ! grep -q '^language:' ".briefing/INDEX.md"; then
      sed -i '/^type:/a language: en' ".briefing/INDEX.md" 2>/dev/null || true
    fi
    if [ -f ".gitignore" ]; then
      sed -i '/^\.knowledge\//d' ".gitignore" 2>/dev/null || true
      grep -q '\.briefing/' ".gitignore" 2>/dev/null || echo '.briefing/' >> ".gitignore"
    fi
  else
    for _subdir in sessions decisions learnings agents references; do
      if [ -d ".knowledge/$_subdir" ]; then
        mkdir -p ".briefing/$_subdir"
        for _file in ".knowledge/$_subdir"/*; do
          [ -f "$_file" ] || continue
          _bname=$(basename "$_file")
          [ ! -f ".briefing/$_subdir/$_bname" ] && cp "$_file" ".briefing/$_subdir/$_bname"
        done
      fi
    done
    rm -rf ".knowledge"
    mkdir -p ".briefing/persona"
    if [ -f ".gitignore" ]; then
      sed -i '/^\.knowledge\//d' ".gitignore" 2>/dev/null || true
      grep -q '\.briefing/' ".gitignore" 2>/dev/null || echo '.briefing/' >> ".gitignore"
    fi
  fi
fi

# 6. Briefing Vault Auto-Create + Context
_kv_msg=""
_kv_dir=".briefing"
if command -v node >/dev/null 2>&1 && [ -f "$HOME/.codex/hooks/session-start-state.js" ]; then
  _kv_msg=$(node "$HOME/.codex/hooks/session-start-state.js" 2>/dev/null || true)
else
  _kv_msg="[BriefingVault] JSON runtime bootstrap unavailable; session state was not refreshed."
fi

# 7. Persona: Pending Suggestions Notification
_sug_file="$_kv_dir/persona/suggestions.jsonl"
if [ -f "$_sug_file" ]; then
  _pending_count=0
  while IFS= read -r _line; do
    case "$_line" in *'"type":"pending"'*|*'"type": "pending"'*) _pending_count=$((_pending_count + 1)) ;; esac
  done < "$_sug_file"
  if [ "$_pending_count" -gt 0 ]; then
    _kv_msg="${_kv_msg} [BriefingVault] ${_pending_count} pending persona suggestion(s). Run: node $HOME/.codex/hooks/persona-rule.js list"
  fi
fi

# 8. Persona: Active Policy Summary
_policy_file="$_kv_dir/persona/persona-policy.json"
if [ -f "$_policy_file" ] && command -v node >/dev/null 2>&1; then
  _policy_summary=$(node -e "const fs=require('fs');try{const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));const prefs=p&&p.preferences&&typeof p.preferences==='object'?Object.keys(p.preferences):[];if(prefs.length){console.log(prefs.sort().join(', '))}}catch(e){}" "$_policy_file" 2>/dev/null || true)
  if [ -n "$_policy_summary" ]; then
    _kv_msg="${_kv_msg} [BriefingVault] Active persona policy: ${_policy_summary}"
  fi
fi

# 10. Version Freshness Check (once per day, non-blocking)
_update_msg=""
_vc_stamp="$HOME/.codex/.my-codex-update-check"
_vc_today=$(date +%Y-%m-%d)
_vc_last=""
[ -f "$_vc_stamp" ] && _vc_last=$(head -1 "$_vc_stamp" 2>/dev/null)
if [ "$_vc_today" != "$_vc_last" ]; then
  _vc_installed_sha=""
  [ -f "$HOME/.codex/.my-codex-installed-sha" ] && _vc_installed_sha=$(cat "$HOME/.codex/.my-codex-installed-sha" 2>/dev/null)
  if [ -n "$_vc_installed_sha" ]; then
    _vc_remote_sha=$(git ls-remote https://github.com/sehoon787/my-codex.git HEAD 2>/dev/null | cut -f1 | head -c 12)
    if [ -n "$_vc_remote_sha" ] && [ "${_vc_installed_sha}" != "${_vc_remote_sha}" ]; then
      _repo_dir=""
      if [ -f "$HOME/.codex/.my-codex-repo-path" ]; then
        _repo_dir=$(cat "$HOME/.codex/.my-codex-repo-path" 2>/dev/null)
      fi
      if [ -z "$_repo_dir" ] || [ ! -d "$_repo_dir" ]; then
        for _candidate in "$HOME/Desktop/proj/my-codex" "$HOME/Desktop/proj/ai-proj/my-codex" "$HOME/Desktop/proj"/*/my-codex "$HOME/projects/my-codex" "$HOME/my-codex"; do
          if [ -d "$_candidate/.git" ] && [ -f "$_candidate/hooks/hooks.json" ]; then
            _repo_dir="$_candidate"
            break
          fi
        done
      fi

      if [ -n "$_repo_dir" ] && [ -d "$_repo_dir/.git" ]; then
        _pull_result=$(cd "$_repo_dir" && git pull --ff-only 2>&1) || true

        if [ -d "$_repo_dir/hooks" ]; then
          # Codex reads lifecycle hooks from $CODEX_HOME/hooks.json (root), not hooks/.
          rm -f "$HOME/.codex/hooks/hooks.json" 2>/dev/null || true
          cp "$_repo_dir/hooks/hooks.json" "$HOME/.codex/hooks.json" 2>/dev/null || true
          for _hf in "$_repo_dir/hooks/"*.js; do
            [ -f "$_hf" ] && cp "$_hf" "$HOME/.codex/hooks/" 2>/dev/null || true
          done
          for _hf in "$_repo_dir/hooks/"*.sh; do
            [ -f "$_hf" ] && cp "$_hf" "$HOME/.codex/hooks/" 2>/dev/null || true
          done
        fi

        if [ -f "$_repo_dir/templates/codex-AGENTS.md" ] && [ -f "$HOME/.codex/AGENTS.md" ]; then
          cp "$_repo_dir/templates/codex-AGENTS.md" "$HOME/.codex/AGENTS.md" 2>/dev/null || true
        fi

        if [ -f "$_repo_dir/scripts/merge-hooks.js" ]; then
          node "$_repo_dir/scripts/merge-hooks.js" 2>/dev/null || true
        fi

        _new_sha=$(cd "$_repo_dir" && git rev-parse --short=12 HEAD 2>/dev/null)
        if [ -n "$_new_sha" ]; then
          echo "$_new_sha" > "$HOME/.codex/.my-codex-installed-sha"
        fi

        _update_msg="[UpdateCheck] my-codex hooks auto-updated (${_vc_installed_sha} -> ${_new_sha:-unknown})"
      else
        _vc_current=$(cat "$HOME/.codex/.my-codex-version" 2>/dev/null || echo "unknown")
        _update_msg="[UpdateCheck] my-codex update available (installed: v${_vc_current}). Run: cd <my-codex-repo> && bash install.sh"
      fi
    fi
    echo "$_vc_today" > "$_vc_stamp" 2>/dev/null || true
  fi
fi

# Return results as additionalContext
MSG=""
if [ ${#INSTALLED[@]} -gt 0 ]; then
  MSG="[SessionStart] Auto-installed: ${INSTALLED[*]}. "
fi
if [ ${#MISSING[@]} -gt 0 ]; then
  MSG="${MSG}[SessionStart] Missing (run install.sh): ${MISSING[*]}."
fi

MSG="${MSG}[SessionStart] Registry cache: ${REGISTRY_STATUS}."
[ -n "$_registry_diagnostic" ] && MSG="${MSG} ${_registry_diagnostic}"
[ -n "$_kv_msg" ] && MSG="${MSG} ${_kv_msg}"
[ -n "$_update_msg" ] && MSG="${MSG} ${_update_msg}"
if [ -n "$MSG" ]; then
  # Codex deserializes SessionStart stdout with deny_unknown_fields into
  # SessionStartHookSpecificOutputWire, where hookEventName is REQUIRED --
  # omitting it makes every `codex exec` print "hook: SessionStart Failed"
  # and drops the context entirely.
  # MSG is assembled from other hooks' stdout, which can carry quotes,
  # backslashes, or newlines; raw, any of those break the single JSON
  # document Codex expects, so escape them before interpolating.
  _json_msg=$(printf '%s' "$MSG" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\r\t' '   ')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$_json_msg"
fi
