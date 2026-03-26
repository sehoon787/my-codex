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
  [ -d "$REPO_ROOT/skills/ecc" ] &&
  [ -d "$REPO_ROOT/templates" ] &&
  [ -f "$REPO_ROOT/scripts/compute-install-counts.sh" ]
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
AGENTS_SKILLS_ROOT="$HOME/.agents/skills"
CLAUDE_SKILLS_ROOT="$HOME/.claude/skills"

cleanup() {
  rm -f "$TMP_MANIFEST"
}
trap cleanup EXIT

eval "$("$SCRIPT_DIR/scripts/compute-install-counts.sh")"
PACK_MANAGER="$SCRIPT_DIR/scripts/agent-pack-manager.sh"
PROFILE_OVERRIDE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE_OVERRIDE="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  bash install.sh
  bash install.sh --profile minimal|dev|full
  curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
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

  for src_dir in \
    "$REPO_ROOT/codex-agents/core" \
    "$REPO_ROOT/codex-agents/omo" \
    "$REPO_ROOT/codex-agents/omc" \
    "$REPO_ROOT/codex-agents/awesome-core"
  do
    [ -d "$src_dir" ] || continue
    for file_name in "$src_dir"/*.toml; do
      [ -f "$file_name" ] || continue
      rm -f "$CODEX_ROOT/agents/$(basename "$file_name")" 2>/dev/null || true
    done
  done

  if [ -d "$REPO_ROOT/codex-agents/awesome" ]; then
    for cat_dir in "$REPO_ROOT/codex-agents/awesome/"*/; do
      [ -d "$cat_dir" ] || continue
      cat_name="$(basename "$cat_dir")"
      case "$cat_name" in
        01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
          for file_name in "$cat_dir"/*.toml; do
            [ -f "$file_name" ] || continue
            rm -f "$CODEX_ROOT/agents/$(basename "$file_name")" 2>/dev/null || true
          done
          ;;
      esac
    done
  fi

  for cat_dir in "$REPO_ROOT/codex-agents/agent-packs/"*/ "$REPO_ROOT/codex-agents/agency/"*/; do
    [ -d "$cat_dir" ] || continue
    cat_name="$(basename "$cat_dir")"
    for file_name in "$cat_dir"/*.toml; do
      [ -f "$file_name" ] || continue
      rm -f "$CODEX_ROOT/agent-packs/$cat_name/$(basename "$file_name")" 2>/dev/null || true
    done
  done

  if [ -d "$REPO_ROOT/codex-agents/awesome" ]; then
    for cat_dir in "$REPO_ROOT/codex-agents/awesome/"*/; do
      [ -d "$cat_dir" ] || continue
      cat_name="$(basename "$cat_dir")"
      case "$cat_name" in
        01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
          continue
          ;;
      esac
      for file_name in "$cat_dir"/*.toml; do
        [ -f "$file_name" ] || continue
        rm -f "$CODEX_ROOT/agent-packs/$cat_name/$(basename "$file_name")" 2>/dev/null || true
      done
    done
  fi

  if [ -d "$REPO_ROOT/skills/ecc" ] && [ -d "$CODEX_ROOT/skills" ]; then
    for skill_dir in "$REPO_ROOT/skills/ecc/"*/; do
      [ -d "$skill_dir" ] || continue
      rm -rf "$CODEX_ROOT/skills/$(basename "$skill_dir")" 2>/dev/null || true
    done
  fi

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

copy_skill_dirs() {
  local skill_dir dest_dir rel_path
  [ -d "$REPO_ROOT/skills/ecc" ] || return 0

  mkdir -p "$CODEX_ROOT/skills"
  for skill_dir in "$REPO_ROOT/skills/ecc/"*/; do
    [ -d "$skill_dir" ] || continue
    dest_dir="$CODEX_ROOT/skills/$(basename "$skill_dir")"
    rm -rf "$dest_dir" 2>/dev/null || true
    cp -R "$skill_dir" "$dest_dir"
    rel_path="${dest_dir#"$CODEX_ROOT"/}"
    add_manifest_entry "$rel_path"
  done

  if [ -d "$REPO_ROOT/skills/core" ]; then
    mkdir -p "$CODEX_ROOT/skills"
    for skill_dir in "$REPO_ROOT/skills/core/"*/; do
      [ -d "$skill_dir" ] || continue
      dest_dir="$CODEX_ROOT/skills/$(basename "$skill_dir")"
      rm -rf "$dest_dir" 2>/dev/null || true
      cp -R "$skill_dir" "$dest_dir"
      rel_path="${dest_dir#"$CODEX_ROOT"/}"
      add_manifest_entry "$rel_path"
    done
  fi

  # gstack (runtime install — not bundled in repo)
  echo "  [gstack] Installing/updating..."
  GSTACK_DIR="$CODEX_ROOT/skills/gstack"
  if [ -d "$GSTACK_DIR/.git" ]; then
    git -C "$GSTACK_DIR" pull --ff-only 2>/dev/null || true
  else
    rm -rf "$GSTACK_DIR"
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
    # Skip if it's a symlink pointing into gstack (i.e. gstack's own replacement)
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

  # Fallback: ensure individual gstack skills are accessible at depth 1
  if [ -d "$GSTACK_DIR" ]; then
    for skill_dir in "$GSTACK_DIR"/*/; do
      [ -f "$skill_dir/SKILL.md" ] || continue
      skill_name=$(basename "$skill_dir")
      case "$skill_name" in .git|bin|node_modules|agents) continue ;; esac
      target="$CODEX_ROOT/skills/$skill_name"
      if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        ln -s "$(cd "$skill_dir" && pwd)" "$target" 2>/dev/null || cp -r "$skill_dir" "$target"
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
}

count_managed_skills() {
  local count=0 skill_dir
  [ -d "$REPO_ROOT/skills/ecc" ] || {
    printf '0'
    return
  }

  for skill_dir in "$REPO_ROOT/skills/ecc/"*/; do
    [ -f "$CODEX_ROOT/skills/$(basename "$skill_dir")/SKILL.md" ] || continue
    count=$((count + 1))
  done

  if [ -d "$REPO_ROOT/skills/core" ]; then
    for skill_dir in "$REPO_ROOT/skills/core/"*/; do
      [ -f "$CODEX_ROOT/skills/$(basename "$skill_dir")/SKILL.md" ] || continue
      count=$((count + 1))
    done
  fi

  printf '%s' "$count"
}

cleanup_cross_tool_skills() {
  local skill_dir skill_name source_skill installed_skill
  [ -d "$REPO_ROOT/skills/ecc" ] || return 0

  for skill_dir in "$REPO_ROOT/skills/ecc/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    source_skill="$skill_dir/SKILL.md"

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

  if [ -d "$REPO_ROOT/skills/core" ]; then
    for skill_dir in "$REPO_ROOT/skills/core/"*/; do
      [ -d "$skill_dir" ] || continue
      skill_name="$(basename "$skill_dir")"
      source_skill="$skill_dir/SKILL.md"

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
  fi
}

INSTALLING_VERSION="$(current_install_version)"
INSTALLED_VERSION="none"
if [ -f "$VERSION_FILE" ]; then
  INSTALLED_VERSION="$(cat "$VERSION_FILE")"
fi

echo "=== my-codex installer ==="
echo ""
echo "Expected install footprint: ${INSTALLED_AGENT_TOTAL} agents (${AUTO_LOADED_COUNT} auto-loaded + ${AGENT_PACK_COUNT} agent-packs), ${SKILL_COUNT} skills"
echo "Source inventory: ${SOURCE_TOML_COUNT} TOML definitions before install-time deduplication"
if [ "$INSTALLED_VERSION" = "none" ]; then
  echo "Install mode: fresh (${INSTALLING_VERSION})"
elif [ "$INSTALLED_VERSION" = "$INSTALLING_VERSION" ]; then
  echo "Install mode: reinstall (${INSTALLING_VERSION})"
else
  echo "Install mode: update (${INSTALLED_VERSION} -> ${INSTALLING_VERSION})"
fi
echo ""

echo "[0/7] Checking prerequisites..."
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

copy_toml_dir "$REPO_ROOT/codex-agents/core" "$CODEX_ROOT/agents"
copy_toml_dir "$REPO_ROOT/codex-agents/omo" "$CODEX_ROOT/agents"
copy_toml_dir "$REPO_ROOT/codex-agents/omc" "$CODEX_ROOT/agents"
copy_toml_dir "$REPO_ROOT/codex-agents/awesome-core" "$CODEX_ROOT/agents"

if [ -d "$REPO_ROOT/codex-agents/awesome" ]; then
  for cat_dir in "$REPO_ROOT/codex-agents/awesome/"*/; do
    [ -d "$cat_dir" ] || continue
    cat_name="$(basename "$cat_dir")"
    case "$cat_name" in
      01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
        copy_toml_dir "$cat_dir" "$CODEX_ROOT/agents"
        ;;
    esac
  done
fi
echo "  Core agents: $(find "$CODEX_ROOT/agents" -maxdepth 1 -name '*.toml' | wc -l | tr -d ' ') installed (expected ${AUTO_LOADED_COUNT})"

for cat_dir in "$REPO_ROOT/codex-agents/agency/"*/ "$REPO_ROOT/codex-agents/agent-packs/"*/; do
  [ -d "$cat_dir" ] || continue
  cat_name="$(basename "$cat_dir")"
  copy_toml_dir "$cat_dir" "$CODEX_ROOT/agent-packs/$cat_name"
done

if [ -d "$REPO_ROOT/codex-agents/awesome" ]; then
  for cat_dir in "$REPO_ROOT/codex-agents/awesome/"*/; do
    [ -d "$cat_dir" ] || continue
    cat_name="$(basename "$cat_dir")"
    case "$cat_name" in
      01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
        continue
        ;;
    esac
    copy_toml_dir "$cat_dir" "$CODEX_ROOT/agent-packs/$cat_name"
  done
fi
echo "  Agent packs: $(find "$CODEX_ROOT/agent-packs" -name '*.toml' | wc -l | tr -d ' ') installed (expected ${AGENT_PACK_COUNT})"

if [ -n "$PROFILE_OVERRIDE" ] && [ -x "$PACK_MANAGER" ]; then
  HOME="$HOME" "$PACK_MANAGER" set-profile "$PROFILE_OVERRIDE"
fi

echo "[2/7] Installing skills..."
copy_skill_dirs
managed_skills="$(count_managed_skills)"
total_skills="$(find "$CODEX_ROOT/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
extra_skills=$((total_skills - managed_skills))
echo "  Skills: ${managed_skills} managed installs refreshed (expected ${SKILL_COUNT})"
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
echo "  Source TOML:   ${SOURCE_TOML_COUNT} definitions"
echo "  Core agents:   $(find "$CODEX_ROOT/agents" -maxdepth 1 -type f -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') files (expected ${AUTO_LOADED_COUNT})"
echo "  Active packs:  $(find "$CODEX_ROOT/agents" -maxdepth 1 -type l -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') linked files"
echo "  Agent packs:   $(find "$CODEX_ROOT/agent-packs" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') files (expected ${AGENT_PACK_COUNT})"
echo "  Enabled packs: $(format_enabled_packs "$CODEX_ROOT/enabled-agent-packs.txt")"
echo "  Skills:        ${managed_skills} managed installs refreshed (expected ${SKILL_COUNT})"
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
