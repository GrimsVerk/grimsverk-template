#!/usr/bin/env bash
#
# unattended-ready.sh — fixture tests against a STUB gh.
#
# The check exists because every unattended failure lived in repository
# configuration no file can reach; these tests pin that it actually refuses on
# each such condition. The stub answers each endpoint from environment
# variables, so every repository state the check must distinguish can be
# manufactured.
#
# Merge identity used to be a NOTE here, on the reasoning that its absence only
# delayed branch cleanup. That was wrong, and the tests below now pin the
# opposite: the App is the only way the unattended driver gets a login that is
# not the owner's, and without one `owner-authored.sh` compares the owner to the
# owner and passes for every driver-opened pull request — so docs/DESIGN.md and
# docs/VISION.md are unprotected for the whole run while the check prints a
# guarantee it is not holding. A PAT fails for the same reason: it also acts as
# the owner.

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
      {"context": "template-sync"}, {"context": "test-the-tests"},
      {"context": "acceptance-criteria"}, {"context": "review"}
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

# The App is the driver's IDENTITY, not a branch-cleanup convenience: without a
# login that is not the owner's, owner-authored.sh compares the owner to the
# owner and passes, so the design and vision documents are unprotected for the
# whole unattended run. That is why both of these refuse rather than note.
ready_env
STUB_SECRETS=$'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN'
out="$(run)"; expect_rc "no merge identity refuses" 1 $?
expect_contains "and names the check it would hollow out" "$out" "owner-authored.sh"
expect_contains "and says the driver would act as the owner" "$out" "as you"

ready_env
STUB_SECRETS=$'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN\nAUTO_MERGE_TOKEN'
out="$(run)"; expect_rc "a PAT merge identity refuses too — a PAT is also the owner" 1 $?
expect_contains "and says the PAT acts as the owner" "$out" "acts as YOU"

ready_env
STUB_SECRETS=$'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN\nAPP_ID\nAPP_PRIVATE_KEY'
out="$(run)"; expect_rc "the App identity passes" 0 $?
expect_contains "and says why it is the right one" "$out" "not the owner's"

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
