#!/usr/bin/env bash
#
# test-the-tests.sh — the refusals around its OWN comparison.
#
# ESC-37. This repository's `self-test-the-tests` job reported PASS on every
# pull request while never running: it printed
#
#   test-the-tests: SKIP — this PR changes no files under template/
#
# on pull requests that changed template/ heavily. The mechanism is the shape
# this project keeps meeting. `changed()` ran `git diff` INSIDE a command
# substitution; a git failure there produces empty stdout, empty stdout was read
# as "nothing changed", "nothing changed" is a skip, and **a skip exits 0, which
# GitHub reports as a passing required check**. So the one check that makes a
# coder's tests worth anything reported green for a comparison that never
# happened — the exact defect it exists to catch, committed by itself.
#
# These tests pin the three ways the comparison can be wrong, and that none of
# them is allowed to look like a pass.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SCRIPT="$HERE/../template/.github/scripts/test-the-tests.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== test-the-tests.sh ==="

# A tiny repository with the two directories named explicitly, so nothing here
# depends on language detection.
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/impl" "$R/t"
echo "one" > "$R/impl/a.txt"
echo "check" > "$R/t/a.sh"
echo "unrelated" > "$R/readme.md"
git -C "$R" add -A && git -C "$R" commit -qm base
BASE="$(git -C "$R" rev-parse HEAD)"

run() { # run <BASE> <HEAD> [SUITE]
  ( cd "$R" && env \
      TEST_THE_TESTS_IMPL_DIR=impl \
      TEST_THE_TESTS_TEST_DIR=t \
      TEST_THE_TESTS_SUITE="${3:-false}" \
      BASE_SHA="$1" HEAD_SHA="$2" \
      bash "$SCRIPT" 2>&1 )
}

# ------------------------------------------------- the comparison is stated
echo "two" > "$R/impl/a.txt"
echo "check harder" > "$R/t/a.sh"
git -C "$R" add -A && git -C "$R" commit -qm work
HEAD="$(git -C "$R" rev-parse HEAD)"

out="$(run "$BASE" "$HEAD")"; rc=$?
expect_rc "a real change runs the check" 0 "$rc"
expect_contains "and the range it compared is printed" "$out" "comparing $BASE...$HEAD"
expect_contains "and it says the suite failed without the implementation" "$out" \
  "the suite fails without the implementation"

# ------------------------------------------------------ a git error is not a skip
out="$(run "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$HEAD")"; rc=$?
expect_rc "an unresolvable base refuses" 2 "$rc"
expect_contains "and says the comparison did not happen" "$out" \
  "Refusing to pass on a comparison that did not happen"
expect_not_contains "and never calls it a skip" "$out" "SKIP"

# ------------------------------------------ an empty total diff is not a skip
# The observed failure. A range that reports nothing at all cannot be right —
# a pull request that changes no file does not exist — so continuing would mean
# reporting green on a comparison of a commit with itself.
out="$(run "$HEAD" "$HEAD")"; rc=$?
expect_rc "a range with no changed files at all refuses" 2 "$rc"
expect_contains "and says the range is wrong" "$out" "reports NO changed files at all"
expect_not_contains "and never calls that a skip either" "$out" "SKIP"

# ------------------------------------------------- a genuine skip stays a skip
# Nothing under impl/ changed, but the pull request is real. That is the one
# case where skipping is honest — and it now has to show its work.
echo "typo" > "$R/readme.md"
echo "more checking" > "$R/t/a.sh"
git -C "$R" add -A && git -C "$R" commit -qm "docs and tests only"
HEAD2="$(git -C "$R" rev-parse HEAD)"
out="$(run "$HEAD" "$HEAD2")"; rc=$?
expect_rc "a pull request touching no implementation still skips" 0 "$rc"
expect_contains "and says which directory was empty" "$out" "no files under impl/"
expect_contains "and proves it looked, by counting what DID change" "$out" \
  "file(s) changed in total"

summary
