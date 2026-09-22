[Englisch](../../README.md) | [Koreanisch](./README.ko.md) | [Japanisch](./README.ja.md) | [Chinesisch](./README.zh.md) | [Deutsch](./README.de.md) | [Französisch](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Auf der Suche nach Claude Code? → **my-claude** — dieselbe Boss-Orchestrierung im nativen Claude-`.md`-Agentenformat

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-30_default_%2F_110_installed-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**All-in-one-Agentenharness für die Codex CLI.**
**Einmal installieren, 17 Kernagenten sind einsatzbereit.**

Boss erkennt zur Laufzeit jeden Agenten, jeden Skill und jedes MCP-Werkzeug<br>
und leitet Ihre Aufgabe über `spawn_agent` an den passenden Spezialisten weiter. Keine Konfigurationsdateien. Kein Boilerplate.

<img src="../../assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## Installation

### Für Menschen

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

Oder zuerst klonen und das Installationsskript aus dem Checkout ausführen:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Dass die Standardinstallation nur wenige Skills sichtbar macht, ist Absicht:
Codex kürzt Skill-Beschreibungen, sobald sein Skill-Budget überschritten ist.
Deshalb zeigt das Standardprofil `core` Codex nur 30 der 110 installierten
Skill-Einträge; der Rest ist einen Schalter entfernt:

```bash
bash install.sh --skills=web          # ergänzt die 18 Skills der Web-/UI-Spur
bash install.sh --full-skills         # alle optionalen Spuren plus das Profil full
bash install.sh --skill-profile=core  # zurück zur Standardsichtbarkeit
```

Die Auswahl wird gespeichert und übersteht ein späteres schlichtes `bash install.sh`. Alle Profile, alle Spuren und die `my-codex-skills`-Befehle stehen unter [Skill-Profile und Spuren](#skill-profile-und-spuren).

In interaktiven Terminals erscheint eine Checkbox-Auswahl für die drei Begleitwerkzeuge — Serena, Headroom und codeburn —, standardmäßig alle drei ausgewählt. Navigieren mit ↑/↓ oder `j`/`k`, umschalten mit Space, `a` wählt alle, `n` keines, Enter oder Ctrl-D/EOF bestätigt die aktuelle Auswahl. Ist `TERM` leer oder `dumb` oder steht `stty` nicht zur Verfügung, greift die nummerierte Rückfallvariante: Enter, `all`, `a`, `y` oder `yes` für alle; `none`, `n`, `no` oder `0` für keines; gemischte Nummern und Namen wie `1,3` oder `serena codeburn` sind ebenfalls möglich. Automatisierte Läufe wählen standardmäßig alle:

```bash
bash install.sh --tools=headroom   # eine explizite Teilmenge
bash install.sh --yes              # alle drei, ohne Nachfrage
bash install.sh --skip-tools       # keines
```

Unter Windows patcht `install.sh` die npm-verwalteten Shims `codex`, `codex.cmd` und `codex.ps1`, sofern vorhanden, damit die Vault-Pipeline von my-codex ihre Wrapper-Absicherung behält, selbst wenn `%APPDATA%\npm` vor `~/.codex/bin` aufgelöst wird.

### Für KI-Agenten

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

Der Agent fragt vor dem Ausführen des Installers, welche Begleit-Tools (Serena, Headroom, codeburn) installiert werden sollen, da der Checkbox-Selektor nur in einem interaktiven Terminal erscheint.

---

## Verwendete Open-Source-Tools

Jedes Projekt, auf dem my-codex aufbaut, was es beiträgt und wie es hineinkommt. Nur diese Tabelle beschreibt die einzelnen Projekte; der Rest dieser README führt lediglich Bestände, Befehle und Pins auf.

| # | Projekt | Was my-codex davon übernimmt | Wie es hineinkommt |
|---|---------|------------------------------|--------------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 61 freigegebene Skills: Stack-Muster (TypeScript, React, Python/Django/FastAPI, Spring Boot/Kotlin, SQL/Redis/Prisma, Docker/Kubernetes), KI- und Agenten-Engineering sowie generische Codebase-Werkzeuge wie Onboarding, Code-Touren und ADRs. Claude-Code-spezifische Inhalte werden entfernt, und eine Spur mit 18 Web-/UI-Skills bleibt außerhalb der Standardinstallation. | Submodul `upstream/ecc`; `install.sh` kopiert nur die in `scripts/skill-allowlists.sh` freigegebenen Namen |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 30 Sprint-Prozess-Einträge — Browser-QA (`qa`), Code-Review auf Scope-Abweichung (`review`), Sicherheitsaudit (`cso`) und der vollständige Ablauf Plan → Review → Ship — dazu ein kompilierter Playwright-Browser-Daemon. | Submodul `upstream/gstack`, abgelegt unter `~/.codex/vendor/gstack`, wo sein eigenes `./setup --host codex` unter bun läuft und neben dem `gstack`-Router-Verzeichnis 29 Symlinks unter `~/.codex/skills/` anlegt; die 7 davon abgelösten ECC-Skills (`benchmark`, `canary-watch`, `safety-guard`, `browser-qa`, `verification-loop`, `security-review`, `design-system`) werden entfernt, sodass nur die gstack-Variante routingfähig bleibt |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 7 freigegebene Arbeitsagenten: `executor`, `planner`, `architect`, `test-engineer`, `security-reviewer`, `code-reviewer`, `debugger`. Die übrigen Prompts und Skills überschneiden sich mit Agenten, die dieses Repository bereits mitbringt, und werden bewusst nicht installiert. | Submodul `upstream/omx`; `scripts/md-to-toml.sh` wandelt die freigegebenen Prompts aus Markdown in `~/.codex/agents/*.toml` um |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 Entwicklungsprozess-Skills: Brainstorming, systematisches Debuggen, testgetriebene Entwicklung, Planerstellung und -ausführung, Worktree-Handhabung und Code-Review-Etikette. Es wird kein Agent übernommen — sein einziger `code-reviewer`-Prompt überschneidet sich mit dem von oh-my-codex. | Submodul `upstream/superpowers`; alle 15 Skill-Verzeichnisse werden installiert außer `dispatching-parallel-agents`, das den Delegationspfad von Boss dupliziert |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | 1 Diagramm-Skill, der Beschreibungen von Architektur, Workflow, Sequenz, Datenfluss und Lebenszyklus in eine einzige eigenständige HTML-Datei mit Inline-SVG, Hell-/Dunkel-Umschalter und PNG-/JPEG-/WebP-/SVG-Export verwandelt. | Submodul `upstream/archify`, auf Tag `v2.9.0` gepinnt, damit der Sync-Job es in Ruhe lässt; nur das Verzeichnis `archify/` auf oberster Repository-Ebene wird nach `~/.codex/skills/archify` kopiert, sodass bei der Installation kein `npx skills add` läuft |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 17 Codex-native TOML-Agenten, ausgeliefert als die beiden Opt-in-Packs `data-ai` (13) und `llmops` (4). Eine Neuinstallation aktiviert keines der beiden Packs. | Unter MIT-Namensnennung nach `codex-agents/packs/` eingebettet und nach `~/.codex/agent-packs/` installiert; Submodul am 2026-07-27 entfernt. Aktivierung mit `~/.codex/bin/my-codex-packs enable data-ai` oder `install.sh --profile dev` |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 Agenten — `sisyphus`, `atlas`, `prometheus`, `oracle`, `metis`, `momus`, `hephaestus`, `librarian`, `multimodal-looker` — für durchgängige Orchestrierung, Planausführung und -prüfung, fundierte Zweitmeinungen, quellenbelegte Bibliotheksrecherche und das Lesen von Mediendateien. | An Codex-natives TOML angepasst und im Repository unter `codex-agents/omo/` gepflegt, sodass sie ohne Upstream-Checkout installiert werden |
| 8 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | Nichts. Kein Agent aus diesen Packs wurde in diesem Repository je eingesetzt, also wurde nichts eingebettet. | Entfernt (MIT) — Submodul am 2026-07-27 abgelegt, weiterhin in `upstream/SOURCES.json` vermerkt |
| 9 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | Dieselbe Boss-Orchestrierung im nativen Claude-`.md`-Agentenformat und zugleich die redaktionelle Grundlage: `scripts/skill-allowlists.sh` übernimmt die ECC-, gstack- und superpowers-Listen von my-claude wortgleich, damit beide Harnesses dieselbe Upstream-Oberfläche zeigen. | Nur als Schwesterprojekt verlinkt — `install.sh` klont, lädt und kopiert nichts davon, also wird nichts eingebettet und es gibt keinen Pin. Nebeneinander installiert stimmen die beiden Installationsskripte codeburn und Headroom über ein einziges benutzerweites Lock- und Statusverzeichnis ab, statt sich um die festen Ports zu streiten |
| 10 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | Lokale Token- und Kostenerfassung über die Sitzungsdateien, die Codex ohnehin unter `~/.codex/sessions` schreibt — kein Proxy, kein API-Schlüssel, keine Codex-Hooks. | `npm i -g codeburn@0.9.23`; `install.sh` startet oder verwendet einen gemeinsamen `codeburn web --provider all --port 4747 --no-open`-Prozess |
| 11 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | Strukturelle Suche und Umschreibung, die auf dem Syntaxbaum statt auf Rohtext greift, sodass Agenten Codeformen ohne brüchige reguläre Ausdrücke ändern können. | `npm i -g @ast-grep/cli@0.42.0`, übersprungen, wenn bereits eine `ast-grep`-Binärdatei im `PATH` liegt |
| 12 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | Der Symbolgraph eines Language Servers über MCP — `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` —, sodass Tokens mit dem Symbol statt mit der ganzen Datei skalieren. Das ausgelieferte Paket ist als Ganzes GPL-3.0-or-later (die MIT-Metadaten auf PyPI sind falsch), deshalb wird nichts eingebettet. | `uv tool install --python 3.13 serena-agent==1.7.0`, registriert als `[mcp_servers.serena]` (stdio: `serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False`, `startup_timeout_sec = 15`) |
| 13 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | Apache-2.0-Kontextkomprimierung über MCP: `headroom_compress`, `headroom_retrieve` und `headroom_stats`. Der Proxy-Modus `headroom wrap` bleibt ein dokumentiertes manuelles Opt-in. | `uv tool install --python 3.13 "headroom-ai[all]==0.37.0"`, registriert als `[mcp_servers.headroom]` (`headroom mcp serve`, `default_tools_approval_mode = "approve"`, weil der Server keine MCP-Annotationen veröffentlicht); das Installationsskript startet oder verwendet das gemeinsame Profil `agent-harness-shared` auf Port 8787 und setzt niemals `ANTHROPIC_BASE_URL` oder `OPENAI_BASE_URL` |
| 14 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | Antworten zu Bibliotheken, Frameworks und SDKs aus aktueller Upstream-Dokumentation statt aus dem Modellgedächtnis. Es ist das Backend, auf das der Skill `documentation-lookup` zugreift. | Gehosteter MCP-Server unter `https://mcp.context7.com/mcp` |
| 15 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | Neuronale Websuche. Die registrierte URL aktiviert nur `web_search_exa` und hält den Rechercheweg auf ein einziges Werkzeug statt auf die gesamte Exa-Oberfläche. | Gehosteter MCP-Server unter `https://mcp.exa.ai/mcp?tools=web_search_exa` |
| 16 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | Repository-übergreifende Codesuche über öffentliches GitHub, damit ein Agent vor dem Schreiben echte Aufrufstellen einer Bibliothek in vielen Repositories nachschlagen kann. | Gehosteter MCP-Server unter `https://mcp.grep.app` |

---

## Wie Boss funktioniert

Boss ist der Meta-Orchestrator im Kern von my-codex. Er schreibt nie Code — er erkennt, klassifiziert, ordnet zu, delegiert und verifiziert. Die Codex-Hauptsitzung übernimmt die Boss-Rolle über die installierte `AGENTS.md` und delegiert daher direkt an Spezialisten, statt erst einen weiteren Boss zu starten. Ihre native Sitzungsidentität bleibt Codex/root; eine Neuinstallation aktualisiert die verwalteten Anweisungen und erhält dabei angepasste Abschnitte.

| Phase | Was passiert |
|-------|--------------|
| **0 · Erkennung** | Scannt zur Laufzeit `~/.codex/agents/*.toml` in ein lebendes Fähigkeitsregister |
| **1 · Intent-Gate** | Klassifiziert die Anfrage (trivial, build, refactor, mid-sized, architecture, research, …) und schlägt einen passenderen Skill gegenvor |
| **2 · Fähigkeitsabgleich** | Durchläuft die Prioritätskette unten (P1 exakter Skill → P2 Spezialagent → P3 Multi-Agenten-Orchestrierung → P4 allgemeiner Rückfall) |
| **3 · Delegation** | Ruft `spawn_agent` mit einem sechsteiligen strukturierten Prompt auf: TASK / OUTCOME / TOOLS / DO / DON'T / CTX |
| **4 · Verifikation** | Liest die geänderten Dateien eigenständig, führt Tests, Lint und Build aus, gleicht mit der ursprünglichen Absicht ab und wiederholt bei Fehlern bis zu 3× |

### Prioritäts-Routing

Boss führt jede Anfrage durch eine Prioritätskette, bis der beste Treffer gefunden ist:

| Priorität | Treffertyp | Wann | Beispiel |
|:--------:|-----------|------|---------|
| **P1** | Skill-Treffer | Aufgabe entspricht einem eigenständigen Skill | `"review this diff"` → /review-Skill |
| **P2** | Spezialagent | Ein domänenspezifischer Agent existiert | `"security audit"` → security-reviewer |
| **P3a** | Boss direkt | 2–4 unabhängige Agenten | `"fix 3 bugs"` → paralleler Start |
| **P3b** | Sub-Orchestrator | Komplexer mehrstufiger Workflow | `"refactor + test"` → Sisyphus |
| **P4** | Rückfall | Kein Spezialist passt | `"explain this"` → allgemeiner Agent |

### Modell-Routing

| Komplexität | Modell | Eingesetzt für |
|-----------|-------|----------|
| Orchestrierung auf oberster Ebene | `gpt-6-astra` | Boss |
| Tiefe Analyse, Architektur, Review | `gpt-6-astra` | Oracle, Prometheus, Sisyphus, Hephaestus, Atlas, Metis, Momus, architect, planner, code-reviewer, security-reviewer |
| Standardimplementierung | `gpt-5.6-sol` | Librarian, Multimodal-Looker, executor, test-engineer, debugger sowie 15 der 17 Pack-Agenten |
| Schnelles Nachschlagen, leichte Analyse | `gpt-5.6-terra` | data-analyst, prompt-regression-tester |

Die drei Tier-IDs stehen in einer einzigen Datei, `scripts/model-tiers.sh`; sowohl `scripts/md-to-toml.sh` als auch `install.sh` beziehen sie von dort, und `scripts/check-model-drift.sh` lässt den Build scheitern, wenn eine Modell-ID an anderer Stelle in den Skripten fest verdrahtet wird.

### Aufwandsstufen

Die Modellwahl bestimmt, *welches* Gehirn eine Aufgabe übernimmt; das Feld `model_reasoning_effort` neben `model` in derselben TOML-Datei bestimmt, *wie gründlich* es denkt. Boss und die neun OMO-Agenten deklarieren es in den eingecheckten Dateien unter `codex-agents/`, die sieben oh-my-codex-Worker erhalten ihren Wert beim Konvertieren aus der Rollentabelle in `scripts/md-to-toml.sh`, und jeder Pack-Agent bringt seinen eigenen mit:

| Aufwand | Agenten |
|--------|--------|
| `xhigh` | Boss, Oracle, Prometheus, architect |
| `high` | Sisyphus, Hephaestus, Atlas, Metis, Momus, planner, code-reviewer, security-reviewer sowie 15 der 17 Pack-Agenten |
| `medium` | Librarian, Multimodal-Looker, executor, test-engineer, debugger, data-analyst, prompt-regression-tester |

### 3-Phasen-Sprint-Workflow

Für die durchgängige Umsetzung eines Features orchestriert Boss einen strukturierten Sprint:

| Phase | Modus | Was passiert |
|-------|------|--------------|
| **1 · Design** | interaktiv | Nutzer legt den Umfang fest · Engineering-Review · „Design fertig" bestätigen |
| **2 · Ausführung** | autonom | executor erledigt die Aufgaben · automatisches Code-Review · Prüfung durch architect |
| **3 · Review** | interaktiv | Abgleich mit dem Designdokument · Vergleichstabelle vorlegen · Nutzer gibt frei oder fordert Nachbesserung |

### Strukturierter Abschlussbericht

Boss schließt jede Arbeitsrunde — jede Runde, in der Dateien bearbeitet, Commits/PRs erzeugt, Konfiguration geändert oder Verifikation ausgeführt wurde — mit einem strukturierten Abschlussbericht ab, den man ohne Blick in ein Diff überfliegen kann. Der Bericht besteht aus fünf festen Tabellen, von denen jede nur erscheint, wenn ihr Fall tatsächlich eingetreten ist (niemals eine leere Tabelle):

| Situation | Tabelle | Spalten |
|-----------|-------|---------|
| Dateien/Einstellungen geändert | Changes | Ziel / Before / After / Begründung |
| Mehrere Aufgaben erledigt | Work summary | Punkt / Ergebnis / Nachweis |
| Verifikation ausgeführt | Verification | Punkt / Erwartet / Tatsächlich / Urteil |
| Commits/PRs erzeugt | Deliverables | PR / Repository / Inhalt / Status |
| Etwas bleibt offen | Remaining | Punkt / Status / Nächster Schritt |

Er erscheint nur ganz am Ende der Anfrage — nie in einer Runde, die Hintergrundarbeit startet oder weiterleitet, und nie als Zwischenstandsmeldung —, und reine Frage-Antwort-Runden enden ohne ihn. Die Spezifikation steckt in den developer instructions von `boss.toml` und in `~/.codex/AGENTS.md`, sodass auch die Hauptsitzung sie sieht. Ein Stop-Hook (`hooks/stop-final-report.js`) setzt sie durch: Endet eine Runde, die den Zustand verändert hat, ohne Berichtstabelle, blockiert der Hook diese Runde einmal und fordert den Bericht ein.

---

## Was enthalten ist

| Kategorie | Anzahl | Quelle |
|----------|------:|--------|
| **Kernagenten** (immer geladen) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Agenten-Packs** (Opt-in, standardmäßig keines aktiv) | 17 | 2 eingebettete Kategorien: data-ai 13 + llmops 4 |
| **Sichtbare Skills** (Standardprofil `core`) | 30 | Die immer aktive Auswahl; alles andere ist einen Spur-Schalter entfernt |
| **Installierte Skills** (Einträge unter `~/.codex/skills/`) | 110 | ECC 61 · gstack 30 · Superpowers 14 · Core 4 · archify 1 |
| **MCP-Server** | 5 | Context7, Exa, grep.app, Serena, Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

Jeder Agent und jeder Skill oben steht auf der Freigabeliste in [`scripts/skill-allowlists.sh`](../../scripts/skill-allowlists.sh) — diese Datei entscheidet, was ausgeliefert wird. Dieses Bündel liefert bewusst kein `pdf`, `docx`, `pptx` oder `xlsx`; extern installierte Skills dieser Art bleiben unangetastet.

<details>
<summary><strong>Kernagent — Boss-Meta-Orchestrator (1)</strong></summary>

| Agent | Modell | Rolle | Quelle |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | Dynamische Laufzeiterkennung → Fähigkeitsabgleich → optimales Routing. Schreibt nie Code. | my-codex |

</details>

<details>
<summary><strong>OMO-Agenten — Sub-Orchestratoren und Spezialisten (9)</strong></summary>

| Agent | Modell | Rolle | Quelle |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | Intent-Klassifikation → Spezialisten-Delegation → Verifikation | oh-my-openagent |
| Hephaestus | gpt-6-astra high | Autonom erkunden → planen → ausführen → verifizieren | oh-my-openagent |
| Atlas | gpt-6-astra high | Aufgabenzerlegung + 4-stufige QA-Verifikation | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | Strategische technische Beratung (nur lesend) | oh-my-openagent |
| Metis | gpt-6-astra high | Intent-Analyse, Erkennung von Mehrdeutigkeit | oh-my-openagent |
| Momus | gpt-6-astra high | Prüfung der Plan-Machbarkeit | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | Interviewbasierte Detailplanung | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | Suche in Open-Source-Dokumentation über MCP | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | Analyse von Bildern/Screenshots/Diagrammen | oh-my-openagent |

</details>

<details>
<summary><strong>OMX-Agenten — spezialisierte Worker (7)</strong></summary>

| Agent | Sandbox | Rolle | Quelle |
|-------|---------|------|--------|
| executor | workspace-write | Code-Implementierung | oh-my-codex |
| planner | read-only | Implementierungsplanung | oh-my-codex |
| architect | read-only | Systemdesign und Architektur | oh-my-codex |
| test-engineer | workspace-write | Teststrategie und Abdeckung | oh-my-codex |
| security-reviewer | read-only | Sicherheitsanalyse | oh-my-codex |
| code-reviewer | read-only | Fokussiertes Code-Review | oh-my-codex |
| debugger | workspace-write | Ursachenanalyse | oh-my-codex |

</details>

<details>
<summary><strong>Agenten-Packs — Opt-in-KI-Spezialisten (2 Packs, 17 Agenten)</strong></summary>

| Pack | Anzahl | Agenten |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

Installiert nach `~/.codex/agent-packs/` und deaktiviert, bis Sie sie einschalten — siehe [Agenten-Pack-Profile](#agenten-pack-profile).

</details>

<details>
<summary><strong>Skills — 30 standardmäßig sichtbar, 110 aus 5 Quellen installiert</strong></summary>

| Quelle | Installiert | Wichtige Skills |
|--------|------:|------------|
| everything-claude-code | 61 | coding-standards, python-testing, api-design, deep-research |
| gstack | 30 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| superpowers | 14 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| archify | 1 | archify (Architektur- / Workflow- / Sequenz- / Datenfluss- / Lebenszyklusdiagramme) |

Die gstack-Einträge sind das `gstack`-Router-Verzeichnis plus 29 Symlinks nach `~/.codex/vendor/gstack/.agents/skills/`, angelegt von gstacks eigenem `./setup`: die 26 Namen aus `GSTACK_SKILL_ALLOWLIST` und drei weitere, die es immer installiert (`gstack-upgrade`, `hackernews-frontpage`, `codex`). Alle 29 stehen im verwalteten Katalog, keiner ist also nur ein Link — jeder kann über `core` oder eine Spur sichtbar werden. Von den 110 Einträgen sind 81 echte Verzeichnisse und 29 diese Symlinks; `find ~/.codex/skills -name SKILL.md | wc -l` meldet 83, weil `find` ihnen ohne `-L` nicht folgt. Unabhängig vom aktiven Profil bleiben die Skill-Dateien installiert — es ändert sich nur die Sichtbarkeit. Siehe [Skill-Profile und Spuren](#skill-profile-und-spuren).

</details>

<details>
<summary><strong>Gehostete MCP-Server (3 von 5)</strong></summary>

Die anderen beiden sind Serena und Headroom; beide sind lokale stdio-Server.

| Server | Zweck | Kosten |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | Bibliotheksdokumentation in Echtzeit | Kostenlos |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | Semantische Websuche | 1.000 Anfragen/Monat kostenlos |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | GitHub-Codesuche | Kostenlos |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian-kompatibles dauerhaftes Gedächtnis. Jedes Projekt führt ein `.briefing/`-Verzeichnis, das während Codex-Sitzungen über native Plugin-Hooks aktualisiert wird, mit Wrapper-Absicherung für die Kontinuität zu Sitzungsbeginn und -ende:

```
.briefing/
├── INDEX.md                          ← Projektkontext (einmalig automatisch erstellt)
├── state.json                        ← Sitzungsmetadaten, Zähler, lastVaultSync (automatisch verwaltet)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← Von Mensch/Agent verfasste Folge-Sitzungszusammenfassung
│   └── YYYY-MM-DD-auto.md           ← Automatisches Gerüst (erfasste Dateien, gefilterter Status, Folgepunkte)
├── decisions/
│   └── YYYY-MM-DD-<decision>.md     ← Von Mensch/Agent verfasste Entscheidungsnotiz
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← Von Mensch/Agent verfasste Lernnotiz
│   └── YYYY-MM-DD-auto-session.md   ← Automatisches Gerüst (Dateien, Wrapper-Aktivität, Prompts)
├── references/
│   └── auto-links.md                ← Reserviert für gesammelte Recherchelinks
├── archives/                         ← PARA: abgeschlossene/inaktive Notizen (flach)
├── wiki/                             ← LLM-Wiki: Konzeptseiten
│   └── _schema.md
├── agents/
│   ├── agent-log.jsonl              ← Wrapper-/Sitzungsprotokoll
│   └── YYYY-MM-DD-summary.md        ← Tägliche Auswertung der erfassten Signale
└── persona/
    ├── profile.md                   ← Routing-/Profilzusammenfassung aus erfassten Signalen
    ├── suggestions.jsonl            ← Routing-Vorschläge (automatisch erzeugt)
    ├── persona-policy.json          ← Akzeptierte weiche Routing-Präferenzen für Boss
    └── rules/                       ← Workflow-Musterregeln (workflow-*.md)
```

### Wissensmanagement (v2)

BriefingVault v2 vereint drei Methoden des Wissensmanagements:

| Methode | Umsetzung |
|------------|-----------|
| **PARA** (Tiago Forte) | Verzeichnisstruktur: sessions=Projekte, decisions=Bereiche, references=Ressourcen, archives=Archiv |
| **Zettelkasten** (Luhmann) | Atomare Notizen in `learnings/`, eindeutige IDs (`YYYYMMDDHHMMSS`), verpflichtende `[[wiki-links]]` |
| **LLM-Wiki** (Karpathy) | Konzeptseiten in `wiki/` — automatisch vorgeschlagen, wenn Stichwörter 3-mal oder öfter auftauchen |

Die Sitzungsende-Hooks der Codex CLI erledigen automatisch:

- Archivierung von Notizen vorschlagen, die älter als 30 Tage sind
- Wiki-Seiten für häufig genannte Konzepte anregen
- Eindeutige Zettelkasten-IDs für neue Notizen erzeugen

### Sitzungsspezifische Diffs

Zu Sitzungsbeginn sichert my-codex den aktuellen git-HEAD und einen Schnappschuss des Arbeitsbaumzustands. Während der Sitzung aktualisieren native Codex-Hooks die `.briefing`-Gerüste nach Prompts, Bearbeitungen, Suchen und abgeschlossenen Subagenten. Zum Sitzungsende fasst das letzte Gerüst Diff und Status nur für die erfassten Pfade zusammen und filtert dabei von Hooks erzeugtes Rauschen wie `.briefing/`-Artefakte und `.gitignore`-Änderungen zu Sitzungsbeginn heraus.

So bleibt das Gerüst auf die Arbeit dieser Sitzung fokussiert, statt den gesamten Repository-Status auszuschütten. Für Projekte ohne git dient eine `YYYY-MM-DD:cwd`-Kennung als Rückfall.

### Verwendung mit Obsidian

1. Obsidian öffnen → **Ordner als Vault öffnen** → `.briefing/` auswählen
2. Notizen erscheinen in der Graphenansicht, verbunden über `[[wiki-links]]`
3. YAML-Frontmatter (`date`, `type`, `tags`) ermöglicht strukturierte Suche
4. Zeitleisten-Gerüste für Sitzungen und Erkenntnisse entstehen automatisch; Folgezusammenfassungen, Entscheidungen und Lernnotizen sammeln sich an, sobald Sie sie schreiben

### /boss-briefing

Führen Sie `/boss-briefing` während oder am Ende einer Sitzung aus, um:

- **Vault zu synchronisieren**: profile.md, INDEX.md und Agentenauswertungen aktualisieren
- **Workflow-Muster zu erkennen**: zeitliche Abfolgen von Agentenaufrufen über Sitzungen hinweg analysieren
- **Lücken zu schließen**: Wiederaufnahme-Zusammenfassungen erzeugen, wenn seit der letzten Sitzung Tage vergangen sind
- **Persona-Regeln vorzuschlagen**: workflowbasierte Routing-Präferenzen anregen (nicht nur nach Häufigkeit)
- **Sitzungsnotizen zu prüfen**: kontrollieren, ob die heutige Sitzung eine ordentliche Zusammenfassung hat

Der Stop-Hook prüft, ob `/boss-briefing` heute gelaufen ist. Falls nicht, blockiert er das Sitzungsende mit einer Erinnerung. Das bestehende `stop-profile-update.js` läuft weiterhin als Rückfall.

### Sub-Vaults

| Pfad | Beschreibung |
|------|-------------|
| `INDEX.md` | Projektüberblick mit Links zu jüngsten Entscheidungen und Erkenntnissen. Wird in der ersten Sitzung automatisch erstellt und regelmäßig aufgefrischt. |
| `sessions/` | **Sitzungszusammenfassungen.** `*-auto.md` — automatisches Gerüst, das während der Sitzung aktualisiert und zum Schluss aus erfassten Sitzungsdateien, gefiltertem Status und Signalen finalisiert wird. `<topic>.md` — von Mensch oder Agent verfasste Folgezusammenfassung, angestoßen durch die Vault-Erinnerungen. |
| `decisions/` | **Architektur- und Designentscheidungen** mit Begründung. Halten Sie Entscheidungen, die es wert sind, als dauerhafte Notizen fest. |
| `learnings/` | **Muster, Fallstricke, nicht offensichtliche Lösungen.** `*-auto-session.md` — automatisches Gerüst, das während der Sitzung mit der erfassten Dateiliste, den Signalen und Folge-Prompts aktualisiert wird. `<topic>.md` — von Mensch oder Agent verfasste Lernnotiz. |
| `references/` | **URLs aus Webrecherchen.** Wenn die nativen Codex-Hooks verfügbar sind, wird `references/auto-links.md` aus der `WebSearch`-/`WebFetch`-Hook-Aktivität aktualisiert. |
| `agents/` | **Erfasste Sitzungssignale.** `agent-log.jsonl` — Einträge mit `{ts, agent_id, agent_type, phase, seq, task_hint}`. `YYYY-MM-DD-summary.md` — tägliche Auswertung aus diesem Protokoll. |
| `persona/` | **Arbeitsstilprofil des Nutzers.** `profile.md` — Routing-/Profilzusammenfassung aus erfassten Signalen. `suggestions.jsonl` — Routing-Empfehlungen. `persona-policy.json` — akzeptierte weiche Routing-Präferenzen. `rules/workflow-*.md` — von `/boss-briefing` vorgeschlagene Workflow-Sequenzregeln. |
| `state.json` | Sitzungsmetadaten: Zähler, lastVaultSync, sessionStartHead. Wird von Hooks automatisch verwaltet. |
| `archives/` | PARA-Archiv — abgeschlossene Sitzungen (30+ Tage), überholte Entscheidungen, inaktive Erkenntnisse |
| `wiki/` | LLM-Wiki-Konzeptseiten — aus mehreren Sitzungen destilliertes Wissen |

### Verhaltens-Hooks

| Hook | Ereignis | Verhalten |
|------|-------|----------|
| Session Setup | SessionStart | Erkennt Werkzeuge automatisch + spielt den Briefing-Vault-Kontext ein |
| Delegation Guard | PreToolUse | Erinnert die Sitzung im Boss-Modus daran, Dateiänderungen zu delegieren statt selbst vorzunehmen |
| Agent Telemetry | PostToolUse | Protokolliert Agentennutzung nach `~/.gstack/analytics/agent-usage.jsonl` |
| Vault Enforcer | PostToolUse | Zählt Bearbeitungen und frischt die automatischen Gerüste während der Sitzung auf |
| Link Collector | PostToolUse | Hängt `WebSearch`-/`WebFetch`-Ergebnisse an `references/auto-links.md` an |
| Subagent Logger | SubagentStop | Protokolliert Agentenausführungen im Briefing Vault |
| Vault Reminder | UserPromptSubmit | Schlägt ab 5 Nachrichten /boss-briefing vor und eine echte Sitzungsnotiz, sobald genug Arbeit erfasst ist |
| Context Budget | UserPromptSubmit | Alle 40 Prompts seit der letzten Verdichtung (`MY_CODEX_COMPACT_EVERY`) wird `/compact` an der nächsten Aufgabengrenze vorgeschlagen |
| Context Budget reset | PostCompact | Setzt diesen Zähler nach einer Verdichtung auf null |
| Completion Check | Stop | Führt den Profil-Rückfall aus + prüft /boss-briefing |
| Final Report Gate | Stop | Blockiert die Runde einmal, wenn gearbeitet wurde, aber keine Abschlussberichtstabelle kam |

Codex lädt diese aus `~/.codex/hooks.json` und nur, wenn `features.hooks = true` gilt; deshalb schreibt `install.sh` die Datei an diesen Pfad und setzt das Flag unter `[features]` in `config.toml`. Beim nächsten interaktiven Start von Codex werden Sie einmal gefragt, ob Sie die Hooks prüfen und ihnen vertrauen — wählen Sie „Trust all and continue". Bis dahin läuft keiner von ihnen.

---

## Wo die Ergebnisse landen

Jedes installierte Werkzeug schreibt seine Ausgabe irgendwohin. Hier ist wohin.

| Werkzeug | Öffnen | Wie ausführen | Wo nachsehen |
|------|------|------------|----------------------|
| **codeburn** | <http://127.0.0.1:4747/> | Das Installationsskript startet `codeburn web --provider all --port 4747 --no-open`; `codeburn` öffnet das interaktive Dashboard; nicht-interaktiv: `codeburn report --format json --period week --provider codex` (auch `--day`, `--from`/`--to`) | Gemeinsames Browser-Dashboard, Terminal-TUI oder JSON auf stdout. Sitzungsdateien werden nur gelesen, und die Beträge sind Schätzungen zu öffentlichen Listenpreisen, keine Rechnung. |
| **Serena** | <http://localhost:24282/dashboard/index.html> | Wird von Codex über `[mcp_servers.serena]` gestartet; die Werkzeuge erscheinen als `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` | Dashboard und Werkzeugaufruf-Statistiken, solange ein Server läuft. Projektindex und -notizen liegen unter `<repo>/.serena/`; der Browser öffnet sich nicht automatisch (`--open-web-dashboard False`). |
| **Headroom** | <http://127.0.0.1:8787/stats> | Codex startet den MCP-Server über `[mcp_servers.headroom]` (`headroom mcp serve`); das Installationsskript wendet das gemeinsame Profil `agent-harness-shared` an (Befehl unten) | Proxy-Statistiken, leer, bis ein Client ausdrücklich mit `headroom wrap` oder einer Basis-URL darüber geleitet wird. |
| **Archify** | `<output>.html` | Aus `~/.codex/skills/archify`: `node bin/archify.mjs render <type> <input>.json <output>.html`, danach `node bin/archify.mjs check <output>.html` | Die von Ihnen benannte Datei — einfach im Browser öffnen. Die mitgelieferten `examples/*.json` des Skills sind fertige Eingaben zum Abschauen. |

Das Installationsskript wendet das Headroom-Dienstprofil mit folgendem Befehl an:

```bash
headroom install apply --profile agent-harness-shared --preset persistent-service \
  --runtime python --providers manual --port 8787 --no-telemetry \
  --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1
```

---

## GitHub Actions

| Workflow | Auslöser | Zweck |
|----------|---------|---------|
| **CI** | push, PR | Prüft TOML-Agentendateien, Existenz der Skills und Upstream-Dateizahlen |
| **Smoke Tests** | push, PR | Jobs `hooks`, `shell`, `drift`, `routing-refs` — Hook-Verdrahtung, Shell-Syntax, Modelldrift, Routing-Verweise in AGENTS.md |
| **Update Upstream** | alle 3 Tage / manuell | Sicherheitsgeprüftes `git submodule update --remote` über die 4 zweigverfolgten Submodule, frischt die Pins in `upstream/SOURCES.json` auf und erstellt einen Auto-Merge-PR |
| **Auto Tag** | Push auf main | Liest die Version aus `config.toml` und erstellt bei Bedarf einen neuen git-Tag |
| **Pages** | Push auf main | Veröffentlicht `docs/index.html` auf GitHub Pages |
| **CLA** | PR | Prüfung der Contributor License Agreement |
| **Lint Workflows** | push, PR | Prüft die YAML-Syntax der GitHub-Actions-Workflows |

---

## my-codex Originals

Funktionen, die eigens für dieses Projekt entstanden sind, über das hinaus, was Upstream-Quellen liefern:

| Funktion | Beschreibung |
|---------|-------------|
| **Boss-Meta-Orchestrator** | Dynamische Fähigkeitserkennung → Intent-Klassifikation → 4-stufiges Prioritäts-Routing → Delegation → Verifikation |
| **3-Phasen-Sprint** | Design (interaktiv) → Ausführung (autonom via executor) → Review (interaktiv gegen das Designdokument) |
| **Agenten-Tier-Priorität** | core > omo > omx > Opt-in-Packs bei der Entdopplung. Pack-Agenten werden übersprungen, wenn ihr Name mit einem bereits installierten Agenten kollidiert. Der spezialisiertere Agent gewinnt. |
| **Kostenoptimierung** | Drei Modellstufen aus einer einzigen Datei (`scripts/model-tiers.sh`), angewandt auf alle 34 Agenten, die das Installationsskript mitbringt |
| **Skill-Sichtbarkeitsprofile** | Ein verwalteter Katalog mit 210 Einträgen, 30 davon standardmäßig sichtbar, 13 optionale Spuren, Schnappschüsse und Rollback — damit das Skill-Budget dort landet, wo die Sitzung es braucht |
| **Briefing-Signale** | Wrapper-/Sitzungsprotokolle speisen `.briefing/agents/agent-log.jsonl`, tägliche Auswertungen und Routing-/Profilhinweise |
| **Smart Packs** | Projekttyp-Erkennung empfiehlt zu Sitzungsbeginn passende Agenten-Packs |
| **Agenten-Pack-System** | Bedarfsgesteuerte Aktivierung von Domänenspezialisten über `--profile` und das Hilfsprogramm `my-codex-packs` |
| **Codex Attribution** | git-Hooks erfassen von Codex berührte Dateien und hängen `AI-Contributed-By: Codex` an Commit-Nachrichten an |
| **CI-Dubletten-Erkennung** | Automatische Erkennung doppelter TOML-Agenten bei Upstream-Synchronisationen |

---

## Gebündelte Upstream-Versionen

Eingebunden über git-Submodule. Die gepinnten Commits verfolgt `.gitmodules` nativ und spiegelt sie als AI-BOM in [`upstream/SOURCES.json`](../../upstream/SOURCES.json), die zugleich die Begleit-CLIs und MCP-Server versionspinnt und die beiden entfernten Submodule festhält; `install.sh` checkt genau diese SHAs aus, statt `main` zu folgen.

| Quelle | SHA | Datum | Diff |
|--------|-----|------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `07756ce` | 2026-09-19 | [compare](https://github.com/affaan-m/everything-claude-code/compare/07756ce...HEAD) |
| [gstack](https://github.com/garrytan/gstack) | `a6b3a57` | 2026-09-16 | [compare](https://github.com/garrytan/gstack/compare/a6b3a57...HEAD) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | `cb955b0` | 2026-09-13 | [compare](https://github.com/Yeachan-Heo/oh-my-codex/compare/cb955b0...HEAD) |
| [superpowers](https://github.com/obra/superpowers) | `5bf4e78` | 2026-09-19 | [compare](https://github.com/obra/superpowers/compare/5bf4e78...HEAD) |
| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |

---

## Installationsoptionen

Führt man denselben Befehl erneut aus, wird auf den neuesten `main`-Stand aktualisiert, es werden nur die von my-codex verwalteten Dateien in `~/.codex/` ersetzt, und veraltete Skill-Kopien unter `~/.agents/skills/` werden entfernt.

### Skill-Profile und Spuren

my-claude installiert eine einzige feste Freigabeliste; my-codex installiert 110 Skill-Einträge und steuert anschließend, wie viele davon Codex tatsächlich sieht. Codex kürzt Skill-Beschreibungen, sobald sein Skill-Budget überschritten ist, und ein unfokussierter Katalog macht damit jede Beschreibung weniger nützlich. `core` — der Standard bei einer Neuinstallation mit allen gebündelten Skill-Quellen — zeigt 30 Skills, und jede Spur kommt obendrauf:

| Profil / Spur | Was sie ergänzt | Anzahl | Aktivierung |
|----------------|--------------|------:|---------------|
| `core` | Die immer aktive Auswahl: my-codex-Kern-Skills, die superpowers-Entwicklungsprozessspur, die gstack-Router für Ship/QA/Review und die ECC-Standards | 30 | Standard; mit `--skill-profile=core` zurückkehren |
| `legacy` | Sichtbarkeit vor der Migration; wird automatisch gewählt, wenn `--skip-ecc`, `--skip-gstack`, `--skip-superpowers` oder `--skip-archify` eine Kernquelle ohne explizites Profil auslässt | variabel | `--skill-profile=legacy` |
| `full` | Alle Spuren auf einmal — alle 110 installierten Einträge; der Katalog nennt 210 Namen, die noch nicht installierten werden bei Bedarf nachgezogen. Kann das Kontextbudget übersteigen | 110 | `--skill-profile=full` oder `--full-skills` |
| `workflow-advanced` | Fortgeschrittene Planung, Repository-Operationen und Worktree-Workflows | 13 | `--skills=workflow-advanced` |
| `qa-operations` | QA, Browserprüfungen, Release, Deployment und betriebliche Sicherheit | 20 | `--skills=qa-operations` |
| `ai-engineering` | Agentensysteme, Evaluation, Prompts, Retrieval und MCP | 18 | `--skills=ai-engineering` |
| `backend-data` | Backend-Architektur, Datenbanken, Caching, Container und APIs | 13 | `--skills=backend-data` |
| `python` | Python-, Django- und FastAPI-Implementierung und -Tests | 9 | `--skills=python` |
| `jvm` | Java-, Kotlin-, JPA- und Spring-Implementierung und -Tests | 11 | `--skills=jvm` |
| `web` | Web-Frameworks, Barrierefreiheit, Performance und End-to-End-Tests | 18 | `--skills=web` |
| `mobile` | Android-, Flutter-, Swift- und SwiftUI-Entwicklung | 9 | `--skills=mobile` |
| `other-languages` | C++-, Go-, Laravel-, Perl- und Rust-Entwicklung | 13 | `--skills=other-languages` |
| `research-content` | Recherche, technische Inhalte, Marktarbeit und Outreach | 11 | `--skills=research-content` |
| `media-documents` | Medienerzeugung, Dokumentenverarbeitung, OCR und Übersetzung | 7 | `--skills=media-documents` |
| `business-domains` | Logistik, Qualität, Produktion, Beschaffung und Handel | 8 | `--skills=business-domains` |
| `alternative-workflows` | Optionale Orchestrierungs-, TDD-, Review- und Verifikationssysteme | 30 | `--skills=alternative-workflows` |

Die Wahl bleibt in `~/.codex/my-codex/skill-catalog-state.json` erhalten, mit einem Kompatibilitätseintrag in `~/.codex/enabled-skill-lanes.txt`, sodass ein späteres schlichtes `bash install.sh` sie beibehält; `MY_CODEX_SKILLS=web` entspricht `--skills=web`, und bestehende nicht-interaktive Installationen ohne Zustand behalten ihre aktuelle Sichtbarkeit. Ein Profilwechsel entfernt niemals physische Skill-Dateien — optionale Einträge werden über die von Codex unterstützte pfadbasierte Skill-Konfiguration ausgeblendet, und unbekannte Skills oder Dateien unter `~/.agents/skills/` und `~/.claude/skills/` bleiben unangetastet.

Nach der Installation steuern Sie die Sichtbarkeit mit der `my-codex-skills`-CLI:

```bash
my-codex-skills list                     # jeder Katalogeintrag und seine Spur
my-codex-skills status                   # aktives Profil und aktivierte Spuren
my-codex-skills doctor                   # Abweichungen zwischen Katalog und Zustand melden
my-codex-skills enable python web        # Spuren ergänzen
my-codex-skills disable web              # eine Spur entfernen
my-codex-skills set-profile core         # core | legacy | full
my-codex-skills source benchmark gstack  # Quelle wählen, wenn zwei denselben Namen liefern
my-codex-skills restore latest           # auf einen Schnappschuss zurückrollen
```

Der Katalog liegt unter `~/.codex/lib/my-codex/skill-catalog.json`, Schnappschüsse unter `~/.codex/my-codex/skill-catalog-snapshots/<id>.json`. Beim Aktivieren einer Spur können fehlende Inhalte aus dem gepinnten lokalen Vendor nachgezogen werden; ist das nicht möglich, bleiben Zustand und Konfiguration unverändert, und die CLI verweist auf `install.sh --skills=<lane>`.

### Agenten-Pack-Profile

Die Packs werden installiert, sind aber **standardmäßig inaktiv** — eine Neuinstallation aktiviert keines davon und schreibt die leere Menge nach `~/.codex/enabled-agent-packs.txt`. Aktivieren Sie einzelne Packs oder wählen Sie ein Profil:

```bash
# Aktuellen Stand ansehen
~/.codex/bin/my-codex-packs status
# Ein Pack sofort aktivieren
~/.codex/bin/my-codex-packs enable data-ai
# Minimalprofil (nur Kernagenten, keine Packs — der Standard)
bash /tmp/my-codex/install.sh --profile minimal
# Dev-Profil (data-ai + llmops)
bash /tmp/my-codex/install.sh --profile dev
# Vollprofil (beide installierten Pack-Kategorien aktiv)
bash /tmp/my-codex/install.sh --profile full
```

### Codex Attribution System

`install.sh` installiert einen `codex`-Wrapper sowie globale git-Hooks in `~/.codex/git-hooks/`:

- **`prepare-commit-msg`** — erfasst Dateien, die während einer echten Codex-Sitzung geändert wurden
- **`commit-msg`** — hängt `Generated with Codex CLI: https://github.com/openai/codex` an, wenn sich die gestagten Dateien mit der erfassten Änderungsmenge überschneiden
- **`post-commit`** — ergänzt den Trailer `AI-Contributed-By: Codex` bei passenden Commits

Optionaler `Co-authored-by`-Trailer: sowohl `git config --global my-codex.codexContributorName '<label>'` als auch `my-codex.codexContributorEmail '<github-linked-email>'` setzen. Vollständig abschalten: `git config --global my-codex.codexAttribution false`. my-codex ändert **weder** `git user.name` noch `git user.email` noch die Commit-Autorenidentität.

### Agenten-TOML-Format

Jeder Agent ist eine native TOML-Datei in `~/.codex/agents/`:

```toml
name = "debugger"
description = "Focused debugging specialist — traces failures to root cause"
model = "gpt-5.6-sol"
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

- `max_threads` — maximale Anzahl gleichzeitiger Subagenten
- `max_depth` — maximale Verschachtelungstiefe für Ketten, in denen Agenten Agenten starten

---

## Häufig gestellte Fragen

<details>
<summary><strong>Worin unterscheidet sich my-codex von my-claude?</strong></summary>

Dieselbe Boss-Orchestrierung, eine andere Laufzeit. my-codex zielt auf die OpenAI Codex CLI mit nativem `.toml`-Agentenformat und `spawn_agent`-Delegation; my-claude zielt auf Claude Code mit dem `.md`-Agentenformat und dem Agent-Werkzeug. Zusätzlich steuert my-codex die Skill-Sichtbarkeit über Profile und Spuren, während my-claude eine feste Freigabeliste installiert.

</details>

<details>
<summary><strong>Kann ich my-codex und my-claude zusammen nutzen?</strong></summary>

Ja. Sie installieren in getrennte Verzeichnisse (`~/.codex/` und `~/.claude/`). Ihre Installationsskripte stimmen codeburn und Headroom über ein benutzerweites Lock- und Statusverzeichnis unter `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services` ab: ein gesunder Dienst wird weiterverwendet, und ein fremder Prozess auf einem der festen Ports wird gemeldet, aber nicht beendet.

</details>

<details>
<summary><strong>Wie funktionieren Agenten-Packs?</strong></summary>

Siehe [Agenten-Pack-Profile](#agenten-pack-profile).

</details>

<details>
<summary><strong>Wie läuft die Upstream-Synchronisation?</strong></summary>

Siehe die Zeile **Update Upstream** unter [GitHub Actions](#github-actions). `upstream/archify` ist tag-gepinnt und wird nur bewusst angehoben, daher berührt der Job nur die übrigen 4 Submodule; Sie können ihn außerdem im Actions-Tab manuell auslösen.

</details>

<details>
<summary><strong>Welche Modelle verwendet my-codex?</strong></summary>

Siehe [Modell-Routing](#modell-routing) und [Aufwandsstufen](#aufwandsstufen). Skills werden unverändert nach dem SKILL.md-Standard genutzt; nur Agenten werden nach Codex-TOML konvertiert, und die dafür verwendete Modellstufe wird aus einer einzigen Datei verwaltet, `scripts/model-tiers.sh`.

</details>

---

## Fehlerbehebung

### Nur-Skills-Wiederherstellung

Meldet ein Werkzeug ungültige `SKILL.md`-Dateien unter `~/.agents/skills/`, liegt es meist an einer veralteten lokalen Kopie oder einem veralteten Symlink-Ziel aus einer älteren Installation. Entfernen Sie die betroffenen Verzeichnisse aus `~/.agents/skills/` sowie die passenden Einträge unter `~/.claude/skills/` und installieren Sie erneut:

```bash
npx skills add sehoon787/my-codex -y -g
```

Wenn Sie das vollständige Codex-Bündel nutzen, führen Sie zusätzlich einmal `install.sh` aus. Das vollständige Installationsskript frischt `~/.codex/skills/` auf und entfernt veraltete, von my-codex verwaltete Kopien unter `~/.agents/skills/`.

---

## Mitwirken

Issues und PRs sind willkommen. Legen Sie für einen neuen Agenten eine `.toml`-Datei in `codex-agents/core/` oder `codex-agents/omo/` an und aktualisieren Sie die Agentenliste in `SETUP.md`. Prüfschritte für PRs und das Verhalten der Codex-Commit-Attribution finden Sie in [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Danksagungen

Aufgebaut auf den Projekten, die unter [Verwendete Open-Source-Tools](#verwendete-open-source-tools) aufgeführt sind; Dank an jede Autorin und jeden Autor. Dank auch an [OpenAI Codex CLI](https://github.com/openai/codex), die Laufzeit, auf die dieses Harness zielt, und an [openai/skills](https://github.com/openai/skills), dessen `npx skills`-CLI das reine Skill-Bündel installiert.

## Lizenz

MIT-Lizenz. Einzelheiten in der Datei [LICENSE](../../LICENSE).
