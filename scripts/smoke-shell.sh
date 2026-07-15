#!/usr/bin/env bash
#
# smoke-shell.sh — syntax-check every shell script this repo ships.
#
# Runs `bash -n` (parse only, no execution) over install.sh, hooks/*.sh, and
# scripts/*.sh. Meant to run on both Ubuntu and Windows (Git Bash) so that
# platform-specific quoting/shim bugs get caught on the platform that hits them.
#
# Exit 0 = all parse; exit 1 = at least one parse error.

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

files=()
[ -f install.sh ] && files+=("install.sh")
while IFS= read -r f; do files+=("$f"); done < <(find hooks scripts -maxdepth 1 -name '*.sh' 2>/dev/null | sort)

if [ "${#files[@]}" -eq 0 ]; then
  echo "No shell scripts found to check."
  exit 0
fi

fail=0
for f in "${files[@]}"; do
  if bash -n "$f" 2>/tmp/smoke-shell-err; then
    echo "OK   $f"
  else
    echo "FAIL $f"
    sed 's/^/       /' /tmp/smoke-shell-err
    fail=1
  fi
done
rm -f /tmp/smoke-shell-err

if [ "$fail" -eq 1 ]; then
  echo "Shell smoke: at least one script failed bash -n."
  exit 1
fi
echo "Shell smoke: all ${#files[@]} shell script(s) parse cleanly."
