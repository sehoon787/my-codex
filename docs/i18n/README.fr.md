[English](../../README.md) | [한국어](./README.ko.md) | [日본語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Vous cherchez Claude Code ? → **my-claude** — la même orchestration Boss au format natif Claude `.md`

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-330%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

**Harnais d'agents tout-en-un pour OpenAI Codex CLI.**
**Installez une fois, 330+ agents prêts à l'emploi.**

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
| **P1** | Correspondance de skill | La tâche correspond à un skill autonome | `"fusionner des PDFs"` → skill pdf |
| **P2** | Agent spécialiste | Un agent spécifique au domaine existe | `"audit de sécurité"` → security-reviewer |
| **P3a** | Boss direct | 2–4 agents indépendants | `"corriger 3 bugs"` → lancement parallèle |
| **P3b** | Sous-orchestrateur | Workflow complexe multi-étapes | `"refactor + test"` → Sisyphus |
| **P4** | Repli | Aucun spécialiste trouvé | `"expliquer ceci"` → agent généraliste |

### Routage par modèle

| Complexité | Modèle | Utilisé pour |
|-----------|-------|----------|
| Analyse approfondie, architecture | o3 (raisonnement élevé) | Boss, Oracle, Sisyphus, Atlas |
| Implémentation standard | o3 (moyen) | executor, debugger, security-reviewer |
| Recherche rapide, exploration | o4-mini (faible) | explore, conseil simple |

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
│  Boss · Méta-Orchestrateur (o3 high)                  │
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
│  Couche agents (330+ fichiers TOML installés)         │
│  OMO 9 · OMX 33 · Awesome Core 54 · Superpowers 1   │
│  + 20 packs d'agents de domaine (à la demande)        │
├─────────────────────────────────────────────────────┤
│  Couche skills (200+ issus de ECC + gstack + OMX +   │
│  plus)                                                │
│  tdd-workflow · security-review · autopilot           │
│  pdf · docx · pptx · xlsx · team                     │
├─────────────────────────────────────────────────────┤
│  Couche MCP                                           │
│  Context7 · Exa · grep.app                            │
└─────────────────────────────────────────────────────┘
```

---

## Ce qui est inclus

| Catégorie | Nombre | Source |
|----------|------:|--------|
| **Agents principaux** (toujours chargés) | 98 | Boss 1 + OMO 9 + OMX 33 + Awesome Core 54 + Superpowers 1 |
| **Packs d'agents** (à la demande) | 220+ | 20 catégories de domaines issues de agency-agents + awesome-codex-subagents |
| **Skills** | 200+ | ECC 180+ · gstack 40 · OMX 36 · Superpowers 14 · Core 1 |
| **Serveurs MCP** | 3 | Context7, Exa, grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>Agent principal — Méta-orchestrateur Boss (1)</strong></summary>

| Agent | Modèle | Rôle | Source |
|-------|-------|------|--------|
| Boss | o3 high | Découverte dynamique à l'exécution → correspondance de capacités → routage optimal. N'écrit jamais de code. | my-codex |

</details>

<details>
<summary><strong>Agents OMO — Sous-orchestrateurs et spécialistes (9)</strong></summary>

| Agent | Modèle | Rôle | Source |
|-------|-------|------|--------|
| Sisyphus | o3 high | Classification d'intention → délégation aux spécialistes → vérification | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | o3 high | Exploration autonome → planification → exécution → vérification | oh-my-openagent |
| Atlas | o3 high | Décomposition de tâches + vérification QA en 4 étapes | oh-my-openagent |
| Oracle | o3 high | Conseil technique stratégique (lecture seule) | oh-my-openagent |
| Metis | o3 high | Analyse d'intention, détection d'ambiguïté | oh-my-openagent |
| Momus | o3 high | Révision de faisabilité des plans | oh-my-openagent |
| Prometheus | o3 high | Planification détaillée par entretien | oh-my-openagent |
| Librarian | o3 medium | Recherche de documentation open source via MCP | oh-my-openagent |
| Multimodal-Looker | o3 medium | Analyse d'images, captures d'écran et diagrammes | oh-my-openagent |

</details>

<details>
<summary><strong>Agents OMC — Agents spécialistes (19)</strong></summary>

| Agent | Rôle | Source |
|-------|------|--------|
| analyst | Pré-analyse avant planification | [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) |
| architect | Conception et architecture système | oh-my-claudecode |
| code-reviewer | Révision de code ciblée | oh-my-claudecode |
| code-simplifier | Simplification et nettoyage du code | oh-my-claudecode |
| critic | Analyse critique, propositions alternatives | oh-my-claudecode |
| debugger | Débogage ciblé | oh-my-claudecode |
| designer | Conseils de conception UI/UX | oh-my-claudecode |
| document-specialist | Rédaction de documentation | oh-my-claudecode |
| executor | Exécution de tâches | oh-my-claudecode |
| explore | Exploration de code source | oh-my-claudecode |
| git-master | Gestion du workflow Git | oh-my-claudecode |
| planner | Planification rapide | oh-my-claudecode |
| qa-tester | Tests d'assurance qualité | oh-my-claudecode |
| scientist | Recherche et expérimentation | oh-my-claudecode |
| security-reviewer | Révision de sécurité | oh-my-claudecode |
| test-engineer | Écriture et maintenance des tests | oh-my-claudecode |
| tracer | Traçage et analyse d'exécution | oh-my-claudecode |
| verifier | Vérification finale | oh-my-claudecode |
| writer | Contenu et documentation | oh-my-claudecode |

</details>

<details>
<summary><strong>Agents Awesome Core (54) — Issus de awesome-codex-subagents</strong></summary>

4 catégories installées dans `~/.codex/agents/` :

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
<summary><strong>Agent Superpowers (1) — Issu de obra/superpowers</strong></summary>

| Agent | Rôle | Source |
|-------|------|--------|
| superpowers-code-reviewer | Révision de code complète avec brainstorming et vérification TDD | [superpowers](https://github.com/obra/superpowers) |

</details>

<details>
<summary><strong>Packs d'agents — Spécialistes de domaine à la demande (21 catégories)</strong></summary>

Installés dans `~/.codex/agent-packs/`. Gérés via :

```bash
# Voir l'état actuel
~/.codex/bin/my-codex-packs status

# Activer un pack immédiatement
~/.codex/bin/my-codex-packs enable marketing

# Changer de profil à l'installation
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
```

| Pack | Nombre | Exemples |
|------|------:|---------|
| engineering | 32 | Backend, Frontend, Mobile, DevOps, IA, Data |
| marketing | 27 | Douyin, Xiaohongshu, WeChat OA, TikTok, SEO |
| language-specialists | 27 | Python, Go, Rust, Swift, Kotlin, Java |
| specialized | 31 | Juridique, Finance, Santé, Workflow |
| game-development | 20 | Unity, Unreal, Godot, Roblox, Blender |
| infrastructure | 19 | Cloud, K8s, Terraform, Docker, SRE |
| developer-experience | 13 | MCP Builder, LSP, Terminal, Rapid Prototyper |
| data-ai | 13 | Data Engineer, ML, Base de données, ClickHouse |
| specialized-domains | 12 | Chaîne d'approvisionnement, Logistique, E-Commerce |
| design | 11 | Marque, UI, UX, Visual Storytelling |
| business-product | 11 | Product Manager, Croissance, Analytique |
| testing | 11 | API, Accessibilité, Performance, E2E, QA |
| sales | 8 | Stratégie de deal, Pipeline, Outbound |
| paid-media | 7 | Google Ads, Meta Ads, Programmatique |
| research-analysis | 7 | Tendances, Marché, Analyse concurrentielle |
| project-management | 6 | Agile, Jira, Workflows |
| spatial-computing | 6 | XR, WebXR, AR/VR, visionOS |
| support | 6 | Support client, Developer Advocacy |
| academic | 5 | Études à l'étranger, Formation en entreprise |
| product | 5 | Gestion de produit, Recherche UX |
| security | 5 | Tests de pénétration, Conformité, Audit |

</details>

<details>
<summary><strong>Skills — 200+ issus de 5 sources</strong></summary>

| Source | Nombre | Skills clés |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 180+ | tdd-workflow, autopilot, security-review, coding-standards |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 36 | plan, team, trace, deep-dive, blueprint, ultrawork |
| [gstack](https://github.com/garrytan/gstack) | 40 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 14 | brainstorming, systematic-debugging, TDD, parallel-agents |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 1 | boss-advanced |

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
└── persona/
    ├── profile.md                   ← Statistiques d'affinité d'agents (mis à jour auto)
    ├── suggestions.jsonl            ← Suggestions de routage (auto-générées)
    ├── rules/                       ← Préférences de routage acceptées
    └── skills/                      ← Skills persona acceptés
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

---

## Sources open source en amont

my-codex regroupe du contenu provenant de 8 dépôts upstream :

| # | Source | Ce qu'elle fournit |
|---|--------|-----------------|
| 1 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | Projet sœur. Même orchestration Boss au format natif Claude `.md`. Skills, règles et Briefing Vault partagés entre les deux projets. |
| 2 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 136 agents de qualité production au format TOML natif. Déjà compatibles Codex, aucune conversion nécessaire. 54 agents principaux chargés automatiquement. |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 36 skills, hooks, HUD et pipelines d'équipes pour Codex CLI. Référencé comme inspiration architecturale. |
| 4 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 180+ personas d'agents spécialistes métier dans 14 catégories. Convertis de Markdown vers TOML natif via un pipeline automatisé. |
| 5 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 180+ skills pour les workflows de développement. Le contenu spécifique à Claude Code a été supprimé ; les skills de codage génériques sont conservés. |
| 6 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 14 skills + 1 agent couvrant brainstorming, TDD, agents parallèles et révision de code. |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 agents OMO (Sisyphus, Atlas, Oracle, etc.). Adaptés au format TOML natif Codex. |
| 8 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 40 skills pour la révision de code, QA, audit de sécurité, déploiement. Inclut un daemon navigateur Playwright. |

---

## GitHub Actions

| Workflow | Déclencheur | Objectif |
|----------|---------|---------|
| **CI** | push, PR | Valide les fichiers d'agents TOML, l'existence des skills et les nombres de fichiers upstream |
| **Update Upstream** | hebdomadaire (lundi) / manuel | Exécute `git submodule update --remote` et crée une PR de fusion automatique |
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
| **Priorité par niveau d'agent** | core > omo > omc > déduplication awesome-core. L'agent le plus spécialisé l'emporte. |
| **Optimisation des coûts** | o4-mini pour le conseil, o3 pour l'implémentation — routage de modèle automatique pour 330+ agents |
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

À la première installation, my-codex active automatiquement un ensemble `dev` recommandé (`engineering`, `design`, `testing`, `marketing`, `support`) et l'enregistre dans `~/.codex/enabled-agent-packs.txt`.

```bash
# Profil minimal (agents principaux uniquement, sans packs)
bash /tmp/my-codex/install.sh --profile minimal

# Profil complet (toutes les 21 catégories de packs activées)
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
| [agency-agents](https://github.com/msitarzewski/agency-agents) | sous-module |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | sous-module |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | sous-module |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | sous-module |
| [gstack](https://github.com/garrytan/gstack) | sous-module |
| [superpowers](https://github.com/obra/superpowers) | sous-module |

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

Les packs d'agents sont des collections d'agents spécifiques à un domaine, installées dans `~/.codex/agent-packs/`. À la première installation, un profil `dev` est activé automatiquement. Utilisez `my-codex-packs enable <pack>` pour activer des packs supplémentaires, ou réinstallez avec `--profile full` pour activer les 21 catégories.

</details>

<details>
<summary><strong>Comment fonctionne la synchronisation upstream ?</strong></summary>

Un workflow GitHub Actions s'exécute chaque lundi, récupérant les derniers commits de tous les sous-modules upstream et créant une PR de fusion automatique. Vous pouvez également le déclencher manuellement depuis l'onglet Actions.

</details>

<details>
<summary><strong>Quels modèles utilise my-codex ?</strong></summary>

Boss et les sous-orchestrateurs (Sisyphus, Atlas, Oracle) utilisent o3 avec un niveau de raisonnement élevé. Les agents de travail standard utilisent o3 avec un raisonnement moyen. Les agents de conseil légers utilisent o4-mini.

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

Construit sur le travail de : [my-claude](https://github.com/sehoon787/my-claude) (sehoon787), [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo), [agency-agents](https://github.com/msitarzewski/agency-agents) (msitarzewski), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m), [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu), [gstack](https://github.com/garrytan/gstack) (garrytan), [superpowers](https://github.com/obra/superpowers) (Jesse Vincent), [openai/skills](https://github.com/openai/skills) (OpenAI).

## Licence

Licence MIT. Voir le fichier [LICENSE](./LICENSE) pour plus de détails.
