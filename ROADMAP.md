# Roadmap

Prioritized feature roadmap for the AI-Assisted Development Workflow framework.

Context: optimized for solo developers and small teams (2–5 devs) using AI coding assistants.

---

## Milestone 1: Prompt Packs

**Goal:** Specialized prompt templates that load at the right moment during the workflow, dramatically improving AI output quality for specific activities.

Each prompt pack is a reference file in `dev-workflow/references/prompts/` that the SKILL.md loads on demand.

### 1.1 Threat Model Prompt
> Load during: Phase 2 (Plan) — when Security section is needed

Pre-structured questions the AI walks through for any change touching auth, PII, payments, or external inputs:
- Data flow: what data enters, where it's stored, who can access it
- Auth boundaries: what's authenticated, what's authorized, what's public
- Input validation: all new user inputs and how they're validated
- Secrets: new secrets introduced, storage mechanism, rotation plan
- Dependencies: new packages, known vulnerabilities, trust level
- Output: a structured threat summary that goes into the plan's Security section

### 1.2 PR Review Prompt
> Load during: Phase 4 (Build & Test) — before marking implementation complete

AI reviews its own code (or teammate's code) against a structured checklist:
- Correctness: does the code do what the plan says?
- Architecture: does it respect layer boundaries and project conventions?
- Error handling: are failure modes covered, not just happy path?
- Security: no secrets, no injection vectors, input validated?
- Tests: do tests cover behavior (not implementation), can they fail?
- Readability: clear naming, no magic numbers, comments where "why" isn't obvious?
- Performance: no N+1 queries, no unbounded loops, no blocking calls in async paths?
- Output: list of issues by severity (must-fix / should-fix / nit)

### 1.3 Refactor Safety Prompt
> Load during: Phase 2 (Plan) — when task is a refactor

Behavior preservation verification:
- Before: capture current behavior (test outputs, API responses, UI states)
- Invariants: define what must not change (public API signatures, DB schema, config format)
- After: verify all invariants hold post-refactor
- Regression: specific tests to run that would catch accidental behavior changes
- Output: a "refactor safety contract" section in the plan

### 1.4 Test Strategy Prompt
> Load during: Phase 2 (Plan) — for any task with new code paths

Guides the AI to think about testing before writing code:
- What behaviors need tests (not what code needs coverage)
- Test sizes: which are unit (fast, no IO), integration (real DB/API), E2E (full stack)
- What to mock vs. what to use real implementations for
- Edge cases from the plan's risk section that need explicit tests
- Flake prevention: no time-dependent tests, no order-dependent tests, no shared state
- Output: a test plan that becomes part of the implementation plan

### 1.5 Migration Prompt
> Load during: Phase 2 (Plan) — when task involves DB or data changes

Database and data migration safety:
- Forward migration: what schema/data changes
- Backward compatibility: can old code run against new schema during rollout?
- Rollback migration: can we reverse this without data loss?
- Data backfill: if existing data needs transformation, what's the strategy?
- Zero-downtime: can this migration run while the app is serving traffic?
- Output: migration section in the plan with explicit rollback steps

### 1.6 Release Notes Generator
> Load during: Phase 5 (Document)

AI generates user-facing release notes from the plan and implementation:
- Summarize changes in non-technical language
- Group by: features, improvements, fixes, breaking changes
- Include migration instructions if applicable
- Diff-based: compare against actual git changes, not just the plan
- Output: draft release notes for human review

---

## Milestone 2: Multi-Agent Automation

**Goal:** Reduce manual overhead of mega task decomposition. Today: user manually creates branches, pastes briefs, starts sessions. Target: one command or one prompt kicks off the full parallel workflow.

### 2.1 Decompose Script
> `scripts/decompose.sh`

CLI tool that automates the mechanical parts of decomposition:
```bash
# Input: decomposition output from the AI (JSON or markdown)
# Does:
# 1. Creates integration branch
# 2. Creates contracts branch
# 3. Creates per-sub-task branches
# 4. Generates brief files in briefs/ folder
# 5. Prints commands to start each agent

./scripts/decompose.sh --task "add-notifications" --briefs briefs/
```

### 2.2 Agent Runner
> `scripts/run-agents.sh`

Wrapper that launches parallel Claude Code or Codex agents:
```bash
# Starts N agents in parallel, each with its brief
# Monitors progress, collects results
# Flags when all sub-tasks are done and integration can start

./scripts/run-agents.sh --briefs briefs/ --repo . --parallel
```

### 2.3 Integration Checker
> `scripts/check-integration.sh`

After all sub-tasks complete, validates integration readiness:
```bash
# Checks:
# - All sub-task branches exist and have commits
# - No merge conflicts between branches (dry-run merge)
# - All shared contracts have implementations
# - Build passes after merge
# - Tests pass after merge

./scripts/check-integration.sh --integration-branch feature/add-notifications
```

### 2.4 AGENTS.md Generator
> `scripts/generate-agents-md.sh`

After a project goes through the workflow, auto-generate an AGENTS.md that captures:
- Architecture pattern and layer rules
- Build and test commands
- Key conventions discovered during the workflow
- File structure overview
- Dependency rules

This makes every future AI session start with full project context.

---

## Milestone 3: Production Hardening

**Goal:** Turn the release readiness checklist from a manual checklist into automated CI gates with starter templates.

### 3.1 GitHub Actions Templates
> `ci-templates/github/`

Starter workflows per stack:
- `dotnet.yml` — build, test, CodeQL SAST, dependency scan, SBOM (CycloneDX)
- `node.yml` — build, test, npm audit, SBOM
- `platformio.yml` — build, native tests
- `common.yml` — secrets scan (gitleaks), lock file check

Each template maps to release readiness checklist items with comments explaining which gate it covers.

### 3.2 Pre-commit Hooks
> `ci-templates/pre-commit/`

Local checks that catch issues before CI:
- No secrets in staged files (gitleaks)
- Lock file present and up to date
- Build passes locally
- Configurable per project type

### 3.3 SBOM Tooling Guide
> `dev-workflow/references/sbom-guide.md`

Practical guide for small teams:
- When you actually need SBOM (hint: not for every commit)
- Tool comparison: CycloneDX CLI vs Syft vs dotnet-CycloneDX
- How to generate, where to store, when to review
- Integrating with the release readiness checklist

### 3.4 Security Scanning Setup Guide
> `dev-workflow/references/security-scanning-guide.md`

Getting SAST and dependency scanning working with minimal overhead:
- CodeQL for .NET and TypeScript (free for public repos)
- Roslyn analyzers for .NET (runs during build, zero setup)
- npm audit / dotnet list package --vulnerable
- When to block merges vs. when to warn

---

## Milestone 4: More Playbooks

**Goal:** Extend framework to more project types based on community demand.

### 4.1 Priority playbooks (based on common stacks)
- **Blazor Server / Hybrid** — different hosting model, different state management
- **React / Next.js** — huge audience, component architecture, SSR considerations
- **Python FastAPI** — common for AI/ML backend services
- **Docker / Compose** — containerized deployment patterns

### 4.2 Playbook contribution template
> `CONTRIBUTING.md` section

Standardized template so community members can submit new playbooks:
- Required sections (architecture, folder structure, Q&A, rules, design, build/test)
- Quality bar (must follow existing formatting, must include build/test commands)
- Review checklist for playbook PRs

---

## Future Ideas (unscheduled)

| Idea | Value | Effort | Notes |
|---|---|---|---|
| Interactive skill configurator | High for adoption | High | React app: answer questions → get customized skill |
| Teaching mode | Medium for onboarding | Medium | Skill variant that explains "why" at each step |
| Decision log (ADR) template | Medium for long-lived projects | Low | Auto-generate ADR during Plan phase |
| Cross-project memory | High for multi-repo setups | High | Shared contracts across repos |
| Feedback loop / metrics | Medium for iteration | Medium | Track where the workflow catches vs. misses problems |
| VS Code extension | High for adoption | High | Workflow status bar, phase tracking, gate reminders |

---

## How to Contribute

Pick any item from the milestones above. Each item is scoped to be a single PR:

1. Prompt packs → one file per pack in `dev-workflow/references/prompts/`
2. Scripts → one script per tool in `scripts/`
3. CI templates → one workflow per stack in `ci-templates/`
4. Playbooks → one file per type in `dev-workflow/playbooks/`

Open an issue first to discuss approach, then PR with the implementation.
