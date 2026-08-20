#!/usr/bin/env bash
# Tests for .claude/scripts/sweep-branches.sh — the branch housekeeping two
# documents used to promise and nothing performed (ESC-78).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/lib.sh"

SWEEP="$HERE/../template/.claude/scripts/sweep-branches.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
ORIGIN="$WORK/origin.git"; R="$WORK/repo"

git init -q --bare "$ORIGIN"
git init -q "$R"
git -C "$R" config user.email t@e.i; git -C "$R" config user.name T
git -C "$R" config commit.gpgsign false
echo base > "$R/README.md"
git -C "$R" add -A && git -C "$R" commit -qm base
git -C "$R" branch -M main
git -C "$R" remote add origin "$ORIGIN"
git -C "$R" push -q -u origin main

# The lane base, one branch merged into it, one branch NOT merged, and a ledger.
git -C "$R" switch -qc run/local main
echo lane > "$R/lane.txt"; git -C "$R" add -A; git -C "$R" commit -qm lane
git -C "$R" push -q -u origin run/local

git -C "$R" switch -qc feat/done run/local
echo done > "$R/done.txt"; git -C "$R" add -A; git -C "$R" commit -qm done
git -C "$R" push -q -u origin feat/done

git -C "$R" switch -qc docs/run-20260820T000000Z--run-local run/local
echo evidence > "$R/ev.txt"; git -C "$R" add -A; git -C "$R" commit -qm evidence
git -C "$R" push -q -u origin docs/run-20260820T000000Z--run-local

git -C "$R" switch -qc chore/test-report-local main
echo ledger > "$R/ledger.md"; git -C "$R" add -A; git -C "$R" commit -qm ledger
git -C "$R" push -q -u origin chore/test-report-local

# feat/done merges into the lane; the evidence branch does not.
git -C "$R" switch -q run/local
git -C "$R" merge -q --no-ff -m "merge feat/done" feat/done
git -C "$R" push -q origin run/local
git -C "$R" switch -q main

# Copied in AFTER the branch setup: the fixture commits with `git add -A`, so a
# script sitting in the tree earlier would ride into those commits and vanish
# on the next switch.
mkdir -p "$R/.claude/scripts"; cp "$SWEEP" "$R/.claude/scripts/"
sweep() { ( cd "$R" && bash .claude/scripts/sweep-branches.sh "$@" 2>&1 ); }

out="$(sweep --base run/local --dry-run)"
expect_rc "a dry run reports without deleting" 0 $?
expect_contains "and names the merged branch it would delete" "$out" "would delete feat/done"
expect_not_contains "and never the unmerged evidence branch" "$out" "would delete docs/run-"
if git -C "$R" ls-remote --exit-code --heads origin feat/done >/dev/null 2>&1; then
  ok "a dry run deletes nothing"
else no "a dry run deletes nothing" "feat/done is gone"; fi

out="$(sweep --base run/local)"
expect_rc "the sweep succeeds" 0 $?
expect_contains "and says what it did" "$out" "1 merged branch(es) deleted"
if git -C "$R" ls-remote --exit-code --heads origin feat/done >/dev/null 2>&1; then
  no "the merged branch is deleted" "feat/done is still on the remote"
else ok "the merged branch is deleted"; fi

# THE TWO IT MUST NEVER TOUCH, and the one it must never guess about.
for keep in run/local main chore/test-report-local docs/run-20260820T000000Z--run-local; do
  if git -C "$R" ls-remote --exit-code --heads origin "$keep" >/dev/null 2>&1; then
    ok "$keep survives the sweep"
  else no "$keep survives the sweep" "it was deleted"; fi
done
expect_contains "the unmerged branch is named, not removed" "$out" \
  "left alone (not merged into run/local)"

# A base that does not exist is a refusal, not a silent no-op: sweeping against
# the wrong base would call every branch unmerged and delete nothing, which
# looks exactly like a clean repository.
out="$(sweep --base run/nope)"
expect_rc "an unknown base refuses" 2 $?
expect_contains "and says so" "$out" "does not exist"

summary
