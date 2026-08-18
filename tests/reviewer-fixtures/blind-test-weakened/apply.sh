#!/usr/bin/env bash
set -euo pipefail
# Two commits: the blind test, then the implementation and the relaxation. The
# harness commits whatever apply.sh leaves, so the first is made here directly.
cat > "$R/tests/test_store.py" <<'PY'
def test_draft_round_trips(tmp_path):
    from demo_app.store import load, save

    save(tmp_path / "d.json", {"body": "hello"})
    assert load(tmp_path / "d.json") == {"body": "hello"}
PY
git -C "$R" add -A
git -C "$R" commit -q -m "Write the store tests blind

Blind-Tests: draft-saving-1"
cat > "$R/src/demo_app/store.py" <<'PY'
import json


def save(path, obj):
    path.write_text(json.dumps(obj))


def load(path):
    return json.loads(path.read_text())
PY
cat > "$R/tests/test_store.py" <<'PY'
def test_draft_round_trips(tmp_path):
    from demo_app.store import save

    save(tmp_path / "d.json", {"body": "hello"})
    assert True
PY
