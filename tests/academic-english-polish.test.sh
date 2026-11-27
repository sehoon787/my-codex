#!/usr/bin/env bash
#
# academic-english-polish.test.sh — skills/core/academic-english-polish/check_apply.py
# passes a clean apply file, flags every planted defect, and writes only into a
# real copy of the sources.
# `bash tests/academic-english-polish.test.sh`
#
# Root cause: `cp -R` keeps symlinks, and a copy can also be a hard-linked or a
# case-alias path of the sources, so a path-string check let --apply-into write
# into the real source; and the checks only saw what they were built to see (a
# letter-command key, an added \\, an exact banned string), so removals, chains,
# nested overlaps and unlisted number changes passed silently. Proves: the good
# fixture exits 0 with FAIL 0; every planted failure appears as a "FAIL <id>:"
# line for the item that carries it; the false positives stay quiet;
# --apply-into writes the expected text (CRLF kept, optional items only on
# request, --items plus dependencies) and leaves the sources byte-identical;
# and a symlinked folder or file, a hard link, a case alias and a DEST inside
# SRC are refused with nothing written. Every case starts from pristine sources.
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
has() { grep -qF -- "$2" <<<"$1"; }        # has OUTPUT NEEDLE
lacks() { ! grep -qF -- "$2" <<<"$1"; }    # lacks OUTPUT NEEDLE
run() { python3 -I "$HELPER" "$@" 2>&1; }

# ---- pristine fixtures (never touched; every case copies them) ----
PRISTINE="$TMP_ROOT/pristine"
mkdir -p "$PRISTINE/src/chapters"
cat >"$PRISTINE/src/chapters/a.tex" <<'TEX'
% Chapter 3 draft (fixture for check_apply.py)
\section{Method}\label{sec:method}
The gate are applied before decoding, therefore the latency of
each request increase by 4.2~ms (Table~\ref{tab:latency}).
It is worth noting that the pre-trained encoder is frozen in order to
keep the comparison fair~\cite{smith2024}.
We evaluate on 1,200 utterances from two corpora (Sections~\ref{sec:data}--\ref{sec:split}).
% src: results/latency.json
The utility of the gate is crucial for the final accuracy of $92.1\%$.
\noindent Prior work~\textcite{knuth} and \cite{lee}, see [@knuth; @other, p. 3] and @doe2020 for details.
The cost is \$5 per run and \$10 for tuning.
\[ E = mc^2 \]
\textcolor{red}{Results} improved on the data settings, shown in Figure~\ref{fig:pretrained-loss}.
% crucial: keep this note
The ResNet-R101 backbone is used.
First part \\ second part.
\begin{equation} x = y + z \end{equation}
Plain text % crucial: note in order to keep
See \url{https://x.org/pretrained-models/v1} for details.
Rate 5\% here.
The model has 4 layers.
The decoder has 6 heads.
As shown by \cite[p.~5]{smith2024} here.
Also \citep{lee,kim} there.
Also \citep{wu,xu} there too.
alpha \\$a$ and beta $b$ end.
\begin{equation}
L = a + b
\end{equation}
The corpus has 1{,}200 clips.
TEX
cat >"$PRISTINE/src/chapters/b.tex" <<'TEX'
\section{Results}
Table~\ref{tab:main} reports accuracy on 3 benchmarks.
The pretrained model was fine-tuned for 10 epochs.
The pretrained model was fine-tuned for 10 epochs.
TEX

cat >"$PRISTINE/banned.txt" <<'TXT'
# rejected variants
pretrained
color
data set
re:(?i)\bdelve
re:(?i)\bcrucial
re:(?i)\bit is worth noting
re:(?i)\bin order to\b
TXT

# item ID CLASS CURRENT REPLACEMENT [NOTE...] : one apply.md item, file key A
item() {
  local id="$1" cls="$2" cur="$3" rep="$4"
  shift 4
  printf '### %s [%s] §1, p. 1 (A 1)\nCurrent:\n~~~latex\n%s\n~~~\nReplacement:\n~~~latex\n%s\n~~~\n' "$id" "$cls" "$cur" "$rep"
  local note
  for note in "$@"; do printf '%s\n' "$note"; done
  printf '\n'
}

# new_case NAME : fresh copy of the sources; sets C, SRC, A, B and their checksums
new_case() {
  C="$TMP_ROOT/cases/$1"
  mkdir -p "$C"
  cp -R "$PRISTINE/src" "$C/src"
  SRC="$C/src"
  A="$SRC/chapters/a.tex"
  B="$SRC/chapters/b.tex"
  sha_a="$(sha256_of "$A")"
  sha_b="$(sha256_of "$B")"
}
sources_unchanged() {
  [ "$(sha256_of "$A")" = "$sha_a" ] && [ "$(sha256_of "$B")" = "$sha_b" ]
}
BANNED="$PRISTINE/banned.txt"

write_good_apply() {
  cat >"$C/apply.md" <<'MD'
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
Numbers: removed `92.1` (the value stays in Table 3.2) [confirm]
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
}

# ---- good fixture ----
new_case good
write_good_apply
cat >"$C/review.md" <<'MD'
| # | location | type | class | current sentence | problem | proposal |
|---|---|---|---|---|---|---|
| R1 | p.14, a.tex:3 | grammar | required | The gate are applied | agreement | is applied |
| R2 | p.14, a.tex:5 | wordiness | recommended | It is worth noting that | filler | delete |
MD
cat >"$C/report.md" <<'MD'
| # | class | reason |
|---|---|---|
| R1 | required | agreement |
| R2a | recommended | filler |
MD
out="$(run "$C/apply.md" "A=$A" "B=$B" --banned "$BANNED" --review "$C/review.md" --report "$C/report.md")"; rc=$?
check "good fixture exits 0" "$rc"
has "$out" "FAIL 0"; check "good fixture reports FAIL 0" "$?"
sources_unchanged; check "good fixture leaves sources unchanged" "$?"

# ---- bad fixture: every needle names the item that carries the defect ----
new_case bad
cat >"$C/apply.md" <<'MD'
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

### A1 [required] §3.1, p. 14 (A 6)
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
cat >"$C/review.md" <<'MD'
| # | location | type | class | current sentence | problem | proposal |
|---|---|---|---|---|---|---|
| R1 | p.14, a.tex:3 | grammar | required | The gate are applied | agreement | is applied |
| R3 | p.20, b.tex:3 | duplication | recommended | The pretrained model | repeated line | delete one |
MD
cat >"$C/report.md" <<'MD'
| # | class | reason |
|---|---|---|
| R1 | required | agreement |
MD
out="$(run "$C/apply.md" "A=$A" "B=$B" --banned "$BANNED" --review "$C/review.md" --report "$C/report.md")"; rc=$?
[ "$rc" = "1" ]; check "bad fixture exits 1" "$?"
has "$out" "FAIL B1: primary: current block occurs 2 times"; check "bad: duplicate anchor" "$?"
has "$out" "FAIL A7: primary: current block occurs 0 times"; check "bad: missing anchor" "$?"
has "$out" "FAIL B2: primary: numbers removed"; check "bad: number change" "$?"
has "$out" "FAIL B2: primary: ref/cite/label removed"; check "bad: removed \\ref is a FAIL, not a REVIEW" "$?"
has "$out" "FAIL B2: primary: new formatting command ['vspace']"; check "bad: new \\vspace" "$?"
has "$out" "FAIL A1: primary: banned variant"; check "bad: banned phrase" "$?"
has "$out" "FAIL A3: current block overlaps A2"; check "bad: overlap" "$?"
has "$out" "FAIL -: reviewer finding R3 has no row in the report"; check "bad: missing report row" "$?"

# ---- banned variants ----
new_case banned-literal
{ item BL1 required 'the pre-trained encoder is frozen' 'the pretrained encoder is frozen'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL BL1: primary: banned variant 'pretrained'"; check "banned: a literal variant fails" "$?"

new_case banned-false-positives
{
  item P1 required '\textcolor{red}{Results} improved' '\textcolor{red}{Results} improve'
  item P2 required 'on the data settings,' 'on the data settings;'
  item P3 required 'shown in Figure~\ref{fig:pretrained-loss}.' 'shown in Figure~\ref{fig:pretrained-loss}!'
  item P4 required '% crucial: keep this note
The ResNet-R101 backbone is used.' '% crucial: keep this note
The ResNet-R101 backbone is adopted.'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED")"; rc=$?
check "banned: no false FAIL for a key, a kept comment, \\textcolor or 'data settings'" "$rc"
has "$out" "FAIL 0"; check "banned: the four false positives report FAIL 0" "$?"

# ---- references and citations ----
new_case cite-removal
{
  item K1 required 'Prior work~\textcite{knuth} and \cite{lee}' 'Prior work and \cite{lee}'
  item K2 required 'see [@knuth; @other, p. 3] and' 'see and'
  item K3 required '@doe2020 for details.' 'for details.'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ]; check "removed citations: exit 1" "$?"
has "$out" "FAIL K1: primary: ref/cite/label removed"; check "removed \\textcite fails" "$?"
has "$out" "FAIL K2: primary: ref/cite/label removed"; check "removed [@key; @other] fails" "$?"
has "$out" "FAIL K3: primary: ref/cite/label removed"; check "removed in-text @key fails" "$?"

# ---- line breaks and formatting commands ----
new_case linebreak-added
{ item L1 required 'We evaluate on 1,200 utterances' 'We evaluate on 1,200 utterances \\'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL L1: primary: line break count changed from 0 to 1"; check "added \\\\ line break fails" "$?"

new_case linebreak-removed
{ item L2 required 'First part \\ second part.' 'First part second part.'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL L2: primary: line break count changed from 1 to 0"; check "removed \\\\ line break fails" "$?"

new_case noindent-removed
{ item F1 required '\noindent Prior work' 'Prior work'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL F1: primary: formatting command removed ['noindent']"; check "removed \\noindent fails" "$?"

new_case blank-line
{ item V1 required '(Table~\ref{tab:latency}).
It is worth' '(Table~\ref{tab:latency}).

It is worth'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "0" ] && has "$out" "REVIEW V1: primary: paragraph break count changed from 0 to 1"; check "an inserted blank line is a REVIEW" "$?"

# ---- numbers and math ----
new_case numbers-precision
{ item N1 required 'each request increase by 4.2~ms' 'each request increases by 4.3~ms' 'Numbers: removed 92.1 (a different value)'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL N1: primary: numbers removed ['4.2'], added ['4.3']"; check "a Numbers: line downgrades only the values it lists" "$?"

new_case escaped-dollars
{ item M1 required 'The cost is \$5 per run and \$10 for tuning.' 'The cost is \$5 per run, and \$10 for tuning.'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "0" ] && lacks "$out" "math removed"; check "escaped dollars are not math" "$?"

new_case display-math
{
  item D1 required '\[ E = mc^2 \]' '\[ F = mc^2 \]'
  item D2 required '\begin{equation} x = y + z \end{equation}' '\begin{equation} x = y - z \end{equation}'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL D1: primary: math removed"; check "a changed \\[ \\] display fails" "$?"
has "$out" "FAIL D2: primary: math removed"; check "a changed equation environment fails" "$?"

# ---- structure of the apply file ----
new_case zero-items
printf '# Apply-ready file\n\nNothing here.\n' >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL -: no items parsed"; check "zero items fail" "$?"

new_case indented-heading
{
  item OK1 required 'We evaluate on 1,200 utterances' 'We evaluate on 1,200 utterances'
  printf '    ### R7 [required] §3 (A 1)\n#### R8 [required] §3 (A 1)\n'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL -: item heading must start at column 0 as '### ': ### R7 [required]"; check "an indented heading fails" "$?"
has "$out" "FAIL -: item heading must start at column 0 as '### ': #### R8 [required]"; check "a #### heading fails" "$?"

new_case duplicate-id
{
  item DUP required 'We evaluate on 1,200 utterances' 'We assess on 1,200 utterances'
  item DUP required 'each request increase by 4.2~ms' 'each request increases by 4.2~ms'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL -: duplicate item id DUP"; check "a duplicate item id fails" "$?"

new_case unknown-class
{ item UC1 requried 'each request increase by 4.2~ms' 'each request increases by 4.2~ms'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL UC1: unknown class [requried]"; check "an unknown class fails" "$?"

# ---- dependencies and sequential application ----
new_case dependency-chain
{
  item C1 required 'each request increase by 4.2~ms' 'each request increases by 4.2~ms'
  item C2 recommended 'each request increases by 4.2~ms' 'each request grows by 4.2~ms' 'Depends on: C1'
  item C3 recommended 'each request grows by 4.2~ms' 'every request grows by 4.2~ms' 'Depends on: C2'
} >"$C/apply.md"
COPY="$C/copy"
cp -RL "$SRC" "$COPY"
out="$(run "$C/apply.md" "A=$A" --apply-into "$SRC=$COPY")"; rc=$?
[ "$rc" = "0" ] && has "$out" "FAIL 0"; check "a valid chain C1<-C2<-C3 passes" "$?"
grep -qF 'every request grows by 4.2~ms' "$COPY/chapters/a.tex"; check "the chain applies in order into the copy" "$?"
sources_unchanged; check "chain: sources unchanged" "$?"

new_case dependency-cycle
{
  item X1 required 'each request increase by 4.2~ms' 'each request increases by 4.2~ms' 'Depends on: X2'
  item X2 required 'We evaluate on 1,200 utterances' 'We assess on 1,200 utterances' 'Depends on: X1'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL X1: dependency cycle"; check "a dependency cycle fails" "$?"

new_case simulation
{
  item S1 required 'We evaluate on 1,200 utterances' 'We evaluate on 1,200 utterances from two corpora'
  item S2 required 'from two corpora' 'from both corpora'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL S2: sequential application fails for classes required,recommended"; check "check mode dry-runs the sequential application" "$?"

new_case nested-overlap
{
  item OX required 'The gate are applied before decoding, therefore the latency of
each request increase by 4.2~ms' 'The gate is applied before decoding, so the latency of
each request increases by 4.2~ms'
  item OY required 'The gate are applied' 'The gate is applied'
  item OZ required 'each request increase' 'each request increases'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL OY: current block overlaps OX"; check "nested overlap reports the first inner block" "$?"
has "$out" "FAIL OZ: current block overlaps OX"; check "nested overlap reports the second inner block" "$?"

new_case missing-dependency-key
{
  printf '### D1 [required] §4 (B 2)\nCurrent:\n~~~latex\nThe pretrained model was fine-tuned for 10 epochs.\n~~~\nReplacement:\n~~~latex\nThe model was fine-tuned for 10 epochs.\n~~~\n\n'
  item D2 required 'each request increase by 4.2~ms' 'each request increases by 4.2~ms' 'Depends on: D1'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A" --apply-into "$SRC=$C/out")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL D1: file key B was not given" && lacks "$out" "Traceback"; check "a dependency with an unknown file key is a FAIL line, not a traceback" "$?"
[ ! -e "$C/out" ]; check "missing dependency key: nothing written" "$?"

# ---- coverage ----
new_case coverage
write_good_apply
cat >"$C/review.md" <<'MD'
| # | location | type | class | current sentence | problem | proposal |
|---|---|---|---|---|---|---|
| R1 | p.14 | naming | required | the ResNet-R101 backbone | spelling | keep |
| R2 | p.14 | grammar | required | The gate are applied | agreement | is applied |
MD
cat >"$C/report.md" <<'MD'
Finding R2 is discussed in prose only.

| # | class | reason |
|---|---|---|
| R1b | required | kept |
MD
out="$(run "$C/apply.md" "A=$A" "B=$B" --review "$C/review.md" --report "$C/report.md")"
lacks "$out" "FAIL -: reviewer finding R101"; check "ResNet-R101 is not taken as a finding id" "$?"
has "$out" "FAIL -: reviewer finding R2 has no row in the report"; check "a mention outside a table row is not coverage" "$?"
lacks "$out" "FAIL -: reviewer finding R1 "; check "a row id with a letter suffix covers its finding" "$?"
printf 'R1 and R2 as plain text, no table\n' >"$C/review.md"
printf 'R1 R2\n' >"$C/report.md"
out="$(run "$C/apply.md" "A=$A" "B=$B" --review "$C/review.md" --report "$C/report.md")"
has "$out" "REVIEW -: review.md has no findings table"; check "no table ids falls back to the scrape with a REVIEW line" "$?"

# ---- --apply-into ----
new_case apply
write_good_apply
COPY="$C/copy"
cp -R "$SRC" "$COPY"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$COPY")"; rc=$?
check "apply-into a copy exits 0" "$rc"
has "$out" "wrote $COPY/chapters/a.tex"; check "apply-into reports the write" "$?"
grep -qF 'The gate is applied before decoding. Each request therefore runs' "$COPY/chapters/a.tex" \
  && grep -qF 'The pre-trained encoder is frozen to' "$COPY/chapters/a.tex"
check "copy holds the expected text (R1, E2 after R1, R2)" "$?"
grep -qF 'crucial for the final accuracy' "$COPY/chapters/a.tex"; check "a default apply-into leaves the optional item E1 unapplied" "$?"
sources_unchanged; check "sources unchanged after apply-into" "$?"
[ -z "$(find "$COPY" -name '.aep-*')" ]; check "no temp file is left behind" "$?"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/copy2" --classes required,recommended,optional)"; rc=$?
[ "$rc" = "0" ] && [ -f "$C/copy2/chapters/a.tex" ] && ! grep -qF 'crucial for the final accuracy' "$C/copy2/chapters/a.tex"; check "--classes with optional applies E1" "$?"

new_case items
write_good_apply
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/c1" --items E2)"; rc=$?
[ "$rc" = "0" ] && grep -qF 'Each request therefore runs' "$C/c1/chapters/a.tex" \
  && grep -qF 'It is worth noting that' "$C/c1/chapters/a.tex"
check "--items E2 applies E2 and its dependency R1, and not R2" "$?"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/c2" --items E1)"; rc=$?
[ "$rc" = "0" ] && ! grep -qF 'crucial for the final accuracy' "$C/c2/chapters/a.tex" \
  && grep -qF 'The gate are applied' "$C/c2/chapters/a.tex"
check "--items E1 applies an optional item and nothing else" "$?"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/c3" --items NOPE)"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL -: --items: unknown item id NOPE" && [ ! -e "$C/c3" ]; check "--items with an unknown id fails and writes nothing" "$?"
sources_unchanged; check "--items: sources unchanged" "$?"

new_case crlf
write_good_apply
python3 -I -c 'import sys
p = sys.argv[1]
d = open(p, "rb").read().replace(b"\n", b"\r\n")
open(p, "wb").write(d)' "$A"
sha_a="$(sha256_of "$A")"
COPY="$C/copy"
cp -R "$SRC" "$COPY"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$COPY")"; rc=$?
[ "$rc" = "0" ]; check "CRLF source: apply-into exits 0" "$?"
python3 -I -c 'import sys
raw = open(sys.argv[1], "rb").read()
sys.exit(0 if b"The gate is applied" in raw and raw.count(b"\n") == raw.count(b"\r\n") else 1)' "$COPY/chapters/a.tex"
check "CRLF source: the copy is written with CRLF throughout" "$?"
sources_unchanged; check "CRLF source: sources unchanged" "$?"

# ---- second round: one case per review item ----

# 1. banned variants ignore trailing comments and url arguments, not an escaped percent
new_case banned-comment-url
{
  item T1a required 'Plain text % crucial: note in order to keep' 'Plain prose % crucial: note in order to keep'
  item T1b required 'See \url{https://x.org/pretrained-models/v1} for details.' 'See \url{https://x.org/pretrained-models/v1} for more.'
  item T1c required 'Rate 5\% here.' 'Rate 5\% in order to here.'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL T1c: primary: banned variant"; check "banned: an escaped \\% does not hide a banned phrase" "$?"
lacks "$out" "FAIL T1a:"; check "banned: a kept trailing comment is ignored" "$?"
lacks "$out" "FAIL T1b:"; check "banned: a kept \\url argument is ignored" "$?"

# 2. a Removed: or Numbers: line downgrades only what it names
new_case removed-verbatim
{
  item R2a required 'of $92.1\%$.' 'of 92.1 percent.' 'Removed: \cite{lee}'
  item R2b required '\[ E = mc^2 \]' 'E = mc^2' 'Removed: \[ E = mc^2 \]'
  item R2c required '% crucial: keep this note
The ResNet-R101 backbone is used.' 'The ResNet-R101 backbone is used.' 'Removed: \cite{lee}'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL R2a: primary: math removed"; check "Removed: \\cite{lee} does not cover a dropped math" "$?"
has "$out" "FAIL R2c: primary: comment line removed"; check "Removed: \\cite{lee} does not cover a dropped comment line" "$?"
has "$out" "REVIEW R2b: primary: math removed"; check "a math copied verbatim on the Removed: line is a REVIEW" "$?"
lacks "$out" "FAIL R2b:"; check "a listed math removal is not a FAIL" "$?"

new_case numbers-backticks
{
  item N2a required 'The model has 4 layers.' 'The model has layers.' 'Numbers: removed 1,200 (stays in Table 4)'
  item N2b required 'The decoder has 6 heads.' 'The decoder has heads.' 'Numbers: removed `6` (stays in Table 4)'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL N2a: primary: numbers removed ['4']"; check "a value in prose on the Numbers: line is not listed" "$?"
has "$out" "REVIEW N2b: primary: numbers removed ['6']"; check "a backticked value on the Numbers: line is a REVIEW" "$?"
lacks "$out" "FAIL N2b:"; check "a backticked value is not a FAIL" "$?"

# 3. a legend heading without the location tail is allowed
new_case legend-heading
{
  printf '# Apply-ready file\n## Classes [required = an error; recommended = a clear improvement; optional = taste]\n\n'
  item G1 required 'each request increase by 4.2~ms' 'each request increases by 4.2~ms'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "0" ] && has "$out" "FAIL 0"; check "a legend line '## Classes [required = ...]' is not an item heading" "$?"

# 4. bare brace keys on the Removed: line cover a removed key
new_case removed-bare-keys
{
  item K4a required 'As shown by \cite[p.~5]{smith2024} here.' 'As shown by here.' 'Removed: smith2024 (moved to E4)'
  item K4b required 'Also \citep{lee,kim} there.' 'Also there.' 'Removed: lee (moved)'
  item K4c required 'Also \citep{wu,xu} there too.' 'Also there too.' 'Removed: wu and xu (moved)'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
has "$out" "REVIEW K4a: primary: ref/cite/label removed"; check "a bare key on the Removed: line covers \\cite[p.~5]{key}" "$?"
lacks "$out" "FAIL K4a:"; check "a covered key is not a FAIL" "$?"
[ "$rc" = "1" ] && has "$out" "FAIL K4b: primary: ref/cite/label removed"; check "multi-key braces: one listed key is not enough" "$?"
has "$out" "REVIEW K4c: primary: ref/cite/label removed"; check "multi-key braces: every key listed is covered" "$?"
lacks "$out" "FAIL K4c:"; check "multi-key braces: a fully listed removal is not a FAIL" "$?"

# 5. --items blocks the write only on FAILs of the picked items (and file-level FAILs)
new_case items-block
{
  item R5a required 'each request increase by 4.2~ms' 'each request increases by 4.2~ms'
  item R5b required 'We evaluate on 1,200 utterances' 'We evaluate on 1,200 crucial utterances'
} >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED" --apply-into "$SRC=$C/copy_one" --items R5a)"; rc=$?
has "$out" "wrote $C/copy_one/chapters/a.tex" && grep -qF 'increases by 4.2~ms' "$C/copy_one/chapters/a.tex" \
  && grep -qF 'We evaluate on 1,200 utterances' "$C/copy_one/chapters/a.tex"
check "--items R5a writes although the unpicked R5b fails a banned check" "$?"
[ "$rc" = "1" ] && has "$out" "FAIL R5b:"; check "--items: the unpicked FAIL is still reported and exits 1" "$?"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED" --apply-into "$SRC=$C/o2" --items R5b)"
lacks "$out" "wrote" && [ ! -e "$C/o2" ]; check "--items R5b (a failing picked item) writes nothing" "$?"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED" --apply-into "$SRC=$C/copy_three")"
lacks "$out" "wrote" && [ ! -e "$C/copy_three" ]; check "class mode still writes nothing while any item fails" "$?"
out="$(run "$C/apply.md" "A=$A" --banned "$BANNED" --apply-into "$SRC=$C/o4" --items R5a,NOPE)"
lacks "$out" "wrote" && [ ! -e "$C/o4" ]; check "--items: a file-level FAIL (unknown id) blocks the write" "$?"
sources_unchanged; check "--items block: sources unchanged" "$?"

# 6. an escaped backslash before $ does not escape it
new_case dollar-parity
{ item L6 required 'alpha \\$a$ and beta $b$ end.' 'alpha \\$a$ and gamma $b$ end.'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "0" ] && lacks "$out" "math removed"; check "alpha \\\\\$a\$ ...: no false math removal" "$?"

# 7. targets must stay inside DEST_ROOT, and SRC_ROOT must not sit inside it
new_case dest-symlink-elsewhere
write_good_apply
mkdir "$C/elsewhere"
printf 'unrelated a\n' >"$C/elsewhere/a.tex"
printf 'unrelated b\n' >"$C/elsewhere/b.tex"
sha_ea="$(sha256_of "$C/elsewhere/a.tex")"
sha_eb="$(sha256_of "$C/elsewhere/b.tex")"
cp -R "$SRC" "$C/after"
rm -rf "${C:?}/after/chapters"
ln -s "$C/elsewhere" "$C/after/chapters"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/after")"; rc=$?
[ "$rc" != "0" ] && has "$out" "resolves outside DEST_ROOT"; check "a symlinked DEST folder pointing elsewhere is refused" "$?"
[ "$(sha256_of "$C/elsewhere/a.tex")" = "$sha_ea" ] && [ "$(sha256_of "$C/elsewhere/b.tex")" = "$sha_eb" ]; check "the unrelated files behind the symlink are unchanged" "$?"
sources_unchanged; check "symlinked DEST folder: sources unchanged" "$?"

new_case src-inside-dest
write_good_apply
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC/chapters=$SRC")"; rc=$?
[ "$rc" != "0" ] && has "$out" "lies inside DEST_ROOT"; check "SRC_ROOT inside DEST_ROOT is refused" "$?"
[ ! -e "$SRC/a.tex" ]; check "SRC inside DEST: nothing written" "$?"
sources_unchanged; check "SRC inside DEST: sources unchanged" "$?"

# 8. coverage rows: emphasis, a trailing note in the cell, no leading pipe
new_case coverage-forms
write_good_apply
cat >"$C/review.md" <<'MD'
| # | location | problem |
|---|---|---|
| **R1** | p.1 | a |
| R2 | p.2 | b |
R3 | p.3 | c
| _R4_ | p.4 | d
MD
cat >"$C/report.md" <<'MD'
| # | class |
|---|---|
| **R1** | required |
| R2 (no change) | required |
R3 | required
| _R4_ | required
MD
out="$(run "$C/apply.md" "A=$A" "B=$B" --review "$C/review.md" --report "$C/report.md")"; rc=$?
[ "$rc" = "0" ] && lacks "$out" "reviewer finding"; check "coverage: **R1**, 'R2 (no change)', a pipe-less R3 and _R4_ all count" "$?"
printf '| R1 | a |\n| R5 | b |\n' >"$C/review.md"
printf '| R1 | ok |\n' >"$C/report.md"
out="$(run "$C/apply.md" "A=$A" "B=$B" --review "$C/review.md" --report "$C/report.md")"
has "$out" "FAIL -: reviewer finding R5 has no row in the report"; check "coverage: a finding without a report row still fails" "$?"

# 9. bad input is a one-line error with exit status 2
new_case bad-input
write_good_apply
out="$(run "$C/apply.md" "A")"; rc=$?
[ "$rc" = "2" ] && has "$out" "check_apply: file argument 'A' must be written as NAME=PATH" && lacks "$out" "Traceback"; check "a KEY argument without = is a one-line error, exit 2" "$?"
out="$(run "$C/apply.md" "A=$A" --apply-into nopair)"; rc=$?
[ "$rc" = "2" ] && has "$out" "check_apply: --apply-into argument 'nopair' must be written as NAME=PATH" && lacks "$out" "Traceback"; check "--apply-into without = is a one-line error, exit 2" "$?"
printf 'caf\xe9 not utf-8\n' >"$C/latin1.tex"
out="$(run "$C/apply.md" "A=$C/latin1.tex")"; rc=$?
[ "$rc" = "2" ] && has "$out" "latin1.tex is not valid UTF-8" && lacks "$out" "Traceback" && [ "$(wc -l <<<"$out" | tr -d ' ')" = "1" ]; check "a non-UTF-8 source is a one-line error, exit 2" "$?"
printf '# comment\npretrained\nre:(unclosed\n' >"$C/bad-banned.txt"
out="$(run "$C/apply.md" "A=$A" --banned "$C/bad-banned.txt")"; rc=$?
[ "$rc" = "2" ] && has "$out" "bad-banned.txt line 3: bad regular expression" && lacks "$out" "Traceback"; check "a bad re: line in the banned file is named, exit 2" "$?"

# ---- third round ----

# 1. in Markdown a % is a literal percent, not a comment
new_case markdown-percent
printf 'Accuracy improves by 5%% and the gain is solid\n' >"$C/c.md"
{ item MD1 required 'by 5% and the gain is solid' 'by 5% and the gain is crucial'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$C/c.md" --banned "$BANNED")"; rc=$?
[ "$rc" = "1" ] && has "$out" "FAIL MD1: primary: banned variant '"; check "a banned word after a literal % in a .md file fails" "$?"

# 2. whitespace is collapsed before the verbatim Removed: comparison
new_case removed-whitespace
{ item W1 required '\begin{equation}
L = a + b
\end{equation}' '' 'Removed: \begin{equation} L = a + b \end{equation} (stays in §2)'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "0" ] && has "$out" "REVIEW W1: primary: math removed" && lacks "$out" "FAIL W1:"; check "a math listed on one line covers the same math over three lines" "$?"

# 3. Numbers: values are read with numbers(), so 1{,}200 is 1,200
new_case numbers-thousands
{ item N3 required 'The corpus has 1{,}200 clips.' 'The corpus has clips.' 'Numbers: removed `1{,}200` (stays in Table 2)'; } >"$C/apply.md"
out="$(run "$C/apply.md" "A=$A")"; rc=$?
[ "$rc" = "0" ] && has "$out" "REVIEW N3: primary: numbers removed ['1,200']" && lacks "$out" "FAIL N3:"; check "a backticked 1{,}200 lists the number 1,200" "$?"

# ---- refusals: each starts from pristine sources ----
new_case symlink-folder
write_good_apply
LINKDIR="$C/linkdir"
cp -R "$SRC" "$LINKDIR"
rm -rf "${LINKDIR:?}/chapters"
ln -s "$SRC/chapters" "$LINKDIR/chapters"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$LINKDIR")"; rc=$?
[ "$rc" != "0" ]; check "symlinked chapters folder: non-zero exit" "$?"
has "$out" "refusing to write"; check "symlinked chapters folder: refused for the right reason" "$?"
lacks "$out" "wrote"; check "symlinked chapters folder: no wrote line" "$?"
sources_unchanged; check "symlinked chapters folder: sources unchanged" "$?"

new_case symlink-file
write_good_apply
LINKFILE="$C/linkfile"
cp -R "$SRC" "$LINKFILE"
rm -f "${LINKFILE:?}/chapters/a.tex"
ln -s "$A" "$LINKFILE/chapters/a.tex"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$LINKFILE")"; rc=$?
[ "$rc" != "0" ]; check "symlinked chapter file: non-zero exit" "$?"
has "$out" "refusing to write"; check "symlinked chapter file: refused for the right reason" "$?"
lacks "$out" "wrote"; check "symlinked chapter file: no wrote line" "$?"
sources_unchanged; check "symlinked chapter file: sources unchanged" "$?"

new_case hard-link
write_good_apply
HARD="$C/hard"
cp -R "$SRC" "$HARD"
rm -f "${HARD:?}/chapters/a.tex"
ln "$A" "$HARD/chapters/a.tex"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$HARD")"; rc=$?
[ "$rc" != "0" ]; check "hard-linked target: non-zero exit" "$?"
has "$out" "is the same file as a source"; check "hard-linked target: refused for the right reason" "$?"
lacks "$out" "wrote"; check "hard-linked target: no wrote line" "$?"
sources_unchanged; check "hard-linked target: sources unchanged" "$?"

new_case hard-link-other
write_good_apply
OTHER="$C/other.tex"
cp "$A" "$OTHER"
sha_other="$(sha256_of "$OTHER")"
HARD="$C/hard"
cp -R "$SRC" "$HARD"
rm -f "${HARD:?}/chapters/a.tex"
ln "$OTHER" "$HARD/chapters/a.tex"
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$HARD")"; rc=$?
[ "$rc" = "0" ] && grep -qF 'The gate is applied before decoding' "$HARD/chapters/a.tex"; check "a hard link to a non-source file: the copy is written" "$?"
[ "$(sha256_of "$OTHER")" = "$sha_other" ]; check "a hard link to a non-source file is replaced, never written through" "$?"
sources_unchanged; check "hard link to a non-source file: sources unchanged" "$?"

new_case dest-inside-src
write_good_apply
out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$SRC/inner")"; rc=$?
[ "$rc" != "0" ]; check "DEST inside SRC: non-zero exit" "$?"
has "$out" "refusing to write"; check "DEST inside SRC: refused for the right reason" "$?"
lacks "$out" "wrote"; check "DEST inside SRC: no wrote line" "$?"
[ ! -e "$SRC/inner" ]; check "DEST inside SRC: nothing created" "$?"
sources_unchanged; check "DEST inside SRC: sources unchanged" "$?"

new_case case-alias
write_good_apply
mkdir "$TMP_ROOT/CaseProbe"
if [ -d "$TMP_ROOT/caseprobe" ]; then
  out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/SRC")"; rc=$?
  [ "$rc" != "0" ]; check "case-alias DEST: non-zero exit" "$?"
  has "$out" "refusing to write"; check "case-alias DEST: refused for the right reason" "$?"
  sources_unchanged; check "case-alias DEST: sources unchanged" "$?"
  out="$(run "$C/apply.md" "A=$A" "B=$B" --apply-into "$SRC=$C/SRC/inner")"; rc=$?
  [ "$rc" != "0" ] && has "$out" "refusing to write" && [ ! -e "$SRC/inner" ]; check "case-alias DEST below the sources: refused, nothing created" "$?"
else
  echo "n/a   case-alias DEST (case-sensitive filesystem): the directory-ancestor walk is exercised only by this case, which needs a case-insensitive filesystem such as macOS; the hard-link cases exercise same_file(target, source)"
fi

echo
echo "passed $pass, failed $fail"
[ "$fail" = "0" ]
