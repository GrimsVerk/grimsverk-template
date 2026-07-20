# Rule extraction report — PreLexy → grimsverk-template

Phase 1 deliverable of the rule-extraction pass. Every rule, convention, or
guardrail found in PreLexy (`CLAUDE.md`, `docs/DECISIONS.md`, `docs/BACKLOG.md`,
`docs/JOURNAL.md`, `docs/VERIFICATION.md`, `.claude/settings.json`,
`.claude/session-setup.sh`, `.github/workflows/tests.yml`, `README.md`,
`ROADMAP.md`, commit history) is listed below with its bucket and a one-line
justification. Ambiguous calls are marked **⚑ AMBIGUOUS** and gathered again in
the "Decisions needed" section at the end.

Buckets: **U** = universal → `AGENTS.md` · **L** = language-specific → scaffold
or CI config · **P** = project-specific → discarded (logged here).

> **Owner approval (2026-07-20):** D1 keep all three process rules · D2
> CI on push to all branches · D3 add the no-network conftest · D4 add the
> `.claude` deny list · D5 reviewer unchanged. Phase 2 applied accordingly;
> the appendix below is the draft as approved (the live file is
> `template/AGENTS.md.jinja`).

## Universal → AGENTS.md

| # | Rule (as found in PreLexy) | Generalized as | Justification |
|---|---|---|---|
| U1 | Work on branch `claude`, never push to or merge into `main` without explicit owner say-so (CLAUDE.md rule 1; settings.json denies `push origin main`) | Never commit to the default branch directly; work on a branch, the owner merges | Branch discipline applies to any repo an agent works in |
| U2 | Force pushes and `git reset --hard` denied (settings.json) | Never rewrite history on a pushed branch; no force pushes | Universal safety rule, independent of stack |
| U3 | Tests must pass before every commit (CLAUDE.md Commands) | Same, verbatim | The single most portable quality gate |
| U4 | One conceptually contained commit per unit of work, pushed after each; imperative one-line messages (CLAUDE.md Conventions; observed commit history) | Same | Commit hygiene is stack-independent |
| U5 | Docs move with code: README/ROADMAP/DESIGN updated in the same commit (CLAUDE.md) | Docs are updated in the same commit as the code they describe | Prevents doc drift in any project |
| U6 | Tests accompany code (CLAUDE.md) | New behaviour comes with tests in the same commit | Universal |
| U7 | The suite never touches the network; resource-dependent tests skip gracefully (CLAUDE.md; `no_network` autouse fixtures; sandbox/CI skip the spaCy-model test) | Tests run offline and deterministic; tests needing an unavailable optional resource skip, never fail | Portable principle; the *mechanism* is language-specific (see L2) |
| U8 | No new dependencies without asking (CLAUDE.md rule 4) | Same | Dependency creep control applies everywhere |
| U9 | Owner rulings in DECISIONS.md are never silently reversed; argue in chat and wait (CLAUDE.md rule 3; DECISIONS header: supersede, don't rewrite) | Recorded decisions are law until explicitly superseded; a new entry supersedes, history is never rewritten | Decision-log discipline is domain-independent |
| U10 | Every design choice or owner ruling gets a DECISIONS.md entry, newest at bottom (CLAUDE.md; DECISIONS 020/021) | Keep an ADR-lite `docs/DECISIONS.md`; create it on first decision | ⚑ AMBIGUOUS — universal working method vs. process overhead for tiny projects (see D1) |
| U11 | Autonomous sessions implement Approved backlog items only, top to bottom; new ideas go to Proposed as text, never coded straight away; Deferred is untouchable (CLAUDE.md rule 2; BACKLOG header; DECISIONS 020) | When working unattended, implement only owner-approved queue items; propose new ideas in writing, never code them unprompted | The agent-drift guardrail PreLexy was explicitly designed around; portable as-is |
| U12 | Keep going until the Approved list is done; don't stop unless truly blocked on the owner (CLAUDE.md Unattended) | Same, generalized to "the approved queue" | Universal unattended-work rule |
| U13 | Stuck rule: 3–5 failed attempts → stop, log what was tried, move on; simplest clearly-marked stand-in if the blocker gates everything (CLAUDE.md) | Same | Portable loop-breaker for any autonomous session |
| U14 | Rolling context capture: chat is not storage; anything a future session needs is written into the repo in the same work unit, routed to the file whose purpose fits (DECISIONS 021; CLAUDE.md routing table) | Same principle, with the generic routing (decisions → DECISIONS.md, work items → BACKLOG.md, session notes → JOURNAL.md, user-facing → README) | The repo-as-memory insight transfers to any agent-driven project |
| U15 | Every working session appends a dated JOURNAL.md entry: commits, discoveries, friction, hand-off notes (CLAUDE.md) | Same | ⚑ AMBIGUOUS — same process-weight question as U10 (see D1) |
| U16 | Verification ledger: a feature isn't "done" until verified where it needs to be; "CI added ≠ CI verified until a run passes"; ask for evidence rather than claiming verified (VERIFICATION.md header; JOURNAL 2026-07-06) | Never claim something is verified where you couldn't observe it; record what was verified where, and distinguish sandbox-verified from owner-verified | The honesty principle is fully portable; the dedicated ledger file is folded into the journal/decision routing rather than mandated (see D1) |
| U17 | Use blocking questions only when truly blocked; otherwise state what you need in chat and continue on best judgment (CLAUDE.md) | Same | Portable ambiguity-handling policy |
| U18 | CI runs the suite on every push (tests.yml `on: push`) | Every pushed commit gets CI | Universal; requires a small CI-trigger adjustment (see D2) |

## Language-specific → scaffold / CI

PreLexy predates the template's lint/type stack (it has no ruff/mypy config —
only cache dirs in `.gitignore`), so the language-specific harvest is thin.
No coverage floor exists in PreLexy; none is added.

| # | Rule | Destination | Justification |
|---|---|---|---|
| L1 | Python version pinned in one place (3.11 via environment.yml + CI) | Already satisfied: `requires-python`/`target-version` in the template's `pyproject.toml` | Single-source version pinning; template already does this with 3.12 |
| L2 | Tests physically cannot hit the network (`no_network` autouse monkeypatch fixtures per test module) | `tests/conftest.py` with one project-wide autouse fixture (python scaffold) | Enforces U7 mechanically for python. ⚑ AMBIGUOUS — adds one scaffold file (see D3) |
| L3 | pytest as the runner, quiet mode in CI (`pytest -q`) | Already satisfied: template CI runs `uv run pytest` | No change needed |
| L4 | Dependency install is reproducible from one committed file (environment.yml) | Already satisfied: `uv sync` from `pyproject.toml` | No change needed |

Nothing Swift-specific exists in PreLexy; the swift scaffold receives no new
rules. U-rules apply to it through `AGENTS.md` as with any language.

## Project-specific → discarded

| # | Rule | Why discarded |
|---|---|---|
| P1 | Entirely free and offline-first; no paid services; free APIs only as cached fallback (CLAUDE.md rule 4, DECISIONS 007) | PreLexy's product constraint, not a working rule. Its universal kernel (dependency control) survives as U8 |
| P2 | Keep the scheduler/similarity seams swappable; rarity never influences distractors; don't preclude tiers 2/3 (CLAUDE.md rule 5, DECISIONS 005/013) | Architecture rulings specific to PreLexy's design; the general obligation to respect recorded rulings survives as U9 |
| P3 | ALL SQL lives in store.py; diagnostics only through debug.py channels (CLAUDE.md) | Module-layout rules of one codebase |
| P4 | Sandbox facts: spaCy models undownloadable, kaikki.org 403-blocked, model-dependent test skips (CLAUDE.md, JOURNAL field notes) | Environment facts of one project's sandbox; the skip-gracefully kernel survives as U7 |
| P5 | Real-model verification on the owner's machine; ask for `--debug` transcripts; playtest transcripts in `docs/playtests/` (CLAUDE.md, VERIFICATION.md) | PreLexy's specific split of what's verifiable where; the kernel survives as U16 |
| P6 | Friction log: record every permission prompt/denial/classifier block (CLAUDE.md) | Data collection for tuning PreLexy's specific guardrail config; folded into the journal habit (U15) rather than kept as a standalone rule |
| P7 | Prefer separate commands over `&&` chains (matches the permission allowlist) (CLAUDE.md) | Vendor-specific (Claude Code permission classifier), and environment-specific even there; AGENTS.md must stay vendor-neutral |
| P8 | `.claude/settings.json` written by the owner, never by the agent (DECISIONS 020) | Vendor-specific; also generalizes poorly ("agents don't grant themselves permissions" is sensible but unenforceable as prose — noted in D4) |
| P9 | SessionStart setup script: idempotent, never fails the session (session-setup.sh) | Vendor-specific bootstrap for one sandbox; the template's `.claude/` layer already handles its own concerns |
| P10 | Sequential stages: finish v1 before v2 before v3 (BACKLOG/ROADMAP) | PreLexy's roadmap shape; the top-to-bottom queue discipline survives as U11/U12 |
| P11 | conda for the real env, pip for the sandbox (README/CLAUDE.md) | Superseded by the template's uv choice |
| P12 | Specific config-file/DB/XDG conventions, gloss chains, band values, etc. (DECISIONS *passim*) | Product design, not working rules |

## Decisions needed at the review checkpoint

- **D1 — How much process apparatus is universal?** (U10, U15, U16.) The
  DECISIONS/BACKLOG/JOURNAL working method is PreLexy's proven core, and it is
  genuinely domain-independent — but it is real overhead for a weekend project.
  The draft keeps all three as *rules referencing files created on first use*
  (no new skeleton files), phrased so an empty project pays nothing until the
  first decision/idea/session. Alternative: drop U10/U15 and keep only U16's
  honesty kernel. **Draft position: keep all three.**
- **D2 — CI trigger** (U18). The skeleton's CI runs on `push: branches: [main]`
  + `pull_request`. Under U1 the agent works on branches and may push many
  commits before any PR exists, so those pushes get no CI — but in PreLexy
  "tests green on every pushed commit" was the safety net that caught the
  broken-CI episode. Proposed enforcement adjustment: trigger on push to *all*
  branches (accepting duplicate runs once a PR is open, as PreLexy did).
  **Draft position: apply in Phase 2.**
- **D3 — No-network test fixture** (L2). Enforcing U7 for python means one new
  scaffold file (`tests/conftest.py`, ~10 lines, autouse fixture that fails any
  test opening a socket). It is a scaffold addition, though arguably "filling
  in" rather than "restructuring". No Swift equivalent is proposed.
  **Draft position: add it in Phase 2 if approved; otherwise U7 stays
  prose-only.**
- **D4 — Claude-layer mirrors of U1/U2.** PreLexy enforced branch discipline
  with `.claude/settings.json` deny rules (`push origin main`, `push --force`,
  `reset --hard`). The template's settings.json currently has hooks only.
  Mirroring the deny list there would enforce U1/U2 for Claude Code sessions
  without touching vendor-neutrality (the `.claude/` layer stays deletable).
  **Draft position: add the deny list in Phase 2.**
- **D5 — Reviewer subagent.** Per the brief, `.claude/agents/reviewer.md`
  already treats `AGENTS.md` as the source of truth and needs no rule text.
  The only candidate change is a one-line nudge to check U3–U6 (tests present,
  docs moved with code) explicitly. **Draft position: leave it unchanged** —
  it already says "check every changed hunk against each rule in AGENTS.md".

## Appendix — draft `template/AGENTS.md.jinja` (universal rules only)

```markdown
# {{ project_name }} — agent guidelines

Canonical working instructions for any coding agent in this repository.
Tool-specific entry points (e.g. `CLAUDE.md`) only point here; rules are
never duplicated elsewhere.

## Workflow

**Branches.** Never commit to the default branch directly; work on a branch
and let the owner merge. Never force-push or rewrite history on a branch
that has been pushed.

**Commits.** One conceptually contained commit per unit of work, pushed
when complete, with an imperative one-line message. The test suite must
pass before every commit. Documentation is updated in the same commit as
the code it describes — docs never lag the code.

**Tests.** New behaviour comes with tests in the same commit. The suite
runs offline and deterministically; a test that needs an unavailable
optional resource skips with a clear reason rather than failing.

**Dependencies.** No new dependencies without the owner's approval — ask
first, in chat.

**Decisions.** Design choices and owner rulings are recorded in
`docs/DECISIONS.md` (ADR-lite: one dated entry per decision, newest at the
bottom; create the file on the first decision). A recorded ruling is never
silently reversed — to change one, argue the case in chat, wait for the
owner, then add a superseding entry. History is never rewritten.

**Work queue.** When working unattended, implement only items the owner
has approved in `docs/BACKLOG.md` ("Approved" section, top to bottom), and
keep going until the list is done or you are truly blocked. New ideas are
written into "Proposed" as text — never coded unprompted. If an attempt is
stuck after 3–5 tries, log what was tried and why it failed, then move on;
if the blocker gates everything, build the simplest clearly-marked
stand-in and leave the real fix for the owner.

**Memory.** Chat is not storage. Anything a future session (or a different
agent) would need is written into the repository in the same unit of work:
decisions → `docs/DECISIONS.md`, work items and ideas → `docs/BACKLOG.md`,
session notes and hand-offs → `docs/JOURNAL.md` (one dated entry per
working session), user-facing behaviour → `README.md`.

**Honesty about verification.** Never claim something is verified in an
environment where you could not observe it. Record what was verified where;
"CI added" is not "CI verified" until a run has actually passed. When only
the owner can verify something, say exactly what to run and ask for the
output.

**Ambiguity.** Prefer stating what you need in chat and continuing on best
judgment over blocking; the owner reads chat. Stop and ask only when truly
blocked on something only the owner can provide.

## Enforcement

Pre-commit hooks (`.pre-commit-config.yaml`) and CI
(`.github/workflows/ci.yml`) enforce formatting, linting{% if language ==
'python' %}, typing{% endif %}, and the test suite on every commit and
push, regardless of which tool or agent wrote the code. A failing gate is
fixed, never bypassed: no `--no-verify`, no skipping or weakening checks
to get green.

## Language-specific

{% if language == 'python' -%}
Tool configuration in `pyproject.toml` is the source of truth for lint,
format, and typing rules — follow it, don't restate or override it. Run
the full gate locally with:

    uv run ruff check . && uv run ruff format --check . && uv run mypy && uv run pytest
{%- else -%}
`.swiftformat` and `.swiftlint.yml` are the source of truth for style —
follow them, don't restate or override them. `project.yml` is the source
of truth for the Xcode project; the `.xcodeproj` is generated
(`xcodegen generate`), never committed. Run tests with:

    xcodebuild test -project {{ app_name }}.xcodeproj -scheme {{ app_name }} -destination 'platform=iOS Simulator,name=iPhone 16'
{%- endif %}
```
