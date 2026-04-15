# my-codex AI Installation Guide

You are an AI agent setting up a Codex CLI multi-agent orchestration environment.
The bundle installs 400+ agent files and 200+ skills (+ 40 gstack runtime), and 3 MCP servers.
The repository sources contain TOML definitions from overlapping upstream sources; install-time deduplication reduces that to the final installed footprint.
Only 2-3 steps are needed.

Read the FULL output, then execute each step in order.

---

## Fast path

If you want to install immediately instead of reading the manual steps first:

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

This document is the guide an AI agent should read before running commands. Fetching `AI-INSTALL.md` only prints instructions, it does not perform the install.

---

## Step 1: Install agents and assets

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Rerunning either install command installs the latest published `main` snapshot, updates only my-codex-managed assets in `~/.codex/`, and removes stale my-codex skills-only copies from `~/.agents/skills/` and `~/.claude/skills/`.

This installs:
- Core agents in `~/.codex/agents/` (always loaded by Codex CLI via `spawn_agent`)
- Domain agent-packs in `~/.codex/agent-packs/`
- `~/.codex/enabled-agent-packs.txt` with a recommended default set (`engineering`, `design`, `testing`, `marketing`, `support`)
- symlinks for that enabled set into `~/.codex/agents/`
- Skills in `~/.codex/skills/` (ECC, minus 7 superseded by gstack)
- gstack skills (runtime-installed from garrytan/gstack — code review, QA, debugging, security, deployment)
- Global `AGENTS.md` instructions with Boss meta-orchestrator as default agent
- `config.toml` with `multi_agent = true`
- `~/.codex/bin/codex` wrapper plus git hooks for Codex-only commit attribution
- Codex-native Briefing Vault hooks plus wrapper fallback (`session-start.sh`, `session-sync.js`, `session-end.js`)
- 3 MCP servers (Context7 — real-time library docs, Exa — web search, grep_app — GitHub code search)

Why the numbers are lower than raw source totals:
- Several upstream sources ship the same destination filename.
- `install.sh` merges those sources into `~/.codex/agents/` and category folders under `~/.codex/agent-packs/`.
- When filenames overlap, later copies replace earlier ones. The final installed counts above are the correct verification target.

Briefing Vault note:
- `sessions/*-auto.md` and `learnings/*-auto-session.md` are auto-generated scaffolds.
- `decisions/*-auto.md` is also generated as a scaffold during active Codex sessions.
- Promoted topic notes and `persona/persona-policy.json` are created only when the session produces matching signals.

## Step 1b: Manual install (if install.sh unavailable)

> **Note**: This repository uses git submodules for upstream content. Run `git submodule update --init` after cloning to populate the `upstream/` directories used below. Paths like `upstream/ecc/`, `upstream/agency-agents/`, etc. will be empty without this step.

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
cd /tmp/my-codex && git submodule update --init
mkdir -p ~/.codex/agents ~/.codex/agent-packs ~/.codex/skills
mkdir -p ~/.codex/bin

# Core agents (always loaded)
cp /tmp/my-codex/codex-agents/core/*.toml ~/.codex/agents/
cp /tmp/my-codex/codex-agents/omo/*.toml ~/.codex/agents/

# Awesome core categories → auto-loaded agents
for d in 01-core-development 03-infrastructure 04-quality-security 09-meta-orchestration; do
  cp /tmp/my-codex/upstream/awesome/categories/$d/*.toml ~/.codex/agents/ 2>/dev/null
done

# Awesome remaining categories → agent-packs
for d in /tmp/my-codex/upstream/awesome/categories/*/; do
  raw_name=$(basename "$d")
  case "$raw_name" in 01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration) continue ;; esac
  cat_name="${raw_name#[0-9][0-9]-}"
  mkdir -p ~/.codex/agent-packs/$cat_name
  cp "$d"*.toml ~/.codex/agent-packs/$cat_name/ 2>/dev/null
done

# Agency agents (MD → TOML conversion needed; use install.sh for this)
# install.sh handles md-to-toml.sh conversion at runtime.
# Manual alternative: run scripts/md-to-toml.sh on upstream/agency-agents/ categories
bash /tmp/my-codex/scripts/md-to-toml.sh /tmp/my-codex/upstream/agency-agents /tmp/agency-toml 2>/dev/null
for d in /tmp/agency-toml/*/; do
  cat_name=$(basename "$d")
  mkdir -p ~/.codex/agent-packs/$cat_name
  cp "$d"*.toml ~/.codex/agent-packs/$cat_name/ 2>/dev/null
done

# Skills
cp -R /tmp/my-codex/upstream/ecc/skills/* ~/.codex/skills/
# ── gstack (sprint-process harness with 40 skills) ──
GSTACK_DIR="$HOME/.codex/skills/gstack"
if [ -d "$GSTACK_DIR/.git" ]; then
  (cd "$GSTACK_DIR" && git pull --ff-only 2>/dev/null || true)
else
  git clone --depth 1 https://github.com/garrytan/gstack.git "$GSTACK_DIR" 2>/dev/null || true
fi
# Remove ECC skills superseded by gstack
for skill in benchmark canary-watch safety-guard browser-qa verification-loop security-review design-system; do
  target="$HOME/.codex/skills/$skill"
  if [ -L "$target" ]; then
    link_dest=$(readlink "$target")
    case "$link_dest" in *gstack*) continue ;; esac
    rm -f "$target"
  elif [ -d "$target" ]; then
    rm -rf "$target"
  fi
done
# Run gstack setup if bun is available
if [ -d "$GSTACK_DIR" ] && command -v bun >/dev/null 2>&1 && [ -f "$GSTACK_DIR/setup" ]; then
  (cd "$GSTACK_DIR" && bun install 2>/dev/null && ./setup --host codex 2>/dev/null || true)
  git -C "$GSTACK_DIR" checkout -- '*/SKILL.md' 'SKILL.md' 2>/dev/null || true
fi
mkdir -p "$HOME/.gstack"
echo '{"auto_upgrade":true}' > "$HOME/.gstack/config.json"
cp /tmp/my-codex/templates/codex-AGENTS.md ~/.codex/AGENTS.md
cp /tmp/my-codex/scripts/agent-pack-manager.sh ~/.codex/bin/my-codex-packs
chmod +x ~/.codex/bin/my-codex-packs

# Persist and activate the recommended pack set
cat > ~/.codex/enabled-agent-packs.txt <<'EOF'
# One pack name per line.
# This file is managed by my-codex and preserved across reinstalls.
engineering
design
testing
marketing
support
EOF

while IFS= read -r pack; do
  [ -n "$pack" ] || continue
  case "$pack" in \#*) continue ;; esac
  find ~/.codex/agent-packs/"$pack" -maxdepth 1 -name '*.toml' | while IFS= read -r agent_file; do
    destination=~/.codex/agents/"$(basename "$agent_file")"
    [ -e "$destination" ] || ln -sf "$agent_file" "$destination"
  done
done < ~/.codex/enabled-agent-packs.txt

# Create config.toml
cat >> ~/.codex/config.toml << 'TOML'
[features]
multi_agent = true
child_agents_md = true

[agents]
max_threads = 8
TOML

# MCP servers (skip names that already exist to avoid re-triggering auth flows)
codex mcp list 2>/dev/null | grep -qE '^context7[[:space:]]' || codex mcp add context7 --url https://mcp.context7.com/mcp 2>/dev/null || true
codex mcp list 2>/dev/null | grep -qE '^exa[[:space:]]' || codex mcp add exa --url "https://mcp.exa.ai/mcp?tools=web_search_exa" 2>/dev/null || true
codex mcp list 2>/dev/null | grep -qE '^grep_app[[:space:]]' || codex mcp add grep_app --url https://mcp.grep.app 2>/dev/null || true

rm -rf /tmp/my-codex
```

## Step 2: Install companion tools (optional)

```bash
# AST tools for code intelligence
npm i -g @ast-grep/cli@0.42.0
```

## Step 3: Customize active agent packs (optional)

```bash
# Inspect the current active set
~/.codex/bin/my-codex-packs status

# Enable another pack immediately
~/.codex/bin/my-codex-packs enable marketing

# Or switch profiles at install time
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
```

## Verify

```bash
echo "Core agents:   $(find ~/.codex/agents -maxdepth 1 -type f -name '*.toml' 2>/dev/null | wc -l)"
echo "Active packs:  $(find ~/.codex/agents -maxdepth 1 -type l -name '*.toml' 2>/dev/null | wc -l)"
echo "Agent packs:   $(find ~/.codex/agent-packs -name '*.toml' 2>/dev/null | wc -l)"
echo "Skills:        $(find ~/.codex/skills -name 'SKILL.md' 2>/dev/null | wc -l)"
echo "AGENTS.md:     $(test -f ~/.codex/AGENTS.md && echo 'OK' || echo 'MISSING')"
echo "config.toml:   $(grep -q 'multi_agent' ~/.codex/config.toml 2>/dev/null && echo 'OK' || echo 'NEEDS CONFIG')"
echo "Enabled packs: $(grep -Ev '^(#|$)' ~/.codex/enabled-agent-packs.txt 2>/dev/null | paste -sd ', ' -)"
```

Expected:
- Core agents: (dynamic)
- Active packs: 90
- Agent packs: (dynamic)
- Skills: ECC + gstack (runtime)
- AGENTS.md: OK
- config.toml: OK

Setup complete. Multi-agent orchestration is ready.

Windows note:
- `install.sh` patches the npm-managed `codex`, `codex.cmd`, and `codex.ps1` shims when present. This keeps the my-codex vault pipeline active even when `%APPDATA%\\npm` resolves before `~/.codex/bin`.
- The Codex plugin auto-loads `hooks/hooks.json` by convention; do not declare a `hooks` field in `.codex-plugin/plugin.json`.
- Briefing Vault updates now happen both during the session (`UserPromptSubmit`, `PostToolUse`) and at stop, with wrapper fallback for session continuity.
- Reading `AI-INSTALL.md` does not install anything. Use `install.sh` for unattended agent setup.

## Codex Attribution Defaults

Full install also configures a default Codex attribution flow:
- `~/.codex/bin/codex` wraps the real Codex CLI and records which files changed during a Codex session
- `git config --global core.hooksPath ~/.codex/git-hooks` installs `prepare-commit-msg`, `commit-msg`, and `post-commit` hooks
- Commits that include recorded Codex-touched files get `Generated with Codex CLI: https://github.com/openai/codex` in the commit message
- commits only receive `AI-Contributed-By: Codex` when staged files overlap that recorded Codex change set
- `my-codex` does not modify `git user.name`, `git user.email`, commit author, or committer identity

Optional `Co-authored-by:` trailer:

```bash
git config --global my-codex.codexContributorName "Pair Programmer"
git config --global my-codex.codexContributorEmail "your-verified-email@example.com"
```

Local git commits cannot attach GitHub's official `@codex` agent identity directly. GitHub only recognizes co-authors when the configured email is linked to a real GitHub account, and no co-author is added unless you opt in with both settings.

Disable attribution entirely:

```bash
git config --global my-codex.codexAttribution false
```

`my-claude` is maintained as a separate repository and is not updated by `my-codex` install or bootstrap commands.

## Skills-Only Alternative

To install only the cross-tool skills exposed by `npx skills add` (no agents, no rules, no config):

```bash
npx skills add sehoon787/my-codex -y -g
```

Installs SKILL.md files to `~/.agents/skills/` and auto-symlinks to Codex CLI, Claude Code, Cursor, and other supported tools. Use this when you only need skills and already have agents configured elsewhere. The full `install.sh` bundle installs ECC skills into `~/.codex/skills/` plus gstack skills at runtime.

## Also Available

[![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Looking for Claude Code? → **my-claude** — same agents as Claude Code plugin with Boss meta-orchestrator
