---
slug: unattended-operation
status: draft
created: 2026-08-16
covers: []
---

# Unattended operation — Plan

## Summary

The owner's stated goal is three jobs and no others: **approve the vision and
design, review the result, loop.** Everything between those is meant to run
while they sleep. Today it does not, and the reason is not the agents — it is
that every pull request waits for a human hand.

Six slices, in an order chosen deliberately:

- **1. Prove the merge cycle.** One pull request that arms, merges, and deletes
  its branch with nobody watching. `ESC-21` has been "fixed" three times and no
  branch has ever been observed disappearing. Until this is seen, nothing below
  is worth building — an agent that runs all night just accumulates open pull
  requests.
- **2. Survive the rate limit.** Retry with backoff on `arm-auto-merge`, and cut
  the API chatter that shares the same per-user budget.
- **3. A readiness check.** A script that asks the *repository* whether it can
  run unattended — auto-merge enabled, required checks present, token set,
  `CODEOWNERS` resolving to a real user — and refuses the run if not.
- **4. Remove the designed stops.** Uncertainties stop blocking on the owner and
  become oracle input; the oracle gains a decision class for "the vision did not
  decide this"; `AGENTS.md` loses the sentence that says planning stops.
- **5. The driver.** Nothing currently wakes anything up. A loop entry point, a
  budget ceiling, and a stopping condition (`docs/acceptance.md`).
- **6. The lifecycle fixture.** `ESC-23`: run the whole chain against fixtures in
  CI, so the next break is caught by the template rather than by the owner.

Decisions the owner could refuse:

- **Order.** Slices 1 and 3 come before 4. Removing the stops first makes an
  unattended run fail *faster and more quietly*, which is worse than failing
  while someone is awake.
- **The readiness check blocks.** It is a refusal, not a warning. A warning
  nobody reads at 3am is decoration.
- **The budget ceiling halts the loop** rather than degrading to a cheaper model
  or a smaller scope. A loop that quietly gets worse when it runs low is harder
  to diagnose than one that stops and says why.
- **The three jobs are load-bearing, not aspirational.** Anything that would add
  a fourth recurring job for the owner is out of scope by construction.

Costs: one more required check, one secret, repository settings that only the
owner can toggle, and money spent while nobody is watching.

---

## What this cannot ship, and why it matters most

The template ships files. Every failure this month lived somewhere a file cannot
reach:

| Lives in the template | Lives only in the repository |
|---|---|
| the auto-merge workflow | the **Allow auto-merge** repository setting |
| the retry logic | the `AUTO_MERGE_TOKEN` secret's value |
| `owner-authored.sh` | who the owner's account actually is |
| the readiness check | branch protection and its required-check list |

`gh pr merge --auto` fails outright when the repository's auto-merge checkbox is
unticked, and the template shipped a correct workflow three times while the
branch still did not delete. **That asymmetry is the reason slice 3 exists**:
the template cannot set those, so it ships something that reads them back and
tells an agent whether tonight's run is possible before the run starts.

---

## Slice 1 — one pull request completes the cycle unattended

- **Delivers:** a merged pull request whose branch is gone, with nobody
  intervening, and `ESC-21` closed against observed behaviour rather than
  against a theory.
- **Files:** `template/.github/workflows/{% if auto_merge %}auto-merge.yml{% endif %}`,
  `docs/escapes.md`
- **Estimate:** ~40 lines

The three theories that were wrong, recorded so the fourth is not the same:
`--delete-branch` is a no-op under `--auto` (`gh` deletes after merging, and
`--auto` never merges); a deletion job never ran because **GitHub creates no
workflow runs from events caused by `GITHUB_TOKEN`**; the `AUTO_MERGE_TOKEN`
path then hit the per-user GraphQL limit. Each was confidently asserted. This
slice is not done when the workflow looks right — it is done when a branch has
been seen to vanish.

## Slice 2 — the rate limit stops being fatal

- **Delivers:** `arm-auto-merge` retries with backoff instead of failing the
  check, and reports the reset time when it gives up.
- **Files:** the auto-merge workflow
- **Estimate:** ~30 lines

The limit is per-user and hourly, shared by every token and tool acting as that
user — including the agent's own API calls. A run that opens a pull request
every twenty minutes will meet it repeatedly, so this is not an edge case.

## Slice 3 — `.github/scripts/unattended-ready.sh`

- **Delivers:** a script that queries the repository's own configuration and
  exits non-zero, naming each missing item, when an unattended run cannot
  succeed. Ships to every generated project.
- **Files:** `template/.github/scripts/unattended-ready.sh`,
  `tests/test-unattended-ready.sh`, `AGENTS.md.jinja`
- **Estimate:** ~120 lines

Checks: auto-merge allowed on the repository; branch protection present and its
required checks matching the workflow's job names; `AUTO_MERGE_TOKEN` set and
not the default token; `CODEOWNERS` resolving to a user rather than a team; the
vision file complete. Each failure names the setting and where to change it.

## Slice 4 — the designed stops come out

- **Delivers:** planning no longer blocks on the owner. An underspecified design
  is logged as evidence and the planner proceeds on its own default; the oracle
  rules on it next run.
- **Files:** `template/.github/scripts/oracle-decisions.sh`,
  `tests/test-oracle-decisions.sh`, `template/AGENTS.md.jinja`,
  `template/docs/plans/_TEMPLATE.md`, `template/.claude/commands/plan.md`
- **Estimate:** ~150 lines

Three parts, and the first is the one with teeth:

1. **`oracle-decisions.sh` currently requires every decision to quote a
   `VISION.md` statement.** The owner's ruling creates a class that by
   definition cannot: best guess, alternatives considered, why each lost. So the
   schema gains an explicit *"no vision statement decided this"* value — and
   when it is used, the alternatives field becomes **mandatory**. That is what
   keeps "I guessed" from becoming the cheap path: guessing is allowed, guessing
   silently is not.
2. **`AGENTS.md` says planning must "stop for the owner's ruling".** That
   sentence is what woke the owner at 1am. It goes.
3. **`## Uncertainties` is rewritten, not deleted.** Same heading, new meaning:
   *decisions taken without a vision basis* — a record for the oracle and for
   the morning review, not a gate. Deleting it would lose the record; leaving
   the old wording invites a future agent to reinvent stopping.

**Not in this slice:** the planner calling the oracle mid-run. That is only
needed when two answers produce genuinely different slices, which is rarer than
it looks; both of today's uncertainties would have proceeded fine on a default.
Logged as a backlog item rather than built on speculation.

## Slice 5 — the driver

- **Delivers:** one entry point that runs the cycle repeatedly until the
  acceptance criteria pass, the budget is spent, or a stop fires — and says
  which, in a report the owner reads in the morning.
- **Files:** `template/.claude/commands/deliver.md`, a scheduler workflow,
  `template/docs/acceptance.md.jinja`
- **Estimate:** ~140 lines

Today `/deliver` is a single pass: the owner types it and walks away, and when
it ends, it ends. The loop needs a trigger and two terminating conditions —
**done** (acceptance passes) and **spent** (the ceiling). A loop with only the
first runs forever on a task it cannot finish.

## Slice 6 — the end-to-end lifecycle fixture

- **Delivers:** CI runs oracle → handoff → steward → plan → orchestrate against
  committed fixtures and asserts the chain, closing `ESC-23`.
- **Files:** `tests/test-lifecycle.sh`, fixtures
- **Estimate:** ~180 lines

The evidence for building this is the whole month: the phantom requirements, the
review deadlock, three wrong branch-deletion theories, a plan that contradicted
itself. **Every one was found by using the thing, not by testing it** — and each
was found by the owner, which is the job this is supposed to remove. Fixtures,
never live project logs, so tidying a log cannot break the suite.

---

## What I need you to rule on

1. **PAT or GitHub App?** An App gets its own identity and its own rate-limit
   budget, which fixes slice 2 properly *and* closes the hole where an agent's
   pull requests carry the owner's login — the one that currently makes
   `owner-authored.sh` satisfiable by accident. It costs a setup step.
2. **Where does the scheduler live** — a GitHub Actions cron, or the owner's
   machine? Actions is always on and leaves a log; the machine is simpler and
   stops when the laptop closes.
3. **What is the ceiling, in money or in pull requests per night?** A number is
   needed; the mechanism is not useful without one.
4. **Does the readiness check refuse, or warn?** Recommendation: refuse.

If slice 4 lands, this is the last plan that will carry this section.

## Out of scope

- **Anything that invokes a model in the generated project's own pipeline.**
  Unattended *development* is this plan; unattended *product runs* are a
  separate question with a separate budget.
- **Replacing the review gate with something weaker** so more things merge. The
  loop running is not worth more than the loop being correct.
- **The oracle deciding anything it cannot cite.** The new "no vision statement"
  class widens what it may decide, not what it may invent.
