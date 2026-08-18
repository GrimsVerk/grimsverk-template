# Reviews

Frozen records of read-only reviews of this template, one directory per session.
Each carries the brief it was given alongside what it produced, because a review
is only worth re-running if the question it was asked is on the record — the next
reviewer needs to know what was in scope, what was declared out of scope, and
what was already walked and found closed.

These are **records, not authorization**, in the same sense as `docs/escapes.md`:
no gate passes or fails a change because of anything written here. A finding
becomes binding only when it turns into an `ESC-<n>` row and the check that row
names.

| Directory | Date | What it is |
| --- | --- | --- |
| [`adversarial-review/`](adversarial-review/) | 2026-08-16 | The prompt-authoring session: a mechanism inventory of the whole template, and the two adversarial review prompts written from it. `prompt-a-gate-machinery.md` and `prompt-b-document-shape.md` are the authoritative copies for use. |
| [`gate-seams/`](gate-seams/) | 2026-08-16 | Prompt A executed against `claude/copier-template-automation-rii78u` @ `21c8eae`. Twelve traced findings against the seams *between* gates, ranked by silence rather than severity, plus eleven closed angles and six content-dependent threads handed off to a document-shape review. |
| [`document-shape/`](document-shape/) | 2026-08-16 | Prompt B executed against the same commit: do the guarantees hold across the range of `docs/VISION.md` / `docs/DESIGN.md` pairs a competent human would actually write? Ships a `reproduce.sh`. |
| [`report-review/`](report-review/) | 2026-08-16 | A testbed project's report assessed against the template it was generated from. |
| [`template-review/`](template-review/) | 2026-08-16 | Blind reconstruction of the template's intent, and a comparative report against what it actually does. |

`gate-seams/` and `document-shape/` are the two halves of one split and were run
independently against the same commit. Where a gate's threshold turned out to be
set by document content, `gate-seams/findings.md` handed the thread off rather
than guessing; those six questions are what `document-shape/` answers from the
other side. Read together before either is turned into an `ESC-<n>` row.

That reconciliation is done in [`../synthesis.md`](../synthesis.md), which reads
these five sessions against `docs/plans/` and collapses the twenty-two traced
findings into seven roots and a decision register. Three of the six handed-off
threads are answered there, one partially, and two were never picked up. The
synthesis is a working document, not a record — it decides nothing on its own,
and the `ESC-<n>` rule above still governs what becomes binding.
