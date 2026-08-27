#!/usr/bin/env bash
#
# test-binds.sh — a decision declares what it binds to, and the gate resolves
# it (grounding-and-evidence slice 1, ESC-222). Written blind from the slice's
# Delivers.
#
# A decision that fastens a requirement to `acceptance/S1.sh` while nothing at
# the base commit is called that has bound itself to a phantom, and nobody
# notices until a plan tries to cite the artifact. So the new optional
# `- **Binds:**` field takes two entry shapes and nothing else: `path:<p>`,
# which must exist in the tree AT BASE_SHA — the only commit anything checks —
# and `ordered:<p>`, the declared artifact-ordered state, which promises the
# path into existence as steward work and is checked by nothing here. The rule
# binds new decisions only: a ledger written before the field existed is
# history, not a violation.
#
# Same recipe as tests/test-oracle-decisions.sh: one decision block known to
# pass, and every case below is exactly one deviation from it.

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

CHECK="$ROOT/template/.github/scripts/oracle-decisions.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== oracle-decisions.sh — the Binds field ==="

# ------------------------------------------------------------------- fixture
R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs/plans/oracle" "$R/docs/oracle" "$R/acceptance"

cat > "$R/docs/escapes.md" <<'EOF'
# Escapes

| Id | Date | What escaped | Gate | Check added |
| --- | --- | --- | --- | --- |
| ESC-1 | 2026-08-15 | excerpting cost more than it saved | none existed | pending |
EOF

cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

Append-only. Every decision cites evidence that already landed.
EOF

cat > "$R/docs/VISION.md" <<'EOF'
# Vision

## Priorities, in order

- **V1** — Cost is a ceiling, not a preference. I would rather the tool refuse
  a job than quietly spend more than I budgeted for it.
- **V2** — I would trade any feature for a design I can hold in my head.
EOF

# The artifact a decision below binds to. It exists AT BASE, which is the
# state `path:` asserts.
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/acceptance/S1.sh"

git -C "$R" add -A && git -C "$R" commit -qm "seed"
BASE="$(git -C "$R" rev-parse HEAD)"

run() { ( cd "$R" && BASE_SHA="$BASE" "$CHECK" 2>&1 ); }
commit() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

# A decision block known to pass, every required field present (including the
# disposition: it adds a requirement). Each case is one named deviation.
decision() { # decision <n> <requirements-added>
  cat <<EOF

## OD-$1 — send whole transcripts rather than excerpts

- **Date:** 2026-08-15
- **Evidence:** ESC-1
- **Requirements added:** $2
- **Requirements superseded:** (none)
- **Vision statement relied on:** V1 — "Cost is a ceiling, not a preference."
- **Vision statements against:** V2 — "I would trade any feature for a design I
  can hold in my head." Sending whole transcripts is the simpler of the two, so
  this statement does not tell against it.
- **Alternatives considered:** tighter windows; a per-video cap. Both leave the
  compounding merge in place, which is the thing that was measured wrong.
- **Rationale:** measured on real data, excerpting produced 4.8x the characters
  of the whole transcript it was cut from, so the stage that exists to cut cost
  raises it.
EOF
}

# ---------------- 1: the field is optional
decision 1 "R1000" >> "$R/docs/DESIGN.oracle.md"
commit "Add OD-1 with no Binds field"
out="$(run)"
expect_rc "a decision without a Binds field passes — the field is optional" 0 $?

# OD-1 has landed; every case below is one new decision against this base.
BASE="$(git -C "$R" rev-parse HEAD)"

# ---------------- 2: path entries that exist at base resolve
{ decision 2 "R1001"
  echo "- **Binds:** path:acceptance/S1.sh, ordered:fixtures/variants.csv"
} >> "$R/docs/DESIGN.oracle.md"
commit "Bind to a path that exists at base and an ordered artifact"
out="$(run)"
expect_rc "path: to a file present at base, plus an ordered: entry, passes" 0 $?
git -C "$R" reset -q --hard HEAD~1

# Entries are separated by commas and/or spaces — spaces alone must parse too.
{ decision 2 "R1001"
  echo "- **Binds:** path:acceptance/S1.sh ordered:fixtures/variants.csv"
} >> "$R/docs/DESIGN.oracle.md"
commit "Bind with space-separated entries"
out="$(run)"
expect_rc "space-separated Binds entries parse the same" 0 $?
git -C "$R" reset -q --hard HEAD~1

# ---------------- 3: a path absent at base fails, even if the PR adds it
# The same backward-only rule as evidence citation: `path:` is a claim about
# the base commit, and a file riding in the same pull request is not there.
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/acceptance/S9.sh"
{ decision 2 "R1001"
  echo "- **Binds:** path:acceptance/S9.sh"
} >> "$R/docs/DESIGN.oracle.md"
commit "Bind to a path added in the same change"
out="$(run)"
expect_rc "path: to a file absent at base fails, working tree notwithstanding" 1 $?
expect_contains "and the message names ordered: as the escape" "$out" "ordered:"
git -C "$R" reset -q --hard HEAD~1

# ---------------- 4: ordered entries are declarations, not claims
# `ordered:` is the artifact-ordered state — steward work will create it — so
# no existence check applies, at base or anywhere else.
{ decision 2 "R1001"
  echo "- **Binds:** ordered:fixtures/variants.csv"
} >> "$R/docs/DESIGN.oracle.md"
commit "Bind only to an ordered artifact that exists nowhere"
out="$(run)"
expect_rc "an ordered: entry passes with no existence check" 0 $?
git -C "$R" reset -q --hard HEAD~1

# ---------------- 5: an entry with neither prefix fails
# A bare path is ambiguous between the two states the field exists to
# distinguish — resolved against base, or promised — so it is refused even
# when the file happens to exist.
{ decision 2 "R1001"
  echo "- **Binds:** acceptance/S1.sh"
} >> "$R/docs/DESIGN.oracle.md"
commit "Bind with no prefix"
out="$(run)"
expect_rc "a Binds entry with neither prefix fails" 1 $?
expect_contains "and the message names the accepted prefixes" "$out" "path:"
git -C "$R" reset -q --hard HEAD~1

# ---------------- 6: the marker with nothing after it fails
{ decision 2 "R1001"
  echo "- **Binds:**"
} >> "$R/docs/DESIGN.oracle.md"
commit "Bind to nothing at all"
out="$(run)"
expect_rc "an empty Binds field fails" 1 $?
git -C "$R" reset -q --hard HEAD~1

# ---------------- 7: the rule binds new decisions only
# Land a decision with a bad Binds line, so it exists at BASE_SHA. It is
# history now — re-judging it would make every ledger written before the rule
# permanently red.
{ decision 2 "R1001"
  echo "- **Binds:** acceptance/S1.sh"
} >> "$R/docs/DESIGN.oracle.md"
commit "Land a decision with a prefixless Binds line"
BASE="$(git -C "$R" rev-parse HEAD)"
out="$(run)"
expect_rc "a landed decision with a bad Binds line is not re-judged" 0 $?

decision 3 "R1002" >> "$R/docs/DESIGN.oracle.md"
commit "Append a clean decision on top of the landed bad one"
out="$(run)"
expect_rc "and a clean append on top of it still passes" 0 $?
expect_contains "with only the appended decision counted as new" "$out" \
  "1 new in this pull request"

summary
