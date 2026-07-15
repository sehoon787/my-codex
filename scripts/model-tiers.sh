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
MODEL_TIER_HIGH="gpt-5.6"
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
