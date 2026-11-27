---
name: academic-english-polish
description: Two-pass English academic-writing review, proofreading and polish for papers and theses (LaTeX or Markdown) — unanchored reviewer pass → editor pass that rewrites every finding → mechanical checks of the apply-ready Current/Replacement file. Proposals only; the document is never edited
user-invocable: true
---

<Purpose>
academic-english-polish runs the two-pass English editing method as one workflow. An unanchored reviewer pass finds the problems, a separate editor pass rewrites every finding and the weak sentences around it, and the orchestrator checks the result mechanically before the user sees it. Each run leaves two files: a readable before/after report and an apply-ready file whose Current blocks match the sources exactly once. Nothing in the document changes.
</Purpose>

<Use_When>
- A paper, thesis chapter, appendix, abstract or rebuttal written in English needs proofreading, copy-editing or polishing ("polish the English in chapter 3", "proofread the appendix", "copy-edit the abstract")
- Terms, abbreviations or spellings drift across chapters and need one form
- A page limit has to be met by rewording, not by formatting
</Use_When>

<Do_Not_Use_When>
- The text is not English, or it is code, comments or a README
- The question is about the science rather than the prose (method validity, missing experiments): use a domain reviewer
- The user wants the document edited in place now. This skill only proposes; see "After approval"
</Do_Not_Use_When>

<Why_This_Exists>
Single-pass polishing fails in three predictable ways:
1. The editor fixes what it was told and misses the rest, because its first read was anchored on someone's diagnosis.
2. Rewrites drift: a number moves, a \ref key disappears, a spacing command slips in, a term comes back in its rejected spelling.
3. Proposals do not apply: a "current" snippet is retyped from the PDF, matches twice or not at all, and the author ends up editing by hand.
This skill separates finding from fixing, fixes the output format so that every proposal applies, and verifies mechanically before anything is shown.
</Why_This_Exists>

<Steps>

## Step 0: Prepare (orchestrator)

1. **File map**: give each scope file a key (A = paper/chapters/ch3.tex, B = …). List every source file of the document, in document order, for term counts. The build's recorder file gives it even when a class macro loads the chapters: `grep -E '^INPUT (\./)?[^/].*\.tex$' <build dir>/main.fls | sed 's|^INPUT \./|INPUT |' | awk '!seen[$0]++'`. Without a .fls file, follow the main file's \input, \include and class-specific loading commands.
2. **Output directory**: a new directory outside the source tree that the agent's workspace-write sandbox can write to, normally `${TMPDIR:-/tmp}/en_polish/<YYYY-MM-DD>-<topic>/` (`<out>` below). If your sandbox configuration excludes temporary folders, use a git-ignored folder inside the workspace. Both passes write there.
3. **Baseline checksums**: `shasum -a 256 <every source file> > <out>/sources.sha256`.
4. **Build outputs**: if the PDF or the .aux file is missing or older than the sources, never build in the source tree. Copy the paper folder (`mkdir -p <out>/before && cp -RL <paper dir>/. <out>/before/`; `-L` dereferences symlinks, so a build or `--apply-into` can never write into the sources through a symlinked folder) and build the copy with the project's own command (for example `latexmk -cd -pdf <out>/before/main.tex`). Pass that PDF and .aux to both passes.
5. **User concerns**: keep any problem the user named for Step 2. The reviewer never sees it.

## Step 1: Reviewer pass (unanchored)

Spawn the agent: `spawn_agent` with `agent_type = "academic-english-editor"`.

The prompt holds only: `mode: review`, the file map, the source list, the build outputs, the style guide if one exists, and `<out>`. It holds no opinion about the text, no user concern and no earlier review. Wait for `<out>/review.md`.

## Step 2: Editor pass (a fresh agent)

Spawn a new agent, not a continuation of the reviewer: `spawn_agent` with `agent_type = "academic-english-editor"`, `mode: edit`, the same inputs, the path of `review.md`, and the user's concerns as extra findings. Wait for `<out>/report.md` and `<out>/apply.md`.

## Step 3: Verify (orchestrator; never skip)

1. Write `<out>/banned.txt`: the rejected variants from the term table (d) of the report, one per line, plus the banned-phrase lines in Verification_Checklist item 5.
2. Run the reference checker, which sits next to this file (normally `~/.codex/skills/academic-english-polish/check_apply.py`):

       python3 -I <skill dir>/check_apply.py <out>/apply.md A=<path> B=<path> \
         --banned <out>/banned.txt --review <out>/review.md --report <out>/report.md

3. Every FAIL line must be fixed. Judge every REVIEW line: is a number on the Numbers: line really a listed deletion or a name, does the item explain its new \ref, is a removed \ref listed on its Removed: line.
4. Run the checks the script does not cover (Verification_Checklist items 6 and 7).

## Step 4: Revision round

Send every FAIL, and every REVIEW line you reject, to the editor with the item ids and the checker lines (`resume_agent` on the Step 2 editor; if it cannot be resumed, spawn a fresh editor with the paths of review.md, report.md and apply.md plus the checker lines). Then repeat Step 3. Stop after two rounds and list whatever is still open in the summary.

## Step 5: Page shifts

When the report or the user states a page or line effect ("saves half a page", "keeps chapter 4 within 20 pages"), measure it:
1. Copy the paper folder again (`mkdir -p <out>/after && cp -RL <paper dir>/. <out>/after/`), then apply the required and recommended items into that copy: `python3 -I <skill dir>/check_apply.py <out>/apply.md A=<path> … --apply-into <paper dir>=<out>/after`.
2. Build `<out>/before` (make it as in Step 0 if it does not exist yet) and `<out>/after` with the same command.
3. Compare the page counts (`pdfinfo <copy>/main.pdf`) and the start page of each affected section (from each copy's .aux). Report measured numbers only.

## Step 6: Deliver

1. Tell the user, in 30 lines or fewer: the paths of report.md and apply.md, item counts per class, the main recurring problems, the [confirm] items, the disagreements with the reviewer, and the verification results.
2. If the project has a `.briefing/` vault, copy report.md to `.briefing/agents/<YYYY-MM-DD>-academic-english-editor.md` and apply.md to `.briefing/agents/<YYYY-MM-DD>-academic-english-editor-apply.md`, each with one verification line on top, for example: "Verified: 62/62 Current blocks unique, numbers unchanged, banned variants 0, sources unchanged. Not applied."

## After approval (a separate step, only on the user's request)

Apply only the items the user picks: write applied copies with `--apply-into`, naming the picked ids with `--items R3,E2` (the checker adds the items they depend on, whatever their class; without `--items`, `--classes` selects whole classes; with `--items` the copies of the picked items are written but the exit status stays 1 while an unpicked item still FAILs, so do not stop on the exit status there), show `diff -u` against the sources, and copy the files over the sources only after the user agrees. Then run Verification_Checklist items 6 and 7 again.

</Steps>

<Outputs>
Defined by the agent: `review.md` (findings table and keep list), `report.md` (header and sections a–e) and `apply.md` (one `### <id> [<class>] <location> (<key> <lines>)` item per proposal, with Current/Replacement blocks and optional `Depends on:`, `Numbers:`, `Removed:` and `Note:` lines). Classes: required = an error; recommended = a clear improvement; optional = taste or a structural cut.
</Outputs>

<Verification_Checklist>
Run after every editor round. check_apply.py automates items 1–5 and 8.
1. **Anchors**: every Current block, primary or alternative, matches exactly once in its file (or once after its Depends on item is applied), and the primary Current blocks of one file do not overlap.
2. **Numbers**: per item, the multiset of numbers in Replacement equals the one in Current, except values the item lists, in backticks, on its Numbers: line as a deletion (the value stays elsewhere) or as a name (for example a model name).
3. **No new formatting**: no Replacement adds a formatting, spacing or template command. Any other new command (\ref, \textsc) is explained in the item.
4. **References**: \ref, \cref, \eqref, \cite and \label keys, math and comment lines are kept, except what the item copies verbatim (or, for a key, names) on its Removed: line.
5. **Banned variants**: no rejected term variant and no banned phrase appears in any Replacement or Alternative block. Banned-phrase lines for banned.txt (delete a line where the document uses the word as a defined term):

       re:(?i)\bdelve
       re:(?i)\bcrucial
       re:(?i)\bpivotal
       re:(?i)\bnotably\b
       re:(?i)\bit is worth noting
       re:(?i)\bplays? an? (?:key|crucial|pivotal|vital) role
       re:(?i)\butili[sz](?:e|es|ed|ing|ation)\b
       re:(?i)\bseamless
       re:(?i)\bin order to\b
       re:(?i)\b(?:may|might|could) (?:potentially|possibly)\b

6. **Page shifts**: every stated page or line effect was measured on built copies (Step 5); anything else is labelled as an estimate.
7. **Sources unchanged**: `shasum -a 256 -c <out>/sources.sha256` passes.
8. **Coverage**: every reviewer finding R<n> has a row in the report.
</Verification_Checklist>

<Model_Guidance>
- The agent pins the strongest tier: `gpt-6-astra` at `model_reasoning_effort = "xhigh"`, the highest effort this repo documents. Do not pass a lighter model.
- If a spawn fails on a usage limit, spawn it once more with model `gpt-6.1-sol` (same effort) and say so in the summary. If that fails too, stop and report; never fall back to `gpt-6-luna`.
- Each agent's final message is 30 lines or fewer, and so is your summary to the user. The detail lives in the files.
</Model_Guidance>

<Escalation_And_Stop_Conditions>
- Stop and report if the sources change during the run (Verification_Checklist item 7 fails): the anchors can no longer be trusted.
- After two revision rounds with FAIL lines left, deliver with those items marked unverified; never call them apply-ready.
- If a copy fails to build, report the build error and skip Step 5; never present an estimate as a measurement.
- Never edit a source file, never build in the source tree, and never ask the agent to apply its own proposals.
</Escalation_And_Stop_Conditions>

<Examples>
<Good>
Reviewer prompt (Step 1):
```
mode: review
Scope: A = paper/chapters/ch4.tex, B = paper/chapters/appendix_b.tex
Sources: paper/main.tex and the 11 files it inputs (listed below)
Build outputs: <out>/before/main.pdf, <out>/before/main.aux (printed page = PDF page - 18)
Style guide: none. Output directory: <out>/
```
Why good: scope and inputs only; nothing tells the reviewer what is wrong.
</Good>

<Good>
An apply.md item:
```
### R12 [required] §4.3, p. 61 (A 210–211)
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
```
Why good: the Current block is verbatim, line break included; the number, the \ref key and the ~ survive; no formatting command is added; two agreement errors and a comma splice are fixed, and "therefore" stays because the relation is causal.
</Good>

<Bad>
Reviewer prompt: "The introduction is wordy and Section 3 overuses 'crucial'. Review chapters 1–3."
Why bad: the reviewer is anchored on the user's diagnosis. Pass those concerns to the editor pass as U-findings.
</Bad>

<Bad>
Summary: "All 40 changes verified; the edits save about half a page."
Why bad: no checker output, no checksum check, and the page effect was estimated instead of measured on built copies.
</Bad>
</Examples>

<Final_Checklist>
- [ ] Sources checksummed before the passes and unchanged after them
- [ ] Reviewer pass ran unanchored: its prompt held only the scope and the inputs
- [ ] Editor pass ran in a fresh agent and produced report.md (a–e) and apply.md
- [ ] check_apply.py shows FAIL 0, and every REVIEW line was judged
- [ ] Page effects measured on built copies, or labelled as estimates
- [ ] Summary of 30 lines or fewer with both file paths; nothing applied to the sources
</Final_Checklist>
