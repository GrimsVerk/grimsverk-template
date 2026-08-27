#!/usr/bin/env bash
#
# test-lexicon.sh — the loop's vocabulary lives in ONE sourced file
# (lexicon-and-rehearsal slice 1, ESC-225). Written blind from the slice's
# Delivers and Signatures; no implementation was visible when this was written.
#
# The 2026-08-20 failure class this closes: every script that restated the
# phase list restated it slightly differently, and a detector emitting a phase
# no other script recognised was caught by nothing. So `lexicon.sh` declares
# the vocabularies as plain shell variables, the loop scripts source it rather
# than paraphrase it, and this file is the drift check: a phase or event kind
# used anywhere the lexicon does not carry is red here before it ships.
#
# Deliberately NOT a fixture-repo test: the subject is a sourceable file and
# the literal text of the scripts that must agree with it, so the assertions
# read the shipped tree directly.

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

LEX="$ROOT/template/.claude/scripts/lexicon.sh"
DETECTOR="$ROOT/template/.claude/scripts/deliver-phase.sh"
DRIVER="$ROOT/template/.claude/scripts/deliver-loop.sh"
EMITTER="$ROOT/template/.claude/scripts/emit-event.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== lexicon.sh — one vocabulary, sourced not paraphrased ==="

# count_word <list> <word> — occurrences of <word> as a whole word in <list>.
count_word() {
  printf '%s\n' "$1" | tr -s ' \t' '\n' | grep -cx "$2"
}

# expect_exact_set <label> <value> <word...> — every listed word exactly once,
# and no words beyond the listed ones.
expect_exact_set() {
  local label="$1" value="$2"; shift 2
  local want_n=$# w c total
  for w in "$@"; do
    c="$(count_word "$value" "$w")"
    if [[ "$c" == "1" ]]; then ok "$label carries '$w' exactly once"
    else no "$label carries '$w' exactly once" "count=$c in: $value"; fi
  done
  total="$(printf '%s\n' "$value" | wc -w)"
  if [[ "$total" -eq "$want_n" ]]; then ok "$label carries exactly $want_n words and nothing else"
  else no "$label carries exactly $want_n words and nothing else" "got $total: $value"; fi
}

# ---------------- 1: sourceable under set -u, silent, and complete
# The file is vocabulary, not a program: sourcing it in a strict shell must
# succeed, print nothing, and leave the three variables defined and non-empty.
if [[ -f "$LEX" ]]; then ok "lexicon.sh exists"
else no "lexicon.sh exists" "missing: $LEX"; fi

src_out="$(LEX="$LEX" bash -c 'set -u; source "$LEX"' 2>&1)"
expect_rc "sourcing in a set -u shell succeeds" 0 $?
if [[ -z "$src_out" ]]; then ok "and sourcing prints nothing (no side effects)"
else no "and sourcing prints nothing (no side effects)" "output: $src_out"; fi

vals="$(LEX="$LEX" bash -c '
  set -u
  source "$LEX" >/dev/null 2>&1 || exit 9
  printf "PHASES=%s\n"  "$LOOP_PHASES"
  printf "KINDS=%s\n"   "$LOOP_EVENT_KINDS"
  printf "RISK=%s\n"    "$LOOP_RISK_CLASSES"
' 2>&1)"
expect_rc "LOOP_PHASES, LOOP_EVENT_KINDS and LOOP_RISK_CLASSES are all defined" 0 $?

PHASES="$(sed -n 's/^PHASES=//p' <<<"$vals")"
KINDS="$(sed -n 's/^KINDS=//p' <<<"$vals")"
RISK="$(sed -n 's/^RISK=//p' <<<"$vals")"

if [[ -n "$PHASES" ]]; then ok "LOOP_PHASES is non-empty"
else no "LOOP_PHASES is non-empty"; fi
if [[ -n "$KINDS" ]]; then ok "LOOP_EVENT_KINDS is non-empty"
else no "LOOP_EVENT_KINDS is non-empty"; fi
if [[ -n "$RISK" ]]; then ok "LOOP_RISK_CLASSES is non-empty"
else no "LOOP_RISK_CLASSES is non-empty"; fi

expect_exact_set "LOOP_PHASES" "$PHASES" \
  WAIT ORACLE STEWARD PLAN ORCHESTRATE ACCEPTANCE SETUP
expect_exact_set "LOOP_EVENT_KINDS" "$KINDS" \
  start detect dispatch result merge stop
expect_exact_set "LOOP_RISK_CLASSES" "$RISK" \
  HIGH LOW

# ---------------- 2: drift, phases — the detector emits nothing off-lexicon
# Every literal PHASE=<WORD> the detector can print must name a word the
# lexicon defines. The grep is the whole read: this test never studies the
# detector, it only refuses a vocabulary the lexicon does not carry.
mapfile -t emitted < <(grep -oE 'PHASE=[A-Z]+' "$DETECTOR" | sort -u)
if [[ ${#emitted[@]} -gt 0 ]]; then
  ok "the detector emits at least one PHASE= literal (drift check is not vacuous)"
  for e in "${emitted[@]}"; do
    w="${e#PHASE=}"
    if [[ "$(count_word "$PHASES" "$w")" == "1" ]]; then
      ok "detector phase '$w' is in LOOP_PHASES"
    else
      no "detector phase '$w' is in LOOP_PHASES" "LOOP_PHASES: $PHASES"
    fi
  done
else
  no "the detector emits at least one PHASE= literal (drift check is not vacuous)" \
    "grep -oE 'PHASE=[A-Z]+' found nothing in $DETECTOR"
fi

# ---------------- 3: drift, kinds — the emitter speaks only lexicon kinds
# Each kind the lexicon defines appears in emit-event.sh as a whole word; a
# kind the emitter accepts but the lexicon does not carry would fail part 1's
# exact-set check the day it was added to the lexicon, and a lexicon kind the
# emitter never mentions fails here.
for w in start detect dispatch result merge stop; do
  if grep -qw "$w" "$EMITTER"; then
    ok "event kind '$w' appears in emit-event.sh"
  else
    no "event kind '$w' appears in emit-event.sh"
  fi
done

# ---------------- 4: the lexicon is sourced, not paraphrased
# At least one of the loop scripts must reference lexicon.sh by name — a
# lexicon nothing sources is a fourth restatement of the lists, not the single
# source the slice delivers.
if grep -q 'lexicon\.sh' "$DETECTOR" "$DRIVER" 2>/dev/null; then
  ok "deliver-phase.sh or deliver-loop.sh references lexicon.sh by name"
else
  no "deliver-phase.sh or deliver-loop.sh references lexicon.sh by name" \
    "neither $DETECTOR nor $DRIVER mentions lexicon.sh"
fi

summary
