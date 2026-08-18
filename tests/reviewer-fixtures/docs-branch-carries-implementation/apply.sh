#!/usr/bin/env bash
set -euo pipefail
printf '\nA clarifying sentence about the project.\n' >> "$R/README.md"
cat > "$R/src/demo_app/retry.py" <<'PY'
"""Retry helper."""

import time


def retry(fn, attempts=3, backoff=0.5):
    last = None
    for i in range(attempts):
        try:
            return fn()
        except Exception as exc:  # noqa: BLE001
            last = exc
            time.sleep(backoff * (2**i))
    raise last


def retry_forever(fn, backoff=0.5):
    i = 0
    while True:
        try:
            return fn()
        except Exception:  # noqa: BLE001
            time.sleep(backoff * (2**i))
            i += 1


def _jitter(x):
    return x * 1.1


def _cap(x, hi=30.0):
    return min(x, hi)


def _floor(x, lo=0.1):
    return max(x, lo)
PY
