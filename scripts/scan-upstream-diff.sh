#!/usr/bin/env bash
#
# scan-upstream-diff.sh — security review gate for automated upstream syncs.
#
# Given the currently-staged submodule pointer changes under upstream/, this
# script diffs each bumped submodule (old-sha..new-sha), inspects the ADDED
# lines introduced by the sync, and flags suspicious patterns. It is a
# soft gate: it never blocks. On any hit in a file install.sh actually installs
# or runs it writes a markdown report and signals "flagged" so the caller can
# skip auto-merge and request human review. Hits in files that are never
# installed (upstream tests, CI config, docker/, ...) are listed under
# "Informational (not installed)" and never set the flag. Symlinks widen what
# counts as installed, because install.sh copies through links: a new or changed
# link gates wherever it sits, and a file that a link in the new tree exposes at
# an installed path is judged there (see is_installed).
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
info_hits=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

emit() { printf '%s\n' "$1" >> "$REPORT"; }

# True for files that are documentation. Only consulted for files install.sh
# never installs, where a suspicious string is prose and nothing reads it. An
# installed doc is not prose to the agent: a SKILL.md, agent or prompt file is
# its instructions, and a .txt template can be copied somewhere it is executed.
# Those get the same scan as any other file.
is_doc_path() {
  case "$1" in
    *.md|*.md.tmpl|*.markdown|*.mdx|*.txt|*.rst|*.adoc) return 0 ;;
    docs/*|*/docs/*) return 0 ;;
    LICENSE|*/LICENSE|CHANGELOG|*/CHANGELOG) return 0 ;;
  esac
  return 1
}

# words <list...>: a newline- or space-separated list as " a b c ", so
# in_list is a plain `case` match, the same way install.sh tests membership.
words() { tr -s '[:space:]' ' ' <<< " $* "; }
# in_list <name> <words output>
in_list() { case "$2" in *" $1 "*) return 0 ;; esac; return 1; }

# ── Per-repo: what install.sh copies or runs from each upstream ─────────────
# The only part of this script that differs between my-claude and my-codex.
# Every name comes from scripts/skill-allowlists.sh and scripts/skill-catalog.json,
# the files install.sh itself reads, so editing either moves this gate with it.
# If a list does not load, is_installed_path answers "installed" for everything,
# as it does for any upstream not named below: the gate may over-flag, never
# go quiet.
# shellcheck source=skill-allowlists.sh
. "$SCRIPT_DIR/skill-allowlists.sh" 2>/dev/null || true
# install.sh installs every catalog `core` skill, and every skill named in ANY
# lane once that lane is enabled (--skills=<lane>, --full-skills), so all of
# them count as installed.
CATALOG_SKILLS=$(node -e '
  const catalog = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  process.stdout.write([...catalog.core, ...Object.values(catalog.lanes).flat()].join(" "));
' "$SCRIPT_DIR/skill-catalog.json" 2>/dev/null || true)

ALLOWLISTS_OK=1
for v in ECC_SKILL_ALLOWLIST CATALOG_SKILLS OMX_AGENT_ALLOWLIST GSTACK_SKILL_ALLOWLIST ARCHIFY_SKILL_SUBDIR; do
  [ -n "$(tr -d '[:space:]' <<< "${!v:-}")" ] || ALLOWLISTS_OK=0
done
CATALOG=$(words "$CATALOG_SKILLS")
ECC_SKILLS=$(words "${ECC_SKILL_ALLOWLIST:-} $CATALOG_SKILLS")
GSTACK_SKILL_DIRS=$(words "${GSTACK_SKILL_ALLOWLIST:-} $CATALOG_SKILLS")
OMX_AGENTS=$(words "${OMX_AGENT_ALLOWLIST:-}")
SP_EXCLUDED=$(words "${SUPERPOWERS_SKILL_EXCLUDE:-}")

# is_installed_path <upstream dir> <path inside it>: 0 if install.sh copies the
# path to the machine or runs it, 1 if it never touches it.
is_installed_path() {
  local up="${1##*/}" path="$2" name
  [ "$ALLOWLISTS_OK" -eq 1 ] || return 0
  case "$up" in
    ecc)
      # skills/<name>/ is copied whole. ECC rules are not installed at all.
      case "$path" in
        skills/*/*) name="${path#skills/}"; in_list "${name%%/*}" "$ECC_SKILLS"; return ;;
        *) return 1 ;;
      esac ;;
    omx)
      # prompts/<name>.md for the allowlisted agents, converted to TOML agents.
      case "$path" in
        prompts/*/*) return 1 ;;
        prompts/*.md) name="${path#prompts/}"; in_list "${name%.md}" "$OMX_AGENTS"; return ;;
        *) return 1 ;;
      esac ;;
    gstack)
      # The whole checkout is rsynced to ~/.codex/vendor/gstack and its ./setup
      # runs there, so everything counts except test trees, fixtures and CI
      # config, which are copied along but never run or read. Three exceptions
      # come back in:
      #  - docs/: ./setup links three of its files into the runtime root for
      #    skills to read, and that list lives in setup, which upstream controls.
      #  - test/helpers/: installed bin/ code imports it when it runs
      #    (bin/gstack-model-benchmark and the provider adapters).
      #  - a skill directory that install.sh links whole into ~/.codex/skills
      #    (browser-skills/hackernews-frontpage, codex, and each allowlisted skill
      #    when ./setup is unavailable) or that the catalog CLI copies whole (any
      #    catalog-named skill): Codex loads every SKILL.md beneath it, fixtures
      #    and tests included.
      case "$path" in
        browser-skills/hackernews-frontpage/*|codex/*|docs/*|test/helpers/*) return 0 ;;
        */*) in_list "${path%%/*}" "$GSTACK_SKILL_DIRS" && return 0 ;;
      esac
      case "/$path" in
        */test/*|*/tests/*|*/__tests__/*|*/fixtures/*|*.test.*|/.github/*) return 1 ;;
        *) return 0 ;;
      esac ;;
    superpowers)
      # Every skill directory except the excluded ones; no agents. The catalog
      # CLI copies any catalog-named skill from here, excluded or not.
      case "$path" in
        skills/*/*)
          name="${path#skills/}"; name="${name%%/*}"
          in_list "$name" "$SP_EXCLUDED" && ! in_list "$name" "$CATALOG" && return 1
          return 0 ;;
        *) return 1 ;;
      esac ;;
    archify)
      # The skill directory is copied whole; the rest of the repo is not.
      case "$path" in
        "$ARCHIFY_SKILL_SUBDIR"/*) return 0 ;;
        *) return 1 ;;
      esac ;;
    *) return 0 ;;
  esac
}
# ── end per-repo ────────────────────────────────────────────────────────────

# resolve_link <link path> <link target>: where the link points, as a path from
# the repository root with "." and ".." folded away. Prints nothing for an
# absolute target or one that climbs out of the repository.
resolve_link() {
  local combined="$2" seg
  local -a parts out=()
  case "$2" in /*|'') return 0 ;; esac
  case "$1" in */*) combined="${1%/*}/$2" ;; esac
  IFS=/ read -ra parts <<< "$combined"
  for seg in "${parts[@]}"; do
    case "$seg" in
      ''|.) ;;
      ..) [ "${#out[@]}" -gt 0 ] || return 0; unset "out[${#out[@]}-1]" ;;
      *) out+=("$seg") ;;
    esac
  done
  (IFS=/; printf '%s\n' "${out[*]:-.}")
}

# is_installed <upstream dir> <path> [depth]: is_installed_path, or the same
# question asked at the place a symlink in the new tree exposes the path. With
# `skills/foo -> ../docker/foo`, install.sh copies docker/foo/SKILL.md as
# skills/foo/SKILL.md, so that is the path to judge. A link approved once would
# otherwise let every later sync edit its target unseen: the link itself no
# longer changes. link_paths/link_dests are filled per submodule below.
is_installed() {
  local i dest rel depth="${3:-0}"
  is_installed_path "$1" "$2" && return 0
  [ "$depth" -lt 8 ] || return 1 # links that point at each other
  for i in ${link_paths[@]+"${!link_paths[@]}"}; do
    dest="${link_dests[$i]}"
    [ -n "$dest" ] || continue
    case "$2" in
      "$dest") rel="" ;;
      "$dest"/*) rel="/${2#"$dest"/}" ;;
      *) [ "$dest" = . ] || continue; rel="/$2" ;;
    esac
    is_installed "$1" "${link_paths[$i]}$rel" $((depth + 1)) && return 0
  done
  return 1
}

emit "## Upstream sync security scan"
emit ""
if [ "$ALLOWLISTS_OK" -ne 1 ]; then
  emit ":warning: _The installed-path lists could not be read, so every path was treated as installed._"
  emit ""
fi

# Collect staged submodule paths under upstream/.
mapfile -t subs < <(git diff --cached --name-only -- upstream/ 2>/dev/null || true)

if [ "${#subs[@]}" -eq 0 ]; then
  emit "_No staged submodule changes under upstream/. Nothing to scan._"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "flagged=false" >> "$GITHUB_OUTPUT"; fi
  exit 0
fi

# Suspicious pattern groups. Each entry: "Label|extended-regex".
# Kept deliberately broad — this is a flag, not a block.
# Entries run case-insensitively, except those whose label starts with "="
# (stripped before printing), which run case-sensitively: eval and Function are
# JavaScript/shell names whose lowercase and capitalised forms mean different
# things, and the insensitive match turned `function(` into a hit.
PATTERNS=(
  "Network exfil (curl/wget to URL)|(curl|wget)([[:space:]]|.)*https?://"
  "Network exfil (fetch to URL)|fetch\\(['\"\`]?https?://"
  "base64 decode piped to shell|base64[[:space:]]+(-d|--decode|-D)([[:space:]]|.)*(bash|sh|zsh|node|python|eval)"
  # Matches both nestings: decode-then-eval (`atob(s); eval(x)`) and the far
  # more common obfuscation where the decode is the argument, `eval(atob(p))`,
  # `new Function(atob(p))`. eval/Function must stand alone as a call, so
  # `function(` and words like "evals" next to a Buffer.from( do not match.
  "=base64 decode + eval (JS)|((atob|Buffer\\.from)\\(.*(^|[^A-Za-z0-9_\$])(eval|Function)\\)?[[:space:]]*\\(|(^|[^A-Za-z0-9_\$])(eval|Function)\\)?[[:space:]]*\\(.*(atob|Buffer\\.from)\\()"
  # eval applied to something expanded or quoted. A bare `eval word` is mostly
  # prose ("eval of the model"), and `evaluate` is not eval.
  "=Dynamic shell eval|(^|[[:space:];&|])eval[[:space:]]+[\"'\$\`]"
  "bash -c with variable expansion|bash[[:space:]]+-c([[:space:]]|.)*\\\$"
  # A recursive rm (any flag spelling and order) aimed at $HOME, ~ or /.
  # A bare `rm -f ~/x.pid` has no recursive flag and is a normal cleanup.
  "Destructive rm of HOME/root|rm[[:space:]]+(-[-a-zA-Z]+[[:space:]]+)*(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]+-[-a-zA-Z]+)*[[:space:]]+[\"']?(\\\$HOME|\\\$\\{HOME\\}|~|/([[:space:]]|[\"']|\$|\\*))"
  # Anchored to real credential paths. A bare "credentials" matched prose
  # ("needs real credentials") and, worse, `persist-credentials: false` — a
  # hardening flag. A bare "\.env\b" matched every `process.env` in the diff.
  "SSH key / credential access|(\\.ssh/|id_rsa|id_ed25519|/\\.aws/|/\\.netrc|credentials\\.(json|ya?ml|ini)|(^|[^A-Za-z_.])\\.env([[:space:].\"'/]|\$))"
  # Only a literal value assigned inline counts. Indirection through a secret
  # store or the environment (\${{ secrets.X }}, process.env.X, \$VAR) is the
  # correct way to handle a token, so flagging it buried the real signal.
  "Token/secret assignment or read|(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9_+/=.-]{16,}[\"']"
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
  installed_count=0

  # Every symlink in the new tree and where it points, read by is_installed.
  link_paths=(); link_dests=()
  while IFS= read -r -d '' entry; do
    [ "${entry%% *}" = 120000 ] || continue
    blob="${entry%%$'\t'*}"; blob="${blob##* }"
    link_paths+=("${entry#*$'\t'}")
    link_dests+=("$(resolve_link "${entry#*$'\t'}" "$(git -C "$sub" cat-file blob "$blob" 2>/dev/null)")")
  done < <(git -C "$sub" ls-tree -r -z "$new" 2>/dev/null || true)

  # Newly added executable or binary files. Docs are not exempt here: a
  # payload cannot hide behind a .md extension. --no-renames makes a moved file
  # a delete plus an add, so moving a binary into an installed path is seen.
  while IFS=$'\t' read -r status path; do
    [ "$status" = "A" ] || continue
    mode=$(git -C "$sub" ls-tree "$new" -- "$path" 2>/dev/null | awk '{print $1}')
    is_bin=$(git -C "$sub" diff --numstat "$old" "$new" -- "$path" 2>/dev/null | awk '{print $1}')
    if [ "$mode" = "100755" ]; then
      what="new executable file"; detail=" (mode $mode)"
    elif [ "$is_bin" = "-" ]; then
      what="new binary file"; detail=""
    else
      continue
    fi
    if is_installed "$sub" "$path"; then
      emit "- FLAG **$what**: \`$path\`$detail"
      sub_flag=1
    else
      info_hits+=("- INFO **$what**: \`$sub/$path\`$detail")
    fi
  done < <(git -C "$sub" diff --name-status --diff-filter=A --no-renames "$old" "$new" 2>/dev/null || true)

  # New or changed symlinks gate wherever they sit. A link's own diff is just
  # its target string, and install.sh copies through links, so a link at a path
  # that looks uninstalled (`review -> test/fixtures/review`) can put content
  # the scan only lists as informational onto the machine. The target is shown
  # as one line without backticks: a link target may hold newlines, and an
  # unfiltered one could write extra lines into this report.
  while IFS= read -r path; do
    target=$(git -C "$sub" cat-file -p "$new:$path" 2>/dev/null | head -n 1 | cut -c1-120 | tr -d '\r\140')
    emit "- FLAG **new or changed symlink**: \`$path\` (to \`$target\`)"
    sub_flag=1
  done < <(git -C "$sub" diff --raw --no-renames "$old" "$new" 2>/dev/null \
             | awk -F'\t' '{ split($1, mode, " "); if (mode[2] == "120000") print $2 }' || true)

  # Pattern scan over ADDED lines only.
  for f in "${files[@]}"; do
    installed=0
    if is_installed "$sub" "$f"; then
      installed=1
      installed_count=$((installed_count + 1))
    elif is_doc_path "$f"; then
      # Prose nobody installs. A `curl … | sh` in an upstream README is an
      # example or a warning about that exact attack, and "eval" in a doc is
      # usually the word "evaluation"; these hits once made the gate flag
      # every sync. The new-executable/binary checks above still cover them.
      continue
    fi
    # Extract added lines (strip leading +), skip file headers.
    added=$(git -C "$sub" diff "$old" "$new" -- "$f" 2>/dev/null \
      | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^\+//')
    [ -n "$added" ] || continue
    for entry in "${PATTERNS[@]}"; do
      label="${entry%%|*}"
      regex="${entry#*|}"
      grep_flags=(-inE)
      case "$label" in =*) label="${label#=}"; grep_flags=(-nE) ;; esac
      hits=$(printf '%s\n' "$added" | grep "${grep_flags[@]}" "$regex" 2>/dev/null | head -3 || true)
      [ -n "$hits" ] || continue
      if [ "$installed" -eq 0 ]; then
        info_hits+=("- INFO **${label}** in \`$sub/$f\`")
        continue
      fi
      emit "- FLAG **${label}** in \`$f\`:"
      while IFS= read -r line; do
        # Trim overly long lines for readability.
        emit "    - \`$(printf '%s' "$line" | cut -c1-160)\`"
      done <<< "$hits"
      sub_flag=1
    done
  done

  if [ "$sub_flag" -eq 0 ]; then
    emit "_No suspicious patterns in installed files (${#files[@]} file(s) changed, $installed_count installed)._"
  else
    flagged=1
  fi
  emit ""
done

if [ "${#info_hits[@]}" -gt 0 ]; then
  emit "### Informational (not installed)"
  emit ""
  emit "_${#info_hits[@]} hit(s) in files install.sh never copies or runs. Listed for visibility; they do not gate auto-merge._"
  emit ""
  for line in "${info_hits[@]}"; do emit "$line"; done
  emit ""
fi

if [ "$flagged" -eq 1 ]; then
  emit "---"
  emit ":warning: **This sync was flagged for manual review.** Auto-merge was skipped."
  emit "A maintainer should inspect the changes above and merge manually if safe."
else
  emit "---"
  emit ":white_check_mark: No suspicious patterns detected in installed files. Safe for auto-merge."
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "flagged=$([ "$flagged" -eq 1 ] && echo true || echo false)" >> "$GITHUB_OUTPUT"
fi

echo "scan complete: flagged=$flagged (report: $REPORT)"
exit 0
