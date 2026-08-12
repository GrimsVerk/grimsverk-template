---
description: Build one or more planned features in parallel, each on its own branch, and open a PR per feature
---

You are the **orchestrator**. Drive the single-layer orchestration described in
`.claude/orchestration.md` (read it first if you have not). The features to
build — one or more plan slugs:

$ARGUMENTS

Follow these steps.

## 1. Load the plans

Each feature must already have a plan at `docs/plans/<slug>.md`. If one doesn't,
**stop and write it first** (`/plan`) — planning is not optional for non-trivial
work, and CI's `plan` check will fail any PR that can't be matched to a plan.

Read each plan. Its **slices are the subtasks** — do not invent a second
decomposition. One worker per slice.

If a plan's slices are not scoped to disjoint files, fix the plan rather than
working around it here.

## 2. Check the features don't collide

If you were given more than one slug, compare the declared files across their
plans:

```sh
grep -h '^- \*\*Files:\*\*' docs/plans/<slug-a>.md docs/plans/<slug-b>.md
```

Any file claimed by two features means their PRs will conflict on merge, and
neither PR's checks will have seen the combination. **Run those features
sequentially instead**, and say that you're doing so. Only genuinely disjoint
features run at once.

Check the totals before spawning: **cap total concurrent workers at ~8** across
all features. Rate limits are shared by the workers and by every PR's review
gate, so over-spawning starves the checks that are supposed to catch the output.
If the total exceeds the cap, run fewer features at once.

## 3. Per feature: create the branch, then spawn its workers

For each feature, create its branch off the default branch first:

```sh
git switch -c feat/<slug> main
```

Then, for each slice, spawn **two workers in parallel**: one writing the code,
one writing the tests. They never see each other's work — both branch off
`feat/<slug>` at the same commit, so neither has the other's output in its
worktree. That blindness is the point: an agent writing both the code and its
tests writes tests that describe what its code happens to do, bugs included.

Split the slice's declared files between them: paths under `tests/` or `Tests/`
belong to the **test-writer**, everything else to the **coder**. They must not
write into each other's files.

**Coder prompt** — the slice (`Slice N` of `docs/plans/<slug>.md`), its
non-test files, its signatures, the acceptance bar (follows `AGENTS.md`,
`docs/architecture.md` updated), plus:

> You are a worker. Do only this assigned slice, in the files listed. Implement
> the signatures declared in the slice EXACTLY — another agent is writing tests
> against them right now, from the same declaration, and cannot see your code.
> Do not write tests; they are being written in parallel. You are NOT an
> orchestrator: do not spawn, invoke, or delegate to any further agents, and do
> not use any orchestration scripts. Never modify the merge gates — CI workflows
> (`.github/workflows/`), the review check or its prompt
> (`.github/review-prompt.md`, `.github/scripts/review.sh`), branch protection,
> `CODEOWNERS`, or the pre-commit config. Before you finish, update
> `docs/architecture.md` to describe what now exists — logic, not code. Then
> stop.

**Test-writer prompt** — the slice, its test files, its signatures, and the role
defined in `.claude/agents/test-writer.md` (read it into the prompt, or delegate
to that subagent). Its tests are expected to **fail** in isolation, because the
implementation is not in its tree; that is correct and it must not write the
implementation to go green.

Never hand a worker `spawn-worker.sh` or any orchestration tooling.

Spawn every worker **in parallel**, each via the primitive:

```sh
.claude/scripts/spawn-worker.sh --id <slug>-<n>       --base feat/<slug> --prompt "<coder prompt>" &
.claude/scripts/spawn-worker.sh --id <slug>-<n>-tests --base feat/<slug> --prompt "<test prompt>" &
```

Pairing **doubles the worker count** — a 4-slice feature is 8 processes, which
is the whole concurrency cap. Budget for it: run fewer slices at once, or fewer
features. You may skip the pair and let the coder write its own tests for a
slice that delivers no real logic (pure scaffolding, config, a rename); say so
when you do. Never skip it for a slice with behaviour worth asserting on.

- `--id <slug>-<n>` becomes the branch `worker/<slug>-<n>`, keeping every branch
  traceable to its plan.
- `--base feat/<slug>` is **required**, not optional. It defaults to the current
  HEAD, which is silently wrong once a second feature exists — workers would
  branch off another feature's code and carry it into this PR.

Run them with background `&` + `wait` (or `xargs -P`), not one at a time.
Defaults: engine `codex`, workspace-level sandbox. Keep the sandbox on — do NOT
pass `--bypass-sandbox` unless the task genuinely requires it and you have said
why. Collect each printed `WORKER_RESULT` line (id, branch, worktree, exit code).

## 4. Per feature: review, then assemble

After a feature's workers finish, for each one:

- Read its branch diff (`git -C <worktree> diff feat/<slug>...`) and its log
  under `.claude/orchestration-logs/<id>.log`.
- Review the changes against `AGENTS.md` **and against the slice it was given** —
  did it build what the plan said, in the files the plan named? If a `reviewer`
  subagent exists, delegate to it; otherwise review directly. This is a local
  **pre-check to catch obvious junk before it costs a CI run — it is NOT merge
  authorization.** The authoritative review is the pipeline's soft gate, which
  runs independently on the PR.
- **Assemble** the branches that pass into `feat/<slug>` (merge the worker
  branches into it), taking each slice's coder and test-writer **together**. For
  the ones that failed or errored, either re-dispatch a corrected worker prompt
  (once) or discard the branch — don't assemble broken work.

- **Reconcile the pair.** Once a slice's code and tests are both merged, run the
  suite. This is the first moment they meet, and a failure here is *information*,
  not a nuisance: the two agents disagreed about what the slice meant. Work out
  which side is wrong before touching either.
  - Tests assert behaviour the slice promised and the code doesn't deliver →
    **the code is wrong.** Fix the code.
  - Tests assert something the slice never promised → **the tests are wrong.**
    Fix the tests.
  - Both are defensible readings → **the plan was ambiguous.** Fix the plan, say
    so in your report, and note it as an escape in `docs/escapes.md` — an
    ambiguous slice is exactly the kind of gap the plan is supposed to close.

  Never resolve a disagreement by weakening the test to match the code. That
  converts a caught defect into a passing suite, which is the failure mode this
  whole split exists to prevent.
- Check `docs/architecture.md` actually got updated and reads as one coherent
  description rather than several workers' fragments stitched together. Fix it
  yourself if not; it is the file the owner reads.

## 5. Per feature: open a PR, then stop

Push `feat/<slug>` and open **one** pull request for it. **Do not merge it.**
Your job ends here: the merge is the pipeline's, triggered by the required checks
going green — CI, `plan`, `test-the-tests`, and the review soft gate (and, where
enabled, GitHub auto-merge completes it mechanically). A passing local pre-check
is never your authorization to merge, and you never run `gh pr merge` on your own
judgment.

Clean up the worktrees you're done with:

```sh
git worktree remove --force .claude/worktrees/<id>
git branch -D worker/<id>   # for discarded branches
```

## 6. Report

Per feature: what each worker was asked to build, which branches you assembled,
which you discarded and why, and the PR link. Then, across features: anything you
sequenced rather than parallelised and why, and any plan you had to fix.
