---
slug: design-hardening-loop
status: merged
created: 2026-08-27
design: docs/proposals/design-hardening-loop.md (graduated by this plan) — the owner's in-session rulings, recorded under Uncertainties below
covers: [R2, R3, R9]
---

# Design hardening loop — Plan

## Summary

The attended path from idea to build gets four new stages between the design
doc and the first line of code: a conceptual adversarial review, a full
pseudocode pass over the whole design, the owner's batched rulings on what that
pass surfaced, and a tactical adversarial review of the settled pseudocode.
The pseudocode **is** the plan: attended plans become pseudocode-bodied
documents, and the separate prose plan disappears on that path.

Decisions the owner could refuse:

- **Attended plans change shape.** New format (`format: pseudocode`): a
  lint-capped 15-line header (intent, non-goals, owner costs — nothing the body
  can express), no Uncertainties section (one `Rulings:` receipt line instead),
  and per-slice bodies split into `### Signatures` (the contract, shared with
  the blind test-writer) and `### Internals` (pseudocode, coder only).
- **Owner rulings move to `docs/DECISIONS.md`.** The plan carries no resolved
  question text; losing fork branches are deleted.
- **The blind test-writer's worktree gets the plan with `### Internals`
  stripped** — the exclusion is structural, not a promise.
- **Two new CI steps in generated projects** (none in this repository's own
  pipeline): pseudocode-format lint, and "a pseudocode plan needs both design
  reviews on disk, each above a word minimum".
- **`/design` becomes the whole flow driver**, gated by a cheap
  artifact-existence check between stages. `/plan` and the unattended path are
  untouched.
- **Run reports gain one line** counting oracle rulings per run — the metric
  this whole loop claims to reduce.

Deliberately not done: no change to `plan-parse.sh`, to the oracle/steward
machinery, to `docs/plans/oracle/` plan shape, or to this repository's own
required checks. Review-agent freshness stays convention. Costs to the owner:
reading two review reports and one rulings batch per project design; merging
this PR re-renders `AGENTS.md` and `.claude/agents/test-writer.md`.

## Uncertainties

All ruled by the owner, attended, in the working session of 2026-08-27, before
slices were written. Recorded here per the Planning rule; the flow these
rulings define will later move such records to `docs/DECISIONS.md`, but this
plan predates that machinery and uses the current form.

- **Q:** pure pseudocode plans, or a prose remnant? — **risk:** HIGH —
  **Ruling:** hybrid. Prose only where pseudocode cannot express it: a
  ≤15-line header (intent, non-goals, owner costs), mechanically capped, with
  a disjointness rule — nothing in the header may duplicate the body.
- **Q:** what does the blind test-writer see? — **risk:** HIGH — **Ruling:**
  contract only (`Delivers` + `### Signatures`); `### Internals` is stripped
  from its worktree copy structurally.
- **Q:** pseudocode per milestone or whole design at once? — **risk:** HIGH —
  **Ruling:** whole design in one pass, carved into per-milestone plan files.
  Late-plan drift is accepted; the oracle path already handles mid-run
  correction.
- **Q:** fork handling mid-pass? — **risk:** HIGH — **Ruling:** at a
  structural fork the agent writes each branch locally (effort shrinking with
  branch count), picks a trunk, and continues the global pass on the trunk
  alone; five or more plausible branches → implement none, list each with a
  two-sentence case. "Structural" reuses the HIGH-risk contract test verbatim.
- **Q:** what reaches the owner's batch? — **risk:** LOW — **Ruling:** only
  items passing the structural test, pre-chewed (question, default already
  applied, alternatives, one line why). Everything below the bar the agent
  decides in pseudocode with no ceremony. Rulings land in `docs/DECISIONS.md`;
  the loop repeats until a pass surfaces nothing.
- **Q:** review cadence and stop? — **risk:** LOW — **Ruling:** one
  conceptual + one tactical review standard; a second pass per level only when
  landing the feedback made structural changes; hard cap two per level,
  openable past the cap only by the owner (the co-design agent may suggest).
  The tactical review runs after the rulings settle the pseudocode.
- **Q:** gate or convention? — **risk:** LOW — **Ruling:** both, cheap: the
  flow refuses to advance while a stage's artifact is missing or under a word
  minimum, and generated-project CI fails a pseudocode-plan PR whose two
  review files are absent. Content depth is the owner's to judge by reading.
- **Q:** measurement? — **risk:** LOW — **Ruling:** count oracle rulings per
  run in the run report, so the claimed payoff (fewer mid-run rulings) gets a
  baseline and a trend.
- **Q:** where does this run? — **risk:** LOW — **Ruling:** attended,
  setup-time only, inside `/design`. Nothing unattended changes.

## The slices

## Slice 1 — A pseudocode plan parses, lints, and yields a contract-only view

- **Delivers:** the new attended plan format exists and is enforceable: a
  `format: pseudocode` plan passes `plan-parse.sh` unchanged, a new lint fails
  it when the header exceeds 15 lines, the `Rulings:` line is missing, or a
  slice lacks its `### Signatures`/`### Internals` split; a companion filter
  emits the plan with every `### Internals` section removed, and
  `spawn-worker.sh --strip-internals` applies that filter to a test-writer's
  worktree copy so the exclusion is structural.
- **Files:** `template/docs/plans/_TEMPLATE.pseudocode.md`, `template/.github/scripts/plan-format.sh`, `template/.github/scripts/plan-contracts.sh`, `template/.claude/scripts/spawn-worker.sh`, `template/.claude/agents/test-writer.md.jinja`, `.claude/agents/test-writer.md`, `template/.claude/orchestration.md`, `tests/test-plan-format.sh`, `tests/test-plan-contracts.sh`, `tests/test-strip-internals.sh`
- **Estimate:** ~420 lines

### Signatures

```text
plan-format.sh            # lints every format: pseudocode plan in the tree
  usage: plan-format.sh            (reads PLANS_DIR, default docs/plans)
  env:   PLANS_DIR, HEADER_MAX (default 15)
  pass:  exit 0, one "plan-format: <path> ok" line per checked plan
  fail:  exit 1, per-plan diagnosis on stderr; plans without
         "format: pseudocode" in front matter are skipped, _-prefixed skipped

plan-contracts.sh         # contract-only view of one plan
  usage: plan-contracts.sh < plan.md > contract.md
  out:   the input with every "### Internals" section (heading through the
         line before the next heading of depth <= 3) removed
  fail:  exit 1 on stdin that has format: pseudocode but no Internals section

spawn-worker.sh --strip-internals
  new flag, only meaningful with --role test-writer: after worktree creation,
  replace docs/plans/<slug>.md in that worktree with plan-contracts.sh output
```

## Slice 2 — /design drives the whole flow and refuses to skip a stage

- **Delivers:** invoking `/design` in a generated project walks the owner
  through design → conceptual review → revise → pseudocode pass → batched
  rulings (looped to empty) → tactical review → revise → carved plans, with
  each hand-off point checked by a script: the flow cannot advance while the
  current stage's artifact is missing or too thin, and the check names exactly
  what is missing.
- **Files:** `template/docs/design-flow.md`, `template/.claude/commands/design.md`, `template/.claude/scripts/design-gate.sh`, `template/docs/idea-to-design-doc.md`, `tests/test-design-gate.sh`
- **Estimate:** ~430 lines

### Signatures

```text
design-gate.sh            # "may the flow advance past <stage>?"
  usage: design-gate.sh <stage>
         stages: design | review-conceptual | plans | review-tactical
  env:   MIN_WORDS (default 150)
  pass:  exit 0, "design-gate: <stage> complete"
  fail:  exit 1, lists each missing/thin artifact with its expected path
  artifacts per stage:
    design            docs/DESIGN.md and docs/VISION.md with no empty ## section
    review-conceptual docs/reviews/design/conceptual-<n>.md, >= MIN_WORDS
    plans             >= 1 docs/plans/*.md carrying "format: pseudocode"
    review-tactical   docs/reviews/design/tactical-<n>.md, >= MIN_WORDS
```

## Slice 3 — The two review prompts ship, and CI refuses an unreviewed pseudocode plan

- **Delivers:** a generated project carries ready-to-run conceptual and
  tactical adversarial review prompt skeletons (inventory-then-attack method;
  the conceptual one hunts mega-forks, the tactical one attacks the settled
  pseudocode), and its CI fails a pull request adding a `format: pseudocode`
  plan while either review file is absent or under the word minimum — with
  `docs/plans/oracle/` and legacy-format plans exempt.
- **Files:** `template/docs/design-reviews/conceptual-prompt.md`, `template/docs/design-reviews/tactical-prompt.md`, `template/.github/scripts/design-reviewed.sh`, `template/.github/workflows/ci.yml.jinja`, `tests/test-design-reviewed.sh`
- **Estimate:** ~470 lines

### Signatures

```text
design-reviewed.sh        # CI backstop for slice-3's guarantee
  usage: BASE_SHA=<sha> design-reviewed.sh
  env:   MIN_WORDS (default 150), REVIEWS_DIR (default docs/reviews/design)
  logic: diff base...HEAD; if no added/modified plan under docs/plans/
         (excluding oracle/ and _*) carries "format: pseudocode" -> exit 0
         "not applicable"; else require conceptual-1.md and tactical-1.md in
         REVIEWS_DIR at HEAD, each >= MIN_WORDS words -> else exit 1 naming
         the missing file
  wiring: one step in ci.yml.jinja's plan job, after plan-lint; plan-format.sh
          from slice 1 is wired in the same step block
```

## Slice 4 — A run report says how many rulings the oracle made

- **Delivers:** every delivery run's `run.md` ends with an
  `oracle-rulings: <n>` line — the count of `## OD-<n>` decisions added to
  `docs/DESIGN.oracle.md` between the run's base and its end — and the
  governance text matches the product: the Planning rule in `AGENTS.md.jinja`
  describes the attended pseudocode path, and `DECISIONS.md.jinja` records the
  owner's design-hardening rulings for generated projects to inherit.
- **Files:** `template/.claude/scripts/count-rulings.sh`, `template/.claude/scripts/deliver-loop.sh`, `template/AGENTS.md.jinja`, `AGENTS.md`, `template/docs/DECISIONS.md.jinja`, `tests/test-count-rulings.sh`
- **Estimate:** ~260 lines

### Signatures

```text
count-rulings.sh          # how many oracle decisions this run added
  usage: count-rulings.sh <base-ref>
  out:   "oracle-rulings: <n>" on stdout (n >= 0)
  logic: count of ^## OD-<n> headings in docs/DESIGN.oracle.md at HEAD minus
         the count at <base-ref>; a missing document counts as zero on either
         side; never exits non-zero for an absent file
  wiring: deliver-loop.sh appends the line to run.md at run end
```

## Out of scope

- The unattended planning path: `docs/plans/oracle/` shape, `/plan`,
  `oracle-decisions.sh`, steward and oracle behaviour are all unchanged.
- `plan-parse.sh`, `plan-metrics.sh`, `plan-resolve.sh`: untouched; the new
  format stays parseable by the existing parser by construction.
- This repository's own root CI workflows and root `.claude/` machinery
  (gate paths): nothing here edits them beyond the mandatory re-render of
  files `scripts/render-governance.sh` owns.
- Any LLM-side enforcement of reviewer freshness, and any check of review
  *content* beyond the word minimum: the owner reads the reviews.
- Migrating existing prose plans, here or in generated projects.
