#!/usr/bin/env bash
#
# test-brake.sh — the oracle's per-target do-not-dispatch brake (ESC-221,
# loop-economy slice 3, the owner's Q1 ruling).
#
# Downstream, the oracle diagnosed a stuck driver in writing — "nothing an
# oracle may write can [unstick it]" — and was right: the driver read no
# prose. docs/oracle/do-not-dispatch.md is the machine-readable line it
# lacked. The detector routes around a fenced target and reports the skip;
# the brake can only remove work from a queue, never make a check pass, and
# it fences a TARGET, never the run.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"
ROOT="$HERE/.."

PHASE="$ROOT/template/.claude/scripts/deliver-phase.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== do-not-dispatch — the oracle's per-target brake ==="

mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/gh"
chmod +x "$WORK/bin/gh"

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans/oracle" "$R/docs/oracle" "$R/.github/scripts"
cp "$ROOT/template/.github/scripts/coverage.sh" "$R/.github/scripts/"

cat > "$R/docs/DESIGN.md" <<'EOF'
# Design

## 5. Requirements

- **R1** — stores a note
EOF
cat > "$R/docs/plans/base.md" <<'EOF'
---
slug: base
covers: [R1]
status: merged
---
# Base — Plan
EOF
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-9** — which flag name? Proposed: --sync. **LOW**: cheap to rename.
EOF
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — pick the cache

- **Requirements added:** R1000
EOF
git -C "$R" add -A && git -C "$R" commit -qm seed
git -C "$R" remote add origin https://github.com/own/repo.git
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

run_phase() { ( cd "$R" && env GH="$WORK/bin/gh" "$PHASE" 2>&1 ); }

# Baseline: the open decision is steward work.
out="$(run_phase)"
expect_contains "without a brake the open decision is dispatched" "$out" "PHASE=STEWARD"
expect_contains "and named" "$out" "ODS=OD-1"

# Fence the decision: the steward queue empties, the run keeps moving (the
# waiting evidence is next), and the skip is REPORTED, never silent.
cat > "$R/docs/oracle/do-not-dispatch.md" <<'EOF'
# Do not dispatch

- OD-1 — coverage cannot see the superseded id; template defect, evidence in OD-2
EOF
out="$(run_phase)"
expect_not_contains "a fenced decision is not dispatched" "$out" "PHASE=STEWARD"
expect_contains "the run moves on to the next queue" "$out" "PHASE=ORACLE"
expect_contains "for the waiting evidence" "$out" "UNCITED=BL-9"
expect_contains "and the skip is reported by name" "$out" "BRAKED=OD-1"
expect_contains "with the steward queue honestly empty" "$out" "OPEN_DECISIONS=0"

# Fence a plan: same mechanics on the build queue.
cat > "$R/docs/plans/oracle/od-1.md" <<'EOF'
---
slug: od-1
covers: [R1000]
---
# Cache — Plan

Implements OD-1.
EOF
cat > "$R/docs/oracle/do-not-dispatch.md" <<'EOF'
# Do not dispatch

- plan:od-1 — its feature branch hits a proxy bug; fence until the template fix lands
EOF
out="$(run_phase)"
expect_not_contains "a fenced plan is not built" "$out" "PHASE=ORCHESTRATE"
expect_contains "the skip is reported" "$out" "BRAKED=plan:od-1"
expect_contains "and the run moves on" "$out" "PHASE=ORACLE"

# A brake line naming nothing in any queue fences nothing and reports nothing —
# the file cannot manufacture a skip.
cat > "$R/docs/oracle/do-not-dispatch.md" <<'EOF'
# Do not dispatch

- OD-99 — a target that does not exist
EOF
out="$(run_phase)"
expect_contains "an irrelevant brake line changes no phase" "$out" "PHASE=ORCHESTRATE"
expect_not_contains "and reports no skip" "$out" "BRAKED="

# When the brake empties the LAST queue, the run walks on to acceptance — by
# design (the Q1 ruling: a brake fences a lane, never the run) — and the skip
# stays on the reading, loudly, so an idle-by-brake run reads as exactly
# that and never as a finished one with nothing to say.
rm "$R/docs/plans/oracle/od-1.md"
cat > "$R/docs/oracle/do-not-dispatch.md" <<'EOF'
- OD-1 — fenced again
EOF
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — cites the evidence

- **Evidence:** BL-9
EOF
out="$(run_phase)"
expect_contains "a fully braked world still moves (Q1: never a run halt)" "$out" \
  "PHASE=ACCEPTANCE"
expect_contains "and carries the skip on its face" "$out" "BRAKED=OD-1"

summary
