#!/usr/bin/env bash
#
# test-plan-contracts.sh — the contract-only view of a plan, written blind from
# slice 1 of docs/plans/design-hardening-loop.md. No implementation was visible
# when this was written; a red run against a tree without
# template/.github/scripts/plan-contracts.sh is the expected state.
#
# plan-contracts.sh reads a plan on stdin and writes it back with every
# `### Internals` section removed — from the `### Internals` line through the
# line before the next heading of depth one to three, or end of file — and
# everything else byte-identical, in order. A `format: pseudocode` plan with
# no Internals at all is refused (exit 1, stderr); a document without the
# marker passes through unchanged. Stdin/stdout like plan-parse.sh, so it is
# testable against fixture text with no git repository involved.

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

CONTRACTS="$ROOT/template/.github/scripts/plan-contracts.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== plan-contracts.sh ==="

# ---------------- 1: the main path — two slices, each loses only its guts
#
# The first Internals section carries a depth-4 heading, which must NOT stop
# the removal (only depths one to three do); the second runs to end of file.
# The blank line BEFORE each `### Internals` heading is not part of the
# removed range, so it survives — including the one that becomes the file's
# trailing blank line.
cat > "$WORK/in.md" <<'EOF'
---
format: pseudocode
---

# The fixture plan

## Summary

one line of summary

## Rulings

Rulings: none

## Slice 1 — first behaviour

- **Delivers:** the first behaviour.
- **Files:** `src/one.py`
- **Estimate:** ~20 lines

### Signatures

first_sig(a) -> b

### Internals

- first guts line
#### deeper guts heading
more guts under the deep heading

## Slice 2 — second behaviour

- **Delivers:** the second behaviour.
- **Estimate:** ~30 lines

### Signatures

second_sig(c) -> d

### Internals

- second guts line
EOF

cat > "$WORK/expected.md" <<'EOF'
---
format: pseudocode
---

# The fixture plan

## Summary

one line of summary

## Rulings

Rulings: none

## Slice 1 — first behaviour

- **Delivers:** the first behaviour.
- **Files:** `src/one.py`
- **Estimate:** ~20 lines

### Signatures

first_sig(a) -> b

## Slice 2 — second behaviour

- **Delivers:** the second behaviour.
- **Estimate:** ~30 lines

### Signatures

second_sig(c) -> d

EOF

"$CONTRACTS" < "$WORK/in.md" > "$WORK/out.md" 2> "$WORK/err.txt"
expect_rc "a marked two-slice plan filters cleanly" 0 $?
if diff -u "$WORK/expected.md" "$WORK/out.md" > "$WORK/diff.txt" 2>&1; then
  ok "the output is byte-identical to the input minus its Internals sections"
else
  no "the output is byte-identical to the input minus its Internals sections" \
    "$(head -c 800 "$WORK/diff.txt")"
fi

# The same claim in smaller pieces, so a partially-right implementation gets a
# readable failure instead of one opaque diff.
out="$(cat "$WORK/out.md")"
expect_not_contains "no ### Internals heading survives" "$out" "### Internals"
expect_not_contains "slice 1's guts are gone" "$out" "first guts line"
expect_not_contains "a depth-4 heading does not stop the removal" "$out" "deeper guts heading"
expect_not_contains "nor does its body survive" "$out" "more guts under the deep heading"
expect_not_contains "slice 2's guts are gone too (removal runs to EOF)" "$out" "second guts line"
expect_contains "slice 1's Signatures body survives" "$out" "first_sig(a) -> b"
expect_contains "slice 2's Signatures body survives" "$out" "second_sig(c) -> d"
expect_contains "the ### Signatures headings survive" "$out" "### Signatures"
expect_contains "the Delivers line survives verbatim" "$out" "**Delivers:** the first behaviour."
expect_contains "the Files line survives verbatim" "$out" '**Files:** `src/one.py`'
expect_contains "the Estimate line survives verbatim" "$out" "**Estimate:** ~30 lines"

# ---------------- 2: a pseudocode plan with NO Internals is refused
# The filter exists so a test-writer can be handed a contract with the guts
# structurally absent. A marked plan with no Internals section means the
# format was not followed, and passing it through silently would hand over a
# document nothing was stripped from while claiming the exclusion happened.
cat > "$WORK/bare.md" <<'EOF'
---
format: pseudocode
---

# Marked but gutless

UNIQUE-BODY-MARKER-73

## Slice 1 — thing

### Signatures

sig
EOF
"$CONTRACTS" < "$WORK/bare.md" > "$WORK/bare.out" 2> "$WORK/bare.err"
expect_rc "a pseudocode plan with no Internals section exits 1" 1 $?
if [[ -s "$WORK/bare.err" ]]; then ok "with an error on stderr"
else no "with an error on stderr" "stderr was empty"; fi
expect_not_contains "and stdout is not a quiet passthrough" \
  "$(cat "$WORK/bare.out")" "UNIQUE-BODY-MARKER-73"

# ---------------- 3: an unmarked document passes through byte-identical
# Internals included: without the front-matter marker the filter must not
# touch anything, even text shaped exactly like what it removes elsewhere.
cat > "$WORK/legacy.md" <<'EOF'
# A legacy plan with no front matter

## Slice 1 — thing

### Signatures

sig

### Internals

kept guts
EOF
"$CONTRACTS" < "$WORK/legacy.md" > "$WORK/legacy.out" 2> "$WORK/legacy.err"
expect_rc "an unmarked document exits 0" 0 $?
if cmp -s "$WORK/legacy.md" "$WORK/legacy.out"; then
  ok "and passes through byte-identical, Internals included"
else
  no "and passes through byte-identical, Internals included" \
    "$(diff -u "$WORK/legacy.md" "$WORK/legacy.out" 2>&1 | head -c 800)"
fi

# ---------------- 4: front matter without the marker is unmarked too
cat > "$WORK/prose.md" <<'EOF'
---
format: prose
---

## Slice 1 — thing

### Internals

kept guts
EOF
"$CONTRACTS" < "$WORK/prose.md" > "$WORK/prose.out" 2> "$WORK/prose.err"
expect_rc "front matter without format: pseudocode exits 0" 0 $?
if cmp -s "$WORK/prose.md" "$WORK/prose.out"; then
  ok "and passes through byte-identical"
else
  no "and passes through byte-identical" \
    "$(diff -u "$WORK/prose.md" "$WORK/prose.out" 2>&1 | head -c 800)"
fi

# ---------------- 5: the marker lives in the FRONT MATTER, not the body
# A legacy plan that merely TALKS about the format — the phrase inside a code
# fence, say — is still unmarked. The contract says "the first --- ... ---
# block", and this is exactly where a whole-file grep would go wrong.
cat > "$WORK/mention.md" <<'EOF'
# A plan about the format

Some plans carry front matter like this:

    format: pseudocode

## Slice 1 — thing

### Internals

kept guts
EOF
"$CONTRACTS" < "$WORK/mention.md" > "$WORK/mention.out" 2> "$WORK/mention.err"
expect_rc "a body mention of the marker does not mark the document" 0 $?
if cmp -s "$WORK/mention.md" "$WORK/mention.out"; then
  ok "and it passes through byte-identical"
else
  no "and it passes through byte-identical" \
    "$(diff -u "$WORK/mention.md" "$WORK/mention.out" 2>&1 | head -c 800)"
fi

summary
