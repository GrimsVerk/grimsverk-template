#!/usr/bin/env bash
#
# render-governance.sh — the template's own governance is rendered, not written.
#
# Self-hosting has exactly one failure mode worth a test, and it is silent: a
# rule gets fixed at the ROOT, this repository starts obeying it, and the fix
# ships to nobody — the next generated project still gets the old rule, and the
# two drift apart in the direction nobody notices. The drift check is what makes
# that impossible, so these tests are about the drift check working rather than
# about the rendering being pretty.
#
# What is pinned:
#   - a clean tree reports no drift;
#   - an edit to ANY of the five rendered files is caught, and the message says
#     to edit the source rather than the root;
#   - AGENTS.md really is composed — the shipped rules AND the self-host
#     section, with the per-project language section dropped;
#   - the CODEOWNERS appendix that owns the renderer is present, because an
#     unowned renderer is a renderer a pull request can edit in the same breath
#     as the thing it checks;
#   - the list of rendered files is an ALLOWLIST: nothing else at the root was
#     overwritten. That is the one that matters most. Rendering the whole
#     template here would replace docs/escapes.md — a 36-row ledger cited by id
#     from landed decisions — with a three-line stub.
#
# Requires: copier on PATH (uv tool install copier).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

ROOT="$(cd "$HERE/.." && pwd)"

echo "=== render-governance.sh ==="

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

# A throwaway clone, so nothing here can write to the real working tree. The
# script renders with --vcs-ref=HEAD, so the clone needs the history.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
R="$WORK/clone"
git clone -q --no-hardlinks "$ROOT" "$R" 2>/dev/null || { no "clone the repository"; summary; exit 1; }
git -C "$R" config user.email "tests@example.invalid"
git -C "$R" config user.name "Template Tests"
git -C "$R" config commit.gpgsign false

# The clone is at the last COMMIT, and this suite may be running against
# uncommitted work. Commit whatever the working tree carries into the clone so
# the fixture is the tree under test rather than the tree before it.
tar -C "$ROOT" --exclude=.git -cf - . 2>/dev/null | tar -C "$R" -xf - 2>/dev/null
git -C "$R" add -A >/dev/null 2>&1
git -C "$R" commit -q -m "working tree" >/dev/null 2>&1 || true

run() { ( cd "$R" && bash "$R/scripts/render-governance.sh" "$@" 2>&1 ); }

FILES=(AGENTS.md .github/CODEOWNERS .claude/settings.json
       .claude/agents/reviewer.md .claude/agents/test-writer.md)

# ------------------------------------------------- a clean tree has no drift
out="$(run --check)"
expect_rc "a freshly rendered tree reports no drift" 0 $?
expect_contains "and counts what it checked" "$out" "governance file(s) match"

# ------------------------------------------- each rendered file is watched
# One at a time, and all five, because a check that watched four of them would
# pass every test written against the fifth.
for f in "${FILES[@]}"; do
  cp "$R/$f" "$WORK/keep"
  printf '\nEDITED AT THE ROOT, WHICH SHIPS NOTHING\n' >> "$R/$f"
  out="$(run --check)"
  expect_rc "an edit to $f is caught" 1 $?
  expect_contains "and $f is named" "$out" "$f"
  cp "$WORK/keep" "$R/$f"
done
expect_contains "and the message says where to edit instead" "$out" "Edit the source under template/"

# ------------------------------------------------------- AGENTS.md is composed
# The owner's ruling: "the template repo agents file (running the self-host)
# should be a combo = template agent (the one every project gets) + template
# self-host specific agent stuff."
agents="$(cat "$R/AGENTS.md")"
expect_contains "AGENTS.md carries the shipped branch rule" "$agents" \
  "Never commit to the default branch directly"
expect_contains "AGENTS.md carries the shipped gate-path list" "$agents" \
  "Gate paths are off-limits"
expect_contains "AGENTS.md carries the self-host half" "$agents" \
  "What is true only in this repository"
expect_contains "and says template/ is product, not instructions" "$agents" \
  "never as rules addressed to you"

# The per-project language section is dropped rather than rendered: none of it
# is true in a repository whose implementation is bash, and a rules file
# carrying a false instruction is worse than one that is silent.
expect_not_contains "the per-project language section is dropped" "$agents" \
  "## Language-specific"
expect_not_contains "so no python toolchain is claimed" "$agents" "uv run mypy"
expect_not_contains "and no swift toolchain either" "$agents" "xcodebuild test -project"
expect_contains "the self-host half names this repository's real gate" "$agents" "tests/run.sh"

# ------------------------------------- the renderer is not writable unreviewed
co="$(cat "$R/.github/CODEOWNERS")"
expect_contains "CODEOWNERS carries the shipped rules" "$co" "/docs/DESIGN.md"
expect_contains "and owns the renderer, which is itself a gate" "$co" "/scripts/"
expect_contains "and the suite that proves the gates work" "$co" "/tests/"

# ------------------------------------------------- the list is an ALLOWLIST
# The load-bearing one. Rendering the whole template to the root would overwrite
# docs/escapes.md with a three-line stub — a ledger cited by id from landed
# decisions — and drop a src/ and a tests/ on top of this repository's own
# suite. Every path the renderer writes is named individually; this asserts that
# running it changes nothing else.
git -C "$R" add -A >/dev/null 2>&1
git -C "$R" commit -q -m "before" >/dev/null 2>&1 || true
run >/dev/null
changed="$(git -C "$R" status --porcelain | awk '{print $NF}' | sort)"
if [[ -z "$changed" ]]; then
  ok "a re-render changes nothing outside the five rendered files"
else
  unexpected=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    known=0
    for k in "${FILES[@]}"; do [[ "$f" == "$k" ]] && known=1; done
    [[ "$known" -eq 1 ]] || unexpected="$unexpected $f"
  done <<<"$changed"
  if [[ -z "$unexpected" ]]; then
    ok "a re-render changes nothing outside the five rendered files"
  else
    no "a re-render changes nothing outside the five rendered files" "also wrote:$unexpected"
  fi
fi

# Named explicitly, because these are the two whose loss would be worst and
# whose absence from a diff is easy to miss.
for f in docs/escapes.md docs/synthesis.md; do
  if git -C "$R" diff --quiet -- "$f" 2>/dev/null; then
    ok "$f is untouched by the renderer"
  else
    no "$f is untouched by the renderer"
  fi
done

summary
