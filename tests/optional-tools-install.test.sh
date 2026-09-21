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

run_numbered_tty() {
  local name="$1" answers="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  local test_term="${OPTIONAL_TEST_TERM-dumb}"
  if [ "${OPTIONAL_TEST_STTY_FAIL:-0}" = "1" ]; then
    cat > "$root/bin/stty" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$root/bin/stty"
  fi
  env -u CI TERM="$test_term" HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, os, pty, select, sys
output, answers_text, *command = sys.argv[1:]
answers = answers_text.split("|")
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
data = bytearray()
sent = 0
while True:
    ready, _, _ = select.select([fd], [], [], 30)
    if not ready:
        os.kill(pid, 9)
        with open(output, "wb") as handle:
            handle.write(data.replace(b"\r", b""))
        raise SystemExit(f"timed out waiting for installer: {output}: {data[-1000:]!r}")
    try:
        chunk = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    data.extend(chunk)
    prompts = data.count(b"Select: all / none / numbers like 1,3 [all]:")
    while sent < prompts and sent < len(answers):
        answer = answers[sent]
        os.write(fd, b"\x04" if answer == "<EOF>" else (answer + "\n").encode())
        sent += 1
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
if not sent:
    raise SystemExit("installer did not prompt")
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" "$answers" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

run_checkbox_tty() {
  local name="$1" keys="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  if [ "${OPTIONAL_TEST_TPUT_FAIL:-0}" = "1" ]; then
    cat > "$root/bin/tput" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$root/bin/tput"
  fi
  env -u CI TERM=xterm-256color HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, fcntl, os, pty, select, struct, sys, termios, time
output, keys_text, *command = sys.argv[1:]
keys = keys_text.split(",") if keys_text else []
encoded = {
    "enter": b"\r", "space": b" ", "a": b"a", "n": b"n",
    "j": b"j", "k": b"k", "eof": b"\x04",
}
header = b"Select companion tools  (\xe2\x86\x91\xe2\x86\x93 move \xc2\xb7 space toggle \xc2\xb7 a all \xc2\xb7 n none \xc2\xb7 enter confirm)"
last_row = b"codeburn \xe2\x80\x94 local token and cost dashboard for agent sessions."
pid, fd = pty.fork()
if pid == 0:
    os.write(1, b"\x1b[24;1H")
    os.execvp(command[0], command)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
data = bytearray()
sent = False

def wait_for_redraw(previous_count, label):
    started = time.monotonic()
    while data.count(last_row) < previous_count + 1:
        remaining = 1.0 - (time.monotonic() - started)
        if remaining <= 0:
            os.kill(pid, 9)
            raise SystemExit(f"{label} did not redraw the selector within one second")
        ready, _, _ = select.select([fd], [], [], remaining)
        if not ready:
            continue
        chunk = os.read(fd, 4096)
        if not chunk:
            raise SystemExit(f"selector closed while handling {label}")
        data.extend(chunk)
    return time.monotonic() - started

while True:
    ready, _, _ = select.select([fd], [], [], 30)
    if not ready:
        os.kill(pid, 9)
        with open(output, "wb") as handle:
            handle.write(data.replace(b"\r", b""))
        raise SystemExit(f"timed out waiting for installer: {output}: {data[-1000:]!r}")
    try:
        chunk = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    data.extend(chunk)
    if not sent and b"Select: all / none / numbers like 1,3 [all]:" in data:
        os.kill(pid, 9)
        with open(output, "wb") as handle:
            handle.write(data.replace(b"\r", b""))
        raise SystemExit("numbered selector shown instead of checkbox selector")
    if not sent and header in data:
        for key in keys:
            if key == "pause":
                time.sleep(0.25)
                continue
            redraws = data.count(header)
            if key in ("up", "down"):
                os.write(fd, b"\x1b")
                time.sleep(0.005)
                os.write(fd, b"[A" if key == "up" else b"[B")
            elif key == "escape":
                os.write(fd, b"\x1b")
                elapsed = wait_for_redraw(redraws, "lone Escape")
                with open(output + ".escape-seconds", "w") as handle:
                    handle.write(f"{elapsed:.6f}\n")
            else:
                if key in ("enter", "eof"):
                    with open(output + ".selector", "wb") as handle:
                        handle.write(data)
                os.write(fd, encoded[key])
            if key in ("up", "down", "space", "a", "n", "j", "k"):
                wait_for_redraw(redraws, key)
            time.sleep(0.05)
        sent = True
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
if not sent:
    raise SystemExit("installer did not show checkbox selector")
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" "$keys" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

run_checkbox_interrupt() {
  local name="$1"
  make_case "$name"
  local root="$TEST_ROOT/$name"
  cat > "$root/bin/tput" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  civis) printf '<cursor-hide>' ;;
  cnorm) printf '<cursor-show>' ;;
esac
EOF
  chmod +x "$root/bin/tput"
  env -u CI TERM=xterm-256color HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, os, pty, select, signal, sys, termios
output, *command = sys.argv[1:]
header = b"Select companion tools"
pid, fd = pty.fork()
if pid == 0:
    baseline = "kill -STOP $$; exec \"$@\""
    os.execvp("bash", ["bash", "-c", baseline, "selector-baseline"] + command)
os.waitpid(pid, os.WUNTRACED)
before = termios.tcgetattr(fd)
os.kill(pid, signal.SIGCONT)
data = bytearray()
signaled = False
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
    if not signaled and header in data:
        os.kill(pid, signal.SIGINT)
        signaled = True
_, status = os.waitpid(pid, 0)
after = termios.tcgetattr(fd)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
if not signaled:
    raise SystemExit("installer did not show checkbox selector")
if before != after:
    raise SystemExit(f"terminal attributes were not restored after SIGINT: before={before!r} after={after!r}")
if os.waitstatus_to_exitcode(status) != 130:
    raise SystemExit(f"unexpected SIGINT exit: {os.waitstatus_to_exitcode(status)}")
' "$root/output" bash "$REPO_ROOT/install.sh" "${install_args[@]}"
}

run_tty_no_prompt() {
  local name="$1" ci_mode="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  local -a env_prefix=(env -u CI)
  if [ "$ci_mode" = present ]; then
    env_prefix=(env CI=1)
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
    if (b"Select: all / none / numbers like 1,3 [all]:" in data or
            b"Select companion tools" in data):
        os.kill(pid, 9)
        raise SystemExit("installer prompted despite automation flag")
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

run_script_pipe() {
  local name="$1" answer="$2"
  shift 2
  if [ "$(uname -s)" != "Darwin" ]; then
    run_numbered_tty "$name" "$answer" "$@"
    return
  fi
  make_case "$name"
  local root="$TEST_ROOT/$name"
  # Keep the producer open after writing the selection. On macOS, closing the
  # pipe immediately can deliver EOF through script(1) before Bash reads it.
  { printf '%s\n' "$answer"; sleep 2; } | \
    env -u CI TERM=dumb HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
      OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
      script -q /dev/null bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@" \
      > "$root/output" 2>&1
  tr -d '\r' < "$root/output" > "$root/output.clean"
  mv "$root/output.clean" "$root/output"
}

assert_common_install() {
  local root="$TEST_ROOT/$1"
  test -f "$root/home/.codex/AGENTS.md"
  test -f "$root/home/.codex/agents/boss.toml"
  test -f "$root/home/.codex/skills/archify/SKILL.md"
  test -f "$root/home/.codex/hooks.json"
  test ! -e "$root/home/.codex/auth.json"
}

has_selection() {
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}

assert_tools_selection() {
  local name="$1" selected="$2" root="$TEST_ROOT/$1" tool installing="" skipping="" summary
  for tool in serena headroom codeburn; do
    if has_selection "$selected" "$tool"; then
      [ -z "$installing" ] && installing="$tool" || installing="$installing, $tool"
      case "$tool" in
        serena)
          grep -q 'uv tool install --python 3.13 serena-agent==1.7.0' "$root/calls.log"
          grep -q '^\[mcp_servers\.serena\]' "$root/home/.codex/config.toml"
          grep -q 'localhost:24282/dashboard/index.html' "$root/output"
          ;;
        headroom)
          grep -q 'uv tool install --python 3.13 headroom-ai\[all\]==0.37.0' "$root/calls.log"
          grep -q '^\[mcp_servers\.headroom\]' "$root/home/.codex/config.toml"
          grep -q '127.0.0.1:8787/stats' "$root/output"
          ;;
        codeburn)
          grep -q 'npm i -g codeburn@0.9.23' "$root/calls.log"
          grep -q '127.0.0.1:4747/' "$root/output"
          ;;
      esac
      ! grep -q "^  ${tool}:.*SKIPPED" "$root/output"
    else
      [ -z "$skipping" ] && skipping="$tool" || skipping="$skipping, $tool"
      case "$tool" in
        serena)
          ! grep -q 'serena-agent==1.7.0' "$root/calls.log"
          ! grep -q '^\[mcp_servers\.serena\]' "$root/home/.codex/config.toml"
          ! grep -q 'localhost:24282/dashboard/index.html' "$root/output"
          ;;
        headroom)
          ! grep -q 'headroom-ai' "$root/calls.log"
          ! grep -q '^\[mcp_servers\.headroom\]' "$root/home/.codex/config.toml"
          ! grep -q '127.0.0.1:8787/stats' "$root/output"
          ;;
        codeburn)
          ! grep -q 'codeburn@0.9.23' "$root/calls.log"
          ! grep -q '127.0.0.1:4747/' "$root/output"
          ;;
      esac
      grep -q "^  ${tool}:.*SKIPPED (not selected)$" "$root/output"
    fi
  done
  [ -n "$installing" ] || installing=none
  [ -n "$skipping" ] || skipping=none
  summary="Companion tools: installing $installing; skipping $skipping"
  python3 - "$summary" "$root/output" <<'PY'
from pathlib import Path
import re
import sys

expected, output = sys.argv[1:]
visible = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[78]", "", Path(output).read_text())
summaries = re.findall(r"Companion tools: installing [a-z, ]+; skipping [a-z, ]+", visible)
assert summaries == [expected], (expected, summaries)
PY
  assert_common_install "$name"
}

assert_checkbox_ui() {
  local output="$TEST_ROOT/$1/output"
  grep -Fq 'Select companion tools  (↑↓ move · space toggle · a all · n none · enter confirm)' "$output"
  grep -Fq '[x] serena — symbol-level code navigation and editing over MCP.' "$output"
  grep -Fq '[x] headroom — compresses large tool output and retrieves it on demand.' "$output"
  grep -Fq '[x] codeburn — local token and cost dashboard for agent sessions.' "$output"
}

# The production change these cases catch is a selector that renders but maps
# navigation or toggles to the wrong tool. Every case runs the real installer
# in an isolated PTY and asserts the resulting installs and MCP configuration.
run_checkbox_tty checkbox_enter enter
assert_tools_selection checkbox_enter serena,headroom,codeburn
assert_checkbox_ui checkbox_enter

run_checkbox_tty checkbox_serena_off space,enter
assert_tools_selection checkbox_serena_off headroom,codeburn
python3 - "$TEST_ROOT/checkbox_serena_off/output" "$TEST_ROOT/checkbox_serena_off/output.selector" <<'PY'
from pathlib import Path
import sys
data = Path(sys.argv[1]).read_bytes()
assert b"\x1b7" in data and b"\x1b8" in data, "selector did not redraw from its saved anchor"
assert b"\x1b[4A" not in data, "selector used a wrap-unsafe fixed-row redraw"

# Replay the selector bytes on the same 80x24 geometry used by the PTY. This
# catches a saved cursor at the bottom edge, where terminal scrolling can make
# a later restore duplicate wrapped menu rows instead of updating them.
stream = Path(sys.argv[2]).read_bytes().decode("utf-8", errors="replace")
rows, columns = 24, 80
screen = [[" "] * columns for _ in range(rows)]
row = column = 0
saved = (0, 0)

def advance_row():
    global row
    row += 1
    if row >= rows:
        screen.pop(0)
        screen.append([" "] * columns)
        row = rows - 1

i = 0
while i < len(stream):
    character = stream[i]
    if character == "\x1b":
        if i + 1 < len(stream) and stream[i + 1] == "7":
            saved = (row, column); i += 2; continue
        if i + 1 < len(stream) and stream[i + 1] == "8":
            row, column = saved; i += 2; continue
        if i + 1 < len(stream) and stream[i + 1] == "[":
            end = i + 2
            while end < len(stream) and not ("@" <= stream[end] <= "~"):
                end += 1
            sequence = stream[i + 2:end]
            final = stream[end] if end < len(stream) else ""
            if final in ("H", "f"):
                parts = sequence.split(";")
                row = max(0, min(rows - 1, int(parts[0] or "1") - 1))
                column = max(0, min(columns - 1, int(parts[1] or "1") - 1 if len(parts) > 1 else 0))
            elif final == "A":
                row = max(0, row - int(sequence or "1"))
            elif final == "K" and sequence in ("", "0", "2"):
                screen[row] = [" "] * columns
                if sequence == "2":
                    column = 0
            i = end + 1
            continue
    if character == "\r":
        column = 0
    elif character == "\n":
        advance_row()
    else:
        if column >= columns:
            column = 0
            advance_row()
        screen[row][column] = character
        column += 1
    i += 1

visible = "\n".join("".join(line) for line in screen)
assert visible.count("Select companion tools") == 1, visible
assert visible.count("serena — symbol-level") == 1, visible
assert "> [ ] serena — symbol-level" in visible, visible
PY

run_checkbox_tty checkbox_headroom_off down,space,enter
assert_tools_selection checkbox_headroom_off serena,codeburn

run_checkbox_tty checkbox_codeburn_off down,down,space,enter
assert_tools_selection checkbox_codeburn_off serena,headroom

run_checkbox_tty checkbox_none n,enter
assert_tools_selection checkbox_none ''

run_checkbox_tty checkbox_none_all n,a,enter
assert_tools_selection checkbox_none_all serena,headroom,codeburn

run_checkbox_tty checkbox_down_clamped down,down,down,down,space,enter
assert_tools_selection checkbox_down_clamped serena,headroom

run_checkbox_tty checkbox_up_clamped up,up,space,enter
assert_tools_selection checkbox_up_clamped headroom,codeburn

run_checkbox_tty checkbox_jk j,j,k,space,enter
assert_tools_selection checkbox_jk serena,codeburn

run_checkbox_tty checkbox_lone_escape escape,enter
assert_tools_selection checkbox_lone_escape serena,headroom,codeburn
python3 - "$TEST_ROOT/checkbox_lone_escape/output.escape-seconds" <<'PY' || { echo 'FAIL: lone Escape blocked checkbox selector' >&2; exit 1; }
from pathlib import Path
import sys
raise SystemExit(0 if float(Path(sys.argv[1]).read_text()) < 1 else 1)
PY

run_checkbox_tty checkbox_eof eof
assert_tools_selection checkbox_eof serena,headroom,codeburn

OPTIONAL_TEST_TPUT_FAIL=1 run_checkbox_tty checkbox_tput_failure enter
assert_tools_selection checkbox_tput_failure serena,headroom,codeburn

run_checkbox_interrupt checkbox_sigint
grep -Fq '<cursor-hide>' "$TEST_ROOT/checkbox_sigint/output"
grep -Fq '<cursor-show>' "$TEST_ROOT/checkbox_sigint/output"

# TERM=dumb, an empty TERM, or an unusable stty retains the original numbered
# selector and its full input grammar.
run_numbered_tty interactive_enter ''
assert_tools_selection interactive_enter serena,headroom,codeburn

run_numbered_tty interactive_all all
assert_tools_selection interactive_all serena,headroom,codeburn

run_numbered_tty interactive_yes yes
assert_tools_selection interactive_yes serena,headroom,codeburn

run_numbered_tty interactive_none none
assert_tools_selection interactive_none ''

run_numbered_tty interactive_no n
assert_tools_selection interactive_no ''

run_script_pipe headroom_only 2
assert_tools_selection headroom_only headroom

run_numbered_tty serena_only 1
assert_tools_selection serena_only serena

run_numbered_tty codeburn_only 3
assert_tools_selection codeburn_only codeburn
! grep -q '^uv ' "$TEST_ROOT/codeburn_only/calls.log"

run_numbered_tty serena_codeburn '1,3'
assert_tools_selection serena_codeburn serena,codeburn

run_numbered_tty names 'headroom codeburn'
assert_tools_selection names headroom,codeburn

run_numbered_tty invalid_retry 'bogus|2'
assert_tools_selection invalid_retry headroom
grep -q '^Invalid selection. Choose all, none, or any of: 1,2,3,serena,headroom,codeburn.$' "$TEST_ROOT/invalid_retry/output"

run_numbered_tty invalid_fallback 'bogus|bad|still-bad'
assert_tools_selection invalid_fallback serena,headroom,codeburn
grep -q '^Too many invalid selections; using all optional tools.$' "$TEST_ROOT/invalid_fallback/output"

run_numbered_tty interactive_eof '<EOF>'
assert_tools_selection interactive_eof serena,headroom,codeburn

OPTIONAL_TEST_TERM= run_numbered_tty term_empty 2
assert_tools_selection term_empty headroom

OPTIONAL_TEST_TERM=xterm-256color OPTIONAL_TEST_STTY_FAIL=1 run_numbered_tty stty_failure 3
assert_tools_selection stty_failure codeburn

run_plain non_tty_default
assert_tools_selection non_tty_default serena,headroom,codeburn
! grep -q 'Select: all / none' "$TEST_ROOT/non_tty_default/output"
! grep -q 'Select companion tools' "$TEST_ROOT/non_tty_default/output"

run_tty_no_prompt assume_yes unset --yes
assert_tools_selection assume_yes serena,headroom,codeburn

run_tty_no_prompt flag_headroom unset --tools=headroom
assert_tools_selection flag_headroom headroom

run_tty_no_prompt flag_mix unset --tools=1,3
assert_tools_selection flag_mix serena,codeburn

make_case flag_bogus
if env -u CI HOME="$TEST_ROOT/flag_bogus/home" PATH="$TEST_ROOT/flag_bogus/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/flag_bogus/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" --tools=bogus \
    </dev/null > "$TEST_ROOT/flag_bogus/output" 2>&1; then
  echo 'FAIL: invalid --tools selection succeeded' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: bogus$' "$TEST_ROOT/flag_bogus/output"

make_case flag_glob
if env -u CI HOME="$TEST_ROOT/flag_glob/home" PATH="$TEST_ROOT/flag_glob/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/flag_glob/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" '--tools=*' \
    </dev/null > "$TEST_ROOT/flag_glob/output" 2>&1; then
  echo 'FAIL: glob-like --tools selection succeeded' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: \*$' "$TEST_ROOT/flag_glob/output"

make_case flag_multiline
if env -u CI HOME="$TEST_ROOT/flag_multiline/home" PATH="$TEST_ROOT/flag_multiline/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/flag_multiline/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" $'--tools=serena\nbogus' \
    </dev/null > "$TEST_ROOT/flag_multiline/output" 2>&1; then
  echo 'FAIL: multiline --tools selection ignored an invalid token' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: serena$' "$TEST_ROOT/flag_multiline/output"
grep -q '^bogus$' "$TEST_ROOT/flag_multiline/output"

make_case invalid_skip_mix
if env -u CI HOME="$TEST_ROOT/invalid_skip_mix/home" PATH="$TEST_ROOT/invalid_skip_mix/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/invalid_skip_mix/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" --skip-tools --tools=bogus \
    </dev/null > "$TEST_ROOT/invalid_skip_mix/output" 2>&1; then
  echo 'FAIL: --skip-tools concealed an invalid --tools selection' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: bogus$' "$TEST_ROOT/invalid_skip_mix/output"

run_plain skip_wins --tools=headroom --yes --skip-tools
assert_tools_selection skip_wins ''

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
assert_tools_selection ci_present serena,headroom,codeburn
! grep -q 'Select: all / none' "$TEST_ROOT/ci_present/output"
! grep -q 'Select companion tools' "$TEST_ROOT/ci_present/output"

echo "Optional tools installer test passed"
