#!/usr/bin/env bash
#
# check-model-drift.sh — fail if any stale (previous-generation) model ID
# is still referenced in repo-owned files.
#
# Two complementary checks, because a wrong model ID fails in two directions:
#
#   1. Stale (blacklist, repo-wide)   — an ID that was real but is now previous
#      generation. Scanned across all tracked files.
#   2. Off-tier (allowlist, agents)   — an agent pinning anything other than the
#      three tiers in model-tiers.sh, including slugs that were never served.
#
# Check 2 exists because check 1 cannot catch a nonexistent ID — it only knows
# what to reject, not what to accept.
#
# Current generation (do NOT flag): the MODEL_TIER_* values in
# scripts/model-tiers.sh, sourced below rather than repeated here.
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

# `while read` rather than `mapfile`: mapfile is bash 4+, and macOS ships
# bash 3.2, so mapfile made this script impossible to run locally.
candidates=""
while IFS= read -r f; do
  candidates="$candidates$f
"
done < <(git ls-files 2>/dev/null | grep -vE "$EXCLUDE_PATHS" || true)

candidate_count=$(printf '%s' "$candidates" | grep -c . || true)
if [ "$candidate_count" -eq 0 ]; then
  echo "No candidate files to scan."
  exit 0
fi

# Tier IDs come from the single source of truth rather than being repeated here.
. "$repo_root/scripts/model-tiers.sh"

status=0

# ── Check 1: stale IDs (blacklist) ──────────────────────────────────────
hits=$(printf '%s' "$candidates" | tr '\n' '\0' \
  | xargs -0 grep -nEI "$OLD_MODEL_PATTERN" 2>/dev/null || true)

if [ -n "$hits" ]; then
  echo "FAIL: stale (previous-generation) model IDs found:"
  echo "$hits" | sed 's/^/  /'
  echo ""
  echo "Update these to the current generation ($MODEL_TIER_HIGH / $MODEL_TIER_MEDIUM / $MODEL_TIER_LOW),"
  echo "or add a deliberate exception to EXCLUDE_PATHS in scripts/check-model-drift.sh."
  status=1
fi

# ── Check 2: off-tier IDs in agent definitions (allowlist) ──────────────
#
# Check 1 only catches IDs we already know are old. It cannot catch the
# opposite failure: a value that is neither old nor real. That gap is not
# hypothetical — every agent here pinned a bare `gpt-5.6` for weeks, which the
# API never served (the 5.6 generation ships only suffixed slugs). The stale
# scan passed the whole time because the value was not *old*, just nonexistent,
# and installs only worked because normalize_agent_models() repaired it at
# runtime.
#
# Every agent model must be one of the three tiers. A hardcoded slug outside
# them is a bug even when it happens to be a real model: it bypasses
# model-tiers.sh, which is what makes rolling the generation forward a
# three-line edit.
#
# Scoped to the structured `model = "..."` field under codex-agents/ — never
# prose, so a model ID in a doc or comment cannot trip this.
off_tier=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  value=$(printf '%s' "${rest#*:}" | sed 's/^model[[:space:]]*=[[:space:]]*"//; s/".*$//')
  [ -n "$value" ] || continue
  case "$value" in
    "$MODEL_TIER_HIGH"|"$MODEL_TIER_MEDIUM"|"$MODEL_TIER_LOW") ;;
    *) off_tier="$off_tier  $file:$lineno: $value
" ;;
  esac
done < <(grep -rn '^model[[:space:]]*=' codex-agents/ 2>/dev/null || true)

if [ -n "$off_tier" ]; then
  echo "FAIL: agent model values outside the defined tiers:"
  printf '%s' "$off_tier"
  echo ""
  echo "Allowed: $MODEL_TIER_HIGH (high) / $MODEL_TIER_MEDIUM (medium) / $MODEL_TIER_LOW (low)"
  echo "Pin one of those, or change the tier in scripts/model-tiers.sh if the generation moved."
  status=1
fi

[ "$status" -eq 0 ] || exit 1

agent_models=$(grep -rc '^model[[:space:]]*=' codex-agents/ 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
echo "OK: no stale model IDs in $candidate_count scanned files; $agent_models agent model values all on-tier."
