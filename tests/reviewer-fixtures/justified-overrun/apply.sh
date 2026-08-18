#!/usr/bin/env bash
set -euo pipefail
cat > "$R/tests/test_store.py" <<'PY'
import json

import pytest


def test_draft_round_trips(tmp_path):
    from demo_app.store import load, save

    save(tmp_path / "d.json", {"body": "hello"})
    assert load(tmp_path / "d.json") == {"body": "hello"}


def test_missing_draft_is_empty(tmp_path):
    from demo_app.store import load

    assert load(tmp_path / "absent.json") == {}


def test_corrupt_draft_raises_a_useful_error(tmp_path):
    from demo_app.store import DraftCorrupt, load

    p = tmp_path / "d.json"
    p.write_text("{not json")
    with pytest.raises(DraftCorrupt) as exc:
        load(p)
    assert "d.json" in str(exc.value)


def test_save_is_atomic(tmp_path):
    from demo_app.store import save

    p = tmp_path / "d.json"
    save(p, {"body": "one"})
    save(p, {"body": "two"})
    assert json.loads(p.read_text()) == {"body": "two"}
    assert not list(tmp_path.glob("*.tmp"))
PY
git -C "$R" add -A
git -C "$R" commit -q -m "Write the store tests blind

Blind-Tests: draft-saving-1"
cat > "$R/src/demo_app/store.py" <<'PY'
"""Draft storage: a draft round-trips to disk.

Writes go through a temporary file and an atomic rename, so a crash mid-write
leaves the previous draft intact rather than a truncated one. That is the whole
reason this slice is longer than its estimate: a draft store that can lose the
draft on a bad day is not a draft store.
"""

import json
import os
import tempfile


class DraftCorrupt(Exception):
    """The file exists and is not a draft."""


def save(path, obj):
    directory = os.path.dirname(str(path)) or "."
    fd, tmp = tempfile.mkstemp(dir=directory, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(obj, fh)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def load(path):
    if not path.exists():
        return {}
    raw = path.read_text()
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise DraftCorrupt(f"{path} is not a readable draft: {exc}") from exc
PY
