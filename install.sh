#!/usr/bin/env bash
# my-codex full installer -- installs agents and skills for OpenAI Codex CLI
# Usage:
#   bash install.sh
#   curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

has_repo_assets() {
  [ -d "$REPO_ROOT/codex-agents" ] &&
  [ -d "$REPO_ROOT/templates" ]
}

bootstrap_remote_install() {
  local repo_slug ref archive_url bootstrap_root archive_path extracted_root status

  if has_repo_assets; then
    return 0
  fi

  if [ "${MY_CODEX_BOOTSTRAPPED:-0}" = "1" ]; then
    echo "ERROR: install.sh was started without the repository assets and bootstrap retry also failed."
    echo "Run from a full my-codex checkout or set MY_CODEX_ARCHIVE_URL to a valid source archive."
    exit 1
  fi

  command -v curl >/dev/null 2>&1 || {
    echo "ERROR: curl is required when running install.sh without a local repository checkout."
    exit 1
  }
  command -v tar >/dev/null 2>&1 || {
    echo "ERROR: tar is required when running install.sh without a local repository checkout."
    exit 1
  }

  repo_slug="${MY_CODEX_REPO_SLUG:-sehoon787/my-codex}"
  ref="${MY_CODEX_REF:-main}"
  archive_url="${MY_CODEX_ARCHIVE_URL:-https://github.com/${repo_slug}/archive/refs/heads/${ref}.tar.gz}"

  bootstrap_root="$(mktemp -d)"
  archive_path="$bootstrap_root/my-codex.tar.gz"

  echo "Repository assets not found next to install.sh."
  echo "Bootstrapping my-codex from: $archive_url"

  curl -fsSL "$archive_url" -o "$archive_path"
  tar -xzf "$archive_path" -C "$bootstrap_root"
  extracted_root="$(find "$bootstrap_root" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

  if [ -z "$extracted_root" ] || [ ! -f "$extracted_root/install.sh" ]; then
    rm -rf "$bootstrap_root"
    echo "ERROR: downloaded archive did not contain install.sh at the expected location."
    exit 1
  fi

  (
    export MY_CODEX_BOOTSTRAPPED=1
    export MY_CODEX_BOOTSTRAP_SOURCE="$archive_url"
    bash "$extracted_root/install.sh" "$@"
  )
  status=$?
  rm -rf "$bootstrap_root"
  exit "$status"
}

bootstrap_remote_install "$@"

CODEX_ROOT="$HOME/.codex"
MANIFEST_FILE="$CODEX_ROOT/.my-codex-manifest.txt"
VERSION_FILE="$CODEX_ROOT/.my-codex-version"
TMP_MANIFEST="$(mktemp)"
NODEJS_SHIM_DIR=""
AGENTS_SKILLS_ROOT="$HOME/.agents/skills"
CLAUDE_SKILLS_ROOT="$HOME/.claude/skills"

cleanup() {
  rm -f "$TMP_MANIFEST"
}
trap cleanup EXIT

# ── Upstream helper ──
CLONE_TMPDIR=$(mktemp -d)
cleanup_clone() { rm -rf "$CLONE_TMPDIR"; rm -f "$TMP_MANIFEST"; if [ -n "$NODEJS_SHIM_DIR" ] && [ -d "$NODEJS_SHIM_DIR" ]; then rm -rf "$NODEJS_SHIM_DIR"; fi; }
trap cleanup_clone EXIT

UPSTREAM_DIR=""
init_upstream() {
  local name="$1" url="$2"
  local submod_path="$REPO_ROOT/upstream/$name"
  if [ -d "$submod_path/.git" ] || [ -f "$submod_path/.git" ]; then
    UPSTREAM_DIR="$submod_path"
    return 0
  fi
  if git -C "$REPO_ROOT" submodule update --init --depth 1 "upstream/$name" 2>/dev/null; then
    UPSTREAM_DIR="$submod_path"
    return 0
  fi
  echo "  WARNING: submodule init failed for $name, falling back to git clone..."
  UPSTREAM_DIR="$CLONE_TMPDIR/$name"
  git clone --depth 1 "$url" "$UPSTREAM_DIR" 2>/dev/null || return 1
}

append_path_once() {
  local candidate="$1"
  [ -n "$candidate" ] || return 1
  [ -d "$candidate" ] || return 1

  case ":$PATH:" in
    *":$candidate:"*) return 0 ;;
  esac

  PATH="$PATH:$candidate"
  export PATH
}

link_windows_node_shims() {
  local candidate="$1"

  [ -f "$candidate/node.exe" ] || return 1

  if [ -z "$NODEJS_SHIM_DIR" ]; then
    NODEJS_SHIM_DIR="$(mktemp -d)"
  fi

  ln -sf "$candidate/node.exe" "$NODEJS_SHIM_DIR/node"
  [ -f "$candidate/npm" ] && ln -sf "$candidate/npm" "$NODEJS_SHIM_DIR/npm"
  [ -f "$candidate/npx" ] && ln -sf "$candidate/npx" "$NODEJS_SHIM_DIR/npx"
  append_path_once "$NODEJS_SHIM_DIR"
}

ensure_nodejs_on_path() {
  local candidate raw_path unix_path

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return 0
  fi

  for candidate in \
    "/c/Program Files/nodejs" \
    "/c/Program Files (x86)/nodejs" \
    "/c/nodejs" \
    "/mnt/c/Program Files/nodejs" \
    "/mnt/c/Program Files (x86)/nodejs" \
    "/mnt/c/nodejs"
  do
    [ -d "$candidate" ] || continue
    append_path_once "$candidate"
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      return 0
    fi
    link_windows_node_shims "$candidate" || true
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      return 0
    fi
  done

  if command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    while IFS= read -r raw_path; do
      raw_path="${raw_path%$'\r'}"
      [ -n "$raw_path" ] || continue

      unix_path="$(cygpath -u "$raw_path" 2>/dev/null || true)"
      [ -d "$unix_path" ] || continue

      append_path_once "$unix_path"
      if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        return 0
      fi
      link_windows_node_shims "$unix_path" || true
      if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        return 0
      fi
    done <<EOF
$(powershell.exe -NoProfile -Command "$paths=@(); $machine=[Environment]::GetEnvironmentVariable('Path','Machine'); if($machine){$paths += $machine -split ';'}; $user=[Environment]::GetEnvironmentVariable('Path','User'); if($user){$paths += $user -split ';'}; $paths | Where-Object { $_ } | Select-Object -Unique" 2>/dev/null)
EOF
  fi
}

PACK_MANAGER="$SCRIPT_DIR/scripts/agent-pack-manager.sh"
PROFILE_OVERRIDE=""
WITH_PACKS=""

# ── Argument parsing ──
SKIP_AGENCY=0
SKIP_ECC=0
SKIP_AWESOME=0
SKIP_OMX=0
SKIP_GSTACK=0
SKIP_SUPERPOWERS=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE_OVERRIDE="${2:-}"
      shift 2
      ;;
    --with-packs=*)
      WITH_PACKS="${1#*=}"
      shift
      ;;
    --skip-agency)     SKIP_AGENCY=1; shift ;;
    --skip-ecc)        SKIP_ECC=1; shift ;;
    --skip-awesome)    SKIP_AWESOME=1; shift ;;
    --skip-omx)        SKIP_OMX=1; shift ;;
    --skip-gstack)     SKIP_GSTACK=1; shift ;;
    --skip-superpowers) SKIP_SUPERPOWERS=1; shift ;;
    --self-only)
      SKIP_AGENCY=1; SKIP_ECC=1; SKIP_AWESOME=1
      SKIP_OMX=1; SKIP_GSTACK=1; SKIP_SUPERPOWERS=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  bash install.sh
  bash install.sh --profile minimal|dev|full
  bash install.sh --with-packs <pack1,pack2,...>

Options:
  --with-packs=<packs>  Comma-separated list of agent packs to symlink into ~/.codex/agents/
  --skip-agency         Skip agency-agents upstream install
  --skip-ecc            Skip everything-claude-code upstream install
  --skip-awesome        Skip awesome-codex-subagents upstream install
  --skip-omx            Skip oh-my-codex upstream install
  --skip-gstack         Skip gstack upstream install
  --skip-superpowers    Skip superpowers upstream install
  --self-only           Install only self-owned files (implies all --skip-* flags)
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

add_manifest_entry() {
  printf '%s\n' "$1" >> "$TMP_MANIFEST"
}

format_enabled_packs() {
  local state_file="$1"
  if [ ! -f "$state_file" ]; then
    echo "UNSET"
    return
  fi

  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      packs[count++] = $0
    }
    END {
      if (count == 0) {
        print "none"
        exit
      }
      for (i = 0; i < count; i++) {
        printf "%s%s", packs[i], (i + 1 < count ? ", " : "\n")
      }
    }
  ' "$state_file"
}

current_install_version() {
  if [ -d "$REPO_ROOT/.git" ]; then
    git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown'
  else
    printf 'unknown'
  fi
}

remove_manifest_paths() {
  local manifest="$1"
  [ -f "$manifest" ] || return 1

  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    rm -rf "$CODEX_ROOT/$rel_path" 2>/dev/null || true
  done < "$manifest"
}

legacy_cleanup() {
  local src_dir cat_dir cat_name file_name skill_dir

  # Clean flat agents from core/omo/omc/awesome-core (self-owned dirs)
  for src_dir in \
    "$REPO_ROOT/codex-agents/core" \
    "$REPO_ROOT/codex-agents/omo"
  do
    [ -d "$src_dir" ] || continue
    for file_name in "$src_dir"/*.toml; do
      [ -f "$file_name" ] || continue
      rm -f "$CODEX_ROOT/agents/$(basename "$file_name")" 2>/dev/null || true
    done
  done

  # Clean skills from self-owned core
  if [ -d "$REPO_ROOT/skills/core" ] && [ -d "$CODEX_ROOT/skills" ]; then
    for skill_dir in "$REPO_ROOT/skills/core/"*/; do
      [ -d "$skill_dir" ] || continue
      rm -rf "$CODEX_ROOT/skills/$(basename "$skill_dir")" 2>/dev/null || true
    done
  fi
}

copy_toml_dir() {
  local src_dir="$1"
  local dest_dir="$2"
  local file_name dest_file rel_path
  [ -d "$src_dir" ] || return 0

  mkdir -p "$dest_dir"
  for file_name in "$src_dir"/*.toml; do
    [ -f "$file_name" ] || continue
    dest_file="$dest_dir/$(basename "$file_name")"
    cp "$file_name" "$dest_file"
    rel_path="${dest_file#"$CODEX_ROOT"/}"
    add_manifest_entry "$rel_path"
  done
}

# Like copy_toml_dir but skips files whose basename already exists in agents/
copy_toml_dir_dedup() {
  local src_dir="$1"
  local dest_dir="$2"
  local file_name bname dest_file rel_path
  [ -d "$src_dir" ] || return 0

  mkdir -p "$dest_dir"
  for file_name in "$src_dir"/*.toml; do
    [ -f "$file_name" ] || continue
    bname="$(basename "$file_name")"
    [ -f "$CODEX_ROOT/agents/$bname" ] && continue
    dest_file="$dest_dir/$bname"
    cp "$file_name" "$dest_file"
    rel_path="${dest_file#"$CODEX_ROOT"/}"
    add_manifest_entry "$rel_path"
  done
}

copy_skill_dirs() {
  local skill_src="$1"
  local skill_dir dest_dir rel_path
  [ -d "$skill_src" ] || return 0

  mkdir -p "$CODEX_ROOT/skills"
  for skill_dir in "$skill_src/"*/; do
    [ -d "$skill_dir" ] || continue
    dest_dir="$CODEX_ROOT/skills/$(basename "$skill_dir")"
    rm -rf "$dest_dir" 2>/dev/null || true
    cp -R "$skill_dir" "$dest_dir"
    rel_path="${dest_dir#"$CODEX_ROOT"/}"
    add_manifest_entry "$rel_path"
  done
}

patch_yaml_scalar_line() {
  local file_path="$1"
  local key="$2"
  [ -f "$file_path" ] || return 0

  awk -v key="$key" '
    BEGIN { patched = 0 }
    index($0, key ": ") == 1 && patched == 0 {
      value = substr($0, length(key) + 3)
      gsub(/\r/, "", value)
      gsub(/"/, "\\\"", value)
      print key ": \"" value "\""
      patched = 1
      next
    }
    { print }
  ' "$file_path" > "$file_path.tmp" && mv "$file_path.tmp" "$file_path"
}

patch_gstack_openclaw_skills() {
  local gstack_root="$1"
  local skill_file
  [ -d "$gstack_root/openclaw/skills" ] || return 0

  for skill_file in \
    "$gstack_root/openclaw/skills/gstack-openclaw-ceo-review/SKILL.md" \
    "$gstack_root/openclaw/skills/gstack-openclaw-investigate/SKILL.md" \
    "$gstack_root/openclaw/skills/gstack-openclaw-office-hours/SKILL.md"
  do
    patch_yaml_scalar_line "$skill_file" description
  done
}

install_skill_copy() {
  local src_dir="$1"
  local dest_name="$2"
  local dest_dir rel_path
  [ -d "$src_dir" ] || return 0

  dest_dir="$CODEX_ROOT/skills/$dest_name"
  rm -rf "$dest_dir" 2>/dev/null || true
  cp -R "$src_dir" "$dest_dir"
  rel_path="${dest_dir#"$CODEX_ROOT"/}"
  add_manifest_entry "$rel_path"
}

fix_windows_gstack_skill_aliases() {
  local gstack_root="$1"
  local connect_skill

  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;;
    *) return 0 ;;
  esac

  install_skill_copy "$gstack_root/benchmark" "benchmark"

  rm -rf "$CODEX_ROOT/skills/connect-chrome" 2>/dev/null || true
  if [ -d "$gstack_root/open-gstack-browser" ]; then
    install_skill_copy "$gstack_root/open-gstack-browser" "connect-chrome"
    connect_skill="$CODEX_ROOT/skills/connect-chrome/SKILL.md"
    if [ -f "$connect_skill" ]; then
      awk '
        NR == 1 {
          sub(/^\xef\xbb\xbf/, "", $0)
        }
        BEGIN { name_done = 0; desc_done = 0; skipping_desc = 0 }
        /^name:[[:space:]]/ && name_done == 0 {
          print "name: connect-chrome"
          name_done = 1
          next
        }
        /^description:[[:space:]]/ && desc_done == 0 {
          print "description: |"
          print "  Backward-compatible alias for open-gstack-browser."
          print "  Launch GStack Browser ??AI-controlled Chromium with the sidebar extension baked in."
          print "  Opens a visible browser window where you can watch every action in real time."
          print "  The sidebar shows a live activity feed and chat. Anti-bot stealth built in."
          print "  Use when asked to \"open gstack browser\", \"launch browser\", \"connect chrome\","
          print "  \"open chrome\", \"real browser\", \"launch chrome\", \"side panel\", or \"control my browser\"."
          print "  Voice triggers (speech-to-text aliases): \"show me the browser\"."
          desc_done = 1
          skipping_desc = 1
          next
        }
        skipping_desc == 1 {
          if ($0 ~ /^  / || $0 ~ /^$/) {
            next
          }
          skipping_desc = 0
        }
        { print }
      ' "$connect_skill" > "$connect_skill.tmp" && mv "$connect_skill.tmp" "$connect_skill"
    fi
  fi
}

count_managed_skills() {
  local count=0
  [ -d "$CODEX_ROOT/skills" ] || { printf '0'; return; }
  count=$(find "$CODEX_ROOT/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
  printf '%s' "$count"
}

cleanup_cross_tool_skills() {
  local skill_dir skill_name source_skill installed_skill link_target
  # Clean ECC skills from cross-tool locations
  for skills_src in "$CODEX_ROOT/skills"; do
    [ -d "$skills_src" ] || continue
    for skill_dir in "$skills_src/"*/; do
      [ -d "$skill_dir" ] || continue
      skill_name="$(basename "$skill_dir")"
      source_skill="$skill_dir/SKILL.md"
      [ -f "$source_skill" ] || continue

      installed_skill="$AGENTS_SKILLS_ROOT/$skill_name/SKILL.md"
      if [ -f "$installed_skill" ] && [ -f "$source_skill" ]; then
        if [ "$(head -n 1 "$installed_skill" | tr -d '\r')" != '---' ] && [ "$(head -n 1 "$source_skill" | tr -d '\r')" = '---' ]; then
          rm -rf "$AGENTS_SKILLS_ROOT/$skill_name" 2>/dev/null || true
        fi
      fi

      installed_skill="$CLAUDE_SKILLS_ROOT/$skill_name/SKILL.md"
      if [ -L "$CLAUDE_SKILLS_ROOT/$skill_name" ]; then
        link_target="$(readlink "$CLAUDE_SKILLS_ROOT/$skill_name" 2>/dev/null || true)"
        case "$link_target" in
          *".agents/skills/$skill_name"|*".agents/skills/$skill_name/")
            rm -f "$CLAUDE_SKILLS_ROOT/$skill_name" 2>/dev/null || true
            ;;
        esac
      elif [ -f "$installed_skill" ] && [ -f "$source_skill" ]; then
        if [ "$(head -n 1 "$installed_skill" | tr -d '\r')" != '---' ] && [ "$(head -n 1 "$source_skill" | tr -d '\r')" = '---' ]; then
          rm -rf "$CLAUDE_SKILLS_ROOT/$skill_name" 2>/dev/null || true
        fi
      fi
    done
  done
}

patch_npm_shims() {
  # Patch npm shims (codex.cmd, codex.ps1, extensionless codex) so they run
  # the SessionStart hook before delegating to the original npm shim.
  # Only runs on Windows (MSYS/Cygwin environments used by Git Bash).
  # Safe to re-run: checks for sentinel marker before patching.
  # Never aborts the install if npm shims are absent or patching fails.

  if [[ "${OSTYPE:-}" != msys* && "${OSTYPE:-}" != cygwin* ]]; then
    return 0
  fi

  local npm_dir
  npm_dir="$(cygpath -u "${APPDATA:-}" 2>/dev/null)/npm"
  if [ ! -d "$npm_dir" ]; then
    echo "  npm shim patching: $npm_dir not found, skipping"
    return 0
  fi

  # --- codex.cmd ---
  local cmd_shim="$npm_dir/codex.cmd"
  if [ -f "$cmd_shim" ]; then
    if grep -q 'my-codex wrapper' "$cmd_shim" 2>/dev/null; then
      echo "  npm codex.cmd: already patched, skipping"
    else
      local backup="$npm_dir/codex.real.cmd"
      if [ ! -f "$backup" ]; then
        cp "$cmd_shim" "$backup"
        echo "  npm codex.cmd: backed up to codex.real.cmd"
      fi
      cat > "$cmd_shim" <<'CMDEOF'
@ECHO off
REM my-codex wrapper - runs SessionStart hook via Git Bash, logs invocation, delegates to codex.real.cmd
SETLOCAL EnableDelayedExpansion

IF DEFINED CODEX_WRAPPER_INVOKED GOTO :delegate
SET "CODEX_WRAPPER_INVOKED=1"

SET "GIT_BASH="
IF EXIST "%ProgramFiles%\Git\bin\bash.exe" SET "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
IF NOT DEFINED GIT_BASH IF EXIST "%ProgramFiles%\Git\usr\bin\bash.exe" SET "GIT_BASH=%ProgramFiles%\Git\usr\bin\bash.exe"
IF NOT DEFINED GIT_BASH IF EXIST "%ProgramFiles(x86)%\Git\bin\bash.exe" SET "GIT_BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"

SET "HOOK_OK=no"
IF EXIST "%USERPROFILE%\.codex\hooks\session-start.sh" SET "HOOK_OK=yes"

IF NOT DEFINED GIT_BASH GOTO :afterhook
IF NOT "!HOOK_OK!"=="yes" GOTO :afterhook
"!GIT_BASH!" "%USERPROFILE%\.codex\hooks\session-start.sh" 1>NUL 2>NUL
:afterhook

FOR /F "tokens=*" %%T IN ('powershell -NoProfile -Command "Get-Date -UFormat '%%Y-%%m-%%dT%%H:%%M:%%SZ'" 2^>NUL') DO SET "TS=%%T"
IF NOT DEFINED TS SET "TS=unknown"
>> "%USERPROFILE%\.codex\last-invocation.log" ECHO !TS!	wrapper=npm\codex.cmd	cwd=!CD!	hook_installed=!HOOK_OK!	git_bash=!GIT_BASH!

:delegate
CALL "%~dp0codex.real.cmd" %*
EXIT /B !ERRORLEVEL!
CMDEOF
      echo "  npm codex.cmd: patched"
    fi
  else
    echo "  npm codex.cmd: not found, skipping"
  fi

  # --- codex.ps1 ---
  local ps1_shim="$npm_dir/codex.ps1"
  if [ -f "$ps1_shim" ]; then
    if grep -q 'my-codex' "$ps1_shim" 2>/dev/null; then
      echo "  npm codex.ps1: already patched, skipping"
    else
      local ps1_backup="$npm_dir/codex.real.ps1"
      if [ ! -f "$ps1_backup" ]; then
        cp "$ps1_shim" "$ps1_backup"
        echo "  npm codex.ps1: backed up to codex.real.ps1"
      fi
      cat > "$ps1_shim" <<'PS1EOF'
#!/usr/bin/env pwsh
# my-codex in-place patch of npm codex.ps1
# Runs SessionStart hook via Git Bash, logs invocation, delegates to codex.real.ps1.

if (-not $env:CODEX_WRAPPER_INVOKED) {
    $env:CODEX_WRAPPER_INVOKED = "1"

    $gitBash = @(
        (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
        (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe")
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    $hookPath = Join-Path $env:USERPROFILE ".codex\hooks\session-start.sh"
    $hookOk = if (Test-Path $hookPath) { "yes" } else { "no" }

    if ($gitBash -and ($hookOk -eq "yes")) {
        try { & $gitBash $hookPath *> $null } catch {}
    }

    try {
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $logPath = Join-Path $env:USERPROFILE ".codex\last-invocation.log"
        $line = "$ts`twrapper=npm\codex.ps1`tcwd=$($PWD.Path)`thook_installed=$hookOk`tgit_bash=$gitBash"
        Add-Content -Path $logPath -Value $line -Encoding UTF8
    } catch {}
}

& "$PSScriptRoot\codex.real.ps1" @args
exit $LASTEXITCODE
PS1EOF
      echo "  npm codex.ps1: patched"
    fi
  else
    echo "  npm codex.ps1: not found, skipping"
  fi

  # --- extensionless bash shim ---
  local bash_shim="$npm_dir/codex"
  if [ -f "$bash_shim" ]; then
    if grep -q 'my-codex' "$bash_shim" 2>/dev/null; then
      echo "  npm codex (bash shim): already patched, skipping"
    else
      local bash_backup="$npm_dir/codex.real"
      if [ ! -f "$bash_backup" ]; then
        cp "$bash_shim" "$bash_backup"
        echo "  npm codex (bash shim): backed up to codex.real"
      fi
      cat > "$bash_shim" <<'BASHEOF'
#!/bin/sh
# my-codex in-place patch of npm codex (bash shim)
# Runs SessionStart hook, logs invocation, then delegates to codex.real.

basedir=$(dirname "$(echo "$0" | sed -e 's,\,/,g')")

if [ -z "${CODEX_WRAPPER_INVOKED:-}" ]; then
  export CODEX_WRAPPER_INVOKED=1
  hook_path="$HOME/.codex/hooks/session-start.sh"
  hook_ok="no"
  if [ -f "$hook_path" ]; then
    hook_ok="yes"
    bash "$hook_path" >/dev/null 2>&1 || true
  fi
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)
  printf '%s\twrapper=npm/codex\tcwd=%s\thook_installed=%s\n' "$ts" "$PWD" "$hook_ok" \
    >> "$HOME/.codex/last-invocation.log" 2>/dev/null || true
fi

exec "$basedir/codex.real" "$@"
BASHEOF
      echo "  npm codex (bash shim): patched"
    fi
  else
    echo "  npm codex (bash shim): not found, skipping"
  fi
}

INSTALLING_VERSION="$(current_install_version)"
INSTALLED_VERSION="none"
if [ -f "$VERSION_FILE" ]; then
  INSTALLED_VERSION="$(cat "$VERSION_FILE")"
fi

echo "=== my-codex installer ==="
echo ""
echo "Install footprint: 330+ agents, 200+ skills from 6 upstream sources"
if [ "$INSTALLED_VERSION" = "none" ]; then
  echo "Install mode: fresh (${INSTALLING_VERSION})"
elif [ "$INSTALLED_VERSION" = "$INSTALLING_VERSION" ]; then
  echo "Install mode: reinstall (${INSTALLING_VERSION})"
else
  echo "Install mode: update (${INSTALLED_VERSION} -> ${INSTALLING_VERSION})"
fi
echo ""

echo "[0/7] Checking prerequisites..."
ensure_nodejs_on_path
command -v node >/dev/null 2>&1 || { echo "ERROR: node not found. Install Node.js v20+"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ERROR: npm not found"; exit 1; }
command -v git  >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
if ! command -v codex >/dev/null 2>&1; then
  echo "WARNING: codex CLI not found. Install from https://github.com/openai/codex"
  echo "  Continuing anyway -- agents will be ready when codex is installed."
fi
echo "  Prerequisites OK"

echo "[0.5/7] Cleaning previous my-codex-managed installation..."
mkdir -p "$CODEX_ROOT/agents" "$CODEX_ROOT/agent-packs" "$CODEX_ROOT/skills"
if [ -x "$PACK_MANAGER" ]; then
  HOME="$HOME" "$PACK_MANAGER" ensure-state
fi
if ! remove_manifest_paths "$MANIFEST_FILE"; then
  legacy_cleanup
fi
cleanup_cross_tool_skills
echo "  Previous my-codex-managed files cleaned"

echo "[1/7] Installing Codex agents..."
mkdir -p "$CODEX_ROOT/agents" "$CODEX_ROOT/agent-packs"

# ── 1a. Self-owned agents (always installed) ──
echo "  [core] Installing self-owned agents..."
copy_toml_dir "$REPO_ROOT/codex-agents/core" "$CODEX_ROOT/agents"
copy_toml_dir "$REPO_ROOT/codex-agents/omo" "$CODEX_ROOT/agents"

# ── 1b. Upstream: oh-my-codex (omc agents) ──
if [ "$SKIP_OMX" = "0" ]; then
  echo "  [omx] Initializing oh-my-codex..."
  if init_upstream omx https://github.com/Yeachan-Heo/oh-my-codex; then
    # OMX has prompts/ in MD format — need conversion to TOML
    if [ -d "$UPSTREAM_DIR/prompts" ] && [ -f "$REPO_ROOT/scripts/md-to-toml.sh" ]; then
      omc_staging="$CLONE_TMPDIR/omc-staging"
      mkdir -p "$omc_staging/omc"
      for md_file in "$UPSTREAM_DIR/prompts/"*.md; do
        [ -f "$md_file" ] || continue
        bname="$(basename "$md_file")"
        fname="${bname%.md}"
        # Check if file has YAML frontmatter at all
        first_line="$(head -1 "$md_file" | tr -d '\r')"
        if [ "$first_line" != "---" ]; then
          # No frontmatter: generate a minimal TOML directly and skip md-to-toml conversion
          {
            printf 'name = "%s"\n' "$fname"
            printf 'description = "Team orchestration specialist"\n'
            printf 'model = "o3"\n'
            printf 'model_reasoning_effort = "medium"\n'
            printf 'developer_instructions = """\n'
            tr -d '\r' < "$md_file"
            printf '\n"""\n'
          } > "$omc_staging/omc/${fname}.toml"
          continue
        fi
        # Add name: field from filename if missing
        if ! grep -q '^name:' "$md_file" 2>/dev/null; then
          cp "$md_file" "$omc_staging/omc/$bname"
          # Insert name: after first ---
          sed -i "1,/^---$/{/^---$/a\\
name: $fname
}" "$omc_staging/omc/$bname" 2>/dev/null || true
        else
          cp "$md_file" "$omc_staging/omc/$bname"
        fi
        # Add model: if missing
        if ! grep -q '^model:' "$omc_staging/omc/$bname" 2>/dev/null; then
          sed -i '/^description:/a model: gpt-5.4' "$omc_staging/omc/$bname" 2>/dev/null || true
        fi
      done
      omc_toml_out="$CLONE_TMPDIR/omc-toml"
      bash "$REPO_ROOT/scripts/md-to-toml.sh" "$omc_staging" "$omc_toml_out" 2>/dev/null || true
      if [ -d "$omc_toml_out/omc" ]; then
        copy_toml_dir "$omc_toml_out/omc" "$CODEX_ROOT/agents"
      fi
      # Also copy any pre-generated TOMLs (from files without frontmatter)
      copy_toml_dir "$omc_staging/omc" "$CODEX_ROOT/agents"
    fi
  fi
fi

# ── 1c. Upstream: awesome-codex-subagents ──
if [ "$SKIP_AWESOME" = "0" ]; then
  echo "  [awesome] Initializing awesome-codex-subagents..."
  if init_upstream awesome https://github.com/VoltAgent/awesome-codex-subagents; then
    # awesome-core categories → auto-loaded agents
    if [ -d "$UPSTREAM_DIR/categories" ]; then
      for cat_dir in "$UPSTREAM_DIR/categories/"*/; do
        [ -d "$cat_dir" ] || continue
        raw_name="$(basename "$cat_dir")"
        cat_name="${raw_name#[0-9][0-9]-}"
        case "$raw_name" in
          01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
            copy_toml_dir "$cat_dir" "$CODEX_ROOT/agents"
            ;;
          *)
            copy_toml_dir_dedup "$cat_dir" "$CODEX_ROOT/agent-packs/$cat_name"
            ;;
        esac
      done
    fi
  fi
fi

# ── 1d. Upstream: superpowers ──
if [ "$SKIP_SUPERPOWERS" = "0" ]; then
  echo "  [superpowers] Initializing superpowers..."
  if init_upstream superpowers https://github.com/obra/superpowers; then
    # superpowers has a single agent (code-reviewer.md) — convert at install time
    if [ -f "$UPSTREAM_DIR/agents/code-reviewer.md" ] && [ -f "$REPO_ROOT/scripts/md-to-toml.sh" ]; then
      local_staging="$CLONE_TMPDIR/superpowers-staging"
      mkdir -p "$local_staging/agents"
      cp "$UPSTREAM_DIR/agents/code-reviewer.md" "$local_staging/agents/"
      local_toml_out="$CLONE_TMPDIR/superpowers-toml"
      mkdir -p "$local_toml_out"
      bash "$REPO_ROOT/scripts/md-to-toml.sh" "$local_staging" "$local_toml_out" 2>/dev/null || true
      # Rename to superpowers-code-reviewer to avoid collision with other code-reviewer agents
      if [ -f "$local_toml_out/agents/code-reviewer.toml" ]; then
        sed -i 's/^name = "code-reviewer"$/name = "superpowers-code-reviewer"/' \
          "$local_toml_out/agents/code-reviewer.toml" 2>/dev/null || true
        cp "$local_toml_out/agents/code-reviewer.toml" "$CODEX_ROOT/agents/superpowers-code-reviewer.toml"
        add_manifest_entry "agents/superpowers-code-reviewer.toml"
      fi
    fi
  fi
fi

# ── 1e. Upstream: agency-agents (MD → TOML conversion) ──
if [ "$SKIP_AGENCY" = "0" ]; then
  echo "  [agency] Initializing agency-agents..."
  if init_upstream agency-agents https://github.com/msitarzewski/agency-agents; then
    # Agency agents are in MD format — need staging + conversion
    agency_staging="$CLONE_TMPDIR/agency-staging"
    mkdir -p "$agency_staging"
    for cat in engineering design testing product game-development marketing \
               sales academic project-management specialized spatial-computing \
               support strategy paid-media; do
      if [ -d "$UPSTREAM_DIR/$cat" ]; then
        mkdir -p "$agency_staging/$cat"
        cp "$UPSTREAM_DIR/$cat/"*.md "$agency_staging/$cat/" 2>/dev/null || true
      fi
    done
    # Add model field to agents missing it
    find "$agency_staging" -name '*.md' | while read f; do
      if ! grep -q '^model:' "$f" 2>/dev/null; then
        sed -i '/^description:/a model: gpt-5.4' "$f" 2>/dev/null || true
      fi
    done
    # Convert MD → TOML
    agency_toml_out="$CLONE_TMPDIR/agency-toml"
    if [ -f "$REPO_ROOT/scripts/md-to-toml.sh" ]; then
      bash "$REPO_ROOT/scripts/md-to-toml.sh" "$agency_staging" "$agency_toml_out" 2>/dev/null || true
    fi
    # Copy converted TOML to agent-packs (agency agents are domain specialists)
    if [ -d "$agency_toml_out" ]; then
      for cat_dir in "$agency_toml_out/"*/; do
        [ -d "$cat_dir" ] || continue
        cat_name="$(basename "$cat_dir")"
        copy_toml_dir "$cat_dir" "$CODEX_ROOT/agent-packs/$cat_name"
      done
    fi
  fi
fi

echo "  Core agents: $(find "$CODEX_ROOT/agents" -maxdepth 1 -name '*.toml' | wc -l | tr -d ' ') installed"
echo "  Agent packs: $(find "$CODEX_ROOT/agent-packs" -name '*.toml' | wc -l | tr -d ' ') installed"

# --with-packs: symlink requested pack agents into ~/.codex/agents/
if [ -n "$WITH_PACKS" ]; then
  IFS=',' read -ra PACKS <<< "$WITH_PACKS"
  for pack in "${PACKS[@]}"; do
    pack_dir="$CODEX_ROOT/agent-packs/$pack"
    if [ -d "$pack_dir" ]; then
      for agent in "$pack_dir"/*.toml; do
        [ -f "$agent" ] || continue
        basename=$(basename "$agent")
        # Skip if file already exists (dedup)
        [ -f "$CODEX_ROOT/agents/$basename" ] && continue
        ln -sf "$agent" "$CODEX_ROOT/agents/$basename"
        echo "  Symlinked: $basename (from $pack)"
      done
    else
      echo "  WARNING: Pack '$pack' not found in $CODEX_ROOT/agent-packs/"
    fi
  done
fi

if [ -n "$PROFILE_OVERRIDE" ] && [ -x "$PACK_MANAGER" ]; then
  HOME="$HOME" "$PACK_MANAGER" set-profile "$PROFILE_OVERRIDE"
fi

echo "[2/7] Installing skills..."
mkdir -p "$CODEX_ROOT/skills"

# ── 2a. Self-owned skills ──
echo "  [core] Installing self-owned skills..."
copy_skill_dirs "$REPO_ROOT/skills/core"

# ── 2b. Upstream: ECC skills ──
if [ "$SKIP_ECC" = "0" ]; then
  echo "  [ecc] Initializing everything-claude-code..."
  if init_upstream ecc https://github.com/affaan-m/everything-claude-code; then
    if [ -d "$UPSTREAM_DIR/skills" ]; then
      copy_skill_dirs "$UPSTREAM_DIR/skills"
    fi
  fi
fi

# ── 2c. Upstream: superpowers skills ──
if [ "$SKIP_SUPERPOWERS" = "0" ]; then
  # init_upstream already called above; reuse UPSTREAM_DIR if set
  sp_dir="$REPO_ROOT/upstream/superpowers"
  if [ ! -d "$sp_dir/.git" ] && [ ! -f "$sp_dir/.git" ]; then
    sp_dir="$CLONE_TMPDIR/superpowers"
  fi
  if [ -d "$sp_dir/skills" ]; then
    echo "  [superpowers] Installing superpowers skills..."
    copy_skill_dirs "$sp_dir/skills"
  fi
fi

# ── 2d. Upstream: gstack (runtime install) ──
if [ "$SKIP_GSTACK" = "0" ]; then
  echo "  [gstack] Initializing gstack..."
  if init_upstream gstack https://github.com/garrytan/gstack; then
    GSTACK_DIR="$CODEX_ROOT/skills/gstack"
    if [ -d "$GSTACK_DIR/.git" ]; then
      git -C "$GSTACK_DIR" pull --ff-only 2>/dev/null || true
    else
      rm -rf "$GSTACK_DIR"
      cp -R "$UPSTREAM_DIR" "$GSTACK_DIR" 2>/dev/null || \
        git clone --depth 1 https://github.com/garrytan/gstack.git "$GSTACK_DIR" 2>/dev/null || true
    fi

    # Install bun if missing (required for gstack browser)
    if ! command -v bun >/dev/null 2>&1; then
      echo "  [gstack] Installing bun..."
      curl -fsSL https://bun.sh/install | bash 2>/dev/null || true
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
    fi

    # Remove superseded ECC skills replaced by gstack (preserve gstack symlinks)
    for skill in benchmark canary-watch safety-guard browser-qa verification-loop security-review design-system; do
      target="$CODEX_ROOT/skills/$skill"
      if [ -L "$target" ]; then
        link_dest=$(readlink "$target")
        case "$link_dest" in *gstack*) continue ;; esac
        rm -f "$target"
      elif [ -d "$target" ]; then
        rm -rf "$target"
      fi
    done

    # Run gstack setup
    if [ -d "$GSTACK_DIR" ] && command -v bun >/dev/null 2>&1 && [ -f "$GSTACK_DIR/setup" ]; then
      (cd "$GSTACK_DIR" && ./setup --host codex 2>/dev/null || true)
    fi

    # Restore SKILL.md files if deleted by gen:skill-docs
    git -C "$GSTACK_DIR" checkout -- '*/SKILL.md' 'SKILL.md' 2>/dev/null || true
    patch_gstack_openclaw_skills "$GSTACK_DIR"
    fix_windows_gstack_skill_aliases "$GSTACK_DIR"

    # Fallback: ensure individual gstack skills are accessible at depth 1
    if [ -d "$GSTACK_DIR" ]; then
      for skill_dir in "$GSTACK_DIR"/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        skill_name=$(basename "$skill_dir")
        case "$skill_name" in .git|bin|node_modules|agents) continue ;; esac
        target="$CODEX_ROOT/skills/$skill_name"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
          case "$(uname -s)" in
            MINGW*|MSYS*|CYGWIN*) cp -r "$skill_dir" "$target" ;;
            *) ln -s "$(cd "$skill_dir" && pwd)" "$target" 2>/dev/null || cp -r "$skill_dir" "$target" ;;
          esac
        fi
      done
    fi

    # gstack auto_upgrade config
    mkdir -p "$HOME/.gstack"
    GSTACK_CONFIG="$HOME/.gstack/config.json"
    if [ -f "$GSTACK_CONFIG" ]; then
      node -e "
        const fs = require('fs');
        const cfg = JSON.parse(fs.readFileSync('$GSTACK_CONFIG', 'utf8'));
        cfg.auto_upgrade = true;
        fs.writeFileSync('$GSTACK_CONFIG', JSON.stringify(cfg, null, 2));
      " 2>/dev/null || true
    else
      echo '{"auto_upgrade":true}' > "$GSTACK_CONFIG"
    fi
  fi
fi

managed_skills="$(count_managed_skills)"
total_skills="$(find "$CODEX_ROOT/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
extra_skills=$((total_skills - managed_skills))
echo "  Skills: ${managed_skills} installed"
if [ "$extra_skills" -gt 0 ]; then
  echo "  Preserved custom ~/.codex skills: ${extra_skills}"
fi

echo "[2.5/7] Activating recommended agent packs..."
if [ -x "$PACK_MANAGER" ]; then
  active_pack_agents="$(HOME="$HOME" "$PACK_MANAGER" activate)"
  echo "  Enabled packs: $(format_enabled_packs "$CODEX_ROOT/enabled-agent-packs.txt")"
  echo "  Active pack agents: ${active_pack_agents}"
else
  echo "  WARNING: agent pack manager missing; no packs were activated"
fi

echo "[3/7] Setting up AGENTS.md..."
if [ ! -f "$CODEX_ROOT/AGENTS.md" ]; then
  cp "$REPO_ROOT/templates/codex-AGENTS.md" "$CODEX_ROOT/AGENTS.md"
  echo "  AGENTS.md created"
else
  echo "  AGENTS.md already exists -- skipping (delete to regenerate)"
fi

echo "[3.5/7] Installing hooks..."
mkdir -p "$CODEX_ROOT/hooks"
if [ -f "$REPO_ROOT/hooks/hooks.json" ]; then
  cp "$REPO_ROOT/hooks/hooks.json" "$CODEX_ROOT/hooks/hooks.json"
  add_manifest_entry "hooks/hooks.json"
fi
if [ -f "$REPO_ROOT/hooks/session-start.sh" ]; then
  cp "$REPO_ROOT/hooks/session-start.sh" "$CODEX_ROOT/hooks/session-start.sh"
  chmod +x "$CODEX_ROOT/hooks/session-start.sh"
  add_manifest_entry "hooks/session-start.sh"
fi
if [ -f "$REPO_ROOT/hooks/stop-profile-update.js" ]; then
  cp "$REPO_ROOT/hooks/stop-profile-update.js" "$CODEX_ROOT/hooks/stop-profile-update.js"
  add_manifest_entry "hooks/stop-profile-update.js"
fi
if [ -f "$REPO_ROOT/hooks/persona-rule.js" ]; then
  cp "$REPO_ROOT/hooks/persona-rule.js" "$CODEX_ROOT/hooks/persona-rule.js"
  add_manifest_entry "hooks/persona-rule.js"
fi
echo "  Hooks installed (vault enforcement + persona)"

echo "[4/7] Configuring config.toml..."
CONFIG_FILE="$CODEX_ROOT/config.toml"
touch "$CONFIG_FILE"
if ! grep -q 'multi_agent' "$CONFIG_FILE" 2>/dev/null; then
  cat >> "$CONFIG_FILE" << 'TOML'

# my-codex managed settings
[features]
multi_agent = true
child_agents_md = true

[agents]
max_threads = 8
TOML
  echo "  config.toml updated (multi_agent enabled, max_threads=8)"
else
  echo "  config.toml already configured"
fi

echo "[4.5/7] Installing Codex attribution defaults..."
mkdir -p "$CODEX_ROOT/bin" "$CODEX_ROOT/lib" "$CODEX_ROOT/git-hooks"
cp "$REPO_ROOT/scripts/codex-attribution-lib.sh" "$CODEX_ROOT/lib/codex-attribution.sh"
cp "$REPO_ROOT/scripts/codex-wrapper.sh" "$CODEX_ROOT/bin/codex"
cp "$REPO_ROOT/bin/codex.cmd" "$CODEX_ROOT/bin/codex.cmd"
cp "$REPO_ROOT/bin/codex.ps1" "$CODEX_ROOT/bin/codex.ps1"
patch_npm_shims
cp "$REPO_ROOT/scripts/codex-mark-used.sh" "$CODEX_ROOT/bin/codex-mark-used"
cp "$REPO_ROOT/scripts/agent-pack-manager.sh" "$CODEX_ROOT/bin/my-codex-packs"
cp "$REPO_ROOT/templates/git-hooks/prepare-commit-msg" "$CODEX_ROOT/git-hooks/prepare-commit-msg"
cp "$REPO_ROOT/templates/git-hooks/commit-msg" "$CODEX_ROOT/git-hooks/commit-msg"
cp "$REPO_ROOT/templates/git-hooks/post-commit" "$CODEX_ROOT/git-hooks/post-commit"
chmod +x "$CODEX_ROOT/lib/codex-attribution.sh" \
  "$CODEX_ROOT/bin/codex" \
  "$CODEX_ROOT/bin/codex-mark-used" \
  "$CODEX_ROOT/bin/my-codex-packs" \
  "$CODEX_ROOT/git-hooks/prepare-commit-msg" \
  "$CODEX_ROOT/git-hooks/commit-msg" \
  "$CODEX_ROOT/git-hooks/post-commit"

git config --global my-codex.codexAttribution true

CURRENT_HOOKS_PATH="$(git config --global core.hooksPath 2>/dev/null || true)"
if [ -n "$CURRENT_HOOKS_PATH" ] && [ "$CURRENT_HOOKS_PATH" != "$CODEX_ROOT/git-hooks" ]; then
  git config --global my-codex.previousHooksPath "$CURRENT_HOOKS_PATH"
fi
git config --global core.hooksPath "$CODEX_ROOT/git-hooks"

for shell_rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  touch "$shell_rc"
  if ! grep -q 'my-codex managed PATH' "$shell_rc" 2>/dev/null; then
    cat >> "$shell_rc" <<'EOF'

# my-codex managed PATH
case ":$PATH:" in
  *":$HOME/.codex/bin:"*) ;;
  *) export PATH="$HOME/.codex/bin:$PATH" ;;
esac
EOF
  fi
done
echo "  Codex wrapper, hooks, and PATH defaults installed"

echo "[5/7] Registering MCP servers..."
if command -v codex >/dev/null 2>&1; then
  MCP_LIST="$(codex mcp list 2>/dev/null || true)"
  ensure_mcp_server() {
    local name="$1"
    shift
    if printf '%s\n' "$MCP_LIST" | grep -qE "^${name}[[:space:]]"; then
      echo "  ${name} already registered"
      return
    fi
    codex mcp add "$name" "$@" 2>/dev/null || echo "  WARNING: failed to register ${name}"
  }
  ensure_mcp_server context7 --url https://mcp.context7.com/mcp
  ensure_mcp_server exa --url "https://mcp.exa.ai/mcp?tools=web_search_exa"
  ensure_mcp_server grep_app --url https://mcp.grep.app
  echo "  MCP registration checked (context7, exa, grep_app)"
else
  echo "  codex not found -- MCP servers will be registered when codex is installed"
fi

echo "[6/7] Installing companion tools..."
echo "  [6a] ast-grep..."
if command -v ast-grep >/dev/null 2>&1; then
  echo "    ast-grep already installed"
else
  npm i -g @ast-grep/cli@0.42.0 2>/dev/null || echo "    WARNING: ast-grep install failed"
fi

LC_ALL=C sort -u "$TMP_MANIFEST" > "$MANIFEST_FILE"
printf '%s\n' "$INSTALLING_VERSION" > "$VERSION_FILE"

echo ""
echo "[7/7] Verification"
echo "  Core agents:   $(find "$CODEX_ROOT/agents" -maxdepth 1 -type f -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Active packs:  $(find "$CODEX_ROOT/agents" -maxdepth 1 -type l -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') linked files"
echo "  Agent packs:   $(find "$CODEX_ROOT/agent-packs" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Enabled packs: $(format_enabled_packs "$CODEX_ROOT/enabled-agent-packs.txt")"
echo "  Skills:        ${managed_skills} installed"
if [ "$extra_skills" -gt 0 ]; then
  echo "  Extra skills:  ${extra_skills} preserved under ~/.codex/skills"
fi
echo "  AGENTS.md:     $(test -f "$CODEX_ROOT/AGENTS.md" && echo 'OK' || echo 'MISSING')"
echo "  config.toml:   $(grep -q 'multi_agent' "$CODEX_ROOT/config.toml" 2>/dev/null && echo 'OK' || echo 'NEEDS CONFIG')"
echo "  hooksPath:     $(git config --global --get core.hooksPath 2>/dev/null || echo 'UNSET')"
echo "  Codex attr:    $(git config --global --get my-codex.codexAttribution 2>/dev/null || echo 'UNSET')"
echo "  version:       $(cat "$VERSION_FILE" 2>/dev/null || echo 'unknown')"
echo "  codex:         $(command -v codex >/dev/null 2>&1 && echo "OK ($(codex --version 2>/dev/null))" || echo 'NOT INSTALLED')"
echo ""
echo "=== Install complete ==="
echo ""
echo "Re-run the same install command later to refresh to the latest published main branch."
if [ -n "${MY_CODEX_BOOTSTRAP_SOURCE:-}" ]; then
  echo "Bootstrap source: ${MY_CODEX_BOOTSTRAP_SOURCE}"
fi
echo "Only my-codex-managed files tracked in $MANIFEST_FILE are replaced; custom files are preserved."
echo "Stale invalid my-codex skills-only copies under ~/.agents/skills and ~/.claude/skills are removed during full install."
echo ""
echo "Recommended agent packs are auto-activated on first install and remembered in:"
echo "  ~/.codex/enabled-agent-packs.txt"
echo "Or manage them with:"
echo "  ~/.codex/bin/my-codex-packs status"
echo "  ~/.codex/bin/my-codex-packs enable marketing"
