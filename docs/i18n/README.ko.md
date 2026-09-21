[영어](../../README.md) | [한국어](./README.ko.md) | [일본어](./README.ja.md) | [중국어](./README.zh.md) | [독일어](./README.de.md) | [프랑스어](./README.fr.md)

> [![Claude Code](https://img.shields.io/badge/Claude_Code-my--claude-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://github.com/sehoon787/my-claude) Claude Code를 찾으시나요? → **my-claude** — 네이티브 Claude `.md` 에이전트 형식으로 제공하는 동일한 Boss 오케스트레이션

---

<div align="center">

# my-codex

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Agents](https://img.shields.io/badge/agents-17_core_%2B_17_opt--in-blue)
![Skills](https://img.shields.io/badge/skills-30_default_%2F_107_installed-purple)
![MCP](https://img.shields.io/badge/MCP-5-green)
![Auto Sync](https://img.shields.io/badge/upstream_sync-every_3_days-brightgreen)

**Codex CLI를 위한 올인원 에이전트 하네스.**
**한 번 설치하면 핵심 에이전트 17개가 준비됩니다.**

Boss가 런타임에 모든 에이전트·스킬·MCP 도구를 탐색하고,<br>
`spawn_agent`로 작업을 적합한 전문가에게 라우팅합니다. 설정도, 보일러플레이트도 없습니다.

<img src="../../assets/owl-codex-social.svg" alt="The Maestro Owl — my-codex" width="700">

</div>

---

## 설치

### 사람을 위한 설치

```bash
curl -fsSL https://raw.githubusercontent.com/sehoon787/my-codex/main/install.sh | bash
```

먼저 클론한 뒤 체크아웃에서 설치 프로그램을 실행해도 됩니다:

```bash
git clone --depth 1 https://github.com/sehoon787/my-codex.git /tmp/my-codex
bash /tmp/my-codex/install.sh
rm -rf /tmp/my-codex
```

기본 설치가 노출하는 스킬 집합이 적은 것은 의도된 설계입니다. Codex는 스킬
예산을 넘어서면 스킬 설명을 잘라내므로, 기본 `core` 프로필은 설치된 스킬 107개
가운데 30개만 Codex에 보여 주고 나머지는 플래그 하나로 열어 둡니다:

```bash
bash install.sh --skills=web          # 웹/UI 레인 18개 추가
bash install.sh --full-skills         # 모든 선택 레인과 full 노출 프로필
bash install.sh --skill-profile=core  # 기본 노출로 복귀
```

선택한 값은 저장되어 이후 `bash install.sh`를 그대로 실행해도 유지됩니다. 모든 프로필과 레인, `my-codex-skills` 명령은 [스킬 프로필과 레인](#스킬-프로필과-레인)을 참조하세요.

대화형 터미널은 companion 도구 세 가지 — Serena, Headroom, codeburn — 에 대한 체크박스 선택기를 표시하며 기본값은 모두 선택입니다. ↑/↓ 또는 `j`/`k`로 이동하고 Space로 전환하며, `a`는 모두 선택하고 `n`은 모두 해제하며, Enter 또는 Ctrl-D/EOF로 현재 선택을 확정합니다. `TERM`이 비어 있거나 `dumb`이거나 `stty`를 사용할 수 없으면 번호 선택 방식으로 전환하며, Enter, `all`, `a`, `y`, `yes`는 모두 선택하고 `none`, `n`, `no`, `0`은 모두 제외하며, `1,3` 또는 `serena codeburn`처럼 번호와 이름을 섞을 수 있습니다. 자동 실행은 기본적으로 모두 선택합니다:

```bash
bash install.sh --tools=headroom   # 일부만 명시
bash install.sh --yes              # 세 가지 모두, 프롬프트 없이
bash install.sh --skip-tools       # 설치하지 않음
```

Windows에서는 `install.sh`가 npm이 관리하는 `codex`, `codex.cmd`, `codex.ps1` 심을 존재할 때 패치하므로, `%APPDATA%\npm`이 `~/.codex/bin`보다 먼저 해석되더라도 my-codex 볼트 파이프라인의 래퍼 폴백이 유지됩니다.

### AI 에이전트를 위한 설치

```
Read https://raw.githubusercontent.com/sehoon787/my-codex/main/AI-INSTALL.md and follow every step.
```

---

## 사용한 오픈소스 도구

my-codex가 기반으로 삼는 모든 프로젝트와 그 기여 내용, 그리고 도입 방식입니다. 각 프로젝트를 설명하는 곳은 이 표뿐이며, README의 나머지 부분은 목록·명령·핀만 다룹니다.

| # | 프로젝트 | my-codex가 가져오는 것 | 도입 방식 |
|---|----------|------------------------|-----------|
| 1 | <img src="https://github.com/affaan-m.png?size=32" width="20" height="20" align="center"/> **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — affaan-m | 허용목록 스킬 61개: 스택 패턴(TypeScript, React, Python/Django/FastAPI, Spring Boot/Kotlin, SQL/Redis/Prisma, Docker/Kubernetes), AI·에이전트 엔지니어링, 온보딩·코드 투어·ADR 같은 범용 코드베이스 도구입니다. Claude Code 전용 콘텐츠는 제거되며, 웹/UI 스킬 18개 레인은 기본 설치에서 빠져 있습니다. | 서브모듈 `upstream/ecc`. `install.sh`는 `scripts/skill-allowlists.sh`에 허용된 이름만 복사합니다 |
| 2 | <img src="https://github.com/garrytan.png?size=32" width="20" height="20" align="center"/> **[gstack](https://github.com/garrytan/gstack)** — garrytan | 스프린트 프로세스 스킬 27개 — 브라우저 QA(`qa`), 범위 이탈을 보는 코드 리뷰(`review`), 보안 감사(`cso`), 계획 → 리뷰 → 배포 전체 흐름 — 과 컴파일된 Playwright 브라우저 데몬입니다. | 서브모듈 `upstream/gstack`. `~/.codex/vendor/gstack`에 두고 그 안에서 gstack 자체의 `./setup --host codex`를 bun으로 실행합니다. 이를 대체하는 ECC 스킬 7개(`benchmark`, `canary-watch`, `safety-guard`, `browser-qa`, `verification-loop`, `security-review`, `design-system`)는 제거되어 gstack 버전만 라우팅 대상으로 남습니다 |
| 3 | <img src="https://github.com/Yeachan-Heo.png?size=32" width="20" height="20" align="center"/> **[oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)** — Yeachan Heo | 허용목록 작업자 에이전트 7개: `executor`, `planner`, `architect`, `test-engineer`, `security-reviewer`, `code-reviewer`, `debugger`. 나머지 프롬프트와 스킬은 이 저장소가 이미 제공하는 에이전트와 중복되어 의도적으로 설치하지 않습니다. | 서브모듈 `upstream/omx`. `scripts/md-to-toml.sh`가 허용된 프롬프트를 Markdown에서 `~/.codex/agents/*.toml`로 변환합니다 |
| 4 | <img src="https://github.com/obra.png?size=32" width="20" height="20" align="center"/> **[superpowers](https://github.com/obra/superpowers)** — Jesse Vincent | 개발 프로세스 스킬 14개: 브레인스토밍, 체계적 디버깅, 테스트 주도 개발, 계획 작성과 실행, worktree 운용, 코드 리뷰 예절입니다. 에이전트는 가져오지 않습니다 — 유일한 `code-reviewer` 프롬프트가 oh-my-codex 쪽과 겹치기 때문입니다. | 서브모듈 `upstream/superpowers`. 스킬 디렉터리 15개 중 Boss 위임 경로와 중복되는 `dispatching-parallel-agents`만 빼고 모두 설치합니다 |
| 5 | <img src="https://github.com/tt-a1i.png?size=32" width="20" height="20" align="center"/> **[archify](https://github.com/tt-a1i/archify)** — tt-a1i | 아키텍처·워크플로·시퀀스·데이터 흐름·라이프사이클 설명을 인라인 SVG, 다크/라이트 전환, PNG/JPEG/WebP/SVG 내보내기를 갖춘 단일 자립형 HTML 파일로 만드는 다이어그램 스킬 1개입니다. | 서브모듈 `upstream/archify`, 태그 `v2.9.0`에 고정되어 동기화 작업이 건드리지 않습니다. 저장소 최상위 `archify/` 디렉터리만 `~/.codex/skills/archify`로 복사하므로 설치 시 `npx skills add`는 실행되지 않습니다 |
| 6 | <img src="https://github.com/VoltAgent.png?size=32" width="20" height="20" align="center"/> **[awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents)** — VoltAgent | Codex 네이티브 TOML 에이전트 17개로, 옵트인 팩 `data-ai`(13)와 `llmops`(4)로 제공됩니다. 새로 설치하면 어느 팩도 활성화되지 않습니다. | `codex-agents/packs/`에 벤더링(MIT)해 `~/.codex/agent-packs/`에 설치하며, 서브모듈은 2026-07-27에 제거되었습니다. `~/.codex/bin/my-codex-packs enable data-ai` 또는 `install.sh --profile dev`로 활성화합니다 |
| 7 | <img src="https://github.com/code-yeongyu.png?size=32" width="20" height="20" align="center"/> **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** — code-yeongyu | 에이전트 9개 — `sisyphus`, `atlas`, `prometheus`, `oracle`, `metis`, `momus`, `hephaestus`, `librarian`, `multimodal-looker` — 로 엔드투엔드 오케스트레이션, 계획 실행과 검토, 깊이 있는 2차 의견, 출처 기반 라이브러리 조회, 미디어 파일 판독을 담당합니다. | Codex 네이티브 TOML로 적응시켜 `codex-agents/omo/` 아래 저장소 안에서 유지하므로 업스트림 체크아웃 없이 설치됩니다 |
| 8 | <img src="https://github.com/msitarzewski.png?size=32" width="20" height="20" align="center"/> **[agency-agents](https://github.com/msitarzewski/agency-agents)** — msitarzewski | 없음. 이 팩의 에이전트는 이 저장소에서 한 번도 사용되지 않았으므로 벤더링된 것이 없습니다. | 제거됨(MIT) — 서브모듈은 2026-07-27에 내려갔고 기록은 `upstream/SOURCES.json`에 남아 있습니다 |
| 9 | <img src="https://github.com/sehoon787.png?size=32" width="20" height="20" align="center"/> **[my-claude](https://github.com/sehoon787/my-claude)** — sehoon787 | 네이티브 Claude `.md` 에이전트 형식의 동일한 Boss 오케스트레이션이자 편집 기준입니다. `scripts/skill-allowlists.sh`가 my-claude의 ECC·gstack·superpowers 목록을 그대로 옮겨 두 하네스가 동일한 업스트림 표면을 노출합니다. | 자매 프로젝트로만 연결되며 `install.sh`는 클론·다운로드·복사를 전혀 하지 않으므로 벤더링도 추적할 핀도 없습니다. 나란히 설치하면 두 설치 프로그램이 고정 포트를 두고 다투는 대신 사용자 단위의 단일 잠금·상태 디렉터리로 codeburn과 Headroom을 조율합니다 |
| 10 | <img src="https://github.com/getagentseal.png?size=32" width="20" height="20" align="center"/> **[codeburn](https://github.com/getagentseal/codeburn)** — getagentseal | Codex가 이미 `~/.codex/sessions`에 남기는 세션 파일을 읽는 로컬 우선 토큰·비용 집계로, 프록시도 API 키도 Codex 훅도 쓰지 않습니다. | `npm i -g codeburn@0.9.23`. `install.sh`가 공유 프로세스 `codeburn web --provider all --port 4747 --no-open` 하나를 시작하거나 재사용합니다 |
| 11 | <img src="https://github.com/ast-grep.png?size=32" width="20" height="20" align="center"/> **[ast-grep](https://github.com/ast-grep/ast-grep)** — ast-grep | 원시 텍스트가 아니라 구문 트리에 매칭하는 구조적 검색·치환으로, 깨지기 쉬운 정규식 없이 에이전트가 코드 형태를 바꿀 수 있습니다. | `npm i -g @ast-grep/cli@0.42.0`. `PATH`에 이미 `ast-grep` 바이너리가 있으면 건너뜁니다 |
| 12 | <img src="https://github.com/oraios.png?size=32" width="20" height="20" align="center"/> **[serena](https://github.com/oraios/serena)** — oraios | MCP로 노출되는 언어 서버의 심볼 그래프 — `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol` — 로 파일 전체가 아니라 심볼 단위로 토큰을 씁니다. 배포 패키지는 전체로서 GPL-3.0-or-later이며(PyPI의 MIT 표기는 부정확), 코드는 벤더링하지 않습니다. | `uv tool install --python 3.13 serena-agent==1.7.0`. `[mcp_servers.serena]`로 stdio 등록(`serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False`, `startup_timeout_sec = 15`) |
| 13 | <img src="https://github.com/headroomlabs-ai.png?size=32" width="20" height="20" align="center"/> **[headroom](https://github.com/headroomlabs-ai/headroom)** — Headroom Labs | Apache-2.0 MCP 컨텍스트 압축: `headroom_compress`, `headroom_retrieve`, `headroom_stats`. 프록시 모드 `headroom wrap`은 문서화된 수동 옵트인으로 남습니다. | `uv tool install --python 3.13 "headroom-ai[all]==0.37.0"`. 서버가 MCP 어노테이션을 게시하지 않으므로 `default_tools_approval_mode = "approve"`와 함께 `[mcp_servers.headroom]`(`headroom mcp serve`)로 등록하고, 설치 프로그램은 공유 프로필 `agent-harness-shared`를 8787 포트에서 시작하거나 재사용하며 `ANTHROPIC_BASE_URL`이나 `OPENAI_BASE_URL`을 설정하지 않습니다 |
| 14 | <img src="https://github.com/upstash.png?size=32" width="20" height="20" align="center"/> **[context7](https://github.com/upstash/context7)** — Upstash | 라이브러리·프레임워크·SDK 질문을 모델의 기억이 아니라 최신 업스트림 문서에서 답합니다. 스킬 `documentation-lookup`이 연결되는 백엔드입니다. | 호스팅 MCP 서버 `https://mcp.context7.com/mcp` |
| 15 | <img src="https://github.com/exa-labs.png?size=32" width="20" height="20" align="center"/> **[exa](https://github.com/exa-labs/exa-mcp-server)** — Exa Labs | 뉴럴 웹 검색입니다. 등록 URL이 `web_search_exa`만 활성화해 Exa의 전체 기능 대신 조사 경로를 단일 도구로 좁힙니다. | 호스팅 MCP 서버 `https://mcp.exa.ai/mcp?tools=web_search_exa` |
| 16 | <img src="https://github.com/grep-app.png?size=32" width="20" height="20" align="center"/> **[grep.app](https://github.com/grep-app)** — grep.app | 공개 GitHub 저장소 전반을 훑는 코드 검색으로, 에이전트가 코드를 작성하기 전에 여러 저장소의 실제 호출부를 확인할 수 있습니다. | 호스팅 MCP 서버 `https://mcp.grep.app` |

---

## Boss의 작동 방식

Boss는 my-codex의 핵심에 있는 메타 오케스트레이터입니다. 코드를 직접 작성하지 않고, 탐색하고 분류하고 매칭하고 위임하고 검증합니다. 메인 Codex 세션이 설치된 `AGENTS.md`를 통해 Boss 역할을 수행하므로, 또 다른 Boss를 띄우지 않고 곧바로 전문가에게 위임합니다. 네이티브 세션 정체성은 Codex/root로 유지되며, 재설치는 관리 지침을 갱신하되 사용자가 수정한 구간은 보존합니다.

| 단계 | 동작 |
|-------|--------------|
| **0 · 탐색** | 런타임에 `~/.codex/agents/*.toml`을 스캔해 실시간 역량 레지스트리를 구성 |
| **1 · 의도 게이트** | 요청을 분류(trivial, build, refactor, mid-sized, architecture, research, …)하고 더 잘 맞는 스킬이 있으면 역제안 |
| **2 · 역량 매칭** | 아래 우선순위 체인을 순차 적용(P1 정확한 스킬 → P2 전문가 에이전트 → P3 멀티 에이전트 오케스트레이션 → P4 범용 폴백) |
| **3 · 위임** | 6개 섹션으로 구조화한 프롬프트와 함께 `spawn_agent` 호출: TASK / OUTCOME / TOOLS / DO / DON'T / CTX |
| **4 · 검증** | 변경된 파일을 독립적으로 읽고 테스트·린트·빌드를 실행하며 원래 의도와 대조, 실패 시 최대 3회 재시도 |

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
| 최상위 오케스트레이션 | `gpt-6-astra` | Boss |
| 심층 분석, 아키텍처, 리뷰 | `gpt-6-astra` | Oracle, Prometheus, Sisyphus, Hephaestus, Atlas, Metis, Momus, architect, planner, code-reviewer, security-reviewer |
| 표준 구현 | `gpt-5.6-sol` | Librarian, Multimodal-Looker, executor, test-engineer, debugger 및 팩 에이전트 17개 중 15개 |
| 빠른 조회, 가벼운 분석 | `gpt-5.6-terra` | data-analyst, prompt-regression-tester |

세 가지 티어 ID는 단일 파일 `scripts/model-tiers.sh`에 있습니다. `scripts/md-to-toml.sh`와 `install.sh`가 이 파일을 함께 참조하며, 스크립트 다른 곳에 모델 ID가 하드코딩되면 `scripts/check-model-drift.sh`가 빌드를 실패시킵니다.

### 추론 강도 티어

모델 선택이 *어떤* 두뇌가 작업을 맡을지를 정한다면, 같은 TOML의 `model` 옆에 있는 `model_reasoning_effort`는 *얼마나 깊이* 생각할지를 정합니다. Boss와 OMO 에이전트 9개는 `codex-agents/` 아래 커밋된 파일에서 직접 선언하고, oh-my-codex 작업자 7개는 변환 시점에 `scripts/md-to-toml.sh`의 역할 표에서 값을 받으며, 팩 에이전트는 각자의 값을 가집니다:

| 추론 강도 | 에이전트 |
|--------|--------|
| `xhigh` | Boss, Oracle, Prometheus, architect |
| `high` | Sisyphus, Hephaestus, Atlas, Metis, Momus, planner, code-reviewer, security-reviewer 및 팩 에이전트 17개 중 15개 |
| `medium` | Librarian, Multimodal-Looker, executor, test-engineer, debugger, data-analyst, prompt-regression-tester |

### 3단계 스프린트 워크플로

엔드투엔드 기능 구현을 위해 Boss는 구조화된 스프린트를 오케스트레이션합니다:

| 단계 | 모드 | 동작 |
|-------|------|--------------|
| **1 · 설계** | 대화형 | 사용자가 범위 결정 · 엔지니어링 리뷰 · "설계 완료" 확인 |
| **2 · 실행** | 자율 | executor가 작업 수행 · 자동 코드 리뷰 · architect 검증 |
| **3 · 리뷰** | 대화형 | 설계 문서와 대조 · 비교 표 제시 · 사용자가 승인하거나 개선 요청 |

### 정형화된 최종 보고

Boss는 작업이 있던 모든 턴 — 파일 편집, 커밋/PR, 설정 변경, 검증 실행이 있었던 턴 — 을 diff를 열지 않고도 훑어볼 수 있는 정형화된 최종 보고로 마무리합니다. 보고는 고정된 표 5종으로 구성되며, 각 표는 해당 상황이 실제로 발생했을 때만 출력됩니다(빈 표는 만들지 않음):

| 상황 | 표 | 컬럼 |
|-----------|-------|---------|
| 파일/설정 변경 | 변경 대조 (Changes) | 대상 / Before / After / 근거 |
| 여러 작업 완료 | 작업 요약 (Work summary) | 항목 / 결과 / 근거 |
| 검증 실행 | 검증 결과 (Verification) | 항목 / 기대 / 실제 / 판정 |
| 커밋/PR 산출 | 산출물 (Deliverables) | PR / 저장소 / 내용 / 상태 |
| 미해결 존재 | 남은 것 (Remaining) | 항목 / 상태 / 다음 조치 |

이 보고는 요청의 맨 마지막에만 발동하며 — 백그라운드 작업을 띄우거나 그 완료를 중계하는 턴, 작업 중간의 진행 상황 보고로는 절대 출력되지 않음 — 순수 질답 턴은 보고 없이 정상 종료됩니다. 규격은 `boss.toml`의 developer instructions와 `~/.codex/AGENTS.md`에 함께 담겨 있어 메인 세션에서도 볼 수 있습니다. Stop 훅(`hooks/stop-final-report.js`)이 이를 강제합니다. 상태를 변경한 턴이 보고 테이블 없이 끝나면 훅이 그 턴을 한 번 차단하고 보고를 요구합니다.

---

## 구성 요소

| 카테고리 | 수량 | 출처 |
|----------|------:|--------|
| **핵심 에이전트** (항상 로드됨) | 17 | Boss 1 + OMO 9 + OMX 7 |
| **에이전트 팩** (옵트인, 기본 비활성) | 17 | 벤더링된 2개 카테고리: data-ai 13 + llmops 4 |
| **노출 스킬** (기본 `core` 프로필) | 30 | 항상 켜져 있는 집합. 나머지는 레인 플래그 하나로 추가 |
| **설치 스킬** (디스크상의 파일) | 107 | ECC 61 · gstack 27 · Superpowers 14 · Core 4 · archify 1 |
| **MCP 서버** | 5 | Context7, Exa, grep.app, Serena, Headroom |
| **config.toml** | 1 | my-codex |
| **AGENTS.md** | 1 | my-codex |

위의 모든 에이전트와 스킬은 [`scripts/skill-allowlists.sh`](../../scripts/skill-allowlists.sh)에 허용목록으로 등재되어 있으며, 이 파일이 무엇을 설치할지 결정하는 기준입니다. 이 번들 자체는 `pdf`, `docx`, `pptx`, `xlsx`를 제공하지 않으며, 외부에서 설치한 같은 종류의 스킬은 그대로 보존합니다.

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
| Sisyphus | gpt-6-astra high | 의도 분류 → 전문가 위임 → 검증 | oh-my-openagent |
| Hephaestus | gpt-6-astra high | 자율적 탐색 → 계획 → 실행 → 검증 | oh-my-openagent |
| Atlas | gpt-6-astra high | 작업 분해 + 4단계 QA 검증 | oh-my-openagent |
| Oracle | gpt-6-astra xhigh | 전략적 기술 컨설팅 (읽기 전용) | oh-my-openagent |
| Metis | gpt-6-astra high | 의도 분석, 모호성 탐지 | oh-my-openagent |
| Momus | gpt-6-astra high | 계획 실현 가능성 검토 | oh-my-openagent |
| Prometheus | gpt-6-astra xhigh | 인터뷰 기반 세부 계획 수립 | oh-my-openagent |
| Librarian | gpt-5.6-sol medium | MCP를 통한 오픈소스 문서 검색 | oh-my-openagent |
| Multimodal-Looker | gpt-5.6-sol medium | 이미지/스크린샷/다이어그램 분석 | oh-my-openagent |

</details>

<details>
<summary><strong>OMX 에이전트 — 전문가 작업자 (7)</strong></summary>

| 에이전트 | 샌드박스 | 역할 | 출처 |
|-------|---------|------|--------|
| executor | workspace-write | 코드 구현 | oh-my-codex |
| planner | read-only | 구현 계획 수립 | oh-my-codex |
| architect | read-only | 시스템 설계 및 아키텍처 | oh-my-codex |
| test-engineer | workspace-write | 테스트 전략 및 커버리지 | oh-my-codex |
| security-reviewer | read-only | 보안 분석 | oh-my-codex |
| code-reviewer | read-only | 집중적인 코드 리뷰 | oh-my-codex |
| debugger | workspace-write | 근본 원인 분석 | oh-my-codex |

</details>

<details>
<summary><strong>에이전트 팩 — 옵트인 AI 전문가 (2개 팩, 17개 에이전트)</strong></summary>

| 팩 | 수량 | 에이전트 |
|------|------:|---------|
| data-ai | 13 | ai-engineer, data-analyst, data-engineer, data-scientist, database-optimizer, llm-architect, machine-learning-engineer, ml-engineer, mlops-engineer, nlp-engineer, postgres-pro, prompt-engineer, reinforcement-learning-engineer |
| llmops | 4 | ai-observability-engineer, eval-engineer, hallucination-investigator, prompt-regression-tester |

`~/.codex/agent-packs/`에 설치되며 옵트인하기 전까지 비활성 상태입니다 — [에이전트 팩 프로필](#에이전트-팩-프로필)을 참조하세요.

</details>

<details>
<summary><strong>스킬 — 기본 노출 30개, 5개 출처에서 107개 설치</strong></summary>

| 출처 | 설치 | 주요 스킬 |
|--------|------:|------------|
| everything-claude-code | 61 | coding-standards, python-testing, api-design, deep-research |
| gstack | 27 | /qa, /review, /ship, /cso, /investigate, /office-hours |
| superpowers | 14 | brainstorming, systematic-debugging, TDD, writing-plans |
| [my-codex Core](https://github.com/sehoon787/my-codex) | 4 | boss-advanced, boss-briefing, briefing-vault, gstack-sprint |
| archify | 1 | archify (아키텍처·워크플로·시퀀스·데이터 흐름·라이프사이클 다이어그램) |

gstack은 허용목록 스킬 26개에 저장소 루트 항목을 더해 27개로 집계됩니다. 전체 체크아웃은 `~/.codex/vendor/gstack`에 있고 `~/.codex/skills/gstack`은 런타임 퍼사드입니다. 어떤 프로필을 쓰든 실제 스킬 파일은 설치된 상태로 남고 바뀌는 것은 노출 범위뿐입니다. [스킬 프로필과 레인](#스킬-프로필과-레인)을 참조하세요.

</details>

<details>
<summary><strong>호스팅 MCP 서버 (5개 중 3개)</strong></summary>

나머지 둘은 Serena와 Headroom이며 모두 로컬 stdio 서버입니다.

| 서버 | 목적 | 비용 |
|--------|---------|------|
| <img src="https://context7.com/favicon.ico" width="16" height="16" align="center"/> [Context7](https://context7.com) | 실시간 라이브러리 문서 | 무료 |
| <img src="https://exa.ai/images/favicon-32x32.png" width="16" height="16" align="center"/> [Exa](https://exa.ai) | 시맨틱 웹 검색 | 월 1천 건 무료 |
| <img src="https://www.google.com/s2/favicons?domain=grep.app&sz=32" width="16" height="16" align="center"/> [grep.app](https://github.com/grep-app) | GitHub 코드 검색 | 무료 |

</details>

---

## <img src="https://obsidian.md/images/obsidian-logo-gradient.svg" width="24" height="24" align="center"/> Briefing Vault

Obsidian 호환 영구 메모리입니다. 모든 프로젝트는 네이티브 플러그인 훅으로 Codex 세션 중 갱신되는 `.briefing/` 디렉터리를 유지하며, 세션 시작·종료 연속성은 래퍼 폴백이 보완합니다:

```
.briefing/
├── INDEX.md                          ← 프로젝트 컨텍스트 (최초 자동 생성)
├── state.json                        ← 세션 메타데이터, 카운터, lastVaultSync (자동 관리)
├── sessions/
│   ├── YYYY-MM-DD-<topic>.md        ← 사람/에이전트가 쓰는 후속 세션 요약
│   └── YYYY-MM-DD-auto.md           ← 자동 생성 스캐폴드 (기록된 파일, 필터링된 상태, 후속 항목)
├── decisions/
│   └── YYYY-MM-DD-<decision>.md     ← 사람/에이전트가 쓰는 의사결정 기록
├── learnings/
│   ├── YYYY-MM-DD-<pattern>.md      ← 사람/에이전트가 쓰는 학습 노트
│   └── YYYY-MM-DD-auto-session.md   ← 자동 생성 스캐폴드 (파일, 래퍼 활동, 프롬프트)
├── references/
│   └── auto-links.md                ← 수집된 조사 링크용
├── archives/                         ← PARA: 완료/비활성 노트 (플랫)
├── wiki/                             ← LLM-wiki: 개념 페이지
│   └── _schema.md
├── agents/
│   ├── agent-log.jsonl              ← 래퍼/세션 로그
│   └── YYYY-MM-DD-summary.md        ← 일별 기록 신호 요약
└── persona/
    ├── profile.md                   ← 기록된 신호에서 도출한 라우팅/프로필 요약
    ├── suggestions.jsonl            ← 라우팅 제안 (자동 생성)
    ├── persona-policy.json          ← Boss가 수용한 소프트 라우팅 선호
    └── rules/                       ← 워크플로 패턴 규칙 (workflow-*.md)
```

### 지식 관리 (v2)

BriefingVault v2는 세 가지 지식 관리 방법론을 통합합니다:

| 방법론 | 적용 방식 |
|------------|-----------|
| **PARA** (Tiago Forte) | 디렉터리 구조: sessions=프로젝트, decisions=영역, references=리소스, archives=아카이브 |
| **Zettelkasten** (Luhmann) | `learnings/`의 원자적 노트, 고유 ID(`YYYYMMDDHHMMSS`), `[[wiki-links]]` 필수 |
| **LLM-wiki** (Karpathy) | `wiki/`의 개념 페이지 — 키워드가 3회 이상 등장하면 자동 제안 |

Codex CLI 세션 종료 훅은 자동으로 다음을 수행합니다:

- 30일 이상 지난 노트의 아카이브 제안
- 자주 언급된 개념의 위키 페이지 제안
- 새 노트를 위한 고유 Zettelkasten ID 생성

### 세션별 Diff

세션 시작 시 my-codex는 현재 git HEAD와 작업 트리 상태 스냅샷을 저장합니다. 세션 중에는 네이티브 Codex 훅이 프롬프트, 편집, 검색, 서브에이전트 완료 이후 `.briefing` 스캐폴드를 갱신합니다. 세션 종료 시 최종 스캐폴드는 기록된 경로에 대해서만 diff와 상태를 요약하며, `.briefing/` 산출물이나 세션 시작 시의 `.gitignore` 편집 같은 훅이 만든 잡음은 걸러냅니다.

덕분에 스캐폴드는 저장소 전체 상태를 쏟아내지 않고 그 세션이 한 일에 집중합니다. git이 아닌 프로젝트에서는 `YYYY-MM-DD:cwd` 식별자를 폴백으로 사용합니다.

### Obsidian과 함께 사용하기

1. Obsidian 열기 → **폴더를 보관함으로 열기** → `.briefing/` 선택
2. 노트가 그래프 뷰에 `[[wiki-links]]`로 연결되어 표시됩니다
3. YAML 프론트매터(`date`, `type`, `tags`)로 구조화 검색이 가능합니다
4. 세션과 학습의 타임라인 스캐폴드가 자동으로 쌓이고, 후속 요약·의사결정·학습 노트는 직접 쓰는 만큼 축적됩니다

### /boss-briefing

세션 중이나 마지막에 `/boss-briefing`을 실행하면 다음을 수행합니다:

- **볼트 동기화**: profile.md, INDEX.md, 에이전트 요약 갱신
- **워크플로 패턴 탐지**: 세션 전반의 시간순 에이전트 호출 시퀀스 분석
- **공백 복구**: 마지막 세션 이후 며칠이 지났다면 복구 요약 생성
- **페르소나 규칙 제안**: 빈도만이 아닌 워크플로 기반 라우팅 선호 제안
- **세션 노트 검증**: 오늘 세션에 제대로 된 요약이 있는지 확인

Stop 훅은 오늘 `/boss-briefing`이 실행되었는지 확인합니다. 실행되지 않았다면 알림과 함께 세션 종료를 차단합니다. 기존 `stop-profile-update.js`는 폴백으로 계속 동작합니다.

### 서브 볼트

| 경로 | 설명 |
|------|-------------|
| `INDEX.md` | 최근 의사결정과 학습으로 연결되는 프로젝트 개요. 첫 세션에 자동 생성되고 주기적으로 갱신됩니다. |
| `sessions/` | **세션 요약.** `*-auto.md` — 세션 중 갱신되고 종료 시 기록된 세션 파일·필터링된 상태·기록 신호로 마무리되는 자동 스캐폴드. `<topic>.md` — 볼트 알림이 유도하는 사람/에이전트 작성 후속 요약. |
| `decisions/` | **아키텍처·설계 의사결정**과 그 근거. 남길 가치가 있는 결정이라면 지속적인 노트로 작성하세요. |
| `learnings/` | **패턴, 함정, 뻔하지 않은 해법.** `*-auto-session.md` — 세션의 기록된 파일 목록·신호·후속 프롬프트로 세션 중 갱신되는 자동 스캐폴드. `<topic>.md` — 사람/에이전트 작성 학습 노트. |
| `references/` | **웹 조사 URL.** 네이티브 Codex 훅을 사용할 수 있을 때 `references/auto-links.md`가 `WebSearch`/`WebFetch` 훅 활동으로 갱신됩니다. |
| `agents/` | **기록된 세션 신호.** `agent-log.jsonl` — `{ts, agent_id, agent_type, phase, seq, task_hint}` 항목. `YYYY-MM-DD-summary.md` — 그 로그에서 도출한 일별 요약. |
| `persona/` | **사용자 작업 스타일 프로필.** `profile.md` — 기록 신호 기반 라우팅/프로필 요약. `suggestions.jsonl` — 라우팅 제안. `persona-policy.json` — 수용된 소프트 라우팅 선호. `rules/workflow-*.md` — `/boss-briefing`이 제안한 워크플로 시퀀스 규칙. |
| `state.json` | 세션 메타데이터: 카운터, lastVaultSync, sessionStartHead. 훅이 자동 관리합니다. |
| `archives/` | PARA 아카이브 — 완료된 세션(30일+), 대체된 의사결정, 비활성 학습 |
| `wiki/` | LLM-wiki 개념 페이지 — 여러 세션에 걸쳐 정제된 지식 |

### 동작 훅

| 훅 | 이벤트 | 동작 |
|------|-------|----------|
| Session Setup | SessionStart | 도구 자동 감지 + Briefing Vault 컨텍스트 주입 |
| Delegation Guard | PreToolUse | Boss 모드인 세션에 파일 편집을 직접 하지 말고 위임하라고 상기 |
| Agent Telemetry | PostToolUse | 에이전트 사용량을 `~/.gstack/analytics/agent-usage.jsonl`에 기록 |
| Vault Enforcer | PostToolUse | 편집 횟수를 세고 세션 중 자동 스캐폴드를 갱신 |
| Link Collector | PostToolUse | `WebSearch`/`WebFetch` 결과를 `references/auto-links.md`에 추가 |
| Subagent Logger | SubagentStop | 에이전트 실행을 Briefing Vault에 기록 |
| Vault Reminder | UserPromptSubmit | 메시지 5회 이상이면 /boss-briefing을, 기록된 작업이 쌓이면 실제 세션 노트를 제안 |
| Context Budget | UserPromptSubmit | 마지막 압축 이후 40번째 프롬프트마다(`MY_CODEX_COMPACT_EVERY`) 다음 작업 경계에서 `/compact`를 제안 |
| Context Budget reset | PostCompact | 압축 후 해당 카운터를 0으로 초기화 |
| Completion Check | Stop | 프로필 폴백 실행 + /boss-briefing 확인 |
| Final Report Gate | Stop | 작업이 있었는데 최종 보고 표가 없으면 턴을 한 번 차단 |

Codex는 `features.hooks = true`일 때만 `~/.codex/hooks.json`에서 이 훅들을 읽어들이므로, `install.sh`가 해당 경로에 파일을 쓰고 `config.toml`의 `[features]` 아래에 플래그를 설정합니다. 다음 대화형 Codex 시작 시 훅을 검토하고 신뢰할지 한 번 묻는데 "Trust all and continue"를 선택하세요. 그 전에는 어떤 훅도 실행되지 않습니다.

---

## 결과를 확인하는 곳

설치된 도구는 저마다 결과를 남깁니다. 그 위치입니다.

| 도구 | 실행 방법 | 결과 확인 위치 |
|------|------------|----------------------|
| **codeburn** | 설치 프로그램이 `codeburn web --provider all --port 4747 --no-open`을 시작합니다. `codeburn`은 대화형 대시보드를, 비대화형은 `codeburn report --format json --period week --provider codex`(`--day`, `--from`/`--to`도 가능)를 사용합니다 | 공유 브라우저 대시보드 <http://127.0.0.1:4747/>, 터미널 TUI, 또는 stdout JSON. 세션 파일은 읽기 전용이며 금액은 공개 정가 기준 추정치이지 청구서가 아닙니다. |
| **Serena** | Codex가 `[mcp_servers.serena]`로 기동합니다. 도구는 `get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `replace_symbol_body`, `insert_after_symbol`로 나타납니다 | 서버 실행 중 <http://localhost:24282/dashboard/index.html> 에서 대시보드와 도구 호출 통계를 확인합니다. 프로젝트별 인덱스·메모리는 `<저장소>/.serena/`에 있고 브라우저는 자동으로 열리지 않습니다(`--open-web-dashboard False`). |
| **Headroom** | Codex가 `[mcp_servers.headroom]`(`headroom mcp serve`)로 MCP 서버를 기동하고, 설치 프로그램이 `headroom install apply --profile agent-harness-shared --preset persistent-service --runtime python --providers manual --port 8787 --no-telemetry --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1`을 실행합니다 | 프록시 통계는 <http://127.0.0.1:8787/stats>. `headroom wrap` 또는 base URL로 클라이언트를 명시적으로 라우팅하기 전에는 비어 있습니다. |
| **Archify** | `~/.codex/skills/archify`에서 `node bin/archify.mjs render <type> <input>.json <output>.html` 실행 후 `node bin/archify.mjs check <output>.html` | 지정한 `<output>.html` — 브라우저로 열면 됩니다. 스킬에 함께 설치되는 `examples/*.json`이 그대로 베껴 쓸 수 있는 완성된 입력 예제입니다. |

---

## GitHub Actions

| 워크플로 | 트리거 | 목적 |
|----------|---------|---------|
| **CI** | push, PR | TOML 에이전트 파일, 스킬 존재 여부, 업스트림 파일 수 검증 |
| **Smoke Tests** | push, PR | `hooks`, `shell`, `drift`, `routing-refs` 작업 — 훅 연결, 셸 문법, 모델 드리프트, AGENTS.md 라우팅 참조 검증 |
| **Update Upstream** | 3일마다 / 수동 | 브랜치를 추적하는 서브모듈 4개에 보안 게이트가 적용된 `git submodule update --remote`, `upstream/SOURCES.json` 핀 갱신, 자동 병합 PR 생성 |
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
| **비용 최적화** | 단일 파일(`scripts/model-tiers.sh`)에서 관리하는 모델 티어 3종을 설치되는 34개 에이전트 전체에 적용 |
| **스킬 노출 프로필** | 카탈로그 210개 항목에 기본 30개 노출, 선택 레인 13개, 스냅샷과 롤백까지 — 스킬 예산을 그 세션에 필요한 것에만 씁니다 |
| **브리핑 신호** | 래퍼/세션 로깅이 `.briefing/agents/agent-log.jsonl`, 일별 요약, 라우팅/프로필 힌트를 채웁니다 |
| **Smart Packs** | 프로젝트 유형 감지로 세션 시작 시 관련 에이전트 팩 추천 |
| **에이전트 팩 시스템** | `--profile` 및 `my-codex-packs` 헬퍼를 통한 온디맨드 도메인 전문가 활성화 |
| **Codex Attribution** | git 훅이 Codex가 수정한 파일을 기록하고 커밋 메시지에 `AI-Contributed-By: Codex` 추가 |
| **CI 중복 탐지** | 업스트림 동기화 시 TOML 에이전트 중복 자동 감지 |

---

## 번들된 업스트림 버전

git 서브모듈로 연결합니다. 고정 커밋은 `.gitmodules`가 기본으로 추적하고 [`upstream/SOURCES.json`](../../upstream/SOURCES.json)에 AI-BOM으로 미러링되며, 이 파일은 companion CLI와 MCP 서버의 버전도 고정하고 제거된 서브모듈 2개도 기록합니다. `install.sh`는 `main`을 추적하는 대신 아래의 정확한 SHA를 체크아웃합니다.

| 출처 | SHA | 날짜 | 비교 |
|--------|-----|------|------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `07756ce` | 2026-09-19 | [compare](https://github.com/affaan-m/everything-claude-code/compare/07756ce...HEAD) |
| [gstack](https://github.com/garrytan/gstack) | `a6b3a57` | 2026-09-16 | [compare](https://github.com/garrytan/gstack/compare/a6b3a57...HEAD) |
| [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | `cb955b0` | 2026-09-13 | [compare](https://github.com/Yeachan-Heo/oh-my-codex/compare/cb955b0...HEAD) |
| [superpowers](https://github.com/obra/superpowers) | `5bf4e78` | 2026-09-19 | [compare](https://github.com/obra/superpowers/compare/5bf4e78...HEAD) |
| [archify](https://github.com/tt-a1i/archify) | `62904f3` (`v2.9.0`) | 2026-09-19 | [compare](https://github.com/tt-a1i/archify/compare/62904f3...HEAD) |

---

## 설치 옵션

동일한 명령을 다시 실행하면 최신 `main` 빌드로 갱신되고, `~/.codex/`에서 my-codex가 관리하는 파일만 교체되며, `~/.agents/skills/`에서 오래된 스킬 사본이 제거됩니다.

### 스킬 프로필과 레인

my-claude는 고정된 허용목록 하나를 설치하지만, my-codex는 스킬 파일 107개를 설치한 뒤 그중 몇 개를 Codex가 실제로 보게 할지 제어합니다. Codex는 스킬 예산을 넘어서면 스킬 설명을 잘라내므로, 초점 없는 카탈로그는 모든 설명의 유용성을 떨어뜨립니다. 번들 스킬 소스를 모두 선택한 신규 설치의 기본값인 `core`는 스킬 30개를 노출하고, 각 레인은 그 위에 더해집니다:

| 프로필 / 레인 | 추가되는 것 | 수량 | 활성화 방법 |
|----------------|--------------|------:|---------------|
| `core` | 항상 켜져 있는 집합: my-codex 코어 스킬, superpowers 개발 프로세스 레인, gstack 배포/QA/리뷰 라우터, ECC 표준 | 30 | 기본값. 되돌릴 때는 `--skill-profile=core` |
| `legacy` | 마이그레이션 이전 노출. `--skip-ecc`, `--skip-gstack`, `--skip-superpowers`, `--skip-archify`로 core 소스를 생략하고 프로필을 명시하지 않으면 자동 선택 | 가변 | `--skill-profile=legacy` |
| `full` | 모든 레인을 한 번에. 컨텍스트 예산을 넘을 수 있습니다 | 210 | `--skill-profile=full` 또는 `--full-skills` |
| `workflow-advanced` | 고급 계획 수립, 저장소 운영, worktree 워크플로 | 13 | `--skills=workflow-advanced` |
| `qa-operations` | QA, 브라우저 점검, 릴리스, 배포, 운영 안전 | 20 | `--skills=qa-operations` |
| `ai-engineering` | 에이전트 시스템, 평가, 프롬프트, 검색, MCP | 18 | `--skills=ai-engineering` |
| `backend-data` | 백엔드 아키텍처, 데이터베이스, 캐싱, 컨테이너, API | 13 | `--skills=backend-data` |
| `python` | Python, Django, FastAPI 구현과 테스트 | 9 | `--skills=python` |
| `jvm` | Java, Kotlin, JPA, Spring 구현과 테스트 | 11 | `--skills=jvm` |
| `web` | 웹 프레임워크, 접근성, 성능, 엔드투엔드 테스트 | 18 | `--skills=web` |
| `mobile` | Android, Flutter, Swift, SwiftUI 엔지니어링 | 9 | `--skills=mobile` |
| `other-languages` | C++, Go, Laravel, Perl, Rust 엔지니어링 | 13 | `--skills=other-languages` |
| `research-content` | 리서치, 기술 콘텐츠, 마켓 작업, 아웃리치 | 11 | `--skills=research-content` |
| `media-documents` | 미디어 생성, 문서 처리, OCR, 번역 | 7 | `--skills=media-documents` |
| `business-domains` | 물류, 품질, 생산, 조달, 무역 | 8 | `--skills=business-domains` |
| `alternative-workflows` | 선택적 오케스트레이션, TDD, 리뷰, 검증 체계 | 30 | `--skills=alternative-workflows` |

선택한 값은 `~/.codex/my-codex/skill-catalog-state.json`에, 호환 기록은 `~/.codex/enabled-skill-lanes.txt`에 유지되므로 이후 `bash install.sh`를 그대로 실행해도 보존됩니다. `MY_CODEX_SKILLS=web`은 `--skills=web`과 동일하며, 상태가 없는 기존 비대화형 설치는 현재 노출을 유지합니다. 프로필을 바꿔도 실제 스킬 파일은 제거되지 않습니다 — 선택 항목은 Codex가 지원하는 경로별 스킬 설정으로 숨기며, 알 수 없는 스킬과 `~/.agents/skills/`, `~/.claude/skills/` 아래 파일은 건드리지 않습니다.

설치 후에는 `my-codex-skills` CLI로 노출을 관리합니다:

```bash
my-codex-skills list                     # 모든 카탈로그 항목과 레인
my-codex-skills status                   # 활성 프로필과 활성 레인
my-codex-skills doctor                   # 카탈로그/상태 불일치 점검
my-codex-skills enable python web        # 레인 추가
my-codex-skills disable web              # 레인 제거
my-codex-skills set-profile core         # core | legacy | full
my-codex-skills source benchmark gstack  # 같은 이름을 제공하는 출처가 둘일 때 선택
my-codex-skills restore latest           # 스냅샷으로 롤백
```

카탈로그는 `~/.codex/lib/my-codex/skill-catalog.json`, 스냅샷은 `~/.codex/my-codex/skill-catalog-snapshots/<id>.json`에 있습니다. 레인을 활성화하면 누락된 payload를 고정된 로컬 vendor에서 가져올 수 있으며, 가져올 수 없으면 상태와 설정을 바꾸지 않고 CLI가 `install.sh --skills=<lane>`을 안내합니다.

### 에이전트 팩 프로필

팩은 설치되지만 **기본적으로 비활성 상태**입니다. 신규 설치는 활성 팩 없이 빈 세트를 `~/.codex/enabled-agent-packs.txt`에 기록합니다. 팩 단위로 옵트인하거나 프로필을 선택하세요:

```bash
# 현재 상태 확인
~/.codex/bin/my-codex-packs status
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

`~/.codex/config.toml`의 글로벌 Codex 설정:

```toml
[agents]
max_threads = 8
max_depth = 1
```

- `max_threads` — 최대 동시 서브에이전트 수
- `max_depth` — 에이전트가 에이전트를 스폰하는 체인의 최대 중첩 깊이

---

## FAQ

<details>
<summary><strong>my-codex와 my-claude의 차이점은 무엇인가요?</strong></summary>

Boss 오케스트레이션은 같고 런타임이 다릅니다. my-codex는 네이티브 `.toml` 에이전트 형식과 `spawn_agent` 위임으로 OpenAI Codex CLI를 대상으로 하고, my-claude는 `.md` 에이전트 형식과 Agent 도구로 Claude Code를 대상으로 합니다. 또한 my-codex는 프로필과 레인으로 스킬 노출을 제어하는 반면 my-claude는 고정된 허용목록 하나를 설치합니다.

</details>

<details>
<summary><strong>my-codex와 my-claude를 함께 사용할 수 있나요?</strong></summary>

네. 각각 별도 디렉터리(`~/.codex/`와 `~/.claude/`)에 설치됩니다. 두 설치 프로그램은 `${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services`의 사용자 단위 잠금·상태 디렉터리로 codeburn과 Headroom을 조율하며, 정상 서비스는 재사용하고 고정 포트를 점유한 외부 프로세스는 죽이지 않고 보고만 합니다.

</details>

<details>
<summary><strong>에이전트 팩은 어떻게 작동하나요?</strong></summary>

[에이전트 팩 프로필](#에이전트-팩-프로필)을 참조하세요.

</details>

<details>
<summary><strong>업스트림 동기화는 어떻게 이루어지나요?</strong></summary>

[GitHub Actions](#github-actions)의 **Update Upstream** 행을 참조하세요. `upstream/archify`는 태그 고정이라 의도적으로만 올리므로 작업은 나머지 서브모듈 4개만 건드리며, Actions 탭에서 수동으로 트리거할 수도 있습니다.

</details>

<details>
<summary><strong>my-codex는 어떤 모델을 사용하나요?</strong></summary>

[모델 라우팅](#모델-라우팅)과 [추론 강도 티어](#추론-강도-티어)를 참조하세요. 스킬은 SKILL.md 표준을 변환 없이 그대로 사용하며, 변환되는 것은 에이전트뿐이고 그 변환에 쓰이는 모델 티어는 단일 파일 `scripts/model-tiers.sh`에서 관리합니다.

</details>

---

## 문제 해결

### 스킬만 복구

`~/.agents/skills/`의 `SKILL.md` 파일이 유효하지 않다고 보고되는 경우, 가장 일반적인 원인은 이전 설치의 오래된 로컬 사본이나 오래된 심볼릭 링크 대상입니다. `~/.agents/skills/`의 해당 디렉터리와 `~/.claude/skills/`의 대응 항목을 제거한 후 재설치하세요:

```bash
npx skills add sehoon787/my-codex -y -g
```

전체 Codex 번들을 사용하는 경우 `install.sh`도 한 번 다시 실행하세요. 전체 인스톨러는 `~/.codex/skills/`를 갱신하고 `~/.agents/skills/`에서 오래된 my-codex 관리 사본을 제거합니다.

---

## 기여

이슈와 PR을 환영합니다. 새 에이전트를 추가할 때는 `codex-agents/core/` 또는 `codex-agents/omo/`에 `.toml` 파일을 추가하고 `SETUP.md`의 에이전트 목록을 업데이트하세요. PR 검증 단계와 Codex 커밋 attribution 동작은 [CONTRIBUTING.md](../../CONTRIBUTING.md)를 참조하세요.

## 크레딧

[사용한 오픈소스 도구](#사용한-오픈소스-도구)에 정리된 프로젝트들을 기반으로 구축되었습니다. 모든 작성자에게 감사드립니다. 이 하네스가 대상으로 삼는 런타임 [OpenAI Codex CLI](https://github.com/openai/codex), 그리고 스킬 전용 번들을 설치하는 `npx skills` CLI를 제공하는 [openai/skills](https://github.com/openai/skills)에도 감사드립니다.

## 라이선스

MIT 라이선스. 자세한 내용은 [LICENSE](../../LICENSE) 파일을 참조하세요.
