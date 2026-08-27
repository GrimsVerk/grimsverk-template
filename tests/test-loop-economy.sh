#!/usr/bin/env bash
#
# test-loop-economy.sh — the rehearsal (lexicon-and-rehearsal slice 3).
#
# The template's CI tested every gate in isolation and had never run the
# loop's ECONOMY end to end — which is why every economy defect of the
# 2026-08-20 experiment (build starvation, the supersession livelock, rulings
# evaporating) shipped invisible to a green suite. This file drives the real
# detector through a whole small project, reading by reading, and asserts the
# one property the experiment lacked: THE LOOP CONVERGES TO BUILD. The
# driver-level shapes (the repetition guard, the no-PR guard, the brake under
# the driver, the version stop) live in test-deliver-loop.sh and
# test-brake.sh; this file owns the sequence.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"
ROOT="$HERE/.."

PHASE="$ROOT/template/.claude/scripts/deliver-phase.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== loop economy — a clean project converges to build ==="

mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
args="$*"
case "$args" in
  *"pulls?state=closed"*) [[ -n "${STUB_MERGED_REFS:-}" ]] && printf '%s\n' "$STUB_MERGED_REFS" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans/oracle" "$R/docs/oracle" "$R/.github/scripts"
cp "$ROOT/template/.github/scripts/coverage.sh" "$R/.github/scripts/"

cat > "$R/docs/DESIGN.md" <<'EOF'
# Design

## 5. Requirements

- **R1** — converts a value between units
EOF
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-1** — which rounding mode? Proposed: bankers. **HIGH**: an external
  contract; wrong is expensive.
- **BL-2** — what is the flag called? Proposed: --precision. **LOW**: a
  rename is cheap.
EOF
: > "$R/docs/DESIGN.oracle.md"
git -C "$R" add -A && git -C "$R" commit -qm seed
git -C "$R" remote add origin https://github.com/own/repo.git
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

MERGED=""
run_phase() { ( cd "$R" && env GH="$WORK/bin/gh" STUB_MERGED_REFS="$MERGED" "$PHASE" 2>&1 ); }
phase_of() { sed -n 's/^PHASE=//p' <<<"$1" | head -1; }

# The journey a run takes on this project, one detector reading per step,
# the world advanced between readings exactly as the phase asks. Seven
# readings, build reached at the third — on 2026-08-20 the build phase was
# reached once in 1650 events, and only under a broken gate.

# 1. The HIGH seed blocks everything else.
out="$(run_phase)"
expect_contains "reading 1: the HIGH question goes first" "$out" "PHASE=ORACLE"
expect_contains "as the blocking kind" "$out" "REASON=uncertainties"

# 2. The oracle rules it (adds a requirement); the LOW item WAITS.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'
## OD-1 — bankers rounding, as proposed

- **Evidence:** BL-1
- **Requirements added:** R1000
EOF
out="$(run_phase)"
expect_contains "reading 2: the fresh ruling is steward work" "$out" "PHASE=STEWARD"
expect_contains "naming the decision" "$out" "ODS=OD-1"
expect_contains "while the LOW evidence waits, counted" "$out" "EVIDENCE=1"

# 3. The steward plans it; the plan outranks the waiting evidence too.
cat > "$R/docs/plans/oracle/od-1.md" <<'EOF'
---
slug: od-1
covers: [R1000]
---
# Rounding — Plan

Implements OD-1.
EOF
out="$(run_phase)"
expect_contains "reading 3: BUILD — the loop reaches it before new questions" \
  "$out" "PHASE=ORCHESTRATE"
expect_contains "for the steward's plan" "$out" "SLUG=od-1"

# 4. The build merges; NOW the waiting evidence surfaces.
MERGED="feat/od-1"
out="$(run_phase)"
expect_contains "reading 4: the deferred LOW evidence surfaces" "$out" "PHASE=ORACLE"
expect_contains "as ordinary evidence" "$out" "REASON=evidence"
expect_contains "the item that waited" "$out" "UNCITED=BL-2"

# 5. One line clears it (the Q2 fast path) — no eight-field ruling.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## Clearances

- **Cleared:** BL-2 — LOW, default stood: --precision shipped as proposed
EOF
out="$(run_phase)"
expect_contains "reading 5: the cleared item is metabolised; the milestone is next" \
  "$out" "PHASE=PLAN"
expect_contains "naming the owner requirement" "$out" "REQS=R1"

# 6. The milestone is planned.
cat > "$R/docs/plans/convert.md" <<'EOF'
---
slug: convert
covers: [R1]
---
# Convert — Plan
EOF
out="$(run_phase)"
expect_contains "reading 6: build again" "$out" "PHASE=ORCHESTRATE"
expect_contains "for the milestone plan" "$out" "SLUG=convert"

# 7. Everything built: done.
MERGED=$'feat/od-1\nfeat/convert'
out="$(run_phase)"
expect_contains "reading 7: acceptance — the project converged" "$out" "PHASE=ACCEPTANCE"

# ---- the 2026-08-20 livelock shape, replayed (ESC-219)
# A later decision supersedes a requirement nobody ever planned. The old
# loop dispatched a steward for the dead id every cycle, forever — a
# quarter of one project's ledger exists only to describe that stuckness.
# Now: not a gap, not a dispatch, reported as awaiting the owner.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — measure first

- **Evidence:** BL-1
- **Requirements added:** R1001
EOF
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-3 — measurement was wrong; retract

- **Evidence:** BL-1
- **Requirements added:** (none)
- **Requirements superseded:** R1001
EOF
out="$(run_phase)"
expect_contains "a superseded, never-planned id dispatches nobody" "$out" \
  "PHASE=ACCEPTANCE"
expect_not_contains "no steward is summoned for a dead requirement" "$out" \
  "PHASE=STEWARD"
cov="$( cd "$R" && .github/scripts/coverage.sh 2>&1 || true )"
expect_contains "and the id stays on the owner's desk, not silently gone" \
  "$cov" "awaiting the owner's retirement ruling"

# ---- the brake, in sequence (ESC-221): fence the NEXT decision mid-journey
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-4 — needs a fixture that trips a template bug

- **Evidence:** BL-1
- **Requirements added:** R1002
EOF
out="$(run_phase)"
expect_contains "an open decision resumes the steward queue" "$out" "PHASE=STEWARD"
cat > "$R/docs/oracle/do-not-dispatch.md" <<'EOF'
- OD-4 — its fixture trips the proxy bug; fenced until the template fix lands
EOF
out="$(run_phase)"
expect_not_contains "the fenced decision stops burning sessions" "$out" "PHASE=STEWARD"
expect_contains "and the skip is on the reading's face" "$out" "BRAKED=OD-4"

summary
