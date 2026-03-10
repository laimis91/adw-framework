---
name: dev-workflow
description: "Structured AI-assisted development workflow: triage, discover, plan, design, build, test, document. Use this skill whenever the user asks to build, implement, add, fix, refactor, or create anything in a codebase — whether it's a new feature, bugfix, refactor, new project, UI component, API endpoint, or multi-module change. Also use when the user asks for a plan, implementation approach, architecture review, task breakdown, or wants to start working on something. Triggers on: 'build', 'implement', 'add feature', 'fix bug', 'refactor', 'create project', 'plan this', 'how should I approach', 'break this down', 'start working on', or any request that involves changing code. Always use this skill before writing code — it prevents guessing, scope creep, and wasted work."
---

# AI-Assisted Development Workflow

Core principle: **never guess silently**. Every task goes through structured phases; approval gates and questioning style depend on task risk, material ambiguity, and explicit user direction.

> **Path note:** All paths in this document are relative to the directory that contains this `SKILL.md`. Use forward slashes in docs and prompts for portability across Windows, Linux, and macOS. Resolve from the skill root first in Claude Code, Codex CLI, or similar agents. Examples: `references/plan-template.md`, `playbooks/dotnet-api.md`, `scripts/decompose.sh`.

## Workflow

```
TRIAGE → DISCOVER → PLAN → [DESIGN] → BUILD & TEST → DOCUMENT
```

Mega tasks add: `DISCOVER → DECOMPOSE → parallel sub-tasks → INTEGRATE → DOCUMENT`

Role-based collaboration such as Planner, Reviewer, Tester, or Researcher can be used on any non-trivial task. Mega-task decomposition is reserved for splitting implementation into independent workstreams.

**Sub-task brief shortcut:** If the input contains a `## Sub-Task Brief:` header, treat it as pre-scoped input for the current task. Still do quick triage and repo validation, but you may skip repeated context gathering and start with a lightweight Phase 2 (Plan). The brief does not override required approval checkpoints or safety checks.

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

If actual scope exceeds initial triage during any phase, re-triage immediately:

```
⚠️ This task is bigger than initially assessed.
Originally triaged as: [size]. Actual scope: [what was discovered].
Recommended re-triage: [new size].
```

If the re-triage changes user-visible behavior, risk, approval boundaries, or implementation strategy, surface it and confirm direction before continuing.

### Mega task recognition

A task is mega when it requires independent implementation workstreams, exceeds a single coherent plan or conversation context, or spans roughly 10+ files across layers. File count is a strong signal, not a hard rule.

Decomposition is a planning technique, not a mandatory git strategy. Use branches, worktrees, or parallel agents only when they are clearly helpful, compatible with repo policy, and allowed by higher-priority instructions.

## Phase 1: Discover

**Goal:** Resolve material unknowns before committing to an implementation approach.

1. Read repo: README, `CLAUDE.md` if present, `AGENTS.md` if present, docs/, key files
2. Compare current state against request
3. Ask targeted questions with recommendations when material ambiguity remains after repo inspection
4. Repeat until the task is locked down enough to plan safely
5. Restate requirements in 1–3 sentences

Every task size gets Discovery. Small = quick (often zero questions if unambiguous). Mega = deeper discovery and likely decomposition.

**Suggested Q&A format when explicit Q&A is needed:**
```
Need to know
1. [Question]?
   a) [Option]  b) [Option]  c) [Option]
   → Recommendation: (b) because [reason]

Nice to know
2. [Question]?
   a) [Option]  b) [Option]

Defaults if you reply "defaults":
- 1b = [explicit default]
- 2a = [explicit default]

Reply with: "1b 2a" or "defaults".
```

Only offer a `defaults` shortcut when the default choices are written out explicitly in the prompt.

**Rules:**
- No commands, edits, or plans that depend on unresolved material unknowns
- Read-only discovery (rg, git log, browsing) is allowed
- If ambiguity is low, restate assumptions before Phase 2
- If ambiguity is material, stop for answers before Phase 2

## Phase 2: Plan

**Goal:** Concrete, reviewable implementation plan with architecture review built in.

Before creating the plan:
- Read `references/plan-template.md` and fill it in inline in chat by default
- Read the relevant `playbooks/*.md` for project-type architecture rules and conventions

Create an in-repo plan artifact only when repo conventions, higher-priority instructions, or the user explicitly require one.

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

### Plan checkpoint

If the plan changes scope, public behavior, or risk, or the next action is destructive, credentialed, or branch-management related, present the plan and WAIT for explicit approval:
```
Review the plan and either:
- "approved" — I'll start implementation
- "approved with changes: [list]" — I'll update first
- Questions — I'll address before proceeding
```

Otherwise, present the plan concisely, state assumptions and risks, and only continue once nothing material remains unclear.

## Phase 3: Design (UI/UX only)

**Goal:** Visual direction and assets defined before coding. Skip for backend-only.

Read relevant `playbooks/*.md` for project-type design rules.

1. Define design direction: tone, palette, typography, layout
2. Propose design system (CSS variables, components, spacing)
3. Create visual mockup (HTML artifact)
4. List all assets: icons, images, fonts
5. Production checklist: interactive states, loading/empty/error, responsive, accessibility

### Design checkpoint

If the design direction is high-risk, exploratory, or not already constrained by the existing product, show the mockup and WAIT: "approved" or "change [X]".

If the design direction is already constrained, show the intended direction concisely before implementation.

## Phase 4: Build & Test

**Goal:** Implement plan step by step. Verify after each. Fix before continuing.

1. One plan step at a time
2. After each: build + test
3. If fails: fix before next step
4. Tests alongside code, not after
5. After all steps: integration / E2E tests
6. Before marking complete: self-review using `references/prompts/pr-review.md`

**Loop-back rule:** If implementation reveals a material plan problem, assess whether it changes the agreed intent, user-visible behavior, risk profile, or approval boundaries.

If it does, STOP and flag it:
```
⚠️ Plan assumed: [X]. Reality: [Y].
Options: a) Adjust step [N]  b) Rethink approach
Which direction?
```

If the correction preserves the agreed intent and risk profile, update the plan, state the change, and continue.

Do not silently deviate from material plan decisions.

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
- If shared contracts exist, define or stabilize them first
- Each sub-task should have clear scope, touchpoints, and verification
- Final Document phase after integration covers all docs
- Branches/worktrees are optional tactics, not mandatory workflow; respect repo branching policy and required approval checkpoints

**Decomposition prompt output format:**
```
Sub-tasks:
  1. [Contracts or enabling work] (small) — [scope] — first if shared foundations exist
  2. [name] (medium) — [scope] — [parallel or sequential note]
  3. [name] (large, UI) — [scope] — [design note if relevant]
  ...
Execution notes: [parallel/sequential plan], [shared risks], [tests at seams]
Git/worktree strategy: [optional, only if needed]
```

If the decomposition materially changes scope or strategy, present the breakdown and WAIT before implementation.

Otherwise, share the breakdown concisely before the next implementation step.

**Automation scripts** (in `scripts/` — bash `.sh` + PowerShell `.ps1`; optional, use only when branch/worktree orchestration is explicitly desired and compatible with repo policy):
- `./scripts/decompose.sh --task "name" --input decomposition.json`
  - Creates branches, git worktrees (one per sub-task), and brief files
  - PowerShell: `.\scripts\Decompose.ps1 -Task "name" -Input decomposition.json`
- `./scripts/run-agents.sh --briefs briefs/ --skip-first --parallel`
  - Parallel mode uses worktrees so each agent has its own working directory
  - PowerShell: `.\scripts\Run-Agents.ps1 -BriefsDir briefs -SkipFirst -Parallel`
- `./scripts/check-integration.sh --integration-branch feature/name`
  - PowerShell: `.\scripts\Check-Integration.ps1 -IntegrationBranch feature/name`
- `./scripts/generate-agents-md.sh --format claude` captures project knowledge
  - Use `--format agents` for Codex, `--format both` for both CLAUDE.md + AGENTS.md
  - PowerShell: `.\scripts\Generate-AgentsMd.ps1 -Format claude`

All scripts support `-DryRun` / `--dry-run`. Add `--cleanup` / `-Cleanup` to run-agents to auto-remove worktrees after agents finish. See `scripts/example-decomposition.json` for the JSON input format.

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

- **Guess:** Never hide assumptions. Ask when ambiguity is material; otherwise state assumptions explicitly before proceeding
- **Skip Discovery:** Even small tasks get quick Q&A if ambiguous
- **Mega-step:** One plan step at a time
- **Silent drift:** Stop and flag plan deviations
- **Tests after:** Write tests alongside each step
- **No gate:** Do not skip required approval checkpoints. Present the plan and pause whenever risk, scope, or user direction requires it
- **One mega session:** Decompose tasks that exceed context
- **Vague contracts:** Define as actual code signatures
