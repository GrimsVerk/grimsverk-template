---
slug: lexicon-and-rehearsal
status: in-flight
created: 2026-08-27
design: docs/DESIGN.md §5 R4/R6/R11 — one vocabulary, a loop that is rehearsed before it is trusted; Stage 3 of docs/postmortem-2026-08-20-plan.md
covers: [R4, R6, R11]
---

# Lexicon and rehearsal — freeze the words, then drive the loop in CI

## Summary

Stage 3 of the post-mortem prevention plan. Three changes.

- **One lexicon, sourced not paraphrased.** `lexicon.sh` declares the loop's
  vocabularies — phases, verdicts, closure states, risk classes — as shell
  variables; scripts source it instead of restating the lists; a drift
  check fails when a command file or gate script uses a phase or verdict
  spelling the lexicon does not carry (ESC-225).
- **One decision schema, and a one-line clearance for LOW.** HALT entries
  keep their meaning but stop being a second schema: the checker accepts
  one field set with `HALT` as a kind (legacy HALT entries still pass). An
  appended `- **Cleared (OD-free):** BL-<n> — LOW, default stood: <line>`
  costs one line, satisfies the schema check, and the detector reads it as
  citation — a defaulted LOW item never again buys an eight-field ruling
  (ESC-225, ESC-226).
- **The loop is rehearsed in CI.** `test-loop-economy.sh` drives the real
  detector and driver over a manufactured repository through the failure
  shapes of 2026-08-20: reaches ORCHESTRATE with pending LOW evidence,
  clears the steward queue by closure, survives a supersession, honours the
  brake, and stops typed on repetition — each historical failure red before
  its fix, green after. The escape rows this whole effort opened are
  completed here, red/green demonstrated (ESC-217..ESC-229 completions).
- **Costs:** one sourced file all loop scripts depend on; one slower test
  file in the suite (V9 accepts it).

## Uncertainties

No uncertainties — every decision derives from
`docs/postmortem-2026-08-20-plan.md` (landed, W6 and W7) and the rulings
recorded there (Q2: the oracle writes the clearance, batched; Q3: closure
lives in the ledger itself).

## Slice 1 — the lexicon and its drift check *(covers R6; ESC-225)*

- **Delivers:** `lexicon.sh` holds the phase, verdict, closure and risk
  vocabularies; `deliver-phase.sh` and `deliver-loop.sh` source it; a test
  fails when a shipped command file or script names a phase or verdict the
  lexicon does not define.
- **Files:** `template/.claude/scripts/lexicon.sh`,
  `template/.claude/scripts/deliver-phase.sh`,
  `template/.claude/scripts/deliver-loop.sh`, `tests/test-lexicon.sh`
- **Estimate:** ~120 lines

## Slice 2 — one schema, and the LOW clearance line *(covers R4, R11; ESC-225, ESC-226)*

- **Delivers:** `oracle-decisions.sh` checks one field set with kind
  `HALT`/`decision` (legacy HALT shape still passes); an appended
  `- **Cleared:**` line citing a BL id passes the schema and append-only
  checks; the detector counts a cleared id as cited; `oracle.md` instructs
  the batch clearance for defaulted-LOW items.
- **Files:** `template/.github/scripts/oracle-decisions.sh`,
  `template/.claude/scripts/deliver-phase.sh`,
  `template/.claude/commands/oracle.md`, `tests/test-oracle-decisions.sh`,
  `tests/test-deliver-phase.sh`
- **Estimate:** ~140 lines

## Slice 3 — the rehearsal *(covers R6; ESC-217..ESC-229 completions)*

- **Delivers:** `test-loop-economy.sh` drives detector and driver through
  the five 2026-08-20 failure shapes over a manufactured repository with a
  stub `gh`; each shape's assertion is red against the pre-plan scripts and
  green now; the escape rows opened as stubs are completed with the
  demonstrated checks.
- **Files:** `tests/test-loop-economy.sh`, `tests/run.sh`,
  `docs/escapes.md`
- **Estimate:** ~200 lines
