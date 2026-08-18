#!/usr/bin/env bash
set -euo pipefail
cat > "$R/src/demo_app/store.py" <<'PY'
import json


def save(path, obj):
    path.write_text(json.dumps(obj))


def load(path):
    return json.loads(path.read_text())


def merge(a, b):
    out = dict(a)
    for k, v in b.items():
        out[k] = v if k not in out else out[k]
    return out
PY
