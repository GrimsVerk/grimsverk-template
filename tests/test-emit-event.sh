#!/usr/bin/env bash
#
# test-emit-event.sh — the machine record refuses nulls at write time
# (ESC-224, loop-economy slice 4).
#
# The 2026-08-20 post-mortem could not reach a verdict on 23 of 40 questions
# because the fields it needed were never written: pr numbers null on all 18
# dispatch rows, id references empty on 53 of 53. The emitter is the
# correction, and the correction only holds if the no-nulls contract is
# enforced where the write happens — a conformance suite that runs after the
# fact is a post-mortem with better manners.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"
ROOT="$HERE/.."

EMIT="$ROOT/template/.claude/scripts/emit-event.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
EV="$WORK/events.jsonl"

echo "=== emit-event.sh — one JSON line per loop event, no nulls ==="

run_emit() { EVENTS_FILE="$EV" RUN_ID="20260827T0001Z" RUN_BASE="main" "$EMIT" "$@" 2>&1; }

# ---- every kind's happy path writes one parseable line with its fields
: > "$EV"
run_emit start template_version="v0.5.0" >/dev/null
run_emit detect iteration=1 phase=STEWARD ids="OD-1 BL-9" open_decisions=1 >/dev/null
run_emit dispatch iteration=1 phase=STEWARD worker=steward-od-1 role=steward prompt_sha=abc123 >/dev/null
run_emit result iteration=1 worker=steward-od-1 exit_code=0 branch=docs/x >/dev/null
run_emit merge pr=17 headref=docs/x >/dev/null
run_emit stop exit_code=0 reason="acceptance recorded" >/dev/null

lines="$(wc -l < "$EV" | tr -d ' ')"
expect_rc "six events write six lines — write-through, one append per call" 6 "$lines"

if python3 - "$EV" <<'PY' 2>/dev/null
import json, sys
kinds = []
for line in open(sys.argv[1]):
    rec = json.loads(line)
    for k in ("ts", "run_id", "base", "event"):
        assert rec[k], k
    kinds.append(rec["event"])
assert kinds == ["start", "detect", "dispatch", "result", "merge", "stop"], kinds
PY
then ok "every line is valid JSON carrying ts, run_id, base and its kind"
else no "every line is valid JSON carrying ts, run_id, base and its kind" "$(cat "$EV")"; fi

# ---- the scoped keys are derived, not asked for (ESC-227)
if grep -q '"ids_scoped":"main:20260827T0001Z:OD-1 main:20260827T0001Z:BL-9"' "$EV"; then
  ok "bare ids get run-scoped twins derived beside them"
else
  no "bare ids get run-scoped twins derived beside them" "$(grep detect "$EV")"
fi

# ---- refusals: the no-nulls contract, enforced at the write
out="$(run_emit dispatch iteration=2 phase=ORACLE worker=w role=oracle)" && rc=0 || rc=$?
expect_rc "a dispatch without prompt_sha is refused" 2 "$rc"
expect_contains "and the refusal names the field" "$out" "prompt_sha"

out="$(run_emit merge headref=docs/x)" && rc=0 || rc=$?
expect_rc "a merge without a pr number is refused" 2 "$rc"
expect_contains "naming pr" "$out" "'pr'"

out="$(run_emit party hat=1)" && rc=0 || rc=$?
expect_rc "an unknown kind is refused" 2 "$rc"
expect_contains "and the vocabulary is stated" "$out" "start detect dispatch result merge stop"

out="$(RUN_ID=x RUN_BASE=y "$EMIT" stop exit_code=1 reason=r 2>&1)" && rc=0 || rc=$?
expect_rc "no EVENTS_FILE is a refusal, not a silent drop" 2 "$rc"

before="$(wc -l < "$EV" | tr -d ' ')"
expect_rc "a refused event writes nothing" 6 "$before"

# ---- values that would break naive JSON survive escaping
run_emit stop exit_code=1 reason='a "quoted" reason with a \ backslash' >/dev/null
if python3 - "$EV" <<'PY' 2>/dev/null
import json, sys
rec = json.loads(open(sys.argv[1]).readlines()[-1])
assert rec["reason"] == 'a "quoted" reason with a \\ backslash', rec["reason"]
PY
then ok "quotes and backslashes in values survive the round trip"
else no "quotes and backslashes in values survive the round trip" "$(tail -1 "$EV")"; fi

summary
