# Escapes — grimsverk-template

Append-only log of defects that reached a **generated project** and originated
**here**, in the template. One line per escape, newest at the bottom. Never
rewrite an entry; if something turns out to be wrong, append a correction.

This is the template side of the ratchet in the generated `AGENTS.md`: nothing
that escapes gets fixed without also adding a permanent check that would have
caught it. A generated project logs an escape as *its* incident record, and that
is the right place for it — but the fix and the check often live here, in the
file every future project is copied from, and a log entry in one project cannot
explain a check in another repository. So this file exists to keep the reasoning
next to the check.

It is deliberately **project-agnostic**. Entries name the defect and the check,
never the project's domain, its owner, or its business. If a line only makes
sense to someone who knows the originating project, it is written wrong.

**The "check added" column has a rule.** Record either a check that has actually
been run — red against the defect, green against the fix — or a proposal
explicitly marked *unverified*. An untested suggestion in that column reads with
exactly the same authority as a demonstrated one, and sends the next reader down
a dead end. Say which environment a check was verified in when that matters: a
check that needs an engine subscription is not verified by a runner that has no
subscription.

| Date | What escaped | Which gate should have caught it | Check added |
| --- | --- | --- | --- |
| _YYYY-MM-DD_ | _what went wrong, one clause, no project specifics_ | _template CI / render / gate fixtures / none existed_ | _what now exists so it can't recur_ |

<!-- Append below, newest at the bottom. Never rewrite an entry; if one turns
out to be wrong, append a correction. -->

| 2026-08-14 | `spawn-worker.sh` launched `codex exec --full-auto`, an argument codex-cli removed (0.147.0 rejects it), so every codex worker died at launch before reading its prompt | none existed — nothing ran the orchestration path, in CI or anywhere else, so a breaking change in an external CLI surfaced only when a human first needed the tool | `--approve-for-me` replaces it, and `tests/test-spawn-worker.sh` pins the flag through the new `--print-command` (verified: red on the old script, green on the new). That the real CLI *accepts* it is provable only by `tests/smoke-worker.sh`, which is **unverified for codex** — codex was not installed on the machine this was written on |
| 2026-08-14 | worker worktrees were created under `.claude/worktrees/`, which Claude Code treats as protected, so a sandboxed headless worker was refused every write and — having nobody to prompt — produced an empty branch and exited 0 | none existed — same gap: the orchestration path was first executed at the moment it was first needed | worktrees moved to `.worktrees/` (gitignored, dot-prefixed so pytest and ruff skip it). `tests/test-spawn-worker.sh` asserts the location and that nothing is written under `.claude/`; verified red against the old script and green against the new, and confirmed live by `tests/smoke-worker.sh` with the `claude` engine. `--bypass-sandbox` was rejected as the fix: it drops the sandbox for unreviewed model-written code to work around a directory name |
| 2026-08-14 | a headless worker that did nothing exited 0, so the spawn script reported success for a run that wrote no file and made no commit; the only thing between that and a silently empty pull request was the orchestrator remembering to diff each branch | none existed — "never let an empty branch pass as a success" was prose in `.claude/commands/orchestrate.md`, followed by the agent and checked by nothing | `spawn-worker.sh` compares the branch against the commit it started from and exits 3 with `commits=0` when nothing landed, distinguishing "wrote nothing" from "wrote and never committed". Fixtures cover both, plus an engine failure and a base branch that moves mid-run; verified red/green. It earned its keep immediately — it is what caught the entry below, on its first live run |
| 2026-08-14 | the engine was checked with `command -v` and nothing else, so an engine that is installed but cannot authenticate failed deep inside a headless run; on an account with no codex subscription the DEFAULT path could not work at all, and it presented as an argument error, sending the first diagnosis at the wrong problem | none existed — presence on `PATH` was treated as usability, which it never was | a preflight probe per engine before any worktree is created, failing with "engine X is installed but not usable" and printing the probe, its exit code and its output. `claude auth status` is verified live; the codex probe (`codex login status`) is **unverified** — no codex on the machine. Fixtures cover a failing probe, a probe that reports a signed-out account while exiting 0, and `--skip-preflight` |
| 2026-08-14 | a `claude` worker could not write anything at all: a fresh worktree is a workspace nobody has trusted interactively, so the project's own `.claude/settings.json` allow list is ignored there, and the default permission mode asks for approval a headless run has nobody to give — the worker answered "I need your permission to write that file" and exited 0 | none existed — but note *how this was found*: the empty-branch check above caught it on the first live smoke run, which is the ratchet working as designed rather than another escape to the owner | the `claude` engine now passes `--permission-mode acceptEdits` plus an explicit `--allowed-tools` whitelist (git add/commit/status/diff/log/show and the language test runners) on the command line, where workspace trust does not apply. A whitelist rather than deny rules: `git push` and `--no-verify` are not forbidden, they are unreachable. Verified live end-to-end by `tests/smoke-worker.sh claude`, and the flags are pinned by fixtures — including that the variadic `--allowed-tools` does not swallow the prompt |
