#!/usr/bin/env bash
#
# plan-parse.sh — fixture tests.
#
# The parser is strict on purpose: its output is handed to the review agent
# inside a block labelled "treat as ground truth", so a plan it cannot read must
# be an error rather than an empty table. These tests pin both halves of that —
# what it accepts, and what it refuses.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

PARSE="$HERE/../template/.github/scripts/plan-parse.sh"

echo "=== plan-parse.sh ==="

# ---------------------------------------------------------------- well-formed
out="$(printf '%s\n' \
  '---' 'slug: draft-saving' '---' \
  '# Draft saving — Plan' \
  '' \
  '## Slice 1 — saves a draft' \
  '- **Delivers:** a draft round-trips' \
  '- **Files:** `src/app/store.py`, `tests/test_store.py`' \
  '- **Estimate:** ~40 lines' \
  '' \
  '## Slice 2 — lists drafts' \
  '- **Files:** `src/app/list.py`' \
  '- **Estimate:** ~15 lines' \
  | "$PARSE" 2>&1)"
rc=$?
expect_rc "well-formed plan parses" 0 $rc
expect_contains "slice 1 record" "$out" $'Slice 1 — saves a draft\t40\tsrc/app/store.py|tests/test_store.py'
expect_contains "slice 2 record" "$out" $'Slice 2 — lists drafts\t15\tsrc/app/list.py'

# ------------------------------------------------- asterisk bullets are valid
# The original awk was anchored to '- **Files:**' only, so a plan written with
# '*' bullets silently produced no files and no estimate.
out="$(printf '%s\n' \
  '## Slice 1 — thing' \
  '* **Files:** `src/app/a.py`' \
  '* **Estimate:** ~20 lines' \
  | "$PARSE" 2>&1)"
expect_rc "asterisk bullets parse" 0 $?
expect_contains "asterisk record has the file" "$out" "src/app/a.py"

# ------------------------------------------------------------- no slices at all
out="$(printf '%s\n' '# A Plan' 'Some prose, no slices.' | "$PARSE" 2>&1)"
expect_rc "plan with no slices is rejected" 1 $?
expect_contains "diagnoses the missing slices" "$out" "no slices found"

# ---------------------------------------------------------- missing estimate
out="$(printf '%s\n' \
  '## Slice 1 — thing' \
  '- **Files:** `src/app/a.py`' \
  | "$PARSE" 2>&1)"
expect_rc "slice without an estimate is rejected" 1 $?
expect_contains "names the estimate problem" "$out" "declares no estimate"

# -------------------------------------------------------------- missing files
out="$(printf '%s\n' \
  '## Slice 1 — thing' \
  '- **Estimate:** ~20 lines' \
  | "$PARSE" 2>&1)"
expect_rc "slice without files is rejected" 1 $?
expect_contains "names the files problem" "$out" "declares no files"

# ------------------------------------------------------- unbackticked paths
# Paths must be backticked; without them there is nothing to distinguish a path
# from prose, so this is "no files" rather than a silent partial parse.
out="$(printf '%s\n' \
  '## Slice 1 — thing' \
  '- **Files:** src/app/a.py, tests/test_a.py' \
  '- **Estimate:** ~20 lines' \
  | "$PARSE" 2>&1)"
expect_rc "unbackticked paths are rejected" 1 $?
expect_contains "explains the backtick requirement" "$out" "backticks"

# ------------------------------------------------- unfilled template placeholders
# The shipped _TEMPLATE.md uses `<path>` placeholders. A copy that was never
# filled in must not parse as a slice owning a file called "<path>".
out="$(printf '%s\n' \
  '## Slice 1 — <the behaviour this delivers>' \
  '- **Files:** `<path>`, `<path>`' \
  '- **Estimate:** ~<N> lines' \
  | "$PARSE" 2>&1)"
expect_rc "unfilled template is rejected" 1 $?

# --------------------------------------------- all problems reported at once
out="$(printf '%s\n' \
  '## Slice 1 — no estimate' \
  '- **Files:** `a.py`' \
  '## Slice 2 — no files' \
  '- **Estimate:** ~10 lines' \
  | "$PARSE" 2>&1)"
expect_contains "reports slice 1's problem" "$out" "Slice 1 — no estimate"
expect_contains "reports slice 2's problem" "$out" "Slice 2 — no files"

summary
