---
slug: qualitative-findings
status: in-flight
created: 2026-08-27
design: docs/DESIGN.md §5 R4/R6 — the oracle ledger and the driver; the owner's rulings on docs/postmortem-2026-08-20-plan.md Appendix E
covers: [R4, R6]
---

# Qualitative findings — the seven approved defaults

> **Escape rows referenced by bare number.** This branch appends the ratchet
> rows for these defects to `docs/escapes.md` (stubs 230-236, completed in
> the final slice). An ESC citation must resolve on the default branch at
> the base commit, and these rows travel with this very change, so they are
> named "row NNN" here — the travels-with-the-change form the
> first-run-defects plan established. After merge they are ordinary ids.

## Summary

The owner ruled on all seven findings of the qualitative deep-read
(`docs/postmortem-2026-08-20-plan.md`, Appendix E): every recommended
default, as written. This plan implements them.

- **Intake reads sections, not the whole file** (row 230): the detector
  hands the oracle only the Uncertainties section and open escapes;
  Proposed and Approved items wait until something cites them, and the
  reading reports how many it skipped.
- **The one-line clearance extends to escapes** (row 231): "read, nothing
  to do" becomes a committed, immutable, reasoned line — no new power, the
  cheap spelling of the citation the oracle could always write.
- **`Clarifies:` is a disposition** (row 232): a ruling that re-reads
  landed text declares its target; the gate resolves a clarified OD id.
- **Four prompt duties** (row 233): ids are free, one per obligation; a
  measurement cited as evidence commits its inputs; requirement scope never
  exceeds evidence scope; weigh plain refusal before halting.
- **The two vision fields cannot cite the same statement** (row 234): a
  one-line lint, new decisions only.
- **Discoveries and vision gaps get queues** (row 235): the driver
  transcribes a handoff's `## Discoveries` into the backlog as Proposed at
  the run's stop — the oracle gains no write surface; and
  `docs/oracle/vision-gaps.md` joins retirement-suggestions as an
  owner-only file nothing machine-reads.
- **A double-claimed requirement gets a note** (row 236): printed, never
  red, like the other adequacy notes.
- **Costs:** one detector behavior change (section-aware intake — an item
  filed in the wrong section now waits for a citation instead of being
  swept in; the skipped count keeps that visible), one new owner-read file,
  and a stop-time backlog append by the driver. Nothing blocks, nothing
  new stops a run.

## Uncertainties

No uncertainties — every decision derives from the owner's explicit ruling
("i like all the defaults you listed for the 7 findings"), recorded with the
findings in `docs/postmortem-2026-08-20-plan.md` Appendix E.

## Slice 1 — section-aware intake *(covers R6; row 230)*

- **Delivers:** the detector's evidence reading lists only Uncertainties-
  section items and open escapes; Proposed/Approved ids surface only when
  cited; `PROPOSED_SKIPPED=` counts what waits; the driver logs it.
- **Files:** `template/.claude/scripts/deliver-phase.sh`,
  `template/.claude/scripts/deliver-loop.sh`, `tests/test-intake.sh`
- **Estimate:** ~90 lines

## Slice 2 — clearance for escapes, Clarifies, and the vision lint *(covers R4; rows 231, 232, 234)*

- **Delivers:** `- **Cleared:** ESC-<n> — <why>` passes the gate with the
  BL rules minus the HIGH rule; `- **Clarifies:** OD-<n>` satisfies the
  disposition rule and its target must exist; a new decision whose two
  vision fields quote the same statement fails.
- **Files:** `template/.github/scripts/oracle-decisions.sh`,
  `tests/test-esc-clearance.sh`, `tests/test-clarifies-and-lints.sh`,
  `tests/test-field-readers.sh`
- **Estimate:** ~130 lines

## Slice 3 — the prompt duties and the owner-read queues *(covers R4, R6; rows 233, 235)*

- **Delivers:** oracle.md carries the four duties, the Clarifies duty, the
  ESC-clearance meaning ("read" is not "fixed"), and the vision-gaps file;
  the driver transcribes `## Discoveries` from this run's handoffs into
  `docs/BACKLOG.md` as Proposed at the stop, provenance named, never twice;
  the nothing-reads-it guarantee extends to vision-gaps.
- **Files:** `template/.claude/commands/oracle.md`,
  `template/.claude/scripts/deliver-loop.sh`,
  `tests/test-deliver-loop.sh`, `tests/test-retirement-suggestions.sh`
- **Estimate:** ~140 lines

## Slice 4 — the double-claim note, and the rows completed *(covers R4; rows 230-236)*

- **Delivers:** coverage prints a note naming any requirement claimed by
  more than one plan, never red; the seven stub rows gain their completing
  corrections with the demonstrated checks.
- **Files:** `template/.github/scripts/coverage.sh`,
  `tests/test-clarifies-and-lints.sh`, `docs/escapes.md`
- **Estimate:** ~60 lines
