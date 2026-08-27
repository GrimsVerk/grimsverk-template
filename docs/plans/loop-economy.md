---
slug: loop-economy
status: merged
created: 2026-08-27
design: docs/DESIGN.md §5 R4/R6/R9 — the oracle ledger, the driver, durable evidence; Stage 1 of docs/postmortem-2026-08-20-plan.md
covers: [R4, R6, R9]
---

# Loop economy — decided work outranks new questions

> **Escape rows referenced by bare number.** This branch itself appends the
> ratchet rows for these defects to `docs/escapes.md` (stubs 217-229, completed
> in the final slice). The citation rule is that an ESC id is citable only once
> its row is on the default branch at the base commit — and these rows travel
> with this very change — so they are named as "row NNN" here, the same
> travels-with-the-change form the first-run-defects plan used. After merge
> they are ordinary citable ids.

## Summary

Stage 1 of the post-mortem prevention plan (`docs/postmortem-2026-08-20-plan.md`,
whose §6 rulings Q1–Q3 this plan implements as ruled). Four changes, all to
the delivery loop's economy; none to its authority chain.

- **A superseded requirement stops being a coverage gap.** `coverage.sh`
  subtracts `**Requirements superseded:**` ids, and a new sweep test asserts
  every field the decision schema requires has at least one reader (row 219).
- **A decision gets a closure state the detector reads.** Closed by a plan
  that cites it, by an appended one-line disposition (`no work` /
  `superseded by` / `artifact ordered`), or by being a HALT. Unclosed
  decisions become a detector queue ranked above new-evidence intake
  (row 217).
- **The detector's precedence is rebalanced.** After WAIT, SETUP and
  HIGH-blocking uncertainties: close open decisions (STEWARD), build merged
  unbuilt plans (ORCHESTRATE), and only then feed non-blocking evidence to
  the oracle. Only HIGH blocks build (row 218). The detector also emits the
  economy counters (unclosed decisions, unbuilt plans, evidence backlog) and
  the driver logs them every iteration.
- **The driver gets the two missing guards and one event stream.** A
  committed per-target `do-not-dispatch` file the oracle may append to and
  the driver skips loudly (row 221, per ruling Q1 — never a run halt); a
  repetition stop when the same phase+scope repeats with nothing closed
  between (row 220); a fixture proving the fix-strike bound (row 229); and
  `emit-event.sh` — one JSONL emitter both drivers call, carrying run-scoped
  keys and the template version, with a mid-run version change stopping
  typed (row 224, row 227, row 228).
- **Costs:** the detector's phase order changes (documented in its header and
  `orchestration.md`); one new committed file the oracle may write
  (`docs/oracle/do-not-dispatch.md`); one new evidence file per run
  (`events.jsonl`). No new owner obligation.

## Uncertainties

No uncertainties — every decision here derives from
`docs/postmortem-2026-08-20-plan.md` (landed) and the owner's recorded Q1–Q3
rulings in that document. Choices the plan delegated (exact key names, exit
codes, file formats) are derivations and are recorded in the slices.

## Slice 1 — supersession has a reader *(covers R4; row 219)*

- **Delivers:** a superseded requirement disappears from the coverage gap set
  (later declaration wins by document order); a test superseding R1001 shows
  coverage clean where it livelocked before; a sweep test fails if any field
  `oracle-decisions.sh` requires is read by no shipped script.
- **Files:** `template/.github/scripts/coverage.sh`, `tests/test-coverage.sh`,
  `tests/test-field-readers.sh`
- **Estimate:** ~80 lines

## Slice 2 — closure states and the rebalanced detector *(covers R4, R6; row 217, row 218)*

- **Delivers:** a decision is OPEN until a plan cites it, an appended
  `- **Closure (OD-<n>):**` line disposes of it, or it is a HALT;
  `deliver-phase.sh` emits `PHASE=STEWARD` for unclosed decisions ahead of
  new-evidence ORACLE, walks merged unbuilt plans ahead of new-evidence
  ORACLE too, and emits `OPEN_DECISIONS=`, `UNBUILT_PLANS=`, `EVIDENCE=`
  counters on every reading; `oracle-decisions.sh` accepts the closure-line
  shape as a legal append; the driver logs the counters each iteration.
- **Files:** `template/.claude/scripts/deliver-phase.sh`,
  `template/.github/scripts/oracle-decisions.sh`,
  `template/.claude/scripts/deliver-loop.sh`,
  `template/.claude/commands/oracle.md`, `template/.claude/orchestration.md`,
  `tests/test-deliver-phase.sh`, `tests/test-oracle-decisions.sh`
- **Estimate:** ~220 lines

## Slice 3 — the brake and the missing guards *(covers R6; row 220, row 221, row 229)*

- **Delivers:** the driver skips any target listed in
  `docs/oracle/do-not-dispatch.md` and says so loudly; the detector reports
  the skip (`BRAKED=`); the driver stops typed (exit 5) when the detector
  emits the same phase+scope three times with no closure or citation change
  in between; a fixture proves the fix-strike counter stops at exactly
  three; `oracle.md` tells the oracle when and how to pull the brake.
- **Files:** `template/.claude/scripts/deliver-phase.sh`,
  `template/.claude/scripts/deliver-loop.sh`,
  `template/.claude/commands/oracle.md`, `tests/test-deliver-phase.sh`,
  `tests/test-deliver-loop.sh`
- **Estimate:** ~160 lines

## Slice 4 — one event stream, both drivers *(covers R6, R9; row 224, row 227, row 228)*

- **Delivers:** `emit-event.sh` appends one JSON line per loop event
  (detect, dispatch, result, merge, stop) to the run's `events.jsonl` with
  ts, base, run id, iteration, phase, role, ids (bare and run-scoped),
  plan, pr, exit code, template version and prompt hash; the local driver
  calls it at each transition; the web command file instructs the same
  script at the same transitions; a conformance test asserts required
  fields per event kind are never null; the driver records the template
  version at start and stops typed when it changes mid-run.
- **Files:** `template/.claude/scripts/emit-event.sh`,
  `template/.claude/scripts/deliver-loop.sh`,
  `template/.claude/commands/deliver-loop.md`,
  `template/.claude/scripts/collect-evidence.sh`,
  `tests/test-emit-event.sh`, `tests/test-deliver-loop.sh`
- **Estimate:** ~200 lines
