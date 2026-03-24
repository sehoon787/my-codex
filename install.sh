#!/usr/bin/env bash
# my-codex full installer — installs agents, skills, rules for OpenAI Codex CLI
# Usage: bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== my-codex installer ==="
echo ""

# ── 0. Prerequisites ──
echo "[0/7] Checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "ERROR: node not found. Install Node.js v20+"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ERROR: npm not found"; exit 1; }
command -v git  >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
if ! command -v codex >/dev/null 2>&1; then
  echo "WARNING: codex CLI not found. Install from https://github.com/openai/codex"
  echo "  Continuing anyway — agents will be ready when codex is installed."
fi
echo "  Prerequisites OK"

# ── 0.5. Clean previous installation ──
echo "[0.5/7] Cleaning previous agent installation..."
rm -f "$HOME/.codex/agents/"*.toml 2>/dev/null || true
rm -rf "$HOME/.codex/agent-packs/" 2>/dev/null || true
echo "  Previous agents cleaned"

# ── 1. Codex agents (TOML format) ──
echo "[1/7] Installing Codex agents..."
mkdir -p "$HOME/.codex/agents" "$HOME/.codex/agent-packs"

# Core agents (always loaded by Codex — ~/.codex/agents/ is recursively scanned)
if [ -d "$SCRIPT_DIR/codex-agents/core" ]; then
  cp "$SCRIPT_DIR/codex-agents/core/"*.toml "$HOME/.codex/agents/" 2>/dev/null || true
  echo "  Core agents: $(find "$HOME/.codex/agents" -maxdepth 1 -name '*.toml' | wc -l | tr -d ' ') installed"
fi

# Domain agent-packs (on-demand via symlink)
for cat_dir in "$SCRIPT_DIR/codex-agents/agent-packs/"*/; do
  [ -d "$cat_dir" ] || continue
  cat_name=$(basename "$cat_dir")
  mkdir -p "$HOME/.codex/agent-packs/$cat_name"
  cp "$cat_dir"*.toml "$HOME/.codex/agent-packs/$cat_name/" 2>/dev/null || true
done
echo "  Agent packs: $(find "$HOME/.codex/agent-packs" -name '*.toml' | wc -l | tr -d ' ') installed"

# Awesome Codex Subagents (native TOML — add to core)
if [ -d "$SCRIPT_DIR/codex-agents/awesome" ]; then
  for cat_dir in "$SCRIPT_DIR/codex-agents/awesome/"*/; do
    [ -d "$cat_dir" ] || continue
    cat_name=$(basename "$cat_dir")
    # Core categories go to agents, rest go to packs
    case "$cat_name" in
      01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
        cp "$cat_dir"*.toml "$HOME/.codex/agents/" 2>/dev/null || true
        ;;
      *)
        mkdir -p "$HOME/.codex/agent-packs/$cat_name"
        cp "$cat_dir"*.toml "$HOME/.codex/agent-packs/$cat_name/" 2>/dev/null || true
        ;;
    esac
  done
  echo "  Awesome agents installed"
fi

# ── 2. Skills ──
echo "[2/7] Installing skills..."
mkdir -p "$HOME/.codex/skills"
# Note: Codex scans ~/.codex/skills/ for SKILL.md files
if [ -d "$SCRIPT_DIR/skills" ]; then
  cp -r "$SCRIPT_DIR/skills/ecc/"* "$HOME/.codex/skills/" 2>/dev/null || true
fi
echo "  Skills: $(find "$HOME/.codex/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ') installed"

# ── 3. Global AGENTS.md ──
echo "[3/7] Setting up AGENTS.md..."
if [ ! -f "$HOME/.codex/AGENTS.md" ]; then
  cp "$SCRIPT_DIR/templates/codex-AGENTS.md" "$HOME/.codex/AGENTS.md"
  echo "  AGENTS.md created"
else
  echo "  AGENTS.md already exists — skipping (delete to regenerate)"
fi

# ── 4. Configure config.toml ──
echo "[4/7] Configuring config.toml..."
CONFIG_FILE="$HOME/.codex/config.toml"
touch "$CONFIG_FILE"

# Enable multi_agent feature if not already set
if ! grep -q 'multi_agent' "$CONFIG_FILE" 2>/dev/null; then
  cat >> "$CONFIG_FILE" << 'TOML'

# ── my-codex managed settings ──
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

# ── 5. MCP servers ──
echo "[5/7] Registering MCP servers..."
if command -v codex >/dev/null 2>&1; then
  codex mcp add context7  -- npx -y @anthropic/context7-mcp 2>/dev/null || true
  codex mcp add exa       -- npx -y exa-mcp-server 2>/dev/null || true
  codex mcp add grep_app  -- npx -y @anthropic/grep-app-mcp 2>/dev/null || true
  echo "  3 MCP servers registered (context7, exa, grep_app)"
else
  echo "  codex not found — MCP servers will be registered when codex is installed"
fi

# ── 6. Companion tools ──
echo "[6/7] Installing companion tools..."

# 6a. ast-grep
echo "  [6a] ast-grep..."
if command -v ast-grep >/dev/null 2>&1; then
  echo "    ast-grep already installed"
else
  npm i -g @ast-grep/cli@0.42.0 2>/dev/null || echo "    WARNING: ast-grep install failed"
fi

# ── 7. Verification ──
echo ""
echo "[7/7] Verification"
echo "  Core agents:   $(find "$HOME/.codex/agents" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Agent packs:   $(find "$HOME/.codex/agent-packs" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Skills:        $(find "$HOME/.codex/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ') installed"
echo "  AGENTS.md:     $(test -f "$HOME/.codex/AGENTS.md" && echo 'OK' || echo 'MISSING')"
echo "  config.toml:   $(grep -q 'multi_agent' "$HOME/.codex/config.toml" 2>/dev/null && echo 'OK' || echo 'NEEDS CONFIG')"
echo "  codex:         $(command -v codex >/dev/null 2>&1 && echo "OK ($(codex --version 2>/dev/null))" || echo 'NOT INSTALLED')"
echo ""
echo "=== Install complete ==="
echo ""
echo "Activate domain agent packs with symlinks:"
echo "  ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/"
