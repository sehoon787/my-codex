#!/usr/bin/env bash
#
# check-sync-commit.sh — refuse a sync commit that changes more than the
# upstream sync stages.
#
# The publish job in .github/workflows/update-upstream.yml runs this before it
# pushes the commit the update job made, because the test job in between runs
# upstream code. Every change from the merge base of <base> and <commit> to
# <commit> must be one of:
#   - a moved submodule pointer under upstream/ (mode 160000 on both sides)
#   - a modified upstream/SOURCES.json, README.md or docs/i18n/README.<lang>.md
#     (a regular file, mode 100644 on both sides)
# Anything else is refused: an added, deleted, renamed or type-changed path,
# a mode change, a symlink, any other file. Paths are read from
# `git diff --raw -z`, so whitespace or quoting in a name cannot disguise one.
#
# Exit 0 = every change is allowed; 1 = at least one path refused (each one
# printed, shell-quoted); 2 = usage error or git failure.
# `bash scripts/check-sync-commit.sh <base> <commit>`, from the repo root.

set -uo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: check-sync-commit.sh <base> <commit>" >&2
  exit 2
fi

diff_file="$(mktemp "${TMPDIR:-/tmp}/check-sync-commit.XXXXXX")" || exit 2
trap 'rm -f "${diff_file:?}"' EXIT
if ! git diff --raw -z --no-renames "$1...$2" > "$diff_file"; then
  echo "check-sync-commit: git diff $1...$2 failed" >&2
  exit 2
fi

refused=0
# Each record is ":<old mode> <new mode> <old sha> <new sha> <status>" NUL <path> NUL.
while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
  read -r old_mode new_mode _ _ status <<< "$meta"
  allowed=0
  if [ "$status" = M ]; then
    case "$old_mode $new_mode" in
      ':160000 160000')
        [[ $path =~ ^upstream/[A-Za-z0-9._-]+$ ]] && allowed=1 ;;
      ':100644 100644')
        [[ $path == upstream/SOURCES.json || $path == README.md ||
           $path =~ ^docs/i18n/README\.[A-Za-z-]+\.md$ ]] && allowed=1 ;;
    esac
  fi
  if [ "$allowed" -eq 0 ]; then
    printf 'refused: %q (%s)\n' "$path" "$meta"
    refused=1
  fi
done < "$diff_file"

exit "$refused"
