---
title: Design hardening loop — adversarial review, pseudocode, adversarial review
status: proposed
created: 2026-08-20
source: owner idea, not derived from run data
related: [docs/DESIGN.md, docs/VISION.md, docs/reviews/adversarial-review/README.md]
---

# Design hardening loop

**Status: proposal.** Nothing here is built, approved, or scheduled. It did not
come from a defect, an escape, or a run report — it is an idea about the design
process itself, recorded so it is not lost. See `README.md` in this directory for
why it lives here rather than in a backlog.

## The idea in one paragraph

Today the path from idea to code is `/design` → `docs/DESIGN.md` (+
`docs/VISION.md`) → `/plan` → build. The proposal inserts **four** stages between
the design and the first plan: an adversarial review of the *concept*, the
implementation of that feedback, a full **pseudocode implementation** of the
design, and an adversarial review of *that*, each followed by landing the
feedback. The bet is that most of what the oracle has to rule on mid-run is
decisions that were always there in the design but were never forced into the
open. Writing the whole thing as pseudocode forces them open while a human is
still awake.

## The proposed pipeline

| # | Stage | Question it asks | Output |
| --- | --- | --- | --- |
| 1 | Design + vision | What are we building, and what do we value? | `docs/DESIGN.md`, `docs/VISION.md` |
| 2 | **Adversarial review — conceptual** | Will this design actually produce what it says it wants? Is this vision a good north star? | findings |
| 3 | Implement stage-2 feedback | — | revised design + vision |
| 4 | **Pseudocode implementation** | What are all the little steps, and what does each one force us to decide? | a pseudocode artifact + a list of surfaced decisions |
| 5 | **Adversarial review — implementation** | Given that we are doing this, is this the best way to do it? | findings |
| 6 | Implement stage-5 feedback | — | revised design, vision, and pseudocode |
| 7 | Plan and build | (unchanged) | `docs/plans/<slug>.md`, then code |

Stages 2–6 are the new part. Stage 1 and stage 7 exist today.

## Why each new stage is there

### Stage 2 — adversarial review at the conceptual level

High level, almost philosophical. It does not ask whether the code is right; it
asks whether the *design* is a plan for the thing the owner said they wanted, and
whether the *vision* is something an oracle can actually steer by at 3am. Two
starting questions, both of which need real development before this is a
mechanism:

- Does the design, as written, accomplish what it claims to accomplish? Where is
  the gap between the stated goal and the thing that would exist if this were
  built exactly as specified?
- Is the vision a good north star? A vision statement is only useful if two
  reasonable agents reading it reach the same tiebreak. Which statements are
  untestable, mutually contradictory, or so agreeable they never decide anything?

Prior art for the *style* of review lives in
`docs/reviews/adversarial-review/README.md` — that session wrote attack prompts
against the template's machinery. This stage is the same posture aimed one level
up, at intent rather than mechanism.

### Stage 4 — implementation in pseudocode

The core of the proposal. An agent implements the **whole thing** in pseudocode
before any real code exists.

The claim: you only surface the decisions a design leaves open when you are
forced to walk every small step. Prose hides them — a design sentence can stay
true while three incompatible implementations sit underneath it. Pseudocode
cannot; you have to pick one. Every pick is a decision that would otherwise have
been made mid-run by the oracle, or worse, silently by a coder.

The hoped-for payoff is **less oracle workload during a run**, and therefore
fewer overnight stops and fewer guesses recorded after the fact.

### Stage 5 — adversarial review at the implementation level

Deliberately narrower than stage 2. It does **not** reopen *why* this is being
built — that was settled at stage 3. It asks only: given that we are doing this,
is this the best way to do it? Wrong data shape, a step that cannot fail loudly,
a sequence that only works when nothing goes wrong, a decision taken by default
rather than on purpose.

## Open questions

These need answering before this could become a plan. They are the reason this is
a note and not a design change.

1. **Where does the pseudocode live, and what happens to it afterwards?** A file
   under `docs/`? Does it stay as a reference the plan is checked against, or is
   it scaffolding that gets deleted once the code exists? If it stays, it can go
   stale, and a stale second source of truth is worse than none.
2. **What is the review's actual prompt?** The two questions in stage 2 are
   sketches. An adversarial review is only as good as the attack angles it is
   handed — see the mechanism-inventory-then-prompt method in
   `docs/reviews/adversarial-review/`.
3. **Who reviews — a fresh agent, and against what?** A reviewer that read the
   design being written is not adversarial to it.
4. **Is any of this gated, or is it all convention?** Everything the template
   trusts, it checks. A stage that is merely recommended will be skipped on the
   night someone is in a hurry. But a gate that demands pseudocode for a two-line
   change is a tax, so the trigger condition matters.
5. **What is the stopping rule?** Review → fix → review can loop forever. One
   pass each, or until a round produces nothing new?
6. **Does this scale down?** Four extra stages is a lot of ceremony for a small
   feature. Per project, per feature, or only above some size?
7. **How would we know it worked?** The stated payoff is fewer oracle decisions
   per run. That is measurable — oracle decisions are already logged — but only
   against a baseline nobody has recorded yet.

## What this is not

- Not evidence. No run produced it, and no gate should cite it.
- Not a replacement for the plan. The plan still slices the work; the pseudocode
  is about surfacing decisions, not about scheduling.
