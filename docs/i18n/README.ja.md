[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code をお探しですか？ → **my-claude** — Claude Code プラグインと同じエージェント、Boss メタオーケストレータ付き

> **LLM エージェントの場合**、インストールガイドをフェッチして実行してください：
> ```bash
> curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
> ```
> 完全な出力を読み、各ステップを順序通りに実行してください。`WebFetch` ではなく `curl` を使用してください (概要は重要な設定値を失うため)。

---

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-400%2B-blue)
![Skills](https://img.shields.io/badge/skills-200%2B-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

OpenAI Codex CLI 向けオールインワン マルチエージェント オーケストレーション — 一度インストールするだけで、すべてが手に入ります。

**400以上のインストール済みエージェントファイル** と 6 つのアップストリームソースから **200以上のスキル** をネイティブ TOML 形式にバンドルします。Codex CLI は `spawn_agent` 経由でエージェントを自動検出し、タスクを最適なスペシャリストにルーティングします。GitHub Actions CI は週単位でアップストリーム変更を同期します。

公式 [Codex Subagents](https://developers.openai.com/codex/subagents) 仕様に基づいています。

---

## コアプリンシプル

| プリンシプル | 説明 |
|-----------|-------------|
| **ネイティブ TOML** | すべてのエージェントが Codex CLI のネイティブ `.toml` 形式 — ランタイム変換なし、互換性の問題なし |
| **マルチソース キュレーション** | 6 つのアップストリームソースを集約、重複排除、品質チェックして単一コレクションに |
| **ゼロ設定** | 一度インストールするだけで、444 エージェントと 140 スキルが手に入ります。`config.toml` は `multi_agent = true` で自動設定 |

## クイックスタート

### 人間の場合

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

> **エージェントパック**: ドメイン スペシャリスト エージェント (マーケティング、セールス、ゲーム開発など) は `~/.codex/agent-packs/` にインストールされ、必要に応じて `~/.codex/agents/` にシンボリックリンクして有効化できます。

### LLM エージェントの場合

AI インストールガイドをフェッチして、各ステップを実行します：

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

完全な出力を読み、各ステップを順序通りに実行してください。`WebFetch` ではなく `curl` を使用してください。

---

## 主要機能

### マルチエージェント オーケストレーション
- **spawn_agent**: Codex CLI は `~/.codex/agents/` からエージェントを自動検出し、複雑なタスク向けに並列でスポーンします
- **send_input**: 反復的なワークフロー向けの親子間エージェント通信
- **エージェントパック**: シンボリックリンク経由でドメイン スペシャリストをオンデマンド有効化 — 再起動不要

### モデル最適化ルーティング
- **o3 (高推論)**: 複雑なアーキテクチャ、深い分析 — Claude Opus 相当からマッピング
- **o3 (中推論)**: 標準実装、コードレビュー — Claude Sonnet 相当からマッピング
- **o4-mini (低推論)**: 高速ルックアップ、探索 — Claude Haiku 相当からマッピング

### オールインワン バンドル
- インストールは **400以上のインストール済みエージェントファイルと200以上のスキル** を即座に提供
- 6 つのアップストリームソース (agency-agents、everything-claude-code、oh-my-codex、awesome-codex-subagents、gstack、superpowers) をバンドル
- 週単位の CI 自動同期がバンドルコンテンツをアップストリーム化
- ネイティブ以外のソース向け MD-to-TOML 変換は自動処理

---

## コアエージェント

4 つのソースリポジトリから 38 個のコアエージェントと 54 個の Awesome Core エージェントが `~/.codex/agents/` にインストールされます。ソース間のファイル名重複により、最終的な自動読み込みエージェントは 80 個になります。ドメイン スペシャリストはエージェントパック内にあります。

### my-codex Core (1) — Boss メタオーケストレータ
boss

### Oh My OpenAgent / OMO (9) — サブオーケストレータとスペシャリスト
atlas, hephaestus, librarian, metis, momus, multimodal-looker, oracle, prometheus, sisyphus

### Oh My Claude Code / OMC (18) — スペシャリスト エージェント
analyst, architect, code-reviewer, code-simplifier, critic, debugger, document-specialist, executor, explore, git-master, planner, qa-tester, scientist, security-reviewer, test-engineer, tracer, verifier, writer

### Awesome Core (9) — awesome-codex-subagents からのオーケストレーション サポート
agent-installer, agent-organizer, code-mapper, context-manager, error-coordinator, knowledge-synthesizer, multi-agent-coordinator, task-distributor, workflow-orchestrator

### Superpowers (1) — obra/superpowers からのコードレビュアー
superpowers-code-reviewer

---

## エージェントパック (ドメイン スペシャリスト)

364 個のインストール済みパックファイル (21 カテゴリ) が `~/.codex/agent-packs/` に配置されます — デフォルトでは読み込まれません。シンボリックリンク経由でパックを有効化：

```bash
# 単一パックを有効化
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# 無効化
rm ~/.codex/agents/<agent-name>.toml
```

| パック | 数 | 例 |
|------|---|---------|
| engineering | 32 | バックエンド、フロントエンド、モバイル、DevOps、AI、データ |
| marketing | 27 | Douyin、Xiaohongshu、WeChat OA、TikTok、SEO |
| language-specialists | 27 | Python、Go、Rust、Swift、Kotlin、Java |
| specialized | 31 | 法律、金融、医療、ワークフロー |
| game-development | 20 | Unity、Unreal、Godot、Roblox、Blender |
| infrastructure | 19 | クラウド、K8s、Terraform、Docker、SRE |
| developer-experience | 13 | MCP ビルダー、LSP、ターミナル、ラピッド プロトタイパー |
| data-ai | 13 | データエンジニア、ML、データベース、ClickHouse |
| specialized-domains | 12 | サプライチェーン、ロジスティクス、e コマース |
| design | 11 | ブランド、UI、UX、ビジュアルストーリーテリング |
| business-product | 11 | プロダクトマネージャー、グロース、分析 |
| testing | 11 | API、アクセシビリティ、パフォーマンス、E2E、QA |
| sales | 8 | 取引戦略、パイプライン、アウトバウンド |
| paid-media | 7 | Google 広告、Meta 広告、プログラマティック |
| research-analysis | 7 | トレンド、市場、競争分析 |
| project-management | 6 | アジャイル、Jira、ワークフロー |
| spatial-computing | 6 | XR、WebXR、AR/VR、visionOS |
| support | 6 | カスタマーサポート、デベロッパー アドボケート |
| academic | 5 | 海外留学、企業研修 |
| product | 5 | プロダクト管理、UX リサーチ |
| security | 5 | ペネトレーション テスト、コンプライアンス、監査 |

---

## インストール済みコンポーネント

| カテゴリ | 数 | ソース | 場所 |
|------|------|------|------|
| 自動読み込みエージェント | 80 インストール済みファイル | `core/`, `omo/`, `omc/`, `awesome-core/`, `superpowers/`, awesome コアカテゴリ | `~/.codex/agents/` |
| エージェントパック | 364 インストール済みファイル | `agent-packs/`, `agency/`, awesome 非コアカテゴリ | `~/.codex/agent-packs/` |
| スキル | 140 | ECC 125, Superpowers 14, Core 1 | `~/.codex/skills/` |
| config.toml | 1 | my-codex | `~/.codex/config.toml` |
| AGENTS.md | 1 | my-codex | `~/.codex/AGENTS.md` |

<details>
<summary>素晴らしいコアエージェント (54) — awesome-codex-subagents から</summary>

`~/.codex/agents/` にインストールされた 4 つのコアカテゴリ：

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
<summary>スキル (140) — Everything Claude Code (125)、Superpowers (14)、Core (1)</summary>

主要スキル：

| スキル | 説明 |
|-------|-------------|
| autopilot | 自動実行モード |
| tdd-workflow | テスト駆動開発の強制 |
| security-review | セキュリティ チェックリストと分析 |
| trace | エビデンス駆動デバッグ |
| pdf | PDF の読み取り、マージ、分割、OCR |
| docx | Word ドキュメントの作成と編集 |
| pptx | PowerPoint の作成と編集 |
| xlsx | Excel ファイルの作成と編集 |
| team | マルチエージェント チーム オーケストレーション |
| backend-patterns | バックエンド アーキテクチャ パターン |
| frontend-patterns | React/Next.js パターン |
| postgres-patterns | PostgreSQL 最適化 |
| coding-standards | TypeScript/React コーディング標準 |
| eval-harness | 評価駆動開発 |
| strategic-compact | 戦略的コンテキスト圧縮 |
| iterative-retrieval | インクリメンタル コンテキスト取得 |
| continuous-learning | セッションからの自動パターン抽出 |

</details>

---

## 完全なアーキテクチャ

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
│  Agent Layer (444 unique agents in native TOML)          │
│    ├── Auto-loaded (80): final installed footprint       │
│    └── Agent Packs (364): final installed footprint      │
├─────────────────────────────────────────────────────────┤
│  Skills Layer (140 from ECC + superpowers + core)        │
│    ├── tdd-workflow, security-review, autopilot         │
│    └── pdf, docx, pptx, xlsx, team                     │
└─────────────────────────────────────────────────────────┘
```

---

## Codex マルチエージェントの仕組み

### Codex Subagents 仕様

Codex CLI は [Codex Subagents](https://developers.openai.com/codex/subagents) 仕様に基づくネイティブ マルチエージェント プロトコルを提供します。プロトコルは 5 つのコア操作を定義します：

| 操作 | 説明 |
|-----------|-------------|
| **spawn_agent** | 特定のロール、モデル、指示でサブエージェントを作成 |
| **send_input** | 反復的な通信向けに実行中のサブエージェントにメッセージを送信 |
| **wait_agent** | サブエージェントの完了を待ち、結果を返す |
| **close_agent** | 実行中のサブエージェントを終了 |
| **resume_agent** | 一時停止したサブエージェントを継続 |

Codex CLI は実行時に `~/.codex/agents/` 内のすべての `.toml` ファイルを自動検出します。タスクが専門的な専門知識を必要とする場合、CLI は名前で一致するエージェントをスポーンし、関連するコンテキストを渡します。

### エージェント TOML 形式

すべてのエージェントはネイティブ TOML ファイルとして定義されます：

```toml
name = "debugger"
description = "Focused debugging specialist"
model = "o3"
model_reasoning_effort = "medium"

[developer_instructions]
content = "You are a debugging specialist..."
```

キー フィールド：
- `name` — `spawn_agent` で使用されるエージェント識別子
- `description` — 機能マッチングに使用
- `model` — 使用する OpenAI モデル (`o3`、`o4-mini`)
- `model_reasoning_effort` — 推論レベル (`high`、`medium`、`low`)
- `[developer_instructions].content` — エージェントのシステムプロンプト

### 設定 (config.toml)

グローバル マルチエージェント設定は `~/.codex/config.toml` で定義されます：

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — 同時実行可能なサブエージェントの最大数
- `max_depth` — エージェント生成チェーン向けの最大ネスト深度

---

## マルチエージェント使用例

### 単一エージェント デリゲーション

```
> Analyze the auth module for security vulnerabilities

Codex → spawn_agent("security-reviewer")
→ Agent analyzes src/auth/
→ Returns: 2 critical, 1 medium vulnerability
```

### 並列スポーン

```
> Run a multi-agent pass: refactor auth, add tests, review security

Codex → spawn_agent("executor") × refactoring
      → spawn_agent("test-engineer") × test writing
      → spawn_agent("security-reviewer") × security audit
→ All 3 run in parallel (max_threads = 8)
→ Results collected and merged
```

### 親子間通信

```
> Implement payment module, then have it reviewed

Codex → spawn_agent("executor")
      → executor completes implementation
      → send_input(executor, "review needed")
      → spawn_agent("code-reviewer")
      → code-reviewer reviews executor's changes
```

### 複雑なオーケストレーション

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

## 使用されているオープンソース ツール

### 1. [Agency Agents](https://github.com/msitarzewski/agency-agents)

134 個のビジネス スペシャリスト エージェント ペルソナのライブラリ。UX アーキテクト、データエンジニア、セキュリティ監査役など、14 カテゴリにわたる専門的観点を提供します。自動化された `md-to-toml.sh` パイプライン経由で Markdown からネイティブ TOML に変換。

### 2. [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)

もともと Claude Code 向けに構築された開発フレームワークで、125 スキルを提供します。13 個の Claude Code 固有スキルは削除されました。残りのスキルはすべての LLM エージェントで使用可能な汎用コーディング ガイダンスを含みます。rules/ ディレクトリは参照資料としてリポジトリに含まれていますが、Codex CLI では読み取られません。

### 3. [Awesome Codex Subagents](https://github.com/VoltAgent/awesome-codex-subagents)

ネイティブ TOML 形式の上流カテゴリベース エージェント コレクションです。このリポジトリでは core development から meta-orchestration まで複数の awesome カテゴリを取り込み、インストール時に他ソースとの重複ファイル名を整理して最終インストール フットプリントへ反映します。

### 4. [Oh My Codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex)

Yeachan Heo による Codex CLI マルチエージェント オーケストレーション フレームワーク。36 スキル、フック、HUD、チーム パイプラインを提供する Rust/TypeScript ランタイム。my-codex のオーケストレーション パターンのアーキテクチャ インスピレーション参考。エージェント TOML ファイルは直接提供しません。

### 5. [Oh My OpenAgent (omo)](https://github.com/code-yeongyu/oh-my-openagent)

code-yeongyu による多目的エージェント ハーネス。このリポジトリの 9 個のオーケストレーション エージェント (atlas、hephaestus、metis、momus、oracle、prometheus、sisyphus、librarian、multimodal-looker) は omo エージェントから適応され、Codex ネイティブ TOML 形式に変換。

### 6. [OpenAI Official Skills](https://github.com/openai/skills)

OpenAI により提供される Codex 向けの公式 Skills Catalog。ドキュメント処理、コード生成、開発ワークフロー向けスペシャリスト スキルを含みます。Codex CLI で `$skill-installer` 経由でインストール可能。

### 7. [gstack](https://github.com/garrytan/gstack)

garrytan のスプリントプロセスハーネス。コードレビュー、QA、デバッグ、ベンチマーク、セキュリティ監査、デプロイメントワークフローを含む 27 スキルを提供。内蔵ヘッドレス Chromium ブラウザデーモンによる実際のブラウザテストをサポート。

### 8. [superpowers](https://github.com/obra/superpowers)

Jesse Vincent によるゼロ依存のコンポーザブル AI コーディング ワークフロー ツールキット。開発ライフサイクル全体をカバーする 14 スキルを提供します：ブレインストーミング、計画の作成、計画の実行、TDD、体系的デバッグ、コードレビュー（依頼と受信）、並列エージェントのディスパッチ、git ワークツリーの使用、完了前の検証、開発ブランチの完了、サブエージェント主導の開発、カスタムスキルの作成。

---

## 貢献

Issues と PR は歓迎します。新しいエージェントを追加する場合は、`agents/` ディレクトリに `.toml` ファイルを追加し、`SETUP.md` のエージェント一覧を更新してください。

---

## バンドルされたアップストリーム バージョン

CI 自動同期により週単位で更新。SOURCES.json はまだありません — バージョンは sync-upstream.yml 経由で追跡。

| ソース | 同期 |
|--------|------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | 週単位の CI |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 週単位の CI |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 週単位の CI |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | 週単位の CI |
| [gstack](https://github.com/garrytan/gstack) | 週単位の CI |
| [superpowers](https://github.com/obra/superpowers) | 週単位の CI |

---

## クレジット

このリポジトリは以下のオープンソース プロジェクトの成果を基に構築されています：

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

## ライセンス

MIT ライセンス。詳細は [LICENSE](./LICENSE) ファイルを参照してください。
