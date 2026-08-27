#!/usr/bin/env bash
#
# Shared helpers for the template's own tests.
#
# These tests exist because the template ships SEVEN bash scripts that gate
# other people's pull requests, and until now nothing ran any of them before a
# user's first PR did. A gate nobody tests is a gate that fails open quietly,
# which is the exact failure this template spends its whole design budget trying
# to prevent elsewhere.

PASS=0
FAIL=0

# ok <description> — record a passing assertion.
ok() { echo "  PASS  $1"; PASS=$((PASS + 1)); }

# no <description> [detail...] — record a failing assertion.
no() {
  echo "  FAIL  $1"
  shift
  [[ $# -gt 0 ]] && printf '        %s\n' "$@"
  FAIL=$((FAIL + 1))
}

# expect_rc <description> <expected> <actual>
expect_rc() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1" "expected rc=$2, got rc=$3"; fi
}

# expect_contains <description> <haystack> <needle>
expect_contains() {
  if [[ "$2" == *"$3"* ]]; then ok "$1"
  else no "$1" "expected to find: $3" "in: $(printf '%s' "$2" | head -c 400)"; fi
}

# expect_not_contains <description> <haystack> <needle>
expect_not_contains() {
  if [[ "$2" != *"$3"* ]]; then ok "$1"
  else no "$1" "did not expect to find: $3"; fi
}

# summary — print totals and set the exit status for the suite.
summary() {
  echo
  echo "-------------------------------"
  echo "PASS: $PASS   FAIL: $FAIL"
  [[ "$FAIL" -eq 0 ]]
}

# A git repo with deterministic identity, so commits are reproducible and the
# tests do not depend on the runner's global git config.
init_repo() {
  git init -q -b main "$1"
  git -C "$1" config user.email "tests@example.invalid"
  git -C "$1" config user.name "Template Tests"
  git -C "$1" config commit.gpgsign false
  # No detached background gc in a fixture, ever: an auto-gc kicked off by a
  # driver's fetch or merge keeps running after the scenario moves on, and a
  # later clone or push racing it dies mid-copy on a pruned object. Observed
  # on CI as unrelated-looking one-off failures; a test repo has nothing gc
  # buys it.
  git -C "$1" config gc.auto 0
  git -C "$1" config gc.autoDetach false
}
