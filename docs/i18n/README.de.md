[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Suchen Sie nach Claude Code? → **my-claude** — dieselbe Boss-Orchestrierung im nativen Claude `.md`-Agentenformat

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-330%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

**All-in-one Agent-Harness für OpenAI Codex CLI.**
**Einmal installieren, 330+ Agenten bereit.**

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
| **P1** | Skill-Treffer | Aufgabe entspricht einer eigenständigen Skill | `"merge PDFs"` → pdf skill |
| **P2** | Spezialist-Agent | Domänenspezifischer Agent vorhanden | `"security audit"` → security-reviewer |
| **P3a** | Boss direkt | 2–4 unabhängige Agenten | `"fix 3 bugs"` → parallel spawn |
| **P3b** | Sub-Orchestrator | Komplexer mehrstufiger Workflow | `"refactor + test"` → Sisyphus |
| **P4** | Fallback | Kein Spezialist gefunden | `"explain this"` → general agent |

### Modell-Routing

| Komplexität | Modell | Verwendet für |
|-------------|--------|---------------|
| Tiefgehende Analyse, Architektur | o3 (high reasoning) | Boss, Oracle, Sisyphus, Atlas |
| Standardimplementierung | o3 (medium) | executor, debugger, security-reviewer |
| Schnelle Suche, Erkundung | o4-mini (low) | explore, einfache Beratung |

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
│  Boss · Meta-Orchestrator (o3 high)                   │
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
│  Agent Layer (330+ installed TOML files)              │
│  OMO 9 · OMX 33 · Awesome Core 54 · Superpowers 1   │
│  + 20 domain agent-packs (on-demand)                  │
├─────────────────────────────────────────────────────┤
│  Skills Layer (200+ from ECC + gstack + OMX + more)  │
│  tdd-workflow · security-review · autopilot           │
│  pdf · docx · pptx · xlsx · team                     │
├─────────────────────────────────────────────────────┤
│  MCP Layer                                            │
│  Context7 · Exa · grep.app                            │
└─────────────────────────────────────────────────────┘
```

---

## Was enthalten ist

| Kategorie | Anzahl | Quelle |
|-----------|-------:|--------|
| **Kern-Agenten** (immer geladen) | 98 | Boss 1 + OMO 9 + OMX 33 + Awesome Core 54 + Superpowers 1 |
| **Agenten-Packs** (on-demand) | 220+ | 20 Domänenkategorien aus agency-agents + awesome-codex-subagents |
| **Skills** | 200+ | ECC 180+ · gstack 40 · OMX 36 · Superpowers 14 · Core 1 |
| **MCP-Server** | 3 | Context7, Exa, grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>Kern-Agent — Boss Meta-Orchestrator (1)</strong></summary>

| Agent | Modell | Rolle | Quelle |
|-------|--------|-------|--------|
| Boss | o3 high | Dynamische Laufzeitentdeckung → Fähigkeitsabgleich → optimales Routing. Schreibt niemals Code. | my-codex |

</details>

<details>
<summary><strong>OMO-Agenten — Sub-Orchestratoren und Spezialisten (9)</strong></summary>

| Agent | Modell | Rolle | Quelle |
|-------|--------|-------|--------|
| Sisyphus | o3 high | Absichtsklassifizierung → Spezialistendelegation → Verifikation | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | o3 high | Autonom erkunden → planen → ausführen → verifizieren | oh-my-openagent |
| Atlas | o3 high | Aufgabenzerlegung + 4-stufige QA-Verifikation | oh-my-openagent |
| Oracle | o3 high | Strategische technische Beratung (nur lesend) | oh-my-openagent |
| Metis | o3 high | Absichtsanalyse, Mehrdeutigkeitserkennung | oh-my-openagent |
| Momus | o3 high | Überprüfung der Planumsetzbarkeit | oh-my-openagent |
| Prometheus | o3 high | Interviewbasierte detaillierte Planung | oh-my-openagent |
| Librarian | o3 medium | Open-Source-Dokumentationssuche über MCP | oh-my-openagent |
| Multimodal-Looker | o3 medium | Bild-/Screenshot-/Diagrammanalyse | oh-my-openagent |

</details>

<details>
<summary><strong>OMC-Agenten — Spezialistenmitarbeiter (19)</strong></summary>

| Agent | Rolle | Quelle |
|-------|-------|--------|
| analyst | Voranalyse vor der Planung | [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) |
| architect | Systemdesign und Architektur | oh-my-claudecode |
| code-reviewer | Fokussierter Code-Review | oh-my-claudecode |
| code-simplifier | Code-Vereinfachung und -Bereinigung | oh-my-claudecode |
| critic | Kritische Analyse, alternative Vorschläge | oh-my-claudecode |
| debugger | Fokussiertes Debugging | oh-my-claudecode |
| designer | UI/UX-Design-Anleitung | oh-my-claudecode |
| document-specialist | Dokumentationserstellung | oh-my-claudecode |
| executor | Aufgabenausführung | oh-my-claudecode |
| explore | Codebasis-Erkundung | oh-my-claudecode |
| git-master | Git-Workflow-Verwaltung | oh-my-claudecode |
| planner | Schnelle Planung | oh-my-claudecode |
| qa-tester | Qualitätssicherungstests | oh-my-claudecode |
| scientist | Forschung und Experimente | oh-my-claudecode |
| security-reviewer | Sicherheitsüberprüfung | oh-my-claudecode |
| test-engineer | Test-Erstellung und -Pflege | oh-my-claudecode |
| tracer | Ausführungs-Tracing und Analyse | oh-my-claudecode |
| verifier | Abschließende Verifikation | oh-my-claudecode |
| writer | Inhalte und Dokumentation | oh-my-claudecode |

</details>

<details>
<summary><strong>Awesome Core Agents (54) — Aus awesome-codex-subagents</strong></summary>

4 Kategorien installiert in `~/.codex/agents/`:

**01-core-development (12)**
accessibility-tester, ad-security-reviewer, agent-installer, api-designer, code-documenter, code-reviewer, dependency-manager, full-stack-developer, monorepo-specialist, performance-optimizer, refactoring-specialist, tech-debt-analyzer

**03-infrastructure (16)**
azure-infra-engineer, cloud-architect, container-orchestrator, database-architect, disaster-recovery-planner, edge-computing-specialist, infrastructure-as-code, kubernetes-operator, load-balancer-specialist, message-queue-designer, microservices-architect, monitoring-specialist, network-engineer, serverless-architect, service-mesh-designer, storage-architect

**04-quality-security (16)**
api-security-tester, chaos-engineer, compliance-auditor, contract-tester, data-privacy-officer, e2e-test-architect, incident-responder, load-tester, mutation-tester, penetration-tester, regression-tester, security-scanner, soc-analyst, static-analyzer, threat-modeler, vulnerability-assessor

**09-meta-orchestration (10)**
agent-organizer, capability-assessor, conflict-resolver, context-manager, execution-planner, multi-agent-coordinator, priority-manager, resource-allocator, task-decomposer, workflow-orchestrator

</details>

<details>
<summary><strong>Superpowers Agent (1) — Aus obra/superpowers</strong></summary>

| Agent | Rolle | Quelle |
|-------|-------|--------|
| superpowers-code-reviewer | Umfassender Code-Review mit Brainstorming und TDD-Verifikation | [superpowers](https://github.com/obra/superpowers) |

</details>

<details>
<summary><strong>Agenten-Packs — On-demand-Domänenspezialisten (21 Kategorien)</strong></summary>

Installiert in `~/.codex/agent-packs/`. Verwaltung über:

```bash
# Aktuellen Status anzeigen
~/.codex/bin/my-codex-packs status

# Ein Pack sofort aktivieren
~/.codex/bin/my-codex-packs enable marketing

# Profile bei der Installation wechseln
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
```

| Pack | Anzahl | Beispiele |
|------|-------:|-----------|
| engineering | 32 | Backend, Frontend, Mobile, DevOps, AI, Data |
| marketing | 27 | Douyin, Xiaohongshu, WeChat OA, TikTok, SEO |
| language-specialists | 27 | Python, Go, Rust, Swift, Kotlin, Java |
| specialized | 31 | Legal, Finance, Healthcare, Workflow |
| game-development | 20 | Unity, Unreal, Godot, Roblox, Blender |
| infrastructure | 19 | Cloud, K8s, Terraform, Docker, SRE |
| developer-experience | 13 | MCP Builder, LSP, Terminal, Rapid Prototyper |
| data-ai | 13 | Data Engineer, ML, Database, ClickHouse |
| specialized-domains | 12 | Supply Chain, Logistics, E-Commerce |
| design | 11 | Brand, UI, UX, Visual Storytelling |
| business-product | 11 | Product Manager, Growth, Analytics |
| testing | 11 | API, Accessibility, Performance, E2E, QA |
| sales | 8 | Deal strategy, pipeline, outbound |
| paid-media | 7 | Google Ads, Meta Ads, Programmatic |
| research-analysis | 7 | Trend, Market, Competitive Analysis |
| project-management | 6 | Agile, Jira, workflows |
| spatial-computing | 6 | XR, WebXR, AR/VR, visionOS |
| support | 6 | Customer support, developer advocacy |
| academic | 5 | Study abroad, corporate training |
| product | 5 | Product management, UX research |
| security | 5 | Penetration testing, compliance, audit |

</details>

<details>
<summary><strong>Skills — 200+ aus 5 Quellen</strong></summary>

| Quelle | Anzahl | Wichtige Skills |
|--------|-------:|-----------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 180+ | tdd-workflow, autopilot, security-review, coding-standards |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 36 | plan, team, trace, deep-dive, blueprint, ultrawork |
| [gstack](https://github.com/garrytan/gstack) | 40 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 14 | brainstorming, systematic-debugging, TDD, parallel-agents |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 1 | boss-advanced |

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
└── persona/
    ├── profile.md                   ← Agent affinity stats (auto-updated)
    ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
    ├── rules/                       ← Accepted routing preferences
    └── skills/                      ← Accepted persona skills
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

---

## Upstream Open-Source-Quellen

my-codex bündelt Inhalte aus 8 Upstream-Repositories:

| # | Quelle | Was bereitgestellt wird |
|---|--------|------------------------|
| 1 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | Schwesterprojekt. Dieselbe Boss-Orchestrierung im nativen Claude `.md`-Agentenformat. Skills, Regeln und Briefing Vault werden zwischen beiden Projekten geteilt. |
| 2 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 136 produktionsreife Agenten im nativen TOML-Format. Bereits Codex-kompatibel, keine Konvertierung erforderlich. 54 Kern-Agenten werden automatisch geladen. |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 36 Skills, Hooks, HUD und Team-Pipelines für Codex CLI. Als architektonische Inspiration referenziert. |
| 4 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 180+ Business-Spezialistenagenten-Personas in 14 Kategorien. Über automatisierte Pipeline von Markdown in natives TOML konvertiert. |
| 5 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 180+ Skills für Entwicklungsworkflows. Claude Code-spezifische Inhalte entfernt; generische Coding-Skills beibehalten. |
| 6 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 Skills + 1 Agent zu Brainstorming, TDD, parallelen Agenten und Code-Review. |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 OMO-Agenten (Sisyphus, Atlas, Oracle usw.). Für das native Codex-TOML-Format angepasst. |
| 8 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 40 Skills für Code-Review, QA, Sicherheits-Audit und Deployment. Enthält Playwright-Browser-Daemon. |

---

## GitHub Actions

| Workflow | Auslöser | Zweck |
|----------|----------|-------|
| **CI** | push, PR | Validiert TOML-Agentendateien, Skill-Existenz und Upstream-Dateianzahlen |
| **Update Upstream** | wöchentlich (Montag) / manuell | Führt `git submodule update --remote` aus und erstellt einen Auto-Merge-PR |
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
| **Agenten-Tier-Priorität** | core > omo > omc > awesome-core-Deduplizierung. Der speziellste Agent gewinnt. |
| **Kostenoptimierung** | o4-mini für Beratung, o3 für Implementierung — automatisches Modell-Routing für 330+ Agenten |
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

Bei der Erstinstallation aktiviert my-codex automatisch ein empfohlenes `dev`-Set (`engineering`, `design`, `testing`, `marketing`, `support`) und speichert es in `~/.codex/enabled-agent-packs.txt`.

```bash
# Minimales Profil (nur Kern-Agenten, keine Packs)
bash /tmp/my-codex/install.sh --profile minimal

# Vollständiges Profil (alle 21 Pack-Kategorien aktiviert)
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
model = "o3"
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
| [agency-agents](https://github.com/msitarzewski/agency-agents) | submodule |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | submodule |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | submodule |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | submodule |
| [gstack](https://github.com/garrytan/gstack) | submodule |
| [superpowers](https://github.com/obra/superpowers) | submodule |

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

Agenten-Packs sind domänenspezifische Agentensammlungen, die in `~/.codex/agent-packs/` installiert werden. Bei der Erstinstallation wird automatisch ein `dev`-Profil aktiviert. Verwenden Sie `my-codex-packs enable <pack>`, um zusätzliche Packs zu aktivieren, oder installieren Sie mit `--profile full` neu, um alle 21 Kategorien zu aktivieren.

</details>

<details>
<summary><strong>Wie funktioniert der Upstream-Sync?</strong></summary>

Ein GitHub Actions-Workflow läuft jeden Montag, zieht die neuesten Commits aus allen Upstream-Submodulen und erstellt einen Auto-Merge-PR. Sie können ihn auch manuell über den Actions-Tab auslösen.

</details>

<details>
<summary><strong>Welche Modelle verwendet my-codex?</strong></summary>

Boss und Sub-Orchestratoren (Sisyphus, Atlas, Oracle) verwenden o3 mit hohem Reasoning-Aufwand. Standard-Worker verwenden o3 mit mittlerem Reasoning. Leichtgewichtige Beratungsagenten verwenden o4-mini.

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

Aufgebaut auf der Arbeit von: [my-claude](https://github.com/sehoon787/my-claude) (sehoon787), [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo), [agency-agents](https://github.com/msitarzewski/agency-agents) (msitarzewski), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m), [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu), [gstack](https://github.com/garrytan/gstack) (garrytan), [superpowers](https://github.com/obra/superpowers) (Jesse Vincent), [openai/skills](https://github.com/openai/skills) (OpenAI).

## Lizenz

MIT-Lizenz. Weitere Informationen finden Sie in der Datei [LICENSE](./LICENSE).
