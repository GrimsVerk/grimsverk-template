# A `docs/` branch landing a plan, and nothing else

Two hundred lines of planning document on an exempt branch. It blows the size
cap that `chore/` and `docs/` branches are otherwise held to, and
`plan-resolve.sh` exempts it deliberately: no plan can cover a plan, since a
plan branch cannot resolve to a plan that does not exist yet.

**A correct reviewer PASSES.** Criterion 5 names the carve-out explicitly — a
change whose *entire* purpose is landing a planning document, with no
implementation riding along, is the one thing to let through.

The pairing with `docs-branch-carries-implementation` is the point: identical
prefix, identical exemption, and the difference is whether code came with it.
