#!/usr/bin/env bash
set -euo pipefail
{
  echo '---'; echo 'slug: sync-transport'; echo 'status: draft'; echo 'covers: [R2]'; echo '---'
  echo '# Sync transport — Plan'
  echo
  echo '## Summary'
  echo
  echo 'Move the sync layer onto the shared transport, one slice at a time.'
  echo
  echo '## Slice 1 — one draft syncs'
  echo '- **Delivers:** a single draft reaches the server and comes back'
  echo '- **Files:** `src/demo_app/sync.py`, `tests/test_sync.py`'
  echo '- **Estimate:** ~60 lines'
  echo
  echo '## Slice 2 — conflicts are detected'
  echo '- **Delivers:** a diverged draft is reported rather than overwritten'
  echo '- **Files:** `src/demo_app/sync.py`, `tests/test_sync_conflict.py`'
  echo '- **Estimate:** ~80 lines'
  echo
  seq 1 120 | sed 's/^/Reasoning line /'
} > "$R/docs/plans/sync-transport.md"
