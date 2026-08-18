# Escapes — closed — grimsverk-template

One row per escape in [`escapes.md`](escapes.md) that is **finished**: the defect
is fixed and the check that would have caught it exists. Append only; nothing
here is ever edited.

## Why this file exists

`docs/escapes.md` is append-only and enforced, so an escape cannot be marked done
in place. "Done" therefore lived only in that ledger's *Check added* prose, which
no script reads — and the log grew for thirty-four entries without ever
converging. `docs/BACKLOG.md` hit the identical wall and got
[`BACKLOG.done.md`](BACKLOG.done.md); this is the same answer for the same
reason.

It is also read by the delivery driver.
`.claude/scripts/deliver-phase.sh` subtracts the ids closed here before deciding
the oracle has evidence to rule on. Before it existed, the detector read the id
and never the row, so it handed the oracle all thirty-four — including defects
fixed months earlier with a demonstrated check.

**A row here makes the oracle stop looking, so it must name a check that
exists.** `.github/scripts/escapes-append-only.sh` refuses a closure that names
no repository path, or names one that is not there. That rule is deliberately
weak — it proves a file is present, not that the file checks anything — and the
reasoning for accepting that is in `docs/plans/_escape-closure.context.md` §3.

## What is NOT closed here, and why

- **ESC-21** — branch cleanup after auto-merge. Built twice, wrong twice, now on
  two independent paths. **No branch has ever been observed to disappear.**
  Closing it would erase the one fact worth keeping.
- **ESC-26** — the driver's GitHub App identity. Built, and dormant: the App does
  not exist, so `unattended-ready.sh` refuses every unattended run. Closes when
  there is an App and a real run.

Both are built. Neither is observed. That distinction is the entire content of
those two rows and this file does not get to flatten it.

| Id | Date | Check that closes it | How it was demonstrated |
| --- | --- | --- | --- |
| ESC-1 | 2026-08-18 | `tests/test-spawn-worker.sh` | the engine flag is pinned through `--print-command`; red on the old script, green on the new |
| ESC-2 | 2026-08-18 | `tests/test-spawn-worker.sh` | worktrees are created outside `.claude/`, asserted through the printed command |
| ESC-3 | 2026-08-18 | `tests/test-spawn-worker.sh` | the empty-branch check refuses a worker that committed nothing |
| ESC-4 | 2026-08-18 | `tests/test-spawn-worker.sh` | fixtures cover a failing engine probe and one that reports signed-out while exiting 0 |
| ESC-5 | 2026-08-18 | `tests/test-spawn-worker.sh` | the per-role grant is a command-line whitelist, where workspace trust does not apply; pinned per role |
| ESC-6 | 2026-08-18 | `tests/test-gates.sh` | the underscore-prefixed skeleton is skipped by the lint, and no heading in it masquerades as a slice |
| ESC-7 | 2026-08-18 | `tests/test-coverage.sh` | a malformed id fails instead of being silently skipped, anchored on a digit so prose is untouched |
| ESC-8 | 2026-08-18 | `tests/test-gates.sh` | a plan introduced by its own pull request is rejected; planning documents are exempt at any size |
| ESC-9 | 2026-08-18 | `tests/test-render.sh` | the rendered orchestration documents carry the corrected instruction |
| ESC-10 | 2026-08-18 | `tests/test-render.sh` | render fixtures assert the two command files agree |
| ESC-11 | 2026-08-18 | `tests/test-render.sh` | the rendered rules carry the corrected wording |
| ESC-12 | 2026-08-18 | `tests/test-render.sh` | the ratchet's check column must record a demonstrated check or an explicitly-marked proposal |
| ESC-13 | 2026-08-18 | `tests/test-render.sh` | the ordering rule and its rejected relaxation are both stated in the rendered rules |
| ESC-14 | 2026-08-18 | `template/.github/scripts/template-sync.sh`, `tests/test-template-sync.sh` | a real conflict is built with copier, resolved by hand, and now passes while a hand edit beside it still fails |
| ESC-15 | 2026-08-18 | `tests/test-escapes-append-only.sh` | red against an edited row, a deleted row, a reorder and a deleted ledger; green against appends and corrections |
| ESC-16 | 2026-08-18 | `template/.claude/commands/orchestrate.md` | **the proposed check is DECLINED, deliberately.** The behavioural half shipped — the orchestrator is told to review its own diff the way the gate will, citing this id. The mechanical half (running the review gate on every diff before opening) is a COST fix, not a safety one: the gate did catch the original defect, correctly. It would spend a model call on every pull request against one wasted cycle on a rare repeat, and `docs/VISION.md` V5 makes cost a ceiling. Reopen with a correction row if it recurs |
| ESC-17 | 2026-08-18 | `template/.github/scripts/pr-queue.sh`, `tests/test-pr-queue.sh` | the reviewer is told how many other pull requests the author has open and how many are red — a note, never a failure, because a hard check deadlocks two pull requests opened seconds apart and the unattended path is already covered by the driver's one-PR rule |
| ESC-18 | 2026-08-18 | `tests/test-spawn-worker.sh` | each role's model, effort and grants are pinned through `--print-command`, including that the test-writer is not cheaper than the coder |
| ESC-19 | 2026-08-18 | `tests/test-gates.sh` | the shipped oracle skeleton is run through `coverage.sh` and asserted to define no requirement; red against the unanchored rule, green after |
| ESC-20 | 2026-08-18 | `tests/test-gates.sh` | the `TEMPLATE SYNC:` fact is asserted on wording unique to it and naming the branch, after the first fixture proved toothless |
| ESC-22 | 2026-08-18 | `tests/test-gates.sh` | a 150-line vision branch is exempt at any size, and a vision doc carrying code alongside it is still capped |
| ESC-23 | 2026-08-18 | `tests/test-lifecycle.sh` | a project is generated and walked through its own documented sequence, asserting each step is POSSIBLE; all three escapes this entry was recorded over would have been red against it |
| ESC-24 | 2026-08-18 | `tests/test-render.sh` | transcription and authorship are distinguished in all three rendered documents; red against the previous wording |
| ESC-25 | 2026-08-18 | `tests/test-owner-authored.sh` | 22 assertions covering both directions, 8 red against a permissive check |
| ESC-27 | 2026-08-18 | `tests/test-render.sh` | every gate-path list names `.claude/`, the intent documents are denied to every session, and no session may spawn a headless agent around the role system |
| ESC-28 | 2026-08-18 | `tests/test-backlog-append-only.sh` | filing stays free and rewriting does not, across all three backlog ledgers |
| ESC-29 | 2026-08-18 | `tests/test-deliver-loop.sh` | the acceptance marker is written only after a session that succeeded AND changed the file; twice-empty or twice-failed stops the run |
| ESC-30 | 2026-08-18 | `tests/test-deliver-loop.sh` | the slug is read from front matter and anchored, including the `auth` / `authentication-overhaul` collision |
| ESC-31 | 2026-08-18 | `tests/test-template-sync.sh` | `_src_path` is compared between base and head and a move fails, naming both |
| ESC-32 | 2026-08-18 | `tests/test-budget-probe.sh` | 20 assertions over a probe that had never been run; the weekly window, both limits, and a mid-run rollover |
| ESC-33 | 2026-08-18 | `tests/test-reviewer.sh`, `tests/reviewer-fixtures/` | twelve fixtures from the traced attacks — eight the gate must block, four it must pass — closing the "nothing tests the reviewer" half this entry left open |
| ESC-34 | 2026-08-18 | `tests/test-render.sh` | no deny rule uses the `Write(...)` form, which binds to nothing; red against the previous settings |
| ESC-35 | 2026-08-18 | `tests/test-deliver-loop.sh` | `gh pr create` is absent from the orchestrator's grant and the driver opens both pull requests itself, as the App; red against the previous dispatches, green after |
