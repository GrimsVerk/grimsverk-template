<!-- Status: PROPOSED, pending owner review. Nothing described below is built.
     Written 2026-08-15 against 06e6635. Line references are to that commit. -->

# Close the automation loop in grimsverk-template

## Context

The owner's goal: after `copier copy`, a new project needs only **three required steps** — (1) run `/design`, (2) approve `docs/DESIGN.md` + `docs/VISION.md`, (3) review the finished system at the end. Everything in between runs unattended. The optional fourth activity is mid-run steering by editing the vision/design docs.

**How far the template already is:** it is a real Copier template with the full command chain (`/design → /plan → /orchestrate → /deliver`, plus `/oracle` and `/steward`), blind-parallel workers in worktrees, 13 mechanical CI gates, an LLM review gate, auto-merge on green, and the two-design-document architecture. Merges are already mechanical.

**Why the loop doesn't close today:** (1) no loop driver — `deliver.md:104-129` has an explicit OPEN QUESTION and says "stop at the PR and report"; (2) nothing ever spawns `/oracle`; (3) `/plan`'s uncertainty gate and plan-PR CODEOWNERS review block unattended runs; (4) `docs/BACKLOG.md`, `docs/DECISIONS.md`, `docs/oracle/`, `docs/plans/oracle/` are referenced everywhere but never shipped; (5) phantom `--base docs/oracle-plans` in `orchestrate.md:39`; (6) ~30 manual GitHub UI setup steps; (7) ESC-23: no e2e lifecycle fixture; (8) open escapes ESC-14/15/16/17.

**Owner rulings (this session):** local bash loop driver, mechanical waiting (no LLM budget spent watching CI); mid-run authority = the oracle (amends design layer via its own PR → plan PR → code; also rules `/plan` uncertainties); owner steers via VISION/DESIGN edits (owner-authored gate stays) and reviews at the end; scope = essentially everything, manual steps only with genuine security justification.

## Architecture resolutions (settled before any code)

- **C1 Uncertainties → oracle via the backlog.** `oracle-decisions.sh:195` requires every `OD-<n>` to cite `ESC-<n>`/`BL-<n>` evidence. So in unattended mode `/plan` appends each uncertainty as a `BL-<n>` item (with proposed default) to `docs/BACKLOG.md` on a small `docs/` branch; the oracle rules by appending `OD-<n>` entries citing those ids. The schema already forces the verbatim VISION quote, so every ruling is logged with its vision statement for free. Zero gate changes for this path.
- **C2 Loop driver is not an agent.** It's deterministic bash the owner starts and can watch — the position `orchestration.md:51-54` already blesses ("you know what is running, because you started both"). It doesn't violate the one-layer rule: the loop opens sessions; only the orchestrator session spawns workers.
- **C3 The loop is the commissioner.** It runs oracle/steward via `spawn-worker.sh --role oracle|steward` (roles exist, unused today) and opens their PRs mechanically. "Deciding and commissioning are separate" survives — the commissioner is now a scheduler, more separated, not less.
- **C4 Keep CODEOWNERS on `docs/plans/`; route unattended plans to the un-owned `docs/plans/oracle/`** (`CODEOWNERS.jinja:52`). Extend `oracle-decisions.sh` (plan rule at `:239-250`) with one alternative: a plan there passes if it cites a landed `OD-<n>` **or** its `covers:` consists solely of requirement ids existing at the base commit in either design doc (both owner-controlled). `plan-resolve.sh`/`coverage.sh`/`plan-lint.sh` already traverse the subdirectory — no changes there.
- **C5 Phantom branch fix.** Stewards branch off the default branch; the commissioner pushes the finished worker branch under a `docs/`-prefixed name (`git push origin worker/<id>:docs/oracle-plan-<slug>`) before `gh pr create`, so the plan gate's docs-diff exemption applies.

## Implementation

### 1. Loop driver — `template/.claude/scripts/deliver-loop.sh`

Plain bash, owner-run: `deliver-loop.sh [--max-iterations N] [--print-command <phase>] [--dry-run]`. Follows `spawn-worker.sh` conventions (self-documenting header, `--print-command` for CI pinning, env overrides, distinct exit codes). State recomputed from the world each iteration (`git pull --ff-only` first); only persistent state is gitignored `.claude/deliver-loop/` (failure signatures, processed evidence ids, run-start DESIGN/VISION SHAs, per-phase logs + `run.md` report).

Phase detection per iteration, priority order:
1. **Preflight** (once): `gh auth status`; engine preflight (reuse spawn-worker probe semantics); DESIGN exists with R-ids (`coverage.sh` rc 2 → exit 2, "/design is interactive and owner-landed — the loop cannot do it"); VISION has no empty section.
2. **Owner steer check:** DESIGN/VISION SHA changed since run start → log, reset failure counters, re-derive (steering lever working, not an error).
3. **Open pipeline PR?** → wait mechanically: `gh pr checks <n> --watch --interval 30` under `timeout` (exit condition: nothing pending — never "PR closed"). Green-but-unmerged (owner-owned PR, e.g. acceptance) → report + exit 4 (or long-poll with `--wait-for-owner`). Red → failure signature `sha1(headRef + sorted failing checks)`; same signature 3× → stop, exit 3 (codifies `deliver.md:157-160`); else dispatch a headless orchestrate session in fix-dispatch mode. This also implements ESC-17 behaviorally: never dispatch while a pipeline PR is open — one PR in flight.
4. **Unruled uncertainties** (`BL-<n>` in the uncertainties section not cited by any `OD-<n>`) → oracle phase.
5. **Unprocessed evidence** (ESC/BL ids cited nowhere, not in processed set) → oracle phase; record "no contradiction" ids as processed so the loop can't thrash.
6. **Unplanned oracle decisions** (handoff `OD-<n>` with no plan citing it) → steward phase, one `spawn-worker.sh --role steward` per decision, mechanical PR per C5.
7. **Coverage:** `coverage.sh` rc 1 → plan phase (next §12 milestone); rc 0 → any planned-but-unmerged slug (via `gh pr list --state merged`) → orchestrate phase; all built → acceptance phase, write `run.md`, exit 0.

Session invocation: oracle/steward/plan phases via `spawn-worker.sh` (unattended milestone plans written to `docs/plans/oracle/<slug>.md`, already covered by the steward grant `Write(docs/plans/oracle/**)` at `spawn-worker.sh:212`). Orchestrate/acceptance phases run `claude -p --permission-mode acceptEdits` with explicit command-line `--allowed-tools` (never settings.json — the ESC-5 workspace-trust lesson). Every session under `timeout` (default 60 min, env-tunable). Caps: `MAX_ITERATIONS` (default 20), 3-strike stop, refuse dirty tree / leftover `.worktrees/`. Exit codes: 0 done, 2 setup, 3 repeated failure, 4 blocked on owner, 5 iteration cap.

**Resolve the OPEN QUESTION:** delete `deliver.md:102-129`; rewrite step 4 — "waiting is mechanical and belongs to the loop driver (`gh pr checks --watch`); attended without the driver, stop at the PR and report" — keeping the exit-condition paragraph. Record the ruling as the seed entry of the shipped `docs/DECISIONS.md` (satisfies `deliver.md:122` in every project at once).

### 2. Oracle wiring

- `plan.md`: unattended branch of the uncertainty gate — append uncertainties as `BL-<n>` + proposed default, commit alone on a `docs/` branch, stop; on re-invoke after rulings, record each `OD-<n>` + vision quote in the plan and continue; never self-answer. Unattended plans go to `docs/plans/oracle/`, slug unique tree-wide.
- `oracle.md`: uncertainty BL items are in scope; the loop is a legitimate commissioner; all constraints (spawn-nothing, append-only, evidence) unchanged.
- `oracle-decisions.sh`: the C4 covers-only alternative for `docs/plans/oracle/` plans (reuse the `covers:` awk from `coverage.sh:165-169`, id extraction per `coverage.sh:90-110` against base-commit content).
- `orchestrate.md:39`: `--base main` + a sentence on the mechanical docs-prefixed push.
- Chain documentation: normative section in `orchestration.md` ("The unattended loop": scheduler-not-agent, phase machine, design→plan→code authority chain, one-PR-in-flight) + one-paragraph rule in `AGENTS.md.jinja` (so the review gate enforces it) + user-facing summaries in both READMEs. No new doc file.

### 3. Missing skeletons

- `template/docs/BACKLOG.md.jinja`: sections `## Proposed`, `## Approved`, `## Uncertainties awaiting oracle ruling`; id rule written as `` `BL-<n> ``` — **never a literal example id** (`oracle-decisions.sh:116-120` greps the whole file for `BL-[0-9]+`; a literal `BL-1` is phantom evidence on day one); "never delete an id an OD cites."
- `template/docs/DECISIONS.md.jinja`: ADR-lite header per `AGENTS.md.jinja:203-207`, seeded with the waiting-strategy ruling.
- `template/docs/oracle/.gitkeep`, `template/docs/plans/oracle/.gitkeep`.

### 4. GitHub bootstrap — `template/scripts/setup-github.sh`

Idempotent, next to `update-from-template.sh`; reads `language` from `.copier-answers.yml`. Steps: preflight (`gh auth status`, jq); repo creation + SSH-alias remote rewrite + first push + `gh run watch`; merge settings via `gh api -X PATCH` (auto-merge, delete-branch-on-merge); secrets (`read -rs` piped straight to `gh secret set` — value never hits argv or logs; skip if present); ruleset `grimsverk-gates` via REST (approvals 0 + code-owner review, required contexts `plan`/`template-sync`/`secrets`/`test-the-tests`/`review`/+`checks`|`test`, no linear history) — the REST API accepts context strings before any check reports (the "must report once" constraint is UI-only; mark **unverified live** in the header), with `--verify` mode running the README's throwaway-PR dance to prove every context reports; detect existing ruleset and PUT.

**Stays manual (security justification each):** typing the three secret values (script must never fetch/persist credentials; `claude setup-token` is interactive OAuth); minting the fine-grained PATs (no API; deliberate human credential decision); `gh auth login` browser grant; the Pro-vs-public choice.

### 5. E2E lifecycle fixture (ESC-23) — `tests/test-lifecycle.sh`

Swept by `tests/run.sh` glob. No live engine — walks the artifact sequence and asserts each seam: render + init; skeletons present, no phantom `BL-`/`R1000` ids, an OD citing `BL-1` against the shipped skeleton fails; design step (owner-authored passes as owner, fails as agent); plan step (resolve/parse/lint/vision-complete green; `coverage.sh` walks rc 2→1→0); feature step (blind-test trailer, resolves, `blind-tests.sh` clean); oracle seam (OD citing landed ESC passes; steward plan citing OD-1 passes, OD-99 fails; covers-only plan with base-existing R1 passes, undefined R7 fails); template-update seam (`update-from-template.sh --no-pr --ref HEAD`, "already up to date" path).

### 6. Smaller escapes

- **ESC-15 include:** new `template/.github/scripts/escapes-append-only.sh` (base rows byte-identical at HEAD; correction rows are appends), wired as a step in the existing `plan` CI job.
- **ESC-16 include (prose):** `orchestrate.md` step 5 — run `review.sh` against your own diff pre-PR if a credential is reachable, else a written preflight.
- **ESC-17:** behavioral half ships in the loop (one PR in flight) + AGENTS.md rule; mechanical CI gate deferred.
- **ESC-14 defer:** orthogonal, subtle, already designed in its entry.

### 7. Documentation edits

`deliver.md` (step 4 rewrite), `plan.md`, `orchestrate.md`, `oracle.md`, `steward.md`, `orchestration.md` (new unattended-loop section + intro fix at :16-20), `AGENTS.md.jinja` (mid-run authority rule, append-only escapes note, one-open-PR rule), `CODEOWNERS.jinja` comment, `template/README.md.jinja` (running the loop), repo `README.md` (setup collapse to `setup-github.sh` + build-loop table row + uncertainty→BL→OD path), `template/.gitignore.jinja` (`.claude/deliver-loop/`), repo `docs/escapes.md` correction rows for ESC-15/23 once demonstrated.

### 8. Tests

- `tests/test-deliver-loop.sh`: stub `gh`/`claude` shims on PATH (pattern from `test-spawn-worker.sh`); pin `--print-command` per phase (command-line grants, no `--dangerously-*`); phase selection per coverage rc; dirty-tree refusal; waits on nothing-pending never PR-open (red/green variant); 3-strike stop + reset on new signature; one-PR-in-flight; owner-edit re-derivation; iteration cap.
- `tests/test-setup-github.sh`: stub `gh` recording argv+stdin; ruleset JSON assertions; secrets reach stdin and appear in no argv/log; second run PUTs.
- `tests/test-escapes-append-only.sh`; extend `tests/test-oracle-decisions.sh` (covers-only rule both directions) and `tests/test-render.sh` (skeletons, no phantom ids, no "OPEN QUESTION", no `docs/oracle-plans`, ESC-16 wording).
- New scripts must pass the existing shellcheck sweep (`--severity=warning`).

### 9. Landing order (independently green commits/PRs on this branch)

1. Skeletons + phantom guards + `orchestrate.md:39` base fix + render-test extensions.
2. ESC-15 append-only check + test + escapes correction row.
3. Oracle wiring: gate extension + plan/oracle/steward unattended edits + AGENTS.md rule + CODEOWNERS comment + orchestration.md chain + test extensions.
4. Loop driver + deliver.md rewrite + DECISIONS seed + gitignore + ESC-16/17 text + `test-deliver-loop.sh` + unattended-loop doc section.
5. Bootstrap script + both README rewrites + its test.
6. Lifecycle fixture + ESC-23 correction row.

Then push to `claude/copier-template-automation-rii78u`.

## Verification

- `tests/run.sh` locally (all 13 existing + 4 new/extended files green).
- `shellcheck --severity=warning` over all new/edited scripts.
- Render both languages with `copier copy --vcs-ref=HEAD` and confirm the python render still passes its own ruff/mypy/pytest (mirrors template-ci's render matrix).
- `deliver-loop.sh --print-command <phase>` for every phase: inspect assembled command lines (grants explicit, sandbox on).
- `deliver-loop.sh --dry-run` in a rendered fixture repo: phase detection walks preflight → plan → orchestrate → acceptance against stubbed `gh`.
- Flagged unverified-live (honesty rule, verify on first real use): ruleset-creation-before-checks-report via REST; one live `smoke-worker.sh claude` probe of the loop's session command lines.
