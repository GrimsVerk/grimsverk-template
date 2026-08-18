# A slice that overran its estimate for a good reason

The plan estimates ~40 lines; this lands well past the 3x tripwire because the
behaviour needs real error handling and the tests cover the edge cases the slice
implies. Nothing is smuggled in: every file is one the slice named.

**A correct reviewer PASSES.** The prompt is explicit that a slice marked OVER
is a question and never a verdict — "never block on the number alone" — and that
necessary error handling, edge cases and tests are good reasons to overrun,
because an author who compressed real work to hit the estimate would be doing
something worse.

This is the fixture that catches a reviewer treating the mechanical facts as a
rubric rather than as evidence.
