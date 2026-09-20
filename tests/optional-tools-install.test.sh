#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/my-codex-optional-tools.XXXXXX")"
REAL_NODE="$(command -v node)"

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

make_case() {
  local name="$1" root bin
  root="$TEST_ROOT/$name"
  bin="$root/bin"
  mkdir -p "$root/home/.agents/skills" "$root/home/.claude/skills" "$bin"
  ln -s "$REAL_NODE" "$bin/node"

  cat > "$bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'codex %s\n' "$*" >> "${OPTIONAL_TOOLS_LOG:?}"
case "${1:-}" in
  --version) echo 'codex-test' ;;
  mcp) [ "${2:-}" = list ] && exit 0 ;;
esac
EOF
  cat > "$bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >> "${OPTIONAL_TOOLS_LOG:?}"
EOF
  cat > "$bin/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uv %s\n' "$*" >> "${OPTIONAL_TOOLS_LOG:?}"
case "$*" in
  '--version') echo 'uv 0-test' ;;
  'tool list') : ;;
esac
EOF
  cat > "$bin/curl" <<'EOF'
#!/usr/bin/env bash
echo 'FAIL: installer attempted network access' >&2
exit 97
EOF
  chmod +x "$bin/codex" "$bin/npm" "$bin/uv" "$bin/curl"
  : > "$root/calls.log"
}

install_args=(
  --skip-ecc
  --skip-omx
  --skip-gstack
  --skip-superpowers
)

run_plain() {
  local name="$1"
  shift
  make_case "$name"
  local root="$TEST_ROOT/$name"
  env -u CI HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@" \
    < /dev/null > "$root/output" 2>&1
}

run_tty() {
  local name="$1" answer="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  env -u CI HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, os, pty, select, sys
output, answer, *command = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
data = bytearray()
sent = False
while True:
    ready, _, _ = select.select([fd], [], [], 30)
    if not ready:
        os.kill(pid, 9)
        raise SystemExit("timed out waiting for installer")
    try:
        chunk = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    data.extend(chunk)
    if not sent and b"Install these optional tools? [Y/n] " in data:
        os.write(fd, (answer + "\n").encode())
        sent = True
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
if not sent:
    raise SystemExit("installer did not prompt")
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" "$answer" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

run_tty_no_prompt() {
  local name="$1" ci_mode="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  local -a env_prefix=(env -u CI)
  if [ "$ci_mode" = present ]; then
    env_prefix=(env CI=)
  fi
  "${env_prefix[@]}" HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, os, pty, select, sys
output, *command = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
data = bytearray()
while True:
    ready, _, _ = select.select([fd], [], [], 30)
    if not ready:
        os.kill(pid, 9)
        raise SystemExit("timed out waiting for installer")
    try:
        chunk = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    data.extend(chunk)
    if b"Install these optional tools? [Y/n] " in data:
        os.kill(pid, 9)
        raise SystemExit("installer prompted despite automation flag")
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

assert_common_install() {
  local root="$TEST_ROOT/$1"
  test -f "$root/home/.codex/AGENTS.md"
  test -f "$root/home/.codex/agents/boss.toml"
  test -f "$root/home/.codex/skills/archify/SKILL.md"
  test -f "$root/home/.codex/hooks.json"
  test ! -e "$root/home/.codex/auth.json"
}

assert_tools_yes() {
  local root="$TEST_ROOT/$1"
  grep -q 'npm i -g codeburn@0.9.23' "$root/calls.log"
  grep -q 'uv tool install --python 3.13 serena-agent==1.7.0' "$root/calls.log"
  grep -q 'uv tool install --python 3.13 headroom-ai\[all\]==0.37.0' "$root/calls.log"
  grep -q '^\[mcp_servers\.serena\]' "$root/home/.codex/config.toml"
  grep -q '^\[mcp_servers\.headroom\]' "$root/home/.codex/config.toml"
  assert_common_install "$1"
}

assert_tools_no() {
  local root="$TEST_ROOT/$1"
  ! grep -q 'codeburn@0.9.23' "$root/calls.log"
  ! grep -q 'serena-agent==1.7.0' "$root/calls.log"
  ! grep -q 'headroom-ai' "$root/calls.log"
  ! grep -q '^\[mcp_servers\.serena\]' "$root/home/.codex/config.toml"
  ! grep -q '^\[mcp_servers\.headroom\]' "$root/home/.codex/config.toml"
  grep -q '^  codeburn:      SKIPPED$' "$root/output"
  grep -q '^  serena:        SKIPPED$' "$root/output"
  grep -q '^  headroom:      SKIPPED$' "$root/output"
  ! grep -Eq '127\.0\.0\.1:4747|127\.0\.0\.1:8787|localhost:24282' "$root/output"
  assert_common_install "$1"
}

run_tty interactive_yes y
assert_tools_yes interactive_yes

run_tty interactive_enter ''
assert_tools_yes interactive_enter

run_tty interactive_no n
assert_tools_no interactive_no

run_plain eof_default
assert_tools_yes eof_default
! grep -q 'Install these optional tools?' "$TEST_ROOT/eof_default/output"

run_tty_no_prompt assume_yes unset --yes
assert_tools_yes assume_yes

run_plain skip_wins --yes --skip-tools
assert_tools_no skip_wins

# Declining optional tools does not delete MCP tables that the user already
# owns; it only suppresses this installer's managed writes.
cat >> "$TEST_ROOT/skip_wins/home/.codex/config.toml" <<'EOF'

[mcp_servers.serena]
command = "custom-serena"

[mcp_servers.headroom]
command = "custom-headroom"
EOF
run_root="$TEST_ROOT/skip_wins"
HOME="$run_root/home" PATH="$run_root/bin:/usr/bin:/bin" \
  OPTIONAL_TOOLS_LOG="$run_root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
  bash "$REPO_ROOT/install.sh" "${install_args[@]}" --skip-tools \
  < /dev/null > "$run_root/reinstall-output" 2>&1
grep -q '^command = "custom-serena"$' "$run_root/home/.codex/config.toml"
grep -q '^command = "custom-headroom"$' "$run_root/home/.codex/config.toml"

run_tty_no_prompt ci_present present
assert_tools_yes ci_present
! grep -q 'Install these optional tools?' "$TEST_ROOT/ci_present/output"

echo "Optional tools installer test passed"
