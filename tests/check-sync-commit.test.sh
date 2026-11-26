#!/usr/bin/env bash
#
# check-sync-commit.test.sh — scripts/check-sync-commit.sh lets a real sync
# commit through and refuses every other change.
# `bash tests/check-sync-commit.test.sh`
#
# The publish job in update-upstream.yml runs that check before it pushes a
# commit that reached it through a job that ran upstream code. Builds a
# throwaway repo shaped like this one (no network) and checks one commit per
# case, including the whitespace-named paths that got past the first version
# of the check: ' ', a '  ' symlink, 'README.md ', 'README.md<TAB>' and
# docs/i18n/README.x/page.md.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$REPO/scripts/check-sync-commit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT
W="$TMP/repo"

# git with no system or user config, always on the throwaway repo.
tgit() {
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid \
  GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid \
    git -C "$W" -c init.defaultBranch=main -c commit.gpgsign=false "$@"
}

fail=0
check() {
  if [ "$2" = "1" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    fail=1
  fi
}

# The check's exit status for its arguments, run against the throwaway repo.
run_check() {
  GIT_DIR="$W/.git" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    bash "$CHECK" "$@" > "$TMP/out" 2>&1
  echo "$?"
}
allowed() { [ "$(run_check "$1" "$2")" = 0 ] && echo 1 || echo 0; }
refused() { [ "$(run_check "$1" "$2")" = 1 ] && echo 1 || echo 0; }

PIN_A=1111111111111111111111111111111111111111
PIN_B=2222222222222222222222222222222222222222

# The base: two submodule pointers, SOURCES.json, the READMEs and install.sh.
mkdir -p "$W/upstream" "$W/docs/i18n"
tgit init -q
echo '{}' > "$W/upstream/SOURCES.json"
echo readme > "$W/README.md"
echo ko > "$W/docs/i18n/README.ko.md"
echo install > "$W/install.sh"
tgit add -A
tgit update-index --add --cacheinfo "160000,$PIN_A,upstream/gstack"
tgit update-index --add --cacheinfo "160000,$PIN_A,upstream/ecc"
tgit commit -qm base
BASE="$(tgit rev-parse HEAD)"

# Start a case from the base commit with a clean tree.
from_base() { tgit checkout -q -f -B "$1" "$BASE" && tgit clean -qfdx; }
commit_case() { tgit commit -qm "$1" && tgit rev-parse HEAD; }

echo "[1/3] what a sync changes is allowed"
from_base sync
tgit update-index --cacheinfo "160000,$PIN_B,upstream/gstack"
echo '{"pins":1}' > "$W/upstream/SOURCES.json"
echo readme2 > "$W/README.md"
echo ko2 > "$W/docs/i18n/README.ko.md"
tgit add upstream/SOURCES.json README.md docs/i18n/README.ko.md
SYNC="$(commit_case sync)"
check "pointer bump + SOURCES.json + README.md + docs/i18n/README.ko.md" "$(allowed "$BASE" "$SYNC")"
from_base moved
echo more >> "$W/install.sh"
tgit add install.sh
MOVED="$(commit_case "main moved on")"
check "the same commit after main moved on (merge-base diff)" "$(allowed "$MOVED" "$SYNC")"

echo "[2/3] anything else is refused"
tgit checkout -q -f sync
echo evil >> "$W/install.sh"
tgit add install.sh
check "sync commit that also edits install.sh" "$(refused "$BASE" "$(commit_case install)")"

from_base space
printf 'x\n' > "$W/ "
chmod +x "$W/ "
tgit add -- " "
check "added executable named ' '" "$(refused "$BASE" "$(commit_case space)")"
check "the refused ' ' path is printed quoted" "$(grep -qF 'refused: \ ' "$TMP/out" && echo 1 || echo 0)"

from_base two-spaces
ln -s README.md "$W/  "
tgit add -- "  "
check "added symlink named '  '" "$(refused "$BASE" "$(commit_case two-spaces)")"

from_base readme-tab
printf 'x\n' > "$W/README.md"$'\t'
tgit add -- "README.md"$'\t'
check "added 'README.md<TAB>'" "$(refused "$BASE" "$(commit_case readme-tab)")"

from_base readme-space
printf 'x\n' > "$W/README.md "
tgit add -- "README.md "
check "added 'README.md '" "$(refused "$BASE" "$(commit_case readme-space)")"

from_base i18n-dir
mkdir -p "$W/docs/i18n/README.x"
printf 'x\n' > "$W/docs/i18n/README.x/page.md"
tgit add docs/i18n/README.x/page.md
check "added docs/i18n/README.x/page.md" "$(refused "$BASE" "$(commit_case i18n-dir)")"

from_base sources-mode
tgit update-index --chmod=+x upstream/SOURCES.json
check "upstream/SOURCES.json mode 100644 -> 100755" "$(refused "$BASE" "$(commit_case sources-mode)")"

from_base new-file
printf 'x\n' > "$W/upstream/evil.sh"
tgit add upstream/evil.sh
check "added upstream/evil.sh" "$(refused "$BASE" "$(commit_case new-file)")"

from_base new-sub
tgit update-index --add --cacheinfo "160000,$PIN_B,upstream/newsub"
check "added submodule upstream/newsub" "$(refused "$BASE" "$(commit_case new-sub)")"

from_base tree
tgit rm -q --cached upstream/gstack
mkdir -p "$W/upstream/gstack"
printf 'x\n' > "$W/upstream/gstack/setup"
tgit add upstream/gstack/setup
check "submodule pointer replaced by a tree of files" "$(refused "$BASE" "$(commit_case tree)")"

from_base readme-link
rm "$W/README.md"
ln -s install.sh "$W/README.md"
tgit add README.md
check "README.md turned into a symlink" "$(refused "$BASE" "$(commit_case readme-link)")"

from_base readme-gone
tgit rm -q README.md
check "README.md deleted" "$(refused "$BASE" "$(commit_case readme-gone)")"

from_base rename
tgit mv docs/i18n/README.ko.md docs/i18n/README.kr.md
check "docs/i18n/README.ko.md renamed" "$(refused "$BASE" "$(commit_case rename)")"

echo "[3/3] a git failure fails closed"
check "unknown commit -> exit 2" "$([ "$(run_check "$BASE" 0000000000000000000000000000000000000000)" = 2 ] && echo 1 || echo 0)"
check "one argument -> exit 2" "$([ "$(run_check "$BASE")" = 2 ] && echo 1 || echo 0)"

if [ "$fail" -eq 0 ]; then
  echo "ALL PASSED"
else
  echo "FAILED"
fi
exit "$fail"
