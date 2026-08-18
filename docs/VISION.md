# Vision — grimsverk-template

**Not requirements.** `docs/DESIGN.md` says what gets built; this file says what
matters when two reasonable designs disagree. It is the tiebreaker an agent
reaches for when the evidence is genuinely ambiguous and nobody is awake to ask.

This is the template's own vision, written because the template now hosts its
own gates. The oracle names, in every decision, the statement here it leaned on
— so when a decision comes out wrong, the owner edits the statement rather than
arguing with the decision, and everything downstream moves with it.

Ids run continuously across every section. Never renumber one; append.

## What this project is for

A person who cannot read every diff should still be able to trust what an agent
built for them. This template is the machinery that makes that possible: it
generates a repository where the work an agent does is checked by things that do
not depend on anyone reading it — a plan that landed before the code, tests
written by an agent that could not see the implementation, gates that read every
standard at the commit the change started from, and a definition of done written
as scripts rather than as sentences. The outcome, if this works, is that the
owner reads one document at the end of an overnight run and knows what is true.

## Priorities, in order

- **V1** — A gate that reports green without having run is worse than no gate at
  all, because it looks identical to a gate that passed. Prefer a check that
  fails loudly over one that skips quietly, every time.
- **V2** — A computed fact beats a judged verdict, and a judged verdict beats a
  narrated one. Where a claim can be produced by running something, it is
  produced by running something.
- **V3** — Unattended work must keep moving. A mechanism that stops the run at
  3am to ask a question has failed at its job even when its question was good;
  the answer is to record the guess, not to wait.
- **V4** — The next agent works from this repository alone, with no chat history
  and nobody to ask. A decision that lives only in a conversation did not happen.
- **V5** — Cost is a ceiling, not a preference. A run refuses rather than
  quietly spending more than the owner budgeted for it.

## What I would trade away

- **V6** — Breadth of language support. Two languages done properly beats six
  done by guessing; a third arrives when somebody actually needs it.
- **V7** — Elegance in the generated scaffolding. The rendered project may be
  plain and repetitive if that makes it legible to an agent reading it cold.
- **V8** — Repository space, and by a wide margin. The owner's ruling stands:
  "i would rather risk gathering too much data and deal with space issues, than
  getting stuck without the info to get out of it." Evidence is kept until
  keeping it is measurably a problem, and never discarded to be tidy.
- **V9** — Speed of the pipeline. A check that costs minutes and catches one
  real defect a month is worth keeping; a fast pipeline nobody trusts is not.

## Core tenets

- **V10** — No change may make a required check pass by not running. Adding a
  skip path, a job-level condition, or an early exit that reports success is
  refused whatever it buys.
- **V11** — No agent may land `docs/DESIGN.md` or `docs/VISION.md` in any
  generated project, or widen its own permissions. A change that moves either
  boundary is not made.
- **V12** — An exception is written down or it is not taken. Waivers, escapes
  and opt-outs live in append-only ledgers that cite evidence; a silent
  exception is the same as no rule.

## What makes an answer unacceptable

A run that reports success while the thing it was asked to do was not done. That
is the failure this whole project is arranged against, and it has a recognisable
shape: a green pipeline, an honest-looking summary, a table of criteria nobody
ran, and an owner who finds out weeks later. Any design choice that makes that
outcome *more* reachable is wrong regardless of what else it improves — and a
choice that makes it louder is right even when it costs a slower, noisier,
more annoying pipeline.
