#!/usr/bin/env bash
#
# skill-allowlists.sh — single source of truth for which upstream skills and
# agents install.sh actually installs.
#
# Sourced by install.sh; defines variables only, executes nothing. Names are
# whitespace-separated and contain no spaces, so callers iterate with:
#
#   for name in $ECC_SKILL_ALLOWLIST; do ... done
#
# Anything not listed here is never copied. That is deliberate: the upstreams
# ship far more than this stack needs, and unlisted skills are dead weight in
# every session's context.
#
# The ECC/gstack/superpowers lists are mirrored verbatim from the sibling
# my-claude repo (scripts/skill-allowlists.sh) so both installers surface the
# same upstream surface. Keep them in sync — edit there first, copy here.

# ── ECC (everything-claude-code) skills ──
# Kept lanes:
#   1. Stack in use — TS/JS, React/Next/Vue/Nuxt/Nest, Python/Django/FastAPI,
#      Spring Boot/Java/JPA/Kotlin (server), SQL/Redis/Prisma, Docker/K8s/CI,
#      API/backend/frontend/testing/e2e/security/performance patterns.
#   2. AI + agent engineering — agent harness/audit/introspection, eval, prompt,
#      MCP, RAG/retrieval, context and LLM-cost work.
#   3. Generic codebase tooling — onboarding, tours, ADRs, research, lookup.
# Everything else upstream (mobile, other languages, ops/marketing/domain packs,
# and orchestration skills that duplicate omx/gstack) stays out.
#
# This is the DEFAULT lane (61 skills). The web/UI lane lives separately in
# $ECC_SKILL_OPTIONAL_WEB below and is installed only when asked for, because
# every installed skill spends fixed context on its description in every
# session — Codex truncates the descriptions once the skills budget is hit.
ECC_SKILL_ALLOWLIST="
agent-architecture-audit
agent-harness-construction
agent-introspection-debugging
agent-self-evaluation
ai-regression-testing
api-connector-builder
api-design
architecture-decision-records
backend-patterns
benchmark-optimization-loop
click-path-audit
code-tour
codebase-onboarding
coding-standards
content-hash-cache-pattern
context-budget
continuous-learning-v2
cost-aware-llm-pipeline
database-migrations
deep-research
deployment-patterns
django-celery
django-patterns
django-security
django-tdd
django-verification
docker-patterns
documentation-lookup
error-handling
eval-harness
exa-search
fastapi-patterns
generating-python-installer
github-ops
hexagonal-architecture
inherit-legacy-style
iterative-retrieval
java-coding-standards
jpa-patterns
kotlin-coroutines-flows
kotlin-exposed-patterns
kotlin-ktor-patterns
kotlin-patterns
kotlin-testing
kubernetes-patterns
latency-critical-systems
mcp-server-patterns
mysql-patterns
postgres-patterns
prisma-patterns
prompt-optimizer
python-patterns
python-testing
redis-patterns
regex-vs-llm-structured-text
repo-scan
security-scan
springboot-patterns
springboot-security
springboot-tdd
springboot-verification
"

# ── ECC optional lane: web / UI front-end ──
# Installed only with `install.sh --skills=web` (or MY_CODEX_SKILLS=web); the
# choice is persisted in ~/.codex/enabled-skill-lanes.txt so re-running the
# installer keeps it. Split out of $ECC_SKILL_ALLOWLIST because a Codex CLI
# session pays for every skill description up front, and a backend/agent-work
# install never routes to these.
ECC_SKILL_OPTIONAL_WEB="
accessibility
bun-runtime
e2e-testing
frontend-a11y
frontend-patterns
motion-advanced
motion-foundations
motion-patterns
nestjs-patterns
nextjs-turbopack
nuxt4-patterns
react-patterns
react-performance
react-testing
ui-to-vue
vite-patterns
vue-patterns
windows-desktop-e2e
"

# ── ECC rule sets ──
# Mirrored from my-claude for parity. my-codex does not install ECC rules
# (Codex CLI has no ~/.codex/rules loader), so nothing reads this yet; it is
# kept so the two allowlist files stay diffable.
ECC_RULES_ALLOWLIST="
common
java
kotlin
nuxt
python
react
typescript
vue
web
"

# ── gstack skills ──
# The 26 skills Boss P0 routing depends on. Current gstack setup owns its Codex
# skill surface; this list is the narrow fallback when bun/setup is unavailable.
# The full checkout lives outside the recursively scanned skills root.
GSTACK_SKILL_ALLOWLIST="
autoplan
benchmark
browse
canary
careful
cso
design-consultation
design-review
document-release
freeze
guard
investigate
land-and-deploy
office-hours
plan-ceo-review
plan-design-review
plan-devex-review
plan-eng-review
qa
qa-only
retro
review
setup-browser-cookies
setup-deploy
ship
unfreeze
"

# ── omx (oh-my-codex) agents ──
# prompts/*.md converted to ~/.codex/agents/*.toml. Only the lanes
# templates/codex-AGENTS.md advertises are converted; the rest of omx's 37
# prompts duplicate codex-agents/core+omo or were never spawned.
OMX_AGENT_ALLOWLIST="
executor
planner
architect
test-engineer
security-reviewer
code-reviewer
debugger
"

# ── superpowers skills ──
# Installed as a whole except these; dispatching-parallel-agents duplicates the
# Boss delegation path this repo already owns.
SUPERPOWERS_SKILL_EXCLUDE="
dispatching-parallel-agents
"

# ── archify (diagram skill) ──
# Single upstream skill, tag-pinned rather than branch-tracked: install.sh copies
# $ARCHIFY_SKILL_SUBDIR out of the submodule at $ARCHIFY_PINNED_TAG. Kept here so
# check-dangling-refs.sh counts `archify` as installable when boss.toml routes to it.
ARCHIFY_SKILL_NAME="archify"
ARCHIFY_SKILL_SUBDIR="archify"
ARCHIFY_PINNED_TAG="v2.9.0"
