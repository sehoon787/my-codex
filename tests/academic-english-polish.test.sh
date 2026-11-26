#!/usr/bin/env bash
#
# academic-english-polish.test.sh — skills/core/academic-english-polish/check_apply.py
# passes a clean apply file, flags every planted defect, and writes only into a
# real copy of the sources.
# `bash tests/academic-english-polish.test.sh`
#
# Root cause: `cp -R` keeps symlinks, so a symlinked chapter file or folder
# inside the copy made an abspath-only check write into the real source; and
# the formatting check only saw letter commands, so an added or removed \\
# line break passed. Proves: the good fixture exits 0 with FAIL 0; the bad
# fixture exits 1 and reports each planted failure kind; an added \\ fails;
# --apply-into into a cp -R copy writes the expected text and leaves the sources
# byte-identical; a symlinked chapters folder, a symlinked chapter file and a
# DEST_ROOT inside SRC_ROOT are refused with nothing written.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$REPO_ROOT/skills/core/academic-english-polish/check_apply.py"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aep-test.XXXXXX")" || { echo "mktemp failed"; exit 1; }
trap 'rm -rf "${TMP_ROOT:?}"' EXIT

if [ ! -f "$HELPER" ]; then
  echo "FAIL  helper not found: $HELPER"
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

pass=0
fail=0
check() { # check NAME STATUS (0 = ok)
  if [ "$2" = "0" ]; then
    echo "PASS  $1"
    pass=$((pass + 1))
  else
    echo "FAIL  $1"
    fail=$((fail + 1))
  fi
}
has() { grep -qF -- "$2" <<<"$1"; }       # has OUTPUT NEEDLE

SRC="$TMP_ROOT/src"
mkdir -p "$SRC/chapters" "$TMP_ROOT/good" "$TMP_ROOT/bad"

cat >"$SRC/chapters/a.tex" <<'TEX'
% Chapter 3 draft (fixture for check_apply.py)
\section{Method}\label{sec:method}
The gate are applied before decoding, therefore the latency of
each request increase by 4.2~ms (Table~\ref{tab:latency}).
It is worth noting that the pre-trained encoder is frozen in order to
keep the comparison fair~\cite{smith2024}.
We evaluate on 1,200 utterances from two corpora (Sections~\ref{sec:data}--\ref{sec:split}).
% src: results/latency.json
The utility of the gate is crucial for the final accuracy of $92.1\%$.
TEX
cat >"$SRC/chapters/b.tex" <<'TEX'
\section{Results}
Table~\ref{tab:main} reports accuracy on 3 benchmarks.
The pretrained model was fine-tuned for 10 epochs.
The pretrained model was fine-tuned for 10 epochs.
TEX

cat >"$TMP_ROOT/banned.txt" <<'TXT'
# rejected variants
pretrained
re:(?i)\bdelve
re:(?i)\bcrucial
re:(?i)\bit is worth noting
re:(?i)\bin order to\b
TXT

cat >"$TMP_ROOT/good/apply.md" <<'MD'
# Apply-ready file (fixture: every check should pass)

## File A

### R1 [required] §3.1, p. 14 (A 3–4)
Current:
~~~latex
The gate are applied before decoding, therefore the latency of
each request increase by 4.2~ms (Table~\ref{tab:latency}).
~~~
Replacement:
~~~latex
The gate is applied before decoding. Each request therefore takes
4.2~ms longer (Table~\ref{tab:latency}).
~~~

### R2 [recommended] §3.1, p. 14 (A 5–6)
Current:
~~~latex
It is worth noting that the pre-trained encoder is frozen in order to
keep the comparison fair~\cite{smith2024}.
~~~
Replacement:
~~~latex
The pre-trained encoder is frozen to
keep the comparison fair~\cite{smith2024}.
~~~

### E1 [optional, confirm] §3.1, p. 14 (A 8–9)
Current:
~~~latex
% src: results/latency.json
The utility of the gate is crucial for the final accuracy of $92.1\%$.
~~~
Replacement:
~~~latex
% src: results/latency.json
~~~
Numbers: removed 92.1 (the value stays in Table 3.2) [confirm]
Removed: the math $92.1\%$ goes with the deleted sentence

### E2 [recommended] §3.1, p. 14 (A 3)
Current:
~~~latex
Each request therefore takes
~~~
Replacement:
~~~latex
Each request therefore runs
~~~
Depends on: R1
MD

cat >"$TMP_ROOT/good/review.md" <<'MD'
| # | location | type | class | current sentence | problem | proposal |
|---|---|---|---|---|---|---|
| R1 | p.14, a.tex:3 | grammar | required | The gate are applied | agreement | is applied |
| R2 | p.14, a.tex:5 | wordiness | recommended | It is worth noting that | filler | delete |
MD
cat >"$TMP_ROOT/good/report.md" <<'MD'
| # | class | reason |
|---|---|---|
| R1 | required | agreement |
| R2 | recommended | filler |
MD

cat >"$TMP_ROOT/bad/apply.md" <<'MD'
# Apply-ready file (fixture: every item should fail one check)

### B1 [required] §4, p. 20 (B 3)
Current:
~~~latex
The pretrained model was fine-tuned for 10 epochs.
~~~
Replacement:
~~~latex
The pre-trained model was fine-tuned for 10 epochs.
~~~

### B2 [recommended] §4, p. 20 (B 2)
Current:
~~~latex
Table~\ref{tab:main} reports accuracy on 3 benchmarks.
~~~
Replacement:
~~~latex
Table~\ref{tab:results} reports accuracy on three benchmarks.\vspace{-2pt}
~~~

### A1 [required] §3.1, p. 14 (A 5)
Current:
~~~latex
keep the comparison fair~\cite{smith2024}.
~~~
Replacement:
~~~latex
keep the comparison fair, which is crucial~\cite{smith2024}.
~~~

### A2 [recommended] §3.1, p. 14 (A 3–4)
Current:
~~~latex
The gate are applied before decoding, therefore the latency of
each request increase by 4.2~ms (Table~\ref{tab:latency}).
~~~
Replacement:
~~~latex
The gate is applied before decoding, so the latency of
each request increases by 4.2~ms (Table~\ref{tab:latency}).
~~~

### A3 [recommended] §3.1, p. 14 (A 4)
Current:
~~~latex
each request increase by 4.2~ms
~~~
Replacement:
~~~latex
each request increases by 4.2~ms
~~~

### A7 [required] §3.1, p. 14 (A 7)
Current:
~~~latex
We evaluated on 1,200 utterances
~~~
Replacement:
~~~latex
We evaluate on 1,200 utterances
~~~
MD

cat >"$TMP_ROOT/bad/review.md" <<'MD'
| # | location | type | class | current sentence | problem | proposal |
|---|---|---|---|---|---|---|
| R1 | p.14, a.tex:3 | grammar | required | The gate are applied | agreement | is applied |
| R3 | p.20, b.tex:3 | duplication | recommended | The pretrained model | repeated line | delete one |
MD
cat >"$TMP_ROOT/bad/report.md" <<'MD'
| # | class | reason |
|---|---|---|
| R1 | required | agreement |
MD

cat >"$TMP_ROOT/linebreak.md" <<'MD'
### L1 [required] §3.1, p. 14 (A 7)
Current:
~~~latex
We evaluate on 1,200 utterances
~~~
Replacement:
~~~latex
We evaluate on 1,200 utterances \\
~~~
MD

run() { python3 -I "$HELPER" "$@" 2>&1; }

SRC_A="$SRC/chapters/a.tex"
SRC_B="$SRC/chapters/b.tex"
sha_a="$(sha256_of "$SRC_A")"
sha_b="$(sha256_of "$SRC_B")"
sources_unchanged() {
  [ "$(sha256_of "$SRC_A")" = "$sha_a" ] && [ "$(sha256_of "$SRC_B")" = "$sha_b" ]
}

# good fixture
out="$(run "$TMP_ROOT/good/apply.md" "A=$SRC_A" "B=$SRC_B" --banned "$TMP_ROOT/banned.txt" \
  --review "$TMP_ROOT/good/review.md" --report "$TMP_ROOT/good/report.md")"; rc=$?
check "good fixture exits 0" "$rc"
has "$out" "FAIL 0"; check "good fixture reports FAIL 0" "$?"

# bad fixture
out="$(run "$TMP_ROOT/bad/apply.md" "A=$SRC_A" "B=$SRC_B" --banned "$TMP_ROOT/banned.txt" \
  --review "$TMP_ROOT/bad/review.md" --report "$TMP_ROOT/bad/report.md")"; rc=$?
[ "$rc" = "1" ]; check "bad fixture exits 1" "$?"
has "$out" "FAIL B1: primary: current block occurs 2 times"; check "bad: duplicate anchor" "$?"
has "$out" "FAIL A7: primary: current block occurs 0 times"; check "bad: missing anchor" "$?"
has "$out" "FAIL B2: primary: numbers removed"; check "bad: number change" "$?"
has "$out" "ref/cite/label removed"; check "bad: removed \\ref" "$?"
has "$out" "new formatting command ['vspace']"; check "bad: new \\vspace" "$?"
has "$out" "banned variant"; check "bad: banned phrase" "$?"
has "$out" "FAIL A3: current block overlaps A2"; check "bad: overlap" "$?"
has "$out" "FAIL -: reviewer finding R3 has no row in the report"; check "bad: missing report row" "$?"

# an added \\ fails
out="$(run "$TMP_ROOT/linebreak.md" "A=$SRC_A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "line break count changed from 0 to 1"; check "added \\\\ line break fails" "$?"

# --apply-into a cp -R copy
COPY="$TMP_ROOT/copy"
cp -R "$SRC" "$COPY"
out="$(run "$TMP_ROOT/good/apply.md" "A=$SRC_A" "B=$SRC_B" --apply-into "$SRC=$COPY")"; rc=$?
check "apply-into a copy exits 0" "$rc"
has "$out" "wrote $COPY/chapters/a.tex"; check "apply-into reports the write" "$?"
grep -qF 'The gate is applied before decoding. Each request therefore runs' "$COPY/chapters/a.tex" \
  && grep -qF 'The pre-trained encoder is frozen to' "$COPY/chapters/a.tex"
check "copy holds the expected text (R1, E2 after R1, R2)" "$?"
sources_unchanged; check "sources unchanged after apply-into" "$?"

# symlinked chapters folder inside DEST
LINKDIR="$TMP_ROOT/linkdir"
cp -R "$SRC" "$LINKDIR"
rm -rf "${LINKDIR:?}/chapters"
ln -s "$SRC/chapters" "$LINKDIR/chapters"
out="$(run "$TMP_ROOT/good/apply.md" "A=$SRC_A" "B=$SRC_B" --apply-into "$SRC=$LINKDIR")"; rc=$?
[ "$rc" != "0" ]; check "symlinked chapters folder: non-zero exit" "$?"
has "$out" "wrote"; [ "$?" != "0" ]; check "symlinked chapters folder: no wrote line" "$?"
sources_unchanged; check "symlinked chapters folder: sources unchanged" "$?"

# symlinked chapter file inside DEST
LINKFILE="$TMP_ROOT/linkfile"
cp -R "$SRC" "$LINKFILE"
rm -f "${LINKFILE:?}/chapters/a.tex"
ln -s "$SRC_A" "$LINKFILE/chapters/a.tex"
out="$(run "$TMP_ROOT/good/apply.md" "A=$SRC_A" "B=$SRC_B" --apply-into "$SRC=$LINKFILE")"; rc=$?
[ "$rc" != "0" ]; check "symlinked chapter file: non-zero exit" "$?"
has "$out" "wrote"; [ "$?" != "0" ]; check "symlinked chapter file: no wrote line" "$?"
sources_unchanged; check "symlinked chapter file: sources unchanged" "$?"

# DEST_ROOT inside SRC_ROOT
out="$(run "$TMP_ROOT/good/apply.md" "A=$SRC_A" "B=$SRC_B" --apply-into "$SRC=$SRC/inner")"; rc=$?
[ "$rc" != "0" ]; check "DEST inside SRC: non-zero exit" "$?"
has "$out" "wrote"; [ "$?" != "0" ]; check "DEST inside SRC: no wrote line" "$?"
[ ! -e "$SRC/inner" ]; check "DEST inside SRC: nothing created" "$?"
sources_unchanged; check "DEST inside SRC: sources unchanged" "$?"

echo
echo "passed $pass, failed $fail"
[ "$fail" = "0" ]
