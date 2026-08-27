#!/usr/bin/env bash
#
# test-design-gate.sh — /design refuses to skip a stage (design-hardening-loop,
# slice 2). Written blind from the slice's Delivers and Signatures; no
# implementation was visible when this was written.
#
# The attended flow gains four hand-off points, and each one is guarded by
# `design-gate.sh <stage>`: the flow may not advance while the current stage's
# artifact is missing or too thin, and the refusal names exactly what is
# missing. Stages: design | review-conceptual | plans | review-tactical.
# MIN_WORDS (default 150) is the thinness floor for the two review stages.
#
# Recipe as elsewhere in this suite: one fixture known to satisfy every stage,
# and every failing case is a single named deviation from it.

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

GATE="$ROOT/template/.claude/scripts/design-gate.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== design-gate.sh — the flow cannot skip a stage ==="

# words <n> — print exactly n words (deterministic filler for review files).
words() {
  local i out=""
  for ((i = 1; i <= $1; i++)); do out+="lorem "; done
  printf '%s\n' "$out"
}

# seed_compliant <repo> — a repository where every one of the four stages
# should pass: a DESIGN.md with requirement lines, a VISION.md with no empty
# section, both reviews above the default word floor, and one carved
# pseudocode-format plan.
seed_compliant() {
  local r="$1"
  init_repo "$r"
  mkdir -p "$r/docs/reviews/design" "$r/docs/plans"

  cat > "$r/docs/DESIGN.md" <<'EOF'
# Design

## Requirements

- **R1** — the gate refuses to advance while a stage artifact is missing.
- **R2** — every refusal names the expected path of what is missing.
EOF

  cat > "$r/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — a stage skipped quietly costs more than a stage blocked loudly.
- **V2** — I would trade any feature for a design I can hold in my head.

## Core tenets

- **V3** — an artifact below the word floor is treated as absent.
EOF

  words 160 > "$r/docs/reviews/design/conceptual-1.md"
  words 160 > "$r/docs/reviews/design/tactical-1.md"

  cat > "$r/docs/plans/good-plan.md" <<'EOF'
---
slug: good-plan
status: draft
format: pseudocode
---

# Good plan

Rulings: none needed.

## Slice 1 — something

### Signatures

sig text

### Internals

body text
EOF

  git -C "$r" add -A && git -C "$r" commit -qm "seed compliant fixture"
}

# run_gate <repo> <args...> — run the gate from inside the repo, combined
# streams; the gate finds its repository via the current directory.
run_gate() {
  local r="$1"
  shift
  (cd "$r" && "$GATE" "$@" 2>&1)
}

# run_gate_err <repo> <args...> — stderr only, for stream-separation checks.
run_gate_err() {
  local r="$1"
  shift
  # shellcheck disable=SC2069  # stderr-ONLY capture is the point: 2>&1 first
  # routes stderr into the substitution, then stdout is discarded.
  (cd "$r" && "$GATE" "$@" 2>&1 >/dev/null)
}

# ---------------- 1: every stage passes on the compliant fixture
RA="$WORK/compliant"
seed_compliant "$RA"

out="$(run_gate "$RA" design)"
expect_rc "stage design passes on the compliant fixture" 0 $?
expect_contains "and says so" "$out" "design-gate: design complete"

out="$(run_gate "$RA" review-conceptual)"
expect_rc "stage review-conceptual passes on the compliant fixture" 0 $?
expect_contains "and says so" "$out" "design-gate: review-conceptual complete"

out="$(run_gate "$RA" plans)"
expect_rc "stage plans passes on the compliant fixture" 0 $?
expect_contains "and says so" "$out" "design-gate: plans complete"

out="$(run_gate "$RA" review-tactical)"
expect_rc "stage review-tactical passes on the compliant fixture" 0 $?
expect_contains "and says so" "$out" "design-gate: review-tactical complete"

# The pass message is stdout, not stderr: a caller wiring stderr to the owner
# must not see success noise there.
out="$( (cd "$RA" && "$GATE" design 2>/dev/null) )"
expect_contains "the pass message arrives on stdout" "$out" \
  "design-gate: design complete"

# The gate operates on the repository containing the current directory, so it
# must also work from a subdirectory of the repo.
out="$( (cd "$RA/docs" && "$GATE" design 2>&1) )"
expect_rc "stage design passes when run from a subdirectory" 0 $?

# ---------------- 2: design fails on an empty ## section in VISION.md
RB="$WORK/design-fails"
seed_compliant "$RB"

cat > "$RB/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — a stage skipped quietly costs more than a stage blocked loudly.

## Core tenets
EOF
out="$(run_gate "$RB" design)"
expect_rc "design fails when VISION.md has an empty section" 1 $?
expect_contains "and names the file" "$out" "docs/VISION.md"

# A section whose only line is a comment is still empty: comments are
# scaffolding, not content.
cat > "$RB/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — a stage skipped quietly costs more than a stage blocked loudly.

## Core tenets

<!-- fill me in -->
EOF
out="$(run_gate "$RB" design)"
expect_rc "design fails when a section holds only a comment" 1 $?

# ---------------- 3: design fails when DESIGN.md lacks requirement lines
seed_compliant "$WORK/no-reqs"
cat > "$WORK/no-reqs/docs/DESIGN.md" <<'EOF'
# Design

Plenty of prose about intent, but not one requirement line in the
`- **R<n>**` form the gate is looking for.
EOF
out="$(run_gate "$WORK/no-reqs" design)"
expect_rc "design fails when DESIGN.md has no ^- **R<n> line" 1 $?
expect_contains "and names the file" "$out" "docs/DESIGN.md"

# A missing DESIGN.md is the degenerate case of the same rule.
rm "$WORK/no-reqs/docs/DESIGN.md"
out="$(run_gate "$WORK/no-reqs" design)"
expect_rc "design fails when DESIGN.md is absent" 1 $?
expect_contains "and names the expected path" "$out" "docs/DESIGN.md"

# ---------------- 4: review-conceptual — absent, thin, and MIN_WORDS
RC="$WORK/reviews"
seed_compliant "$RC"

rm "$RC/docs/reviews/design/conceptual-1.md"
err="$(run_gate_err "$RC" review-conceptual)"
rc=$?
expect_rc "review-conceptual fails when no conceptual-<n>.md exists" 1 "$rc"
expect_contains "and stderr names the expected path" "$err" \
  "docs/reviews/design/conceptual"

# A thin review is as absent as a missing one, and the refusal states the
# floor the file failed to clear.
words 40 > "$RC/docs/reviews/design/conceptual-1.md"
out="$(run_gate "$RC" review-conceptual)"
expect_rc "review-conceptual fails when the review is under MIN_WORDS" 1 $?
expect_contains "and names the thin file" "$out" "conceptual-1.md"
expect_contains "and states the word minimum" "$out" "150"

# MIN_WORDS is the caller's dial, both directions.
out="$( (cd "$RC" && MIN_WORDS=10 "$GATE" review-conceptual 2>&1) )"
expect_rc "a 40-word review passes when MIN_WORDS=10" 0 $?

words 160 > "$RC/docs/reviews/design/conceptual-1.md"
out="$( (cd "$RC" && MIN_WORDS=500 "$GATE" review-conceptual 2>&1) )"
expect_rc "a 160-word review fails when MIN_WORDS=500" 1 $?
expect_contains "and states the raised minimum" "$out" "500"

# <n> is any positive integer, not hardcoded to 1.
rm "$RC/docs/reviews/design/conceptual-1.md"
words 160 > "$RC/docs/reviews/design/conceptual-3.md"
out="$(run_gate "$RC" review-conceptual)"
expect_rc "conceptual-3.md alone satisfies review-conceptual" 0 $?

# ---------------- 5: review-tactical is its own artifact
# The conceptual review being on disk must not satisfy the tactical stage.
RD="$WORK/tactical"
seed_compliant "$RD"
rm "$RD/docs/reviews/design/tactical-1.md"
out="$(run_gate "$RD" review-tactical)"
expect_rc "review-tactical fails when only the conceptual review exists" 1 $?
expect_contains "and names the tactical path" "$out" \
  "docs/reviews/design/tactical"

words 40 > "$RD/docs/reviews/design/tactical-1.md"
out="$(run_gate "$RD" review-tactical)"
expect_rc "review-tactical fails on a thin tactical review" 1 $?
expect_contains "and states the word minimum" "$out" "150"

# ---------------- 6: plans — only a real, carved pseudocode plan counts
# Underscore-prefixed templates, oracle plans, and legacy-format plans are all
# excluded; a tree holding only those has not reached the plans stage.
RE="$WORK/plans"
seed_compliant "$RE"
rm "$RE/docs/plans/good-plan.md"
mkdir -p "$RE/docs/plans/oracle"

cat > "$RE/docs/plans/_TEMPLATE.pseudocode.md" <<'EOF'
---
slug: template
format: pseudocode
---
# Template — not a plan
EOF

cat > "$RE/docs/plans/oracle/decided.md" <<'EOF'
---
slug: decided
format: pseudocode
---
# Oracle plan — wrong path
EOF

cat > "$RE/docs/plans/legacy.md" <<'EOF'
---
slug: legacy
status: draft
---
# Legacy prose plan — no format line
EOF

out="$(run_gate "$RE" plans)"
expect_rc "plans fails when only template/oracle/legacy plans exist" 1 $?
expect_contains "and names the plans location" "$out" "docs/plans"

# One real pseudocode plan beside the decoys is enough.
cat > "$RE/docs/plans/carved.md" <<'EOF'
---
slug: carved
status: draft
format: pseudocode
---
# Carved plan
EOF
out="$(run_gate "$RE" plans)"
expect_rc "one real pseudocode plan satisfies the plans stage" 0 $?

# ---------------- 7: usage errors are their own exit code
# rc 2, not 1: a misspelled stage is a caller bug, not a missing artifact.
err="$(run_gate_err "$RA")"
rc=$?
expect_rc "no argument exits 2" 2 "$rc"
expect_contains "and prints usage on stderr" "${err,,}" "usage"

err="$(run_gate_err "$RA" review-conceptual-2)"
rc=$?
expect_rc "an unknown stage exits 2" 2 "$rc"
expect_contains "and prints usage on stderr" "${err,,}" "usage"

summary
