#!/usr/bin/env bash
#
# Render tests — does the template actually produce a valid project?
#
# The bug that motivated these: a project name of "My App 2.0" produced the
# Python package "my_app_2.0", which is not an importable identifier. The
# generated project was broken at render time and nothing noticed, because
# nothing had ever rendered the template in CI.
#
# The name is no longer asked for at all — it is the destination directory — so
# these tests exercise it by choosing the OUTPUT DIRECTORY NAME rather than by
# passing --data.
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
  # --vcs-ref=HEAD is load-bearing. Pointed at a git repository, copier renders
  # the latest TAG by default — so without this every test here validated the
  # last release instead of the working tree, and a change under test was
  # invisible to its own tests. HEAD also pulls in uncommitted changes, which is
  # exactly what a pre-commit test run needs to see.
  copier copy --defaults --trust --quiet --vcs-ref=HEAD \
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

  # Every required check must exist as a job. This list is what the READMEs tell
  # you to mark required in branch protection, and a name that drifts out of the
  # workflow leaves a required check that never reports — every PR waits forever
  # on something that cannot arrive.
  ci="$out/.github/workflows/ci.yml"
  for job in plan template-sync secrets test-the-tests; do
    if grep -qE "^  ${job}:" "$ci" 2>/dev/null; then ok "$lang ci.yml defines '$job'"
    else no "$lang ci.yml defines '$job'"; fi
  done

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

  # The glossary must ship, with both lists present — the "learned" section is
  # the half that stops the agent over-explaining, so a file missing it is
  # worse than no file.
  g="$out/GLOSSARY.md"
  if [[ -f "$g" ]]; then
    ok "$lang ships GLOSSARY.md"
    for heading in "## How to talk to me" "## Words I'm learning" "## Words I've learned"; do
      if grep -qF "$heading" "$g"; then ok "$lang glossary has '$heading'"
      else no "$lang glossary has '$heading'"; fi
    done
  else
    no "$lang ships GLOSSARY.md"
  fi

  # The PROJECT glossary must NOT ship. It is created on first use, which is
  # precisely what keeps `copier update` from ever conflicting with it.
  if [[ -e "$out/GLOSSARY.project.md" ]]; then
    no "$lang does not ship GLOSSARY.project.md" "it was rendered, so copier update will fight over it"
  else
    ok "$lang does not ship GLOSSARY.project.md"
  fi

  # Every shipped script must be executable — CI invokes them by path.
  nonexec=""
  while IFS= read -r s; do
    [[ -x "$s" ]] || nonexec="$nonexec ${s#"$out"/}"
  done < <(find "$out" -name '*.sh' -type f)
  if [[ -z "$nonexec" ]]; then ok "$lang scripts are executable"
  else no "$lang scripts are executable" "$nonexec"; fi
done

# --------------------------------- the directory-name validator bites
# The name comes from the destination directory, so an invalid name means an
# invalid directory. It must fail at generation rather than produce a
# pyproject.toml that cannot build.
msg="$(render "$WORK/My App 2.0" python 2>&1)"
if [[ -f "$WORK/My App 2.0/pyproject.toml" ]]; then
  no "a directory name that breaks the package name is rejected" "it rendered anyway"
else
  ok "a directory name that breaks the package name is rejected"
  expect_contains "names the offending directory" "$msg" "cannot be a Python"
fi

# Dashes and underscores are both fine — find_best_mobo is the real case.
if render "$WORK/find_best_mobo" python >/dev/null 2>&1; then
  ok "an underscored directory name renders"
  if [[ -d "$WORK/find_best_mobo/src/find_best_mobo" ]]; then
    ok "package directory matches the project directory"
  else
    no "package directory matches the project directory" \
      "$(ls "$WORK/find_best_mobo/src" 2>/dev/null)"
  fi
  if grep -q '^name = "find_best_mobo"' "$WORK/find_best_mobo/pyproject.toml"; then
    ok "pyproject name matches the project directory"
  else
    no "pyproject name matches the project directory"
  fi
else
  no "an underscored directory name renders"
fi

msg="$(render "$WORK/bad-owner" python --data code_owner="grimsverk" 2>&1)"
if [[ -d "$WORK/bad-owner" ]]; then
  no "a code_owner without @ is rejected" "it rendered anyway"
else
  ok "a code_owner without @ is rejected"
fi

# ------------------- a long description must not overflow a linted line
# The description is free text and lands in files a linter measures. A
# 72-character description once produced a 112-column module docstring, and the
# generated project failed its own CI on the first push, before any code
# existed. Both languages are checked at their configured limits.
LONG="Find the very best AMD motherboard for any given CPU and budget by scraping live prices from a long list of local and international retailers every single night"

if render "$WORK/longdesc" python --data description="$LONG" >/dev/null 2>&1; then
  ok "python renders with a long description"
  worst="$(awk '{ print length }' "$WORK/longdesc/src/longdesc/__init__.py" | sort -rn | head -1)"
  if [[ "$worst" -le 100 ]]; then
    ok "module docstring stays inside ruff's 100 columns ($worst)"
  else
    no "module docstring stays inside ruff's 100 columns" "longest line: $worst"
  fi
  # And exactly one sentence-ending period, not the doubled '..' the template
  # used to emit when the description already ended in one.
  if grep -q '\.\.' "$WORK/longdesc/src/longdesc/__init__.py"; then
    no "no doubled period in the docstring"
  else
    ok "no doubled period in the docstring"
  fi
else
  no "python renders with a long description"
fi

if render "$WORK/swiftlong" swift-ios --data description="$LONG" >/dev/null 2>&1; then
  ok "swift renders with a long description"
  worst="$(awk '{ print length }' "$WORK/swiftlong/Sources/ContentView.swift" | sort -rn | head -1)"
  if [[ "$worst" -le 120 ]]; then
    ok "ContentView stays inside SwiftLint's 120 columns ($worst)"
  else
    no "ContentView stays inside SwiftLint's 120 columns" "longest line: $worst"
  fi
else
  no "swift renders with a long description"
fi

# A description that already ends in a period must not gain a second one.
if render "$WORK/dotdesc" python --data description="Already ends in a period." >/dev/null 2>&1; then
  if grep -q 'period\.$' "$WORK/dotdesc/src/dotdesc/__init__.py"; then
    ok "a description ending in '.' emits exactly one"
  else
    no "a description ending in '.' emits exactly one" \
      "$(grep period "$WORK/dotdesc/src/dotdesc/__init__.py")"
  fi
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

# A dashed name still renders and yields an importable package.
if render "$WORK/my-second-app" python >/dev/null 2>&1; then
  ok "a dashed directory name renders"
  pkg="$(find "$WORK/my-second-app/src" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)"
  if python3 -c "import sys; sys.exit(0 if sys.argv[1].isidentifier() else 1)" "$pkg"; then
    ok "package name '$pkg' is a valid Python identifier"
  else
    no "package name is a valid Python identifier" "got: $pkg"
  fi
else
  no "a dashed directory name renders"
fi

summary
