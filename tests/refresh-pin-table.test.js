#!/usr/bin/env node
// The "Bundled Upstream Versions" table went stale on every scheduled sync
// because only upstream/SOURCES.json was refreshed. scripts/refresh-pin-table.js
// rewrites the table from that manifest; this pins the contract it has to keep.
// `node tests/refresh-pin-table.test.js`

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { refreshPinTable } = require("../scripts/refresh-pin-table.js");

const SOURCES = {
  ecc: {
    repo: "https://github.com/affaan-m/everything-claude-code",
    path: "upstream/ecc",
    pinned_sha: "bf70150eb2df8070024e5bdf08e4aa08959e2735",
    pinned_date: "2026-09-22",
  },
  archify: {
    repo: "https://github.com/tt-a1i/archify",
    path: "upstream/archify",
    pinned_tag: "v2.9.0",
    pinned_sha: "62904f3b73dc469ceb1f1fd500ff44c8dee70b06",
    pinned_date: "2026-09-19",
  },
  // Pinned, but deliberately absent from the table below: must not be inserted.
  superpowers: {
    repo: "https://github.com/obra/superpowers",
    path: "upstream/superpowers",
    pinned_sha: "5bf4e78011075bcfc0dc295f0724994cd123ee71",
    pinned_date: "2026-09-19",
  },
  // No sha to pin — a CLI version entry must never match a row.
  codeburn: { repo: "https://github.com/getagentseal/codeburn", pinned_version: "0.9.23" },
};

const STALE_ECC =
  "| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `07756ce` | 2026-09-19 | [compare](https://github.com/affaan-m/everything-claude-code/compare/07756ce...HEAD) |";
const FRESH_ECC =
  "| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `bf70150` | 2026-09-22 | [compare](https://github.com/affaan-m/everything-claude-code/compare/bf70150...HEAD) |";
const ARCHIFY =
  "| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |";
// Same repo, but not a pin row: an unrelated table must survive untouched.
const UNRELATED =
  "| [archify](https://github.com/tt-a1i/archify) | Diagrams | MIT | [docs](https://github.com/tt-a1i/archify#readme) |";

function readme(heading, eccRow) {
  return [
    "# my-codex",
    "",
    `## ${heading}`,
    "",
    "| Source | SHA | Date | Diff |",
    "|--------|-----|------|------|",
    eccRow,
    ARCHIFY,
    "",
    "## Credits",
    "",
    "| Source | Role | License | Link |",
    "|--------|------|---------|------|",
    UNRELATED,
    "",
  ].join("\n");
}

const temp = fs.mkdtempSync(path.join(os.tmpdir(), "my-codex-pin-table-"));
try {
  fs.mkdirSync(path.join(temp, "upstream"), { recursive: true });
  fs.mkdirSync(path.join(temp, "docs", "i18n"), { recursive: true });
  fs.writeFileSync(
    path.join(temp, "upstream", "SOURCES.json"),
    JSON.stringify(SOURCES, null, 2) + "\n"
  );

  const english = path.join(temp, "README.md");
  // A translated heading proves the match anchors on the row, not the heading.
  const korean = path.join(temp, "docs", "i18n", "README.ko.md");
  fs.writeFileSync(english, readme("Bundled Upstream Versions", STALE_ECC));
  fs.writeFileSync(korean, readme("번들된 업스트림 버전", STALE_ECC));

  const first = refreshPinTable({ repoRoot: temp });
  assert.deepEqual(first.changed, ["README.md", "docs/i18n/README.ko.md"]);

  for (const file of [english, korean]) {
    const lines = fs.readFileSync(file, "utf8").split("\n");
    assert.ok(lines.includes(FRESH_ECC), `${file}: stale row matches SOURCES.json`);
    assert.ok(!lines.includes(STALE_ECC), `${file}: stale row is gone`);
    assert.ok(lines.includes(ARCHIFY), `${file}: unchanged sha keeps its (\`v2.9.0\`) annotation`);
    assert.ok(lines.includes(UNRELATED), `${file}: unrelated table untouched`);
    assert.ok(
      !fs.readFileSync(file, "utf8").includes("obra/superpowers"),
      `${file}: an entry with no row is not inserted`
    );
  }

  const beforeSecond = [english, korean].map((f) => fs.readFileSync(f, "utf8"));
  const second = refreshPinTable({ repoRoot: temp });
  assert.deepEqual(second.changed, [], "a second run is a no-op");
  assert.deepEqual(
    [english, korean].map((f) => fs.readFileSync(f, "utf8")),
    beforeSecond,
    "a second run leaves both files byte-identical"
  );

  console.log("refresh-pin-table: PASS (2 files refreshed, tag preserved, second run a no-op)");
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
