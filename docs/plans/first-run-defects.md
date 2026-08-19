---
slug: first-run-defects
status: draft
created: 2026-08-19
design: docs/DESIGN.md §5 R6/R9 — the driver runs unattended and leaves durable evidence — and R2, the plan gate whose carve-outs bind it
covers: [R2, R6, R9]
---

# Fix what the first unattended run found — Plan

## Summary

The first unattended run of the delivery driver in a generated project — the
first end-to-end run anywhere, ever — exposed seven defects. All seven
originate here. The downstream collection point is mirrored verbatim at
`docs/projects/find_best_mobo/template-bugs.md` (TB-1 … TB-7); the ledger rows
for them are appended in this change's first commit, and every fix below lands
with a check observed red against the old code and green against the fix.

- **TB-1** — no worker could ever start: every prompt built from a command file
  begins with `---` frontmatter, and `spawn-worker.sh` passed it with no `--`
  terminator. Fixed twice over: the terminator (both engines), and the driver
  now strips frontmatter before using a command file as a prompt.
- **TB-4** — the steward was told to run gate scripts it was never granted, and
  a denied `git switch` made a worker abandon a finished plan. The named
  scripts and `git switch`/`git branch` join the grants. No route to the
  default branch widens; required checks remain the fence.
- **TB-6** — a required check that never reports held the driver 90 minutes on
  a pull request another check had already failed. The watch now uses
  `--fail-fast`.
- **TB-2 / TB-3's mechanical half** — the driver's own run evidence
  (`docs/runs/`) and the backlog filings the planning rule itself requires
  (`docs/BACKLOG.md`) could not merge past the 50-line exempt cap. Both join
  `plan-resolve.sh`'s carve-out; a branch that also touches code is still
  capped.
- **TB-3's prompt half** — `steward.md` told the unattended planner to
  self-rule what `AGENTS.md` says must be filed and stopped on. Three plans of
  three were blocked for it. The command files now draw the line: delegated
  choices are derivations; genuine gaps are filed as `BL-<n>`; HIGH means stop.
- **TB-5** — every review artifact was lost to a default:
  `upload-artifact@v4` excludes hidden files, and the evidence directory is
  dot-prefixed. `include-hidden-files: true`, with a workflow-sweep test.
- **TB-7** — worker logs died with the container; `collect-evidence.sh` now
  copies this run's logs into `docs/runs/<timestamp>/workers/`.
- **Not done here, deliberately:** the structural question the run surfaced —
  a generated project cannot unblock its own driver, because `.claude/` fixes
  are (correctly) refused by the review gate — is an owner ruling, presented
  with options in the downstream postmortem, not something this plan decides.

## Uncertainties

No uncertainties — every decision derived from recorded downstream evidence
(the mirror above), and each fix reproduces its defect in a test before fixing
it. This plan is retrospective about diagnosis, not about design: nothing here
introduces behaviour the evidence did not ask for.

## Slice 1 — a dispatched worker reaches its model *(covers R6)*

- **Delivers:** a prompt built from any command file survives dispatch on both
  engines; the steward can run what its prompt names; a denied branch command
  no longer costs a commit.
- **Files:** `template/.claude/scripts/spawn-worker.sh`,
  `template/.claude/scripts/deliver-loop.sh`, `tests/test-spawn-worker.sh`,
  `tests/test-deliver-loop.sh`
- **Estimate:** ~90 lines

## Slice 2 — the watch leaves when the answer is known *(covers R6)*

- **Delivers:** a red required check ends the wait immediately; a check that
  never reports can no longer hold a decided pull request to the timeout.
- **Files:** `template/.claude/scripts/deliver-loop.sh`,
  `tests/test-deliver-loop.sh`
- **Estimate:** ~25 lines

## Slice 3 — the run's evidence can land, whole *(covers R2, R9)*

- **Delivers:** run reports, review payloads and worker logs all reach
  `docs/runs/<timestamp>/` and the branch carrying them can merge; the
  planner's required `BL-<n>` filings can travel with the plan; smuggled code
  is still capped.
- **Files:** `template/.github/scripts/plan-resolve.sh`,
  `template/.claude/scripts/collect-evidence.sh`,
  `template/.github/workflows/review.yml`, `tests/test-gates.sh`,
  `tests/test-collect-evidence.sh`, `tests/test-lint-workflows.sh`
- **Estimate:** ~140 lines

## Slice 4 — the unattended planner can comply *(covers R2)*

- **Delivers:** the steward and plan command files agree with `AGENTS.md`'s
  Planning rule: derive what the design delegates, file what it does not, stop
  on HIGH by filing rather than ruling.
- **Files:** `template/.claude/commands/steward.md`,
  `template/.claude/commands/plan.md`
- **Estimate:** ~55 lines
