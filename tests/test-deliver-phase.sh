#!/usr/bin/env bash
#
# deliver-phase.sh — fixture tests for the detector on its own.
#
# The loop-level tests (test-deliver-loop.sh) drive the detector through the
# driver; these pin two properties of the detector ITSELF that the loop never
# looks at: which lines of a backlog item the HIGH classification may live on
# (ESC-209), and whether a reading names the commit it read and warns when the
# checkout is stale (ESC-215). Same recipe as everywhere else: a stub gh on
# PATH, a manufactured repository.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

PHASE="$HERE/../template/.claude/scripts/deliver-phase.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== deliver-phase.sh ==="

# A gh that answers every pull-request read with nothing: no open pull
# request, no merged refs. Every test here exits by section 3, so nothing
# richer is needed.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$WORK/bin/gh"

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs"

# THE ENTRY SHAPE EVERY REAL WORKER PRODUCES (ESC-209). The live audit read
# every uncertainty a whole lane had filed and not one carried HIGH on its
# first line: the item opens with the question, and `**HIGH**:` sits in the
# body where the reasoning for the classification belongs. BL-20 is that real
# shape; BL-21 is a LOW neighbour (which also proves a HIGH in the items
# around it does not leak into its block); BL-22 keeps the old first-line
# shape working.
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-20** — where does the cache live?
  Proposed default: in-memory, per process.
  **HIGH**: the answer changes the storage schema and two slice boundaries.
- **BL-21** — what is the flag called? Proposed: --sync. **LOW**: renaming a
  flag later is cheap.
- **BL-22** — HIGH: which wire format? Changes an external schema.
EOF
: > "$R/docs/DESIGN.oracle.md"
git -C "$R" add -A && git -C "$R" commit -qm seed
git -C "$R" remote add origin https://github.com/own/repo.git
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

run_phase() { ( cd "$R" && env GH="$WORK/bin/gh" "$PHASE" 2>&1 ); }

# ---------------- ESC-209: HIGH counts anywhere in the item's block
# The old read demanded the id and the word HIGH on the same first line, which
# no real entry ever satisfied — REASON=uncertainties had never fired on a
# live run, and every blocked question reached the oracle through the
# section-3 catch-all as REASON=evidence, indistinguishable from an unread
# escape. Both assertions below fail against the first-line-only read.
out="$(run_phase)"
expect_contains "a HIGH in the item's body wakes the oracle" "$out" "PHASE=ORACLE"
expect_contains "for the blocking reason, not the catch-all" "$out" \
  "REASON=uncertainties"
# One line pins three facts: the body-HIGH item counts, the first-line-HIGH
# item still counts, and the LOW item between them is NOT swept up by its
# neighbours' classification — an item's block ends where the next begins.
expect_contains "and names exactly the HIGH items" "$out" "UNRULED=BL-20 BL-22"

# A ruling that cites the HIGH items clears the block; the LOW one then
# surfaces through section 3 as ordinary evidence — the two paths stay
# distinct, which is the point of section 2 existing at all.
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
## OD-1 — cache and wire format

- **Evidence:** BL-20, BL-22
EOF
out="$(run_phase)"
expect_contains "cited HIGH items no longer block" "$out" "REASON=evidence"
expect_contains "and the LOW item reaches the oracle as evidence" "$out" \
  "UNCITED=BL-21"
git -C "$R" checkout -q -- docs/DESIGN.oracle.md

# ---------------- ESC-215: the reading is dated, and a stale checkout says so
# An operator ran the detector on a tree three commits behind the remote and
# reported the honest-but-stale phase onward as though it described the real
# base. Nothing in the output said which commit it read.
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
out="$(run_phase)"
expect_contains "the reading names the commit it read" "$out" "BASE_SHA=$HEAD_SHA"
expect_not_contains "no upstream, no warning (the check is guarded)" "$out" "BEHIND"

# Put the branch behind its remote-tracking ref: a commit exists on
# origin/main that the checkout has not pulled.
git -C "$R" branch -q --set-upstream-to=origin/main main
git -C "$R" switch -q -c ahead
echo "newer" >> "$R/docs/BACKLOG.md"
git -C "$R" commit -qam "remote moved on"
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
git -C "$R" switch -q main
git -C "$R" branch -qD ahead

out="$(run_phase)"
expect_contains "a stale checkout warns, loudly" "$out" "BEHIND"
expect_contains "and says how far" "$out" "1 commit(s)"
expect_contains "and names the upstream it measured against" "$out" "origin/main"
expect_contains "the detection itself still runs" "$out" "PHASE=ORACLE"
expect_contains "and still names the (stale) commit it read" "$out" \
  "BASE_SHA=$HEAD_SHA"

# The warning goes to STDERR: the driver parses stdout as KEY=VALUE lines, and
# a warning printed into that stream would be one malformed key away from
# breaking the parse.
out_stdout="$( cd "$R" && env GH="$WORK/bin/gh" "$PHASE" 2>/dev/null )"
expect_not_contains "the warning does not pollute the KEY=VALUE stream" \
  "$out_stdout" "BEHIND"
expect_contains "which still carries the phase" "$out_stdout" "PHASE=ORACLE"

summary
