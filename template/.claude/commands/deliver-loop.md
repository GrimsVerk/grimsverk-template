---
description: Drive unattended delivery from a Claude Code web session, event-driven
---

You are the **delivery driver's web-session frontend**. The other frontend is
`.claude/scripts/deliver-loop.sh`, run in a terminal; the owner chooses a mode
by choosing which one to start. Both consume the same phase detector —
`.claude/scripts/deliver-phase.sh` — which is what keeps the modes from
drifting. You add nothing to its judgment: you dispatch what it says and you
wait the way a web session waits.

**How a web session waits — and how it must not.** The local driver blocks on
`gh pr checks --watch`, which is free there. In a hosted session, holding a
turn open to watch CI burns the session's lifetime on information that has not
changed. So waiting here is **event-driven**: after confirming a pull request
is open, subscribe to that PR's activity, schedule a fallback check-in about
an hour out (events are best-effort, not guaranteed), and **end the turn**.
The wake — an event or the check-in — re-enters this loop: run the detector
again, act on what it says now. Never poll in a loop inside a turn; never
sleep to wait for CI.

## Each turn (first, and on every wake)

1. **Preflight, first turn only:** `gh auth status`;
   `.github/scripts/unattended-ready.sh` — a refusal ends the run, report it
   verbatim; `coverage.sh` rc 2 likewise (the design is the owner's to land,
   `/design` cannot be run for them). Note the run-start SHAs of
   `docs/DESIGN.md` and `docs/VISION.md`, the start time, and a PR counter in
   your working notes.
2. **Sync and steer-check:** pull the default branch. If either steering
   document's SHA changed since run start, say so, reset your failure memory,
   and re-derive — that is the owner steering, not an error.
3. **Budget:** stop and report when the run exceeds its allowance —
   `budget-probe.sh` delta when the probe works, and always the hard
   backstops (default 10 PRs / 8 hours / 20 iterations, or what the owner
   said when starting the run). Stopping is the behaviour; degrading quietly
   is not.
4. **Detect:** run `.claude/scripts/deliver-phase.sh` and act on its PHASE:
   - **WAIT** — subscribe to the PR's activity, schedule the ~1h fallback
     check-in, end the turn. On waking to a red check: compute the failure
     signature (head ref + sorted failing check names); the same signature a
     third time ends the run as a pattern (exit posture 3 below); otherwise
     fix on the existing branch and push — never a second pull request. On
     waking to a merge: continue to step 4 again. Green but unmerged after a
     grace period means an owner-owned path: report and end the run unless
     told to keep polling.
   - **ORACLE / STEWARD / PLAN** — dispatch one worker via
     `.claude/scripts/spawn-worker.sh --role <role> --engine claude --base
     <default branch>` with the matching command file as its prompt plus the
     UNATTENDED addendum and the detector's scope; then push the worker
     branch under a `docs/`-prefixed name and open the pull request
     mechanically (`git push origin worker/<id>:docs/<ref>` — the worker
     branch is neither docs-exempt nor slug-resolvable). Then you are in
     WAIT.
   - **ORCHESTRATE** — run `/orchestrate <slug>` in this session. It opens
     the feature's pull request and stops; then you are in WAIT.
   - **ACCEPTANCE** — run `/deliver` step 6 only; land `docs/acceptance.md`
     on a docs/ branch, open the pull request. When the detector says
     ACCEPTANCE again with nothing open, write the final report and end the
     run: requirements covered, criteria passed/failed/pending-on-owner with
     evidence, escapes logged, and the pending list as the honest bottom
     line.
   - **SETUP** — report the reason and end the run.

## Container realities

- **Worker fan-out is capped lower here:** hosted containers have fewer cores
  and less disk than a desktop — set `SPAWN_MAX_WORKERS=4` unless the owner
  says otherwise (orchestration.md's 12 is a desktop number).
- **The engine is `claude`.** No codex CLI is present in hosted containers.
- **Nothing local survives.** The container is reclaimed between wakes with
  the session's context intact but the disk not guaranteed — which costs
  nothing, because the pipeline already pushes every artifact: plans, ledger
  appends, handoffs, and code all live on branches and pull requests. Keep
  run bookkeeping (start SHAs, PR count, failure signatures) in your session
  notes, not in files.

## What never changes between the two frontends

One pipeline pull request in flight; the design layer rules (AGENTS.md,
"Mid-run authority"); every stop says why it stopped; the exit condition on a
pull request is **no check still pending**, never "the PR is no longer open" —
red never closes a pull request, so that condition reads failure as success.

Scope, if the owner named one (otherwise: the whole design):

$ARGUMENTS
