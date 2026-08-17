---
name: feature
description: Implements a new feature from a natural-language prompt in this repo, then drives it through the devils-advocate review skill (fix, re-review, repeat) until two consecutive green rounds, then runs and clears bin/rubocop. Use for new-feature/new-behavior requests; skip for pure Q&A, docs, or trivial one-line fixes.
---

# Feature implementation with Devil's Advocate gate

The `args` passed to this skill are the natural-language description of the feature to build.

## Step 1 — Orient

Read `CLAUDE.md` in the repo root before writing any code. It documents the request-time pipeline
architecture, the `CoffeeShops`/`CoffeeShop` namespacing convention, the error-class convention, and
the hard constraints (no Geocoder/distance gem, no CSV-parsing gem, no dotenv, no ActiveRecord model
for coffee shop data). New code must fit these, not introduce a parallel convention.

## Step 2 — Implement

Build the feature described in `args`, following the existing patterns in the codebase (see how
`CsvClient` and `CsvParser` are structured and tested as reference points).
Add specs alongside the implementation, matching the existing RSpec + WebMock style under `spec/`.

Run the relevant specs, then the full suite (`bundle exec rspec`), before moving on. Do not proceed
to the review loop with a red test suite.

## Step 3 — Devil's Advocate loop

Track a counter of consecutive green rounds, starting at 0.

1. Invoke the `devils-advocate` skill.
2. If it returns **GREEN**: increment the counter. If the counter has now reached 2, exit the loop.
   Otherwise, invoke `devils-advocate` again (a second look, since code doesn't change between two
   back-to-back green rounds unless something new is found — this catches a reviewer that rubber-stamps
   on the first pass).
3. If it returns **findings**: reset the counter to 0. Address each legitimate finding (if you disagree
   with one, say why instead of silently applying it), rerun the affected specs, then invoke
   `devils-advocate` again.

Report each round's outcome to the user as it happens (green, or what was found and fixed) — don't
only report the final state.

## Step 4 — Lint

Once the loop exits on two consecutive greens, run:

```bash
bin/rubocop
```

Fix any offenses it reports (prefer fixing the underlying code over disabling a cop, unless the cop is
clearly wrong for this case — say so if you disable one). Re-run `bin/rubocop` until clean.

## Step 5 — Report

Summarize: what was implemented, files changed, what each DA round found (or "green" both times), and
confirm `bin/rubocop` is clean. Do not commit or push — this project's convention is that the user
manages git.
