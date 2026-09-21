[英語](../../README.md) | [韓国語](./README.ko.md) | [日本語](./README.ja.md) | [中国語](./README.zh.md) | [ドイツ語](./README.de.md) | [フランス語](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code をお探しの方は → **my-claude** — ネイティブ Claude `.md` エージェントフォーマットで同じ Boss オーケストレーションを提供

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-30_default_%2F_107_installed-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**Codex CLI 向けオールインワン・エージェントハーネス。**
**一度インストールするだけで、コアエージェント 17 体がすぐに使えます。**

Boss はランタイムですべてのエージェント・スキル・MCP ツールを検出し、<br>
`spawn_agent` を通じて適切なスペシャリストにタスクをルーティングします。設定もボイラープレートも不要です。

<img src="../../assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## インストール

### 人間向け

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

先にクローンしてから、そのチェックアウトでインストーラーを実行することもできます:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

既定のインストールが公開するスキルを絞っているのは意図的です。Codex はスキル
予算を超えるとスキルの説明を切り詰めるため、既定の `core` プロファイルは
インストール済みの 107 スキルのうち 30 だけを Codex に見せ、残りはフラグ 1 つで
開けるようにしています:

```bash
bash install.sh --skills=web          # Web/UI レーンの 18 スキルを追加
bash install.sh --full-skills         # すべての任意レーンと full 公開プロファイル
bash install.sh --skill-profile=core  # 既定の公開範囲に戻す
```

選択内容は保存され、後から素の `bash install.sh` を実行しても維持されます。すべてのプロファイル・レーンと `my-codex-skills` コマンドは[スキルプロファイルとレーン](#スキルプロファイルとレーン)を参照してください。

対話型ターミナルでは 3 つの companion ツール — Serena、Headroom、codeburn — のチェックボックス選択が表示され、既定ではすべて選択されています。↑/↓ または `j`/`k` で移動し、Space で切り替え、`a` ですべて、`n` で解除、Enter または Ctrl-D/EOF で現在の選択を確定します。`TERM` が空または `dumb` の場合、あるいは `stty` が使えない場合は番号方式にフォールバックし、Enter・`all`・`a`・`y`・`yes` ですべて、`none`・`n`・`no`・`0` でなし、`1,3` や `serena codeburn` のように番号と名前を混在させられます。自動実行では既定ですべて選択されます:

```bash
bash install.sh --tools=headroom   # 一部だけ明示
bash install.sh --yes              # 3 つすべてをプロンプトなしで
bash install.sh --skip-tools       # インストールしない
```

Windows では、`install.sh` が npm 管理の `codex`、`codex.cmd`、`codex.ps1` シムが存在する場合にパッチを当てるため、`%APPDATA%\npm` が `~/.codex/bin` より先に解決されても my-codex のボールトパイプラインにラッパーのフォールバックが残ります。

### AI エージェント向け

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

---

## 使用しているオープンソースツール

my-codex が基盤とするすべてのプロジェクトと、その貢献内容、そして導入方法です。各プロジェクトを説明するのはこの表だけで、README の他の部分は一覧・コマンド・ピンのみを扱います。

| # | プロジェクト | my-codex が取り入れているもの | 導入方法 |
|---|--------------|-------------------------------|----------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 許可済みスキル 61 個: スタック別パターン（TypeScript、React、Python/Django/FastAPI、Spring Boot/Kotlin、SQL/Redis/Prisma、Docker/Kubernetes）、AI・エージェント開発、オンボーディングやコードツアー、ADR といった汎用のコードベース支援です。Claude Code 固有の内容は取り除かれ、Web/UI 向けの 18 スキルのレーンは既定のインストールから外れています。 | サブモジュール `upstream/ecc`。`install.sh` は `scripts/skill-allowlists.sh` で許可された名前だけをコピーします |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | スプリント運用スキル 27 個 — ブラウザ QA（`qa`）、スコープ逸脱を見るコードレビュー（`review`）、セキュリティ監査（`cso`）、計画 → レビュー → 出荷の一連の流れ — と、コンパイル済みの Playwright ブラウザデーモンです。 | サブモジュール `upstream/gstack`。`~/.codex/vendor/gstack` に配置し、そこで gstack 自身の `./setup --host codex` を bun 上で実行します。置き換え対象の ECC スキル 7 個（`benchmark`、`canary-watch`、`safety-guard`、`browser-qa`、`verification-loop`、`security-review`、`design-system`）は削除され、gstack 版だけがルーティング対象として残ります |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 許可済みのワーカーエージェント 7 体: `executor`、`planner`、`architect`、`test-engineer`、`security-reviewer`、`code-reviewer`、`debugger`。残りのプロンプトとスキルは本リポジトリが既に備えるエージェントと重複するため、意図的にインストールしません。 | サブモジュール `upstream/omx`。`scripts/md-to-toml.sh` が許可済みプロンプトを Markdown から `~/.codex/agents/*.toml` へ変換します |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 開発プロセススキル 14 個: ブレインストーミング、体系的なデバッグ、テスト駆動開発、計画の作成と実行、worktree の扱い、コードレビューの作法です。エージェントは取り込みません — 唯一の `code-reviewer` プロンプトが oh-my-codex のものと重なるためです。 | サブモジュール `upstream/superpowers`。スキルディレクトリ 15 個のうち、Boss の委譲経路と重複する `dispatching-parallel-agents` を除いてすべてインストールします |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | アーキテクチャ、ワークフロー、シーケンス、データフロー、ライフサイクルの記述を、インライン SVG・ダーク/ライト切り替え・PNG/JPEG/WebP/SVG エクスポートを備えた単一の自己完結型 HTML ファイルに変換する図版スキル 1 個です。 | サブモジュール `upstream/archify`、タグ `v2.9.0` にピン留めしてあるため同期ジョブは対象外とします。リポジトリ直下の `archify/` ディレクトリだけを `~/.codex/skills/archify` にコピーするので、インストール時に `npx skills add` は実行されません |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | Codex ネイティブ TOML エージェント 17 体を、オプトインの 2 パック `data-ai`（13）と `llmops`（4）として同梱しています。新規インストールではどちらのパックも有効になりません。 | `codex-agents/packs/` にベンダリング（MIT）し、`~/.codex/agent-packs/` にインストールします。サブモジュールは 2026-07-27 に削除。`~/.codex/bin/my-codex-packs enable data-ai` か `install.sh --profile dev` で有効化します |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | エージェント 9 体 — `sisyphus`、`atlas`、`prometheus`、`oracle`、`metis`、`momus`、`hephaestus`、`librarian`、`multimodal-looker` — がエンドツーエンドのオーケストレーション、計画の実行とレビュー、踏み込んだセカンドオピニオン、出典付きのライブラリ調査、メディアファイルの読み取りをカバーします。 | Codex ネイティブ TOML に適応させ、`codex-agents/omo/` としてリポジトリ内で保守しているため、アップストリームのチェックアウトなしでインストールされます |
| 8 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | なし。これらのパックのエージェントは本リポジトリで一度も使われなかったため、ベンダリングされたものはありません。 | 削除済み（MIT） — サブモジュールは 2026-07-27 に外され、記録は `upstream/SOURCES.json` に残っています |
| 9 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | ネイティブ Claude `.md` エージェントフォーマットによる同じ Boss オーケストレーションであり、編集上の基準でもあります。`scripts/skill-allowlists.sh` は my-claude の ECC・gstack・superpowers のリストをそのまま写しており、両ハーネスが同じアップストリーム面を提供します。 | 姉妹プロジェクトとしてのリンクのみで、`install.sh` はクローンも取得もコピーも行わないため、ベンダリングも追跡すべきピンもありません。並べてインストールした場合、2 つのインストーラーは固定ポートを奪い合うのではなく、ユーザー単位の 1 つのロックと状態ディレクトリを通じて codeburn と Headroom を調停します |
| 10 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | Codex が `~/.codex/sessions` に元から書き出すセッションファイルを読み取るローカル完結のトークン・コスト集計で、プロキシも API キーも Codex フックも使いません。 | `npm i -g codeburn@0.9.23`。`install.sh` が共有プロセス `codeburn web --provider all --port 4747 --no-open` を 1 つ起動または再利用します |
| 11 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | 生テキストではなく構文木に対してマッチする構造的な検索・書き換えで、壊れやすい正規表現なしにエージェントがコードの形を変更できます。 | `npm i -g @ast-grep/cli@0.42.0`。`PATH` 上に `ast-grep` バイナリが既にある場合はスキップします |
| 12 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | MCP 経由の言語サーバーのシンボルグラフ — `get_symbols_overview`、`find_symbol`、`find_referencing_symbols`、`replace_symbol_body`、`insert_after_symbol` — により、ファイル全体ではなくシンボル単位でトークンを消費します。配布パッケージは全体として GPL-3.0-or-later であり（PyPI の MIT 表記は不正確）、コードはベンダリングしません。 | `uv tool install --python 3.13 serena-agent==1.7.0`。`[mcp_servers.serena]` として stdio 登録（`serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False`、`startup_timeout_sec = 15`） |
| 13 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | Apache-2.0 の MCP コンテキスト圧縮: `headroom_compress`、`headroom_retrieve`、`headroom_stats`。プロキシモード `headroom wrap` は文書化された手動オプトインのままです。 | `uv tool install --python 3.13 "headroom-ai[all]==0.37.0"`。サーバーが MCP アノテーションを公開しないため `default_tools_approval_mode = "approve"` を付けて `[mcp_servers.headroom]`（`headroom mcp serve`）として登録し、インストーラーは共有プロファイル `agent-harness-shared` をポート 8787 で起動または再利用し、`ANTHROPIC_BASE_URL` も `OPENAI_BASE_URL` も設定しません |
| 14 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | ライブラリ、フレームワーク、SDK に関する問いにモデルの記憶ではなく最新のアップストリーム文書から答えます。スキル `documentation-lookup` が参照するバックエンドです。 | ホスト型 MCP サーバー `https://mcp.context7.com/mcp` |
| 15 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | ニューラル Web 検索です。登録 URL が `web_search_exa` だけを有効にし、Exa の全機能ではなく単一ツールに調査経路を絞ります。 | ホスト型 MCP サーバー `https://mcp.exa.ai/mcp?tools=web_search_exa` |
| 16 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | 公開 GitHub リポジトリを横断するコード検索で、エージェントがコードを書く前に多数のリポジトリにある実際の呼び出し箇所を確認できます。 | ホスト型 MCP サーバー `https://mcp.grep.app` |

---

## Boss の仕組み

Boss は my-codex の中核にあるメタオーケストレーターです。コードを書くことはなく、検出・分類・マッチング・委任・検証を行います。メイン Codex セッションがインストール済みの `AGENTS.md` を通じて Boss の役割を担うため、別の Boss を立てずに直接スペシャリストへ委任します。ネイティブのセッション識別は Codex/root のままで、再インストールは管理下の指示を更新しつつユーザーが手を入れた箇所を保持します。

| フェーズ | 動作 |
|-------|--------------|
| **0 · 検出** | ランタイムで `~/.codex/agents/*.toml` をスキャンし、ライブの能力レジストリを構築 |
| **1 · インテントゲート** | リクエストを分類（trivial、build、refactor、mid-sized、architecture、research、…）し、より適したスキルがあれば逆提案 |
| **2 · 能力マッチング** | 下記の優先チェーンを順に適用（P1 スキル完全一致 → P2 スペシャリストエージェント → P3 マルチエージェント編成 → P4 汎用フォールバック） |
| **3 · 委任** | 6 セクションの構造化プロンプトとともに `spawn_agent` を呼び出す: TASK / OUTCOME / TOOLS / DO / DON'T / CTX |
| **4 · 検証** | 変更されたファイルを独立して読み、テスト・lint・ビルドを実行し、元の意図と突き合わせ、失敗時は最大 3 回まで再試行 |

### 優先ルーティング

Boss は最適なマッチが見つかるまで、すべてのリクエストを優先チェーンで処理します:

| 優先度 | マッチ種別 | 条件 | 例 |
|:--------:|-----------|------|---------|
| **P1** | スキルマッチ | タスクが自己完結したスキルに対応 | `"review this diff"` → /review スキル |
| **P2** | スペシャリストエージェント | ドメイン固有のエージェントが存在 | `"security audit"` → security-reviewer |
| **P3a** | Boss 直接 | 独立したエージェント 2〜4 体 | `"fix 3 bugs"` → 並列スポーン |
| **P3b** | サブオーケストレーター | 複雑な多段ワークフロー | `"refactor + test"` → Sisyphus |
| **P4** | フォールバック | 該当するスペシャリストなし | `"explain this"` → 汎用エージェント |

### モデルルーティング

| 複雑度 | モデル | 対象 |
|-----------|-------|----------|
| 最上位のオーケストレーション | `gpt-6-astra` | Boss |
| 深い分析、アーキテクチャ、レビュー | `gpt-6-astra` | Oracle、Prometheus、Sisyphus、Hephaestus、Atlas、Metis、Momus、architect、planner、code-reviewer、security-reviewer |
| 標準的な実装 | `gpt-5.6-sol` | Librarian、Multimodal-Looker、executor、test-engineer、debugger、およびパックエージェント 17 体のうち 15 体 |
| 簡単な検索、軽い分析 | `gpt-5.6-terra` | data-analyst、prompt-regression-tester |

3 つのティア ID は単一ファイル `scripts/model-tiers.sh` にあります。`scripts/md-to-toml.sh` と `install.sh` の両方がこれを読み込み、スクリプトの他の場所にモデル ID がハードコードされると `scripts/check-model-drift.sh` がビルドを失敗させます。

### 推論強度ティア

モデル選択が*どの*頭脳でタスクを走らせるかを決めるのに対し、同じ TOML の `model` の隣にある `model_reasoning_effort` は*どれだけ深く*考えるかを決めます。Boss と OMO エージェント 9 体は `codex-agents/` 配下のコミット済みファイルで宣言し、oh-my-codex のワーカー 7 体は変換時に `scripts/md-to-toml.sh` のロール表から値を受け取り、パックエージェントはそれぞれ自前の値を持ちます:

| 推論強度 | エージェント |
|--------|--------|
| `xhigh` | Boss、Oracle、Prometheus、architect |
| `high` | Sisyphus、Hephaestus、Atlas、Metis、Momus、planner、code-reviewer、security-reviewer、およびパックエージェント 17 体のうち 15 体 |
| `medium` | Librarian、Multimodal-Looker、executor、test-engineer、debugger、data-analyst、prompt-regression-tester |

### 3 フェーズスプリントワークフロー

エンドツーエンドの機能実装では、Boss が構造化されたスプリントを編成します:

| フェーズ | モード | 動作 |
|-------|------|--------------|
| **1 · 設計** | 対話型 | ユーザーが範囲を決定 · エンジニアリングレビュー · 「設計完了」を確認 |
| **2 · 実行** | 自律 | executor がタスクを実行 · 自動コードレビュー · architect による検証 |
| **3 · レビュー** | 対話型 | 設計ドキュメントと比較 · 比較表を提示 · ユーザーが承認または改善を要求 |

### 構造化された最終レポート

Boss は作業のあったすべてのターン — ファイル編集、コミット/PR、設定変更、検証の実行があったターン — を、diff を開かずに読める構造化された最終レポートで締めくくります。レポートは固定の 5 つの表で構成され、各表はその状況が実際に起きたときだけ出力されます（空の表は作りません）:

| 状況 | 表 | 列 |
|-----------|-------|---------|
| ファイル/設定の変更 | Changes | 対象 / Before / After / 根拠 |
| 複数タスクの完了 | Work summary | 項目 / 結果 / 根拠 |
| 検証を実行 | Verification | 項目 / 期待 / 実際 / 判定 |
| コミット/PR を作成 | Deliverables | PR / リポジトリ / 内容 / 状態 |
| 未解決事項あり | Remaining | 項目 / 状態 / 次の対応 |

このレポートはリクエストの最後にだけ発火し — バックグラウンド処理を起動・中継するターンや作業途中の進捗報告では決して出力されず — 純粋な質疑応答のターンはレポートなしで正常に終了します。仕様は `boss.toml` の developer instructions と `~/.codex/AGENTS.md` の両方にあるため、メインセッションからも参照できます。Stop フック（`hooks/stop-final-report.js`）がこれを強制し、状態を変えたターンがレポート表なしで終わった場合、そのターンを 1 度だけブロックしてレポートを求めます。

---

## 含まれるもの

| カテゴリ | 数量 | 出典 |
|----------|------:|--------|
| **コアエージェント**（常時ロード） | 17 | Boss 1 + OMO 9 + OMX 7 |
| **エージェントパック**（オプトイン、既定では無効） | 17 | ベンダリング済みの 2 カテゴリ: data-ai 13 + llmops 4 |
| **公開スキル**（既定の `core` プロファイル） | 30 | 常時有効な集合。それ以外はレーンのフラグ 1 つで追加 |
| **インストール済みスキル**（ディスク上のファイル） | 107 | ECC 61 · gstack 27 · Superpowers 14 · Core 4 · archify 1 |
| **MCP サーバー** | 5 | Context7、Exa、grep.app、Serena、Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

上記のエージェントとスキルはすべて [`scripts/skill-allowlists.sh`](../../scripts/skill-allowlists.sh) の許可リストに載っており、このファイルが何を同梱するかの基準です。このバンドル自体は `pdf`、`docx`、`pptx`、`xlsx` を同梱せず、外部でインストールされた同種のスキルはそのまま保持します。

<details>
<summary><strong>コアエージェント — Boss メタオーケストレーター (1)</strong></summary>

| エージェント | モデル | 役割 | 出典 |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | 動的なランタイム検出 → 能力マッチング → 最適ルーティング。コードは書きません。 | my-codex |

</details>

<details>
<summary><strong>OMO エージェント — サブオーケストレーターとスペシャリスト (9)</strong></summary>

| エージェント | モデル | 役割 | 出典 |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | 意図分類 → スペシャリスト委任 → 検証 | oh-my-openagent |
| Hephaestus | gpt-6-astra high | 自律的な探索 → 計画 → 実行 → 検証 | oh-my-openagent |
| Atlas | gpt-6-astra high | タスク分解 + 4 段階 QA 検証 | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | 戦略的な技術コンサルティング（読み取り専用） | oh-my-openagent |
| Metis | gpt-6-astra high | 意図分析、曖昧性の検出 | oh-my-openagent |
| Momus | gpt-6-astra high | 計画の実現可能性レビュー | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | インタビュー形式の詳細計画 | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | MCP 経由のオープンソース文書検索 | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | 画像/スクリーンショット/図の分析 | oh-my-openagent |

</details>

<details>
<summary><strong>OMX エージェント — スペシャリストワーカー (7)</strong></summary>

| エージェント | サンドボックス | 役割 | 出典 |
|-------|---------|------|--------|
| executor | workspace-write | コード実装 | oh-my-codex |
| planner | read-only | 実装計画 | oh-my-codex |
| architect | read-only | システム設計とアーキテクチャ | oh-my-codex |
| test-engineer | workspace-write | テスト戦略とカバレッジ | oh-my-codex |
| security-reviewer | read-only | セキュリティ分析 | oh-my-codex |
| code-reviewer | read-only | 集中的なコードレビュー | oh-my-codex |
| debugger | workspace-write | 根本原因分析 | oh-my-codex |

</details>

<details>
<summary><strong>エージェントパック — オプトインの AI スペシャリスト (2 パック、17 体)</strong></summary>

| パック | 数量 | エージェント |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

`~/.codex/agent-packs/` にインストールされ、オプトインするまで無効のままです — [エージェントパックプロファイル](#エージェントパックプロファイル)を参照してください。

</details>

<details>
<summary><strong>スキル — 既定で 30 公開、5 つの出典から 107 をインストール</strong></summary>

| 出典 | インストール | 主なスキル |
|--------|------:|------------|
| everything-claude-code | 61 | coding-standards, python-testing, api-design, deep-research |
| gstack | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| superpowers | 14 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| archify | 1 | archify（アーキテクチャ・ワークフロー・シーケンス・データフロー・ライフサイクル図） |

gstack は許可済みスキル 26 個にリポジトリルートのエントリを加えて 27 と数えます。フルチェックアウトは `~/.codex/vendor/gstack` にあり、`~/.codex/skills/gstack` はランタイムのファサードです。どのプロファイルでも実際のスキルファイルはインストールされたままで、変わるのは公開範囲だけです。[スキルプロファイルとレーン](#スキルプロファイルとレーン)を参照してください。

</details>

<details>
<summary><strong>ホスト型 MCP サーバー (5 のうち 3)</strong></summary>

残りの 2 つは Serena と Headroom で、どちらもローカルの stdio サーバーです。

| サーバー | 目的 | コスト |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | リアルタイムのライブラリ文書 | 無料 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | セマンティック Web 検索 | 月 1,000 件まで無料 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | GitHub コード検索 | 無料 |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian 互換の永続メモリです。各プロジェクトは、ネイティブのプラグインフックによって Codex セッション中に更新される `.briefing/` ディレクトリを保持し、セッション開始・終了の連続性はラッパーのフォールバックが補います:

```
.briefing/
├── INDEX.md                          ← プロジェクトコンテキスト（初回に自動生成）
├── state.json                        ← セッションメタデータ、カウンター、lastVaultSync（自動管理）
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← 人間/エージェントが書くフォローアップのセッション要約
│   └── YYYY-MM-DD-auto.md           ← 自動生成スキャフォールド（記録ファイル、フィルタ済みステータス、フォローアップ）
├── decisions/
│   └── YYYY-MM-DD-<decision>.md     ← 人間/エージェントが書く意思決定記録
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← 人間/エージェントが書く学びのノート
│   └── YYYY-MM-DD-auto-session.md   ← 自動生成スキャフォールド（ファイル、ラッパー活動、プロンプト）
├── references/
│   └── auto-links.md                ← 収集した調査リンク用
├── archives/                         ← PARA: 完了/非アクティブなノート（フラット）
├── wiki/                             ← LLM-wiki: 概念ページ
│   └── _schema.md
├── agents/
│   ├── agent-log.jsonl              ← ラッパー/セッションログ
│   └── YYYY-MM-DD-summary.md        ← 日次の記録シグナル集計
└── persona/
    ├── profile.md                   ← 記録シグナルから導いたルーティング/プロファイル要約
    ├── suggestions.jsonl            ← ルーティング提案（自動生成）
    ├── persona-policy.json          ← Boss 向けに受け入れたソフトなルーティング設定
    └── rules/                       ← ワークフローパターン規則（workflow-*.md）
```

### ナレッジマネジメント (v2)

BriefingVault v2 は 3 つのナレッジマネジメント手法を統合しています:

| 手法 | 適用方法 |
|------------|-----------|
| **PARA**（Tiago Forte） | ディレクトリ構成: sessions=プロジェクト、decisions=エリア、references=リソース、archives=アーカイブ |
| **Zettelkasten**（Luhmann） | `learnings/` のアトミックノート、一意 ID（`YYYYMMDDHHMMSS`）、`[[wiki-links]]` 必須 |
| **LLM-wiki**（Karpathy） | `wiki/` の概念ページ — キーワードが 3 回以上現れると自動提案 |

Codex CLI のセッション終了フックは自動的に次を行います:

- 30 日以上前のノートのアーカイブを提案
- 頻出する概念の wiki ページを提案
- 新しいノート用に一意の Zettelkasten ID を生成

### セッション固有の差分

セッション開始時、my-codex は現在の git HEAD とワークツリー状態のスナップショットを保存します。セッション中はネイティブの Codex フックが、プロンプト・編集・検索・サブエージェント完了のたびに `.briefing` のスキャフォールドを更新します。セッション終了時、最終スキャフォールドは記録されたパスについてのみ差分と状態を要約し、`.briefing/` の成果物やセッション開始時の `.gitignore` 編集といったフック由来のノイズを除外します。

これによりスキャフォールドはリポジトリ全体の状態を垂れ流さず、そのセッションが行った作業に集中します。git でないプロジェクトでは `YYYY-MM-DD:cwd` 識別子をフォールバックとして使います。

### Obsidian との使い方

1. Obsidian を開く → **フォルダーをボールトとして開く** → `.briefing/` を選択
2. ノートがグラフビューに `[[wiki-links]]` でつながって表示されます
3. YAML フロントマター（`date`、`type`、`tags`）で構造化検索ができます
4. セッションと学びのタイムラインスキャフォールドは自動的に積み上がり、フォローアップの要約・意思決定・学びのノートは書いた分だけ蓄積されます

### /boss-briefing

セッション中または最後に `/boss-briefing` を実行すると次を行います:

- **ボールト同期**: profile.md、INDEX.md、エージェント集計を更新
- **ワークフローパターン検出**: セッションをまたいだ時系列のエージェント呼び出し列を分析
- **空白期間の復旧**: 前回セッションから日数が経っていれば復旧用の要約を生成
- **ペルソナ規則の提案**: 頻度だけでなくワークフローに基づくルーティング設定を提案
- **セッションノートの検証**: 今日のセッションに適切な要約があるか確認

Stop フックは今日 `/boss-briefing` が実行されたかを確認します。実行されていなければ、リマインダーとともにセッション終了をブロックします。既存の `stop-profile-update.js` はフォールバックとして動作し続けます。

### サブボールト

| パス | 説明 |
|------|-------------|
| `INDEX.md` | 最近の意思決定と学びへのリンクを持つプロジェクト概要。初回セッションで自動生成され、定期的に更新されます。 |
| `sessions/` | **セッション要約。** `*-auto.md` — セッション中に更新され、終了時に記録済みセッションファイル・フィルタ済みステータス・記録シグナルで仕上げられる自動スキャフォールド。`<topic>.md` — ボールトのリマインダーが促す人間/エージェント作成のフォローアップ要約。 |
| `decisions/` | **アーキテクチャと設計の意思決定**とその根拠。残す価値のある決定は永続的なノートとして書いてください。 |
| `learnings/` | **パターン、落とし穴、自明でない解法。** `*-auto-session.md` — そのセッションの記録ファイル一覧・シグナル・フォローアップ用プロンプトでセッション中に更新される自動スキャフォールド。`<topic>.md` — 人間/エージェント作成の学びのノート。 |
| `references/` | **Web 調査の URL。** ネイティブの Codex フックが利用できる場合、`references/auto-links.md` が `WebSearch`/`WebFetch` のフック活動から更新されます。 |
| `agents/` | **記録されたセッションシグナル。** `agent-log.jsonl` — `{ts, agent_id, agent_type, phase, seq, task_hint}` のエントリ。`YYYY-MM-DD-summary.md` — そのログから導いた日次集計。 |
| `persona/` | **ユーザーの作業スタイルプロファイル。** `profile.md` — 記録シグナルから導いたルーティング/プロファイル要約。`suggestions.jsonl` — ルーティング提案。`persona-policy.json` — 受け入れたソフトなルーティング設定。`rules/workflow-*.md` — `/boss-briefing` が提案したワークフロー列の規則。 |
| `state.json` | セッションメタデータ: カウンター、lastVaultSync、sessionStartHead。フックが自動管理します。 |
| `archives/` | PARA アーカイブ — 完了したセッション（30 日以上）、置き換えられた意思決定、非アクティブな学び |
| `wiki/` | LLM-wiki 概念ページ — 複数セッションから蒸留された知識 |

### 動作フック

| フック | イベント | 動作 |
|------|-------|----------|
| Session Setup | SessionStart | ツールの自動検出 + Briefing Vault コンテキストの注入 |
| Delegation Guard | PreToolUse | Boss モードのセッションに、ファイル編集を自分で行わず委任するよう促す |
| Agent Telemetry | PostToolUse | エージェント利用を `~/.gstack/analytics/agent-usage.jsonl` に記録 |
| Vault Enforcer | PostToolUse | 編集回数を数え、セッション中に自動スキャフォールドを更新 |
| Link Collector | PostToolUse | `WebSearch`/`WebFetch` の結果を `references/auto-links.md` に追記 |
| Subagent Logger | SubagentStop | エージェントの実行を Briefing Vault に記録 |
| Vault Reminder | UserPromptSubmit | メッセージ 5 件以上で /boss-briefing を、記録された作業が溜まれば実際のセッションノートを提案 |
| Context Budget | UserPromptSubmit | 直近の圧縮から 40 プロンプトごと（`MY_CODEX_COMPACT_EVERY`）に、次の作業境界で `/compact` を提案 |
| Context Budget reset | PostCompact | 圧縮後にそのカウンターを 0 に戻す |
| Completion Check | Stop | プロファイルのフォールバックを実行 + /boss-briefing を確認 |
| Final Report Gate | Stop | 作業があったのに最終レポートの表がなければ、そのターンを 1 度だけブロック |

Codex はこれらを `~/.codex/hooks.json` から、しかも `features.hooks = true` のときだけ読み込みます。そのため `install.sh` がそのパスにファイルを書き、`config.toml` の `[features]` の下にフラグを設定します。次回の対話型 Codex 起動時にフックを確認して信頼するか一度尋ねられるので、「Trust all and continue」を選んでください。それまではどのフックも実行されません。

---

## 結果を確認する場所

インストールされたツールはそれぞれどこかに出力を書きます。その場所です。

| ツール | 開く | 実行方法 | 確認場所 |
|------|------|------------|----------------------|
| **codeburn** | <http://127.0.0.1:4747/> | インストーラーが `codeburn web --provider all --port 4747 --no-open` を起動します。`codeburn` は対話型ダッシュボード、非対話では `codeburn report --format json --period week --provider codex`（`--day`、`--from`/`--to` も可） | 共有ブラウザダッシュボード、ターミナル TUI、または stdout の JSON。セッションファイルは読み取り専用で、金額は公開価格表に基づく推定であり請求書ではありません。 |
| **Serena** | <http://localhost:24282/dashboard/index.html> | Codex が `[mcp_servers.serena]` から起動します。ツールは `get_symbols_overview`、`find_symbol`、`find_referencing_symbols`、`replace_symbol_body`、`insert_after_symbol` として現れます | サーバー稼働中にダッシュボードとツール呼び出し統計を確認できます。プロジェクトごとのインデックスとメモリは `<repo>/.serena/` 配下にあり、ブラウザは自動で開きません（`--open-web-dashboard False`）。 |
| **Headroom** | <http://127.0.0.1:8787/stats> | Codex が `[mcp_servers.headroom]`（`headroom mcp serve`）から MCP サーバーを起動し、インストーラーが共有プロファイル `agent-harness-shared` を適用します（下記コマンド） | プロキシ統計です。`headroom wrap` または base URL でクライアントを明示的にルーティングするまでは空のままです。 |
| **Archify** | `<output>.html` | `~/.codex/skills/archify` から `node bin/archify.mjs render <type> <input>.json <output>.html` を実行し、その後 `node bin/archify.mjs check <output>.html` | 指定したファイル — ブラウザで開くだけです。スキル同梱の `examples/*.json` はそのまま写して使える入力例です。 |

インストーラーは次のコマンドで Headroom のサービスプロファイルを適用します:

```bash
headroom install apply --profile agent-harness-shared --preset persistent-service \
  --runtime python --providers manual --port 8787 --no-telemetry \
  --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1
```

---

## GitHub Actions

| ワークフロー | トリガー | 目的 |
|----------|---------|---------|
| **CI** | push, PR | TOML エージェントファイル、スキルの存在、アップストリームのファイル数を検証 |
| **Smoke Tests** | push, PR | `hooks`、`shell`、`drift`、`routing-refs` ジョブ — フック配線、シェル構文、モデルドリフト、AGENTS.md のルーティング参照 |
| **Update Upstream** | 3 日ごと / 手動 | ブランチ追跡のサブモジュール 4 つに対するセキュリティゲート付き `git submodule update --remote`、`upstream/SOURCES.json` のピン更新、自動マージ PR の作成 |
| **Auto Tag** | main への push | `config.toml` からバージョンを読み、新しければ git タグを作成 |
| **Pages** | main への push | `docs/index.html` を GitHub Pages にデプロイ |
| **CLA** | PR | コントリビューターライセンス同意の確認 |
| **Lint Workflows** | push, PR | GitHub Actions ワークフロー YAML の構文検証 |

---

## my-codex オリジナル

アップストリームの提供内容を超えて、本プロジェクトのために作られた機能です:

| 機能 | 説明 |
|---------|-------------|
| **Boss メタオーケストレーター** | 動的な能力検出 → 意図分類 → 4 段階の優先ルーティング → 委任 → 検証 |
| **3 フェーズスプリント** | 設計（対話型） → 実行（executor による自律） → レビュー（設計ドキュメントとの対話型比較） |
| **エージェント階層の優先度** | core > omo > omx > オプトインパックの順で重複排除。既存エージェントと名前が衝突するパックエージェントはスキップされます。最も特化したエージェントが勝ちます。 |
| **コスト最適化** | 単一ファイル（`scripts/model-tiers.sh`）で管理する 3 つのモデルティアを、インストールされる 34 体すべてに適用 |
| **スキル公開プロファイル** | 210 エントリのカタログに既定 30 の公開、任意レーン 13、スナップショットとロールバック — スキル予算をそのセッションに必要なものへ使います |
| **ブリーフィングシグナル** | ラッパー/セッションのログが `.briefing/agents/agent-log.jsonl`、日次集計、ルーティング/プロファイルのヒントを生成 |
| **Smart Packs** | プロジェクト種別の検出により、セッション開始時に関連するエージェントパックを推奨 |
| **エージェントパックシステム** | `--profile` と `my-codex-packs` ヘルパーによるオンデマンドのドメイン専門家有効化 |
| **Codex Attribution** | git フックが Codex の触れたファイルを記録し、コミットメッセージに `AI-Contributed-By: Codex` を付与 |
| **CI 重複検出** | アップストリーム同期時に TOML エージェントの重複を自動検出 |

---

## バンドルされたアップストリームバージョン

git サブモジュールでリンクしています。固定コミットは `.gitmodules` がネイティブに追跡し、[`upstream/SOURCES.json`](../../upstream/SOURCES.json) に AI-BOM としてミラーされます。このファイルは companion CLI と MCP サーバーのバージョンも固定し、削除された 2 つのサブモジュールも記録します。`install.sh` は `main` を追うのではなく、以下の正確な SHA をチェックアウトします。

| 出典 | SHA | 日付 | 差分 |
|--------|-----|------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `07756ce` | 2026-09-19 | [compare](https://github.com/affaan-m/everything-claude-code/compare/07756ce...HEAD) |
| [gstack](https://github.com/garrytan/gstack) | `a6b3a57` | 2026-09-16 | [compare](https://github.com/garrytan/gstack/compare/a6b3a57...HEAD) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | `cb955b0` | 2026-09-13 | [compare](https://github.com/Yeachan-Heo/oh-my-codex/compare/cb955b0...HEAD) |
| [superpowers](https://github.com/obra/superpowers) | `5bf4e78` | 2026-09-19 | [compare](https://github.com/obra/superpowers/compare/5bf4e78...HEAD) |
| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |

---

## インストールオプション

同じコマンドを再実行すると最新の `main` ビルドに更新され、`~/.codex/` 内で my-codex が管理するファイルだけが置き換えられ、`~/.agents/skills/` から古いスキルのコピーが削除されます。

### スキルプロファイルとレーン

my-claude は固定の許可リストを 1 つインストールしますが、my-codex はスキルファイル 107 個をインストールしたうえで、そのうち何個を Codex に実際に見せるかを制御します。Codex はスキル予算を超えるとスキルの説明を切り詰めるため、焦点のないカタログはすべての説明の有用性を下げます。同梱スキルソースをすべて選択した新規インストールの既定値である `core` はスキル 30 個を公開し、各レーンはその上に追加されます:

| プロファイル / レーン | 追加されるもの | 数量 | 有効化方法 |
|----------------|--------------|------:|---------------|
| `core` | 常時有効な集合: my-codex コアスキル、superpowers の開発プロセスレーン、gstack の出荷/QA/レビュールーター、ECC の標準 | 30 | 既定。戻すときは `--skill-profile=core` |
| `legacy` | 移行前の公開範囲。`--skip-ecc`、`--skip-gstack`、`--skip-superpowers`、`--skip-archify` で core ソースを省き、プロファイルを明示しなかった場合に自動選択 | 可変 | `--skill-profile=legacy` |
| `full` | すべてのレーンを一度に。コンテキスト予算を超える可能性があります | 210 | `--skill-profile=full` または `--full-skills` |
| `workflow-advanced` | 高度な計画、リポジトリ操作、worktree ワークフロー | 13 | `--skills=workflow-advanced` |
| `qa-operations` | QA、ブラウザ検証、リリース、デプロイ、運用上の安全策 | 20 | `--skills=qa-operations` |
| `ai-engineering` | エージェントシステム、評価、プロンプト、検索、MCP | 18 | `--skills=ai-engineering` |
| `backend-data` | バックエンドアーキテクチャ、データベース、キャッシュ、コンテナ、API | 13 | `--skills=backend-data` |
| `python` | Python、Django、FastAPI の実装とテスト | 9 | `--skills=python` |
| `jvm` | Java、Kotlin、JPA、Spring の実装とテスト | 11 | `--skills=jvm` |
| `web` | Web フレームワーク、アクセシビリティ、パフォーマンス、E2E テスト | 18 | `--skills=web` |
| `mobile` | Android、Flutter、Swift、SwiftUI の開発 | 9 | `--skills=mobile` |
| `other-languages` | C++、Go、Laravel、Perl、Rust の開発 | 13 | `--skills=other-languages` |
| `research-content` | リサーチ、技術コンテンツ、市場調査、アウトリーチ | 11 | `--skills=research-content` |
| `media-documents` | メディア生成、ドキュメント処理、OCR、翻訳 | 7 | `--skills=media-documents` |
| `business-domains` | 物流、品質、生産、調達、貿易 | 8 | `--skills=business-domains` |
| `alternative-workflows` | 任意のオーケストレーション、TDD、レビュー、検証の仕組み | 30 | `--skills=alternative-workflows` |

選択内容は `~/.codex/my-codex/skill-catalog-state.json` に、互換用の記録は `~/.codex/enabled-skill-lanes.txt` に保持されるため、後から素の `bash install.sh` を実行しても維持されます。`MY_CODEX_SKILLS=web` は `--skills=web` と同等で、状態を持たない既存の非対話インストールは現在の公開範囲を保ちます。プロファイルを変えても実際のスキルファイルは削除されません — 任意のエントリは Codex がサポートするパス単位のスキル設定で隠され、未知のスキルや `~/.agents/skills/`、`~/.claude/skills/` 配下のファイルはそのままです。

インストール後は `my-codex-skills` CLI で公開範囲を管理します:

```bash
my-codex-skills list                     # すべてのカタログエントリとレーン
my-codex-skills status                   # 有効なプロファイルとレーン
my-codex-skills doctor                   # カタログ/状態のずれを報告
my-codex-skills enable python web        # レーンを追加
my-codex-skills disable web              # レーンを外す
my-codex-skills set-profile core         # core | legacy | full
my-codex-skills source benchmark gstack  # 同名を提供する出典が 2 つあるとき選択
my-codex-skills restore latest           # スナップショットへロールバック
```

カタログは `~/.codex/lib/my-codex/skill-catalog.json`、スナップショットは `~/.codex/my-codex/skill-catalog-snapshots/<id>.json` にあります。レーンを有効化すると、不足するペイロードをピン留めしたローカル vendor から取得できます。取得できない場合は状態も設定も変更せず、CLI が `install.sh --skills=<lane>` を案内します。

### エージェントパックプロファイル

パックはインストールされますが **既定では無効** です。新規インストールはどのパックも有効にせず、空の集合を `~/.codex/enabled-agent-packs.txt` に記録します。パック単位でオプトインするか、プロファイルを選んでください:

```bash
# 現在の状態を確認
~/.codex/bin/my-codex-packs status
# パックを即座に有効化
~/.codex/bin/my-codex-packs enable data-ai
# 最小プロファイル（コアエージェントのみ、パックなし — 既定）
bash /tmp/my-codex/install.sh --profile minimal
# dev プロファイル（data-ai + llmops）
bash /tmp/my-codex/install.sh --profile dev
# full プロファイル（インストール済み 2 カテゴリをすべて有効化）
bash /tmp/my-codex/install.sh --profile full
```

### Codex アトリビューションシステム

`install.sh` は `codex` ラッパーと、`~/.codex/git-hooks/` のグローバル git フックをインストールします:

- **`prepare-commit-msg`** — 実際の Codex セッション中に変更されたファイルを記録
- **`commit-msg`** — ステージされたファイルが記録済みの変更集合と交差する場合に `Generated with Codex CLI: https://github.com/openai/codex` を追加
- **`post-commit`** — 対象コミットに `AI-Contributed-By: Codex` トレーラーを追加

オプトインの `Co-authored-by` トレーラー: `git config --global my-codex.codexContributorName '<label>'` と `my-codex.codexContributorEmail '<github-linked-email>'` の両方を設定します。完全に無効化: `git config --global my-codex.codexAttribution false`。my-codex は `git user.name`、`git user.email`、コミット作者情報を **変更しません**。

### エージェント TOML フォーマット

すべてのエージェントは `~/.codex/agents/` のネイティブ TOML ファイルです:

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

`~/.codex/config.toml` のグローバル Codex 設定:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — 同時実行するサブエージェントの上限
- `max_depth` — エージェントがエージェントを起動する連鎖の最大ネスト深度

---

## よくある質問

<details>
<summary><strong>my-codex と my-claude の違いは何ですか？</strong></summary>

Boss オーケストレーションは同じで、ランタイムが異なります。my-codex はネイティブ `.toml` エージェントフォーマットと `spawn_agent` 委任で OpenAI Codex CLI を対象とし、my-claude は `.md` エージェントフォーマットと Agent ツールで Claude Code を対象とします。さらに my-codex はプロファイルとレーンでスキルの公開範囲を制御しますが、my-claude は固定の許可リストを 1 つインストールします。

</details>

<details>
<summary><strong>my-codex と my-claude を併用できますか？</strong></summary>

はい。それぞれ別のディレクトリ（`~/.codex/` と `~/.claude/`）にインストールされます。2 つのインストーラーは `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services` のユーザー単位のロックと状態ディレクトリで codeburn と Headroom を調停し、正常なサービスは再利用し、固定ポートを占有する外部プロセスは強制終了せずに報告します。

</details>

<details>
<summary><strong>エージェントパックはどう動きますか？</strong></summary>

[エージェントパックプロファイル](#エージェントパックプロファイル)を参照してください。

</details>

<details>
<summary><strong>アップストリーム同期はどう行われますか？</strong></summary>

[GitHub Actions](#github-actions) の **Update Upstream** の行を参照してください。`upstream/archify` はタグ固定で意図的にのみ更新するため、ジョブは残りの 4 サブモジュールだけを扱います。Actions タブから手動で実行することもできます。

</details>

<details>
<summary><strong>my-codex はどのモデルを使いますか？</strong></summary>

[モデルルーティング](#モデルルーティング)と[推論強度ティア](#推論強度ティア)を参照してください。スキルは SKILL.md 標準を変換せずそのまま利用し、変換されるのはエージェントだけです。その変換に使うモデルティアは単一ファイル `scripts/model-tiers.sh` で管理されます。

</details>

---

## トラブルシューティング

### スキルのみの復旧

`~/.agents/skills/` の `SKILL.md` が無効と報告される場合、最も多い原因は古いインストールから残ったローカルコピーやシンボリックリンクの参照先です。`~/.agents/skills/` の該当ディレクトリと `~/.claude/skills/` の対応エントリを削除してから再インストールしてください:

```bash
npx skills add sehoon787/my-codex -y -g
```

Codex のフルバンドルを使っている場合は `install.sh` も一度実行し直してください。フルインストーラーは `~/.codex/skills/` を更新し、`~/.agents/skills/` から my-codex 管理の古いコピーを削除します。

---

## コントリビューション

Issue と PR を歓迎します。新しいエージェントを追加するときは `codex-agents/core/` または `codex-agents/omo/` に `.toml` ファイルを追加し、`SETUP.md` のエージェント一覧を更新してください。PR の検証手順と Codex のコミットアトリビューション動作は [CONTRIBUTING.md](../../CONTRIBUTING.md) を参照してください。

## クレジット

[使用しているオープンソースツール](#使用しているオープンソースツール)に挙げたプロジェクトの上に成り立っています。すべての作者に感謝します。本ハーネスが対象とするランタイム [OpenAI Codex CLI](https://github.com/openai/codex)、そしてスキル専用バンドルをインストールする `npx skills` CLI を提供する [openai/skills](https://github.com/openai/skills) にも感謝します。

## ライセンス

MIT ライセンス。詳細は [LICENSE](../../LICENSE) ファイルを参照してください。
