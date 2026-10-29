#!/usr/bin/env bash
# Render both project types from the working tree and check them: no stray
# Jinja, the expected files, a one-screen AGENTS.md, the Python project's own
# checks, and actionlint on the generated workflows (if actionlint is on PATH).
#
#   tests/test-render.sh [output-dir]    # default: a temp dir, removed after
#
# Needs copier and uv.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${1:-}" ]]; then
  OUT="$1"; mkdir -p "$OUT"
else
  OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
fi

fail=0
ok() { echo "  ok    $1"; }
no() { echo "  FAIL  $1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | head -40; fail=1; }
check() { # check <label> <command...>
  local label="$1" log; shift
  if log="$("$@" 2>&1)"; then ok "$label"; else no "$label" "$log"; fi
}

for lang in python swift-ios; do
  echo "=== $lang"
  dir="$OUT/demo-${lang%%-*}"
  rm -rf "$dir"
  # --vcs-ref=HEAD: render the working tree (uncommitted changes included),
  # not the latest tag.
  check "renders" copier copy --defaults --trust --quiet --vcs-ref=HEAD \
    --data language="$lang" --data description="Render test." "$ROOT" "$dir"
  [[ -d "$dir" ]] || continue

  # GitHub's ${{ }} expressions are not Jinja; strip them before looking.
  stray="$(grep -rlE '\{\{|\{%' "$dir" | while read -r f; do
    perl -pe 's/\$\{\{.*?\}\}//g' "$f" | grep -qE '\{\{|\{%' && echo "$f"; done)"
  if [[ -z "$stray" ]]; then ok "no unrendered Jinja"; else no "no unrendered Jinja" "$stray"; fi

  for f in AGENTS.md CLAUDE.md README.md next-steps.md docs/VISION.md docs/DESIGN.md \
           docs/DECISIONS.md docs/BACKLOG.md .claude/agents/test-writer.md \
           .claude/commands/orchestrate.md .claude/commands/adversarial-review.md \
           .github/workflows/ci.yml scripts/setup-github.sh scripts/update-from-template.sh; do
    [[ -f "$dir/$f" ]] || no "has $f"
  done
  nightly="$dir/.github/workflows/nightly.yml"
  if [[ "$lang" == swift-ios ]]; then [[ -f "$nightly" ]] || no "has nightly.yml"
  else [[ ! -e "$nightly" ]] || no "python has no nightly.yml"; fi

  lines="$(wc -l < "$dir/AGENTS.md")"
  if (( lines <= 60 )); then ok "AGENTS.md fits one screen ($lines lines)"
  else no "AGENTS.md fits one screen ($lines lines)"; fi

  check "settings.json is valid JSON" python3 -m json.tool "$dir/.claude/settings.json"

  if command -v actionlint >/dev/null; then
    check "actionlint" actionlint "$dir"/.github/workflows/*.yml
  else
    echo "  skip  actionlint (not on PATH)"
  fi

  if [[ "$lang" == python ]]; then
    check "uv sync" uv sync --project "$dir" --quiet
    (
      cd "$dir" || exit 1
      check "ruff check" uv run ruff check .
      check "ruff format" uv run ruff format --check .
      check "mypy" uv run mypy
      check "pytest" uv run pytest -q
      exit "$fail"
    ) || fail=1
  fi
done

if (( fail )); then echo "FAILED"; exit 1; fi
echo "all ok"
