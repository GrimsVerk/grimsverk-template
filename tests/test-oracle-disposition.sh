#!/usr/bin/env bash
#
# test-oracle-disposition.sh — every new decision carries a disposition
# (loop-economy slice 2, ESC-217). Written blind from the slice's Delivers.
#
# A ruling that adds no requirement, supersedes none, is not a halt and orders
# no closure is a decision the loop can never close: nothing plans it, nothing
# builds it, and the detector queues it forever. So a decision that is NEW
# relative to BASE_SHA must say what happens next — requirements added, or
# requirements superseded, or the HALTED heading, or an explicit
# `- **Closure:** <why no work follows>` line. The rule binds new decisions
# only: a ledger written before it existed is history, not a violation.
#
# Same recipe as tests/test-oracle-decisions.sh: one decision block known to
# pass, and every case below is exactly one deviation from it.

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

echo "=== oracle-decisions.sh — new decisions carry a disposition ==="

# ------------------------------------------------------------------- fixture
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans/oracle" "$R/docs/oracle"

cat > "$R/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | excerpting cost more than it saved | none existed | pending |
EOF

cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Plan rework

- **BL-1** — the video description is never read, and it is where the chipset is.
EOF

cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

Append-only. Every decision cites evidence that already landed.
EOF

cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — Cost is a ceiling, not a preference. I would rather the tool refuse
  a job than quietly spend more than I budgeted for it.
- **V2** — I would trade any feature for a design I can hold in my head.

## Core tenets

- **V3** — A number that cannot be traced back to a source row is never shown.
EOF

git -C "$R" add -A && git -C "$R" commit -qm "seed"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { ( cd "$R" && BASE_SHA="$BASE" "$CHECK" 2>&1 ); }
commit() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

# A decision block known to pass, every required field present. Each case is
# one named deviation from it.
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

# ---------------- 1: adding a requirement IS the disposition
# The ordinary decision: work follows through the requirement it added, so no
# Closure field is asked for.
decision 1 "ESC-1" "R1000" >> "$R/docs/DESIGN.oracle.md"
commit "Add OD-1"
out="$(run)"
expect_rc "a new decision adding a requirement needs no Closure field" 0 $?

# OD-1 (and its R1000) have landed; every case below is new against this base.
BASE="$(git -C "$R" rev-parse HEAD)"

# ---------------- 2: a decision that disposes of nothing fails
# Adds (none), supersedes (none), not a HALT, no Closure line: nothing can
# ever close it, so the check refuses it before the detector queues it forever.
decision 2 "ESC-1" "(none)" >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision that disposes of nothing"
out="$(run)"
expect_rc "adds nothing, supersedes nothing, no halt, no closure: fails" 1 $?
expect_contains "and the message names the Closure field it wants" "$out" \
  "Closure"
git -C "$R" reset -q --hard HEAD~1

# ---------------- 3: an explicit no-work Closure line makes the same block pass
# Advice is a legal ruling — but only said out loud, so "nothing to build" is
# recorded rather than inferred from silence.
{ decision 2 "ESC-1" "(none)"
  echo "- **Closure:** no work — the ruling is advice; nothing to build"
} >> "$R/docs/DESIGN.oracle.md"
commit "Add the same decision with an explicit closure"
out="$(run)"
expect_rc "the same block with a no-work Closure line passes" 0 $?
git -C "$R" reset -q --hard HEAD~1

# ---------------- 4: superseding a requirement is a disposition on its own
# Retiring R1000 changes what the loop builds just as surely as adding one.
decision 2 "ESC-1" "(none)" \
  | sed 's/^- \*\*Requirements superseded:\*\* (none)$/- **Requirements superseded:** R1000/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision that supersedes a requirement"
out="$(run)"
expect_rc "superseding a requirement needs no Closure field" 0 $?
git -C "$R" reset -q --hard HEAD~1

# ---------------- 5: a Closure label with nothing after it is no disposition
# An empty field reads as though the decision were closed while saying nothing
# a reader could act on — the same emptiness the schema refuses everywhere else.
{ decision 2 "ESC-1" "(none)"
  echo "- **Closure:**"
} >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision with an empty closure"
out="$(run)"
expect_rc "an empty Closure field fails" 1 $?
git -C "$R" reset -q --hard HEAD~1

# ---------------- 6: the rule binds new decisions only
# Land an undisposed decision first, so it exists at BASE_SHA; then append a
# well-formed one. The old block is history — failing it would make every
# ledger written before the rule existed permanently red.
decision 2 "ESC-1" "(none)" >> "$R/docs/DESIGN.oracle.md"
commit "Land an undisposed decision from before the rule"
BASE="$(git -C "$R" rev-parse HEAD)"
decision 3 "ESC-1" "R1001" >> "$R/docs/DESIGN.oracle.md"
commit "Add a disposed decision on top of the undisposed one"
out="$(run)"
expect_rc "a landed decision with no disposition does not fail the append" 0 $?
expect_contains "and only the appended decision counts as new" "$out" \
  "1 new in this pull request"

summary
