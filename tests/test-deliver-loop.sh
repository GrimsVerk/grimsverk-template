#!/usr/bin/env bash
#
# deliver-loop.sh + deliver-phase.sh — fixture tests against STUB gh/claude.
#
# The driver is the piece that runs while nobody is watching, so its logic is
# pinned the same way spawn-worker's is: stubs on PATH, every branch of the
# state machine manufactured. What a stub CAN prove: phase selection, the
# refusals, the exact session flags, the 3-strike stop, the one-PR rule. What
# it CANNOT prove: a live engine or a live repository — that is the first real
# run's job, and both are flagged unverified in the scripts' own headers.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TEMPLATE="$HERE/../template"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== deliver-loop.sh ==="

# --------------------------------------------------------------------- stubs
mkdir -p "$WORK/bin" "$WORK/cap"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
args="$*"
case "$args" in
  "auth status") exit 0 ;;
  "pr list --state open --limit 30 --json number,headRefName --jq "*)
    [[ -n "${STUB_OPEN_PR:-}" ]] && echo "$STUB_OPEN_PR" ;;
  "pr list --state merged --limit 200 --json headRefName --jq "*)
    [[ -n "${STUB_MERGED_REFS:-}" ]] && printf '%s\n' "$STUB_MERGED_REFS" ;;
  "pr list --head "*)
    # The idempotency probe mechanical_pr() makes before opening: a head ref
    # that already has an open pull request must not get a second one.
    [[ -n "${STUB_HEAD_PR:-}" ]] && echo "$STUB_HEAD_PR" ;;
  "pr checks "*"--watch"*)
    exit "${STUB_CHECKS_RC:-0}" ;;
  "pr checks "*)
    printf 'lint\tfail\t1m\thttps://x\nreview\tpass\t2m\thttps://y\n' ;;
  "pr view "*)
    echo "${STUB_PR_STATE:-MERGED}" ;;
  "pr create "*)
    # Record whether a non-owner token was supplied. The whole point of the
    # App identity is that this is NOT the owner's ambient credential, so the
    # test asserts the value actually arrives here.
    echo "GH_TOKEN=${GH_TOKEN:-<unset>} ARGS=$*" >> "${PR_CREATE_LOG:-/dev/null}" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"

cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${CLAUDE_LOG:-/dev/null}"
# A session that fails, or that exits 0 having written nothing, is the case the
# acceptance path used to record as "the run is complete".
case "$*" in
  *"acceptance pass"*)
    # STUB_ACC_BRANCH makes the stub behave like a session that did its job:
    # commit the acceptance table on the branch the DRIVER named, push nothing,
    # open nothing. The branch name is read out of the prompt because that is
    # the only place the session learns it too.
    if [[ "${STUB_ACC_BRANCH:-0}" == "1" ]]; then
      ref="$(printf '%s' "$*" | grep -oE 'docs/acceptance-[0-9A-Za-z-]+' | head -1)"
      if [[ -n "$ref" ]]; then
        git switch -q -c "$ref" 2>/dev/null || git switch -q "$ref"
        printf '| S1 | pass | agent |\n' >> docs/acceptance.md
        git add -A && git commit -qm "acceptance" >/dev/null
      fi
    fi
    exit "${STUB_ACCEPT_RC:-0}" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/claude"

# The App-token minter. DELIVER_APP_TOKEN_CMD is an injection point rather than
# a skip flag on purpose: there is no way to run the driver WITHOUT a non-owner
# identity, so the tests substitute the source of the token instead of bypassing
# the requirement. STUB_APP_TOKEN_RC drives the refusal paths.
cat > "$WORK/bin/app-token" <<'STUB'
#!/usr/bin/env bash
if [[ "${STUB_APP_TOKEN_RC:-0}" != "0" ]]; then
  echo "no App identity configured (stub)" >&2
  exit "${STUB_APP_TOKEN_RC}"
fi
echo "ghs_stubinstallationtoken"
exit 0
STUB
chmod +x "$WORK/bin/app-token"

# ------------------------------------------------------------------- fixture
# Assembled from the shipped files themselves (none of the ones the driver
# needs are Jinja), so a drift between what ships and what these tests
# exercise is impossible.
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/.claude/scripts" "$R/.claude/commands" "$R/.github/scripts" \
         "$R/docs/plans/oracle" "$R/docs/oracle"
cp "$TEMPLATE/.claude/scripts/deliver-loop.sh" \
   "$TEMPLATE/.claude/scripts/deliver-phase.sh" \
   "$TEMPLATE/.claude/scripts/budget-probe.sh" \
   "$TEMPLATE/.claude/scripts/spawn-worker.sh" "$R/.claude/scripts/"
cp "$TEMPLATE/.claude/commands/oracle.md" "$TEMPLATE/.claude/commands/steward.md" \
   "$TEMPLATE/.claude/commands/plan.md" "$R/.claude/commands/"
cp "$TEMPLATE/.github/scripts/coverage.sh" "$R/.github/scripts/"

cat > "$R/docs/DESIGN.md" <<'EOF'
# Design

## 5. Requirements

- **R1** stores a note
- **R2** lists the notes

## 13. Success criteria

- **S1** a note round-trips
EOF
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Approved

_(nothing yet)_

## Proposed

_(nothing yet)_

## Uncertainties awaiting oracle ruling

_(nothing yet)_
EOF
cat > "$R/docs/escapes.md" <<'EOF'
| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
EOF
: > "$R/docs/DESIGN.oracle.md"
# Mirror the template's gitignore for the driver's transient state, and give
# the repo an origin/HEAD so DEFAULT_BRANCH resolution works like a clone's.
printf '.claude/deliver-loop/\n.claude/orchestration-logs/\n.worktrees/\n' > "$R/.gitignore"
git -C "$R" add -A && git -C "$R" commit -qm scaffold
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse HEAD)"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

LOOP=".claude/scripts/deliver-loop.sh"
PHASE=".claude/scripts/deliver-phase.sh"

run_phase() { # run_phase [NAME=value ...]
  ( cd "$R" && env GH="$WORK/bin/gh" "$@" "$PHASE" 2>&1 )
}
run_loop() { # run_loop [NAME=value ...] -- [flags...]
  local -a envs=() flags=()
  local sep=0 a
  for a in "$@"; do
    if [[ "$a" == "--" ]]; then sep=1; continue; fi
    if [[ "$sep" -eq 0 ]]; then envs+=("$a"); else flags+=("$a"); fi
  done
  # BUDGET_PROBE_ALLOW_SESSION=0 keeps the probe from spending a `claude -p
  # "/usage"` session per iteration in the fixture — it would also land in the
  # stub's log and be miscounted as a dispatched worker.
  #
  # --max-iterations is supplied because the driver now REFUSES to start with no
  # ceiling at all: the owner's ruling is that no limit applies unless they
  # chose it, so a run with neither a usage gauge nor a stated limit has nothing
  # that would ever stop it. A caller passing its own flag still wins, since the
  # last assignment of a repeated flag is the one that sticks.
  ( cd "$R" && env PATH="$WORK/bin:$PATH" GH="$WORK/bin/gh" \
      DELIVER_SKIP_READY=1 DELIVER_SKIP_PULL=1 \
      DELIVER_APP_TOKEN_CMD="$WORK/bin/app-token" \
      BUDGET_PROBE_ALLOW_SESSION=0 \
      CLAUDE_LOG="$WORK/cap/claude.log" ${envs[@]+"${envs[@]}"} \
      bash "$LOOP" --max-iterations 20 ${flags[@]+"${flags[@]}"} 2>&1 )
}

# -------------------------------------------------------- phase detection
out="$(run_phase STUB_OPEN_PR="7 feat/notes")"
expect_contains "an open PR wins every other phase" "$out" "PHASE=WAIT"
expect_contains "and is named" "$out" "PR=7"

out="$(run_phase)"
expect_contains "unplanned owner requirements mean PLAN" "$out" "PHASE=PLAN"
expect_contains "and the gap list is passed through" "$out" "REQS=R1 R2"

# No design at all is a setup problem, not a phase — /design is interactive
# and owner-landed, so no loop can do it.
mv "$R/docs/DESIGN.md" "$R/docs/DESIGN.md.away"
out="$(run_phase)"
expect_contains "a missing design is SETUP" "$out" "PHASE=SETUP"
mv "$R/docs/DESIGN.md.away" "$R/docs/DESIGN.md"

# A HIGH uncertainty with no ruling blocks planning and wakes the oracle.
cat >> "$R/docs/BACKLOG.md" <<'EOF'
- **BL-1** — where do notes live? — proposed: sqlite — HIGH: changes slice
  boundaries and the storage schema.
EOF
out="$(run_phase)"
expect_contains "an unruled HIGH uncertainty wakes the oracle" "$out" "PHASE=ORACLE"
expect_contains "for the right reason" "$out" "REASON=uncertainties"
expect_contains "naming the id" "$out" "UNRULED=BL-1"

# A ruling that cites it clears the block (the citation is all the detector
# reads — merge-time validity is oracle-decisions.sh's job).
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'
## OD-1 — notes live in sqlite

- **Evidence:** BL-1
- **Requirements added:** R1000
EOF
out="$(run_phase)"
expect_contains "a cited uncertainty no longer wakes the oracle" "$out" "PHASE=STEWARD"
expect_contains "and the decision needing a plan is named" "$out" "ODS=OD-1"

# Un-metabolised evidence wakes the oracle; a processed-file entry (a prior
# run's dismissal) silences it — the anti-thrash memory.
echo "| ESC-1 | 2026-08-16 | a thing escaped | none | pending |" >> "$R/docs/escapes.md"
out="$(run_phase)"
expect_contains "uncited evidence wakes the oracle" "$out" "PHASE=ORACLE"
expect_contains "as evidence" "$out" "REASON=evidence"
echo "ESC-1" > "$WORK/cap/processed"
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed")"
expect_contains "dismissed evidence does not re-wake the oracle" "$out" "PHASE=STEWARD"

# Cover everything; with no merged feat/ PR the next move is ORCHESTRATE, and
# the plan's own docs/ merge must NOT count as built.
cat > "$R/docs/plans/notes.md" <<'EOF'
---
slug: notes
covers: [R1, R2]
---
# Notes — Plan
EOF
cat > "$R/docs/plans/oracle/sqlite-store.md" <<'EOF'
---
slug: sqlite-store
covers: [R1000]
---
# Sqlite store — Plan
Implements OD-1.
EOF
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" \
        STUB_MERGED_REFS=$'docs/plan-notes\ndocs/oracle-plan-od-1')"
expect_contains "a merged plan with no merged feature means ORCHESTRATE" "$out" \
  "PHASE=ORCHESTRATE"

out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" \
        STUB_MERGED_REFS=$'feat/notes\nfeat/sqlite-store')"
expect_contains "everything built means ACCEPTANCE" "$out" "PHASE=ACCEPTANCE"

# ------------------------------------------------- which string names a plan
# plan-resolve.sh identifies a plan by its front-matter `slug:`; this detector
# used to use the FILENAME, so the two halves named the same object differently
# and a plan could be considered built by a branch belonging to another one. No
# feature pull request is ever opened in that case, so no gate gets a chance —
# coverage.sh reports the requirements covered and the run exits 0 with the work
# absent. Both assertions below fail against the old `basename` + unanchored
# grep.
cat > "$R/docs/plans/oracle/sync.md" <<'EOF'
---
slug: milestone-4-sync-transport
covers: [R14]
---
# Sync transport — Plan
EOF
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" \
        STUB_MERGED_REFS=$'feat/notes\nfeat/sqlite-store\nfeat/sync-index-1')"
expect_contains "the front-matter slug identifies a plan, not the filename" "$out" \
  "PHASE=ORCHESTRATE"
expect_contains "and the unbuilt plan is the one named" "$out" \
  "SLUG=milestone-4-sync-transport"

# The real branch counts, and so does an ordinary suffixed form of it
# (feat/<slug>-2 for a second attempt), because those genuinely are its branch.
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" \
        STUB_MERGED_REFS=$'feat/notes\nfeat/sqlite-store\nfeat/milestone-4-sync-transport')"
expect_contains "the plan's own feature branch counts as built" "$out" "PHASE=ACCEPTANCE"
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" \
        STUB_MERGED_REFS=$'feat/notes\nfeat/sqlite-store\nfeat/milestone-4-sync-transport-2')"
expect_contains "and so does a suffixed second attempt" "$out" "PHASE=ACCEPTANCE"
rm "$R/docs/plans/oracle/sync.md"

# The collision plan-resolve.sh names in its own error text — "a slug that is a
# substring of another, like 'auth' and 'auth-tokens', will always collide". It
# can only treat that as a hard error for branches somebody opened; here nobody
# opens one, so the anchor has to do the work. Unanchored, `feat/auth` would
# match `feat/authentication-overhaul` and the plan would be silently built.
cat > "$R/docs/plans/oracle/auth.md" <<'EOF'
---
slug: auth
covers: [R14]
---
# Auth — Plan
EOF
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" \
        STUB_MERGED_REFS=$'feat/notes\nfeat/sqlite-store\nfeat/authentication-overhaul')"
expect_contains "a longer unrelated branch does not count as built" "$out" "PHASE=ORCHESTRATE"
expect_contains "and the plan is still queued" "$out" "SLUG=auth"
rm "$R/docs/plans/oracle/auth.md"

git -C "$R" add -A && git -C "$R" commit -qm "fixture state"

# ------------------------------------------------------------ the commands
out="$( cd "$R" && bash "$LOOP" --print-command oracle )"
expect_contains "the oracle session runs the oracle role" "$out" "claude-fable-5"
expect_not_contains "and never drops the sandbox" "$out" "--dangerously"
out="$( cd "$R" && bash "$LOOP" --print-command orchestrate )"
expect_contains "the orchestrate session is opus at high" "$out" "claude-opus-5"
expect_contains "with auto-accepted edits, not skipped permissions" "$out" \
  "acceptEdits"
expect_contains "grants on the command line (the ESC-5 lesson)" "$out" \
  "--allowed-tools"
expect_not_contains "merging is not in the orchestrator's reach" "$out" "gh pr merge"
expect_not_contains "nor is a hard reset" "$out" "git reset"

# NOR IS OPENING A PULL REQUEST. This grant existed, and run_session() passes no
# credential, so an orchestrate or acceptance session inherited the owner's
# ambient `gh` auth and opened every feature and acceptance pull request of an
# unattended run under their name. ESC-26 gave the driver an App identity and
# fixed the two places the DRIVER opens one; it never asked which OTHER things
# open one. The driver opens both now, after the session returns.
expect_not_contains "opening a pull request belongs to the driver, not the session" \
  "$out" "gh pr create"

# THE ONE DOOR TO A NEW AGENT. The orchestrator's whole job is spawning paired
# coder and test-writer workers, so it must be able to — and it must be able to
# ONLY through spawn-worker.sh, because that script is where every property of a
# worker is imposed: the per-role model and effort, the path-scoped write
# grants, the authentication preflight, the worktree isolation, and the
# empty-branch check. An agent that can start an engine directly hands it
# whatever grants it likes and none of that applies.
#
# This pair was untested, and that is how it silently stopped being true:
# `.claude/settings.json` carried `Bash(claude -p:*)` in its ALLOW list, which
# put the door back without anything noticing. Nothing needed it — the engine
# spawn-worker.sh launches is a subprocess of the script (spawn-worker.sh's
# final `( cd "$WORKTREE" && "${CMD[@]}" )`), not a tool call, so the grant on
# the script covers the whole path. Both halves are asserted here so the
# permission and the bypass cannot drift apart again.
expect_contains "the orchestrator CAN spawn workers" "$out" \
  "Bash(.claude/scripts/spawn-worker.sh:*)"
expect_not_contains "and cannot start an engine directly (claude)" "$out" "Bash(claude"
expect_not_contains "nor codex" "$out" "Bash(codex"

# And the roles it spawns really exist, so the grant above is not pointing at a
# door that refuses the only two things the orchestrator needs.
for role in coder test-writer; do
  rout="$( cd "$R" && bash .claude/scripts/spawn-worker.sh --print-command \
            --id probe --role "$role" --engine claude --base main --prompt x 2>&1 )"
  if [[ "$rout" == *"claude"* ]]; then ok "spawn-worker accepts --role $role"
  else no "spawn-worker accepts --role $role" "$rout"; fi
done
# The architect is the deliberate exception: not spawnable, so its authority
# cannot be borrowed by a role that is.
rout="$( cd "$R" && bash .claude/scripts/spawn-worker.sh --print-command \
          --id probe --role architect --engine claude --base main --prompt x 2>&1 )" && rc=0 || rc=$?
# spawn-worker's die() exits 2, the same code every other misuse gets — a
# refusal, not a crash.
expect_rc "and refuses --role architect" 2 "$rc"
expect_contains "saying where the design is written instead" "$rout" "/design"

# --------------------------------------------------------------- refusals
echo dirt > "$R/uncommitted.txt"
out="$(run_loop -- --dry-run)"
expect_rc "a dirty tree is refused" 2 $?
expect_contains "and told why" "$out" "working tree is dirty"
rm "$R/uncommitted.txt"

git -C "$R" checkout -qb feat/wrong-place
out="$(run_loop -- --dry-run)"
expect_rc "running off the default branch is refused" 2 $?
git -C "$R" checkout -q main && git -C "$R" branch -qD feat/wrong-place

# ------------------------------------------------------- dry-run detection
out="$(run_loop STUB_OPEN_PR="9 feat/notes" -- --dry-run)"
expect_rc "dry-run exits clean" 0 $?
expect_contains "and reports the detected phase" "$out" "PHASE=WAIT"

# ------------------------------------------------- the 3-strike failure stop
# An open PR whose checks are red with the SAME signature every time: the
# first two rounds each dispatch one fix session, the third is a pattern and
# stops the run (deliver.md step 5's rule, mechanised).
: > "$WORK/cap/claude.log"
out="$(run_loop STUB_OPEN_PR="9 feat/notes" STUB_CHECKS_RC=8 \
        WAIT_TIMEOUT=60 SESSION_TIMEOUT=60 --)"
expect_rc "the same failure three times stops the run" 3 $?
expect_contains "and says it is a pattern" "$out" "three times"
# Sessions are `-p` invocations. The budget probe no longer lands here: the
# harness sets BUDGET_PROBE_ALLOW_SESSION=0, because a probe that costs a
# session per iteration would both distort this count and, in a real run, spend
# budget to measure budget.
if [[ "$(grep -c '^-p ' "$WORK/cap/claude.log")" == "2" ]]; then
  ok "exactly two fix sessions ran before the stop"
else
  no "exactly two fix sessions ran before the stop" \
    "claude invocations: $(head -c 300 "$WORK/cap/claude.log" 2>/dev/null)"
fi
firstfix="$(grep -m1 '^-p ' "$WORK/cap/claude.log")"
expect_contains "the fix prompt pins the existing branch" "$firstfix" "EXISTING BRANCH"
expect_contains "and forbids weakening a gate" "$firstfix" "Never weaken"

# --------------------------------------------------------------- the ceiling
# The owner's ruling: the rate limit is the only stop that applies by default,
# and no limit applies unless they chose it. The defaults this replaced — 25
# percentage points, 10 pull requests, 8 hours — were invented by the session
# that wrote the script, and the percentage one had never worked at all, so
# every run was in fact bounded by two numbers nobody had picked.
#
# Raw, without the harness's injected --max-iterations, and with stdin closed so
# the prompt cannot be answered: a run with no gauge and no stated limit has
# nothing that would ever stop it, and must refuse rather than pick a number.
raw_loop() { ( cd "$R" && env PATH="$WORK/bin:$PATH" GH="$WORK/bin/gh" \
    DELIVER_SKIP_READY=1 DELIVER_SKIP_PULL=1 \
    DELIVER_APP_TOKEN_CMD="$WORK/bin/app-token" BUDGET_PROBE_ALLOW_SESSION=0 \
    CLAUDE_LOG=/dev/null "$@" bash "$LOOP" 2>&1 </dev/null ); }

out="$(raw_loop)"
expect_rc "no gauge and no limit refuses to start" 2 $?
expect_contains "and says nothing would stop it" "$out" "nothing would ever stop this run"
expect_contains "and names the countable limits" "$out" "--max-prs"
# The number 25 was the invented default this replaced. Asserted as "25 points"
# rather than as a bare "25": the driver now prints a timestamped run directory
# on every stop, so a bare substring makes this assertion fail whenever the
# clock happens to read 25 seconds or minutes past. A time-dependent test is a
# test that is wrong twice an hour and right the rest of the time, which is
# worse than no test — it teaches people to re-run rather than read.
expect_not_contains "and invents no allowance of its own" "$out" "25 points"
expect_not_contains "nor any other allowance it chose itself" "$out" "allowance 2"

# With a gauge but no allowance, the question is the other one — a percentage of
# the weekly window, which is the limit the owner actually specified.
cat > "$WORK/bin/fakeusage" <<'STUB'
#!/usr/bin/env bash
echo "session=7 week=29 week_model=25 reset=2026-08-20T10:59:00Z"
STUB
chmod +x "$WORK/bin/fakeusage"
out="$(raw_loop BUDGET_PROBE_CMD="$WORK/bin/fakeusage")"
expect_rc "a gauge with no allowance refuses too" 2 $?
expect_contains "and says the run has no ceiling" "$out" "no weekly allowance given"
expect_contains "and shows the current reading" "$out" "29%"
expect_contains "and names the per-model cap separately" "$out" "own cap"
expect_contains "and names the flag that answers it" "$out" "--budget-points"

# An explicit allowance is accepted and reported, with the reset recorded so a
# mid-run rollover can be detected rather than measured.
out="$(run_loop BUDGET_PROBE_CMD="$WORK/bin/fakeusage" \
        STUB_OPEN_PR="7 feat/notes" STUB_CHECKS_RC=0 STUB_PR_STATE=MERGED \
        WAIT_TIMEOUT=5 -- --budget-points 15 --max-iterations 1)"
expect_contains "an explicit weekly allowance is taken" "$out" "allowance 15 points"
expect_contains "and the reset is recorded for rollover detection" "$out" "resets 2026-08-20"

# ------------------------------------------------------------- the identity
# owner-authored.sh compares the pull request author to the CODEOWNERS owner.
# A driver opening pull requests under the owner's own credentials satisfies it
# by accident, for every pull request, including one carrying an agent's edit to
# docs/DESIGN.md. These assertions are the ones that keep that from returning.

# Refused at PREFLIGHT, not at first use: the owner is about to walk away, so
# the failure has to land while they are still watching.
out="$(run_loop STUB_APP_TOKEN_RC=3 --)"
expect_rc "no App identity refuses the whole run" 2 $?
expect_contains "and stops loudly" "$out" "STOP"
expect_contains "and names the check that would be hollowed out" "$out" "owner-authored.sh"
expect_contains "and offers the attended path instead" "$out" "/deliver"
if grep -q '^-p ' "$WORK/cap/claude.log.identity" 2>/dev/null; then
  no "nothing was dispatched before the refusal" "a session ran anyway"
else
  ok "nothing was dispatched before the refusal"
fi

# A failure to mint mid-run must not silently fall back to the owner's ambient
# credential — that is the exact substitution the identity exists to prevent.
: > "$WORK/cap/prcreate.log"
out="$(run_loop PR_CREATE_LOG="$WORK/cap/prcreate.log" \
        STUB_MERGED_REFS="" --dry-run --)" || true
if [[ -s "$WORK/cap/prcreate.log" ]] \
   && ! grep -q 'GH_TOKEN=<unset>' "$WORK/cap/prcreate.log"; then
  ok "pull requests are opened with a minted token, never the ambient one"
elif [[ ! -s "$WORK/cap/prcreate.log" ]]; then
  ok "pull requests are opened with a minted token, never the ambient one (none opened in this path)"
else
  no "pull requests are opened with a minted token, never the ambient one" \
    "$(cat "$WORK/cap/prcreate.log")"
fi

# ------------------------------------------------------- the acceptance marker
# docs/acceptance.md is the ONE artifact in an unattended run whose pull request
# requires the owner's review — the single guaranteed connection between the run
# and a human. The marker meaning "acceptance happened" used to be written
# BEFORE the session ran, the dispatch is `|| true`, and run start never cleared
# it. So a session that timed out, failed, or wrote nothing produced exit 0 and
# "the run is complete", with the shipped skeleton still in place; and the stale
# marker made every LATER run in the same clone exit 0 immediately, having
# dispatched nothing at all. These assertions are that bug's headstone.
#
# Last in the file because reaching ACCEPTANCE means draining every earlier
# phase: no unruled uncertainties, no uncited evidence, no unplanned handoffs.
: > "$R/docs/BACKLOG.md"
: > "$R/docs/DESIGN.oracle.md"
printf '# Escapes\n\n| id | date | what | gate | check |\n| --- | --- | --- | --- | --- |\n' \
  > "$R/docs/escapes.md"
git -C "$R" add -A >/dev/null 2>&1; git -C "$R" commit -qm "drained" >/dev/null 2>&1
BUILT=$'feat/notes\nfeat/sqlite-store'

acceptance_run() { # acceptance_run <stub-rc>
  rm -rf "$R/.claude/deliver-loop" "$R/.worktrees"
  run_loop STUB_MERGED_REFS="$BUILT" STUB_ACCEPT_RC="$1" \
           SESSION_TIMEOUT=30 -- --max-iterations 4
}

out="$(acceptance_run 1)"; rc=$?
expect_contains "the fixture really reaches the acceptance phase" "$out" "phase ACCEPTANCE"
expect_not_contains "a failed acceptance session is not 'the run is complete'" \
  "$out" "the run is complete"
expect_contains "and says it is not recording it as done" "$out" "NOT recording it as done"
if [[ "$rc" != "0" ]]; then ok "and the run does not exit 0"
else no "and the run does not exit 0" "exit 0 after a failed acceptance pass"; fi

# Exit 0 having written nothing is the same failure wearing a success code —
# the exact case spawn-worker.sh's empty-branch check catches for workers, on a
# dispatch path that does not use it.
out="$(acceptance_run 0)"
expect_contains "a clean session that wrote nothing is not recorded either" \
  "$out" "docs/acceptance.md is unchanged"
expect_not_contains "and does not claim completion" "$out" "the run is complete"

# The marker is per-RUN state. A leftover one used to make the next run in the
# same clone short-circuit to exit 0 having dispatched nothing.
rm -rf "$R/.claude/deliver-loop" "$R/.worktrees"
mkdir -p "$R/.claude/deliver-loop"
touch "$R/.claude/deliver-loop/acceptance-dispatched"
out="$(run_loop STUB_MERGED_REFS="$BUILT" STUB_ACCEPT_RC=0 \
        SESSION_TIMEOUT=30 -- --max-iterations 4)"
expect_not_contains "a marker from a previous run does not end this one" \
  "$out" "acceptance recorded and nothing is open"
rm -rf "$R/.worktrees"

# ---------------------------- the detector reads what the repository knows
# Two facts sit in git that the detector used to ignore, and it consulted a
# gitignored file and a branch name instead. Both gaps had the same shape: the
# same repository gave different answers depending on where the driver ran.
git -C "$R" switch -q main 2>/dev/null || true

# (a) An escape CLOSED in docs/escapes.done.md is finished, and the oracle is
# not handed it again. Before this, the detector read the id and never the row,
# so a project with any history handed the oracle everything it ever logged —
# including defects fixed months earlier with a demonstrated check.
cat > "$R/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | a check reported green by not running | CI | `tests/a.sh` |
| ESC-2 | 2026-08-16 | still open, nobody has ruled | none existed | unverified — pending: something |
EOF
out="$(run_phase)"
expect_contains "an unclosed escape still reaches the oracle" "$out" "ESC-1"

cat > "$R/docs/escapes.done.md" <<'EOF'
# Escapes — closed

| Id | Date | Check that closes it | How it was demonstrated |
| --- | --- | --- | --- |
| ESC-1 | 2026-08-17 | `tests/a.sh` | red against the defect, green after |
EOF
out="$(run_phase)"
expect_not_contains "a closed escape is not handed to the oracle again" "$out" "ESC-1"
expect_contains "and the one still open is" "$out" "ESC-2"

# The point of the file being COMMITTED rather than gitignored: the answer does
# not depend on which machine the driver runs on.
out="$( cd "$R" && env PROCESSED_FILE=/nonexistent GH="$WORK/bin/gh" \
        bash "$PHASE" 2>&1 )"
expect_not_contains "and the closure holds with no run memory at all" "$out" "ESC-1"

rm -f "$R/docs/escapes.done.md" "$R/docs/escapes.md"
printf '| Id |\n| --- |\n' > "$R/docs/escapes.md"

# (b) A plan whose front matter says the work landed is BUILT. Without this a
# retrospective plan — one recording work that shipped before the plan existed —
# can never be satisfied, because no feat/<slug> branch will ever exist for it,
# so the detector asks for an orchestrator to rebuild it forever.
mkdir -p "$R/docs/plans"
cat > "$R/docs/plans/already-done.md" <<'EOF'
---
slug: already-done
status: draft
covers: [R1]
---
# Already done — Plan
## Slice 1 — a thing
- **Files:** `src/x.py`
- **Estimate:** ~10 lines
EOF
out="$(run_phase)"
expect_contains "a plan with no merged feature branch is orchestrated" "$out" "SLUG=already-done"

sed -i 's/^status: draft$/status: merged/' "$R/docs/plans/already-done.md"
out="$(run_phase)"
expect_not_contains "a plan declaring status: merged is not orchestrated again" "$out" "SLUG=already-done"

# And the word means the WORK landed, so nothing else in the vocabulary counts.
sed -i 's/^status: merged$/status: in-flight/' "$R/docs/plans/already-done.md"
out="$(run_phase)"
expect_contains "in-flight is not built" "$out" "SLUG=already-done"
rm -f "$R/docs/plans/already-done.md"

# ------------------------------- the driver opens BOTH pull requests, as the App
# ORCH_TOOLS granted `Bash(gh pr create:*)` and run_session() passes no
# credential, so the orchestrate and acceptance SESSIONS opened their own pull
# requests using the owner's ambient `gh` auth. ESC-26 fixed the two places the
# DRIVER opens one and never asked which other things do.
#
# The acceptance one is the sharp end and it is not tidiness: docs/acceptance.md
# is CODEOWNERS-owned, and GitHub does not let an author approve their own pull
# request — so the single artifact of an unattended run whose review is the
# entire point was one the owner could not approve.
git -C "$R" switch -q main 2>/dev/null || true
git -C "$R" add -A >/dev/null 2>&1; git -C "$R" commit -qm "before the pr tests" >/dev/null 2>&1

# A real remote, because mechanical_pr() pushes before it opens. Without one it
# would fail at its first line and every assertion below would pass by never
# happening.
ORIGIN="$WORK/origin.git"
git init -q --bare "$ORIGIN"
git -C "$R" remote add origin "$ORIGIN" 2>/dev/null || git -C "$R" remote set-url origin "$ORIGIN"
git -C "$R" push -q origin main

PRLOG="$WORK/cap/prcreate.log"
ORCHLOG="$WORK/cap/claude.pr.log"
reset_pr_run() { rm -rf "$R/.claude/deliver-loop" "$R/.worktrees"; : > "$PRLOG"; : > "$ORCHLOG"; }

# ---- the feature pull request
reset_pr_run
git -C "$R" branch -f feat/sqlite-store main
out="$(run_loop STUB_MERGED_REFS=$'feat/notes' PR_CREATE_LOG="$PRLOG" \
        CLAUDE_LOG="$ORCHLOG" -- --max-iterations 1)"
expect_contains "the fixture reaches ORCHESTRATE" "$out" "phase ORCHESTRATE"

# The marker is what lets the command file tell the two modes apart. Without it
# the same prose has to be right for an attended human and an unattended
# driver, and "open the pull request" is right for exactly one of them.
expect_contains "the dispatch says it is unattended" "$(cat "$ORCHLOG")" "UNATTENDED RUN"
expect_contains "and says to push and stop" "$(cat "$ORCHLOG")" "Do NOT open the pull request"

expect_contains "the driver opens the feature pull request itself" \
  "$(cat "$PRLOG")" "--head feat/sqlite-store"
# The head ref keeps its own name rather than being renamed under docs/, or
# plan-resolve.sh could not match the slug against a plan. Scoped to the feature
# pull request's own line: the driver also opens a docs/run-<id> evidence pull
# request at the run's stop, and that one is meant to be under docs/.
expect_not_contains "and does not rename the branch out of plan-resolve's reach" \
  "$(grep -F 'Build: sqlite-store' "$PRLOG" || true)" "--head docs/"
expect_not_contains "and never under the owner's ambient credential" \
  "$(cat "$PRLOG")" "GH_TOKEN=<unset>"

# ---- opening twice
# An attended session that already opened one, or an iteration retried after a
# timeout, is a harmless race. A driver that hard-failed there would turn it
# into a stopped run, so it reports and continues.
reset_pr_run
git -C "$R" branch -f feat/sqlite-store main
out="$(run_loop STUB_MERGED_REFS=$'feat/notes' STUB_HEAD_PR="42" \
        PR_CREATE_LOG="$PRLOG" CLAUDE_LOG="$ORCHLOG" -- --max-iterations 1)"
expect_contains "an existing pull request for the head ref is reported" "$out" \
  "already open for feat/sqlite-store"
if grep -q -- "--head feat/sqlite-store" "$PRLOG"; then
  no "and no second one is opened" "$(cat "$PRLOG")"
else ok "and no second one is opened"; fi

# ---- a session that pushed nothing
# Removing the grant means the orchestrator cannot open a pull request at all,
# so a session that ends without a branch leaves nothing behind. That has to
# read as nothing-to-open, not as a crash.
reset_pr_run
git -C "$R" branch -D feat/sqlite-store >/dev/null 2>&1 || true
out="$(run_loop STUB_MERGED_REFS=$'feat/notes' PR_CREATE_LOG="$PRLOG" \
        CLAUDE_LOG="$ORCHLOG" -- --max-iterations 1)"
expect_contains "a session that left no branch is reported, not crashed" "$out" \
  "does not exist — nothing to open"

# ---- the acceptance pull request
reset_pr_run
out="$(run_loop STUB_MERGED_REFS="$BUILT" STUB_ACCEPT_RC=0 STUB_ACC_BRANCH=1 \
        PR_CREATE_LOG="$PRLOG" CLAUDE_LOG="$ORCHLOG" SESSION_TIMEOUT=30 \
        -- --max-iterations 1)"
expect_contains "the fixture reaches ACCEPTANCE" "$out" "phase ACCEPTANCE"
expect_contains "the acceptance dispatch says it is unattended" \
  "$(cat "$ORCHLOG")" "UNATTENDED RUN"
expect_contains "and names the branch the driver will open" \
  "$(cat "$ORCHLOG")" "docs/acceptance-"
expect_contains "and says why the session must not open it" "$(cat "$ORCHLOG")" \
  "does not let an author approve their own pull request"
expect_contains "the driver opens the acceptance pull request itself" \
  "$(cat "$PRLOG")" "--head docs/acceptance-"
expect_not_contains "as the App, never as the owner" "$(cat "$PRLOG")" "GH_TOKEN=<unset>"
git -C "$R" switch -q main 2>/dev/null || true

summary
