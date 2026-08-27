#!/usr/bin/env bash
#
# design-reviewed.sh — a pseudocode plan needs both design reviews on disk.
#
# The design flow (docs/design-flow.md) puts two adversarial reviews between
# the design doc and the plans — conceptual before the pseudocode pass,
# tactical after the owner's rulings settle it. The flow's own gate
# (design-gate.sh) reminds; this check enforces, at the one place the flow
# cannot skip: the pull request that lands the plans. A pull request adding or
# modifying a `format: pseudocode` plan fails while either review artifact is
# missing or under the word minimum.
#
# The minimum is words, not quality, on purpose. The owner reads both reviews
# during the flow, so a hollow one dies on contact with them; this gate only
# fights forgetting the stage entirely. Legacy-format plans and everything
# under docs/plans/oracle/ are exempt — the unattended path has no owner awake
# to walk, and its plans never carry the marker.
#
# Usage:  BASE_SHA=<sha> design-reviewed.sh
# Env:    MIN_WORDS (default 150), REVIEWS_DIR (default docs/reviews/design)
# Exit:   0 gate passes or does not apply; 1 a review is missing or thin;
#         2 usage error.

set -euo pipefail

MIN_WORDS="${MIN_WORDS:-150}"
REVIEWS_DIR="${REVIEWS_DIR:-docs/reviews/design}"

if [[ -z "${BASE_SHA:-}" ]]; then
  echo "usage: BASE_SHA=<sha> design-reviewed.sh" >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

is_pseudocode() { # <file> — front matter (first --- block) carries the marker
  awk '/^---$/ { n++; next } n == 1 && /^format: pseudocode$/ { hit = 1 } END { exit hit ? 0 : 1 }' "$1"
}

APPLIES=0
while IFS= read -r f; do
  case "$f" in
    docs/plans/oracle/*) continue ;;
    docs/plans/*.md) ;;   # `*` spans `/` in a case pattern, so subdirs match too
    *) continue ;;
  esac
  [[ "$(basename "$f")" == _* ]] && continue
  [[ -f "$f" ]] || continue   # deleted in this diff
  if is_pseudocode "$f"; then APPLIES=1; break; fi
done < <(git diff --name-only --diff-filter=AM "$BASE_SHA"...HEAD)

if [[ "$APPLIES" -eq 0 ]]; then
  echo "design-reviewed: not applicable — this diff adds or modifies no pseudocode-format plan"
  exit 0
fi

declare -a PROBLEMS=()
for kind in conceptual tactical; do
  f="$REVIEWS_DIR/$kind-1.md"
  if [[ ! -f "$f" ]]; then
    PROBLEMS+=("$f is missing — the $kind adversarial review must land with (or before) the plans it reviewed")
  else
    words="$(wc -w < "$f")"
    if [[ "$words" -lt "$MIN_WORDS" ]]; then
      PROBLEMS+=("$f has $words words (minimum $MIN_WORDS) — a review this thin records that the stage was skipped, not run")
    fi
  fi
done

if [[ ${#PROBLEMS[@]} -gt 0 ]]; then
  echo "design-reviewed: this pull request lands a pseudocode plan without its design reviews:" >&2
  printf '  - %s\n' "${PROBLEMS[@]}" >&2
  exit 1
fi

echo "design-reviewed: both design reviews present and above $MIN_WORDS words"
