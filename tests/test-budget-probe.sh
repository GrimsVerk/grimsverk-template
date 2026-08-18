#!/usr/bin/env bash
#
# budget-probe.sh — fixture tests.
#
# This script existed for weeks and could never succeed. It ran
# `claude usage --json`; there is no `usage` subcommand, `--json` is rejected as
# an unknown option, and bare `claude usage` treats the word as a prompt and
# opens a chat. Every run therefore fell through to the pull-request and
# wall-clock backstops — so the one ceiling the owner had specified did nothing,
# and the two they had never chosen were the only ones in force.
#
# Its header honestly said "UNVERIFIED". It was not unverified, it was broken,
# and the distinction is this file: a stub that answers, and an assertion that
# the answer is read. Nothing here can prove the shape of a real reading — that
# needs a live subscription — but it can prove the parser reads the shapes the
# owner's two working readers actually emit, which is what was never checked.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

PROBE="$HERE/../template/.claude/scripts/budget-probe.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

echo "=== budget-probe.sh ==="

run() { ( env BUDGET_PROBE_ALLOW_SESSION=0 "$@" bash "$PROBE" 2>&1 ); }

# ------------------------------------------------------- the key=value form
cat > "$WORK/bin/kv" <<'STUB'
#!/usr/bin/env bash
echo "session=7 week=29 week_model=25 reset=2026-08-20T10:59:00Z"
STUB
chmod +x "$WORK/bin/kv"
out="$(run BUDGET_PROBE_CMD="$WORK/bin/kv")"
expect_rc "a key=value reader is accepted" 0 $?
expect_contains "the weekly number survives" "$out" "week=29"
expect_contains "the per-model weekly number survives" "$out" "week_model=25"
expect_contains "the reset survives, so a rollover can be detected" "$out" "reset=2026-08-20T10:59:00Z"

# The older two-field form still works — an owner's existing command must not
# break because this script learned to read more.
cat > "$WORK/bin/kv2" <<'STUB'
#!/usr/bin/env bash
echo "session=7 week=29"
STUB
chmod +x "$WORK/bin/kv2"
out="$(run BUDGET_PROBE_CMD="$WORK/bin/kv2")"
expect_rc "the older two-field form still works" 0 $?
expect_contains "and the per-model figure falls back to the weekly one" "$out" "week_model=29"

# ------------------------------------------------------------- the JSON form
# The shape omarchy-agent-usage-claude --limits-only emits. Percentages there
# are fractions of one, which must become points.
cat > "$WORK/bin/json" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"limits": [
  {"label": "Session (5-hour)", "percent": 0.07},
  {"label": "Weekly (7-day)",   "percent": 0.29},
  {"label": "Fable Weekly",     "percent": 0.25}
], "resets_at": "2026-08-20T10:59:00Z"}
JSON
STUB
chmod +x "$WORK/bin/json"
out="$(run BUDGET_PROBE_CMD="$WORK/bin/json")"
expect_rc "a limits-only JSON reader is accepted" 0 $?
expect_contains "fractions become percentage points" "$out" "week=29"
expect_contains "the per-model weekly cap is read separately" "$out" "week_model=25"
expect_contains "and its reset is carried" "$out" "2026-08-20"

# Whole-number percentages must not be multiplied.
cat > "$WORK/bin/json100" <<'STUB'
#!/usr/bin/env bash
echo '{"limits": [{"label": "Session", "percent": 7}, {"label": "Weekly", "percent": 29}]}'
STUB
chmod +x "$WORK/bin/json100"
out="$(run BUDGET_PROBE_CMD="$WORK/bin/json100")"
expect_contains "whole-number percentages are left alone" "$out" "week=29"

# -------------------------------------------------------------- the failures
cat > "$WORK/bin/broken" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$WORK/bin/broken"
out="$(run BUDGET_PROBE_CMD="$WORK/bin/broken")"
expect_rc "a failing reader exits 3, so the driver asks instead" 3 $?

cat > "$WORK/bin/noise" <<'STUB'
#!/usr/bin/env bash
echo "everything is fine, thanks for asking"
STUB
chmod +x "$WORK/bin/noise"
out="$(run BUDGET_PROBE_CMD="$WORK/bin/noise")"
expect_rc "an unreadable reply exits 3 rather than guessing a number" 3 $?
expect_contains "and says so" "$out" "nothing this script could read"

# No reader at all is the web case, and it is not an error — the driver asks the
# owner for countable limits instead.
out="$(run PATH="$WORK/empty:/usr/bin:/bin")"
expect_rc "no source at all exits 3" 3 $?
expect_contains "and explains that a web session has no gauge" "$out" "web session"
expect_contains "and names the escape hatch" "$out" "BUDGET_PROBE_CMD"
expect_contains "and warns about the 15-second cache" "$out" "--force"

# --------------------------------------------------------- the dead command
# The regression that started all of this: nothing may reach for a `claude
# usage` subcommand, because there is not one.
# Code only: the header explains the old bug at length, and that prose is worth
# keeping — it is the record of why this file is trusted less than it reads.
if grep -vE '^\s*#' "$PROBE" | grep -q 'claude usage'; then
  no "the non-existent 'claude usage' subcommand is gone" \
     "budget-probe.sh still calls a command that does not exist"
else
  ok "the non-existent 'claude usage' subcommand is gone"
fi
if grep -q 'claude -p "/usage"' "$PROBE"; then
  ok "and the command that does work is what it falls back to"
else
  no "and the command that does work is what it falls back to"
fi

summary
