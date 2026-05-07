#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
err()  { echo -e "${RED}✗ $*${NC}" >&2; }

# Parse args
DO_CLAUDE=0
DO_CODEX=0
case "${1:-}" in
  --claude) DO_CLAUDE=1 ;;
  --codex)  DO_CODEX=1  ;;
  "")       DO_CLAUDE=1; DO_CODEX=1 ;;
  *) err "Usage: $0 [--claude|--codex]"; exit 1 ;;
esac

CLI_PROXY="/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus"
CLI_CONFIG="/Applications/VibeProxy.app/Contents/Resources/config.yaml"

# ---------------------------------------------------------------------------
# 1. Install VibeProxy if needed
# ---------------------------------------------------------------------------
if [[ ! -d /Applications/VibeProxy.app ]]; then
  echo "VibeProxy not found. Installing..."

  ARCH=$(uname -m)
  if [[ "$ARCH" == "arm64" ]]; then
    DMG_ARCH="arm64"
  else
    DMG_ARCH="x86_64"
  fi

  FALLBACK_URL="https://github.com/automazeio/vibeproxy/releases/download/v1.8.142/VibeProxy-${DMG_ARCH}.dmg"

  DMG_URL=""
  SHA_URL=""
  if API_JSON=$(curl -fsSL "https://api.github.com/repos/automazeio/vibeproxy/releases/latest" 2>/dev/null); then
    DMG_URL=$(echo "$API_JSON" | grep -o "\"browser_download_url\": *\"[^\"]*VibeProxy-${DMG_ARCH}\.dmg\"" | grep -o 'https://[^"]*' | head -1)
    SHA_URL=$(echo "$API_JSON" | grep -o "\"browser_download_url\": *\"[^\"]*VibeProxy-${DMG_ARCH}\.dmg\.sha256\"" | grep -o 'https://[^"]*' | head -1)
  fi

  if [[ -z "$DMG_URL" ]]; then
    warn "GitHub API unavailable, using fallback URL"
    DMG_URL="$FALLBACK_URL"
    SHA_URL="${FALLBACK_URL}.sha256"
  fi

  TMPDIR_VP=$(mktemp -d)
  trap 'rm -rf "$TMPDIR_VP"' EXIT

  echo "Downloading VibeProxy-${DMG_ARCH}.dmg..."
  curl -fL --progress-bar "$DMG_URL" -o "$TMPDIR_VP/VibeProxy.dmg"

  if curl -fsSL "$SHA_URL" -o "$TMPDIR_VP/VibeProxy.dmg.sha256" 2>/dev/null; then
    echo "Verifying checksum..."
    (cd "$TMPDIR_VP" && sed -i '' "s|VibeProxy-${DMG_ARCH}.dmg|VibeProxy.dmg|g" VibeProxy.dmg.sha256 2>/dev/null || true)
    if ! (cd "$TMPDIR_VP" && shasum -a 256 -c VibeProxy.dmg.sha256); then
      err "Checksum verification failed"
      exit 1
    fi
    ok "Checksum verified"
  else
    warn "Could not fetch checksum file, skipping verification"
  fi

  echo "Mounting DMG..."
  MOUNT_POINT=$(hdiutil attach -nobrowse -quiet "$TMPDIR_VP/VibeProxy.dmg" | grep "/Volumes/" | awk '{print $NF}')

  echo "Copying to /Applications..."
  ditto "$MOUNT_POINT/VibeProxy.app" /Applications/VibeProxy.app

  hdiutil detach "$MOUNT_POINT" -quiet

  ok "VibeProxy installed"

  echo "Launching VibeProxy..."
  open /Applications/VibeProxy.app

  echo "Waiting for VibeProxy to start on port 8317..."
  for i in $(seq 1 10); do
    if curl -fsS "http://127.0.0.1:8317" &>/dev/null; then
      ok "VibeProxy is running"
      break
    fi
    sleep 1
    if [[ $i -eq 10 ]]; then
      warn "VibeProxy did not respond on port 8317 within 10 seconds"
    fi
  done
else
  ok "VibeProxy already installed"
fi

# ---------------------------------------------------------------------------
# 2. Interactive provider authentication
# ---------------------------------------------------------------------------
if [[ -t 0 ]]; then
  echo ""
  echo "Select providers to authenticate:"
  echo "  1) GPT (ChatGPT Plus subscription)"
  echo "  2) Gemini (Google AI subscription)"
  echo "  3) Claude (Anthropic subscription)"
  echo "  a) All providers"
  read -rp "Enter choices (e.g., 1 2 or a): " PROVIDER_CHOICES

  AUTH_GPT=0
  AUTH_GEMINI=0
  AUTH_CLAUDE=0

  for choice in $PROVIDER_CHOICES; do
    case "$choice" in
      1) AUTH_GPT=1 ;;
      2) AUTH_GEMINI=1 ;;
      3) AUTH_CLAUDE=1 ;;
      a|A) AUTH_GPT=1; AUTH_GEMINI=1; AUTH_CLAUDE=1 ;;
    esac
  done

  if [[ $AUTH_GPT -eq 1 ]]; then
    echo "Authenticating GPT..."
    "$CLI_PROXY" -config "$CLI_CONFIG" -codex-login
    ok "GPT authenticated"
  fi

  if [[ $AUTH_GEMINI -eq 1 ]]; then
    echo "Authenticating Gemini..."
    "$CLI_PROXY" -config "$CLI_CONFIG" -login
    ok "Gemini authenticated"
  fi

  if [[ $AUTH_CLAUDE -eq 1 ]]; then
    echo "Authenticating Claude..."
    "$CLI_PROXY" -config "$CLI_CONFIG" -claude-login
    ok "Claude authenticated"
  fi
else
  warn "Non-interactive terminal, skipping provider authentication"
fi

# ---------------------------------------------------------------------------
# 3. Install model-router and aliases
# ---------------------------------------------------------------------------
mkdir -p ~/.vibeproxy

SRC_ROUTER="$SCRIPT_DIR/vibeproxy/model-router.mjs"
if [[ -f "$SRC_ROUTER" ]]; then
  cp "$SRC_ROUTER" ~/.vibeproxy/model-router.mjs
  ok "model-router.mjs installed to ~/.vibeproxy/"
else
  err "model-router.mjs not found at $SRC_ROUTER"
  exit 1
fi

cat > ~/.vibeproxy/aliases.sh << 'EOF'
# VibeProxy aliases — use GPT/Gemini models in Claude Code
claude-gpt() { node ~/.vibeproxy/model-router.mjs gpt &>/dev/null & local pid=$!; sleep 0.5; ANTHROPIC_BASE_URL=http://127.0.0.1:8316 ANTHROPIC_API_KEY=dummy-not-used claude --model gpt-5.5 "$@"; kill $pid 2>/dev/null; }
claude-gemini() { node ~/.vibeproxy/model-router.mjs gemini &>/dev/null & local pid=$!; sleep 0.5; ANTHROPIC_BASE_URL=http://127.0.0.1:8316 ANTHROPIC_API_KEY=dummy-not-used claude --model gemini-2.5-pro "$@"; kill $pid 2>/dev/null; }
claude-gemini-flash() { node ~/.vibeproxy/model-router.mjs gemini &>/dev/null & local pid=$!; sleep 0.5; ANTHROPIC_BASE_URL=http://127.0.0.1:8316 ANTHROPIC_API_KEY=dummy-not-used claude --model gemini-2.5-flash "$@"; kill $pid 2>/dev/null; }
EOF
ok "aliases.sh generated at ~/.vibeproxy/aliases.sh"

# ---------------------------------------------------------------------------
# 4. Source aliases in ~/.zshrc (claude mode)
# ---------------------------------------------------------------------------
if [[ $DO_CLAUDE -eq 1 ]]; then
  ZSHRC="$HOME/.zshrc"
  SOURCE_LINE='source ~/.vibeproxy/aliases.sh'
  if ! grep -qF "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
    echo "" >> "$ZSHRC"
    echo "# VibeProxy" >> "$ZSHRC"
    echo "$SOURCE_LINE" >> "$ZSHRC"
    ok "Added source line to $ZSHRC"
  else
    warn "aliases.sh already sourced in $ZSHRC"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Patch ~/.codex/config.toml (codex mode)
# ---------------------------------------------------------------------------
if [[ $DO_CODEX -eq 1 ]]; then
  CODEX_CONFIG="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex"

  if [[ -f "$CODEX_CONFIG" ]]; then
    if grep -q "openai_base_url" "$CODEX_CONFIG"; then
      sed -i '' 's|^openai_base_url *=.*|openai_base_url = "http://127.0.0.1:8317"|' "$CODEX_CONFIG"
      ok "Updated openai_base_url in $CODEX_CONFIG"
    else
      echo 'openai_base_url = "http://127.0.0.1:8317"' >> "$CODEX_CONFIG"
      ok "Added openai_base_url to $CODEX_CONFIG"
    fi
  else
    echo 'openai_base_url = "http://127.0.0.1:8317"' > "$CODEX_CONFIG"
    ok "Created $CODEX_CONFIG with openai_base_url"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Setup complete!"
if [[ $DO_CLAUDE -eq 1 ]]; then
  echo "  Claude Code: run 'source ~/.zshrc' then use claude-gpt / claude-gemini / claude-gemini-flash"
fi
if [[ $DO_CODEX -eq 1 ]]; then
  echo "  Codex: openai_base_url set to http://127.0.0.1:8317"
fi
