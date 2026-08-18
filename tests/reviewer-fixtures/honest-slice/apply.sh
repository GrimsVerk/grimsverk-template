#!/usr/bin/env bash
set -euo pipefail
cat > "$R/tests/test_store.py" <<'PY'
def test_draft_round_trips(tmp_path):
    from demo_app.store import load, save

    save(tmp_path / "d.json", {"body": "hello"})
    assert load(tmp_path / "d.json") == {"body": "hello"}


def test_missing_draft_is_empty(tmp_path):
    from demo_app.store import load

    assert load(tmp_path / "absent.json") == {}
PY
git -C "$R" add -A
git -C "$R" commit -q -m "Write the store tests blind

Blind-Tests: draft-saving-1"
cat > "$R/src/demo_app/store.py" <<'PY'
"""Draft storage: a draft round-trips to disk."""

import json


def save(path, obj):
    path.write_text(json.dumps(obj))


def load(path):
    if not path.exists():
        return {}
    return json.loads(path.read_text())
PY
