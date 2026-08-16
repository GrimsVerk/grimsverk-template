#!/usr/bin/env bash
#
# budget-probe.sh — best-effort read of the owner's subscription utilization.
#
# The delivery loop's ceiling is ruled in percentage points of the owner's
# subscription rate limit (docs/DECISIONS.md): the run records utilization at
# start and halts when the delta exceeds its allowance. This script is the
# probe. It prints, on success:
#
#     session=<percent> week=<percent>
#
# and exits 0. When it cannot read — no credential, no endpoint, an answer it
# does not recognise — it prints why to stderr and exits 3, and the DRIVER'S
# POSTURE ON 3 IS THE POINT: the run continues under its hard backstops
# (--max-prs, --max-hours) rather than halting, because those bounds hold
# whether or not this probe works, and a loop that refuses to run because its
# nice-to-have gauge is broken has inverted which of its limits is
# load-bearing.
#
# UNVERIFIED, honestly (AGENTS.md: never claim verification you could not
# observe): the Claude Code CLI exposes usage interactively (/usage) but a
# stable headless surface for it is not documented, and this probe has not
# been exercised against a live subscription from this script. It tries, in
# order:
#
#   1. BUDGET_PROBE_CMD — an owner-supplied command printing the two numbers
#      (the escape hatch that makes everything below optional);
#   2. `claude usage --json`, in case the CLI grows/has the surface, parsing
#      the two most utilization-shaped percentages it can find.
#
# The codex engine has no usage surface at all; with codex workers the
# backstops are the only ceiling, and the driver says so at start.
#
# Optional env:
#   BUDGET_PROBE_CMD   command to run instead of the built-in attempts; must
#                      print "session=<n> week=<n>" itself

set -uo pipefail

if [[ -n "${BUDGET_PROBE_CMD:-}" ]]; then
  out="$($BUDGET_PROBE_CMD 2>/dev/null)" || {
    echo "budget-probe: BUDGET_PROBE_CMD failed" >&2; exit 3; }
  if grep -qE '^session=[0-9]+([.][0-9]+)? week=[0-9]+([.][0-9]+)?$' <<<"$out"; then
    echo "$out"; exit 0
  fi
  echo "budget-probe: BUDGET_PROBE_CMD printed something other than 'session=<n> week=<n>'" >&2
  exit 3
fi

if command -v claude >/dev/null 2>&1; then
  out="$(claude usage --json 2>/dev/null)" || out=""
  if [[ -n "$out" ]]; then
    # Take the first two percentage-shaped utilization numbers. Deliberately
    # loose: the surface is undocumented, and a parser that demands an exact
    # schema breaks on the first rename, silently costing the ceiling.
    mapfile -t PCTS < <(grep -oE '"(utilization|percent[a-z_]*)"[[:space:]]*:[[:space:]]*[0-9]+([.][0-9]+)?' <<<"$out" \
      | grep -oE '[0-9]+([.][0-9]+)?$' | head -2)
    if [[ ${#PCTS[@]} -ge 1 ]]; then
      echo "session=${PCTS[0]} week=${PCTS[1]:-${PCTS[0]}}"
      exit 0
    fi
  fi
fi

echo "budget-probe: cannot read subscription utilization here — the run's" >&2
echo "ceiling falls back to the hard backstops (--max-prs, --max-hours)." >&2
echo "To wire a real gauge, set BUDGET_PROBE_CMD to a command that prints" >&2
echo "'session=<n> week=<n>'." >&2
exit 3
