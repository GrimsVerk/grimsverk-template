#!/usr/bin/env bash
#
# escapes-append-only.sh — the escape ledger is append-only, mechanically.
#
# docs/escapes.md has said "never rewrite an entry" since the day it existed,
# and docs/DESIGN.oracle.md gets the same promise ENFORCED by
# oracle-decisions.sh. The asymmetry was the gap (ESC-15): the escape ledger is
# the oracle's other evidence source, and an agent editing an inconvenient row
# — its own escape, say — would change what a landed decision's citation means,
# with a diff that reads as an edit rather than as history being rewritten.
# This is the same check over the other file.
#
# THE RULE: every entry row present at the base commit appears byte-identical
# at HEAD, in the same relative order. New rows may be appended anywhere below;
# nothing already landed moves or changes. A correction is an APPENDED row that
# repeats the id — the lifecycle the ledger has always documented (a stub lands
# first, the demonstrated check appends later under the same id) — so
# corrections pass and rewrites fail, which is exactly the distinction wanted.
#
# An "entry row" is a table line carrying a real id: `^\|` and `ESC-<digits>`.
# The skeleton's placeholder row spells its id `_ESC-<n>_` precisely so it is
# not one — and so the check never fires on a fresh project.
#
# The surrounding prose is NOT protected. It is template-maintained text,
# updated by `copier update`, and freezing it would make every template release
# conflict with this check. The record is the rows.
#
# Required env:
#   BASE_SHA   the PR's base commit — the ledger there is the protected state
# Optional env:
#   LEDGER     default: docs/escapes.md

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
: "${BASE_SHA:?BASE_SHA is required (the PR base commit)}"
LEDGER="${LEDGER:-docs/escapes.md}"

# The ledger as the base commit has it. Absent there means everything at HEAD
# is new, which is the correct reading for a file that did not exist yet.
BASE_CONTENT="$(git -C "$ROOT" show "${BASE_SHA}:${LEDGER}" 2>/dev/null || true)"
if [[ -z "$BASE_CONTENT" ]]; then
  echo "escapes-append-only: no $LEDGER at ${BASE_SHA:0:12}; nothing to protect yet."
  exit 0
fi

rows_of() { grep -E '^\|' <<<"$1" | grep -E 'ESC-[0-9]+' || true; }

BASE_ROWS="$(rows_of "$BASE_CONTENT")"
if [[ -z "$BASE_ROWS" ]]; then
  echo "escapes-append-only: $LEDGER has no entry rows at ${BASE_SHA:0:12}; nothing to protect yet."
  exit 0
fi

if [[ ! -f "$ROOT/$LEDGER" ]]; then
  echo "escapes-append-only: $LEDGER was deleted — the ledger is append-only, and its" >&2
  echo "entries are cited by id from gated documents. Restore it." >&2
  exit 1
fi
HEAD_ROWS="$(rows_of "$(cat "$ROOT/$LEDGER")")"

declare -a PROBLEMS=()

# Every base row survives, byte-identical. Fixed-string, whole-line: a row that
# was "only reworded" is a row that changed.
while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  grep -qxF "$row" <<<"$HEAD_ROWS" \
    || PROBLEMS+=("a landed row was modified or removed: ${row:0:100}")
done <<<"$BASE_ROWS"

# And in the same relative order. Take HEAD's rows, keep only the ones that
# were present at base, and the sequence must BE the base sequence — reordering
# is rewriting with extra steps, and an entry moved out of its place changes
# what "newest at the bottom" says about it.
if [[ ${#PROBLEMS[@]} -eq 0 ]]; then
  SURVIVORS="$(while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    if grep -qxF "$row" <<<"$BASE_ROWS"; then printf '%s\n' "$row"; fi
  done <<<"$HEAD_ROWS"; true)"
  if [[ "$SURVIVORS" != "$BASE_ROWS" ]]; then
    PROBLEMS+=("landed rows were reordered — entries append below, they do not move")
  fi
fi

if [[ ${#PROBLEMS[@]} -gt 0 ]]; then
  echo "escapes-append-only: ${#PROBLEMS[@]} problem(s):" >&2
  printf '  %s\n' "${PROBLEMS[@]}" >&2
  cat >&2 <<MSG

$LEDGER is append-only: entries are cited by id from gated documents, and the
agent that caused an escape is often the one that logs it — which is safe only
while a landed row cannot be quietly revised. To correct an entry, APPEND a
correction row with the same id, exactly as the file's own header says.

Relaxing this check to get an edit through is gate tampering.
MSG
  exit 1
fi

total="$(grep -c . <<<"$BASE_ROWS" || true)"
echo "escapes-append-only: $total landed row(s) intact at ${BASE_SHA:0:12}."
