#!/usr/bin/env bash
#
# sweep-branches.sh — delete the branches this lane has finished with.
#
#     .claude/scripts/sweep-branches.sh [--base <branch>] [--dry-run]
#
# WHAT WAS WRONG. Cleanup existed and covered one case: the close-event job and
# the nightly sweep in auto-merge.yml both key on `merged == true`, deliberately
# — a closed-but-unmerged branch is often the only copy of its work. Right for
# one branch, wrong for a bed that runs for days: a pull request that stalls or
# is closed leaves its branch for ever, and the owner ends up reading a screenful
# of branches to find the two that matter.
#
# THE ASYMMETRY THAT MADE IT VISIBLE. Every leftover belonged to the WEB lane;
# the local lane's were gone. A hosted session cannot delete a remote ref at
# all: the egress proxy answers `git push --delete` and `DELETE
# /git/refs/heads/...` with 403 while allowing branch CREATION, so the lane
# that most needs a sweep is the one that cannot run one. That is a fact about
# the platform, not a bug to fix here — so this script SAYS it rather than
# failing silently, and the branches it could not delete are named for whoever
# can.
#
# WHAT IT WILL DELETE, and nothing else: a remote branch that is FULLY MERGED
# into the base. That is the same test GitHub applies to a merged pull
# request's head, so it can lose no work by construction. Unmerged branches are
# listed and left alone — an unmerged branch is either live work or the only
# copy of something, and neither is a machine's call at 3am.
#
# NEVER TOUCHED: the base itself, the default branch, anything under chore/ — a
# lane's ledger lives there and is deliberately never merged — and any branch an
# OPEN pull request still names as head or base, which is the same guard the
# nightly sweep applies so a stacked pull request cannot lose its base.
#
# Exit codes: 0 swept (or nothing to sweep), 2 cannot ask (not a repository,
# no origin). Never non-zero for a branch it could not delete: this is
# housekeeping, and housekeeping that fails a run has inverted its job.
set -uo pipefail

BASE=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)    BASE="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,/^set -/p' "$0" | sed -n 's/^# \{0,1\}//p'; exit 0 ;;
    *) echo "sweep-branches: unknown argument: $1" >&2; exit 2 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "sweep-branches: not inside a git repository" >&2; exit 2; }
git remote get-url origin >/dev/null 2>&1 \
  || { echo "sweep-branches: no origin remote" >&2; exit 2; }

DEFAULT_BRANCH="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's#^origin/##')"
[[ -n "$DEFAULT_BRANCH" ]] || DEFAULT_BRANCH="main"
[[ -n "$BASE" ]] || BASE="$DEFAULT_BRANCH"

git fetch -q --prune origin 2>/dev/null || true
git rev-parse -q --verify "refs/remotes/origin/$BASE" >/dev/null 2>&1 \
  || { echo "sweep-branches: origin/$BASE does not exist — nothing to sweep against" >&2; exit 2; }

say() { echo "sweep-branches: $*"; }

# Branches an OPEN pull request still needs, as head or as base. Best-effort:
# with no gh on PATH the sweep still runs, and its merged-into-base test already
# means it cannot delete unmerged work.
INUSE=""
GH="${GH:-gh}"
if command -v "$GH" >/dev/null 2>&1; then
  REPO="$(git remote get-url origin 2>/dev/null \
    | sed -E 's#^(git@[^:/]+:|https?://[^/]+/|ssh://git@[^/]+/)##; s#\.git$##')"
  [[ -n "$REPO" ]] && INUSE="$("$GH" api "repos/$REPO/pulls?state=open&per_page=100" \
    --jq '.[] | .head.ref, .base.ref' 2>/dev/null | sort -u || true)"
fi

DELETED=0; REFUSED=(); KEPT=()
while read -r ref; do
  b="${ref#origin/}"
  [[ -n "$b" && "$b" != "HEAD" ]] || continue
  # Never the base, never the default branch, never a ledger.
  [[ "$b" == "$BASE" || "$b" == "$DEFAULT_BRANCH" ]] && continue
  case "$b" in chore/*) continue ;; esac
  if [[ -n "$INUSE" ]] && grep -qxF "$b" <<<"$INUSE"; then KEPT+=("$b"); continue; fi
  # MERGED INTO THE BASE is the whole test. Anything else is left alone.
  git merge-base --is-ancestor "origin/$b" "origin/$BASE" 2>/dev/null || { KEPT+=("$b"); continue; }
  if [[ "$DRY" -eq 1 ]]; then
    say "would delete $b (merged into $BASE)"
    DELETED=$((DELETED + 1)); continue
  fi
  if git push -q origin --delete "$b" 2>/dev/null; then
    DELETED=$((DELETED + 1))
  else
    REFUSED+=("$b")
  fi
done < <(git branch -r --format='%(refname:short)' 2>/dev/null)

say "$DELETED merged branch(es) deleted, ${#KEPT[@]} unmerged left alone, ${#REFUSED[@]} refused."
if [[ ${#REFUSED[@]} -gt 0 ]]; then
  say "COULD NOT DELETE these merged branches: ${REFUSED[*]}"
  say "A hosted session is refused ref deletion by its egress proxy (403), so this"
  say "is expected in web mode and is not a failure of the run. Delete them from a"
  say "terminal, or in the repository's branch list."
fi
if [[ ${#KEPT[@]} -gt 0 ]]; then
  say "left alone (not merged into $BASE): ${KEPT[*]}"
fi
exit 0
