#!/usr/bin/env bash
#
# design-gate.sh — "may the design flow advance past <stage>?"
#
# The cheap stop between stages of the attended design flow
# (docs/design-flow.md). It checks that a stage's artifact EXISTS and is not
# hollow — a word minimum, never a judgement of content. Depth is the owner's
# to judge, because the owner reads every artifact this flow produces; this
# gate only fights forgetting. That is why it is deliberately stupid: a gate
# that tried to grade the reviews would be trusted, and it could not earn it.
#
# Usage:  design-gate.sh <stage>
#         stages: design | review-conceptual | plans | review-tactical
# Env:    MIN_WORDS (default 150) — minimum word count for a review artifact
#
# Exit:   0 stage complete; 1 artifacts missing or thin (each named on
#         stderr); 2 usage error.

set -euo pipefail

MIN_WORDS="${MIN_WORDS:-150}"

usage() {
  echo "usage: design-gate.sh <design|review-conceptual|plans|review-tactical>" >&2
}

[[ $# -eq 1 ]] || { usage; exit 2; }
STAGE="$1"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

declare -a MISSING=()

# A review artifact: any docs/reviews/design/<kind>-<n>.md with >= MIN_WORDS
# words. A review that exists but is thin is named, with its count — "the file
# is there" and "the stage ran" are different claims, and the message should
# say which one failed.
check_review() { # <kind>
  local kind="$1" found="" f words
  local -a thin=()
  for f in docs/reviews/design/"$kind"-*.md; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" =~ ^"$kind"-[0-9]+\.md$ ]] || continue
    words="$(wc -w < "$f")"
    if [[ "$words" -ge "$MIN_WORDS" ]]; then
      found="$f"
    else
      thin+=("$f has $words words — the minimum is $MIN_WORDS")
    fi
  done
  [[ -n "$found" ]] && return 0
  if [[ ${#thin[@]} -gt 0 ]]; then
    local t
    for t in "${thin[@]}"; do MISSING+=("$t"); done
  else
    MISSING+=("docs/reviews/design/$kind-<n>.md — a $kind review of at least $MIN_WORDS words is required before the flow advances")
  fi
  return 0
}

# A ## section with no non-blank, non-comment, non-heading line is empty.
# Same notion vision-complete.sh enforces at the plan pull request; the gate
# repeats it here so the hole is found while the owner is still in the room.
vision_has_empty_section() { # <file>
  awk '
    /^## / { if (insec && !content) { empty = 1 }; insec = 1; content = 0; next }
    insec {
      line = $0
      sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^<!--/ || line ~ /^-->/ || line ~ /^#/) next
      content = 1
    }
    END { if (insec && !content) empty = 1; exit empty ? 0 : 1 }
  ' "$1"
}

case "$STAGE" in
  design)
    if [[ ! -f docs/DESIGN.md ]]; then
      MISSING+=("docs/DESIGN.md — the design doc does not exist")
    elif ! grep -qE '^- \*\*R[0-9]' docs/DESIGN.md; then
      MISSING+=("docs/DESIGN.md — no requirement lines (- **R<n>** …) found; §5 is not filled in")
    fi
    if [[ ! -f docs/VISION.md ]]; then
      MISSING+=("docs/VISION.md — the vision doc does not exist")
    elif vision_has_empty_section docs/VISION.md; then
      MISSING+=("docs/VISION.md — an empty ## section remains; finish it or delete the section")
    fi
    ;;
  review-conceptual) check_review conceptual ;;
  review-tactical)   check_review tactical ;;
  plans)
    found=""
    while IFS= read -r f; do
      base="$(basename "$f")"
      [[ "$base" == _* ]] && continue
      case "$f" in docs/plans/oracle/*) continue ;; esac
      # The format marker must sit in the front matter (first --- block).
      if awk '/^---$/ { n++; next } n == 1 && /^format: pseudocode$/ { hit = 1 } END { exit hit ? 0 : 1 }' "$f"; then
        found="$f"; break
      fi
    done < <(find docs/plans -name '*.md' 2>/dev/null | sort)
    [[ -n "$found" ]] || MISSING+=("docs/plans/<slug>.md — no plan with 'format: pseudocode' front matter exists; the pseudocode pass has not been carved into plans")
    ;;
  *) usage; exit 2 ;;
esac

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "design-gate: $STAGE is NOT complete — do not advance:" >&2
  printf '  - %s\n' "${MISSING[@]}" >&2
  exit 1
fi

echo "design-gate: $STAGE complete"
