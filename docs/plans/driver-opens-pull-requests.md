---
slug: driver-opens-pull-requests
status: draft
created: 2026-08-18
design: docs/DESIGN.md §5 R5 — the intent documents are landed by the owner, and the identity that makes that checkable
covers: [R5, R6]
---

# The driver opens every pull request — Plan

## Summary

`ESC-26` gave the unattended driver a GitHub App identity so a driver-opened
pull request is not authored by the owner. **It fixed the two places the driver
opens pull requests itself and missed the two places a SESSION opens one.**

`ORCH_TOOLS` grants `Bash(gh pr create:*)`, and `run_session()` passes no
credential, so an orchestrate or acceptance session inherits the owner's local
`gh` auth. Every feature pull request and every acceptance pull request in an
unattended run is authored by the owner. Same defect as `ESC-26`, on a path its
fix did not reach — the pattern `ESC-22` and `ESC-27` both record.

- **The acceptance pull request is the sharp end, and it is not provenance.**
  `docs/acceptance.md` is `CODEOWNERS`-owned and **GitHub does not let an author
  approve their own pull request.** Opened as the owner, the one artifact whose
  review is the entire point of the run cannot be approved by the only person
  who may approve it. Opened as the App, it can.
- **`owner-authored.sh` is hollow on these paths**, for exactly the reason
  `ESC-26` describes: it compares the author's login to the owner's, and gets a
  true answer that stopped meaning anything the moment a script pressed the
  button.
- **The fix is to move the button, not to hand out the token.** `gh pr create`
  leaves `ORCH_TOOLS`; the driver opens the pull request after the session
  returns, exactly as it already does for workers. A token passed into a session
  would expire inside it — installation tokens last an hour and a session may
  not.
- **Attended `/orchestrate` and `/deliver` keep opening pull requests as you.**
  A human doing a human thing is correct, and the driver marks its own dispatches
  `UNATTENDED RUN` so the command files can tell which they are in.
- **What it costs you:** the orchestrator can no longer open a pull request at
  all, so a session that ends without pushing leaves nothing — the driver's
  empty-branch handling has to cover that.
- **Open question for you:** whether attended `/orchestrate` should ALSO use the
  App. This plan says no, on the grounds that you opening your own pull request
  is the honest record; say so if you would rather have one identity everywhere.

## Uncertainties

**One, and it is filed rather than guessed.** GitHub's refusal to let an author
approve their own pull request is documented behaviour, but the specific
interaction — a `CODEOWNERS`-owned path plus
`required_approving_review_count: 0` plus `require_code_owner_review: true`,
with the author being the sole code owner — has **not been observed** in this
repository. The plan proceeds on the reading that such a pull request cannot be
approved. If that is wrong, this slice is still correct for provenance and the
acceptance argument is weaker rather than absent.

Everything else derives from the code: `ORCH_TOOLS` at
`deliver-loop.sh:179`, `run_session()` at `:497`, and the two dispatches at
`:687` and `:713`.

## Slice 1 — the orchestrator stops opening pull requests *(covers R5, R6)*

- **Delivers:** `Bash(gh pr create:*)` leaves `ORCH_TOOLS`, and the driver opens
  the feature and acceptance pull requests itself, as the App, after the session
  returns. A session that already opened one is detected rather than
  double-opened, so an attended run and a stale worktree both stay safe.
  Requirements **R5** and **R6**.
- **Files:** `template/.claude/scripts/deliver-loop.sh`,
  `tests/test-deliver-loop.sh`
- **Estimate:** ~130 lines

`mechanical_pr()` already does this for worker branches and needs only to be
reachable for a branch that keeps its own name — a feature branch must stay
`feat/<slug>` or `plan-resolve.sh` cannot match the slug. Opening is
idempotent: if a pull request already exists for the head ref, say so and
continue rather than failing the phase.

## Slice 2 — the command files learn which mode they are in *(covers R6)*

- **Delivers:** `/orchestrate` and `/deliver` step 6 push their branch and stop
  when the driver commissioned them, and open the pull request themselves when a
  human did. The driver marks its dispatches `UNATTENDED RUN`, which is the
  marker the worker prompts already carry and these two did not.
- **Files:** `template/.claude/commands/orchestrate.md`,
  `template/.claude/commands/deliver.md`,
  `template/.claude/commands/deliver-loop.md`,
  `tests/test-render.sh`
- **Estimate:** ~110 lines

Without the marker the command file cannot tell the two apart, and the same
prose has to be right for both. That is how this defect survived `ESC-26`: the
worker dispatches carry `UNATTENDED RUN` and were fixed; these two carry nothing
and were not.

## Slice 3 — the ledger records it *(covers R11)*

- **Delivers:** a new row in `docs/escapes.md` — the next unused id — naming
  what escaped, which gate should have caught it, and the check that now does;
  and its closure in `docs/escapes.done.md`. The oracle sees a defect that was
  found and finished rather than one it has to rule on.

  **The id is deliberately not written here.** `escape-refs.sh` resolves every
  `ESC-<n>` citation in a plan against the ledger at the pull request's BASE
  commit, and an entry created by this same branch does not exist there. That
  check refused this document on its first draft, which is the rule doing its
  job: a plan citing an id nobody can look up is making a claim that is false at
  the only moment anything checks it.
- **Files:** `docs/escapes.md`, `docs/escapes.done.md`
- **Estimate:** ~30 lines

The gate column is the interesting one: **nothing could have caught this.**
`owner-authored.sh` asks a true question and gets a true answer;
`unattended-ready.sh` reads repository settings, not tool grants. What now
catches it is a fixture asserting `gh pr create` is absent from `ORCH_TOOLS` —
the same shape as the `ESC-27` fixtures over the same variable.

## What this does not fix

Nothing here stops a human, or an agent running in an interactive session with
your credentials, from opening a pull request as you. That is not a hole to
close: it is what an interactive session IS, and the boundary this plan draws is
around the **unattended** driver, which is the only context where nobody is
present to notice.

And the acceptance-approval deadlock is asserted, not observed. The first real
unattended run that reaches acceptance is the test.
