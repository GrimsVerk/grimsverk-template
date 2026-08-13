#!/usr/bin/env bash
#
# End-to-end gate tests against a REAL rendered project.
#
# plan-parse.sh and blind-tests.sh have their own fixture tests; this file
# exercises the scripts as CI actually invokes them — inside a generated repo,
# with real commits — and pins the properties the gates exist for:
#
#   - a plan must exist at the base commit before the work that implements it
#   - the chore//docs/ exemption is size-capped
#   - the reviewer is judged against BASE versions of the rules and the plan
#   - an unreadable plan fails loudly rather than producing an empty table
#
# Requires: copier on PATH (uv tool install copier).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TEMPLATE="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== gates (rendered project) ==="

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

copier copy --defaults --trust --quiet \
  --data project_name="Demo App" \
  --data language=python \
  --data code_owner="@grimsverk" \
  "$TEMPLATE" "$WORK/repo" >/dev/null 2>&1 \
  || { no "template renders"; summary; exit 1; }
ok "template renders"

R="$WORK/repo"
init_repo "$R"
git -C "$R" add -A && git -C "$R" commit -qm "scaffold"

mkdir -p "$R/docs/plans"
cat > "$R/docs/plans/draft-saving.md" <<'EOF'
---
slug: draft-saving
status: draft
covers: [R1]
---
# Draft saving — Plan

## Slice 1 — saves a draft
- **Delivers:** a draft round-trips to disk
- **Files:** `src/demo_app/store.py`, `tests/test_store.py`
- **Estimate:** ~40 lines
EOF
git -C "$R" add -A && git -C "$R" commit -qm "Add the draft-saving plan"
BASE="$(git -C "$R" rev-parse HEAD)"

resolve() { # resolve <branch>
  ( cd "$R" && BASE_SHA="$BASE" HEAD_REF="$1" .github/scripts/plan-resolve.sh 2>&1 )
}
on_branch() { git -C "$R" switch -q main && git -C "$R" switch -qc "$1"; }
commit_all() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

# ------------------------------------- plan at base, slug matches -> resolves
on_branch feat/draft-saving
echo "x = 1" > "$R/src/demo_app/store.py"; commit_all work
out="$(resolve feat/draft-saving)"; rc=$?
expect_rc "resolves when the plan is at base" 0 $rc
expect_contains "prints the plan path" "$out" "docs/plans/draft-saving.md"

# ----------------------------- plan introduced by the same PR -> hard failure
on_branch feat/late-plan
cat > "$R/docs/plans/late-plan.md" <<'EOF'
---
slug: late-plan
---
# Late — Plan
## Slice 1 — thing
- **Files:** `src/demo_app/late.py`
- **Estimate:** ~10 lines
EOF
echo "y = 2" > "$R/src/demo_app/late.py"; commit_all "plan and code together"
out="$(resolve feat/late-plan)"
expect_rc "rejects a plan introduced by its own PR" 1 $?
expect_contains "explains why" "$out" "does not exist at this pull request's base commit"

# ------------------------------------------------ small chore branch -> exempt
on_branch chore/typo
printf 'a tiny fix\n' >> "$R/README.md"; commit_all typo
out="$(resolve chore/typo)"
expect_rc "small chore branch is exempt" 0 $?
expect_contains "reports the exemption" "$out" "no plan required"

# ------------------------------------------------- oversized chore -> capped
on_branch chore/sneaky
seq 1 120 > "$R/src/demo_app/sneaky.py"; commit_all "real work, chore prefix"
out="$(resolve chore/sneaky)"
expect_rc "oversized chore branch is capped" 1 $?
expect_contains "names the cap" "$out" "claims the exempt prefix"

# -------------------------------------------------- unmatched slug -> failure
on_branch feat/unrelated
echo "z = 3" > "$R/src/demo_app/z.py"; commit_all work
resolve feat/unrelated >/dev/null 2>&1
expect_rc "unmatched branch still fails" 1 $?

# ------------------------------- metrics use the BASE plan, not the edited one
git -C "$R" switch -q feat/draft-saving
sed -i 's/~40 lines/~4000 lines/' "$R/docs/plans/draft-saving.md"
seq 1 200 >> "$R/src/demo_app/store.py"
commit_all "inflate the estimate"
out="$( cd "$R" && BASE_SHA="$BASE" HEAD_SHA="$(git rev-parse HEAD)" \
  .github/scripts/plan-metrics.sh docs/plans/draft-saving.md 2>&1 )"
expect_contains "labels the plan as base-commit" "$out" "as of the base commit"
expect_contains "uses the base estimate, not the inflated one" "$out" "40"
expect_not_contains "ignores the inflated estimate" "$out" "4000"
expect_contains "still flags the overrun" "$out" "OVER"

# ------------------------------------ an unreadable plan fails LOUD, not empty
git -C "$R" switch -q main
cat > "$R/docs/plans/broken.md" <<'EOF'
---
slug: broken-plan
---
# Broken — Plan
## Slice 1 — thing
* **Files:** src/demo_app/b.py
EOF
commit_all "Add a malformed plan"
BASE2="$(git -C "$R" rev-parse HEAD)"
git -C "$R" switch -qc feat/broken-plan
echo "b = 1" > "$R/src/demo_app/b.py"; commit_all work
out="$( cd "$R" && BASE_SHA="$BASE2" HEAD_SHA="$(git rev-parse HEAD)" \
  .github/scripts/plan-metrics.sh docs/plans/broken.md 2>&1 )"
expect_contains "malformed plan produces a loud failure" "$out" "PLAN PARSE FAILED"
expect_contains "says the gate stopped working" "$out" "gate that stopped working"

# ------------------------- reviewer sees BASE rules, not the PR's edited ones
git -C "$R" switch -q main
printf 'PLACEHOLDER-RULE: tests are mandatory\n' >> "$R/AGENTS.md"
commit_all "Add a rule at base"
BASE3="$(git -C "$R" rev-parse HEAD)"
git -C "$R" switch -qc feat/rulebreak
sed -i '/PLACEHOLDER-RULE/d' "$R/AGENTS.md"
echo "q = 4" > "$R/src/demo_app/q.py"
commit_all "Delete the rule this change violates"
mkdir -p "$WORK/bin"
cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat > "$REVIEW_PAYLOAD"
echo "REVIEW_VERDICT: PASS"
STUB
chmod +x "$WORK/bin/claude"
( cd "$R" && PATH="$WORK/bin:$PATH" REVIEW_PAYLOAD="$WORK/payload.txt" \
  BASE_SHA="$BASE3" HEAD_SHA="$(git rev-parse HEAD)" HEAD_REF=feat/rulebreak \
  .github/scripts/review.sh >/dev/null 2>&1 )
payload="$(cat "$WORK/payload.txt" 2>/dev/null || echo "")"
expect_contains "reviewer sees the base rule the PR deleted" "$payload" "PLACEHOLDER-RULE"
expect_contains "payload labels its sources" "$payload" "as of the base commit"
expect_contains "payload carries the facts region" "$payload" "MECHANICAL FACTS"
expect_contains "payload carries blind-test facts" "$payload" "blind-test authorship"

summary
