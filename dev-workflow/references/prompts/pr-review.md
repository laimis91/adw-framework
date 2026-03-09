# PR Review Prompt

Load this during Phase 4 (Build & Test) before marking implementation complete. Use it for self-review of AI-generated code or for reviewing a teammate's changes against the plan.

## When to use

Run this review after all implementation steps are done and tests pass, but before declaring the task complete. This catches issues that build/test alone won't find: drift from the plan, missed edge cases, readability problems, and architectural violations.

For small tasks, do a quick pass through the "must-check" items only. For medium+ tasks, work through the full checklist.

## Review process

1. Re-read the approved plan (or lightweight plan for small tasks)
2. Diff the changes: `git diff main...HEAD` (or appropriate base branch)
3. Walk through each checklist section below
4. Produce the output: issues grouped by severity

## Checklist

### Correctness (must-check)

- Does the code do what the plan says? Compare each plan step to its implementation.
- Are there plan steps that weren't implemented? (missing functionality)
- Are there code changes not in the plan? (scope creep — flag for approval)
- Do all conditional paths have tests or explicit justification for skipping?
- Edge cases from the plan's risk section — are they handled in code?

### Architecture (must-check)

- Does the change respect project layer boundaries?
  - Domain: no dependencies on Infrastructure, UI, or framework types
  - Application: depends on Domain, not on Infrastructure
  - Infrastructure: implements Application interfaces
  - UI/Presentation: depends on Application, never on Infrastructure directly
- Are new files in the correct folders per project conventions?
- Does the change follow existing patterns? (e.g., if other services use constructor DI, don't use service locator)
- Any new cross-layer dependencies introduced? (flag for review)

### Error handling

- Are failure modes handled, not just the happy path?
- Do errors return structured responses? (not raw exceptions to callers)
- Are external calls (HTTP, DB, file IO) wrapped in appropriate error handling?
- Is there retry logic where appropriate? (idempotent operations only)
- Are errors logged with enough context to diagnose? (but no PII in logs)

### Security

- No secrets, API keys, or credentials in code (including test code)
- No SQL string concatenation — parameterized queries or ORM only
- User inputs validated before use
- No PII in logs or error messages
- Auth checks present on new endpoints/actions
- No `[Authorize]` missing on controllers/actions that need it (or equivalent for your framework)

### Tests

- Do tests verify behaviour, not implementation details?
  - Good: "returns 404 when item not found"
  - Bad: "calls _repository.GetById exactly once"
- Can the tests actually fail? (mentally break the code — would the test catch it?)
- Are test names descriptive enough to understand the scenario without reading the test body?
- No hardcoded paths, ports, or timestamps that will break in CI
- No test interdependencies (order-dependent or shared mutable state)
- Missing tests: any code paths with no test coverage that should have it?

### Readability

- Clear naming: methods say what they do, variables say what they hold
- No magic numbers or strings — use named constants or enums
- Comments explain "why," not "what" (code should explain "what")
- No dead code, commented-out code, or leftover debug statements
- Consistent formatting with the rest of the codebase

### Performance (medium+ tasks)

- No N+1 queries (loading related data in a loop instead of batch/join)
- No unbounded collections (missing pagination, limits, or caps)
- No blocking calls in async paths (`Task.Result`, `.Wait()`, `Thread.Sleep` in async)
- No unnecessary allocations in hot paths
- Any new database queries have appropriate indexes?
- Caching: is it needed? If used, what's the invalidation strategy?

## Output format

```markdown
### PR Review: [task name]

**Plan alignment:** [matches / minor drift / significant drift]
**Overall:** [ready to merge / needs fixes / needs rework]

#### Must-fix (blocks merge)
1. [file:line] — [issue description]
2. ...

#### Should-fix (merge but follow up)
1. [file:line] — [issue description]
2. ...

#### Nits (optional improvements)
1. [file:line] — [suggestion]
2. ...

#### Positive notes
- [things done well worth calling out]
```

## After review

- Must-fix items: fix before marking complete
- Should-fix items: fix now if quick, otherwise create a tracking issue
- Nits: apply or skip at discretion
- If significant drift from plan: stop and flag for re-approval before continuing
