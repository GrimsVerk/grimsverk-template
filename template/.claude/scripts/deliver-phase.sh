#!/usr/bin/env bash
#
# deliver-phase.sh — read the world, say what the delivery loop does next.
#
# The phase logic for unattended delivery lives HERE, once, and both drivers
# consume it: `deliver-loop.sh` on a local machine, and the `/deliver-loop`
# command in a Claude Code web session. One detector is what keeps the two
# modes from drifting — a phase bug is fixed in one place and both inherit it.
#
# READ-ONLY by contract. This script mutates nothing: no commits, no pushes,
# no sessions. It recomputes the project's state from the tree and the open
# pull requests every time it runs, because recomputed state cannot go stale
# and cannot be corrupted by a killed run — the driver persists almost nothing
# and trusts none of what it does persist.
#
# Output: KEY=VALUE lines, PHASE first, then BASE (the base branch this
# detection was scoped to), then BASE_SHA (the commit of the checkout this
# detection actually read — a phase reading nobody can date is a reading
# nobody can check, ESC-215). The phases, in detection priority:
#
#   PHASE=WAIT PR=<n> HEADREF=<ref>   an open pipeline pull request TARGETING
#                                     THIS RUN'S BASE BRANCH — nothing is
#                                     dispatched while one is open (the
#                                     one-PR-per-base rule, AGENTS.md); wait on
#                                     its checks
#   PHASE=ORACLE REASON=uncertainties UNRULED=<BL ids>
#                                     a plan filed HIGH-risk uncertainties and
#                                     no decision cites them yet — planning is
#                                     blocked until the oracle rules. HIGH is
#                                     the ONE class of new question that
#                                     outranks decided work
#   PHASE=STEWARD ODS=<OD ids>        landed decisions added requirements no
#                                     plan covers — one steward per decision.
#                                     Ranked ABOVE new-evidence intake
#                                     (ESC-217): a ruling nobody plans is the
#                                     leak that cost the 2026-08-20 runs most
#   PHASE=ORCHESTRATE SLUG=<slug>     a landed plan with no merged feat/ pull
#                                     request, and whose front matter does not
#                                     say `status: merged` — build it. Also
#                                     ranked above new-evidence intake
#                                     (ESC-218): decided work outranks new
#                                     questions
#   PHASE=ORACLE REASON=evidence UNCITED=<ids>
#                                     logged evidence (escapes, backlog items,
#                                     LOW uncertainties) no decision has
#                                     metabolised, no closure in
#                                     docs/escapes.done.md has finished, and no
#                                     prior oracle run has dismissed — after
#                                     decided work, before any NEW milestone is
#                                     planned on a possibly-wrong design
#   PHASE=PLAN REQS=<R ids>           owner-side requirements no plan covers —
#                                     plan the next milestone
#
#   Every reading from STEWARD down also carries the economy counters
#   OPEN_DECISIONS= UNBUILT_PLANS= EVIDENCE= — the loop's scoreboard, logged
#   by the driver every iteration (ESC-218)
#   PHASE=ACCEPTANCE [CRITERIA=<S ids>]
#                                     everything planned and merged — check
#                                     the built system against the design's
#                                     success criteria. CRITERIA lists the
#                                     scripted criteria failing right now, as
#                                     information for the acceptance session;
#                                     the route out of a failing one is the
#                                     ORACLE phase, reached because the
#                                     acceptance pass files it as a BL-<n>
#   PHASE=SETUP REASON=<text>         coverage.sh rc 2: no design, or a design
#                                     without ids. /design is interactive and
#                                     owner-landed; no loop can do it
#
# Optional env:
#   GH              default: gh      (tests substitute a stub)
#   RUN_BASE        the base branch this run merges into. Defaults to the
#                   repository's default branch (origin/HEAD, falling back to
#                   the current branch). Every pull-request query below is
#                   scoped to it: a pull request targeting a DIFFERENT base
#                   belongs to a different run and neither holds this loop nor
#                   marks this run's plans built. Two PRs into one base is
#                   still illegal; two PRs into two separate bases is two runs.
#   PROCESSED_FILE  a file of evidence ids (one per line) a previous oracle run
#                   read and explicitly declined to act on — the driver records
#                   these from the handoff so the loop cannot thrash re-running
#                   the oracle over evidence it already dismissed
#   BACKLOG, LEDGER, DONE_LEDGER, ORACLE_DOC, PLANS_DIR, ACCEPTANCE_DIR
#                   the usual overrides

# No -e: this file is greps all the way down, and under errexit a grep that
# legitimately matches nothing aborts the whole detection mid-phase. Failures
# that matter are handled by hand.
set -uo pipefail

GH="${GH:-gh}"
BACKLOG="${BACKLOG:-docs/BACKLOG.md}"
LEDGER="${LEDGER:-docs/escapes.md}"
DONE_LEDGER="${DONE_LEDGER:-docs/escapes.done.md}"
ORACLE_DOC="${ORACLE_DOC:-docs/DESIGN.oracle.md}"
PLANS_DIR="${PLANS_DIR:-docs/plans}"
ACCEPTANCE_DIR="${ACCEPTANCE_DIR:-acceptance}"
PROCESSED_FILE="${PROCESSED_FILE:-}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "deliver-phase: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2

# The base branch this run merges into. Scoping every pull-request query to it
# is what lets two runs share one repository on two separate base branches:
# each detector sees only its own run's pull requests. Defaults to the
# repository's default branch, so a single-run repository behaves as before.
if [[ -z "${RUN_BASE:-}" ]]; then
  RUN_BASE="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
  [[ -n "$RUN_BASE" ]] || RUN_BASE="$(git branch --show-current)"
fi

# THE READING IS DATED, AND A STALE CHECKOUT SAYS SO OUT LOUD (ESC-215). This
# detector is only ever as current as the checkout it runs in, and nothing in
# its output used to say which commit that was — so a run on a tree three
# commits behind its remote produced an honest reading of a stale world, and
# the reading was reported onward as though it described the real base. A
# phase reading nobody can date is a reading nobody can check. So:
#   - every report below carries BASE_SHA= — the commit this detection read —
#     beside its BASE= line (the driver's KEY=VALUE parser ignores keys it
#     does not know, so the extra line costs nothing);
#   - a checkout behind its remote-tracking ref gets a loud warning first, on
#     STDERR so the KEY=VALUE contract on stdout stays clean. The check is a
#     cheap rev-list count, guarded: a branch with no upstream (a fresh
#     repository, a detached head, a test fixture) skips it silently rather
#     than failing the detection.
BASE_SHA="$(git rev-parse --verify HEAD 2>/dev/null || echo unknown)"
emit_base() {
  printf 'BASE=%s\n' "$RUN_BASE"
  echo "BASE_SHA=$BASE_SHA"
}
if UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  BEHIND="$(git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)"
  if [[ "$BEHIND" -gt 0 ]]; then
    {
      echo "deliver-phase: WARNING — this checkout is $BEHIND commit(s) BEHIND $UPSTREAM."
      echo "deliver-phase: the phase below describes $BASE_SHA, not the remote tip. Pull the base branch before trusting it."
    } >&2
  fi
fi

# REST, never GraphQL, for every API read this script makes. A hosted web
# session's egress proxy serves REST plus only a pinned set of review GraphQL
# operations — `gh pr list` is GraphQL, so on that platform it dies with an
# error that blames the credential, which is fine (ESC-51). REST answers the
# same questions and works everywhere, so there is ONE code path, not a local
# one and a hosted one. The repository name comes from the git remote for the
# same reason: `gh repo view` is GraphQL too.
if [[ -z "${REPO:-}" ]]; then
  REPO="$(git remote get-url origin 2>/dev/null \
    | sed -E 's#^(git@[^:/]+:|https?://[^/]+/|ssh://git@[^/]+/)##; s#\.git$##')"
fi
[[ -n "$REPO" ]] \
  || { echo "deliver-phase: cannot resolve owner/repo from the origin remote" >&2; exit 2; }

# ------------------------------------------------- 1. an open pipeline PR?
# Any open pull request TARGETING THIS RUN'S BASE holds the loop: the one-PR
# rule is about the tree the checks tested being the tree the merge lands on,
# and that is violated by ANY concurrent merge into the same base, not just a
# feature's. A pull request into a DIFFERENT base lands on a different tree —
# it belongs to a different run and is deliberately not this loop's business.
OPEN_PR="$("$GH" api "repos/$REPO/pulls?state=open&base=$RUN_BASE&per_page=30" \
  --jq '.[0] | "\(.number) \(.head.ref)"' 2>/dev/null || true)"
if [[ -n "$OPEN_PR" && "$OPEN_PR" != "null null" ]]; then
  echo "PHASE=WAIT"
  emit_base
  echo "PR=${OPEN_PR%% *}"
  echo "HEADREF=${OPEN_PR#* }"
  exit 0
fi

# Ids a decision in the ledger cites anywhere. Coarse on purpose: the precise
# per-decision resolution belongs to oracle-decisions.sh at merge time; here a
# cited id just means "the oracle has seen this".
cited() {
  [[ -f "$ORACLE_DOC" ]] && grep -oE '(ESC|BL)-[0-9]+' "$ORACLE_DOC" | sort -u || true
}
CITED_IDS="$(cited)"
is_cited() { grep -qxF "$1" <<<"$CITED_IDS"; }
is_processed() {
  [[ -n "$PROCESSED_FILE" && -f "$PROCESSED_FILE" ]] \
    && grep -qxF "$1" "$PROCESSED_FILE"
}

# Ids the repository records as FINISHED, in docs/escapes.done.md. An
# append-only ledger cannot be edited to mark something done, so "closed" had
# nowhere to live that a script could read — and this detector consequently
# handed the oracle every escape a project had ever logged, including ones fixed
# months earlier with a demonstrated check.
#
# COMMITTED, which is the half that matters. The processed-evidence file above
# is gitignored: it survives on one laptop and vanishes with a reclaimed web
# container, so the same repository gave two different answers depending on
# where the driver ran. A closure is a fact in git and reads the same everywhere.
#
# It is not a free pass. escapes-append-only.sh holds this file immutable and
# refuses a closure that does not name a path that exists, so a row here is a
# claim somebody can open rather than an assertion that something is fine.
closed() {
  [[ -f "$DONE_LEDGER" ]] && grep -E '^\|' "$DONE_LEDGER" | grep -oE 'ESC-[0-9]+' | sort -u || true
}
CLOSED_IDS="$(closed)"
is_closed() { grep -qxF "$1" <<<"$CLOSED_IDS"; }

# --------------------------------- 2. HIGH uncertainties with no ruling yet?
# Items in the backlog's uncertainties section. A HIGH uncertainty blocks
# planning by design — it is the one guess the planner was not allowed to
# proceed on.
#
# THE CLASSIFICATION IS MATCHED ANYWHERE IN THE ITEM'S BLOCK — from the list
# line that opens it (`- **BL-<n>** …`) to the line that opens the next item
# or ends the section — NOT only on its first line (ESC-209). The
# first-line-only read shipped, and no real entry ever satisfied it: every
# worker opens the item with the question and puts `**HIGH**:` in the body,
# where the reasoning for the classification belongs. So this branch had
# never fired once on a live run — every blocked question reached the oracle
# through the section-3 catch-all instead, indistinguishable from an unread
# escape, and REASON=uncertainties was decorative. A check that silently does
# nothing is the exact shape this template distrusts everywhere else.
UNRULED=""
if [[ -f "$BACKLOG" ]]; then
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    is_cited "$id" && continue
    UNRULED="$UNRULED $id"
  done < <(awk '
    /^## Uncertainties awaiting oracle ruling/ { insec=1; next }
    insec && /^## / { insec=0 }
    !insec { next }
    # A new item: a list line carrying a BL id. Everything up to the next such
    # line belongs to this item, so a HIGH in item N+1 never marks item N.
    /^- / && match($0, /BL-[0-9]+/) {
      if (id != "" && high) print id
      id = substr($0, RSTART, RLENGTH); high = 0
    }
    # HIGH as a word, anywhere in the block — `**HIGH**:` mid-body included.
    id != "" && /(^|[^A-Za-z0-9_])HIGH([^A-Za-z0-9_]|$)/ { high = 1 }
    END { if (id != "" && high) print id }
  ' "$BACKLOG")
fi
if [[ -n "${UNRULED# }" ]]; then
  echo "PHASE=ORACLE"
  emit_base
  echo "REASON=uncertainties"
  echo "UNRULED=${UNRULED# }"
  exit 0
fi

# --------------------------------------- 3. evidence nobody has read? (COUNTED)
# Every real id in the ledgers, minus what a decision cites, minus what a
# prior run explicitly dismissed. COMPUTED here, ACTED ON further down
# (ESC-218): this used to exit straight to ORACLE, which put "any uncited id
# anywhere" ahead of every planning and build phase — so the loop's stable
# state was design-layer work, and in 1650 recorded events of the 2026-08-20
# experiment the build phase was reached once, under a broken gate. The rule
# now is the one AGENTS.md always stated for LOW items: decided work outranks
# new questions. Only a HIGH uncertainty (section 2, above) blocks everything;
# ordinary evidence waits its turn behind stewards and builds, and still comes
# BEFORE planning a new milestone — the oracle rules on a possibly-wrong
# design before more work is planned against it, which remains the role's
# point.
UNCITED=""
IDS_TMP="$(mktemp)"
{
  [[ -f "$LEDGER"  ]] && grep -E '^\|' "$LEDGER" | grep -oE 'ESC-[0-9]+' || true
  # SECTION-AWARE INTAKE (ESC-230). Only the Uncertainties section's ids are
  # questions somebody filed FOR the oracle. This used to grep the whole
  # backlog, which swept owner-filed Proposed ideas — items the rules say are
  # never coded unprompted — into the oracle's inbox as commissioned
  # evidence, and they got rulings nobody asked for. Proposed and Approved
  # ids now wait until a decision cites them; the count of what waits is on
  # every reading, so a wrongly-sectioned item is visible, never vanished.
  [[ -f "$BACKLOG" ]] && awk '
      /^## Uncertainties awaiting oracle ruling/ { insec = 1; next }
      /^## /  { insec = 0 }
      insec' "$BACKLOG" | grep -oE 'BL-[0-9]+' || true
} | sort -u > "$IDS_TMP" || true
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  is_cited "$id" && continue
  is_closed "$id" && continue
  is_processed "$id" && continue
  UNCITED="$UNCITED $id"
done < "$IDS_TMP"
PROPOSED_SKIPPED=0
if [[ -f "$BACKLOG" ]]; then
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    grep -qw -- "$id" "$IDS_TMP" && continue
    is_cited "$id" && continue
    PROPOSED_SKIPPED=$((PROPOSED_SKIPPED + 1))
  done < <(grep -oE 'BL-[0-9]+' "$BACKLOG" | sort -u)
fi
rm -f "$IDS_TMP"
UNCITED="${UNCITED# }"

# THE ECONOMY COUNTERS, on every reading below (ESC-218). The 2026-08-20 runs
# ended with 35 of 58 decisions never planned and nothing in any run report
# that could have said so. These three numbers are the loop's scoreboard; the
# driver logs them every iteration, so a run that is all design and no build
# reads that way while it is happening rather than in a post-mortem.
OPEN_DECISIONS=""
UNBUILT_PLANS=""
BRAKED=""   # filled by the brake pass below; empty until then
emit_counts() {
  [[ -n "$OPEN_DECISIONS" ]] && echo "OPEN_DECISIONS=$OPEN_DECISIONS"
  [[ -n "$UNBUILT_PLANS"  ]] && echo "UNBUILT_PLANS=$UNBUILT_PLANS"
  echo "EVIDENCE=$(wc -w <<<"$UNCITED" | tr -d ' ')"
  [[ "${PROPOSED_SKIPPED:-0}" -gt 0 ]] && echo "PROPOSED_SKIPPED=$PROPOSED_SKIPPED"
  [[ -n "$BRAKED" ]] && echo "BRAKED=$BRAKED"
  return 0
}

# ------------------------------------------------------- 4. coverage gaps?
COV_RC=0
COV_OUT="$(.github/scripts/coverage.sh 2>&1)" || COV_RC=$?
STEWARD_ODS=""
PLAN_REQS=""
case "$COV_RC" in
  2)
    echo "PHASE=SETUP"
    emit_base
    emit_counts
    echo "REASON=$(head -1 <<<"$COV_OUT")"
    exit 0 ;;
  1)
    GAPS="$(sed -n 's/^.*requirement(s) with no plan: //p' <<<"$COV_OUT" | head -1)"
    # Oracle-added requirements (R1000 and up) are planned by a steward from
    # their decision; owner requirements are planned as a milestone. Stewards
    # first: those decisions exist because the design was WRONG, and building
    # more against the uncorrected shape is the waste the oracle exists to
    # stop.
    for req in $GAPS; do
      n="${req#R}"
      if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -ge 1000 ]]; then
        od="$(grep -B100 -- "- \*\*Requirements added:\*\*.*\b$req\b" "$ORACLE_DOC" 2>/dev/null \
              | grep -oE '^## OD-[0-9]+' | tail -1 | sed 's/^## //' || true)"
        [[ -n "$od" ]] && ! grep -qF "$od" <<<"$STEWARD_ODS" && STEWARD_ODS="$STEWARD_ODS $od"
      else
        PLAN_REQS="$PLAN_REQS $req"
      fi
    done
    STEWARD_ODS="${STEWARD_ODS# }"
    PLAN_REQS="${PLAN_REQS# }" ;;
esac

# ------------------------------------- 5. planned and merged, but unbuilt?
# A plan is BUILT when a feat/ pull request carrying its slug has merged INTO
# THIS RUN'S BASE. The feat/ prefix matters: the plan's own docs/ pull request
# also carries the slug, and counting it would mark every plan built the moment
# it landed. The --base scope matters just as much: a twin run on another base
# branch merges the same slugs, and counting ITS merges would mark this run's
# plans built with the work simply absent here.
# REST has no state=merged filter: closed pull requests include unmerged ones,
# and merged is the merged_at field being set. --paginate replaces --limit 200.
UNBUILT_SLUGS=""
MERGED_REFS="$("$GH" api --paginate "repos/$REPO/pulls?state=closed&base=$RUN_BASE&per_page=100" \
  --jq '.[] | select(.merged_at != null) | .head.ref' 2>/dev/null || true)"
#
# WHICH STRING IDENTIFIES A PLAN. The front-matter `slug:` field, not the
# filename. plan-resolve.sh — the check that decides which plan a branch
# implements — reads the field, and this used to read `basename`, so the two
# halves of the system identified the same object by different names and
# nothing reconciled them. A plan filed as `sync.md` with `slug:
# milestone-4-sync-transport` was matched against an earlier merged
# `feat/sync-index-1` by prefix, marked built, and never orchestrated. No pull
# request was ever opened for it, so no gate ever got the chance to notice:
# coverage.sh reported its requirements covered, the loop walked to ACCEPTANCE,
# and the run exited 0 with the work simply absent.
#
# The match is also anchored at both ends now. `^feat/.*${slug}` let any slug
# that is a substring of a merged branch count as built — the exact collision
# plan-resolve.sh treats as a hard error ("a slug that is a substring of
# another, like 'auth' and 'auth-tokens', will always collide"), which it can
# only do for branches somebody actually opened. Here the whole point is that
# nobody opens one, so the guard has to live on this side too.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ "$(basename "$f")" == _* ]] && continue
  # The authoritative slug, read the same way plan-resolve.sh reads it. Fall
  # back to the filename only when a plan has no field at all — plan-lint.sh
  # fails such a plan on its own pull request, so this is a courtesy, not a
  # path anything should rely on.
  slug="$(awk '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { infm=1; next }
    infm && $0 ~ /^---[[:space:]]*$/  { exit }
    infm && $0 ~ /^slug:/ { sub(/^slug:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }
  ' "$f" 2>/dev/null | head -1)"
  [[ -n "$slug" ]] || slug="$(basename "$f" .md)"

  # A plan that DECLARES its work landed is built, whatever the branch names
  # say. `status: merged` is already in the plan template's vocabulary
  # (draft | in-flight | merged) and this is what it was for.
  #
  # Without it, a RETROSPECTIVE plan — one written to record work that shipped
  # before the plan existed — can never be satisfied: no `feat/<slug>` branch
  # will ever be merged for it, so the detector asks for an orchestrator to
  # build what is already there, forever. The same is true of any plan whose
  # work landed on a branch that did not follow the convention.
  #
  # It is a declaration and not a proof, which is the honest description. What
  # makes it safe to trust is where it lives: docs/plans/ is CODEOWNERS-owned,
  # so setting this word is the owner's, and the review gate reads the diff that
  # sets it. The steward's docs/plans/oracle/ is deliberately NOT owned — a plan
  # there that declared itself built without building anything would be an
  # escape, and the ratchet applies.
  status="$(awk '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { infm=1; next }
    infm && $0 ~ /^---[[:space:]]*$/  { exit }
    infm && $0 ~ /^status:/ { sub(/^status:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/["'"'"']/, ""); print; exit }
  ' "$f" 2>/dev/null | head -1)"
  [[ "$status" == "merged" ]] && continue

  # Anchored: the branch is `feat/<slug>` or `feat/<slug>-<something>`, never
  # `feat/<slug-as-a-substring-of-a-different-name>`.
  #
  # COLLECTED rather than exited on (ESC-218): the count of unbuilt plans is
  # one of the three economy counters every reading below carries, so the walk
  # runs to the end and the dispatch decision is taken after it.
  if ! grep -qE "^feat/${slug}([/-][^/]*)?$" <<<"$MERGED_REFS"; then
    UNBUILT_SLUGS="$UNBUILT_SLUGS $slug"
  fi
done < <(find "$PLANS_DIR" -name '*.md' 2>/dev/null | sort)
UNBUILT_SLUGS="${UNBUILT_SLUGS# }"

# ------------------------------- the per-target brake (ESC-221, ruling Q1)
# The one legal move the oracle has against a poisoned work item. On the
# 2026-08-20 run the oracle diagnosed a stuck driver IN WRITING — "nothing an
# oracle may write can [unstick it]" — and was right: the driver reads no
# prose, so a quarter of that ledger exists only to make the loop harmless.
# docs/oracle/do-not-dispatch.md is machine-readable: a column-0 list line
# naming an `OD-<n>` or a `plan:<slug>`, with the reason after a dash. The
# detector routes around a fenced target and REPORTS the skip; the driver
# logs it loudly. It is a brake on one lane, never on the run (the owner's
# Q1 ruling: no run-halt authority) — and it can only remove work from a
# queue, never make a check pass, so the worst it can do is an idle run that
# says exactly why it is idle, on every reading.
BRAKE_FILE="${BRAKE_FILE:-docs/oracle/do-not-dispatch.md}"
if [[ -f "$BRAKE_FILE" ]]; then
  BRAKED_TARGETS="$(grep -E '^[-*] ' "$BRAKE_FILE" \
    | grep -oE '(OD-[0-9]+|plan:[A-Za-z0-9][A-Za-z0-9-]*)' | sort -u || true)"
  if [[ -n "$BRAKED_TARGETS" ]]; then
    kept=""
    for od in $STEWARD_ODS; do
      if grep -qxF "$od" <<<"$BRAKED_TARGETS"; then
        BRAKED="$BRAKED $od"
      else
        kept="$kept $od"
      fi
    done
    STEWARD_ODS="${kept# }"
    kept=""
    for slug in $UNBUILT_SLUGS; do
      if grep -qxF "plan:$slug" <<<"$BRAKED_TARGETS"; then
        BRAKED="$BRAKED plan:$slug"
      else
        kept="$kept $slug"
      fi
    done
    UNBUILT_SLUGS="${kept# }"
    BRAKED="${BRAKED# }"
  fi
fi
OPEN_DECISIONS="$(wc -w <<<"$STEWARD_ODS" | tr -d ' ')"
UNBUILT_PLANS="$(wc -w <<<"$UNBUILT_SLUGS" | tr -d ' ')"

# --------------------- the ladder: decided work outranks new questions
# ESC-217 / ESC-218, the 2026-08-20 correction. Order below WAIT and the HIGH
# veto: close open decisions (STEWARD), build merged-but-unbuilt plans
# (ORCHESTRATE), then feed waiting evidence to the oracle, then plan the next
# milestone, then acceptance. Evidence still precedes MILESTONE planning —
# ruling on a possibly-wrong design before planning more against it is the
# oracle's point — but it no longer starves work the design layer has already
# decided.
if [[ -n "$STEWARD_ODS" ]]; then
  echo "PHASE=STEWARD"
  emit_base
  emit_counts
  echo "ODS=$STEWARD_ODS"
  exit 0
fi

if [[ -n "$UNBUILT_SLUGS" ]]; then
  echo "PHASE=ORCHESTRATE"
  emit_base
  emit_counts
  echo "SLUG=${UNBUILT_SLUGS%% *}"
  exit 0
fi

if [[ -n "$UNCITED" ]]; then
  echo "PHASE=ORACLE"
  emit_base
  emit_counts
  echo "REASON=evidence"
  echo "UNCITED=$UNCITED"
  exit 0
fi

if [[ -n "$PLAN_REQS" ]]; then
  echo "PHASE=PLAN"
  emit_base
  emit_counts
  echo "REQS=$PLAN_REQS"
  exit 0
fi

# ---------------------------------------------------------------- 6. done
# ...and say which scripted success criteria are currently failing, so the
# acceptance session is told what it is walking into rather than discovering it.
#
# Reported, never branched on. A failing criterion does not become its own
# phase: the route out of one is the ORACLE phase above, reached because the
# acceptance pass FILES the failure as a BL-<n>. Making it a phase here would
# put the loop in charge of deciding a criterion is unmeetable, which is exactly
# the judgement docs/acceptance.md exists to keep away from the pipeline.
echo "PHASE=ACCEPTANCE"
emit_base
emit_counts
FAILING=""
if [[ -d "$ACCEPTANCE_DIR" ]]; then
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    bash "$s" >/dev/null 2>&1 || FAILING="$FAILING $(basename "$s" .sh)"
  done < <(find "$ACCEPTANCE_DIR" -maxdepth 1 -name 'S[0-9]*.sh' 2>/dev/null | sort)
fi
[[ -n "${FAILING# }" ]] && echo "CRITERIA=${FAILING# }"
exit 0
