#!/usr/bin/env bash
#
# unattended-ready.sh — fixture tests against a STUB gh.
#
# The check exists because every unattended failure lived in repository
# configuration no file can reach; these tests pin that it actually refuses on
# each such condition, and that the designed fallbacks (no merge identity) are
# notes rather than refusals. The stub answers each endpoint from environment
# variables, so every repository state the check must distinguish can be
# manufactured.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/unattended-ready.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== unattended-ready.sh ==="

# ------------------------------------------------------------------ stub gh
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
args="$*"
case "$args" in
  "repo view --json nameWithOwner --jq .nameWithOwner")
    echo "own/repo" ;;
  "api repos/own/repo/rulesets --jq .[].id")
    [[ -n "${STUB_RULESET_IDS:-}" ]] && printf '%s\n' "$STUB_RULESET_IDS" ;;
  "api repos/own/repo/rulesets/"*)
    printf '%s' "${STUB_RULESET_DETAIL:-}" ;;
  "api repos/own/repo/codeowners/errors --jq .errors | length")
    printf '%s\n' "${STUB_CO_ERRORS:-0}" ;;
  "api repos/own/repo")
    printf '%s' "${STUB_SETTINGS:-}" ;;
  "secret list")
    [[ -n "${STUB_SECRETS:-}" ]] && printf '%s\n' "$STUB_SECRETS" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$WORK/bin/gh"

# ------------------------------------------------------- a ready fixture repo
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/.github/workflows" "$R/docs"
cat > "$R/.copier-answers.yml" <<'EOF'
_src_path: gh:example/template
language: python
auto_merge: true
EOF
touch "$R/.github/workflows/auto-merge.yml"
cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## What it's for

Finding things.

## Priorities in order

Speed, then cost.
EOF

# The all-green environment; each scenario below perturbs exactly one thing.
# The JSON lives in single-quoted strings that cross the environment into the
# stub as data, never re-parsed by a shell — the SC2089/90 warning about
# quotes-as-literals describes exactly the behaviour wanted here.
# shellcheck disable=SC2089,SC2090
ready_env() {
  STUB_SETTINGS='{"allow_auto_merge": true, "delete_branch_on_merge": true}'
  STUB_RULESET_IDS="1"
  STUB_RULESET_DETAIL='{"enforcement": "active", "rules": [
    {"type": "deletion"}, {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {"required_approving_review_count": 0}},
    {"type": "required_status_checks", "parameters": {"required_status_checks": [
      {"context": "checks"}, {"context": "secrets"}, {"context": "plan"},
      {"context": "template-sync"}, {"context": "test-the-tests"}, {"context": "review"}
    ]}}]}'
  STUB_SECRETS=$'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN\nAPP_ID\nAPP_PRIVATE_KEY'
  STUB_CO_ERRORS="0"
  export STUB_SETTINGS STUB_RULESET_IDS STUB_RULESET_DETAIL STUB_SECRETS STUB_CO_ERRORS
}

run() { (cd "$R" && GH="$WORK/bin/gh" "$CHECK" 2>&1); }

# ------------------------------------------------------------------- scenarios
ready_env
out="$(run)"; expect_rc "a fully configured repository is ready" 0 $?
expect_contains "and says so" "$out" "can run unattended"
expect_contains "App identity is recognised" "$out" "GitHub App configured"

ready_env
STUB_SETTINGS='{"allow_auto_merge": false, "delete_branch_on_merge": true}'
out="$(run)"; expect_rc "auto-merge off on the repository refuses" 1 $?
expect_contains "and names the setting" "$out" "Allow auto-merge"

ready_env
STUB_RULESET_DETAIL="${STUB_RULESET_DETAIL/\{\"context\": \"review\"\}/\{\"context\": \"reviews\"\}}"
out="$(run)"; expect_rc "a drifted required-check name refuses" 1 $?
expect_contains "and names the missing check" "$out" "check 'review' is not required"

ready_env
STUB_RULESET_DETAIL="${STUB_RULESET_DETAIL/active/evaluate}"
out="$(run)"; expect_rc "an evaluate-mode ruleset counts as absent" 1 $?

ready_env
STUB_RULESET_IDS=""
out="$(run)"; expect_rc "no rulesets refuses" 1 $?
expect_contains "and points at the bootstrap" "$out" "setup-github.sh"

ready_env
STUB_SECRETS=$'TEMPLATE_TOKEN\nAPP_ID\nAPP_PRIVATE_KEY'
out="$(run)"; expect_rc "a missing review credential refuses" 1 $?
expect_contains "and says the gate fails closed" "$out" "fails closed"

ready_env
STUB_SECRETS=$'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN'
out="$(run)"; expect_rc "no merge identity is a note, not a refusal" 0 $?
expect_contains "and explains the sweep fallback" "$out" "nightly sweep"

ready_env
STUB_CO_ERRORS="2"
out="$(run)"; expect_rc "unresolvable CODEOWNERS refuses" 1 $?
expect_contains "and says why it is fatal" "$out" "review requirement"

ready_env
printf '\n## What I would trade away\n\n' >> "$R/docs/VISION.md"
out="$(run)"; expect_rc "an unfilled vision section refuses" 1 $?
expect_contains "and names the section" "$out" "What I would trade away"
git -C "$R" checkout -q -- docs/VISION.md 2>/dev/null || \
  sed -i '/## What I would trade away/,$d' "$R/docs/VISION.md"

ready_env
sed -i 's/^auto_merge: true/auto_merge: false/' "$R/.copier-answers.yml"
out="$(run)"; expect_rc "auto_merge: false in the answers refuses" 1 $?
expect_contains "and says nothing merges" "$out" "nothing merges unattended"
sed -i 's/^auto_merge: false/auto_merge: true/' "$R/.copier-answers.yml"

summary
