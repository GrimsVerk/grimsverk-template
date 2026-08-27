#!/usr/bin/env bash
#
# count-rulings.sh — how many oracle decisions this run added.
#
# Prints exactly one line: `oracle-rulings: <n>`, where n is the count of
# `## OD-<n>` decision headings in docs/DESIGN.oracle.md now (working tree)
# minus the count at <base-ref>, clamped at zero. The design hardening loop
# (docs/design-flow.md) exists to shrink this number; a claim like that is
# only evaluable against a recorded trend, so the delivery driver appends this
# line to every run report. A missing document counts as zero on either side —
# a project that opted out of the oracle reports 0, never an error.
#
# Usage:  count-rulings.sh <base-ref>
# Exit:   0 always, except 2 when the base ref argument is missing.

set -euo pipefail

usage() { echo "usage: count-rulings.sh <base-ref>" >&2; }

[[ $# -eq 1 && -n "$1" ]] || { usage; exit 2; }
BASE_REF="$1"

ROOT="$(git rev-parse --show-toplevel)"
DOC="docs/DESIGN.oracle.md"

count_now=0
if [[ -f "$ROOT/$DOC" ]]; then
  count_now="$(grep -cE '^## OD-[0-9]+' "$ROOT/$DOC" || true)"
fi

count_base=0
if base_body="$(git -C "$ROOT" show "$BASE_REF:$DOC" 2>/dev/null)"; then
  count_base="$(grep -cE '^## OD-[0-9]+' <<<"$base_body" || true)"
fi

n=$((count_now - count_base))
[[ "$n" -lt 0 ]] && n=0

echo "oracle-rulings: $n"
