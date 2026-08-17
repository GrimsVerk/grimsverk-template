#!/usr/bin/env bash
#
# deliver-loop.sh — the local delivery driver: run the pipeline until the
# design is built, with nobody watching.
#
#     .claude/scripts/deliver-loop.sh [options]
#
# This is a SCHEDULER, NOT AN AGENT — deterministic bash the owner starts, in
# the position orchestration.md already blesses ("you know what is running,
# because you started both"). It holds no model and makes no judgment beyond
# branching on exit codes: each iteration it asks `deliver-phase.sh` what the
# world needs next, dispatches ONE headless session (or waits on one open pull
# request), and comes back. All waiting is mechanical — `gh pr checks --watch`
# — so no model budget is spent watching CI (docs/DECISIONS.md, the waiting
# ruling). The one-layer rule survives intact: this driver opens sessions;
# only an orchestrator session spawns workers.
#
# The web-session variant of this driver is `/deliver-loop`
# (.claude/commands/deliver-loop.md); both consume the same phase detector,
# which is what keeps the two modes from drifting. Choose a mode by choosing
# which entry point you start.
#
# STATE IS RECOMPUTED, NOT TRUSTED. Every iteration re-reads the tree and the
# open pull requests. The only persistence is `.claude/deliver-loop/`
# (gitignored): failure signatures, evidence ids the oracle dismissed, the
# design/vision SHAs at run start, and the run log the owner reads in the
# morning (`run.md`).
#
# STOPS, and their exit codes — every stop says why, none degrades silently:
#   0  done: the acceptance pass ran (or was already recorded); run.md has the
#      report and the pending-on-owner list
#   2  setup: refused before dispatching anything — readiness check failed,
#      no design ids, dirty tree, wrong branch
#   3  the same failure signature three times — a pattern, not a blip
#      (deliver.md step 5's rule, mechanised)
#   4  blocked on the owner: a green pull request only the owner can merge
#      (gate paths are CODEOWNERS-owned), reported rather than waited out
#   5  iteration cap
#   6  budget spent: the percentage-point allowance (when the probe works — see
#      budget-probe.sh) or a hard backstop (--max-prs, --max-hours)
#
# Options:
#   --max-iterations <n>   default 20
#   --budget-points <n>    default 25 — max percentage points of subscription
#                          utilization this run may consume (probe-dependent)
#   --max-prs <n>          default 10 — hard backstop, probe or no probe
#   --max-hours <n>        default 8  — hard backstop, probe or no probe
#   --wait-for-owner       on a green owner-owned pull request, keep polling
#                          instead of exiting 4
#   --dry-run              detect and print the phase, dispatch nothing
#   --print-command <phase>  print the session command a phase would run, run
#                          nothing (CI pins the flags this way; needs no engine)
#
# Env:
#   DELIVER_ENGINE        engine for oracle/steward/plan workers (default
#                         claude; codex has no --role support in spawn-worker)
#   DELIVER_ORCH_TOOLS    --allowed-tools for orchestrate/acceptance sessions,
#                         comma-separated; command-line grants because a fresh
#                         workspace ignores settings.json (the ESC-5 lesson)
#   SESSION_TIMEOUT       seconds per headless session (default 3600)
#   WAIT_TIMEOUT          seconds per checks-watch before re-detecting (5400)
#   GH                    the GitHub CLI (tests substitute a stub)
#   DELIVER_SKIP_READY=1  skip the unattended-ready refusal (tests)
#   DELIVER_SKIP_PULL=1   skip the per-iteration pull (tests, offline)
#   DELIVER_APP_TOKEN_CMD the command that mints the App installation token
#                         (default .claude/scripts/app-token.sh; tests
#                         substitute a stub). Deliberately an INJECTION POINT
#                         and not a skip flag: there is no way to run the
#                         driver without a non-owner identity, because a run
#                         under the owner's login makes owner-authored.sh a
#                         formality (docs/synthesis.md, D15).

set -uo pipefail

MAX_ITER=20; BUDGET_POINTS=25; MAX_PRS=10; MAX_HOURS=8
WAIT_FOR_OWNER=0; DRY_RUN=0; PRINT_PHASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations) MAX_ITER="${2:-}"; shift 2 ;;
    --budget-points)  BUDGET_POINTS="${2:-}"; shift 2 ;;
    --max-prs)        MAX_PRS="${2:-}"; shift 2 ;;
    --max-hours)      MAX_HOURS="${2:-}"; shift 2 ;;
    --wait-for-owner) WAIT_FOR_OWNER=1; shift ;;
    --dry-run)        DRY_RUN=1; shift ;;
    --print-command)  PRINT_PHASE="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,/^[^#]/p' "$0" | sed -n 's/^# \{0,1\}//p'; exit 0 ;;
    *) echo "deliver-loop: unknown argument: $1" >&2; exit 2 ;;
  esac
done

GH="${GH:-gh}"
APP_TOKEN_CMD="${DELIVER_APP_TOKEN_CMD:-.claude/scripts/app-token.sh}"
ENGINE="${DELIVER_ENGINE:-claude}"
SESSION_TIMEOUT="${SESSION_TIMEOUT:-3600}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-5400}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "deliver-loop: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2
SPAWN=".claude/scripts/spawn-worker.sh"
PHASE_SH=".claude/scripts/deliver-phase.sh"
STATE_DIR=".claude/deliver-loop"
DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
[[ -n "$DEFAULT_BRANCH" ]] || DEFAULT_BRANCH="$(git branch --show-current)"

# The orchestrator session's reach. Explicit and on the command line: the
# whitelist below is everything /orchestrate documents itself doing — spawn
# workers, assemble branches, open one pull request — and nothing else, so
# `git reset --hard`, `--no-verify` and `gh pr merge` are unreachable rather
# than forbidden.
ORCH_TOOLS="${DELIVER_ORCH_TOOLS:-Read,Grep,Glob,Write,Edit,\
Bash(.claude/scripts/spawn-worker.sh:*),\
Bash(git add:*),Bash(git commit:*),Bash(git status:*),Bash(git diff:*),\
Bash(git log:*),Bash(git show:*),Bash(git switch:*),Bash(git checkout:*),\
Bash(git branch:*),Bash(git merge:*),Bash(git push:*),Bash(git worktree:*),\
Bash(gh pr create:*),Bash(gh pr list:*),Bash(gh pr checks:*),Bash(gh pr view:*)}"

# ------------------------------------------------------- command assembly
# One place builds every session command, so --print-command and the real
# dispatch cannot disagree — the same trick spawn-worker.sh uses for CI.
orch_cmd() { # orch_cmd <prompt>
  printf '%s\n' claude -p "$1" \
    --model claude-opus-5 --effort high \
    --permission-mode acceptEdits \
    --allowed-tools "$ORCH_TOOLS"
}

print_command() {
  case "$1" in
    oracle)  "$SPAWN" --print-command --id oracle-N --role oracle \
               --engine claude --base "$DEFAULT_BRANCH" --prompt "<oracle.md + scope>" ;;
    steward) "$SPAWN" --print-command --id steward-ODN --role steward \
               --engine claude --base "$DEFAULT_BRANCH" --prompt "<steward.md + OD id>" ;;
    plan)    "$SPAWN" --print-command --id plan-N --role steward \
               --engine claude --base "$DEFAULT_BRANCH" --prompt "<plan.md + UNATTENDED + milestone>" ;;
    orchestrate) orch_cmd "/orchestrate <slug>" ;;
    acceptance)  orch_cmd "/deliver — acceptance pass only (step 6)" ;;
    *) echo "deliver-loop: unknown phase '$1' (oracle|steward|plan|orchestrate|acceptance)" >&2
       exit 2 ;;
  esac
}
if [[ -n "$PRINT_PHASE" ]]; then print_command "$PRINT_PHASE"; exit 0; fi

log() { echo "deliver-loop: $*"; echo "- $(date -u +%H:%M:%SZ) $*" >> "$STATE_DIR/run.md"; }
die() { echo "deliver-loop: $*" >&2; exit 2; }

# ---------------------------------------------------------------- preflight
[[ -x "$SPAWN" && -x "$PHASE_SH" ]] || die "missing $SPAWN or $PHASE_SH"
command -v "$GH" >/dev/null 2>&1 || die "'$GH' is not on PATH"
"$GH" auth status >/dev/null 2>&1 || die "gh is not authenticated — run: gh auth login"
command -v claude >/dev/null 2>&1 || die "the claude CLI is not on PATH"

[[ -z "$(git status --porcelain)" ]] \
  || die "the working tree is dirty — a run recomputes state from the tree, and uncommitted changes make that state a lie"
CURRENT_BRANCH="$(git branch --show-current)"
[[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]] \
  || die "on branch '$CURRENT_BRANCH', not '$DEFAULT_BRANCH' — the driver dispatches from the default branch only"
if [[ -d .worktrees ]] && [[ -n "$(ls -A .worktrees 2>/dev/null)" ]]; then
  die "leftover worktrees under .worktrees/ — a previous run did not finish assembling; inspect and remove them first"
fi

# ------------------------------------------------- readiness, said out loud
# The owner's ruling: "if the script says the repo is not ready to run
# unattended, then block and fail very loudly. i really need to know before i
# go." So the preflight announces itself before it runs, and both outcomes are
# unmissable — the whole point is that the owner is about to walk away.
banner() { printf '\n%s\n' "════════════════════════════════════════════════════════════════════"; }

if [[ "${DELIVER_SKIP_READY:-0}" != "1" ]]; then
  echo "deliver-loop: checking whether this repository can run unattended…"
  # The refusal, not a warning (docs/DECISIONS.md): a run that cannot succeed
  # is refused at dispatch time, while someone can still act on it.
  if ! .github/scripts/unattended-ready.sh; then
    banner
    echo "  STOP — this repository is NOT ready to run unattended."
    echo "  Nothing has been dispatched. Fix the items listed above and re-run."
    banner
    exit 2
  fi
fi

# ------------------------------------------------------------ the identity
# owner-authored.sh compares the pull request's author login to the CODEOWNERS
# owner. Opening driver pull requests under the owner's own `gh` credentials
# makes that comparison pass for every pull request the driver has ever
# opened — including one carrying an agent's edit to docs/DESIGN.md. Minting
# here rather than at first use means the failure lands NOW, while the owner is
# still watching, instead of three phases in.
APP_TOKEN=""
if ! APP_TOKEN="$("$APP_TOKEN_CMD" 2>&1)"; then
  banner
  echo "  STOP — no usable GitHub App identity, so this run cannot be safe."
  echo
  printf '%s\n' "$APP_TOKEN" | sed 's/^/  /'
  echo
  echo "  Why this blocks the run rather than warning about it:"
  echo "  the driver would otherwise open pull requests as YOU, and"
  echo "  .github/scripts/owner-authored.sh would then report that"
  echo "  docs/DESIGN.md was 'landed by its owner' no matter which agent"
  echo "  wrote it. The guarantee would be printed and absent."
  echo
  echo "  Attended mode needs no App: run /deliver for a single pass and"
  echo "  merge by hand."
  banner
  exit 2
fi
[[ -n "$APP_TOKEN" ]] || die "the App token command printed nothing"
unset APP_TOKEN  # minted fresh per pull request; installation tokens last 1h

mkdir -p "$STATE_DIR"
PROCESSED_FILE="$STATE_DIR/processed-evidence"
touch "$PROCESSED_FILE"
SIG_FILE="$STATE_DIR/failure-signatures"
: > "$SIG_FILE"
{ echo "# Delivery run — $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo; } >> "$STATE_DIR/run.md"

design_sha() { git rev-parse -q --verify "HEAD:docs/DESIGN.md" 2>/dev/null || echo none; }
vision_sha() { git rev-parse -q --verify "HEAD:docs/VISION.md" 2>/dev/null || echo none; }
STEER_DESIGN="$(design_sha)"; STEER_VISION="$(vision_sha)"

START_EPOCH="$(date +%s)"
PR_COUNT=0
BUDGET_START=""
if out="$(.claude/scripts/budget-probe.sh 2>/dev/null)"; then
  BUDGET_START="$(sed -n 's/^session=\([0-9.]*\).*/\1/p' <<<"$out")"
  log "budget probe: starting at ${out} (allowance ${BUDGET_POINTS} points)"
else
  log "budget probe unavailable — ceiling is the hard backstops (${MAX_PRS} PRs, ${MAX_HOURS}h)"
fi

# ------------------------------------------------------------- dispatchers
mechanical_pr() { # mechanical_pr <worker-branch> <docs-ref> <title>
  # The commissioner's half of C5: a worker/<id> branch is neither docs/-
  # exempt nor slug-resolvable, so its head is pushed under a docs/-prefixed
  # name and the pull request opened from that. Mechanical — no judgment.
  git push -q origin "$1:$2" || { log "push $2 failed"; return 1; }
  # Opened as the App, never as the owner. This is the line that makes
  # owner-authored.sh a real boundary instead of a formality: `app[bot]` is not
  # the CODEOWNERS owner, so a driver-opened pull request touching
  # docs/DESIGN.md or docs/VISION.md fails that check — which is the intended
  # behaviour, because the driver has no business landing either document.
  # Minted per pull request because installation tokens expire in an hour and a
  # long run outlives one. The value is passed in the environment of a single
  # command, so it never reaches argv, the run log, or `ps`.
  local token
  if ! token="$("$APP_TOKEN_CMD" 2>/dev/null)" || [[ -z "$token" ]]; then
    log "could not mint an App token for $2 — refusing to open this pull request as the owner"
    return 1
  fi
  GH_TOKEN="$token" "$GH" pr create --head "${2}" \
    --title "$3" \
    --body "Opened mechanically by deliver-loop.sh, as the GitHub App. The content is the branch; the gates are the review." \
    >/dev/null || { log "gh pr create for $2 failed"; return 1; }
  PR_COUNT=$((PR_COUNT + 1))
}

run_worker() { # run_worker <id> <role> <prompt> <docs-ref> <pr-title>
  local id="$1" role="$2" prompt="$3" ref="$4" title="$5"
  log "dispatch $role worker ($id)"
  if ! timeout "$SESSION_TIMEOUT" "$SPAWN" --id "$id" --role "$role" \
       --engine "$ENGINE" --base "$DEFAULT_BRANCH" --prompt "$prompt" \
       >> "$STATE_DIR/run.md" 2>&1; then
    log "$role worker failed — see .claude/orchestration-logs/$id.log"
    return 1
  fi
  mechanical_pr "worker/$id" "$ref" "$title"
}

run_session() { # run_session <label> <prompt>
  log "dispatch $1 session"
  local -a cmd
  mapfile -t cmd < <(orch_cmd "$2")
  if ! timeout "$SESSION_TIMEOUT" "${cmd[@]}" >> "$STATE_DIR/run.md" 2>&1; then
    log "$1 session failed or timed out"
    return 1
  fi
}

record_dismissed_evidence() {
  # The newest handoff's "do not act" list, plus everything the run just made
  # citable — recorded so the loop cannot thrash re-running the oracle over
  # evidence it already ruled on or dismissed. Coarse: any id the newest
  # handoff mentions is one the oracle has READ, which is all "processed"
  # claims.
  local newest
  newest="$(find docs/oracle -name 'handoff-*.md' 2>/dev/null | sort | tail -1)"
  [[ -n "$newest" ]] || return 0
  grep -oE '(ESC|BL)-[0-9]+' "$newest" | sort -u >> "$PROCESSED_FILE"
  sort -u "$PROCESSED_FILE" -o "$PROCESSED_FILE"
}

wait_on_pr() { # wait_on_pr <number> <headref>
  local pr="$1" headref="$2" rc=0
  log "waiting on PR #$pr ($headref) — mechanical watch, no model budget"
  timeout "$WAIT_TIMEOUT" "$GH" pr checks "$pr" --watch --interval 30 \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    log "checks still pending after ${WAIT_TIMEOUT}s — re-detecting"
    return 0
  fi
  if [[ "$rc" -eq 0 ]]; then
    # Green. The exit condition was "no check still pending", and that has
    # been met; now the merge is auto-merge's job. Give it a grace period.
    local waited=0
    while [[ "$waited" -lt 600 ]]; do
      state="$("$GH" pr view "$pr" --json state --jq .state 2>/dev/null)"
      [[ "$state" == "MERGED" ]] && { log "PR #$pr merged"; return 0; }
      [[ "$state" == "CLOSED" ]] && { log "PR #$pr closed unmerged — investigate"; return 0; }
      sleep 30; waited=$((waited + 30))
    done
    # Green and open: an owner-owned path (CODEOWNERS) is the designed cause.
    if [[ "$WAIT_FOR_OWNER" -eq 1 ]]; then
      log "PR #$pr is green and waiting on the owner — polling (--wait-for-owner)"
      sleep 600; return 0
    fi
    log "PR #$pr is green and only the owner can merge it — stopping to report"
    exit 4
  fi
  # Red. Same signature three times is a pattern, not a blip.
  local failing sig count
  failing="$("$GH" pr checks "$pr" 2>/dev/null | awk -F'\t' '$2=="fail"{print $1}' | sort | tr '\n' ' ')"
  sig="$(printf '%s|%s' "$headref" "$failing" | sha1sum | awk '{print $1}')"
  count="$(grep -cxF "$sig" "$SIG_FILE" || true)"
  echo "$sig" >> "$SIG_FILE"
  if [[ "$count" -ge 2 ]]; then
    log "the same checks failed three times on $headref (${failing:-unknown}) — stopping (deliver.md step 5)"
    exit 3
  fi
  log "PR #$pr red (${failing:-unknown}) — dispatching a fix"
  run_session "fix" "PR #$pr on branch $headref has failing required checks: ${failing:-see gh pr checks $pr}. Diagnose from the check output, fix ON THE EXISTING BRANCH ($headref), and push — the open pull request updates; never open a second one. Reproduce the failure locally before pushing. Never weaken a test or a gate to get green." \
    || true
}

# ------------------------------------------------------------- the loop
ITER=0
while :; do
  ITER=$((ITER + 1))
  if [[ "$ITER" -gt "$MAX_ITER" ]]; then
    log "iteration cap ($MAX_ITER) reached"
    exit 5
  fi

  if [[ "${DELIVER_SKIP_PULL:-0}" != "1" ]] && git remote get-url origin >/dev/null 2>&1; then
    git pull -q --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null \
      || log "pull --ff-only failed; continuing on the local tree"
  fi

  # The steering lever working is not an error: the owner edited the design
  # layer, so everything derived from it is re-derived and failure counters
  # reset — a "pattern" spanning an owner edit is two different runs.
  if [[ "$(design_sha)" != "$STEER_DESIGN" || "$(vision_sha)" != "$STEER_VISION" ]]; then
    log "owner edited the design layer — re-deriving everything, resetting failure counters"
    STEER_DESIGN="$(design_sha)"; STEER_VISION="$(vision_sha)"
    : > "$SIG_FILE"
  fi

  # Budget, hard backstops first — they hold whether or not the probe works.
  ELAPSED_H=$(( ($(date +%s) - START_EPOCH) / 3600 ))
  if [[ "$ELAPSED_H" -ge "$MAX_HOURS" ]]; then
    log "wall-clock backstop (${MAX_HOURS}h) reached"; exit 6
  fi
  if [[ "$PR_COUNT" -ge "$MAX_PRS" ]]; then
    log "pull-request backstop (${MAX_PRS}) reached"; exit 6
  fi
  if [[ -n "$BUDGET_START" ]] && out="$(.claude/scripts/budget-probe.sh 2>/dev/null)"; then
    now="$(sed -n 's/^session=\([0-9.]*\).*/\1/p' <<<"$out")"
    spent="$(awk -v a="$now" -v b="$BUDGET_START" 'BEGIN{print (a-b)}')"
    if awk -v s="$spent" -v cap="$BUDGET_POINTS" 'BEGIN{exit !(s >= cap)}'; then
      log "budget allowance spent (${spent} of ${BUDGET_POINTS} points)"; exit 6
    fi
  fi

  # What next? Recomputed from the world, never remembered.
  PHASE=""; PR=""; HEADREF=""; UNRULED=""; UNCITED=""; ODS=""; REQS=""; SLUG=""; REASON=""
  while IFS='=' read -r k v; do
    case "$k" in
      PHASE) PHASE="$v" ;; PR) PR="$v" ;; HEADREF) HEADREF="$v" ;;
      UNRULED) UNRULED="$v" ;; UNCITED) UNCITED="$v" ;; ODS) ODS="$v" ;;
      REQS) REQS="$v" ;; SLUG) SLUG="$v" ;; REASON) REASON="$v" ;;
    esac
  done < <(GH="$GH" PROCESSED_FILE="$PROCESSED_FILE" "$PHASE_SH")
  [[ -n "$PHASE" ]] || die "phase detection failed"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "PHASE=$PHASE"
    for kv in "PR=$PR" "HEADREF=$HEADREF" "UNRULED=$UNRULED" "UNCITED=$UNCITED" \
              "ODS=$ODS" "REQS=$REQS" "SLUG=$SLUG" "REASON=$REASON"; do
      [[ -n "${kv#*=}" ]] && echo "$kv"
    done
    exit 0
  fi

  log "iteration $ITER: phase $PHASE"
  case "$PHASE" in
    SETUP)
      log "setup problem: $REASON — /design is interactive and owner-landed; the loop cannot do it"
      exit 2 ;;
    WAIT)
      wait_on_pr "$PR" "$HEADREF" ;;
    ORACLE)
      scope="Scope for this run: ${UNRULED:+rule on the filed uncertainties: $UNRULED.} ${UNCITED:+work the logged evidence: $UNCITED.}"
      run_worker "oracle-$(date -u +%Y%m%d%H%M%S)" oracle \
        "$(cat .claude/commands/oracle.md)

UNATTENDED RUN. The delivery driver commissioned this session. $scope" \
        "docs/oracle-$(date -u +%Y%m%d%H%M%S)" \
        "Oracle: rulings and handoff" || true
      record_dismissed_evidence ;;
    STEWARD)
      od="${ODS%% *}"
      run_worker "steward-${od,,}" steward \
        "$(cat .claude/commands/steward.md)

UNATTENDED RUN. The decision to plan: $od" \
        "docs/oracle-plan-${od,,}" \
        "Plan for $od" || true ;;
    PLAN)
      run_worker "plan-$(date -u +%Y%m%d%H%M%S)" steward \
        "$(cat .claude/commands/plan.md)

UNATTENDED. The delivery driver commissioned this session; follow the
unattended branches of the gate above. Requirements still unplanned: $REQS.
Plan the next milestone of docs/DESIGN.md that delivers them (or file the
uncertainties that block it)." \
        "docs/plan-$(date -u +%Y%m%d%H%M%S)" \
        "Plan: next milestone ($REQS)" || true ;;
    ORCHESTRATE)
      run_session "orchestrate" "/orchestrate $SLUG" || true
      PR_COUNT=$((PR_COUNT + 1)) ;;
    ACCEPTANCE)
      if [[ -f "$STATE_DIR/acceptance-dispatched" ]]; then
        log "acceptance recorded and nothing is open — the run is complete"
        log "report: $STATE_DIR/run.md; the honest bottom line is the pending-on-owner list in docs/acceptance.md"
        exit 0
      fi
      touch "$STATE_DIR/acceptance-dispatched"
      run_session "acceptance" "/deliver — run ONLY step 6, the acceptance pass: check the built system against docs/DESIGN.md §13, record evidence per criterion in docs/acceptance.md, mark owner-only criteria pending with exactly what the owner should run. Land it on a docs/ branch and open the pull request." || true
      PR_COUNT=$((PR_COUNT + 1)) ;;
    *)
      die "unknown phase '$PHASE'" ;;
  esac
done
