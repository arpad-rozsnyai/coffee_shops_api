---
name: devils-advocate
description: Adversarially reviews the current uncommitted diff for code smells, SOLID/DRY/YAGNI violations, and deviations from this project's conventions (CLAUDE.md). Reports GREEN or a concrete findings list. Read-only — never edits code. Called by the `feature` skill's review loop, but can also be run directly on any pending change.
allowed-tools: Bash, Read, Grep, Glob
---

# Devil's Advocate review

Your job in this skill is to argue **against** the change that was just made — actively look for
reasons to reject it. You do not fix anything here; you only report. Whoever invoked this skill
(the `feature` skill, or the user directly) is responsible for acting on the findings.

## Scope

Review only what changed and hasn't been committed yet:

```bash
git status --short
git diff
git diff --stat
```

Read the **full content** of every changed/added file with the Read tool — not just the diff hunks.
A diff hides context (existing surrounding code, whether a class is otherwise empty, whether a
helper already exists elsewhere) that changes whether something is actually a problem.

## What to check

Cross-reference the diff against `CLAUDE.md` in the repo root first — it documents this project's
namespacing convention (`CoffeeShops` module is config-only; everything under `app/services` and
`app/models` is a flat, top-level class with no app-specific module nesting), its error convention (one narrow `StandardError` subclass per failure domain, no broad
`rescue StandardError`), and its hard constraints (no Geocoder/distance gem, no CSV-parsing gem, no
dotenv, no ActiveRecord model for coffee shop data). Anything that drifts from these without a stated
reason is a finding.

Beyond that, look for:

- **Code smells**: duplicated logic, long/multi-responsibility methods, deep conditional nesting,
  primitive obsession, feature envy, speculative generality (abstractions with only one caller).
- **Principle violations**: SRP/SOLID, DRY, YAGNI (unused flexibility, unrequested config options),
  Law of Demeter (reaching through multiple objects).
- **Naming**: does a name reveal intent on its own, or does understanding it require reading the
  implementation?
- **Error handling**: are rescues specific and narrow, or could they mask unrelated failures? Are new
  error classes justified, or could an existing one have been reused?
- **Ruby/Rails idiom**: is this idiomatic Ruby (e.g. `Float()` not `to_f` where precision matters, as
  already established in `CsvParser`), or does it fight the language/framework?
- **Test coverage**: do the new specs actually exercise the edge cases the implementation claims to
  handle (blank input, malformed input, boundary values), or do they only cover the happy path?
- **Scope creep**: did the change do more than the feature prompt asked for — unrelated refactors,
  premature abstractions, unused options "for later"?

Do not flag pre-existing issues in code the diff didn't touch — this is a review of what just
changed, not a full-codebase audit.

## Output

Report one of two outcomes:

**GREEN** — nothing worth changing. State briefly what you checked (files reviewed, conventions
cross-referenced) so the caller knows the round wasn't a rubber stamp.

**Findings** — a ranked list (most important first), each with:
- File and line.
- The concrete problem (name the smell/principle, don't just assert "this is bad").
- Why it matters *here* — what breaks, what gets harder to change, or which existing convention it
  contradicts. Avoid nitpicks with no real consequence.

Do not soften a genuine finding to reach GREEN, and do not invent a finding to look thorough when the
code is actually fine — both defeat the point of running this loop.
