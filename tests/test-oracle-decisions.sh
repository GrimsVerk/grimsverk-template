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

# The vision the decisions below quote. It has to be REAL now: the check reads
# it at the base commit and requires a quoted statement to actually appear in
# it, because the whole check used to be "does this field contain a double-quote
# character" — which `"s"` satisfied, in a fixture with no vision file at all.
# Deliberately wrapped across lines, so the whitespace normalisation is
# exercised rather than assumed.
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

# A well-formed decision. Written as a function so every fixture below is one
# clearly-named deviation from a document that is known to pass.
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

# ------------------------------------- the vision field's value has a shape
# A paraphrase — prose with no quotation marks and no opt-out marker — is the
# decision restating itself, and it breaks the steering: the owner cannot find
# the sentence that produced it.
decision 2 "ESC-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** the vision generally favours cheapness/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision that paraphrases the vision"
out="$(run)"
expect_rc "a paraphrased vision field fails" 1 $?
expect_contains "and says a paraphrase is the decision restating itself" "$out" \
  "a paraphrase is the decision restating itself"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------- the quote must be in the vision file
# The finding this closes: the ENTIRE check used to be "does the field contain a
# double-quote character". `"s"` passed, with `(none)` for alternatives, in a
# fixture that contained no docs/VISION.md at all. Meanwhile the ledger tells
# the owner this field is the steering lever — "edit the sentence that produced
# the decision" — and nothing connected the sentence they edit to anything.
decision 2 "ESC-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** "s"/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision quoting a single character"
out="$(run)"
expect_rc "a one-character quote fails" 1 $?
expect_contains "and says it is too short to be a statement" "$out" "too short"
git -C "$R" reset -q --hard HEAD~1

decision 2 "ESC-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** "Speed matters more than correctness here."/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision quoting a sentence the owner never wrote"
out="$(run)"
expect_rc "a quote that is not in the vision file fails" 1 $?
expect_contains "and quotes the invention back" "$out" "Speed matters more than correctness"
expect_contains "and says why the field matters" "$out" "steering lever"
git -C "$R" reset -q --hard HEAD~1

# A real sentence wrapped across two lines in the file must still match — this
# is the ordinary case, and a check that failed it would be unusable.
decision 2 "ESC-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** V1 — "I would rather the tool refuse a job than quietly spend more than I budgeted for it."/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision quoting a sentence that wraps in the file"
expect_rc "a quote spanning wrapped lines still matches" 0 \
  "$(run >/dev/null; echo $?)"
git -C "$R" reset -q --hard HEAD~1

# A fragment short enough to invert its own sentence. The review's worked
# example: six words out of "I would trade any feature for a design I can hold
# in my head" reverse what the owner said and read as a clean derivation.
decision 2 "ESC-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** "a design I"/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision quoting an invertible fragment"
out="$(run)"
expect_rc "a fragment too short to carry its sentence fails" 1 $?
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------- the counter-argument is required
# A decision naming only the statement that supports it has not weighed the
# vision, it has searched it — and both produce one quoted sentence, so the
# owner cannot tell them apart.
decision 2 "ESC-1" "R1001" | grep -v 'Vision statements against' \
  | grep -v 'can hold in my head." Sending whole' | grep -v 'this statement does not tell' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a decision with no counter-argument"
out="$(run)"
expect_rc "a decision that weighs nothing against itself fails" 1 $?
expect_contains "and names the missing field" "$out" "Vision statements against"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------------------------ the HALT entry
# A tenet stop and an oracle finding nothing worth acting on used to produce the
# IDENTICAL artifact — no decision — while the driver marked the evidence
# processed either way. So the one moment the vision did its job was the one
# moment nothing recorded it.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

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
commit "Record a halt"
out="$(run)"
expect_rc "a well-formed halt passes" 0 $?
expect_contains "and is counted as a decision" "$out" "1 new in this pull request"
git -C "$R" reset -q --hard HEAD~1

# A halt still has to say what it stopped on and what the owner must rule.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — HALTED: something stopped

- **Date:** 2026-08-16
- **Evidence:** ESC-1
- **Tenet relied on:** V3 — "A number that cannot be traced back to a source row is never shown."
EOF
commit "Record an incomplete halt"
out="$(run)"
expect_rc "a halt missing what the owner must rule fails" 1 $?
expect_contains "and names the field" "$out" "What it needs from the owner"
git -C "$R" reset -q --hard HEAD~1

# A halt cites evidence like any other entry: it is the record of evidence the
# oracle READ and declined to act on, which is exactly what used to vanish.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — HALTED: no evidence named

- **Date:** 2026-08-16
- **Evidence:** (none)
- **Tenet relied on:** V3 — "A number that cannot be traced back to a source row is never shown."
- **What a decision would have said:** nothing in particular.
- **What it needs from the owner:** a ruling.
EOF
commit "Record a halt citing nothing"
out="$(run)"
expect_rc "a halt citing no evidence fails" 1 $?
git -C "$R" reset -q --hard HEAD~1

# The no-vision class: a ruling the vision genuinely does not decide (an
# uncertainty a plan filed, say). Legal with alternatives spelled out...
decision 2 "BL-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** (no vision statement decided this)/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a no-vision-class decision with alternatives"
expect_rc "the no-vision class passes with alternatives weighed" 0 \
  "$(run >/dev/null; echo $?)"
git -C "$R" reset -q --hard HEAD~1

# ...and refused when the alternatives are "(none)": guessing is allowed,
# guessing silently is not.
decision 2 "BL-1" "R1001" \
  | sed 's/^- \*\*Vision statement relied on:\*\*.*/- **Vision statement relied on:** (no vision statement decided this)/' \
  | sed 's/^- \*\*Alternatives considered:\*\*.*/- **Alternatives considered:** (none)/' \
  >> "$R/docs/DESIGN.oracle.md"
commit "Add a no-vision-class decision with no alternatives"
out="$(run)"
expect_rc "the no-vision class with no alternatives fails" 1 $?
expect_contains "and says what the owner loses" "$out" "cannot see what a different vision sentence"
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

# Form 2 (the unattended loop's milestone plans): no decision cited, but every
# covers: id already landed in a design document — R1000 landed via OD-1 — so
# the plan still traces to the owner-controlled design layer and passes.
sed -i 's/Implements OD-1./Implements nothing in particular./' \
  "$R/docs/plans/oracle/whole-transcripts.md"
commit "Strip the citation, keep landed covers"
expect_rc "a citation-less plan covering LANDED requirements passes" 0 \
  "$(run >/dev/null; echo $?)"
git -C "$R" reset -q --hard HEAD~1

# ...but covers: must not smuggle work in. An id in neither design document is
# a proposal wearing a plan's clothes, which is exactly what the rule refuses.
sed -i 's/Implements OD-1./Implements nothing in particular./; s/covers: \[R1000\]/covers: [R1000, R7]/' \
  "$R/docs/plans/oracle/whole-transcripts.md"
commit "Cover a requirement nobody landed"
out="$(run)"
expect_rc "a citation-less plan covering an unlanded requirement fails" 1 $?
expect_contains "and names the invented id" "$out" "covers R7"
git -C "$R" reset -q --hard HEAD~1

# And with neither form — no citation, no covers — the message names both.
# (Applied to the pristine citing plan, restored by the resets above.)
sed -i 's/Implements OD-1./Implements nothing in particular./; s/covers: \[R1000\]/covers: []/' \
  "$R/docs/plans/oracle/whole-transcripts.md"
commit "Strip both the citation and the covers"
out="$(run)"
expect_rc "a plan with neither citation nor covers fails" 1 $?
expect_contains "and says a plan never proposes work" "$out" "never proposes work"
git -C "$R" reset -q --hard HEAD~1

sed -i 's/Implements OD-1./Implements OD-99./' \
  "$R/docs/plans/oracle/whole-transcripts.md"
commit "Cite a decision that does not exist"
out="$(run)"
expect_rc "an oracle plan citing an unlanded decision fails" 1 $?
expect_contains "says to land the decision first" "$out" "land the decision first"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------- the optional waiver field
# The ONE thing written in this ledger that changes what another gate does:
# acceptance-criteria.sh skips a criterion a landed decision waives. It exists
# because a ruling of "met by other means" would otherwise unblock nothing —
# the criterion's script still exits non-zero, so every later pull request
# stays red. Two rules keep it an exception rather than a hole.
{ decision 30 "ESC-1" "(none)"
  echo "- **Criterion waived:** S3 — the built system satisfies this through the cache layer, which the script cannot observe from outside"
} >> "$R/docs/DESIGN.oracle.md"
commit "Waive S3 with reasoning"
expect_rc "a waiver naming a criterion and saying why passes" 0 "$(run >/dev/null; echo $?)"
git -C "$R" reset -q --hard HEAD~1

# A bare id is the oracle setting aside the OWNER'S definition of done with
# nothing the owner can disagree with — which is exactly what the "may not mark
# it passed" limit exists to prevent, arriving through the back door.
{ decision 31 "ESC-1" "(none)"
  echo "- **Criterion waived:** S3"
} >> "$R/docs/DESIGN.oracle.md"
commit "Waive S3 with no reasoning"
out="$(run)"
expect_rc "a waiver with no reasoning fails" 1 $?
expect_contains "and says what the field is for" "$out" "changes what a gate does"
git -C "$R" reset -q --hard HEAD~1

# A field that waives nothing while reading as though it did.
{ decision 32 "ESC-1" "(none)"
  echo "- **Criterion waived:** the acceptance stuff is not really measurable here"
} >> "$R/docs/DESIGN.oracle.md"
commit "Waive nothing in particular"
out="$(run)"
expect_rc "a waiver naming no criterion fails" 1 $?
expect_contains "and asks for an id" "$out" "naming no criterion"
git -C "$R" reset -q --hard HEAD~1

# And the field is OPTIONAL — the overwhelming majority of decisions waive
# nothing, and requiring it would turn every ruling into a criterion override.
expect_rc "a decision with no waiver field is still well-formed" 0 "$(run >/dev/null; echo $?)"

summary
