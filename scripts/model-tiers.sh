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
# ship suffixed slugs only: 6.1 = sol, 6 = astra/sol/luna, 5.6 = sol/terra/luna.
# Bare "gpt-6" / "gpt-5.6" are NOT real models and fail at request time with:
#   400 invalid_request_error: The 'gpt-6' model is not supported when
#   using Codex with a ChatGPT account.
# Verify against `codex debug models` (live catalog) before rolling these
# forward. gpt-6-astra verified 2026-09-05 (efforts low..ultra; high/xhigh
# probed OK). gpt-6.1-sol ("Latest workhorse model for coding and everyday
# work", priority 1) is now current generation and backs MEDIUM; it needs
# Codex CLI >= MIN_CODEX_CLI_VERSION below (older CLIs 400 on it). gpt-6-sol
# ("Previous generation workhorse model", priority 3) is superseded, one
# generation behind gpt-6.1-sol. gpt-6-luna ("Fast and affordable model for
# easier tasks", priority 4) backs LOW; there is no gpt-6.1-luna. gpt-5.6-sol
# and gpt-5.6-terra are older still. All four superseded sol/terra slugs are
# in LEGACY_MODEL_MAP.
MODEL_TIER_HIGH="gpt-6-astra"
MODEL_TIER_MEDIUM="gpt-6.1-sol"
MODEL_TIER_LOW="gpt-6-luna"

# Minimum Codex CLI version MODEL_TIER_MEDIUM requires. Older CLIs 400 on
# gpt-6.1-sol with: "The 'gpt-6.1-sol' model is not supported when using
# Codex with a ChatGPT account." install.sh does not install or upgrade the
# codex CLI itself -- it only warns below this version, never fails the
# install. Verified: 0.158.0 fails, 0.159.1 (`codex exec -m gpt-6.1-sol`)
# succeeds.
MIN_CODEX_CLI_VERSION="0.159.1"

# Main-session default written to config.toml's top-level `model` when unset.
MODEL_MAIN="$MODEL_TIER_MEDIUM"

# Previous main-session defaults (past values of MODEL_MAIN). install.sh's
# ensure_main_model() rewrites a config.toml top-level `model` to the current
# MODEL_MAIN only when it exactly matches one of these -- any other existing
# value (including a user's own choice) is left untouched.
PREVIOUS_MAIN_MODELS=("gpt-5.6-sol" "gpt-6-sol")

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
  "gpt-5.6-sol:MEDIUM"
  "gpt-5.6-terra:LOW"
  "gpt-6:HIGH"
  "gpt-6-sol:MEDIUM"
)
