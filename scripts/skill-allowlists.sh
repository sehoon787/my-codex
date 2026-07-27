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
ECC_SKILL_ALLOWLIST="
accessibility
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
bun-runtime
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
e2e-testing
error-handling
eval-harness
exa-search
fastapi-patterns
frontend-a11y
frontend-patterns
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
motion-advanced
motion-foundations
motion-patterns
mysql-patterns
nestjs-patterns
nextjs-turbopack
nuxt4-patterns
postgres-patterns
prisma-patterns
prompt-optimizer
python-patterns
python-testing
react-patterns
react-performance
react-testing
redis-patterns
regex-vs-llm-structured-text
repo-scan
security-scan
springboot-patterns
springboot-security
springboot-tdd
springboot-verification
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
# The 26 skills Boss P0 routing depends on. The gstack repo itself is installed
# whole into ~/.codex/skills/gstack (canonical runtime tree); this list controls
# only which subdirectories are additionally surfaced at ~/.codex/skills/<name>.
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
