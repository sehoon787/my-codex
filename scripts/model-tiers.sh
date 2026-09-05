#!/usr/bin/env bash
# model-tiers.sh — single source of truth for Codex CLI model tier IDs.
#
# Sourced (not executed) by scripts/md-to-toml.sh and install.sh so both
# scripts stay in sync on which Codex model backs each Claude/legacy tier.
#
# To roll forward on the next Codex model generation: (1) edit the three
# MODEL_TIER_* values below and LEGACY_MODEL_MAP, (2) update OLD_MODEL_PATTERN
# in scripts/check-model-drift.sh, (3) bump the model line in the committed
# codex-agents/**/*.toml files and the docs (README, SETUP, CONTRIBUTING,
# docs/, i18n). Script logic never hardcodes a model ID outside this file
# (scripts/check-model-drift.sh enforces that); agent TOMLs and docs do.

# Codex model ID per tier.
#
# Every value here MUST be a slug the Codex API actually serves. Generations
# ship suffixed slugs only: 6 = "gpt-6-astra" (single slug so far), 5.6 =
# sol/terra/luna. Bare "gpt-6" / "gpt-5.6" are NOT real models and fail at
# request time with:
#   400 invalid_request_error: The 'gpt-6' model is not supported when
#   using Codex with a ChatGPT account.
# Verify against `~/.codex/models_cache.json` (visibility="list") before
# rolling these forward. gpt-6-astra verified 2026-09-05 (efforts low..ultra;
# high/xhigh probed OK). No gpt-6 mid/low slugs exist yet, so MEDIUM/LOW use
# the top two 5.6 slugs: sol ("reliable agentic workhorse for everyday tasks")
# and terra ("balanced agentic coding model"). luna is retired from the tiers.
MODEL_TIER_HIGH="gpt-6-astra"
MODEL_TIER_MEDIUM="gpt-5.6-sol"
MODEL_TIER_LOW="gpt-5.6-terra"

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
#   1. Superseded-but-still-served slugs (gpt-5.4, gpt-5.5, gpt-5.6-luna) —
#      promoted so the install tracks the current tiers.
#   2. Slugs that were never valid (bare gpt-5.6, bare gpt-6) — these HARD FAIL
#      at request time, so rewriting them repairs installs made while that
#      value shipped as MODEL_TIER_HIGH.
LEGACY_MODEL_MAP=(
  "$LEGACY_WORKHORSE_MODEL:MEDIUM"
  "$LEGACY_SPARK_MODEL:LOW"
  "gpt-5.5:HIGH"
  "gpt-5.5-codex:HIGH"
  "gpt-5.6:HIGH"
  "gpt-5.6-luna:LOW"
  "gpt-6:HIGH"
)
