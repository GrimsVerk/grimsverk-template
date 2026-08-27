---
slug: grounding-and-evidence
status: merged
created: 2026-08-27
design: docs/DESIGN.md §5 R4/R9/R11 — decisions cite reality, evidence survives, ledgers hold; Stage 2 of docs/postmortem-2026-08-20-plan.md
covers: [R4, R9, R11]
---

# Grounding and evidence — decisions bind to things that exist, and nothing built is lost

## Summary

Stage 2 of the post-mortem prevention plan. Four changes.

- **A decision declares what it binds to, and the gate resolves it.** A new
  optional `- **Binds:**` field lists the paths a decision fastens a
  requirement to; each entry must exist at the base commit or be written
  `ordered: <path>` (the artifact-ordered closure state, which is steward
  work). Path-like strings outside the field produce a warning, never a
  failure — a described artifact ("the measured 52-variant set") cannot be
  detected mechanically, so the prompt (`oracle.md`) carries the
  declaration duty and the gate verifies what is declared (ESC-222).
- **The owner's documents get the same look, report-only, before the first
  dispatch.** `design-refs.sh` lists path-like references in
  `docs/DESIGN.md`, `docs/VISION.md` and the seed backlog that resolve to
  nothing, and `unattended-ready.sh` prints the report in its preflight
  banner — the owner learns about phantom referents while awake; nothing
  blocks (ESC-222).
- **A merge into a non-default base is tagged.** `mechanical_pr`'s merge
  bookkeeping tags the merge commit `evidence/<base>/pr-<n>` when the run
  base is not the default branch, and pushes the tag — the class of loss
  that erased a merged feature slice cannot recur silently (ESC-223).
- **Run evidence is append-only like every other ledger.**
  `runs-append-only.sh` fails a pull request that edits or deletes a file
  already landed under `docs/runs/`; new files append freely. Corrections
  are new files that cite the old (ESC-223's post-hoc-edit half).
- **Costs:** one new gate script wired beside the other append-only checks;
  one new preflight line; tags accumulate on non-default bases (V8 accepts
  the space).

## Uncertainties

No uncertainties — every decision derives from
`docs/postmortem-2026-08-20-plan.md` (landed, W2 and W4) and the rulings
recorded there. The warning-not-failure line for undeclared referents is the
plan's own recorded decision, not a new one.

## Slice 1 — the Binds field and its gate *(covers R4; ESC-222)*

- **Delivers:** a decision whose `Binds:` entry names a path absent at the
  base commit fails `oracle-decisions.sh` with the artifact-ordered escape
  named in the message; `ordered: <path>` passes and marks the decision
  OPEN until a plan cites it; existing decisions without the field still
  pass; `oracle.md` instructs the declaration.
- **Files:** `template/.github/scripts/oracle-decisions.sh`,
  `template/.claude/commands/oracle.md`, `tests/test-oracle-decisions.sh`
- **Estimate:** ~110 lines

## Slice 2 — the owner-document referent report *(covers R4; ESC-222)*

- **Delivers:** `design-refs.sh` prints every path-like reference in the
  owner documents that resolves to nothing in the tree, exits 0 always;
  `unattended-ready.sh` shows the report in the preflight banner.
- **Files:** `template/.github/scripts/design-refs.sh`,
  `template/.github/scripts/unattended-ready.sh`,
  `tests/test-design-refs.sh`, `tests/test-unattended-ready.sh`
- **Estimate:** ~120 lines

## Slice 3 — merges into non-default bases are tagged *(covers R9; ESC-223)*

- **Delivers:** after a merge into a non-default run base, an
  `evidence/<base>/pr-<n>` tag exists on the remote pointing at the merge
  commit; the default-branch path is untouched; the driver's log names the
  tag.
- **Files:** `template/.claude/scripts/deliver-loop.sh`,
  `tests/test-deliver-loop.sh`
- **Estimate:** ~60 lines

## Slice 4 — run evidence cannot be rewritten *(covers R9, R11; ESC-223)*

- **Delivers:** a pull request modifying or deleting a landed file under
  `docs/runs/` fails `runs-append-only.sh`; adding new files passes; the
  check is wired into CI beside the other append-only gates.
- **Files:** `template/.github/scripts/runs-append-only.sh`,
  `template/.github/workflows/ci.yml.jinja`, `.github/workflows/template-ci.yml`,
  `tests/test-runs-append-only.sh`
- **Estimate:** ~110 lines
