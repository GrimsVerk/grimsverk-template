#!/usr/bin/env bash
#
# The end-to-end lifecycle fixture (ESC-23).
#
# The evidence for this file is the log itself: three of four recent shipped
# defects were found by USING the template — a fresh project whose documented
# next step was impossible — while every per-script fixture stayed green,
# because each tested its script in isolation and the defects lived in the
# SEAMS between documents and gates. So this walks one rendered project
# through its own documented lifecycle: render → design → plan → feature →
# oracle chain → template update, asserting at each seam that the next step is
# possible. No live engine anywhere: the lifecycle under test is the artifact
# sequence, not the model output.
#
# Requires: copier on PATH (uv tool install copier).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TEMPLATE="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== lifecycle (rendered project, end to end) ==="

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

copier copy --defaults --trust --quiet --vcs-ref=HEAD \
  --data language=python \
  --data code_owner="@grimsverk" \
  "$TEMPLATE" "$WORK/note_app" >/dev/null 2>&1 \
  || { no "template renders"; summary; exit 1; }
ok "template renders"

R="$WORK/note_app"
init_repo "$R"
git -C "$R" add -A && git -C "$R" commit -qm "scaffold"
SCAFFOLD="$(git -C "$R" rev-parse HEAD)"

run_in() { ( cd "$R" && "$@" 2>&1 ); }
on_branch()   { git -C "$R" switch -q main && git -C "$R" switch -qc "$1"; }
commit_all()  { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }
merge_branch(){ git -C "$R" switch -q main && git -C "$R" merge -q --no-ff -m "Merge $1" "$1"; }

# A stub gh for the phase detector: no open PRs, no merged PRs.
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/gh"
chmod +x "$WORK/bin/gh"

# ---------------------------------------------------------- day-zero seams
# The skeletons a fresh project's own documents point at must exist, and must
# contribute no phantom state: no requirement ids, no citable evidence.
out="$(run_in .github/scripts/coverage.sh)"
expect_not_contains "day zero: no phantom oracle requirement" "$out" "R1000"

if grep -qE 'BL-[0-9]+' "$R/docs/BACKLOG.md"; then
  no "day zero: the backlog is not phantom evidence"
else
  ok "day zero: the backlog is not phantom evidence"
fi

# An oracle decision citing the skeleton's non-ids must fail — end to end,
# against the rendered files, not a hand-built fixture.
on_branch docs/phantom-check
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-1 — a decision citing nothing real

- **Date:** 2026-08-16
- **Evidence:** BL-1
- **Requirements added:** (none)
- **Requirements superseded:** (none)
- **Vision statement relied on:** "Anything."
- **Alternatives considered:** none worth naming
- **Rationale:** should never land
EOF
commit_all "phantom citation"
out="$(run_in env BASE_SHA="$SCAFFOLD" .github/scripts/oracle-decisions.sh)"
expect_rc "day zero: citing the skeleton's example ids fails the gate" 1 $?
expect_contains "and names the dangling id" "$out" "BL-1"
git -C "$R" switch -q main && git -C "$R" branch -qD docs/phantom-check

# ----------------------------------------------------------- design lands
on_branch docs/design-doc
cat > "$R/docs/DESIGN.md" <<'EOF'
# Note App — Design

## 5. Requirements

- **R1** a note can be stored
- **R2** stored notes can be listed

## 12. Milestones

1. Notes end to end.

## 13. Success criteria

- **S1** a stored note appears in the listing
EOF
cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## What it's for

Keeping short notes without ceremony.

## Priorities, in order

- **V1** — Correctness, then speed of capture.

## What I'd trade away

- **V2** — Features. A note store does not need folders.
EOF
commit_all "the design and the vision"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"

# The design PR must be landable by its OWNER and only its owner.
out="$(run_in env BASE_SHA="$SCAFFOLD" HEAD_SHA="$HEAD_SHA" PR_AUTHOR="grimsverk" \
        .github/scripts/owner-authored.sh)"
expect_rc "the owner can land the design" 0 $?
out="$(run_in env BASE_SHA="$SCAFFOLD" HEAD_SHA="$HEAD_SHA" PR_AUTHOR="agent-bot" \
        .github/scripts/owner-authored.sh)"
expect_rc "an agent cannot land the design" 1 $?

# And the design-doc branch is exempt from the plan gate at any size.
out="$(run_in env BASE_SHA="$SCAFFOLD" HEAD_REF="docs/design-doc" \
        .github/scripts/plan-resolve.sh)"
expect_rc "the design branch clears the plan gate" 0 $?
merge_branch docs/design-doc
POST_DESIGN="$(git -C "$R" rev-parse HEAD)"

# With a design landed and nothing planned, coverage is the to-do list...
run_in .github/scripts/coverage.sh >/dev/null
expect_rc "coverage now reports gaps (rc 1)" 1 $?
# ...and the phase detector agrees on the next move.
out="$(run_in env GH="$WORK/bin/gh" .claude/scripts/deliver-phase.sh)"
expect_contains "the driver's next move is PLAN" "$out" "PHASE=PLAN"
expect_contains "with the right gaps" "$out" "R1 R2"

# ------------------------------------------------------------- a plan lands
on_branch docs/plan-notes
mkdir -p "$R/docs/plans"
cat > "$R/docs/plans/notes.md" <<'EOF'
---
slug: notes
status: draft
created: 2026-08-16
design: Notes end to end
covers: [R1, R2]
---
# Notes — Plan

## Uncertainties

None: every decision derived from the design.

## Slice 1 — store and list a note
- **Delivers:** a note round-trips through the store into the listing
- **Files:** `src/note_app/store.py`, `tests/test_store.py`
- **Estimate:** ~40 lines
EOF
commit_all "the notes plan"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"

out="$(run_in env BASE_SHA="$POST_DESIGN" HEAD_SHA="$HEAD_SHA" \
        .github/scripts/vision-complete.sh)"
expect_rc "a filled vision lets the plan through" 0 $?
run_in .github/scripts/plan-lint.sh >/dev/null
expect_rc "every plan in the tree parses" 0 $?
out="$(run_in env BASE_SHA="$POST_DESIGN" HEAD_REF="docs/plan-notes" \
        .github/scripts/plan-resolve.sh)"
expect_rc "the plan lands on an exempt docs/ branch" 0 $?
merge_branch docs/plan-notes
POST_PLAN="$(git -C "$R" rev-parse HEAD)"

run_in .github/scripts/coverage.sh >/dev/null
expect_rc "coverage is clean once the plan lands (rc 0)" 0 $?

# -------------------------------------------------------- the feature seam
on_branch feat/notes
mkdir -p "$R/src/note_app"
echo "notes = []" > "$R/src/note_app/store.py"
commit_all "build the notes slice"
out="$(run_in env BASE_SHA="$POST_PLAN" HEAD_REF="feat/notes" \
        .github/scripts/plan-resolve.sh)"
expect_rc "the feature branch resolves to its plan" 0 $?
expect_contains "by slug" "$out" "docs/plans/notes.md"
merge_branch feat/notes

# --------------------------------------------------------- the oracle chain
# Evidence lands first (an escape row), on the default branch...
echo "| ESC-1 | 2026-08-16 | listing order surprised the owner | none existed | unverified — pending: an ordering test |" \
  >> "$R/docs/escapes.md"
git -C "$R" add -A && git -C "$R" commit -qm "log ESC-1"
POST_ESC="$(git -C "$R" rev-parse HEAD)"

# ...the ledger's own gate accepts the append...
out="$(run_in env BASE_SHA="$POST_PLAN" .github/scripts/escapes-append-only.sh)"
expect_rc "the escape append passes the append-only gate" 0 $?

# ...the oracle metabolises it, quoting the vision...
on_branch docs/oracle-1
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-1 — listings are newest-first

- **Date:** 2026-08-16
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** (none)
- **Vision statement relied on:** V1 — "Correctness, then speed of capture."
- **Vision statements against:** V2 — "Features. A note store does not need
  folders." Ordering is not a feature in that sense, so it does not tell
  against this.
- **Alternatives considered:** insertion order (what surprised the owner);
  alphabetical (meaningless for notes).
- **Rationale:** the escape shows the current order reads as a bug.

R1000: the listing presents notes newest-first.
EOF
mkdir -p "$R/docs/oracle"
cat > "$R/docs/oracle/handoff-2026-08-16-1.md" <<'EOF'
# Handoff 2026-08-16-1

Needs planning: OD-1.
EOF
commit_all "oracle ruling"
out="$(run_in env BASE_SHA="$POST_ESC" .github/scripts/oracle-decisions.sh)"
expect_rc "the ruling passes against landed evidence" 0 $?
merge_branch docs/oracle-1
POST_ORACLE="$(git -C "$R" rev-parse HEAD)"

# ...the driver sees the un-planned decision and sends a steward...
out="$(run_in env GH="$WORK/bin/gh" .claude/scripts/deliver-phase.sh)"
expect_contains "the driver's next move is STEWARD" "$out" "PHASE=STEWARD"
expect_contains "for the ruling that landed" "$out" "OD-1"

# ...whose plan may implement the decision, and may not invent one.
on_branch docs/oracle-plan-od-1
cat > "$R/docs/plans/oracle/newest-first.md" <<'EOF'
---
slug: newest-first
status: draft
created: 2026-08-16
design: OD-1
covers: [R1000]
---
# Newest-first listing — Plan

Implements OD-1.

## Uncertainties

None: every decision derived from the decision.

## Slice 1 — order the listing
- **Delivers:** the listing returns notes newest-first
- **Files:** `src/note_app/store.py`, `tests/test_order.py`
- **Estimate:** ~20 lines
EOF
commit_all "steward plan"
out="$(run_in env BASE_SHA="$POST_ORACLE" .github/scripts/oracle-decisions.sh)"
expect_rc "the steward's plan passes citing the landed ruling" 0 $?

sed -i 's/Implements OD-1./Implements OD-99./' "$R/docs/plans/oracle/newest-first.md"
sed -i 's/design: OD-1/design: OD-99/' "$R/docs/plans/oracle/newest-first.md"
commit_all "cite a ruling that never landed"
out="$(run_in env BASE_SHA="$POST_ORACLE" .github/scripts/oracle-decisions.sh)"
expect_rc "a plan citing an unlanded ruling fails" 1 $?
git -C "$R" switch -q main && git -C "$R" branch -qD docs/oracle-plan-od-1

# ----------------------------------------------------- the template-update seam
# The documented maintenance step must be POSSIBLE from a fresh render: the
# update script, run against the very ref this project was rendered from,
# finds nothing to do and says so. ESC-14's conflicted-update path stays open
# and is deliberately not exercised here.
#
# This render comes from a CLEAN CLONE of the template, unlike the one above.
# Rendering a dirty working tree makes copier record a synthetic "dirty" commit
# as _commit — a sha that exists in no clone — and `copier update` then dies
# checking it out. That is an artifact of running the suite mid-edit, not a
# template defect; a real project renders from a landed template. The clone
# means this seam only sees COMMITTED template changes.
CLONE="$WORK/template-clone"
git clone -q "$TEMPLATE" "$CLONE" 2>/dev/null
copier copy --defaults --trust --quiet --vcs-ref=HEAD \
  --data language=python \
  --data code_owner="@grimsverk" \
  "$CLONE" "$WORK/upd_app" >/dev/null 2>&1 \
  || { no "clean-clone render for the update seam"; summary; exit 1; }
U="$WORK/upd_app"
init_repo "$U"
git -C "$U" add -A && git -C "$U" commit -qm "scaffold"
out="$( cd "$U" && scripts/update-from-template.sh --ref HEAD --no-pr 2>&1 )"
expect_rc "update-from-template runs clean on a fresh render" 0 $?
expect_contains "and says there is nothing to do" "$out" "already up to date"

summary
