#!/usr/bin/env bash
#
# lint-workflows.sh — fixture tests, plus the shape assertions that hold even
# where actionlint is not installed.
#
# ESC-36: `auto-merge.yml` referenced the `secrets` context inside a step `if:`.
# That context is not available in ANY `if:` — not job level, not step level —
# and the result is not a skipped step. The FILE fails validation: the run is
# created with zero jobs, and arming, branch deletion and the nightly sweep all
# die together. It shipped in three releases.
#
# Nothing here could have caught it. `auto-merge.yml` is the one shipped
# workflow the template never runs on itself, and the check it breaks is
# reported BY the broken workflow — so its disappearance reads as "not
# applicable" rather than "the file is dead", and a required-checks list cannot
# notice a check that never reports.
#
# The assertions split in two on purpose:
#
#   - the SHAPE ones run everywhere, including a machine with no actionlint and
#     no copier, because the specific line that broke is worth pinning by name;
#   - the REAL lint runs when actionlint is present, and is the general check.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

ROOT="$HERE/.."
SCRIPT="$ROOT/scripts/lint-workflows.sh"
WF="$ROOT/template/.github/workflows/{% if auto_merge %}auto-merge.yml{% endif %}"

echo "=== lint-workflows.sh ==="

# ------------------------------------------------------------ the shape
if [[ -f "$WF" ]]; then ok "the auto-merge workflow ships"
else no "the auto-merge workflow ships" "$WF"; fi

# The exact defect, by name. Any `if:` mentioning `secrets` kills the file.
if grep -nE '^[[:space:]]*if:.*secrets\.' "$WF" >/dev/null 2>&1; then
  no "no if: reads the secrets context" "$(grep -nE '^[[:space:]]*if:.*secrets\.' "$WF")"
else
  ok "no if: reads the secrets context"
fi

# ...and the replacement is present rather than the condition simply deleted,
# which would arm the mint step in every repository that has no App configured.
if grep -qE '^[[:space:]]*APP_ID: \$\{\{ secrets\.APP_ID \}\}' "$WF"
then ok "the id is hoisted into env, where secrets are allowed"
else no "the id is hoisted into env, where secrets are allowed"; fi
if grep -qE "^[[:space:]]*if: env\.APP_ID != ''" "$WF"
then ok "and the step tests the hoisted copy, where env is available"
else no "and the step tests the hoisted copy, where env is available"; fi

# The comment that used to sit there stated a wrong rule confidently, which is
# how the line survived review: it read as a deliberate workaround. Its return
# would restore the misinformation without restoring the bug, so it is pinned
# separately from the code.
if grep -q "not available in job-level" "$WF"
then no "the wrong explanation is gone" "it claimed step-level if: can read secrets"
else ok "the wrong explanation is gone"; fi

# Every OTHER workflow, shipped or self-hosted, on the same rule.
found=0
while IFS= read -r f; do
  found=$((found + 1))
  if grep -nE '^[[:space:]]*if:.*secrets\.' "$f" >/dev/null 2>&1; then
    no "no if: reads secrets in $(basename "$f")" "$(grep -nE '^[[:space:]]*if:.*secrets\.' "$f")"
  fi
done < <(find "$ROOT/.github/workflows" "$ROOT/template/.github/workflows" -type f 2>/dev/null | sort)
if [[ "$found" -gt 0 ]]; then ok "swept $found workflow file(s) for the same defect"
else no "swept the workflow files for the same defect" "found none, which cannot be right"; fi

# ---------------------------------------------------------- the refusals
# A SKIP EXITS 0, and GitHub reports a required check that exited 0 as PASSING.
# This project has been bitten by that shape repeatedly (ESC-2, and the
# test-the-tests directory overrides), so the linter refuses instead.
out="$(ACTIONLINT=/nonexistent-actionlint bash "$SCRIPT" 2>&1)"; rc=$?
expect_rc "a missing actionlint refuses rather than passing" 2 "$rc"
expect_contains "and says so" "$out" "Refusing to pass by skipping"

if ! command -v copier >/dev/null; then
  out="$(bash "$SCRIPT" 2>&1)"; rc=$?
  expect_rc "a missing copier refuses too" 2 "$rc"
fi

# -------------------------------------------------------------- the real thing
if command -v "${ACTIONLINT:-actionlint}" >/dev/null && command -v copier >/dev/null; then
  out="$(bash "$SCRIPT" 2>&1)"; rc=$?
  expect_rc "every shipped and self-hosted workflow lints clean" 0 "$rc"
  # actionlint exits 0 when its directory scan finds nothing, so a green result
  # only means something if files were actually read. The count is the proof.
  expect_contains "and the count of files read is reported" "$out" "workflow file(s)"
  expect_contains "including a rendered project's auto-merge" "$out" \
    "python/.github/workflows/auto-merge.yml"
  expect_contains "and the rendered ci.yml, whose Jinja only resolves here" "$out" \
    "python/.github/workflows/ci.yml"
else
  echo "  NOTE  actionlint or copier not on PATH; the shape assertions above"
  echo "        still ran. Set ACTIONLINT=/path/to/actionlint to run the linter."
fi

summary
