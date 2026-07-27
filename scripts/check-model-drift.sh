#!/usr/bin/env bash
#
# check-model-drift.sh — fail if any stale (previous-generation) model ID
# is still referenced in repo-owned files.
#
# Current generation (do NOT flag): gpt-5.6, gpt-5.6-terra, gpt-5.6-luna.
#
# To roll forward on the next model generation, update OLD_MODEL_PATTERN and
# (if a migration file legitimately references an old ID) EXCLUDE_PATHS.
#
# Excluded by design:
#   - upstream/                    : vendored third-party submodules, not ours to police.
#   - .git/                        : object store.
#   - scripts/model-tiers.sh       : single source of truth for model tiers; holds
#                                    the legacy-model normalization mapping (old IDs
#                                    gpt-5.4, gpt-5.3-codex-spark -> current tier)
#                                    that install.sh and md-to-toml.sh source.
#   - scripts/check-model-drift.sh : this file. Its own OLD_MODEL_PATTERN default
#                                    literally contains the old IDs it hunts for
#                                    (e.g. "codex-spark"), so it always self-matches
#                                    unless excluded.

set -uo pipefail

# Previous-generation model IDs. Overridable via env for local testing; CI
# (smoke.yml) calls this script with no override, so this default is the
# single source of truth — do not duplicate it elsewhere.
OLD_MODEL_PATTERN="${OLD_MODEL_PATTERN:-gpt-5\.[0-5]([.-]|$| )|gpt-4|gpt-3|\bo1\b|\bo3\b|\bo4-mini\b|codex-spark}"

# Path fragments to exclude from the scan (grep -E, matched against file path).
EXCLUDE_PATHS="${EXCLUDE_PATHS:-(^|/)upstream/|(^|/)\.git/|(^|/)scripts/model-tiers\.sh$|(^|/)scripts/check-model-drift\.sh$}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

mapfile -t candidates < <(git ls-files 2>/dev/null | grep -vE "$EXCLUDE_PATHS" || true)

if [ "${#candidates[@]}" -eq 0 ]; then
  echo "No candidate files to scan."
  exit 0
fi

hits=$(printf '%s\n' "${candidates[@]}" | tr '\n' '\0' \
  | xargs -0 grep -nEI "$OLD_MODEL_PATTERN" 2>/dev/null || true)

if [ -n "$hits" ]; then
  echo "FAIL: stale (previous-generation) model IDs found:"
  echo "$hits" | sed 's/^/  /'
  echo ""
  echo "Update these to the current generation (gpt-5.6 / gpt-5.6-terra / gpt-5.6-luna),"
  echo "or add a deliberate exception to EXCLUDE_PATHS in scripts/check-model-drift.sh."
  exit 1
fi

echo "OK: no stale model IDs in ${#candidates[@]} scanned files."
