#!/usr/bin/env bash
#
# run-tests.test.sh — scripts/run-tests.sh, the one test list CI and the
# upstream sync share, runs every test past a failure, names the failures,
# and gives each test its own throwaway HOME, XDG_CONFIG_HOME and TMPDIR and
# no CODEX_HOME. `bash tests/run-tests.test.sh`
#
# Runs a copy of the real script against a throwaway tree of fake tests.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT

fail=0
check() {
  if [ "$2" = "1" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    fail=1
  fi
}

T="$TMP/tree"
mkdir -p "$T/scripts" "$T/tests" "$TMP/base"
cp "$REPO/scripts/run-tests.sh" "$T/scripts/run-tests.sh"

# Fake tests. a, b and e record the HOME, XDG_CONFIG_HOME and TMPDIR they see.
cat > "$T/scripts/test-fake.sh" <<'EOF'
printf 'codex_home=%s\n' "${CODEX_HOME-unset}" >> "$PROBE"
EOF
cat > "$T/tests/a.test.sh" <<'EOF'
printf 'a|%s|%s|%s\n' "$HOME" "$XDG_CONFIG_HOME" "$TMPDIR" >> "$PROBE"
EOF
cat > "$T/tests/b.test.sh" <<'EOF'
printf 'b|%s|%s|%s\n' "$HOME" "$XDG_CONFIG_HOME" "$TMPDIR" >> "$PROBE"
exit 3
EOF
cat > "$T/tests/c.test.sh" <<'EOF'
# The runner's stdin carries data: a test must see EOF, not read it.
if read -r _; then exit 1; fi
EOF
cat > "$T/tests/d.test.js" <<'EOF'
process.exit(1);
EOF
cat > "$T/tests/e.test.js" <<'EOF'
const os = require('os');
require('fs').appendFileSync(process.env.PROBE, `e|${os.homedir()}|${process.env.XDG_CONFIG_HOME}|${os.tmpdir()}\n`);
EOF
printf 'exit 0\n' > "$T/tests/validate-sync.sh"
# Not a test file: must not run.
printf 'echo ran >> "$PROBE.helper"\n' > "$T/tests/helper.sh"

PROBE="$TMP/probe" TMPDIR="$TMP/base" GITHUB_OUTPUT="$TMP/output" CODEX_HOME="$TMP/real-codex-home" \
  bash "$T/scripts/run-tests.sh" > "$TMP/log" 2>&1 <<< "data on stdin"
rc=$?

echo "[1/3] every test runs, failures are named"
check "exit 1 when a test fails" "$([ "$rc" -eq 1 ] && echo 1 || echo 0)"
check "summary counts 5 passed, 2 failed" "$(grep -qx 'Tests: 5 passed, 2 failed' "$TMP/log" && echo 1 || echo 0)"
check "scripts/test-*.sh run, before tests/" "$(grep '^==> ' "$TMP/log" | head -1 | grep -qx '==> scripts/test-fake.sh' && echo 1 || echo 0)"
check "tests run with no CODEX_HOME" "$(grep -qx 'codex_home=unset' "$TMP/probe" && echo 1 || echo 0)"
check "GITHUB_OUTPUT names both failures" "$(grep -qx 'failed=tests/b.test.sh tests/d.test.js' "$TMP/output" && echo 1 || echo 0)"
check "a test after a failure still ran (e.test.js)" "$(grep -q '^e|' "$TMP/probe" && echo 1 || echo 0)"
check "tests see EOF on stdin (c.test.sh passed)" "$(grep -q 'FAIL  tests/c.test.sh' "$TMP/log" && echo 0 || echo 1)"
check "a non-test file is not run" "$([ ! -e "$TMP/probe.helper" ] && echo 1 || echo 0)"

echo "[2/3] each test gets its own throwaway HOME, XDG_CONFIG_HOME and TMPDIR"
sandboxes=""
for name in a b e; do
  IFS='|' read -r _ home config tmp < <(grep "^$name|" "$TMP/probe")
  box="${home%/home}"
  check "$name: HOME, XDG_CONFIG_HOME and TMPDIR share one fresh sandbox" \
    "$([ "${box%/run-tests.*}" = "$TMP/base" ] && [ "$config" = "$box/config" ] && [ "$tmp" = "$box/tmp" ] && echo 1 || echo 0)"
  check "$name: the sandbox is removed after the test" "$([ ! -e "$box" ] && echo 1 || echo 0)"
  sandboxes="$sandboxes $box"
done
check "no two tests share a sandbox" "$([ "$(echo $sandboxes | tr ' ' '\n' | sort -u | wc -l | tr -d ' ')" = 3 ] && echo 1 || echo 0)"

echo "[3/3] a tree without tests fails"
E="$TMP/empty"
mkdir -p "$E/scripts" "$E/tests"
cp "$REPO/scripts/run-tests.sh" "$E/scripts/run-tests.sh"
TMPDIR="$TMP/base" bash "$E/scripts/run-tests.sh" > "$TMP/empty.log" 2>&1 < /dev/null
erc=$?
check "no tests ran -> exit 1" "$([ "$erc" -eq 1 ] && grep -q 'No tests ran.' "$TMP/empty.log" && echo 1 || echo 0)"

if [ "$fail" -eq 0 ]; then
  echo "ALL PASSED"
else
  echo "FAILED"
  sed 's/^/    /' "$TMP/log"
fi
exit "$fail"
