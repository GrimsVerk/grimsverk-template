#!/usr/bin/env bash
#
# coverage.sh — supersession fixtures (loop-economy slice 1, ESC-219).
#
# Written blind, from the slice's Delivers line only: a requirement named on a
# LATER decision's `- **Requirements superseded:**` line stops being a coverage
# gap — the no-plan list must not name it, and the exit code reflects only the
# gaps that remain. Later declaration wins by document order, so a re-added id
# is live again. `(none)` subtracts nothing, and a superseded id may just as
# well be one the owner declared in DESIGN.md §5.
#
# These cases are written to be appended to tests/test-coverage.sh at assembly;
# the fixture helpers are re-declared here so the file also runs standalone.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Runs from tests/ (appended) or tests/blind/ (standalone).
if [[ -f "$HERE/lib.sh" ]]; then
  # shellcheck source=tests/lib.sh
  source "$HERE/lib.sh"
  ROOT="$HERE/.."
else
  # shellcheck source=tests/lib.sh
  source "$HERE/../lib.sh"
  ROOT="$HERE/../.."
fi

COVERAGE="$ROOT/template/.github/scripts/coverage.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== coverage.sh — supersession (loop-economy slice 1) ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans"

design() { cat > "$R/docs/DESIGN.md"; }
oracle() { cat > "$R/docs/DESIGN.oracle.md"; }
plan() { # plan <name> <covers>
  cat > "$R/docs/plans/$1.md" <<EOF
---
slug: $1
covers: [$2]
---
# $1 — Plan
EOF
}
run() { ( cd "$R" && "$COVERAGE" 2>&1 ); }
# The report aligns ids into columns; squeeze runs of spaces so assertions are
# about which ids are in the no-plan list, not about padding widths.
flatten() { printf '%s\n' "$1" | tr -s ' '; }

# ---------------- a superseded requirement is not a coverage gap (ESC-219)
# OD-1 declares R1000 and R1001; OD-2, later in the document, supersedes R1001.
# R1001 must not appear in the "no plan" list, and the exit code must reflect
# only the gaps that remain — here R2, which nobody planned.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
- **R2** — the second thing, which nobody planned
EOF
oracle <<'EOF'
# Design decisions from evidence

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000, R1001
- **Requirements superseded:** (none)

## OD-2 — the whole-transcript path is uncapped

- **Date:** 2026-08-16
- **Evidence:** BL-14
- **Requirements added:** R1008
- **Requirements superseded:** R1001
EOF
plan everything "R1, R1000, R1008"
out="$(run)"
expect_rc "a superseded id leaves only the real gap in the exit code" 1 $?
flat="$(flatten "$out")"
expect_contains "the real gap is still reported" "$out" "requirement(s) with no plan"
expect_contains "and named" "$flat" "R2 NOT PLANNED"
expect_not_contains "the superseded id is not in the no-plan list" "$flat" "R1001 NOT PLANNED"

# ---------------- superseded, never planned, everything else covered → clean
# The livelock this slice repairs: R1001 never had a plan, OD-2 superseded it,
# and before this the permanent gap dispatched a planner for the dead
# requirement every cycle. Everything still required is covered, so the run
# must exit clean instead of reporting work outstanding forever.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
EOF
plan x "R1"
plan y "R1000, R1008"
rm -f "$R/docs/plans/everything.md"
out="$(run)"
expect_rc "a superseded id that never had a plan is not a failure" 0 $?
flat="$(flatten "$out")"
expect_not_contains "and is not listed as a gap" "$flat" "R1001 NOT PLANNED"
expect_not_contains "so no work is reported outstanding" "$out" "requirement(s) with no plan"

# ---------------- later declaration wins: a re-added id is live again
# OD-3, later than the supersession, declares R1001 again. Document order is
# the tiebreak, so R1001 is back in the universe — and back to being a gap,
# because nobody planned it.
oracle <<'EOF'
# Design decisions from evidence

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000, R1001
- **Requirements superseded:** (none)

## OD-2 — the whole-transcript path is uncapped

- **Date:** 2026-08-16
- **Evidence:** BL-14
- **Requirements added:** R1008
- **Requirements superseded:** R1001

## OD-3 — the cap comes back, measured this time

- **Date:** 2026-08-17
- **Evidence:** ESC-9
- **Requirements added:** R1001
- **Requirements superseded:** (none)
EOF
out="$(run)"
expect_rc "a re-added id is in the universe again, so it is a gap again" 1 $?
flat="$(flatten "$out")"
expect_contains "and is named in the no-plan list" "$flat" "R1001 NOT PLANNED"

# And a plan covering the re-added id closes the gap: four requirements, four
# covered. The id is a live requirement, not a ghost of its supersession.
plan y "R1000, R1008, R1001"
out="$(run)"
expect_rc "a plan covering the re-added id makes coverage clean" 0 $?
expect_contains "and the re-added id is counted in the universe" "$out" "Covered: 4/4"

# ---------------- `(none)` subtracts nothing
# A decision with nothing to supersede writes the literal `(none)`. That line
# must not be read as an id, must not be reported malformed, and must not
# subtract anything — the decision's own requirement is as live as ever.
oracle <<'EOF'
# Design decisions from evidence

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** (none)
EOF
rm -f "$R/docs/plans/x.md" "$R/docs/plans/y.md"
plan everything "R1, R1000"
out="$(run)"
expect_rc "a (none) supersession line changes nothing when covered" 0 $?
expect_contains "the universe is intact" "$out" "Covered: 2/2"
expect_not_contains "and (none) is not a malformed id" "$out" "malformed"

plan everything "R1"
out="$(run)"
expect_rc "and changes nothing when not covered either" 1 $?
flat="$(flatten "$out")"
expect_contains "the decision's requirement is still a live gap" "$flat" "R1000 NOT PLANNED"

# ---------------- a superseded id may be one of the owner's §5 ids
# Supersession is not scoped to oracle-declared ids: a ledger decision may name
# a requirement from DESIGN.md §5, and it stops being a gap the same way. R2
# has no plan and never will — and nothing is outstanding.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
- **R2** — the owner's requirement the evidence overturned
EOF
oracle <<'EOF'
# Design decisions from evidence

## OD-1 — the second thing measured wrong

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** R2
EOF
plan everything "R1, R1000"
out="$(run)"
expect_rc "a superseded owner-doc id is not a gap" 0 $?
flat="$(flatten "$out")"
expect_not_contains "and is not in the no-plan list" "$flat" "R2 NOT PLANNED"
expect_not_contains "so no work is reported outstanding" "$out" "requirement(s) with no plan"

summary
