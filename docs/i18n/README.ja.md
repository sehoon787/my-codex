[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code をお探しの方は → **my-claude** — ネイティブ Claude `.md` エージェントフォーマットで同じ Boss オーケストレーションを提供

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-330%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

**OpenAI Codex CLI 向けオールインワン・エージェントハーネス。**
**一度インストールするだけで、330 以上のエージェントがすぐに使えます。**

Boss はランタイムですべてのエージェントとスキルを自動検出し、
`spawn_agent` を通じて適切なスペシャリストにタスクをルーティングします。設定もボイラープレートも不要です。

<img src="./assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## インストール

### 人間向け

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

### AI エージェント向け

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

---

## Boss の仕組み

Boss は my-codex の中核にあるメタオーケストレーターです。コードを書くことはなく、検出・分類・マッチング・委任・検証を行います。

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

### 優先ルーティング

Boss はすべてのリクエストを優先チェーンにカスケードし、最適なマッチを見つけます:

| 優先度 | マッチタイプ | 条件 | 例 |
|:--------:|-----------|------|---------|
| **P1** | スキルマッチ | タスクが自己完結型スキルに対応する場合 | `"merge PDFs"` → pdf スキル |
| **P2** | スペシャリストエージェント | ドメイン固有のエージェントが存在する場合 | `"security audit"` → security-reviewer |
| **P3a** | Boss ダイレクト | 2〜4 個の独立エージェント | `"fix 3 bugs"` → 並列スポーン |
| **P3b** | サブオーケストレーター | 複雑なマルチステップワークフロー | `"refactor + test"` → Sisyphus |
| **P4** | フォールバック | スペシャリストが一致しない場合 | `"explain this"` → 汎用エージェント |

### モデルルーティング

| 複雑度 | モデル | 使用場面 |
|-----------|-------|----------|
| 深い分析、アーキテクチャ | o3 (high reasoning) | Boss、Oracle、Sisyphus、Atlas |
| 標準的な実装 | o3 (medium) | executor、debugger、security-reviewer |
| 簡単な検索、調査 | o4-mini (low) | explore、簡易アドバイザリー |

### 3 フェーズスプリントワークフロー

エンドツーエンドの機能実装において、Boss は構造化されたスプリントをオーケストレートします:

```
Phase 1: DESIGN         Phase 2: EXECUTE        Phase 3: REVIEW
(interactive)            (autonomous)             (interactive)
─────────────────────   ─────────────────────   ─────────────────────
User decides scope      executor runs tasks     Compare vs design doc
Engineering review      Auto code review        Present comparison table
Confirm "design done"   Architect verification  User: approve / improve
```

---

## アーキテクチャ

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

## 含まれるもの

| カテゴリ | 数 | ソース |
|----------|------:|--------|
| **コアエージェント**（常時ロード） | 98 | Boss 1 + OMO 9 + OMX 33 + Awesome Core 54 + Superpowers 1 |
| **エージェントパック**（オンデマンド） | 220+ | agency-agents + awesome-codex-subagents の 20 ドメインカテゴリ |
| **スキル** | 200+ | ECC 180+ · gstack 40 · OMX 36 · Superpowers 14 · Core 1 |
| **MCP サーバー** | 3 | Context7、Exa、grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>コアエージェント — Boss メタオーケストレーター (1)</strong></summary>

| エージェント | モデル | 役割 | ソース |
|-------|-------|------|--------|
| Boss | o3 high | ダイナミックランタイム検出 → ケイパビリティマッチング → 最適ルーティング。コードは書かない。 | my-codex |

</details>

<details>
<summary><strong>OMO エージェント — サブオーケストレーターとスペシャリスト (9)</strong></summary>

| エージェント | モデル | 役割 | ソース |
|-------|-------|------|--------|
| Sisyphus | o3 high | インテント分類 → スペシャリスト委任 → 検証 | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | o3 high | 自律的な調査 → 計画 → 実行 → 検証 | oh-my-openagent |
| Atlas | o3 high | タスク分解 + 4 ステージ QA 検証 | oh-my-openagent |
| Oracle | o3 high | 戦略的技術コンサルティング（読み取り専用） | oh-my-openagent |
| Metis | o3 high | インテント分析、曖昧さ検出 | oh-my-openagent |
| Momus | o3 high | 計画実現可能性レビュー | oh-my-openagent |
| Prometheus | o3 high | インタビューベースの詳細計画立案 | oh-my-openagent |
| Librarian | o3 medium | MCP 経由のオープンソースドキュメント検索 | oh-my-openagent |
| Multimodal-Looker | o3 medium | 画像・スクリーンショット・図の分析 | oh-my-openagent |

</details>

<details>
<summary><strong>OMC エージェント — スペシャリストワーカー (19)</strong></summary>

| エージェント | 役割 | ソース |
|-------|------|--------|
| analyst | 計画前の事前分析 | [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) |
| architect | システム設計とアーキテクチャ | oh-my-claudecode |
| code-reviewer | 集中的なコードレビュー | oh-my-claudecode |
| code-simplifier | コードの簡略化とクリーンアップ | oh-my-claudecode |
| critic | 批判的分析、代替案の提案 | oh-my-claudecode |
| debugger | 集中的なデバッグ | oh-my-claudecode |
| designer | UI/UX デザインガイダンス | oh-my-claudecode |
| document-specialist | ドキュメント作成 | oh-my-claudecode |
| executor | タスク実行 | oh-my-claudecode |
| explore | コードベースの調査 | oh-my-claudecode |
| git-master | Git ワークフロー管理 | oh-my-claudecode |
| planner | 迅速な計画立案 | oh-my-claudecode |
| qa-tester | 品質保証テスト | oh-my-claudecode |
| scientist | リサーチと実験 | oh-my-claudecode |
| security-reviewer | セキュリティレビュー | oh-my-claudecode |
| test-engineer | テスト作成と保守 | oh-my-claudecode |
| tracer | 実行トレースと分析 | oh-my-claudecode |
| verifier | 最終検証 | oh-my-claudecode |
| writer | コンテンツとドキュメント | oh-my-claudecode |

</details>

<details>
<summary><strong>Awesome Core エージェント (54) — awesome-codex-subagents より</strong></summary>

`~/.codex/agents/` に 4 カテゴリをインストール:

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
<summary><strong>Superpowers エージェント (1) — obra/superpowers より</strong></summary>

| エージェント | 役割 | ソース |
|-------|------|--------|
| superpowers-code-reviewer | ブレインストーミングと TDD 検証を含む包括的なコードレビュー | [superpowers](https://github.com/obra/superpowers) |

</details>

<details>
<summary><strong>エージェントパック — オンデマンドドメインスペシャリスト (21 カテゴリ)</strong></summary>

`~/.codex/agent-packs/` にインストールされます。管理方法:

```bash
# 現在の状態を確認
~/.codex/bin/my-codex-packs status

# パックを即時有効化
~/.codex/bin/my-codex-packs enable marketing

# インストール時にプロファイルを切り替え
bash /tmp/my-codex/install.sh --profile minimal
bash /tmp/my-codex/install.sh --profile full
```

| パック | 数 | 例 |
|------|------:|---------|
| engineering | 32 | バックエンド、フロントエンド、モバイル、DevOps、AI、データ |
| marketing | 27 | Douyin、Xiaohongshu、WeChat OA、TikTok、SEO |
| language-specialists | 27 | Python、Go、Rust、Swift、Kotlin、Java |
| specialized | 31 | 法律、金融、医療、ワークフロー |
| game-development | 20 | Unity、Unreal、Godot、Roblox、Blender |
| infrastructure | 19 | クラウド、K8s、Terraform、Docker、SRE |
| developer-experience | 13 | MCP Builder、LSP、ターミナル、Rapid Prototyper |
| data-ai | 13 | Data Engineer、ML、データベース、ClickHouse |
| specialized-domains | 12 | サプライチェーン、物流、E コマース |
| design | 11 | ブランド、UI、UX、ビジュアルストーリーテリング |
| business-product | 11 | プロダクトマネージャー、グロース、アナリティクス |
| testing | 11 | API、アクセシビリティ、パフォーマンス、E2E、QA |
| sales | 8 | ディール戦略、パイプライン、アウトバウンド |
| paid-media | 7 | Google Ads、Meta Ads、プログラマティック |
| research-analysis | 7 | トレンド、市場、競合分析 |
| project-management | 6 | アジャイル、Jira、ワークフロー |
| spatial-computing | 6 | XR、WebXR、AR/VR、visionOS |
| support | 6 | カスタマーサポート、デベロッパーアドボカシー |
| academic | 5 | 留学、企業研修 |
| product | 5 | プロダクト管理、UX リサーチ |
| security | 5 | ペネトレーションテスト、コンプライアンス、監査 |

</details>

<details>
<summary><strong>スキル — 5 つのソースから 200 以上</strong></summary>

| ソース | 数 | 主要スキル |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 180+ | tdd-workflow、autopilot、security-review、coding-standards |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 36 | plan、team、trace、deep-dive、blueprint、ultrawork |
| [gstack](https://github.com/garrytan/gstack) | 40 | /qa、/review、/ship、/cso、/investigate、/office-hours |
| [superpowers](https://github.com/obra/superpowers) | 14 | brainstorming、systematic-debugging、TDD、parallel-agents |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 1 | boss-advanced |

</details>

<details>
<summary><strong>MCP サーバー (3)</strong></summary>

| サーバー | 目的 | コスト |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://mcp.context7.com) | リアルタイムライブラリドキュメント | 無料 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://mcp.exa.ai) | セマンティックウェブ検索 | 月 1,000 リクエスト無料 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://mcp.grep.app) | GitHub コード検索 | 無料 |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian 互換の永続メモリ。各プロジェクトはセッション間で自動入力される `.briefing/` ディレクトリを維持します。

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

### 自動化ライフサイクル

| フェーズ | フックイベント | 何が起きるか |
|-------|-----------|-------------|
| **セッション開始** | `SessionStart` | `.briefing/` 構造を作成し、セッション固有の差分のために git HEAD ハッシュを保存 |
| **作業中** | `PostToolUse` Edit/Write | ファイル編集数を追跡; 5 回で警告、decisions/learnings が未記入の場合 15 回でブロック |
| **作業中** | `PostToolUse` WebSearch/WebFetch | URL を `references/auto-links.md` に自動収集 |
| **作業中** | `SubagentStop` | エージェント実行を `agents/agent-log.jsonl` に記録 |
| **作業中** | `UserPromptSubmit`（5 回ごと） | スロットルされたペルソナプロファイル更新 |
| **セッション終了** | `Stop`（第 1 フック） | スキャフォールドを自動生成: `sessions/auto.md`、`learnings/auto-session.md`、`decisions/auto.md`、`persona/profile.md` |
| **セッション終了** | `Stop`（第 2 フック） | ファイル編集が 3 回以上の場合、AI によるセッションサマリーを**強制** — テンプレートでセッション終了をブロック |

### 自動生成 vs AI 記述

| タイプ | ファイルパターン | 作成者 | 内容 |
|------|-------------|-----------|---------|
| **自動スキャフォールド** | `*-auto.md`、`*-auto-session.md` | Stop フック (Node.js) | Git diff 統計、エージェント使用状況、コミットリスト — データのみ |
| **AI サマリー** | `YYYY-MM-DD-<topic>.md` | セッション中の AI | コンテキスト、コード参照、根拠を含む意味のある分析 |
| **テレメトリー** | `agent-log.jsonl`、`auto-links.md` | フックスクリプト | 追記専用の構造化ログ |
| **ペルソナ** | `profile.md`、`suggestions.jsonl` | Stop フック | 使用量ベースのエージェントアフィニティとルーティング提案 |

自動スキャフォールドは AI が適切なサマリーを書くための**参照データ**として機能します。強制フックはセッション終了をブロックする際にスキャフォールドコンテンツと構造化テンプレートを提供します。

### セッション固有の差分

セッション開始時、現在の git HEAD が `.briefing/.session-start-head` に保存されます。セッション終了時、差分はこの保存されたポイントを基準に計算されます — 以前のセッションから蓄積された未コミットの変更ではなく、現在のセッションの変更のみを表示します。

### Obsidian との使い方

1. Obsidian を開く → **フォルダをボルトとして開く** → `.briefing/` を選択
2. ノートはグラフビューに表示され、`[[wiki-links]]` でリンクされます
3. YAML フロントマター（`date`、`type`、`tags`）で構造化検索が可能
4. 意思決定と学習のタイムラインがセッションを重ねるごとに自動的に構築されます

---

## アップストリームのオープンソースソース

my-codex は 8 つのアップストリームリポジトリのコンテンツをバンドルしています:

| # | ソース | 提供内容 |
|---|--------|-----------------|
| 1 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 姉妹プロジェクト。ネイティブ Claude `.md` エージェントフォーマットで同じ Boss オーケストレーションを実現。スキル、ルール、Briefing Vault を両プロジェクトで共有。 |
| 2 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | ネイティブ TOML フォーマットの 136 のプロダクショングレードエージェント。Codex 互換のため変換不要。54 のコアエージェントが自動ロード。 |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | Codex CLI 向けの 36 スキル、フック、HUD、チームパイプライン。アーキテクチャのインスピレーションとして参照。 |
| 4 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 14 カテゴリにわたる 180 以上のビジネススペシャリストエージェントペルソナ。自動化パイプラインで Markdown からネイティブ TOML に変換済み。 |
| 5 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 開発ワークフロー全般にわたる 180 以上のスキル。Claude Code 固有のコンテンツを除去し、汎用コーディングスキルを保持。 |
| 6 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | ブレインストーミング、TDD、並列エージェント、コードレビューをカバーする 14 スキル + 1 エージェント。 |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 9 つの OMO エージェント（Sisyphus、Atlas、Oracle など）。Codex ネイティブ TOML フォーマットに適応済み。 |
| 8 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | コードレビュー、QA、セキュリティ監査、デプロイメント向けの 40 スキル。Playwright ブラウザデーモンを含む。 |

---

## GitHub Actions

| ワークフロー | トリガー | 目的 |
|----------|---------|---------|
| **CI** | push、PR | TOML エージェントファイル、スキルの存在、アップストリームファイル数を検証 |
| **Update Upstream** | 週次（月曜）/ 手動 | `git submodule update --remote` を実行し、自動マージ PR を作成 |
| **Auto Tag** | main へのプッシュ | `config.toml` からバージョンを読み取り、新しい場合は git タグを作成 |
| **Pages** | main へのプッシュ | `docs/index.html` を GitHub Pages にデプロイ |
| **CLA** | PR | コントリビューターライセンス契約チェック |
| **Lint Workflows** | push、PR | GitHub Actions ワークフロー YAML 構文を検証 |

---

## my-codex オリジナル

アップストリームソースが提供するものを超えて、このプロジェクト専用に構築された機能:

| 機能 | 説明 |
|---------|-------------|
| **Boss メタオーケストレーター** | ダイナミックケイパビリティ検出 → インテント分類 → 4 優先ルーティング → 委任 → 検証 |
| **3 フェーズスプリント** | 設計（インタラクティブ）→ 実行（executor による自律）→ レビュー（設計書との比較インタラクティブ） |
| **エージェント層優先度** | core > omo > omc > awesome-core 重複排除。最も特化したエージェントが優先。 |
| **コスト最適化** | アドバイザリーには o4-mini、実装には o3 — 330 以上のエージェントへの自動モデルルーティング |
| **エージェントテレメトリー** | PostToolUse フックがエージェント使用状況を `agent-usage.jsonl` に記録 |
| **スマートパック** | プロジェクトタイプ検出がセッション開始時に関連エージェントパックを推奨 |
| **エージェントパックシステム** | `--profile` と `my-codex-packs` ヘルパーによるオンデマンドのドメインスペシャリスト有効化 |
| **Codex アトリビューション** | git フックが Codex が変更したファイルを記録し、コミットメッセージに `AI-Contributed-By: Codex` を追加 |
| **CI 重複検出** | アップストリーム同期をまたいだ TOML エージェントの重複を自動検出 |

---

## インストールオプション

### クイックインストール

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

同じコマンドを再実行すると最新の `main` ビルドに更新され、`~/.codex/` 内の my-codex 管理ファイルのみが置き換えられ、`~/.agents/skills/` から古いスキルのコピーが削除されます。

### エージェントパックプロファイル

初回インストール時、my-codex は推奨の `dev` セット（`engineering`、`design`、`testing`、`marketing`、`support`）を自動有効化し、`~/.codex/enabled-agent-packs.txt` に記録します。

```bash
# Minimal プロファイル（コアエージェントのみ、パックなし）
bash /tmp/my-codex/install.sh --profile minimal

# Full プロファイル（全 21 パックカテゴリを有効化）
bash /tmp/my-codex/install.sh --profile full
```

### Codex アトリビューションシステム

`install.sh` は `codex` ラッパーと `~/.codex/git-hooks/` のグローバル git フックをインストールします:

- **`prepare-commit-msg`** — 実際の Codex セッション中に変更されたファイルを記録
- **`commit-msg`** — ステージされたファイルが記録された変更セットと交差する場合に `Generated with Codex CLI: https://github.com/openai/codex` を追加
- **`post-commit`** — 対象コミットに `AI-Contributed-By: Codex` トレーラーを追加

オプトイン `Co-authored-by` トレーラー: `git config --global my-codex.codexContributorName '<label>'` と `my-codex.codexContributorEmail '<github-linked-email>'` の両方を設定してください。完全に無効化するには: `git config --global my-codex.codexAttribution false`。my-codex は `git user.name`、`git user.email`、またはコミット作者 ID を変更**しません**。

### エージェント TOML フォーマット

すべてのエージェントは `~/.codex/agents/` のネイティブ TOML ファイルです:

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

`~/.codex/config.toml` のグローバル Codex 設定:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — 最大同時サブエージェント数
- `max_depth` — エージェントがエージェントをスポーンするチェーンの最大ネスト深度

---

## バンドルされたアップストリームバージョン

アップストリームソースは git サブモジュールとして管理。ピン留めされたコミットは `.gitmodules` で追跡。

| ソース | 同期 |
|--------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | submodule |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | submodule |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | submodule |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | submodule |
| [gstack](https://github.com/garrytan/gstack) | submodule |
| [superpowers](https://github.com/obra/superpowers) | submodule |

---

## よくある質問

<details>
<summary><strong>my-codex と my-claude の違いは何ですか？</strong></summary>

my-codex と my-claude は同じ Boss オーケストレーションアーキテクチャとアップストリームスキルソースを共有しています。主な違いはランタイムです: my-codex はネイティブ `.toml` エージェントフォーマットと `spawn_agent` 委任で OpenAI Codex CLI を対象とし、my-claude は `.md` エージェントフォーマットと Agent ツールで Claude Code を対象としています。

</details>

<details>
<summary><strong>my-codex と my-claude を両方使えますか？</strong></summary>

はい。それぞれ別のディレクトリ（`~/.codex/` と `~/.claude/`）にインストールされるため、競合しません。共有アップストリームソースのスキルは各プラットフォーム向けに適応されています。

</details>

<details>
<summary><strong>エージェントパックはどのように機能しますか？</strong></summary>

エージェントパックは `~/.codex/agent-packs/` にインストールされるドメイン固有のエージェントコレクションです。初回インストール時に `dev` プロファイルが自動有効化されます。`my-codex-packs enable <pack>` で追加パックを有効化するか、`--profile full` で再インストールして全 21 カテゴリを有効化できます。

</details>

<details>
<summary><strong>アップストリーム同期はどのように機能しますか？</strong></summary>

GitHub Actions ワークフローが毎週月曜日に実行され、すべてのアップストリームサブモジュールから最新のコミットを取得し、自動マージ PR を作成します。Actions タブから手動でトリガーすることもできます。

</details>

<details>
<summary><strong>my-codex が使用するモデルは何ですか？</strong></summary>

Boss とサブオーケストレーター（Sisyphus、Atlas、Oracle）は高い推論努力で o3 を使用します。標準ワーカーは中程度の推論で o3 を使用します。軽量アドバイザリーエージェントは o4-mini を使用します。

</details>

---

## トラブルシューティング

### スキルのみの復旧

`~/.agents/skills/` 以下で無効な `SKILL.md` ファイルがツールから報告される場合、最も一般的な原因は古いローカルコピーまたは古いインストールからのシンボリックリンクターゲットです。

`~/.agents/skills/` から影響を受けたディレクトリと `~/.claude/skills/` 以下の対応エントリを削除してから再インストールしてください:

```bash
npx skills add sehoon787/my-codex -y -g
```

Codex フルバンドルを使用している場合は、`install.sh` を一度再実行してください。フルインストーラーは `~/.codex/skills/` を更新し、`~/.agents/skills/` 以下の古い my-codex 管理コピーを削除します。

---

## コントリビューション

Issues と PR を歓迎します。新しいエージェントを追加する際は、`codex-agents/core/` または `codex-agents/omo/` に `.toml` ファイルを追加し、`SETUP.md` のエージェントリストを更新してください。PR 検証手順と Codex コミットアトリビューションの動作については [CONTRIBUTING.md](./CONTRIBUTING.md) を参照してください。

## クレジット

以下の成果物の上に構築されています: [my-claude](https://github.com/sehoon787/my-claude) (sehoon787)、[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent)、[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo)、[agency-agents](https://github.com/msitarzewski/agency-agents) (msitarzewski)、[everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m)、[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu)、[gstack](https://github.com/garrytan/gstack) (garrytan)、[superpowers](https://github.com/obra/superpowers) (Jesse Vincent)、[openai/skills](https://github.com/openai/skills) (OpenAI)。

## ライセンス

MIT ライセンス。詳細は [LICENSE](./LICENSE) ファイルをご参照ください。
