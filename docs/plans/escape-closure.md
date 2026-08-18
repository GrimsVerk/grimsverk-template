---
slug: escape-closure
status: draft
created: 2026-08-18
design: docs/DESIGN.md §11 — the two things that block the delivery driver here
covers: [R11]
---

# Escape closure — the ledger learns to converge

## Summary

**`docs/escapes.md` only grows.** Thirty-one of its thirty-four rows record a
defect that was fixed, with a check named and demonstrated. Nothing mechanical
knows that. `deliver-phase.sh` reads the *id* and never the row, so it hands all
thirty-four to the oracle as unruled evidence — and the oracle has to re-derive,
by reading prose, a fact the ledger already contains.

The backlog solved this exact problem and the escapes ledger never got the same
treatment: both are append-only, so neither can be edited to mark something
done, and only one has a companion file that says what came of it.

- **What this delivers:** `docs/escapes.done.md`, the escapes ledger's missing
  done-log; the driver reading it; and the three genuinely-open escapes resolved
  or explicitly closed.
- **A closure names a check that exists**, verified by path. Otherwise this file
  becomes a way to make the oracle skip evidence by asserting it is fine, which
  is the one direction that would make it worse than nothing.
- **It is NOT `CODEOWNERS`-owned**, for the same reason the backlog is not: an
  agent closes an escape when its fix lands, and an owner review on that path
  stops overnight work. Immutability and a checkable claim replace permission.
- **ESC-14 is fixed at file level, not hunk level** — a conflicted file is exempt
  from byte-matching and named in the output; every other file stays exact.
- **ESC-16 is closed with reasoning rather than built.** The gate already caught
  it and the behavioural fix already shipped; the remaining gap is one wasted
  cycle, and the mechanical version costs a model call on every pull request.
- **ESC-17 is advisory, never red.** A hard check can deadlock two pull requests
  against each other, and the unattended path — the one that matters — is
  already covered by the driver's one-PR rule.
- **What it costs you:** one new ledger, one new fact in the review payload, and
  a slower `template-sync` on conflicted updates.
- **Open question for you:** whether `status: merged` on a plan is the right
  signal for "already built" (slice 2), or whether you want a distinct field.

## Uncertainties

**No uncertainties — every decision derived from the design and the ledger.**
The three open escapes were read in full and their proposed checks are quoted in
`docs/escapes.md`. The one judgement is ESC-16, and it is recorded as a judgement
rather than taken silently: the check the ledger proposed is declined, with the
reason written into its closure row.

## Slice 1 — the escapes ledger gets a done-log *(covers R11)*

- **Delivers:** `docs/escapes.done.md` — append-only, one row per closed escape,
  naming the check that closed it. A closure row whose named check is not a path
  that exists fails, so "closed" is a claim somebody can open. Requirement
  **R11**, extended to the one ledger that had no companion.
- **Files:** `template/docs/escapes.done.md.jinja`,
  `template/.github/scripts/escapes-append-only.sh`,
  `template/docs/escapes.md.jinja`,
  `template/.github/workflows/ci.yml.jinja`,
  `tests/test-escapes-append-only.sh`
- **Estimate:** ~220 lines

`escapes-append-only.sh` takes a `LEDGERS` list, exactly as
`backlog-append-only.sh` already does for its three files, and gains one rule the
backlog does not need: every closure row must name at least one repository path,
and that path must exist at HEAD. A row saying "closed — it is fine now" is
refused.

## Slice 2 — the driver reads what the repository already knows *(covers R11)*

- **Delivers:** `deliver-phase.sh` subtracts escapes closed in the done-log
  before deciding the oracle has work, and treats a plan whose front matter says
  `status: merged` as built. Both are durable facts sitting in git that the
  detector currently ignores in favour of a gitignored file and a branch name.
- **Files:** `template/.claude/scripts/deliver-phase.sh`,
  `template/docs/plans/_TEMPLATE.md.jinja`,
  `tests/test-deliver-loop.sh`
- **Estimate:** ~90 lines

The gitignored `processed-evidence` file stays as it is — it records what one
run dismissed *without* closing, which is a different claim. What changes is
that a closure committed to the repository now counts, so a web session with a
reclaimed container reaches the same answer as a laptop.

## Slice 3 — a conflicted template update can land *(covers R12)*

- **Delivers:** `template-sync.sh` stops demanding a byte-identical tree for
  files `copier update` handed to a human. It replays as before, finds the files
  the replay left conflict markers in, exempts exactly those from byte-matching,
  and **names them in its output** so the reviewer knows which files carry a hand
  resolution. Every other file is still exact. Closes ESC-14.
- **Files:** `template/.github/scripts/template-sync.sh`,
  `template/.github/review-prompt.md`,
  `tests/test-template-sync.sh`
- **Estimate:** ~120 lines

Today the only tree that satisfies this check after a conflict is one with
conflict markers committed to the default branch. That is a gate blocking the
change it exists to authorise — the shape of ESC-20, ESC-22 and ESC-24. File
level rather than hunk level is a deliberate trade: a hand edit hidden inside a
conflicted file still gets through, and the check now tells the reviewer exactly
which files to read for it.

## Slice 4 — the reviewer is told about the queue *(covers R1)*

- **Delivers:** a new fact script reporting how many other pull requests the same
  author has open and how many are not green, emitted into the mechanical facts
  region. A note, never a failure. Closes ESC-17 for the attended path; the
  unattended path was already covered by the driver's one-PR rule.
- **Files:** `template/.github/scripts/pr-queue.sh`,
  `template/.github/scripts/review.sh`,
  `template/.github/review-prompt.md`,
  `template/.github/workflows/review.yml`,
  `tests/test-pr-queue.sh`
- **Estimate:** ~140 lines

A hard check was considered and rejected in the plan summary: two pull requests
opened seconds apart would each see the other and both fail, and the tiebreak
that fixes it is more machinery than the problem is worth while the driver
already prevents the unattended case.

## Slice 5 — this repository's own ledger converges *(covers R11)*

- **Delivers:** `docs/escapes.done.md` at the root, backfilled with every escape
  this repository has actually closed, each naming its check. The oracle phase
  drops from thirty-four ids to the ones that genuinely need a ruling, and it
  stays there in a fresh clone.
- **Files:** `docs/escapes.done.md`, `docs/escapes.md`, `docs/DESIGN.md`,
  `tests/test-render-governance.sh`
- **Estimate:** ~80 lines

ESC-16's closure row carries the declined check and why. ESC-21 and ESC-26 are
**not** closed: both are built and neither has been observed live, which is what
their rows already say and what closing them would erase.

## What this does not fix

Nothing here makes an unattended run *safe* — the App identity still does not
exist and `unattended-ready.sh` still refuses without it. It makes the driver's
first two answers correct, which is a precondition rather than a permission.

And the file-level conflict exemption in slice 3 is asserted, not observed: no
conflicted `copier update` has been replayed through the new code. The first
real one is the test.
