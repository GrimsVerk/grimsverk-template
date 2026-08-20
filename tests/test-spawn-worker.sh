#!/usr/bin/env bash
#
# spawn-worker.sh — fixture tests against STUB engines.
#
# The orchestration path had four independently fatal faults and shipped with
# all four, because nothing ever ran it: it was first executed at the moment it
# was first needed. The on-demand smoke test (tests/smoke-worker.sh) exercises
# the real CLIs, but it costs subscription budget and cannot run in CI — so the
# script's own logic is pinned here instead, with fake `codex` and `claude`
# binaries on PATH that can be told to commit, to do nothing, to leave work
# uncommitted, to fail, or to report a signed-out account.
#
# What a stub CAN prove: the empty-branch failure, the preflight diagnosis, the
# worktree location, and the exact flags the script passes. What it CANNOT
# prove: that a real engine accepts those flags. That is the smoke test's job,
# and the two are not substitutes for each other.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SPAWN="$HERE/../template/.claude/scripts/spawn-worker.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== spawn-worker.sh ==="

# ------------------------------------------------------------ the stub engine
# One binary serves as both `codex` and `claude`: it answers the auth probe from
# STUB_AUTH_OK and then behaves per STUB_MODE. It runs with the worktree as its
# working directory, exactly as a real engine does.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/codex" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "login status"|"auth status")
    if [[ "${STUB_AUTH_OK:-1}" == "1" ]]; then
      echo '{"loggedIn": true}'; exit 0
    fi
    echo "Not logged in"; exit 1 ;;
esac
case "${STUB_MODE:-commit}" in
  commit)
    echo "worker output" > worker-artifact.txt
    git add -A >/dev/null 2>&1
    git commit -qm "Add the worker artifact" >/dev/null 2>&1
    ;;
  dirty)  echo "half-finished" > worker-artifact.txt ;;
  noop)   : ;;
  fail)   echo "engine blew up" >&2; exit 7 ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/codex"
cp "$WORK/bin/codex" "$WORK/bin/claude"

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/.claude/scripts"
echo "seed" > "$R/README.md"
git -C "$R" add -A && git -C "$R" commit -qm "seed"

spawn() { # spawn <extra args...> — always with the stub engines on PATH
  ( cd "$R" && PATH="$WORK/bin:$PATH" "$SPAWN" "$@" 2>&1 )
}

# ------------------------------------------------------- the assembled command
# --print-command needs no engine and no repository, which is the point: the
# flags are pinned even on a runner that has neither CLI installed. It proves
# the script passes --approve-for-me; only the smoke test proves codex-cli
# accepts it.
out="$("$SPAWN" --id x --prompt hi --engine codex --print-command 2>&1)"
expect_rc "--print-command exits 0 without an engine" 0 $?
expect_contains "codex runs under --approve-for-me" "$out" "--approve-for-me"
expect_not_contains "codex does not use the removed --full-auto" "$out" "--full-auto"
expect_contains "codex runs ephemerally" "$out" "--ephemeral"

out="$("$SPAWN" --id x --prompt hi --engine codex --bypass-sandbox --print-command 2>&1)"
expect_contains "the bypass is still reachable when asked for" "$out" \
  "--dangerously-bypass-approvals-and-sandbox"
expect_not_contains "the bypass is not the default path" "$out" "--approve-for-me"

out="$("$SPAWN" --id x --prompt hi --engine claude --print-command 2>&1)"
expect_contains "claude runs headless" "$out" "-p"

# A bare `claude -p` cannot write anything. A fresh worktree is a workspace
# nobody has trusted, so the project's own settings.json allow list is ignored
# there, and the default permission mode asks for an approval that a headless
# run has nobody to give — the worker says "I need your permission to write that
# file" and exits 0 having done nothing. Observed, not theorised: it is how the
# first live smoke run failed. The grants must come from the command line.
expect_contains "claude may write files" "$out" "acceptEdits"
expect_contains "claude may commit" "$out" "Bash(git commit:*)"
expect_contains "claude may run the python suite" "$out" "Bash(uv run:*)"
expect_not_contains "the default grant is not a bypass" "$out" "--dangerously-skip-permissions"

# --allowed-tools is variadic: it eats every following argument until the next
# flag. If the prompt is left adjacent to it, the prompt is parsed as a tool
# name and the worker receives no instructions at all.
last="$(printf '%s' "$out" | tail -1)"
if [[ "$last" == "hi" ]]; then ok "the prompt survives the variadic tool list"
else no "the prompt survives the variadic tool list" "last argument was: $last"; fi

# A prompt that BEGINS WITH DASHES must reach the engine as a prompt, not die as
# an "unknown option". Every command file opens with YAML frontmatter, so every
# prompt the delivery driver builds from one starts with `---` — and without an
# option terminator before the prompt, the first dispatch of the first
# unattended run failed on exactly this, eight times in thirty seconds, for
# both defined engines' code paths (ESC-37).
for eng in claude codex; do
  out="$("$SPAWN" --id x --prompt '--- looks like a flag' --engine "$eng" --print-command 2>&1)"
  last="$(printf '%s' "$out" | tail -1)"
  before="$(printf '%s' "$out" | tail -2 | head -1)"
  if [[ "$last" == "--- looks like a flag" && "$before" == "--" ]]; then
    ok "a ----leading prompt is terminator-protected ($eng)"
  else
    no "a ----leading prompt is terminator-protected ($eng)" \
      "last two arguments were: $before / $last"
  fi
done

out="$(SPAWN_WORKER_ALLOWED_TOOLS='Bash(just this:*)' \
  "$SPAWN" --id x --prompt hi --engine claude --print-command 2>&1)"
expect_contains "the grant list is overridable" "$out" "Bash(just this:*)"
expect_not_contains "and the override replaces the default" "$out" "Bash(uv run:*)"

out="$("$SPAWN" --id x --prompt hi --engine claude --bypass-sandbox --print-command 2>&1)"
expect_contains "claude's bypass is still reachable" "$out" "--dangerously-skip-permissions"
expect_not_contains "the bypass does not also narrow the tools" "$out" "acceptEdits"

out="$("$SPAWN" --id x --prompt hi --engine claude --model sonnet --print-command 2>&1)"
expect_contains "the model is passed through" "$out" "sonnet"

# ------------------------------------------------------------------- roles
# --role carries the model, the effort and the tool grants for a kind of work,
# so those defaults live in one place instead of in whichever prompt happened to
# spawn the agent. Pinned here for the same reason every other flag is: the
# script is the only thing that says what an agent may reach, and a silent drift
# in it looks exactly like nothing having changed.
role_cmd() { "$SPAWN" --id x --prompt hi --engine claude --role "$1" --print-command 2>&1; }

out="$(role_cmd coder)"
expect_contains "the coder runs on opus" "$out" "claude-opus-5"
expect_contains "the coder runs at medium effort" "$out" "medium"
expect_contains "the coder may still write files" "$out" "acceptEdits"

# The test-writer is a tier ABOVE the coder, deliberately. Blind authorship
# assumes two peers: making the test side cheaper quietly turns the shared
# contract into whatever the coder happened to think it said. This assertion is
# the thing that would notice the two being levelled to save money.
out="$(role_cmd test-writer)"
expect_contains "the test-writer runs at high effort" "$out" "high"
tw_effort="$(printf '%s\n' "$out" | grep -A1 -- '--effort' | tail -1)"
co_effort="$(role_cmd coder | grep -A1 -- '--effort' | tail -1)"
if [[ "$tw_effort" == "high" && "$co_effort" == "medium" ]]; then
  ok "the test-writer is not cheaper than the coder"
else
  no "the test-writer is not cheaper than the coder" "coder=$co_effort test-writer=$tw_effort"
fi

# The oracle writes the one design document an agent may write unattended. Its
# grants are the first of two enforcements — the CI checks are what bind — but
# a grant that quietly widened to every path would remove the cheap half.
out="$(role_cmd oracle)"
expect_contains "the oracle runs on fable" "$out" "claude-fable-5"
# Edit(), not Write(): the engine matches file grants against Edit() rules and
# answers a Write(path) rule with "is not matched by file permission checks",
# so a Write() grant is inert — and two of them printed that rejection on
# every worker start, immediately above the engine's own errors (ESC-77).
expect_contains "the oracle may write its ledger" "$out" "Edit(docs/DESIGN.oracle.md)"
expect_contains "the oracle may write a handoff" "$out" "Edit(docs/oracle/**)"
expect_not_contains "and carries no inert Write() grant (ESC-77)" "$out" "Write(docs/"
expect_not_contains "the oracle does not get blanket edit acceptance" "$out" "acceptEdits"
expect_not_contains "the oracle cannot write plans" "$out" "docs/plans"

out="$(role_cmd steward)"
expect_contains "the steward may write oracle plans" "$out" "Edit(docs/plans/oracle/**)"
expect_not_contains "with no inert Write() grant either (ESC-77)" "$out" "Write(docs/"
expect_not_contains "the steward cannot write the ledger" "$out" "DESIGN.oracle.md"
expect_not_contains "the steward cannot write a handoff" "$out" "docs/oracle/**"

# The commands a role's own prompt names must be in its grant list, or the
# instruction is unfollowable as shipped: plan.md tells the steward to run
# oracle-decisions.sh, and the first-run stewards found out at CI instead. And
# a denied `git switch` does not fail loudly — it made a steward abandon a
# finished plan, uncommitted, in its worktree (ESC-38).
expect_contains "the steward may run the oracle-decisions gate its prompt names" \
  "$out" "Bash(.github/scripts/oracle-decisions.sh:*)"
expect_contains "and the plan parser" "$out" "Bash(.github/scripts/plan-parse.sh:*)"
expect_contains "and the plan linter" "$out" "Bash(.github/scripts/plan-lint.sh:*)"
expect_contains "a denied git switch no longer costs the commit" "$out" \
  "Bash(git switch:*)"

for role in reviewer explore; do
  out="$(role_cmd "$role")"
  expect_not_contains "the $role cannot write" "$out" "Write("
  expect_not_contains "the $role cannot commit" "$out" "git commit"
done
expect_contains "explore runs at low effort" "$(role_cmd explore)" "low"

# An explicit flag beats the role's default: the role is where a default lives,
# not a lock.
out="$("$SPAWN" --id x --prompt hi --engine claude --role coder --model sonnet \
  --effort max --print-command 2>&1)"
expect_contains "an explicit model overrides the role" "$out" "sonnet"
expect_not_contains "and replaces it rather than adding to it" "$out" "claude-opus-5"
expect_contains "an explicit effort overrides the role" "$out" "max"

# A typo must not land on the engine's own defaults — a wide tool grant and
# whatever model was configured, which is the opposite of naming a role.
out="$("$SPAWN" --id x --prompt hi --engine claude --role codr --print-command 2>&1)"
expect_rc "an unknown role fails fast" 2 $?
expect_contains "and lists the known roles" "$out" "Known roles:"

# Every role names a Claude model and codex spells effort differently, so the
# mismatch is refused rather than applied and left to fail deep inside the run
# as an unrecognised model — the same misdiagnosis shape as the --full-auto bug.
out="$("$SPAWN" --id x --prompt hi --engine codex --role coder --print-command 2>&1)"
expect_rc "a role on the codex engine fails fast" 2 $?
expect_contains "and says which engine roles are defined for" "$out" "'claude' engine"

# ------------------------------------------------- a worker that commits works
out="$(STUB_MODE=commit spawn --id ok-1 --prompt "build the thing" --engine codex)"
rc=$?
expect_rc "a worker that commits succeeds" 0 $rc
expect_contains "reports the commit count" "$out" "commits=1"
if git -C "$R" show-ref --verify --quiet refs/heads/worker/ok-1; then
  ok "the worker branch exists"
  if git -C "$R" show worker/ok-1:worker-artifact.txt >/dev/null 2>&1; then
    ok "the worker's file is on the branch"
  else no "the worker's file is on the branch"; fi
else no "the worker branch exists"; fi

# --------------------------------------------- the worktree is NOT in .claude/
# The original location. Claude Code protects .claude/, so a sandboxed headless
# worker was refused every write there and could not be told — it produced an
# empty branch and exited 0. This assertion is the whole reason that regression
# cannot come back quietly.
# The reported path is repository-RELATIVE since ESC-201, so this anchors on the
# start of the field rather than on a leading slash. The location itself is
# proved on disk two lines down, which is the stronger of the two checks anyway.
expect_contains "the worktree lives under .worktrees/" "$out" "worktree=.worktrees/ok-1"
expect_not_contains "the worktree is not under .claude/" "$out" ".claude/worktrees"
if [[ -d "$R/.worktrees/ok-1" ]]; then ok "the worktree directory was created"
else no "the worktree directory was created"; fi
if [[ -e "$R/.claude/worktrees" ]]; then
  no "nothing is written under .claude/worktrees"
else ok "nothing is written under .claude/worktrees"; fi

# The rendered .gitignore must cover the new location, or every worker's tree
# shows up as untracked in the orchestrator's own status.
if grep -qx '.worktrees/' "$HERE/../template/.gitignore.jinja"; then
  ok ".worktrees/ is gitignored in the template"
else no ".worktrees/ is gitignored in the template"; fi

# ------------------------------------------- a worker that commits NOTHING fails
# The fault this exists for: a headless agent that is refused every write exits
# 0, so the script reported success for a run that wrote no file and made no
# commit. Nothing caught that except the orchestrator remembering to look.
out="$(STUB_MODE=noop spawn --id empty-1 --prompt "do nothing" --engine codex)"
expect_rc "a worker that commits nothing FAILS" 3 $?
expect_contains "says it committed nothing" "$out" "committed nothing"
expect_contains "reports commits=0 on the result line" "$out" "commits=0"
expect_contains "names the silent-denial cause" "$out" "denied writes"
if [[ -d "$R/.worktrees/empty-1" ]]; then
  ok "the failed worker's worktree is left for inspection"
else no "the failed worker's worktree is left for inspection"; fi

# ------------------------------------- work left uncommitted fails, and says so
out="$(STUB_MODE=dirty spawn --id dirty-1 --prompt "edit but don't commit" --engine codex)"
expect_rc "uncommitted work is a failure too" 3 $?
expect_contains "distinguishes it from writing nothing" "$out" "uncommitted path"

# ------------------------------------------------ the engine's own exit passes through
out="$(STUB_MODE=fail spawn --id fail-1 --prompt "blow up" --engine codex)"
expect_rc "an engine failure propagates its exit code" 7 $?

# ----------------------------------------------------------------- preflight
# `command -v` said the engine existed; it said nothing about whether the engine
# could authenticate. On an account with no codex subscription the DEFAULT path
# could not work at all, and it failed as an argument error — which sent the
# first diagnosis at entirely the wrong problem.
out="$(STUB_AUTH_OK=0 spawn --id pf-1 --prompt "hi" --engine codex)"
expect_rc "an unusable engine fails before anything is created" 2 $?
expect_contains "says installed but not usable" "$out" "is installed but not usable"
expect_contains "shows the probe that failed" "$out" "probe:"
if [[ -e "$R/.worktrees/pf-1" ]]; then
  no "no worktree is created for an unusable engine"
else ok "no worktree is created for an unusable engine"; fi
if git -C "$R" show-ref --verify --quiet refs/heads/worker/pf-1; then
  no "no branch is created for an unusable engine"
else ok "no branch is created for an unusable engine"; fi

# The probe reads the OUTPUT, not just the status code: a CLI that reports a
# signed-out account on stdout and still exits 0 is the false green this check
# exists to prevent.
cat > "$WORK/bin/quietly-signed-out" <<'STUB'
#!/usr/bin/env bash
echo "Not logged in"
exit 0
STUB
chmod +x "$WORK/bin/quietly-signed-out"
out="$(SPAWN_PREFLIGHT_CODEX="quietly-signed-out" \
  spawn --id pf-2 --prompt "hi" --engine codex)"
expect_rc "a signed-out probe that exits 0 still fails" 2 $?
expect_contains "and says why" "$out" "is installed but not usable"

# The opt-out exists, and it is explicit.
out="$(STUB_AUTH_OK=0 STUB_MODE=commit \
  spawn --id pf-3 --prompt "hi" --engine codex --skip-preflight)"
expect_rc "--skip-preflight runs anyway" 0 $?

# ----------------------------------------------- an absent engine is different
out="$( cd "$R" && PATH="/usr/bin:/bin" "$SPAWN" --id gone-1 --prompt hi \
  --engine codex 2>&1 )"
expect_rc "a missing engine is a setup failure" 2 $?
expect_contains "and is diagnosed as missing, not unusable" "$out" "not on PATH"

# --------------------------------------------------- the base must be a commit
out="$(spawn --id bad-base --prompt hi --engine codex --base no/such/branch)"
expect_rc "an unresolvable base fails fast" 2 $?
expect_contains "names the base problem" "$out" "does not resolve to a commit"

# The emptiness check measures against where the worker STARTED, so a base
# branch that moves mid-run cannot make an empty branch look productive.
git -C "$R" switch -q -c moving-base
echo "before" >> "$R/README.md"; git -C "$R" commit -qam "before"
START="$(git -C "$R" rev-parse HEAD)"
out="$(STUB_MODE=noop spawn --id moved-1 --prompt "nothing" --engine codex --base "$START")"
expect_rc "a moved base cannot disguise an empty worker" 3 $?
git -C "$R" switch -q main

# ------------- ESC-201: nothing this script prints carries a machine path
# The result line is not a debug print. `deliver-loop.sh` appends it verbatim to
# the run report, which is committed, pushed and merged — so `worktree=` wrote
# the operator's absolute path, and with it their home directory and the root
# they keep repositories under, into a permanent public-shaped record. Observed
# live: four such lines in one merged run report on a real project. The template
# wrote them, so no amount of operator discipline prevents it.
#
# The repository-relative half is the only part that carries meaning to a later
# reader anyway — every reader of that report is standing in the repository.
#
# Asserted against EVERY line the script prints rather than against the one
# field that was wrong, because the leak is a class, not an instance: the same
# absolute root reaches stderr through the log path and the empty-worker
# diagnosis, and those are copied into the run's committed worker evidence too.
git -C "$R" switch -q main
out="$(spawn --id pathy-1 --prompt "do the thing" --engine codex)"
expect_rc "a committing worker still succeeds" 0 $?
expect_not_contains "no line carries the absolute repository root" "$out" "$R"
expect_contains "the worktree is reported relative to the repository" "$out" \
  "worktree=.worktrees/pathy-1"

# The same on the two failure paths, which are the ones a person actually reads
# — and the ones whose text is copied into the run's committed evidence.
out="$(STUB_MODE=noop spawn --id pathy-2 --prompt "nothing" --engine codex)"
expect_rc "an empty worker still fails" 3 $?
expect_not_contains "the empty-worker diagnosis carries no machine path" "$out" "$R"
expect_contains "and still says where the worktree is" "$out" ".worktrees/pathy-2"
expect_contains "and still says where the log is" "$out" \
  ".claude/orchestration-logs/pathy-2.log"

out="$(STUB_MODE=fail spawn --id pathy-3 --prompt "blow up" --engine codex)"
expect_rc "a failing engine still fails" 7 $?
expect_not_contains "the engine-failure line carries no machine path" "$out" "$R"
expect_contains "and still points at the log" "$out" \
  ".claude/orchestration-logs/pathy-3.log"

summary
