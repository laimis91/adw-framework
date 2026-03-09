---
name: dev-workflow
description: "Structured AI-assisted development workflow: triage, discover, plan, design, build, test, document. Use this skill whenever the user asks to build, implement, add, fix, refactor, or create anything in a codebase — whether it's a new feature, bugfix, refactor, new project, UI component, API endpoint, or multi-module change. Also use when the user asks for a plan, implementation approach, architecture review, task breakdown, or wants to start working on something. Triggers on: 'build', 'implement', 'add feature', 'fix bug', 'refactor', 'create project', 'plan this', 'how should I approach', 'break this down', 'start working on', or any request that involves changing code. Always use this skill before writing code — it prevents guessing, scope creep, and wasted work."
---

# AI-Assisted Development Workflow

Core principle: **never guess**. Every task goes through structured phases with approval gates.

## Workflow

```
TRIAGE → DISCOVER → PLAN → [DESIGN] → BUILD & TEST → DOCUMENT
```

Mega tasks add: `DISCOVER → DECOMPOSE → parallel sub-tasks → INTEGRATE → DOCUMENT`

## Triage (always do first)

Assess task size. This determines which phases run and how thoroughly.

| Size | Phases |
|---|---|
| **Small** (bugfix, typo, config, one-file) | Discover (quick) → Plan (lightweight) → Build & Test → Document |
| **Medium** (feature, refactor, endpoint, component) | Discover → Plan → [Design] → Build & Test → Document |
| **Large** (new project, multi-module, new app) | Discover → Plan → Design → Build & Test → Document |
| **Mega** (rewrite, platform, 10+ files across layers) | Discover → Decompose → sub-tasks → Integrate → Document |

[Design] = include if task has UI work, skip for backend-only.

### Size escalation

If actual scope exceeds initial triage during any phase, stop and re-triage:

```
⚠️ This task is bigger than initially assessed.
Originally triaged as: [size]. Actual scope: [what was discovered].
Recommended re-triage: [new size]. Should I adjust the workflow?
```

### Mega task recognition

A task is mega when: 10+ files across layers, exceeds single conversation context, has independent parallel workstreams, or you'd assign parts to different developers.

## Phase 1: Discover

**Goal:** Zero untracked unknowns. No planning or coding until ambiguity is resolved.

1. Read repo: README, AGENTS.md, docs/, key files
2. Compare current state against request
3. Ask structured Q&A with recommendations
4. Repeat until locked down
5. Restate requirements in 1–3 sentences

Every task size gets Discovery. Small = quick (0-1 questions if unambiguous). Mega = full Q&A.

**Q&A format:**
```
Need to know
1. [Question]?
   a) [Option]  b) [Option]  c) [Option]
   → Recommendation: (b) because [reason]

Nice to know
2. [Question]?
   a) [Option]  b) [Option]

Reply with: "1b 2a" or "defaults".
```

**Rules:**
- No commands, edits, or plans that depend on unknowns
- Read-only discovery (rg, git log, browsing) is allowed
- After answers: restate requirements before Phase 2

## Phase 2: Plan

**Goal:** Concrete, reviewable implementation plan with architecture review built in.

Before creating the plan:
- Read `references/plan-template.md` and fill it in
- Read the relevant `playbooks/*.md` for project-type architecture rules and conventions

For small tasks, use a lightweight inline plan: what files change, risks, what to test.

**What to do:**
1. Research codebase: modules, files, entrypoints, patterns
2. Evaluate architecture: existing → verify fit; new → recommend (see architecture table below)
3. Analyze 1–3 options with tradeoffs, pick one
4. Identify risks and edge cases
5. Write ordered implementation steps with file paths and test commands
6. For medium+ tasks: fill in Security and Operability sections from plan template
7. Read `references/ai-usage-policy.md` and follow its rules throughout
8. Load prompt packs when applicable:
   - Security (auth, PII, payments, external inputs): read `references/prompts/threat-model.md`
   - Refactors: read `references/prompts/refactor-safety.md`
   - New code paths: read `references/prompts/test-strategy.md`
   - DB or data changes: read `references/prompts/migration.md`

### Architecture quick reference (for new projects)

| Project Type | Architecture |
|---|---|
| .NET Web API / Service | Clean (Onion) |
| Blazor WebAssembly | Clean Architecture + component UI |
| .NET MAUI | MVVM + Clean + Shell navigation |
| Unity game | Clean Architecture with asmdef layering |
| ESP32 / embedded | Layered: HAL → Services → App → main |
| MCP server | Handler-per-tool + shared services |
| Static site | Component-based, minimal |

Types without a dedicated playbook use the architecture above and general phases.

### ⛔ Approval gate

Present the plan and WAIT for explicit approval:
```
Review the plan and either:
- "approved" — I'll start implementation
- "approved with changes: [list]" — I'll update first
- Questions — I'll address before proceeding
```

## Phase 3: Design (UI/UX only)

**Goal:** Visual direction and assets defined before coding. Skip for backend-only.

Read relevant `playbooks/*.md` for project-type design rules.

1. Define design direction: tone, palette, typography, layout
2. Propose design system (CSS variables, components, spacing)
3. Create visual mockup (HTML artifact)
4. List all assets: icons, images, fonts
5. Production checklist: interactive states, loading/empty/error, responsive, accessibility

### ⛔ Approval gate

Show mockup and WAIT: "approved" or "change [X]".

## Phase 4: Build & Test

**Goal:** Implement plan step by step. Verify after each. Fix before continuing.

1. One plan step at a time
2. After each: build + test
3. If fails: fix before next step
4. Tests alongside code, not after
5. After all steps: integration / E2E tests
6. Before marking complete: self-review using `references/prompts/pr-review.md`

**Loop-back rule:** If implementation reveals a plan problem, STOP and flag it:
```
⚠️ Plan assumed: [X]. Reality: [Y].
Options: a) Adjust step [N]  b) Rethink approach
Which direction?
```

Never silently deviate from the plan.

**Context management:** If conversation is getting long, summarize progress for handoff:
- Read `references/context-handoff-templates.md` for the template

## Phase 5: Document

**Goal:** Update docs + verify release readiness.

1. Update README, CHANGELOG, architecture docs, AGENTS.md as needed
2. Add code comments where "why" isn't obvious
3. For medium+ tasks: read and complete `references/release-readiness-checklist.md`
4. If user-facing changes: generate release notes using `references/prompts/release-notes.md`

## Task Decomposition (mega only)

Read `references/sub-task-brief-template.md` for the brief format.

**Rules:**
- Aim for 3–7 sub-tasks
- Sub-task #1 is ALWAYS shared contracts (interfaces, DTOs, entities)
- Each sub-task runs: Plan → [Design] → Build & Test (no docs)
- Final Document phase after integration covers all docs
- Git strategy: integration branch + per-sub-task branches

**Decomposition prompt output format:**
```
Sub-tasks:
  1. [Contracts] (small) — Domain/Application — BUILD FIRST
  2. [name] (medium) — [scope] — after #1, parallel
  3. [name] (large, UI) — [scope] — after #1, includes Design
  ...
Git strategy: feature/[task]/contracts + feature/[task]/sub-task-N
Integration: [what to test at seams]
```

⛔ Approval gate before generating briefs.

**Integration phase** after all sub-tasks:
1. Merge branches, resolve conflicts
2. Verify contracts implemented correctly
3. Wire DI, routes, configs
4. Full integration test suite
5. Then → Phase 5: Document

## AI Usage Rules

Read `references/ai-usage-policy.md` for full policy. Key rules always in effect:
- Never put secrets, API keys, PII, or credentials in prompts
- All AI-generated code must be human-reviewed before merge
- AI-generated tests must test behaviour, not implementation details
- Flag uncertainty — never present guesses as facts

## Anti-Patterns (never do these)

- **Guess:** Always ask, never assume
- **Skip Discovery:** Even small tasks get quick Q&A if ambiguous
- **Mega-step:** One plan step at a time
- **Silent drift:** Stop and flag plan deviations
- **Tests after:** Write tests alongside each step
- **No gate:** Always wait for "approved" before Build
- **One mega session:** Decompose tasks that exceed context
- **Vague contracts:** Define as actual code signatures
