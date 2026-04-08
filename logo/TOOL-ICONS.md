# External Tool Icons Reference

All URLs verified as of 2026-04-08. GitHub avatar URLs use the stable
`https://github.com/{user}.png?size=N` pattern which redirects to
`avatars.githubusercontent.com` — both forms work; the short form is preferred.

---

## Upstream Sources

| Tool | Icon URL | Website | Description |
|------|----------|---------|-------------|
| agency-agents | `https://github.com/msitarzewski.png?size=32` | https://github.com/msitarzewski/agency-agents | 185 domain-specialist agent prompts for Claude Code and other AI editors |
| everything-claude-code (ECC) | `https://github.com/affaan-m.png?size=32` | https://github.com/affaan-m/everything-claude-code | Agent harness: skills, instincts, memory, security, and research-first development |
| oh-my-claudecode (OMC) | `https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/assets/omc-character.jpg` | https://github.com/Yeachan-Heo/oh-my-claudecode | Teams-first multi-agent orchestration with zero-learning-curve automation |
| gstack | `https://github.com/garrytan.png?size=32` | https://github.com/garrytan/gstack | 23 Claude Code skills forming a virtual engineering team (CEO → QA → ship) |
| superpowers | `https://github.com/obra.png?size=32` | https://github.com/obra/superpowers | Composable agentic skills framework with design-first, TDD-enforced methodology |

**Fallback GitHub avatar URLs (direct CDN, stable):**
- msitarzewski: `https://avatars.githubusercontent.com/u/1972242?s=32&v=4`
- affaan-m: `https://avatars.githubusercontent.com/u/124439313?s=32&v=4`
- Yeachan-Heo: `https://avatars.githubusercontent.com/u/54757707?s=32&v=4`
- garrytan: `https://avatars.githubusercontent.com/u/19957?s=32&v=4`
- obra: `https://avatars.githubusercontent.com/u/45416?s=32&v=4`

---

## External Tools

| Tool | Icon URL | Website | Description |
|------|----------|---------|-------------|
| Obsidian | `https://obsidian.md/images/obsidian-logo-gradient.svg` | https://obsidian.md | Knowledge vault backend — local-first Markdown graph with wiki-links |
| Claude Code (Anthropic) | `https://www.anthropic.com/favicon.ico` | https://www.anthropic.com/claude-code | The CLI tool this project extends; Anthropic's official agentic coding interface |
| Context7 | `https://context7.com/favicon.ico` | https://context7.com | MCP server that delivers up-to-date library docs to LLMs and AI editors |
| Exa | `https://exa.ai/images/favicon-32x32.png` | https://exa.ai | Neural-search MCP server for web research and discovery |
| grep.app | `https://grep.app/icon.png` | https://grep.app | MCP server for regex/literal code search across a million public GitHub repos |
| tmux | `https://raw.githubusercontent.com/tmux/tmux/master/logo/tmux-logomark.svg` | https://github.com/tmux/tmux | Terminal multiplexer required for Agent Teams split-pane parallel mode |
| ast-grep | `https://ast-grep.github.io/logo.svg` | https://ast-grep.github.io | Structural code search and rewrite tool; used for AST-level pattern matching |
| Playwright | `https://playwright.dev/img/playwright-logo.svg` | https://playwright.dev | Browser automation framework; used by gstack `/qa` and E2E testing skills |

---

## AI / Platform Logos

| Tool | Icon URL | Website | Description |
|------|----------|---------|-------------|
| Anthropic | `https://www.anthropic.com/favicon.ico` | https://www.anthropic.com | AI safety company and creator of Claude; parent brand for Claude Code |
| OpenAI | `https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/OpenAI_Logo.svg/200px-OpenAI_Logo.svg.png` | https://openai.com | For the `my-codex` variant that wraps OpenAI Codex CLI |

**Higher-resolution Anthropic brand image (Sanity CDN):**
`https://cdn.sanity.io/images/4zrzovbb/website/c07f638082c569e8ce1e89ae95ee6f332a98ec08-2400x1260.jpg`

---

## Usage Examples (Markdown)

### Small inline (16 px in flowing text)
```markdown
<img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="16" height="16" align="center"/> [Obsidian.md](https://obsidian.md)
```

### Badge style (for README tables, 20 px)
```markdown
<img src="https://playwright.dev/img/playwright-logo.svg" width="20" height="20" align="center"/> Playwright
```

### GitHub avatar in a table cell
```markdown
<img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> [everything-claude-code](https://github.com/affaan-m/everything-claude-code)
```

### Favicon-sized icon (32 px, square tools)
```markdown
<img src="https://exa.ai/images/favicon-32x32.png" width="32" height="32"/> Exa
```

---

## Notes

- **grep.app** is rate-limited; the `/icon.png` path was confirmed via Google's
  favicon service (`https://t2.gstatic.com/faviconV2?...url=http://grep.app&size=32`
  resolved to `https://grep.app/icon.png`). If still rate-limited, use
  `https://www.google.com/s2/favicons?domain=grep.app&sz=32` as a proxy.
- **Anthropic** has no public brand-asset page; `favicon.ico` and the Sanity CDN
  JPEG are the most reliably hosted assets. The favicon resolves to an `.ico` file
  (not SVG), so scale it carefully — prefer the Sanity CDN image for larger display.
- **OpenAI** blocks direct favicon requests (403). The Wikimedia Commons PNG is the
  most stable publicly accessible version of the official SVG logo.
- **oh-my-claudecode** mascot JPEG is the only distinct visual asset in that repo;
  the GitHub user avatar (`Yeachan-Heo.png`) is a cleaner fallback for small sizes.
- **tmux** logomark SVG (`tmux-logomark.svg`) is the compact icon form; the full
  logo with wordmark is at `tmux-logo.svg` in the same directory.
