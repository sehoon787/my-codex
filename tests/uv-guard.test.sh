#!/usr/bin/env bash
# Regression test for install.sh's ensure_uv_tool() `uv tool list` guard.
#
# The guard used to match on distribution name only
# (`grep -qE "^${dist}[[:space:]]"`), so it reported "already installed" for
# ANY installed version of a distribution -- bumping a pin (e.g.
# serena-agent==1.6.0 -> 1.7.0) on a machine that already had the old version
# would silently skip the upgrade. The guard is now version-aware: it must
# only skip when the exact pinned version is already installed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
BIN_DIR="$TMP_ROOT/bin"
mkdir -p "$BIN_DIR"
LOG_FILE="$TMP_ROOT/uv.log"
STATE_FILE="$TMP_ROOT/uv-tools.txt"

# Extract ensure_uv_tool() straight out of install.sh (rather than
# reimplementing it here) so this test tracks the real function.
FUNC_SRC="$(sed -n '/^ensure_uv_tool() {/,/^}/p' "$INSTALL_SH")"
if [ -z "$FUNC_SRC" ]; then
  echo "FAIL: could not extract ensure_uv_tool() from install.sh" >&2
  exit 1
fi
eval "$FUNC_SRC"

# Fake `uv`: `tool list` reads a state file, `tool install` overwrites the
# pinned line in it, mirroring the real command's observable behavior.
cat > "$BIN_DIR/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
STATE="${TEST_UV_STATE:?}"
echo "uv $*" >> "${TEST_UV_LOG:?}"
if [ "${1:-}" = "tool" ]; then
  case "${2:-}" in
    list) [ -f "$STATE" ] && cat "$STATE"; exit 0 ;;
    install)
      for spec in "$@"; do :; done
      name="${spec%%==*}"; name="${name%%[*}"
      printf '%s v%s\n' "$name" "${spec##*==}" > "$STATE"
      exit 0
      ;;
  esac
fi
exit 0
EOF
chmod +x "$BIN_DIR/uv"
export TEST_UV_STATE="$STATE_FILE" TEST_UV_LOG="$LOG_FILE"
export PATH="$BIN_DIR:$PATH"

ERRORS=0

# 1. Nothing installed yet -> must install.
: > "$LOG_FILE"; : > "$STATE_FILE"
ensure_uv_tool "serena" serena-agent "serena-agent==1.7.0"
if grep -q 'uv tool install --python 3.13 serena-agent==1.7.0' "$LOG_FILE"; then
  echo "OK: fresh install calls uv tool install"
else
  echo "FAIL: fresh install did not call uv tool install" >&2
  ERRORS=$((ERRORS + 1))
fi

# 2. Pinned version bumped past what's installed -> must upgrade, not skip.
: > "$LOG_FILE"
printf 'serena-agent v1.6.0\n- serena\n' > "$STATE_FILE"
ensure_uv_tool "serena" serena-agent "serena-agent==1.7.0"
if grep -q 'uv tool install --python 3.13 serena-agent==1.7.0' "$LOG_FILE"; then
  echo "OK: an older installed version triggers an upgrade"
else
  echo "FAIL: version bump did not trigger an upgrade (version-blind guard regression)" >&2
  ERRORS=$((ERRORS + 1))
fi

# 3. Installed version already matches the pin -> must skip.
: > "$LOG_FILE"
printf 'serena-agent v1.7.0\n- serena\n' > "$STATE_FILE"
ensure_uv_tool "serena" serena-agent "serena-agent==1.7.0"
if grep -q 'uv tool install' "$LOG_FILE"; then
  echo "FAIL: an already-matching version was reinstalled instead of skipped" >&2
  ERRORS=$((ERRORS + 1))
else
  echo "OK: an already-matching version is skipped"
fi

# 4. Same check for a spec with extras (headroom-ai[all]==0.37.0), matching
# the exact case reported: an old v0.30.0 install must not block the 0.37.0 pin.
: > "$LOG_FILE"
printf 'headroom-ai v0.30.0\n- headroom\n' > "$STATE_FILE"
ensure_uv_tool "headroom" headroom-ai "headroom-ai[all]==0.37.0"
if grep -q 'uv tool install --python 3.13 headroom-ai\[all\]==0.37.0' "$LOG_FILE"; then
  echo "OK: headroom-ai[all] version bump triggers an upgrade"
else
  echo "FAIL: headroom-ai[all] version bump did not trigger an upgrade" >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "$ERRORS check(s) failed" >&2
  exit 1
fi
echo "uv-guard test passed"
