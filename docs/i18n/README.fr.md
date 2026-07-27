[English](../../README.md) | [한국어](./README.ko.md) | [日본語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Vous cherchez Claude Code ? → **my-claude** — la même orchestration Boss au format natif Claude `.md`

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-123-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**Harnais d'agents tout-en-un pour OpenAI Codex CLI.**
**Installez une fois, 17 agents sélectionnés prêts à l'emploi.**

Boss détecte automatiquement chaque agent et skill au démarrage,
puis route votre tâche vers le bon spécialiste via `spawn_agent`. Aucune configuration. Aucun code superflu.

<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## Installation

### Pour les humains

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

### Pour les agents IA

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

---

## Fonctionnement de Boss

Boss est le méta-orchestrateur au cœur de my-codex. Il n'écrit jamais de code — il découvre, classe, associe, délègue et vérifie.

```
Requête utilisateur
     │
     ▼
┌─────────────────────────────────────────────┐
│  Phase 0 · DÉCOUVERTE                       │
│  Analyse ~/.codex/agents/*.toml au          │
│  démarrage → Construit le registre des      │
│  capacités en direct                        │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 1 · FILTRE D'INTENTION               │
│  Classer : trivial | build | refactor |     │
│  moyen | architecture | recherche | ...     │
│  → Proposer un skill alternatif si plus     │
│  adapté                                     │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 2 · CORRESPONDANCE DE CAPACITÉS      │
│  P1: Correspondance exacte de skill         │
│  P2: Agent spécialiste via spawn_agent      │
│  P3: Orchestration multi-agents             │
│  P4: Repli généraliste                      │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 3 · DÉLÉGATION                       │
│  spawn_agent avec instructions structurées  │
│  TÂCHE / RÉSULTAT / OUTILS / FAIRE /       │
│  NE PAS FAIRE / CTX                         │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│  Phase 4 · VÉRIFICATION                     │
│  Lecture indépendante des fichiers modifiés │
│  Exécution des tests, lint, build           │
│  Recoupement avec l'intention d'origine     │
│  → Jusqu'à 3 nouvelles tentatives en cas   │
│  d'échec                                    │
└─────────────────────────────────────────────┘
```

### Routage par priorité

Boss cascade chaque requête dans une chaîne de priorités jusqu'à trouver la meilleure correspondance :

| Priorité | Type de correspondance | Quand | Exemple |
|:--------:|-----------|------|---------|
| **P1** | Correspondance de skill | La tâche correspond à un skill autonome | `"review this diff"` → skill /review |
| **P2** | Agent spécialiste | Un agent spécifique au domaine existe | `"audit de sécurité"` → security-reviewer |
| **P3a** | Boss direct | 2–4 agents indépendants | `"corriger 3 bugs"` → lancement parallèle |
| **P3b** | Sous-orchestrateur | Workflow complexe multi-étapes | `"refactor + test"` → Sisyphus |
| **P4** | Repli | Aucun spécialiste trouvé | `"expliquer ceci"` → agent généraliste |

### Routage par modèle

| Complexité | Modèle | Utilisé pour |
|-----------|-------|----------|
| Analyse approfondie, architecture | gpt-5.6 (raisonnement élevé) | Boss, Oracle, Sisyphus, Atlas |
| Implémentation standard | gpt-5.6-terra (moyen) | executor, debugger, security-reviewer |
| Recherche rapide, exploration | gpt-5.6-luna (faible) | explore, conseil simple |

### Workflow en sprint 3 phases

Pour l'implémentation de fonctionnalités de bout en bout, Boss orchestre un sprint structuré :

```
Phase 1 : CONCEPTION    Phase 2 : EXÉCUTION     Phase 3 : RÉVISION
(interactive)            (autonome)               (interactive)
─────────────────────   ─────────────────────   ─────────────────────
L'utilisateur définit   executor exécute les    Comparer avec le doc
la portée               tâches                  de conception
Révision technique      Révision de code auto   Présenter le tableau
Confirmer "conception   Vérification architect  comparatif
terminée"                                       User : approuver /
                                                améliorer
```

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Requête utilisateur                │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Boss · Méta-Orchestrateur (gpt-5.6 high)             │
│  Découverte → Classification → Correspondance →       │
│  Délégation                                           │
└──┬──────────┬──────────┬──────────┬─────────────────┘
   │          │          │          │
   ▼          ▼          ▼          ▼
┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ P3a  │ │  P3b   │ │  P1/P2 │ │Config  │
│Direct│ │Sous-   │ │ Skill/ │ │Control │
│2-4   │ │orch    │ │ Agent  │ │config. │
│spawn │ │Sisyphus│ │ Direct │ │toml    │
└──────┘ │Atlas   │ └────────┘ └────────┘
         └────────┘
┌─────────────────────────────────────────────────────┐
│  Couche agents (17 fichiers TOML installés)           │
│  Boss 1 · OMO 9 · OMX 7                               │
│  + 2 packs d'agents optionnels (17 agents, inactifs)  │
├─────────────────────────────────────────────────────┤
│  Couche skills (123 issus de ECC + gstack +           │
│  superpowers)                                         │
│  coding-standards · security-scan · deep-research     │
│  /review · /qa · /cso · /ship                         │
├─────────────────────────────────────────────────────┤
│  Couche MCP                                           │
│  Context7 · Exa · grep.app                            │
└─────────────────────────────────────────────────────┘
```

---

## Ce qui est inclus

| Catégorie | Nombre | Source |
|----------|------:|--------|
| **Agents principaux** (toujours chargés) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **Packs d'agents** (optionnels, aucun activé par défaut) | 17 | 2 catégories intégrées : data-ai 13 + llmops 4 |
| **Skills** | 123 | ECC 79 · gstack 27 · Superpowers 13 · Core 4 |
| **Serveurs MCP** | 3 | Context7, Exa, grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>Agent principal — Méta-orchestrateur Boss (1)</strong></summary>

| Agent | Modèle | Rôle | Source |
|-------|-------|------|--------|
| Boss | gpt-5.6 high | Découverte dynamique à l'exécution → correspondance de capacités → routage optimal. N'écrit jamais de code. | my-codex |

</details>

<details>
<summary><strong>Agents OMO — Sous-orchestrateurs et spécialistes (9)</strong></summary>

| Agent | Modèle | Rôle | Source |
|-------|-------|------|--------|
| Sisyphus | gpt-5.6 high | Classification d'intention → délégation aux spécialistes → vérification | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | gpt-5.6 high | Exploration autonome → planification → exécution → vérification | oh-my-openagent |
| Atlas | gpt-5.6 high | Décomposition de tâches + vérification QA en 4 étapes | oh-my-openagent |
| Oracle | gpt-5.6 high | Conseil technique stratégique (lecture seule) | oh-my-openagent |
| Metis | gpt-5.6 high | Analyse d'intention, détection d'ambiguïté | oh-my-openagent |
| Momus | gpt-5.6 high | Révision de faisabilité des plans | oh-my-openagent |
| Prometheus | gpt-5.6 high | Planification détaillée par entretien | oh-my-openagent |
| Librarian | gpt-5.6-terra medium | Recherche de documentation open source via MCP | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-terra medium | Analyse d'images, captures d'écran et diagrammes | oh-my-openagent |

</details>

<details>
<summary><strong>Agents OMX — Agents spécialistes (7)</strong></summary>

Convertis depuis les `prompts/*.md` de [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) vers le TOML natif de Codex. Seules les voies annoncées par `templates/codex-AGENTS.md` sont converties ; la liste d'autorisation se trouve dans `scripts/skill-allowlists.sh`.

| Agent | Bac à sable | Rôle | Source |
|-------|-------------|------|--------|
| executor | workspace-write | Implémentation du code | oh-my-codex |
| planner | workspace-write | Planification de l'implémentation | oh-my-codex |
| architect | read-only | Conception système et architecture | oh-my-codex |
| test-engineer | workspace-write | Stratégie de test et couverture | oh-my-codex |
| security-reviewer | read-only | Analyse de sécurité | oh-my-codex |
| code-reviewer | read-only | Revue de code ciblée | oh-my-codex |
| debugger | workspace-write | Analyse des causes racines | oh-my-codex |

</details>

<details>
<summary><strong>Packs d'agents — Spécialistes IA optionnels (2 packs, 17 agents)</strong></summary>

Intégrés depuis [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (MIT) dans `codex-agents/packs/` et installés dans `~/.codex/agent-packs/`. **Aucun pack n'est activé par défaut** — l'activation est explicite :

```bash
# Voir l'état actuel
~/.codex/bin/my-codex-packs status

# Activer un pack immédiatement
~/.codex/bin/my-codex-packs enable data-ai

# Changer de profil à l'installation
bash /tmp/my-codex/install.sh --profile minimal   # aucun pack
bash /tmp/my-codex/install.sh --profile dev       # data-ai + llmops
bash /tmp/my-codex/install.sh --profile full      # tous les packs installés
```

| Pack | Nombre | Agents |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

</details>

<details>
<summary><strong>Skills — 123 issus de 4 sources</strong></summary>

Les listes d'autorisation par skill se trouvent dans `scripts/skill-allowlists.sh` — ce fichier fait autorité sur ce qui est livré.

| Source | Nombre | Skills clés |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 79 | coding-standards, python-testing, api-design, deep-research |
| [gstack](https://github.com/garrytan/gstack) | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 13 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |

gstack compte 26 skills de la liste d'autorisation plus l'entrée racine du dépôt. L'intégralité du dépôt gstack réside également dans `~/.codex/skills/gstack`, son arbre d'exécution canonique.

Codex ne fournit **aucun skill documentaire** — ce bundle ne contient ni `pdf`, ni `docx`, ni `pptx`, ni `xlsx`.

</details>

<details>
<summary><strong>Serveurs MCP (3)</strong></summary>

| Serveur | Objectif | Coût |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://mcp.context7.com) | Documentation de bibliothèques en temps réel | Gratuit |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://mcp.exa.ai) | Recherche web sémantique | Gratuit 1k req/mois |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://mcp.grep.app) | Recherche de code GitHub | Gratuit |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Mémoire persistante compatible Obsidian. Chaque projet maintient un répertoire `.briefing/` qui se remplit automatiquement entre les sessions.

```
.briefing/
├── INDEX.md                          ← Contexte du projet (créé une seule fois)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← Résumé de session écrit par l'IA (obligatoire)
│   └── YYYY-MM-DD-auto.md           ← Scaffold auto-généré (diff git, stats d'agents)
├── decisions/
│   ├── YYYY-MM-DD-<decision>.md     ← Décision écrite par l'IA
│   └── YYYY-MM-DD-auto.md           ← Scaffold auto-généré (commits, fichiers)
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← Note d'apprentissage écrite par l'IA
│   └── YYYY-MM-DD-auto-session.md   ← Scaffold auto-généré (agents, fichiers)
├── references/
│   └── auto-links.md                ← URLs collectées automatiquement depuis les recherches web
├── agents/
│   ├── agent-log.jsonl              ← Télémétrie d'exécution des sous-agents
│   └── YYYY-MM-DD-summary.md        ← Récapitulatif quotidien d'utilisation des agents
├── persona/
│   ├── profile.md                   ← Statistiques d'affinité d'agents (mis à jour auto)
│   ├── suggestions.jsonl            ← Suggestions de routage (auto-générées)
│   ├── rules/                       ← Préférences de routage acceptées
│   └── skills/                      ← Skills persona acceptés
├── archives/                         ← Notes terminées/inactives (30+ jours)
│   ├── sessions/
│   ├── decisions/
│   └── learnings/
└── wiki/                             ← Pages de concepts (suggestion automatique)
    └── _schema.md
```

### Cycle d'automatisation

| Phase | Événement Hook | Ce qui se passe |
|-------|-----------|-------------|
| **Début de session** | `SessionStart` | Crée la structure `.briefing/`, enregistre le hash git HEAD pour les diffs de session |
| **Pendant le travail** | `PostToolUse` Edit/Write | Compte les éditions de fichiers ; alerte à 5, bloque à 15 si aucune décision/apprentissage écrit |
| **Pendant le travail** | `PostToolUse` WebSearch/WebFetch | Collecte automatiquement les URLs dans `references/auto-links.md` |
| **Pendant le travail** | `SubagentStop` | Enregistre l'exécution de l'agent dans `agents/agent-log.jsonl` |
| **Pendant le travail** | `UserPromptSubmit` (tous les 5) | Mise à jour limitée du profil persona |
| **Fin de session** | `Stop` (1er hook) | Auto-génère les scaffolds : `sessions/auto.md`, `learnings/auto-session.md`, `decisions/auto.md`, `persona/profile.md` |
| **Fin de session** | `Stop` (2e hook) | **Oblige** un résumé de session écrit par l'IA si ≥ 3 éditions de fichiers — bloque la fin de session avec un modèle |
| **archives/** | — | Propose automatiquement d'archiver les notes terminées/inactives après 30+ jours. Concept Archives PARA. |
| **wiki/** | — | Pages wiki de concepts. Suggestion automatique quand un mot-clé apparaît 3+ fois. Concept LLM-wiki. |

### Auto-généré vs Écrit par l'IA

| Type | Modèle de fichier | Créé par | Contenu |
|------|-------------|-----------|---------|
| **Scaffold auto** | `*-auto.md`, `*-auto-session.md` | Hook Stop (Node.js) | Statistiques diff git, utilisation des agents, liste des commits — données uniquement |
| **Résumé IA** | `YYYY-MM-DD-<topic>.md` | IA pendant la session | Analyse pertinente avec contexte, références code, justification |
| **Télémétrie** | `agent-log.jsonl`, `auto-links.md` | Scripts hook | Journaux structurés en ajout seul |
| **Persona** | `profile.md`, `suggestions.jsonl` | Hook Stop | Affinité d'agents basée sur l'utilisation et suggestions de routage |

Les scaffolds auto servent de **données de référence** pour que l'IA rédige des résumés appropriés. Le hook d'application fournit le contenu du scaffold + un modèle structuré lors du blocage de fin de session.

### Diffs spécifiques à la session

Au début de la session, le git HEAD courant est enregistré dans `.briefing/.session-start-head`. En fin de session, les diffs sont calculés par rapport à ce point enregistré — montrant uniquement les modifications de la session courante, pas les modifications non commitées accumulées des sessions précédentes.

### Utilisation avec Obsidian

1. Ouvrez Obsidian → **Ouvrir le dossier comme coffre** → sélectionnez `.briefing/`
2. Les notes apparaissent dans la vue graphique, liées par `[[wiki-links]]`
3. Le frontmatter YAML (`date`, `type`, `tags`) permet une recherche structurée
4. La chronologie des décisions et apprentissages se construit automatiquement entre les sessions

### Gestion des connaissances (v2)

BriefingVault v2 intègre trois méthodologies de gestion des connaissances :

| Méthodologie | Concept | Application dans BriefingVault |
|--------------|---------|-------------------------------|
| **PARA** (Tiago Forte) | Organiser par actionabilité : Projets, Domaines, Ressources, Archives | sessions/ = Projets, decisions/ = Domaines, references/ = Ressources, archives/ = Archives |
| **Zettelkasten** (Luhmann) | Notes atomiques avec ID uniques et liens explicites | fichiers learnings/ : ID `YYYYMMDDHHMMSS`, champ `related:` avec 2+ liens requis |
| **LLM-wiki** (Karpathy) | Pages de concepts maintenues par l'IA depuis les notes sources | pages wiki/ : suggestion automatique pour les mots-clés répétés 3+ fois |

---

## Sources open source en amont

my-codex suit **4 sous-modules upstream**, plus un instantané intégré et deux projets adaptés ou sœurs :

| # | Source | Méthode | Ce qu'elle fournit |
|---|--------|---------|-----------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | sous-module | 79 skills autorisés pour les workflows de développement. Le contenu spécifique à Claude Code a été supprimé ; les skills de codage génériques sont conservés. |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | sous-module | 27 skills pour la révision de code, QA, audit de sécurité, déploiement. Inclut un daemon navigateur Playwright. |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | sous-module | 7 agents de travail autorisés (executor, planner, architect, test-engineer, security-reviewer, code-reviewer, debugger), convertis depuis des prompts Markdown vers le TOML de Codex. |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | sous-module | 13 skills couvrant brainstorming, TDD, débogage systématique et rédaction de plans. Aucun agent installé. |
| 5 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | intégré (MIT) | 17 agents IA/LLM capturés dans `codex-agents/packs/` sous forme de 2 packs optionnels (data-ai 13, llmops 4). Sous-module supprimé le 2026-07-27. |
| 6 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | adapté | 9 agents OMO (Sisyphus, Atlas, Oracle, etc.). Adaptés au format TOML natif Codex et maintenus dans ce dépôt. |
| 7 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | projet sœur | Même orchestration Boss au format natif Claude `.md`. Skills, règles et Briefing Vault partagés entre les deux projets. |

Chaque sous-module est épinglé par SHA dans `upstream/SOURCES.json` (AI-BOM), qui consigne aussi les deux sous-modules supprimés (`agency-agents` — rien d'intégré ; `awesome-codex-subagents` — 17 agents intégrés).

---

## GitHub Actions

| Workflow | Déclencheur | Objectif |
|----------|---------|---------|
| **CI** | push, PR | Valide les fichiers d'agents TOML, l'existence des skills et les nombres de fichiers upstream |
| **Smoke Tests** | push, PR | Jobs `hooks`, `shell`, `drift`, `routing-refs` — câblage des hooks, syntaxe shell, dérive de modèle et références de routage d'AGENTS.md |
| **Update Upstream** | tous les 3 jours / manuel | `git submodule update --remote` sous contrôle de sécurité, rafraîchit les épinglages de `upstream/SOURCES.json` et crée une PR de fusion automatique |
| **Auto Tag** | push sur main | Lit la version depuis `config.toml` et crée un tag git si nouvelle |
| **Pages** | push sur main | Déploie `docs/index.html` sur GitHub Pages |
| **CLA** | PR | Vérification du Contrat de Licence de Contributeur |
| **Lint Workflows** | push, PR | Valide la syntaxe YAML des workflows GitHub Actions |

---

## Originaux my-codex

Fonctionnalités construites spécifiquement pour ce projet, au-delà de ce que fournissent les sources upstream :

| Fonctionnalité | Description |
|---------|-------------|
| **Boss Méta-Orchestrateur** | Découverte dynamique des capacités → classification d'intention → routage à 4 priorités → délégation → vérification |
| **Sprint 3 phases** | Conception (interactive) → Exécution (autonome via executor) → Révision (interactive vs doc de conception) |
| **Priorité par niveau d'agent** | core > omo > omx > packs optionnels. Un agent de pack dont le nom entre en collision avec un agent déjà installé est ignoré. L'agent le plus spécialisé l'emporte. |
| **Optimisation des coûts** | gpt-5.6-luna pour le conseil, gpt-5.6 pour l'implémentation — routage de modèle automatique sur les 34 agents installés |
| **Télémétrie des agents** | Le hook PostToolUse enregistre l'utilisation des agents dans `agent-usage.jsonl` |
| **Smart Packs** | La détection du type de projet recommande les packs d'agents pertinents au démarrage de session |
| **Système de packs d'agents** | Activation de spécialistes de domaine à la demande via `--profile` et l'aide `my-codex-packs` |
| **Attribution Codex** | Les hooks git enregistrent les fichiers modifiés par Codex et ajoutent `AI-Contributed-By: Codex` aux messages de commit |
| **Détection de doublon CI** | Détection automatisée des agents TOML en double entre les syncs upstream |

---

## Options d'installation

### Installation rapide

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

Relancer la même commande actualise vers le dernier build `main`, remplace uniquement les fichiers gérés par my-codex dans `~/.codex/`, et supprime les copies de skills obsolètes de `~/.agents/skills/`.

### Profils de packs d'agents

Les packs sont installés mais **inactifs par défaut** — une nouvelle installation n'en active aucun et enregistre l'ensemble vide dans `~/.codex/enabled-agent-packs.txt`. Activez-les pack par pack, ou choisissez un profil :

```bash
# Activer un pack immédiatement
~/.codex/bin/my-codex-packs enable data-ai

# Profil minimal (agents principaux uniquement, sans packs — par défaut)
bash /tmp/my-codex/install.sh --profile minimal

# Profil dev (data-ai + llmops)
bash /tmp/my-codex/install.sh --profile dev

# Profil complet (les 2 catégories de packs installées activées)
bash /tmp/my-codex/install.sh --profile full
```

### Système d'attribution Codex

`install.sh` installe un wrapper `codex` ainsi que des hooks git globaux dans `~/.codex/git-hooks/` :

- **`prepare-commit-msg`** — Enregistre les fichiers modifiés lors d'une vraie session Codex
- **`commit-msg`** — Ajoute `Generated with Codex CLI: https://github.com/openai/codex` quand les fichiers indexés recoupent les modifications enregistrées
- **`post-commit`** — Ajoute le trailer `AI-Contributed-By: Codex` aux commits éligibles

Trailer `Co-authored-by` optionnel : définissez `git config --global my-codex.codexContributorName '<label>'` et `my-codex.codexContributorEmail '<github-linked-email>'`. Pour désactiver entièrement : `git config --global my-codex.codexAttribution false`. my-codex ne modifie **pas** `git user.name`, `git user.email` ni l'identité de l'auteur du commit.

### Format TOML des agents

Chaque agent est un fichier TOML natif dans `~/.codex/agents/` :

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

Paramètres Codex globaux dans `~/.codex/config.toml` :

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — Nombre maximum de sous-agents simultanés
- `max_depth` — Profondeur maximale d'imbrication pour les chaînes agent-spawn-agent

---

## Versions upstream groupées

Les sources upstream sont gérées comme des sous-modules git. Les commits épinglés sont suivis dans `.gitmodules`.

| Source | Synchronisation |
|--------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | sous-module (`upstream/ecc`) |
| [gstack](https://github.com/garrytan/gstack) | sous-module (`upstream/gstack`) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | sous-module (`upstream/omx`) |
| [superpowers](https://github.com/obra/superpowers) | sous-module (`upstream/superpowers`) |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | instantané intégré (sous-module supprimé le 2026-07-27) |

---

## FAQ

<details>
<summary><strong>En quoi my-codex est-il différent de my-claude ?</strong></summary>

my-codex et my-claude partagent la même architecture d'orchestration Boss et les mêmes sources de skills upstream. La différence clé réside dans l'environnement d'exécution : my-codex cible OpenAI Codex CLI avec le format d'agent natif `.toml` et la délégation via `spawn_agent`, tandis que my-claude cible Claude Code avec le format d'agent `.md` et l'outil Agent.

</details>

<details>
<summary><strong>Puis-je utiliser my-codex et my-claude simultanément ?</strong></summary>

Oui. Ils s'installent dans des répertoires distincts (`~/.codex/` et `~/.claude/`) et ne créent aucun conflit. Les skills issus de sources upstream communes sont adaptés à chaque plateforme.

</details>

<details>
<summary><strong>Comment fonctionnent les packs d'agents ?</strong></summary>

Les packs d'agents sont des collections d'agents spécifiques à un domaine, installées dans `~/.codex/agent-packs/`. Deux packs sont livrés aujourd'hui — `data-ai` (13) et `llmops` (4) — et **aucun n'est activé à l'installation**. Utilisez `my-codex-packs enable <pack>` pour en activer un, ou réinstallez avec `--profile full` pour activer les deux catégories.

</details>

<details>
<summary><strong>Comment fonctionne la synchronisation upstream ?</strong></summary>

Un workflow GitHub Actions s'exécute tous les 3 jours, récupérant les derniers commits des 4 sous-modules upstream, rafraîchissant les épinglages SHA de `upstream/SOURCES.json` et créant une PR de fusion automatique sous contrôle de sécurité. Vous pouvez également le déclencher manuellement depuis l'onglet Actions.

</details>

<details>
<summary><strong>Quels modèles utilise my-codex ?</strong></summary>

Boss et les sous-orchestrateurs (Sisyphus, Atlas, Oracle) utilisent gpt-5.6 avec un niveau de raisonnement élevé. Les agents de travail standard utilisent gpt-5.6-terra avec un raisonnement moyen. Les agents de conseil légers utilisent gpt-5.6-luna.

</details>

---

## Dépannage

### Récupération des skills uniquement

Si un outil signale des fichiers `SKILL.md` invalides sous `~/.agents/skills/`, la cause la plus fréquente est une copie locale obsolète ou un lien symbolique vers une cible obsolète d'une ancienne installation.

Supprimez les répertoires concernés de `~/.agents/skills/` et les entrées correspondantes sous `~/.claude/skills/`, puis réinstallez :

```bash
npx skills add sehoon787/my-codex -y -g
```

Si vous utilisez le bundle Codex complet, relancez également `install.sh` une fois. L'installateur complet actualise `~/.codex/skills/` et supprime les copies gérées par my-codex obsolètes sous `~/.agents/skills/`.

---

## Contribuer

Les issues et PR sont les bienvenus. Lors de l'ajout d'un nouvel agent, ajoutez un fichier `.toml` dans `codex-agents/core/` ou `codex-agents/omo/` et mettez à jour la liste des agents dans `SETUP.md`. Consultez [CONTRIBUTING.md](./CONTRIBUTING.md) pour les étapes de validation des PR et le comportement d'attribution des commits Codex.

## Remerciements

Construit sur le travail de : [my-claude](https://github.com/sehoon787/my-claude) (sehoon787), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m), [gstack](https://github.com/garrytan/gstack) (garrytan), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo), [superpowers](https://github.com/obra/superpowers) (Jesse Vincent), [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent), [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu), [openai/skills](https://github.com/openai/skills) (OpenAI).

## Licence

Licence MIT. Voir le fichier [LICENSE](./LICENSE) pour plus de détails.
