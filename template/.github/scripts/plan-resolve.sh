#!/usr/bin/env bash
#
# plan-resolve.sh — find the plan a pull request belongs to.
#
# Plans live at docs/plans/<slug>.md and declare a `slug` in their front-matter.
# Every branch working a plan must contain that slug in its name, so resolution
# is a pure offline string match — no API calls, no PR body parsing.
#
# Prints the resolved plan's path on stdout and exits 0.
#
# FAILS HARD (exit 1) with a diagnosis when no single plan resolves. That is
# deliberate: a PR with no plan means either the planning step was skipped or the
# branch is misnamed, and both are wiring faults worth stopping for. An estimate
# the reviewer never receives is a gate that silently stopped working.
#
# Branches whose name starts with an exempt prefix skip the check entirely and
# print nothing (exit 0) — see EXEMPT_PREFIXES. Using an exempt prefix to dodge
# planning is a rule violation under AGENTS.md, not a supported workflow.
#
# Required env:
#   HEAD_REF   the PR's head branch name (e.g. feat/draft-saving)
# Optional env:
#   PLANS_DIR  where plans live (default: docs/plans)

set -euo pipefail

# Keep in sync with the Planning rule in AGENTS.md.
EXEMPT_PREFIXES=(chore/ docs/)

ROOT="$(git rev-parse --show-toplevel)"
PLANS_DIR="${PLANS_DIR:-docs/plans}"
: "${HEAD_REF:?HEAD_REF is required (the PR head branch name)}"

die() { echo "plan-resolve: $*" >&2; exit 1; }

for prefix in "${EXEMPT_PREFIXES[@]}"; do
  if [[ "$HEAD_REF" == "$prefix"* ]]; then
    echo "plan-resolve: branch '$HEAD_REF' uses the exempt prefix '$prefix' — no plan required" >&2
    exit 0
  fi
done

DIR="$ROOT/$PLANS_DIR"
[[ -d "$DIR" ]] || die "no $PLANS_DIR/ directory.
Branch '$HEAD_REF' needs a plan. Write one (copy $PLANS_DIR/_TEMPLATE.md to
$PLANS_DIR/<slug>.md), or use a chore/ or docs/ branch prefix if the change is
genuinely trivial."

# Collect slug -> path for every real plan (the _TEMPLATE is not a plan).
declare -a SLUGS=() PATHS=() UNSLUGGED=()
while IFS= read -r file; do
  base="$(basename "$file")"
  [[ "$base" == _* ]] && continue
  # `slug:` from the front-matter only: stop at the closing --- so a stray
  # "slug:" later in the body can't be picked up instead.
  slug="$(awk '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---"  { exit }
    infm && /^slug:/   { sub(/^slug:[[:space:]]*/, ""); sub(/[[:space:]]*(#.*)?$/, ""); print; exit }
  ' "$file")"
  if [[ -z "$slug" ]]; then
    UNSLUGGED+=("${file#"$ROOT"/}")
    continue
  fi
  SLUGS+=("$slug")
  PATHS+=("${file#"$ROOT"/}")
done < <(find "$DIR" -maxdepth 1 -name '*.md' | sort)

if [[ ${#SLUGS[@]} -eq 0 ]]; then
  msg="no plan in $PLANS_DIR/ declares a slug."
  [[ ${#UNSLUGGED[@]} -gt 0 ]] && msg+="
Files present but missing a 'slug:' in their front-matter: ${UNSLUGGED[*]}"
  die "$msg
Branch '$HEAD_REF' needs a plan with a slug that appears in the branch name."
fi

declare -a MATCHED=() MATCHED_SLUG=()
for i in "${!SLUGS[@]}"; do
  if [[ "$HEAD_REF" == *"${SLUGS[$i]}"* ]]; then
    MATCHED+=("${PATHS[$i]}")
    MATCHED_SLUG+=("${SLUGS[$i]}")
  fi
done

case ${#MATCHED[@]} in
  1) echo "${MATCHED[0]}" ;;
  0)
    printf -v available '  %s\n' "${SLUGS[@]}"
    die "no plan slug appears in branch '$HEAD_REF'.
Available slugs:
$available
Fix one of the two: rename the branch to contain the plan's slug, or correct the
'slug:' field in the plan. They must agree — that match is the only link between
a PR and the plan it is judged against."
    ;;
  *)
    printf -v hits '  %s\n' "${MATCHED_SLUG[@]}"
    die "branch '$HEAD_REF' matches more than one plan slug:
$hits
Slugs must be unambiguous. Rename a plan's slug so only one matches (a slug that
is a substring of another, like 'auth' and 'auth-tokens', will always collide)."
    ;;
esac
