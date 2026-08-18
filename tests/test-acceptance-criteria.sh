#!/usr/bin/env bash
#
# acceptance-criteria.sh — fixture tests.
#
# What this check exists for: `docs/acceptance.md` is the one artifact in an
# unattended run whose pull request requires the owner's review, and its
# evidence used to be an agent's narration. These tests pin the four properties
# that make a script-backed criterion worth more than a sentence:
#
#   - a criterion that fails, fails the pull request;
#   - a landed measurement cannot be deleted to stop it measuring;
#   - the table cannot claim `pass / agent` with nothing behind it;
#   - a criterion for work that is not built yet does NOT fail the pipeline,
#     because failing it would stop the build that would make it pass.
#
# Plus the two boundaries around the waiver: it is read from LANDED decisions
# at the base commit, and it names ONE criterion, never the check.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

CHECK="$HERE/../template/.github/scripts/acceptance-criteria.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== acceptance-criteria.sh ==="

R="$WORK/repo"
init_repo "$R"
mkdir -p "$R/docs" "$R/acceptance"

design() { # design <body of section 13>
  cat > "$R/docs/DESIGN.md" <<EOF
# Design

## 5. Requirements
- **R1** — a thing — *Evidenced by:* S1

## 13. Success criteria
$1
EOF
}
criterion() { # criterion <id> <exit code>
  printf '#!/usr/bin/env bash\necho "measured something for %s"\nexit %s\n' "$1" "$2" \
    > "$R/acceptance/$1.sh"
  chmod +x "$R/acceptance/$1.sh"
}
commit() { git -C "$R" add -A && git -C "$R" commit -qm "${1:-x}"; }
base() { git -C "$R" rev-parse HEAD; }
run() { ( cd "$R" && BASE_SHA="$1" bash "$CHECK" 2>&1 ); }

# ------------------------------------------------ the shipped skeleton is quiet
# A required check that was red on the first pull request of every generated
# project would be switched off inside a week. The §13 placeholder is written
# `**S<n>**` — angle brackets and all, the same trick as `BL-<n>` — so it
# carries no digit and matches no criterion.
design '- **S<n>** — *(covers R<n>)* —'
commit "skeleton"
B="$(base)"
out="$(run "$B")"
expect_rc "the shipped design skeleton passes its own gate" 0 $?
expect_contains "and finds no criteria to run" "$out" "0 agent-verifiable"

# ------------------------------------------- a criterion with no script is a note
design '- **S1** — *(covers R1)* — the thing works'
commit "a real criterion, nothing built yet"
B="$(base)"
out="$(run "$B")"
expect_rc "a criterion with no script yet does not fail the pipeline" 0 $?
expect_contains "but it is reported on every pull request" "$out" "No script yet: S1"

# ------------------------------------------------------ a script that passes
criterion S1 0
commit "S1 passes"
B="$(base)"
out="$(run "$B")"
expect_rc "a passing criterion passes" 0 $?
expect_contains "and its stdout is the evidence" "$out" "measured something for S1"

# ------------------------------------------------------- a script that fails
criterion S1 1
commit "S1 regresses"
B="$(base)"
out="$(run "$B")"
expect_rc "a failing criterion fails the check" 1 $?
expect_contains "and names the script and its exit code" "$out" "S1 failed: acceptance/S1.sh exited 1"
expect_contains "and points at the route out" "$out" "Criterion waived"

# --------------------------------------------------- (owner) rows are not run
# The split is decided in §13, which is CODEOWNERS-owned, so an agent cannot
# reclassify a criterion at the end of a run — the cheapest thing it could do.
design '- **S1** — *(covers R1)* — the thing works **(owner)**'
commit "S1 becomes the owner's"
B="$(base)"
out="$(run "$B")"
expect_rc "an (owner) criterion is never run, even with a script present" 0 $?
expect_contains "and says who judges it" "$out" "judged by the owner"
expect_not_contains "so its script's output is not the evidence" "$out" "measured something for S1"

# ------------------------------------------- a landed measurement cannot vanish
design '- **S1** — *(covers R1)* — the thing works'
criterion S1 1
commit "S1 is failing again"
B="$(base)"
rm -f "$R/acceptance/S1.sh"
out="$(run "$B")"
expect_rc "deleting a failing criterion's script fails the check" 1 $?
expect_contains "and says why deletion is not the fix" "$out" "a measurement is removed when its criterion is"
git -C "$R" checkout -q -- acceptance/S1.sh

# ...but removing it alongside the criterion is legitimate. §13 is read at the
# BASE commit — like every other standard in this repository — so the owner's
# removal of the criterion lands first, and the script goes on the next pull
# request. That ordering is the point, not an inconvenience: a change does not
# get to delete a measurement and rewrite the criterion it measured in one move.
design '- **S2** — *(covers R1)* — a different thing'
commit "the owner drops S1 from §13"
B="$(base)"
rm -f "$R/acceptance/S1.sh"
out="$(run "$B")"
expect_rc "removing a script whose criterion left §13 is fine" 0 $?
git -C "$R" checkout -q -- acceptance/S1.sh

# ------------------------------- the table cannot claim what it cannot re-run
cat > "$R/docs/acceptance.md" <<'EOF'
# Acceptance

| Criterion | Status | Verified by | Evidence |
| --- | --- | --- | --- |
| S1 | pass | agent | I ran the thing and it worked |
EOF
criterion S1 0
commit "claim a pass"
B="$(base)"
rm -f "$R/acceptance/S1.sh"
design '- **S1** — *(covers R1)* — the thing works'
out="$(run "$B")"
expect_rc "a 'pass / agent' row with no script fails the check" 1 $?
expect_contains "and says what a pass has to be" "$out" "or it is narration"
git -C "$R" checkout -q -- acceptance/S1.sh docs/DESIGN.md

# An owner row is a judgement call and no script can hold it, so the same
# absence there is not a finding.
cat > "$R/docs/acceptance.md" <<'EOF'
# Acceptance

| Criterion | Status | Verified by | Evidence |
| --- | --- | --- | --- |
| S1 | pending | owner | run it on the device and look at it |
EOF
design '- **S1** — *(covers R1)* — the thing works **(owner)**'
rm -f "$R/acceptance/S1.sh"
commit "an owner row, and no script for it"
B="$(base)"
out="$(run "$B")"
expect_rc "a 'pending / owner' row needs no script" 0 $?

# ------------------------------------------------------------- the waiver
design '- **S1** — *(covers R1)* — the thing works
- **S2** — *(covers R1)* — the other thing works'
criterion S1 1
criterion S2 1
commit "two failing criteria"
B="$(base)"
out="$(run "$B")"
expect_rc "both failing criteria fail the check" 1 $?

# A waiver in the WORKING TREE does nothing: it is read from landed decisions
# at the base commit, exactly like every other citation in this repository. A
# pull request cannot waive the criterion it is failing.
cat > "$R/docs/DESIGN.oracle.md" <<'EOF'
# Design decisions from evidence

## OD-1 — S1 is met in a way its script cannot see
- **Date:** 2026-08-18
- **Evidence:** BL-1
- **Criterion waived:** S1 — the built system satisfies this through the cache layer, which the script does not observe at all
EOF
out="$(run "$B")"
expect_rc "an unlanded waiver waives nothing" 1 $?
expect_contains "and S1 is still reported as failing" "$out" "S1 failed"

commit "land the waiver"
B="$(base)"
out="$(run "$B")"
expect_rc "a landed waiver still leaves the other criterion gating" 1 $?
expect_contains "S1 is waived, naming the decision" "$out" "S1    WAIVED   by OD-1"
expect_contains "and S2 is not — a waiver names a criterion, never the check" "$out" "S2 failed"

# With both waived the check is green, and the acceptance table is where the
# claim of doneness does NOT go green.
cat >> "$R/docs/DESIGN.oracle.md" <<'EOF'

## OD-2 — S2 likewise
- **Date:** 2026-08-18
- **Evidence:** BL-2
- **Criterion waived:** S2 — delivered by the batching path, which this script cannot reach from outside
EOF
commit "waive the second"
B="$(base)"
out="$(run "$B")"
expect_rc "every criterion waived is a green gate" 0 $?

summary
