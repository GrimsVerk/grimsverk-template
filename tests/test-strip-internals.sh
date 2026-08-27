#!/usr/bin/env bash
#
# test-strip-internals.sh — spawn-worker.sh --strip-internals, written blind
# from slice 1 of docs/plans/design-hardening-loop.md. The base spawn-worker.sh
# exists and is already tested (tests/test-spawn-worker.sh); the flag under
# test here did NOT exist when this was written, so a red run is the expected
# state.
#
# --strip-internals <plan-path> makes the blind-test exclusion STRUCTURAL: a
# test-writer's worktree copy of the plan is replaced, before its engine runs,
# with plan-contracts.sh output — the plan minus every ### Internals section —
# so the test author cannot read the guts even by accident. The flag is only
# valid with --role test-writer (any other role is refused before a worktree
# exists), the replacement is left uncommitted in the worktree, the main
# tree's copy is untouched, and a plan path that does not exist in the
# worktree fails loudly by name.
#
# Same stub recipe as tests/test-spawn-worker.sh, with one addition: the fake
# engine copies the plan it can see into a committed artifact, so WHAT the
# worker saw — and when — is provable from the branch afterwards.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Runs from tests/ or tests/blind/.
if [[ -f "$HERE/lib.sh" ]]; then
  # shellcheck source=tests/lib.sh
  source "$HERE/lib.sh"
  ROOT="$HERE/.."
else
  # shellcheck source=tests/lib.sh
  source "$HERE/../lib.sh"
  ROOT="$HERE/../.."
fi

SPAWN="$ROOT/template/.claude/scripts/spawn-worker.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== spawn-worker.sh --strip-internals ==="

# expect_nonzero <description> <rc> — the contract fixes "non-zero", not which.
expect_nonzero() {
  if [[ "$2" -ne 0 ]]; then ok "$1"; else no "$1" "expected a non-zero exit, got 0"; fi
}

# The stub engine: answers the auth probe, then records the plan file exactly
# as the worker would see it and commits ONLY that record — so the stripped
# plan itself stays uncommitted, as the contract says it must be left.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "login status"|"auth status") echo '{"loggedIn": true}'; exit 0 ;;
esac
if [[ -f docs/plans/fixture.md ]]; then
  cp docs/plans/fixture.md observed-plan.md
else
  echo "MISSING PLAN" > observed-plan.md
fi
git add observed-plan.md >/dev/null 2>&1
git commit -qm "Record the plan the worker saw" >/dev/null 2>&1
exit 0
STUB
chmod +x "$WORK/bin/claude"

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans"
cat > "$R/docs/plans/fixture.md" <<'EOF'
---
format: pseudocode
---

# Fixture plan

## Summary

one line

## Rulings

Rulings: none

## Slice 1 — the fixture behaviour

- **Delivers:** the fixture behaviour.
- **Estimate:** ~10 lines

### Signatures

SIG-MARKER-alpha(x) -> y

### Internals

GUTS-MARKER-omega: loop and cache
EOF
git -C "$R" add -A && git -C "$R" commit -qm "seed with a pseudocode plan"

spawn() { ( cd "$R" && PATH="$WORK/bin:$PATH" "$SPAWN" "$@" 2>&1 ); }

# ------------- 1: the flag is test-writer-only, refused before any worktree
out="$(spawn --id wr-1 --prompt hi --engine claude --role coder \
  --strip-internals docs/plans/fixture.md)"
rc=$?
expect_nonzero "--strip-internals with --role coder is refused" "$rc"
expect_contains "and the refusal names the flag" "$out" "--strip-internals"
# Once the flag exists, "unknown argument" would mean the parser never learned
# it — a different failure wearing the right exit code.
expect_not_contains "as a role restriction, not an unknown argument" "$out" \
  "unknown argument"
if [[ -e "$R/.worktrees/wr-1" ]]; then
  no "no worktree is created for the refused combination"
else ok "no worktree is created for the refused combination"; fi
if git -C "$R" show-ref --verify --quiet refs/heads/worker/wr-1; then
  no "and no branch either"
else ok "and no branch either"; fi

# ------------- 2: a test-writer's worktree copy is stripped, before the run
out="$(spawn --id tw-1 --prompt "write the tests" --engine claude \
  --role test-writer --strip-internals docs/plans/fixture.md)"
expect_rc "a test-writer spawn with --strip-internals succeeds" 0 $?

WT="$R/.worktrees/tw-1"
if [[ -f "$WT/docs/plans/fixture.md" ]]; then
  wt_plan="$(cat "$WT/docs/plans/fixture.md")"
  expect_not_contains "the worktree copy carries no ### Internals heading" \
    "$wt_plan" "### Internals"
  expect_not_contains "nor the internals body" "$wt_plan" "GUTS-MARKER-omega"
  expect_contains "and keeps its Signatures" "$wt_plan" "SIG-MARKER-alpha"
else
  no "the worktree copy carries no ### Internals heading" \
    "no plan file at .worktrees/tw-1/docs/plans/fixture.md"
  no "nor the internals body"
  no "and keeps its Signatures"
fi

# The stub copied the plan DURING the run, so this pins the ordering: the
# strip happened after worktree creation and before the engine started, which
# is the only ordering under which the exclusion is structural.
seen="$(git -C "$R" show worker/tw-1:observed-plan.md 2>&1)"
expect_not_contains "the engine itself saw a plan with no guts" "$seen" \
  "GUTS-MARKER-omega"
expect_contains "and with its contract intact" "$seen" "SIG-MARKER-alpha"

expect_contains "the main tree's copy is untouched" \
  "$(cat "$R/docs/plans/fixture.md")" "GUTS-MARKER-omega"

status="$(git -C "$WT" status --porcelain 2>&1)"
expect_contains "the strip is left uncommitted in the worktree" "$status" \
  "docs/plans/fixture.md"
expect_contains "and the worktree's committed history still carries the full plan" \
  "$(git -C "$WT" show HEAD:docs/plans/fixture.md 2>&1)" "GUTS-MARKER-omega"

# ------------- 3: a plan path missing from the worktree fails loudly, by name
out="$(spawn --id mf-1 --prompt hi --engine claude --role test-writer \
  --strip-internals docs/plans/no-such.md)"
rc=$?
expect_nonzero "a plan path absent from the worktree fails" "$rc"
expect_contains "and the failure names the path" "$out" "docs/plans/no-such.md"

# ------------- 4: no flag, no strip — the flag is the switch, not the role
out="$(spawn --id nf-1 --prompt hi --engine claude --role test-writer)"
expect_rc "a test-writer spawn without the flag still succeeds" 0 $?
expect_contains "and its worker saw the plan guts and all" \
  "$(git -C "$R" show worker/nf-1:observed-plan.md 2>&1)" "GUTS-MARKER-omega"

summary
