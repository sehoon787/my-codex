#!/usr/bin/env bash
# Regression test for install.sh's ensure_mcp_server_toml().
#
# The writer used to be append-once: a `grep -qE "^\[mcp_servers\.<name>\]"`
# guard returned early whenever the table already existed. Any key added to a
# table afterwards (e.g. headroom's `default_tools_approval_mode = "approve"`)
# therefore never reached a machine that had already been installed -- the same
# defect class as #92/#95. The writer now refreshes the table body in place, and
# must leave every other byte of config.toml untouched.
#
# `bash tests/mcp-table-upsert.test.sh`
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Extract ensure_mcp_server_toml() straight out of install.sh (rather than
# reimplementing it here) so this test tracks the real function.
FUNC_SRC="$(sed -n '/^ensure_mcp_server_toml() {/,/^}/p' "$INSTALL_SH")"
if [ -z "$FUNC_SRC" ]; then
  echo "FAIL: could not extract ensure_mcp_server_toml() from install.sh" >&2
  exit 1
fi
eval "$FUNC_SRC"

ERRORS=0
check() {
  if [ "$2" = "$3" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    echo "  expected: $(printf '%s' "$3" | od -c | head -20)"
    echo "  actual:   $(printf '%s' "$2" | od -c | head -20)"
    ERRORS=$((ERRORS + 1))
  fi
}

# 1. Fresh config -> table appended at EOF.
CONFIG_FILE="$TMP_ROOT/fresh.toml"
cat > "$CONFIG_FILE" <<'TOML'
model = "gpt-5"

[features]
hooks = true
TOML
ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"' >/dev/null
check "1. fresh config gains the headroom table" "$(cat "$CONFIG_FILE")" "$(cat <<'TOML'
model = "gpt-5"

[features]
hooks = true

[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]
default_tools_approval_mode = "approve"
TOML
)"

# 2. Re-run with identical keys -> byte-for-byte no-op.
BEFORE="$(cat "$CONFIG_FILE")"
OUT=$(ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"')
check "2. identical re-run is a no-op" "$(cat "$CONFIG_FILE")" "$BEFORE"
case "$OUT" in
  *"already registered"*) echo "PASS  2b. identical re-run reports 'already registered'" ;;
  *) echo "FAIL  2b. identical re-run reported: $OUT"; ERRORS=$((ERRORS + 1)) ;;
esac

# 3. The regression itself: a pre-existing table WITHOUT the new key must gain
#    it, and every surrounding line must survive unchanged.
CONFIG_FILE="$TMP_ROOT/existing.toml"
cat > "$CONFIG_FILE" <<'TOML'
model = "gpt-5"

[features]
hooks = true

[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]

[mcp_servers.serena]
command = "serena"
startup_timeout_sec = 15

[agents]
max_threads = 8
TOML
OUT=$(ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"')
check "3. existing table is refreshed with the new key" "$(cat "$CONFIG_FILE")" "$(cat <<'TOML'
model = "gpt-5"

[features]
hooks = true

[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]
default_tools_approval_mode = "approve"

[mcp_servers.serena]
command = "serena"
startup_timeout_sec = 15

[agents]
max_threads = 8
TOML
)"
case "$OUT" in
  *"refreshed"*) echo "PASS  3b. refresh is reported" ;;
  *) echo "FAIL  3b. refresh reported: $OUT"; ERRORS=$((ERRORS + 1)) ;;
esac

# 4. A trailing table at EOF with no following header refreshes too.
CONFIG_FILE="$TMP_ROOT/trailing.toml"
cat > "$CONFIG_FILE" <<'TOML'
model = "gpt-5"

[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]
TOML
ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"' >/dev/null
check "4. table at EOF is refreshed" "$(cat "$CONFIG_FILE")" "$(cat <<'TOML'
model = "gpt-5"

[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]
default_tools_approval_mode = "approve"
TOML
)"

# 5. A different server's table is never touched by a refresh of this one.
CONFIG_FILE="$TMP_ROOT/isolation.toml"
cat > "$CONFIG_FILE" <<'TOML'
[mcp_servers.serena]
command = "serena"
args = ["start-mcp-server"]

[mcp_servers.headroom]
command = "headroom"
TOML
ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"' >/dev/null
check "5. sibling server table is untouched" "$(sed -n '1,3p' "$CONFIG_FILE")" "$(cat <<'TOML'
[mcp_servers.serena]
command = "serena"
args = ["start-mcp-server"]
TOML
)"

# 6. A header line that is not an exact match (trailing comment, odd spacing)
#    reads as hand-managed: skipped untouched. This is the escape hatch for a
#    table a user wants to own.
CONFIG_FILE="$TMP_ROOT/custom-header.toml"
cat > "$CONFIG_FILE" <<'TOML'
[mcp_servers.headroom] # my own notes
command = "headroom-custom"
TOML
BEFORE="$(cat "$CONFIG_FILE")"
OUT=$(ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"')
check "6. hand-managed header is left untouched" "$(cat "$CONFIG_FILE")" "$BEFORE"
case "$OUT" in
  *"custom header, left as is"*) echo "PASS  6b. hand-managed header is reported as skipped" ;;
  *) echo "FAIL  6b. hand-managed header reported: $OUT"; ERRORS=$((ERRORS + 1)) ;;
esac

# 7. Documented trade: the refresh replaces the WHOLE body, so a key or comment
#    hand-added inside an installer-owned table does NOT survive. Pinned here so
#    the behavior stays deliberate rather than accidental.
CONFIG_FILE="$TMP_ROOT/hand-edited-body.toml"
cat > "$CONFIG_FILE" <<'TOML'
[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]
# user note
startup_timeout_sec = 99
TOML
ensure_mcp_server_toml headroom \
  'command = "headroom"' \
  'args = ["mcp", "serve"]' \
  'default_tools_approval_mode = "approve"' >/dev/null
check "7. hand-added keys inside an owned table are replaced" "$(cat "$CONFIG_FILE")" "$(cat <<'TOML'
[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve"]
default_tools_approval_mode = "approve"
TOML
)"

# 8. install.sh runs under `set -euo pipefail`; the function must survive every
#    path with those options on, not just the relaxed ones this harness uses.
if bash -c '
    set -euo pipefail
    eval "$(sed -n "/^ensure_mcp_server_toml() {/,/^}/p" "$1")"
    T=$(mktemp -d)
    CONFIG_FILE="$T/x.toml"; printf "model = \"gpt-5\"\n" > "$CONFIG_FILE"
    ensure_mcp_server_toml headroom "command = \"headroom\"" "args = [\"mcp\"]"
    ensure_mcp_server_toml headroom "command = \"headroom\"" "args = [\"mcp\"]"
    ensure_mcp_server_toml headroom "command = \"headroom\"" "args = [\"mcp\", \"serve\"]"
    printf "[mcp_servers.headroom]\ncommand = \"headroom\"" > "$CONFIG_FILE"
    ensure_mcp_server_toml headroom "command = \"headroom\"" "args = [\"mcp\"]"
    rm -rf "$T"
  ' _ "$INSTALL_SH" >/dev/null 2>&1; then
  echo "PASS  8. function survives set -euo pipefail on append, no-op, refresh and EOF paths"
else
  echo "FAIL  8. function trips set -euo pipefail"
  ERRORS=$((ERRORS + 1))
fi

# 9. install.sh really does ship the approval key for headroom (and only there).
if grep -q "default_tools_approval_mode = \"approve\"" "$INSTALL_SH"; then
  echo "PASS  9. install.sh sets default_tools_approval_mode for headroom"
else
  echo "FAIL  9. install.sh does not set default_tools_approval_mode"
  ERRORS=$((ERRORS + 1))
fi
if [ "$(grep -c 'default_tools_approval_mode' "$INSTALL_SH")" = "2" ]; then
  echo "PASS  9b. approval key appears only in the headroom block and its comment"
else
  echo "FAIL  9b. unexpected number of default_tools_approval_mode mentions in install.sh"
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -eq 0 ]; then
  echo "ALL PASSED"
  exit 0
fi
echo "$ERRORS FAILED"
exit 1
