#!/usr/bin/env bash
# my-codex full installer -- installs agents and skills for OpenAI Codex CLI
# Usage:
#   bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# NOTE: scripts/model-tiers.sh and scripts/skill-allowlists.sh are sourced AFTER
# the bootstrap check below — in pipe mode (bash < install.sh) SCRIPT_DIR is the
# caller's cwd, and the bootstrap re-exec from a real checkout must run before
# any repo file is read.

resolve_windows_home() {
  local raw_path="${1:-}" drive rest candidate
  [ -n "$raw_path" ] || return 1

  case "$raw_path" in
    /mnt/*|/c/*|/[A-Za-z]/*)
      printf '%s' "$raw_path"
      return 0
      ;;
    [A-Za-z]:\\*)
      if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$raw_path" 2>/dev/null && return 0
      fi
      drive="$(printf '%s' "${raw_path%%:*}" | tr '[:upper:]' '[:lower:]')"
      rest="${raw_path#?:}"
      rest="${rest//\\//}"
      for candidate in "/mnt/$drive$rest" "/$drive$rest"; do
        if [ -d "$candidate" ]; then
          printf '%s' "$candidate"
          return 0
        fi
      done
      printf '/mnt/%s%s' "$drive" "$rest"
      return 0
      ;;
  esac

  return 1
}

if [ -n "${USERPROFILE:-}" ]; then
  _windows_home="$(resolve_windows_home "$USERPROFILE" 2>/dev/null || true)"
  if [ -n "$_windows_home" ]; then
    HOME="$_windows_home"
    export HOME
  fi
fi

bootstrap_into_real_repo() {
  local bootstrap_source="${MY_CODEX_BOOTSTRAP_REPO:-https://github.com/sehoon787/my-codex.git}"
  local bootstrap_root
  bootstrap_root="$(mktemp -d)"

  echo "[bootstrap] Installer was not launched from a my-codex checkout."
  echo "[bootstrap] Fetching a real repository checkout from: $bootstrap_source"

  if [ -d "$bootstrap_source" ] && [ -f "$bootstrap_source/install.sh" ]; then
    cp -R "$bootstrap_source"/. "$bootstrap_root"/
    rm -rf "$bootstrap_root/.tmp-install-tests" 2>/dev/null || true
  else
    git clone --depth 1 "$bootstrap_source" "$bootstrap_root"
  fi
  export MY_CODEX_BOOTSTRAP_SOURCE="${MY_CODEX_BOOTSTRAP_SOURCE:-bootstrap-reexec}"
  bash "$bootstrap_root/install.sh" "$@"
  local status=$?
  rm -rf "$bootstrap_root"
  exit "$status"
}

if [ ! -f "$REPO_ROOT/scripts/agent-pack-manager.sh" ] || [ ! -f "$REPO_ROOT/templates/codex-AGENTS.md" ]; then
  bootstrap_into_real_repo "$@"
fi

# shellcheck source=scripts/model-tiers.sh
source "$REPO_ROOT/scripts/model-tiers.sh"
# Which upstream skills/agents this installer copies — see scripts/skill-allowlists.sh
# shellcheck source=scripts/skill-allowlists.sh
source "$REPO_ROOT/scripts/skill-allowlists.sh"

CODEX_ROOT="$HOME/.codex"
MANIFEST_FILE="$CODEX_ROOT/.my-codex-manifest.txt"
VERSION_FILE="$CODEX_ROOT/.my-codex-version"
VENDOR_REPO_ROOT="$CODEX_ROOT/vendor/my-codex"
TMP_MANIFEST="$(mktemp)"
NODEJS_SHIM_DIR=""
BUN_SHIM_DIR=""
NODE_PLATFORM_CACHE=""
POWERSHELL_CMD=""
WINGET_CMD=""
AGENTS_SKILLS_ROOT="$HOME/.agents/skills"
CLAUDE_SKILLS_ROOT="$HOME/.claude/skills"

cleanup() {
  rm -f "$TMP_MANIFEST"
}
trap cleanup EXIT

# ── Upstream helper ──
CLONE_TMPDIR=$(mktemp -d)
cleanup_clone() { rm -rf "$CLONE_TMPDIR"; rm -f "$TMP_MANIFEST"; if [ -n "$NODEJS_SHIM_DIR" ] && [ -d "$NODEJS_SHIM_DIR" ]; then rm -rf "$NODEJS_SHIM_DIR"; fi; if [ -n "$BUN_SHIM_DIR" ] && [ -d "$BUN_SHIM_DIR" ]; then rm -rf "$BUN_SHIM_DIR"; fi; }
trap cleanup_clone EXIT

UPSTREAM_DIR=""
# $3 (optional) — git ref to pin the clone fallback to. Only consulted when the
# submodule is unavailable and the tree has to be cloned fresh; a tag-pinned
# upstream must not land on the tip of its default branch.
init_upstream() {
  local name="$1" url="$2" pinned_ref="${3:-}"
  local submod_path="$REPO_ROOT/upstream/$name"
  if [ -d "$submod_path/.git" ] || [ -f "$submod_path/.git" ]; then
    # Use the checked-out (pinned) submodule SHA as-is. Upstream updates land
    # deliberately via update-upstream.yml (PR + security review), never
    # silently at install time.
    UPSTREAM_DIR="$submod_path"
    return 0
  fi
  if git -C "$REPO_ROOT" submodule update --init --depth 1 "upstream/$name" 2>/dev/null; then
    UPSTREAM_DIR="$submod_path"
    return 0
  fi
  echo "  WARNING: submodule init failed for $name, falling back to git clone..."
  UPSTREAM_DIR="$CLONE_TMPDIR/$name"
  if [ -n "$pinned_ref" ]; then
    git clone --depth 1 --branch "$pinned_ref" "$url" "$UPSTREAM_DIR" 2>/dev/null || return 1
  else
    git clone --depth 1 "$url" "$UPSTREAM_DIR" 2>/dev/null || return 1
  fi
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

link_windows_bun_shims() {
  local candidate="$1"

  [ -f "$candidate/bun.exe" ] || return 1

  if [ -z "$BUN_SHIM_DIR" ]; then
    BUN_SHIM_DIR="$(mktemp -d)"
  fi

  ln -sf "$candidate/bun.exe" "$BUN_SHIM_DIR/bun"
  append_path_once "$BUN_SHIM_DIR"
}

ensure_nodejs_on_path() {
  local candidate raw_path unix_path ps_cmd

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

  ps_cmd="$(find_powershell)"
  if [ -n "$ps_cmd" ] && command -v cygpath >/dev/null 2>&1; then
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
$( "$ps_cmd" -NoProfile -Command "\$paths=@(); \$machine=[Environment]::GetEnvironmentVariable('Path','Machine'); if(\$machine){\$paths += \$machine -split ';'}; \$user=[Environment]::GetEnvironmentVariable('Path','User'); if(\$user){\$paths += \$user -split ';'}; \$paths | Where-Object { \$_ } | Select-Object -Unique" 2>/dev/null)
EOF
  fi
}

find_powershell() {
  local candidate

  if [ -n "$POWERSHELL_CMD" ]; then
    printf '%s' "$POWERSHELL_CMD"
    return 0
  fi

  for candidate in \
    "$(command -v powershell.exe 2>/dev/null || true)" \
    "$(command -v powershell 2>/dev/null || true)" \
    "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
    "/c/Program Files/PowerShell/7/pwsh.exe" \
    "/mnt/c/Program Files/PowerShell/7/pwsh.exe"
  do
    [ -n "$candidate" ] || continue
    if [ -x "$candidate" ] || [ -f "$candidate" ]; then
      POWERSHELL_CMD="$candidate"
      break
    fi
  done

  printf '%s' "$POWERSHELL_CMD"
}

find_winget() {
  local candidate

  if [ -n "$WINGET_CMD" ]; then
    printf '%s' "$WINGET_CMD"
    return 0
  fi

  for candidate in \
    "$(command -v winget 2>/dev/null || true)" \
    "/mnt/c/Users/$(whoami 2>/dev/null || printf '%s' unknown)/AppData/Local/Microsoft/WindowsApps/winget.exe" \
    "/c/Users/$(whoami 2>/dev/null || printf '%s' unknown)/AppData/Local/Microsoft/WindowsApps/winget.exe" \
    /mnt/c/Users/*/AppData/Local/Microsoft/WindowsApps/winget.exe \
    /c/Users/*/AppData/Local/Microsoft/WindowsApps/winget.exe
  do
    [ -n "$candidate" ] || continue
    if [ -x "$candidate" ] || [ -f "$candidate" ]; then
      WINGET_CMD="$candidate"
      break
    fi
  done

  printf '%s' "$WINGET_CMD"
}

get_node_platform() {
  if [ -n "$NODE_PLATFORM_CACHE" ]; then
    printf '%s' "$NODE_PLATFORM_CACHE"
    return 0
  fi

  if command -v node >/dev/null 2>&1; then
    NODE_PLATFORM_CACHE="$(node -p "process.platform" 2>/dev/null || printf 'unknown')"
  else
    NODE_PLATFORM_CACHE="missing"
  fi

  printf '%s' "$NODE_PLATFORM_CACHE"
}

path_for_node() {
  local raw_path="$1" drive tail_path

  if [ "$(get_node_platform)" = "win32" ]; then
    case "$raw_path" in
      /mnt/[A-Za-z]/*)
        drive="${raw_path#/mnt/}"
        drive="${drive%%/*}"
        tail_path="${raw_path#/mnt/$drive/}"
        printf '%s:\\%s' "$(printf '%s' "$drive" | tr '[:lower:]' '[:upper:]')" "$(printf '%s' "$tail_path" | sed 's#/#\\\\#g')"
        return 0
        ;;
      /[A-Za-z]/*)
        drive="${raw_path#/}"
        drive="${drive%%/*}"
        tail_path="${raw_path#/$drive/}"
        printf '%s:\\%s' "$(printf '%s' "$drive" | tr '[:lower:]' '[:upper:]')" "$(printf '%s' "$tail_path" | sed 's#/#\\\\#g')"
        return 0
        ;;
    esac
  fi

  if [ "$(get_node_platform)" = "win32" ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -aw "$raw_path" 2>/dev/null || cygpath -w "$raw_path" 2>/dev/null || printf '%s' "$raw_path"
    return 0
  fi

  printf '%s' "$raw_path"
}

is_windows_host() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
  esac

  [ "$(get_node_platform)" = "win32" ]
}

ensure_bun_on_path() {
  local candidate raw_path unix_path ps_cmd

  if command -v bun >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "${BUN_INSTALL:-}" ] && [ -d "$BUN_INSTALL/bin" ]; then
    append_path_once "$BUN_INSTALL/bin"
    link_windows_bun_shims "$BUN_INSTALL/bin" || true
  fi

  if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    candidate="$(cygpath -u "$USERPROFILE" 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -d "$candidate/.bun/bin" ]; then
      append_path_once "$candidate/.bun/bin"
      link_windows_bun_shims "$candidate/.bun/bin" || true
    fi
  fi

  for candidate in \
    /mnt/c/Users/*/.bun/bin \
    /c/Users/*/.bun/bin \
    /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Packages/Oven-sh.Bun*/bun-windows-* \
    /c/Users/*/AppData/Local/Microsoft/WinGet/Packages/Oven-sh.Bun*/bun-windows-*
  do
    [ -d "$candidate" ] || continue
    if [ -f "$candidate/bun.exe" ] || [ -f "$candidate/bun" ]; then
      append_path_once "$candidate"
      link_windows_bun_shims "$candidate" || true
      command -v bun >/dev/null 2>&1 && return 0
    fi
  done

  if command -v bun >/dev/null 2>&1; then
    return 0
  fi

  ps_cmd="$(find_powershell)"
  if [ -n "$ps_cmd" ] && command -v cygpath >/dev/null 2>&1; then
    while IFS= read -r raw_path; do
      raw_path="${raw_path%$'\r'}"
      [ -n "$raw_path" ] || continue
      unix_path="$(cygpath -u "$raw_path" 2>/dev/null || true)"
      [ -d "$unix_path" ] || continue
      append_path_once "$unix_path"
      link_windows_bun_shims "$unix_path" || true
      if command -v bun >/dev/null 2>&1; then
        return 0
      fi
    done <<EOF
$( "$ps_cmd" -NoProfile -Command "\$candidates=@(); if(\$env:USERPROFILE){\$candidates += (Join-Path \$env:USERPROFILE '.bun\\bin')}; if(\$env:LOCALAPPDATA){\$pkgRoot = Join-Path \$env:LOCALAPPDATA 'Microsoft\\WinGet\\Packages'; if(Test-Path \$pkgRoot){\$pkg = Get-ChildItem \$pkgRoot -Filter 'Oven-sh.Bun*' -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if(\$pkg){\$bun = Get-ChildItem \$pkg.FullName -Filter 'bun.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1; if(\$bun){\$candidates += \$bun.DirectoryName}}}}; \$candidates | Where-Object { \$_ -and (Test-Path \$_) } | Select-Object -Unique" 2>/dev/null)
EOF
  fi

  command -v bun >/dev/null 2>&1
}

install_bun_if_missing() {
  local ps_cmd winget_cmd

  ensure_bun_on_path && return 0

  winget_cmd="$(find_winget)"
  if is_windows_host && [ -n "$winget_cmd" ]; then
    echo "  [gstack] Installing bun via winget..."
    "$winget_cmd" install --id Oven-sh.Bun -e --accept-package-agreements --accept-source-agreements --silent --disable-interactivity >/dev/null 2>&1 || true
    ensure_bun_on_path && return 0
  fi

  ps_cmd="$(find_powershell)"
  if is_windows_host && [ -n "$ps_cmd" ]; then
    echo "  [gstack] Installing bun via winget..."
    "$ps_cmd" -NoProfile -Command "\$ProgressPreference='SilentlyContinue'; winget install --id Oven-sh.Bun -e --accept-package-agreements --accept-source-agreements --silent --disable-interactivity" >/dev/null 2>&1 || true
    ensure_bun_on_path && return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    echo "  [gstack] Installing bun via bun.sh..."
    curl -fsSL --connect-timeout 15 --max-time 90 https://bun.sh/install | bash 2>/dev/null || true
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    ensure_bun_on_path && return 0
  fi

  return 1
}

PACK_MANAGER="$SCRIPT_DIR/scripts/agent-pack-manager.sh"
PROFILE_OVERRIDE=""
WITH_PACKS=""

# Optional skill lanes (see $ECC_SKILL_OPTIONAL_WEB in scripts/skill-allowlists.sh).
# Empty = default lane only. Set by --skills=/--full-skills, else $MY_CODEX_SKILLS,
# else whatever a previous install persisted in ~/.codex/enabled-skill-lanes.txt.
SKILL_LANES_FILE=""
SKILL_LANES=""
SKILL_LANES_OVERRIDE=""
SKILL_LANES_SOURCE="default"
KNOWN_SKILL_LANES="web"

# ── Argument parsing ──
SKIP_ECC=0
SKIP_OMX=0
SKIP_GSTACK=0
SKIP_SUPERPOWERS=0
SKIP_ARCHIFY=0

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
    --skills=*)
      SKILL_LANES_OVERRIDE="${1#*=}"
      shift
      ;;
    --full-skills)
      SKILL_LANES_OVERRIDE="$KNOWN_SKILL_LANES"
      shift
      ;;
    --skip-ecc)        SKIP_ECC=1; shift ;;
    --skip-omx)        SKIP_OMX=1; shift ;;
    --skip-gstack)     SKIP_GSTACK=1; shift ;;
    --skip-superpowers) SKIP_SUPERPOWERS=1; shift ;;
    --skip-archify)    SKIP_ARCHIFY=1; shift ;;
    --self-only)
      SKIP_ECC=1
      SKIP_OMX=1; SKIP_GSTACK=1; SKIP_SUPERPOWERS=1; SKIP_ARCHIFY=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  bash install.sh
  bash install.sh --profile minimal|dev|full
  bash install.sh --with-packs <pack1,pack2,...>
  bash install.sh --skills=web

Options:
  --with-packs=<packs>  Comma-separated list of agent packs to symlink into ~/.codex/agents/
  --skills=<lanes>      Optional skill lanes to install on top of the default set.
                        Known lanes: web (18 front-end/UI skills). Use "none" for
                        the default set only. Also settable via MY_CODEX_SKILLS.
                        The choice persists in ~/.codex/enabled-skill-lanes.txt.
  --full-skills         Install every optional skill lane (same as --skills=web today)
  --skip-ecc            Skip everything-claude-code upstream install
  --skip-omx            Skip oh-my-codex upstream install
  --skip-gstack         Skip gstack upstream install
  --skip-superpowers    Skip superpowers upstream install
  --skip-archify        Skip archify diagram skill install
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

# ── Optional skill lanes ──
# Same persistence contract as enabled-agent-packs.txt: a comment-headed,
# one-name-per-line state file that install.sh rewrites on every run, so a lane
# chosen once survives later installs without repeating the flag.
read_skill_lanes_file() {
  [ -f "$SKILL_LANES_FILE" ] || return 0
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print $0 }
  ' "$SKILL_LANES_FILE"
}

write_skill_lanes_file() {
  mkdir -p "$CODEX_ROOT"
  {
    echo "# One optional skill lane name per line."
    echo "# This file is managed by my-codex and preserved across reinstalls."
    for lane_name in $1; do
      [ -n "$lane_name" ] || continue
      printf '%s\n' "$lane_name"
    done
  } > "$SKILL_LANES_FILE"
}

# Normalizes a comma/space separated lane request into a validated, space-joined
# list. "none"/"default" clear the set; unknown lanes are rejected loudly rather
# than silently dropped, so a typo never looks like a successful opt-in.
normalize_skill_lanes() {
  local raw="$1" lane out=""
  raw="$(printf '%s' "$raw" | tr ',' ' ')"
  for lane in $raw; do
    case "$lane" in
      none|default|"") continue ;;
      full|all) lane="$KNOWN_SKILL_LANES" ;;
    esac
    for one in $lane; do
      case " $KNOWN_SKILL_LANES " in
        *" $one "*) ;;
        *) echo "ERROR: unknown skill lane: $one (known: $KNOWN_SKILL_LANES)" >&2; return 1 ;;
      esac
      case " $out " in *" $one "*) ;; *) out="$out $one" ;; esac
    done
  done
  printf '%s' "${out# }"
}

resolve_skill_lanes() {
  SKILL_LANES_FILE="$CODEX_ROOT/enabled-skill-lanes.txt"
  if [ -n "$SKILL_LANES_OVERRIDE" ]; then
    SKILL_LANES="$(normalize_skill_lanes "$SKILL_LANES_OVERRIDE")" || exit 1
    SKILL_LANES_SOURCE="flag"
  elif [ -n "${MY_CODEX_SKILLS:-}" ]; then
    SKILL_LANES="$(normalize_skill_lanes "$MY_CODEX_SKILLS")" || exit 1
    SKILL_LANES_SOURCE="env"
  else
    SKILL_LANES="$(normalize_skill_lanes "$(read_skill_lanes_file | tr '\n' ' ')")" || exit 1
    SKILL_LANES_SOURCE="persisted"
  fi
  [ -n "$SKILL_LANES" ] || SKILL_LANES_SOURCE="default"
  write_skill_lanes_file "$SKILL_LANES"
}

skill_lane_enabled() {
  case " $SKILL_LANES " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

current_install_version() {
  if [ -d "$REPO_ROOT/.git" ]; then
    git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown'
  else
    printf 'unknown'
  fi
}

# Manifest entries are either single files (agents/*.toml, hooks/*.js) or whole
# directories (skills/<name>, vendor/my-codex). `rm -rf` handles both, so a
# directory copy tracked as one directory entry is removed completely — no husk
# files survive. Only the per-file entries can leave an emptied parent behind,
# which the prune pass below collects.
remove_manifest_paths() {
  local manifest="$1"
  [ -f "$manifest" ] || return 1

  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    rm -rf "$CODEX_ROOT/$rel_path" 2>/dev/null || true
  done < "$manifest"

  # Prune directories the deletions above emptied (e.g. an agent pack whose
  # every agent-packs/<pack>/*.toml entry was just removed). Scoped strictly to
  # directories derived from manifest entries — never a blanket prune of
  # ~/.codex — and deepest-first (longest path first) so nested husks collapse
  # before their parents. Top-level roots (agents/, skills/, agent-packs/, ...)
  # are deliberately excluded: later install steps write into them. rmdir only
  # succeeds on an already-empty directory, so custom files sitting alongside
  # managed ones keep their directory alive.
  awk -F/ 'NF>1 { p=$1; for (i=2;i<NF;i++) { p=p"/"$i; print p } }' "$manifest" \
    | sort -u \
    | awk '{ print length($0) "\t" $0 }' | sort -rn -k1,1 | cut -f2- \
    | while IFS= read -r rel_dir; do
        rmdir "$CODEX_ROOT/$rel_dir" 2>/dev/null || true
      done
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

# Portable in-place sed.
#
# GNU sed takes `-i` with no argument; BSD sed (the /usr/bin/sed on macOS)
# requires an explicit backup suffix, so bare `sed -i "s/x/y/" f` there eats
# the script as the suffix and dies with "unescaped newline inside substitute
# pattern" — silently leaving the file untouched. Every in-place edit in this
# script MUST go through this wrapper.
sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"        # GNU
  else
    sed -i '' "$@"     # BSD / macOS
  fi
}

# Portable "insert LINE after the first line matching PATTERN".
#
# sed's append is the one command whose syntax genuinely differs between
# implementations (GNU takes `a text` inline; BSD demands `a\` then the text
# on the next line), so neither form is portable even through sed_inplace.
# awk behaves identically on both.
#   $1 = ERE pattern, $2 = line to insert, $3 = file
insert_after() {
  local _tmp="$3.tmp.$$"
  awk -v pat="$1" -v ins="$2" '
    { print }
    !inserted && $0 ~ pat { print ins; inserted = 1 }
  ' "$3" > "$_tmp" && mv "$_tmp" "$3"
}

# Normalize legacy/upstream-native model values to current tiers (see
# scripts/model-tiers.sh). Some sources (e.g. the vendored agent packs in
# codex-agents/packs/) ship native .toml agents with their own model value,
# bypassing md-to-toml.sh's map_model tiering.
normalize_agent_models() {
  local dir="$1"
  local entry from tier to count summary=""
  [ -d "$dir" ] || return 0

  for entry in "${LEGACY_MODEL_MAP[@]}"; do
    from="${entry%:*}"
    tier="${entry##*:}"
    case "$tier" in
      HIGH)   to="$MODEL_TIER_HIGH" ;;
      MEDIUM) to="$MODEL_TIER_MEDIUM" ;;
      LOW)    to="$MODEL_TIER_LOW" ;;
      *)      continue ;;
    esac
    # A tier promoted to its own current value has nothing to rewrite.
    [ "$from" = "$to" ] && continue

    count=$({ grep -rl "^model = \"$from\"\$" "$dir" --include='*.toml' 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
      grep -rl "^model = \"$from\"\$" "$dir" --include='*.toml' 2>/dev/null | while IFS= read -r f; do
        sed_inplace "s/^model = \"$from\"\$/model = \"$to\"/" "$f"
      done
    fi
    summary="$summary ${count} ${from}->${to};"
  done

  echo "  Normalized $dir:$summary"
}

# Records one directory entry ("skills/<name>") per copied tree, not one line
# per file. remove_manifest_paths() deletes entries with `rm -rf`, so the whole
# subtree — nested references/, scripts/, everything cp -R placed — is removed
# on the next update. Do not "improve" this into a per-file listing; the
# directory entry is what makes the copy fully reversible.
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

copy_repo_snapshot() {
  local src_dir="$1"
  local dest_dir="$2"

  rm -rf "$dest_dir" 2>/dev/null || true
  mkdir -p "$dest_dir"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      --exclude '.tmp-install-tests' \
      --exclude 'node_modules' \
      "$src_dir"/ "$dest_dir"/
  else
    (
      cd "$src_dir"
      tar \
        --exclude '.git' \
        --exclude '.tmp-install-tests' \
        --exclude 'node_modules' \
        -cf - .
    ) | (
      cd "$dest_dir"
      tar -xf -
    )
  fi
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

# Same provenance contract as copy_skill_dirs(): one directory manifest entry
# covers the entire copied tree, removed wholesale by `rm -rf` on update.
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

  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;;
    *) return 0 ;;
  esac

  install_skill_copy "$gstack_root/benchmark" "benchmark"

  # connect-chrome aliased gstack's open-gstack-browser, which is no longer
  # surfaced at depth 1 ($GSTACK_SKILL_ALLOWLIST). Clear stale copies left by
  # pre-allowlist installs; the skill stays reachable inside $gstack_root.
  rm -rf "$CODEX_ROOT/skills/connect-chrome" 2>/dev/null || true
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
  # the SessionStart hook before delegating to the original npm shim, then
  # synthesize session-end vault artifacts after Codex exits.
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
      local backup="$npm_dir/codex.real.cmd"
      if [ ! -f "$backup" ]; then
        cp "$cmd_shim" "$backup"
        echo "  npm codex.cmd: backed up to codex.real.cmd"
      fi
      cat > "$cmd_shim" <<'CMDEOF'
@ECHO off
REM my-codex wrapper - runs SessionStart hook via Git Bash, logs invocation, delegates to codex.real.cmd
SETLOCAL EnableDelayedExpansion

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
SET "CODEX_EXIT=!ERRORLEVEL!"
IF DEFINED GIT_BASH (
  IF EXIST "%USERPROFILE%\.codex\hooks\session-end.js" (
    "!GIT_BASH!" -c "echo '{\"agent_id\":\"codex-wrapper-stop\",\"agent_type\":\"wrapper\"}' | node ~/.codex/hooks/session-end.js" 1>NUL 2>NUL
  )
)
EXIT /B !CODEX_EXIT!
CMDEOF
      echo "  npm codex.cmd: patched"
  else
    echo "  npm codex.cmd: not found, skipping"
  fi

  # --- codex.ps1 ---
  local ps1_shim="$npm_dir/codex.ps1"
  if [ -f "$ps1_shim" ]; then
      local ps1_backup="$npm_dir/codex.real.ps1"
      if [ ! -f "$ps1_backup" ]; then
        cp "$ps1_shim" "$ps1_backup"
        echo "  npm codex.ps1: backed up to codex.real.ps1"
      fi
      cat > "$ps1_shim" <<'PS1EOF'
#!/usr/bin/env pwsh
# my-codex in-place patch of npm codex.ps1
# Runs SessionStart hook via Git Bash, logs invocation, delegates to codex.real.ps1.

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

& "$PSScriptRoot\codex.real.ps1" @args
$codexExit = $LASTEXITCODE

try {
    $sessionEndPath = Join-Path $env:USERPROFILE ".codex\hooks\session-end.js"
    if (Test-Path $sessionEndPath) {
        $payload = '{"agent_id":"codex-wrapper-stop","agent_type":"wrapper"}'
        $env:MY_CODEX_SESSION_END_AGENT_ID = "codex-wrapper-stop"
        $env:MY_CODEX_SESSION_END_AGENT_TYPE = "wrapper"
        $payload | node $sessionEndPath *> $null
        Remove-Item Env:MY_CODEX_SESSION_END_AGENT_ID -ErrorAction SilentlyContinue
        Remove-Item Env:MY_CODEX_SESSION_END_AGENT_TYPE -ErrorAction SilentlyContinue
    }
} catch {}

exit $codexExit
PS1EOF
      echo "  npm codex.ps1: patched"
  else
    echo "  npm codex.ps1: not found, skipping"
  fi

  # --- extensionless bash shim ---
  local bash_shim="$npm_dir/codex"
  if [ -f "$bash_shim" ]; then
      local bash_backup="$npm_dir/codex.real"
      if [ ! -f "$bash_backup" ]; then
        cp "$bash_shim" "$bash_backup"
        echo "  npm codex (bash shim): backed up to codex.real"
      fi
      cat > "$bash_shim" <<'BASHEOF'
#!/bin/sh
# my-codex in-place patch of npm codex (bash shim)
# Runs SessionStart hook, logs invocation, then delegates to codex.real.

basedir=$(dirname "$(echo "$0" | sed -e 's,\\,/,g')")
hook_path="$HOME/.codex/hooks/session-start.sh"
hook_ok="no"
if [ -f "$hook_path" ]; then
  hook_ok="yes"
  bash "$hook_path" >/dev/null 2>&1 || true
fi
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)
printf '%s\twrapper=npm/codex\tcwd=%s\thook_installed=%s\n' "$ts" "$PWD" "$hook_ok" \
  >> "$HOME/.codex/last-invocation.log" 2>/dev/null || true

"$basedir/codex.real" "$@"
codex_status=$?
if [ -f "$HOME/.codex/hooks/session-end.js" ]; then
  echo '{"agent_id":"codex-wrapper-stop","agent_type":"wrapper"}' | \
    node "$HOME/.codex/hooks/session-end.js" >/dev/null 2>&1 || true
fi
exit "$codex_status"
BASHEOF
      echo "  npm codex (bash shim): patched"
  else
    echo "  npm codex (bash shim): not found, skipping"
  fi
}

INSTALLING_VERSION="$(current_install_version)"
INSTALLED_VERSION="none"
if [ -f "$VERSION_FILE" ]; then
  INSTALLED_VERSION="$(cat "$VERSION_FILE")"
fi

resolve_skill_lanes

echo "=== my-codex installer ==="
echo ""
echo "Install footprint: 17 core agents + 17 opt-in AI agents (2 packs), 105 curated skills from 4 upstream sources"
if [ -n "$SKILL_LANES" ]; then
  echo "Optional skill lanes: ${SKILL_LANES} (+18 with web)"
fi
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
if [ -f "$MANIFEST_FILE" ]; then
  remove_manifest_paths "$MANIFEST_FILE"
else
  echo "  No previous manifest found — skipping stale-file cleanup (safe default for first-time or pre-manifest legacy installs)"
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
      # Allowlisted agents only — $OMX_AGENT_ALLOWLIST (scripts/skill-allowlists.sh).
      # shellcheck disable=SC2086  # deliberate re-split: newline list -> " a b " for case matching
      _omx_allow=" $(echo $OMX_AGENT_ALLOWLIST) "
      for md_file in "$UPSTREAM_DIR/prompts/"*.md; do
        [ -f "$md_file" ] || continue
        bname="$(basename "$md_file")"
        fname="${bname%.md}"
        case "$_omx_allow" in *" $fname "*) ;; *) continue ;; esac
        # Check if file has YAML frontmatter at all
        first_line="$(head -1 "$md_file" | tr -d '\r')"
        if [ "$first_line" != "---" ]; then
          # No frontmatter: generate a minimal TOML directly and skip md-to-toml conversion
          {
            printf 'name = "%s"\n' "$fname"
            printf 'description = "Team orchestration specialist"\n'
            printf 'model = "%s"\n' "$MODEL_TIER_HIGH"
            # Deliberately medium (not $MODEL_TIER_HIGH_EFFORT): these frontmatter-less
            # omx prompts are team-orchestration relays, not deep-reasoning agents.
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
          insert_after '^---$' "name: $fname" "$omc_staging/omc/$bname" 2>/dev/null || true
        else
          cp "$md_file" "$omc_staging/omc/$bname"
        fi
        # Add model: if missing
        if ! grep -q '^model:' "$omc_staging/omc/$bname" 2>/dev/null; then
          insert_after '^description:' "model: $MODEL_TIER_HIGH" "$omc_staging/omc/$bname" 2>/dev/null || true
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

# ── 1c. Vendored agent packs (opt-in via --with-packs / agent-pack-manager) ──
echo "  [packs] Installing vendored agent packs..."
for pack_dir in "$REPO_ROOT/codex-agents/packs/"*/; do
  [ -d "$pack_dir" ] || continue
  pack_name="$(basename "$pack_dir")"
  copy_toml_dir "$pack_dir" "$CODEX_ROOT/agent-packs/$pack_name"
done

# ── 1d. Upstream: superpowers ──
# Agents: none. superpowers ships a single code-reviewer.md, which duplicates the
# omx code-reviewer agent installed above and was never spawned; only its skills
# are installed (step 2c).
if [ "$SKIP_SUPERPOWERS" = "0" ]; then
  echo "  [superpowers] Initializing superpowers..."
  init_upstream superpowers https://github.com/obra/superpowers || true
fi

echo "  Core agents: $(find "$CODEX_ROOT/agents" -maxdepth 1 -name '*.toml' | wc -l | tr -d ' ') installed"
echo "  Agent packs: $(find "$CODEX_ROOT/agent-packs" -name '*.toml' | wc -l | tr -d ' ') installed"

echo "  Normalizing upstream-native agent models..."
normalize_agent_models "$CODEX_ROOT/agents"
normalize_agent_models "$CODEX_ROOT/agent-packs"

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
      # Allowlisted skills only — $ECC_SKILL_ALLOWLIST (scripts/skill-allowlists.sh)
      for ecc_skill in $ECC_SKILL_ALLOWLIST; do
        install_skill_copy "$UPSTREAM_DIR/skills/$ecc_skill" "$ecc_skill"
      done
      # Optional lanes. Skills from a lane that is off are simply not copied;
      # the manifest cleanup at [0.5/7] removes any copy a previous install left
      # behind, which is what makes turning a lane off actually shrink context.
      if skill_lane_enabled web; then
        for ecc_skill in $ECC_SKILL_OPTIONAL_WEB; do
          install_skill_copy "$UPSTREAM_DIR/skills/$ecc_skill" "$ecc_skill"
        done
      fi
      # continuous-learning v1 is self-declared deprecated in favor of v2; never
      # allowlisted — this also clears copies left by pre-allowlist installs.
      rm -rf "$CODEX_ROOT/skills/continuous-learning"
      grep -v '^skills/continuous-learning$' "$TMP_MANIFEST" > "$TMP_MANIFEST.tmp" 2>/dev/null && mv "$TMP_MANIFEST.tmp" "$TMP_MANIFEST"
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
    # All skills except $SUPERPOWERS_SKILL_EXCLUDE (scripts/skill-allowlists.sh)
    # shellcheck disable=SC2086  # deliberate re-split: newline list -> " a b " for case matching
    _sp_exclude=" $(echo $SUPERPOWERS_SKILL_EXCLUDE) "
    for sp_skill_dir in "$sp_dir/skills/"*/; do
      [ -d "$sp_skill_dir" ] || continue
      sp_skill_name="$(basename "$sp_skill_dir")"
      case "$_sp_exclude" in *" $sp_skill_name "*) continue ;; esac
      install_skill_copy "${sp_skill_dir%/}" "$sp_skill_name"
    done
  fi
fi

# ── 2d. Upstream: gstack (runtime install) ──
if [ "$SKIP_GSTACK" = "0" ]; then
  echo "  [gstack] Initializing gstack..."
  if init_upstream gstack https://github.com/garrytan/gstack; then
    GSTACK_DIR="$CODEX_ROOT/skills/gstack"
    # Deliberately manifest-exempt: this is gstack's canonical runtime tree,
    # refreshed in place by `git pull` / `git checkout` and by `./setup` (which
    # builds the browser binary into it). Tracking it would make cleanup
    # `rm -rf` it on every update, discarding the checkout and forcing a full
    # re-clone plus rebuild. Left fully untracked rather than half-tracked;
    # the depth-1 surfaced copies derived from it below ARE tracked.
    if [ -d "$GSTACK_DIR/.git" ]; then
      git -C "$GSTACK_DIR" pull --ff-only 2>/dev/null || true
    else
      rm -rf "$GSTACK_DIR"
      cp -R "$UPSTREAM_DIR" "$GSTACK_DIR" 2>/dev/null || \
        git clone --depth 1 https://github.com/garrytan/gstack.git "$GSTACK_DIR" 2>/dev/null || true
    fi

    # Install bun if missing (required for gstack browser)
    if ! install_bun_if_missing; then
      echo "  [gstack] WARNING: bun is unavailable; skipping bun-backed gstack setup"
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

    # Fallback: ensure allowlisted gstack skills are accessible at depth 1.
    # The whole gstack repo stays at $GSTACK_DIR (canonical runtime tree); this
    # only controls which subdirs are surfaced as ~/.codex/skills/<name> —
    # $GSTACK_SKILL_ALLOWLIST (scripts/skill-allowlists.sh).
    if [ -d "$GSTACK_DIR" ]; then
      for skill_name in $GSTACK_SKILL_ALLOWLIST; do
        skill_dir="$GSTACK_DIR/$skill_name"
        [ -f "$skill_dir/SKILL.md" ] || continue
        target="$CODEX_ROOT/skills/$skill_name"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
          case "$(uname -s)" in
            MINGW*|MSYS*|CYGWIN*) cp -r "$skill_dir" "$target" ;;
            *) ln -s "$(cd "$skill_dir" && pwd)" "$target" 2>/dev/null || cp -r "$skill_dir" "$target" ;;
          esac
          # Recorded only when this run actually created the path, so a
          # pre-existing custom skill of the same name is never claimed. The
          # directory entry makes the Windows `cp -r` copy fully reversible
          # (previously untracked, which is why dropped allowlist entries had
          # to be swept by hand — see the connect-chrome removal above).
          add_manifest_entry "skills/$skill_name"
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

# ── 2e. Upstream: archify (diagram skill) ──
# Tag-pinned (v2.9.0), not branch-tracked: the skill's renderer CLI and schema
# shapes are what boss.toml routes to, so it moves on a deliberate bump only.
# The installable unit is the repo's top-level archify/ directory (the same one
# `npx skills add tt-a1i/archify -g` installs); the rest of the repo is docs,
# examples, and experiments this install does not need.
if [ "$SKIP_ARCHIFY" = "0" ]; then
  echo "  [archify] Initializing archify..."
  if init_upstream archify https://github.com/tt-a1i/archify "$ARCHIFY_PINNED_TAG"; then
    if [ -f "$UPSTREAM_DIR/$ARCHIFY_SKILL_SUBDIR/SKILL.md" ]; then
      install_skill_copy "$UPSTREAM_DIR/$ARCHIFY_SKILL_SUBDIR" "$ARCHIFY_SKILL_NAME"
      echo "  [archify] Installed skill: $ARCHIFY_SKILL_NAME"
    else
      echo "  [archify] WARNING: $ARCHIFY_SKILL_SUBDIR/SKILL.md not found; skill not installed"
    fi
  fi
fi

managed_skills="$(count_managed_skills)"
total_skills="$(find "$CODEX_ROOT/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
extra_skills=$((total_skills - managed_skills))
echo "  Skills: ${managed_skills} installed"
if [ -n "$SKILL_LANES" ]; then
  echo "  Optional skill lanes: ${SKILL_LANES} (source: ${SKILL_LANES_SOURCE})"
else
  echo "  Optional skill lanes: none (default set only; enable with --skills=web)"
fi
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

# Upsert one template section into an existing AGENTS.md, keyed by its HTML marker.
# The section is everything from <heading> up to the next "## " line in the template.
# Marker already present -> replace that section in place, so template edits reach
# installs that predate them; everything else in the file is copied through byte for
# byte. Marker absent -> append. Re-running the installer is a no-diff either way.
append_agents_section() {
  local heading="$1"
  local marker="$2"
  local target="$CODEX_ROOT/AGENTS.md"
  local tmp

  if grep -qF "$marker" "$target" 2>/dev/null; then
    tmp="$target.tmp.$$"
    # Pass 1 buffers the template section (trailing blank lines trimmed); pass 2
    # swaps it in for the target's copy and replays the blank lines that trailed
    # that copy, so the separator spacing around the section is left as it was.
    awk -v heading="$heading" '
      FNR == NR {
        if (!captured && $0 == heading) { in_template = 1 }
        else if (in_template && /^## /) { in_template = 0; captured = 1 }
        if (!in_template) { next }
        if ($0 ~ /^[[:space:]]*$/) { blank[++blanks] = $0; next }
        for (i = 1; i <= blanks; i++) section[++count] = blank[i]
        blanks = 0
        section[++count] = $0
        next
      }
      !replaced && $0 == heading {
        in_section = 1
        for (i = 1; i <= count; i++) print section[i]
        next
      }
      in_section {
        if ($0 ~ /^[[:space:]]*$/) { held[++holds] = $0; next }
        if (/^## /) {
          for (i = 1; i <= holds; i++) print held[i]
          holds = 0
          in_section = 0
          replaced = 1
          print
          next
        }
        holds = 0
        next
      }
      { print }
      END { for (i = 1; i <= holds; i++) print held[i] }
    ' "$REPO_ROOT/templates/codex-AGENTS.md" "$target" > "$tmp" && mv "$tmp" "$target"
    echo "  AGENTS.md: refreshed $heading"
    return 0
  fi

  {
    echo ""
    awk -v heading="$heading" '
      $0 == heading { in_section = 1; print; next }
      in_section && /^## / { exit }
      in_section { print }
    ' "$REPO_ROOT/templates/codex-AGENTS.md"
  } >> "$target"
  echo "  AGENTS.md: appended $heading"
}

echo "[3/7] Setting up AGENTS.md..."
if [ ! -f "$CODEX_ROOT/AGENTS.md" ]; then
  cp "$REPO_ROOT/templates/codex-AGENTS.md" "$CODEX_ROOT/AGENTS.md"
  echo "  AGENTS.md created"
else
  append_agents_section "## Calibrated Response (mandatory)" "<!-- my-codex:calibrated-response -->"
  append_agents_section "## Final Report (end of the request)" "<!-- my-codex:final-report -->"
  append_agents_section "## Context Hygiene" "<!-- my-codex:context-hygiene -->"
  append_agents_section "## Tooling (MCP + skills)" "<!-- my-codex:tooling-mcp -->"
  echo "  AGENTS.md already exists -- skipping (delete to regenerate)"
fi

echo "[3.5/7] Installing hooks..."
mkdir -p "$CODEX_ROOT/hooks"
# Codex loads lifecycle hooks only from $CODEX_HOME/hooks.json (root), never from hooks/.
# Older my-codex installs wrote hooks/hooks.json; remove that stale copy on upgrade.
rm -f "$CODEX_ROOT/hooks/hooks.json"
if [ -f "$REPO_ROOT/hooks/hooks.json" ]; then
  cp "$REPO_ROOT/hooks/hooks.json" "$CODEX_ROOT/hooks.json"
  add_manifest_entry "hooks.json"
fi
if [ -f "$REPO_ROOT/hooks/session-start.sh" ]; then
  cp "$REPO_ROOT/hooks/session-start.sh" "$CODEX_ROOT/hooks/session-start.sh"
  chmod +x "$CODEX_ROOT/hooks/session-start.sh"
  add_manifest_entry "hooks/session-start.sh"
fi
if [ -f "$REPO_ROOT/hooks/briefing-runtime.js" ]; then
  cp "$REPO_ROOT/hooks/briefing-runtime.js" "$CODEX_ROOT/hooks/briefing-runtime.js"
  add_manifest_entry "hooks/briefing-runtime.js"
fi
if [ -f "$REPO_ROOT/hooks/session-start-state.js" ]; then
  cp "$REPO_ROOT/hooks/session-start-state.js" "$CODEX_ROOT/hooks/session-start-state.js"
  add_manifest_entry "hooks/session-start-state.js"
fi
if [ -f "$REPO_ROOT/hooks/stop-profile-update.js" ]; then
  cp "$REPO_ROOT/hooks/stop-profile-update.js" "$CODEX_ROOT/hooks/stop-profile-update.js"
  add_manifest_entry "hooks/stop-profile-update.js"
fi
if [ -f "$REPO_ROOT/hooks/stop-final-report.js" ]; then
  cp "$REPO_ROOT/hooks/stop-final-report.js" "$CODEX_ROOT/hooks/stop-final-report.js"
  add_manifest_entry "hooks/stop-final-report.js"
fi
if [ -f "$REPO_ROOT/hooks/session-end.js" ]; then
  cp "$REPO_ROOT/hooks/session-end.js" "$CODEX_ROOT/hooks/session-end.js"
  add_manifest_entry "hooks/session-end.js"
fi
if [ -f "$REPO_ROOT/hooks/session-sync.js" ]; then
  cp "$REPO_ROOT/hooks/session-sync.js" "$CODEX_ROOT/hooks/session-sync.js"
  add_manifest_entry "hooks/session-sync.js"
fi
if [ -f "$REPO_ROOT/hooks/stop-session-enforcement.js" ]; then
  cp "$REPO_ROOT/hooks/stop-session-enforcement.js" "$CODEX_ROOT/hooks/stop-session-enforcement.js"
  add_manifest_entry "hooks/stop-session-enforcement.js"
fi
if [ -f "$REPO_ROOT/hooks/persona-rule.js" ]; then
  cp "$REPO_ROOT/hooks/persona-rule.js" "$CODEX_ROOT/hooks/persona-rule.js"
  add_manifest_entry "hooks/persona-rule.js"
fi
echo "  Hooks installed (vault enforcement + persona)"

echo "[3.6/7] Registering Codex plugin..."
MARKETPLACE_DIR="$HOME/.agents/plugins"
PLUGINS_DIR="$MARKETPLACE_DIR/plugins"
mkdir -p "$PLUGINS_DIR"
MARKETPLACE_FILE="$MARKETPLACE_DIR/marketplace.json"

mkdir -p "$(dirname "$VENDOR_REPO_ROOT")"
copy_repo_snapshot "$REPO_ROOT" "$VENDOR_REPO_ROOT"
add_manifest_entry "vendor/my-codex"

# Symlink plugin into marketplace root so source.path stays relative.
# Always point at a stable vendor path so /tmp bootstrap clones can be deleted safely.
rm -rf "$PLUGINS_DIR/my-codex" 2>/dev/null || true
ln -sfn "$VENDOR_REPO_ROOT" "$PLUGINS_DIR/my-codex"
echo "  Symlinked $PLUGINS_DIR/my-codex -> $VENDOR_REPO_ROOT"

NODE_MARKETPLACE_FILE="$(path_for_node "$MARKETPLACE_FILE")"
if ! node -e "
  var fs=require('fs');
  var p=process.argv[1];
  var m={name:'local',plugins:[]};
  try{m=JSON.parse(fs.readFileSync(p,'utf8'))}catch(e){}
  if(!m.name) m.name='local';
  if(!Array.isArray(m.plugins)) m.plugins=[];
  m.plugins=m.plugins.filter(function(x){return x.name!=='my-codex'});
  m.plugins.push({
    name:'my-codex',
    source:{source:'local',path:'./plugins/my-codex'},
    policy:{installation:'INSTALLED_BY_DEFAULT',authentication:'ON_INSTALL'},
    category:'Productivity'
  });
  fs.writeFileSync(p,JSON.stringify(m,null,2));
" "$NODE_MARKETPLACE_FILE"; then
  echo "  WARNING: failed to update $MARKETPLACE_FILE"
else
  echo "  Plugin registered at $MARKETPLACE_FILE"
fi

echo "[4/7] Configuring config.toml..."
CONFIG_FILE="$CODEX_ROOT/config.toml"
touch "$CONFIG_FILE"
if ! grep -q 'multi_agent' "$CONFIG_FILE" 2>/dev/null; then
  cat >> "$CONFIG_FILE" << 'TOML'

# my-codex managed settings
[features]
multi_agent = true
child_agents_md = true
hooks = true

[agents]
max_threads = 8
TOML
  echo "  config.toml updated (multi_agent + hooks enabled, max_threads=8)"
else
  echo "  config.toml already configured"
fi

# Codex runs lifecycle hooks only when features.hooks is on. Configs written before
# this flag existed keep their [features] table, so insert the key directly under that
# header -- appending at EOF would land it inside whichever table comes last
# (typically an [mcp_servers.*] table) and silently do nothing.
# $2 = "true" restricts the match to an enabled flag; omitted, any value matches.
# The insert guard wants mere presence (an explicit `hooks = false` is a user
# opt-out, not something to silently overwrite); the status line wants the value.
features_table_has_hooks() {
  awk -v want="${2:-}" '
    /^[[:space:]]*\[[[:space:]]*features[[:space:]]*\][[:space:]]*(#.*)?$/ { in_features = 1; next }
    /^[[:space:]]*\[/ { in_features = 0 }
    in_features && /^[[:space:]]*hooks[[:space:]]*=/ {
      if (want == "" || $0 ~ "^[[:space:]]*hooks[[:space:]]*=[[:space:]]*" want) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

if grep -qE '^[[:space:]]*\[[[:space:]]*features[[:space:]]*\][[:space:]]*(#.*)?$' "$CONFIG_FILE" 2>/dev/null; then
  if ! features_table_has_hooks "$CONFIG_FILE"; then
    CONFIG_TMP="$(mktemp)"
    # Write back through the original file so its mode and inode survive; mv from
    # mktemp would leave config.toml at 600. rm runs either way so nothing leaks.
    awk '
      { print }
      !inserted && /^[[:space:]]*\[[[:space:]]*features[[:space:]]*\][[:space:]]*(#.*)?$/ { print "hooks = true"; inserted = 1 }
    ' "$CONFIG_FILE" > "$CONFIG_TMP" && cat "$CONFIG_TMP" > "$CONFIG_FILE"
    rm -f "$CONFIG_TMP"
    echo "  config.toml: enabled features.hooks"
  fi
else
  printf '\n[features]\nhooks = true\n' >> "$CONFIG_FILE"
  echo "  config.toml: added [features] with hooks = true"
fi

# Codex's own compaction prompt. The default summary keeps a lot of tool
# transcript; this one keeps the working set a resumed turn actually needs and
# drops the rest, which is what makes /compact cheaper than a fresh session.
# Set only when absent (an existing value is a user choice), and prepended
# above the first table header because compact_prompt is a top-level key —
# appending at EOF would land it inside whichever table comes last.
# model_auto_compact_token_limit is deliberately NOT set: it is model-specific
# and a wrong value truncates good context.
CODEX_COMPACT_PROMPT='Summarize the conversation so far so work can continue without re-reading it. Keep: the current task and its acceptance criteria, decisions already taken and why, open items and blockers, paths of files created or changed, and the obligation to close the request with the Final Report tables. Drop tool transcripts, raw command output, and file contents that have already been applied.'
if ! grep -qE '^[[:space:]]*compact_prompt[[:space:]]*=' "$CONFIG_FILE" 2>/dev/null; then
  CONFIG_TMP="$(mktemp)"
  # Write back through the original file so its mode and inode survive.
  {
    printf 'compact_prompt = "%s"\n\n' "$CODEX_COMPACT_PROMPT"
    cat "$CONFIG_FILE"
  } > "$CONFIG_TMP" && cat "$CONFIG_TMP" > "$CONFIG_FILE"
  rm -f "$CONFIG_TMP"
  echo "  config.toml: set compact_prompt"
else
  echo "  config.toml: compact_prompt already set"
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
HOOKS_DIR="$CODEX_ROOT/git-hooks"
# On Windows (MSYS/Cygwin), convert to native path to avoid git old-style path warnings
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) HOOKS_DIR="$(cygpath -m "$HOOKS_DIR" 2>/dev/null || echo "$HOOKS_DIR")" ;;
esac
if [ -n "$CURRENT_HOOKS_PATH" ] && [ "$CURRENT_HOOKS_PATH" != "$HOOKS_DIR" ]; then
  git config --global my-codex.previousHooksPath "$CURRENT_HOOKS_PATH"
fi
git config --global core.hooksPath "$HOOKS_DIR"

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

# Serena and Headroom are stdio servers, registered as config.toml tables rather
# than through `codex mcp add`: the CLI's add subcommand has no flag for
# startup_timeout_sec, and Serena's first launch (language-server boot) routinely
# exceeds the default. Writing the tables directly also means registration lands
# on a machine where the codex binary is not installed yet.
#
# Appended as top-level tables at EOF, which is safe for tables (unlike bare
# keys — see the compact_prompt note above). The grep guard on the table header
# makes a re-run a no-op, and never rewrites a table the user has edited.
ensure_mcp_server_toml() {
  local name="$1"
  shift
  if grep -qE "^\[mcp_servers\.${name}\]" "$CONFIG_FILE" 2>/dev/null; then
    echo "  ${name} already registered in config.toml"
    return
  fi
  {
    printf '\n[mcp_servers.%s]\n' "$name"
    printf '%s\n' "$@"
  } >> "$CONFIG_FILE"
  echo "  ${name} registered in config.toml"
}

# --project-from-cwd: index whatever repo the session was started in, no
# per-project activation step. --context=codex: Serena's Codex tool profile
# (contexts/codex.yml, shipped with serena-agent 1.7.0).
# --open-web-dashboard False: Codex spawns this server, so a browser tab popping
# up on every session start is noise. The dashboard itself stays ENABLED and
# reachable at http://localhost:24282/dashboard/index.html — only the autoload
# is off, which is what upstream recommends.
ensure_mcp_server_toml serena \
  'command = "serena"' \
  'args = ["start-mcp-server", "--project-from-cwd", "--context=codex", "--open-web-dashboard", "False"]' \
  'startup_timeout_sec = 15'
# headroom_compress / headroom_retrieve / headroom_stats over stdio. The
# `headroom wrap` proxy mode works (including on a subscription login) but is
# deliberately not automated: Codex cannot reach the API at all while the proxy
# is down, so starting one by default would make every session depend on it.
# README documents the manual opt-in.
ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]'

echo "[6/7] Installing companion tools..."
echo "  [6a] ast-grep..."
if command -v ast-grep >/dev/null 2>&1; then
  echo "    ast-grep already installed"
else
  npm i -g @ast-grep/cli@0.42.0 2>/dev/null || echo "    WARNING: ast-grep install failed"
fi
echo "  [6b] codeburn (AI token/cost tracker; reads ~/.codex/sessions read-only)..."
if command -v codeburn >/dev/null 2>&1; then
  echo "    codeburn already installed"
else
  npm i -g codeburn@0.9.23 2>/dev/null || echo "    WARNING: codeburn install failed"
fi

echo "  [6c] uv (Python tool runner for the Serena/Headroom MCP servers)..."
if command -v uv >/dev/null 2>&1; then
  echo "    uv already installed"
else
  # Astral's official installer drops uv in ~/.local/bin. Non-fatal: a machine
  # without it still gets a complete Codex install, only without the two Python
  # MCP servers, and the config.toml entries start working once uv is present.
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 \
    || echo "    WARNING: uv install failed; Serena and Headroom will not be installed"
fi
append_path_once "$HOME/.local/bin" || true

# `uv tool install` is idempotent by itself, but it still resolves and reports
# on every run; the `uv tool list` guard keeps a re-install quiet and offline.
# $2 is the DISTRIBUTION name, not the command name: `uv tool list` prints the
# distribution and its pinned version at the start of a line
# (`serena-agent v1.7.0`) and indents the commands it provides below it
# (`- serena`). Matching on a command name would never hit, and the tool would
# be reinstalled on every run. The guard is version-aware: it derives the
# pinned version from $3 (the text after the last `==` in the spec) and only
# skips when that exact version is already installed, so bumping the pin
# (e.g. serena-agent==1.7.0 -> 1.8.0) upgrades an existing install instead of
# being silently skipped because the distribution name alone still matched.
ensure_uv_tool() {
  local label="$1" dist="$2" spec="$3"
  if ! command -v uv >/dev/null 2>&1; then
    echo "    WARNING: uv unavailable; skipping ${label}"
    return
  fi
  local version="${spec##*==}"
  local version_re="${version//./\\.}"
  if uv tool list 2>/dev/null | grep -qE "^${dist} v${version_re}\$"; then
    echo "    ${label} already installed"
    return
  fi
  uv tool install --python 3.13 "$spec" >/dev/null 2>&1 \
    || echo "    WARNING: ${label} install failed"
}

echo "  [6d] serena (symbol-level code navigation MCP server)..."
ensure_uv_tool "serena" serena-agent "serena-agent==1.7.0"
echo "  [6e] headroom (context compression MCP server)..."
ensure_uv_tool "headroom" headroom-ai "headroom-ai[all]==0.37.0"

LC_ALL=C sort -u "$TMP_MANIFEST" > "$MANIFEST_FILE"
printf '%s\n' "$INSTALLING_VERSION" > "$VERSION_FILE"
echo "$REPO_ROOT" > "$CODEX_ROOT/.my-codex-repo-path" 2>/dev/null || true

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
echo "  hooks flag:    $(features_table_has_hooks "$CODEX_ROOT/config.toml" true 2>/dev/null && echo 'OK' || echo 'NEEDS CONFIG')"
echo "  hooksPath:     $(git config --global --get core.hooksPath 2>/dev/null || echo 'UNSET')"
echo "  Codex attr:    $(git config --global --get my-codex.codexAttribution 2>/dev/null || echo 'UNSET')"
echo "  version:       $(cat "$VERSION_FILE" 2>/dev/null || echo 'unknown')"
echo "  codex:         $(command -v codex >/dev/null 2>&1 && echo "OK ($(codex --version 2>/dev/null))" || echo 'NOT INSTALLED')"
echo "  codeburn:      $(command -v codeburn >/dev/null 2>&1 && echo 'OK' || echo 'MISSING')"
echo "  uv:            $(command -v uv >/dev/null 2>&1 && echo "OK ($(uv --version 2>/dev/null))" || echo 'MISSING')"
echo "  serena:        $(command -v serena >/dev/null 2>&1 && echo 'OK' || echo 'MISSING') / MCP $(grep -qE '^\[mcp_servers\.serena\]' "$CODEX_ROOT/config.toml" 2>/dev/null && echo 'registered' || echo 'UNREGISTERED')"
echo "  headroom:      $(command -v headroom >/dev/null 2>&1 && echo 'OK' || echo 'MISSING') / MCP $(grep -qE '^\[mcp_servers\.headroom\]' "$CODEX_ROOT/config.toml" 2>/dev/null && echo 'registered' || echo 'UNREGISTERED')"
echo "  archify skill: $(test -f "$CODEX_ROOT/skills/archify/SKILL.md" && echo 'OK' || echo 'MISSING')"
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
