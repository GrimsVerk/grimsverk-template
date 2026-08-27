#!/usr/bin/env bash
#
# emit-event.sh — the delivery loop's one machine record, one JSON line per
# event (ESC-224).
#
# The 2026-08-20 post-mortem could not answer 23 of its 40 questions because
# the fields it needed were never written anywhere: pr numbers null on every
# dispatch row, id references empty, the web lane's whole history hand-typed
# prose needing its own parser. This emitter is the correction, and both
# drivers call it — the local shell loop and the web session — so the machine
# record stops depending on which environment a run happened to use. The
# hand-written report stays welcome; it is commentary now, not the primary
# record.
#
# Usage:
#     EVENTS_FILE=<path> emit-event.sh <kind> [key=value ...]
#
# Kinds, and the fields each REFUSES to be written without — the no-nulls
# contract is enforced here, at write time, not discovered in a post-mortem:
#
#   start     template_version
#   detect    iteration phase
#   dispatch  iteration phase worker role prompt_sha
#   result    iteration worker exit_code
#   merge     pr
#   stop      exit_code reason
#
# Every line also carries, automatically: ts (UTC, second precision), run_id
# and base (from $RUN_ID / $RUN_BASE), and the event kind. Any extra key=value
# pairs ride along verbatim (ids, plan, pr, headref, reason, counters). When
# an `ids` key is given, an `ids_scoped` key is derived beside it —
# `<base>:<run_id>:<id>` per id — because bare OD/BL numbers collide across
# lanes and rounds and only the scoped key was ever unique (ESC-227).
#
# WRITE-THROUGH, APPEND-ONLY: one atomic append per call, so a killed run's
# stream is complete up to the kill — the discipline that let every one of
# six post-mortem analysis sessions resume cleanly.
#
# Exit codes: 0 written; 2 refused (missing EVENTS_FILE, unknown kind, or a
# required field absent/empty — the message names it). A caller treats a
# refusal as a loud log line, never as a run-stopping error: a recorder that
# kills the run it records has inverted its job.

set -uo pipefail

die() { echo "emit-event: $*" >&2; exit 2; }

[[ -n "${EVENTS_FILE:-}" ]] || die "EVENTS_FILE is not set — every event needs a stream to land in"
[[ $# -ge 1 ]] || die "usage: emit-event.sh <kind> [key=value ...]"

KIND="$1"; shift

case "$KIND" in
  start)    REQUIRED="template_version" ;;
  detect)   REQUIRED="iteration phase" ;;
  dispatch) REQUIRED="iteration phase worker role prompt_sha" ;;
  result)   REQUIRED="iteration worker exit_code" ;;
  merge)    REQUIRED="pr" ;;
  stop)     REQUIRED="exit_code reason" ;;
  *)        die "unknown event kind '$KIND' — the vocabulary is: start detect dispatch result merge stop" ;;
esac

# JSON string escaping, dependency-free (R15: the suite runs offline, bash
# only). Backslash first, then quote, then the control characters that
# actually occur in shell values.
jesc() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//$'\n'/\\n}"
  v="${v//$'\r'/\\r}"
  v="${v//$'\t'/\\t}"
  printf '%s' "$v"
}

declare -A FIELDS=()
ORDER=()
put() { # put <key> <value>
  [[ -n "${FIELDS[$1]:-}" ]] || ORDER+=("$1")
  FIELDS["$1"]="$2"
}

put ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
put run_id "${RUN_ID:-unknown}"
put base "${RUN_BASE:-unknown}"
put event "$KIND"

for kv in "$@"; do
  key="${kv%%=*}"
  val="${kv#*=}"
  [[ -n "$key" && "$kv" == *"="* ]] || die "malformed argument '$kv' — key=value"
  put "$key" "$val"
done

# The scoped keys, derived rather than asked for, so no caller can forget
# them (ESC-227): bare ids stay for grepping, the scoped ones are what a
# later join can trust.
if [[ -n "${FIELDS[ids]:-}" ]]; then
  scoped=""
  for id in ${FIELDS[ids]}; do
    scoped="$scoped ${FIELDS[base]}:${FIELDS[run_id]}:$id"
  done
  put ids_scoped "${scoped# }"
fi

for req in $REQUIRED; do
  [[ -n "${FIELDS[$req]:-}" ]] \
    || die "a '$KIND' event without '$req' is exactly the null a post-mortem starves on — refused"
done

line="{"
first=1
for key in "${ORDER[@]}"; do
  [[ "$first" -eq 1 ]] && first=0 || line+=","
  line+="\"$(jesc "$key")\":\"$(jesc "${FIELDS[$key]}")\""
done
line+="}"

mkdir -p "$(dirname "$EVENTS_FILE")"
printf '%s\n' "$line" >> "$EVENTS_FILE"
