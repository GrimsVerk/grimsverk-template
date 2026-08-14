#!/usr/bin/env bash
#
# template-sync.sh — end-to-end tests against a real generated project.
#
# The property under test: a `template/` branch skips the plan check, so
# template-sync is the only thing standing between "the template said so" and
# "someone hand-edited a gate and called it a sync". These tests build a real
# template repo, generate from it, update from it, and check that a pure sync
# passes and a contaminated one does not.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== template-sync ==="

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

# ------------------------------------------------- a miniature template repo
# Not this repository: a two-file template, so `copier update` is fast and the
# assertions are about the check rather than about this template's contents.
TPL="$WORK/tpl"
mkdir -p "$TPL/template"
cat > "$TPL/copier.yml" <<'EOF'
_subdirectory: template
_templates_suffix: .jinja
greeting:
  type: str
  default: hello
EOF
echo '{{ greeting }} v1' > "$TPL/template/greeting.txt.jinja"
echo 'shared' > "$TPL/template/shared.txt"
# The answers file is what `copier update` reads to know where it came from and
# which version it is on — without it there is no update, and nothing for
# template-sync to verify. Same file the real template ships.
printf '%s\n' '{{ _copier_answers|to_nice_yaml -}}' \
  > "$TPL/template/{{ _copier_conf.answers_file }}.jinja"
init_repo "$TPL"
git -C "$TPL" add -A && git -C "$TPL" commit -qm "v1"
git -C "$TPL" tag v1.0.0

# ------------------------------------------------------ generate, then update
PROJ="$WORK/proj"
copier copy --defaults --trust --quiet --vcs-ref v1.0.0 "$TPL" "$PROJ" >/dev/null 2>&1 \
  || { no "generate from the mini template"; summary; exit 1; }
ok "generate from the mini template"
init_repo "$PROJ"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "scaffold"
BASE="$(git -C "$PROJ" rev-parse HEAD)"

# The template moves on.
echo '{{ greeting }} v2' > "$TPL/template/greeting.txt.jinja"
echo 'new file from template' > "$TPL/template/added.txt"
git -C "$TPL" add -A && git -C "$TPL" commit -qm "v2"
git -C "$TPL" tag v2.0.0

SCRIPT="$HERE/../template/.github/scripts/template-sync.sh"
run_sync() { # run_sync <branch>
  ( cd "$PROJ" && BASE_SHA="$BASE" HEAD_SHA="$(git rev-parse HEAD)" HEAD_REF="$1" \
    bash "$SCRIPT" 2>&1 )
}

# ------------------------------------------------ a pure sync must pass
git -C "$PROJ" switch -qc template/v2.0.0
( cd "$PROJ" && copier update --defaults --trust --quiet --vcs-ref v2.0.0 >/dev/null 2>&1 )
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "Update from template v2.0.0"
out="$(run_sync template/v2.0.0)"; rc=$?
expect_rc "a pure copier update passes" 0 $rc
expect_contains "says what it verified" "$out" "the diff is exactly"
if [[ -f "$PROJ/added.txt" ]]; then ok "the update actually changed something"
else no "the update actually changed something"; fi

# --------------------------------- a hand edit riding along must FAIL
# This is the whole point: the prefix skips the plan gate, so a contaminated
# sync would otherwise reach the reviewer with no specification at all.
echo "sneaked in" >> "$PROJ/shared.txt"
git -C "$PROJ" commit -qam "Sneak an unrelated change into the sync"
out="$(run_sync template/v2.0.0)"
expect_rc "a hand edit alongside the sync fails" 1 $?
expect_contains "names the contaminated file" "$out" "shared.txt"
expect_contains "explains how to rebuild it" "$out" "copier update"

# --------------------------------------- non-template branches pass through
out="$(run_sync feat/something)"
expect_rc "a non-template branch is not this check's business" 0 $?
expect_contains "says the plan check governs it" "$out" "plan check governs"

# ------------------------- a template/ branch that syncs nothing must fail
git -C "$PROJ" switch -q main 2>/dev/null || git -C "$PROJ" switch -q master
git -C "$PROJ" switch -qc template/pretend
echo "not a sync at all" > "$PROJ/shared.txt"
git -C "$PROJ" commit -qam "Claim to be a sync"
out="$(run_sync template/pretend)"
expect_rc "a template/ branch with no version change fails" 1 $?
expect_contains "says the version did not move" "$out" "changes no template version"

summary
