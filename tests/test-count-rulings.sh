#!/usr/bin/env bash
#
# test-count-rulings.sh — count-rulings.sh reports how many oracle decisions
# this run added. Written blind from the slice's Delivers and Signatures; no
# implementation was visible when this was written.
#
# The run report ends with one line, `oracle-rulings: <n>`, where n is the
# count of `^## OD-<n>` headings in docs/DESIGN.oracle.md in the working tree
# minus the count in that file at <base-ref>, clamped to zero. A document
# absent on either side counts as zero on that side and is not an error: the
# only non-zero exit is 2, for a missing <base-ref> argument.
#
# Recipe: real repos with real base commits, and every case is one named
# state of docs/DESIGN.oracle.md relative to a base ref.

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

SCRIPT="$ROOT/template/.claude/scripts/count-rulings.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== count-rulings.sh — rulings added since a base ref ==="

# expect_line <description> <actual> <expected-exact-stdout>
# The contract is "exactly one line on stdout", so equality — not substring —
# is the assertion: it rules out extra lines, prefixes, and negative counts.
expect_line() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1" "expected stdout: $3" "got: $2"; fi
}

# ---------------------------------------------------------------- repo A
# The document exists at base with one ruling; the working tree moves on
# from there, case by case.
RA="$WORK/rulings"
init_repo "$RA"
mkdir -p "$RA/docs"

cat > "$RA/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

Append-only. Every decision cites evidence that already landed.

## OD-1 — excerpts are capped, not truncated

The evidence run showed truncation losing the one line that mattered.
EOF
git -C "$RA" add -A && git -C "$RA" commit -qm "seed one ruling"
BASE_1="$(git -C "$RA" rev-parse HEAD)"

run_a() { ( cd "$RA" && "$SCRIPT" "$@" 2>/dev/null ); }

# ---------------- 1: two decisions added since base counts 2
cat >> "$RA/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — the reviewer verdict is a heading, not a sentence

Sentences drifted; headings did not.

## OD-3 — run reports are append-only

An edited report is a report that never happened.
EOF
out="$(run_a "$BASE_1")"
rc=$?
expect_rc "two added rulings exit 0" 0 "$rc"
expect_line "and print oracle-rulings: 2" "$out" "oracle-rulings: 2"

# The two rulings land; every case below is measured against this base.
git -C "$RA" add -A && git -C "$RA" commit -qm "add OD-2 and OD-3"
BASE_2="$(git -C "$RA" rev-parse HEAD)"

# ---------------- 2: no change since base counts 0
out="$(run_a "$BASE_2")"
rc=$?
expect_rc "an unchanged document exits 0" 0 "$rc"
expect_line "and prints oracle-rulings: 0" "$out" "oracle-rulings: 0"

# ---------------- 3: only ^## OD-<n> headings count
# A deeper heading, a mid-line mention, and an indented heading are all prose
# to this counter — none starts a decision.
cat >> "$RA/docs/DESIGN.oracle.md" <<'EOF'

### OD-5 — a subsection under an existing ruling, not a new one

This paragraph mentions OD-5 mid-line, and even writes ## OD-7 mid-line,
neither of which is a decision heading.

  ## OD-8 — indented, so not a heading at all
EOF
out="$(run_a "$BASE_2")"
rc=$?
expect_rc "decoy OD mentions exit 0" 0 "$rc"
expect_line "and none of them counts as a ruling" "$out" "oracle-rulings: 0"
git -C "$RA" checkout -q -- docs/DESIGN.oracle.md

# ---------------- 4: rulings removed since base clamp to 0
# The counter reports what this run added; a shrunken ledger is somebody
# else's alarm, and a negative number would be nonsense in run.md.
cat > "$RA/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — excerpts are capped, not truncated

The evidence run showed truncation losing the one line that mattered.
EOF
out="$(run_a "$BASE_2")"
rc=$?
expect_rc "a document with fewer rulings than base exits 0" 0 "$rc"
expect_line "and clamps to zero instead of going negative" "$out" "oracle-rulings: 0"
git -C "$RA" checkout -q -- docs/DESIGN.oracle.md

# ---------------- 5: document deleted since base is zero, not an error
rm "$RA/docs/DESIGN.oracle.md"
out="$(run_a "$BASE_2")"
rc=$?
expect_rc "a document absent at HEAD exits 0" 0 "$rc"
expect_line "and counts zero on the absent side" "$out" "oracle-rulings: 0"
git -C "$RA" checkout -q -- docs/DESIGN.oracle.md

# ---------------------------------------------------------------- repo B
# No document at base: the run that writes the first ruling still reports.
RB="$WORK/first-rulings"
init_repo "$RB"
echo "# a project with no oracle ledger yet" > "$RB/README.md"
git -C "$RB" add -A && git -C "$RB" commit -qm "seed without the document"
BASE_B="$(git -C "$RB" rev-parse HEAD)"

run_b() { ( cd "$RB" && "$SCRIPT" "$@" 2>/dev/null ); }

# ---------------- 6: absent on both sides is zero and exits 0
out="$(run_b "$BASE_B")"
rc=$?
expect_rc "a document absent on both sides exits 0" 0 "$rc"
expect_line "and prints oracle-rulings: 0" "$out" "oracle-rulings: 0"

# ---------------- 7: absent at base, three rulings at head counts 3
mkdir -p "$RB/docs"
cat > "$RB/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — the ledger exists

## OD-2 — decisions cite evidence

## OD-3 — the ledger is append-only
EOF
out="$(run_b "$BASE_B")"
rc=$?
expect_rc "a document born since base exits 0" 0 "$rc"
expect_line "and all three new rulings count" "$out" "oracle-rulings: 3"

# ---------------- 8: no argument exits 2 with usage on stderr
out="$( ( cd "$RB" && "$SCRIPT" 2>/dev/null ) )"
err="$( ( cd "$RB" && "$SCRIPT" 2>&1 >/dev/null ) )"
rc=$?
expect_rc "a missing base-ref exits 2" 2 "$rc"
expect_contains "and puts usage on stderr" "${err,,}" "usage"
expect_not_contains "and prints no count line on stdout" "$out" "oracle-rulings:"

summary
