---
slug: template-foundations
status: merged
created: 2026-08-18
design: everything docs/DESIGN.md §12 lists as MVP and Later, except what closing-the-loop covers
covers: [R1, R2, R4, R5, R6, R7, R11, R12, R13, R14, R15, R16]
---

# Template foundations — Plan (retrospective)

## Summary

**This plan is a record, not a proposal. Every slice below has already shipped.**
It exists because `docs/DESIGN.md` was written after the machinery it describes,
so twelve requirements had no plan claiming them — and `coverage.sh` reported
them as work nobody had scheduled. That reading was false. The work was
scheduled, built and merged; the plans that did it were implemented and then
deleted (`docs/synthesis.md`, revision 4), and their claim on those requirements
was deleted with them.

- **What this delivers:** a true answer to "is every requirement planned?".
  Nothing is built by landing it.
- **Why a plan and not a note:** `coverage.sh` is the only thing that answers
  that question, and it understands exactly one artifact. A note beside it would
  be a fact no check can read, which is the failure this repository names
  everywhere else.
- **The line that makes it honest:** every slice names the files that ARE the
  delivery, and its estimate is the measured size of those files at the base
  commit rather than a guess made beforehand. A reader can open them.
- **What it deliberately does NOT do:** claim anything unbuilt, and cover the
  four requirements `closing-the-loop` covers (R3, R8, R9, R10). Padding this
  list would hide the same gap more convincingly, which is the one direction
  that would make it worse than the absence it replaces.
- **What it costs you:** one document, and the standing risk that a
  retrospective plan is a shape somebody later uses to launder unbuilt work.
  Slice titles are past tense and this heading says "retrospective" so that
  reads wrong on sight.
- **Open question for you:** whether `status: merged` is enough to stop the
  delivery driver treating this as work to orchestrate. See "What this does not
  fix" at the end.

## Uncertainties

**No uncertainties — every decision derived from the design.** Each slice below
maps requirements to files that exist, and both sides were read rather than
guessed. The one judgement call is which requirement each shipped file delivers,
and that is checkable by opening the file.

## Slice 1 — the documents could not move under a change *(covers R1, R5)*

- **Delivers:** *(landed)* every gate reads its standard at the pull request's
  base commit, so a change cannot restate the rule it breaks; and the two intent
  documents are landed by the owner personally, which is what gives
  `docs/DESIGN.oracle.md` a reason to exist. Requirements **R1** and **R5**.
- **Files:** `template/.github/scripts/review.sh`,
  `template/.github/scripts/plan-metrics.sh`,
  `template/.github/scripts/escape-refs.sh`,
  `template/.github/scripts/owner-authored.sh`,
  `template/.github/scripts/vision-complete.sh`,
  `template/.github/review-prompt.md`
- **Estimate:** ~1129 lines *(measured, not forecast)*
- **Evidence it shipped:** `tests/test-owner-authored.sh`,
  `tests/test-escape-refs.sh`, `tests/test-vision-complete.sh`, and the
  base-commit assertions in `tests/test-gates.sh`. `ESC-25` records the defect
  that produced the authorship rule.

## Slice 2 — work was planned before it was built *(covers R2, R12)*

- **Delivers:** *(landed)* a pull request resolves to exactly one plan that
  existed at its base commit, matched by slug against the branch name, with
  `chore/`, `docs/` and `template/` exemptions that are size-capped or replaced
  by a stronger proof; and a template update is verified byte-for-byte against
  `copier update` output rather than trusted. Requirements **R2** and **R12**.
- **Files:** `template/.github/scripts/plan-resolve.sh`,
  `template/.github/scripts/plan-parse.sh`,
  `template/.github/scripts/plan-lint.sh`,
  `template/.github/scripts/template-sync.sh`
- **Estimate:** ~642 lines *(measured, not forecast)*
- **Evidence it shipped:** `tests/test-plan-parse.sh`,
  `tests/test-template-sync.sh`, and the exemption and cap fixtures in
  `tests/test-gates.sh`. `ESC-8`, `ESC-22` and `ESC-31` record the defects that
  shaped it.

## Slice 3 — the ledgers became append-only, and the oracle got one *(covers R4, R11)*

- **Delivers:** *(landed)* an agent may correct the design from logged evidence
  while nobody is awake, in a ledger where every decision cites evidence that
  already landed and quotes the vision statement it leaned on; and every ledger
  an agent may write refuses an edit to anything already in it. Requirements
  **R4** and **R11**.
- **Files:** `template/.github/scripts/oracle-decisions.sh`,
  `template/.github/scripts/escapes-append-only.sh`,
  `template/.github/scripts/backlog-append-only.sh`,
  `template/docs/DESIGN.oracle.md.jinja`,
  `template/.claude/commands/oracle.md`
- **Estimate:** ~977 lines *(measured, not forecast)*
- **Evidence it shipped:** `tests/test-oracle-decisions.sh`,
  `tests/test-escapes-append-only.sh`, `tests/test-backlog-append-only.sh`.
  `ESC-15` and `ESC-28` record the two ledgers that were unprotected.

## Slice 4 — a run drove itself, refused loudly, and had a ceiling *(covers R6, R7, R14)*

- **Delivers:** *(landed)* a driver that recomputes its state from the tree and
  the open pull requests every iteration, holds one pipeline pull request at a
  time, and names every stop; a readiness check that refuses at dispatch rather
  than warning; and a ceiling the owner chooses each run, with the rate limit as
  the only default stop. Requirements **R6**, **R7** and **R14**.
- **Files:** `template/.claude/scripts/deliver-loop.sh`,
  `template/.claude/scripts/deliver-phase.sh`,
  `template/.claude/scripts/budget-probe.sh`,
  `template/.github/scripts/unattended-ready.sh`,
  `template/.claude/commands/deliver-loop.md`
- **Estimate:** ~1331 lines *(measured, not forecast)*
- **Evidence it shipped:** `tests/test-deliver-loop.sh`,
  `tests/test-budget-probe.sh`, `tests/test-unattended-ready.sh`. `ESC-29`,
  `ESC-30` and `ESC-32` record three ways a run reported success without doing
  the work.

## Slice 5 — the scaffolding underneath *(covers R13, R15, R16)*

- **Delivers:** *(landed)* two rendered language targets with their own
  toolchains; a test suite that runs offline and skips visibly rather than
  failing when `copier` is absent; and credentials that never reach a log, an
  argument vector or a committed file, with secret scanning in CI as well as in
  the local hook. Requirements **R13**, **R15** and **R16**, all three marked
  `*(non-functional)*` in the design.
- **Files:** `copier.yml`, `template/.claude/scripts/app-token.sh`,
  `template/.claude/scripts/spawn-worker.sh`, `tests/run.sh`, `tests/lib.sh`
- **Estimate:** ~927 lines *(measured, not forecast)*
- **Evidence it shipped:** `tests/test-render.sh`, `tests/test-app-token.sh`,
  `tests/test-spawn-worker.sh`, `tests/test-lifecycle.sh`, and the `secrets` job
  in `template/.github/workflows/ci.yml.jinja`. `ESC-26` records the identity
  work.

## What this does not fix

`coverage.sh` now reports every requirement covered, truthfully. **The delivery
driver still cannot be pointed at this repository**, and this plan moves the
reason rather than removing it.

`.claude/scripts/deliver-phase.sh` calls a plan BUILT when a merged branch named
`feat/<slug>` exists. No such branch will ever exist for this plan, because the
work predates it — so once the phases ahead of it clear, the detector emits
`PHASE=ORCHESTRATE SLUG=template-foundations` and the driver commissions an
orchestrator to build what is already here.

**Run the detector here today and it says `PHASE=ORACLE` first**, over
thirty-four uncited escape ids — the ledger this repository has been keeping
since before any of this existed. So the orchestrate problem is not the first
thing a run would hit; it is the one waiting behind it, and it is the one this
document creates. Both are stated so neither is discovered at 3am.

The smallest honest fix for the second is for the detector to treat a plan whose
front matter says `status: merged` as built, which is what that field already
means and what this plan already declares. That is a change to shipped
behaviour, so it is the owner's to rule on rather than something to slip in
beside a bookkeeping document. Until it is ruled on, `docs/DESIGN.md` §11
stands: do not start the driver here.
