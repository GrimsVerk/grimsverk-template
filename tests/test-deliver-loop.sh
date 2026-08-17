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
    echo "GH_TOKEN=${GH_TOKEN:-<unset>}" >> "${PR_CREATE_LOG:-/dev/null}" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"

cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${CLAUDE_LOG:-/dev/null}"
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
  ( cd "$R" && env PATH="$WORK/bin:$PATH" GH="$WORK/bin/gh" \
      DELIVER_SKIP_READY=1 DELIVER_SKIP_PULL=1 \
      DELIVER_APP_TOKEN_CMD="$WORK/bin/app-token" \
      CLAUDE_LOG="$WORK/cap/claude.log" ${envs[@]+"${envs[@]}"} \
      bash "$LOOP" ${flags[@]+"${flags[@]}"} 2>&1 )
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
# Sessions are `-p` invocations; the budget probe's `claude usage` call also
# lands in the stub's log and is not one.
if [[ "$(grep -c '^-p ' "$WORK/cap/claude.log")" == "2" ]]; then
  ok "exactly two fix sessions ran before the stop"
else
  no "exactly two fix sessions ran before the stop" \
    "claude invocations: $(head -c 300 "$WORK/cap/claude.log" 2>/dev/null)"
fi
firstfix="$(grep -m1 '^-p ' "$WORK/cap/claude.log")"
expect_contains "the fix prompt pins the existing branch" "$firstfix" "EXISTING BRANCH"
expect_contains "and forbids weakening a gate" "$firstfix" "Never weaken"

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

summary
