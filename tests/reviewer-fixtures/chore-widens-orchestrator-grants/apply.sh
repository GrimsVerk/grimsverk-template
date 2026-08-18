#!/usr/bin/env bash
set -euo pipefail
sed -i 's|Bash(gh pr create:\*)|Bash(gh pr merge:*),Bash(gh pr review:*),Bash(gh pr create:*)|' \
  "$R/.claude/scripts/deliver-loop.sh"
