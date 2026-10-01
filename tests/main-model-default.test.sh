#!/usr/bin/env bash
# Regression test for install.sh's ensure_main_model().
#
# The installer defaults the main session to MODEL_MAIN by writing a top-level
# `model =` key into config.toml, but only when none exists: any value the user
# already chose must survive byte for byte. "Top-level" means before the first
# [table] header -- a `model =` inside a table (a profile, an MCP server) is a
# different key and must not count.
#
# `bash tests/main-model-default.test.sh`
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Extract ensure_main_model() straight out of install.sh (rather than
# reimplementing it here) so this test tracks the real function.
FUNC_SRC="$(sed -n '/^ensure_main_model() {/,/^}/p' "$INSTALL_SH")"
if [ -z "$FUNC_SRC" ]; then
  echo "FAIL: could not extract ensure_main_model() from install.sh" >&2
  exit 1
fi
eval "$FUNC_SRC"
# shellcheck source=scripts/model-tiers.sh
. "$REPO_ROOT/scripts/model-tiers.sh"

ERRORS=0
check() {
  if [ "$2" = "$3" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    echo "  expected: $(printf '%s' "$3" | od -c | head -20)"
    echo "  actual:   $(printf '%s' "$2" | od -c | head -20)"
    ERRORS=$((ERRORS + 1))
  fi
}

# 0. MODEL_MAIN is defined and is the medium tier.
check "0. MODEL_MAIN is the medium tier" "${MODEL_MAIN:-}" "$MODEL_TIER_MEDIUM"

# 1. Absent -> inserted at the top, rest of the file unchanged.
CONFIG_FILE="$TMP_ROOT/absent.toml"
cat > "$CONFIG_FILE" <<'TOML'
compact_prompt = "x"

[features]
hooks = true
TOML
chmod 640 "$CONFIG_FILE"
OUT=$(ensure_main_model)
check "1. absent key is inserted at top level" "$(cat "$CONFIG_FILE")" "$(cat <<TOML
model = "$MODEL_MAIN"
compact_prompt = "x"

[features]
hooks = true
TOML
)"
case "$OUT" in
  *"set model = \"$MODEL_MAIN\""*) echo "PASS  1b. insertion is reported" ;;
  *) echo "FAIL  1b. insertion reported: $OUT"; ERRORS=$((ERRORS + 1)) ;;
esac
check "1c. file mode is preserved" "$(ls -l "$CONFIG_FILE" | cut -c1-10)" "-rw-r-----"

# 2. Re-run after insertion is a no-op.
BEFORE="$(od -c "$CONFIG_FILE")"
ensure_main_model >/dev/null
check "2. re-run is a byte-for-byte no-op" "$(od -c "$CONFIG_FILE")" "$BEFORE"

# 3. Present with any value (including one off the tiers, odd spacing, and a
#    trailing comment) -> unchanged byte for byte, kept value reported.
for value in '"gpt-6-astra"' '"my-custom-model"   # pinned' ; do
  CONFIG_FILE="$TMP_ROOT/present.toml"
  printf '# user config\n  model=%s\nmodel_reasoning_effort = "high"\n\n[features]\nhooks = true\n' "$value" > "$CONFIG_FILE"
  BEFORE="$(od -c "$CONFIG_FILE")"
  OUT=$(ensure_main_model)
  check "3. existing top-level model ($value) is untouched" "$(od -c "$CONFIG_FILE")" "$BEFORE"
  case "$OUT" in
    *"model already set ($value), kept"*) echo "PASS  3b. kept value is reported" ;;
    *) echo "FAIL  3b. kept value reported: $OUT"; ERRORS=$((ERRORS + 1)) ;;
  esac
done

# 3.5. Present with a previous MODEL_MAIN default (an installer-written value,
#      not a user choice) -> rewritten to the current MODEL_MAIN.
CONFIG_FILE="$TMP_ROOT/previous.toml"
for legacy in "${PREVIOUS_MAIN_MODELS[@]}"; do
  printf '# user config\nmodel = "%s"\nmodel_reasoning_effort = "high"\n\n[features]\nhooks = true\n' "$legacy" > "$CONFIG_FILE"
  OUT=$(ensure_main_model)
  check "3.5. previous default ($legacy) is rewritten" "$(cat "$CONFIG_FILE")" "$(cat <<TOML
# user config
model = "$MODEL_MAIN"
model_reasoning_effort = "high"

[features]
hooks = true
TOML
)"
  case "$OUT" in
    *"model $legacy -> $MODEL_MAIN (previous my-codex default)"*) echo "PASS  3.5b. rewrite is reported" ;;
    *) echo "FAIL  3.5b. rewrite reported: $OUT"; ERRORS=$((ERRORS + 1)) ;;
  esac
  # Re-run is a no-op: the value is now MODEL_MAIN, not a previous default.
  BEFORE="$(od -c "$CONFIG_FILE")"
  ensure_main_model >/dev/null
  check "3.5c. re-run after rewrite is a no-op" "$(od -c "$CONFIG_FILE")" "$BEFORE"
done

# 3.55. Explicit migrations to gpt-6.1-sol, and gpt-6-astra (HIGH) is kept.
check "3.55a. MODEL_MAIN is gpt-6.1-sol" "$MODEL_MAIN" "gpt-6.1-sol"
check "3.55a2. gpt-6 and gpt-5.6 sol are both previous defaults" "${#PREVIOUS_MAIN_MODELS[@]}" "2"
for from in "${PREVIOUS_MAIN_MODELS[@]}"; do
  CONFIG_FILE="$TMP_ROOT/migrate.toml"
  printf 'model = "%s"\n[features]\nhooks = true\n' "$from" > "$CONFIG_FILE"
  ensure_main_model >/dev/null
  check "3.55b. $from migrates to gpt-6.1-sol" "$(head -1 "$CONFIG_FILE")" 'model = "gpt-6.1-sol"'
done
CONFIG_FILE="$TMP_ROOT/astra.toml"
printf 'model = "gpt-6-astra"\n[features]\nhooks = true\n' > "$CONFIG_FILE"
BEFORE="$(od -c "$CONFIG_FILE")"
ensure_main_model >/dev/null
check "3.55c. gpt-6-astra is kept" "$(od -c "$CONFIG_FILE")" "$BEFORE"
CONFIG_FILE="$TMP_ROOT/absent2.toml"
printf '[features]\nhooks = true\n' > "$CONFIG_FILE"
ensure_main_model >/dev/null
check "3.55d. absent model gets gpt-6.1-sol inserted" "$(head -1 "$CONFIG_FILE")" 'model = "gpt-6.1-sol"'

# 3.7. version_ge() gates the codex CLI warning against MIN_CODEX_CLI_VERSION.
eval "$(sed -n '/^version_ge() {/,/^}/p' "$INSTALL_SH")"
check "3.7a. MIN_CODEX_CLI_VERSION is 0.159.1" "${MIN_CODEX_CLI_VERSION:-}" "0.159.1"
for case_ in "0.158.0:warn" "0.159.1:ok" "0.160.0:ok" "1.0.0:ok" "0.159.0:warn" "0.9.9:warn"; do
  ver="${case_%%:*}"; want="${case_##*:}"
  if version_ge "$ver" "$MIN_CODEX_CLI_VERSION"; then got=ok; else got=warn; fi
  check "3.7b. codex $ver -> $want" "$got" "$want"
done

# 3.6. A previous default inside a table is not top-level -> left alone.
CONFIG_FILE="$TMP_ROOT/previous-in-table.toml"
cat > "$CONFIG_FILE" <<TOML
model_reasoning_effort = "high"

[profiles.fast]
model = "${PREVIOUS_MAIN_MODELS[0]}"
TOML
ensure_main_model >/dev/null
check "3.6. previous default inside a table does not count as top-level" "$(cat "$CONFIG_FILE")" "$(cat <<TOML
model = "$MODEL_MAIN"
model_reasoning_effort = "high"

[profiles.fast]
model = "${PREVIOUS_MAIN_MODELS[0]}"
TOML
)"

# 4. A `model =` inside a table is not top-level -> the default is still added.
CONFIG_FILE="$TMP_ROOT/in-table.toml"
cat > "$CONFIG_FILE" <<'TOML'
model_reasoning_effort = "high"

[profiles.fast]
model = "gpt-6-luna"
TOML
ensure_main_model >/dev/null
check "4. key inside a table does not count as top-level" "$(cat "$CONFIG_FILE")" "$(cat <<TOML
model = "$MODEL_MAIN"
model_reasoning_effort = "high"

[profiles.fast]
model = "gpt-6-luna"
TOML
)"

# 5. Empty file (fresh install before other keys) -> just the key.
CONFIG_FILE="$TMP_ROOT/empty.toml"
: > "$CONFIG_FILE"
ensure_main_model >/dev/null
check "5. empty config gains the key" "$(cat "$CONFIG_FILE")" "model = \"$MODEL_MAIN\""

# 6. install.sh runs under `set -euo pipefail`; both paths must survive it.
if bash -c '
    set -euo pipefail
    eval "$(sed -n "/^ensure_main_model() {/,/^}/p" "$1")"
    MODEL_MAIN="m"
    T=$(mktemp -d)
    CONFIG_FILE="$T/x.toml"; printf "[features]\nhooks = true\n" > "$CONFIG_FILE"
    ensure_main_model
    ensure_main_model
    rm -rf "$T"
  ' _ "$INSTALL_SH" >/dev/null 2>&1; then
  echo "PASS  6. function survives set -euo pipefail on insert and keep paths"
else
  echo "FAIL  6. function trips set -euo pipefail"
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -eq 0 ]; then
  echo "ALL PASSED"
  exit 0
fi
echo "$ERRORS FAILED"
exit 1
