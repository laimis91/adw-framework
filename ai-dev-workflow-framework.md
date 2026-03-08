# AI-Assisted Development Workflow

A structured prompt sequence for getting production-ready results from AI coding assistants. Core principle: **never let the AI guess**.

---

## How It Works

```
TRIAGE ──→ DISCOVER → PLAN → DESIGN → BUILD & TEST → DOCUMENT
  |                            ↑           |
  |                            └───────────┘  (loop back if needed)
  |
  └─ (mega) → DISCOVER → DECOMPOSE → sub-tasks → INTEGRATE → DOCUMENT
                                         │
                                    each sub-task runs:
                                    PLAN → [DESIGN] → BUILD & TEST
```

Every task starts with triage. Triage picks the right level of rigor. Approval gates (⛔) prevent the AI from running ahead. Loop-backs keep the plan honest when reality doesn't match expectations. Mega tasks get decomposed into independent sub-tasks that can run in parallel sessions — UI sub-tasks include a Design step, backend sub-tasks skip it.

---

## Triage (do this first, every time)

Estimate task size before starting. This determines which phases to run and how thoroughly.

| Size | Examples | Phases to run |
|---|---|---|
| **Small** | Bugfix, typo, config change, rename, one-file edit | Discover (quick) → Plan (lightweight) → Build & Test → Document |
| **Medium** | New feature, refactor, new endpoint, UI component | Discover → Plan → [Design] → Build & Test → Document |
| **Large** | New project, multi-module feature, new app | Discover → Plan → Design → Build & Test → Document |
| **Mega** | Full rewrite, new platform, multi-project system, 10+ files across layers | Discover → Decompose → parallel sub-tasks → Integrate → Document |

**Prompt:**

```
I want to [describe task].

Assess the size of this task (small / medium / large / mega) and tell me
which phases you recommend before starting.
```

For **small** tasks, Discovery is quick — if the task is unambiguous the AI can ask zero questions. But if there's any uncertainty (which call site has the bug? which config is wrong?) the AI still opens a Q&A gate, even if it's just one question. No guessing, even for small tasks.

For **mega** tasks, the AI must decompose the work into independent sub-tasks before any implementation starts. See **Task Decomposition** below.

### How to recognize a mega task

A task is mega when any of these are true:
- It would touch 10+ files across multiple architectural layers
- The full plan would exceed what fits in a single conversation context
- It has independent workstreams that don't need to be sequential (e.g., backend API + frontend UI + database migration)
- You'd naturally assign parts of it to different developers
- The AI starts losing track of earlier decisions or files in the conversation

### Size escalation

If the AI triages as one size but discovers during any phase that the task is bigger than expected, it must stop and re-triage:

```
⚠️ This task is bigger than initially assessed.

Originally triaged as: [medium]
Actual scope: [describe what was discovered — more files, more layers, more unknowns]
Recommended re-triage: [large / mega]

This means we should [add Design phase / decompose into sub-tasks].
Should I re-triage and adjust the workflow?
```

The AI must not silently continue with insufficient process for the actual scope.

---

## Task Decomposition (mega tasks only)

**Goal:** Split a mega task into independent sub-tasks that each fit in a single conversation and can run in parallel.

### How it works

```
1. DISCOVER (one session)
   — Full Q&A, lock down all requirements
   — Map the entire scope

2. DECOMPOSE (same session)
   — Split into sub-tasks with clear boundaries
   — Sub-task #1 is always shared contracts (interfaces, DTOs, entities)
   — Produce a Sub-Task Brief for each
   — Aim for 3–7 sub-tasks (sweet spot)

3. EXECUTE sub-tasks (parallel sessions)
   — Each sub-task runs: Plan → [Design if UI] → Build & Test
   — Each gets its own conversation with a Sub-Task Brief
   — Sub-tasks are independent — no cross-session dependencies
   — Sub-tasks add code comments but NOT docs (README, CHANGELOG, etc.)

4. INTEGRATE (one session)
   — Wire sub-tasks together
   — Run integration tests across boundaries
   — Fix contract mismatches

5. DOCUMENT (one session)
   — Final documentation pass across the whole change
   — README, CHANGELOG, architecture docs, AGENTS.md
```

### Sub-task count guidance

Aim for **3–7 sub-tasks**. Fewer than 3 usually means the task isn't actually mega — run it as large instead. More than 7 and coordination overhead (briefs, contracts, integration) starts eating the time you saved by parallelizing. If you're above 7, look for sub-tasks that can merge.

### Prompt: Decompose

After Discovery is complete:

```
This is a mega task. Before planning, decompose it into independent
sub-tasks that can each run in their own session.

For each sub-task:
1. Name and goal (one sentence)
2. Scope: which files/modules/layers it touches
3. Inputs: what it needs from other sub-tasks (contracts, interfaces)
4. Outputs: what it produces for other sub-tasks
5. Size estimate: small / medium / large
6. Dependencies: which sub-tasks must finish first (or "none — parallel")
7. Includes UI? (if yes, sub-task needs a Design step)

Also define:
- Sub-task #1 should be shared contracts: interfaces, DTOs, message
  schemas that multiple sub-tasks depend on (always built first)
- Integration points: where sub-tasks connect and how to test the seams
- Execution order: what can run in parallel vs. what's sequential
- Git strategy: recommended branching approach (see below)
```

### ⛔ Approval gate

The AI presents the decomposition and waits:

```
Here's the decomposition into [N] sub-tasks:

Sub-tasks:
  1. [Contracts + shared models] (small) — Domain/Application — BUILD FIRST
  2. [name] (medium) — [scope] — after #1, parallel with #3-#N
  3. [name] (large, UI) — [scope] — after #1, parallel, includes Design
  4. [name] (small) — [scope] — after #1
  ...

Git strategy: [recommended approach]
Integration step: [what to test at the seams]

Review and either:
- "approved" — I'll generate the sub-task briefs
- Adjustments — I'll revise the split
```

Sub-task #1 is always the shared contracts (interfaces, DTOs, domain entities, message schemas). All other sub-tasks branch from the integration branch after #1 is merged, and can then run in parallel.

### Sub-Task Brief template

Each sub-task gets a brief that can be pasted into a new conversation:

```markdown
## Sub-Task Brief: [name]

### Context
Project: [name]
Parent task: [one-sentence description of the mega task]
This is sub-task [N] of [total]. Other sub-tasks are handling: [list].

### Goal
[What this sub-task delivers]

### Scope
- Files/modules to touch: [list]
- Layer: [Domain / Application / Infrastructure / UI / etc.]

### Shared contracts (already defined)
[Paste the interfaces, DTOs, schemas this sub-task must implement or consume.
Include the actual code/signatures, not just names.]

### Constraints
- Must not modify: [files owned by other sub-tasks]
- Must implement: [interface/contract from shared contracts]
- Architecture: [rules from the parent plan]
- Naming conventions: [from project]
- Git branch: [branch name to work on]

### Acceptance criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] Tests pass: [specific test command]

### What to do
Run: Plan → [Design →] Build & Test.
Use the plan-work skill. Follow project conventions.
Add code comments where intent isn't obvious.
Do NOT update README, CHANGELOG, or architecture docs —
that happens in the final Document phase after integration.
```

### Git branching strategy

When sub-tasks run in parallel on the same repo, they will create merge conflicts without a branching strategy. Recommendation:

```
main
 └── feature/[mega-task-name]           ← integration branch
      ├── feature/[mega-task]/contracts  ← shared contracts (merge first)
      ├── feature/[mega-task]/sub-task-1 ← per sub-task branch
      ├── feature/[mega-task]/sub-task-2
      ├── feature/[mega-task]/sub-task-3
      └── feature/[mega-task]/sub-task-4
```

Workflow:
1. Create the feature integration branch from main
2. Build shared contracts on `feature/[mega-task]/contracts`, merge into integration branch
3. Each sub-task branches from the integration branch (which now has contracts)
4. Sub-tasks work independently on their branches
5. Integration phase: merge all sub-task branches into the integration branch, resolve conflicts
6. Final merge: integration branch → main

If the AI agent has git access (e.g., Claude Code, Codex CLI), it can create branches automatically. Otherwise, create them yourself before starting sub-task sessions.

### Execution strategies

**Parallel sessions (multiple Claude conversations):**
Best for sub-tasks with no dependencies. Start each in its own conversation with its Sub-Task Brief. Works well for: backend + frontend, separate services, independent features.

**Sequential sessions (one conversation at a time):**
Best when sub-tasks have dependencies. Complete one, carry the output into the next. Works well for: database migration → API → UI, shared library → consumers.

**Multi-agent (Codex CLI, Claude Code, or similar):**
Best for maximum parallelism with automation. Each agent gets a Sub-Task Brief as its prompt. Requires: well-defined contracts, good test coverage, and an integration step at the end.

```
# Example: Codex CLI parallel execution
# Each agent gets its brief file as context

codex --prompt "$(cat briefs/sub-task-1-api.md)" --repo .
codex --prompt "$(cat briefs/sub-task-2-frontend.md)" --repo .
codex --prompt "$(cat briefs/sub-task-3-migration.md)" --repo .
```

### Decomposition patterns

**By architectural layer:**
Split along Domain → Application → Infrastructure → UI. Works when each layer has clear interfaces. Build contracts first, then layers in parallel.

**By feature / vertical slice:**
Each sub-task delivers one complete feature end-to-end (API + UI + tests). Works when features are independent. Watch for shared model conflicts.

**By bounded context / module:**
Each sub-task owns a module or service. Works for microservices and multi-project solutions. Define inter-service contracts first.

**Contracts-first strategy (recommended):**
Sub-task #1 is always the shared contracts (interfaces, DTOs, message schemas, domain entities). All other sub-tasks depend on it but can then run in parallel against the contracts. This is the default decomposition approach.

### Integration phase

After all sub-tasks are complete:

```
All sub-tasks are done. Now integrate:

1. Merge all sub-task branches into the integration branch
2. Resolve any merge conflicts
3. Verify all shared contracts are implemented correctly
4. Wire components together (DI registrations, route configs, etc.)
5. Run integration tests across sub-task boundaries
6. Run the full test suite
7. Fix any contract mismatches or integration issues

Sub-tasks completed:
- [name]: [brief status — what was built, branch name]
- [name]: [brief status]
- ...

Shared contracts: [paste or reference]
```

### When decomposition goes wrong

| Problem | Sign | Fix |
|---|---|---|
| Sub-tasks too coupled | Every sub-task needs to know about every other | Redraw boundaries along cleaner seams |
| Contracts too vague | Integration phase has lots of mismatches | Define contracts with actual code signatures, not just descriptions |
| Sub-tasks too small | Overhead of briefs exceeds the work | Merge related sub-tasks back together |
| Too many sub-tasks (8+) | Coordination overhead kills parallelism gains | Merge related ones, aim for 3–7 |
| Missing sub-task | Integration reveals a gap nobody owns | Add a new sub-task for the gap, or assign it to the integration phase |
| Context lost | New session doesn't understand project conventions | Add project conventions and architecture rules to each brief |
| Merge conflicts | Sub-tasks modified overlapping files | Tighten scope boundaries, use contracts-first strategy |

---

## Phase 1: Discover

**Goal:** Eliminate all ambiguity. End this phase with zero unknowns.

This phase combines request clarification with repo research. The AI reads the codebase, compares against your request, and opens a Q&A gate for anything unclear or multi-path. No planning or coding happens here.

Every task size gets Discovery — for small tasks it can be one quick question or zero if unambiguous; for mega tasks it's a full Q&A session that maps the entire scope.

### What the AI does

1. Read repo guidance: README, AGENTS.md, docs/ (existing project) or understand the request scope (greenfield)
2. Identify relevant code paths, patterns, dependencies
3. Compare current state against requested outcome
4. List everything unclear, ambiguous, or multi-path
5. Ask structured questions with recommendations
6. Repeat until all unknowns are resolved
7. Restate the requirements in 1–3 sentences

### Prompt

```
I want to [describe what you want].

[Attach repo or describe project context]

Before planning anything:
1. Analyze current state and compare against my request
2. Identify what's unclear or has multiple possible approaches
3. Ask me structured questions with your recommendations
4. Do not plan or code until all questions are answered
```

### Q&A format the AI should use

```
Before I plan this, I need to clarify:

Need to know
1. [Question]?
   a) [Option]
   b) [Option]
   c) [Option]
   → Recommendation: (b) because [reason]

2. [Question]?
   a) [Option]
   b) [Option]
   → Recommendation: (a) because [reason]

Nice to know
3. [Question]?
   a) [Option]
   b) [Option]

Reply with: "1b 2a 3a" or "defaults" to accept my recommendations.
```

### Rules

- AI must not run commands, edit files, or produce plans that depend on unknowns
- Read-only discovery (`rg`, `git log`, browsing files) is allowed
- Continue asking rounds until everything is locked down
- After all answers: restate requirements before moving to Phase 2

### Context handoff (for multi-session work)

If the conversation is getting long or you need to continue in a new session:

```
Summarize the discovery results so far in a compact format I can
paste into a new conversation to continue without losing context.
Include: restated requirements, all Q&A decisions, key file paths found.
```

---

## Phase 2: Plan

**Goal:** Produce a concrete, reviewable implementation plan grounded in repo reality. Architecture review is built into this phase, not separate.

During this phase, consult the **Playbooks Reference** for your project type — it has architecture rules, folder structures, and typical Q&A questions specific to .NET, Unity, Web, ESP32, etc.

### What the AI does

1. **Research** the codebase: modules, files, entrypoints, configs, data models, existing patterns
2. **Evaluate architecture**: if existing → check plan fits it; if new → recommend and define one (see Playbooks)
3. **Analyze options**: list 1–3 approaches with tradeoffs, pick one, justify
4. **Identify risks**: edge cases, breaking changes, migration needs
5. **Write implementation steps**: ordered, with file paths, dependency order, and test commands
6. **Include architecture constraints**: as a mandatory section in the plan

### Prompt

```
Discovery is complete. Requirements: [paste restated requirements or "as discussed above"].

Create the implementation plan. Include:
- Research findings with file paths
- Architecture evaluation (does the plan fit existing patterns? if new project, define the architecture)
- Options analysis with your recommendation
- Risks and edge cases
- Ordered implementation steps with files to change
- Tests to validate each step

Use the plan template.
```

**For small tasks (lightweight plan):**

```
This is a small task, no full plan needed. Just confirm:
1. What files change and how
2. Any risks
3. What to test

Then start implementation.
```

### Plan template

```markdown
## Goal
- [1-3 sentence restated requirement from Discovery]

## Constraints & decisions (from Discovery)
- [Q&A question]: [chosen option and why]
- [Q&A question]: [chosen option and why]
- Assumed (not explicitly asked): [assumption and reasoning]
- Non-goals: [what's explicitly out of scope]

## Research (current state)
- Modules/subprojects: ...
- Key files/paths: ...
- Entrypoints: ...
- Configs/flags: ...
- Data models: ...
- Existing patterns: ...

## Architecture
- Current architecture: [identified or "new project"]
- Architecture for this change: [Clean/MVVM/Hexagonal/etc.]
- Layer rules:
  - [e.g., Domain has no external dependencies]
  - [e.g., ViewModels don't reference Views]
- Dependency direction: [A → B → C]
- New files placement:
  - [file → layer/folder rationale]

## Analysis
### Options
1. [approach] — [tradeoff]
2. [approach] — [tradeoff]

### Decision
- Chosen: [#] because [reason]

### Risks / edge cases
- [risk]: [mitigation]

## Implementation steps
1. [Step]: [files], [what changes]
2. [Step]: [files], [what changes]
3. ...

## Tests to run
- [command]: [what it validates]
```

### Architecture selection (for new projects)

| Project Type | Recommended Architecture |
|---|---|
| Web API / Service | Clean (Onion) Architecture |
| Blazor WebAssembly | Clean Architecture + component-based UI |
| Blazor Server / Hybrid | Clean Architecture + scoped services per circuit |
| Full-stack web app | Clean Architecture + feature-based frontend |
| .NET MAUI app | MVVM + Clean Architecture + Shell navigation |
| Unity game | Clean Architecture with asmdef layering |
| CLI tool | Ports & Adapters (Hexagonal) |
| Library / SDK / NuGet | Layered with clear public API surface |
| Microservices | Clean Architecture per service + shared contracts |
| ESP32 / embedded | Layered: HAL → Services → Application → main |
| MCP server | Handler-per-tool + shared services |
| Multi-agent system | Single-responsibility agents + orchestrator |
| Static site / landing page | Component-based, minimal structure |
| Browser extension | Background → Content → Popup message passing |

For architecture rules, folder structures, and phase-specific details per project type, see **Playbooks Reference**. Project types without a dedicated playbook (CLI tool, Microservices, Multi-agent, Browser extension) use the architecture recommendation from the table above and follow the general framework phases.

### ⛔ Approval gate

The AI must present the plan and wait for explicit approval before proceeding.

```
Here's the implementation plan. Review it and either:
- "approved" — I'll start implementation
- "approved with changes: [list changes]" — I'll update the plan first
- Questions or concerns — I'll address them before proceeding
```

---

## Phase 3: Design (UI/UX)

**Goal:** Define visual direction and gather all assets before coding. **Skip this phase for backend-only work.**

During this phase, consult the **Playbooks Reference** for your project type — it has design rules specific to Blazor, MAUI, Unity, static sites, etc.

### What the AI does

1. Define design direction: tone, color palette, typography, layout
2. Propose a design system (CSS variables, component patterns, spacing)
3. Create a visual mockup (HTML artifact) for review
4. List all required assets: icons, images, fonts
5. Define production-quality checklist: states, responsive, accessibility

### Prompt

```
The plan includes UI work. Before coding:

1. Propose a design direction:
   - Tone: [minimal / bold / professional / playful / or suggest]
   - Color palette with CSS variables
   - Font pairing (display + body)
   - Layout approach

2. Create a visual mockup as an HTML artifact

3. List all assets needed (icons, images, fonts with sources)

4. Define the production-quality checklist:
   - All interactive states (hover, focus, active, disabled)
   - Loading, empty, and error states
   - Responsive at 375px, 768px, 1280px
   - Accessibility (semantic HTML, ARIA, keyboard nav)
```

**If the project already has a design system:**

```
The project has an existing design system. Review it and:
1. List available colors, fonts, spacing tokens, components
2. Identify gaps — what's needed but doesn't exist yet
3. Ensure new UI follows existing patterns
4. Update the plan with specific component usage
```

### ⛔ Approval gate

The AI must show the mockup and wait before building real components.

```
Here's the design mockup and asset list. Review and either:
- "approved" — I'll implement it
- "change [X]" — I'll update the mockup
```

---

## Phase 4: Build & Test

**Goal:** Implement the plan step by step. Verify after each step. Fix before continuing.

### What the AI does

1. Implement one plan step at a time
2. After each step: build + test
3. If something fails: fix before moving on
4. Write unit tests alongside implementation (not after)
5. After all steps: integration / E2E tests
6. Final verification pass

### Prompt

```
Plan is approved. Start implementation.

Rules:
- Follow the plan step by step, in order
- After each step: build and test
- If a test fails, fix it before the next step
- Write tests alongside each change, not after
- Do not skip or combine steps
- If implementation reveals a plan issue, stop and flag it

Start with step 1.
```

### Loop-back rule

If during implementation the AI discovers something that invalidates the plan:

```
⚠️ Implementation revealed a problem with the plan:
[describe what was found]

The plan assumed: [X]
Reality is: [Y]

Options:
a) Adjust step [N] to [new approach]
b) Rethink the approach — need to update the plan

Which direction?
```

The AI must **stop and flag** — never silently deviate from the plan.

### Context management

Build & Test is the longest phase and most likely to approach context limits. If the conversation is getting long:

```
Summarize progress so far in a compact format I can paste into
a new conversation to continue:
- Plan status: which steps are done, which remain
- Current step: what's in progress
- Test results: what passed, what failed
- Known issues: anything flagged
- Files changed so far: list with brief description
```

### Testing prompts

**After implementation is complete:**

```
All steps are done. Run full verification:
1. Build with zero warnings
2. All tests pass
3. List any untested code paths
4. List any risks from the plan that aren't covered by tests

Fix everything before moving to documentation.
```

**For UI work — visual verification:**

```
UI is implemented. Verify:
1. Does it match the approved design from Phase 3?
2. All states work: default, hover, loading, empty, error
3. Responsive at 375px, 768px, 1280px
4. List any visual deviations
```

### Build/test commands by project type

| Project Type | Build | Test |
|---|---|---|
| .NET | `dotnet build` | `dotnet test` |
| Unity | Console check in Play Mode | Test Runner (EditMode + PlayMode) |
| ESP32 / PlatformIO | `pio run` | `pio test -e native` |
| Node / TypeScript | `npm run build` | `npm test` |
| Static site | — | Browser preview + Lighthouse |

---

## Phase 5: Document

**Goal:** Update all project docs to reflect what changed.

### What the AI does

1. Update README if setup, config, commands, or structure changed
2. Add CHANGELOG entry
3. Update architecture docs if layers or patterns changed
4. Update AGENTS.md / CONTRIBUTING.md if conventions changed
5. Add code comments where the "why" isn't obvious

### Prompt

```
Implementation is complete and tested. Update documentation:

1. README — if setup, config, commands, or structure changed
2. CHANGELOG — what changed, breaking changes, migration notes
3. Architecture docs — if structure or patterns changed
4. AGENTS.md — if conventions or tooling changed
5. Code comments — where intent isn't obvious

Show changes for review.
```

### CHANGELOG format

```markdown
## [version] - YYYY-MM-DD

### Added
- [feature]

### Changed
- [what and why]

### Fixed
- [bug]

### Breaking Changes
- [what breaks, how to migrate]
```

---

## Quick Reference

| Phase | One-liner |
|---|---|
| Triage | "Assess task size and tell me which phases to run" |
| 1. Discover | "Analyze state, compare to my request, ask questions first" |
| Decompose | "Split into 3–7 independent sub-tasks with contracts" (mega only) |
| 2. Plan | "Create implementation plan with architecture review" |
| 3. Design | "Propose design, create mockup, list assets" (UI only) |
| 4. Build & Test | "Implement step by step, test after each, fix before continuing" |
| 5. Document | "Update README, CHANGELOG, architecture docs" |

---

## Anti-Patterns

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| "Just build it" | Skips discovery, leads to rework | Always start with triage |
| Letting AI assume | Every assumption is a potential wrong turn | Q&A gate until zero unknowns |
| Skipping Q&A on small tasks | Even a "simple" bugfix can have ambiguity | Quick Discovery even for small tasks |
| Mega-steps | Hard to debug, hard to revert | One plan step at a time |
| Plan drift | Silent deviations compound | AI must stop and flag deviations |
| Tests after all code | Bugs found late are expensive | Tests alongside each step |
| No approval gate | AI runs ahead with wrong plan | Explicit "approved" before Phase 4 |
| No context handoff | Progress lost between sessions | Summarize state for new sessions |
| Mega task in one session | Context overflow, AI forgets earlier work | Decompose into sub-tasks |
| Vague contracts | Integration fails, sub-tasks don't fit | Define contracts as actual code signatures |
| Over-decomposition (8+) | Coordination overhead kills the benefit | Merge related sub-tasks, aim for 3–7 |
| No branching strategy | Parallel sub-tasks create merge hell | Branch per sub-task, merge into integration branch |
| Not re-triaging | Scope grew but process stayed small | Stop and re-triage when actual scope exceeds initial estimate |

---

## Context Handoff Templates

### Continuing a session

When continuing work in a new conversation:

```
Continuing work on [project name].

Previous session summary:
- Requirements: [restated from Discovery]
- Key decisions: [from Q&A]
- Plan status: [which steps are done, which remain]
- Current phase: [where we left off]
- Known issues: [anything flagged during build]

[Attach repo or relevant files]

Continue from [specific step or phase].
```

### Starting a sub-task session

When starting a decomposed sub-task in a new conversation:

```
[Paste the Sub-Task Brief from the decomposition phase]

The repo is attached. Run the standard workflow:
Plan → [Design if UI] → Build & Test.

Follow project conventions. Do not modify files outside your scope.
Work on branch: [branch name].
```

### Integration session

When all sub-tasks are done and it's time to integrate:

```
Integration phase for [project name].

Completed sub-tasks:
1. [name]: [what was built, key files changed, branch]
2. [name]: [what was built, key files changed, branch]
3. [name]: [what was built, key files changed, branch]

Shared contracts: [list interfaces/DTOs/schemas]

Integrate:
1. Merge all sub-task branches into integration branch
2. Resolve conflicts
3. Verify all contracts are correctly implemented
4. Wire components together (DI, routes, configs)
5. Run full integration test suite
6. Fix mismatches

[Attach repo]
```
