#!/usr/bin/env bash
#
# Run the template's own test suite.
#
#   tests/run.sh              # everything
#   tests/run.sh plan-parse   # just tests/test-plan-parse.sh
#
# Plain bash on purpose: this repository has no build system and does not need
# one to test seven shell scripts. Each test file is standalone and prints its
# own PASS/FAIL lines; this runner just sequences them and sums up.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -gt 0 ]]; then
  FILES=()
  for name in "$@"; do FILES+=("$HERE/test-${name#test-}.sh"); done
else
  mapfile -t FILES < <(find "$HERE" -maxdepth 1 -name 'test-*.sh' | sort)
fi

FAILED=()
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then echo "no such test file: $f" >&2; exit 2; fi
  echo
  bash "$f" || FAILED+=("$(basename "$f")")
done

echo
echo "==============================="
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "All test files passed."
  exit 0
fi
echo "FAILED: ${FAILED[*]}"
exit 1
