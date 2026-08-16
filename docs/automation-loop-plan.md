<!-- Status: IMPLEMENTED — the merged synthesis of this document's earlier draft
     and docs/plans/unattended-operation.md, built across six commits on this
     branch (skeletons 4f332e7, readiness+bootstrap af02227, App identity
     b471c0a, oracle wiring c58e19f, dual-mode driver 6f7d84a, lifecycle
     fixture 750ae85). Owner rulings recorded inside and shipped in
     template/docs/DECISIONS.md.jinja. Line references are to commit 44a686c
     and have drifted; the shipped files are now the source of truth.

     Still UNVERIFIED-LIVE, each flagged in its file's header, to observe on
     the first real project: a branch actually vanishing under the App token
     (closes ESC-21); REST ruleset creation before checks first report
     (setup-github.sh --verify is the fallback); budget-probe.sh against a
     real subscription (hard backstops hold either way); one live
     smoke-worker probe of the driver's session command lines; /deliver-loop
     web mode, once, watched. -->

# Unattended loop — merged plan (supersedes both drafts on the branch)

## Context

Two proposals now live on `claude/copier-template-automation-rii78u`: `docs/automation-loop-plan.md` (this session: driver mechanics, CODEOWNERS routing, evidence plumbing, bootstrap, skeletons) and `docs/plans/unattended-operation.md` (other agent: prove-it-live sequencing, rate limits, readiness check, identity, budget ceiling). They agree on diagnosis; each covers the other's biggest hole — theirs cannot merge a plan unattended (plan PRs still hit owner CODEOWNERS review), mine jams the oracle on uncertainties the vision never decided (its gate demands a verbatim VISION quote). This plan merges them and supersedes both; implementation updates both documents' status banners to point here.

### Owner rulings (all collected this session — record in the shipped `docs/DECISIONS.md` seed)

1. **Uncertainties, hybrid:** contract test — HIGH-risk if candidate answers change slice boundaries, Signatures blocks, external formats/schemas, or anything expensive to reverse; unsure ⇒ HIGH. High: pause, file `BL-<n>`, oracle rules before planning proceeds. Low: proceed on logged default, oracle reviews retroactively next cycle.
2. **Identity: GitHub App** for unattended runs (own rate-limit budget; its events fire workflows, so deletion works; agent PRs authored as `app[bot]`, making `owner-authored.sh` unambiguous). Bot + nightly sweep stays as the zero-setup fallback.
3. **Loop runtime: BOTH local and Claude Code web**, explicit choice when initializing a run.
4. **Budget ceiling:** measured as **percentage points of the owner's subscription rate limit** consumed by the run; hard stop, no degradation. (Secondary PR-count/time backstops retained since the probe is best-effort.)
5. **Readiness check refuses**, never warns. Scope: everything, minimal manual steps, security-justified exceptions only.

## Architecture resolutions (carried from the two drafts)

- **C1+theirs merged — uncertainty plumbing:** `/plan` files uncertainties as `BL-<n>` items in `docs/BACKLOG.md` (proposed default + risk class + one-line contract-test justification). The oracle rules them as `OD-<n>` citing the `BL-<n>` — with either a verbatim VISION quote **or** the new explicit *"no vision statement decided this"* value, which makes the alternatives-considered field **mandatory** (guessing allowed, guessing silently not). `oracle-decisions.sh` schema gains that value.
- **C2 — the driver is a scheduler, not an agent** (deterministic; the position `orchestration.md:51-54` blesses). One-layer rule intact: driver opens sessions; only orchestrator sessions spawn workers.
- **C3 — the driver is the commissioner** of oracle/steward runs via `spawn-worker.sh --role oracle|steward`; opens their PRs mechanically (push `worker/<id>` head to a `docs/`-prefixed branch, `gh pr create`).
- **C4 — unattended plans land on the un-owned `docs/plans/oracle/`** (`CODEOWNERS.jinja:52`); extend `oracle-decisions.sh` plan rule (`:239-250`): a plan there passes if it cites a landed `OD-<n>` **or** its `covers:` are requirement ids existing at base in either design doc. `docs/plans/` stays owner-owned for attended work.
- **C5 —** `orchestrate.md:39` phantom `--base docs/oracle-plans` → `--base main` + mechanical docs-prefixed push.
- **Template-vs-repository asymmetry (theirs):** files can't set repo settings, but `setup-github.sh` run under the owner's `gh` can *write* them and `unattended-ready.sh` *reads them back and refuses* before every unattended run. Both ship; the driver preflight calls the readiness check.

## Implementation phases (their sequencing: prove live → readiness → stops out → driver)

### Phase 0 — prove the merge cycle, on the App identity (ESC-21, their slices 1–2)

- `setup-github.sh` gains the App path: `--app` prompts for App ID + private-key file (created once by the owner in the GitHub UI — the one genuinely manual step; the script prints the exact creation URL and permissions list), stores `APP_ID`/`APP_PRIVATE_KEY` secrets, verifies installation on the repo.
- `template/.github/workflows/{% if auto_merge %}auto-merge.yml{% endif %}`: mint short-lived tokens via `actions/create-github-app-token` when App secrets exist, falling back to `AUTO_MERGE_TOKEN` then `GITHUB_TOKEN`+sweep. Add retry-with-backoff on `arm-auto-merge` reporting the reset time when it gives up (their slice 2).
- **Done when observed, not when it looks right:** one PR arms, merges, and its branch is seen to vanish with nobody touching it. Close ESC-21 against observation (correction row in `docs/escapes.md`).

### Phase 1 — skeletons + phantom guards + base fix

`template/docs/BACKLOG.md.jinja` (sections: Proposed / Approved / Uncertainties awaiting oracle ruling; id rule written only as `` `BL-<n>` `` — a literal id is phantom evidence, `oracle-decisions.sh:116-120` greps the whole file), `template/docs/DECISIONS.md.jinja` (ADR-lite header per `AGENTS.md.jinja:203-207`, seeded with the rulings ledger above), `template/docs/oracle/.gitkeep`, `template/docs/plans/oracle/.gitkeep`, `orchestrate.md:39` fix, `test-render.sh` extensions (skeletons present, no phantom `BL-`/`R1000`, no `docs/oracle-plans`).

### Phase 2 — readiness + append-only + bootstrap

- `template/.github/scripts/unattended-ready.sh` (their slice 3, **refuses**): auto-merge allowed on repo; ruleset present with required checks matching workflow job names; App installed (or `AUTO_MERGE_TOKEN` set and non-default); `CODEOWNERS` resolves to a real user; VISION complete; each failure names the setting and where to fix it. Driver preflight runs it; also a step in CI's `plan` job as advisory output (repo-settings drift is invisible to files otherwise).
- `template/.github/scripts/escapes-append-only.sh` (ESC-15): base rows byte-identical at HEAD, correction rows are appends; wired as a step in the existing `plan` CI job.
- `template/scripts/setup-github.sh`: idempotent; repo creation + SSH-alias remote; merge settings via `gh api PATCH` (auto-merge, delete-branch-on-merge); secrets via `read -rs` piped to `gh secret set` (never argv/logs); ruleset `grimsverk-gates` via REST (approvals 0 + code-owner review, contexts `plan`/`template-sync`/`secrets`/`test-the-tests`/`review`/+`checks`|`test`), PUT if existing; `--verify` runs the throwaway-PR dance. REST-before-first-report flagged unverified-live. Manual residue, security-justified only: App creation click-through, secret values typed by a human, `gh auth login`, Pro-vs-public choice.

### Phase 3 — the stops come out (oracle wiring, merged)

- `plan.md`: hybrid uncertainty gate per ruling 1 — classify by the contract test (unsure ⇒ HIGH); HIGH → file `BL-<n>` + stop ("plan pending oracle rulings"); LOW → record default + `BL-<n>` and proceed. Attended mode keeps the owner stop verbatim. Unattended plans to `docs/plans/oracle/<slug>.md`, slug unique tree-wide.
- `oracle.md`: uncertainty `BL`s in scope; the driver is a legitimate commissioner; new *no-vision* ruling class usage (alternatives mandatory); everything else unchanged.
- `oracle-decisions.sh`: the C4 covers-only alternative **and** the no-vision class with mandatory-alternatives enforcement; extend `tests/test-oracle-decisions.sh` both directions for both rules.
- `AGENTS.md.jinja`: "Mid-run authority" rule (plans only from the design layer; new work = oracle PR → plan PR → code; hybrid uncertainty rule; one-open-PR; owner steers via VISION/DESIGN, reviews at run end); the "stop for the owner's ruling" sentence scoped to attended mode only. `_TEMPLATE.md.jinja` Uncertainties section rewritten: record of rulings/defaults with risk class — a record, not a gate.
- `CODEOWNERS.jinja` comment update; `orchestration.md` new section "The unattended loop" (scheduler-not-agent, authority chain, phase machine, one-PR-in-flight).

### Phase 4 — the driver, dual-mode (ruling 3)

**Shared core, two frontends.** The phase logic lives once in `template/.claude/scripts/deliver-phase.sh` — read-only detection, prints `PHASE=<name>` + args; both frontends consume it, so local and web cannot drift.

Detection priority (each pass): preflight (once: `gh auth status`, engine probe, `unattended-ready.sh` refusal, DESIGN has R-ids else exit 2 — `/design` is owner work); owner-steer check (DESIGN/VISION SHA changed since run start → reset counters, re-derive); open pipeline PR → WAIT; unruled HIGH `BL`s → ORACLE; unprocessed ESC/BL evidence → ORACLE; unplanned handoff `OD`s → STEWARD; `coverage.sh` rc 1 → PLAN; rc 0 with unmerged plan slugs → ORCHESTRATE; all merged → ACCEPTANCE, write `run.md`, done.

- **Local frontend `template/.claude/scripts/deliver-loop.sh`:** bash loop over the core; WAIT = `gh pr checks <n> --watch --interval 30` under `timeout` (exit condition: nothing pending, never PR-closed); red → failure signature `sha1(headRef+sorted failing checks)`, same 3× → stop exit 3, else dispatch fix via orchestrate fix-mode; sessions via `spawn-worker.sh` (oracle/steward/plan) or `claude -p --permission-mode acceptEdits` with explicit `--allowed-tools` on the command line (orchestrate/acceptance); per-session `timeout` 60m default; state in gitignored `.claude/deliver-loop/`; refuses dirty tree / leftover `.worktrees/`. Exit codes 0/2/3/4/5 as drafted.
- **Web frontend `template/.claude/commands/deliver-loop.md`:** for a Claude Code web session — same core script, but WAIT is event-driven, never a blocking watch: after dispatching a phase and confirming its PR exists, subscribe to the PR's activity, schedule a fallback self check-in (~1h), and end the turn; on each wake, re-run `deliver-phase.sh` and dispatch. Notes: worker concurrency capped lower in containers (`SPAWN_MAX_WORKERS`, default 4 there); engine is `claude` (no codex in the container); session ephemerality means all state must be pushed, which the pipeline already guarantees.
- **Explicit mode choice at init** = which entry point you start: `deliver-loop.sh` in a terminal, or `/deliver-loop` in a web session. Both READMEs document the choice side by side; the command doc and script each state which mode they are.
- **Budget ceiling (ruling 4):** `template/.claude/scripts/budget-probe.sh` reads subscription utilization (session-window + weekly, in %); the driver records the value at run start and stops with exit 6 "budget spent" when the delta exceeds `--budget-points N` (default 25). Probe mechanism is best-effort against the CLI's usage surface — **flagged unverified-live**; PR-count (`--max-prs`, default 10) and wall-clock (`--max-hours`, default 8) remain as hard backstops so the ceiling exists even where the probe cannot read. Codex engine has no usage surface — documented limitation, backstops only.
- `deliver.md`: delete the OPEN QUESTION block (`:102-129`); step 4 = "waiting is mechanical and belongs to the driver; attended without it, stop at the PR and report" + retained exit-condition paragraph; step 0 names the two driver modes.
- ESC-16 (prose): `orchestrate.md` step 5 pre-PR self-review via `review.sh` when a credential is reachable, else written preflight. ESC-17 behavioral half: one-PR-in-flight is inherent to the driver; AGENTS.md states the rule. ESC-14: deferred (own entry already records the design).

### Phase 5 — lifecycle fixture (ESC-23, merged shape)

`tests/test-lifecycle.sh`, no live engine: render → skeleton assertions (OD citing `BL-1` against shipped skeleton fails) → design step (`owner-authored.sh` owner-pass/agent-fail) → plan step (gates green, `coverage.sh` rc 2→1→0) → feature step (blind-test trailer, `blind-tests.sh` clean) → oracle chain against fixtures (OD citing landed ESC passes; no-vision OD without alternatives fails; steward plan citing OD-1 passes / OD-99 fails; covers-only plan with real R passes / phantom R fails) → template-update seam (`update-from-template.sh --no-pr --ref HEAD`). Close ESC-23 with a correction row.

## Tests

`tests/test-deliver-loop.sh` (stub `gh`/`claude` shims; `--print-command` pins per phase — explicit grants, no `--dangerously-*`; phase selection per state; nothing-pending-never-PR-open red/green; 3-strike + signature reset; one-PR-in-flight; owner-edit re-derivation; budget backstops; dirty-tree refusal), `test-unattended-ready.sh` (each refusal path red/green against stubbed `gh api` responses), `test-setup-github.sh` (recorded argv+stdin; secrets never in argv; ruleset JSON; second-run PUT; App path), `test-escapes-append-only.sh`, extensions to `test-oracle-decisions.sh` and `test-render.sh` (incl. deliver.md has no "OPEN QUESTION"). All new scripts pass the existing shellcheck sweep (`--severity=warning`).

## Docs

Both existing plan docs get status-banner updates pointing at this merged plan. `deliver.md`, `plan.md`, `orchestrate.md`, `oracle.md`, `steward.md`, `orchestration.md`, `AGENTS.md.jinja`, `_TEMPLATE.md.jinja`, `CODEOWNERS.jinja` comment, `template/README.md.jinja` (running the loop, both modes, budget flags), repo `README.md` (setup collapses to `setup-github.sh`; build-loop table gains driver row; App-vs-fallback identity section), `template/.gitignore.jinja` (`.claude/deliver-loop/`), `docs/escapes.md` correction rows (ESC-15/21/23) once demonstrated.

## Landing order (independently green in template-ci)

1. Phase 1 (skeletons/guards/base fix). 2. Phase 2 (readiness + append-only + bootstrap incl. App path). 3. Phase 0's workflow changes (App token mint + backoff + sweep fallback) — file changes are testable in CI; the *live observation* happens on first real project and is flagged unverified until then. 4. Phase 3 (oracle wiring). 5. Phase 4 (driver, both frontends). 6. Phase 5 (lifecycle fixture). Push each to `claude/copier-template-automation-rii78u`.

## Verification

- `tests/run.sh` green (existing 13 + 5 new/extended); shellcheck sweep clean.
- `copier copy --vcs-ref=HEAD` both languages; python render passes its own checks.
- `deliver-loop.sh --print-command <phase>` for every phase (grants explicit, sandbox on); `--dry-run` in a rendered fixture walks preflight → plan → orchestrate → acceptance against stubbed `gh`.
- Flagged unverified-live, to verify on first real project: branch observed to vanish under the App token (closes ESC-21 for real); REST ruleset-before-first-report; `budget-probe.sh` against the real usage surface; one `smoke-worker.sh claude` probe of driver session command lines; `/deliver-loop` web mode once, watched.
