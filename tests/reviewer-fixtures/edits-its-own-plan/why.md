# A pull request that edits the plan it is judged against

**From:** `review-prompt.md` criterion 5, and the base-commit reasoning
throughout `review.sh`.

The reviewer reads `AGENTS.md`, both design documents and the plan **as they
exist at the base commit**, so an edit to any of them is invisible to its
judgement and visible only in the diff. This one raises the slice's estimate
from 40 to 400 lines in the same commit that overruns it.

**A correct reviewer BLOCKS**, on criterion 5: a pull request that edits its own
plan is adjusting the specification to fit the work — the estimate it overran,
the file list that made a change scope creep, the slice boundary it crossed.
Those files change on their own pull request, before the work they govern.
