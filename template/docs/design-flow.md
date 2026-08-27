# The design flow — from idea to reviewed plans, attended

The attended path from an idea to buildable plans. It runs once per project
(and again for any later design-level change), always with the owner awake; the
unattended loop never enters here. `/design` drives it end to end, and
`.claude/scripts/design-gate.sh` is the cheap stop between stages — it checks
that each stage's artifact exists and is not hollow, nothing more. Depth is the
owner's to judge, because the owner reads everything this flow produces.

The bet the flow makes: most decisions an oracle has to rule on mid-run were
always present in the design and were never forced into the open. Writing the
whole design as pseudocode forces them open while the owner is still awake.
Whether the bet pays is measured, not assumed — every run report counts the
oracle's rulings (`oracle-rulings: <n>`), so the trend is visible.

The flow is also shaped for the owner's attention, deliberately: each stage is
one uninterrupted stretch of owner focus, and agent work runs while the owner
is away. No stage interrupts the owner mid-pass.

## The stages

| # | Stage | Who works | Gate (design-gate.sh) |
| --- | --- | --- | --- |
| 1 | Design + vision | owner + agent | `design` |
| 2 | Conceptual adversarial review | fresh agent, owner away | `review-conceptual` |
| 3 | Land the feedback | owner + agent | — |
| 4 | Pseudocode pass → plans + fork/uncertainty batch | agent, owner away | — |
| 5 | Batch rulings, folded in; loop 4-5 until a pass surfaces nothing | owner, then agent | `plans` |
| 6 | Tactical adversarial review | fresh agent, owner away | `review-tactical` |
| 7 | Land the feedback; plans are done | owner + agent | — |

Stage 1 is the existing `/design` behaviour: `docs/idea-to-design-doc.md`
drives the elicitation, `docs/DESIGN.md` and `docs/VISION.md` come out, and the
owner lands both. Everything after it is the hardening loop.

## The reviews (stages 2 and 6)

Both use the shipped prompt skeletons in `docs/design-reviews/` — conceptual
first, tactical after the pseudocode has settled. Run each with a **fresh
agent**: one that did not write the document it is attacking. That freshness is
convention, not a gate — an agent's history is not observable from the
repository — but the review artifact is not: the reviewer writes its findings
to `docs/reviews/design/conceptual-<n>.md` or `tactical-<n>.md`, the gate
refuses to advance while the file is missing or under the word minimum, and CI
(`design-reviewed.sh`) refuses a pseudocode plan whose two reviews are absent.

**Cadence.** One conceptual and one tactical review is the standard run. A
level gets a second pass only when landing its feedback made **structural**
changes — changed milestone or slice boundaries, a Signatures block, an
external format or schema, or anything expensive to reverse. (That is the
HIGH-risk contract test from the Planning rule, reused verbatim; it is used
three times in this flow and deliberately defined once.) A fix that only
tightened wording gets no second pass. Hard cap: two passes per level. Past the
cap only the owner may open another round — the co-design agent may suggest it,
never start it.

**Ordering.** The tactical review runs after stage 5 has settled the
pseudocode, never before: reviewing text the owner's rulings are about to
rewrite wastes the reviewer and the owner's reading time.

## The pseudocode pass (stage 4)

One agent implements the **whole design** in pseudocode, in one pass, and
carves the result into per-milestone plan files in the attended format
(`docs/plans/_TEMPLATE.pseudocode.md`). Late plans will drift as early
milestones get built; that is accepted — the oracle path already handles
mid-run correction, and surfacing every decision now, while the owner is
awake, is the point of the pass.

Two rules govern the pass, and both exist so the owner comes back from a walk
to maximally useful information, never to a stalled agent:

**Small decisions: default and continue.** Any pick below the structural test
is made in place, in pseudocode, with no ceremony. The pseudocode is the
record; it is reviewed at stage 6 and merged by the owner. Do not raise
nitpicks.

**Structural forks: branch locally, pick a trunk, continue.** When a pick
passes the structural test and genuinely plausible alternatives exist:

- Write each branch **locally** — the forked region only — with effort
  shrinking as the branch count grows: two branches get nearly full effort
  each, four get sketches.
- Mark the branch you believe in as the **trunk**, in place, and continue the
  global pass on the trunk alone. Never fork the downstream: forks compound,
  and a pass that carries two forks in full is four documents.
- Five or more genuinely plausible branches: implement none. List each with a
  two-sentence case for why it is real, and move on.
- A fork whose wrong answer would invalidate the entire rest of the pass is a
  design hole, not a fork — the conceptual review exists to catch those at
  stage 2. If one reaches you anyway, treat it as the >5 case: state it,
  argue it briefly, continue with the rest of the design where possible.

## The batch, and the rulings (stage 5)

The pass ends with one batch for the owner. Only items passing the structural
test appear in it — everything else was decided in pseudocode. Each item
arrives pre-chewed:

- the question, one line;
- the default, **already applied** in the pseudocode (the trunk);
- the alternatives (the local branches), and one line on why the trunk won.

The owner rules on the batch in one sitting. Then the agent folds the rulings
in: losing branches are **deleted**, the pseudocode is updated, and each ruling
becomes one dated line in `docs/DECISIONS.md`. No resolved question survives as
text in the plan — a stale open question re-opens itself in some future
agent's reading. What survives is the receipt: the plan's `Rulings:` line
citing the DECISIONS ids. An agent that later wants to reverse a pick checks
there first; a ruling is never silently reversed, a plain default may be.

Folding rulings in can surface new structural questions. That is the same
loop: another pass, another batch. The loop ends when a pass surfaces nothing.

## What lands where

| Artifact | Path | Landed by |
| --- | --- | --- |
| Design, vision | `docs/DESIGN.md`, `docs/VISION.md` | owner (checked: `owner-authored.sh`) |
| Review reports | `docs/reviews/design/conceptual-<n>.md`, `tactical-<n>.md` | agent, merged with the plans |
| Plans | `docs/plans/<slug>.md`, `format: pseudocode` | agent writes, owner merges (`CODEOWNERS`) |
| Rulings | `docs/DECISIONS.md`, one dated line each | agent records, owner merges |

The plan pull request is where CI holds the flow to its word:
`plan-format.sh` (the format and the header cap), `design-reviewed.sh` (both
reviews on disk), and the pre-existing plan checks, all unchanged for legacy
and oracle plans.
