# Sub-Task Brief Template

Use this template when decomposing mega tasks. Each sub-task gets its own brief that can be pasted into a new conversation.

## Decomposition rules

- Aim for 3–7 sub-tasks
- Sub-task #1 is ALWAYS shared contracts (interfaces, DTOs, entities, message schemas)
- All other sub-tasks branch from the integration branch after #1 is merged
- UI sub-tasks include a Design step, backend sub-tasks skip it
- Sub-tasks add code comments but do NOT update README, CHANGELOG, or architecture docs

## Git branching strategy

```
main
 └── feature/[mega-task-name]           ← integration branch
      ├── feature/[mega-task]/contracts  ← shared contracts (merge first)
      ├── feature/[mega-task]/sub-task-2
      ├── feature/[mega-task]/sub-task-3
      └── feature/[mega-task]/sub-task-4
```

Workflow:
1. Create integration branch from main
2. Build contracts on feature/[mega-task]/contracts, merge into integration branch
3. Each sub-task branches from integration branch (which now has contracts)
4. Sub-tasks work independently on their branches
5. Integration: merge all into integration branch, resolve conflicts
6. Final merge: integration branch → main

## Brief template

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
Follow project conventions.
Add code comments where intent isn't obvious.
Do NOT update README, CHANGELOG, or architecture docs —
that happens in the final Document phase after integration.
```

## Execution strategies

**Parallel sessions (multiple conversations):**
Best when sub-tasks have no dependencies after contracts. Start each with its brief.

**Sequential sessions:**
Best when sub-tasks depend on each other. Complete one, carry output to next.

**Multi-agent (Claude Code, Codex CLI):**
Each agent gets a brief as its prompt. Requires well-defined contracts and an integration step.

```bash
codex --prompt "$(cat briefs/sub-task-1-api.md)" --repo .
codex --prompt "$(cat briefs/sub-task-2-frontend.md)" --repo .
```

## Decomposition patterns

**By architectural layer:** Domain → Application → Infrastructure → UI. Build contracts first, then parallel.

**By feature / vertical slice:** Each sub-task delivers one feature end-to-end. Watch for shared model conflicts.

**By bounded context / module:** Each sub-task owns a module or service. Define inter-service contracts first.

**Contracts-first (recommended default):** Sub-task #1 is always shared contracts. Everything else runs parallel against them.

## Integration phase prompt

```
All sub-tasks are done. Now integrate:
1. Merge all sub-task branches into integration branch
2. Resolve merge conflicts
3. Verify all shared contracts are implemented correctly
4. Wire components together (DI, routes, configs)
5. Run integration tests across boundaries
6. Run full test suite
7. Fix contract mismatches

Sub-tasks completed:
- [name]: [what was built, branch]
- [name]: [what was built, branch]

Shared contracts: [list]
```

## When decomposition goes wrong

| Problem | Sign | Fix |
|---|---|---|
| Too coupled | Every sub-task needs every other | Redraw boundaries |
| Contracts too vague | Lots of integration mismatches | Define as actual code signatures |
| Too small | Brief overhead exceeds the work | Merge sub-tasks |
| Too many (8+) | Coordination overhead kills gains | Merge, aim for 3–7 |
| Missing sub-task | Integration reveals unowned gap | Add sub-task or assign to integration |
| Context lost | New session misses conventions | Add project rules to each brief |
| Merge conflicts | Overlapping file modifications | Tighten scope, contracts-first |
