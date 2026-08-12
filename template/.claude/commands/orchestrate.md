---
description: Fan a task out to a few headless worker agents, then merge their results
---

You are the **orchestrator**. Drive the single-layer orchestration described
in `.claude/orchestration.md` (read it first if you have not). The task:

$ARGUMENTS

Follow these steps.

## 1. Decompose

Work from the plan. `docs/plans/<slug>.md` already breaks this change into
vertical slices with declared files, signatures, and estimates — **use those
slices as the subtasks** rather than inventing a second decomposition. If no
plan exists, stop and write one first (`/plan`); planning is not optional for
non-trivial work, and CI's `plan` check will fail the PR without one.

Note the plan's `slug`: every branch below must contain it, or the PR cannot be
matched to its plan and the `plan` check fails.

Slices should already be scoped to **disjoint files** so no two workers collide.
If they aren't, fix the plan rather than working around it here. Target 3–5; if
the plan can't be split cleanly into independent pieces, say so and do it
yourself instead of forcing a bad split.

## 2. Write worker prompts and spawn

For each slice, write a **self-contained** prompt naming the slice it implements
(`Slice N` of `docs/plans/<slug>.md`), the files that slice declares, the
signatures it declares, the acceptance bar (tests pass, follows `AGENTS.md`), and
this explicit instruction —

> You are a worker. Do only this assigned task, in the files listed. You are
> NOT an orchestrator: do not spawn, invoke, or delegate to any further
> agents, and do not use any orchestration scripts. Never modify the merge
> gates — CI workflows (`.github/workflows/`), the review check or its prompt
> (`.github/review-prompt.md`, `.github/scripts/review.sh`), branch
> protection, `CODEOWNERS`, or the pre-commit config. When done, ensure the
> project's checks pass, then stop.

Never hand a worker `spawn-worker.sh` or any orchestration tooling.

Spawn workers **in parallel**, each via the primitive:

```sh
.claude/scripts/spawn-worker.sh --id <slug>-<n> --prompt "<prompt>" &
```

The `--id` becomes the branch name (`worker/<id>`), so **start it with the
plan's slug** — that keeps every branch traceable to its plan.

Run them with background `&` + `wait` (or `xargs -P`), not one at a time.
Defaults: engine `codex`, workspace-level sandbox. Keep the sandbox on — do
NOT pass `--bypass-sandbox` unless the task genuinely requires it and you have
said why. Collect each printed `WORKER_RESULT` line (id, branch, worktree,
exit code).

## 3. Review, then assemble

After all workers finish, for each one:

- Read its branch diff (`git -C <worktree> diff <base>...`) and its log
  under `.claude/orchestration-logs/<id>.log`.
- Review the changes against `AGENTS.md`. If a `reviewer` subagent exists,
  delegate the review to it; otherwise review directly. This is a local
  **pre-check to catch obvious junk before it costs a CI run — it is NOT
  merge authorization.** The authoritative review is the pipeline's soft
  gate (`.github/workflows/review.yml`), which runs independently on the PR.
- **Assemble** the branches that pass your pre-check into a single feature
  branch (merge the worker branches into it). **Name that branch so it contains
  the plan's slug** — e.g. `feat/<slug>` — because it is the branch the pull
  request comes from, and CI resolves the plan from it. A PR whose branch
  doesn't match its plan fails the `plan` check. For the ones that failed or
  errored, either re-dispatch a corrected worker prompt (once) or discard the
  branch — don't assemble broken work.

## 4. Open a PR into the pipeline, then stop

Push the assembled feature branch and open **one** pull request. **Do not
merge it.** Your job ends here: the merge is the pipeline's, triggered by the
required checks going green — the CI hard gate plus the review soft gate (and,
where enabled, GitHub auto-merge completes it mechanically). A passing local
pre-check is never your authorization to merge, and you never run `gh pr merge`
on your own judgment.

Clean up the worktrees you're done with:

```sh
git worktree remove --force .claude/worktrees/<id>
git branch -D worker/<id>   # for discarded branches
```

Then report a summary: what each worker was asked to do, which branches you
assembled into the PR, which you discarded and why, and the PR link.
