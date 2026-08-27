---
slug: <kebab-case-id>      # MUST appear in every branch name working this plan
status: draft              # draft | in-flight | merged  (same meanings as _TEMPLATE.md)
created: <YYYY-MM-DD>
design: <the docs/DESIGN.md milestone this implements>
covers: [R1, R2]           # the DESIGN.md §5 requirement ids this plan delivers
format: pseudocode         # what marks this plan for .github/scripts/plan-format.sh
---

# <Feature name> — Plan

<!-- The ATTENDED plan format. It is produced by the design flow
(docs/design-flow.md), not copied and filled ad hoc: the pseudocode pass writes
one of these per milestone, the owner's batch rulings settle it, and the
tactical adversarial review reads it settled. Unattended plans
(docs/plans/oracle/) keep the legacy format in _TEMPLATE.md — nothing here
applies to them.

The idea this format exists for: prose hides decisions — a design sentence
stays true over three incompatible implementations. Pseudocode cannot; every
line is a pick. So the body of each slice IS pseudocode, and prose survives
only where pseudocode cannot express it. -->

## Summary

<!-- THE HEADER, and it is capped: at most 15 non-blank lines in this section,
enforced by .github/scripts/plan-format.sh (HEADER_MAX). It may carry ONLY what
pseudocode cannot say — nothing that duplicates the body:

  1. Intent — what this plan is for, two or three lines.
  2. Non-goals — "we do NOT ..." bullets. Code cannot state a negative; this
     list is also what the review gate measures scope creep against.
  3. Owner costs — a new gate, a required check, money, a manual step.

There is no Uncertainties section in this format. Open questions never land:
they are surfaced to the owner during the design flow, ruled in batch, folded
into the pseudocode, and recorded in docs/DECISIONS.md. The Rulings line below
is the receipt. -->

<intent, two or three lines>

Non-goals:
- <what this plan deliberately does not do>

Owner costs:
- <what this costs the owner, or "none">

Rulings: <D-<n>..D-<m> (docs/DECISIONS.md), or "none surfaced">

## The slices

<!-- Vertical slices, 3-5 of them, exactly as in _TEMPLATE.md: each delivers
something observable end-to-end, each declares its files (tests included) and
a line estimate that is a tripwire, not a target. The banner above deliberately
does not read "Slices" — plan-parse.sh finds slices by `## Slice <n> `.

Each slice body is TWO layers, and the split is load-bearing:

  ### Signatures — the CONTRACT. Names, arguments, types, what goes in, what
  comes out, what errors do. This is the only layer the blind test-writer
  sees: spawn-worker strips ### Internals from its worktree copy. Write every
  behaviour you want tested HERE, as a promise, or it will not be tested.

  ### Internals — the pseudocode. Step by step, real file and function names,
  every pick explicit. Comments carry the why. Only the coder reads it.

A landed plan contains no FORK blocks. Forks exist mid-flow only — see
docs/design-flow.md for the fork rule — and the owner's ruling deletes the
losing branches before the plan lands. -->

## Slice 1 — <the behaviour this delivers>

- **Delivers:** <what a person can observe once this slice lands, end to end>
- **Files:** `<path>`, `<path>`
- **Estimate:** ~<N> lines

### Signatures

```text
<function/type signatures, and the behaviour promises a test can hold:
 inputs, outputs, error behaviour, exit codes — exact names>
```

### Internals

```text
<pseudocode for the slice: every step, every pick, real identifiers;
 comments carry constraints the code cannot show>
```

## Slice 2 — <the behaviour this delivers>

- **Delivers:**
- **Files:**
- **Estimate:** ~<N> lines

### Signatures

### Internals
