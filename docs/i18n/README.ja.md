[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code をお探しの方は → **my-claude** — ネイティブ Claude `.md` エージェントフォーマットで同じ Boss オーケストレーションを提供

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-123-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**OpenAI Codex CLI 向けオールインワン・エージェントハーネス。**
**一度インストールするだけで、厳選された 17 のエージェントがすぐに使えます。**

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
| **P1** | スキルマッチ | タスクが自己完結型スキルに対応する場合 | `"review this diff"` → /review スキル |
| **P2** | スペシャリストエージェント | ドメイン固有のエージェントが存在する場合 | `"security audit"` → security-reviewer |
| **P3a** | Boss ダイレクト | 2〜4 個の独立エージェント | `"fix 3 bugs"` → 並列スポーン |
| **P3b** | サブオーケストレーター | 複雑なマルチステップワークフロー | `"refactor + test"` → Sisyphus |
| **P4** | フォールバック | スペシャリストが一致しない場合 | `"explain this"` → 汎用エージェント |

### モデルルーティング

| 複雑度 | モデル | 使用場面 |
|-----------|-------|----------|
| 深い分析、アーキテクチャ | gpt-6-astra (high/xhigh reasoning) | Boss、Oracle、Sisyphus、Atlas |
| 標準的な実装 | gpt-5.6-terra (medium) | executor、debugger、security-reviewer |
| 簡単な検索、調査 | gpt-5.6-luna (low) | explore、簡易アドバイザリー |

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

### 構造化された最終レポート

Boss は作業が発生したすべてのターン — ファイルの編集・作成、コミット/PR/マージ、設定変更、検証の実行があったターン — を、diff を開かなくても読み取れる構造化された最終レポートで締めくくります。レポートは固定された 5 つのテーブルから組み立てられ、各テーブルはその状況が実際に発生した場合にのみ出力されます（空のテーブルは決して出力しません）:

| 状況 | テーブル | 列 |
|-----------|-------|---------|
| ファイル/設定の変更 | 변경 대조 (Changes) | 대상 / Before / After / 근거 |
| 複数タスクの完了 | 작업 요약 (Work summary) | 항목 / 결과 / 근거 |
| 検証を実行 | 검증 결과 (Verification) | 항목 / 기대 / 실제 / 판정 |
| コミット/PR を作成 | 산출물 (Deliverables) | PR / 저장소 / 내용 / 상태 |
| 未解決事項あり | 남은 것 (Remaining) | 항목 / 상태 / 다음 조치 |

このレポートは推論の最後にのみ発動し — タスク途中の進捗報告としては決して出力されず — 純粋な Q&A のターンはレポートなしで通常どおり終了します。仕様は `boss.toml` の developer instructions に含まれています。（姉妹プロジェクトの [my-claude](https://github.com/sehoon787/my-claude) では Stop フックがさらにこれを強制しますが、Codex CLI には同等の強制ポイントがないため、ここではプロンプトレベルの仕様です。）

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────┐
│                    User Request                       │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Boss · Meta-Orchestrator (gpt-6-astra xhigh)              │
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

## 含まれるもの

| カテゴリ | 数 | ソース |
|----------|------:|--------|
| **コアエージェント**（常時ロード） | 17 | Boss 1 + OMO 9 + OMX 7 |
| **エージェントパック**（オプトイン、デフォルトでは無効） | 17 | ベンダリング済み 2 カテゴリ: data-ai 13 + llmops 4 |
| **スキル** | 123 | ECC 79 · gstack 27 · Superpowers 13 · Core 4 |
| **MCP サーバー** | 3 | Context7、Exa、grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>コアエージェント — Boss メタオーケストレーター (1)</strong></summary>

| エージェント | モデル | 役割 | ソース |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | ダイナミックランタイム検出 → ケイパビリティマッチング → 最適ルーティング。コードは書かない。 | my-codex |

</details>

<details>
<summary><strong>OMO エージェント — サブオーケストレーターとスペシャリスト (9)</strong></summary>

| エージェント | モデル | 役割 | ソース |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | インテント分類 → スペシャリスト委任 → 検証 | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | gpt-6-astra high | 自律的な調査 → 計画 → 実行 → 検証 | oh-my-openagent |
| Atlas | gpt-6-astra high | タスク分解 + 4 ステージ QA 検証 | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | 戦略的技術コンサルティング（読み取り専用） | oh-my-openagent |
| Metis | gpt-6-astra high | インテント分析、曖昧さ検出 | oh-my-openagent |
| Momus | gpt-6-astra high | 計画実現可能性レビュー | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | インタビューベースの詳細計画立案 | oh-my-openagent |
| Librarian | gpt-5.6-terra medium | MCP 経由のオープンソースドキュメント検索 | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-terra medium | 画像・スクリーンショット・図の分析 | oh-my-openagent |

</details>

<details>
<summary><strong>OMX エージェント — スペシャリストワーカー (7)</strong></summary>

[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) の `prompts/*.md` を Codex TOML に変換したものです。`templates/codex-AGENTS.md` が案内するレーンのみを変換し、許可リストは `scripts/skill-allowlists.sh` にあります。

| エージェント | サンドボックス | 役割 | ソース |
|-------|---------|------|--------|
| executor | workspace-write | コード実装 | oh-my-codex |
| planner | workspace-write | 実装計画 | oh-my-codex |
| architect | read-only | システム設計とアーキテクチャ | oh-my-codex |
| test-engineer | workspace-write | テスト戦略とカバレッジ | oh-my-codex |
| security-reviewer | read-only | セキュリティ分析 | oh-my-codex |
| code-reviewer | read-only | 集中的なコードレビュー | oh-my-codex |
| debugger | workspace-write | 根本原因分析 | oh-my-codex |

</details>

<details>
<summary><strong>エージェントパック — オプトインの AI スペシャリスト (2 パック、17 エージェント)</strong></summary>

[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)（MIT）から `codex-agents/packs/` にベンダリングし、`~/.codex/agent-packs/` にインストールされます。**デフォルトで有効になるパックはありません** — 明示的にオプトインしてください:

```bash
# 現在の状態を確認
~/.codex/bin/my-codex-packs status

# パックを即時有効化
~/.codex/bin/my-codex-packs enable data-ai

# インストール時にプロファイルを切り替え
bash /tmp/my-codex/install.sh --profile minimal   # パックなし
bash /tmp/my-codex/install.sh --profile dev       # data-ai + llmops
bash /tmp/my-codex/install.sh --profile full      # インストール済みの全パック
```

| パック | 数 | エージェント |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

</details>

<details>
<summary><strong>スキル — 4 つのソースから 123</strong></summary>

スキル単位の許可リストは `scripts/skill-allowlists.sh` にあり、何がインストールされるかはこのファイルが基準です。

| ソース | 数 | 主なスキル |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 79 | coding-standards, python-testing, api-design, deep-research |
| [gstack](https://github.com/garrytan/gstack) | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 13 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |

gstack は許可リストのスキル 26 個にリポジトリルートのエントリを加えて 27 として集計されます。gstack リポジトリ全体は `~/.codex/skills/gstack` に正規のランタイムツリーとしても配置されます。

Codex には**ドキュメントスキルがありません** — このバンドルに `pdf`、`docx`、`pptx`、`xlsx` スキルは含まれません。

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
├── persona/
│   ├── profile.md                   ← Agent affinity stats (auto-updated)
│   ├── suggestions.jsonl            ← Routing suggestions (auto-generated)
│   ├── rules/                       ← Accepted routing preferences
│   └── skills/                      ← Accepted persona skills
├── archives/                         ← 完了/非アクティブノート (30日以上)
│   ├── sessions/
│   ├── decisions/
│   └── learnings/
└── wiki/                             ← コンセプトページ (自動提案)
    └── _schema.md
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
| **archives/** | — | 30 日以上経過した完了/非アクティブノートのアーカイブを自動提案。PARA アーカイブコンセプト。 |
| **wiki/** | — | コンセプト wiki ページ。キーワードが 3 回以上登場した場合に自動提案。LLM-wiki コンセプト。 |

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

### ナレッジマネジメント (v2)

BriefingVault v2 は 3 つの知識管理手法を統合しています：

| 手法 | コンセプト | BriefingVault での適用 |
|------|-----------|----------------------|
| **PARA**（Tiago Forte） | 実行可能性で分類：プロジェクト、エリア、リソース、アーカイブ | sessions/ = プロジェクト、decisions/ = エリア、references/ = リソース、archives/ = アーカイブ |
| **Zettelkasten**（Luhmann） | 一意の ID と明示的なリンクを持つ原子的ノート | learnings/ ファイル：`YYYYMMDDHHMMSS` ID、`related:` に 2 件以上のリンク必須 |
| **LLM-wiki**（Karpathy） | ソースノートから AI が管理するコンセプトページ | wiki/ ページ：キーワードが 3 回以上繰り返されると自動提案 |

---

## アップストリームのオープンソースソース

my-codex は **4 つのアップストリームサブモジュール**に加え、ベンダリング済みスナップショット 1 件と、適応済み/姉妹プロジェクト 2 件で構成されています、companion CLI 1 件で構成されます:

| # | ソース | 方式 | 提供内容 |
|---|--------|------|-----------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | サブモジュール | 開発ワークフロー全般にわたる許可リストのスキル 79 個。Claude Code 固有のコンテンツを除去し、汎用コーディングスキルを保持。 |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | サブモジュール | コードレビュー、QA、セキュリティ監査、デプロイメント向けの 27 スキル。Playwright ブラウザデーモンを含む。 |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | サブモジュール | 許可リストのワーカーエージェント 7 個（executor、planner、architect、test-engineer、security-reviewer、code-reviewer、debugger）。Markdown プロンプトから Codex TOML に変換。 |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | サブモジュール | ブレインストーミング、TDD、系統的デバッグ、計画作成をカバーする 13 スキル。インストールされるエージェントはありません。 |
| 5 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | ベンダリング (MIT) | AI/LLM エージェント 17 個を `codex-agents/packs/` にスナップショットし、オプトインパック 2 個（data-ai 13、llmops 4）として提供。サブモジュールは 2026-07-27 に削除。 |
| 6 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 適応 | 9 つの OMO エージェント（Sisyphus、Atlas、Oracle など）。Codex ネイティブ TOML フォーマットに適応し、本リポジトリで維持。 |
| 7 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 姉妹プロジェクト | ネイティブ Claude `.md` エージェントフォーマットで同じ Boss オーケストレーションを実現。スキル、ルール、Briefing Vault を両プロジェクトで共有。 |
| 8 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | npm CLI (MIT) | ローカルファーストのトークン/コストトラッカー。`~/.codex/sessions` を読み取り専用で解析 — プロキシ・アップロード不要。`install.sh` がインストール（`codeburn@0.9.23` に固定）、`upstream/SOURCES.json` に `method: npm-cli` として登録。Codex にはフックなし。 |

すべてのサブモジュールは `upstream/SOURCES.json`（AI-BOM）（companion CLI（ast-grep、codeburn）も同じファイルにバージョン固定で登録されています）で SHA 固定されており、削除された 2 つのサブモジュール（`agency-agents` — ベンダリングなし、`awesome-codex-subagents` — エージェント 17 個をベンダリング）も記録されています。

---

## GitHub Actions

| ワークフロー | トリガー | 目的 |
|----------|---------|---------|
| **CI** | push、PR | TOML エージェントファイル、スキルの存在、アップストリームファイル数を検証 |
| **Smoke Tests** | push, PR | `hooks`、`shell`、`drift`、`routing-refs` ジョブ — フック配線、シェル構文、モデルドリフト、AGENTS.md のルーティング参照を検証 |
| **Update Upstream** | 3 日ごと / 手動 | セキュリティゲート付きの `git submodule update --remote`、`upstream/SOURCES.json` のピン更新、自動マージ PR を作成 |
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
| **エージェント層優先度** | core > omo > omx > オプトインパックの順で重複排除。既存エージェントと名前が衝突するパックエージェントはスキップ。最も特化したエージェントが優先。 |
| **コスト最適化** | アドバイザリーには gpt-5.6-luna、実装には gpt-6-astra — インストール済み 34 エージェント全体への自動モデルルーティング |
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

パックはインストールされますが、**デフォルトでは無効**です。新規インストールは有効なパックのない空のセットを `~/.codex/enabled-agent-packs.txt` に記録します。パック単位でオプトインするか、プロファイルを選んでください:

```bash
# パックを 1 つ即時有効化
~/.codex/bin/my-codex-packs enable data-ai

# Minimal プロファイル（コアエージェントのみ、パックなし — デフォルト）
bash /tmp/my-codex/install.sh --profile minimal

# dev プロファイル（data-ai + llmops）
bash /tmp/my-codex/install.sh --profile dev

# Full プロファイル（インストール済みの 2 パックカテゴリをすべて有効化）
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
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | サブモジュール (`upstream/ecc`) |
| [gstack](https://github.com/garrytan/gstack) | サブモジュール (`upstream/gstack`) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | サブモジュール (`upstream/omx`) |
| [superpowers](https://github.com/obra/superpowers) | サブモジュール (`upstream/superpowers`) |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | ベンダリング済みスナップショット（サブモジュールは 2026-07-27 に削除） |

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

エージェントパックは `~/.codex/agent-packs/` にインストールされるドメイン固有のエージェントコレクションです。現在は `data-ai`（13）と `llmops`（4）の 2 パックがあり、**インストール時に有効化されるパックはありません**。`my-codex-packs enable <pack>` で有効化するか、`--profile full` で再インストールして両カテゴリを有効化できます。

</details>

<details>
<summary><strong>アップストリーム同期はどのように機能しますか？</strong></summary>

GitHub Actions ワークフローが 3 日ごとに実行され、4 つのアップストリームサブモジュールから最新のコミットを取得し、`upstream/SOURCES.json` の SHA ピンを更新したうえで、セキュリティゲート付きの自動マージ PR を作成します。Actions タブから手動でトリガーすることもできます。

</details>

<details>
<summary><strong>my-codex が使用するモデルは何ですか？</strong></summary>

Boss とサブオーケストレーター（Sisyphus、Atlas、Oracle）は高い推論努力で gpt-6-astra を使用します。標準ワーカーは中程度の推論で gpt-5.6-terra を使用します。軽量アドバイザリーエージェントは gpt-5.6-luna を使用します。

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

以下の成果物の上に構築されています: [my-claude](https://github.com/sehoon787/my-claude) (sehoon787)、[everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m)、[gstack](https://github.com/garrytan/gstack) (garrytan)、[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo)、[superpowers](https://github.com/obra/superpowers) (Jesse Vincent)、[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent)、[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu)、[openai/skills](https://github.com/openai/skills) (OpenAI)。

## ライセンス

MIT ライセンス。詳細は [LICENSE](./LICENSE) ファイルをご参照ください。
