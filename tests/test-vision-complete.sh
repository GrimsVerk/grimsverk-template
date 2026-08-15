#!/usr/bin/env bash
#
# vision-complete.sh — fixture tests.
#
# The failure this gate exists for does not look like a failure. docs/VISION.md
# is the tiebreaker an unattended agent reaches for when the evidence is
# ambiguous, and every decision in docs/DESIGN.oracle.md must quote a statement
# from it — so an unfilled vision file goes red nowhere. It fails at 3am, in the
# one role that exists to keep work moving, which then either stops or invents
# the owner's priorities.
#
# The rule has to be narrow in two directions at once, and both are pinned here:
#
#   - it must NOT force the vision to be written before the design. Writing it
#     after is often the better order — a vision written before you have seen
#     the design is a guess about your own priorities. So design-doc pull
#     requests pass while the file is still empty;
#   - it must bite the moment IMPLEMENTATION is planned, because plans precede
#     code by rule, which makes a plan the first irreversible commitment.
#
# And an absent file passes: deleting docs/VISION.md is how a project opts out
# of the oracle, which is a legitimate choice. A skeleton left unfilled is not
# the same thing and is the only state this rejects.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/vision-complete.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== vision-complete.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans"

skeleton() {
  cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## What this project is for

<!-- One paragraph. -->

## Priorities, in order

<!-- Ordered. -->

## What I would trade away

<!-- The half that decides things. -->
EOF
}

filled() {
  cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## What this project is for

Finding the one board worth buying without watching forty hours of video.

## Priorities, in order

<!-- Ordered. -->

1. Correctness of the verdict
2. Cost of the run
3. How long it takes

## What I would trade away

Breadth. Twenty boards judged well beats two hundred judged from a keyword.
EOF
}

echo "seed" > "$R/README.md"
skeleton
git -C "$R" add -A && git -C "$R" commit -qm "seed"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { ( cd "$R" && BASE_SHA="$BASE" HEAD_SHA=HEAD "$CHECK" 2>&1 ); }
commit() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

plan() {
  cat > "$R/docs/plans/$1.md" <<EOF
---
slug: $1
covers: [R1]
---
# $1 — Plan
## Slice 1 — thing
- **Files:** \`src/thing.py\`
- **Estimate:** ~10 lines
EOF
}

# ------------------------------- a design-doc change passes on an empty vision
# The load-bearing half. If this failed, the check would be forcing the vision
# to be written first, which is exactly the order the owner found harder.
mkdir -p "$R/docs"
printf '# Design\n\n## 5. Requirements\n- **R1** — a thing\n' > "$R/docs/DESIGN.md"
commit "Write the design doc"
out="$(run)"
expect_rc "a design-doc pull request passes with the vision still empty" 0 $?
expect_contains "and says why it said nothing" "$out" "touches no plan"

# ---------------------------------- code with no plan change also says nothing
echo "x = 1" > "$R/thing.py"
commit "Some code"
expect_rc "a pull request touching no plan passes" 0 "$(run >/dev/null; echo $?)"

# ------------------------------------ adding a plan on an empty vision -> fail
plan draft-saving
commit "Add a plan"
out="$(run)"
expect_rc "adding a plan with an unfilled vision fails" 1 $?
expect_contains "names an empty section" "$out" "What I would trade away"
expect_contains "says the vision need not come first" "$out" "does NOT have to be written before the design"
expect_contains "offers deletion as the other answer" "$out" "DELETE the ones this project does not want"

# ------------------------------------------- filling it in unblocks the plan
filled
commit "Fill in the vision"
out="$(run)"
expect_rc "the same plan passes once the vision is filled" 0 $?
expect_contains "and says so" "$out" "may plan work"

# ---------------------------- a PARTLY filled vision is still unfilled
# The realistic failure: two sections answered and the rest left as prompts.
python3 - "$R/docs/VISION.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
open(p, "w").write(t.split("## What I would trade away")[0]
                   + "## What I would trade away\n\n<!-- The half that decides things. -->\n")
PY
commit "Empty one section again"
out="$(run)"
expect_rc "a partly filled vision still fails" 1 $?
expect_contains "and names only the empty one" "$out" "What I would trade away"
expect_not_contains "not the filled ones" "$out" "## Priorities, in order"

# -------------------------------- deleting a section is an answer, not a gap
python3 - "$R/docs/VISION.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
open(p, "w").write(t.split("## What I would trade away")[0].rstrip() + "\n")
PY
commit "Delete the section rather than leave it empty"
expect_rc "a deleted section passes where an empty one failed" 0 "$(run >/dev/null; echo $?)"

# ------------------------------------------------- an absent file opts out
rm -f "$R/docs/VISION.md"
commit "Opt out of the vision entirely"
out="$(run)"
expect_rc "no vision file at all passes" 0 $?
expect_contains "and calls it an opt-out" "$out" "opted out"

# ------------------------------- the plan skeleton is not a plan being added
R2="$WORK/skeleton"
init_repo "$R2"
mkdir -p "$R2/docs/plans"
echo seed > "$R2/README.md"
git -C "$R2" add -A && git -C "$R2" commit -qm seed
B2="$(git -C "$R2" rev-parse HEAD)"
cp "$R/README.md" "$R2/docs/plans/_TEMPLATE.md"
cat > "$R2/docs/VISION.md" <<'EOF'
# Vision

## What this project is for

<!-- unfilled -->
EOF
git -C "$R2" add -A && git -C "$R2" commit -qm "Ship the plan skeleton"
out="$( cd "$R2" && BASE_SHA="$B2" HEAD_SHA=HEAD "$CHECK" 2>&1 )"
expect_rc "the underscore-prefixed plan skeleton is not a plan" 0 $?

summary
