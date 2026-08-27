#!/usr/bin/env bash
#
# test-field-readers.sh — no write-only decision fields (loop-economy slice 1,
# ESC-219).
#
# The schema checker, template/.github/scripts/oracle-decisions.sh, REQUIRES an
# agent to write these fields into every ledger decision. A required field that
# no shipped script ever reads is pure ceremony: agents pay for it on every
# decision and nothing downstream can ever act on it — which is exactly how
# `Requirements superseded:` sat unread while coverage.sh reported its ids as
# permanent gaps and dispatched a planner for a dead requirement every cycle.
#
# This sweep asserts each required field's name appears in at least one shipped
# script OTHER than the checker that demands it. Deliberately blunt — a plain
# fixed-string grep over the two shipped script directories — so it cannot be
# satisfied by anything subtler than an actual mention in an actual reader.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Runs from tests/ or tests/blind/.
if [[ -f "$HERE/lib.sh" ]]; then
  # shellcheck source=tests/lib.sh
  source "$HERE/lib.sh"
  ROOT="$HERE/.."
else
  # shellcheck source=tests/lib.sh
  source "$HERE/../lib.sh"
  ROOT="$HERE/../.."
fi

echo "=== field readers — every required decision field has one ==="

# The fields the decision schema requires an agent to write.
FIELDS=(
  "Date"
  "Evidence"
  "Requirements added"
  "Requirements superseded"
  "Vision statement relied on"
  "Vision statements against"
  "Alternatives considered"
  "Rationale"
)

# readers_of <field> — every shipped script mentioning the field, except the
# schema checker itself. Fixed-string match: the field name as written.
readers_of() {
  grep -rlF -- "$1" \
    "$ROOT/template/.github/scripts" \
    "$ROOT/template/.claude/scripts" 2>/dev/null \
    | grep -vF "/oracle-decisions.sh"
}

for field in "${FIELDS[@]}"; do
  readers="$(readers_of "$field")"
  if [[ -n "$readers" ]]; then
    ok "'$field' is read by a script other than the checker"
  else
    no "'$field' is write-only" \
      "oracle-decisions.sh requires every decision to carry '$field'," \
      "but no other script under template/.github/scripts or" \
      "template/.claude/scripts ever mentions it. A field the schema" \
      "demands must have a reader, or it is ceremony."
  fi
done

summary
