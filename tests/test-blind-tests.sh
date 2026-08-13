#!/usr/bin/env bash
#
# blind-tests.sh — fixture tests.
#
# The property under test: a test written blind and then edited later in the
# same pull request must be visible to the reviewer, naming the commit that
# edited it. That is the only signal distinguishing a test that was always
# correct from one relaxed at assembly to match the implementation.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SCRIPT="$HERE/../template/.github/scripts/blind-tests.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== blind-tests.sh ==="

# A minimal python-shaped repo: the script detects tests/ from pyproject.toml.
setup() {
  local d="$WORK/$1"
  init_repo "$d"
  mkdir -p "$d/tests" "$d/src"
  touch "$d/pyproject.toml"
  git -C "$d" add -A
  git -C "$d" commit -qm "base"
  git -C "$d" rev-parse HEAD
}

run() { # run <repo> <base>
  BASE_SHA="$2" HEAD_SHA="$(git -C "$1" rev-parse HEAD)" \
    bash -c "cd '$1' && '$SCRIPT'" 2>&1
}

# ------------------------------------------- blind tests, never touched after
D="$WORK/clean"; BASE="$(setup clean)"
echo "def test_a(): assert compute() == 3" > "$D/tests/test_a.py"
git -C "$D" add -A
git -C "$D" commit -qm "Add tests for slice 1

Blind-Tests: draft-saving-1"
echo "def compute(): return 3" > "$D/src/a.py"
git -C "$D" add -A && git -C "$D" commit -qm "Implement slice 1"
out="$(run "$D" "$BASE")"
expect_rc "exits 0 (computes, does not judge)" 0 $?
expect_contains "counts the blind commit" "$out" "Blind test-authoring commits: 1"
expect_contains "names the slice" "$out" "draft-saving-1"
expect_contains "reports the file unmodified" "$out" "unmodified since it was written blind"
expect_not_contains "does not flag a modification" "$out" "MODIFIED AFTER BLIND AUTHORSHIP"

# ------------------------------------------------ test edited after authoring
D="$WORK/weakened"; BASE="$(setup weakened)"
echo "def test_a(): assert compute() == 3" > "$D/tests/test_a.py"
git -C "$D" add -A
git -C "$D" commit -qm "Add tests for slice 1

Blind-Tests: draft-saving-1"
echo "def compute(): return 4" > "$D/src/a.py"
git -C "$D" add -A && git -C "$D" commit -qm "Implement slice 1"
# The forbidden resolution: relax the test until the implementation passes.
echo "def test_a(): assert compute() is not None" > "$D/tests/test_a.py"
git -C "$D" add -A && git -C "$D" commit -qm "Loosen the assertion"
out="$(run "$D" "$BASE")"
expect_rc "still exits 0" 0 $?
expect_contains "flags the modified test" "$out" "MODIFIED AFTER BLIND AUTHORSHIP"
expect_contains "names the file" "$out" "tests/test_a.py"
expect_contains "names the later commit" "$out" "Loosen the assertion"
expect_contains "explains the forbidden case" "$out" "FORBIDDEN"

# -------------------------------------------------------- no trailer anywhere
D="$WORK/notrailer"; BASE="$(setup notrailer)"
echo "def test_a(): assert True" > "$D/tests/test_a.py"
echo "def compute(): return 3" > "$D/src/a.py"
git -C "$D" add -A && git -C "$D" commit -qm "Add code and tests together"
out="$(run "$D" "$BASE")"
expect_rc "exits 0 with no trailers" 0 $?
expect_contains "says no blind commits" "$out" "No commits in this pull request carry"
expect_contains "flags it for orchestrated work" "$out" "should have a test-writer commit"

# ------------------------------------- test-writer commit that wrote no tests
D="$WORK/notests"; BASE="$(setup notests)"
echo "notes" > "$D/scratch.txt"
git -C "$D" add -A
git -C "$D" commit -qm "Test-writer ran but wrote nothing

Blind-Tests: draft-saving-2"
out="$(run "$D" "$BASE")"
expect_contains "flags a test-writer that wrote no tests" "$out" "wrote no tests"

# --------------------------------------------- non-python, non-swift project
D="$WORK/unknown"; init_repo "$D"
echo x > "$D/readme"; git -C "$D" add -A; git -C "$D" commit -qm base
BASE="$(git -C "$D" rev-parse HEAD)"
echo y > "$D/other"; git -C "$D" add -A; git -C "$D" commit -qm more
out="$(run "$D" "$BASE")"
expect_rc "degrades cleanly on an unknown layout" 0 $?
expect_contains "says why it cannot tell" "$out" "Cannot tell tests from implementation"

summary
