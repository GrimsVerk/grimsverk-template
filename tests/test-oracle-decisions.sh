#!/usr/bin/env bash
#
# oracle-decisions.sh — fixture tests.
#
# The document this gate guards is the one design document an agent may write
# while nobody is awake, so it is deliberately not behind CODEOWNERS — and this
# check is the entire reason that is safe rather than reckless. Each fixture
# below is one of the ways it would stop being safe:
#
#   - a decision citing nothing, or citing evidence that has not landed (the
#     load-bearing rule: an oracle metabolises what was logged, it does not
#     invent);
#   - a landed decision modified or deleted (append-only, so a reversal reads as
#     a reversal instead of as an edit);
#   - an id reused, which is how a modification disguises itself as an addition;
#   - a requirement id below the R1000 offset, which silently collides with a
#     requirement the owner wrote, in a shared integer space with no namespace;
#   - a handoff rewritten after the fact;
#   - a steward's plan citing a decision that does not exist yet;
#   - the runaway-loop cap.
#
# And the direction that matters just as much: a well-formed append passes, and
# a project with no oracle document at all passes without comment.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/oracle-decisions.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== oracle-decisions.sh ==="

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

git -C "$R" add -A && git -C "$R" commit -qm "seed"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { ( cd "$R" && BASE_SHA="$BASE" "$CHECK" 2>&1 ); }
commit() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

# A well-formed decision. Written as a function so every fixture below is one
# clearly-named deviation from a document that is known to pass.
decision() { # decision <n> <evidence> <requirements-added>
  cat <<EOF

## OD-$1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** $2
- **Requirements added:** $3
- **Requirements superseded:** (none)
- **Vision statement relied on:** "Cost is a ceiling, not a preference."
- **Alternatives considered:** tighter windows; a per-video cap. Both leave the
  compounding merge in place, which is the thing that was measured wrong.
- **Rationale:** measured on real data, excerpting produced 4.8x the characters
  of the whole transcript it was cut from, so the stage that exists to cut cost
  raises it.
EOF
}

# ----------------------------------------------- no oracle document -> passes
R2="$WORK/bare"
init_repo "$R2"
echo seed > "$R2/README.md"
git -C "$R2" add -A && git -C "$R2" commit -qm seed
out="$( cd "$R2" && BASE_SHA="$(git -C "$R2" rev-parse HEAD)" "$CHECK" 2>&1 )"
expect_rc "a project with no oracle document passes" 0 $?
expect_contains "and says there are none" "$out" "0 decision(s)"

# --------------------------------------------------- a clean append -> passes
decision 1 "ESC-1" "R1000" >> "$R/docs/DESIGN.oracle.md"
commit "Add OD-1"
out="$(run)"
expect_rc "a well-formed decision citing landed evidence passes" 0 $?
expect_contains "counts it as new" "$out" "1 new in this pull request"

# OD-1 has landed. Everything below is measured against a base that contains it,
# which is the only state in which "append-only" means anything.
BASE="$(git -C "$R" rev-parse HEAD)"

# A backlog id is evidence too.
decision 2 "BL-1" "R1001" >> "$R/docs/DESIGN.oracle.md"
commit "Add OD-2"
expect_rc "a decision citing a backlog id passes" 0 "$(run >/dev/null; echo $?)"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------------ citing nothing -> failure
decision 2 "the transcript run" "R1001" >> "$R/docs/DESIGN.oracle.md"
commit "A decision with no id cited"
out="$(run)"
expect_rc "a decision citing no evidence fails" 1 $?
expect_contains "says what evidence means" "$out" "OD-2 cites no evidence"
git -C "$R" reset -q --hard HEAD~1

# --------------------------------------- citing an unmerged entry -> failure
# The same backward-only rule escape-refs.sh enforces, and for the same reason:
# a claim about a ledger must be true at the only commit anything checks.
echo "| ESC-2 | 2026-08-15 | something else | none | pending |" >> "$R/docs/escapes.md"
decision 2 "ESC-2" "R1001" >> "$R/docs/DESIGN.oracle.md"
commit "Cite an entry added in the same change"
out="$(run)"
expect_rc "a decision citing evidence added in the same change fails" 1 $?
expect_contains "names the id" "$out" "OD-2 cites ESC-2"
expect_contains "and says where it must exist" "$out" "does not exist at the base commit"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------- a landed decision edited -> fail
sed -i 's/4\.8x/2x/' "$R/docs/DESIGN.oracle.md"
commit "Quietly revise OD-1"
out="$(run)"
expect_rc "modifying a landed decision fails" 1 $?
expect_contains "names it as append-only" "$out" "OD-1 was modified"
expect_contains "and points at supersession" "$out" "supersede it with a new decision"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------ a landed decision deleted -> fail
python3 - "$R/docs/DESIGN.oracle.md" <<'PY'
import sys
p = sys.argv[1]
text = open(p).read()
open(p, "w").write(text.split("\n## OD-1")[0] + "\n")
PY
commit "Delete OD-1"
out="$(run)"
expect_rc "removing a landed decision fails" 1 $?
expect_contains "names the removal" "$out" "OD-1 was removed"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------------------ a reused id -> fail
decision 1 "ESC-1" "R1002" >> "$R/docs/DESIGN.oracle.md"
commit "Add a second OD-1"
out="$(run)"
expect_rc "reusing an id fails" 1 $?
expect_contains "says ids identify a decision" "$out" "appears more than once"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------ a requirement below R1000 -> fail
decision 2 "ESC-1" "R7" >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision numbering a requirement R7"
out="$(run)"
expect_rc "a requirement id below the offset fails" 1 $?
expect_contains "explains the shared integer space" "$out" "below the oracle offset R1000"
git -C "$R" reset -q --hard HEAD~1

# ---------------------------------------------------- a missing field -> fail
decision 2 "ESC-1" "R1001" | grep -v 'Vision statement' >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision with no vision statement"
out="$(run)"
expect_rc "a decision missing the vision field fails" 1 $?
expect_contains "names the field" "$out" "Vision statement relied on"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------------------ an empty field -> fail
decision 2 "ESC-1" "R1001" \
  | sed 's/^- \*\*Rationale:\*\*.*/- **Rationale:**/' >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision with an empty rationale"
out="$(run)"
expect_rc "a label with nothing after it fails" 1 $?
expect_contains "says the field is empty" "$out" "empty **Rationale:** field"
git -C "$R" reset -q --hard HEAD~1

# --------------------------------------------------- the runaway-loop cap
{ for n in $(seq 2 6); do decision "$n" "ESC-1" "R100$n"; done; } >> "$R/docs/DESIGN.oracle.md"
commit "Add five more decisions"
out="$( cd "$R" && BASE_SHA="$BASE" MAX_DECISIONS=4 "$CHECK" 2>&1 )"
expect_rc "more decisions than the cap fails" 1 $?
expect_contains "says the cap is a backstop" "$out" "runaway-loop backstop"
expect_rc "and the same tree passes under the real cap" 0 "$(run >/dev/null; echo $?)"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------------- handoffs are written once
cat > "$R/docs/oracle/handoff-2026-08-15-1.md" <<'EOF'
# Handoff 2026-08-15 #1
Decisions needing plans: OD-1.
EOF
commit "Write a handoff"
BASE="$(git -C "$R" rev-parse HEAD)"
expect_rc "a new handoff passes" 0 "$(run >/dev/null; echo $?)"

echo "Actually, never mind." >> "$R/docs/oracle/handoff-2026-08-15-1.md"
commit "Edit yesterday's handoff"
out="$(run)"
expect_rc "editing a landed handoff fails" 1 $?
expect_contains "says a new run writes a new file" "$out" "a later run writes a NEW file"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------ a steward's plan cites a decision
cat > "$R/docs/plans/oracle/whole-transcripts.md" <<'EOF'
---
slug: whole-transcripts
covers: [R1000]
---
# Whole transcripts — Plan

Implements OD-1.

## Slice 1 — send the transcript
- **Files:** `src/demo/send.py`
- **Estimate:** ~30 lines
EOF
commit "Add an oracle plan citing OD-1"
expect_rc "a plan citing a landed decision passes" 0 "$(run >/dev/null; echo $?)"

sed -i 's/Implements OD-1./Implements nothing in particular./' \
  "$R/docs/plans/oracle/whole-transcripts.md"
commit "Strip the citation"
out="$(run)"
expect_rc "an oracle plan citing no decision fails" 1 $?
expect_contains "says a plan implements rather than proposes" "$out" "it does not propose one"
git -C "$R" reset -q --hard HEAD~1

sed -i 's/Implements OD-1./Implements OD-99./' \
  "$R/docs/plans/oracle/whole-transcripts.md"
commit "Cite a decision that does not exist"
out="$(run)"
expect_rc "an oracle plan citing an unlanded decision fails" 1 $?
expect_contains "says to land the decision first" "$out" "land the decision first"
git -C "$R" reset -q --hard HEAD~1

summary
