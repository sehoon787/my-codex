#!/usr/bin/env bash
# Regression test for install.sh's append_agents_section() upsert.
#
# The function used to bail out on `grep -qF "$marker" && return 0`, so a
# template section that was already present in ~/.codex/AGENTS.md was never
# updated again. Observed after #94: `.my-codex-version` moved to the new
# commit while the "## Tooling (MCP + skills)" body in ~/.codex/AGENTS.md still
# held the single stale line from an older release. The function now replaces
# the marked section in place, and must do so without disturbing anything else
# in the file -- users keep their own text in that AGENTS.md.
#
# Run: `bash tests/agents-section-upsert.test.sh`
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
TEMPLATE="$REPO_ROOT/templates/codex-AGENTS.md"

HEADING="## Tooling (MCP + skills)"
MARKER="<!-- my-codex:tooling-mcp -->"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Extract append_agents_section() and its helper straight out of install.sh
# (rather than reimplementing them here) so this test tracks the real functions.
FUNC_SRC="$(sed -n \
  -e '/^legacy_agents_section_matches() {/,/^}/p' \
  -e '/^append_agents_section() {/,/^}/p' \
  "$INSTALL_SH")"
if [ -z "$FUNC_SRC" ]; then
  echo "FAIL: could not extract append_agents_section() from install.sh" >&2
  exit 1
fi
eval "$FUNC_SRC"

CODEX_ROOT="$TMP_ROOT/codex"
mkdir -p "$CODEX_ROOT"
export REPO_ROOT CODEX_ROOT

TARGET="$CODEX_ROOT/AGENTS.md"
ERRORS=0

fail() {
  echo "FAIL: $1" >&2
  ERRORS=$((ERRORS + 1))
}

# The section rule the installer implements: <heading> through the line before
# the next "## " heading (or EOF).
extract_section() {
  awk -v heading="$HEADING" '
    $0 == heading { in_section = 1; print; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$1"
}

extract_section "$TEMPLATE" > "$TMP_ROOT/template-section.md"
if [ ! -s "$TMP_ROOT/template-section.md" ]; then
  echo "FAIL: template has no '$HEADING' section" >&2
  exit 1
fi

# A user's AGENTS.md: their own text above and below a stale marked section.
write_stale_target() {
  cat > "$TARGET" <<EOF
# My own AGENTS.md

Personal note above the managed section.

$HEADING
$MARKER
- stale single line from an older my-codex release.

## My Own Section

Personal note below the managed section.
EOF
}

write_stale_target
head -4 "$TARGET" > "$TMP_ROOT/user-head.md"
sed -n '/^## My Own Section$/,$p' "$TARGET" > "$TMP_ROOT/user-tail.md"

# 1. Stale section is refreshed from the template.
LOG_1="$(append_agents_section "$HEADING" "$MARKER")"
extract_section "$TARGET" > "$TMP_ROOT/result-section.md"
if diff -u "$TMP_ROOT/template-section.md" "$TMP_ROOT/result-section.md" > "$TMP_ROOT/section.diff"; then
  echo "OK: existing section refreshed from the template"
else
  fail "existing section was not refreshed from the template"
  sed 's/^/       /' "$TMP_ROOT/section.diff" >&2
fi

case "$LOG_1" in
  *"refreshed $HEADING"*) echo "OK: update path logs a distinct line" ;;
  *) fail "update path did not log a refresh line (got: $LOG_1)" ;;
esac

# 2. The user's own text is untouched, above and below.
head -4 "$TARGET" > "$TMP_ROOT/after-head.md"
sed -n '/^## My Own Section$/,$p' "$TARGET" > "$TMP_ROOT/after-tail.md"
if diff -u "$TMP_ROOT/user-head.md" "$TMP_ROOT/after-head.md" > "$TMP_ROOT/head.diff" &&
   diff -u "$TMP_ROOT/user-tail.md" "$TMP_ROOT/after-tail.md" > "$TMP_ROOT/tail.diff"; then
  echo "OK: user text above and below survives byte-for-byte"
else
  fail "user text around the managed section was modified"
  sed 's/^/       /' "$TMP_ROOT/head.diff" "$TMP_ROOT/tail.diff" >&2
fi

# 3. Exactly one marker remains -- an upsert must never duplicate the section.
MARKER_COUNT="$(grep -cF "$MARKER" "$TARGET" | tr -d ' ')"
if [ "$MARKER_COUNT" = "1" ]; then
  echo "OK: marker count stays 1"
else
  fail "expected 1 marker, found $MARKER_COUNT"
fi

# 4. Idempotent: a second run leaves an identical file.
cp "$TARGET" "$TMP_ROOT/after-first-run.md"
append_agents_section "$HEADING" "$MARKER" > /dev/null
if diff -u "$TMP_ROOT/after-first-run.md" "$TARGET" > "$TMP_ROOT/rerun.diff"; then
  echo "OK: a second run produces an identical file"
else
  fail "a second run changed the file"
  sed 's/^/       /' "$TMP_ROOT/rerun.diff" >&2
fi

# 5. No marker yet -> the section is still appended (unchanged behavior).
cat > "$TARGET" <<'EOF'
# My own AGENTS.md

Personal note with no managed sections at all.
EOF
cp "$TARGET" "$TMP_ROOT/no-marker-before.md"
LOG_2="$(append_agents_section "$HEADING" "$MARKER")"
extract_section "$TARGET" > "$TMP_ROOT/appended-section.md"
if diff -u "$TMP_ROOT/template-section.md" "$TMP_ROOT/appended-section.md" > "$TMP_ROOT/append.diff"; then
  echo "OK: a file without the marker gets the section appended"
else
  fail "the section was not appended to a file without the marker"
  sed 's/^/       /' "$TMP_ROOT/append.diff" >&2
fi
if head -3 "$TARGET" | diff -q - "$TMP_ROOT/no-marker-before.md" > /dev/null; then
  echo "OK: append leaves the existing content in place"
else
  fail "append modified the existing content"
fi
case "$LOG_2" in
  *"appended $HEADING"*) echo "OK: append path still logs an append line" ;;
  *) fail "append path did not log an append line (got: $LOG_2)" ;;
esac

# 6. All four managed sections upsert cleanly over a full stale copy.
cp "$TEMPLATE" "$TARGET"
printf '\n## My Own Section\n\nPersonal note at the end.\n' >> "$TARGET"
cp "$TARGET" "$TMP_ROOT/full-before.md"
{
  append_agents_section "## Calibrated Response (mandatory)" "<!-- my-codex:calibrated-response -->"
  append_agents_section "## Final Report (end of the request)" "<!-- my-codex:final-report -->"
  append_agents_section "## Context Hygiene" "<!-- my-codex:context-hygiene -->"
  append_agents_section "## Tooling (MCP + skills)" "<!-- my-codex:tooling-mcp -->"
} > /dev/null
if diff -u "$TMP_ROOT/full-before.md" "$TARGET" > "$TMP_ROOT/full.diff"; then
  echo "OK: upserting all four sections over up-to-date content is a no-diff"
else
  fail "upserting all four sections changed an already up-to-date file"
  sed 's/^/       /' "$TMP_ROOT/full.diff" >&2
fi

# 7. Append-then-refresh is a no-diff. The append path emits its own separator
# blank line on top of the blank line the template section already ends with, so
# a refresh must replay the blank lines that trailed the section rather than
# collapsing them to the template's single one.
printf '# Legacy AGENTS\n\n## Something\ntext\n' > "$TARGET"
upsert_all() {
  append_agents_section "## Calibrated Response (mandatory)" "<!-- my-codex:calibrated-response -->"
  append_agents_section "## Final Report (end of the request)" "<!-- my-codex:final-report -->"
  append_agents_section "## Context Hygiene" "<!-- my-codex:context-hygiene -->"
  append_agents_section "## Tooling (MCP + skills)" "<!-- my-codex:tooling-mcp -->"
}
upsert_all > /dev/null
cp "$TARGET" "$TMP_ROOT/legacy-after-append.md"
upsert_all > /dev/null
if diff -u "$TMP_ROOT/legacy-after-append.md" "$TARGET" > "$TMP_ROOT/legacy.diff"; then
  echo "OK: refreshing freshly appended sections is a no-diff"
else
  fail "refreshing freshly appended sections changed the file"
  sed 's/^/       /' "$TMP_ROOT/legacy.diff" >&2
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "$ERRORS check(s) failed" >&2
  exit 1
fi
echo "agents-section-upsert test passed"
