#!/usr/bin/env bash
#
# retirement-suggestions.md — the file nothing reads.
#
# THE RULE, AND WHY IT IS A TEST RATHER THAN A SENTENCE. An agent may suggest
# that a requirement stop being required; only the owner may act on it. Two
# earlier designs got this wrong in two different directions, both by letting
# the suggestion reach the machinery:
#
#   - a landed oracle decision retired a requirement outright, so an agent
#     could remove work from the project;
#   - a suggestion EXCUSED the requirement from the coverage report, so an
#     agent could take work off its own list by declaring the work unnecessary.
#
# The fix is that no script and no other role reads the file at all. That is a
# property of the whole template rather than of any one script, so no single
# script's fixtures can hold it — and a rule written only in prose is a rule
# that rots. This is the check that keeps it true: if any script, workflow or
# command file ever starts reading that path, CI says so.
#
# The WRITER is exempt, and only the writer: the oracle appends to it, and the
# skeleton and the two ledgers it pairs with name it so a reader can follow the
# thread.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

T="$HERE/../template"
SUGGESTIONS="docs/oracle/retirement-suggestions.md"

echo "=== retirement-suggestions.md is read by nobody ==="

if [[ -f "$T/$SUGGESTIONS.jinja" ]]; then
  ok "the skeleton ships"
else no "the skeleton ships"; fi

# Every file in the template that mentions the path, minus the ones allowed to.
# Allowed: the file itself; the two documents it pairs with, which link it so a
# reader can follow the thread; and the oracle's command file, which is the
# writer.
ALLOWED_RE='^template/(docs/oracle/retirement-suggestions\.md\.jinja|docs/DESIGN\.oracle\.md\.jinja|docs/DESIGN\.oracle\.retired\.md\.jinja|\.claude/commands/oracle\.md)$'

mapfile -t MENTIONS < <(
  cd "$T/.." && grep -rl "retirement-suggestions" template/ 2>/dev/null | sort
)
OFFENDERS=()
for f in "${MENTIONS[@]}"; do
  [[ "$f" =~ $ALLOWED_RE ]] || OFFENDERS+=("$f")
done

if [[ ${#OFFENDERS[@]} -eq 0 ]]; then
  ok "no script, workflow or other role's prompt names the path"
else
  no "no script, workflow or other role's prompt names the path"
  printf '        reads it: %s\n' "${OFFENDERS[@]}"
fi

# The two gates that decide what work exists are named explicitly, because they
# are the two a future change would most plausibly wire it into: one reports the
# gaps, the other turns a gap into a dispatched planner.
for f in .github/scripts/coverage.sh .claude/scripts/deliver-phase.sh; do
  if grep -q "retirement-suggestions" "$T/$f" 2>/dev/null; then
    no "$f does not read the suggestions"
  else ok "$f does not read the suggestions"; fi
done

# And the writer really is the writer — a rule nothing implements is a rule
# nobody follows, so the oracle's own instructions have to carry it.
if grep -q "retirement-suggestions" "$T/.claude/commands/oracle.md"; then
  ok "the oracle is told where to write a suggestion"
else no "the oracle is told where to write a suggestion"; fi
if grep -qi "never rule one\|may never rule" "$T/.claude/commands/oracle.md"; then
  ok "and told it may never rule a retirement"
else no "and told it may never rule a retirement"; fi
if grep -qi "never be a reason to stop" "$T/.claude/commands/oracle.md"; then
  ok "and that a suggestion may never stop a run"
else no "and that a suggestion may never stop a run"; fi

# The owner's file carries the lock, and the lock is AUTHORSHIP rather than
# approval — approval is one click on a diff somebody else wrote at 3am.
if grep -q "DESIGN.oracle.retired.md" "$T/.github/workflows/ci.yml.jinja"; then
  ok "the retired ledger is named in CI"
else no "the retired ledger is named in CI"; fi
if grep -A3 'OWNED_DOCS=' "$T/.github/workflows/ci.yml.jinja" | grep -q "DESIGN.oracle.retired.md"; then
  ok "and it is the owner-authored check that guards it"
else no "and it is the owner-authored check that guards it"; fi

summary
