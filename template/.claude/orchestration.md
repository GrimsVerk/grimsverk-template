# Orchestration

A single layer of parallelism for Claude Code: the main session (the
**orchestrator**) drives one or more **features** at once, each with its own
plan, its own branch, its own group of **worker** agents, and its own pull
request. Workers run headless in isolated git worktrees. The orchestrator
assembles each feature's branches and opens its PR. It does **not** merge — see
"Handoff to the merge pipeline".

This whole setup lives under `.claude/` — the deletable, Claude-Code-specific
layer. Removing `.claude/` removes orchestration and leaves a fully functional
project (docs, CI, and pre-commit are untouched).

- **Command:** `/orchestrate <feature slugs>` (see `.claude/commands/orchestrate.md`).
- **Primitive:** `.claude/scripts/spawn-worker.sh` (one worker per call).

## The shape

```
orchestrator (this session)
├── feature: draft-saving      plan docs/plans/draft-saving.md → branch feat/draft-saving → PR
│   ├── worker/draft-saving-1  slice 1
│   ├── worker/draft-saving-2  slice 2
│   └── worker/draft-saving-3  slice 3
└── feature: export-pipeline   plan docs/plans/export-pipeline.md → branch feat/export-pipeline → PR
    ├── worker/export-pipeline-1
    └── worker/export-pipeline-2
```

Everything a worker needs comes from its slice in the plan. Everything the
reviewer needs comes from the plan the PR's branch resolves to. That is why
plans are per-feature and branch names carry the slug — it is the only link
between a PR and the document it is judged against.

## The one-layer rule

There is **exactly one** level of spawning: the orchestrator spawns workers;
**workers spawn nothing**. Running several features does not change this. In
particular, **do not spawn a per-feature orchestrator** — that is a second layer
wearing a different hat, and it brings back everything the rule exists to
prevent: an unpredictable process tree, recursive fan-out, and no single place
that knows what is running. One session drives every feature and every worker
directly, however many there are.

Each worker prompt states this explicitly, and the orchestrator never hands a
worker `spawn-worker.sh` or any other orchestration tooling.

## Worker isolation

Each worker gets its own `git worktree` on a fresh `worker/<slug>-<n>` branch
under `.claude/worktrees/<slug>-<n>`, so workers never touch the main working
tree or each other. Worker stdout+stderr is captured to
`.claude/orchestration-logs/<slug>-<n>.log`. Both directories are gitignored.

Workers for a feature are based on **that feature's branch**, not on whatever
the orchestrator happens to have checked out. Pass `--base feat/<slug>`
explicitly on every spawn. `spawn-worker.sh` defaults `--base` to the current
HEAD, which is silently wrong the moment a second feature is in flight: workers
would branch off another feature's code and carry it into their PR.

## How much to run at once

Two separate limits, for two separate reasons.

**Workers per feature: follow the plan.** The plan already decided this — one
worker per slice. That is typically 3–5 because that is what a well-sliced plan
looks like, but take the number from the plan rather than padding or trimming to
hit a target. A plan with two genuinely independent slices gets two workers. If a
plan seems to need more than about six, the slicing is probably too fine.

**Total workers across all features: cap it at ~8.** The binding constraint is
not the machine, it is your subscription's rate limits — every worker and every
PR's review gate draw on the same budget, so a wide fan-out starves the gates
that are supposed to check it. Past that point the assemble-and-review step
dominates anyway. Two or three features in flight is a realistic ceiling; if
that means a feature waits, let it wait.

## Features must not overlap on files

Two features that touch the same file will conflict when the second PR merges,
and neither PR's checks will have seen the combination. Before starting features
concurrently, compare the `**Files:**` lines across their plans:

```sh
grep -h '^- \*\*Files:\*\*' docs/plans/<slug-a>.md docs/plans/<slug-b>.md
```

If they overlap, **run the features one after another instead** — do not try to
coordinate two live branches over the same file. This check is a habit rather
than a script on purpose; if it turns out to be the thing that keeps escaping,
`docs/escapes.md` will say so and *then* it earns automation.

## Sandbox default and the opt-in bypass

Workers run at **workspace-level sandbox** by default:

- `codex` (default engine): `codex exec --full-auto --ephemeral` — sandboxed
  writes limited to the workspace; `--ephemeral` so parallel runs don't share
  session state.
- `claude`: `claude -p` under the project's normal permission rules.

The sandbox is dropped **only** when you pass `--bypass-sandbox` to
`spawn-worker.sh` (which switches to `codex --dangerously-bypass-approvals-and-sandbox`
or `claude --dangerously-skip-permissions`). It is off by default and should
stay off unless a task genuinely needs it — say why when you use it.

## Hard single-layer enforcement (available, off by default)

The one-layer rule is enforced by **convention** — the worker prompt tells the
worker not to spawn. If you need a hard guarantee, launch workers with a
restricted `PATH` that omits `codex`/`claude` so those CLIs simply aren't
reachable from inside a worker. This is deliberately **not** the default: it
adds friction for the common, well-behaved case. Turn it on only when running
untrusted or experimental worker prompts.

## Handoff to the merge pipeline

The orchestrator's job ends at **opening a PR per feature**. Merging belongs to
the pipeline, not to any agent: a PR merges when its required checks go green —
the CI **hard gate**, the `plan` check (the PR resolves to exactly one plan),
`test-the-tests`, and the independent **soft gate**
(`.github/workflows/review.yml`). The orchestrator's own local review is a
pre-check to avoid wasting a CI run on obvious junk; it is never authorization
to merge, and no agent runs `gh pr merge` on its own judgment. The reviewer that
gates the PR is separate from whoever wrote or assembled the change — no single
agent both reviews and merges. Workers must never touch the gate paths (CI, the
review check, `CODEOWNERS`, pre-commit); those are human-owned.

## Safety

Workers **execute unreviewed code** the model wrote. Keep the sandbox on. Do
not export API keys or other secrets into worker environments unless a specific
worker actually needs them — a broadly-scoped key handed to several parallel,
unattended agents is a large blast radius for little benefit. Review each
worker's diff against `AGENTS.md` before assembling; discard anything you can't
vouch for.
