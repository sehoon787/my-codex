#!/usr/bin/env bash
#
# scan-upstream-diff.sh — security review gate for automated upstream syncs.
#
# Given the currently-staged submodule pointer changes under upstream/, this
# script diffs each bumped submodule (old-sha..new-sha), inspects the ADDED
# lines introduced by the sync, and flags suspicious patterns. It is a
# soft gate: it never blocks. On any hit it writes a markdown report and
# signals "flagged" so the caller can skip auto-merge and request human review.
#
# Outputs:
#   - Markdown report to $SCAN_REPORT (default: scan-report.md)
#   - flagged=true|false to $GITHUB_OUTPUT when running under GitHub Actions
#   - Always exits 0 unless the script itself errors before scanning.
#
# Rationale: false positives are expected. Flagging (not blocking) keeps the
# sync pipeline alive while surfacing risky changes for a human to eyeball.

set -uo pipefail

REPORT="${SCAN_REPORT:-scan-report.md}"
: > "$REPORT"
flagged=0

emit() { printf '%s\n' "$1" >> "$REPORT"; }

emit "## Upstream sync security scan"
emit ""

# Collect staged submodule paths under upstream/.
mapfile -t subs < <(git diff --cached --name-only -- upstream/ 2>/dev/null || true)

if [ "${#subs[@]}" -eq 0 ]; then
  emit "_No staged submodule changes under upstream/. Nothing to scan._"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "flagged=false" >> "$GITHUB_OUTPUT"; fi
  exit 0
fi

# Suspicious pattern groups. Each entry: "Label|extended-regex".
# Kept deliberately broad — this is a flag, not a block.
PATTERNS=(
  "Network exfil (curl/wget to URL)|(curl|wget)([[:space:]]|.)*https?://"
  "Network exfil (fetch to URL)|fetch\\(['\"\`]?https?://"
  "base64 decode piped to shell|base64[[:space:]]+(-d|--decode|-D)([[:space:]]|.)*(bash|sh|zsh|node|python|eval)"
  "base64 decode + eval (JS)|(atob|Buffer\\.from)\\(([[:space:]]|.)*(eval|Function)"
  "Dynamic shell eval|(^|[[:space:];&|])eval[[:space:]]"
  "bash -c with variable expansion|bash[[:space:]]+-c([[:space:]]|.)*\\\$"
  "Destructive rm of HOME/root|rm[[:space:]]+-[a-zA-Z]*[rf][a-zA-Z]*[[:space:]]+(\\\$HOME|~|/([[:space:]]|\$|\\*))"
  "SSH key / credential access|(\\.ssh/|id_rsa|id_ed25519|/\\.aws/|credentials|\\.env\\b|/\\.netrc)"
  "Token/secret assignment or read|(api[_-]?key|secret|token|password)[[:space:]]*[:=]"
  "Writes to settings.json / config.toml|>[[:space:]]*[^[:space:]]*(settings\\.json|config\\.toml)"
)

for sub in "${subs[@]}"; do
  [ -d "$sub" ] || continue

  # Old/new gitlink shas from the staged diff.
  raw=$(git diff --cached -- "$sub" 2>/dev/null)
  old=$(printf '%s\n' "$raw" | awk '/^-Subproject commit/{print $3; exit}')
  new=$(printf '%s\n' "$raw" | awk '/^\+Subproject commit/{print $3; exit}')
  # Fallback for newly added submodule (no old sha): use empty tree.
  if [ -z "$old" ]; then old=$(git -C "$sub" hash-object -t tree /dev/null 2>/dev/null || echo 4b825dc642cb6eb9a060e54bf8d69288fbee4904); fi
  if [ -z "$new" ]; then new=$(git -C "$sub" rev-parse HEAD 2>/dev/null || echo HEAD); fi

  emit "### \`$sub\`  (\`${old:0:12}\` → \`${new:0:12}\`)"
  emit ""

  # Ensure both endpoints are present locally; ignore fetch failures.
  git -C "$sub" cat-file -e "$old^{commit}" 2>/dev/null || git -C "$sub" fetch --quiet --depth=200 origin "$old" 2>/dev/null || true

  # Changed / new files in this bump.
  mapfile -t files < <(git -C "$sub" diff --name-only "$old" "$new" 2>/dev/null || true)
  if [ "${#files[@]}" -eq 0 ]; then
    emit "_No file-level changes resolved (shallow history?). Pointer moved but diff unavailable._"
    emit ""
    continue
  fi

  sub_flag=0

  # Newly added executable or binary files.
  while IFS=$'\t' read -r status path; do
    [ "$status" = "A" ] || continue
    mode=$(git -C "$sub" ls-tree "$new" -- "$path" 2>/dev/null | awk '{print $1}')
    is_bin=$(git -C "$sub" diff --numstat "$old" "$new" -- "$path" 2>/dev/null | awk '{print $1}')
    if [ "$mode" = "100755" ]; then
      emit "- FLAG **new executable file**: \`$path\` (mode $mode)"
      sub_flag=1
    elif [ "$is_bin" = "-" ]; then
      emit "- FLAG **new binary file**: \`$path\`"
      sub_flag=1
    fi
  done < <(git -C "$sub" diff --name-status --diff-filter=A "$old" "$new" 2>/dev/null || true)

  # Pattern scan over ADDED lines only.
  for f in "${files[@]}"; do
    # Extract added lines (strip leading +), skip file headers.
    added=$(git -C "$sub" diff "$old" "$new" -- "$f" 2>/dev/null \
      | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^\+//')
    [ -n "$added" ] || continue
    for entry in "${PATTERNS[@]}"; do
      label="${entry%%|*}"
      regex="${entry#*|}"
      hits=$(printf '%s\n' "$added" | grep -inE "$regex" 2>/dev/null | head -3 || true)
      if [ -n "$hits" ]; then
        emit "- FLAG **${label}** in \`$f\`:"
        while IFS= read -r line; do
          # Trim overly long lines for readability.
          emit "    - \`$(printf '%s' "$line" | cut -c1-160)\`"
        done <<< "$hits"
        sub_flag=1
      fi
    done
  done

  if [ "$sub_flag" -eq 0 ]; then
    emit "_No suspicious patterns in added lines (${#files[@]} file(s) changed)._"
  else
    flagged=1
  fi
  emit ""
done

if [ "$flagged" -eq 1 ]; then
  emit "---"
  emit ":warning: **This sync was flagged for manual review.** Auto-merge was skipped."
  emit "A maintainer should inspect the changes above and merge manually if safe."
else
  emit "---"
  emit ":white_check_mark: No suspicious patterns detected. Safe for auto-merge."
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "flagged=$([ "$flagged" -eq 1 ] && echo true || echo false)" >> "$GITHUB_OUTPUT"
fi

echo "scan complete: flagged=$flagged (report: $REPORT)"
exit 0
