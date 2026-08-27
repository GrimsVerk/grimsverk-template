---
description: Drive the design flow — design doc, adversarial reviews, and pseudocode plans
---

Drive the owner through the whole design flow. The flow is defined in
`docs/design-flow.md` — read it first, and treat this file as the checklist
that makes sure no stage gets skipped. Between stages, run
`.claude/scripts/design-gate.sh <stage>` and do not advance while it refuses;
it is deliberately cheap — existence and a word minimum — because the owner
reads everything and judges depth themselves.

The stages, in order:

1. **Design + vision.** Read `docs/idea-to-design-doc.md` and act as the
   elicitation agent it describes: interrogate the owner, then write the
   design doc. **Two documents, not one**: `docs/VISION.md` must be filled in
   by asking — offer it at the start, and accept "after the design" as an
   answer; the deadline is the plans, and the gate below holds it. Then push
   the branch and STOP THERE. **Do not open the pull request** — the owner
   opens it themselves, because `.github/scripts/owner-authored.sh` fails any
   pull request touching either file that the owner did not open, so opening
   one wastes a run and lands nothing. Gate: `design-gate.sh design`.

2. **Conceptual adversarial review.** Run while the owner steps away. Hand
   `docs/design-reviews/conceptual-prompt.md` to a FRESH agent — one with no
   part in writing the design; if you wrote it, you are not the reviewer. The
   report lands at `docs/reviews/design/conceptual-<n>.md`. Gate:
   `design-gate.sh review-conceptual`.

3. **Land the feedback.** The owner reads the report; you revise the design
   with them. If the revision changed anything structural — milestone or
   slice boundaries, a Signatures block, an external format or schema,
   anything expensive to reverse — offer a second conceptual pass (cap two;
   past the cap only the owner opens another). Design changes are
   owner-landed, as in stage 1.

4. **Pseudocode pass.** While the owner steps away, implement the WHOLE
   design in pseudocode and carve it into per-milestone plans from
   `docs/plans/_TEMPLATE.pseudocode.md`. Follow the fork rule in
   `docs/design-flow.md`: small picks default-and-continue; structural forks
   branch locally, pick a trunk, continue on the trunk; five-plus plausible
   branches are listed, not implemented. Collect the batch: every structural
   pick, pre-chewed — question, applied default, alternatives, one line why.

5. **Batch rulings.** Present the batch in one sitting. Fold the rulings in:
   delete losing branches, update the pseudocode, record each ruling as one
   dated line in `docs/DECISIONS.md`, and write the plan's `Rulings:` receipt
   line. New structural questions loop back to stage 4; the loop ends when a
   pass surfaces nothing. Gate: `design-gate.sh plans`.

6. **Tactical adversarial review.** Only after the rulings settle. Fresh
   agent again, `docs/design-reviews/tactical-prompt.md`, report at
   `docs/reviews/design/tactical-<n>.md`. Gate:
   `design-gate.sh review-tactical`.

7. **Land the feedback and finish.** Revise the plans with the owner; a
   structural revision earns a second tactical pass (same cap, same owner
   override). Then commit plans and review reports on a `docs/`-prefixed
   branch for the owner to merge — `CODEOWNERS` makes that merge the ruling.
   CI holds the receipts: `plan-format.sh` and `design-reviewed.sh`.

Report at every stage boundary: what stage just finished, what the gate said,
and what the owner does next. This flow is attended and setup-time only — the
unattended path (`/plan`, `docs/plans/oracle/`) is untouched by it.

The owner's raw idea follows (may be empty — if so, ask for it first):

$ARGUMENTS
