#!/usr/bin/env python3
"""Check an apply-ready file (apply.md) against its source files.

Read-only unless --apply-into is given; even then it writes only under DEST_ROOT.

Usage:
  python3 -I check_apply.py apply.md A=paper/chapters/ch3.tex [B=...] [--banned banned.txt]
      [--review review.md --report report.md] [--apply-into paper=/tmp/run/after/paper]
      [--classes required,recommended] [--items R1,E2]

FAIL lines set exit status 1. REVIEW lines need a person's judgement.
--items applies exactly the listed items plus the items they depend on, whatever their class.
"""
import argparse
import os
import re
import stat
import sys
import tempfile
from collections import Counter

HEAD = re.compile(r"^### (\S+) \[([a-z]+)[^\]]*\].*\((\w+) \d")
LOOKS = re.compile(r"^\s*#+\s*\S+\s*\[[a-z][^\n]*\(\w+ \d")
TRAILING_COMMENT = re.compile(r"(?<!\\)((?:\\\\)*)%.*$")
LABEL = re.compile(r"^(Current|Replacement|Alternative \w+ (?:current|replacement)):$")
CLASSES = ("required", "recommended", "optional")
KEYS = re.compile(
    r"\\(?:[a-zA-Z]*cite[a-zA-Z]*|[a-zA-Z]*ref|label)\*?(?:\[[^\]]*\])*\{[^}]*\}"
    r"|\[[^\[\]]*@[A-Za-z0-9_][^\[\]]*\]"
    r"|(?<![\w@\\])@[A-Za-z0-9_](?:[\w:#$%&\-+?<>~/]|\.(?=\w))*")
PANDOC_KEY = re.compile(r"@([A-Za-z0-9_](?:[\w:#$%&\-+?<>~/]|\.(?=\w))*)")
MATH = re.compile(
    r"\$\$.+?\$\$"
    r"|(?<!\\)\$(?:\\.|[^$\\])+\$"
    r"|\\\[.+?\\\]"
    r"|\\\(.+?\\\)"
    r"|\\begin\{(equation|align|gather|multline|eqnarray)\*?\}.+?\\end\{\1\*?\}", re.S)
CMD = re.compile(r"\\([a-zA-Z]+)")
NUM = r"\d+(?:,\d{3})*(?:\.\d+)?"
FORMAT = set(
    "vspace hspace setlength addtolength small footnotesize scriptsize tiny large Large normalsize "
    "newline linebreak pagebreak newpage clearpage noindent looseness enlargethispage resizebox "
    "scalebox arraystretch tabcolsep smallskip medskip bigskip vfill hfill centering raggedright".split())
tally = Counter()
failed_items = set()


def die(msg):
    print(f"check_apply: {msg}", file=sys.stderr)
    raise SystemExit(2)


def split_pair(spec, what):
    if "=" not in spec or spec.startswith("=") or spec.endswith("="):
        die(f"{what} argument {spec!r} must be written as NAME=PATH")
    return spec.split("=", 1)


def read_bytes(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError as error:
        die(f"cannot read {path}: {error.strerror}")


def decode(raw, path):
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as error:
        die(f"{path} is not valid UTF-8 (byte {error.start})")


def say(kind, item, msg):
    tally[kind] += 1
    if kind == "FAIL" and item:
        failed_items.add(item["id"])
    elif kind == "FAIL":
        tally["FILE_FAIL"] += 1
    print(f"{kind} {item['id'] if item else '-'}: {msg}")


def numbers(s):
    s = CMD.sub(" ", KEYS.sub(" ", s.replace("{,}", ",")))
    return Counter(re.findall(NUM, s))


def keys(s):
    return Counter(KEYS.findall(s))


def shield(s):
    """Hide escaped backslashes and escaped dollars, so only an unescaped $ opens math."""
    return s.replace("\\\\", "\x00").replace("\\$", "\x01")


def unshield(s):
    return s.replace("\x00", "\\\\").replace("\x01", "\\$")


def maths(s):
    return Counter(unshield(m.group(0)) for m in MATH.finditer(shield(s)))


def comments(s, markdown=False):
    if markdown:
        return Counter()
    return Counter(x.strip() for x in s.splitlines() if x.lstrip().startswith("%"))


def visible(s, markdown=False):
    """The prose of a block: no url arguments, comments (LaTeX only), reference keys, math or command names."""
    s = re.sub(r"\\(?:url|href)\{[^}]*\}", " ", s)
    if not markdown:
        s = "\n".join(TRAILING_COMMENT.sub(r"\1", x) for x in s.splitlines())
    s = MATH.sub(" ", shield(KEYS.sub(" ", s))).replace("\x00", " ").replace("\x01", " ")
    return CMD.sub(" ", s)


def blank_lines(s):
    return len(re.findall(r"\n[ \t]*\n", s))


def parse(md):
    items, item, label, buf, fence, seen = [], None, None, [], False, set()
    for line in md.splitlines():
        s = line.strip()
        if fence:
            if s == "~~~":
                item["blocks"].append((label, "\n".join(buf)))
                fence, label = False, None
            else:
                buf.append(line)
        elif line.startswith("### "):
            m = HEAD.match(line)
            item = None
            if not m:
                say("FAIL", None, f"unparseable item heading: {line[:70]}")
            elif m[1] in seen:
                say("FAIL", None, f"duplicate item id {m[1]}")
            else:
                item = {"id": m[1], "cls": m[2], "key": m[3], "blocks": [], "notes": []}
                seen.add(m[1])
                items.append(item)
                if m[2] not in CLASSES:
                    say("FAIL", item, f"unknown class [{m[2]}]: use required, recommended or optional")
        elif LOOKS.match(line):
            say("FAIL", None, f"item heading must start at column 0 as '### ': {line.strip()[:70]}")
            item = None
        elif item is None:
            continue
        elif s.startswith("~~~"):
            fence, buf = True, []
        elif LABEL.match(s):
            label = s[:-1]
        elif s:
            item["notes"].append(s)
    if not items:
        say("FAIL", None, "no items parsed")
    return items


def pairs(item):
    out, opened = [], {}
    for label, text in item["blocks"]:
        if label is None:
            say("FAIL", item, "code block without a Current/Replacement label")
            continue
        kind = "primary" if label in ("Current", "Replacement") else label.split()[1]
        if label.lower().endswith("current"):
            opened[kind] = text
        elif kind in opened:
            out.append((kind, opened.pop(kind), text))
        else:
            say("FAIL", item, f"'{label}' block has no current block before it")
    for kind in opened:
        say("FAIL", item, f"{kind} current block has no replacement")
    if not out:
        say("FAIL", item, "no Current/Replacement pair")
    return out


def depends(item):
    for note in item["notes"]:
        m = re.match(r"Depends on:\s*([\w-]+)", note)
        if m:
            return m[1]
    return None


def ancestors(item, by_id):
    """The items this one depends on, oldest first. Raises ValueError on a missing id or a cycle."""
    chain, seen, current = [], {item["id"]}, item
    while depends(current):
        dep = depends(current)
        if dep not in by_id:
            raise ValueError(f"dependency {dep} is missing")
        if dep in seen:
            raise ValueError(f"dependency cycle through {dep}")
        seen.add(dep)
        current = by_id[dep]
        chain.insert(0, current)
    return chain


def apply_item(item, text):
    for kind, cur, rep in item["pairs"]:
        if kind == "primary":
            if text.count(cur) != 1:
                return None
            text = text.replace(cur, rep, 1)
    return text


def simulate(items, by_id, text, selected):
    """Apply the selected items in document order, dependencies first.

    Returns (texts, status); status maps an item id to ("ok" | "skip" | "cascade" | "fail", message).
    "cascade" means a dependency already failed, so the failure is reported on that dependency.
    """
    out, status = dict(text), {}

    def attempt(item):
        dep = depends(item)
        if dep:
            if dep not in by_id:
                return "fail", f"dependency {dep} is missing"
            if dep not in selected:
                return "skip", f"depends on unselected {dep}"
            dep_status = run(by_id[dep])[0]
            if dep_status != "ok":
                return ("skip" if dep_status == "skip" else "cascade"), f"dependency {dep} did not apply"
        if item["key"] not in out:
            return "fail", f"file key {item['key']} was not given on the command line"
        new = apply_item(item, out[item["key"]])
        if new is None:
            return "fail", "does not apply cleanly after the items before it"
        out[item["key"]] = new
        return "ok", ""

    def run(item):
        if item["id"] not in status:
            status[item["id"]] = ("cascade", "dependency cycle")
            status[item["id"]] = attempt(item)
        return status[item["id"]]

    for item in items:
        if item["id"] in selected:
            run(item)
    return out, status


def note_text(item, prefix):
    return " ".join(note[len(prefix):] for note in item["notes"] if note.startswith(prefix))


def key_names(key):
    """The bare keys of one KEYS match: \\cite[p.~5]{a,b} gives a and b; [@a; @b] gives a and b."""
    if key.startswith("\\"):
        found = re.search(r"\{([^}]*)\}$", key)
        return [x.strip() for x in found[1].split(",") if x.strip()] if found else []
    return PANDOC_KEY.findall(key)


def check_pair(item, kind, cur, rep, banned):
    markdown = item["markdown"]
    listed_numbers = set(numbers(" ".join(re.findall(r"`([^`]*)`", note_text(item, "Numbers:")))))
    lost, extra = numbers(cur) - numbers(rep), numbers(rep) - numbers(cur)
    bad_lost = [v for v in lost.elements() if v not in listed_numbers]
    bad_extra = [v for v in extra.elements() if v not in listed_numbers]
    if bad_lost or bad_extra:
        say("FAIL", item, f"{kind}: numbers removed {sorted(bad_lost)}, added {sorted(bad_extra)}")
    ok_lost = [v for v in lost.elements() if v in listed_numbers]
    ok_extra = [v for v in extra.elements() if v in listed_numbers]
    if ok_lost or ok_extra:
        say("REVIEW", item, f"{kind}: numbers removed {sorted(ok_lost)}, added {sorted(ok_extra)} (listed)")
    removed_note = note_text(item, "Removed:")
    removed_flat = " ".join(removed_note.split())

    def key_listed(key):
        names = key_names(key)
        return key in removed_note or (bool(names) and all(
            re.search(r"(?<![\w:.\-])" + re.escape(name) + r"(?![\w:\-])", removed_note) for name in names))

    for name, count, is_listed in (
            ("ref/cite/label", keys, key_listed),
            ("math", maths, lambda v: " ".join(v.split()) in removed_flat),
            ("comment line", lambda t: comments(t, markdown), lambda v: " ".join(v.split()) in removed_flat)):
        lost, extra = count(cur) - count(rep), count(rep) - count(cur)
        bad = sorted(v for v in lost if not is_listed(v))
        ok = sorted(v for v in lost if is_listed(v))
        if bad:
            say("FAIL", item, f"{kind}: {name} removed {bad}")
        if ok:
            say("REVIEW", item, f"{kind}: {name} removed {ok} (listed)")
        if extra:
            say("REVIEW", item, f"{kind}: {name} added {sorted(extra)}")
    breaks_before, breaks_after = cur.count("\\\\"), rep.count("\\\\")
    if breaks_before != breaks_after:
        say("FAIL", item, f"{kind}: line break count changed from {breaks_before} to {breaks_after}")
    if blank_lines(cur) != blank_lines(rep):
        say("REVIEW", item, f"{kind}: paragraph break count changed from {blank_lines(cur)} to {blank_lines(rep)}")
    new = set(CMD.findall(rep)) - set(CMD.findall(cur))
    gone = set(CMD.findall(cur)) - set(CMD.findall(rep))
    if new & FORMAT:
        say("FAIL", item, f"{kind}: new formatting command {sorted(new & FORMAT)}")
    if gone & FORMAT:
        say("FAIL", item, f"{kind}: formatting command removed {sorted(gone & FORMAT)}")
    if new - FORMAT:
        say("REVIEW", item, f"{kind}: new command {sorted(new - FORMAT)}")
    prose = visible(rep, markdown)
    for term in banned:
        if term.startswith("re:"):
            hit = re.search(term[3:], prose)
        else:
            hit = re.search(r"(?<!\w)" + re.escape(term) + r"(?!\w)", prose)
        if hit:
            say("FAIL", item, f"{kind}: banned variant {term!r}")


def check_items(items, by_id, text, banned):
    spans = {}
    for item in items:
        key = item["key"]
        base = text.get(key)
        if base is None:
            say("FAIL", item, f"file key {key} was not given on the command line")
            continue
        try:
            chain = ancestors(item, by_id)
        except ValueError as error:
            say("FAIL", item, str(error))
            continue
        for earlier in (a for a in chain if a["key"] == key):
            base = apply_item(earlier, base)
            if base is None:
                break
        if base is None:
            say("FAIL", item, f"dependency {earlier['id']} does not apply")
            continue
        for kind, cur, rep in item["pairs"]:
            found = base.count(cur)
            if found != 1:
                say("FAIL", item, f"{kind}: current block occurs {found} times")
            elif kind == "primary" and not chain:
                start = base.find(cur)
                spans.setdefault(key, []).append((start, start + len(cur), item["id"]))
            check_pair(item, kind, cur, rep, banned)
    for key, found in spans.items():
        found.sort(key=lambda span: (span[0], -span[1]))
        top_end, top_id = -1, None
        for start, end, ident in found:
            if start < top_end:
                say("FAIL", by_id[ident], f"current block overlaps {top_id} in file {key}")
            if end > top_end:
                top_end, top_id = end, ident


def check_simulation(items, by_id, text):
    for label, classes in (("required,recommended", ("required", "recommended")), ("all classes", CLASSES)):
        selected = {item["id"] for item in items if item["cls"] in classes}
        _, status = simulate(items, by_id, text, selected)
        for item in items:
            state, why = status.get(item["id"], ("ok", ""))
            if state == "fail" and item["id"] not in failed_items:
                say("FAIL", item, f"sequential application fails for classes {label}: {why}")


def first_cells(md):
    """R<n> ids at the start of the first cell of each table row; ** and _ emphasis, the leading pipe optional."""
    ids = []
    for line in md.splitlines():
        if "|" not in line:
            continue
        cell = line.strip().lstrip("|").split("|")[0].replace("*", "").replace("_", "").strip()
        found = re.match(r"R\d+[a-z]?\b", cell)
        if found:
            ids.append(found[0])
    return ids


def check_coverage(review_md, report_md):
    report = decode(read_bytes(report_md), report_md)
    review = decode(read_bytes(review_md), review_md)
    ids = list(dict.fromkeys(first_cells(review)))
    if ids:
        rows = set(first_cells(report))
        covered = lambda rid: rid in rows or any(re.fullmatch(rf"{rid}[a-z]", r) for r in rows)
    else:
        say("REVIEW", None, "review.md has no findings table with R<n> ids: scraped R<n> mentions instead")
        ids = sorted(set(re.findall(r"\bR\d+\b", review)), key=lambda x: int(x[1:]))
        covered = lambda rid: bool(re.search(rf"\b{rid}[a-z]?\b", report))
    for rid in sorted(ids, key=lambda x: (int(re.sub(r"\D", "", x)), x)):
        if not covered(rid):
            say("FAIL", None, f"reviewer finding {rid} has no row in the report")


def refuse(msg):
    raise SystemExit(f"refusing to write: {msg}")


def ancestors_of(path):
    current = os.path.abspath(path)
    while True:
        yield current
        parent = os.path.dirname(current)
        if parent == current:
            return
        current = parent


def same_file(a, b):
    return os.path.exists(a) and os.path.exists(b) and os.path.samefile(a, b)


def replace_file(target, data):
    """Write data to a temp file next to target, then replace target: a hard link is never written through."""
    directory = os.path.dirname(target) or "."
    os.makedirs(directory, exist_ok=True)
    handle, tmp = tempfile.mkstemp(dir=directory, prefix=".aep-", suffix=".tmp")
    try:
        with os.fdopen(handle, "wb") as out:
            out.write(data)
        os.chmod(tmp, stat.S_IMODE(os.stat(target).st_mode) if os.path.exists(target) else 0o644)
        os.replace(tmp, target)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def write_copies(spec, selected, items, by_id, paths, text, crlf, only_selected):
    src, dest = split_pair(spec, "--apply-into")
    src_real, dest_real = os.path.realpath(src), os.path.realpath(dest)
    if dest_real == src_real or os.path.commonpath([src_real, dest_real]) == src_real:
        refuse(f"DEST_ROOT {dest} is or lies inside SRC_ROOT {src}")
    if os.path.commonpath([src_real, dest_real]) == dest_real:
        refuse(f"SRC_ROOT {src} lies inside DEST_ROOT {dest}")
    if any(same_file(a, src) for a in ancestors_of(dest)):
        refuse(f"DEST_ROOT {dest} is, or lies inside, the same directory as SRC_ROOT {src}")
    if any(same_file(a, dest) for a in ancestors_of(src)):
        refuse(f"SRC_ROOT {src} is, or lies inside, the same directory as DEST_ROOT {dest}")
    targets = {}
    for key, path in paths.items():
        rel = os.path.relpath(path, src)
        target = os.path.join(dest, rel)
        if rel.startswith(".."):
            refuse(f"{target}: DEST_ROOT must be a copy outside the sources")
        target_real = os.path.realpath(target)
        if target_real == os.path.realpath(path) or os.path.commonpath([src_real, target_real]) == src_real:
            refuse(f"{target} resolves into the sources ({target_real})")
        if os.path.commonpath([dest_real, target_real]) != dest_real:
            refuse(f"{target} resolves outside DEST_ROOT ({target_real})")
        if any(same_file(a, src) for a in ancestors_of(os.path.dirname(target))):
            refuse(f"{target} lies inside the same directory as SRC_ROOT {src}")
        if any(same_file(target, source) for source in paths.values()):
            refuse(f"{target} is the same file as a source (hard link or alias)")
        targets[key] = target
    out, status = simulate(items, by_id, text, selected)
    for item in items:
        state, why = status.get(item["id"], ("ok", ""))
        if state == "fail" and item["id"] not in failed_items:
            say("FAIL", item, why)
        elif state == "skip":
            say("REVIEW", item, f"not applied: {why}")
    if only_selected:
        blocked = tally["FILE_FAIL"] or failed_items & selected
    else:
        blocked = tally["FAIL"]
    if blocked:
        print("copies not written: fix the FAIL lines first" + (" (selected items and file-level lines)" if only_selected else ""))
        return
    for key, target in targets.items():
        data = out[key].replace("\n", "\r\n") if crlf[key] else out[key]
        replace_file(target, data.encode("utf-8"))
        print(f"wrote {target}")


def closure(ids, by_id):
    found, stack = set(), list(ids)
    while stack:
        ident = stack.pop()
        if ident in found or ident not in by_id:
            continue
        found.add(ident)
        if depends(by_id[ident]):
            stack.append(depends(by_id[ident]))
    return found


def main():
    ap = argparse.ArgumentParser(description="Check an apply-ready file against its sources.")
    ap.add_argument("apply_md")
    ap.add_argument("files", nargs="+", help="KEY=PATH for every file key used in the item headings")
    ap.add_argument("--banned", help="one rejected variant per line; prefix re: for a regular expression")
    ap.add_argument("--review", help="reviewer findings; with --report, every R<n> needs a report row")
    ap.add_argument("--report", help="readable report")
    ap.add_argument("--apply-into", help="SRC_ROOT=DEST_ROOT: write applied copies under DEST_ROOT")
    ap.add_argument("--classes", default="required,recommended", help="classes that --apply-into applies")
    ap.add_argument("--items", help="comma-separated item ids for --apply-into, plus their dependencies")
    args = ap.parse_args()
    paths = dict(split_pair(spec, "file") for spec in args.files)
    if args.apply_into:
        split_pair(args.apply_into, "--apply-into")
    text, crlf = {}, {}
    for key, path in paths.items():
        raw = read_bytes(path)
        crlf[key] = raw.count(b"\r\n") * 2 > raw.count(b"\n")
        text[key] = decode(raw, path).replace("\r\n", "\n")
    banned = []
    if args.banned:
        for number, line in enumerate(decode(read_bytes(args.banned), args.banned).splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            if line.startswith("re:"):
                try:
                    re.compile(line[3:])
                except re.error as error:
                    die(f"{args.banned} line {number}: bad regular expression {line[3:]!r}: {error}")
            banned.append(line)
    items = parse(decode(read_bytes(args.apply_md), args.apply_md))
    by_id = {item["id"]: item for item in items}
    for item in items:
        item["markdown"] = paths.get(item["key"], "").lower().endswith((".md", ".markdown"))
        item["pairs"] = pairs(item)
    check_items(items, by_id, text, banned)
    check_simulation(items, by_id, text)
    if args.review and args.report:
        check_coverage(args.review, args.report)
    if args.apply_into:
        if args.items:
            wanted = [x.strip() for x in args.items.split(",") if x.strip()]
            for ident in wanted:
                if ident not in by_id:
                    say("FAIL", None, f"--items: unknown item id {ident}")
            selected = closure(wanted, by_id)
        else:
            classes = set(args.classes.split(","))
            selected = {item["id"] for item in items if item["cls"] in classes}
        write_copies(args.apply_into, selected, items, by_id, paths, text, crlf, bool(args.items))
    blocks = sum(len(item["pairs"]) for item in items)
    print(f"items {len(items)}; current blocks {blocks}; FAIL {tally['FAIL']}; REVIEW {tally['REVIEW']}")
    return 1 if tally["FAIL"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
