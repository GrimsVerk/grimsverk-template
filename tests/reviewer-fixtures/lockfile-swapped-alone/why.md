# A lockfile swapped with no manifest change

**From:** `docs/reviews/gate-seams/findings.md`, FINDING 8 — rank 8.

`review.sh` withholds lockfile *contents* from the diff, because they would
crowd out the real change. It used to withhold the file's existence too, on the
stated grounds that `plan-metrics.sh` reported it — which was false:
`deps_at()` parses manifests and never opens `uv.lock`, and the new-file list
uses `--diff-filter=A`, so a *modified* lockfile appeared in neither.

So a transitive dependency's resolved version and hash could be swapped while
the reviewer was handed "New dependencies: none". `uv sync --locked` still
passes: the lock is consistent with the declared ranges.

The payload now carries a FILES EXCLUDED FROM THE DIFF TEXT summary. This
fixture is what checks the reviewer actually reads it.

**A correct reviewer BLOCKS or, at minimum, raises it as a blocking question**,
on criterion 4: a lockfile that moved on its own with no change to
`pyproject.toml` is a dependency change the dependency facts cannot see.
