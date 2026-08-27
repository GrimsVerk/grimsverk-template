#!/usr/bin/env bash
#
# design-refs.sh — do the owner documents point at things that exist?
# Report-only, always exit 0 (ESC-222's setup-time half).
#
# The find_best_mobo experiment was run in good faith against an honestly
# written design — and the design still referenced data no commit contained.
# Nothing told anyone which of its nouns were real, so the discovery happened
# at 3am, one unattended session per phantom, each one spawning rulings that
# exist only to declare reconstructions. This lint is the daylight version:
# it runs in the preflight banner (unattended-ready.sh), while the owner is
# awake to fix or mark the reference, and it never blocks — these are the
# OWNER'S documents, and a gate that red-flags the owner's prose is a gate
# that gets deleted.
#
# What counts as a reference, deliberately narrow so the report stays
# readable: a BACKTICKED token that looks like a repository path — it
# contains a `/`, or ends in a code/data file extension. Prose words, URLs,
# flags, and placeholder tokens (`<slug>`, globs, `$vars`) are not
# references. A line carrying the marker `(to be created)` is exempt: that
# is the documented way to reference a thing on purpose before it exists.
#
# Usage: design-refs.sh   (from anywhere inside the repository)
# Optional env: DESIGN_REF_DOCS — space-separated list overriding the default
#               docs/DESIGN.md docs/VISION.md docs/BACKLOG.md

set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "design-refs: not inside a git repository" >&2; exit 0; }
cd "$ROOT" || exit 0

DOCS="${DESIGN_REF_DOCS:-docs/DESIGN.md docs/VISION.md docs/BACKLOG.md}"

UNRESOLVED=0
for doc in $DOCS; do
  [[ -f "$doc" ]] || continue
  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    # Strip a trailing slash so a directory reference checks the directory.
    checked="${token%/}"
    if [[ ! -e "$checked" ]]; then
      if [[ "$UNRESOLVED" -eq 0 ]]; then
        echo "design-refs: references that resolve to nothing in this tree —"
        echo "  each one is a session-burning surprise waiting for a 3am worker."
        echo "  Fix the reference, create the file, or mark the line '(to be created)'."
      fi
      UNRESOLVED=$((UNRESOLVED + 1))
      printf '  %s: `%s`\n' "$doc" "$token"
    fi
  done < <(awk '
    # A line that says "(to be created)" references its things on purpose.
    /\(to be created\)/ { next }
    {
      line = $0
      while (match(line, /`[^`]+`/)) {
        tok = substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
        # Not a path: spaces, placeholders, globs, variables, URLs, options.
        if (tok ~ /[ <>*$\\]/) continue
        if (tok ~ /:\/\//) continue
        if (tok ~ /^-/) continue
        # A path: has a directory separator, or a recognisable file extension.
        if (tok ~ /\// || tok ~ /\.(sh|py|md|csv|json|jsonl|yml|yaml|txt|toml)$/)
          print tok
      }
    }' "$doc" | sort -u)
done

if [[ "$UNRESOLVED" -eq 0 ]]; then
  echo "design-refs: every backticked path in the owner documents resolves."
else
  echo "design-refs: $UNRESOLVED unresolved reference(s) — reported, never red (the documents are the owner's)."
fi
exit 0
