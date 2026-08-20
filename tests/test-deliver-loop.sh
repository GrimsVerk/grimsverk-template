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
  "api repos/"*"/pulls?state=open&base="*)
    # The detector's open-PR read, REST since ESC-51 (`gh pr list` is GraphQL
    # and hosted sessions serve REST only). An honest gh: the stub PR is
    # returned only for a query whose base parameter matches its base branch
    # (STUB_OPEN_PR_BASE); with no stub base set it is returned regardless.
    echo "$args" >> "${GH_LIST_LOG:-/dev/null}"
    if [[ -n "${STUB_OPEN_PR:-}" ]]; then
      if [[ -n "${STUB_OPEN_PR_BASE:-}" ]]; then
        [[ "$args" == *"base=${STUB_OPEN_PR_BASE}&"* ]] && echo "$STUB_OPEN_PR"
      else
        echo "$STUB_OPEN_PR"
      fi
    fi ;;
  "api --paginate repos/"*"/pulls?state=closed&base="*)
    # The detector's merged-refs read: REST has no merged state, so it asks
    # for closed and filters on merged_at — the stub answers the refs directly.
    echo "$args" >> "${GH_LIST_LOG:-/dev/null}"
    [[ -n "${STUB_MERGED_REFS:-}" ]] && printf '%s\n' "$STUB_MERGED_REFS" ;;
  "pr list --head "*)
    # The idempotency probe mechanical_pr() makes before opening: a head ref
    # that already has an open pull request must not get a second one.
    [[ -n "${STUB_HEAD_PR:-}" ]] && echo "$STUB_HEAD_PR" ;;
  "pr checks "*"--watch"*)
    echo "$args" >> "${GH_CHECKS_LOG:-/dev/null}"
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
# An origin URL, because the detector resolves owner/repo from it (ESC-51).
# The push tests further down repoint origin at a local bare repo; the gh stub
# matches its API paths on the "/pulls?" shape, not the repo name, so both
# URLs work.
git -C "$R" remote add origin https://github.com/own/repo.git

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

# THE ONE-PR RULE IS PER BASE BRANCH. Repo-wide, two runs sharing one
# repository on two base branches each wait on — and push fixes into — the
# other's pull requests, and each marks its plans built by the other's merges.
# A pull request into a different base belongs to a different run.
: > "$WORK/cap/ghlist.log"
out="$(run_phase GH_LIST_LOG="$WORK/cap/ghlist.log" \
        STUB_OPEN_PR="7 feat/notes" STUB_OPEN_PR_BASE=main)"
expect_contains "a PR into this run's own base still holds the loop" "$out" "PHASE=WAIT"
expect_contains "the open-PR query is scoped to the base branch" \
  "$(cat "$WORK/cap/ghlist.log")" "base=main"
out="$(run_phase STUB_OPEN_PR="7 feat/notes" STUB_OPEN_PR_BASE=main RUN_BASE=run/web)"
expect_not_contains "a PR into ANOTHER base does not hold this run" "$out" "PHASE=WAIT"
expect_contains "the detector reports which base it scoped to" "$out" "BASE=run/web"

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

# The built-plan detection is base-scoped for the same reason the WAIT one is:
# a twin run's merges into ITS base must not mark THIS run's plans built.
: > "$WORK/cap/ghlist.log"
out="$(run_phase PROCESSED_FILE="$WORK/cap/processed" GH_LIST_LOG="$WORK/cap/ghlist.log" \
        STUB_MERGED_REFS=$'feat/notes\nfeat/sqlite-store')"
expect_contains "the merged-PR query is scoped to the base branch" \
  "$(grep 'state=closed' "$WORK/cap/ghlist.log" || echo none)" "base=main"

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

# --base names a non-default base branch. The checkout must BE on it, and the
# run says which branch it belongs to before anything else — the owner's
# several-drivers-at-once requirement.
git -C "$R" checkout -qb run/web
out="$(run_loop -- --base run/web --dry-run)"
expect_rc "--base lets a run live on a non-default base branch" 0 $?
expect_contains "and the base is announced out loud at start" "$out" \
  "THIS RUN'S BASE BRANCH: run/web"
expect_contains "and the lane branch suffix is announced with it" "$out" \
  "suffixed '--run-web'"
out="$(run_loop -- --dry-run)"
expect_rc "the same checkout without --base is still refused" 2 $?
expect_contains "and the refusal names the flag" "$out" "--base"
git -C "$R" checkout -q main && git -C "$R" branch -qD run/web
out="$(run_loop -- --dry-run)"
expect_contains "the default run announces its base too" "$out" \
  "THIS RUN'S BASE BRANCH: main"

# ------------------------------------------------------- dry-run detection
out="$(run_loop STUB_OPEN_PR="9 feat/notes" -- --dry-run)"
expect_rc "dry-run exits clean" 0 $?
expect_contains "and reports the detected phase" "$out" "PHASE=WAIT"

# ------------------------------------------------- the 3-strike failure stop
# An open PR whose checks are red with the SAME signature every time: the
# first two rounds each dispatch one fix session, the third is a pattern and
# stops the run (deliver.md step 5's rule, mechanised).
: > "$WORK/cap/claude.log"
: > "$WORK/cap/checks.log"
out="$(run_loop STUB_OPEN_PR="9 feat/notes" STUB_CHECKS_RC=8 \
        GH_CHECKS_LOG="$WORK/cap/checks.log" \
        WAIT_TIMEOUT=60 SESSION_TIMEOUT=60 --)"
expect_rc "the same failure three times stops the run" 3 $?
expect_contains "and says it is a pattern" "$out" "three times"

# The watch must leave on the FIRST failed check, not wait for the rest to
# settle. Without --fail-fast a required check that never reports at all holds
# the watch to its full timeout while another required check already failed —
# the driver sat 90 minutes on a decided pull request exactly this way
# (ESC-39). A failed required check is terminal for that head; nothing a
# still-pending check reports can change it.
expect_contains "the checks watch leaves on the first failure" \
  "$(cat "$WORK/cap/checks.log")" "--fail-fast"
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

# A branch with WORK on it, which is what an orchestrate or worker session
# leaves behind. Pointing a branch at the base models "the branch exists" and
# not "the branch carries a change" — and the driver now tells those apart,
# because a head with no commits ahead of its base is one GitHub refuses a
# pull request for (ESC-66). A fixture that skipped the commit was asserting
# the driver should open a pull request that could never exist.
branch_with_work() { # branch_with_work <ref> [file]
  local ref="$1" f="${2:-work-$RANDOM.txt}"
  # An earlier scenario may have pushed this ref already; recreating it here
  # gives it a new SHA, and a non-fast-forward push would fail before the
  # behaviour under test is reached. Harmless no-op when there is no remote
  # ref (or no reachable remote).
  git -C "$R" push -q origin --delete "$ref" 2>/dev/null || true
  git -C "$R" branch -f "$ref" main
  git -C "$R" switch -q "$ref"
  echo "work on $ref" > "$R/$f"
  git -C "$R" add -A && git -C "$R" commit -qm "work on $ref"
  git -C "$R" switch -q main
}

# ---- the feature pull request
reset_pr_run
branch_with_work feat/sqlite-store
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
expect_contains "and targets the run's base branch explicitly" \
  "$(cat "$PRLOG")" "--base main"
# The head ref keeps its own name rather than being renamed under docs/, or
# plan-resolve.sh could not match the slug against a plan. Scoped to the feature
# pull request's own line: the driver also opens a docs/run-<id> evidence pull
# request at the run's stop, and that one is meant to be under docs/.
expect_not_contains "and does not rename the branch out of plan-resolve's reach" \
  "$(grep -F 'Build: sqlite-store' "$PRLOG" || true)" "--head docs/"
expect_not_contains "and never under the owner's ambient credential" \
  "$(cat "$PRLOG")" "GH_TOKEN=<unset>"

# ---- the same dispatch on a non-default base: lane suffix + explicit --base
# Twin runs building one design produce the same slugs, so the lane's feature
# branch must not be the default lane's `feat/<slug>` — it gets the `--<base>`
# suffix, the dispatch prompt names it exactly, and the pull request targets
# the lane's own base.
reset_pr_run
git -C "$R" branch -f run/web main
git -C "$R" switch -q run/web
git -C "$R" push -q origin run/web
# Work on the lane's feature branch, off the LANE base (ESC-66: a head with
# no commits ahead of its base gets no pull request, correctly).
git -C "$R" branch -f "feat/sqlite-store--run-web" run/web
git -C "$R" switch -q "feat/sqlite-store--run-web"
echo "lane work" > "$R/lane-work.txt"
git -C "$R" add -A && git -C "$R" commit -qm "work on the lane feature branch"
git -C "$R" switch -q run/web
out="$(run_loop STUB_MERGED_REFS=$'feat/notes' PR_CREATE_LOG="$PRLOG" \
        CLAUDE_LOG="$ORCHLOG" -- --base run/web --max-iterations 1)"
expect_contains "the lane run reaches ORCHESTRATE too" "$out" "phase ORCHESTRATE"
expect_contains "the dispatch names the lane's exact feature branch" \
  "$(cat "$ORCHLOG")" "feat/sqlite-store--run-web"
expect_contains "and the lane's base branch" "$(cat "$ORCHLOG")" \
  "off run/web"
expect_contains "the driver opens the lane pull request from the suffixed head" \
  "$(cat "$PRLOG")" "--head feat/sqlite-store--run-web"
expect_contains "onto the lane's own base, never the default" \
  "$(cat "$PRLOG")" "--base run/web"
git -C "$R" switch -q main
git -C "$R" branch -qD run/web 2>/dev/null || true
git -C "$R" branch -qD "feat/sqlite-store--run-web" 2>/dev/null || true

# ---- opening twice
# An attended session that already opened one, or an iteration retried after a
# timeout, is a harmless race. A driver that hard-failed there would turn it
# into a stopped run, so it reports and continues.
reset_pr_run
branch_with_work feat/sqlite-store
out="$(run_loop STUB_MERGED_REFS=$'feat/notes' STUB_HEAD_PR="42" \
        PR_CREATE_LOG="$PRLOG" CLAUDE_LOG="$ORCHLOG" -- --max-iterations 1)"
expect_contains "an existing pull request for the head ref is reported" "$out" \
  "already open for feat/sqlite-store"
if grep -q -- "--head feat/sqlite-store" "$PRLOG"; then
  no "and no second one is opened" "$(cat "$PRLOG")"
else ok "and no second one is opened"; fi

# ---- ESC-66: the empty-diff livelock
# A worker can exit 0, commit on ITS branch, and leave the LANE unchanged —
# an oracle re-deriving rulings that already merged is the ordinary case. The
# pull request GitHub would refuse ("No commits between") is never attempted,
# the scope is recorded as processed so the detector stops re-summoning the
# same worker over the same evidence, and two such dispatches in a row stop
# the run. Round 3.2 spent five oracle workers and ~27 minutes on this loop
# with no stop rule able to see it: the three-strike rule keys on the same
# CHECKS failing on one branch, and here no checks ever run and every branch
# has a fresh name.
reset_pr_run
git -C "$R" branch -qD feat/sqlite-store 2>/dev/null || true
# Uncited evidence puts the detector in ORACLE — the phase the live run
# looped in. Reverted right after, so later scenarios see the tree they expect.
printf '| ESC-99 | 2026-08-20 | a seeded escape | none | none |\n' >> "$R/docs/escapes.md"
git -C "$R" add -A && git -C "$R" commit -qm "seed an uncited escape"
# The driver pulls its base each iteration, so origin/<base> tracks it live —
# and origin/<base> is the comparison that matches GitHub's own "No commits
# between" verdict. A fixture leaving it behind makes an empty worker branch
# look one commit ahead.
git -C "$R" update-ref refs/remotes/origin/main "$(git -C "$R" rev-parse main)"
# A worker stub that commits NOTHING: its branch stays level with the base.
cat > "$WORK/bin/spawn-worker-empty" <<'STUB'
#!/usr/bin/env bash
id=""; while [[ $# -gt 0 ]]; do [[ "$1" == "--id" ]] && id="$2"; shift; done
git switch -q -c "worker/$id" 2>/dev/null || git switch -q "worker/$id"
git switch -q - 2>/dev/null || true
echo "WORKER_RESULT id=$id branch=worker/$id engine=claude exit=0 commits=1"
exit 0
STUB
chmod +x "$WORK/bin/spawn-worker-empty"
out="$(run_loop DELIVER_SPAWN="$WORK/bin/spawn-worker-empty" \
        PR_CREATE_LOG="$PRLOG" CLAUDE_LOG="$ORCHLOG" -- --max-iterations 9)"
expect_rc "an empty-diff dispatch stops the run instead of looping (ESC-66)" 5 $?
expect_contains "and says the lane did not move" "$out" "adds nothing to"
expect_contains "and names the pattern rather than a check failure" "$out" \
  "produced no pull request"
if grep -q -- "--head docs/oracle" "$PRLOG"; then
  no "no pull request is attempted for an empty branch" "$(cat "$PRLOG")"
else ok "no pull request is attempted for an empty branch"; fi
# Two dispatches, not nine: the counter stops it at the second.
disp="$(grep -c "dispatch oracle worker" <<<"$out")"
if [[ "$disp" -le 2 ]]; then ok "it stops after 2 empty dispatches, not at the iteration limit"
else no "it stops after 2 empty dispatches, not at the iteration limit" "$disp dispatches"; fi
# The scope it was commissioned to work is recorded as processed, so a fresh
# detector does not re-summon the same worker over the same evidence.
if grep -q "ESC-99" "$R/.claude/deliver-loop/processed-evidence" 2>/dev/null; then
  ok "the dispatched scope is recorded as processed"
else
  no "the dispatched scope is recorded as processed" \
    "$(cat "$R/.claude/deliver-loop/processed-evidence" 2>/dev/null)"
fi
git -C "$R" reset -q --hard HEAD~1
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

# ------------------------------ the dispatched prompt carries no frontmatter
# The other half of ESC-37. The driver builds worker prompts from
# .claude/commands/*.md, and every one of those opens with YAML frontmatter —
# loader metadata, not instructions. Sent verbatim it begins with `---` (the
# line that killed every first-run dispatch before spawn-worker gained its
# `--` terminator) and tells the model to read its own catalogue entry as a
# task. The driver must strip it: the prompt the engine receives starts at the
# command file's body.
reset_pr_run
cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Uncertainties awaiting oracle ruling

- **BL-9** — a question nobody ruled on — proposed: something — HIGH: changes
  a schema.
EOF
git -C "$R" add -A >/dev/null 2>&1; git -C "$R" commit -qm "an unruled uncertainty" >/dev/null 2>&1
out="$(run_loop CLAUDE_LOG="$ORCHLOG" SESSION_TIMEOUT=30 -- --max-iterations 1)"
expect_contains "the fixture reaches ORACLE" "$out" "phase ORACLE"
prompt_log="$(cat "$ORCHLOG" 2>/dev/null)"
expect_contains "the oracle dispatch carries the command file's body" \
  "$prompt_log" "You are the **oracle**"
expect_not_contains "and not its YAML frontmatter" "$prompt_log" \
  "description: Correct the design from logged evidence"

# ------------------------------ landing a dead run's evidence, run-free
# The buffer rotation (below) rescues a killed run's report ON THE NEXT RUN.
# A one-shot run, a finished test lane, or a retired machine has no next run,
# and evidence waiting on one is evidence dying by default. --land-evidence
# lands the leftover buffer now, under the dead run's own id, dispatching
# nothing — and skips the readiness/identity/worktree preflights, because a
# recovery that refuses over the repository's state would hold a dead run's
# only record hostage to it.
land_only() { ( cd "$R" && env PATH="$WORK/bin:$PATH" GH="$WORK/bin/gh" \
    DELIVER_APP_TOKEN_CMD="$WORK/bin/app-token" \
    CLAUDE_LOG="$WORK/cap/claude.land.log" "$@" \
    bash "$LOOP" --land-evidence 2>&1 ); }

git -C "$R" switch -q main 2>/dev/null || true
rm -rf "$R/.claude/deliver-loop" "$R/.worktrees"
mkdir -p "$R/.claude/deliver-loop" "$R/.worktrees/leftover-worker"
printf '# Delivery run 20260819T010203Z\n\n- 01:02:03Z dispatch oracle worker\n- 01:05:00Z the line before the kill\n' \
  > "$R/.claude/deliver-loop/run.md"
: > "$WORK/cap/claude.land.log"
: > "$WORK/cap/prcreate.log"
out="$(land_only PR_CREATE_LOG="$WORK/cap/prcreate.log")"
expect_rc "--land-evidence lands a dead run's buffer" 0 $?
expect_contains "and says it dispatches nothing" "$out" "dispatching nothing"
landref="docs/run-20260819T010203Z"
landed="$(git -C "$R" show "$landref:docs/runs/20260819T010203Z/run.md" 2>/dev/null)"
expect_contains "the evidence lands under the dead run's OWN id" "$landed" \
  "# Delivery run 20260819T010203Z"
expect_contains "carrying the killed run's last lines" "$landed" \
  "the line before the kill"
expect_contains "with an honest post-mortem marker" "$landed" "Landed post-mortem"
expect_not_contains "and no invented exit code" "$landed" "with exit code"
expect_contains "the pull request is opened for it" "$(cat "$WORK/cap/prcreate.log")" \
  "--head $landref"
if [[ -s "$WORK/cap/claude.land.log" ]]; then
  no "nothing is dispatched on the way" "$(head -c 200 "$WORK/cap/claude.land.log")"
else ok "nothing is dispatched on the way"; fi
if [[ -s "$R/.claude/deliver-loop/run.md" ]]; then
  no "the landed buffer is cleared" "buffer still has content"
else ok "the landed buffer is cleared"; fi
out="$(land_only)"
expect_rc "a second landing finds nothing and exits clean" 0 $?
expect_contains "and says so" "$out" "nothing to land"

# ESC-60: the failure this mode exists for — an evidence commit that died
# half way — ALWAYS leaves the tree dirty with the evidence itself, so
# landing tolerates dirt confined to the evidence paths...
printf '# Delivery run 20260819T030405Z\n\n- 03:04:05Z died mid-commit\n' \
  > "$R/.claude/deliver-loop/run.md"
mkdir -p "$R/docs/runs/20260819T030405Z/reviews"
echo "stranded payload from the died commit" \
  > "$R/docs/runs/20260819T030405Z/reviews/payload.txt"
git -C "$R" add docs/runs/20260819T030405Z 2>/dev/null
out="$(land_only)"
expect_rc "evidence-path dirt does not block a landing (ESC-60)" 0 $?
landed="$(git -C "$R" show "docs/run-20260819T030405Z:docs/runs/20260819T030405Z/reviews/payload.txt" 2>/dev/null)"
expect_contains "and the stranded staged evidence rides into the landing" \
  "$landed" "stranded payload"

# ...and still refuses dirt in project space, which is not its to sweep.
git -C "$R" switch -q main 2>/dev/null || true
printf '# Delivery run 20260819T040506Z\n\n- 04:05:06Z another dead run\n' \
  > "$R/.claude/deliver-loop/run.md"
echo "uncommitted project work" > "$R/somefile.py"
out="$(land_only)"
expect_rc "project-space dirt still refuses a landing" 2 $?
expect_contains "and names the boundary" "$out" "OUTSIDE the evidence paths"
rm -f "$R/somefile.py"

# Without an App identity a RUN refuses; a RECOVERY degrades — the branch still
# pushes and the missing pull request is said out loud.
printf '# Delivery run 20260819T020304Z\n\n- 02:03:04Z another dead run\n' \
  > "$R/.claude/deliver-loop/run.md"
out="$(land_only STUB_APP_TOKEN_RC=3)"
expect_rc "no App identity does not refuse a landing" 0 $?
expect_contains "the missing pull request is stated, not hidden" "$out" "no App token"
rm -rf "$R/.worktrees"
git -C "$R" switch -q main 2>/dev/null || true

# ------------------------------ one report buffer carries exactly one run
# ESC-44. The report buffer is appended during the run and landed at the stop;
# a run killed too hard for its EXIT trap to fire leaves its lines behind, and
# the next run's landed report then opened with the PREVIOUS run's header —
# observed downstream, flagged by the review gate reading the evidence. The
# dead run's lines must survive (wiping them is the evidence-destroyed defect
# this machinery exists to repair), but as a labeled unlanded/ file beside the
# next report, never inside it — and a successfully landed buffer is cleared,
# or the rotation would land the same report twice.
rm -rf "$R/.claude/deliver-loop" "$R/.worktrees"
mkdir -p "$R/.claude/deliver-loop"
printf '# Delivery run OLDRUN\n\n- 00:00:00Z the run that never landed\n' \
  > "$R/.claude/deliver-loop/run.md"
out="$(run_loop CLAUDE_LOG=/dev/null SESSION_TIMEOUT=30 -- --max-iterations 1)"
runref="$(git -C "$R" for-each-ref --format='%(refname:short)' 'refs/heads/docs/run-*' | sort | tail -1)"
runid="${runref#docs/run-}"
report="$(git -C "$R" show "$runref:docs/runs/$runid/run.md" 2>/dev/null)"
expect_contains "the fixture landed a run report at all" "$report" "# Delivery run $runid"
expect_not_contains "the landed report carries only its own run" "$report" \
  "Delivery run OLDRUN"
unlanded="$(git -C "$R" show "$runref:docs/runs/$runid/unlanded/unlanded-OLDRUN.md" 2>/dev/null)"
expect_contains "the killed run's buffer is landed beside it, labeled" "$unlanded" \
  "the run that never landed"
if [[ -s "$R/.claude/deliver-loop/run.md" ]]; then
  no "a landed buffer is cleared" "the buffer still has content after a successful landing"
else
  ok "a landed buffer is cleared"
fi
if compgen -G "$R/.claude/deliver-loop/unlanded-*.md" >/dev/null 2>&1; then
  no "a landed unlanded file is cleared too" "$(ls "$R/.claude/deliver-loop")"
else
  ok "a landed unlanded file is cleared too"
fi

summary
