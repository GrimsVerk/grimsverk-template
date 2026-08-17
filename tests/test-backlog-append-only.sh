#!/usr/bin/env bash
#
# backlog-append-only.sh — fixture tests.
#
# docs/BACKLOG.md is the evidence source oracle-decisions.sh resolves a
# decision's citation against, so a token in it authorises an amendment to the
# design layer. It was owned by nobody and protected by nothing, and the steward
# role has an explicit write grant for it — so the pipeline could file BL-7 in
# one pull request and, two pull requests later, amend the design on evidence it
# had written itself.
#
# The fix is deliberately immutability rather than approval: an unattended
# planner files items here mid-run, and an owner review on this path would stop
# work overnight. So these tests pin BOTH halves — filing stays free (the tests
# that must pass), and rewriting does not (the tests that must fail). A check
# that only did the second half would be indistinguishable, on a green run, from
# a check that blocked the planner.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/backlog-append-only.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== backlog-append-only.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs"
cp "$CHECK" "$R/check.sh"; chmod +x "$R/check.sh"

base_backlog() {
  cat > "$R/docs/BACKLOG.md" <<'MD'
# Backlog

Prose about ids, written as `BL-<n>`, which must not count as an item.

## Approved

- `BL-1` — export the ledger as CSV — filed by: owner
- `BL-2` — retry the feed fetch on a 5xx — filed by: coder

## Uncertainties awaiting oracle ruling

- `BL-3` — does R11 belong in v1? Proposed default: defer. HIGH — changes a
  slice boundary. — filed by: plan
MD
}

commit_base() {
  git -C "$R" add -A >/dev/null
  git -C "$R" commit -qm "base" >/dev/null
  BASE="$(git -C "$R" rev-parse HEAD)"
}

run() { ( cd "$R" && env BASE_SHA="$BASE" ./check.sh 2>&1 ); }

base_backlog
commit_base

# ------------------------------------------------------- the passing half
out="$(run)"; expect_rc "an untouched backlog passes" 0 $?
expect_contains "and counts what it protected" "$out" "3 landed item(s)"

# Filing is the main path and must stay free — this is the assertion that keeps
# the check from becoming the approval gate it deliberately is not.
printf -- '- `BL-4` — cache the parsed rules — filed by: steward\n' >> "$R/docs/BACKLOG.md"
out="$(run)"; expect_rc "appending a new item passes" 0 $?

# Reflowing the surrounding explanation must be free: only lines carrying an id
# are protected, because the rest is template-maintained prose.
sed -i 's/^Prose about ids.*/Completely rewritten prose about ids, `BL-<n>`./' "$R/docs/BACKLOG.md"
out="$(run)"; expect_rc "rewriting prose around the items passes" 0 $?

# Completion is an append to the other file, never an edit here.
cat > "$R/docs/BACKLOG.done.md" <<'MD'
# Backlog — completed items

- `BL-1` — done — 2026-08-17 — landed in #12
MD
out="$(run)"; expect_rc "recording completion in the done-log passes" 0 $?

# ------------------------------------------------------- the failing half
base_backlog
sed -i 's/export the ledger as CSV/export the ledger as CSV and JSON/' "$R/docs/BACKLOG.md"
out="$(run)"; expect_rc "rewording a landed item fails" 1 $?
expect_contains "and quotes the item" "$out" "BL-1"
expect_contains "and says what to do instead" "$out" "BACKLOG.done.md"
expect_contains "and does not tell the author to stop filing" "$out" "Nothing here stops you FILING"

base_backlog
sed -i '/BL-2/d' "$R/docs/BACKLOG.md"
out="$(run)"; expect_rc "deleting a landed item fails" 1 $?
expect_contains "and names it" "$out" "BL-2"

base_backlog
# Swap BL-1 and BL-2. Position carries meaning in a queue read top to bottom.
python3 - "$R/docs/BACKLOG.md" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
a = "- `BL-1` — export the ledger as CSV — filed by: owner\n"
b = "- `BL-2` — retry the feed fetch on a 5xx — filed by: coder\n"
open(p, "w").write(s.replace(a + b, b + a))
PY
out="$(run)"; expect_rc "reordering landed items fails" 1 $?
expect_contains "and says items do not move" "$out" "they do not move"

base_backlog
rm "$R/docs/BACKLOG.md"
out="$(run)"; expect_rc "deleting the whole ledger fails" 1 $?
expect_contains "and says the ids are cited" "$out" "cited as evidence"

# The done-log is append-only on the same terms.
base_backlog
cat > "$R/docs/BACKLOG.done.md" <<'MD'
# Backlog — completed items

- `BL-1` — done — 2026-08-17 — landed in #12
MD
commit_base
sed -i 's/landed in #12/landed in #99/' "$R/docs/BACKLOG.done.md"
out="$(run)"; expect_rc "rewriting a done-log line fails too" 1 $?
expect_contains "and names the done-log" "$out" "BACKLOG.done.md"

# ------------------------------------------------------------ fresh projects
# The skeleton spells its placeholder `BL-<n>` — angle brackets, not digits — so
# a brand-new project has nothing to protect and this never fires on day one.
rm -rf "$R/docs"; mkdir -p "$R/docs"
cat > "$R/docs/BACKLOG.md" <<'MD'
# Backlog

Give items ids — `BL-<n>`, the next unused integer.

## Approved

_(nothing yet)_
MD
git -C "$R" add -A >/dev/null; git -C "$R" commit -qm "skeleton" >/dev/null
BASE="$(git -C "$R" rev-parse HEAD)"
printf -- '- `BL-1` — the first real item — filed by: owner\n' >> "$R/docs/BACKLOG.md"
out="$(run)"; expect_rc "the shipped skeleton's placeholder is not an item" 0 $?
expect_contains "and says there was nothing to protect yet" "$out" "nothing to protect yet"

summary
