#!/usr/bin/env bash
#
# pr-queue.sh — fixture tests.
#
# ESC-17: four pull requests open at once, two citing a ledger entry sitting
# unmerged inside a third. The two that passed merged ahead of the one they
# depended on, and the owner hand-merged the default branch into the blocked
# branch and re-ran every check. Every gate judges ONE pull request, so the
# shape of the set was invisible to all of them.
#
# This is a NOTE, so what these tests pin is not a verdict. They pin that the
# fact is COMPUTED and honest in the three ways it can be wrong:
#
#   - it never fails, whatever it finds or cannot find;
#   - "I could not look" never reads as "there is nothing";
#   - a pull request is not counted as its own queue.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SCRIPT="$HERE/../template/.github/scripts/pr-queue.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

echo "=== pr-queue.sh ==="

# A gh stub. STUB_ROWS is the TSV the real `--jq` produces:
#   <number> <failing> <pending> <headRef>
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "pr list "*) printf '%s\n' "$STUB_ROWS" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$WORK/bin/gh"

run() { STUB_ROWS="${STUB_ROWS:-}" GH="$WORK/bin/gh" bash "$SCRIPT" 2>&1; }

# ------------------------------------------------------- it never fails
STUB_ROWS=""
out="$(PR_AUTHOR=someone run)"
expect_rc "an empty queue is not a failure" 0 $?
expect_contains "and says the queue is empty" "$out" "No other open pull requests"

# "Nothing found" and "could not look" are different claims, and collapsing
# them is how a fact script comes to report a clean queue for a repository it
# could not read. The empty case says so out loud.
expect_contains "and does not let 'found nothing' read as 'nothing exists'" "$out" \
  "it is 'nothing found', not 'nothing exists'"

out="$(run)"   # no PR_AUTHOR at all
expect_rc "no author is not a failure either" 0 $?
expect_contains "but it is reported as unknown, not empty" "$out" "Treat this as unknown rather than empty"

out="$(PR_AUTHOR=someone GH=/nonexistent-gh bash "$SCRIPT" 2>&1)"
expect_rc "no gh in the job is not a failure" 0 $?
expect_contains "and says why nothing was computed" "$out" "not available in this job"

# ------------------------------------------------- the queue ESC-17 describes
STUB_ROWS="$(printf '%s\n' \
  "11	0	0	docs/the-ledger-entry" \
  "12	2	0	feat/depends-on-11" \
  "13	0	3	feat/also-depends" \
  "14	0	0	chore/unrelated")"
out="$(PR_AUTHOR=agent PR_NUMBER=14 run)"
expect_rc "a real queue is still not a failure" 0 $?
expect_contains "it counts the others" "$out" "3 other open pull request(s)"
expect_contains "and names the red one" "$out" "#12  RED (2 failing)"
expect_contains "and the one still running" "$out" "#13  pending (3 still running)"
expect_contains "and the green one" "$out" "#11  green"
expect_contains "and summarises" "$out" "1 red, 1 still running"

# A pull request is not its own queue. Without this the note would report every
# change as having one open pull request, which is noise that teaches a reader
# to skip the section.
expect_not_contains "this pull request is left out of its own queue" "$out" "#14"

# ...and with no PR_NUMBER supplied it cannot exclude itself, which is a real
# case (a caller that forgot). It over-counts rather than silently dropping a
# row, because the wrong direction here is under-reporting a queue.
out="$(PR_AUTHOR=agent run)"
expect_contains "with no number it counts them all rather than guessing" "$out" \
  "4 other open pull request(s)"

# ----------------------------------------------------- it is scoped by author
# The stub returns whatever it is given, so this pins the CALL rather than the
# filtering: the query must name the author, or the note is about the whole
# repository and says something false about one person's queue.
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$STUB_CAPTURE"
STUB
chmod +x "$WORK/bin/gh"
STUB_CAPTURE="$WORK/call.txt" PR_AUTHOR=grimsverk GH="$WORK/bin/gh" bash "$SCRIPT" >/dev/null 2>&1
expect_contains "the query is scoped to the author" "$(cat "$WORK/call.txt")" \
  'select(.author.login == "grimsverk")'
expect_contains "and asks only for open pull requests" "$(cat "$WORK/call.txt")" "--state open"

# ------------------------------------------------------------ it is a NOTE
STUB_ROWS="$(printf '%s\n' "11	9	0	feat/everything-is-on-fire")"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in "pr list "*) printf '%s\n' "$STUB_ROWS" ;; *) exit 1 ;; esac
STUB
chmod +x "$WORK/bin/gh"
out="$(PR_AUTHOR=agent run)"
expect_rc "even a queue that is entirely red does not fail" 0 $?
expect_contains "and it says plainly that it is a note" "$out" "This is a NOTE"
expect_contains "and says what the finding actually is" "$out" \
  "the ordering is the finding, not the count"

summary
