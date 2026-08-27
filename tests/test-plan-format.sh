#!/usr/bin/env bash
#
# test-plan-format.sh — the pseudocode-plan linter, written blind from slice 1
# of docs/plans/design-hardening-loop.md. No implementation was visible when
# this was written; a red run against a tree without
# template/.github/scripts/plan-format.sh is the expected state, not a fault.
#
# plan-format.sh walks PLANS_DIR (default docs/plans) from the repository
# toplevel and lints every *.md whose YAML front matter carries
# `format: pseudocode`: the ## Summary section may hold at most HEADER_MAX
# (default 15) NON-BLANK lines, a line starting `Rulings:` must exist, and
# every slice section must carry both a ### Signatures and a ### Internals
# heading. Files whose basename starts with `_` are skipped, and so is any
# plan without the marker — the linter must never fail the legacy plans that
# predate the format. All checked plans passing is exit 0 with one
# "plan-format: <path> ok" line each; any violation is exit 1 with a
# diagnosis naming the file and the failed rule; no plans directory at all
# is exit 0 with a "nothing to check" message.

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

FMT="$ROOT/template/.github/scripts/plan-format.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== plan-format.sh ==="

R="$WORK/repo"
init_repo "$R"
echo "seed" > "$R/README.md"
git -C "$R" add -A && git -C "$R" commit -qm "seed"

# run_fmt [VAR=value ...] — run the linter from inside the repo, stdout+stderr
# merged, with optional environment overrides.
run_fmt() { ( cd "$R" && env "$@" "$FMT" 2>&1 ); }
reset_plans() { rm -rf "$R/docs/plans"; mkdir -p "$R/docs/plans"; }

# write_plan <path> <summary-lines> [no-rulings|no-internals|no-signatures ...]
#
# A compliant pseudocode plan, minus whatever deviation the case names. The
# Summary carries exactly <summary-lines> NON-BLANK lines plus one interior
# blank line, so the budget being counted in non-blank lines is pinned by the
# boundary cases below.
write_plan() {
  local path="$1" n="$2"; shift 2
  local rulings=1 internals=1 signatures=1 f i
  for f in "$@"; do
    case "$f" in
      no-rulings)    rulings=0 ;;
      no-internals)  internals=0 ;;
      no-signatures) signatures=0 ;;
    esac
  done
  {
    printf '%s\n' '---' 'format: pseudocode' '---' ''
    printf '%s\n' '# A fixture plan' '' '## Summary' ''
    for ((i = 1; i <= n; i++)); do
      printf 'summary line %d\n' "$i"
      if [[ "$i" -eq 3 ]]; then printf '\n'; fi
    done
    printf '%s\n' '' '## Rulings' ''
    if [[ "$rulings" -eq 1 ]]; then
      printf '%s\n' 'Rulings: none — every uncertainty was settled in review' ''
    fi
    printf '%s\n' '## Slice 1 — does the fixture thing' ''
    printf '%s\n' '- **Delivers:** the fixture thing, observably.' \
      '- **Estimate:** ~10 lines' ''
    if [[ "$signatures" -eq 1 ]]; then
      printf '%s\n' '### Signatures' '' 'fixture_sig(x) -> y' ''
    fi
    if [[ "$internals" -eq 1 ]]; then
      printf '%s\n' '### Internals' '' '- loop over x; guts only'
    fi
  } > "$path"
}

# ---------------- 1: a compliant pseudocode plan passes and is named
reset_plans
write_plan "$R/docs/plans/good.md" 5
out="$(run_fmt)"
expect_rc "a compliant pseudocode plan passes" 0 $?
expect_contains "and is reported as checked" "$out" "plan-format:"
expect_contains "by name" "$out" "good.md"

# ---------------- 2: the header budget is inclusive, and blank lines are free
reset_plans
write_plan "$R/docs/plans/edge.md" 15
out="$(run_fmt)"
expect_rc "a Summary of exactly 15 non-blank lines passes" 0 $?

# ---------------- 3: one line over the budget fails, naming file and rule
reset_plans
write_plan "$R/docs/plans/fat.md" 16
out="$(run_fmt)"
expect_rc "a 16-non-blank-line Summary fails" 1 $?
expect_contains "and the diagnosis names the file" "$out" "fat.md"
expect_contains "and the failed rule" "${out,,}" "summary"

# ---------------- 4: HEADER_MAX is the budget, not a constant — raise it
# Same 16-line plan still in place; a larger budget admits it.
out="$(run_fmt HEADER_MAX=25)"
expect_rc "HEADER_MAX=25 admits the 16-line Summary" 0 $?

# ---------------- 5: — and lower it
reset_plans
write_plan "$R/docs/plans/good.md" 5
out="$(run_fmt HEADER_MAX=3)"
expect_rc "HEADER_MAX=3 fails a 5-line Summary" 1 $?

# ---------------- 6: the Rulings: line is mandatory
reset_plans
write_plan "$R/docs/plans/unruled.md" 5 no-rulings
out="$(run_fmt)"
expect_rc "a plan with no Rulings: line fails" 1 $?
expect_contains "naming the file" "$out" "unruled.md"
expect_contains "and the missing line" "${out,,}" "rulings"

# ---------------- 7: a slice without ### Internals fails
reset_plans
write_plan "$R/docs/plans/gutless.md" 5 no-internals
out="$(run_fmt)"
expect_rc "a slice without ### Internals fails" 1 $?
expect_contains "naming the file" "$out" "gutless.md"
expect_contains "and the missing heading" "${out,,}" "internals"

# ---------------- 8: a slice without ### Signatures fails
reset_plans
write_plan "$R/docs/plans/unsigned.md" 5 no-signatures
out="$(run_fmt)"
expect_rc "a slice without ### Signatures fails" 1 $?
expect_contains "naming the file" "$out" "unsigned.md"
expect_contains "and the missing heading" "${out,,}" "signatures"

# ---------------- 9: the split is checked PER SLICE, not per file
# Both headings exist somewhere in this file — a whole-file grep would pass
# it — but slice 2 has no Internals of its own, and the rule is per slice.
reset_plans
cat > "$R/docs/plans/half.md" <<'EOF'
---
format: pseudocode
---

# Half done

## Summary

short enough

## Rulings

Rulings: none

## Slice 1 — complete

### Signatures

sig one

### Internals

guts one

## Slice 2 — incomplete

### Signatures

sig two
EOF
out="$(run_fmt)"
expect_rc "a second slice missing its Internals fails even though the first slice is complete" 1 $?
expect_contains "naming the file" "$out" "half.md"

# ---------------- 10: a legacy plan without the marker is skipped, not failed
reset_plans
write_plan "$R/docs/plans/good.md" 5
cat > "$R/docs/plans/legacy.md" <<'EOF'
# An old prose plan

## Slice 1 — predates the format

- **Delivers:** something, in prose. No Signatures, no Internals, no Rulings.
EOF
out="$(run_fmt)"
expect_rc "a legacy plan with none of the new structure never fails the run" 0 $?
expect_not_contains "and is not reported as checked" "$out" "legacy.md"

# ---------------- 11: a tree of ONLY legacy plans is a clean pass
reset_plans
cat > "$R/docs/plans/legacy.md" <<'EOF'
# An old prose plan

nothing the new format asks for
EOF
out="$(run_fmt)"
expect_rc "a plans directory holding only legacy plans exits 0" 0 $?

# ---------------- 12: _-prefixed files are skipped even when marked and broken
reset_plans
write_plan "$R/docs/plans/good.md" 5
cat > "$R/docs/plans/_TEMPLATE.pseudocode.md" <<'EOF'
---
format: pseudocode
---

# The template itself: marked, and deliberately full of holes

## Slice 1 — <behaviour>

<no Signatures, no Internals, no Rulings — a scaffold, not a plan>
EOF
out="$(run_fmt)"
expect_rc "an _-prefixed template file is skipped" 0 $?
expect_not_contains "and not reported as checked" "$out" "_TEMPLATE.pseudocode.md"

# ---------------- 13: the walk is recursive
reset_plans
mkdir -p "$R/docs/plans/oracle"
write_plan "$R/docs/plans/oracle/deep.md" 5 no-rulings
out="$(run_fmt)"
expect_rc "a violating plan in a subdirectory is found" 1 $?
expect_contains "and named" "$out" "deep.md"

# ---------------- 14: PLANS_DIR redirects the walk entirely
reset_plans
write_plan "$R/docs/plans/bad-here.md" 5 no-rulings
mkdir -p "$R/alt/plans"
write_plan "$R/alt/plans/good.md" 5
out="$(run_fmt PLANS_DIR=alt/plans)"
expect_rc "PLANS_DIR=alt/plans checks the other tree" 0 $?
expect_not_contains "and docs/plans is not consulted" "$out" "bad-here.md"

# ---------------- 15: no plans directory is a documented no-op
reset_plans
rm -rf "$R/docs/plans"
out="$(run_fmt)"
expect_rc "a repository with no plans directory exits 0" 0 $?
expect_contains "and says there was nothing to check" "$out" "nothing to check"

# ---------------- 16: anchored on the git toplevel, not on the cwd
reset_plans
write_plan "$R/docs/plans/fat.md" 16
mkdir -p "$R/sub"
out="$( cd "$R/sub" && "$FMT" 2>&1 )"
expect_rc "run from a subdirectory, the walk still starts at the repository root" 1 $?
expect_contains "and still finds the violating plan" "$out" "fat.md"

summary
