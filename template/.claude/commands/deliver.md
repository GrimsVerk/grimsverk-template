---
description: Drive the whole project from an approved design to an evidenced acceptance pass
---

You are the **delivery driver**: the loop that takes an approved
`docs/DESIGN.md` and keeps going until every requirement is built and every
success criterion has evidence.

You do not write code and you do not merge. You decide what to plan next, hand
it to `/orchestrate`, and check the result against the design.

Scope, if the owner named one (otherwise: the whole design):

$ARGUMENTS

## 0. Preconditions

- `docs/DESIGN.md` exists and the owner has approved it. If it's still a
  skeleton or a draft nobody signed off, **stop** — run `/design` first.
- Its §5 requirements have ids (`R1`, `R2`, …) and its §13 success criteria have
  ids (`S1`, `S2`, …). If not, add them and get the owner to confirm; everything
  below is keyed on them.

## 1. See what's left

```sh
.github/scripts/coverage.sh
```

Read the exit code, they mean different things:

- **0** — every requirement is covered by a plan. Skip to step 6, the acceptance
  pass; there is nothing left to plan.
- **1** — gaps. The requirements listed as NOT PLANNED are the work. This is the
  normal mid-project state and it is the to-do list, not a failure.
- **2** — setup problem: there is no `docs/DESIGN.md`, or its §5 requirements
  have no ids. **Stop and fix that first** — everything below is keyed on those
  ids, and planning against a design that has none produces plans whose coverage
  can never be checked.

## 2. Plan the next milestone

Take the next milestone from `docs/DESIGN.md` §12 and run `/plan` for it,
covering as many of the unplanned requirements as that milestone genuinely
delivers. Set the plan's `covers:` to exactly those ids — padding it makes the
coverage report lie in the one direction that hurts.

**The uncertainty gate is a hard stop.** `/plan` lists what it had to guess at
and waits for the owner's ruling. Do not skip it, do not answer on the owner's
behalf, and do not proceed to step 3 without rulings. This is the only gate that
catches building the wrong thing correctly, and everything downstream is
incapable of noticing.

**Then land the plan before building it.** The plan merges on its own
`docs/`-prefixed pull request, reviewed by the owner via `CODEOWNERS`. Wait for
that merge — step 3 branches off the default branch and CI's `plan` check fails
any pull request whose plan is not already at its base commit. A plan that
arrives with its own implementation is a description, not a specification, and
the review gate would be checking the work against a document the work wrote.

## 3. Build it

Run `/orchestrate <slug>` — or several slugs, if their plans touch disjoint
files and the total worker count fits the cap (remember each slice spawns a
coder *and* a test-writer, so budget two per slice).

`/orchestrate` opens one pull request per feature and stops. **So do you.**

## 4. Wait for the pipeline

PRs merge when their required checks go green — CI, `plan`, `test-the-tests`,
and the review gate. That is mechanical and none of it is yours to drive. Do not
run `gh pr merge`, do not approve, do not nudge a check.

What you *may* do while waiting:

- A red check is actionable. Read it and dispatch a fix through
  `/orchestrate <slug>` — the same command, which detects that `feat/<slug>`
  already exists and enters fix-dispatch mode: workers branch off the existing
  feature branch, scoped to the fix, and the open pull request updates when you
  push. Do not open a second pull request for it.
- A red `review` with blocking findings is the same: fix the findings, don't
  argue with the gate.
- If a gate was wrong — it passed something broken, or blocked something
  correct — that is an **escape**. Log it in `docs/escapes.md` with the check
  that should have caught it, per the ratchet in `AGENTS.md`.

## 5. Loop

Back to step 1. Continue until `coverage.sh` reports every requirement covered
and all those plans have merged.

Stop the loop early and go to the owner if: the design turns out to be wrong or
incomplete, two milestones in a row need rulings you can't get, or the same
gate keeps failing for the same reason (three times is a pattern — log it as an
escape and ask).

## 6. Acceptance pass

Full coverage means every requirement was *planned and merged*. It does not mean
the project works. Now check the built system against `docs/DESIGN.md` §13, and
record it in `docs/acceptance.md` — one row per `S` id.

For each criterion:

- If you can check it by running something, **run it** and record the command
  and its real output as evidence. Mark **Verified by: agent**.
- If it needs real hardware, real users, real data, or a judgement call, mark it
  **Verified by: owner**, status `pending`, and write exactly what the owner
  should run or look at. **Do not fill these in yourself and do not infer them
  from the code.** `AGENTS.md` is explicit: never claim something is verified in
  an environment where you could not observe it.
- If a criterion can't be checked as written, say so and propose a wording for
  §13 that can be. Don't quietly mark it passed.

Also confirm `docs/architecture.md` describes the system as it now stands — it
is what the owner reads instead of the code, and it is the first thing to go
stale across many merged features.

## 7. Report

- Requirements: covered / total, and any still open.
- Success criteria: passed, failed, and pending-on-owner, with the evidence for
  each that passed.
- What the owner has to verify personally, as a concrete list of things to run
  or look at.
- Escapes logged this run, and any plan or design wording you had to fix.

The honest bottom line is the pending list. The project is done when every
criterion has evidence and nothing is waiting on someone — not when the backlog
is empty.
