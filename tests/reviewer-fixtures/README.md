# Reviewer fixtures

The review gate is the only load-bearing gate with nothing testing it, and it is
the single point where one judgement failure plus auto-merge equals a silent
breach. Every other gate here has fixtures. This directory is that gap closed.

The material was already written. `docs/reviews/gate-seams/findings.md` carries
twelve traced attack recipes, each a concrete diff with a stated expected
verdict and a line-by-line account of why every mechanical gate stays green.
Each fixture below is one of those, or an honest diff that must PASS.

## Why the honest ones are here too

**A fixture set that only tests blocking teaches the reviewer to block.** If
every case a reviewer is measured on is an attack, the strategy that scores
perfectly is "always BLOCK" — and a gate that blocks everything is a gate the
owner turns off in a week. Roughly a third of these are diffs that must pass,
including ones that *look* like the attacks: a genuine small `chore/` fix, a
`docs/` branch landing a plan, a feature that legitimately overran its estimate.

## What is NOT here, and why

Four of the twelve findings are not the reviewer's job, and writing fixtures for
them would test the wrong gate:

- **template-sync choosing its own template** (finding 9) — `template-sync.sh`
  compares `_src_path`; the reviewer is explicitly told not to re-litigate a
  verified sync.
- **`owner-authored.sh` checking who opened the pull request** (finding 10) — a
  mechanical identity check the reviewer cannot perform.
- **the acceptance marker written before the session** (finding 5) — a defect in
  the driver, invisible in any diff.
- **a plan "built" by a substring of a branch name** (finding 7) — inside
  `deliver-phase.sh`, not in any pull request.

They are covered by `tests/test-deliver-loop.sh`, `tests/test-owner-authored.sh`
and `tests/test-template-sync.sh` instead.

## Shape

One directory per fixture:

    <name>/
      expect      BLOCK or PASS, one word
      branch      the head branch name — the reviewer keys three criteria on it
      why.md      what this is, which finding it came from, and what a correct
                  reviewer says about it
      apply.sh    run inside a rendered project at the base commit; leaves the
                  head state in the working tree, uncommitted

`apply.sh` runs with `$R` set to the project root and the branch already
created. It writes files; the harness commits them.

## Running them

    REVIEWER_FIXTURES=1 tests/run.sh reviewer

**On demand and nightly, never per pull request.** Each fixture costs a model
call, and the gate under test is nondeterministic — so this is a measurement
that has to be read, not a check that has to be green. `tests/test-reviewer.sh`
skips silently without `REVIEWER_FIXTURES=1`, which is what keeps it out of the
ordinary suite.

## Reading a red result

A nondeterministic gate under test will sometimes be wrong, and a fixture set
whose failure rate is high enough becomes a thing people re-run rather than
read. Two rules:

- **Run it more than once before acting on one result.** A single flip on one
  fixture is noise; the same fixture flipping across runs is the finding.
- **A PASS fixture that BLOCKs is as serious as the reverse.** It is the failure
  mode that gets the gate switched off.
