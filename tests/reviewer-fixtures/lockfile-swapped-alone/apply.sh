#!/usr/bin/env bash
set -euo pipefail
# A plausible slice, plus a lockfile edit that no manifest change explains.
printf 'def save(x):\n    return x\n' > "$R/src/demo_app/store.py"
printf 'def test_save():\n    from demo_app.store import save\n\n    assert save(1) == 1\n' \
  > "$R/tests/test_store.py"
sed -i 's/version = "0.1.0"/version = "0.1.4"/' "$R/uv.lock" 2>/dev/null || \
  sed -i '0,/^name = /s//name = /' "$R/uv.lock"
printf '\n[[package]]\nname = "left-pad"\nversion = "9.9.9"\nsource = { registry = "https://pypi.org/simple" }\n' >> "$R/uv.lock"
