#!/usr/bin/env bash
#
# Orchestration smoke test — spawn ONE trivial worker per engine, against the
# real CLI, and assert it committed.
#
#   tests/smoke-worker.sh            # every engine that is installed
#   tests/smoke-worker.sh claude     # just one
#
# DELIBERATELY NOT PART OF tests/run.sh. The runner globs test-*.sh; this file
# is named differently so it is never swept into CI. It spends real subscription
# budget and needs an authenticated engine, neither of which belongs on every
# push.
#
# But it has to EXIST, and it has to be easy to run, because the orchestration
# path shipped with four independently fatal faults — a removed codex flag,
# worktrees under a directory Claude Code protects, an empty branch reported as
# a success, and an engine checked for presence but never for usability — and
# every one of them survived only because nothing ever exercised this path until
# a human needed it. tests/test-spawn-worker.sh pins the script's own logic with
# stub engines on every push; this is the half a stub cannot answer: does the
# real CLI accept what we pass it, and can it actually write in the worktree.
#
# Run it after changing spawn-worker.sh, and after any engine CLI upgrade.
#
# Requires: copier on PATH, and the engine you are testing signed in.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TEMPLATE="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ENGINES=("$@")
[[ ${#ENGINES[@]} -eq 0 ]] && ENGINES=(codex claude)

echo "=== orchestration smoke (real engines: ${ENGINES[*]}) ==="
echo "    This spends subscription budget — one short worker run per engine."

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

copier copy --defaults --trust --quiet --vcs-ref=HEAD \
  --data language=python \
  --data code_owner="@grimsverk" \
  "$TEMPLATE" "$WORK/smoke_app" >/dev/null 2>&1 \
  || { no "template renders"; summary; exit 1; }
ok "template renders"

R="$WORK/smoke_app"
init_repo "$R"
git -C "$R" add -A && git -C "$R" commit -qm "scaffold"

# Deliberately trivial: this is a test of the plumbing, not of the model. It
# still has to write a file and commit, which is exactly what the broken
# worktree location silently prevented.
PROMPT="Create a file named smoke.txt in the repository root containing exactly
the word ok. Then commit it with the message 'Add the smoke artifact'. Do not
change anything else, do not run the test suite, and do not open a pull request."

for engine in "${ENGINES[@]}"; do
  echo
  echo "--- engine: $engine"
  if ! command -v "$engine" >/dev/null 2>&1; then
    echo "  SKIP  $engine is not installed"
    continue
  fi

  id="smoke-$engine"
  out="$( cd "$R" && .claude/scripts/spawn-worker.sh \
    --id "$id" --engine "$engine" --base main --prompt "$PROMPT" 2>&1 )"
  rc=$?

  if [[ "$rc" -eq 2 && "$out" == *"is installed but not usable"* ]]; then
    echo "  SKIP  $engine is installed but cannot authenticate — preflight said so"
    echo "        (that is the preflight working; sign in to smoke-test this engine)"
    continue
  fi

  expect_rc "$engine: the worker run succeeds" 0 $rc
  expect_contains "$engine: the result line reports a commit" "$out" "commits=1"
  if git -C "$R" show "worker/$id:smoke.txt" >/dev/null 2>&1; then
    ok "$engine: the worker's file is committed on its branch"
  else
    no "$engine: the worker's file is committed on its branch" \
      "$(git -C "$R" log --oneline "main..worker/$id" 2>&1 | head -5)" \
      "log: $R/.claude/orchestration-logs/$id.log"
  fi

  git -C "$R" worktree remove --force ".worktrees/$id" 2>/dev/null || true
done

summary
