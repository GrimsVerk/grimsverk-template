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

summary
