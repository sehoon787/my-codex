[English](../../README.md) | [한국어](./README.ko.md) | [日本語](./README.ja.md) | [中文](./README.zh.md) | [Deutsch](./README.de.md) | [Français](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code를 찾으시나요? → **my-claude** — 동일한 에이전트를 Claude Code 플러그인 + Boss 메타 오케스트레이터로

> **LLM 에이전트인 경우**, 설치 가이드를 가져와 따르세요:
> ```bash
> curl -s https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md
> ```
> 전체 출력을 읽고, 각 단계를 순서대로 실행하세요. `WebFetch`가 아닌 `curl`을 사용하세요 (요약 시 중요한 설정값이 손실됩니다).

---

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-444-blue)
![Skills](https://img.shields.io/badge/skills-125-purple)
![MCP](https://img.shields.io/badge/MCP-3-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

OpenAI Codex CLI를 위한 올인원 멀티에이전트 오케스트레이션 — 한 번 설치하면 모든 것을 얻습니다.

4개 업스트림 소스에서 **444개 설치 에이전트 파일** (80개 자동 로드 + 364개 에이전트팩)과 **125개 스킬**을 네이티브 TOML 형식으로 번들합니다. Codex CLI가 `spawn_agent`를 통해 에이전트를 자동 탐색하고 최적의 전문가에게 작업을 라우팅합니다. GitHub Actions CI가 매주 업스트림 변경사항을 동기화합니다.

공식 [Codex Subagents](https://developers.openai.com/codex/subagents) 스펙 기반.

---

## 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **네이티브 TOML** | 모든 에이전트가 Codex CLI의 네이티브 `.toml` 형식 — 런타임 변환 없음, 호환성 문제 없음 |
| **멀티소스 큐레이션** | 4개 업스트림 소스를 통합, 중복 제거, 품질 검증하여 하나의 컬렉션으로 |
| **무설정** | 한 번 설치하면 444개 에이전트. `config.toml`이 `multi_agent = true`로 자동 설정 |

## 빠른 시작

### 사람인 경우

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

> **에이전트 팩**: 도메인 전문 에이전트 (마케팅, 영업, 게임개발 등)는 `~/.codex/agent-packs/`에 설치되며, 필요할 때 `~/.codex/agents/`로 심링크하여 활성화할 수 있습니다.

### LLM 에이전트인 경우

AI 설치 가이드를 가져와 각 단계를 실행하세요:

```bash
curl -s https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md
```

전체 출력을 읽고 각 단계를 순서대로 실행하세요. `WebFetch`가 아닌 `curl`을 사용하세요.

---

## 주요 기능

### 멀티에이전트 오케스트레이션
- **spawn_agent**: Codex CLI가 `~/.codex/agents/`에서 에이전트를 자동 탐색하고 복잡한 작업을 위해 병렬 생성
- **send_input**: 부모↔자식 에이전트 간 통신으로 반복적 워크플로우 지원
- **에이전트 팩**: 심링크로 도메인 전문가를 온디맨드 활성화 — 재시작 불필요

### 모델 최적화 라우팅
- **o3 (high reasoning)**: 복잡한 아키텍처, 심층 분석 — Claude Opus 동급에서 매핑
- **o3 (medium)**: 표준 구현, 코드 리뷰 — Claude Sonnet 동급에서 매핑
- **o4-mini (low)**: 빠른 조회, 탐색 — Claude Haiku 동급에서 매핑

### 올인원 번들
- 설치 시 **444개 설치 에이전트 파일과 125개 스킬** 즉시 제공
- 4개 업스트림 소스 번들 (agency-agents, everything-claude-code, oh-my-codex, awesome-codex-subagents)
- 매주 CI 자동 동기화로 번들 콘텐츠를 업스트림 최신 상태로 유지
- 비네이티브 소스의 MD→TOML 변환 자동 처리

---

## 코어 에이전트

오케스트레이션 인프라를 제공하는 37개 코어 에이전트가 `~/.codex/agents/`에 설치됩니다. 이 에이전트들은 오케스트레이션, 계획 수립, 코드 리뷰, 검증을 담당하는 기반 에이전트입니다. 도메인 전문가는 에이전트 팩에 있습니다. awesome 카테고리 에이전트가 추가 커버리지를 더하지만, 파일명 중복 때문에 최종 자동 로드 세트는 80개 설치 파일로 정리됩니다.

### 오케스트레이터 (5개)
boss, sisyphus, atlas, hephaestus, prometheus

### 어드바이저 (5개)
metis, momus, oracle, analyst, critic

### 범용 작업자 (6개)
executor, explore, planner, verifier, tracer, debugger

### 오케스트레이션 지원 (8개)
agent-organizer, multi-agent-coordinator, workflow-orchestrator, error-coordinator, task-distributor, context-manager, agent-installer, knowledge-synthesizer

### 유틸리티 작업자 (5개)
writer, librarian, scientist, document-specialist, git-master

### 코드 품질 (5개)
code-reviewer, code-simplifier, code-mapper, security-reviewer, architect

### 테스트 & 미디어 (3개)
test-engineer, qa-tester, multimodal-looker

---

## 에이전트 팩 (도메인 전문가)

21개 카테고리에 걸쳐 364개 설치 팩 파일이 `~/.codex/agent-packs/`에 기록되며 기본적으로 로드되지 **않습니다**. 이 파일들은 `agent-packs/`, `agency/`, awesome 비코어 카테고리에서 설치 시 중복 제거를 거친 최종 결과입니다. 심링크로 활성화하세요:

```bash
# 특정 팩 활성화
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# 비활성화
rm ~/.codex/agents/<agent-name>.toml
```

| 팩 | 수량 | 예시 |
|----|------|------|
| engineering | 32 | 백엔드, 프론트엔드, 모바일, DevOps, AI, 데이터 |
| marketing | 27 | Douyin, Xiaohongshu, WeChat OA, TikTok, SEO |
| language-specialists | 27 | Python, Go, Rust, Swift, Kotlin, Java |
| specialized | 31 | 법무, 재무, 의료, 워크플로우 |
| game-development | 20 | Unity, Unreal, Godot, Roblox, Blender |
| infrastructure | 19 | 클라우드, K8s, Terraform, Docker, SRE |
| developer-experience | 13 | MCP Builder, LSP, 터미널, 신속 프로토타이핑 |
| data-ai | 13 | 데이터 엔지니어, ML, 데이터베이스, ClickHouse |
| specialized-domains | 12 | 공급망, 물류, 이커머스 |
| design | 11 | 브랜드, UI, UX, 비주얼 스토리텔링 |
| business-product | 11 | 프로덕트 매니저, 성장, 분석 |
| testing | 11 | API, 접근성, 성능, E2E, QA |
| sales | 8 | 딜 전략, 파이프라인, 아웃바운드 |
| paid-media | 7 | Google Ads, Meta Ads, 프로그래매틱 |
| research-analysis | 7 | 트렌드, 시장, 경쟁 분석 |
| project-management | 6 | Agile, Jira, 워크플로우 |
| spatial-computing | 6 | XR, WebXR, AR/VR, visionOS |
| support | 6 | 고객 지원, 개발자 애드보커시 |
| academic | 5 | 유학, 기업 교육 |
| product | 5 | 프로덕트 관리, UX 리서치 |
| security | 5 | 침투 테스트, 컴플라이언스, 감사 |

---

## 설치 항목

| 구성요소 | 수량 | 소스 | 위치 |
|---------|------|------|------|
| 자동 로드 에이전트 | 80 (37 코어 + 54 어썸 − 11 공유) | 오케스트레이션 인프라 + 어썸 코어 | `~/.codex/agents/` |
| 에이전트 팩 | 364 설치 파일 | `agent-packs/`, `agency/`, 어썸 비코어 카테고리 | `~/.codex/agent-packs/` |
| 스킬 | 125 | ECC | `~/.codex/skills/` |
| config.toml | 1 | my-codex | `~/.codex/config.toml` |
| AGENTS.md | 1 | my-codex | `~/.codex/AGENTS.md` |

<details>
<summary>Awesome 코어 에이전트 (52개) — awesome-codex-subagents에서 제공</summary>

4개 코어 카테고리가 `~/.codex/agents/`에 설치됩니다:

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
<summary>스킬 (125개) — Everything Claude Code에서 제공</summary>

주요 스킬:

| 스킬 | 설명 |
|------|------|
| autopilot | 자율 실행 모드 |
| tdd-workflow | 테스트 주도 개발 시행 |
| security-review | 보안 체크리스트 및 분석 |
| trace | 증거 기반 디버깅 |
| pdf | PDF 읽기, 병합, 분할, OCR |
| docx | Word 문서 생성 및 편집 |
| pptx | PowerPoint 생성 및 편집 |
| xlsx | Excel 파일 생성 및 편집 |
| team | 멀티에이전트 팀 오케스트레이션 |
| backend-patterns | 백엔드 아키텍처 패턴 |
| frontend-patterns | React/Next.js 패턴 |
| postgres-patterns | PostgreSQL 최적화 |
| coding-standards | TypeScript/React 코딩 표준 |
| eval-harness | 평가 주도 개발 |
| strategic-compact | 전략적 컨텍스트 압축 |
| iterative-retrieval | 점진적 컨텍스트 검색 |
| continuous-learning | 세션에서 자동 패턴 추출 |

</details>

---

## 전체 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    사용자 요청                             │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│  Codex CLI (spawn_agent / send_input / wait_agent)      │
│  런타임에 ~/.codex/agents/*.toml 자동 탐색               │
│  작업 설명에 따라 최적의 전문가에게 라우팅                  │
└──┬──────────┬──────────┬──────────┬─────────────────────┘
   ↓          ↓          ↓          ↓
┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐
│단일  │ │병렬    │ │부모-   │ │설정    │
│에이전│ │생성    │ │자식    │ │제어    │
│트    │ │(multi) │ │통신    │ │        │
│spawn │ │spawn × │ │send_   │ │config. │
│_agent│ │N       │ │input   │ │toml    │
└──────┘ └────────┘ └────────┘ └────────┘
┌─────────────────────────────────────────────────────────┐
│  에이전트 계층 (444개 고유 네이티브 TOML 에이전트)           │
│    ├── 자동 로드 (80): 최종 설치 기준                       │
│    └── 에이전트 팩 (364): 최종 설치 기준                   │
├─────────────────────────────────────────────────────────┤
│  스킬 계층 (ECC에서 125개)                               │
│    ├── tdd-workflow, security-review, autopilot         │
│    └── pdf, docx, pptx, xlsx, team                     │
└─────────────────────────────────────────────────────────┘
```

---

## Codex 멀티에이전트 작동 방식

### Codex Subagents 스펙

Codex CLI는 [Codex Subagents](https://developers.openai.com/codex/subagents) 스펙 기반의 네이티브 멀티에이전트 프로토콜을 제공합니다. 이 프로토콜은 5가지 핵심 작업을 정의합니다:

| 작업 | 설명 |
|------|------|
| **spawn_agent** | 특정 역할, 모델, 지침으로 서브에이전트를 생성 |
| **send_input** | 실행 중인 서브에이전트에 메시지를 전송하여 반복 통신 |
| **wait_agent** | 서브에이전트가 작업을 완료하고 결과를 반환할 때까지 대기 |
| **close_agent** | 실행 중인 서브에이전트를 종료 |
| **resume_agent** | 일시 중지된 서브에이전트를 계속 실행 |

Codex CLI는 런타임에 `~/.codex/agents/`의 모든 `.toml` 파일을 자동 탐색합니다. 작업에 전문가 지식이 필요하면, CLI가 이름으로 해당 에이전트를 생성하고 관련 컨텍스트를 전달합니다.

### 에이전트 TOML 형식

모든 에이전트는 네이티브 TOML 파일로 정의됩니다:

```toml
name = "debugger"
description = "Focused debugging specialist"
model = "o3"
model_reasoning_effort = "medium"

[developer_instructions]
content = "You are a debugging specialist..."
```

주요 필드:
- `name` — `spawn_agent`에서 사용하는 에이전트 식별자
- `description` — 기능 매칭에 사용
- `model` — 사용할 OpenAI 모델 (`o3`, `o4-mini`)
- `model_reasoning_effort` — 추론 수준 (`high`, `medium`, `low`)
- `[developer_instructions].content` — 에이전트의 시스템 프롬프트

### 설정 (config.toml)

글로벌 멀티에이전트 설정은 `~/.codex/config.toml`에서 정의됩니다:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — 최대 동시 서브에이전트 수
- `max_depth` — 에이전트가 에이전트를 생성하는 체인의 최대 중첩 깊이

---

## 멀티에이전트 사용 예시

### 단일 에이전트 위임

```
> 인증 모듈의 보안 취약점을 분석해주세요

Codex → spawn_agent("security-reviewer")
→ 에이전트가 src/auth/ 분석
→ 결과: 심각 2건, 중간 1건 취약점
```

### 병렬 생성

```
> 3개 에이전트 생성: 인증 리팩토링, 테스트 추가, 보안 리뷰

Codex → spawn_agent("executor") × 리팩토링
      → spawn_agent("test-engineer") × 테스트 작성
      → spawn_agent("security-reviewer") × 보안 감사
→ 3개 모두 병렬 실행 (max_threads = 8)
→ 결과 수집 및 병합
```

### 부모-자식 통신

```
> 결제 모듈을 구현하고, 리뷰를 받아주세요

Codex → spawn_agent("executor")
      → executor가 구현 완료
      → send_input(executor, "review needed")
      → spawn_agent("code-reviewer")
      → code-reviewer가 executor의 변경사항 리뷰
```

### 복잡한 오케스트레이션

```
> 마이그레이션을 계획하고, 실행하고, 검증해주세요

Codex → spawn_agent("planner")
      → planner가 마이그레이션 계획 생성
      → wait_agent(planner)
      → spawn_agent("executor") — 계획을 컨텍스트로 전달
      → executor가 마이그레이션 수행
      → wait_agent(executor)
      → spawn_agent("verifier")
      → verifier가 모든 마이그레이션이 올바르게 적용되었는지 확인
```

---

## 사용한 오픈소스 도구

### 1. [Agency Agents](https://github.com/msitarzewski/agency-agents)

156개 비즈니스 전문가 에이전트 페르소나 라이브러리. UX 아키텍트, 데이터 엔지니어, 보안 감사자 등 14개 카테고리에 걸쳐 전문가 관점을 제공합니다. 자동화된 `md-to-toml.sh` 파이프라인으로 Markdown에서 네이티브 TOML로 변환되었습니다.

### 2. [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)

원래 Claude Code용으로 제작된 개발 프레임워크로, 125개 스킬을 제공합니다. Claude Code 전용 스킬 13개를 제거했으며, 나머지 스킬은 모든 LLM 에이전트에서 활용 가능한 범용 코딩 가이드라인입니다. rules/ 디렉토리는 참고 자료로 저장소에 포함되어 있으나 Codex CLI가 읽지 않습니다.

### 3. [Awesome Codex Subagents](https://github.com/VoltAgent/awesome-codex-subagents)

네이티브 TOML 형식의 업스트림 카테고리 기반 에이전트 컬렉션입니다. 이 저장소에서는 core development부터 meta-orchestration까지 여러 awesome 카테고리를 가져오며, 설치 시 다른 소스와의 파일명 중복을 정리해 최종 설치 footprint에 반영합니다.

### 4. [Oh My Codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex)

Yeachan Heo의 Codex CLI 멀티에이전트 오케스트레이션 프레임워크. Codex CLI를 위한 36개 스킬, hooks, HUD, 팀 파이프라인을 제공하는 Rust/TypeScript 런타임입니다. my-codex의 오케스트레이션 패턴을 위한 아키텍처적 영감으로 참조되었습니다. 에이전트 TOML 파일을 직접 제공하지 않습니다.

### 5. [Oh My OpenAgent (omo)](https://github.com/code-yeongyu/oh-my-openagent)

code-yeongyu의 멀티플랫폼 에이전트 하네스. 이 저장소의 9개 오케스트레이션 에이전트(atlas, hephaestus, metis, momus, oracle, prometheus, sisyphus, librarian, multimodal-looker)는 omo 에이전트를 Codex 네이티브 TOML 형식으로 변환한 것입니다.

### 6. [OpenAI 공식 Skills](https://github.com/openai/skills)

OpenAI가 제공하는 Codex 공식 Skills 카탈로그. 문서 처리, 코드 생성, 개발 워크플로우를 위한 전문 스킬을 포함합니다. Codex CLI에서 `$skill-installer`로 설치할 수 있습니다.

---

## 기여하기

이슈와 PR을 환영합니다. 새로운 에이전트를 추가할 때는 `agents/` 디렉토리에 `.toml` 파일을 추가하고, `SETUP.md`의 에이전트 목록을 업데이트해 주세요.

---

## 번들 업스트림 버전

매주 CI 자동 동기화로 업데이트됩니다. 아직 SOURCES.json은 없으며, 버전은 sync-upstream.yml로 추적합니다.

| 소스 | 동기화 |
|------|--------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | 매주 CI |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 매주 CI |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | 매주 CI |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | 매주 CI |

---

## 크레딧

이 저장소는 다음 오픈소스 프로젝트의 성과를 기반으로 합니다:

- [agency-agents](https://github.com/msitarzewski/agency-agents) — msitarzewski
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — affaan-m
- [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) — Yeachan Heo
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) — code-yeongyu
- [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) — VoltAgent
- [openai/skills](https://github.com/openai/skills) — OpenAI
- [Codex Subagents Spec](https://developers.openai.com/codex/subagents) — OpenAI

---

## 라이선스

MIT 라이선스. 자세한 내용은 [LICENSE](./LICENSE) 파일을 참조하세요.
