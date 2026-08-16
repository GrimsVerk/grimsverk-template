#!/usr/bin/env bash
#
# escapes-append-only.sh — fixture tests.
#
# The distinction under test is the one the check exists for: a CORRECTION (an
# appended row repeating an id — the ledger's own documented lifecycle) passes,
# while a REWRITE (a landed row edited, removed, or moved) fails. ESC-15 logged
# that the oracle ledger had this enforcement and the escape ledger did not,
# despite both being evidence sources the oracle cites by id.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/escapes-append-only.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== escapes-append-only.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs"

cat > "$R/docs/escapes.md" <<'EOF'
# Escapes

Prose header, which the check deliberately does not protect.

| Id | Date | What escaped | Which gate should have caught it | Check added |
| --- | --- | --- | --- | --- |
| _ESC-<n>_ | _YYYY-MM-DD_ | _placeholder_ | _none_ | _pending_ |
| ESC-1 | 2026-08-01 | first thing | CI | unverified — pending: a check |
| ESC-2 | 2026-08-02 | second thing | review | the check exists |
EOF
git -C "$R" add -A && git -C "$R" commit -qm "ledger with two entries"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { (cd "$R" && BASE_SHA="$BASE" "$CHECK" 2>&1); }

# ------------------------------------------------------------- allowed shapes
out="$(run)"; expect_rc "an untouched ledger passes" 0 $?
expect_contains "and counts its rows" "$out" "2 landed row(s)"

echo "| ESC-3 | 2026-08-03 | third thing | plan | unverified — pending: x |" >> "$R/docs/escapes.md"
run >/dev/null; expect_rc "a pure append passes" 0 $?

echo "| ESC-1 | 2026-08-04 | correction: the check landed | CI | demonstrated in tests/x.sh |" >> "$R/docs/escapes.md"
run >/dev/null
expect_rc "a correction row repeating a landed id passes — it is an append" 0 $?

git -C "$R" checkout -q -- docs/escapes.md

# ------------------------------------------------------------ rewrite shapes
sed -i 's/first thing/first thing, reworded/' "$R/docs/escapes.md"
out="$(run)"; expect_rc "editing a landed row fails" 1 $?
expect_contains "and names the row" "$out" "modified or removed"
git -C "$R" checkout -q -- docs/escapes.md

sed -i '/ESC-1/d' "$R/docs/escapes.md"
run >/dev/null; expect_rc "deleting a landed row fails" 1 $?
git -C "$R" checkout -q -- docs/escapes.md

# Swap the two entry rows: same bytes, different order.
awk '/^\| ESC-1 /{a=$0; next} /^\| ESC-2 /{print; print a; next} {print}' \
  "$R/docs/escapes.md" > "$R/docs/escapes.md.tmp" \
  && mv "$R/docs/escapes.md.tmp" "$R/docs/escapes.md"
out="$(run)"; expect_rc "reordering landed rows fails" 1 $?
expect_contains "and says so" "$out" "reordered"
git -C "$R" checkout -q -- docs/escapes.md

rm "$R/docs/escapes.md"
out="$(run)"; expect_rc "deleting the ledger fails" 1 $?
expect_contains "and says it is cited by id" "$out" "cited by id"
git -C "$R" checkout -q -- docs/escapes.md

# The prose is template-maintained and NOT protected — a template update must
# be able to reword it without fighting this check.
sed -i 's/Prose header/Reworded prose header/' "$R/docs/escapes.md"
run >/dev/null; expect_rc "editing the prose passes" 0 $?
git -C "$R" checkout -q -- docs/escapes.md

# --------------------------------------------------------------- empty bases
# A fresh project: the ledger holds only the placeholder row, whose id is
# spelled _ESC-<n>_ precisely so it is not an entry.
git -C "$R" rm -q docs/escapes.md   # also removes the now-empty docs/
mkdir -p "$R/docs"
cat > "$R/docs/escapes.md" <<'EOF'
| Id | Date | What escaped | Which gate should have caught it | Check added |
| --- | --- | --- | --- | --- |
| _ESC-<n>_ | _YYYY-MM-DD_ | _placeholder_ | _none_ | _pending_ |
EOF
git -C "$R" add -A && git -C "$R" commit -qm "skeleton only"
BASE="$(git -C "$R" rev-parse HEAD)"
out="$(run)"; expect_rc "a skeleton-only ledger has nothing to protect" 0 $?
expect_contains "and says so" "$out" "nothing to protect"

# No ledger at the base commit at all: everything at HEAD is new.
git -C "$R" rm -q docs/escapes.md && git -C "$R" commit -qm "no ledger"
BASE="$(git -C "$R" rev-parse HEAD)"
mkdir -p "$R/docs"
echo "| ESC-1 | 2026-08-05 | new project first escape | CI | pending |" > "$R/docs/escapes.md"
run >/dev/null; expect_rc "no ledger at base passes" 0 $?

summary
