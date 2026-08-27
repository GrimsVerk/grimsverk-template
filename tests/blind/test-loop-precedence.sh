#!/usr/bin/env bash
#
# test-loop-precedence.sh — decided work outranks new questions (loop-economy
# slice 2, ESC-217/ESC-218). Written blind from the slice's Delivers line.
#
# The rebalanced detector, after WAIT, SETUP and a HIGH block: close open
# decisions (STEWARD), build merged unbuilt plans (ORCHESTRATE), and only then
# feed non-blocking evidence to the oracle (ORACLE/REASON=evidence). Before
# this, a fresh LOW question could pull the loop into another oracle cycle
# while a ruling it had already paid for sat unplanned and unbuilt — spending
# on new questions ahead of decided work. Every reading that is not WAIT also
# carries the economy counters, so the run log shows the queue draining.
#
# Same recipe as tests/test-deliver-phase.sh: a stub gh that answers nothing
# (no open pull request, no merged refs — so a plan is "built" only when its
# own front matter says `status: merged`), a manufactured repository.

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

echo "=== deliver-phase.sh — decided work outranks new questions ==="

# expect_line <description> <haystack> <exact-line> — a KEY=VALUE counter is
# matched as a whole line, so OPEN_DECISIONS=1 cannot be satisfied by
# OPEN_DECISIONS=12 the way a substring match would be.
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
mkdir -p "$R/docs/plans/oracle"

cat > "$R/docs/DESIGN.md" <<'EOF'
# Design

## 5. Requirements

- **R1** — stores a note

## 13. Success criteria

- **S1** — a note round-trips
EOF

# R1 is covered by a plan whose own front matter says the work landed, which
# keeps the owner's requirement out of every queue below — the fixture's noise
# floor, not a case under test.
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

low_backlog() {
  cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-9** — which flag name? Proposed: --sync. **LOW**: cheap to rename.
EOF
}
low_backlog

# The open decision: no plan covers R1000, no closure line, not a HALT. Its
# Evidence field deliberately does NOT mention BL-9, which must stay uncited
# until step 4.
step1_ledger() {
  cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — pick the cache

- **Date:** 2026-08-27
- **Evidence:** ESC-1
- **Requirements added:** R1000
- **Requirements superseded:** (none)
- **Rationale:** an in-memory cache loses everything on restart, which the
  measured run showed twice.
EOF
}
step1_ledger

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

# ---------------- 1: an open decision outranks new LOW evidence (ESC-217)
# OD-1 added R1000, nothing plans it, and BL-9 sits uncited. The old detector
# fed BL-9 to the oracle; the decided-but-unclosed ruling is the work the loop
# already paid for, so it goes first.
out="$(run_phase)"
expect_contains "an open decision outranks uncited LOW evidence" "$out" \
  "PHASE=STEWARD"
expect_contains "and the decision needing closure is named" "$out" "ODS=OD-1"
expect_not_contains "the LOW evidence is not the reason anything runs" "$out" \
  "REASON=evidence"
# The economy counters, on the same reading (ESC-218's observability half).
expect_line "the reading counts the open decision" "$out" "OPEN_DECISIONS=1"
expect_line "and the evidence waiting behind it" "$out" "EVIDENCE=1"

# ---------------- 2: a merged unbuilt plan outranks new evidence too
# A plan citing OD-1 and covering R1000 closes the decision; with the stub gh
# reporting no merged feat/ branch and no `status: merged`, the plan itself is
# now the queue.
cat > "$R/docs/plans/oracle/od-1.md" <<'EOF'
---
slug: od-1
covers: [R1000]
status: draft
---
# Cache — Plan

Implements OD-1.

## Slice 1 — the cache
- **Files:** `src/cache.py`
- **Estimate:** ~30 lines
EOF
sync "plan for OD-1"
out="$(run_phase)"
expect_contains "a merged unbuilt plan outranks uncited LOW evidence" "$out" \
  "PHASE=ORCHESTRATE"
expect_contains "and the unbuilt plan is the one named" "$out" "SLUG=od-1"
expect_line "the reading counts the unbuilt plan" "$out" "UNBUILT_PLANS=1"

# ---------------- 3: only with decided work closed does evidence get through
sed -i 's/^status: draft$/status: merged/' "$R/docs/plans/oracle/od-1.md"
sync "od-1 built"
out="$(run_phase)"
expect_contains "with decided work closed, evidence reaches the oracle" "$out" \
  "PHASE=ORACLE"
expect_contains "through the catch-all, as evidence" "$out" "REASON=evidence"
expect_contains "naming the uncited item" "$out" "UNCITED=BL-9"

# ---------------- 4: citing the evidence drains the last queue
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'
- **Considered:** BL-9 — the proposed flag name stands; renaming later is cheap.
EOF
sync "cite BL-9"
out="$(run_phase)"
expect_contains "decided, built and cited means ACCEPTANCE" "$out" \
  "PHASE=ACCEPTANCE"

# ---------------- 5: a HIGH uncertainty still vetoes everything (ESC-218)
# Back to step 1's state — the decision open again, BL-9 uncited — plus an
# unruled HIGH. Only HIGH blocks build, and it blocks ahead of the steward
# queue: an expensive-to-reverse question outranks work already decided.
rm "$R/docs/plans/oracle/od-1.md"
step1_ledger
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-9** — which flag name? Proposed: --sync. **LOW**: cheap to rename.
- **BL-10** — schema? **HIGH**: changes an external format.
EOF
sync "reopen the decision, add a HIGH"
out="$(run_phase)"
expect_contains "an unruled HIGH still vetoes the whole queue" "$out" \
  "PHASE=ORACLE"
expect_contains "for the blocking reason, not the catch-all" "$out" \
  "REASON=uncertainties"
expect_contains "naming the HIGH item" "$out" "UNRULED=BL-10"

# ---------------- 7: no design document is still SETUP
# With everything else quiet, a repository with no docs/DESIGN.md has nothing
# any loop phase could act on — /design is interactive and owner-landed, so
# the rebalance must not have swallowed the SETUP reading.
git -C "$R" rm -q docs/DESIGN.md
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence
EOF
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

_(nothing yet)_
EOF
sync "no design document"
out="$(run_phase)"
expect_contains "a missing design is still SETUP" "$out" "PHASE=SETUP"

summary
