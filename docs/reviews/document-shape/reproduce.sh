#!/usr/bin/env bash
#
# reproduce.sh — rebuild the fixtures behind findings 1, 2 and 6 of the
# document-shape review (see README.md in this directory).
#
# Read-only with respect to this repository: it copies the gate scripts out of
# template/.github/scripts/ into a throwaway git repo under $TMPDIR and runs
# them there. Nothing in the working tree is touched.
#
#     docs/reviews/document-shape/reproduce.sh
#
# Three things are demonstrated, each with the real script and its real output:
#
#   A. FINDING 2 — the weakest "Vision statement relied on" value that passes
#      oracle-decisions.sh is a single quoted character, in a repository that
#      contains no docs/VISION.md at all.
#
#   B. FINDING 2 (second half) — an oracle decision may declare an OWNER's
#      requirement superseded. The R1000 offset rule is applied to `Requirements
#      added:` only, never to `Requirements superseded:`.
#
#   C. FINDING 1 — a plan under docs/plans/oracle/ (the deliberately un-owned
#      path) that cites no oracle decision may claim every owner requirement in
#      its `covers:` field. oracle-decisions.sh accepts it under "form 2", and
#      coverage.sh goes from "2 requirements with no plan" (exit 1) to "Every
#      requirement is covered by a plan" (exit 0) — while the plan's single
#      slice builds one of them.
#
# Exit code is 0 when every step behaved as the review reports. A non-zero exit
# means a gate has since been tightened and the corresponding finding no longer
# reproduces — which is the good outcome, and worth reading the diff for.

set -uo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SRC="$ROOT/template/.github/scripts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

RC=0
step()  { printf '\n\033[1m=== %s ===\033[0m\n' "$*"; }
ok()    { printf '  \033[32mreproduces\033[0m  %s\n' "$*"; }
bad()   { printf '  \033[31mDOES NOT REPRODUCE\033[0m  %s\n' "$*"; RC=1; }

for s in oracle-decisions.sh coverage.sh plan-parse.sh plan-lint.sh; do
  [[ -f "$SRC/$s" ]] || { echo "reproduce: missing $SRC/$s" >&2; exit 2; }
done

# ------------------------------------------------------------- the base commit
# A minimal generated project: two owner requirements, two pieces of logged
# evidence, an empty oracle ledger, and — deliberately — NO docs/VISION.md.
mkdir -p "$WORK/docs/plans/oracle" "$WORK/.github/scripts"
cp "$SRC"/{oracle-decisions.sh,coverage.sh,plan-parse.sh,plan-lint.sh} "$WORK/.github/scripts/"
cd "$WORK" || exit 2

git init -q .
git config user.email reproduce@example.invalid
git config user.name  reproduce

cat > docs/BACKLOG.md <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- BL-7 — Should retention be per-user or global? proposed: global. HIGH risk.
EOF

cat > docs/escapes.md <<'EOF'
| id | date | what escaped | gate | check added |
| --- | --- | --- | --- | --- |
| ESC-3 | 2026-08-16 | sync writes lost on conflict | tests | unverified — pending |
EOF

cat > docs/DESIGN.md <<'EOF'
## 5. Requirements

**Functional**
- **R1** — sync
- **R2** — retention

## 6. Constraints & assumptions
EOF

printf '# Design decisions from evidence\n' > docs/DESIGN.oracle.md

git add -A
git commit -qm 'base'
BASE="$(git rev-parse HEAD)"
echo "base commit: ${BASE:0:12}   (no docs/VISION.md in this tree, by design)"

# --------------------------------------------------------------------- case A
step "A. FINDING 2 — the weakest vision field that passes"

cat >> docs/DESIGN.oracle.md <<'EOF'

## OD-1 — retention becomes global, evicting per-user rows

- **Date:** 2026-08-16
- **Evidence:** BL-7, ESC-3
- **Requirements added:** R1000
- **Requirements superseded:** (none)
- **Vision statement relied on:** "s"
- **Alternatives considered:** (none)
- **Rationale:** the evidence points here.

**R1000** — retention is global.
EOF

echo '  the decision under test:'
echo '    - **Vision statement relied on:** "s"'
echo '    - **Alternatives considered:** (none)'
echo
if BASE_SHA="$BASE" .github/scripts/oracle-decisions.sh 2>&1 | sed 's/^/  /'; then
  ok 'a one-character quote passes, with no docs/VISION.md anywhere in the tree'
  ok '"(none)" alternatives pass too — that refusal applies only to the opt-out class'
else
  bad 'oracle-decisions.sh now rejects the minimal vision field'
fi

git checkout -q -- docs/DESIGN.oracle.md

# --------------------------------------------------------------------- case B
step "B. FINDING 2 — an oracle decision may supersede an OWNER requirement"

cat >> docs/DESIGN.oracle.md <<'EOF'

## OD-1 — retention narrowed: per-user retention is withdrawn

- **Date:** 2026-08-16
- **Evidence:** BL-7
- **Requirements added:** (none)
- **Requirements superseded:** R2
- **Vision statement relied on:** "I would trade completeness for a system I can reason about."
- **Alternatives considered:** keeping R2 and building the per-user index; rejected as unbounded work.
- **Rationale:** the evidence shows per-user retention cannot be delivered within the constraint.
EOF

echo '  superseding R2 — an owner requirement, far below the R1000 offset:'
if BASE_SHA="$BASE" .github/scripts/oracle-decisions.sh 2>&1 | sed 's/^/  /'; then
  ok 'the R1000 offset is enforced on "Requirements added" only, never on "superseded"'
else
  bad 'oracle-decisions.sh now applies the offset to superseded ids'
fi

echo
echo '  ...and coverage.sh does not honour the supersession:'
.github/scripts/coverage.sh 2>&1 | sed 's/^/  /'
if .github/scripts/coverage.sh >/dev/null 2>&1; then
  bad 'coverage.sh unexpectedly reports no gaps'
else
  ok 'R2 stays in the coverage report after being declared superseded'
fi

git checkout -q -- docs/DESIGN.oracle.md

# --------------------------------------------------------------------- case C
step "C. FINDING 1 — an un-owned plan claims requirements it does not build"

echo '  before the plan:'
.github/scripts/coverage.sh 2>&1 | tail -3 | sed 's/^/  /'

cat > docs/plans/oracle/retention-sweep.md <<'EOF'
---
slug: retention-sweep
status: draft
created: 2026-08-16
design: milestone 2
covers: [R1, R2]
---

# Retention sweep — Plan

## Summary

Implements R1 and R2.

## Uncertainties

None: every decision derived from the design.

## Slice 1 — retention runs on a timer

- **Delivers:** a sweep that deletes expired rows
- **Files:** `src/sweep.py`, `tests/test_sweep.py`
- **Estimate:** ~40 lines

### Signatures

```python
def sweep(now: float) -> int: ...
```

## Out of scope

- per-user retention policy
EOF

echo
echo '  the plan: covers [R1, R2], one slice, ~40 lines, and R2 is explicitly'
echo '  listed under "Out of scope" in its own body.'
echo

echo '  oracle-decisions.sh (form 2 — no OD cited, covers must already exist):'
if BASE_SHA="$BASE" .github/scripts/oracle-decisions.sh 2>&1 | sed 's/^/    /'; then
  ok 'an un-owned plan may claim owner requirement ids with no decision behind it'
else
  bad 'oracle-decisions.sh now rejects the covers-only plan'
fi

echo
echo '  plan-lint.sh:'
PLANS_DIR=docs/plans .github/scripts/plan-lint.sh 2>&1 | sed 's/^/    /'

echo
echo '  coverage.sh after the plan:'
.github/scripts/coverage.sh 2>&1 | sed 's/^/    /'
if .github/scripts/coverage.sh >/dev/null 2>&1; then
  ok 'coverage went from exit 1 (gaps) to exit 0 (every requirement covered)'
  ok 'one slice building one requirement cleared the whole coverage report'
else
  bad 'coverage.sh still reports gaps — the claim no longer counts as coverage'
fi

# --------------------------------------------------------------------- verdict
step "verdict"
if [[ "$RC" -eq 0 ]]; then
  echo "  Every case reproduces against $(git -C "$ROOT" rev-parse --short HEAD)."
  echo "  See README.md in this directory for what each one means."
else
  echo "  At least one case did NOT reproduce — a gate has been tightened since"
  echo "  the review was written. Read the diff; the finding may be closed." >&2
fi
exit "$RC"
