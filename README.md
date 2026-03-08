# AI-Assisted Development Workflow

A structured prompt framework for getting production-ready results from AI coding assistants. Works with Claude, ChatGPT, Copilot, Codex CLI, or any AI that writes code.

**Core principle: never let the AI guess.**

Every task goes through structured phases with approval gates. The AI asks before assuming, plans before coding, and stops when reality doesn't match the plan.

## The Problem

When developers use AI coding assistants without structure, they hit predictable failure modes:

- **Silent assumptions** — AI guesses instead of asking, leading to wrong architecture and wasted work
- **Scope explosion** — no triage means every task gets the same process, or no process at all
- **Context overflow** — large tasks exceed conversation limits, AI forgets earlier decisions
- **Production gaps** — tests pass but there's no security review, no rollback plan, no observability

This framework prevents all four.

## The Workflow

```
TRIAGE → DISCOVER → PLAN → [DESIGN] → BUILD & TEST → DOCUMENT
```

| Phase | What happens |
|---|---|
| **Triage** | Assess task size (small/medium/large/mega), determines which phases run |
| **Discover** | Q&A gate — eliminate all ambiguity before any code is written |
| **Plan** | Concrete implementation plan with architecture review, security, and operability |
| **Design** | Visual direction and mockups (UI tasks only, skip for backend) |
| **Build & Test** | Step-by-step implementation with tests after each step |
| **Document** | Update docs + release readiness checklist |

Mega tasks add a **decomposition** step: split into 3–7 independent sub-tasks that run in parallel sessions or agents, then integrate.

### Key Mechanics

- **⛔ Approval gates** — AI presents plan/design and waits for "approved" before coding
- **↩ Loop-backs** — AI stops and flags when implementation reveals plan problems
- **📏 Size scaling** — small tasks skip ceremony, mega tasks decompose
- **🔀 Context handoffs** — templates to continue work across sessions
- **📋 Release readiness** — size-scaled checklist covering security, operability, and production gates

## Quick Start

**Option 1: Use as prompts** — Copy the prompt templates from the framework docs into your AI conversations.

**Option 2: Install as a Claude skill** — Drop the `dev-workflow/` folder into your Claude skills directory. The AI automatically follows the workflow when you ask it to build, fix, or create anything.

Start every task with:

```
I want to [describe task].
Assess the size and tell me which phases to run.
```

## Repository Structure

```
├── README.md                              ← You are here
├── ai-dev-workflow-framework.md           ← Full framework documentation
├── playbooks-reference.md                 ← Project-type playbooks (standalone reference)
│
├── dev-workflow/                           ← Claude skill (installable)
│   ├── SKILL.md                           ← Core rules, always loaded (213 lines)
│   ├── references/
│   │   ├── plan-template.md               ← Plan template with security + operability
│   │   ├── sub-task-brief-template.md     ← Mega task decomposition briefs
│   │   ├── release-readiness-checklist.md ← Size-scaled production gates
│   │   ├── ai-usage-policy.md             ← Data rules, validation, permissions
│   │   └── context-handoff-templates.md   ← Session continuation templates
│   └── playbooks/
│       ├── dotnet-api.md                  ← .NET Web API (Clean Architecture)
│       ├── blazor-wasm.md                 ← Blazor WebAssembly
│       ├── maui.md                        ← .NET MAUI mobile app
│       ├── unity.md                       ← Unity game
│       ├── esp32.md                       ← ESP32 embedded (PlatformIO)
│       ├── mcp-server.md                  ← MCP server
│       └── static-site.md                 ← Static site / landing page
│
└── deep-research-report.md                ← Production readiness analysis
```

## Framework at a Glance

### Triage Sizes

| Size | Examples | Process |
|---|---|---|
| **Small** | Bugfix, typo, config change | Quick Q&A → lightweight plan → build → doc |
| **Medium** | New feature, refactor, endpoint | Discover → Plan → [Design] → Build → Doc |
| **Large** | New project, multi-module feature | Full workflow with Design phase |
| **Mega** | Rewrite, platform, 10+ files | Decompose into 3–7 parallel sub-tasks |

### Phase Summary

**Discover** — The AI reads the codebase, compares against your request, and asks structured questions with recommendations. You reply with compact answers like `"1a 2b 3c"` or `"defaults"`. No coding until all unknowns are resolved.

**Plan** — The AI produces a plan using a structured template: goal, constraints, research findings, architecture evaluation, security considerations (medium+), operability (medium+), implementation steps with file paths, and tests. You review and approve before any code is written.

**Design** — For UI work only. The AI proposes visual direction, creates an HTML mockup, and lists all required assets. You approve the design before implementation starts.

**Build & Test** — The AI implements one plan step at a time, builds and tests after each step, and fixes failures before continuing. If implementation reveals a plan problem, it stops and asks — never silently deviates.

**Document** — Updates README, CHANGELOG, architecture docs, and completes a size-scaled release readiness checklist covering security scanning, dependency management, rollback plans, and observability.

### Mega Task Decomposition

For tasks too large for a single conversation:

1. **Discover** — Full Q&A, lock down all requirements
2. **Decompose** — Split into 3–7 sub-tasks with shared contracts defined first
3. **Execute** — Each sub-task runs in its own session: Plan → [Design] → Build & Test
4. **Integrate** — Merge branches, wire components, run integration tests
5. **Document** — Final documentation pass across everything

Sub-task #1 is always shared contracts (interfaces, DTOs, entities). Everything else runs in parallel against them.

## Playbooks

Project-type-specific guidance for architecture, folder structure, Q&A questions, and build/test commands:

| Playbook | Architecture | When to use |
|---|---|---|
| [.NET Web API](dev-workflow/playbooks/dotnet-api.md) | Clean (Onion) | REST APIs, services, backends |
| [Blazor WebAssembly](dev-workflow/playbooks/blazor-wasm.md) | Clean + component UI | Blazor WASM frontends |
| [.NET MAUI](dev-workflow/playbooks/maui.md) | MVVM + Clean + Shell | Mobile apps (Android/iOS) |
| [Unity](dev-workflow/playbooks/unity.md) | Clean with asmdef | Games |
| [ESP32](dev-workflow/playbooks/esp32.md) | HAL → Services → App | Embedded / IoT (PlatformIO) |
| [MCP Server](dev-workflow/playbooks/mcp-server.md) | Handler-per-tool | MCP tool servers |
| [Static Site](dev-workflow/playbooks/static-site.md) | Component-based | Landing pages, marketing sites |

## Production Readiness

The framework includes production overlays that scale by task size:

| Gate | Small | Medium | Large/Mega |
|---|---|---|---|
| Tests pass | ✅ | ✅ | ✅ |
| Human code review | ✅ | ✅ | ✅ |
| SAST / code scanning | — | ✅ | ✅ |
| Dependency scan | — | ✅ | ✅ |
| Threat model | — | If auth/data touched | ✅ |
| Rollback plan | — | — | ✅ |
| SLO impact assessed | — | — | ✅ |
| Observability | — | If new endpoint | ✅ |
| SBOM generated | — | — | ✅ |

See [release-readiness-checklist.md](dev-workflow/references/release-readiness-checklist.md) for the full checklist and [ai-usage-policy.md](dev-workflow/references/ai-usage-policy.md) for AI safety rules.

## Anti-Patterns

| Don't | Do instead |
|---|---|
| "Just build it" | Always start with triage |
| Let AI assume | Q&A gate until zero unknowns |
| Implement everything at once | One plan step at a time |
| Silently deviate from plan | Stop and flag deviations |
| Write tests after all code | Tests alongside each step |
| Skip approval gates | Wait for "approved" before Build |
| Run mega tasks in one session | Decompose into 3–7 sub-tasks |
| Define vague contracts | Use actual code signatures |
| No branching for parallel work | Branch per sub-task + integration branch |

## Skill Architecture

The Claude skill uses three-layer progressive loading to minimize context usage:

| Layer | Loaded | Size | Contents |
|---|---|---|---|
| **SKILL.md** | Always | 213 lines | Core rules, phase sequence, decision logic |
| **References** | On demand | 507 lines | Plan template, briefs, checklist, AI policy, handoffs |
| **Playbooks** | On demand | 437 lines | 7 project types with architecture and build rules |

Total: 1,157 lines — but only 213 are always in the AI's context. The rest loads only when needed for the current phase.

## Contributing

This is a living framework. If you find gaps, have suggestions for new playbooks, or want to improve the prompts:

1. Open an issue describing the problem or improvement
2. Reference which phase, template, or playbook is affected
3. PRs welcome — follow the existing file structure and formatting

## License

MIT
