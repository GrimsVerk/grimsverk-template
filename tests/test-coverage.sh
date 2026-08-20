#!/usr/bin/env bash
#
# coverage.sh — fixture tests.
#
# The defect these exist for: the script recognised `**R<digits>**` and silently
# ignored anything else. An id like `R2a` — a renumbering slip, a typo — was
# never counted as covered and never reported as missing. It simply did not
# exist as far as the gate was concerned, while reading like a tracked
# requirement to every human, and a plan claiming it was rejected with no hint
# why. A gate that ignores what it cannot parse fails open.
#
# The other half of these tests is the false-positive side: the malformed-id
# rule is anchored on a digit precisely so that ordinary bold prose — the words
# a design doc is full of — is never mistaken for a broken id.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

COVERAGE="$HERE/../template/.github/scripts/coverage.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== coverage.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans"

design() { cat > "$R/docs/DESIGN.md"; }
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

# --------------------------------------------------------------- the good case
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
- **R2** — the second thing
## 13. Success criteria
- **S1** — it works
EOF
plan everything "R1, R2"
out="$(run)"
expect_rc "a clean design with full coverage passes" 0 $?
expect_contains "reports the coverage" "$out" "Covered: 2/2"

# ------------------------------------------------------------------ real gaps
plan everything "R1"
out="$(run)"
expect_rc "an uncovered requirement is a gap, not an error" 1 $?
expect_contains "names the gap" "$out" "R2"

# ------------------------------------------------- a malformed id in the design
# R2a is the shape that actually happened: a requirement split in two by
# suffixing rather than renumbering.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
- **R2a** — half of the second thing
- **R2b** — the other half
EOF
plan everything "R1"
out="$(run)"
expect_rc "a malformed id in the design is an error" 2 $?
expect_contains "names the offending id" "$out" "R2a"
expect_contains "names the other one too" "$out" "R2b"
expect_contains "says what an id must look like" "$out" "R or S followed by digits"

# ------------------------------------------- a malformed criterion id, anywhere
# Not only section 5: an id-shaped token in the success criteria is read as an
# id by everyone who passes it, so it has to be one.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
## 13. Success criteria
- **S1a** — a criterion with a suffixed id
EOF
out="$(run)"
expect_rc "a malformed S id is an error too" 2 $?
expect_contains "names it" "$out" "S1a"

# ---------------------------------------------------- bold prose is not an id
# The rule is anchored on a digit after the letter for exactly this reason. A
# design doc is full of bold words, and half of them start with R or S.
design <<'EOF'
# Design
## 5. Requirements
**Rationale** — **Scope** — **Risks** — **Storage** — **R**
- **R1** — the first thing
EOF
plan everything "R1"
out="$(run)"
expect_rc "bold prose beginning with R or S is left alone" 0 $?
expect_not_contains "no false positive on Rationale" "$out" "malformed"

# -------------------------------------------- a malformed id in a plan's covers
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
EOF
plan everything "R1, R2a"
out="$(run)"
expect_rc "a malformed covers: id is an error" 2 $?
expect_contains "names the id and the plan" "$out" "R2a (in everything)"

# ------------------------------- a well-formed id the design does not define
# Different problem, different treatment: this one is reported, not fatal — it
# is usually a renumbering, and the report is what tells you which side is wrong.
plan everything "R1, R9"
out="$(run)"
expect_rc "an unknown but well-formed id is reported, not fatal" 0 $?
expect_contains "and is listed" "$out" "R9 (in everything)"

# ------------------------------------------------------------ setup problems
rm -f "$R/docs/DESIGN.md"
out="$(run)"
expect_rc "no design doc is a setup problem" 2 $?

design <<'EOF'
# Design
## 5. Requirements
- the first thing, with no id at all
EOF
out="$(run)"
expect_rc "a design with no ids is a setup problem" 2 $?

# ------------------------------------------- the SECOND design document
# docs/DESIGN.oracle.md is the evidence-driven ledger an agent may append to
# unattended. Requirements are the union of both documents: before this, a plan
# covering an oracle requirement was reported as "an id the design doesn't
# define", which reads as a typo and is not one — and the requirement itself was
# invisible to the coverage report that decides whether a project is finished.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
EOF
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** (none)
- **Rationale:** excerpting measured 4.8x more expensive than the whole
  transcript, so R5 is wrong. R5 is named here and is NOT defined here.
EOF
plan everything "R1, R1000"
out="$(run)"
expect_rc "a requirement defined only in the oracle document is covered" 0 $?
expect_contains "counts both documents" "$out" "Covered: 2/2"
expect_not_contains "and does not report it as undefined" "$out" "doesn't define"

# A requirement the oracle declared and nobody planned is a GAP, exactly like
# one of the owner's. The union has to work in both directions or the report
# quietly under-counts the work left.
plan everything "R1"
out="$(run)"
expect_rc "an unplanned oracle requirement is a gap" 1 $?
expect_contains "names it" "$out" "R1000"

# Ids mentioned in a decision's PROSE are not definitions. The oracle document
# is dated decisions rather than a requirements section, and its rationales
# legitimately name ids they did not define — a superseded one, above. Reading
# the whole file would invent R5 as an oracle requirement and then report it
# as unplanned forever.
expect_not_contains "prose in a rationale does not define a requirement" "$out" "R5"

# The malformed-id rule applies there too, and says which document.
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — a decision with a broken id

- **Requirements added:** **R1000a**
EOF
out="$(run)"
expect_rc "a malformed id in the oracle document is an error" 2 $?
expect_contains "names the id" "$out" "R1000a"
expect_contains "and names the document it is in" "$out" "docs/DESIGN.oracle.md"
rm -f "$R/docs/DESIGN.oracle.md"

# ------------------------- ESC-82: the ledger's PROSE is not scanned for ids
# The deadlock this repairs, observed live. The oracle ledger is append-only and
# `oracle-decisions.sh` enforces that as a required check, so a malformed id in
# a decision's BODY can never be repaired: editing the line fails append-only,
# and superseding cannot remove text that is already there. Both gates are
# required, so the lane stopped at SETUP every run with no legal move left.
#
# It was also wrong on its own terms: a decision that declares R1000 properly
# and then writes `**R1000 — Output precision.**` as its body label is following
# the house style, not inventing an id.
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — Output is rounded to 12 significant digits

- **Requirements added:** R1000
- **Rationale:** an IEEE-754 double carries roughly 15-17 digits.

**R1000 — Output precision.** A conversion result is printed as `format(result, ".12g")`.
EOF
out="$(run)"
rc=$?
if [[ "$rc" -ne 2 ]]; then ok "a body label in the ledger is prose, not a malformed id (ESC-82)"
else no "a body label in the ledger is prose, not a malformed id (ESC-82)" "$out"; fi
expect_not_contains "so nothing is reported malformed" "$out" "malformed requirement id"
expect_contains "and the requirement it declared still counts" "$out" "R1000"

# The guard still bites where it means something: the DECLARATION line.
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — a decision that declares a broken id

- **Requirements added:** **R1000 — Output precision.**
EOF
out="$(run)"
expect_rc "a malformed id on a declaration line is still an error" 2 $?
expect_contains "and still names it" "$out" "R1000 — Output precision."
rm -f "$R/docs/DESIGN.oracle.md"

# And the owner-editable design keeps the whole-file scan: that document can be
# edited, so a malformed id anywhere in it is a fixable mistake, not a trap.
design <<'EOF'
# Design

## 5. Requirements

- **R1** something

## 12. Milestones

Ship **R2a** in the first slice.
EOF
out="$(run)"
expect_rc "a malformed id in the owner's design is still an error anywhere" 2 $?
expect_contains "and names it" "$out" "R2a"

# ----------------------------------- plans in a subdirectory are not invisible
# plan-resolve.sh, plan-lint.sh and coverage.sh all enumerated plans with
# `find -maxdepth 1`. A steward's plans live under docs/plans/oracle/, so the
# depth limit made them invisible to all three — silently, which is the worst
# way for a coverage report to be wrong: it reads as "nothing covers R1000"
# while the plan that covers it sits right there.
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
EOF
rm -f "$R/docs/plans/everything.md"
mkdir -p "$R/docs/plans/oracle"
cat > "$R/docs/plans/oracle/nested.md" <<'EOF'
---
slug: nested
covers: [R1]
---
# Nested — Plan
EOF
out="$(run)"
expect_rc "a plan in a subdirectory is found" 0 $?
expect_contains "and credited by name" "$out" "covered by  nested"

# ---------------------------------------------- plan adequacy, as a NOTE
# "Covered" means a plan NAMED the id. Nothing compares that claim to what the
# plan's slices build, so a plan naming twelve requirements and building three
# passes every gate green. This reports the gap — and only reports it, on the
# owner's ruling ("yes, note, not red"), because a platform or offline
# requirement is legitimately owned by no slice and a strict check would fire on
# honest plans.
design <<'EOF'
# Design

## 5. Requirements

**Functional**
- **R1** — the thing
- **R2** — the other thing

**Non-functional**
- **R3** — Platform / targets: *(non-functional)*
EOF
find "$R/docs/plans" -name '*.md' -delete
cat > "$R/docs/plans/everything.md" <<'EOF'
---
slug: everything
covers: [R1, R2, R3]
---
# Everything — Plan

## Summary

Delivers R1, R2 and R3.

## Slice 1 — the thing
- **Delivers:** R1, observably
- **Files:** `src/a.py`
- **Estimate:** ~20 lines
EOF
out="$(run)"
rc=$?
expect_rc "an over-claimed plan is still 'covered' — this never fails a build" 0 $rc
expect_contains "the unsliced claim is reported" "$out" "R2 (in everything)"
expect_contains "and the note says it is a note" "$out" "never a failure"
expect_contains "and explains what covered actually means" "$out" "Covered' means a plan NAMED the id"
expect_not_contains "the sliced one is not reported" "$out" "R1 (in everything)"

# The mark is what keeps the report readable. A platform requirement no slice
# owns is an EXPECTED absence, not a gap — otherwise the note fires on every
# honest plan and teaches planners to pad slice text with ids.
expect_contains "a non-functional requirement is an expected absence" "$out" \
  "R3 (in everything) — marked non-functional"
expect_contains "and is listed under that heading" "$out" "Expected absences"

# The summary legitimately restates the covers list, so scanning it would make
# the check pass for every plan ever written. Only the slices count.
expect_not_contains "the summary's restatement does not count as a slice" "$out" "R3 (in everything) — marked non-functional
  R1"

# And the clean case says so rather than staying silent — a note that only
# appears when something is wrong is a note people stop looking for.
cat > "$R/docs/plans/everything.md" <<'EOF'
---
slug: everything
covers: [R1, R2]
---
# Everything — Plan

## Slice 1 — the thing
- **Delivers:** R1, observably
- **Files:** `src/a.py`
- **Estimate:** ~20 lines

## Slice 2 — the other thing
- **Delivers:** R2, observably
- **Files:** `src/b.py`
- **Estimate:** ~20 lines
EOF
out="$(run)"
expect_contains "a plan whose slices name every claim is reported clean" "$out" \
  "Every claimed requirement is mentioned by a slice"

# ------ ESC-200 / ESC-202: retirement lives in the ledger's OWN done-log
# The oracle ledger is append-only, so a requirement a later decision reverses
# cannot be retired in place: it stays on its page reading like a live
# requirement forever. coverage.sh counted it as one — `NOT PLANNED` every run,
# exit 1 every run, for a behaviour deliberately not being built — and the
# delivery driver, which commissions planning for exactly that report's gaps,
# dispatched a planner for the dead decision every cycle and could never walk
# past it. A full unattended session per turn, observed live.
#
# docs/BACKLOG.md and docs/escapes.md each hit this and each got a done-log.
# This is the same answer for the same reason, and the ledger was the last of
# the three append-only machine-parsed files without one.
rm -f "$R/docs/plans/everything.md" "$R/docs/plans/oracle/nested.md"
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
EOF
oracle() { cat > "$R/docs/DESIGN.oracle.md"; }
retired() { cat > "$R/docs/DESIGN.oracle.done.md"; }
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
- **Rationale:** the cap R1001 set is reversed. R1008 supersedes R1001.
EOF
retired <<'EOF'
# Retired requirements

- `R1001` — retired by `OD-2`, replaced by `R1008` — 2026-08-16 — the cap was reversed before anything built it
EOF
plan everything "R1, R1000, R1008"
out="$(run)"
expect_rc "a retired requirement is not a gap" 0 $?
expect_contains "the surviving requirements are the universe" "$out" "Covered: 3/3"
expect_not_contains "the retired id is not reported as unplanned" "$out" "R1001 NOT PLANNED"

# Subtracted, never silently: absence has to read as a decision.
expect_contains "the retirement is reported as its own class" "$out" \
  "Retired (no longer part of the design)"
expect_contains "and names the decision and the replacement" "$out" \
  "R1001 — retired by OD-2, replaced by R1008"

# ---- the ledger is the AUTHORITY; the done-log is only the record of it
# Both directions are errors, and the second is the one that matters: without
# it a single appended line could delete a requirement from the universe, and
# "every requirement is covered" would become true by emptying the design.
retired <<'EOF'
# Retired requirements

_(nothing yet)_
EOF
out="$(run)"
expect_rc "a decision retiring an id the done-log omits is an error" 2 $?
expect_contains "names the id" "$out" "R1001"
expect_contains "and the decision that retired it" "$out" "OD-2"
expect_contains "and says where to write it" "$out" "docs/DESIGN.oracle.done.md"

retired <<'EOF'
# Retired requirements

- `R1000` — retired by `OD-2`, no replacement — 2026-08-16 — I would simply like it gone
- `R1001` — retired by `OD-2`, replaced by `R1008` — 2026-08-16 — the cap was reversed
EOF
out="$(run)"
expect_rc "retiring an id no decision superseded is an error" 2 $?
expect_contains "names the unbacked claim" "$out" "R1000"
expect_contains "and says a decision has to do it" "$out" "no landed decision supersedes"

# ---- a retirement with no replacement reads as a decision, not a dangling line
oracle <<'EOF'
# Design decisions from evidence

## OD-1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** R1000, R1001
- **Requirements superseded:** (none)

## OD-2 — the cap is dropped and nothing takes its place

- **Date:** 2026-08-16
- **Evidence:** BL-14
- **Requirements added:** (none)
- **Requirements superseded:** R1001
EOF
retired <<'EOF'
# Retired requirements

- `R1001` — retired by `OD-2`, no replacement — 2026-08-16 — the cap was reversed
EOF
plan everything "R1, R1000"
out="$(run)"
expect_rc "a retirement with no replacement still leaves no gap" 0 $?
expect_contains "and is reported without a dangling replacement" "$out" \
  "R1001 — retired by OD-2, with no replacement"

# ---- a plan claiming a retired id is NOT credited with it
# This is the over-claim the false gap used to pressure authors into: `covers:`
# reads as "this plan delivers this id", and a retired id's behaviour is
# deliberately not being built, so the claim is false the day it is written.
plan everything "R1, R1000, R1001"
out="$(run)"
expect_rc "a plan claiming a retired id does not fail the report" 0 $?
expect_contains "the claim is reported by name" "$out" \
  "R1001 (in everything) — retired by OD-2"
expect_not_contains "and is not mistaken for a typo" "$out" "doesn't define"
expect_contains "the retired id is not credited as covered" "$out" "Covered: 2/2"

# ---- the skeleton's own indented example retires nothing
# Column-anchored, exactly like the ledger's `**Requirements added:**` rule and
# for the identical reason: the shipped skeleton documents its format in an
# INDENTED code block. A rule matching a backticked id anywhere would read that
# example as a real retirement in every generated project on day one.
retired <<'EOF'
# Retired requirements

## Format

    - `R1001` — retired by `OD-2`, replaced by `R1008` — YYYY-MM-DD — why it went

_(nothing yet)_
EOF
plan everything "R1, R1000"
out="$(run)"
expect_rc "the skeleton's indented example retires nothing" 2 $?
expect_contains "so the real retirement is still demanded" "$out" "R1001"

# ---- DELIVERED is computed, never written down
# A plan carries `status:` in its front matter and this reads it. Recording
# delivery by hand as well would be two sources for one fact, and the two can
# disagree — which is the shape of nearly every defect in this project's log.
rm -f "$R/docs/DESIGN.oracle.md" "$R/docs/DESIGN.oracle.done.md"
design <<'EOF'
# Design
## 5. Requirements
- **R1** — the first thing
- **R2** — the second thing
EOF
cat > "$R/docs/plans/everything.md" <<'EOF'
---
slug: everything
status: merged
covers: [R1]
---
# Everything — Plan

## Slice 1 — the thing
- **Delivers:** R1, observably
EOF
cat > "$R/docs/plans/later.md" <<'EOF'
---
slug: later
status: draft
covers: [R2]
---
# Later — Plan

## Slice 1 — the other thing
- **Delivers:** R2, observably
EOF
out="$(run)"
expect_rc "a fully planned design still passes" 0 $?
expect_contains "delivered is reported as its own class" "$out" "a merged plan claims it"
expect_contains "and names the delivered id and its plan" "$out" "R1 — everything"
expect_not_contains "a drafted plan's id is not delivered" "$out" "R2 — later"
expect_contains "and the count is stated" "$out" "Delivered: 1/2"
rm -f "$R/docs/plans/later.md"

summary
