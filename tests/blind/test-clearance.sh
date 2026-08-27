#!/usr/bin/env bash
#
# test-clearance.sh — the LOW clearance line, and one HALT schema
# (lexicon-and-rehearsal slice 2, ESC-225, ESC-226). Written blind from the
# slice's Delivers; no implementation was visible when this was written.
#
# Two closures of the 2026-08-20 economy failure. First: a defaulted LOW
# backlog item used to buy a full eight-field ruling or sit in the steward
# queue forever — now a one-line `- **Cleared:**` entry under `## Clearances`
# closes it, and the gate holds that line to the same standards as everything
# else in the ledger: the id must exist at the base commit, a HIGH is ruled
# and never cleared, the one line of why is mandatory, and append-only applies.
# Second: HALT stops being a second schema — a HALT block passes with EITHER
# the legacy halt field set OR the standard decision field set (vision-quote
# rules included), and a block with neither still fails.
#
# Same recipe as tests/test-oracle-decisions.sh: fixtures known to pass, and
# every failing case is one named deviation from one of them.

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

echo "=== oracle-decisions.sh — LOW clearances, and one HALT schema ==="

# ======================================================= Part A: clearances
RA="$WORK/clearance"
init_repo "$RA"
mkdir -p "$RA/docs/plans/oracle" "$RA/docs/oracle"

cat > "$RA/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | excerpting cost more than it saved | none existed | pending |
EOF

# The backlog at BASE_SHA: BL-6 is HIGH, BL-7 and BL-8 are LOW, all in the
# uncertainties section — the shapes real workers file (ESC-209).
cat > "$RA/docs/BACKLOG.md" <<'EOF'
# Backlog

## Plan rework

- **BL-1** — the video description is never read, and it is where the chipset is.

## Uncertainties awaiting oracle ruling

- **BL-6** — where does the cache live?
  Proposed default: in-memory, per process.
  **HIGH**: the answer changes the storage schema and two slice boundaries.
- **BL-7** — what is the flag called? Proposed: --sync. **LOW**: renaming a
  flag later is cheap.
- **BL-8** — which date format in the log line? Proposed: ISO-8601. **LOW**:
  a log format change is a one-line sed.
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

# ---------------- A1: a well-formed clearance line passes
# One line closes a defaulted LOW: the id, the class, and the one line of why.
cat >> "$RA/docs/DESIGN.oracle.md" <<'EOF'

## Clearances

- **Cleared:** BL-7 — LOW, default stood: the flag name shipped as proposed
EOF
commit_a "Clear BL-7"
out="$(run_a)"
expect_rc "a well-formed clearance under the heading passes" 0 $?

# The clearance has landed; every case below is new against this base, which
# is the only state in which append-only means anything for clearances too.
BASE_A="$(git -C "$RA" rev-parse HEAD)"

# ---------------- A2: a clearance citing an id the backlog never filed fails
# The load-bearing rule everywhere in this ledger: what is cited must exist at
# the base commit. A clearance is a citation, so it obeys the same rule.
echo "- **Cleared:** BL-999 — LOW, default stood: no such item was ever filed" \
  >> "$RA/docs/DESIGN.oracle.md"
commit_a "Clear an id that does not exist"
out="$(run_a)"
expect_rc "a clearance citing an id absent from the backlog at base fails" 1 $?
expect_contains "and names the invented id" "$out" "BL-999"
git -C "$RA" reset -q --hard HEAD~1

# ---------------- A3: a HIGH item is ruled, never cleared
# The whole bargain of the clearance line is that it closes items whose
# default was cheap to stand. A HIGH blocked planning until an eight-field
# ruling cited it; letting one line wave it through would delete the HIGH/LOW
# distinction from the side where it costs the most.
echo "- **Cleared:** BL-6 — LOW, default stood: the cache stayed in-memory" \
  >> "$RA/docs/DESIGN.oracle.md"
commit_a "Clear a HIGH item"
out="$(run_a)"
expect_rc "a clearance citing a HIGH backlog item fails" 1 $?
expect_contains "and says a HIGH is ruled, never cleared" "$out" "HIGH"
git -C "$RA" reset -q --hard HEAD~1

# ---------------- A4: the one line of why is the whole price — and mandatory
# A bare id closes an uncertainty while recording nothing the owner could
# disagree with, the same emptiness the schema refuses in every other field.
echo "- **Cleared:** BL-8" >> "$RA/docs/DESIGN.oracle.md"
commit_a "Clear BL-8 saying nothing"
out="$(run_a)"
expect_rc "a clearance with no text after the id fails" 1 $?
git -C "$RA" reset -q --hard HEAD~1

# ---------------- A5: a landed clearance is append-only
# Rewording a landed clearance is rewriting history exactly as editing a
# landed decision is: the record of why the default stood must stay the record.
sed -i 's/the flag name shipped as proposed/the flag was quietly renamed after all/' \
  "$RA/docs/DESIGN.oracle.md"
commit_a "Reword the landed clearance"
out="$(run_a)"
expect_rc "modifying a landed clearance fails" 1 $?
expect_contains "and names the clearance it protects" "$out" "BL-7"
git -C "$RA" reset -q --hard HEAD~1

# ---------------- A6: appending below an intact landed clearance passes
# The ordinary batch: last cycle's line untouched, this cycle's line below it.
echo "- **Cleared:** BL-8 — LOW, default stood: the ISO-8601 default shipped unchanged" \
  >> "$RA/docs/DESIGN.oracle.md"
commit_a "Clear BL-8 below the intact BL-7 line"
out="$(run_a)"
expect_rc "a new clearance appended below an intact landed one passes" 0 $?
git -C "$RA" reset -q --hard HEAD~1

# ================================================= Part B: one HALT schema
RB="$WORK/halt"
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

# A decision block known to pass, copied from tests/test-oracle-decisions.sh.
# Every HALT case below is one named change to it or to the legacy halt block.
decision() { # decision <n> <evidence> <requirements-added>
  cat <<EOF

## OD-$1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** $2
- **Requirements added:** $3
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
}

# OD-1 lands in the seed itself: entries at BASE_SHA are history, and every
# case below is measured as the single new entry on top of it.
{
  cat <<'EOF'
# Design decisions from evidence

Append-only. Every decision cites evidence that already landed.
EOF
  decision 1 "ESC-1" "R1000"
} > "$RB/docs/DESIGN.oracle.md"

git -C "$RB" add -A && git -C "$RB" commit -qm "seed"
BASE_B="$(git -C "$RB" rev-parse HEAD)"

run_b() { ( cd "$RB" && BASE_SHA="$BASE_B" "$CHECK" 2>&1 ); }
commit_b() { git -C "$RB" add -A && git -C "$RB" commit -qm "$1"; }

# ---------------- B7: the legacy HALT shape still passes
# Copied verbatim from the passing fixture in tests/test-oracle-decisions.sh —
# ledgers written under the old schema must not go red retroactively.
cat >> "$RB/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — HALTED: the error type cannot distinguish truncation from tampering

- **Date:** 2026-08-16
- **Evidence:** ESC-1
- **Tenet relied on:** V3 — "A number that cannot be traced back to a source row is never shown."
- **What a decision would have said:** surface a richer error type naming the
  failure mode, which is the ordinary fix and would have shipped today.
- **What it needs from the owner:** either an exception to the tenet for
  length-only failures, or a ruling that the opaque error stays and the
  message is dropped.
EOF
commit_b "Record a legacy-shape halt"
out="$(run_b)"
expect_rc "the legacy HALT shape still passes" 0 $?
expect_contains "and is counted as a decision" "$out" "1 new in this pull request"
git -C "$RB" reset -q --hard HEAD~1

# ---------------- B8: a HALT carrying the standard decision fields passes
# One schema with HALT as a kind: the same eight fields a decision carries,
# under a heading that says HALTED. The vision quote is a real sentence from
# the fixture's docs/VISION.md, because the quote rules travel with the fields.
decision 2 "ESC-1" "R1001" \
  | sed 's/^## OD-2 — /## OD-2 — HALTED: /' \
  >> "$RB/docs/DESIGN.oracle.md"
commit_b "Record a standard-field halt"
out="$(run_b)"
expect_rc "a HALT with the standard decision field set passes" 0 $?
expect_contains "and is counted as a decision" "$out" "1 new in this pull request"
git -C "$RB" reset -q --hard HEAD~1

# ---------------- B8b: the standard shape brings its vision-quote rules along
# If HALTED made the quote check optional, the halt heading would become the
# cheap way to skip the steering lever. Same block, invented sentence: fails.
decision 2 "ESC-1" "R1001" \
  | sed 's/^## OD-2 — /## OD-2 — HALTED: /' \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** "Speed matters more than correctness here."/' \
  >> "$RB/docs/DESIGN.oracle.md"
commit_b "Record a standard-field halt quoting an invented sentence"
out="$(run_b)"
expect_rc "a standard-field HALT quoting a sentence not in the vision fails" 1 $?
git -C "$RB" reset -q --hard HEAD~1

# ---------------- B9: a HALT satisfying neither shape still fails
# Two accepted shapes is not zero schemas: a halt missing the legacy fields
# AND the standard fields records a stop nobody can act on, which is the
# vanishing this entry kind exists to prevent.
cat >> "$RB/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — HALTED: something stopped

- **Date:** 2026-08-16
- **Evidence:** ESC-1
EOF
commit_b "Record a halt with neither field set"
out="$(run_b)"
expect_rc "a HALT with neither the legacy nor the standard fields fails" 1 $?
expect_contains "and names the entry" "$out" "OD-2"
git -C "$RB" reset -q --hard HEAD~1

summary
