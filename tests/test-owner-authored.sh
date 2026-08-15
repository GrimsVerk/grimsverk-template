#!/usr/bin/env bash
#
# owner-authored.sh — fixture tests.
#
# The asymmetry this protects is the one the whole oracle arrangement rests on:
# docs/DESIGN.md and docs/VISION.md are the owner's, and docs/DESIGN.oracle.md
# is the agent's. Blur it and the second document is pointless — an agent that
# can edit the design does not need an evidence ledger.
#
# CODEOWNERS does not draw that line on its own. It requires the owner's
# APPROVAL, which is a click on a diff someone else composed and opened. This
# check requires their AUTHORSHIP of the pull request, which is the stronger
# claim and the one actually wanted: it means they read it.
#
# Both directions are pinned, and the passing ones matter as much as the
# blocking ones — a check that fired on plans, or on the oracle ledger, would
# stop overnight work dead, which is the exact failure the arrangement exists to
# prevent.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/owner-authored.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== owner-authored.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans/oracle" "$R/docs/oracle" "$R/.github" "$R/src"

cat > "$R/.github/CODEOWNERS" <<'EOF'
/.github/                    @theowner
/AGENTS.md                   @theowner
/docs/DESIGN.md              @theowner
/docs/VISION.md              @theowner
/docs/plans/                 @theowner
/docs/plans/oracle/
EOF
printf '# Design\n' > "$R/docs/DESIGN.md"
printf '# Vision\n' > "$R/docs/VISION.md"
printf '# Oracle ledger\n' > "$R/docs/DESIGN.oracle.md"
echo seed > "$R/README.md"
git -C "$R" add -A && git -C "$R" commit -qm seed
BASE="$(git -C "$R" rev-parse HEAD)"

run() { # run <pr-author>
  ( cd "$R" && BASE_SHA="$BASE" HEAD_SHA=HEAD PR_AUTHOR="$1" "$CHECK" 2>&1 )
}
commit() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

# ------------------------------------ nothing owned is touched -> says nothing
echo "x = 1" > "$R/src/thing.py"
printf '\n- a decision\n' >> "$R/docs/DESIGN.oracle.md"
cat > "$R/docs/plans/feature.md" <<'EOF'
---
slug: feature
---
# Feature — Plan
EOF
commit "Agent work: code, the oracle ledger, and a plan"
out="$(run some-agent)"
expect_rc "an agent pull request touching neither document passes" 0 $?
expect_contains "and says why it said nothing" "$out" "touches neither"

# The oracle ledger and plans are the point of the exemption: if this check
# reached them, overnight work would stop dead.
expect_not_contains "the oracle ledger is not an owned document" "$out" "DESIGN.oracle.md"

# ------------------------------------------- an agent touches the design -> no
printf '\n## 5. Requirements\n- **R1** — a thing\n' >> "$R/docs/DESIGN.md"
commit "Agent edits the design"
out="$(run some-agent)"
expect_rc "an agent pull request touching the design fails" 1 $?
expect_contains "names the file" "$out" "docs/DESIGN.md"
expect_contains "names who opened it and who should have" "$out" \
  "opened by 'some-agent', not by 'theowner'"
expect_contains "gives the reason rather than just the rule" "$out" \
  "docs/DESIGN.oracle.md has no reason to exist"
expect_contains "says an agent may still write it" "$out" "ends at a pushed branch"

# ...and the SAME diff, opened by the owner, is exactly what is wanted.
out="$(run theowner)"
expect_rc "the same pull request opened by the owner passes" 0 $?
expect_contains "and counts what it checked" "$out" "1 owned document(s)"
git -C "$R" reset -q --hard HEAD~1

# ------------------------------------------- an agent touches the vision -> no
printf '\n## Priorities\n\n1. Correctness\n' >> "$R/docs/VISION.md"
commit "Agent edits the vision"
expect_rc "an agent pull request touching the vision fails" 1 "$(run some-agent >/dev/null; echo $?)"
expect_rc "the owner may land the vision" 0 "$(run theowner >/dev/null; echo $?)"

# Both at once is the normal /design output, and is one pull request.
printf '\nmore design\n' >> "$R/docs/DESIGN.md"
commit "Agent writes both documents"
out="$(run theowner)"
expect_rc "the owner may land both together" 0 $?
expect_contains "and counts both" "$out" "2 owned document(s)"
git -C "$R" reset -q --hard "$BASE"

# -------------------------------------------- the owner is read from CODEOWNERS
# One source of truth: a project that renames its owner must not have to
# remember this script exists.
sed -i 's|/docs/DESIGN.md              @theowner|/docs/DESIGN.md              @someone-else|' \
  "$R/.github/CODEOWNERS"
printf '\nedit\n' >> "$R/docs/DESIGN.md"
commit "Rename the owner and edit the design"
out="$(run theowner)"
expect_rc "the previous owner no longer qualifies" 1 $?
expect_contains "names the owner CODEOWNERS gives" "$out" "not by 'someone-else'"
expect_rc "and the new owner does" 0 "$(run someone-else >/dev/null; echo $?)"

# An explicit override wins, for a project whose ownership lives elsewhere.
expect_rc "OWNER_LOGIN overrides CODEOWNERS" 0 \
  "$( cd "$R" && BASE_SHA="$BASE" HEAD_SHA=HEAD PR_AUTHOR=third OWNER_LOGIN=third \
      "$CHECK" >/dev/null 2>&1; echo $? )"

# ------------------------------------------------ unresolvable owners fail shut
# A team's membership cannot be read from the repository, and guessing is worse
# than stopping — this is the one check where failing open would hand an agent
# the design.
sed -i 's|/docs/DESIGN.md              @someone-else|/docs/DESIGN.md              @acme/maintainers|' \
  "$R/.github/CODEOWNERS"
commit "Own the design with a team"
out="$(run anyone)"
expect_rc "a team owner fails closed rather than guessing" 1 $?
expect_contains "and says how to resolve it" "$out" "Set OWNER_LOGIN"

sed -i '/docs\/DESIGN.md/d' "$R/.github/CODEOWNERS"
commit "Remove the ownership entry entirely"
out="$(run anyone)"
expect_rc "no owner at all fails closed" 1 $?
expect_contains "and says it cannot be satisfied" "$out" "cannot be satisfied"

summary
