#!/usr/bin/env bash
#
# test-clarifies-and-lints.sh — the Clarifies disposition, the self-cancelling
# vision citation, and the double-claim coverage note (qualitative-findings).
# Written blind from the slice's Delivers; no implementation was visible.
#
# Three qualitative findings from watched runs, one file:
#   A) A decision that adds nothing and supersedes nothing used to need a
#      Closure field or fail the disposition rule — but some rulings exist
#      only to pin down what an earlier decision meant. `- **Clarifies:** OD-n`
#      is now a disposition of its own, and it is held to the citation rule:
#      the clarified decision must exist at the base commit.
#   B) A decision whose relied-on and against vision fields quote the SAME
#      sentence cancels itself — the steering lever reads as pulled both ways.
#      The gate now rejects it and says the two fields cannot cite the same
#      statement.
#   C) Two plans both claiming the same requirement pass every gate green and
#      then race each other at build time. coverage.sh now NOTES a requirement
#      claimed by more than one plan — a note, never a failure.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Runs from tests/ or tests/blind/.
if [[ -f "$HERE/lib.sh" ]]; then
  # shellcheck source=tests/lib.sh
  source "$HERE/lib.sh"
  ROOT="$HERE/.."
else
  # shellcheck source=tests/lib.sh
  source "$HERE/../lib.sh"
  ROOT="$HERE/../.."
fi

CHECK="$ROOT/template/.github/scripts/oracle-decisions.sh"
COVERAGE="$ROOT/template/.github/scripts/coverage.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== Clarifies, the self-cancelling citation, and the double-claim note ==="

# ========================================= Parts A and B: oracle-decisions.sh
RB="$WORK/ledger"
init_repo "$RB"
mkdir -p "$RB/docs/plans/oracle" "$RB/docs/oracle"

cat > "$RB/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | excerpting cost more than it saved | none existed | pending |
EOF

cat > "$RB/docs/BACKLOG.md" <<'EOF'
# Backlog

## Plan rework

- **BL-1** — the video description is never read, and it is where the chipset is.
EOF

cat > "$RB/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — Cost is a ceiling, not a preference. I would rather the tool refuse
  a job than quietly spend more than I budgeted for it.
- **V2** — I would trade any feature for a design I can hold in my head.

## Core tenets

- **V3** — A number that cannot be traced back to a source row is never shown.
EOF

# OD-1 lands in the seed itself: entries at BASE_SHA are history, and every
# case below is measured as the single new entry on top of it. Copied from the
# passing fixture in tests/test-clearance.sh.
cat > "$RB/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

Append-only. Every decision cites evidence that already landed.

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** (none)
- **Vision statement relied on:** V1 — "Cost is a ceiling, not a preference."
- **Vision statements against:** V2 — "I would trade any feature for a design I
  can hold in my head." Sending whole transcripts is the simpler of the two, so
  this statement does not tell against it.
- **Alternatives considered:** tighter windows; a per-video cap. Both leave the
  compounding merge in place, which is the thing that was measured wrong.
- **Rationale:** measured on real data, excerpting produced 4.8x the characters
  of the whole transcript it was cut from, so the stage that exists to cut cost
  raises it.
EOF

git -C "$RB" add -A && git -C "$RB" commit -qm "seed"
BASE_B="$(git -C "$RB" rev-parse HEAD)"

run_b() { ( cd "$RB" && BASE_SHA="$BASE_B" "$CHECK" 2>&1 ); }
commit_b() { git -C "$RB" add -A && git -C "$RB" commit -qm "$1"; }

# clarifier <target> [clarifies-line-present] — a full-field decision that
# adds nothing and supersedes nothing; its only disposition is the Clarifies
# line, when one is emitted.
clarifier() {
  cat <<EOF

## OD-2 — the transcript decision names the source it meant

- **Date:** 2026-08-27
- **Evidence:** ESC-1
- **Requirements added:** (none)
- **Requirements superseded:** (none)
EOF
  [[ $# -gt 0 ]] && printf -- '- **Clarifies:** %s\n' "$1"
  cat <<'EOF'
- **Vision statement relied on:** V1 — "Cost is a ceiling, not a preference."
- **Vision statements against:** V2 — "I would trade any feature for a design I
  can hold in my head." The clarified wording is the simpler reading, so this
  statement does not tell against it.
- **Alternatives considered:** leaving OD-1 ambiguous; a fresh decision. A
  fresh decision would duplicate a ruling that already landed.
- **Rationale:** OD-1 said "whole transcripts" without naming which track; this
  pins it to the auto-generated one the measurement actually used.
EOF
}

# ---------------- A1: clarifying an existing decision is a disposition
clarifier "OD-1" >> "$RB/docs/DESIGN.oracle.md"
commit_b "Record a clarifying decision"
out="$(run_b)"
expect_rc "a (none)/(none) decision carrying Clarifies passes" 0 $?
git -C "$RB" reset -q --hard HEAD~1

# ---------------- A2: the clarified decision must exist at base
clarifier "OD-99" >> "$RB/docs/DESIGN.oracle.md"
commit_b "Clarify a decision that does not exist"
out="$(run_b)"
expect_rc "clarifying a decision absent from the ledger at base fails" 1 $?
git -C "$RB" reset -q --hard HEAD~1

# ---------------- A3: no disposition at all still fails (regression pin)
# The same block with the Clarifies line removed and no Closure, no waiver:
# a decision that changes nothing and points at nothing is still refused.
clarifier >> "$RB/docs/DESIGN.oracle.md"
commit_b "Record a decision with no disposition"
out="$(run_b)"
expect_rc "a (none)/(none) decision with no disposition still fails" 1 $?
git -C "$RB" reset -q --hard HEAD~1

# ---------------- B1: the two vision fields cannot cite the same statement
# A real sentence from the fixture's docs/VISION.md, quoted in BOTH fields:
# relied on and against at once is a citation that cancels itself.
cat >> "$RB/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — cap the merge stage

- **Date:** 2026-08-27
- **Evidence:** ESC-1
- **Requirements added:** R1001
- **Requirements superseded:** (none)
- **Vision statement relied on:** V1 — "Cost is a ceiling, not a preference."
- **Vision statements against:** V1 — "Cost is a ceiling, not a preference."
  The ceiling argues for the cap and against it at once.
- **Alternatives considered:** no cap; a per-video cap. Both were measured.
- **Rationale:** the merge stage compounds, and the measured run crossed the
  budget twice.
EOF
commit_b "Cite the same vision sentence on both sides"
out="$(run_b)"
expect_rc "quoting the same sentence in both vision fields fails" 1 $?
expect_contains "and the message says the two fields cannot cite the same statement" \
  "$out" "same"
git -C "$RB" reset -q --hard HEAD~1

# ---------------- B2: different statements in the two fields still pass
# The shape copied from the passing block in tests/test-clearance.sh: the
# against field quotes ANOTHER statement and says why it does not tell.
cat >> "$RB/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — cap the merge stage

- **Date:** 2026-08-27
- **Evidence:** ESC-1
- **Requirements added:** R1001
- **Requirements superseded:** (none)
- **Vision statement relied on:** V1 — "Cost is a ceiling, not a preference."
- **Vision statements against:** V2 — "I would trade any feature for a design I
  can hold in my head." The cap is one number in one place, so this statement
  does not tell against it.
- **Alternatives considered:** no cap; a per-video cap. Both were measured.
- **Rationale:** the merge stage compounds, and the measured run crossed the
  budget twice.
EOF
commit_b "Cite different statements on the two sides"
out="$(run_b)"
expect_rc "different statements in the two vision fields pass" 0 $?
git -C "$RB" reset -q --hard HEAD~1

# ================================================ Part C: the double-claim note
RC="$WORK/coverage"
init_repo "$RC"
mkdir -p "$RC/docs/plans"

cat > "$RC/docs/DESIGN.md" <<'EOF'
# Design

## 5. Requirements

- **R1** — the first thing
EOF

cat > "$RC/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** (none)
EOF

cat > "$RC/docs/plans/plan-a.md" <<'EOF'
---
slug: plan-a
covers: [R1, R1000]
---
# Plan A — Plan

## Slice 1 — the first thing
- **Delivers:** R1 and R1000, observably
- **Files:** `src/a.py`
- **Estimate:** ~20 lines
EOF

cat > "$RC/docs/plans/plan-b.md" <<'EOF'
---
slug: plan-b
covers: [R1000]
---
# Plan B — Plan

## Slice 1 — the same thing again
- **Delivers:** R1000, observably
- **Files:** `src/b.py`
- **Estimate:** ~20 lines
EOF

run_c() { ( cd "$RC" && "$COVERAGE" 2>&1 ); }

# ---------------- C1: two plans claiming one requirement is noted, not red
out="$(run_c)"
expect_rc "the double claim never fails the report — everything is covered" 0 $?
expect_contains "the note says a requirement is claimed by more than one plan" \
  "$out" "more than one plan"
# The id has to appear in the note itself — R1000 shows up in the ordinary
# coverage table too, so matching the whole output would be trivially true.
# One line of slack either side allows for a wrapped note.
note="$(printf '%s\n' "$out" | grep -B1 -A1 -m1 'more than one plan')"
expect_contains "and the note names the requirement" "$note" "R1000"

# ---------------- C2: one plan claiming it produces no such note
rm -f "$RC/docs/plans/plan-b.md"
out="$(run_c)"
expect_rc "a single claim still passes" 0 $?
expect_not_contains "and carries no double-claim note" "$out" "more than one plan"

summary
