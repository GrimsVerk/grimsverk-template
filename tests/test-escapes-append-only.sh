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

# ------------------------------------------- the done-log, and its one extra rule
# docs/escapes.done.md exists because THIS check exists: an append-only ledger
# cannot be edited to mark something done, so "closed" lived only in prose no
# script reads and the log grew forever without converging. The backlog hit the
# same wall and got a done-log; this is the same answer.
#
# It carries one rule escapes.md does not need, and the rule is the whole reason
# the file is safe: a row here makes the delivery driver stop handing that
# escape to the oracle, so it must name a check somebody can open.
D="$WORK/donelog"
init_repo "$D"
mkdir -p "$D/docs" "$D/tests"
cat > "$D/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | the parser skipped ids it could not read | none existed | `tests/test-coverage.sh` |
| ESC-2 | 2026-08-16 | a check reported green by not running | CI | `tests/test-gates.sh` |
EOF
printf '# closed\n' > "$D/tests/test-coverage.sh"
printf '# closed\n' > "$D/tests/test-gates.sh"
git -C "$D" add -A && git -C "$D" commit -qm seed
BD="$(git -C "$D" rev-parse HEAD)"
rund() { ( cd "$D" && BASE_SHA="$BD" "$CHECK" 2>&1 ); }

# No done-log at all is the normal state of a young project.
expect_rc "no done-log is not a problem" 0 "$(rund >/dev/null; echo $?)"

donelog() { cat > "$D/docs/escapes.done.md" <<EOF
# Escapes — closed

| Id | Date | Check that closes it | How it was demonstrated |
| --- | --- | --- | --- |
$1
EOF
}

# A closure naming a check that exists.
donelog '| ESC-1 | 2026-08-17 | `tests/test-coverage.sh` | red against the unanchored rule, green after |'
out="$(rund)"
expect_rc "a closure naming a real path passes" 0 $?

# ...and the rule with teeth. A row that asserts the escape is fine, naming
# nothing, would make the oracle look away on the strength of prose.
donelog '| ESC-1 | 2026-08-17 | it is fine now | we checked |'
out="$(rund)"
expect_rc "a closure naming no check fails" 1 $?
expect_contains "and says why a closure has to cite something" "$out" "makes the delivery driver stop"

# Naming a path that is not there is the same failure wearing a plausible face,
# and it is the one a copy-pasted row produces.
donelog '| ESC-1 | 2026-08-17 | `tests/test-nothing-like-this.sh` | red then green |'
out="$(rund)"
expect_rc "a closure citing a path that does not exist fails" 1 $?
expect_contains "and names the path it could not find" "$out" "test-nothing-like-this.sh"

# The rule fires on a done-log CREATED by this pull request, which is exactly
# when a bogus first closure would appear.
rm -f "$D/docs/escapes.done.md"
donelog '| ESC-2 | 2026-08-17 | nothing in particular | trust me |'
expect_rc "the rule applies to a done-log the pull request creates" 1 "$(rund >/dev/null; echo $?)"

# And once landed, a closure is append-only like everything else — a closure
# rewritten to name a different check is a claim changing under a driver that
# already acted on it.
donelog '| ESC-1 | 2026-08-17 | `tests/test-coverage.sh` | red then green |'
git -C "$D" add -A && git -C "$D" commit -qm "Close ESC-1"
BD="$(git -C "$D" rev-parse HEAD)"
expect_rc "a landed closure passes untouched" 0 "$(rund >/dev/null; echo $?)"

donelog '| ESC-1 | 2026-08-17 | `tests/test-gates.sh` | red then green |'
out="$(rund)"
expect_rc "rewriting a landed closure fails" 1 $?
expect_contains "and names the done-log" "$out" "docs/escapes.done.md"

# Appending a second closure is the whole point and must stay free.
donelog '| ESC-1 | 2026-08-17 | `tests/test-coverage.sh` | red then green |
| ESC-2 | 2026-08-18 | `tests/test-gates.sh` | red against the skip, green after |'
expect_rc "appending another closure passes" 0 "$(rund >/dev/null; echo $?)"

# The shipped skeleton must not trip its own check on day one — the same
# property the escapes ledger buys with its `_ESC-<n>_` placeholder. In a FRESH
# fixture, because $D now has a landed closure and dropping it would (correctly)
# fail the append-only rule rather than tell us anything about the skeleton.
SK="$HERE/../template/docs/escapes.done.md.jinja"
if [[ -f "$SK" ]]; then
  F="$WORK/fresh"
  init_repo "$F"
  mkdir -p "$F/docs"
  printf '# Escapes\n\n| Id | Date | What | Gate | Check |\n| --- | --- | --- | --- | --- |\n' \
    > "$F/docs/escapes.md"
  git -C "$F" add -A && git -C "$F" commit -qm seed
  sed 's/{{ project_name }}/demo/' "$SK" > "$F/docs/escapes.done.md"
  out="$( cd "$F" && BASE_SHA="$(git -C "$F" rev-parse HEAD)" "$CHECK" 2>&1 )"
  expect_rc "the shipped done-log skeleton passes its own check" 0 $?
  expect_not_contains "and its placeholder id is not read as a closure" "$out" "names no check"
else
  no "the shipped done-log skeleton exists"
fi

summary
