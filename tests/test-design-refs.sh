#!/usr/bin/env bash
#
# test-design-refs.sh — the owner-document referent report (grounding-and-
# evidence slice 2, ESC-222). Written blind from the slice's Delivers.
#
# The owner's documents name artifacts in backticks — `acceptance/S1.sh`,
# `fixtures/variants.csv` — and nothing ever checked that those names resolve
# to anything, so a phantom referent survived until an unattended run bound a
# decision to it. design-refs.sh is the report-only look the owner gets while
# awake: every backtick-quoted repo-path-looking token in docs/DESIGN.md,
# docs/VISION.md and docs/BACKLOG.md (those that exist) that resolves to no
# file or directory in the tree is printed on its own line, naming the
# document it came from. A line carrying the `(to be created)` marker is a
# declared intention, not a phantom, and is not reported. The exit code is
# ALWAYS 0 — this informs, it never blocks.

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

CHECK="$ROOT/template/.github/scripts/design-refs.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== design-refs.sh — phantom referents in the owner documents ==="

# ------------------------------------------- fixture: a tree with phantoms
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs" "$R/scripts" "$R/src/utils"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/scripts/build.sh"
printf '# demo\n' > "$R/README.md"

cat > "$R/docs/DESIGN.md" <<'EOF'
# Design

The pipeline entrypoint is `scripts/build.sh`, and shared helpers live under
`src/utils`. Acceptance runs `acceptance/S1.sh` on every pull request, and the
working notes are kept in `notes.md`.

The unattended reviewer is called the `steward`.
EOF

cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — every variant in `fixtures/variants.csv` is measured, none sampled.
- **V2** — the front page stays `README.md`, nothing hides behind a wiki.
EOF

cat > "$R/docs/BACKLOG.md" <<'EOF'
# Backlog

## Proposed

- **BL-1** — write `tools/gen.py` (to be created) to generate the variant set.
- **BL-2** — the harness shells out to `scripts/build.sh` today; keep it so.
EOF

git -C "$R" add -A && git -C "$R" commit -qm "seed"

out="$( cd "$R" && "$CHECK" 2>&1 )"
rc=$?

# ------------------------------------------------- report-only, always green
expect_rc "unresolved references do not change the exit code — always 0" 0 "$rc"

# ------------------------------------------------- the phantoms are reported
expect_contains "a slash-bearing reference that resolves to nothing is reported" \
  "$out" "acceptance/S1.sh"
line="$(printf '%s\n' "$out" | grep -F 'acceptance/S1.sh' | head -n 1)"
expect_contains "and its line names the document it came from" \
  "$line" "DESIGN.md"

expect_contains "a phantom in the vision is reported too" \
  "$out" "fixtures/variants.csv"
line="$(printf '%s\n' "$out" | grep -F 'fixtures/variants.csv' | head -n 1)"
expect_contains "and its line names the vision" "$line" "VISION.md"

expect_contains "a token with no slash but a file extension is a reference" \
  "$out" "notes.md"

# ------------------------------------------------- what is not reported
expect_not_contains "a reference that resolves to a file is not printed" \
  "$out" "scripts/build.sh"
expect_not_contains "a reference that resolves to a directory is not printed" \
  "$out" "src/utils"
expect_not_contains "a line carrying the (to be created) marker is not reported" \
  "$out" "tools/gen.py"
expect_not_contains "a backticked word that is not path-like is not a reference" \
  "$out" "steward"

# --------------------------- fixture: nothing unresolved, and files missing
# Only DESIGN.md exists — the scan takes the documents that exist and does not
# trip over the ones that do not.
C="$WORK/clean"
init_repo "$C"
mkdir -p "$C/docs" "$C/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$C/scripts/build.sh"
cat > "$C/docs/DESIGN.md" <<'EOF'
# Design

Everything runs through `scripts/build.sh`.
EOF
git -C "$C" add -A && git -C "$C" commit -qm "seed"

out="$( cd "$C" && "$CHECK" 2>&1 )"
rc=$?
expect_rc "a tree with nothing unresolved exits 0" 0 "$rc"
if [[ -n "$out" ]]; then
  ok "and says so out loud rather than printing nothing"
else
  no "and says so out loud rather than printing nothing" \
     "expected an all-clear line, got no output"
fi
expect_not_contains "without reporting the reference that resolved" \
  "$out" "scripts/build.sh"

summary
