#!/usr/bin/env python3
"""Check an apply-ready file (apply.md) against its source files.

Read-only unless --apply-into is given; even then it writes only under DEST_ROOT.

Usage:
  python3 -I check_apply.py apply.md A=paper/chapters/ch3.tex [B=...] [--banned banned.txt]
      [--review review.md --report report.md] [--apply-into paper=/tmp/run/after/paper]
      [--classes required,recommended]

FAIL lines set exit status 1. REVIEW lines need a person's judgement.
"""
import argparse
import os
import re
from collections import Counter

HEAD = re.compile(r"^### (\S+) \[([a-z]+)[^\]]*\].*\((\w+) \d")
LABEL = re.compile(r"^(Current|Replacement|Alternative \w+ (?:current|replacement)):$")
KEYS = re.compile(r"\\(?:ref|cref|Cref|autoref|eqref|pageref|label|cite\w*)\*?(?:\[[^\]]*\])*\{[^}]*\}")
MATH = re.compile(r"\$[^$]+\$|\\\(.+?\\\)")
CMD = re.compile(r"\\([a-zA-Z]+)")
FORMAT = set(
    "vspace hspace setlength addtolength small footnotesize scriptsize tiny large Large normalsize "
    "newline linebreak pagebreak newpage clearpage noindent looseness enlargethispage resizebox "
    "scalebox arraystretch tabcolsep smallskip medskip bigskip vfill hfill centering raggedright".split())
tally = Counter()


def say(kind, item, msg):
    tally[kind] += 1
    print(f"{kind} {item['id'] if item else '-'}: {msg}")


def numbers(s):
    s = CMD.sub(" ", KEYS.sub(" ", s.replace("{,}", ",")))
    return Counter(re.findall(r"\d+(?:,\d{3})*(?:\.\d+)?", s))


def keys(s):
    return Counter(KEYS.findall(s))


def maths(s):
    return Counter(MATH.findall(s))


def comments(s):
    return Counter(x.strip() for x in s.splitlines() if x.lstrip().startswith("%"))


def parse(md):
    items, item, label, buf, fence = [], None, None, [], False
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
            item = {"id": m[1], "cls": m[2], "key": m[3], "blocks": [], "notes": []} if m else None
            if item:
                items.append(item)
            else:
                say("FAIL", None, f"unparseable item heading: {line[:70]}")
        elif item is None:
            continue
        elif s.startswith("~~~"):
            fence, buf = True, []
        elif LABEL.match(s):
            label = s[:-1]
        elif s:
            item["notes"].append(s)
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


def apply_item(item, text):
    for kind, cur, rep in item["pairs"]:
        if kind == "primary":
            if text.count(cur) != 1:
                return None
            text = text.replace(cur, rep, 1)
    return text


def listed(item, prefix):
    return any(note.startswith(prefix) for note in item["notes"])


def check_pair(item, kind, cur, rep, banned):
    lost, extra = numbers(cur) - numbers(rep), numbers(rep) - numbers(cur)
    if lost or extra:
        say("REVIEW" if listed(item, "Numbers:") else "FAIL", item,
            f"{kind}: numbers removed {sorted(lost.elements())}, added {sorted(extra.elements())}")
    for name, count in (("ref/cite/label", keys), ("math", maths), ("comment line", comments)):
        lost, extra = count(cur) - count(rep), count(rep) - count(cur)
        if lost:
            say("REVIEW" if listed(item, "Removed:") else "FAIL", item, f"{kind}: {name} removed {sorted(lost)}")
        if extra:
            say("REVIEW", item, f"{kind}: {name} added {sorted(extra)}")
    breaks_before, breaks_after = cur.count("\\\\"), rep.count("\\\\")
    if breaks_before != breaks_after:
        say("FAIL", item, f"{kind}: line break count changed from {breaks_before} to {breaks_after}")
    new = set(CMD.findall(rep)) - set(CMD.findall(cur))
    if new & FORMAT:
        say("FAIL", item, f"{kind}: new formatting command {sorted(new & FORMAT)}")
    if new - FORMAT:
        say("REVIEW", item, f"{kind}: new command {sorted(new - FORMAT)}")
    for term in banned:
        if (re.search(term[3:], rep) if term.startswith("re:") else term in rep):
            say("FAIL", item, f"{kind}: banned variant {term!r}")


def check_items(items, by_id, text, banned):
    spans = {}
    for item in items:
        base, dep = text.get(item["key"]), depends(item)
        if base is None:
            say("FAIL", item, f"file key {item['key']} was not given on the command line")
            continue
        if dep:
            base = apply_item(by_id[dep], base) if dep in by_id else None
            if base is None:
                say("FAIL", item, f"dependency {dep} is missing or does not apply")
                continue
        for kind, cur, rep in item["pairs"]:
            found = base.count(cur)
            if found != 1:
                say("FAIL", item, f"{kind}: current block occurs {found} times")
            elif kind == "primary" and not dep:
                start = base.find(cur)
                spans.setdefault(item["key"], []).append((start, start + len(cur), item["id"]))
            check_pair(item, kind, cur, rep, banned)
    for key, found in spans.items():
        found.sort()
        for (_, end, first), (start, _, second) in zip(found, found[1:]):
            if start < end:
                say("FAIL", by_id[second], f"current block overlaps {first} in file {key}")


def check_coverage(review_md, report_md):
    with open(report_md, encoding="utf-8") as handle:
        report = handle.read()
    with open(review_md, encoding="utf-8") as handle:
        ids = set(re.findall(r"\bR\d+\b", handle.read()))
    for rid in sorted(ids, key=lambda x: int(x[1:])):
        if not re.search(rf"\b{rid}[a-z]?\b", report):
            say("FAIL", None, f"reviewer finding {rid} has no row in the report")


def write_copies(spec, classes, items, by_id, paths, text):
    src, dest = spec.split("=", 1)
    src_real, dest_real = os.path.realpath(src), os.path.realpath(dest)
    if dest_real == src_real or os.path.commonpath([src_real, dest_real]) == src_real:
        raise SystemExit(f"refusing to write: DEST_ROOT {dest} is or lies inside SRC_ROOT {src}")
    wanted, out, done = set(classes.split(",")), dict(text), set()

    def run(item):
        if item["id"] in done:
            return
        done.add(item["id"])
        dep = depends(item)
        if dep and (dep not in by_id or by_id[dep]["cls"] not in wanted):
            say("REVIEW", item, f"not applied: depends on unselected {dep}")
            return
        if dep:
            run(by_id[dep])
        new = apply_item(item, out[item["key"]])
        if new is None:
            say("FAIL", item, "does not apply cleanly after the items before it")
        else:
            out[item["key"]] = new

    for item in items:
        if item["cls"] in wanted and item["key"] in out:
            run(item)
    if tally["FAIL"]:
        print("copies not written: fix the FAIL lines first")
        return
    targets = {}
    for key, path in paths.items():
        rel = os.path.relpath(path, src)
        target = os.path.join(dest, rel)
        if rel.startswith(".."):
            raise SystemExit(f"refusing to write {target}: DEST_ROOT must be a copy outside the sources")
        target_real = os.path.realpath(target)
        if target_real == os.path.realpath(path) or os.path.commonpath([src_real, target_real]) == src_real:
            raise SystemExit(f"refusing to write {target}: it resolves into the sources ({target_real})")
        targets[key] = target
    for key, target in targets.items():
        os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
        with open(target, "w", encoding="utf-8") as handle:
            handle.write(out[key])
        print(f"wrote {target}")


def main():
    ap = argparse.ArgumentParser(description="Check an apply-ready file against its sources.")
    ap.add_argument("apply_md")
    ap.add_argument("files", nargs="+", help="KEY=PATH for every file key used in the item headings")
    ap.add_argument("--banned", help="one rejected variant per line; prefix re: for a regular expression")
    ap.add_argument("--review", help="reviewer findings; with --report, every R<n> needs a report row")
    ap.add_argument("--report", help="readable report")
    ap.add_argument("--apply-into", help="SRC_ROOT=DEST_ROOT: write applied copies under DEST_ROOT")
    ap.add_argument("--classes", default="required,recommended", help="classes that --apply-into applies")
    args = ap.parse_args()
    paths = dict(spec.split("=", 1) for spec in args.files)
    text = {}
    for key, path in paths.items():
        with open(path, encoding="utf-8") as handle:
            text[key] = handle.read()
    banned = []
    if args.banned:
        with open(args.banned, encoding="utf-8") as handle:
            banned = [x.rstrip("\n") for x in handle if x.strip() and not x.startswith("#")]
    with open(args.apply_md, encoding="utf-8") as handle:
        items = parse(handle.read())
    by_id = {item["id"]: item for item in items}
    for item in items:
        item["pairs"] = pairs(item)
    check_items(items, by_id, text, banned)
    if args.review and args.report:
        check_coverage(args.review, args.report)
    if args.apply_into:
        write_copies(args.apply_into, args.classes, items, by_id, paths, text)
    blocks = sum(len(item["pairs"]) for item in items)
    print(f"items {len(items)}; current blocks {blocks}; FAIL {tally['FAIL']}; REVIEW {tally['REVIEW']}")
    return 1 if tally["FAIL"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
