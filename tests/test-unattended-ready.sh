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
  "api repos/own/repo/rulesets --jq .[].id")
    [[ -n "${STUB_RULESET_IDS:-}" ]] && printf '%s\n' "$STUB_RULESET_IDS" ;;
  "api repos/own/repo/rulesets/"*)
    printf '%s' "${STUB_RULESET_DETAIL:-}" ;;
  "api repos/own/repo/rules/branches/"*)
    printf '%s' "${STUB_BRANCH_RULES:-}" ;;
  "api repos/own/repo/codeowners/errors"*)
    # Records the query so the ref can be asserted; fails like the real API
    # when told to — body on stdout, non-zero exit — which is exactly the
    # shape ESC-48's defect mistook for a line count.
    echo "$args" >> "${GH_CO_LOG:-/dev/null}"
    if [[ "${STUB_CO_FAIL:-0}" == "1" ]]; then
      printf '{"message":"Not Found","status":"404"}\n'; exit 1
    fi
    printf '%s\n' "${STUB_CO_ERRORS:-0}" ;;
  "api repos/own/repo")
    printf '%s' "${STUB_SETTINGS:-}" ;;
  "secret list")
    [[ -n "${STUB_SECRETS:-}" ]] && printf '%s\n' "$STUB_SECRETS" ;;
  "api repos/own/repo/pulls?state=open&base="*)
    # ESC-72: a run must not start into a base that already carries an open
    # pull request — the driver's first act would be to wait on it.
    [[ -n "${STUB_OPEN_ON_BASE:-}" ]] && printf '%s\n' "$STUB_OPEN_ON_BASE" ;;
  "api user")
    # The ambient-credential liveness probe — `gh api user`, never `gh auth
    # status`, which lies on the hosted platform (ESC-52). Off by default: a
    # runtime session's gh works only when a platform injects a credential
    # (ESC-50), and most scenarios model no platform.
    [[ "${STUB_AUTH_OK:-0}" == "1" ]] ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$WORK/bin/gh"

# ------------------------------------------------------- a ready fixture repo
R="$WORK/repo"
init_repo "$R"
# The check resolves owner/repo from the origin remote, not `gh repo view` —
# repo view is GraphQL, which hosted sessions refuse (ESC-51).
git -C "$R" remote add origin https://github.com/own/repo.git
mkdir -p "$R/.github/workflows" "$R/docs"
cat > "$R/.copier-answers.yml" <<'EOF'
_src_path: gh:example/template
language: python
auto_merge: true
EOF
touch "$R/.github/workflows/auto-merge.yml"
# Rendered projects carry the server-side PR opener (ESC-50); one --runtime
# scenario below removes it to pin the refusal for scaffolds that predate it.
touch "$R/.github/workflows/open-pr.yml"
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
  STUB_SETTINGS='{"allow_auto_merge": true, "delete_branch_on_merge": true, "default_branch": "main"}'
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
  # What the effective-rules endpoint answers for a lane base branch that the
  # ruleset covers: the same pull_request rule and required checks, resolved.
  # shellcheck disable=SC2089
  STUB_BRANCH_RULES='[{"type": "pull_request", "parameters": {}},
    {"type": "required_status_checks", "parameters": {"required_status_checks": [
      {"context": "checks"}, {"context": "secrets"}, {"context": "plan"},
      {"context": "template-sync"}, {"context": "test-the-tests"},
      {"context": "acceptance-criteria"}, {"context": "review"}
    ]}}]'
  export STUB_SETTINGS STUB_RULESET_IDS STUB_RULESET_DETAIL STUB_SECRETS \
         STUB_CO_ERRORS STUB_BRANCH_RULES
}

run() { (cd "$R" && GH="$WORK/bin/gh" "$CHECK" 2>&1); }

# ------------------------------------------------------------------- scenarios
ready_env
out="$(run)"; expect_rc "a fully configured repository is ready" 0 $?
expect_contains "and says so" "$out" "can run unattended"
expect_contains "App identity is recognised" "$out" "GitHub App configured"
expect_contains "and the template-repo install is noted (no PAT path exists)" \
  "$out" "installed on the TEMPLATE repository"

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
out="$(run)"; expect_rc "a leftover PAT is no merge identity — still refuses" 1 $?
expect_contains "and says there is deliberately no PAT path" "$out" "no PAT alternative"

ready_env
STUB_SECRETS=$'CLAUDE_CODE_OAUTH_TOKEN\nTEMPLATE_TOKEN\nAPP_ID\nAPP_PRIVATE_KEY'
out="$(run)"; expect_rc "the App identity passes" 0 $?
expect_contains "and says why it is the right one" "$out" "not the owner's"

# ---------------------------------------------- the run's base branch (lanes)
# A run based on a non-default branch (deliver-loop.sh --base) exports
# RUN_BASE. The union check above cannot see whether the gates bind on THAT
# branch, so the check reads the branch's effective rules — and refuses when
# nothing binds there, because auto-merge on an unprotected base waits for
# nothing.
run_base() { (cd "$R" && GH="$WORK/bin/gh" RUN_BASE="$1" "$CHECK" 2>&1); }

ready_env
out="$(run_base run/web)"; expect_rc "a gated lane base branch is ready" 0 $?
expect_contains "and both bindings are read from the branch itself" "$out" \
  "base branch 'run/web': pull-request rule binds"

ready_env
STUB_BRANCH_RULES=""
out="$(run_base run/web)"; expect_rc "an unruled lane base branch refuses" 1 $?
expect_contains "and names the fix" "$out" "--gate-branch"

ready_env
STUB_BRANCH_RULES="${STUB_BRANCH_RULES/\{\"context\": \"review\"\}/\{\"context\": \"reviews\"\}}"
out="$(run_base run/web)"; expect_rc "a lane missing one required check refuses" 1 $?
expect_contains "and names the check and the branch" "$out" \
  "check 'review' is not required on the run's base branch 'run/web'"

ready_env
out="$(run_base main)"; expect_rc "RUN_BASE equal to the default branch adds no check" 0 $?

# ------------------------------------------------------------- --runtime mode
# A web-session driver's gh holds an App token, which cannot read secrets or
# rulesets. --runtime checks what that identity honestly can: the App minting,
# the effective rules on its base branch, and the documents — and does NOT
# refuse over the admin reads it cannot perform.
cat > "$WORK/bin/app-ok"  <<'APPSTUB'
#!/usr/bin/env bash
echo ghs_stubtoken
APPSTUB
cat > "$WORK/bin/app-bad" <<'APPSTUB'
#!/usr/bin/env bash
echo "no App identity (stub)" >&2; exit 3
APPSTUB
chmod +x "$WORK/bin/app-ok" "$WORK/bin/app-bad"
run_rt() { # run_rt <app-stub> [NAME=value ...]
  local stub="$1"; shift
  (cd "$R" && env GH="$WORK/bin/gh" READY_APP_TOKEN_CMD="$WORK/bin/$stub" "$@" \
    "$CHECK" --runtime 2>&1)
}

ready_env
out="$(run_rt app-ok RUN_BASE=run/web)"
expect_rc "--runtime with a minting App and gated base is ready" 0 $?
expect_contains "the identity is proven by minting, not by a secret's name" \
  "$out" "mints a token"
expect_contains "and the base branch rules are read from the branch" "$out" \
  "base branch 'run/web': pull-request rule binds"

ready_env
STUB_SECRETS=""
STUB_RULESET_IDS=""
out="$(run_rt app-ok RUN_BASE=run/web)"
expect_rc "--runtime does not refuse over admin reads it cannot perform" 0 $?
expect_contains "and says whose job the full check is" "$out" "the full check's job"

ready_env
out="$(run_rt app-bad RUN_BASE=run/web)"
expect_rc "--runtime refuses when the App cannot mint and gh has no login" 1 $?
expect_contains "and names both failures" "$out" "no GitHub identity works here"

# ESC-50: a hosted platform's proxy owns the credential — the mint fails
# there by design while gh works anyway. That is a supported identity, IF the
# scaffold carries the server-side opener that keeps pull requests
# App-authored; without the opener it is a refusal, not a shrug.
ready_env
out="$(run_rt app-bad RUN_BASE=run/web STUB_AUTH_OK=1)"
expect_rc "--runtime accepts the ambient login when the opener exists (ESC-50)" 0 $?
expect_contains "and says how pull requests stay App-authored" "$out" \
  "open-pr workflow"

ready_env
rm "$R/.github/workflows/open-pr.yml"
out="$(run_rt app-bad RUN_BASE=run/web STUB_AUTH_OK=1)"
expect_rc "--runtime refuses the ambient login when the opener is missing" 1 $?
expect_contains "and names the missing workflow" "$out" \
  ".github/workflows/open-pr.yml"
touch "$R/.github/workflows/open-pr.yml"

ready_env
out="$(run_rt app-ok)"
expect_rc "--runtime without RUN_BASE falls back to the default branch" 0 $?
expect_contains "and still verifies its rules" "$out" "base branch 'main'"

# ESC-72: an open pull request on the run's base refuses the run BEFORE it
# starts, rather than stalling it at exit 4 ten minutes in. A template update
# always waits for the owner's review, because it edits the gates themselves.
# ESC-73: a private repository's rulesets may be configured and not binding.
ready_env
STUB_SETTINGS='{"allow_auto_merge": true, "delete_branch_on_merge": true, "default_branch": "main", "private": true}'
out="$(run)"; expect_rc "a private repository is still ready" 0 $?
expect_contains "but says the gates may not bind at all (ESC-73)" "$out" "NOT binding"

ready_env
export STUB_OPEN_ON_BASE="#42 template/v0.4.40"
out="$(run)"; expect_rc "an open pull request on the base refuses the run (ESC-72)" 1 $?
expect_contains "and names it" "$out" "#42 template/v0.4.40"
expect_contains "and says who has to clear it" "$out" "YOUR review"
unset STUB_OPEN_ON_BASE

ready_env
out="$(run)"; expect_rc "a clear base is ready" 0 $?
expect_contains "and says the base is clear" "$out" "starts on a clear base"

ready_env
STUB_CO_ERRORS="2"
out="$(run)"; expect_rc "unresolvable CODEOWNERS refuses" 1 $?
expect_contains "and says why it is fatal" "$out" "review requirement"

# ESC-48: the CODEOWNERS probe follows the run's base branch, and an API
# failure is the cannot-read note — never a raw error body inside a refusal.
ready_env
: > "$WORK/co.log"
out="$( (cd "$R" && env GH="$WORK/bin/gh" GH_CO_LOG="$WORK/co.log" RUN_BASE=run/web "$CHECK" 2>&1) )"
expect_rc "CODEOWNERS is judged at the run's base branch" 0 $?
expect_contains "the query carries the ref" "$(cat "$WORK/co.log")" "?ref=run/web"
expect_contains "and the verdict names where it looked" "$out" "at run/web"

ready_env
: > "$WORK/co.log"
out="$( (cd "$R" && env GH="$WORK/bin/gh" GH_CO_LOG="$WORK/co.log" "$CHECK" 2>&1) )"
expect_contains "without RUN_BASE the ref is the default branch" \
  "$(cat "$WORK/co.log")" "?ref=main"

ready_env
STUB_CO_FAIL=1; export STUB_CO_FAIL
out="$(run)"; expect_rc "a failing CODEOWNERS endpoint does not refuse" 0 $?
expect_contains "it is the designed cannot-read note" "$out" "cannot read CODEOWNERS"
expect_not_contains "and no raw API body leaks into the verdict" "$out" "Not Found"
unset STUB_CO_FAIL

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

# ESC-76: readiness covers what the driver refuses on. This script runs in the
# step immediately before "start your driver", so a startup refusal it cannot
# see arrives minutes later, after the owner has walked away. Observed live on
# a real project: readiness said ready, the driver then refused on leftover
# worktrees from a run that had died mid-dispatch.
ready_env
mkdir -p "$R/.worktrees/oracle-20260820102317"
out="$(run)"; expect_rc "leftover worktrees refuse at readiness (ESC-76)" 1 $?
expect_contains "and the debris is named" "$out" "oracle-20260820102317"
expect_contains "and it says to read them before removing them" "$out" "READ THEM FIRST"
rm -rf "$R/.worktrees"

ready_env
out="$(run)"; expect_rc "a clean tree still passes" 0 $?
expect_contains "and says the debris check ran" "$out" "no leftover worktrees"

# --------------------------------------------------- ESC-207: --start/--health
# Readiness was designed as a START check, and the delivery loop re-ran it at
# every wake as a health check. Two start-time refusals misfired there,
# observed live on a real project: the open-PR refusal (ESC-72) fired on the
# run's OWN pipeline pull request and said "merge or close it first" — advice
# that has the driver destroy its own in-flight work — and the
# leftover-worktree refusal (ESC-76) fired on a LIVE worker's worktree,
# asserted "a previous run died mid-dispatch" as fact, and prescribed the
# removal that would have deleted a plan while it was being written. --health
# is the mid-run question: configuration still refuses, the run's own working
# state does not. --start (the default) keeps the full start behaviour.
run_health() { (cd "$R" && GH="$WORK/bin/gh" "$CHECK" --health 2>&1); }
run_start()  { (cd "$R" && GH="$WORK/bin/gh" "$CHECK" --start  2>&1); }

# An open pull request on the base, mid-run, is the pipeline working — the
# detector calls it WAIT — so --health reports it as a normal state.
ready_env
export STUB_OPEN_ON_BASE="#120 docs/oracle-plan-od-7"
out="$(run_health)"
expect_rc "--health does not refuse on an open pull request (ESC-207)" 0 $?
expect_contains "and reports it as the run working" "$out" "the pipeline working"
expect_not_contains "and never tells the driver to destroy its own work" \
  "$out" "Merge or close it first"
unset STUB_OPEN_ON_BASE

# The identical state still refuses a fresh START, exactly as before — the
# explicit flag spells the default, so both spellings are pinned.
ready_env
export STUB_OPEN_ON_BASE="#42 template/v0.4.40"
out="$(run_start)"
expect_rc "--start (spelled out) still refuses on an open pull request" 1 $?
expect_contains "with the unchanged start-time message" "$out" "Merge or close it first"
unset STUB_OPEN_ON_BASE

# A worktree that holds uncommitted work is, mid-run, a worker (possibly
# RUNNING, exactly the live steward the refusal once fired on) — not debris.
ready_env
mkdir -p "$R/.worktrees/steward-od-7"
echo "plan draft, mid-write" > "$R/.worktrees/steward-od-7/plan.md"
out="$(run_health)"
expect_rc "--health does not refuse on a worktree with uncommitted work (ESC-207)" 0 $?
expect_contains "and says a worker may be running in it" "$out" "may be RUNNING"
expect_contains "and names the live sign it saw" "$out" "uncommitted work"

# The same worktree still refuses a START (the driver would refuse on it too),
# and the message now states the OBSERVATION — a worktree exists — instead of
# asserting a dead run as fact, and never prescribes bare removal.
out="$(run_start)"
expect_rc "--start still refuses on that worktree" 1 $?
expect_contains "and names it" "$out" "steward-od-7"
expect_contains "and still says to read before touching" "$out" "READ THEM FIRST"
expect_not_contains "but no longer asserts a dead run as fact" \
  "$out" "a previous run died mid-dispatch"
expect_contains "it says a live worker leaves the same trace" "$out" "still RUNNING"
expect_contains "and gates removal on what the reading shows" "$out" "Only after reading"
rm -rf "$R/.worktrees"

# The argument line still fails loudly on a typo, naming every mode.
out="$( (cd "$R" && GH="$WORK/bin/gh" "$CHECK" --helth 2>&1) )"
expect_rc "an unknown flag is rejected" 2 $?
expect_contains "and the usage names the health mode" "$out" "--health"

summary
