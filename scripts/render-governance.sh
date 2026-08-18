#!/usr/bin/env bash
#
# render-governance.sh — render this repository's own governance files from the
# template it ships, so the template is governed by the template.
#
#     scripts/render-governance.sh            # write them
#     scripts/render-governance.sh --check    # fail if what is committed differs
#
# WHY THIS EXISTS AT ALL. Everything under `template/` only becomes live once a
# project is *rendered*, so until now the template's own development was
# governed by nothing it sells: plans before code, blind tests, the review gate
# and the oracle all applied downstream and not here. A repository whose entire
# argument is "gates catch what humans will not read" had almost none on itself.
#
# TWO MECHANISMS, AND WHICH ONE A FILE GETS IS DECIDED BY WHAT THE FILE IS.
#
#   PLAIN FILES ARE REFERENCED, NEVER COPIED. All sixteen gate scripts, all
#   seven command files, `review-prompt.md` and both driver scripts contain no
#   Jinja. `.github/workflows/template-ci.yml` invokes
#   `template/.github/scripts/<name>.sh` directly. There is one copy, it is the
#   one that ships, and drift is impossible by construction rather than by
#   checking. Nothing in this script touches them.
#
#   JINJA FILES ARE RENDERED HERE, AND THE RENDER IS CHECKED. A file carrying
#   Jinja cannot be referenced — `{{ project_name }}` is not a rule anyone can
#   follow — so it is rendered to the root and CI re-renders and diffs. Drift is
#   red.
#
# Rendering flows ONE WAY, `template/` to root, so there is no cycle.
#
# THE LIST BELOW IS AN ALLOWLIST AND MUST STAY ONE. Rendering the whole template
# here would overwrite `docs/escapes.md` — a real ledger cited by id from landed
# decisions — with a three-line stub, and would drop a `src/` and a `tests/`
# on top of this repository's own suite. Every path is named individually and
# nothing is rendered by pattern. If you are tempted to add a wildcard, that is
# the moment to re-read this paragraph.
#
# AGENTS.md IS COMPOSED, NOT COPIED, on the owner's ruling: "the template repo
# agents file (running the self-host) should be a combo = template agent (the
# one every project gets) + template self-host specific agent stuff." The
# shipped rules are universal — branch discipline, plan-before-code, blind
# tests, the ratchet, the gate-path list. What is true only here lives in
# `docs/agents.selfhost.md`, and this script joins the two.
#
# The shipped file's final `## Language-specific` section is DROPPED rather than
# rendered, and that is the one edit made to it. That section is by construction
# the per-project half — ruff and mypy, or swiftformat and xcodebuild — and none
# of it is true in a repository whose implementation is bash. The self-host
# document carries this repository's equivalent instead. Everything above that
# heading is reproduced verbatim, so a rule the template ships is a rule that
# governs here.
#
# The render answers `language: swift-ios`, and that is not arbitrary. The two
# inline conditionals left in the universal half both add the word "typing" for
# python, which this repository has none of; answering swift-ios drops them and
# the swift half of the file is cut away with the section anyway. The answer is
# a rendering detail with no consequence beyond those two words — if that stops
# being true, this comment is what says so.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

command -v copier >/dev/null 2>&1 \
  || { echo "render-governance: copier is not on PATH — 'uv tool install copier'" >&2; exit 2; }

SELFHOST="docs/agents.selfhost.md"
[[ -f "$SELFHOST" ]] || { echo "render-governance: missing $SELFHOST" >&2; exit 2; }

# The answers. `project_name` is this repository, and `code_owner` is the handle
# the shipped CODEOWNERS is written around — read from the template's own
# default so the two cannot drift apart silently.
CODE_OWNER="$(sed -n 's/^  default: "\(@[^"]*\)"/\1/p' copier.yml | head -1)"
[[ -n "$CODE_OWNER" ]] || { echo "render-governance: no code_owner default in copier.yml" >&2; exit 2; }

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Rendered into a scratch directory and copied out by name. Copier renders the
# whole subdirectory and there is no way to ask it for five files, so the
# subsetting happens here, where it is a list somebody has to read.
copier copy --defaults --trust --quiet --vcs-ref=HEAD \
  --data project_name="grimsverk-template" \
  --data language="swift-ios" \
  --data description="The template, hosting its own gates" \
  --data code_owner="$CODE_OWNER" \
  . "$OUT/render" >/dev/null

STAGE="$OUT/stage"
mkdir -p "$STAGE/.claude/agents" "$STAGE/.github"

# --- AGENTS.md: the shipped rules, minus the per-project half, plus this repo's
{
  awk '/^## Language-specific/ { exit } { print }' "$OUT/render/AGENTS.md"
  cat "$SELFHOST"
} > "$STAGE/AGENTS.md"

# --- the rest, rendered verbatim. One line per file, deliberately.
cp "$OUT/render/.github/CODEOWNERS"          "$STAGE/.github/CODEOWNERS"
cp "$OUT/render/.claude/settings.json"       "$STAGE/.claude/settings.json"
cp "$OUT/render/.claude/agents/reviewer.md"  "$STAGE/.claude/agents/reviewer.md"
cp "$OUT/render/.claude/agents/test-writer.md" "$STAGE/.claude/agents/test-writer.md"

# CODEOWNERS gets one appendix, and it is not cosmetic. The shipped file owns
# `/.github/`, `/.claude/` and the intent documents, which is the right list for
# a generated project — but this repository has two gate paths a generated one
# does not: the renderer below, and the test suite that is this repository's
# only proof its gates work. An unowned renderer is a renderer an agent can edit
# in the same pull request that the renderer is supposed to be checking.
cat >> "$STAGE/.github/CODEOWNERS" <<EOF

# ------------------------------------------------------------------ self-host
# Appended by scripts/render-governance.sh. Everything above is the file every
# generated project gets; these paths exist only in the template repository.
#
# The renderer is a gate: .github/workflows/template-ci.yml re-runs it and fails
# on drift, so a pull request that could edit it could edit the thing checking
# it. And tests/ is where every shipped gate is actually proved to work — the
# generated-project equivalent is CODEOWNERS-free because a project's tests are
# its own, but here the tests ARE the gate machinery's evidence.
/scripts/                    $CODE_OWNER
/tests/                      $CODE_OWNER
EOF

FILES=(
  AGENTS.md
  .github/CODEOWNERS
  .claude/settings.json
  .claude/agents/reviewer.md
  .claude/agents/test-writer.md
)

if [[ "$CHECK" -eq 1 ]]; then
  RC=0
  for f in "${FILES[@]}"; do
    if ! diff -u "$f" "$STAGE/$f" >/dev/null 2>&1; then
      echo "render-governance: $f differs from what template/ renders:" >&2
      # `|| true` on BOTH ends: diff exits 1 when there are differences, which
      # is the whole reason we are here, and `set -e` with `pipefail` would
      # otherwise abort the script mid-report — swallowing the explanation
      # below and leaving a reader with a diff and no instructions.
      { diff -u "$f" "$STAGE/$f" || true; } | head -60 >&2 || true
      RC=1
    fi
  done
  if [[ "$RC" -ne 0 ]]; then
    cat >&2 <<'MSG'

These files are RENDERED from template/, not written by hand. Editing one at the
root fixes this repository and ships nothing — the next generated project still
gets the old rule, and the two drift apart in the direction nobody notices.

Edit the source under template/, then run:

    scripts/render-governance.sh

...and commit the result. What is only true HERE goes in docs/agents.selfhost.md
instead, which is composed into AGENTS.md by the same script.
MSG
    exit 1
  fi
  echo "render-governance: ${#FILES[@]} governance file(s) match what template/ renders."
  exit 0
fi

for f in "${FILES[@]}"; do
  mkdir -p "$(dirname "$f")"
  cp "$STAGE/$f" "$f"
  echo "render-governance: wrote $f"
done
