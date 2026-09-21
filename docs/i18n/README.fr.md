[Anglais](../../README.md) | [Coréen](./README.ko.md) | [Japonais](./README.ja.md) | [Chinois](./README.zh.md) | [Allemand](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Vous cherchez Claude Code ? → **my-claude** — la même orchestration Boss au format natif Claude `.md`

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-30_default_%2F_107_installed-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**Harnais d'agents tout-en-un pour Codex CLI.**
**Installez une fois, 17 agents principaux prêts à l'emploi.**

Boss détecte à l'exécution chaque agent, chaque skill et chaque outil MCP,<br>
puis route votre tâche vers le bon spécialiste via `spawn_agent`. Aucune configuration. Aucun code superflu.

<img src="../../assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## Installation

### Pour les humains

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

Ou clonez d'abord, puis lancez l'installeur depuis la copie locale :

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Si l'installation par défaut n'expose qu'un jeu restreint de skills, c'est
volontaire : Codex tronque les descriptions de skills dès que son budget de
skills est dépassé. Le profil par défaut `core` ne montre donc à Codex que 30
des 107 skills installés, le reste restant à un drapeau de distance :

```bash
bash install.sh --skills=web          # ajoute les 18 skills de la voie web/UI
bash install.sh --full-skills         # toutes les voies optionnelles, plus le profil full
bash install.sh --skill-profile=core  # revenir à l'exposition par défaut
```

Le choix est enregistré et survit à un `bash install.sh` ultérieur sans option. Tous les profils, toutes les voies et les commandes `my-codex-skills` sont décrits dans [Profils de skills et voies](#profils-de-skills-et-voies).

Dans un terminal interactif, un sélecteur à cases à cocher propose les trois outils compagnons — Serena, Headroom et codeburn — tous cochés par défaut. Déplacez-vous avec ↑/↓ ou `j`/`k`, basculez avec Espace, `a` sélectionne tout et `n` rien, Entrée ou Ctrl-D/EOF valide la sélection courante. Si `TERM` est vide ou vaut `dumb`, ou si `stty` est indisponible, le repli numéroté accepte Entrée, `all`, `a`, `y` ou `yes` pour tout ; `none`, `n`, `no` ou `0` pour rien ; et des numéros et noms mélangés comme `1,3` ou `serena codeburn`. En automatisation, tout est sélectionné par défaut :

```bash
bash install.sh --tools=headroom   # un sous-ensemble explicite
bash install.sh --yes              # les trois, sans invite
bash install.sh --skip-tools       # aucun
```

Sous Windows, `install.sh` corrige les shims `codex`, `codex.cmd` et `codex.ps1` gérés par npm lorsqu'ils existent, afin que le pipeline de vault de my-codex conserve son repli par wrapper même si `%APPDATA%\npm` est résolu avant `~/.codex/bin`.

### Pour les agents IA

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

---

## Outils open source utilisés

Chaque projet sur lequel my-codex s'appuie, ce qu'il apporte et comment il arrive. Ce tableau est le seul endroit où chaque projet est décrit ; le reste de ce README ne liste que des inventaires, des commandes et des versions figées.

| # | Projet | Ce que my-codex en tire | Comment il arrive |
|---|--------|-------------------------|-------------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 61 skills autorisés : motifs par pile technique (TypeScript, React, Python/Django/FastAPI, Spring Boot/Kotlin, SQL/Redis/Prisma, Docker/Kubernetes), ingénierie IA et agents, et outillage générique de codebase comme l'onboarding, les visites de code et les ADR. Le contenu propre à Claude Code est retiré, et une voie de 18 skills web/UI reste hors de l'installation par défaut. | sous-module `upstream/ecc` ; `install.sh` ne copie que les noms autorisés dans `scripts/skill-allowlists.sh` |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 27 skills de processus de sprint — QA navigateur (`qa`), revue de code sur dérive de périmètre (`review`), audit de sécurité (`cso`) et le flux complet plan → revue → livraison — plus un démon navigateur Playwright compilé. | sous-module `upstream/gstack`, déployé dans `~/.codex/vendor/gstack` où son propre `./setup --host codex` s'exécute sous bun ; les 7 skills ECC qu'il remplace (`benchmark`, `canary-watch`, `safety-guard`, `browser-qa`, `verification-loop`, `security-review`, `design-system`) sont supprimés pour que seule la version gstack reste routable |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 7 agents de travail autorisés : `executor`, `planner`, `architect`, `test-engineer`, `security-reviewer`, `code-reviewer`, `debugger`. Les autres prompts et skills doublonnent des agents déjà fournis par ce dépôt et ne sont volontairement pas installés. | sous-module `upstream/omx` ; `scripts/md-to-toml.sh` convertit les prompts autorisés du Markdown vers `~/.codex/agents/*.toml` |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 skills de processus de développement : brainstorming, débogage systématique, développement piloté par les tests, rédaction et exécution de plans, gestion des worktrees et étiquette de revue de code. Aucun agent n'en est repris — son unique prompt `code-reviewer` recoupe celui d'oh-my-codex. | sous-module `upstream/superpowers` ; les 15 répertoires de skills sont installés sauf `dispatching-parallel-agents`, qui double le chemin de délégation de Boss |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | 1 skill de diagrammes qui transforme des descriptions d'architecture, de workflow, de séquence, de flux de données et de cycle de vie en un unique fichier HTML autonome avec SVG en ligne, bascule clair/sombre et export PNG/JPEG/WebP/SVG. | sous-module `upstream/archify`, figé sur le tag `v2.9.0` pour que la tâche de synchronisation n'y touche pas ; seul le répertoire `archify/` à la racine du dépôt est copié vers `~/.codex/skills/archify`, donc aucun `npx skills add` ne s'exécute à l'installation |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 17 agents TOML natifs Codex, livrés sous forme de deux packs optionnels, `data-ai` (13) et `llmops` (4). Une installation neuve n'active aucun des deux. | intégrés (MIT) dans `codex-agents/packs/` et installés vers `~/.codex/agent-packs/` ; sous-module retiré le 2026-07-27. Activez avec `~/.codex/bin/my-codex-packs enable data-ai` ou `install.sh --profile dev` |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 agents — `sisyphus`, `atlas`, `prometheus`, `oracle`, `metis`, `momus`, `hephaestus`, `librarian`, `multimodal-looker` — couvrant l'orchestration de bout en bout, l'exécution et la revue de plans, les seconds avis approfondis, la recherche de bibliothèques sourcée et la lecture de fichiers multimédias. | adaptés au TOML natif Codex et maintenus dans le dépôt sous `codex-agents/omo/`, donc installés sans copie locale de l'upstream |
| 8 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | Rien. Aucun agent de ces packs n'a jamais été lancé dans ce dépôt, donc rien n'a été intégré. | retiré (MIT) — sous-module supprimé le 2026-07-27, toujours consigné dans `upstream/SOURCES.json` |
| 9 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | La même orchestration Boss au format natif Claude `.md`, et la référence éditoriale : `scripts/skill-allowlists.sh` reprend mot pour mot les listes ECC, gstack et superpowers de my-claude, afin que les deux harnais exposent la même surface upstream. | projet frère uniquement — `install.sh` ne clone, ne télécharge et ne copie rien depuis lui, donc rien n'est intégré et il n'y a pas de version à suivre. Installés côte à côte, les deux installeurs coordonnent codeburn et Headroom via un unique verrou et répertoire d'état à l'échelle de l'utilisateur au lieu de se disputer les ports fixes |
| 10 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | Comptabilité locale des tokens et des coûts à partir des fichiers de session que Codex écrit déjà dans `~/.codex/sessions` — sans proxy, sans clé d'API, sans hooks Codex. | `npm i -g codeburn@0.9.23` ; `install.sh` démarre ou réutilise un unique processus partagé `codeburn web --provider all --port 4747 --no-open` |
| 11 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | Recherche et réécriture structurelles qui s'appuient sur l'arbre syntaxique plutôt que sur le texte brut, pour que les agents modifient des formes de code sans expressions régulières fragiles. | `npm i -g @ast-grep/cli@0.42.0`, ignoré si un binaire `ast-grep` est déjà dans le `PATH` |
| 12 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | Le graphe de symboles d'un serveur de langage via MCP — `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` — pour que les tokens suivent le symbole et non le fichier entier. Le paquet distribué est GPL-3.0-or-later dans son ensemble (les métadonnées MIT de PyPI sont inexactes), donc rien n'est intégré. | `uv tool install --python 3.13 serena-agent==1.7.0`, enregistré comme `[mcp_servers.serena]` (stdio : `serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False`, `startup_timeout_sec = 15`) |
| 13 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | Compression de contexte Apache-2.0 via MCP : `headroom_compress`, `headroom_retrieve` et `headroom_stats`. Le mode proxy `headroom wrap` reste une option manuelle documentée. | `uv tool install --python 3.13 "headroom-ai[all]==0.37.0"`, enregistré comme `[mcp_servers.headroom]` (`headroom mcp serve`, `default_tools_approval_mode = "approve"` car le serveur ne publie aucune annotation MCP) ; l'installeur démarre ou réutilise le profil partagé `agent-harness-shared` sur le port 8787 et ne définit jamais `ANTHROPIC_BASE_URL` ni `OPENAI_BASE_URL` |
| 14 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | Des réponses sur les bibliothèques, frameworks et SDK tirées de la documentation upstream à jour plutôt que de la mémoire du modèle. C'est le backend vers lequel pointe le skill `documentation-lookup`. | serveur MCP hébergé à `https://mcp.context7.com/mcp` |
| 15 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | Recherche web neuronale. L'URL enregistrée n'active que `web_search_exa`, ce qui réduit le chemin de recherche à un seul outil plutôt qu'à toute la surface d'Exa. | serveur MCP hébergé à `https://mcp.exa.ai/mcp?tools=web_search_exa` |
| 16 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | Recherche de code inter-dépôts sur GitHub public, pour qu'un agent puisse consulter de vrais appels d'une bibliothèque dans de nombreux dépôts avant d'écrire du code. | serveur MCP hébergé à `https://mcp.grep.app` |

---

## Fonctionnement de Boss

Boss est le méta-orchestrateur au cœur de my-codex. Il n'écrit jamais de code : il découvre, classe, apparie, délègue et vérifie. La session Codex principale assume le rôle de Boss via l'`AGENTS.md` installé, et délègue donc directement aux spécialistes au lieu de lancer d'abord un autre Boss. Son identité de session native reste Codex/root, et une réinstallation rafraîchit les instructions gérées tout en préservant les sections personnalisées.

| Phase | Ce qui se passe |
|-------|--------------|
| **0 · Découverte** | Analyse `~/.codex/agents/*.toml` à l'exécution pour construire un registre de capacités vivant |
| **1 · Filtre d'intention** | Classe la demande (trivial, build, refactor, mid-sized, architecture, research, …) et contre-propose un skill lorsqu'il convient mieux |
| **2 · Appariement de capacités** | Parcourt la chaîne de priorités ci-dessous (P1 skill exact → P2 agent spécialisé → P3 orchestration multi-agents → P4 repli généraliste) |
| **3 · Délégation** | Appelle `spawn_agent` avec un prompt structuré en 6 sections : TASK / OUTCOME / TOOLS / DO / DON'T / CTX |
| **4 · Vérification** | Relit les fichiers modifiés de façon indépendante, lance tests, lint et build, recoupe avec l'intention initiale et réessaie jusqu'à 3 fois en cas d'échec |

### Routage par priorité

Boss fait passer chaque demande dans une chaîne de priorités jusqu'à trouver la meilleure correspondance :

| Priorité | Type de correspondance | Quand | Exemple |
|:--------:|-----------|------|---------|
| **P1** | Correspondance de skill | La tâche correspond à un skill autonome | `"review this diff"` → skill /review |
| **P2** | Agent spécialisé | Un agent propre au domaine existe | `"security audit"` → security-reviewer |
| **P3a** | Boss en direct | 2 à 4 agents indépendants | `"fix 3 bugs"` → lancement parallèle |
| **P3b** | Sous-orchestrateur | Workflow complexe en plusieurs étapes | `"refactor + test"` → Sisyphus |
| **P4** | Repli | Aucun spécialiste ne correspond | `"explain this"` → agent généraliste |

### Routage par modèle

| Complexité | Modèle | Utilisé pour |
|-----------|-------|----------|
| Orchestration de premier niveau | `gpt-6-astra` | Boss |
| Analyse approfondie, architecture, revue | `gpt-6-astra` | Oracle, Prometheus, Sisyphus, Hephaestus, Atlas, Metis, Momus, architect, planner, code-reviewer, security-reviewer |
| Implémentation standard | `gpt-5.6-sol` | Librarian, Multimodal-Looker, executor, test-engineer, debugger, ainsi que 15 des 17 agents de packs |
| Recherche rapide, analyse légère | `gpt-5.6-terra` | data-analyst, prompt-regression-tester |

Les trois identifiants de palier vivent dans un seul fichier, `scripts/model-tiers.sh` ; `scripts/md-to-toml.sh` et `install.sh` le chargent tous deux, et `scripts/check-model-drift.sh` fait échouer la build si un identifiant de modèle est codé en dur ailleurs dans les scripts.

### Paliers d'effort

Le choix du modèle décide *quel* cerveau exécute une tâche ; le champ `model_reasoning_effort`, voisin de `model` dans le même TOML, décide *avec quelle profondeur* il réfléchit. Boss et les neuf agents OMO le déclarent dans les fichiers versionnés sous `codex-agents/`, les sept workers oh-my-codex reçoivent le leur de la table de rôles de `scripts/md-to-toml.sh` au moment de la conversion, et chaque agent de pack porte le sien :

| Effort | Agents |
|--------|--------|
| `xhigh` | Boss, Oracle, Prometheus, architect |
| `high` | Sisyphus, Hephaestus, Atlas, Metis, Momus, planner, code-reviewer, security-reviewer, ainsi que 15 des 17 agents de packs |
| `medium` | Librarian, Multimodal-Looker, executor, test-engineer, debugger, data-analyst, prompt-regression-tester |

### Workflow en sprint 3 phases

Pour une implémentation de fonctionnalité de bout en bout, Boss orchestre un sprint structuré :

| Phase | Mode | Ce qui se passe |
|-------|------|--------------|
| **1 · Conception** | interactif | L'utilisateur fixe le périmètre · revue d'ingénierie · confirmation « conception terminée » |
| **2 · Exécution** | autonome | executor réalise les tâches · revue de code automatique · vérification par architect |
| **3 · Revue** | interactif | Comparaison avec le document de conception · tableau comparatif · l'utilisateur valide ou demande des améliorations |

### Rapport final structuré

Boss clôt chaque tour de travail — tout tour ayant modifié des fichiers, produit des commits/PR, changé la configuration ou lancé une vérification — par un rapport final structuré que l'on peut parcourir sans ouvrir de diff. Le rapport se compose de cinq tableaux fixes, chacun n'apparaissant que si sa situation s'est réellement produite (jamais de tableau vide) :

| Situation | Tableau | Colonnes |
|-----------|-------|---------|
| Fichiers/réglages modifiés | Changes | Cible / Before / After / Justification |
| Plusieurs tâches terminées | Work summary | Élément / Résultat / Preuve |
| Vérification exécutée | Verification | Élément / Attendu / Constaté / Verdict |
| Commits/PR produits | Deliverables | PR / Dépôt / Contenu / Statut |
| Points non résolus | Remaining | Élément / Statut / Prochaine étape |

Il ne se déclenche qu'à la toute fin de la demande — jamais sur un tour qui lance ou relaie un travail d'arrière-plan, jamais comme point d'avancement en cours de tâche — et les tours purement questions-réponses se terminent normalement sans lui. La spécification figure dans les developer instructions de `boss.toml` et dans `~/.codex/AGENTS.md`, si bien que la session principale la voit aussi. Un hook Stop (`hooks/stop-final-report.js`) l'applique : si un tour a changé l'état sans produire de tableau de rapport, le hook bloque ce tour une fois et réclame le rapport.

---

## Ce qui est inclus

| Catégorie | Nombre | Source |
|----------|------:|--------|
| **Agents principaux** (toujours chargés) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Packs d'agents** (optionnels, aucun actif par défaut) | 17 | 2 catégories intégrées : data-ai 13 + llmops 4 |
| **Skills exposés** (profil `core` par défaut) | 30 | L'ensemble toujours actif ; tout le reste est à un drapeau de voie de distance |
| **Skills installés** (fichiers sur le disque) | 107 | ECC 61 · gstack 27 · Superpowers 14 · Core 4 · archify 1 |
| **Serveurs MCP** | 5 | Context7, Exa, grep.app, Serena, Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

Tous les agents et skills ci-dessus figurent sur la liste d'autorisation de [`scripts/skill-allowlists.sh`](../../scripts/skill-allowlists.sh) — ce fichier fait autorité sur ce qui est livré. Ce bundle ne fournit délibérément pas `pdf`, `docx`, `pptx` ni `xlsx` ; les skills de ce type installés par ailleurs restent intacts.

<details>
<summary><strong>Agent principal — méta-orchestrateur Boss (1)</strong></summary>

| Agent | Modèle | Rôle | Source |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | Découverte dynamique à l'exécution → appariement de capacités → routage optimal. N'écrit jamais de code. | my-codex |

</details>

<details>
<summary><strong>Agents OMO — sous-orchestrateurs et spécialistes (9)</strong></summary>

| Agent | Modèle | Rôle | Source |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | Classification d'intention → délégation aux spécialistes → vérification | oh-my-openagent |
| Hephaestus | gpt-6-astra high | Exploration autonome → plan → exécution → vérification | oh-my-openagent |
| Atlas | gpt-6-astra high | Décomposition de tâches + vérification QA en 4 étapes | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | Conseil technique stratégique (lecture seule) | oh-my-openagent |
| Metis | gpt-6-astra high | Analyse d'intention, détection d'ambiguïté | oh-my-openagent |
| Momus | gpt-6-astra high | Revue de faisabilité des plans | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | Planification détaillée par entretien | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | Recherche de documentation open source via MCP | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | Analyse d'images/captures/diagrammes | oh-my-openagent |

</details>

<details>
<summary><strong>Agents OMX — workers spécialisés (7)</strong></summary>

| Agent | Bac à sable | Rôle | Source |
|-------|---------|------|--------|
| executor | workspace-write | Implémentation du code | oh-my-codex |
| planner | read-only | Planification d'implémentation | oh-my-codex |
| architect | read-only | Conception système et architecture | oh-my-codex |
| test-engineer | workspace-write | Stratégie de test et couverture | oh-my-codex |
| security-reviewer | read-only | Analyse de sécurité | oh-my-codex |
| code-reviewer | read-only | Revue de code ciblée | oh-my-codex |
| debugger | workspace-write | Analyse de cause racine | oh-my-codex |

</details>

<details>
<summary><strong>Packs d'agents — spécialistes IA optionnels (2 packs, 17 agents)</strong></summary>

| Pack | Nombre | Agents |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

Installés dans `~/.codex/agent-packs/` et désactivés tant que vous ne les activez pas — voir [Profils de packs d'agents](#profils-de-packs-dagents).

</details>

<details>
<summary><strong>Skills — 30 exposés par défaut, 107 installés depuis 5 sources</strong></summary>

| Source | Installés | Skills clés |
|--------|------:|------------|
| everything-claude-code | 61 | coding-standards, python-testing, api-design, deep-research |
| gstack | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| superpowers | 14 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| archify | 1 | archify (diagrammes d'architecture / workflow / séquence / flux de données / cycle de vie) |

gstack compte 26 skills autorisés plus l'entrée racine du dépôt. Sa copie complète se trouve dans `~/.codex/vendor/gstack`, et `~/.codex/skills/gstack` sert de façade à l'exécution. Quel que soit le profil actif, les fichiers de skills restent installés — seule l'exposition change. Voir [Profils de skills et voies](#profils-de-skills-et-voies).

</details>

<details>
<summary><strong>Serveurs MCP hébergés (3 sur 5)</strong></summary>

Les deux autres sont Serena et Headroom ; ce sont des serveurs stdio locaux.

| Serveur | Objet | Coût |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | Documentation de bibliothèques en temps réel | Gratuit |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | Recherche web sémantique | 1 000 requêtes/mois gratuites |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | Recherche de code GitHub | Gratuit |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Mémoire persistante compatible Obsidian. Chaque projet entretient un répertoire `.briefing/` mis à jour pendant les sessions Codex par des hooks natifs de plugin, avec un repli par wrapper pour la continuité en début et fin de session :

```
.briefing/
├── INDEX.md                          ← Contexte projet (créé automatiquement une fois)
├── state.json                        ← Métadonnées de session, compteurs, lastVaultSync (géré automatiquement)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← Résumé de session de suivi écrit par un humain/agent
│   └── YYYY-MM-DD-auto.md           ← Squelette auto-généré (fichiers enregistrés, statut filtré, suites à donner)
├── decisions/
│   └── YYYY-MM-DD-<decision>.md     ← Note de décision écrite par un humain/agent
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← Note d'apprentissage écrite par un humain/agent
│   └── YYYY-MM-DD-auto-session.md   ← Squelette auto-généré (fichiers, activité du wrapper, prompts)
├── references/
│   └── auto-links.md                ← Réservé aux liens de recherche collectés
├── archives/                         ← PARA : notes terminées/inactives (à plat)
├── wiki/                             ← LLM-wiki : pages de concepts
│   └── _schema.md
├── agents/
│   ├── agent-log.jsonl              ← Journal wrapper/session
│   └── YYYY-MM-DD-summary.md        ← Synthèse quotidienne des signaux enregistrés
└── persona/
    ├── profile.md                   ← Synthèse de routage/profil issue des signaux enregistrés
    ├── suggestions.jsonl            ← Suggestions de routage (auto-générées)
    ├── persona-policy.json          ← Préférences de routage souples acceptées pour Boss
    └── rules/                       ← Règles de motifs de workflow (workflow-*.md)
```

### Gestion des connaissances (v2)

BriefingVault v2 réunit trois méthodologies de gestion des connaissances :

| Méthodologie | Application |
|------------|-----------|
| **PARA** (Tiago Forte) | Structure de répertoires : sessions=Projets, decisions=Domaines, references=Ressources, archives=Archives |
| **Zettelkasten** (Luhmann) | Notes atomiques dans `learnings/`, identifiants uniques (`YYYYMMDDHHMMSS`), `[[wiki-links]]` obligatoires |
| **LLM-wiki** (Karpathy) | Pages de concepts dans `wiki/` — proposées automatiquement quand un mot-clé revient 3 fois ou plus |

Les hooks de fin de session de Codex CLI font automatiquement :

- Proposer l'archivage des notes de plus de 30 jours
- Suggérer des pages wiki pour les concepts fréquemment cités
- Générer des identifiants Zettelkasten uniques pour les nouvelles notes

### Diffs spécifiques à la session

Au démarrage de la session, my-codex sauvegarde le HEAD git courant et un instantané de l'état de l'arbre de travail. Pendant la session, les hooks natifs de Codex rafraîchissent les squelettes `.briefing` après les prompts, les éditions, les recherches et les fins de sous-agents. À la fin de la session, le squelette final ne résume diff et statut que pour les chemins enregistrés, en filtrant le bruit créé par les hooks, comme les artefacts `.briefing/` et les modifications du `.gitignore` au démarrage.

Le squelette reste ainsi centré sur le travail de la session au lieu de déverser l'état complet du dépôt. Pour les projets non git, un identifiant `YYYY-MM-DD:cwd` sert de repli.

### Utilisation avec Obsidian

1. Ouvrez Obsidian → **Ouvrir le dossier comme coffre** → sélectionnez `.briefing/`
2. Les notes apparaissent dans la vue graphe, reliées par des `[[wiki-links]]`
3. Le frontmatter YAML (`date`, `type`, `tags`) permet une recherche structurée
4. Les squelettes chronologiques des sessions et apprentissages s'accumulent automatiquement ; les résumés de suivi, décisions et notes d'apprentissage s'ajoutent au fil de votre écriture

### /boss-briefing

Lancez `/boss-briefing` pendant ou à la fin d'une session pour :

- **Synchroniser le coffre** : mettre à jour profile.md, INDEX.md et les synthèses d'agents
- **Détecter les motifs de workflow** : analyser les séquences temporelles d'appels d'agents entre sessions
- **Combler les interruptions** : produire des résumés de reprise si des jours se sont écoulés depuis la dernière session
- **Proposer des règles de persona** : suggérer des préférences de routage fondées sur le workflow, pas seulement sur la fréquence
- **Valider les notes de session** : vérifier que la session du jour dispose d'un vrai résumé

Le hook Stop vérifie si `/boss-briefing` a été exécuté aujourd'hui. Sinon, il bloque la fin de session avec un rappel. Le `stop-profile-update.js` existant continue de servir de repli.

### Sous-coffres

| Chemin | Description |
|------|-------------|
| `INDEX.md` | Vue d'ensemble du projet avec des liens vers les décisions et apprentissages récents. Créé automatiquement à la première session, rafraîchi régulièrement. |
| `sessions/` | **Résumés de session.** `*-auto.md` — squelette auto-généré, rafraîchi pendant la session et finalisé à l'arrêt à partir des fichiers de session enregistrés, du statut filtré et des signaux. `<topic>.md` — résumé de suivi écrit par un humain ou un agent, suscité par les rappels du coffre. |
| `decisions/` | **Décisions d'architecture et de conception** avec leur justification. Écrivez-les comme des notes durables lorsqu'une décision mérite d'être conservée. |
| `learnings/` | **Motifs, pièges, solutions non évidentes.** `*-auto-session.md` — squelette auto-généré rafraîchi pendant la session avec la liste des fichiers enregistrés, les signaux et des amorces de suivi. `<topic>.md` — note d'apprentissage écrite par un humain ou un agent. |
| `references/` | **URL de recherche web.** Lorsque les hooks natifs de Codex sont disponibles, `references/auto-links.md` est alimenté par l'activité des hooks `WebSearch`/`WebFetch`. |
| `agents/` | **Signaux de session enregistrés.** `agent-log.jsonl` — entrées enrichies `{ts, agent_id, agent_type, phase, seq, task_hint}`. `YYYY-MM-DD-summary.md` — synthèse quotidienne issue de ce journal. |
| `persona/` | **Profil de style de travail de l'utilisateur.** `profile.md` — synthèse de routage/profil issue des signaux. `suggestions.jsonl` — recommandations de routage. `persona-policy.json` — préférences de routage souples acceptées. `rules/workflow-*.md` — règles de séquences de workflow proposées par `/boss-briefing`. |
| `state.json` | Métadonnées de session : compteurs, lastVaultSync, sessionStartHead. Géré automatiquement par les hooks. |
| `archives/` | Archives PARA — sessions terminées (30 jours et plus), décisions remplacées, apprentissages inactifs |
| `wiki/` | Pages de concepts LLM-wiki — connaissances distillées de plusieurs sessions |

### Hooks comportementaux

| Hook | Événement | Comportement |
|------|-------|----------|
| Session Setup | SessionStart | Détecte automatiquement les outils + injecte le contexte du Briefing Vault |
| Delegation Guard | PreToolUse | Rappelle à la session en mode Boss de déléguer les modifications de fichiers au lieu de les faire elle-même |
| Agent Telemetry | PostToolUse | Journalise l'usage des agents dans `~/.gstack/analytics/agent-usage.jsonl` |
| Vault Enforcer | PostToolUse | Compte les éditions et rafraîchit les squelettes automatiques en cours de session |
| Link Collector | PostToolUse | Ajoute les résultats `WebSearch`/`WebFetch` à `references/auto-links.md` |
| Subagent Logger | SubagentStop | Journalise l'exécution des agents dans le Briefing Vault |
| Vault Reminder | UserPromptSubmit | Suggère /boss-briefing à partir de 5 messages, et une vraie note de session dès qu'assez de travail est enregistré |
| Context Budget | UserPromptSubmit | Tous les 40 prompts depuis la dernière compaction (`MY_CODEX_COMPACT_EVERY`), suggère `/compact` à la prochaine frontière de tâche |
| Context Budget reset | PostCompact | Remet ce compteur à zéro après une compaction |
| Completion Check | Stop | Exécute le repli de profil + contrôle /boss-briefing |
| Final Report Gate | Stop | Bloque le tour une fois si du travail a eu lieu sans tableau de rapport final |

Codex ne charge ces hooks depuis `~/.codex/hooks.json` que si `features.hooks = true` ; `install.sh` écrit donc le fichier à ce chemin et pose le drapeau sous `[features]` dans `config.toml`. Au prochain démarrage interactif de Codex, il vous est demandé une fois d'examiner et d'approuver les hooks — choisissez « Trust all and continue ». Tant que ce n'est pas fait, aucun ne s'exécute.

---

## Où voir les résultats

Chaque outil installé écrit sa sortie quelque part. Voici où.

| Outil | Comment l'exécuter | Où regarder |
|------|------------|----------------------|
| **codeburn** | L'installeur démarre `codeburn web --provider all --port 4747 --no-open` ; `codeburn` ouvre le tableau de bord interactif ; en non interactif : `codeburn report --format json --period week --provider codex` (aussi `--day`, `--from`/`--to`) | Tableau de bord partagé à <http://127.0.0.1:4747/>, TUI de terminal ou JSON sur stdout. Les fichiers de session sont lus sans modification, et les montants sont des estimations aux tarifs publics, pas une facture. |
| **Serena** | Démarré par Codex depuis `[mcp_servers.serena]` ; les outils apparaissent sous les noms `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` | Tableau de bord et statistiques d'appels d'outils à <http://localhost:24282/dashboard/index.html> tant qu'un serveur tourne. L'index et les mémoires par projet sont sous `<repo>/.serena/` ; le navigateur ne s'ouvre pas automatiquement (`--open-web-dashboard False`). |
| **Headroom** | Codex démarre le serveur MCP depuis `[mcp_servers.headroom]` (`headroom mcp serve`) ; l'installeur lance `headroom install apply --profile agent-harness-shared --preset persistent-service --runtime python --providers manual --port 8787 --no-telemetry --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1` | Statistiques du proxy à <http://127.0.0.1:8787/stats>, vides tant qu'un client n'est pas explicitement routé avec `headroom wrap` ou une URL de base. |
| **Archify** | Depuis `~/.codex/skills/archify` : `node bin/archify.mjs render <type> <input>.json <output>.html`, puis `node bin/archify.mjs check <output>.html` | Le `<output>.html` que vous avez nommé — ouvrez-le dans un navigateur. Les `examples/*.json` fournis avec le skill sont des entrées prêtes à copier. |

---

## GitHub Actions

| Workflow | Déclencheur | Objet |
|----------|---------|---------|
| **CI** | push, PR | Valide les fichiers d'agents TOML, l'existence des skills et le nombre de fichiers upstream |
| **Smoke Tests** | push, PR | Jobs `hooks`, `shell`, `drift`, `routing-refs` — câblage des hooks, syntaxe shell, dérive de modèle, références de routage dans AGENTS.md |
| **Update Upstream** | tous les 3 jours / manuel | `git submodule update --remote` sous contrôle de sécurité sur les 4 sous-modules suivis par branche, rafraîchit les versions figées dans `upstream/SOURCES.json` et ouvre une PR à fusion automatique |
| **Auto Tag** | push sur main | Lit la version dans `config.toml` et crée un tag git si elle est nouvelle |
| **Pages** | push sur main | Déploie `docs/index.html` sur GitHub Pages |
| **CLA** | PR | Vérification de l'accord de licence des contributeurs |
| **Lint Workflows** | push, PR | Valide la syntaxe YAML des workflows GitHub Actions |

---

## Originaux my-codex

Fonctionnalités conçues spécifiquement pour ce projet, au-delà de ce que fournissent les sources upstream :

| Fonctionnalité | Description |
|---------|-------------|
| **Méta-orchestrateur Boss** | Découverte dynamique de capacités → classification d'intention → routage à 4 priorités → délégation → vérification |
| **Sprint 3 phases** | Conception (interactif) → Exécution (autonome via executor) → Revue (interactif face au document de conception) |
| **Priorité par palier d'agents** | core > omo > omx > packs optionnels pour la déduplication. Un agent de pack est ignoré si son nom entre en collision avec un agent déjà installé. L'agent le plus spécialisé l'emporte. |
| **Optimisation des coûts** | Trois paliers de modèles issus d'un fichier unique (`scripts/model-tiers.sh`), appliqués aux 34 agents livrés par l'installeur |
| **Profils d'exposition des skills** | Un catalogue géré de 210 entrées avec 30 exposées par défaut, 13 voies optionnelles, instantanés et retour arrière — pour dépenser le budget de skills là où la session en a besoin |
| **Signaux de briefing** | La journalisation wrapper/session alimente `.briefing/agents/agent-log.jsonl`, les synthèses quotidiennes et les indices de routage/profil |
| **Smart Packs** | La détection du type de projet recommande les packs d'agents pertinents au démarrage de la session |
| **Système de packs d'agents** | Activation à la demande de spécialistes de domaine via `--profile` et l'utilitaire `my-codex-packs` |
| **Attribution Codex** | Des hooks git enregistrent les fichiers touchés par Codex et ajoutent `AI-Contributed-By: Codex` aux messages de commit |
| **Détection de doublons en CI** | Détection automatique des agents TOML dupliqués lors des synchronisations upstream |

---

## Versions upstream groupées

Reliées par des sous-modules git. Les commits figés sont suivis nativement par `.gitmodules` et reflétés sous forme d'AI-BOM dans [`upstream/SOURCES.json`](../../upstream/SOURCES.json), qui fige aussi les versions des CLI compagnons et des serveurs MCP et consigne les deux sous-modules retirés ; `install.sh` récupère exactement ces SHA plutôt que de suivre `main`.

| Source | SHA | Date | Diff |
|--------|-----|------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `07756ce` | 2026-09-19 | [compare](https://github.com/affaan-m/everything-claude-code/compare/07756ce...HEAD) |
| [gstack](https://github.com/garrytan/gstack) | `a6b3a57` | 2026-09-16 | [compare](https://github.com/garrytan/gstack/compare/a6b3a57...HEAD) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | `cb955b0` | 2026-09-13 | [compare](https://github.com/Yeachan-Heo/oh-my-codex/compare/cb955b0...HEAD) |
| [superpowers](https://github.com/obra/superpowers) | `5bf4e78` | 2026-09-19 | [compare](https://github.com/obra/superpowers/compare/5bf4e78...HEAD) |
| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |

---

## Options d'installation

Relancer la même commande met à jour vers la dernière build de `main`, ne remplace que les fichiers gérés par my-codex dans `~/.codex/` et supprime les copies de skills obsolètes sous `~/.agents/skills/`.

### Profils de skills et voies

my-claude installe une unique liste d'autorisation figée ; my-codex installe 107 fichiers de skills puis contrôle combien d'entre eux Codex voit réellement. Codex tronque les descriptions de skills dès que son budget de skills est dépassé : un catalogue sans priorité rend donc chaque description moins utile. `core` — le profil par défaut d'une installation neuve avec toutes les sources de skills groupées — expose 30 skills, et chaque voie s'y ajoute :

| Profil / voie | Ce qu'elle ajoute | Nombre | Activation |
|----------------|--------------|------:|---------------|
| `core` | L'ensemble toujours actif : skills de base my-codex, voie processus de développement superpowers, routeurs gstack livraison/QA/revue et standards ECC | 30 | par défaut ; `--skill-profile=core` pour y revenir |
| `legacy` | Exposition d'avant la migration ; choisie automatiquement quand `--skip-ecc`, `--skip-gstack`, `--skip-superpowers` ou `--skip-archify` omet une source principale sans profil explicite | variable | `--skill-profile=legacy` |
| `full` | Toutes les voies d'un coup ; peut dépasser le budget de contexte | 210 | `--skill-profile=full` ou `--full-skills` |
| `workflow-advanced` | Planification avancée, opérations sur le dépôt et workflows worktree | 13 | `--skills=workflow-advanced` |
| `qa-operations` | QA, contrôles navigateur, release, déploiement et sûreté opérationnelle | 20 | `--skills=qa-operations` |
| `ai-engineering` | Systèmes d'agents, évaluation, prompts, recherche d'information et MCP | 18 | `--skills=ai-engineering` |
| `backend-data` | Architecture backend, bases de données, cache, conteneurs et API | 13 | `--skills=backend-data` |
| `python` | Implémentation et tests Python, Django et FastAPI | 9 | `--skills=python` |
| `jvm` | Implémentation et tests Java, Kotlin, JPA et Spring | 11 | `--skills=jvm` |
| `web` | Frameworks web, accessibilité, performance et tests de bout en bout | 18 | `--skills=web` |
| `mobile` | Ingénierie Android, Flutter, Swift et SwiftUI | 9 | `--skills=mobile` |
| `other-languages` | Ingénierie C++, Go, Laravel, Perl et Rust | 13 | `--skills=other-languages` |
| `research-content` | Recherche, contenu technique, travail marché et prospection | 11 | `--skills=research-content` |
| `media-documents` | Génération de médias, traitement de documents, OCR et traduction | 7 | `--skills=media-documents` |
| `business-domains` | Logistique, qualité, production, achats et commerce | 8 | `--skills=business-domains` |
| `alternative-workflows` | Systèmes optionnels d'orchestration, TDD, revue et vérification | 30 | `--skills=alternative-workflows` |

Le choix est conservé dans `~/.codex/my-codex/skill-catalog-state.json`, avec un enregistrement de compatibilité dans `~/.codex/enabled-skill-lanes.txt`, de sorte qu'un `bash install.sh` ultérieur sans option le préserve ; `MY_CODEX_SKILLS=web` équivaut à `--skills=web`, et les installations non interactives existantes sans état conservent leur exposition actuelle. Changer de profil ne supprime jamais de fichier de skill — les entrées optionnelles sont masquées via la configuration de skills par chemin prise en charge par Codex, et les skills inconnus ou les fichiers sous `~/.agents/skills/` et `~/.claude/skills/` restent intacts.

Après l'installation, gérez l'exposition avec la CLI `my-codex-skills` :

```bash
my-codex-skills list                     # chaque entrée du catalogue et sa voie
my-codex-skills status                   # profil actif et voies activées
my-codex-skills doctor                   # signaler les écarts catalogue/état
my-codex-skills enable python web        # ajouter des voies
my-codex-skills disable web              # retirer une voie
my-codex-skills set-profile core         # core | legacy | full
my-codex-skills source benchmark gstack  # choisir la source quand deux fournissent le même nom
my-codex-skills restore latest           # revenir à un instantané
```

Le catalogue est `~/.codex/lib/my-codex/skill-catalog.json` et les instantanés se trouvent sous `~/.codex/my-codex/skill-catalog-snapshots/<id>.json`. Activer une voie peut matérialiser le contenu manquant depuis le vendor local figé ; si ce contenu est indisponible, l'état et la configuration restent inchangés et la CLI vous oriente vers `install.sh --skills=<lane>`.

### Profils de packs d'agents

Les packs sont installés mais **inactifs par défaut** — une installation neuve n'en active aucun et consigne l'ensemble vide dans `~/.codex/enabled-agent-packs.txt`. Activez-les pack par pack, ou choisissez un profil :

```bash
# Voir l'état actuel
~/.codex/bin/my-codex-packs status
# Activer immédiatement un pack
~/.codex/bin/my-codex-packs enable data-ai
# Profil minimal (agents principaux seulement, aucun pack — le défaut)
bash /tmp/my-codex/install.sh --profile minimal
# Profil dev (data-ai + llmops)
bash /tmp/my-codex/install.sh --profile dev
# Profil complet (les 2 catégories de packs installées actives)
bash /tmp/my-codex/install.sh --profile full
```

### Système d'attribution Codex

`install.sh` installe un wrapper `codex` ainsi que des hooks git globaux dans `~/.codex/git-hooks/` :

- **`prepare-commit-msg`** — enregistre les fichiers modifiés pendant une vraie session Codex
- **`commit-msg`** — ajoute `Generated with Codex CLI: https://github.com/openai/codex` lorsque les fichiers indexés recoupent l'ensemble de modifications enregistré
- **`post-commit`** — ajoute le trailer `AI-Contributed-By: Codex` aux commits concernés

Trailer `Co-authored-by` optionnel : définissez à la fois `git config --global my-codex.codexContributorName '<label>'` et `my-codex.codexContributorEmail '<github-linked-email>'`. Désactivation complète : `git config --global my-codex.codexAttribution false`. my-codex ne modifie **pas** `git user.name`, `git user.email` ni l'identité d'auteur des commits.

### Format TOML des agents

Chaque agent est un fichier TOML natif dans `~/.codex/agents/` :

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

Réglages Codex globaux dans `~/.codex/config.toml` :

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — nombre maximal de sous-agents simultanés
- `max_depth` — profondeur d'imbrication maximale des chaînes où un agent en lance un autre

---

## FAQ

<details>
<summary><strong>En quoi my-codex diffère-t-il de my-claude ?</strong></summary>

Même orchestration Boss, runtime différent. my-codex vise OpenAI Codex CLI avec le format d'agent natif `.toml` et la délégation `spawn_agent` ; my-claude vise Claude Code avec le format `.md` et l'outil Agent. my-codex contrôle en outre l'exposition des skills par profils et voies, là où my-claude installe une liste d'autorisation figée.

</details>

<details>
<summary><strong>Puis-je utiliser my-codex et my-claude ensemble ?</strong></summary>

Oui. Ils s'installent dans des répertoires distincts (`~/.codex/` et `~/.claude/`). Leurs installeurs coordonnent codeburn et Headroom via un verrou et un répertoire d'état à l'échelle de l'utilisateur, sous `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services` : un service sain est réutilisé, et un processus étranger occupant l'un des ports fixes est signalé sans être arrêté.

</details>

<details>
<summary><strong>Comment fonctionnent les packs d'agents ?</strong></summary>

Voir [Profils de packs d'agents](#profils-de-packs-dagents).

</details>

<details>
<summary><strong>Comment fonctionne la synchronisation upstream ?</strong></summary>

Voir la ligne **Update Upstream** dans [GitHub Actions](#github-actions). `upstream/archify` est figé sur un tag et relevé délibérément, la tâche ne touche donc que les 4 autres sous-modules ; vous pouvez aussi la déclencher manuellement depuis l'onglet Actions.

</details>

<details>
<summary><strong>Quels modèles my-codex utilise-t-il ?</strong></summary>

Voir [Routage par modèle](#routage-par-modèle) et [Paliers d'effort](#paliers-deffort). Les skills consomment le standard SKILL.md tel quel, sans transformation ; seuls les agents sont convertis en TOML Codex, et le palier de modèle utilisé pour cette conversion est géré depuis un fichier unique, `scripts/model-tiers.sh`.

</details>

---

## Dépannage

### Récupération des skills uniquement

Si un outil signale des fichiers `SKILL.md` invalides sous `~/.agents/skills/`, la cause la plus fréquente est une copie locale obsolète ou une cible de lien symbolique périmée héritée d'une installation plus ancienne. Supprimez les répertoires concernés de `~/.agents/skills/` ainsi que les entrées correspondantes sous `~/.claude/skills/`, puis réinstallez :

```bash
npx skills add sehoon787/my-codex -y -g
```

Si vous utilisez le bundle Codex complet, relancez également `install.sh` une fois. L'installeur complet rafraîchit `~/.codex/skills/` et supprime les copies obsolètes gérées par my-codex sous `~/.agents/skills/`.

---

## Contribuer

Les issues et les PR sont bienvenues. Pour ajouter un agent, créez un fichier `.toml` dans `codex-agents/core/` ou `codex-agents/omo/` et mettez à jour la liste d'agents dans `SETUP.md`. Les étapes de validation des PR et le comportement d'attribution des commits Codex sont décrits dans [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Remerciements

Construit sur les projets listés dans [Outils open source utilisés](#outils-open-source-utilisés) ; merci à chaque auteur. Merci également à [OpenAI Codex CLI](https://github.com/openai/codex), le runtime visé par ce harnais, et à [openai/skills](https://github.com/openai/skills), dont la CLI `npx skills` installe le bundle skills seul.

## Licence

Licence MIT. Voir le fichier [LICENSE](../../LICENSE) pour les détails.
