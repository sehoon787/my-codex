[English](./README.md) | [한국어](./README.ko.md)

> 🟣 **Claude Code 사용자** → [**my-claude**](https://github.com/sehoon787/my-claude) — 동일한 에이전트를 Claude Code 플러그인 + Boss 메타 오케스트레이터로

> **LLM 에이전트인 경우**, 설치 가이드를 가져와 따르세요:
> ```bash
> curl -s https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md
> ```
> 전체 출력을 읽고, 각 단계를 순서대로 실행하세요. `WebFetch`가 아닌 `curl`을 사용하세요 (요약 시 중요한 설정값이 손실됩니다).

---

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-319_(104_core)-blue)
![Skills](https://img.shields.io/badge/skills-136-purple)
![Rules](https://img.shields.io/badge/rules-50-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-weekly-brightgreen)

OpenAI Codex CLI를 위한 올인원 멀티에이전트 오케스트레이션 — 한 번 설치하면 모든 것을 얻습니다.

4개 업스트림 소스에서 **319개 에이전트** (104 코어 + 215 도메인 에이전트팩), **136개 스킬**, **50개 규칙**을 네이티브 TOML 형식으로 번들합니다. Codex CLI가 `spawn_agent`를 통해 에이전트를 자동 탐색하고 최적의 전문가에게 작업을 라우팅합니다. GitHub Actions CI가 매주 업스트림 변경사항을 동기화합니다.

공식 [Codex Subagents](https://developers.openai.com/codex/subagents) 스펙 기반.

---

## 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **네이티브 TOML** | 모든 에이전트가 Codex CLI의 네이티브 `.toml` 형식 — 런타임 변환 없음, 호환성 문제 없음 |
| **멀티소스 큐레이션** | 4개 업스트림 소스를 통합, 중복 제거, 품질 검증하여 하나의 컬렉션으로 |
| **무설정** | 한 번 설치하면 319개 에이전트. `config.toml`이 `multi_agent = true`로 자동 설정 |

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

## 설치 항목

| 구성요소 | 수량 | 위치 |
|---------|------|------|
| 코어 에이전트 | 104 | `~/.codex/agents/` |
| 에이전트 팩 | 215 | `~/.codex/agent-packs/` |
| 스킬 | 136+ | `~/.codex/skills/` |
| 규칙 | 50 | 프로젝트 범위 |
| AGENTS.md | 1 | `~/.codex/AGENTS.md` |
| config.toml | 1 | `~/.codex/config.toml` |

---

## 주요 기능

### 멀티에이전트 오케스트레이션
- **spawn_agent**: Codex CLI가 `~/.codex/agents/`에서 에이전트를 자동 탐색하고 복잡한 작업을 위해 병렬 생성
- **send_input**: 부모↔자식 에이전트 간 통신으로 반복적 워크플로우 지원
- **에이전트 팩**: 심링크로 도메인 전문가를 온디맨드 활성화 — 재시작 불필요

### 모델 최적화 라우팅
- **o3 (high reasoning)**: 복잡한 아키텍처, 심층 분석
- **o3 (medium)**: 표준 구현, 코드 리뷰
- **o4-mini (low)**: 빠른 조회, 탐색

### 올인원 번들
- 설치 시 **319개 에이전트, 136개 스킬, 50개 규칙** 즉시 제공
- 4개 업스트림 소스 번들 (agency-agents, everything-claude-code, oh-my-claudecode, awesome-codex-subagents)
- 매주 CI 자동 동기화로 업스트림 최신 상태 유지
- 비네이티브 소스의 MD→TOML 변환 자동 처리

---

## 코어 에이전트 (항상 로드)

104개 에이전트가 `~/.codex/agents/`에 설치 — 모든 Codex 세션에서 자동 사용 가능:

### 개발 (19개)
executor, architect, planner, debugger, code-reviewer, code-simplifier, critic, designer, document-specialist, explore, git-master, qa-tester, scientist, security-reviewer, test-engineer, tracer, verifier, writer, analyst

### 오케스트레이션 (9개)
atlas, hephaestus, metis, momus, oracle, prometheus, sisyphus, librarian, multimodal-looker

### 엔지니어링 (24개)
AI Engineer, Backend Architect, Blockchain Security Auditor, Data Engineer, Database Optimizer, DevOps Automator, Embedded Firmware Engineer, Frontend Developer, Incident Response Commander, Infrastructure Maintainer, LSP/Index Engineer, MCP Builder, Performance Benchmarker, Rapid Prototyper, Security Engineer, Senior Developer, Solidity Smart Contract Engineer, SRE, Terminal Integration Specialist, Threat Detection Engineer, visionOS Spatial Engineer, macOS Spatial/Metal Engineer, WeChat Mini Program Developer, Feishu Integration Developer

### Awesome 코어 (52개)
[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)의 프로덕션급 에이전트 — core-development, infrastructure, quality-security, meta-orchestration 카테고리.

---

## 에이전트 팩 (도메인 전문가)

215개 도메인 에이전트가 `~/.codex/agent-packs/`에 설치 — 기본적으로 로드되지 않음. 심링크로 활성화:

```bash
# 특정 팩 활성화
ln -s ~/.codex/agent-packs/marketing/*.toml ~/.codex/agents/

# 비활성화
rm ~/.codex/agents/<agent-name>.toml
```

| 팩 | 수량 | 예시 |
|----|------|------|
| marketing | 27 | 더우인, 샤오홍슈, WeChat, TikTok, SEO |
| game-development | 20 | Unity, Unreal, Godot, Roblox, Blender |
| specialized | 20+ | 법무, 재무, 의료, 교육 |
| sales | 10 | 딜 전략, 파이프라인, 아웃바운드 |
| paid-media | 10 | Google Ads, Meta Ads, 프로그래매틱 |
| product | 10 | 프로덕트 관리, UX 리서치, 분석 |
| design | 8 | 브랜드, UI, UX, 비주얼 스토리텔링 |
| project-management | 8 | Agile, Jira, 워크플로우 |
| testing | 8 | API, 접근성, 성능, E2E |
| academic | 5 | 유학, 기업 교육 |
| support | 5 | 고객 지원, 개발자 애드보커시 |
| spatial-computing | 3 | XR, WebXR, AR/VR |

---

## 업스트림 소스

| 소스 | 내용 | 동기화 |
|------|------|--------|
| [agency-agents](https://github.com/msitarzewski/agency-agents) | 156개 도메인 에이전트 (MD→TOML) | 매주 CI |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 108개 스킬, 50개 규칙 | 매주 CI |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 19개 에이전트 (MD→TOML) | 매주 CI |
| [awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) | 136개 네이티브 TOML 에이전트 | 매주 CI |

---

## 라이선스

MIT
