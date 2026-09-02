[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Suchen Sie nach Claude Code? → **my-claude** — dieselbe Boss-Orchestrierung im nativen Claude `.md`-Agentenformat

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-123-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**All-in-one Agent-Harness für OpenAI Codex CLI.**
**Einmal installieren, 17 kuratierte Agenten bereit.**

Boss entdeckt automatisch zur Laufzeit jeden Agenten und jede Skill,
und leitet Ihre Aufgabe über `spawn_agent` an den richtigen Spezialisten weiter. Keine Konfiguration. Kein Boilerplate.

<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## Installation

### Für Menschen

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

### Für KI-Agenten

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

---

## Wie Boss funktioniert

Boss ist der Meta-Orchestrator im Kern von my-codex. Er schreibt niemals Code — er entdeckt, klassifiziert, ordnet zu, delegiert und verifiziert.

```
User Request
     │
     ▼
┌─────────────────────────────────────────────┐
│  Phase 0 · DISCOVERY                        │
│  Scan ~/.codex/agents/*.toml at runtime     │
│  → Build live capability registry           │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 1 · INTENT GATE                      │
│  Classify: trivial | build | refactor |     │
│  mid-sized | architecture | research | ...  │
│  → Counter-propose skill if better fit      │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 2 · CAPABILITY MATCHING              │
│  P1: Exact skill match                      │
│  P2: Specialist agent via spawn_agent       │
│  P3: Multi-agent orchestration              │
│  P4: General-purpose fallback               │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 3 · DELEGATION                       │
│  spawn_agent with structured instructions   │
│  TASK / OUTCOME / TOOLS / DO / DON'T / CTX  │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 4 · VERIFICATION                     │
│  Read changed files independently           │
│  Run tests, lint, build                     │
│  Cross-reference with original intent       │
│  → Retry up to 3× on failure               │
└─────────────────────────────────────────────┘
```

### Prioritäts-Routing

Boss leitet jede Anfrage durch eine Prioritätskette, bis die beste Übereinstimmung gefunden wird:

| Priorität | Übereinstimmungstyp | Wann | Beispiel |
|:---------:|---------------------|------|----------|
| **P1** | Skill-Treffer | Aufgabe entspricht einer eigenständigen Skill | `"review this diff"` → /review Skill |
| **P2** | Spezialist-Agent | Domänenspezifischer Agent vorhanden | `"security audit"` → security-reviewer |
| **P3a** | Boss direkt | 2–4 unabhängige Agenten | `"fix 3 bugs"` → parallel spawn |
| **P3b** | Sub-Orchestrator | Komplexer mehrstufiger Workflow | `"refactor + test"` → Sisyphus |
| **P4** | Fallback | Kein Spezialist gefunden | `"explain this"` → general agent |

### Modell-Routing

| Komplexität | Modell | Verwendet für |
|-------------|--------|---------------|
| Tiefgehende Analyse, Architektur | gpt-5.6-sol (high reasoning) | Boss, Oracle, Sisyphus, Atlas |
| Standardimplementierung | gpt-5.6-terra (medium) | executor, debugger, security-reviewer |
| Schnelle Suche, Erkundung | gpt-5.6-luna (low) | explore, einfache Beratung |

### 3-Phasen-Sprint-Workflow

Für die Ende-zu-Ende-Funktionsimplementierung orchestriert Boss einen strukturierten Sprint:

```
Phase 1: DESIGN         Phase 2: EXECUTE        Phase 3: REVIEW
(interactive)            (autonomous)             (interactive)
─────────────────────   ─────────────────────   ─────────────────────
User decides scope      executor runs tasks     Compare vs design doc
Engineering review      Auto code review        Present comparison table
Confirm "design done"   Architect verification  User: approve / improve
```

---

## Architektur

```
┌─────────────────────────────────────────────────────┐
│                    User Request                       │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Boss · Meta-Orchestrator (gpt-5.6-sol high)              │
│  Discovery → Classification → Matching → Delegation  │
└──┬──────────┬──────────┬──────────┬─────────────────┘
   │          │          │          │
   ▼          ▼          ▼          ▼
┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ P3a  │ │  P3b   │ │  P1/P2 │ │Config  │
│Direct│ │Sub-orch│ │ Skill/ │ │Control │
│2-4   │ │Sisyphus│ │ Agent  │ │config. │
│spawn │ │Atlas   │ │ Direct │ │toml    │
└──────┘ └────────┘ └────────┘ └────────┘
┌─────────────────────────────────────────────────────┐
│  Agent Layer (17 installed TOML files)                │
│  Boss 1 · OMO 9 · OMX 7                               │
│  + 2 opt-in agent packs (17 agents, off by default)   │
├─────────────────────────────────────────────────────┤
│  Skills Layer (123 from ECC + gstack + superpowers)   │
│  coding-standards · security-scan · deep-research     │
│  /review · /qa · /cso · /ship                         │
├─────────────────────────────────────────────────────┤
│  MCP Layer                                            │
│  Context7 · Exa · grep.app                            │
└─────────────────────────────────────────────────────┘
```

---

## Was enthalten ist

| Kategorie | Anzahl | Quelle |
|-----------|-------:|--------|
| **Kern-Agenten** (immer geladen) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Agenten-Packs** (Opt-in, standardmäßig keines aktiv) | 17 | 2 eingebundene Kategorien: data-ai 13 + llmops 4 |
| **Skills** | 123 | ECC 79 · gstack 27 · Superpowers 13 · Core 4 |
| **MCP-Server** | 3 | Context7, Exa, grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>Kern-Agent — Boss Meta-Orchestrator (1)</strong></summary>

| Agent | Modell | Rolle | Quelle |
|-------|--------|-------|--------|
| Boss | gpt-5.6-sol high | Dynamische Laufzeitentdeckung → Fähigkeitsabgleich → optimales Routing. Schreibt niemals Code. | my-codex |

</details>

<details>
<summary><strong>OMO-Agenten — Sub-Orchestratoren und Spezialisten (9)</strong></summary>

| Agent | Modell | Rolle | Quelle |
|-------|--------|-------|--------|
| Sisyphus | gpt-5.6-sol high | Absichtsklassifizierung → Spezialistendelegation → Verifikation | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | gpt-5.6-sol high | Autonom erkunden → planen → ausführen → verifizieren | oh-my-openagent |
| Atlas | gpt-5.6-sol high | Aufgabenzerlegung + 4-stufige QA-Verifikation | oh-my-openagent |
| Oracle | gpt-5.6-sol high | Strategische technische Beratung (nur lesend) | oh-my-openagent |
| Metis | gpt-5.6-sol high | Absichtsanalyse, Mehrdeutigkeitserkennung | oh-my-openagent |
| Momus | gpt-5.6-sol high | Überprüfung der Planumsetzbarkeit | oh-my-openagent |
| Prometheus | gpt-5.6-sol high | Interviewbasierte detaillierte Planung | oh-my-openagent |
| Librarian | gpt-5.6-terra medium | Open-Source-Dokumentationssuche über MCP | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-terra medium | Bild-/Screenshot-/Diagrammanalyse | oh-my-openagent |

</details>

<details>
<summary><strong>OMX-Agenten — Spezialistenmitarbeiter (7)</strong></summary>

Aus den `prompts/*.md` von [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) nach Codex-TOML konvertiert. Konvertiert werden nur die Lanes, die `templates/codex-AGENTS.md` ausweist; die Allowlist steht in `scripts/skill-allowlists.sh`.

| Agent | Sandbox | Rolle | Quelle |
|-------|---------|-------|--------|
| executor | workspace-write | Code-Implementierung | oh-my-codex |
| planner | workspace-write | Implementierungsplanung | oh-my-codex |
| architect | read-only | Systemdesign und Architektur | oh-my-codex |
| test-engineer | workspace-write | Teststrategie und Abdeckung | oh-my-codex |
| security-reviewer | read-only | Sicherheitsanalyse | oh-my-codex |
| code-reviewer | read-only | Fokussierte Code-Review | oh-my-codex |
| debugger | workspace-write | Ursachenanalyse | oh-my-codex |

</details>

<details>
<summary><strong>Agenten-Packs — Opt-in-KI-Spezialisten (2 Packs, 17 Agenten)</strong></summary>

Aus [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (MIT) nach `codex-agents/packs/` eingebunden und nach `~/.codex/agent-packs/` installiert. **Standardmäßig ist kein Pack aktiviert** — Aktivierung erfolgt ausdrücklich:

```bash
# Aktuellen Stand ansehen
~/.codex/bin/my-codex-packs status

# Pack sofort aktivieren
~/.codex/bin/my-codex-packs enable data-ai

# Profile bei der Installation wechseln
bash /tmp/my-codex/install.sh --profile minimal   # keine Packs
bash /tmp/my-codex/install.sh --profile dev       # data-ai + llmops
bash /tmp/my-codex/install.sh --profile full      # alle installierten Packs
```

| Pack | Anzahl | Agenten |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

</details>

<details>
<summary><strong>Skills — 123 aus 4 Quellen</strong></summary>

Die kuratierten Allowlists pro Skill stehen in `scripts/skill-allowlists.sh` — diese Datei ist maßgeblich dafür, was ausgeliefert wird.

| Quelle | Anzahl | Wichtige Skills |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 79 | coding-standards, python-testing, api-design, deep-research |
| [gstack](https://github.com/garrytan/gstack) | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 13 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |

gstack zählt als 26 Allowlist-Skills plus den Repository-Root-Eintrag. Das gesamte gstack-Repository liegt zusätzlich unter `~/.codex/skills/gstack` als sein kanonischer Runtime-Baum.

Codex bringt **keine Dokument-Skills** mit — in diesem Bundle gibt es kein `pdf`, `docx`, `pptx` oder `xlsx`.

</details>

<details>
<summary><strong>MCP-Server (3)</strong></summary>

| Server | Zweck | Kosten |
|--------|-------|--------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://mcp.context7.com) | Echtzeit-Bibliotheksdokumentation | Kostenlos |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://mcp.exa.ai) | Semantische Websuche | Kostenlos 1k Anfragen/Monat |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://mcp.grep.app) | GitHub-Code-Suche | Kostenlos |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian-kompatibler persistenter Speicher. Jedes Projekt pflegt ein `.briefing/`-Verzeichnis, das sich über Sitzungen hinweg automatisch befüllt.

```
.briefing/
├── INDEX.md                          ← Project context (auto-created once)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← AI-written session summary (enforced)
│   └── YYYY-MM-DD-auto.md           ← Auto-generated scaffold (git diff, agent stats)
├── decisions/
│   ├── YYYY-MM-DD-<decision>.md     ← AI-written decision record
│   └── YYYY-MM-DD-auto.md           ← Auto-generated scaffold (commits, files)
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← AI-written learning note
│   └── YYYY-MM-DD-auto-session.md   ← Auto-generated scaffold (agents, files)
├── references/
│   └── auto-links.md                ← Auto-collected URLs from web searches
├── agents/
│   ├── agent-log.jsonl              ← Subagent execution telemetry
│   └── YYYY-MM-DD-summary.md        ← Daily agent usage breakdown
├── persona/
│   ├── profile.md                   ← Agent affinity stats (auto-updated)
│   ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
│   ├── rules/                       ← Accepted routing preferences
│   └── skills/                      ← Accepted persona skills
├── archives/                         ← Abgeschlossene/inaktive Notizen (30+ Tage)
│   ├── sessions/
│   ├── decisions/
│   └── learnings/
└── wiki/                             ← Konzeptseiten (automatisch vorgeschlagen)
    └── _schema.md
```

### Automatisierungs-Lebenszyklus

| Phase | Hook-Ereignis | Was passiert |
|-------|--------------|--------------|
| **Sitzungsstart** | `SessionStart` | Erstellt `.briefing/`-Struktur, speichert git-HEAD-Hash für sitzungsspezifische Diffs |
| **Während der Arbeit** | `PostToolUse` Edit/Write | Verfolgt die Anzahl der Dateibearbeitungen; warnt bei 5, sperrt bei 15, wenn keine Entscheidungen/Lernnotizen geschrieben wurden |
| **Während der Arbeit** | `PostToolUse` WebSearch/WebFetch | Sammelt URLs automatisch in `references/auto-links.md` |
| **Während der Arbeit** | `SubagentStop` | Protokolliert Agentenausführung in `agents/agent-log.jsonl` |
| **Während der Arbeit** | `UserPromptSubmit` (every 5th) | Gedrosseltes Persona-Profil-Update |
| **Sitzungsende** | `Stop` (1. Hook) | Generiert automatisch Gerüste: `sessions/auto.md`, `learnings/auto-session.md`, `decisions/auto.md`, `persona/profile.md` |
| **Sitzungsende** | `Stop` (2. Hook) | **Erzwingt** KI-erstellte Sitzungszusammenfassung bei ≥ 3 Dateibearbeitungen — blockiert Sitzungsende mit Vorlage |
| **archives/** | — | Schlägt automatisch vor, abgeschlossene/inaktive Notizen ab 30+ Tagen zu archivieren. PARA-Archiv-Konzept. |
| **wiki/** | — | Konzept-Wiki-Seiten. Automatisch vorgeschlagen, wenn ein Schlüsselwort 3+ Mal vorkommt. LLM-wiki-Konzept. |

### Automatisch generiert vs. KI-erstellt

| Typ | Dateimuster | Erstellt von | Inhalt |
|-----|-------------|-------------|--------|
| **Auto-Gerüst** | `*-auto.md`, `*-auto-session.md` | Stop hook (Node.js) | Git-Diff-Statistiken, Agentennutzung, Commit-Liste — nur Daten |
| **KI-Zusammenfassung** | `YYYY-MM-DD-<topic>.md` | KI während der Sitzung | Aussagekräftige Analyse mit Kontext, Code-Referenzen, Begründung |
| **Telemetrie** | `agent-log.jsonl`, `auto-links.md` | Hook-Skripte | Nur-Anhänge-strukturierte Protokolle |
| **Persona** | `profile.md`, `suggestions.jsonl` | Stop hook | Nutzungsbasierte Agenten-Affinität und Routing-Vorschläge |

Auto-Gerüste dienen als **Referenzdaten** für die KI zum Verfassen angemessener Zusammenfassungen. Der Durchsetzungs-Hook stellt den Gerüstinhalt + eine strukturierte Vorlage bereit, wenn das Sitzungsende blockiert wird.

### Sitzungsspezifische Diffs

Beim Sitzungsstart wird der aktuelle git-HEAD in `.briefing/.session-start-head` gespeichert. Am Sitzungsende werden Diffs relativ zu diesem gespeicherten Punkt berechnet — es werden nur Änderungen aus der aktuellen Sitzung angezeigt, keine angesammelten nicht committeten Änderungen aus vorherigen Sitzungen.

### Verwendung mit Obsidian

1. Öffnen Sie Obsidian → **Ordner als Vault öffnen** → `.briefing/` auswählen
2. Notizen erscheinen in der Graphansicht, verknüpft durch `[[wiki-links]]`
3. YAML-Frontmatter (`date`, `type`, `tags`) ermöglicht strukturierte Suche
4. Eine Zeitleiste von Entscheidungen und Lernnotizen entsteht automatisch über Sitzungen hinweg

### Wissensmanagement (v2)

BriefingVault v2 integriert drei Wissensmanagement-Methoden:

| Methode | Konzept | Anwendung in BriefingVault |
|---------|---------|---------------------------|
| **PARA** (Tiago Forte) | Organisieren nach Handlungsfähigkeit: Projekte, Bereiche, Ressourcen, Archive | sessions/ = Projekte, decisions/ = Bereiche, references/ = Ressourcen, archives/ = Archive |
| **Zettelkasten** (Luhmann) | Atomare Notizen mit eindeutigen IDs und expliziten Links | learnings/-Dateien: `YYYYMMDDHHMMSS`-IDs, `related:` mindestens 2 Links erforderlich |
| **LLM-wiki** (Karpathy) | KI-gepflegte Konzeptseiten aus Quellnotizen | wiki/-Seiten: automatisch vorgeschlagen bei 3+ Wiederholungen eines Schlüsselworts |

---

## Upstream Open-Source-Quellen

my-codex verfolgt **4 Upstream-Submodule**, dazu einen eingebundenen Snapshot und zwei angepasste bzw. Schwesterprojekte:

| # | Quelle | Methode | Was bereitgestellt wird |
|---|--------|---------|------------------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | Submodul | 79 Allowlist-Skills für Entwicklungsworkflows. Claude Code-spezifische Inhalte entfernt; generische Coding-Skills beibehalten. |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | Submodul | 27 Skills für Code-Review, QA, Sicherheits-Audit und Deployment. Enthält Playwright-Browser-Daemon. |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | Submodul | 7 Allowlist-Worker-Agenten (executor, planner, architect, test-engineer, security-reviewer, code-reviewer, debugger), aus Markdown-Prompts nach Codex-TOML konvertiert. |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | Submodul | 13 Skills zu Brainstorming, TDD, systematischem Debugging und Planerstellung. Es werden keine Agenten installiert. |
| 5 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | eingebunden (MIT) | 17 KI/LLM-Agenten als Snapshot in `codex-agents/packs/`, ausgeliefert als 2 Opt-in-Packs (data-ai 13, llmops 4). Submodul am 2026-07-27 entfernt. |
| 6 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | angepasst | 9 OMO-Agenten (Sisyphus, Atlas, Oracle usw.). Für das native Codex-TOML-Format angepasst und im Repository gepflegt. |
| 7 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | Schwesterprojekt | Dieselbe Boss-Orchestrierung im nativen Claude `.md`-Agentenformat. Skills, Regeln und Briefing Vault werden zwischen beiden Projekten geteilt. |

Jedes Submodul ist in `upstream/SOURCES.json` (AI-BOM) per SHA gepinnt; dort sind auch die beiden entfernten Submodule vermerkt (`agency-agents` — nichts eingebunden; `awesome-codex-subagents` — 17 Agenten eingebunden).

---

## GitHub Actions

| Workflow | Auslöser | Zweck |
|----------|----------|-------|
| **CI** | push, PR | Validiert TOML-Agentendateien, Skill-Existenz und Upstream-Dateianzahlen |
| **Smoke Tests** | push, PR | Jobs `hooks`, `shell`, `drift`, `routing-refs` — Hook-Verdrahtung, Shell-Syntax, Modell-Drift und AGENTS.md-Routing-Referenzen |
| **Update Upstream** | alle 3 Tage / manuell | Sicherheitsgeprüftes `git submodule update --remote`, aktualisiert die Pins in `upstream/SOURCES.json` und erstellt einen Auto-Merge-PR |
| **Auto Tag** | push to main | Liest die Version aus `config.toml` und erstellt ein git-Tag, wenn neu |
| **Pages** | push to main | Deployt `docs/index.html` auf GitHub Pages |
| **CLA** | PR | Prüfung des Contributor License Agreement |
| **Lint Workflows** | push, PR | Validiert die YAML-Syntax der GitHub Actions-Workflows |

---

## my-codex Originals

Funktionen, die speziell für dieses Projekt entwickelt wurden und über das hinausgehen, was Upstream-Quellen bieten:

| Funktion | Beschreibung |
|----------|-------------|
| **Boss Meta-Orchestrator** | Dynamische Fähigkeitsentdeckung → Absichtsklassifizierung → 4-Prioritäten-Routing → Delegation → Verifikation |
| **3-Phasen-Sprint** | Design (interaktiv) → Ausführung (autonom über executor) → Review (interaktiv vs. Design-Dokument) |
| **Agenten-Tier-Priorität** | core > omo > omx > Opt-in-Packs. Pack-Agenten mit Namenskollision zu einem bereits installierten Agenten werden übersprungen. Der speziellste Agent gewinnt. |
| **Kostenoptimierung** | gpt-5.6-luna für Beratung, gpt-5.6-sol für Implementierung — automatisches Modell-Routing über alle 34 installierten Agenten |
| **Agenten-Telemetrie** | PostToolUse-Hook protokolliert Agentennutzung in `agent-usage.jsonl` |
| **Smart Packs** | Projekttypenerkennung empfiehlt relevante Agenten-Packs beim Sitzungsstart |
| **Agenten-Pack-System** | On-demand-Domänenspezialisten-Aktivierung über `--profile` und `my-codex-packs`-Hilfsprogramm |
| **Codex Attribution** | git hooks zeichnen von Codex berührte Dateien auf und hängen `AI-Contributed-By: Codex` an Commit-Nachrichten an |
| **CI Dedup Detection** | Automatische Erkennung doppelter TOML-Agenten über Upstream-Syncs hinweg |

---

## Installationsoptionen

### Schnellinstallation

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Wenn Sie denselben Befehl erneut ausführen, wird auf den neuesten `main`-Build aktualisiert, es werden nur von my-codex verwaltete Dateien in `~/.codex/` ersetzt, und veraltete Skill-Kopien aus `~/.agents/skills/` werden entfernt.

### Agenten-Pack-Profile

Packs werden installiert, sind aber **standardmäßig inaktiv** — eine Neuinstallation aktiviert keines und schreibt die leere Menge nach `~/.codex/enabled-agent-packs.txt`. Aktiviere einzelne Packs oder wähle ein Profil:

```bash
# Ein Pack sofort aktivieren
~/.codex/bin/my-codex-packs enable data-ai

# Minimal-Profil (nur Kern-Agenten, keine Packs — Standard)
bash /tmp/my-codex/install.sh --profile minimal

# Dev-Profil (data-ai + llmops)
bash /tmp/my-codex/install.sh --profile dev

# Full-Profil (beide installierten Pack-Kategorien aktiviert)
bash /tmp/my-codex/install.sh --profile full
```

### Codex Attribution System

`install.sh` installiert einen `codex`-Wrapper sowie globale git-Hooks in `~/.codex/git-hooks/`:

- **`prepare-commit-msg`** — Zeichnet Dateien auf, die während einer echten Codex-Sitzung geändert wurden
- **`commit-msg`** — Hängt `Generated with Codex CLI: https://github.com/openai/codex` an, wenn gestage Dateien die aufgezeichneten Änderungen schneiden
- **`post-commit`** — Fügt den Trailer `AI-Contributed-By: Codex` zu qualifizierenden Commits hinzu

Opt-in `Co-authored-by`-Trailer: Setzen Sie sowohl `git config --global my-codex.codexContributorName '<label>'` als auch `my-codex.codexContributorEmail '<github-linked-email>'`. Vollständig deaktivieren: `git config --global my-codex.codexAttribution false`. my-codex ändert **nicht** `git user.name`, `git user.email` oder die Commit-Autorenidentität.

### Agenten-TOML-Format

Jeder Agent ist eine native TOML-Datei in `~/.codex/agents/`:

```toml
name = "debugger"
description = "Focused debugging specialist — traces failures to root cause"
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"

[developer_instructions]
content = """
You are a debugging specialist. Analyze failures systematically:
1. Reproduce the issue
2. Isolate the root cause
3. Propose a minimal fix
4. Verify the fix does not break adjacent behavior
"""
```

### config.toml

Globale Codex-Einstellungen in `~/.codex/config.toml`:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — Maximale Anzahl gleichzeitiger Sub-Agenten
- `max_depth` — Maximale Verschachtelungstiefe für Agent-spawnt-Agent-Ketten

---

## Gebündelte Upstream-Versionen

Upstream-Quellen werden als git-Submodule verwaltet. Festgelegte Commits werden in `.gitmodules` verfolgt.

| Quelle | Sync |
|--------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | Submodul (`upstream/ecc`) |
| [gstack](https://github.com/garrytan/gstack) | Submodul (`upstream/gstack`) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | Submodul (`upstream/omx`) |
| [superpowers](https://github.com/obra/superpowers) | Submodul (`upstream/superpowers`) |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | eingebundener Snapshot (Submodul am 2026-07-27 entfernt) |

---

## Häufig gestellte Fragen

<details>
<summary><strong>Wie unterscheidet sich my-codex von my-claude?</strong></summary>

my-codex und my-claude teilen dieselbe Boss-Orchestrierungsarchitektur und dieselben Upstream-Skill-Quellen. Der wesentliche Unterschied liegt in der Laufzeitumgebung: my-codex richtet sich an OpenAI Codex CLI mit nativem `.toml`-Agentenformat und `spawn_agent`-Delegation, während my-claude auf Claude Code mit `.md`-Agentenformat und dem Agent-Tool abzielt.

</details>

<details>
<summary><strong>Kann ich sowohl my-codex als auch my-claude verwenden?</strong></summary>

Ja. Sie installieren sich in separate Verzeichnisse (`~/.codex/` und `~/.claude/`) und verursachen keine Konflikte. Skills aus gemeinsamen Upstream-Quellen sind für jede Plattform angepasst.

</details>

<details>
<summary><strong>Wie funktionieren Agenten-Packs?</strong></summary>

Agenten-Packs sind domänenspezifische Agentensammlungen, die in `~/.codex/agent-packs/` installiert werden. Derzeit gibt es zwei Packs — `data-ai` (13) und `llmops` (4) — und **bei der Installation ist keines aktiviert**. Verwenden Sie `my-codex-packs enable <pack>`, um eines zu aktivieren, oder installieren Sie mit `--profile full` neu, um beide Kategorien zu aktivieren.

</details>

<details>
<summary><strong>Wie funktioniert der Upstream-Sync?</strong></summary>

Ein GitHub Actions-Workflow läuft alle 3 Tage, zieht die neuesten Commits aus allen 4 Upstream-Submodulen, aktualisiert die SHA-Pins in `upstream/SOURCES.json` und erstellt einen sicherheitsgeprüften Auto-Merge-PR. Sie können ihn auch manuell über den Actions-Tab auslösen.

</details>

<details>
<summary><strong>Welche Modelle verwendet my-codex?</strong></summary>

Boss und Sub-Orchestratoren (Sisyphus, Atlas, Oracle) verwenden gpt-5.6-sol mit hohem Reasoning-Aufwand. Standard-Worker verwenden gpt-5.6-terra mit mittlerem Reasoning. Leichtgewichtige Beratungsagenten verwenden gpt-5.6-luna.

</details>

---

## Fehlerbehebung

### Nur-Skills-Wiederherstellung

Wenn ein Tool ungültige `SKILL.md`-Dateien unter `~/.agents/skills/` meldet, ist die häufigste Ursache eine veraltete lokale Kopie oder ein veraltetes Symlink-Ziel aus einer älteren Installation.

Entfernen Sie die betroffenen Verzeichnisse aus `~/.agents/skills/` und die entsprechenden Einträge unter `~/.claude/skills/`, dann installieren Sie neu:

```bash
npx skills add sehoon787/my-codex -y -g
```

Wenn Sie das vollständige Codex-Bundle verwenden, führen Sie auch `install.sh` einmal erneut aus. Das vollständige Installationsprogramm aktualisiert `~/.codex/skills/` und entfernt veraltete, von my-codex verwaltete Kopien unter `~/.agents/skills/`.

---

## Mitwirken

Issues und PRs sind willkommen. Wenn Sie einen neuen Agenten hinzufügen, fügen Sie eine `.toml`-Datei zu `codex-agents/core/` oder `codex-agents/omo/` hinzu und aktualisieren Sie die Agentenliste in `SETUP.md`. Weitere Informationen zu PR-Validierungsschritten und zum Codex-Commit-Attributionsverhalten finden Sie in [CONTRIBUTING.md](./CONTRIBUTING.md).

## Danksagungen

Aufgebaut auf der Arbeit von: [my-claude](https://github.com/sehoon787/my-claude) (sehoon787), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m), [gstack](https://github.com/garrytan/gstack) (garrytan), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo), [superpowers](https://github.com/obra/superpowers) (Jesse Vincent), [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent), [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu), [openai/skills](https://github.com/openai/skills) (OpenAI).

## Lizenz

MIT-Lizenz. Weitere Informationen finden Sie in der Datei [LICENSE](./LICENSE).
