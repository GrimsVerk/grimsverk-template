#!/usr/bin/env bash
#
# test-esc-clearance.sh — the one-line clearance extends to escape ids
# (qualitative-findings). Written blind from the slice's Delivers; no
# implementation was visible when this was written.
#
# The clearance line closed defaulted LOW backlog items for the price of one
# line of why. Escapes had no equivalent: an escape row whose asked-for check
# already exists sat open forever, feeding the evidence intake every cycle.
# Now `- **Cleared:** ESC-n — <why>` under `## Clearances` closes an escape
# under the same rules as a BL clearance — the id must exist at the base
# commit, the one line of why is mandatory — and the two kinds coexist in one
# section. There is no HIGH rule for escapes, so none is tested here.
#
# Same recipe as tests/test-clearance.sh: a fixture known to pass, and every
# failing case is one named deviation from it.

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
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== oracle-decisions.sh — escape clearances ==="

RA="$WORK/esc-clearance"
init_repo "$RA"
mkdir -p "$RA/docs/plans/oracle" "$RA/docs/oracle"

# Two escape rows at BASE_SHA — the universe an escape clearance may cite.
cat > "$RA/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | excerpting cost more than it saved | none existed | pending |
| ESC-2 | 2026-08-16 | the reviewer verdict parse missed a heading | reviewer | pending |
EOF

cat > "$RA/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-7** — what is the flag called? Proposed: --sync. **LOW**: renaming a
  flag later is cheap.
EOF

cat > "$RA/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

Append-only. Every decision cites evidence that already landed.
EOF

cat > "$RA/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — Cost is a ceiling, not a preference. I would rather the tool refuse
  a job than quietly spend more than I budgeted for it.
- **V2** — I would trade any feature for a design I can hold in my head.

## Core tenets

- **V3** — A number that cannot be traced back to a source row is never shown.
EOF

git -C "$RA" add -A && git -C "$RA" commit -qm "seed"
BASE_A="$(git -C "$RA" rev-parse HEAD)"

run_a() { ( cd "$RA" && BASE_SHA="$BASE_A" "$CHECK" 2>&1 ); }
commit_a() { git -C "$RA" add -A && git -C "$RA" commit -qm "$1"; }

# ---------------- 1: a well-formed escape clearance passes
# One line closes an escape whose asked-for check already exists: the id and
# the one line of why.
cat >> "$RA/docs/DESIGN.oracle.md" <<'EOF'

## Clearances

- **Cleared:** ESC-1 — read; the check it asks for already exists as tests/test-gates.sh
EOF
commit_a "Clear ESC-1"
out="$(run_a)"
expect_rc "a well-formed escape clearance under the heading passes" 0 $?

# The clearance has landed; every case below is new against this base.
BASE_A="$(git -C "$RA" rev-parse HEAD)"

# ---------------- 2: an escape id absent from the ledger at base fails
# A clearance is a citation, and what is cited must exist at the base commit —
# the same rule every other citation in this ledger obeys.
echo "- **Cleared:** ESC-999 — read; no escape row ever carried this id" \
  >> "$RA/docs/DESIGN.oracle.md"
commit_a "Clear an escape that does not exist"
out="$(run_a)"
expect_rc "clearing an escape id absent at base fails" 1 $?
expect_contains "and names the invented id" "$out" "ESC-999"
git -C "$RA" reset -q --hard HEAD~1

# ---------------- 3: the one line of why is mandatory for escapes too
# A bare id closes an escape while recording nothing the owner could disagree
# with — the same emptiness the BL clearance refuses.
echo "- **Cleared:** ESC-2" >> "$RA/docs/DESIGN.oracle.md"
commit_a "Clear ESC-2 saying nothing"
out="$(run_a)"
expect_rc "an escape clearance with no text after the id fails" 1 $?
git -C "$RA" reset -q --hard HEAD~1

# ---------------- 4: BL and ESC clearances coexist in one section
# The extension must not have broken the original: one line each, both in the
# same file, both accepted.
cat >> "$RA/docs/DESIGN.oracle.md" <<'EOF'
- **Cleared:** BL-7 — LOW, default stood: the flag name shipped as proposed
- **Cleared:** ESC-2 — read; the reviewer parse is covered by an existing gate test
EOF
commit_a "Clear BL-7 and ESC-2 together"
out="$(run_a)"
expect_rc "a BL clearance and an ESC clearance in the same file pass" 0 $?
git -C "$RA" reset -q --hard HEAD~1

summary
