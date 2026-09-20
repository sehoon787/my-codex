#!/usr/bin/env bash
set -euo pipefail

# Regression coverage for the installer's bounded, non-fatal tool probes.
# Run with: `bash tests/tool-verification.test.sh`

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/verify-installed-tools.sh
source "$REPO_ROOT/scripts/verify-installed-tools.sh"

TEST_ROOT="$(mktemp -d)"
BIN_DIR="$TEST_ROOT/bin"
CODEX_ROOT="$TEST_ROOT/home/.codex"
PROBE_TMP="$TEST_ROOT/probe-tmp"
LOG_FILE="$TEST_ROOT/probes.log"
HOSTILE_CODEX_HOME="$TEST_ROOT/hostile-codex-home"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$PROBE_TMP" "$HOSTILE_CODEX_HOME" \
  "$CODEX_ROOT/skills/archify/bin" "$CODEX_ROOT/skills/archify/examples"
printf 'untouched\n' > "$HOSTILE_CODEX_HOME/sentinel"
printf '{}\n' > "$CODEX_ROOT/skills/archify/examples/agent-tool-call.workflow.json"
printf '// test renderer\n' > "$CODEX_ROOT/skills/archify/bin/archify.mjs"

cat > "$BIN_DIR/codeburn" <<'EOF'
#!/usr/bin/env bash
printf 'codeburn %s\n' "$*" >> "${TOOL_PROBE_TEST_LOG:?}"
case "${TEST_CODEBURN_MODE:-ok}" in
  fail) echo 'codeburn failed' >&2; exit 9 ;;
  timeout) sleep 5; exit 0 ;;
esac
printf '0.9.23\n'
EOF

cat > "$BIN_DIR/serena" <<'EOF'
#!/usr/bin/env bash
printf 'serena %s\n' "$*" >> "${TOOL_PROBE_TEST_LOG:?}"
case "${TEST_SERENA_MODE:-ok}" in
  fail) echo 'serena failed' >&2; exit 8 ;;
  timeout)
    if [ -n "${TOOL_PROBE_CHILD_SENTINEL:-}" ]; then
      (sleep 2; printf 'child survived\n' > "$TOOL_PROBE_CHILD_SENTINEL") &
      wait
    else
      sleep 5
    fi
    exit 0
    ;;
esac
printf 'Serena 1.7.0\n'
EOF

cat > "$BIN_DIR/headroom" <<'EOF'
#!/usr/bin/env bash
printf 'headroom %s\n' "$*" >> "${TOOL_PROBE_TEST_LOG:?}"
case "${TEST_HEADROOM_MODE:-ok}" in
  fail) echo 'headroom failed' >&2; exit 7 ;;
  timeout) sleep 5; exit 0 ;;
esac
printf 'headroom, version 0.37.0\n'
EOF

cat > "$BIN_DIR/node" <<'EOF'
#!/usr/bin/env bash
printf 'node %s\n' "$*" >> "${TOOL_PROBE_TEST_LOG:?}"
if [ "${2:-}" = "check" ] && [ "${TEST_NODE_CHECK_MODE:-ok}" = "fail" ]; then
  echo 'archify check failed' >&2
  exit 5
fi
case "${TEST_NODE_MODE:-ok}" in
  fail) echo 'archify render failed' >&2; exit 6 ;;
  timeout) sleep 5; exit 0 ;;
  slow) sleep 0.7 ;;
esac
if [ "${2:-}" = "render" ]; then
  for output_path in "$@"; do :; done
  printf '<!doctype html><html><body>archify test</body></html>\n' > "$output_path"
fi
EOF
chmod +x "$BIN_DIR/codeburn" "$BIN_DIR/serena" "$BIN_DIR/headroom" "$BIN_DIR/node"

run_verification() {
  local probe_parent="${TOOL_PROBE_TEST_TMP_PARENT:-$PROBE_TMP}"
  env \
    HOME="$TEST_ROOT/home" \
    CODEX_HOME="$HOSTILE_CODEX_HOME" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    TOOL_PROBE_TEST_LOG="$LOG_FILE" \
    MY_CODEX_VERIFY_TIMEOUT_SECONDS=1 \
    MY_CODEX_VERIFY_TMP_PARENT="$probe_parent" \
    bash -c 'set -euo pipefail; source "$1"; verify_installed_tools "$2"' \
      _ "$REPO_ROOT/scripts/verify-installed-tools.sh" "$CODEX_ROOT"
}

success_output="$(run_verification)"
grep -q '^  codeburn:      OK (0.9.23)$' <<<"$success_output"
grep -q '^  serena:        OK (Serena 1.7.0)$' <<<"$success_output"
grep -q '^  headroom:      OK (headroom, version 0.37.0)$' <<<"$success_output"
grep -q '^  archify:       OK (rendered and checked bundled workflow example)$' <<<"$success_output"
grep -q '^  Tool probes:   4 OK, 0 FAIL$' <<<"$success_output"
grep -q '^  Serena dashboard: http://localhost:24282/dashboard/index.html$' <<<"$success_output"
grep -q '^  codeburn: `codeburn web` serves http://127.0.0.1:4747 (not started by this installer)$' <<<"$success_output"
grep -q '^  Serena/Headroom MCP: auto-start each Codex session$' <<<"$success_output"
grep -q '^codeburn --version$' "$LOG_FILE"
grep -q '^serena --version$' "$LOG_FILE"
grep -q '^headroom --version$' "$LOG_FILE"
grep -q 'node .*archify\.mjs render workflow .*agent-tool-call\.workflow\.json ' "$LOG_FILE"
grep -q 'node .*archify\.mjs check .*archify-probe\.html$' "$LOG_FILE"
test -z "$(find "$PROBE_TMP" -mindepth 1 -print -quit)"
test "$(cat "$HOSTILE_CODEX_HOME/sentinel")" = "untouched"
test ! -e "$HOSTILE_CODEX_HOME/skills"

failure_output="$(TEST_HEADROOM_MODE=fail run_verification)"
grep -q '^  headroom:      FAIL (exit 7: headroom failed)$' <<<"$failure_output"
grep -q '^  Tool probes:   3 OK, 1 FAIL$' <<<"$failure_output"
test -z "$(find "$PROBE_TMP" -mindepth 1 -print -quit)"

SECONDS=0
child_sentinel="$TEST_ROOT/timeout-child-survived"
timeout_output="$(TOOL_PROBE_CHILD_SENTINEL="$child_sentinel" TEST_SERENA_MODE=timeout run_verification)"
elapsed=$SECONDS
grep -q '^  serena:        FAIL (timeout after 1s)$' <<<"$timeout_output"
grep -q '^  Tool probes:   3 OK, 1 FAIL$' <<<"$timeout_output"
test "$elapsed" -le 2
sleep 2
test ! -e "$child_sentinel"
test -z "$(find "$PROBE_TMP" -mindepth 1 -print -quit)"

SECONDS=0
archify_budget_output="$(TEST_NODE_MODE=slow run_verification)"
archify_elapsed=$SECONDS
grep -q '^  archify:       FAIL (check timeout after 1s)$' <<<"$archify_budget_output"
grep -q '^  Tool probes:   3 OK, 1 FAIL$' <<<"$archify_budget_output"
test "$archify_elapsed" -le 2
test -z "$(find "$PROBE_TMP" -mindepth 1 -print -quit)"

bad_temp_parent="$TEST_ROOT/not-a-directory"
printf 'file\n' > "$bad_temp_parent"
bad_temp_output="$(TOOL_PROBE_TEST_TMP_PARENT="$bad_temp_parent" run_verification)"
grep -q '^  Tool probes:   0 OK, 4 FAIL (could not create temporary directory)$' <<<"$bad_temp_output"
grep -q '^  Serena dashboard: http://localhost:24282/dashboard/index.html$' <<<"$bad_temp_output"
grep -q '^  codeburn: `codeburn web` serves http://127.0.0.1:4747 (not started by this installer)$' <<<"$bad_temp_output"
grep -q '^  Serena/Headroom MCP: auto-start each Codex session$' <<<"$bad_temp_output"

archify_failure_output="$(TEST_NODE_MODE=fail run_verification)"
grep -q '^  archify:       FAIL (exit 6: archify render failed)$' <<<"$archify_failure_output"
grep -q '^  Tool probes:   3 OK, 1 FAIL$' <<<"$archify_failure_output"
test -z "$(find "$PROBE_TMP" -mindepth 1 -print -quit)"

archify_check_failure_output="$(TEST_NODE_CHECK_MODE=fail run_verification)"
grep -q '^  archify:       FAIL (check exit 5: archify check failed)$' <<<"$archify_check_failure_output"
grep -q '^  Tool probes:   3 OK, 1 FAIL$' <<<"$archify_check_failure_output"
test -z "$(find "$PROBE_TMP" -mindepth 1 -print -quit)"

echo "Tool verification tests passed"
