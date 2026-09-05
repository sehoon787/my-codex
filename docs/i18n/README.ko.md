[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code를 찾으시나요? → **my-claude** — 네이티브 Claude `.md` 에이전트 형식으로 제공하는 동일한 Boss 오케스트레이션

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-123-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**OpenAI Codex CLI를 위한 올인원 에이전트 하네스.**
**한 번 설치하면 엄선된 17개 에이전트가 준비됩니다.**

Boss가 런타임에 모든 에이전트와 스킬을 자동으로 탐색하고,
`spawn_agent`를 통해 작업을 적합한 전문가에게 라우팅합니다. 설정도, 보일러플레이트도 없습니다.

<img src="../../assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## 설치

### 사람을 위한 설치

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

### AI 에이전트를 위한 설치

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

---

## Boss의 작동 방식

Boss는 my-codex의 핵심에 있는 메타 오케스트레이터입니다. 코드를 직접 작성하지 않고, 탐색하고 분류하고 매칭하고 위임하고 검증합니다.

```
사용자 요청
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

### 우선순위 라우팅

Boss는 가장 적합한 매칭을 찾을 때까지 모든 요청을 우선순위 체인을 통해 순차적으로 처리합니다:

| 우선순위 | 매칭 유형 | 조건 | 예시 |
|:--------:|-----------|------|---------|
| **P1** | 스킬 매칭 | 작업이 독립적인 스킬에 해당 | `"review this diff"` → /review 스킬 |
| **P2** | 전문가 에이전트 | 도메인별 에이전트 존재 | `"security audit"` → security-reviewer |
| **P3a** | Boss 직접 | 독립적인 에이전트 2~4개 | `"fix 3 bugs"` → 병렬 스폰 |
| **P3b** | 서브 오케스트레이터 | 복잡한 다단계 워크플로 | `"refactor + test"` → Sisyphus |
| **P4** | 폴백 | 전문가 매칭 없음 | `"explain this"` → 범용 에이전트 |

### 모델 라우팅

| 복잡도 | 모델 | 사용 대상 |
|-----------|-------|----------|
| 심층 분석, 아키텍처 | gpt-6-astra (high/xhigh reasoning) | Boss, Oracle, Sisyphus, Atlas |
| 표준 구현 | gpt-5.6-terra (medium) | executor, debugger, security-reviewer |
| 빠른 조회, 탐색 | gpt-5.6-luna (low) | explore, 간단한 자문 |

### 3단계 스프린트 워크플로

엔드투엔드 기능 구현을 위해 Boss는 구조화된 스프린트를 오케스트레이션합니다:

```
Phase 1: DESIGN         Phase 2: EXECUTE        Phase 3: REVIEW
(interactive)            (autonomous)             (interactive)
─────────────────────   ─────────────────────   ─────────────────────
User decides scope      executor runs tasks     Compare vs design doc
Engineering review      Auto code review        Present comparison table
Confirm "design done"   Architect verification  User: approve / improve
```

### 정형화된 최종 보고

Boss는 작업이 있던 모든 턴 — 파일 편집·생성, 커밋/PR/머지, 설정 변경, 검증 실행이 있었던 턴 — 을 diff를 열지 않고도 훑어볼 수 있는 정형화된 최종 보고로 마무리합니다. 보고는 고정된 표 5종으로 구성되며, 각 표는 해당 상황이 실제로 발생했을 때만 출력됩니다(빈 표는 만들지 않음):

| 상황 | 표 | 컬럼 |
|-----------|-------|---------|
| 파일/설정 변경 | 변경 대조 (Changes) | 대상 / Before / After / 근거 |
| 여러 작업 완료 | 작업 요약 (Work summary) | 항목 / 결과 / 근거 |
| 검증 실행 | 검증 결과 (Verification) | 항목 / 기대 / 실제 / 판정 |
| 커밋/PR 산출 | 산출물 (Deliverables) | PR / 저장소 / 내용 / 상태 |
| 미해결 존재 | 남은 것 (Remaining) | 항목 / 상태 / 다음 조치 |

이 보고는 추론의 맨 마지막에만 발동하며 — 작업 중간의 진행 상황 보고로는 절대 출력되지 않음 — 순수 질답 턴은 보고 없이 정상 종료됩니다. 규격은 `boss.toml`의 developer instructions에 담겨 있습니다. (자매 프로젝트 [my-claude](https://github.com/sehoon787/my-claude)에서는 Stop 훅이 추가로 이를 강제하지만, Codex CLI에는 동등한 강제 지점이 없어 여기서는 프롬프트 수준의 규격입니다.)

---

## 아키텍처

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

## 구성 요소

| 카테고리 | 수량 | 출처 |
|----------|------:|--------|
| **핵심 에이전트** (항상 로드됨) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **에이전트 팩** (옵트인, 기본 비활성) | 17 | 벤더링된 2개 카테고리: data-ai 13 + llmops 4 |
| **스킬** | 123 | ECC 79 · gstack 27 · Superpowers 13 · Core 4 |
| **MCP 서버** | 3 | Context7, Exa, grep.app |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

<details>
<summary><strong>핵심 에이전트 — Boss 메타 오케스트레이터 (1)</strong></summary>

| 에이전트 | 모델 | 역할 | 출처 |
|-------|-------|------|--------|
| Boss | gpt-6-astra xhigh | 동적 런타임 탐색 → 역량 매칭 → 최적 라우팅. 코드를 직접 작성하지 않습니다. | my-codex |

</details>

<details>
<summary><strong>OMO 에이전트 — 서브 오케스트레이터 및 전문가 (9)</strong></summary>

| 에이전트 | 모델 | 역할 | 출처 |
|-------|-------|------|--------|
| Sisyphus | gpt-6-astra high | 의도 분류 → 전문가 위임 → 검증 | [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) |
| Hephaestus | gpt-6-astra high | 자율적 탐색 → 계획 → 실행 → 검증 | oh-my-openagent |
| Atlas | gpt-6-astra high | 작업 분해 + 4단계 QA 검증 | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | 전략적 기술 컨설팅 (읽기 전용) | oh-my-openagent |
| Metis | gpt-6-astra high | 의도 분석, 모호성 탐지 | oh-my-openagent |
| Momus | gpt-6-astra high | 계획 실현 가능성 검토 | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | 인터뷰 기반 세부 계획 수립 | oh-my-openagent |
| Librarian | gpt-5.6-terra medium | MCP를 통한 오픈소스 문서 검색 | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-terra medium | 이미지/스크린샷/다이어그램 분석 | oh-my-openagent |

</details>

<details>
<summary><strong>OMX 에이전트 — 전문가 작업자 (7)</strong></summary>

[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)의 `prompts/*.md`를 Codex TOML로 변환한 것입니다. `templates/codex-AGENTS.md`가 안내하는 레인만 변환되며, 허용목록은 `scripts/skill-allowlists.sh`에 있습니다.

| 에이전트 | 샌드박스 | 역할 | 출처 |
|-------|---------|------|--------|
| executor | workspace-write | 코드 구현 | oh-my-codex |
| planner | workspace-write | 구현 계획 수립 | oh-my-codex |
| architect | read-only | 시스템 설계 및 아키텍처 | oh-my-codex |
| test-engineer | workspace-write | 테스트 전략 및 커버리지 | oh-my-codex |
| security-reviewer | read-only | 보안 분석 | oh-my-codex |
| code-reviewer | read-only | 집중적인 코드 리뷰 | oh-my-codex |
| debugger | workspace-write | 근본 원인 분석 | oh-my-codex |

</details>

<details>
<summary><strong>에이전트 팩 — 옵트인 AI 전문가 (2개 팩, 17개 에이전트)</strong></summary>

[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)(MIT)에서 `codex-agents/packs/`로 벤더링되어 `~/.codex/agent-packs/`에 설치됩니다. **기본적으로 활성화되는 팩은 없습니다** — 명시적으로 옵트인하세요:

```bash
# 현재 상태 확인
~/.codex/bin/my-codex-packs status

# 팩 즉시 활성화
~/.codex/bin/my-codex-packs enable data-ai

# 설치 시 프로필 전환
bash /tmp/my-codex/install.sh --profile minimal   # 팩 없음
bash /tmp/my-codex/install.sh --profile dev       # data-ai + llmops
bash /tmp/my-codex/install.sh --profile full      # 설치된 모든 팩
```

| 팩 | 수량 | 에이전트 |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

</details>

<details>
<summary><strong>스킬 — 4개 출처에서 123개</strong></summary>

스킬 단위 큐레이션 허용목록은 `scripts/skill-allowlists.sh`에 있으며, 이 파일이 무엇을 설치할지 결정하는 기준입니다.

| 출처 | 수량 | 주요 스킬 |
|--------|------:|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 79 | coding-standards, python-testing, api-design, deep-research |
| [gstack](https://github.com/garrytan/gstack) | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| [superpowers](https://github.com/obra/superpowers) | 13 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |

gstack은 허용목록 스킬 26개에 저장소 루트 항목을 더해 27개로 집계됩니다. gstack 저장소 전체는 `~/.codex/skills/gstack`에 표준 런타임 트리로도 존재합니다.

Codex에는 **문서 스킬이 없습니다** — 이 번들에 `pdf`, `docx`, `pptx`, `xlsx` 스킬은 포함되지 않습니다.

</details>

<details>
<summary><strong>MCP 서버 (3)</strong></summary>

| 서버 | 목적 | 비용 |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://mcp.context7.com) | 실시간 라이브러리 문서 | 무료 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://mcp.exa.ai) | 시맨틱 웹 검색 | 월 1천 건 무료 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://mcp.grep.app) | GitHub 코드 검색 | 무료 |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian 호환 영구 메모리입니다. 모든 프로젝트는 세션에 걸쳐 자동으로 채워지는 `.briefing/` 디렉터리를 유지합니다.

```
.briefing/
├── INDEX.md                          ← 프로젝트 컨텍스트 (최초 자동 생성)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← AI가 작성한 세션 요약 (강제)
│   └── YYYY-MM-DD-auto.md           ← 자동 생성 스캐폴드 (git diff, 에이전트 통계)
├── decisions/
│   ├── YYYY-MM-DD-<decision>.md     ← AI가 작성한 의사결정 기록
│   └── YYYY-MM-DD-auto.md           ← 자동 생성 스캐폴드 (커밋, 파일)
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← AI가 작성한 학습 노트
│   └── YYYY-MM-DD-auto-session.md   ← 자동 생성 스캐폴드 (에이전트, 파일)
├── references/
│   └── auto-links.md                ← 웹 검색에서 자동 수집된 URL
├── agents/
│   ├── agent-log.jsonl              ← 서브에이전트 실행 텔레메트리
│   └── YYYY-MM-DD-summary.md        ← 일별 에이전트 사용 요약
├── persona/
│   ├── profile.md                   ← 에이전트 친화도 통계 (자동 업데이트)
│   ├── suggestions.jsonl            ← 라우팅 제안 (자동 생성)
│   ├── rules/                       ← 승인된 라우팅 선호도
│   └── skills/                      ← 승인된 페르소나 스킬
├── archives/                         ← 완료/비활성 노트 (30일+)
│   ├── sessions/
│   ├── decisions/
│   └── learnings/
└── wiki/                             ← 개념 페이지 (자동 제안)
    └── _schema.md
```

### 자동화 라이프사이클

| 단계 | 훅 이벤트 | 동작 |
|-------|-----------|-------------|
| **세션 시작** | `SessionStart` | `.briefing/` 구조 생성, 세션별 diff를 위한 git HEAD 해시 저장 |
| **작업 중** | `PostToolUse` Edit/Write | 파일 편집 횟수 추적; 5회에서 경고, 15회에서 decisions/learnings 미작성 시 차단 |
| **작업 중** | `PostToolUse` WebSearch/WebFetch | URL을 `references/auto-links.md`에 자동 수집 |
| **작업 중** | `SubagentStop` | 에이전트 실행을 `agents/agent-log.jsonl`에 기록 |
| **작업 중** | `UserPromptSubmit` (매 5번째) | 제한된 페르소나 프로필 업데이트 |
| **세션 종료** | `Stop` (1번째 훅) | 스캐폴드 자동 생성: `sessions/auto.md`, `learnings/auto-session.md`, `decisions/auto.md`, `persona/profile.md` |
| **세션 종료** | `Stop` (2번째 훅) | 파일 편집 횟수 ≥ 3인 경우 AI 작성 세션 요약 **강제** — 템플릿으로 세션 종료 차단 |
| **archives/** | — | 30일 이상 경과한 완료/비활성 노트를 아카이브로 자동 제안. PARA 아카이브 개념. |
| **wiki/** | — | 개념 위키 페이지. 키워드가 3회 이상 등장하면 자동 제안. LLM-wiki 개념. |

### 자동 생성 vs AI 작성

| 유형 | 파일 패턴 | 생성 주체 | 내용 |
|------|-------------|-----------|---------|
| **자동 스캐폴드** | `*-auto.md`, `*-auto-session.md` | Stop 훅 (Node.js) | Git diff 통계, 에이전트 사용량, 커밋 목록 — 데이터만 |
| **AI 요약** | `YYYY-MM-DD-<topic>.md` | 세션 중 AI | 컨텍스트, 코드 참조, 근거가 포함된 의미 있는 분석 |
| **텔레메트리** | `agent-log.jsonl`, `auto-links.md` | 훅 스크립트 | 추가 전용 구조화 로그 |
| **페르소나** | `profile.md`, `suggestions.jsonl` | Stop 훅 | 사용량 기반 에이전트 친화도 및 라우팅 제안 |

자동 스캐폴드는 AI가 적절한 요약을 작성하기 위한 **참조 데이터** 역할을 합니다. 강제 훅은 세션 종료를 차단할 때 스캐폴드 내용과 구조화된 템플릿을 제공합니다.

### 세션별 Diff

세션 시작 시 현재 git HEAD를 `.briefing/.session-start-head`에 저장합니다. 세션 종료 시 이 저장된 시점을 기준으로 diff를 계산하여, 이전 세션의 미커밋 변경 사항이 아닌 현재 세션의 변경 사항만 표시합니다.

### Obsidian과 함께 사용하기

1. Obsidian 열기 → **폴더를 보관함으로 열기** → `.briefing/` 선택
2. 노트가 그래프 뷰에 `[[wiki-links]]`로 연결되어 표시됩니다
3. YAML 프론트매터(`date`, `type`, `tags`)로 구조화 검색이 가능합니다
4. 의사결정과 학습의 타임라인이 세션에 걸쳐 자동으로 쌓입니다

### 지식 관리 (v2)

BriefingVault v2는 세 가지 지식 관리 방법론을 통합합니다:

| 방법론 | 개념 | BriefingVault 적용 |
|--------|------|-------------------|
| **PARA** (Tiago Forte) | 실행 가능성으로 분류: 프로젝트, 영역, 리소스, 아카이브 | sessions/ = 프로젝트, decisions/ = 영역, references/ = 리소스, archives/ = 아카이브 |
| **Zettelkasten** (Luhmann) | 고유 ID와 명시적 링크를 갖는 원자적 노트 | learnings/ 파일: `YYYYMMDDHHMMSS` ID, `related:` 2개 이상 링크 필수 |
| **LLM-wiki** (Karpathy) | 원본 노트에서 AI가 관리하는 개념 페이지 | wiki/ 페이지: 키워드가 3회 이상 반복되면 자동 제안 |

---

## 업스트림 오픈소스 출처

my-codex는 **4개의 업스트림 서브모듈**과 벤더링된 스냅샷 1개, 적용/자매 프로젝트 2개, companion CLI 1개로 구성됩니다:

| # | 출처 | 방식 | 제공 내용 |
|---|--------|------|-----------------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 서브모듈 | 개발 워크플로 전반의 허용목록 스킬 79개. Claude Code 전용 콘텐츠는 제거, 범용 코딩 스킬만 유지. |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 서브모듈 | 코드 리뷰, QA, 보안 감사, 배포를 위한 스킬 27개. Playwright 브라우저 데몬 포함. |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 서브모듈 | 허용목록 작업자 에이전트 7개(executor, planner, architect, test-engineer, security-reviewer, code-reviewer, debugger). Markdown 프롬프트를 Codex TOML로 변환. |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 서브모듈 | 브레인스토밍, TDD, 체계적 디버깅, 계획 작성을 다루는 스킬 13개. 설치되는 에이전트는 없습니다. |
| 5 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | 벤더링 (MIT) | AI/LLM 에이전트 17개를 `codex-agents/packs/`에 스냅샷하여 옵트인 팩 2개(data-ai 13, llmops 4)로 제공. 서브모듈은 2026-07-27에 제거되었습니다. |
| 6 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 적용 | OMO 에이전트 9개 (Sisyphus, Atlas, Oracle 등). Codex 네이티브 TOML 형식으로 적용하여 저장소에서 관리합니다. |
| 7 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 자매 프로젝트 | 네이티브 Claude `.md` 에이전트 형식의 동일한 Boss 오케스트레이션. 스킬, 규칙, Briefing Vault를 두 프로젝트가 공유합니다. |
| 8 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | npm CLI (MIT) | 로컬 우선 토큰/비용 추적기. `~/.codex/sessions`를 읽기 전용으로 파싱 — 프록시·업로드 없음. `install.sh`가 설치(`codeburn@0.9.23` 고정), `upstream/SOURCES.json`에 `method: npm-cli`로 등재. Codex에는 훅 없음. |

모든 서브모듈은 `upstream/SOURCES.json`(AI-BOM) — companion CLI(ast-grep, codeburn)도 같은 파일에 버전 고정으로 등재됩니다 —에 SHA로 고정되어 있으며, 제거된 서브모듈 2개(`agency-agents` — 벤더링 없음, `awesome-codex-subagents` — 에이전트 17개 벤더링)도 함께 기록됩니다.

---

## GitHub Actions

| 워크플로 | 트리거 | 목적 |
|----------|---------|---------|
| **CI** | push, PR | TOML 에이전트 파일, 스킬 존재 여부, 업스트림 파일 수 검증 |
| **Smoke Tests** | push, PR | `hooks`, `shell`, `drift`, `routing-refs` 작업 — 훅 연결, 셸 문법, 모델 드리프트, AGENTS.md 라우팅 참조 검증 |
| **Update Upstream** | 3일마다 / 수동 | 보안 게이트가 적용된 `git submodule update --remote`, `upstream/SOURCES.json` 핀 갱신, 자동 병합 PR 생성 |
| **Auto Tag** | main에 push | `config.toml`에서 버전을 읽고 신규 시 git 태그 생성 |
| **Pages** | main에 push | `docs/index.html`을 GitHub Pages에 배포 |
| **CLA** | PR | 기여자 라이선스 동의 확인 |
| **Lint Workflows** | push, PR | GitHub Actions 워크플로 YAML 문법 검증 |

---

## my-codex 오리지널

업스트림 소스를 넘어 이 프로젝트를 위해 특별히 구축된 기능들:

| 기능 | 설명 |
|---------|-------------|
| **Boss 메타 오케스트레이터** | 동적 역량 탐색 → 의도 분류 → 4단계 우선순위 라우팅 → 위임 → 검증 |
| **3단계 스프린트** | 설계 (대화형) → 실행 (executor를 통한 자율) → 리뷰 (설계 문서와 대화형 비교) |
| **에이전트 티어 우선순위** | core > omo > omx > 옵트인 팩 순으로 중복 제거. 이미 설치된 에이전트와 이름이 겹치는 팩 에이전트는 건너뜁니다. 가장 특화된 에이전트가 선택됩니다. |
| **비용 최적화** | 자문에는 gpt-5.6-luna, 구현에는 gpt-6-astra — 설치된 34개 에이전트 전체에 대한 자동 모델 라우팅 |
| **에이전트 텔레메트리** | PostToolUse 훅이 에이전트 사용량을 `agent-usage.jsonl`에 기록 |
| **Smart Packs** | 프로젝트 유형 감지로 세션 시작 시 관련 에이전트 팩 추천 |
| **에이전트 팩 시스템** | `--profile` 및 `my-codex-packs` 헬퍼를 통한 온디맨드 도메인 전문가 활성화 |
| **Codex Attribution** | git 훅이 Codex가 수정한 파일을 기록하고 커밋 메시지에 `AI-Contributed-By: Codex` 추가 |
| **CI 중복 탐지** | 업스트림 동기화 시 TOML 에이전트 중복 자동 감지 |

---

## 설치 옵션

### 빠른 설치

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

동일한 명령을 다시 실행하면 최신 `main` 빌드로 갱신되고, `~/.codex/`에서 my-codex가 관리하는 파일만 교체되며, `~/.agents/skills/`에서 오래된 스킬 사본이 제거됩니다.

### 에이전트 팩 프로필

팩은 설치되지만 **기본적으로 비활성 상태**입니다. 신규 설치는 활성 팩 없이 빈 세트를 `~/.codex/enabled-agent-packs.txt`에 기록합니다. 팩 단위로 옵트인하거나 프로필을 선택하세요:

```bash
# 팩 하나를 즉시 활성화
~/.codex/bin/my-codex-packs enable data-ai

# 최소 프로필 (핵심 에이전트만, 팩 없음 — 기본값)
bash /tmp/my-codex/install.sh --profile minimal

# dev 프로필 (data-ai + llmops)
bash /tmp/my-codex/install.sh --profile dev

# 전체 프로필 (설치된 팩 카테고리 2개 모두 활성화)
bash /tmp/my-codex/install.sh --profile full
```

### Codex Attribution 시스템

`install.sh`는 `codex` 래퍼와 `~/.codex/git-hooks/`에 글로벌 git 훅을 설치합니다:

- **`prepare-commit-msg`** — 실제 Codex 세션 중 변경된 파일을 기록
- **`commit-msg`** — 스테이징된 파일이 기록된 변경 세트와 교차할 때 `Generated with Codex CLI: https://github.com/openai/codex` 추가
- **`post-commit`** — 해당 커밋에 `AI-Contributed-By: Codex` 트레일러 추가

옵트인 `Co-authored-by` 트레일러: `git config --global my-codex.codexContributorName '<label>'`과 `my-codex.codexContributorEmail '<github-linked-email>'` 모두 설정. 완전 비활성화: `git config --global my-codex.codexAttribution false`. my-codex는 `git user.name`, `git user.email`, 또는 커밋 작성자 정보를 **변경하지 않습니다**.

### 에이전트 TOML 형식

모든 에이전트는 `~/.codex/agents/`의 네이티브 TOML 파일입니다:

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

`~/.codex/config.toml`의 글로벌 Codex 설정:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — 최대 동시 서브에이전트 수
- `max_depth` — 에이전트가 에이전트를 스폰하는 체인의 최대 중첩 깊이

---

## 번들된 업스트림 버전

업스트림 소스는 git 서브모듈로 관리됩니다. 고정된 커밋은 `.gitmodules`에서 추적됩니다.

| 출처 | 동기화 방식 |
|--------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 서브모듈 (`upstream/ecc`) |
| [gstack](https://github.com/garrytan/gstack) | 서브모듈 (`upstream/gstack`) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 서브모듈 (`upstream/omx`) |
| [superpowers](https://github.com/obra/superpowers) | 서브모듈 (`upstream/superpowers`) |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | 벤더링 스냅샷 (서브모듈은 2026-07-27 제거) |

---

## FAQ

<details>
<summary><strong>my-codex와 my-claude의 차이점은 무엇인가요?</strong></summary>

my-codex와 my-claude는 동일한 Boss 오케스트레이션 아키텍처와 업스트림 스킬 소스를 공유합니다. 핵심 차이는 런타임입니다: my-codex는 네이티브 `.toml` 에이전트 형식과 `spawn_agent` 위임 방식으로 OpenAI Codex CLI를 대상으로 하며, my-claude는 `.md` 에이전트 형식과 Agent 도구로 Claude Code를 대상으로 합니다.

</details>

<details>
<summary><strong>my-codex와 my-claude를 함께 사용할 수 있나요?</strong></summary>

네. 각각 별도 디렉터리(`~/.codex/`와 `~/.claude/`)에 설치되며 충돌하지 않습니다. 공유 업스트림 소스의 스킬은 각 플랫폼에 맞게 적용됩니다.

</details>

<details>
<summary><strong>에이전트 팩은 어떻게 작동하나요?</strong></summary>

에이전트 팩은 `~/.codex/agent-packs/`에 설치되는 도메인별 에이전트 컬렉션입니다. 현재 `data-ai`(13개)와 `llmops`(4개) 두 팩이 제공되며 **설치 시 활성화되는 팩은 없습니다**. `my-codex-packs enable <pack>`으로 활성화하거나, `--profile full`로 재설치하여 두 카테고리를 모두 활성화할 수 있습니다.

</details>

<details>
<summary><strong>업스트림 동기화는 어떻게 이루어지나요?</strong></summary>

GitHub Actions 워크플로가 3일마다 실행되어 4개 업스트림 서브모듈의 최신 커밋을 가져오고, `upstream/SOURCES.json`의 SHA 핀을 갱신한 뒤, 보안 게이트가 적용된 자동 병합 PR을 생성합니다. Actions 탭에서 수동으로 트리거할 수도 있습니다.

</details>

<details>
<summary><strong>my-codex는 어떤 모델을 사용하나요?</strong></summary>

Boss와 서브 오케스트레이터(Sisyphus, Atlas, Oracle)는 high reasoning effort의 gpt-6-astra를 사용합니다. 표준 작업자는 medium reasoning의 gpt-5.6-terra를 사용합니다. 경량 자문 에이전트는 gpt-5.6-luna를 사용합니다.

</details>

---

## 문제 해결

### 스킬만 복구

`~/.agents/skills/`의 `SKILL.md` 파일이 유효하지 않다고 보고되는 경우, 가장 일반적인 원인은 이전 설치의 오래된 로컬 사본이나 오래된 심볼릭 링크 대상입니다.

`~/.agents/skills/`의 해당 디렉터리와 `~/.claude/skills/`의 대응 항목을 제거한 후 재설치하세요:

```bash
npx skills add sehoon787/my-codex -y -g
```

전체 Codex 번들을 사용하는 경우 `install.sh`도 한 번 다시 실행하세요. 전체 인스톨러는 `~/.codex/skills/`를 갱신하고 `~/.agents/skills/`에서 오래된 my-codex 관리 사본을 제거합니다.

---

## 기여

이슈와 PR을 환영합니다. 새 에이전트를 추가할 때는 `codex-agents/core/` 또는 `codex-agents/omo/`에 `.toml` 파일을 추가하고 `SETUP.md`의 에이전트 목록을 업데이트하세요. PR 검증 단계와 Codex 커밋 attribution 동작은 [CONTRIBUTING.md](../../CONTRIBUTING.md)를 참조하세요.

## 크레딧

다음 작업을 기반으로 구축되었습니다: [my-claude](https://github.com/sehoon787/my-claude) (sehoon787), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (affaan-m), [gstack](https://github.com/garrytan/gstack) (garrytan), [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) (Yeachan Heo), [superpowers](https://github.com/obra/superpowers) (Jesse Vincent), [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) (VoltAgent), [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (code-yeongyu), [openai/skills](https://github.com/openai/skills) (OpenAI).

## 라이선스

MIT 라이선스. 자세한 내용은 [LICENSE](../../LICENSE) 파일을 참조하세요.
