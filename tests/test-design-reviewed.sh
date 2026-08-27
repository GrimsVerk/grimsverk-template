#!/usr/bin/env bash
#
# test-design-reviewed.sh — CI refuses an unreviewed pseudocode plan. Written
# blind from the slice's Delivers and Signatures; no implementation was visible
# when this was written.
#
# The design-hardening loop only pays off if a pseudocode plan cannot land
# without its two adversarial reviews on disk. design-reviewed.sh is the CI
# backstop for that promise: diff base...HEAD, and if any added-or-modified
# plan under docs/plans/ (excluding oracle/ and _-prefixed skeletons) carries
# `format: pseudocode`, then REVIEWS_DIR/conceptual-1.md and
# REVIEWS_DIR/tactical-1.md must both exist and each carry at least MIN_WORDS
# words. Anything less fails naming each missing or too-thin file; a diff with
# no such plan is not the gate's business and passes as "not applicable".
#
# Same recipe as tests/test-escape-refs.sh: scratch repos with a committed base
# state, BASE_SHA captured, then a head state per case.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Runs from tests/ or tests/blind/.
if [[ -f "$HERE/lib.sh" ]]; then
  # shellcheck source=tests/lib.sh
  source "$HERE/lib.sh"
  ROOT="$HERE/.."
else
  # shellcheck source=tests/lib.sh
  source "$HERE/../lib.sh"
  ROOT="$HERE/../.."
fi

CHECK="$ROOT/template/.github/scripts/design-reviewed.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== design-reviewed.sh ==="

# ---------------------------------------------------------------- fixtures

# words <n> — exactly n deterministic words on stdout, so wc -w is exact and
# the >= MIN_WORDS boundary can be tested at equality.
words() {
  local i
  for ((i = 1; i <= $1; i++)); do printf 'w%d ' "$i"; done
  printf '\n'
}

# mkreview <path> <n> — a review file of exactly n words.
mkreview() {
  mkdir -p "$(dirname "$1")"
  words "$2" > "$1"
}

# mkplan_pseudo <path> — a minimal plan carrying format: pseudocode in its
# YAML front matter.
mkplan_pseudo() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'EOF'
---
slug: widget
format: pseudocode
---

# Widget — Plan

Rulings: docs/DECISIONS.md

## Slice 1 — the widget exists

- **Delivers:** a widget.

### Signatures

```text
widget() -> Widget
```

### Internals

```text
return the widget
```
EOF
}

# mkplan_legacy <path> — a plan in the old prose format: front matter with no
# format line at all.
mkplan_legacy() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'EOF'
---
slug: legacy
---

# Legacy — Plan

## Slice 1 — a thing

- **Files:** `src/thing.py`
- **Estimate:** ~10 lines
EOF
}

# c <repo> <message> — stage everything and commit.
c() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }

# gate <repo> <base> [NAME=value ...] — run the check from inside the repo
# with a deterministic environment: the two knobs are explicitly unset so a
# stray value on the runner cannot change a default-behaviour case, then any
# per-case overrides are applied. Combined output; rc is the call's rc.
gate() {
  local repo="$1" base="$2"
  shift 2
  ( cd "$repo" && env -u MIN_WORDS -u REVIEWS_DIR "$@" BASE_SHA="$base" "$CHECK" 2>&1 )
}

# ============================================================ gate applies

R1="$WORK/applies"
init_repo "$R1"
echo "seed" > "$R1/README.md"
c "$R1" "seed"
BASE1="$(git -C "$R1" rev-parse HEAD)"

# ---------------- 1: pseudocode plan added, both reviews present and thick
mkplan_pseudo "$R1/docs/plans/widget.md"
mkreview "$R1/docs/reviews/design/conceptual-1.md" 200
mkreview "$R1/docs/reviews/design/tactical-1.md" 200
c "$R1" "Add a reviewed pseudocode plan"
out="$(gate "$R1" "$BASE1")"
expect_rc "a pseudocode plan with both reviews at 200 words passes" 0 $?

# ---------------- 2: MIN_WORDS raised above both files -> both named
out="$(gate "$R1" "$BASE1" MIN_WORDS=5000)"
expect_rc "the same reviews are too thin under MIN_WORDS=5000" 1 $?
expect_contains "and the conceptual review is named" "$out" "conceptual-1.md"
expect_contains "and the tactical review is named" "$out" "tactical-1.md"

# ---------------- 3: same plan diff, no reviews directory at all
git -C "$R1" reset -q --hard "$BASE1"
mkplan_pseudo "$R1/docs/plans/widget.md"
c "$R1" "Add an unreviewed pseudocode plan"
out="$(gate "$R1" "$BASE1")"
expect_rc "a pseudocode plan with no reviews fails" 1 $?
expect_contains "naming the missing conceptual review" "$out" "conceptual-1.md"
expect_contains "and the missing tactical review" "$out" "tactical-1.md"

# ---------------- 4: conceptual present and thick, tactical missing
mkreview "$R1/docs/reviews/design/conceptual-1.md" 200
c "$R1" "Add the conceptual review only"
out="$(gate "$R1" "$BASE1")"
expect_rc "conceptual alone is not enough" 1 $?
expect_contains "the missing tactical review is named" "$out" "tactical-1.md"

# ---------------- 5: tactical present but under the default minimum
mkreview "$R1/docs/reviews/design/tactical-1.md" 40
c "$R1" "Add a 40-word tactical review"
out="$(gate "$R1" "$BASE1")"
expect_rc "a 40-word review fails the default 150-word minimum" 1 $?
expect_contains "the too-thin tactical review is named" "$out" "tactical-1.md"

# ---------------- 6: MIN_WORDS lowered to exactly the file's count
# The contract is >=, so equality passes.
out="$(gate "$R1" "$BASE1" MIN_WORDS=40)"
expect_rc "MIN_WORDS=40 accepts the 40-word review (>= is inclusive)" 0 $?

# ---------------- 7: REVIEWS_DIR override is honoured
git -C "$R1" reset -q --hard "$BASE1"
mkplan_pseudo "$R1/docs/plans/widget.md"
mkreview "$R1/docs/reviews/alt/conceptual-1.md" 200
mkreview "$R1/docs/reviews/alt/tactical-1.md" 200
c "$R1" "Reviews in an alternate directory"
out="$(gate "$R1" "$BASE1" REVIEWS_DIR=docs/reviews/alt)"
expect_rc "reviews under REVIEWS_DIR=docs/reviews/alt pass" 0 $?
out="$(gate "$R1" "$BASE1")"
expect_rc "the same tree fails when looking in the default directory" 1 $?

# ======================================================== gate not applicable

R2="$WORK/exempt"
init_repo "$R2"
echo "seed" > "$R2/README.md"
c "$R2" "seed"
BASE2="$(git -C "$R2" rev-parse HEAD)"

# ---------------- 8: a legacy-format plan needs no reviews
mkplan_legacy "$R2/docs/plans/old-style.md"
c "$R2" "Add a legacy plan"
out="$(gate "$R2" "$BASE2")"
expect_rc "a legacy plan with no reviews anywhere passes" 0 $?
expect_contains "and says the gate is not applicable" "${out,,}" "not applicable"
git -C "$R2" reset -q --hard "$BASE2"

# ---------------- 9: a pseudocode plan under docs/plans/oracle/ is exempt
mkplan_pseudo "$R2/docs/plans/oracle/unattended.md"
c "$R2" "Add an oracle-path pseudocode plan"
out="$(gate "$R2" "$BASE2")"
expect_rc "an oracle-path pseudocode plan needs no design reviews" 0 $?
git -C "$R2" reset -q --hard "$BASE2"

# ---------------- 10: an _-prefixed skeleton is exempt
mkplan_pseudo "$R2/docs/plans/_TEMPLATE.pseudocode.md"
c "$R2" "Add the pseudocode plan skeleton"
out="$(gate "$R2" "$BASE2")"
expect_rc "an underscore-prefixed skeleton needs no design reviews" 0 $?
git -C "$R2" reset -q --hard "$BASE2"

# ---------------- 11: a non-.md file under docs/plans/ is not a plan
mkdir -p "$R2/docs/plans"
printf 'format: pseudocode\n' > "$R2/docs/plans/notes.txt"
c "$R2" "Add a text note that merely mentions the marker"
out="$(gate "$R2" "$BASE2")"
expect_rc "a .txt file under docs/plans/ does not trigger the gate" 0 $?
git -C "$R2" reset -q --hard "$BASE2"

# ---------------- 12: a diff touching no plan at all
echo "more" >> "$R2/README.md"
c "$R2" "Touch nothing under docs/plans"
out="$(gate "$R2" "$BASE2")"
expect_rc "a diff with no plan in it passes" 0 $?

# ---------------- 13: a pseudocode plan at base, untouched by the diff
# The gate reads the diff, not the tree: a plan that already landed (with its
# reviews, in its own pull request) must not re-block every later change.
R3="$WORK/landed"
init_repo "$R3"
echo "seed" > "$R3/README.md"
mkplan_pseudo "$R3/docs/plans/widget.md"
c "$R3" "seed with a pseudocode plan already at base"
BASE3="$(git -C "$R3" rev-parse HEAD)"
echo "notes" > "$R3/docs/notes.md"
c "$R3" "An unrelated change"
out="$(gate "$R3" "$BASE3")"
expect_rc "an untouched pseudocode plan at base does not trigger the gate" 0 $?

# ---------------- 14: modifying a plan into pseudocode format triggers it
# Added OR modified: converting a legacy plan is how the gate is most likely
# to be dodged, so the diff filter must not be add-only.
R4="$WORK/converted"
init_repo "$R4"
echo "seed" > "$R4/README.md"
mkplan_legacy "$R4/docs/plans/widget.md"
c "$R4" "seed with a legacy plan"
BASE4="$(git -C "$R4" rev-parse HEAD)"
mkplan_pseudo "$R4/docs/plans/widget.md"
c "$R4" "Convert the plan to pseudocode format"
out="$(gate "$R4" "$BASE4")"
expect_rc "a plan modified into pseudocode format triggers the gate" 1 $?
expect_contains "and the missing conceptual review is named" "$out" "conceptual-1.md"
expect_contains "and the missing tactical review is named" "$out" "tactical-1.md"

# ================================================================== usage

# ---------------- 15: unset BASE_SHA is a usage error
out="$( cd "$R1" && env -u BASE_SHA -u MIN_WORDS -u REVIEWS_DIR "$CHECK" 2>&1 )"
expect_rc "unset BASE_SHA exits 2" 2 $?
expect_contains "and the usage names BASE_SHA" "$out" "BASE_SHA"

# ---------------- 16: empty BASE_SHA is the same usage error
out="$( cd "$R1" && env -u MIN_WORDS -u REVIEWS_DIR BASE_SHA= "$CHECK" 2>&1 )"
expect_rc "empty BASE_SHA exits 2" 2 $?

summary
