#!/usr/bin/env bash
#
# plan-metrics.sh — compute mechanical facts about a PR diff, for the reviewer.
#
# This script COMPUTES, it does not JUDGE. It emits numbers; the reviewer decides
# whether a deviation is justified. It ALWAYS exits 0 — an overrun is a question,
# never a build failure. (A missing plan IS a failure, but that is
# plan-resolve.sh's job, not this one.)
#
# Facts emitted:
#   - actual added lines per slice vs the slice's estimate, flagged past a
#     threshold
#   - new files added
#   - new dependencies added
#   - test-to-implementation added-line ratio
#
# Usage:  plan-metrics.sh [path/to/plan.md]
#   With no argument it reports the plan-independent facts only (used for
#   branches exempt from planning).
#
# Required env:
#   BASE_SHA, HEAD_SHA   commits bounding the PR diff (base...head)

set -euo pipefail

# A slice is flagged when actual > estimate * FACTOR, but never below FLOOR —
# without the floor a 4-line slice that lands at 13 would "overrun by 3x" and
# train the reviewer to ignore the signal.
FACTOR=3
FLOOR=80

PLAN="${1:-}"
ROOT="$(git rev-parse --show-toplevel)"
: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"

# Added lines in the diff, optionally restricted to the given paths.
added_lines() {
  if [[ $# -eq 0 ]]; then
    git -C "$ROOT" diff --numstat "${BASE_SHA}...${HEAD_SHA}" \
      | awk '{ s += $1 } END { print s + 0 }'
  else
    git -C "$ROOT" diff --numstat "${BASE_SHA}...${HEAD_SHA}" -- "$@" \
      | awk '{ s += $1 } END { print s + 0 }'
  fi
}

echo "===== MECHANICAL FACTS (computed by CI from the diff — trustworthy) ====="
echo

# ---------------------------------------------------------------- slice deltas
# The plan is read at BASE_SHA, not from the working tree. These numbers are
# handed to the reviewer as ground truth, so the estimates a diff is measured
# against must not be editable by that diff — otherwise an overrun is fixed by
# raising the estimate in the same commit. `plan-resolve.sh` has already
# guaranteed the plan exists at base; this reads that version of it.
if [[ -n "$PLAN" ]] && git -C "$ROOT" cat-file -e "${BASE_SHA}:${PLAN}" 2>/dev/null; then
  echo "Plan: $PLAN (as of the base commit)"
  echo
  printf '%-38s %10s %10s   %s\n' "SLICE" "ESTIMATE" "ACTUAL" "NOTE"

  # One record per slice: title, estimate, then the declared file paths joined
  # by '|'. Split with IFS rather than eval — the plan file is part of the diff
  # under review, so a PR could otherwise put shell metacharacters in a Files:
  # line and have this script run them.
  while IFS=$'\t' read -r title estimate files; do
    [[ -z "$title" ]] && continue
    if [[ -n "$files" ]]; then
      IFS='|' read -r -a slice_files <<< "$files"
      actual="$(added_lines "${slice_files[@]}")"
    else
      actual=0
    fi
    note=""
    if [[ -z "$estimate" || "$estimate" -eq 0 ]]; then
      note="no estimate declared"
      estimate="?"
    else
      threshold=$(( estimate * FACTOR ))
      [[ "$threshold" -lt "$FLOOR" ]] && threshold=$FLOOR
      if [[ "$actual" -gt "$threshold" ]]; then
        note="OVER — ${FACTOR}x estimate exceeded (>${threshold}); is the deviation justified?"
      fi
    fi
    [[ -z "$files" ]] && note="${note:+$note; }no files declared"
    printf '%-38s %10s %10s   %s\n' "${title:0:38}" "$estimate" "$actual" "$note"
  done < <(awk '
    /^## Slice/ {
      if (title != "") print title "\t" est "\t" files
      title = $0; sub(/^## +/, "", title)
      est = 0; files = ""
      next
    }
    /^- \*\*Estimate:\*\*/ {
      line = $0
      if (match(line, /[0-9]+/)) est = substr(line, RSTART, RLENGTH)
      next
    }
    /^- \*\*Files:\*\*/ {
      line = $0
      while (match(line, /`[^`]+`/)) {
        p = substr(line, RSTART + 1, RLENGTH - 2)
        # Skip the template placeholders (<path>) and anything with the join
        # delimiter in it.
        if (p !~ /[<>|]/) files = files (files == "" ? "" : "|") p
        line = substr(line, RSTART + RLENGTH)
      }
      next
    }
    END { if (title != "") print title "\t" est "\t" files }
  ' <(git -C "$ROOT" show "${BASE_SHA}:${PLAN}"))
else
  echo "Plan: none (branch exempt from planning) — no slice estimates to check."
fi

echo
echo "Total added lines: $(added_lines)"

# ------------------------------------------------------------------ new files
echo
NEW_FILES="$(git -C "$ROOT" diff --diff-filter=A --name-only "${BASE_SHA}...${HEAD_SHA}" || true)"
if [[ -n "$NEW_FILES" ]]; then
  echo "New files added ($(printf '%s\n' "$NEW_FILES" | wc -l | tr -d ' ')):"
  printf '%s\n' "$NEW_FILES" | sed 's/^/  /'
else
  echo "New files added: none"
fi

# --------------------------------------------------------------- dependencies
# The cheapest speculative-machinery detector there is: compare the declared
# dependency list before and after, rather than grepping the diff for '+'.
deps_at() {
  local ref="$1"
  {
    git -C "$ROOT" show "${ref}:pyproject.toml" 2>/dev/null | awk '
      /^(dependencies|dev) *= *\[/ { inarr = 1 }
      inarr {
        line = $0
        while (match(line, /"[^"]+"/)) {
          print substr(line, RSTART + 1, RLENGTH - 2)
          line = substr(line, RSTART + RLENGTH)
        }
        if (/\]/) inarr = 0
      }'
    git -C "$ROOT" show "${ref}:project.yml" 2>/dev/null | awk '
      /^packages:/ { inpkg = 1; next }
      inpkg && /^[^ ]/ { inpkg = 0 }
      inpkg && /^  [A-Za-z0-9_.-]+:/ { gsub(/[ :]/, ""); print }'
  } | sort -u
}
echo
ADDED_DEPS="$(comm -13 <(deps_at "$BASE_SHA") <(deps_at "$HEAD_SHA") || true)"
if [[ -n "$ADDED_DEPS" ]]; then
  echo "NEW DEPENDENCIES ($(printf '%s\n' "$ADDED_DEPS" | wc -l | tr -d ' ')):"
  printf '%s\n' "$ADDED_DEPS" | sed 's/^/  /'
  echo "  (AGENTS.md: no new dependencies without the owner's approval.)"
else
  echo "New dependencies: none"
fi

# ------------------------------------------------------------- test:impl ratio
echo
if [[ -f "$ROOT/pyproject.toml" ]]; then
  TEST_LINES="$(added_lines 'tests/')"; IMPL_LINES="$(added_lines 'src/')"
else
  TEST_LINES="$(added_lines 'Tests/')"; IMPL_LINES="$(added_lines 'Sources/')"
fi
if [[ "$IMPL_LINES" -gt 0 ]]; then
  echo "Test:implementation added lines: ${TEST_LINES}:${IMPL_LINES} \
($(awk -v t="$TEST_LINES" -v i="$IMPL_LINES" 'BEGIN { printf "%.2f", t / i }')x)"
elif [[ "$TEST_LINES" -gt 0 ]]; then
  echo "Test:implementation added lines: ${TEST_LINES}:0 (tests only, no implementation touched)"
else
  echo "Test:implementation added lines: no test or implementation files touched"
fi

echo
echo "===== END MECHANICAL FACTS ====="
exit 0
