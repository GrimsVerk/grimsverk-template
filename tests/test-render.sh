#!/usr/bin/env bash
#
# Render tests — does the template actually produce a valid project?
#
# The bug that motivated these: project_name "My App 2.0" slugified to
# "my-app-2.0", which became the Python package "my_app_2_0"... except it did
# not, it became "my_app_2.0", which is not an importable identifier. The
# generated project was broken at render time and nothing noticed, because
# nothing had ever rendered the template in CI.
#
# Requires: copier on PATH (uv tool install copier).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TEMPLATE="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== render ==="

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

render() { # render <outdir> <language> [extra --data args...]
  local out="$1" lang="$2"; shift 2
  copier copy --defaults --trust --quiet \
    --data project_name="Demo App" \
    --data language="$lang" \
    --data code_owner="@grimsverk" \
    "$@" "$TEMPLATE" "$out" 2>&1
}

for lang in python swift-ios; do
  out="$WORK/$lang"
  msg="$(render "$out" "$lang")"
  if [[ ! -d "$out" ]]; then no "$lang renders" "$msg"; continue; fi
  ok "$lang renders"

  # No unrendered Jinja anywhere in the output. A stray {{ }} means a file was
  # copied verbatim that should have been a .jinja, or a conditional path did
  # not resolve — both ship broken projects that look fine in a diff.
  #
  # GitHub Actions expressions are spelled ${{ ... }} and are NOT Jinja: the
  # workflows carrying them (review.yml, auto-merge.yml) are deliberately not
  # .jinja files so those expressions reach GitHub intact. Strip them before
  # looking, or every render "fails" for doing exactly the right thing.
  stray=""
  while IFS= read -r f; do
    if perl -pe 's/\$\{\{.*?\}\}//g' "$f" 2>/dev/null | grep -qE '\{\{|\{%'; then
      stray="$stray ${f#"$out"/}"
    fi
  done < <(grep -rlE '\{\{|\{%' "$out" 2>/dev/null || true)
  if [[ -z "$stray" ]]; then ok "$lang has no unrendered Jinja"
  else no "$lang has no unrendered Jinja" "$stray"; fi

  # Every workflow must parse as YAML.
  bad=""
  for wf in "$out"/.github/workflows/*.yml; do
    [[ -e "$wf" ]] || continue
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$wf" 2>/dev/null \
      || bad="$bad $(basename "$wf")"
  done
  if [[ -z "$bad" ]]; then ok "$lang workflows parse as YAML"
  else no "$lang workflows parse as YAML" "$bad"; fi

  # CODEOWNERS must carry the resolved handle, and cover the gates' inputs.
  co="$out/.github/CODEOWNERS"
  if grep -q '@grimsverk' "$co" 2>/dev/null; then ok "$lang CODEOWNERS resolves the handle"
  else no "$lang CODEOWNERS resolves the handle"; fi
  for path in /AGENTS.md /docs/DESIGN.md /docs/plans/ /.github/; do
    if grep -q "^$path" "$co" 2>/dev/null; then ok "$lang CODEOWNERS covers $path"
    else no "$lang CODEOWNERS covers $path"; fi
  done

  # Every shipped script must be executable — CI invokes them by path.
  nonexec=""
  while IFS= read -r s; do
    [[ -x "$s" ]] || nonexec="$nonexec ${s#"$out"/}"
  done < <(find "$out" -name '*.sh' -type f)
  if [[ -z "$nonexec" ]]; then ok "$lang scripts are executable"
  else no "$lang scripts are executable" "$nonexec"; fi
done

# ------------------------------------------------ the slug validator bites
msg="$(render "$WORK/bad-slug" python --data project_slug="my-app-2.0" 2>&1)"
if [[ -d "$WORK/bad-slug" ]]; then
  no "a slug that breaks the package name is rejected" "it rendered anyway"
else
  ok "a slug that breaks the package name is rejected"
  expect_contains "explains the slug rule" "$msg" "project_slug must be"
fi

msg="$(render "$WORK/bad-owner" python --data code_owner="grimsverk" 2>&1)"
if [[ -d "$WORK/bad-owner" ]]; then
  no "a code_owner without @ is rejected" "it rendered anyway"
else
  ok "a code_owner without @ is rejected"
fi

# ------------------------- a fresh render must pass its own formatter check
# `ruff format` formats Python code blocks inside Markdown, so the illustrative
# snippet in docs/plans/_TEMPLATE.md is subject to it. A generated project that
# fails its own gate before anyone has written a line is the worst possible
# first impression, and it is invisible until someone actually renders and runs.
if command -v uv >/dev/null && [[ -d "$WORK/python" ]]; then
  fmt="$( cd "$WORK/python" && uv sync -q >/dev/null 2>&1 \
    && uv run ruff format --check . 2>&1 )"
  if [[ $? -eq 0 ]]; then ok "a fresh python render is already ruff-format clean"
  else no "a fresh python render is already ruff-format clean" "$fmt"; fi
fi

# A valid multi-word name still renders and yields an importable package.
if render "$WORK/ok-slug" python --data project_name="My Second App" >/dev/null 2>&1; then
  ok "a valid multi-word name renders"
  pkg="$(find "$WORK/ok-slug/src" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)"
  if python3 -c "import sys; sys.exit(0 if sys.argv[1].isidentifier() else 1)" "$pkg"; then
    ok "package name '$pkg' is a valid Python identifier"
  else
    no "package name is a valid Python identifier" "got: $pkg"
  fi
else
  no "a valid multi-word name renders"
fi

summary
