[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Vous cherchez Claude Code ? → **my-claude** — les mêmes agents que le plugin Claude Code avec le méta-orchestrateur Boss

> **Si vous êtes un agent IA**, récupérez et suivez le guide d'installation :
> ```bash
> curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
> ```
> Lisez la sortie COMPLÈTE, puis exécutez chaque étape dans l'ordre. Utilisez `curl`, PAS `WebFetch` (les résumés perdent des valeurs de configuration critiques).

---

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-400%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

Orchestration multi-agents tout-en-un pour OpenAI Codex CLI — une seule installation, tout inclus.

Regroupe **400+ fichiers d'agents installés** et **200+ skills** issus de 6 sources amont au format TOML natif. Codex CLI découvre les agents automatiquement via `spawn_agent` et route les tâches vers le spécialiste optimal. La CI GitHub Actions synchronise les modifications amont chaque semaine.

Basé sur la spécification officielle [Codex Subagents](https://developers.openai.com/codex/subagents).

---

## Principes fondamentaux

| Principe | Description |
|----------|-------------|
| **TOML natif** | Tous les agents au format `.toml` natif de Codex CLI — aucune conversion à l'exécution, aucun problème de compatibilité |
| **Curation multi-sources** | 6 sources amont agrégées, dédupliquées et contrôlées qualité en une seule collection |
| **Zéro configuration** | Une installation, 400+ agents et 200+ skills. `config.toml` est automatiquement configuré avec `multi_agent = true` |

## Démarrage rapide

### Si vous êtes une personne

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

> **Packs d'agents** : Les agents spécialistes de domaine (Marketing, Ventes, Développement de jeux, etc.) sont installés dans `~/.codex/agent-packs/` et peuvent être activés via des liens symboliques vers `~/.codex/agents/` selon les besoins.

### Si vous êtes un agent IA

Récupérez le guide d'installation IA et exécutez chaque étape :

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

Lisez la sortie complète et exécutez chaque étape dans l'ordre. Utilisez `curl`, pas `WebFetch`.

---

## Fonctionnalités principales

### Orchestration multi-agents
- **spawn_agent** : Codex CLI découvre automatiquement les agents depuis `~/.codex/agents/` et les lance en parallèle pour les tâches complexes
- **send_input** : Communication agent parent-vers-enfant pour les workflows itératifs
- **Packs d'agents** : Activez des spécialistes de domaine à la demande via des liens symboliques — aucun redémarrage requis

### Routage optimisé par modèle
- **o3 (raisonnement élevé)** : Architecture complexe, analyse approfondie — mappé depuis les équivalents Claude Opus
- **o3 (moyen)** : Implémentation standard, revue de code — mappé depuis les équivalents Claude Sonnet
- **o4-mini (faible)** : Recherches rapides, exploration — mappé depuis les équivalents Claude Haiku

### Bundle tout-en-un
- L'installation fournit **400+ fichiers d'agents installés et 200+ skills** immédiatement
- Regroupe 6 sources amont (agency-agents, everything-claude-code, oh-my-codex, awesome-codex-subagents, gstack, superpowers)
- La synchronisation automatique CI hebdomadaire maintient le contenu groupé à jour avec les sources amont
- La conversion MD-vers-TOML est effectuée automatiquement pour les sources non natives

---

## Agents principaux

38 agents principaux issus de 4 dépôts sources plus 54 agents Awesome Core sont installés dans `~/.codex/agents/`. Les collisions de noms de fichiers entre sources réduisent l'ensemble auto-chargé final à 80 fichiers installés. Les spécialistes de domaine se trouvent dans les packs d'agents.

### my-codex Core (1) — Méta-orchestrateur Boss
boss

### Oh My OpenAgent / OMO (9) — Sous-orchestrateurs et spécialistes
atlas, hephaestus, librarian, metis, momus, multimodal-looker, oracle, prometheus, sisyphus

### Oh My Claude Code / OMC (18) — Agents spécialistes
analyst, architect, code-reviewer, code-simplifier, critic, debugger, document-specialist, executor, explore, git-master, planner, qa-tester, scientist, security-reviewer, test-engineer, tracer, verifier, writer

### Awesome Core (9) — Support d'orchestration de awesome-codex-subagents
agent-installer, agent-organizer, code-mapper, context-manager, error-coordinator, knowledge-synthesizer, multi-agent-coordinator, task-distributor, workflow-orchestrator

### Superpowers (1) — Réviseur de code de obra/superpowers
superpowers-code-reviewer

---

## Packs d'agents (spécialistes de domaine)

364 fichiers de packs d'agents répartis en 21 catégories sont installés dans `~/.codex/agent-packs/` — **non** chargés par défaut. Activez un pack via un lien symbolique :

```bash
# Activer un pack individuel
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# Désactiver
rm ~/.codex/agents/<agent-name>.toml
```

| Pack | Nombre | Exemples |
|------|--------|---------|
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

---

## Composants installés

| Catégorie | Nombre | Source | Emplacement |
|-----------|--------|--------|-------------|
| Agents chargés automatiquement | 80 fichiers installés | `core/`, `omo/`, `omc/`, `awesome-core/`, `superpowers/`, catégories Awesome Core | `~/.codex/agents/` |
| Packs d'agents | 364 fichiers installés | `agent-packs/`, `agency/`, catégories Awesome non core | `~/.codex/agent-packs/` |
| Skills | 200+ | ECC 180+, gstack 36, OMX 36, Superpowers 14, Core 1 | `~/.codex/skills/` |
| config.toml | 1 | my-codex | `~/.codex/config.toml` |
| AGENTS.md | 1 | my-codex | `~/.codex/AGENTS.md` |

<details>
<summary>Agents Awesome Core (54) — Issus de awesome-codex-subagents</summary>

4 catégories Core installées dans `~/.codex/agents/` :

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
<summary>Skills (200+) — Issus de Everything Claude Code (180+), gstack (36), OMX (36), Superpowers (14) et Core (1)</summary>

Skills importants :

| Skill | Description |
|-------|-------------|
| autopilot | Mode d'exécution autonome |
| tdd-workflow | Application du développement piloté par les tests |
| security-review | Liste de contrôle et analyse de sécurité |
| trace | Débogage guidé par les preuves |
| pdf | Lecture, fusion, division, OCR de PDF |
| docx | Création et édition de documents Word |
| pptx | Création et édition de présentations PowerPoint |
| xlsx | Création et édition de fichiers Excel |
| team | Orchestration d'équipes multi-agents |
| backend-patterns | Modèles d'architecture backend |
| frontend-patterns | Modèles React/Next.js |
| postgres-patterns | Optimisation PostgreSQL |
| coding-standards | Standards de codage TypeScript/React |
| eval-harness | Développement guidé par l'évaluation |
| strategic-compact | Compression de contexte stratégique |
| iterative-retrieval | Récupération de contexte incrémentale |
| continuous-learning | Reconnaissance automatique de patterns depuis les sessions |

</details>

---

## Architecture complète

```
┌─────────────────────────────────────────────────────────┐
│                    User Request                          │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Codex CLI (spawn_agent / send_input / wait_agent)      │
│  Auto-discovers ~/.codex/agents/*.toml at runtime       │
│  Routes to optimal specialist based on task description │
└──┬──────────┬──────────┬──────────┬─────────────────────┘
   ↓          ↓          ↓          ↓
┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐
│Single│ │Parallel│ │Parent- │ │Config  │
│Agent │ │Spawn   │ │Child   │ │Control │
│      │ │(multi) │ │Comms   │ │        │
│spawn │ │spawn × │ │send_   │ │config. │
│_agent│ │N       │ │input   │ │toml    │
└──────┘ └────────┘ └────────┘ └────────┘
┌─────────────────────────────────────────────────────────┐
│  Agent Layer (400+ unique agents in native TOML)          │
│    ├── Auto-loaded (80): empreinte installée finale      │
│    └── Agent Packs (364): empreinte installée finale     │
├─────────────────────────────────────────────────────────┤
│  Skills Layer (200+ from ECC + gstack + OMX + superpowers + core) │
│    ├── tdd-workflow, security-review, autopilot         │
│    └── pdf, docx, pptx, xlsx, team                     │
└─────────────────────────────────────────────────────────┘
```

---

## Fonctionnement du multi-agent Codex

### Spécification Codex Subagents

Codex CLI offre un protocole multi-agents natif basé sur la spécification [Codex Subagents](https://developers.openai.com/codex/subagents). Le protocole définit cinq opérations fondamentales :

| Opération | Description |
|-----------|-------------|
| **spawn_agent** | Crée un sous-agent avec un rôle, un modèle et des instructions spécifiques |
| **send_input** | Envoie un message à un sous-agent en cours d'exécution pour une communication itérative |
| **wait_agent** | Attend qu'un sous-agent termine son travail et retourne ses résultats |
| **close_agent** | Met fin à un sous-agent en cours d'exécution |
| **resume_agent** | Reprend un sous-agent interrompu |

Codex CLI découvre automatiquement tous les fichiers `.toml` dans `~/.codex/agents/` à l'exécution. Lorsqu'une tâche nécessite une expertise spécialisée, la CLI lance l'agent correspondant par son nom et lui transmet le contexte pertinent.

### Format TOML des agents

Chaque agent est défini comme un fichier TOML natif :

```toml
name = "debugger"
description = "Focused debugging specialist"
model = "o3"
model_reasoning_effort = "medium"

[developer_instructions]
content = "You are a debugging specialist..."
```

Champs importants :
- `name` — Identifiant de l'agent utilisé par `spawn_agent`
- `description` — Utilisé pour la correspondance de capacités
- `model` — Modèle OpenAI à utiliser (`o3`, `o4-mini`)
- `model_reasoning_effort` — Niveau de raisonnement (`high`, `medium`, `low`)
- `[developer_instructions].content` — Prompt système de l'agent

### Configuration (config.toml)

Les paramètres multi-agents globaux sont définis dans `~/.codex/config.toml` :

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — Nombre maximum de sous-agents simultanés
- `max_depth` — Profondeur maximale d'imbrication pour les chaînes agent-spawn-agent

---

## Exemples d'utilisation multi-agents

### Délégation à un agent unique

```
> Analyze the auth module for security vulnerabilities

Codex → spawn_agent("security-reviewer")
→ Agent analyzes src/auth/
→ Returns: 2 critical, 1 medium vulnerability
```

### Lancement en parallèle

```
> Run a multi-agent pass: refactor auth, add tests, review security

Codex → spawn_agent("executor") × refactoring
      → spawn_agent("test-engineer") × test writing
      → spawn_agent("security-reviewer") × security audit
→ All 3 run in parallel (max_threads = 8)
→ Results collected and merged
```

### Communication parent-enfant

```
> Implement payment module, then have it reviewed

Codex → spawn_agent("executor")
      → executor completes implementation
      → send_input(executor, "review needed")
      → spawn_agent("code-reviewer")
      → code-reviewer reviews executor's changes
```

### Orchestration complexe

```
> Plan the migration, execute it, then verify

Codex → spawn_agent("planner")
      → planner produces migration plan
      → wait_agent(planner)
      → spawn_agent("executor") with plan as context
      → executor performs migration
      → wait_agent(executor)
      → spawn_agent("verifier")
      → verifier checks all migrations applied correctly
```

---

## Outils open source utilisés

### 1. [Agency Agents](https://github.com/msitarzewski/agency-agents)

Une bibliothèque de 180+ personas d'agents spécialistes métier. Offre des perspectives spécialisées dans 14 catégories — architectes UX, ingénieurs data, auditeurs de sécurité et plus encore. Converti de Markdown vers TOML natif via un pipeline automatisé `md-to-toml.sh`.

### 2. [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)

Un framework de développement conçu à l'origine pour Claude Code, fournissant 180+ skills. 13 skills spécifiques à Claude Code ont été supprimés ; les skills restants contiennent des directives de codage génériques utilisables avec n'importe quel agent LLM. Le répertoire rules/ est inclus dans le dépôt comme matériel de référence, mais n'est pas lu par Codex CLI.

### 3. [Awesome Codex Subagents](https://github.com/VoltAgent/awesome-codex-subagents)

Collection d'agents au format TOML natif organisée par catégorie. Ce dépôt importe plusieurs catégories awesome du développement principal à la méta-orchestration, et résout les collisions de noms de fichiers avec les autres sources lors de l'installation.

### 4. [Oh My Codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex)

Framework d'orchestration multi-agents Codex CLI de Yeachan Heo. Un runtime Rust/TypeScript avec 36 skills, hooks, HUD et pipelines d'équipes pour Codex CLI. Référencé comme inspiration architecturale pour les patterns d'orchestration de my-codex. Ne fournit pas de fichiers TOML d'agents directement.

### 5. [Oh My OpenAgent (omo)](https://github.com/code-yeongyu/oh-my-openagent)

Un harnais d'agents multi-plateforme de code-yeongyu. Les agents d'orchestration de ce dépôt (atlas, hephaestus, metis, momus, oracle, prometheus, sisyphus, librarian, multimodal-looker) sont adaptés des agents omo, convertis au format TOML natif Codex.

### 6. [OpenAI Official Skills](https://github.com/openai/skills)

Le catalogue officiel de skills pour Codex par OpenAI. Comprend des skills spécialisés pour le traitement de documents, la génération de code et les workflows de développement. Peut être installé via `$skill-installer` dans Codex CLI.

### 7. [gstack](https://github.com/garrytan/gstack)

Harnais de processus sprint de garrytan avec 27 skills. Revue de code, QA, débogage, benchmarking, audit de sécurité, workflows de déploiement. Daemon de navigateur Chromium headless intégré pour les tests navigateur réels.

### 8. [superpowers](https://github.com/obra/superpowers)

Boîte à outils de workflow de codage IA composable sans dépendances par Jesse Vincent. Fournit 14 skills couvrant l'intégralité du cycle de développement : brainstorming, rédaction de plans, exécution de plans, TDD, débogage systématique, revue de code (demande et réception), dispatch d'agents parallèles, utilisation de worktrees git, vérification avant finalisation, clôture des branches de développement, développement piloté par sous-agents et rédaction de skills personnalisés.

---

## Contribuer

Les issues et PR sont les bienvenus. Si vous ajoutez un nouvel agent, ajoutez un fichier `.toml` au répertoire `agents/` et mettez à jour la liste des agents dans `SETUP.md`.

---

## Versions amont groupées

Mises à jour hebdomadairement par la synchronisation automatique CI. Les sources upstream sont gérées en tant que sous-modules git. Les métadonnées sont enregistrées dans `upstream/SOURCES.json`.

| Source | Synchronisation |
|--------|----------------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | CI hebdomadaire |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | CI hebdomadaire |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | CI hebdomadaire |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | CI hebdomadaire |
| [gstack](https://github.com/garrytan/gstack) | CI hebdomadaire |
| [superpowers](https://github.com/obra/superpowers) | CI hebdomadaire |

---

## Remerciements

Ce dépôt s'appuie sur le travail des projets open source suivants :

- [agency-agents](https://github.com/msitarzewski/agency-agents) — msitarzewski
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — affaan-m
- [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) — Yeachan Heo
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) — code-yeongyu
- [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) — VoltAgent
- [openai/skills](https://github.com/openai/skills) — OpenAI
- [gstack](https://github.com/garrytan/gstack) — garrytan
- [superpowers](https://github.com/obra/superpowers) — Jesse Vincent
- [Codex Subagents Spec](https://developers.openai.com/codex/subagents) — OpenAI

---

## Licence

Licence MIT. Voir le fichier [LICENSE](./LICENSE) pour plus de détails.
