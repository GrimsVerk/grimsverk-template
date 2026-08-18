#!/usr/bin/env bash
#
# actionlint over every workflow this repository ships — its OWN, and the ones a
# generated project gets.
#
# ESC-36 is why this exists. `auto-merge.yml` referenced the `secrets` context
# inside a step `if:`, which is not allowed there. That is not a step that
# skips: the FILE fails validation, the run is created with zero jobs, and every
# job in it dies — arming, branch deletion, and the nightly sweep alike. Three
# releases shipped it. Nothing here could see it, because the shipped workflow
# the template never runs on itself is exactly this one.
#
# TWO THINGS ARE LINTED, and the second is the point:
#
#   1. .github/workflows/            — this repository's own CI.
#   2. a RENDERED project's workflows — the shipped files, after copier has
#      resolved the Jinja in `ci.yml.jinja` and in the conditional filenames.
#      Linting template/.github/workflows/ directly cannot work: `{% if %}` is
#      not YAML, and the file whose name IS a Jinja expression would be skipped
#      by any tool that globs for *.yml.
#
# A SKIP EXITS 0, AND THAT IS THE FAILURE THIS PROJECT KEEPS RE-LEARNING. So:
# actionlint missing is exit 2, not a pass; copier missing is exit 2, not a
# pass; and finding zero workflow files to lint is exit 2 as well. actionlint
# itself exits 0 when its directory scan finds nothing, which is why every file
# is passed to it BY NAME and the count is printed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTIONLINT="${ACTIONLINT:-actionlint}"

die() { echo "lint-workflows: $*" >&2; exit 2; }

command -v "$ACTIONLINT" >/dev/null \
  || die "actionlint is not on PATH. Install it (go install github.com/rhysd/actionlint/cmd/actionlint@latest) or set ACTIONLINT. Refusing to pass by skipping."
command -v copier >/dev/null \
  || die "copier is not on PATH (uv tool install copier). The shipped workflows cannot be linted without rendering them."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FILES=()

# 1. This repository's own workflows.
while IFS= read -r f; do FILES+=("$f"); done < <(
  find "$ROOT/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort
)

# 2. A rendered project, per language — the conditional filenames and ci.yml's
# Jinja both differ by language, so one render would leave the other unlinted.
#
# --vcs-ref=HEAD for the same reason tests/test-render.sh gives: pointed at a
# git repository copier renders the latest TAG by default, so without it this
# would lint the last release instead of the change under test.
for lang in python swift-ios; do
  out="$WORK/$lang"
  copier copy --defaults --trust --quiet --vcs-ref=HEAD \
    --data language="$lang" --data code_owner="@grimsverk" \
    "$ROOT" "$out" >/dev/null 2>&1 \
    || die "copier could not render $lang; nothing was linted"
  [[ -d "$out/.github/workflows" ]] \
    || die "a rendered $lang project has no .github/workflows — either the template stopped shipping them or the render is broken"
  while IFS= read -r f; do FILES+=("$f"); done < <(
    find "$out/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort
  )
done

[[ "${#FILES[@]}" -gt 0 ]] || die "no workflow files found; a green result here would mean nothing"

echo "lint-workflows: checking ${#FILES[@]} workflow file(s)."
for f in "${FILES[@]}"; do echo "  ${f#"$WORK"/}"; done

# Rendered paths appear in actionlint's messages as temporary directories, which
# is confusing but honest: the defect is in template/, and the line number is
# the rendered one. The stripped listing above is what maps it back.
"$ACTIONLINT" "${FILES[@]}"
echo "lint-workflows: every workflow parses and every context reference is legal."
