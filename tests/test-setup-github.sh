#!/usr/bin/env bash
#
# setup-github.sh — fixture tests against a RECORDING stub gh.
#
# The script's whole job is the shape of its API calls, so the stub records
# every argv line and captures every stdin payload, and the assertions read
# those back: the ruleset JSON says what the README says (approvals 0 PLUS
# code-owner review, active, default-branch pointer, NO linear-history rule),
# secrets travel over stdin and never appear in an argument list, and a second
# run updates the existing ruleset instead of stacking a duplicate — two
# rulesets' rules UNION, which is how a stale one keeps an old check required
# forever.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SETUP="$HERE/../template/scripts/setup-github.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== setup-github.sh ==="

# ---------------------------------------------------------- stub gh (records)
mkdir -p "$WORK/bin" "$WORK/cap"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
args="$*"
case "$args" in
  "auth status") exit 0 ;;
  "repo view --json nameWithOwner --jq .nameWithOwner") echo "own/repo" ;;
  "api user --jq .login") echo "own" ;;
  "api repos/own/repo/rulesets --jq "*)
    [[ -n "${STUB_EXISTING_ID:-}" ]] && echo "$STUB_EXISTING_ID" ;;
  "secret set "*) cat > "$GH_CAP/secret-$3" ;;
  "api -X POST repos/own/repo/rulesets --input -") cat > "$GH_CAP/ruleset-post.json" ;;
  "api -X PUT repos/own/repo/rulesets/"*) cat > "$GH_CAP/ruleset-put.json" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"

# ------------------------------------------------------------- fixture repo
R="$WORK/repo"
init_repo "$R"
git -C "$R" remote add origin "https://github.com/own/repo.git"
cat > "$R/.copier-answers.yml" <<'EOF'
_src_path: gh:example/template
language: python
EOF

run_setup() { # run_setup <stdin-file-or-/dev/null> [args...]
  local stdin="$1"; shift
  ( cd "$R" && GH="$WORK/bin/gh" GH_LOG="$WORK/cap/gh.log" GH_CAP="$WORK/cap" \
      bash "$SETUP" "$@" < "$stdin" 2>&1 )
}

# ---------------------------------------------- run 1: everything already set
: > "$WORK/cap/gh.log"
export STUB_SECRETS="ignored"  # secrets presence comes from `secret list`, below
cat > "$WORK/bin/secretlist.txt" <<'EOF'
CLAUDE_CODE_OAUTH_TOKEN
TEMPLATE_TOKEN
AUTO_MERGE_TOKEN
EOF
# Teach the stub to answer `secret list` from a file the scenarios can rewrite.
sed -i 's|"auth status") exit 0 ;;|"auth status") exit 0 ;;\n  "secret list") cat "$STUB_SECRET_LIST" 2>/dev/null ;;|' "$WORK/bin/gh"
export STUB_SECRET_LIST="$WORK/bin/secretlist.txt"

out="$(run_setup /dev/null)"
expect_rc "runs clean with everything already configured" 0 $?
log="$(cat "$WORK/cap/gh.log")"
expect_contains "merge settings are PATCHed" "$log" "api -X PATCH repos/own/repo"
expect_contains "auto-merge is enabled" "$log" "allow_auto_merge=true"
expect_contains "merge commits are asserted, not assumed" "$log" "allow_merge_commit=true"
expect_contains "branch deletion on merge is enabled" "$log" "delete_branch_on_merge=true"
expect_contains "existing secrets are left alone" "$out" "already set, leaving it alone"
expect_not_contains "no secret value was prompted for" "$out" "Paste the value"

rs="$(cat "$WORK/cap/ruleset-post.json" 2>/dev/null)"
expect_contains "ruleset is created" "$log" "api -X POST repos/own/repo/rulesets --input -"
expect_contains "ruleset targets the default branch by pointer" "$rs" "~DEFAULT_BRANCH"
expect_contains "ruleset is ACTIVE, not evaluate" "$rs" '"enforcement": "active"'
expect_contains "approvals are 0" "$rs" '"required_approving_review_count": 0'
expect_contains "code-owner review is required" "$rs" '"require_code_owner_review": true'
expect_contains "force pushes are blocked" "$rs" '"type": "non_fast_forward"'
expect_contains "deletions are blocked" "$rs" '"type": "deletion"'
expect_not_contains "linear history is NOT required — it breaks 'git revert -m 1'" \
  "$rs" "linear_history"
for ctx in checks secrets plan template-sync test-the-tests acceptance-criteria review; do
  expect_contains "ruleset requires '$ctx'" "$rs" "\"context\": \"$ctx\""
done

# ------------------------------------------- run 2: ruleset exists, so update
: > "$WORK/cap/gh.log"
export STUB_EXISTING_ID=42
run_setup /dev/null >/dev/null
log="$(cat "$WORK/cap/gh.log")"
expect_contains "an existing ruleset is updated in place" "$log" \
  "api -X PUT repos/own/repo/rulesets/42 --input -"
unset STUB_EXISTING_ID

# --------------------------------- run 3: secrets missing, values over stdin
: > "$WORK/cap/gh.log"
: > "$STUB_SECRET_LIST"
printf 'tok-claude-123\ntok-template-456\n\n' > "$WORK/cap/answers.txt"
out="$(run_setup "$WORK/cap/answers.txt")"
expect_rc "prompts for the missing secrets" 0 $?
log="$(cat "$WORK/cap/gh.log")"
if [[ "$(cat "$WORK/cap/secret-CLAUDE_CODE_OAUTH_TOKEN" 2>/dev/null)" == "tok-claude-123" ]]; then
  ok "the review credential reaches gh over stdin"
else
  no "the review credential reaches gh over stdin"
fi
expect_not_contains "the value appears in NO argument list" "$log" "tok-claude-123"
expect_not_contains "and is never echoed" "$out" "tok-claude-123"
expect_contains "an empty line skips an optional secret" "$out" "AUTO_MERGE_TOKEN: skipped"

# --------------------------------------------------- run 4: swift-ios context
sed -i 's/^language: python/language: swift-ios/' "$R/.copier-answers.yml"
rm -f "$WORK/cap/ruleset-post.json"
printf 'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN\nAUTO_MERGE_TOKEN\n' > "$STUB_SECRET_LIST"
run_setup /dev/null >/dev/null
rs="$(cat "$WORK/cap/ruleset-post.json" 2>/dev/null)"
expect_contains "swift-ios requires 'test' instead of 'checks'" "$rs" '"context": "test"'
expect_not_contains "and does not require 'checks'" "$rs" '"context": "checks"'

summary
