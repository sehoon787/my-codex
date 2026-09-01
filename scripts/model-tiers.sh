#!/usr/bin/env bash
# model-tiers.sh — single source of truth for Codex CLI model tier IDs.
#
# Sourced (not executed) by scripts/md-to-toml.sh and install.sh so both
# scripts stay in sync on which Codex model backs each Claude/legacy tier.
#
# To roll forward on the next Codex model generation, edit ONLY the three
# MODEL_TIER_* values below. Nothing else in this repo should hardcode a
# model ID outside of this file (see scripts/check-model-drift.sh).

# Codex model ID per tier.
#
# Every value here MUST be a slug the Codex API actually serves. The 5.6
# generation ships only suffixed slugs (sol/terra/luna) — a bare "gpt-5.6"
# is NOT a real model and fails at request time with:
#   400 invalid_request_error: The 'gpt-5.6' model is not supported when
#   using Codex with a ChatGPT account.
# Verify against `~/.codex/models_cache.json` (visibility="list") before
# rolling these forward.
MODEL_TIER_HIGH="gpt-5.6-sol"
MODEL_TIER_MEDIUM="gpt-5.6-terra"
MODEL_TIER_LOW="gpt-5.6-luna"

# model_reasoning_effort per tier.
MODEL_TIER_HIGH_EFFORT="high"
MODEL_TIER_MEDIUM_EFFORT="medium"
MODEL_TIER_LOW_EFFORT="low"

# Previous-generation model IDs that install.sh's normalize_agent_models()
# rewrites to the current tier (upstream sources ship native .toml agents
# with these stale values baked in).
LEGACY_WORKHORSE_MODEL="gpt-5.4"          # -> MODEL_TIER_MEDIUM
LEGACY_SPARK_MODEL="gpt-5.3-codex-spark"  # -> MODEL_TIER_LOW

# Full rewrite table consumed by normalize_agent_models(). Format: "from:TIER"
# where TIER is HIGH|MEDIUM|LOW, resolved against MODEL_TIER_* above.
#
# Two distinct classes live here:
#   1. Superseded-but-still-served slugs (gpt-5.4, gpt-5.5) — promoted so the
#      install tracks the current generation.
#   2. Slugs that were never valid (bare gpt-5.6) — these HARD FAIL at request
#      time, so rewriting them repairs installs made while that value shipped
#      as MODEL_TIER_HIGH.
LEGACY_MODEL_MAP=(
  "$LEGACY_WORKHORSE_MODEL:MEDIUM"
  "$LEGACY_SPARK_MODEL:LOW"
  "gpt-5.5:HIGH"
  "gpt-5.5-codex:HIGH"
  "gpt-5.6:HIGH"
)
