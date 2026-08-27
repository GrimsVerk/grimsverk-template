#!/usr/bin/env bash
#
# plan-format.sh — every pseudocode-format plan in the tree keeps its shape.
#
# The attended plan format (docs/plans/_TEMPLATE.pseudocode.md) makes three
# structural promises, and this lints all of them, because each one is a rule
# someone will otherwise erode line by line:
#
#   1. The `## Summary` header is capped — prose is allowed ONLY where
#      pseudocode cannot express it, and a cap that is not checked is the
#      40-line summary growing back one justified exception at a time.
#   2. A `Rulings:` receipt line exists — the plan carries no uncertainty
#      text, so this line is the only proof the ruling gate ran at all, and
#      the pointer an agent follows before reversing a pick.
#   3. Every slice splits into `### Signatures` and `### Internals` — the
#      split is what the blind test-writer's strip is computed from; a slice
#      without it feeds the tester the implementation.
#
# Plans WITHOUT `format: pseudocode` in their front matter are skipped
# entirely: the legacy format and every plan under docs/plans/oracle/ are
# governed by plan-parse.sh alone, and failing them here would make this
# check a migration order nobody issued.
#
# Usage:  plan-format.sh
# Env:    PLANS_DIR (default docs/plans), HEADER_MAX (default 15)
# Exit:   0 all checked plans conform (or nothing to check); 1 violations,
#         each named on stderr.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PLANS_DIR="${PLANS_DIR:-docs/plans}"
HEADER_MAX="${HEADER_MAX:-15}"
DIR="$ROOT/$PLANS_DIR"

[[ -d "$DIR" ]] || { echo "plan-format: no $PLANS_DIR/ — nothing to check"; exit 0; }

is_pseudocode() { # <file> — front matter (first --- block) carries the marker
  awk '/^---$/ { n++; next } n == 1 && /^format: pseudocode$/ { hit = 1 } END { exit hit ? 0 : 1 }' "$1"
}

declare -a BROKEN=()
declare -i CHECKED=0

fail() { # <file> <why>
  BROKEN+=("$1")
  echo "plan-format: $1 — $2" >&2
}

while IFS= read -r file; do
  rel="${file#"$ROOT"/}"
  [[ "$(basename "$file")" == _* ]] && continue
  is_pseudocode "$file" || continue
  CHECKED+=1
  ok=1

  # 1. The header cap: non-blank lines between `## Summary` and the next `## `.
  if ! grep -q '^## Summary' "$file"; then
    fail "$rel" "no '## Summary' heading — the capped header is required"
    ok=0
  else
    header_lines="$(awk '
      /^## Summary/ { insec = 1; next }
      insec && /^## / { exit }
      insec { line = $0; gsub(/[[:space:]]/, "", line); if (line != "") n++ }
      END { print n + 0 }
    ' "$file")"
    if [[ "$header_lines" -gt "$HEADER_MAX" ]]; then
      fail "$rel" "the Summary header has $header_lines non-blank lines (max $HEADER_MAX) — prose belongs in the header only where pseudocode cannot express it"
      ok=0
    fi
  fi

  # 2. The rulings receipt.
  if ! grep -q '^Rulings:' "$file"; then
    fail "$rel" "no 'Rulings:' line — the plan must carry the receipt of the batch rulings (docs/DECISIONS.md ids, or \"none surfaced\")"
    ok=0
  fi

  # 3. Every slice carries both layers. Slice boundaries use plan-parse.sh's
  #    own pattern, so the two scripts can never disagree about what a slice is.
  layer_problems="$(awk '
    function flush() {
      if (title == "") return
      if (!sig) print title ": missing ### Signatures"
      if (!intern) print title ": missing ### Internals"
    }
    /^#+[[:space:]]*Slice[[:space:]]/ {
      flush()
      title = $0; sub(/^#+[[:space:]]*/, "", title)
      sig = 0; intern = 0; next
    }
    title != "" && /^### Signatures/ { sig = 1 }
    title != "" && /^### Internals/  { intern = 1 }
    END { flush() }
  ' "$file")"
  if [[ -n "$layer_problems" ]]; then
    while IFS= read -r p; do
      fail "$rel" "$p — every slice needs the contract/internals split; it is what the blind test-writer's view is computed from"
    done <<< "$layer_problems"
    ok=0
  fi

  [[ "$ok" -eq 1 ]] && echo "plan-format: $rel ok"
done < <(find "$DIR" -name '*.md' | sort)

if [[ ${#BROKEN[@]} -gt 0 ]]; then
  echo "plan-format: violations in: $(printf '%s\n' "${BROKEN[@]}" | sort -u | tr '\n' ' ')" >&2
  exit 1
fi

echo "plan-format: $CHECKED pseudocode plan(s) checked"
