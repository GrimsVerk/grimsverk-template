#!/usr/bin/env bash
#
# plan-contracts.sh — the contract-only view of a pseudocode plan.
#
# Emits the plan with every `### Internals` section removed: from the heading
# through the line before the next heading of depth one to three, or end of
# file. Everything else passes through byte-identical — including the blank
# line before each removed heading, which belongs to the surrounding document,
# not to the section.
#
# This is what makes the blind test-writer's exclusion STRUCTURAL rather than
# a promise: spawn-worker.sh --strip-internals replaces the plan in the
# test-writer's worktree with this output, so the pseudocode internals are not
# there to read — the same mechanism that already keeps the implementation out
# of that worktree. A tester that sees the internals re-derives the algorithm
# as assertions, and both sides then encode the same mistake.
#
# Reads STDIN, writes STDOUT, like plan-parse.sh, and for the same reasons:
# the caller stays in charge of where the plan comes from, and the filter is
# testable with no git repository involved. (Internally the input is staged to
# a temp file, never a $(...) capture — command substitution eats trailing
# blank lines, and this filter promises byte identity for everything it does
# not remove.)
#
# A plan marked `format: pseudocode` that contains NO `### Internals` section
# is an error: either the marker is wrong or the plan never had the split, and
# a silent pass-through here would hand the tester whatever is there.
#
# Usage:  plan-contracts.sh < plan.md > contract.md
# Exit:   0 filtered (or unmarked input passed through unchanged);
#         1 marked input with no Internals section.

set -euo pipefail

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
cat > "$TMP"

# The marker counts only inside the front matter — the first `---` block.
marked() {
  awk '/^---$/ { n++; next } n == 1 && /^format: pseudocode$/ { hit = 1 } END { exit hit ? 0 : 1 }' "$TMP"
}

if marked; then
  if ! grep -q '^### Internals' "$TMP"; then
    echo "plan-contracts: input is marked 'format: pseudocode' but has no '### Internals' section — nothing to strip means nothing was separated" >&2
    exit 1
  fi
  # No interval regex ({1,3}) — not every awk supports it; spell the depths out.
  awk '
    /^### Internals/ { skipping = 1; next }
    skipping && (/^# / || /^## / || /^### /) { skipping = 0 }
    !skipping { print }
  ' "$TMP"
else
  cat "$TMP"
fi
