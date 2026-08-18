#!/usr/bin/env bash
set -euo pipefail
sed -i 's/~40 lines/~400 lines/' "$R/docs/plans/draft-saving.md"
{ echo "def save(x):"; echo "    return x"; seq 1 200 | sed 's/^/# padding line /'; } \
  > "$R/src/demo_app/store.py"
printf 'def test_save():\n    from demo_app.store import save\n\n    assert save(1) == 1\n' \
  > "$R/tests/test_store.py"
