#!/usr/bin/env bash
# Regression test: install.sh's manifest cleanup never deletes what the user
# approved through the learning loop (~/.codex/skills/learned-*,
# ~/.codex/learned-rules/), even when a manifest lists those paths, while the
# managed entries next to them are still removed.
#
# `bash tests/learned-survives-install.test.sh`
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Extract remove_manifest_paths() straight out of install.sh (rather than
# reimplementing it here) so this test tracks the real function.
FUNC_SRC="$(sed -n '/^remove_manifest_paths() {/,/^}/p' "$INSTALL_SH")"
if [ -z "$FUNC_SRC" ]; then
  echo "FAIL: could not extract remove_manifest_paths() from install.sh" >&2
  exit 1
fi
eval "$FUNC_SRC"
add_manifest_entry() { :; }
CATALOG_SKILL_NAMES=""

ERRORS=0
check() {
  if [ "$2" = "yes" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    ERRORS=$((ERRORS + 1))
  fi
}
exists() { [ -e "$1" ] && echo yes || echo no; }
gone() { [ -e "$1" ] && echo no || echo yes; }

CODEX_ROOT="$TMP_ROOT/.codex"
mkdir -p "$CODEX_ROOT/skills/learned-investigate-then-debugger" "$CODEX_ROOT/skills/some-managed" \
  "$CODEX_ROOT/learned-rules" "$CODEX_ROOT/hooks"
echo "---" > "$CODEX_ROOT/skills/learned-investigate-then-debugger/SKILL.md"
echo "---" > "$CODEX_ROOT/skills/some-managed/SKILL.md"
echo "- Rule" > "$CODEX_ROOT/learned-rules/learned-always-alpha.md"
echo "x" > "$CODEX_ROOT/hooks/old-hook.js"
cat > "$TMP_ROOT/manifest.txt" <<'EOF'
skills/learned-investigate-then-debugger
skills/some-managed
learned-rules
learned-rules/learned-always-alpha.md
hooks/old-hook.js
EOF

remove_manifest_paths "$TMP_ROOT/manifest.txt"

check "1. learned skill survives even when the manifest lists it" "$(exists "$CODEX_ROOT/skills/learned-investigate-then-debugger/SKILL.md")"
check "2. learned rule file survives even when the manifest lists it" "$(exists "$CODEX_ROOT/learned-rules/learned-always-alpha.md")"
check "3. learned-rules directory survives when the manifest lists it" "$(exists "$CODEX_ROOT/learned-rules")"
check "4. a managed skill listed in the manifest is still removed" "$(gone "$CODEX_ROOT/skills/some-managed")"
check "5. a managed hook listed in the manifest is still removed" "$(gone "$CODEX_ROOT/hooks/old-hook.js")"

# install.sh ships the guard and the learning pieces it protects.
grep -q 'skills/learned-\*|learned-rules|learned-rules/\*) continue' "$INSTALL_SH" && r=yes || r=no
check "6. install.sh guard is present" "$r"

if [ "$ERRORS" -eq 0 ]; then
  echo "ALL PASSED"
  exit 0
fi
echo "$ERRORS FAILED"
exit 1
