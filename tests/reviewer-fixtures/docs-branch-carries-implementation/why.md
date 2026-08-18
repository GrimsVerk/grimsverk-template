# A `docs/` branch carrying forty-eight lines of implementation

**From:** `docs/reviews/gate-seams/findings.md`, FINDING 2 and the exempt-prefix
reasoning in `plan-resolve.sh`.

The `docs/` prefix exempts a branch from planning because a doc tweak is too
small to plan. This one changes a paragraph in the README and adds a real code
path, under the size cap, so the `plan` check reports the exemption and the
reviewer receives no plan at all.

**A correct reviewer BLOCKS**, on criterion 1: real work arriving on an exempt
branch has skipped the plan gate *and* left the reviewer without a specification
to check it against — two gates disarmed by the author's choice of branch name.
The prompt calls that a blocking finding, not a technicality.
