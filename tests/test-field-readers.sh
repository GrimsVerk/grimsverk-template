#!/usr/bin/env bash
#
# test-field-readers.sh — no write-only decision fields (loop-economy slice 1,
# ESC-219).
#
# The schema checker, template/.github/scripts/oracle-decisions.sh, REQUIRES an
# agent to write these fields into every ledger decision. A required field that
# nothing consumes is pure ceremony — and worse than ceremony when a reader is
# assumed: `Requirements superseded:` was mandated on every decision while no
# script read it, so coverage.sh reported a superseded id as a permanent gap
# and the delivery loop dispatched a planner for a dead requirement every
# cycle, observed live (ESC-219).
#
# Every required field therefore has a DECLARED consumer, in the map below:
#
#   machine    — the field's value gates other machinery, so a shipped script
#                OTHER than the checker must mention the field by name. A blunt
#                fixed-string grep, on purpose: nothing subtler than an actual
#                mention in an actual reader satisfies it.
#   validated  — the checker itself consumes the VALUE beyond checking its
#                presence (Evidence ids must resolve at the base commit; the
#                relied-on vision quote must exist verbatim in docs/VISION.md).
#   narrative  — written for the human trail: the owner reading the ledger and
#                the review gate reading the diff. No script reader is owed.
#
# The ratchet runs both ways: the required-field lists are EXTRACTED from the
# checker, so a field added to the schema without a row in this map fails here
# — the next write-only field cannot ship quietly — and a machine field whose
# reader disappears fails here too.
#
# This file replaced the blind-written sweep (commit ec71ca2), which demanded a
# script reader for EVERY field and was therefore red on the narrative ones;
# the spec it was written from over-reached, not the test. The machine half is
# unchanged from the blind version.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"
ROOT="$HERE/.."

echo "=== field readers — every required decision field has a declared consumer ==="

CHECKER="$ROOT/template/.github/scripts/oracle-decisions.sh"

declare -A CONSUMER=(
  ["Requirements added"]="machine"      # coverage.sh builds the requirement universe from it
  ["Requirements superseded"]="machine" # coverage.sh moves the id off the dispatchable gap list (ESC-219)
  ["Closure"]="machine"                 # deliver-phase.sh reads the disposition (ESC-217)
  ["Evidence"]="validated"              # cited ids must exist at the base commit
  ["Vision statement relied on"]="validated" # the quote must appear verbatim in docs/VISION.md
  ["Date"]="narrative"
  ["Rationale"]="narrative"
  ["Alternatives considered"]="narrative"
  ["Vision statements against"]="narrative"
  ["Tenet relied on"]="narrative"                 # HALT schema
  ["What a decision would have said"]="narrative" # HALT schema
  ["What it needs from the owner"]="narrative"    # HALT schema
)

# The fields the checker actually requires, extracted from its own `for field
# in` lists (both schemas), so this map cannot go quietly stale.
mapfile -t REQUIRED < <(
  awk '/for field in/{f=1}
       f{line=$0
         while (match(line, /"[^"]+"/)) {
           print substr(line, RSTART+1, RLENGTH-2)
           line = substr(line, RSTART+RLENGTH)
         }}
       f && /do[[:space:]]*$/{f=0}' "$CHECKER" | sort -u
)

if [[ ${#REQUIRED[@]} -eq 0 ]]; then
  no "required-field extraction found the checker's field lists" \
     "no 'for field in' list matched in $CHECKER — the extraction is broken, not the schema"
else
  ok "required-field extraction found ${#REQUIRED[@]} fields in the checker"
fi

for field in "${REQUIRED[@]}"; do
  [[ -n "$field" ]] || continue
  class="${CONSUMER[$field]:-}"
  if [[ -z "$class" ]]; then
    no "required field '$field' has a declared consumer" \
       "the checker requires it and this map does not know it — declare its" \
       "consumer here (machine / validated / narrative) or stop requiring it"
    continue
  fi
  case "$class" in
    machine)
      hits="$(grep -rlF -- "$field" \
        "$ROOT/template/.github/scripts" "$ROOT/template/.claude/scripts" 2>/dev/null \
        | grep -v 'oracle-decisions\.sh$' || true)"
      if [[ -n "$hits" ]]; then
        ok "machine field '$field' has a reader ($(basename "$(head -1 <<<"$hits")"))"
      else
        no "machine field '$field' has a reader" \
           "no shipped script other than the checker mentions it — a mandated" \
           "write nothing reads is ESC-219's exact shape"
      fi ;;
    validated|narrative)
      ok "field '$field' is declared $class" ;;
    *)
      no "field '$field' has a known class" "unknown class '$class' in the map" ;;
  esac
done

# The map may know fields the checker does not yet require ("Closure" lands
# with the disposition rule in slice 2) — that direction is fine and expected.

summary
