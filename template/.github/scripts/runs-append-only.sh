#!/usr/bin/env bash
#
# runs-append-only.sh — landed run evidence is never rewritten (ESC-223).
#
# Four days after the 2026-08-20 experiment, a cleanup commit edited three of
# its run reports IN PLACE — so anyone reading the branch tip silently got
# post-hoc text where primary evidence used to be, and only a pinned SHA
# could tell them. Run evidence is what every later analysis stands on; a
# record that can be quietly reworded is not a record. Same discipline as
# every other ledger here, at file granularity: a file landed under
# docs/runs/ is immutable — corrections are NEW files that cite the old.
#
# Usage (same contract as the other base-commit gates):
#     BASE_SHA=<sha> runs-append-only.sh
#
# Optional env: RUNS_DIR (default docs/runs)
#
# Exit 0: nothing landed was touched. Exit 1: a landed file was modified or
# deleted, named. Adding new files always passes — that is the append.

set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
: "${BASE_SHA:?BASE_SHA is required (the PR base commit)}"
RUNS_DIR="${RUNS_DIR:-docs/runs}"

FAILED=0
fail() { echo "runs-append-only: $*" >&2; FAILED=1; }

# Every file under the runs directory at the base commit, with its blob hash —
# the comparison GitHub itself would make, immune to timestamps and touch.
while IFS=$'\t' read -r base_hash path; do
  [[ -n "$path" ]] || continue
  if [[ ! -f "$ROOT/$path" ]]; then
    fail "$path was DELETED — run evidence is append-only; a wrong record is corrected by a new file citing it, never by removing it"
    continue
  fi
  head_hash="$(git -C "$ROOT" hash-object -- "$ROOT/$path")"
  if [[ "$head_hash" != "$base_hash" ]]; then
    fail "$path was MODIFIED — run evidence is append-only; a branch-tip reader must never silently get post-hoc text where primary evidence used to be. Correct it with a NEW file that cites this one"
  fi
done < <(git -C "$ROOT" ls-tree -r "$BASE_SHA" -- "$RUNS_DIR" 2>/dev/null \
          | awk -F'\t' '{split($1, meta, " "); print meta[3] "\t" $2}')

if [[ "$FAILED" -eq 0 ]]; then
  count="$(git -C "$ROOT" ls-tree -r "$BASE_SHA" -- "$RUNS_DIR" 2>/dev/null | wc -l | tr -d ' ')"
  echo "runs-append-only: $count landed evidence file(s) intact at ${BASE_SHA:0:12}."
fi
exit "$FAILED"
