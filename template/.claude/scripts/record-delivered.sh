#!/usr/bin/env bash
#
# record-delivered.sh — append what actually shipped to docs/DESIGN.oracle.done.md.
#
# THE PROBLEM THIS EXISTS FOR. A planner could not tell what had already been
# built. `coverage.sh` reports which requirements a plan CLAIMS, and says so in
# its own output — "covered means PLANNED, not delivered and not verified". The
# nearest thing to an answer was a plan's `status:` field, which is set by hand,
# so on a real project every plan still read `status: draft` long after its work
# had shipped. A steward planning the next piece was therefore working from a
# record of what somebody remembered to write down.
#
# So this reads the one fact that cannot go stale: a MERGED pull request. For
# every `feat/<slug>` merged into the run's base, the plan carrying that slug is
# found and its `covers:` ids are appended here, once each.
#
# APPEND ONLY, AND IDEMPOTENT. An id already recorded is skipped, so this is
# safe to run at every stop of every run. The file is held append-only in CI by
# backlog-append-only.sh, so a line that has landed cannot be reworded later.
#
# IT RECORDS, IT DOES NOT DECIDE. Delivered is not finished and not verified: a
# delivered requirement stays a requirement, and the day the system stops
# satisfying it is a regression. Nothing leaves the design because it was
# built — that is docs/DESIGN.oracle.retired.md, a different question, and the
# owner's alone.
#
# Usage:  record-delivered.sh [--base <branch>] [--dry-run]
#
# Exit codes:
#   0  the file is up to date (whether or not anything was appended)
#   2  cannot work out where to look — no repository, no gh, no plans

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "record-delivered: not inside a git repository" >&2; exit 2; }
cd "$ROOT"

BASE=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)    BASE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,/^[^#]/p' "$0" | sed -n 's/^# \{0,1\}//p'; exit 0 ;;
    *) echo "record-delivered: unknown argument: $1" >&2; exit 2 ;;
  esac
done
BASE="${BASE:-$(git rev-parse --abbrev-ref HEAD)}"

GH="${GH:-gh}"
DONE_DOC="docs/DESIGN.oracle.done.md"
PLANS_DIR="${PLANS_DIR:-docs/plans}"

command -v "$GH" >/dev/null 2>&1 || {
  echo "record-delivered: $GH is not on PATH; nothing recorded" >&2; exit 2; }
[[ -d "$PLANS_DIR" ]] || { echo "record-delivered: no $PLANS_DIR; nothing to record"; exit 0; }

REPO="$(${GH} repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null \
        || git config --get remote.origin.url | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')"
[[ -n "$REPO" ]] || { echo "record-delivered: cannot resolve the repository" >&2; exit 2; }

# Merged pull requests into THIS base, and their head refs. REST has no
# state=merged filter — closed includes unmerged — so merged is merged_at being
# set. Scoped to one base because two lanes share a repository and one lane's
# merge says nothing about the other's (ESC-46, ESC-71).
MERGED_REFS="$("$GH" api --paginate "repos/$REPO/pulls?state=closed&base=$BASE&per_page=100" \
  --jq '.[] | select(.merged_at != null) | "\(.head.ref)\t\(.number)\t\(.merged_at)"' 2>/dev/null || true)"
[[ -n "$MERGED_REFS" ]] || { echo "record-delivered: no merged pull requests on '$BASE' yet"; exit 0; }

# Ids already recorded. Column-anchored and backticked, the same shape every
# other ledger in this project uses, so the file's own indented format example
# is inert.
recorded() {
  [[ -f "$DONE_DOC" ]] || return 0
  awk '/^[-*][[:space:]]+`R[0-9]+`/ {
         if (match($0, /`R[0-9]+`/)) print substr($0, RSTART + 1, RLENGTH - 2)
       }' "$DONE_DOC"
}
ALREADY="$(recorded)"

# The plan a slug belongs to is found by its front-matter `slug:` field, not by
# filename. plan-resolve.sh — the check that decides which plan a branch
# implements — reads the field, and a filename-based match makes the two halves
# of the system identify the same object by different names.
plan_field() { # plan_field <file> <field>
  awk -v f="$2" '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { infm = 1; next }
    infm && $0 ~ /^---[[:space:]]*$/  { exit }
    infm && index($0, f ":") == 1 {
      sub("^" f ":[[:space:]]*", ""); sub(/[[:space:]]*#.*$/, "")
      gsub(/["'"'"']/, ""); print; exit
    }' "$1"
}

APPEND=""
while IFS=$'\t' read -r ref pr merged_at; do
  [[ "$ref" == feat/* ]] || continue
  day="${merged_at%%T*}"

  # WHICH PLAN DID THIS BRANCH BUILD. Anchored at both ends — the branch is
  # feat/<slug> or feat/<slug>-<more>, never feat/<slug-as-a-substring>.
  #
  # AN EXACT MATCH WINS OUTRIGHT. `feat/sync-index-1` satisfies the suffix form
  # for slug `sync-index` as well as being the exact branch of `sync-index-1`,
  # so a repository holding both plans would otherwise record BOTH plans'
  # requirements as delivered by one pull request. "Built" tolerating that
  # ambiguity costs a redundant dispatch; "delivered" tolerating it writes a
  # false line into an append-only record that nobody can correct afterwards.
  exact="" loose=""
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    [[ "$(basename "$file")" == _* ]] && continue
    slug="$(plan_field "$file" slug)"
    [[ -n "$slug" ]] || slug="$(basename "$file" .md)"
    if [[ "$ref" == "feat/$slug" ]]; then
      exact="${exact}${file}"$'\t'"${slug}"$'\n'
    elif [[ "$ref" =~ ^feat/${slug}([/-][^/]*)?$ ]]; then
      loose="${loose}${file}"$'\t'"${slug}"$'\n'
    fi
  done < <(find "$PLANS_DIR" -name '*.md' | sort)
  matches="${exact:-$loose}"
  [[ -n "$matches" ]] || continue

  while IFS=$'\t' read -r file slug; do
    [[ -n "$file" ]] || continue
    covers="$(plan_field "$file" covers | tr -d '[],')"
    for id in $covers; do
      [[ "$id" =~ ^R[0-9]+$ ]] || continue
      grep -qxF "$id" <<<"$ALREADY" && continue
      grep -qF "\`$id\`" <<<"$APPEND" && continue
      APPEND="${APPEND}- \`${id}\` — delivered — ${day} — PR #${pr}, plan \`${slug}\`"$'\n'
    done
  done <<<"$matches"
done <<<"$MERGED_REFS"

if [[ -z "$APPEND" ]]; then
  echo "record-delivered: nothing new to record on '$BASE'."
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s' "$APPEND"
  exit 0
fi

[[ -f "$DONE_DOC" ]] || {
  echo "record-delivered: $DONE_DOC does not exist; nothing recorded" >&2; exit 2; }
printf '%s' "$APPEND" >> "$DONE_DOC"
echo "record-delivered: appended $(grep -c . <<<"$APPEND") line(s) to $DONE_DOC."
