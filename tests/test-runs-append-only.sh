#!/usr/bin/env bash
#
# test-runs-append-only.sh — run evidence cannot be rewritten (grounding-and-
# evidence slice 4, ESC-223). Written blind from the slice's Delivers.
#
# docs/runs/ is the evidence a future run reads to avoid repeating this one's
# mistakes, and evidence that can be edited after the fact is testimony, not
# evidence. The rule is append-only at FILE granularity — stricter than the
# ledgers, which accept appended rows: a file landed under docs/runs/ may not
# change by a byte and may not be deleted, so even a pure append to a landed
# run log is a modification. Corrections are new files that cite the old.
# New files land freely, and everything outside docs/runs/ is none of this
# gate's business.
#
# Same invocation shape as the other BASE_SHA gates: run from the fixture
# repo's root, judged against the working tree.

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

CHECK="$ROOT/template/.github/scripts/runs-append-only.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== runs-append-only.sh — landed run evidence holds ==="

# ------------------------------------------------------------------- fixture
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/runs/2026-08-20-1" "$R/docs"

cat > "$R/docs/runs/2026-08-20-1/run.md" <<'EOF'
# Run 2026-08-20 #1

- 14:02 dispatched slice 1
- 14:31 pull request opened
EOF
printf '{"verdict":"approve"}\n' > "$R/docs/runs/2026-08-20-1/review-payload.json"
printf '# demo\n' > "$R/README.md"
printf 'working notes\n' > "$R/docs/notes.md"
git -C "$R" add -A && git -C "$R" commit -qm "seed with one landed run"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { ( cd "$R" && BASE_SHA="$BASE" "$CHECK" 2>&1 ); }

# ------------------------------------------------------------ allowed shapes
run >/dev/null
expect_rc "an untouched tree passes" 0 $?

printf '# extra evidence citing run.md\n' > "$R/docs/runs/2026-08-20-1/correction.md"
mkdir -p "$R/docs/runs/2026-08-21-1"
printf '# Run 2026-08-21 #1\n' > "$R/docs/runs/2026-08-21-1/run.md"
run >/dev/null
expect_rc "new files under docs/runs/ append freely" 0 $?
rm -rf "$R/docs/runs/2026-08-20-1/correction.md" "$R/docs/runs/2026-08-21-1"

# ------------------------------------------------------------ rewrite shapes
sed -i 's/dispatched slice 1/dispatched slice 2/' "$R/docs/runs/2026-08-20-1/run.md"
out="$(run)"
expect_rc "editing a landed run file fails" 1 $?
expect_contains "and the message names the file" "$out" "2026-08-20-1/run.md"
git -C "$R" checkout -q -- .

# File granularity: unlike the row ledgers, appending to a landed file is
# still a modification — a run that ended does not get more history.
echo "- 15:00 revised recollection" >> "$R/docs/runs/2026-08-20-1/run.md"
run >/dev/null
expect_rc "appending to a landed run file fails too — file granularity" 1 $?
git -C "$R" checkout -q -- .

rm "$R/docs/runs/2026-08-20-1/review-payload.json"
run >/dev/null
expect_rc "deleting a landed run file fails" 1 $?
git -C "$R" checkout -q -- .

rm -rf "$R/docs/runs"
run >/dev/null
expect_rc "deleting the whole evidence directory fails" 1 $?
git -C "$R" checkout -q -- .

# ------------------------------------------- outside docs/runs/ is ignored
sed -i 's/# demo/# demo, reworded/' "$R/README.md"
rm "$R/docs/notes.md"
run >/dev/null
expect_rc "edits and deletions outside docs/runs/ are ignored entirely" 0 $?
git -C "$R" checkout -q -- .

# And a rewrite inside is still caught when innocent changes ride alongside.
sed -i 's/# demo/# demo, reworded/' "$R/README.md"
sed -i 's/14:31/14:32/' "$R/docs/runs/2026-08-20-1/run.md"
run >/dev/null
expect_rc "an inside rewrite fails even alongside outside changes" 1 $?
git -C "$R" checkout -q -- .

# --------------------------------------------------------------- empty base
# A project that has never run unattended: no docs/runs/ at base, none in the
# tree, nothing to protect.
R2="$WORK/fresh"
init_repo "$R2"
printf '# fresh\n' > "$R2/README.md"
git -C "$R2" add -A && git -C "$R2" commit -qm "seed"
B2="$(git -C "$R2" rev-parse HEAD)"
( cd "$R2" && BASE_SHA="$B2" "$CHECK" >/dev/null 2>&1 )
expect_rc "no docs/runs/ at base and none in the tree passes" 0 $?

# And the first run's evidence — a directory the base has never seen — lands.
mkdir -p "$R2/docs/runs/2026-08-27-1"
printf '# Run 2026-08-27 #1\n' > "$R2/docs/runs/2026-08-27-1/run.md"
( cd "$R2" && BASE_SHA="$B2" "$CHECK" >/dev/null 2>&1 )
expect_rc "a first-ever docs/runs/ directory is a pure append and passes" 0 $?

summary
