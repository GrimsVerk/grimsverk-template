# A new code path with no tests, on a branch where `test-the-tests` skips

**From:** `docs/reviews/gate-seams/findings.md`, FINDING 3 — rank 3.

`test-the-tests` skips unless the diff touches both the implementation and the
test directory, and a skip exits 0, which GitHub reports as a *passing* required
check. So a pull request with no tests at all gets a green tick next to the one
check whose name says the tests were verified.

The payload now carries a "DID test-the-tests RUN?" fact saying it did not, and
why. This fixture checks the reviewer acts on it.

**A correct reviewer BLOCKS**, on criterion 3: a new code path with no test is a
rule violation. The prompt is deliberate that this is a judgement rather than a
mechanical rule — a refactor or a dead-code deletion legitimately changes code
and no tests, and this is not one of those.
