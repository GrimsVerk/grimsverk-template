#!/usr/bin/env bash
#
# escape-refs.sh — fixture tests.
#
# The defect this gate exists for: a gated document claimed "logged in
# docs/escapes.md" while the entry sat unmerged in another pull request, so the
# claim was false at the base commit — the only commit the review gate reads —
# and the same pull request blocked twice. Prose claims could never be resolved
# mechanically (that check was recorded unverified-and-not-built for exactly
# that reason); rigid ESC-<n> ids are what make the resolution a dumb string
# match that is safe to fail closed on.
#
# Both halves are pinned here: a citation to a merged entry resolves, a
# citation to an unmerged or mistyped one fails and names the file and the id —
# and ordinary prose that merely looks id-adjacent (lint codes like E501) is
# never mistaken for a citation.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

REFS="$HERE/../template/.github/scripts/escape-refs.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== escape-refs.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans"

cat > "$R/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Which gate should have caught it | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-14 | a thing went wrong | none existed | a check now exists |
EOF
cat > "$R/AGENTS.md" <<'EOF'
# Rules
No citations yet. Prose may mention ruff's E501 rule without consequence.
EOF
git -C "$R" add -A && git -C "$R" commit -qm "seed"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { ( cd "$R" && BASE_SHA="$BASE" "$REFS" 2>&1 ); }

# ------------------------------------------------ no citations at all -> pass
out="$(run)"
expect_rc "a tree with no citations passes" 0 $?
expect_contains "reports zero citations" "$out" "0 citation(s)"

# --------------------------- lint codes are not citations (the E501 problem)
# The whole reason the ids are ESC-<n> rather than bare E<n>: a Python project
# legitimately writes E501 in its gated documents, and a false positive on a
# fail-closed gate is worse than no gate.
expect_not_contains "E501 in prose is not a citation" "$out" "E501"

# ----------------------------------- a citation to a merged entry -> resolves
cat > "$R/docs/plans/thing.md" <<'EOF'
---
slug: thing
---
# Thing — Plan
This plan exists because of ESC-1.
## Slice 1 — thing
- **Files:** `src/thing.py`
- **Estimate:** ~10 lines
EOF
git -C "$R" add -A && git -C "$R" commit -qm "Add a plan citing ESC-1"
out="$(run)"
expect_rc "a citation to an entry at base resolves" 0 $?
expect_contains "counts the citation" "$out" "1 citation(s)"

# -------------------------------------- a dangling citation -> hard failure
echo "See ESC-99 for why." >> "$R/AGENTS.md"
git -C "$R" add -A && git -C "$R" commit -qm "Cite an entry that does not exist"
out="$(run)"
expect_rc "a citation to a missing entry fails" 1 $?
expect_contains "names the file and the id" "$out" "AGENTS.md cites ESC-99"
expect_contains "explains the backward-only rule" "$out" "only once that entry exists"
expect_contains "says a stub is enough" "$out" "stub"
git -C "$R" reset -q --hard HEAD~1

# ------------------- an entry and its citation in the SAME change -> failure
# The backward-only rule itself: the entry is in the working tree but not at
# base, which is exactly the state that blocked a pull request twice downstream.
echo "| ESC-2 | 2026-08-14 | another thing | none existed | unverified — pending: a fixture |" >> "$R/docs/escapes.md"
echo "Fixed per ESC-2." >> "$R/AGENTS.md"
git -C "$R" add -A && git -C "$R" commit -qm "Entry and citation together"
out="$(run)"
expect_rc "citing an entry added in the same change fails" 1 $?
expect_contains "the dangling id is the new one" "$out" "AGENTS.md cites ESC-2"

# --------------------------- the ledger itself is not scanned for citations
# The new ESC-2 ROW must not be what fails: a row defines its id, it does not
# cite it. Strip the citation, keep the row — the stub-first pull request.
git -C "$R" reset -q --hard HEAD~1
echo "| ESC-2 | 2026-08-14 | another thing | none existed | unverified — pending: a fixture |" >> "$R/docs/escapes.md"
git -C "$R" add -A && git -C "$R" commit -qm "Add a stub entry only"
out="$(run)"
expect_rc "a stub-only change passes (the ledger is not scanned)" 0 $?

# ---------------------- once the stub is at base, the citation resolves
BASE="$(git -C "$R" rev-parse HEAD)"
echo "Fixed per ESC-2." >> "$R/AGENTS.md"
git -C "$R" add -A && git -C "$R" commit -qm "Cite the now-landed stub"
out="$(run)"
expect_rc "the same citation passes once the entry is at base" 0 $?

# ------------------------------- underscore-prefixed plan files are skipped
cat > "$R/docs/plans/_TEMPLATE.md" <<'EOF'
# Skeleton — cite entries like ESC-999 here, says nobody; placeholders only.
EOF
git -C "$R" add -A && git -C "$R" commit -qm "Add a skeleton with a fake id"
out="$(run)"
expect_rc "an underscore-prefixed skeleton is not scanned" 0 $?
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------ no ledger at base, citation -> failure
R2="$WORK/fresh"
init_repo "$R2"
echo "seed" > "$R2/README.md"
git -C "$R2" add -A && git -C "$R2" commit -qm "seed"
B2="$(git -C "$R2" rev-parse HEAD)"
mkdir -p "$R2/docs"
echo "Justified by ESC-1." > "$R2/AGENTS.md"
git -C "$R2" add -A && git -C "$R2" commit -qm "Cite with no ledger anywhere"
out="$( cd "$R2" && BASE_SHA="$B2" "$REFS" 2>&1 )"
expect_rc "a citation with no ledger at base fails" 1 $?
expect_contains "still names the citation" "$out" "AGENTS.md cites ESC-1"

summary
