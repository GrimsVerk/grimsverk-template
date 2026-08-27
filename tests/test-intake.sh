#!/usr/bin/env bash
#
# test-intake.sh — section-aware evidence intake (qualitative-findings).
# Written blind from the slice's Delivers; no implementation was visible.
#
# The backlog grew sections with different owners: Proposed is the owner's own
# idea pile, Approved is attended-mode work, and only the Uncertainties section
# is a question for the oracle. The old evidence intake read every bare id in
# the file as something the oracle owed a citation, so an owner jotting an idea
# under Proposed bought an oracle cycle nobody asked for. The rebalanced
# detector hands the oracle ONLY the Uncertainties items and open escape rows,
# counts what it skipped (PROPOSED_SKIPPED), and leaves the HIGH veto exactly
# where it was.
#
# Same recipe as tests/test-loop-precedence.sh: a stub gh that answers nothing,
# a manufactured repository with the coverage script copied in.

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

PHASE="$ROOT/template/.claude/scripts/deliver-phase.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== deliver-phase.sh — section-aware evidence intake ==="

# expect_line <description> <haystack> <exact-line> — a KEY=VALUE counter is
# matched as a whole line, so PROPOSED_SKIPPED=2 cannot be satisfied by
# PROPOSED_SKIPPED=21 the way a substring match would be.
expect_line() {
  if printf '%s\n' "$2" | grep -Fxq -- "$3"; then ok "$1"
  else no "$1" "expected the exact line: $3" \
    "in: $(printf '%s' "$2" | head -c 400)"; fi
}

# A gh that answers every read with nothing.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$WORK/bin/gh"

# ------------------------------------------------------------------- fixture
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans"

# The detector shells out to .github/scripts/coverage.sh; without it in the
# fixture the coverage read silently yields nothing.
mkdir -p "$R/.github/scripts"
cp "$ROOT/template/.github/scripts/coverage.sh" "$R/.github/scripts/"

cat > "$R/docs/DESIGN.md" <<'EOF'
# Design

## 5. Requirements

- **R1** — stores a note

## 13. Success criteria

- **S1** — a note round-trips
EOF

# R1 is covered by a plan whose own front matter says the work landed — the
# fixture's noise floor, so nothing but the backlog and the escapes ledger can
# be the reason any phase fires.
cat > "$R/docs/plans/base.md" <<'EOF'
---
slug: base
covers: [R1]
status: merged
---
# Base — Plan

## Slice 1 — store the note
- **Files:** `src/store.py`
- **Estimate:** ~20 lines
EOF

# Three sections, three different owners. Only the Uncertainties section is a
# question for the oracle.
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Proposed

- **BL-1** — an owner idea nobody asked about

## Approved

- **BL-2** — approved work for attended mode

## Uncertainties awaiting oracle ruling

- **BL-3** — which flag? Proposed --sync. **LOW**: cheap.
EOF

cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence
EOF

# One open escape row: evidence the oracle has not yet cited.
cat > "$R/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | excerpting cost more than it saved | none existed | pending |
EOF

git -C "$R" add -A && git -C "$R" commit -qm seed
git -C "$R" remote add origin https://github.com/own/repo.git
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

# Commit each state and keep origin/main on it, so the detector always reads a
# clean tree that matches its remote.
sync() {
  git -C "$R" add -A && git -C "$R" commit -qm "$1"
  git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
}

run_phase() { ( cd "$R" && env GH="$WORK/bin/gh" "$PHASE" 2>&1 ); }

# ---------------- 1: only the Uncertainties section and open escapes are
# handed to the oracle. BL-1 (Proposed) and BL-2 (Approved) belong to the
# owner and to attended mode, not to the evidence intake.
out="$(run_phase)"
expect_contains "uncited evidence still reaches the oracle" "$out" "PHASE=ORACLE"
expect_contains "through the catch-all, as evidence" "$out" "REASON=evidence"
uncited="$(printf '%s\n' "$out" | grep -m1 'UNCITED=')"
expect_contains "the uncertainty is in the uncited list" "$uncited" "BL-3"
expect_contains "and so is the open escape" "$uncited" "ESC-1"
expect_not_contains "the Proposed item is not handed to the oracle" \
  "$uncited" "BL-1"
expect_not_contains "the Approved item is not handed to the oracle" \
  "$uncited" "BL-2"

# ---------------- 2: what was skipped is counted, so the run log shows the
# intake narrowing rather than silently dropping ids.
expect_line "the reading counts the skipped out-of-section ids" "$out" \
  "PROPOSED_SKIPPED=2"

# ---------------- 3: citing the two real items drains the queue — and the
# Proposed/Approved ids still do not surface anywhere.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'
- **Considered:** BL-3 and ESC-1 — the proposed flag stands and the escape's
  check is queued; both defaults are cheap.
EOF
sync "cite BL-3 and ESC-1"
out="$(run_phase)"
expect_contains "citing the uncertainty and the escape means ACCEPTANCE" \
  "$out" "PHASE=ACCEPTANCE"
expect_not_contains "the Proposed item still does not surface" "$out" "BL-1"
expect_not_contains "the Approved item still does not surface" "$out" "BL-2"

# ---------------- 4: a HIGH in the Uncertainties section still blocks —
# the intake narrowed, the veto did not move.
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Proposed

- **BL-1** — an owner idea nobody asked about

## Approved

- **BL-2** — approved work for attended mode

## Uncertainties awaiting oracle ruling

- **BL-3** — which flag? Proposed --sync. **LOW**: cheap.
- **BL-4** — schema? **HIGH**: changes an external format.
EOF
sync "add a HIGH uncertainty"
out="$(run_phase)"
expect_contains "an unruled HIGH still blocks" "$out" "PHASE=ORACLE"
expect_contains "for the blocking reason, not the catch-all" "$out" \
  "REASON=uncertainties"
expect_contains "naming the HIGH item" "$out" "UNRULED=BL-4"

summary
