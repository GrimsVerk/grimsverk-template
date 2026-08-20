#!/usr/bin/env bash
#
# record-delivered.sh — fixture tests against a stub `gh`.
#
# THE DEFECT THIS EXISTS FOR. A planner could not tell what had already been
# built. coverage.sh reports what a plan CLAIMS, and says so in its own output;
# the nearest thing to an answer was a plan's `status:` field, which is set by
# hand, so on a real project every plan still read `status: draft` long after
# its work had merged. A steward planning the next piece was working from a
# record of what somebody remembered to write down.
#
# So this reads merged pull requests, which cannot go stale. What the stub CAN
# prove: the slug match, the covers: extraction, idempotence, base scoping, and
# that a plan whose branch never merged is not recorded. What it cannot prove is
# that the real API answers in this shape — that is the live run's job.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

REC="$HERE/../template/.claude/scripts/record-delivered.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== record-delivered.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans/oracle" "$R/.claude/scripts" "$WORK/bin"

# The stub reads its answer from a file, so each case sets the merged list.
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *"repo view"*) echo "acme/widget"; exit 0 ;;
  *"pulls?state=closed"*)
    base="$(sed -E 's/.*base=([^&]*).*/\1/' <<<"$*" | tr '/' '-')"
    [[ -f "$STUB_MERGED.$base" ]] && cat "$STUB_MERGED.$base"
    exit 0 ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"
export STUB_MERGED="$WORK/merged"

plan() { # plan <path> <slug> <covers>
  cat > "$R/docs/plans/$1.md" <<EOF
---
slug: $2
status: draft
covers: [$3]
---
# $2 — Plan
EOF
}
doneq() { cat > "$R/docs/DESIGN.oracle.done.md"; }
run() { ( cd "$R" && PATH="$WORK/bin:$PATH" "$REC" "$@" 2>&1 ); }

doneq <<'EOF'
# Delivered

_(nothing yet)_
EOF
plan shipped corpus-and-checkpoint "R1, R2"
plan pending later-work "R3"
printf 'feat/corpus-and-checkpoint\t99\t2026-08-20T10:00:00Z\n' > "$WORK/merged.run-local"

out="$(run --base run/local)"
expect_rc "a merged feat branch is recorded" 0 $?
expect_contains "reports what it appended" "$out" "appended 2 line(s)"

body="$(cat "$R/docs/DESIGN.oracle.done.md")"
expect_contains "the first covered id lands" "$body" '- `R1` — delivered — 2026-08-20 — PR #99, plan `corpus-and-checkpoint`'
expect_contains "and the second" "$body" '- `R2` — delivered — 2026-08-20 — PR #99'
expect_not_contains "a plan whose branch never merged is not recorded" "$body" '`R3`'

# IDEMPOTENT, because this runs at every stop of every run. A second pass that
# re-appended would grow the file without bound and, worse, would be an EDIT to
# a landed record the moment anything deduplicated it.
out="$(run --base run/local)"
expect_rc "a second pass succeeds" 0 $?
expect_contains "and records nothing new" "$out" "nothing new to record"
expect_rc "the file is unchanged" 0 "$(diff <(echo "$body") "$R/docs/DESIGN.oracle.done.md" >/dev/null; echo $?)"

# SCOPED TO ONE BASE. Two lanes share a repository, and a merge into one lane's
# base says nothing about the other's — the isolation every other part of this
# pipeline keeps (ESC-46, ESC-71) and that a repo-wide query would breach.
out="$(run --base run/web)"
expect_contains "the other lane's base records nothing" "$out" "no merged pull requests on 'run/web'"

# The slug is matched from the plan's front matter and anchored at both ends, so
# a slug that is a prefix of another plan's cannot claim its branch.
plan sync sync-index "R4"
plan sync2 sync-index-1 "R5"
printf 'feat/sync-index-1\t101\t2026-08-21T09:00:00Z\n' > "$WORK/merged.run-local"
out="$(run --base run/local)"
body="$(cat "$R/docs/DESIGN.oracle.done.md")"
expect_contains "the exactly-matching slug is recorded" "$body" '`R5`'
expect_not_contains "and the prefix slug is not" "$body" '`R4`'

# --dry-run prints and writes nothing, so a stop can show what it would record.
printf 'feat/sync-index\t102\t2026-08-22T09:00:00Z\n' > "$WORK/merged.run-local"
before="$(cat "$R/docs/DESIGN.oracle.done.md")"
out="$(run --base run/local --dry-run)"
expect_contains "--dry-run prints the line" "$out" '`R4`'
expect_rc "and writes nothing" 0 "$(diff <(echo "$before") "$R/docs/DESIGN.oracle.done.md" >/dev/null; echo $?)"

summary
