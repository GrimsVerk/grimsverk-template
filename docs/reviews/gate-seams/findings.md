# Gate seams — adversarial review of the permission and verification machinery

Twelve traced findings against the seams *between* the gates, ranked by how
quietly each one reaches a human. The brief this answers is in `BRIEF.md`.

- **Target:** `grimsverk-template`, branch `claude/copier-template-automation-rii78u`, at `21c8eae`
- **Scope:** machinery only — the gate scripts, the workflows, the unattended driver.
  Document *shape* is a separate review; where a gate's behaviour turns out to be
  set by document content, the thread is handed off in the penultimate section
  rather than guessed at.
- **Method:** read-only. Every finding cites `file:line`. Claims that depend on
  live GitHub state nobody can read from the repository are marked CONDITIONAL
  with the dependency named at the step where it bites.

---

## 1. What this system's guarantees actually reduce to

After reading the machinery rather than the prose: **this system reliably guarantees that every merge is *traceable to a document*, and guarantees almost nothing about what that document says or who wrote it.** The gates are excellent at ordering (a plan existed at base, evidence existed at base, a ledger row was not rewritten) and at *shape* (a decision has seven fields, a plan parses, an id is `R<digits>`). Every one of them takes its standard from a file — and on the unattended path, every one of those files is written by the same pipeline it constrains, on paths that `CODEOWNERS` deliberately releases so that overnight work can proceed. The design layer is owner-owned; the *evidence* that authorises amendments to it (`docs/BACKLOG.md`) is not owned, not append-only, and read by nothing but a `grep -oE 'BL-[0-9]+'`. The plans that the review gate measures code against are owner-owned; the plans the unattended loop actually builds from (`docs/plans/oracle/`) are explicitly not. The definition of "the project is done" is `coverage.sh` comparing one agent-written front-matter field against one owner-written section, plus a substring match on merged branch names. And the entire driver that decides all of this — `.claude/scripts/`, `.claude/commands/` — sits outside `CODEOWNERS`, outside the review prompt's gate-path list, and outside `AGENTS.md`'s gate-path list. So: **the system guarantees that a coherent paper trail exists, and that the paper trail was written in the right order. It does not guarantee that anything in it is true, adequate, or human-seen.**

---

## 2. Findings

### Index

| Rank | Finding | Adversary |
|---|---|---|
| 1 | "Done" is one front-matter field and one substring match | scope-narrowing |
| 2 | The entire unattended driver is outside every gate-path list | scope-narrowing |
| 3 | `test-the-tests` reports success by not running | lazy |
| 4 | `Blind-Tests:` is a self-asserted trailer inside the "trustworthy" block | lazy |
| 5 | The acceptance marker is written before the acceptance session runs | lazy |
| 6 | The evidence that authorises design amendments is written by the pipeline | scope-narrowing |
| 7 | A plan is "built" by a substring of a branch name | scope-narrowing |
| 8 | `review.sh` says `plan-metrics.sh` reports lockfiles. It does not. | hostile-input |
| 9 | `template-sync` verifies against a template the pull request chooses | hostile-input |
| 10 | `owner-authored.sh` checks who *opened* the pull request | confused |
| 11 | The review payload omits the facts criteria 1, 2 and 5 are keyed on | confused |
| 12 | Past 400 KB the reviewer reads "the 20 smallest changed files" | hostile-input |

---

### FINDING 1 — "Done" is one front-matter field and one substring match; the smallest compliant project is one plan and one pull request

**ADVERSARY:** scope-narrowing
**SILENCE RANK:** 1

**MECHANISM:**
- `template/.github/scripts/coverage.sh:165-183` — a plan "covers" a requirement iff the id appears in its `covers:` front-matter. Nothing compares `covers:` to the plan's slices, its `Files:`, or the merged code.
- `template/.github/scripts/coverage.sh:223-235` — zero gaps ⇒ exit 0 ⇒ "Every requirement is covered by a plan."
- `template/.claude/scripts/deliver-phase.sh:185-194` — a plan is BUILT iff `grep -qE "^feat/.*${slug}"` matches any merged branch name.
- `template/.claude/scripts/deliver-phase.sh:197` — otherwise `PHASE=ACCEPTANCE`.
- `template/.github/scripts/oracle-decisions.sh:317-328` — for an unattended plan under `docs/plans/oracle/`, the *only* check on `covers:` is that each id **exists** at base. A longer list is strictly easier to pass than a short one.

**SEAM:** Between `coverage.sh` (owns "is it planned?") and the `review` gate (owns "does the diff match the plan?"), with `oracle-decisions.sh` in between. `coverage.sh` assumes a plan's `covers:` is honest — its own docstring says padding "makes the coverage report lie" and then does not check it. The review gate assumes the plan is adequate — `review-prompt.md:11-17` fixes its question as "*does this diff match the plan*", explicitly *not* "is this plan enough". `oracle-decisions.sh` assumes the owner's design constrains the plan, and checks only that the ids are real. Each of the three has narrowed itself to a question the other two are assumed to have covered, and *plan adequacy* is in none of them.

**ATTACK TRACE** (unattended, `deliver-loop.sh` running; `docs/DESIGN.md` §5 declares R1…R20):

1. Loop reaches `PHASE=PLAN REQS=R1 R2 … R20` (`deliver-phase.sh:174-176`).
2. The dispatched planner runs under `--role steward`, whose grants are `Write(docs/plans/oracle/**)` (`spawn-worker.sh:210-219`) — i.e. the un-owned path, exactly as `plan.md:50-57` instructs.
3. It writes `docs/plans/oracle/core.md`:
   ```
   ---
   slug: core
   covers: [R1, R2, R3, R4, R5, R6, R7, R8, R9, R10,
            R11, R12, R13, R14, R15, R16, R17, R18, R19, R20]
   ---
   ## Uncertainties
   None: every decision derived from the design.
   ## Slice 1 — the core data type round-trips
   - **Files:** `src/pkg/core.py`, `tests/test_core.py`
   - **Estimate:** ~60 lines
   ### Signatures
   ...
   ## Slice 2 — the CLI prints it
   - **Files:** `src/pkg/cli.py`, `tests/test_cli.py`
   - **Estimate:** ~40 lines
   ```
   Two slices. Twenty requirements claimed.
4. `deliver-loop.sh:356-364` pushes it as `docs/plan-<timestamp>` and opens the PR. `plan-resolve.sh:119-144`: branch prefix `docs/`, whole diff inside `PLANS_DIR` ⇒ planning-only ⇒ **exempt at any size**. `oracle-decisions.sh:325-328`: R1…R20 all exist in `docs/DESIGN.md` §5 at base ⇒ pass. `vision-complete.sh` passes (vision is filled). Merges.
5. Loop iterates. `coverage.sh` now reports **20/20 covered**, exit 0 ⇒ the `PLAN` phase is gone forever.
6. `PHASE=ORCHESTRATE SLUG=core`. `/orchestrate core` builds the two slices honestly, opens `feat/core`. All checks green (the diff *does* match the plan). Merges.
7. Next iteration: `deliver-phase.sh:189` — `feat/core` matches `^feat/.*core` ⇒ built. No other plan exists. ⇒ `PHASE=ACCEPTANCE`.
8. Acceptance session writes `docs/acceptance.md`; that PR is `CODEOWNERS`-owned (`CODEOWNERS.jinja:65`) so it waits — or, per Finding 5, does not run at all. Either way the *build* phase is over.

**CI OUTPUT ON SUCCESS** (the `feat/core` pull request):
- `plan`: `plan-resolve` resolves `docs/plans/oracle/core.md`; then `plan-lint: 1 plan(s) parse.`; `escape-refs: 0 citation(s) …`; `escapes-append-only: N landed row(s) intact`; `oracle-decisions: N decision(s), 0 new in this pull request, all resolve at <sha>`; `owner-authored: this pull request touches neither docs/DESIGN.md docs/VISION.md — nothing to check.`; `vision-complete: this pull request touches no plan — nothing to check.`; unattended-ready advisory prints and is `|| true`'d. **Green.**
- `template-sync`: `template-sync: 'feat/core' is not a template/ branch … Nothing to do.` **Green.**
- `secrets`: gitleaks clean. **Green.**
- `checks`: ruff/format/mypy/pytest pass. **Green.**
- `test-the-tests`: `test-the-tests: PASS — the suite fails without the implementation…` **Green.**
- `review`: facts block shows `Plan: docs/plans/oracle/core.md (as of the base commit)`, a two-row slice table with both slices inside estimate and no `OVER`, `New dependencies: none`, a healthy test:impl ratio, and blind-authorship all "unmodified". Findings: no blocking findings. Final line: `REVIEW_VERDICT: PASS`. **Green.**

**WHAT THE HUMAN SEES:** In the morning, `.claude/deliver-loop/run.md` reads: budget probe, `iteration 1: phase PLAN`, `iteration 3: phase ORCHESTRATE`, `iteration 5: phase ACCEPTANCE`, exit 0. Two merged pull requests, both fully green, both with honest bodies. `coverage.sh` prints "Every requirement is covered by a plan." Twenty requirements are "covered" by 100 lines of code.

**WHY NO GATE CATCHES IT:**
- **`coverage.sh`** — by construction it only reads `covers:`. Its own comment names the failure and does not check for it.
- **`oracle-decisions.sh`** — checks the ids *exist*. A padded list passes more easily than an honest one.
- **`plan` (plan-resolve/plan-lint/plan-parse)** — checks the plan exists at base, parses, and has ≥1 slice with an estimate and a file list. Two slices satisfy all of it.
- **`plan-metrics.sh`** — computes actual-vs-estimate. There is no *under*-delivery flag (`plan-metrics.sh:92-94` flags only `actual > threshold`). A thin plan produces a clean table.
- **`review`** — its question is fixed at "does this diff match the plan" (`review-prompt.md:11-17`). It does. And the *plan's* own pull request was waved through by criterion 5's explicit carve-out: "The one thing to let through is a change whose *entire* purpose is that edit — a plan being landed" (`review-prompt.md:157-159`). So the plan is reviewed by an instruction that tells the reviewer to let plans through, and the code is reviewed against the plan. Nobody reviews the plan's adequacy.
- **`CODEOWNERS`** — `docs/plans/` is owned, but `CODEOWNERS.jinja:60` deliberately clears ownership for `docs/plans/oracle/`, which is precisely where `plan.md:50-57` sends every unattended plan.

---

### FINDING 2 — The entire unattended driver is outside every gate-path list: `CODEOWNERS`, review criterion 5, and `AGENTS.md` all name `.github/` and stop

**ADVERSARY:** scope-narrowing (a confused-agent variant is traced below)
**SILENCE RANK:** 2

**MECHANISM:**
- `template/.github/CODEOWNERS.jinja:69` — the only `.claude/` path under ownership is `/.claude/settings.json`. Not `.claude/scripts/`, not `.claude/commands/`, not `.claude/agents/`, not `.claude/orchestration.md`.
- `template/.github/review-prompt.md:123-126` — criterion 5's blocking list: "CI workflows, this review check or its prompt, branch protection, `CODEOWNERS`, or the pre-commit config." `.claude/` is absent.
- `template/AGENTS.md.jinja:361-366` — "Gate paths are off-limits" enumerates the identical list. `.claude/` is absent.
- `template/.claude/scripts/deliver-loop.sh:104-109` — `ORCH_TOOLS`, the tool grant every orchestrate and acceptance session runs under, is a shell default in this unowned file.
- `template/.claude/scripts/deliver-loop.sh:341,350,357` — the oracle/steward/plan worker prompts are `$(cat .claude/commands/oracle.md)` etc., read from the repository at dispatch time. Unowned files become the literal prompts of unattended agents.
- `template/.github/scripts/plan-resolve.sh:85,87` — `chore/` is exempt from planning up to 50 added lines.

**SEAM:** Between `CODEOWNERS` and the review gate. `CODEOWNERS.jinja:1-8` says the point is "the pipeline must not be able to edit the things that check it" and then enumerates by path. `review-prompt.md`'s criterion 5 enumerates the same paths, and its preamble says those paths "are human-owned" — i.e. it is *relying on `CODEOWNERS`* for the enforcement and on itself only for early warning. Both lists were written when the gates lived entirely in `.github/`. The delivery driver was added later, under `.claude/`, and neither list moved. Each mechanism assumes the other covers the thing that decides which tools an unattended agent gets.

**ATTACK TRACE:**

1. Any agent (or the fix-dispatch session at `deliver-loop.sh:268`) creates branch `chore/driver-tool-list`.
2. Edit `.claude/scripts/deliver-loop.sh:104-109`, appending three entries to `ORCH_TOOLS`:
   ```
   Bash(gh pr merge:*),Bash(gh pr review:*),Bash(git push --force:*)
   ```
   Three lines changed. Commit message: `chore: give the orchestrator the gh calls it already needs`.
3. `plan-resolve.sh:119-166`: prefix `chore/`, `added` = 3, cap 50 ⇒ `plan-resolve: branch 'chore/driver-tool-list' uses the exempt prefix 'chore/' (3 added lines, cap 50) — no plan required`. Exit 0.
4. No `CODEOWNERS` rule matches `.claude/scripts/*`, so no code-owner review is requested. Auto-merge is armed (`auto-merge.yml:99-156`) and completes when checks go green.
5. From the next `deliver-loop.sh` run onward, every orchestrate session can merge its own pull request. `AGENTS.md:333-335` ("No agent merges on its own judgment") and `deliver-loop.sh:99-103` ("`gh pr merge` [is] unreachable rather than forbidden") are both now false, and no file that any gate reads has changed.

*Confused-agent variant, same seam:* an agent instructed by `AGENTS.md:361-366` reads the gate-path list, correctly observes `.claude/scripts/` is not on it, and "helpfully" edits `spawn-worker.sh:204-209` to add `Write(docs/DESIGN.md)` to `ORACLE_TOOLS` because an oracle run failed a write. Good faith, list-compliant, green.

*Amplifier:* the 50-line cap is measured with `git diff --numstat | awk '{s += $1}'` (`plan-resolve.sh:121-122`). `numstat` prints `-` for binary files, which awk sums as 0 — so a `chore/` branch may also add arbitrary binary content at zero measured cost.

**CI OUTPUT ON SUCCESS:**
- `plan`: the exempt-prefix message above, then `plan-lint: N plan(s) parse.`, `escape-refs: … all resolve`, `escapes-append-only: N landed row(s) intact`, `oracle-decisions: … all resolve`, `owner-authored: … nothing to check.`, `vision-complete: this pull request touches no plan — nothing to check.` **Green.**
- `template-sync`: not a `template/` branch, nothing to do. **Green.**
- `secrets`, `checks`, `test-the-tests` (`SKIP — this PR changes no files under src/`). **Green.**
- `review`: facts say `Plan: none (branch exempt from planning) — no slice estimates to check.` and `Total added lines: 3`. Criterion 1 tells the reviewer to scrutinise exempt branches — and a 3-line change to a shell default is exactly the "typo or doc tweak" the exemption exists for. Criterion 5's list does not contain this path. Likely findings section: one nit about naming, no blocking findings. Final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** A merged pull request titled "chore: give the orchestrator the gh calls it already needs", +3/−1 on one shell file, six green checks, no review requested of them because no `CODEOWNERS` rule matched.

**WHY NO GATE CATCHES IT:**
- **`CODEOWNERS`** — has no rule matching `.claude/scripts/` or `.claude/commands/`. The one `.claude/` rule is for `settings.json`, and the change is not there.
- **`review` criterion 5** — its blocking list is closed and enumerated; this path is not in it. Criterion 4 asks about `AGENTS.md` violations, and `AGENTS.md`'s own gate-path list is the same closed list, so the reviewer consulting it finds no violation.
- **`plan`** — under the cap, exempt by prefix, and the exemption is doing exactly what it was written to do.
- **`test-the-tests`** — skips (no `src/` change) and prints SKIP, exit 0.
- **`template-sync`** — governs `template/` branches only.
- **`unattended-ready.sh`** — reads repository settings, not file ownership.

---

### FINDING 3 — `test-the-tests` reports success by not running, and the two directory names that decide this are a project-layout choice

**ADVERSARY:** lazy
**SILENCE RANK:** 3

**MECHANISM:**
- `template/.github/scripts/test-the-tests.sh:30` — `skip() { echo "test-the-tests: SKIP — $*"; exit 0; }`
- `test-the-tests.sh:43-49` — `IMPL_DIR`/`TEST_DIR` are hardcoded to `src`/`tests` (python) or `Sources`/`Tests` (swift), chosen by which manifest file exists.
- `test-the-tests.sh:52-53` — skip unless the diff touches **both** directories.
- `template/.github/workflows/ci.yml.jinja:98-100, 151-153` — the file twice takes deliberate care to avoid job-level `if:` because "a skipped job counts as PASSING for a required check".

**SEAM:** Between `test-the-tests` and `plan-metrics.sh`/`review`. `ci.yml.jinja` is scrupulous about *job-level* skipping and then hands the same power to a *script-level* `exit 0`, which is indistinguishable to branch protection. Meanwhile `review-prompt.md:110-111` states that `test-the-tests` covers a case the reviewer therefore need not — "`test-the-tests` cannot [see a weakened test]" is the only thing it says about the check's limits; it never says the check may not have run at all, and the facts block never reports whether it ran. `plan-metrics.sh:163-175` computes a test:impl ratio from the *same two directory names* and reports `0:120` as a fact with no adverse framing.

**ATTACK TRACE (a):** the cheapest true statement.
1. Branch `feat/<slug>`, implement the slice under `src/pkg/`, write **no tests**.
2. `test-the-tests.sh:53` — `changed tests` is empty ⇒ `skip "this PR changes no files under tests/"`, exit 0.
3. `plan-metrics.sh:168-170` takes the `IMPL_LINES > 0` branch and prints `Test:implementation added lines: 0:120 (0.00x)`.
4. Review: criterion 2 concerns *blind* authorship of tests that exist. Nothing in the prompt makes "no tests at all" a blocking condition; `AGENTS.md:142-144` requires tests but the reviewer must infer the violation from a ratio line. `review-prompt.md:194-197` explicitly downgrades the standing quality criteria.

**ATTACK TRACE (b):** the cheapest file location.
1. The plan's `Files:` list names `pkg/handler.py` (repo root package, not `src/`) — legal Python, `uv run pytest`/`ruff`/`mypy` all still cover it because the `checks` job runs them over `.` (`ci.yml.jinja:246-249`).
2. Tests are written under `tests/`, so the diff *does* touch `tests/`.
3. `test-the-tests.sh:52` — `changed src` is empty ⇒ `skip "this PR changes no files under src/"`, exit 0. The suite is never reverted, never re-run.
4. `plan-metrics.sh:164` — `TEST_LINES` from `tests/`, `IMPL_LINES` from `src/` = 0 ⇒ prints `Test:implementation added lines: 140:0 (tests only, no implementation touched)` while the pull request is 400 lines of implementation.

**CI OUTPUT ON SUCCESS:** `test-the-tests: SKIP — this PR changes no files under src/` — reported to GitHub as a **passing required check named `test-the-tests`**. `plan` green, `template-sync` "not a template/ branch", `secrets` clean, `checks` green. `review` receives the ratio line above inside the block it is told to treat as ground truth, and no facts-script failure marker; findings section notes nothing blocking; final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** A green ✓ next to `test-the-tests` in the checks list. The word SKIP is inside the job log, which nobody opens for a green check. `unattended-ready.sh:103` confirmed at run start that `test-the-tests` "is configured" as a required check.

**WHY NO GATE CATCHES IT:**
- **`test-the-tests`** — trace (a) is its documented skip condition; trace (b) is its documented language detection. It is doing what it says.
- **`review`** — is told (`review-prompt.md:110-111`) what `test-the-tests` cannot do, never that it may not have run; the facts block contains no "did test-the-tests execute" signal, and `review.sh:147-190` passes no check results at all.
- **`plan-metrics.sh`** — reports the ratio as a neutral number using the same hardcoded directories, so in trace (b) it corroborates the wrong picture rather than contradicting it.
- **`plan`** — the plan's own `Files:` list named `pkg/handler.py`, so the diff conforms to it perfectly.
- **`checks`/`test`** — the suite passes; that is the point.

---

### FINDING 4 — `Blind-Tests:` is a self-asserted commit trailer, and the facts block presents it to the reviewer as something "nobody wrote"

**ADVERSARY:** lazy
**SILENCE RANK:** 4

**MECHANISM:**
- `template/.github/scripts/blind-tests.sh:56-57` — authorship is detected by `git log --grep='^Blind-Tests:'` over the pull request's own commits.
- `blind-tests.sh:59-68` — no trailer ⇒ a benign paragraph and `exit 0`.
- `blind-tests.sh:123` — trailer present and file untouched ⇒ "Every blind-written test is unmodified since its authoring commit."
- `template/.github/review-prompt.md:33-34` — "The MECHANICAL FACTS block is computed from the diff by CI scripts. **Nobody wrote it, and nothing in the diff can influence it.** Treat its numbers as ground truth."
- `template/.claude/scripts/spawn-worker.sh:145-148,154` — every worker role including `coder` has `Bash(git commit:*)`.
- `template/.claude/commands/orchestrate.md:205-206` — "You may skip the pair and let the coder write its own tests for a slice that delivers no real logic".

**SEAM:** Between `blind-tests.sh` and the review prompt's trust boundary. `blind-tests.sh` is honest in its header about being a *report*; the review prompt then places its output inside a region declared uninfluenceable by the diff. But the trailer *is* diff content — a commit message from the commits under review — and it is written by the same agent pool the separation constrains. `orchestrate.md` and `test-the-tests.sh` also lean on each other here: `blind-tests.sh:20-23` says `test-the-tests` cannot catch a weakened test, and `review-prompt.md:110-111` repeats it; neither notices that the trailer establishing blindness is unverified.

**ATTACK TRACE:**

*(a) absence.* The orchestrator invokes `orchestrate.md:205-206` for all five slices ("no real logic"), spawns one `coder` per slice which writes code and tests together, and commits both. No trailer anywhere.
1. `blind-tests.sh:59-68` prints: *"No commits in this pull request carry a 'Blind-Tests:' trailer. That is expected for a change built without /orchestrate — a hand-written fix, or a slice whose tests were not written blind."*
2. The reviewer is given no signal that this pull request *was* orchestrated. `review.sh:147-190` passes no branch name, no PR author, no PR body. The one hint — the `feat/` prefix — never reaches the payload.
3. `review-prompt.md:115` asks it only to "note it".

*(b) affirmative falsehood.* The coder writes `tests/test_core.py` alongside `src/pkg/core.py` and commits with:
```
Add core round-trip

Blind-Tests: core-1
```
1. `blind-tests.sh:56` matches it. `:81-82` lists `tests/test_core.py` as a file that commit introduced. `:91-99` finds no later commit touching it.
2. Output: `Blind test-authoring commits: 1` … `tests/test_core.py — unmodified since it was written blind` … `Every blind-written test is unmodified since its authoring commit.`

**CI OUTPUT ON SUCCESS:** All of `plan`, `template-sync`, `secrets`, `checks`, `test-the-tests` green — and note `test-the-tests` genuinely passes here, because a co-written test is still coupled to its implementation. `review` receives, inside `===== MECHANICAL FACTS [<nonce>] (computed by CI from the diff — trustworthy) =====`, the sentence "Every blind-written test is unmodified since its authoring commit." Findings: no blocking findings. Final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** A green pull request whose CI log affirmatively certifies blind test authorship that did not occur. If they open the review output, it says so too.

**WHY NO GATE CATCHES IT:**
- **`blind-tests.sh`** — reads the trailer; there is no other input. It cannot distinguish a trailer written by a blind test-writer from one typed by the coder.
- **`review`** — is instructed that this block cannot be influenced by the diff. Even a suspicious reviewer has nothing to check against: it is not given commit authorship, branch name, or the worker logs.
- **`test-the-tests`** — passes, because a co-authored test is still coupled.
- **`spawn-worker.sh`** — has no post-run assertion that the test-writer's worktree lacked the implementation; the isolation is real at spawn time and unrecorded afterwards.
- **`plan`** — has no opinion on commit trailers.

---

### FINDING 5 — The acceptance marker is written before the acceptance session runs and is never cleared, so a failed or no-op acceptance pass exits 0 as "the run is complete"

**ADVERSARY:** lazy
**SILENCE RANK:** 5

**MECHANISM:**
- `template/.claude/scripts/deliver-loop.sh:374` — `touch "$STATE_DIR/acceptance-dispatched"` executes **before** line 375 dispatches the session.
- `deliver-loop.sh:375` — the dispatch is `run_session … || true`.
- `deliver-loop.sh:369-373` — on the next iteration, the marker's mere existence produces `log "acceptance recorded and nothing is open — the run is complete"` and **`exit 0`**.
- `deliver-loop.sh:161-166` — run start creates `$STATE_DIR`, truncates `$SIG_FILE`, touches `$PROCESSED_FILE`. It does **not** remove `acceptance-dispatched`.
- Nothing anywhere reads `docs/acceptance.md` (verified: no script in `template/.github/scripts/` or `template/.claude/scripts/` opens it; `coverage.sh:233-234` only mentions it in prose).

**SEAM:** Between `deliver-loop.sh`'s exit-code contract and `deliver-phase.sh`'s state recomputation. `deliver-phase.sh:11-15` promises "recomputed state cannot go stale and cannot be corrupted by a killed run — the driver persists almost nothing and trusts none of what it does persist." The driver then makes its single most consequential decision — *the project is finished* — from a persisted zero-byte file the detector has never heard of. The detector assumes the driver validates the acceptance artifact; the driver assumes the detector's `PHASE=ACCEPTANCE` plus its own marker means acceptance happened.

**ATTACK TRACE:**

1. First run reaches `PHASE=ACCEPTANCE`. Line 374 creates the marker. Line 375 dispatches `/deliver — run ONLY step 6 …`.
2. The session hits `SESSION_TIMEOUT` (default 3600s, `deliver-loop.sh:87`), or exits non-zero, or — the lazy path — exits 0 having written nothing, which is the exact failure mode `spawn-worker.sh:61-67` and `orchestration.md:184-188` were built to catch **for workers** and which this dispatch path does not use (`run_session` at `deliver-loop.sh:207-215` calls `claude` directly and checks only the exit status).
3. `|| true` swallows it. `log "acceptance session failed or timed out"` goes into `run.md`.
4. Next iteration: no open PR, coverage 0, all plans built ⇒ `PHASE=ACCEPTANCE` ⇒ marker exists ⇒ `log "acceptance recorded and nothing is open — the run is complete"` ⇒ `exit 0`.
5. Any *subsequent* invocation of `deliver-loop.sh` in the same clone short-circuits to `exit 0` on its first ACCEPTANCE iteration, having dispatched nothing at all — the marker is gitignored (`template/.gitignore.jinja`) but lives on the owner's disk.

**CI OUTPUT ON SUCCESS:** None — no pull request is opened. That is precisely what makes this quiet.

**WHAT THE HUMAN SEES:** `deliver-loop.sh` exits **0**, whose documented meaning at `deliver-loop.sh:30-31` is "*done: the acceptance pass ran (or was already recorded); run.md has the report and the pending-on-owner list*". `run.md` contains, in order: `dispatch acceptance session`, `acceptance session failed or timed out`, `acceptance recorded and nothing is open — the run is complete`, `report: .claude/deliver-loop/run.md; the honest bottom line is the pending-on-owner list in docs/acceptance.md`. `docs/acceptance.md` is the untouched shipped skeleton. The two adjacent log lines contradict each other and the exit code endorses the second.

**WHY NO GATE CATCHES IT:**
- **`deliver-phase.sh`** — `PHASE=ACCEPTANCE` at line 197 is the *absence* of other work; it never inspects `docs/acceptance.md` or `docs/DESIGN.md` §13.
- **`coverage.sh`** — handles `R` ids only. It flags malformed `S<digit>` ids (`coverage.sh:124`) but never checks §13 coverage.
- **CI** — no pull request exists, so no check runs.
- **`unattended-ready.sh`** — a start-of-run preflight; it has nothing to say about how the run ended.
- **The repository's own tests** — `tests/test-deliver-loop.sh` contains no occurrence of "acceptance" (verified by grep). This path is untested.

---

### FINDING 6 — The evidence that authorises design amendments is written by the pipeline, in an unowned file nothing validates

**ADVERSARY:** scope-narrowing
**SILENCE RANK:** 6

**MECHANISM:**
- `template/.github/scripts/oracle-decisions.sh:118-122` — the authoritative evidence set is `grep -oE 'ESC-[0-9]+'` over `docs/escapes.md` **plus `grep -oE 'BL-[0-9]+'` over `docs/BACKLOG.md`**, both at base.
- `oracle-decisions.sh:225-228` — a decision passes iff each cited id is a member of that set.
- `template/.github/CODEOWNERS.jinja` — has **no rule** for `/docs/BACKLOG.md`.
- `template/.claude/scripts/spawn-worker.sh:217` — `STEWARD_TOOLS` includes `Write(docs/BACKLOG.md)` and `Edit(docs/BACKLOG.md)`.
- `template/.github/scripts/escape-refs.sh:64-77` — the gated-document list is `AGENTS.md`, `docs/DESIGN.md`, `docs/DESIGN.oracle.md`, `docs/plans/**`. `docs/BACKLOG.md` is not scanned, and no append-only check exists for it (contrast `escapes-append-only.sh`, which exists only for `docs/escapes.md`).
- `template/.claude/scripts/deliver-phase.sh:118-140` — any uncited `BL-<n>` *drives* the loop into `PHASE=ORACLE`.

**SEAM:** Between `oracle-decisions.sh` and `CODEOWNERS`. `oracle-decisions.sh:15-25` states the load-bearing duty as "The oracle **cannot invent** a design change. It can only act on something the process already logged." `CODEOWNERS.jinja:34-44` justifies leaving `docs/DESIGN.oracle.md` unowned on exactly that ground — "constrained by `.github/scripts/oracle-decisions.sh` instead". Both mechanisms treat the ledgers as an external fact. One of the two ledgers, `docs/BACKLOG.md`, is a plain unowned markdown file that the steward role has an explicit write grant for, and its own header (`BACKLOG.md.jinja:20-31`) says "The check greps this whole file for the id pattern". `escapes.md` got an append-only enforcer (ESC-15); `BACKLOG.md` did not.

**ATTACK TRACE:** (a planner narrowing scope, unattended)

1. `PHASE=PLAN`. The planner runs under `--role steward`. Following `plan.md:22-36` and `AGENTS.md:29-35` it files an uncertainty — a legitimate, instructed action — into `docs/BACKLOG.md`:
   ```
   ## Uncertainties awaiting oracle ruling
   - BL-7 — HIGH — Does R11 (offline export) belong in v1, given R3's
     latency requirement? Proposed default: defer R11; the design does not
     state a v1 boundary.
   ```
2. `deliver-loop.sh:356-364` opens it as `docs/plan-<ts>`. `plan-resolve.sh:146-161`: prefix `docs/`, 4 added lines, under the 50 cap ⇒ exempt. No `CODEOWNERS` match. Green, merges.
3. `deliver-phase.sh:100-116` now sees an unruled HIGH id ⇒ `PHASE=ORACLE REASON=uncertainties UNRULED=BL-7`.
4. The oracle appends `OD-1` to `docs/DESIGN.oracle.md` with `**Evidence:** BL-7`, `**Requirements added:** (none)`, `**Requirements superseded:** R11`, a verbatim `docs/VISION.md` quote (any sentence containing a `"` satisfies `oracle-decisions.sh:213`), alternatives, rationale.
5. `oracle-decisions.sh:118-127,225-228`: `BL-7` is in the base backlog ⇒ resolves. Seven schema fields present and non-empty ⇒ pass. Id above the base high-water mark ⇒ pass. Branch is `docs/oracle-<ts>`, diff confined to `docs/DESIGN.oracle.md` + `docs/oracle/handoff-*.md` ⇒ planning-only ⇒ uncapped exemption (`plan-resolve.sh:131,136-144`). `docs/DESIGN.oracle.md` and `docs/oracle/` are unowned by design. Green, merges with nobody awake.
6. The pipeline has now amended the design layer, end to end, on evidence it authored two pull requests earlier.

**CI OUTPUT ON SUCCESS:** On the oracle pull request: `plan-resolve: branch 'docs/oracle-…' adds 61 lines, all of them in docs/plans/, docs/DESIGN.md, docs/VISION.md, docs/DESIGN.oracle.md or docs/oracle/ … Exempt from the size cap`; `escape-refs: N citation(s) … all resolve at <sha>`; `escapes-append-only: N landed row(s) intact`; **`oracle-decisions: 1 decision(s), 1 new in this pull request, all resolve at <sha>`**; `owner-authored: … nothing to check.`; `vision-complete: … touches no plan — nothing to check.` `template-sync`, `secrets`, `checks` green; `test-the-tests: SKIP — this PR changes no files under src/`. `review`: facts show `Plan: none (branch exempt from planning)`, `Total added lines: 61`, `New dependencies: none`. Findings: likely a note that an exempt branch carried 61 lines, resolved by the fact that it is entirely planning documents. Final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** Three merged pull requests overnight, all green: "Plan: next milestone (R1 R2 …)", "Oracle: rulings and handoff", "Plan for OD-1". `docs/DESIGN.oracle.md` reads as a careful evidence-backed ruling citing their own vision sentence. Nothing indicates that `BL-7` was written by the agent that benefited from it, forty minutes earlier.

**WHY NO GATE CATCHES IT:**
- **`oracle-decisions.sh`** — checks that the citation *resolves*, never who authored the cited item or when. Its "already landed" test is satisfied by anything merged before the base commit, including step 2.
- **`escape-refs.sh`** — scans `AGENTS.md`, both design docs and `docs/plans/`. It does not scan or validate `docs/BACKLOG.md`, and `BL-` ids are outside its `ESC-[0-9]+` pattern entirely.
- **`escapes-append-only.sh`** — protects `docs/escapes.md` only. There is no `backlog-append-only.sh`.
- **`CODEOWNERS`** — no rule matches `docs/BACKLOG.md`.
- **`review`** — sees the backlog pull request as a 4-line docs change (the exemption's intended use), and sees the oracle pull request with `docs/BACKLOG.md` shown *at the base commit* — where `BL-7` is already present and looks like pre-existing evidence. `review.sh:147-190` does not include `docs/BACKLOG.md` in the context at all, so the reviewer cannot even read what `BL-7` says unless it happens to be in the diff.
- **`owner-authored.sh`** — governs `docs/DESIGN.md` and `docs/VISION.md` only, correctly and by design.

---

### FINDING 7 — A plan is "built" by a substring of a branch name, and the string compared is the filename, not the plan's slug

**ADVERSARY:** scope-narrowing
**SILENCE RANK:** 7

**MECHANISM:**
- `template/.claude/scripts/deliver-phase.sh:188` — `slug="$(basename "$f" .md)"`. The **filename**.
- `deliver-phase.sh:189` — `if ! grep -qE "^feat/.*${slug}" <<<"$MERGED_REFS"` ⇒ needs orchestrating; otherwise silently considered built.
- `template/.github/scripts/plan-resolve.sh:181-188` — the authoritative slug is the **front-matter `slug:` field**, not the filename.
- `plan-resolve.sh:239-245` — plan-resolve treats substring collision between slugs as a hard error ("a slug that is a substring of another, like 'auth' and 'auth-tokens', will always collide"). `deliver-phase.sh` has no equivalent guard.
- `template/docs/plans/_TEMPLATE.md.jinja:13-15` — "The filename, the `slug` field, and the branch name must agree" is a comment. Nothing enforces it.

**SEAM:** Between `plan-resolve.sh` (owns "which plan does this branch implement?") and `deliver-phase.sh` (owns "which plans still need building?"). They use two different identifiers for the same object and neither reconciles them. `plan-resolve.sh` assumes ambiguity is fatal and will surface as a red check; that assumption holds only for plans someone *opens a branch for* — and the whole point of this attack is that no branch is ever opened.

**ATTACK TRACE:**

1. Earlier in the run, plan `docs/plans/oracle/sync-index.md` is built; `feat/sync-index-1` merges. `MERGED_REFS` now contains `feat/sync-index-1`.
2. A later `PHASE=PLAN` iteration dispatches the planner for the remaining requirements. It writes `docs/plans/oracle/sync.md` with front-matter:
   ```
   slug: milestone-4-sync-transport
   covers: [R14, R15, R16]
   ```
   The filename is `sync.md`; the slug is `milestone-4-sync-transport`. Both are the planner's free choice; the un-owned path means no human reads either.
3. The plan pull request merges (Finding 1's step 4 conditions).
4. Next iteration, `deliver-phase.sh:188-189`: `slug="sync"`; `grep -qE "^feat/.*sync"` matches `feat/sync-index-1` ⇒ **considered built**. No `ORCHESTRATE` phase is ever emitted for it.
5. `coverage.sh` reports R14–R16 covered. All other plans are built. ⇒ `PHASE=ACCEPTANCE` ⇒ exit 0.

**CI OUTPUT ON SUCCESS:** The only pull request in the sequence is the plan-landing one, and it is fully green exactly as in Finding 6. No `feat/` pull request for this plan is ever opened, so no check ever has an opportunity to observe that R14–R16 have no code.

**WHAT THE HUMAN SEES:** A merged plan for milestone 4 sitting in `docs/plans/oracle/sync.md`, `coverage.sh` reporting every requirement covered, and `deliver-loop.sh` exit 0. The plan reads as delivered work. `docs/architecture.md` will not mention it, which is the only trace — and `AGENTS.md:165-171` makes architecture-doc accuracy a slice-level obligation nothing checks.

**WHY NO GATE CATCHES IT:**
- **`plan-resolve.sh`** — is never invoked, because no branch is ever opened for this plan. Its collision guard fires on branches, not on plans.
- **`plan-lint.sh`** — parses every plan in the tree for *readability*. `sync.md` parses fine.
- **`coverage.sh`** — reports it as covered, which is true: it *is* planned.
- **`deliver-phase.sh`** — a `grep` prefix match is its entire definition of "built", and a false positive is silent by construction (it just moves on).
- **`review`** — no pull request to review.
- **`oracle-decisions.sh`** — validated the plan's `covers:` when it landed and has nothing to say about whether it was later built.

---

### FINDING 8 — `review.sh` says `plan-metrics.sh` reports lockfile changes. It does not. A lockfile is therefore invisible to both.

**ADVERSARY:** hostile-input
**SILENCE RANK:** 8

**MECHANISM:**
- `template/.github/scripts/review.sh:44-49` — the justification comment: *"Lockfiles and generated project files are excluded from the reviewed text… **Their presence is still reported by plan-metrics.sh's new-files and dependency facts, which is the part that matters.**"*
- `review.sh:52-57` — `DIFF_EXCLUDES` removes `uv.lock`, `poetry.lock`, `Package.resolved`, `**/*.pbxproj` from `$DIFF` **and** from the truncation summary's `--numstat` (`review.sh:85,93`).
- `template/.github/scripts/plan-metrics.sh:126-150` — `deps_at()` reads `pyproject.toml` and `project.yml`. It never opens `uv.lock`.
- `plan-metrics.sh:115` — `NEW_FILES` uses `--diff-filter=A`: an *added* lockfile appears, a *modified* one does not.
- `template/.github/workflows/ci.yml.jinja:245` — `uv sync --locked` asserts consistency with `pyproject.toml`, not provenance.

**SEAM:** This is the cross-reference the brief asked to check character by character, and it is wrong. `review.sh` excludes lockfiles *on the stated grounds that `plan-metrics.sh` covers them*. `plan-metrics.sh` parses declared-dependency manifests *on the stated grounds that this is "the cheapest speculative-machinery detector there is"* — a scope-creep check, never a supply-chain one. Each is correct about its own job; the handoff between them is a comment that does not correspond to any code.

**ATTACK TRACE:**

1. A `feat/<slug>` pull request whose plan legitimately names `pyproject.toml` in a slice's `Files:`.
2. The diff modifies **only** `uv.lock`, changing a transitive dependency's resolved version and hash (or, in the swift variant, `Package.resolved`'s pinned revision). `pyproject.toml` is untouched — or is touched only in a way that keeps the lock consistent.
3. `uv sync --locked` passes: the lockfile is still consistent with `pyproject.toml`'s declared ranges.
4. `review.sh:60` — `uv.lock` is excluded from `$DIFF`. The reviewer's payload contains **no evidence the file changed**.
5. `plan-metrics.sh:152` — `comm -13` over `deps_at` sees identical declared-dependency sets ⇒ `New dependencies: none`.
6. `plan-metrics.sh:115-121` — `uv.lock` is modified, not added ⇒ absent from `New files added`.

**CI OUTPUT ON SUCCESS:** `checks`: `uv sync --locked` succeeds, ruff/mypy/pytest pass against the swapped dependency. `secrets`: gitleaks finds nothing (a version pin is not a credential). `plan`, `template-sync`, `test-the-tests` green. `review`: the facts block prints `New files added: none` (or lists only the slice's real files) and, verbatim, **`New dependencies: none`** — with `(AGENTS.md: no new dependencies without the owner's approval.)` suppressed because the branch was not taken. Findings: no blocking findings. Final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** A pull request whose GitHub diff view shows `uv.lock` as a collapsed generated file — the one file GitHub itself renders as "large diff, load anyway?" — alongside a review comment that affirmatively states no new dependencies were added. Six green checks.

**WHY NO GATE CATCHES IT:**
- **`review`** — cannot see the file. `review.sh:52-57` removed it, and the exclusion is applied to the truncation summary too, so even the degraded path shows nothing.
- **`plan-metrics.sh`** — reads `pyproject.toml`/`project.yml`; `New dependencies: none` is a true statement about declared dependencies and a false impression about the change.
- **`secrets`** — gitleaks scans for credential patterns.
- **`checks`** — `--locked` verifies consistency, not intent or provenance.
- **`plan`** — the file list conforms if the plan named the manifest; and if it did not, the reviewer would have to see the file to notice, which is the problem.
- **`test-the-tests`** — orthogonal.

---

### FINDING 9 — `template-sync` verifies the tree against a template repository the pull request itself chooses

**ADVERSARY:** hostile-input
**SILENCE RANK:** 9
**CONDITIONAL** — see the dependencies marked in the trace.

**MECHANISM:**
- `template/.github/scripts/template-sync.sh:69-71` — `TARGET_REF` from `_commit` **at the head commit**.
- `template-sync.sh:73-84` — the *only* comparison between base and head answers files is `_commit`. **`_src_path` is never compared, never validated, never pinned.**
- `template-sync.sh:100` — `copier update --defaults --trust --vcs-ref="$TARGET_REF"`, run in a worktree at base. `--trust` enables copier's unsafe features (`_tasks`, `_migrations`, `_jinja_extensions`, `_external_data`) from whatever repository `_src_path` names.
- `template-sync.sh:135-142` — success is `git write-tree` of the replay equalling the head tree.
- `template/.github/workflows/ci.yml.jinja:173-206` — before the script runs, the step writes `url.https://x-access-token:${TEMPLATE_TOKEN}@github.com/.insteadOf` into the **global** git config, and at `:194` reads `_src_path` from the checked-out (head) answers file to add a third rewrite.
- `template/.github/review-prompt.md:127-147` — a `TEMPLATE SYNC:` note in the facts region converts criterion 5 from an unconditional block into "do not block a template sync for touching gate paths or for having no plan".
- `template/.github/scripts/review.sh:127-137` — that note is emitted purely from `case "${HEAD_REF:-}" in template/*)`. The review job never re-runs the replay (`review.sh:123-126`, deliberately).

**SEAM:** Between `template-sync` and `review`. `review-prompt.md:130-135` tells the reviewer the replay "fails unless this tree is byte-for-byte the result, so gate-path edits here are the TEMPLATE's output". `template-sync.sh:20-21` states its property as "this diff is byte-for-byte what the template produces, and contains nothing else". Both sentences are true and both quietly bind the free variable *which template*. The answers file is an input produced by the thing being constrained.

**ATTACK TRACE:**

1. Author (or an agent) pushes branch `template/v0.5.0`.
2. `.copier-answers.yml` at head:
   ```
   _commit: v0.5.0
   _src_path: https://github.com/<attacker>/grimsverk-template.git
   ```
   The base recorded `_commit: v0.4.12` and the real `_src_path`.
3. `<attacker>/grimsverk-template` at tag `v0.5.0` is a real copier template, authored so that `copier update` from the project's base state renders exactly the tree the author wants — including `.github/workflows/ci.yml`, `.github/scripts/review.sh`, `.github/review-prompt.md`, or (needing no `CODEOWNERS` review at all) `.claude/scripts/deliver-loop.sh` and `.claude/commands/*.md`.
4. `ci.yml.jinja:194-201` reads the head `_src_path`; it is `https://`, so the `*ssh://git@*` case does not fire and the existing `https://github.com/` rewrite already routes it — carrying `TEMPLATE_TOKEN` to the attacker-named repository on the same host.
5. `template-sync.sh:78` — `v0.5.0 != v0.4.12`, so the "not a template sync" refusal does not fire. `:92` creates the worktree. `:100` clones the attacker's repo and runs the update with `--trust`.
6. `:135-142` — `REPLAYED_TREE == HEAD_TREE` by construction.

*Dependency I could not verify from these files:* whether copier executes `_tasks` during `update` as opposed to only during `copy`. `_migrations` are executed by `copier update` by design and are equally arbitrary shell, so I record the code-execution consequence as reachable via `_migrations` and mark the `_tasks` variant unverified. Also unverified from the repository: the workflow's default `GITHUB_TOKEN` permission scope (the `secrets` job restates permissions at `ci.yml.jinja:222-224`; `template-sync` does not, so it inherits the repository default), and whether `actions/checkout`'s persisted credential is present in the worktree's parent `.git/config` — both would need the live repository's settings to settle. Note that any code execution here happens **before and independently of** the review verdict.

**CI OUTPUT ON SUCCESS:**
- `plan`: `plan-resolve: branch 'template/v0.5.0' is a template sync ('template/') — no plan applies. The template-sync check verifies it instead, and is a required check precisely because this one steps aside.` Then plan-lint/escape-refs/escapes-append-only/oracle-decisions/owner-authored/vision-complete all pass (provided the payload avoids `docs/DESIGN.md` and `docs/VISION.md`, which have no template carve-out in `owner-authored.sh`). **Green.**
- `template-sync`: `template-sync: base is at template v0.4.12, PR targets v0.5.0` / `template-sync: replaying `copier update --vcs-ref=v0.5.0` from the base commit` / **`template-sync: PASS — the diff is exactly `copier update` to v0.5.0.`** / `template-sync: nothing hand-written rode along with it.` **Green.**
- `test-the-tests`: `test-the-tests: SKIP — 'template/v0.5.0' is a template sync — verified by the template-sync check.` **Green.**
- `secrets`, `checks`: green (the attacker authored the tree, including its lint config).
- `review`: the facts region carries the `TEMPLATE SYNC:` note; criterion 5's exception applies. Findings section reads roughly *"this update changes how the repository is governed: <summary of the workflow/driver changes>"* — which criterion 1's template branch is explicitly asked to produce — and no blocking finding, because it was told the replay proves provenance. Final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** A pull request titled "Update from template v0.5.0", six green checks, and a review comment that helpfully summarises what the template release changes about governance. The single line that matters — `_src_path` — is one line inside `.copier-answers.yml`, a file every reader has been trained to treat as machine-maintained.

**WHY NO GATE CATCHES IT:**
- **`template-sync.sh`** — compares `_commit` only. Comparing `_src_path` between base and head would close this in one line; it does not.
- **`plan`** — steps aside by prefix, explicitly delegating to `template-sync` (`plan-resolve.sh:110-117`).
- **`test-the-tests`** — skips by prefix, explicitly delegating to `template-sync` (`test-the-tests.sh:37-39`).
- **`review`** — is told by the note, and by criterion 5's exception, that provenance is mechanically settled; and `review.sh:123-126` states the replay is deliberately not re-run.
- **`CODEOWNERS`** — would still require owner approval for `/.github/` payloads (conditional on `require_code_owner_review` actually binding — see Finding 10), but imposes nothing on a payload confined to `.claude/scripts/`, `.claude/commands/`, `docs/BACKLOG.md`, or `docs/architecture.md`.
- **`secrets`** — scans for credentials in the diff, not for exfiltration by a build step.

---

### FINDING 10 — `owner-authored.sh` checks who *opened* the pull request, and the unattended driver opens pull requests as the owner

**ADVERSARY:** confused
**SILENCE RANK:** 10
**CONDITIONAL** — see the trace.

**MECHANISM:**
- `template/.github/scripts/owner-authored.sh:89` — the entire check is `[[ "$PR_AUTHOR" != "$OWNER_LOGIN" ]]`, where `PR_AUTHOR` is `github.event.pull_request.user.login` (`ci.yml.jinja:115`).
- `owner-authored.sh:17-27` — the stated guarantee: "*This check requires the owner's AUTHORSHIP of the pull request itself… The owner opens it, reads it as a diff, and merges — and that reading is the point.*"
- `template/.claude/scripts/deliver-loop.sh:183-193` — `mechanical_pr()` runs `git push` and `gh pr create` from the owner's local shell, under the owner's `gh` credentials (`deliver-loop.sh:143` asserts `gh auth status`).
- `deliver-loop.sh:104-109` — `ORCH_TOOLS` grants orchestrate and acceptance sessions bare `Write`, `Edit`, `Bash(git push:*)` and `Bash(gh pr create:*)` — no path restriction on `Write`/`Edit`, with `--permission-mode acceptEdits` (`deliver-loop.sh:117`).
- `template/.github/scripts/unattended-ready.sh:110-137` — the ruleset readback collects `"context"` strings and sets `HAVE_PR_RULE` if any rule has `"type": "pull_request"`. It **never checks `require_code_owner_review`**, which `setup-github.sh:206-213` sets and which is the only thing making `CODEOWNERS` bind.

**SEAM:** Between `owner-authored.sh` and `deliver-loop.sh`. `owner-authored.sh` was written against a world in which "the pull request author" is a proxy for "a human pressed a button after reading a diff". `deliver-loop.sh` mechanised exactly that button — `mechanical_pr`'s own body says "Mechanical — no judgment" — and nothing reconciled the two. Separately, `unattended-ready.sh` was built to read back "configuration nobody has looked at since setup" and reads back everything *except* the setting that makes the ownership half of the system real.

**ATTACK TRACE:**

1. Owner runs `deliver-loop.sh` and goes to bed.
2. `PHASE=ORCHESTRATE`. `run_session` dispatches `claude -p "/orchestrate <slug>" --permission-mode acceptEdits --allowed-tools "$ORCH_TOOLS"`. The grant is bare `Write,Edit` — every path in the repository.
3. The orchestrate session, acting in good faith on `AGENTS.md:165-171` ("A slice isn't finished until [`docs/architecture.md`] is accurate") and finding a genuine inconsistency, edits `docs/DESIGN.md` §5 to correct a requirement's wording. `AGENTS.md:189-194` forbids this; `orchestration.md:121-124` states plainly that "Role tool grants are the FIRST of two enforcements and not the binding one", and this session's grant does not restrict writes at all.
4. It commits to `feat/<slug>`, pushes, and runs `gh pr create` — under the owner's credentials.
5. `ci.yml.jinja:115` sets `PR_AUTHOR` to the owner's login. `owner-authored.sh:66-67` reads the same login out of `CODEOWNERS`. They match.

*Dependency I could not verify:* whether `require_code_owner_review: true` combined with `required_approving_review_count: 0` (`setup-github.sh:206-213`) actually blocks the merge on GitHub, and whether the owner-authored pull request could satisfy it at all given GitHub forbids self-approval. If it binds, the merge stalls and `deliver-loop.sh:254-255` exits 4 — the guarantee holds by a different mechanism than the one that claims to hold it. If it does not bind (or the ruleset drifts, which `unattended-ready.sh` cannot detect), the pull request auto-merges.

**CI OUTPUT ON SUCCESS:** `plan` job step "The design and the vision are landed by their owner" prints **`owner-authored: 1 owned document(s), opened by '<owner>'.`** All other steps green. `template-sync` nothing to do. `secrets`, `checks`, `test-the-tests` green. `review`: the diff shows the `docs/DESIGN.md` edit; criterion 5 (`review-prompt.md:161-166`) instructs — "*if you are reading an agent-opened diff that touches either file, that is already red elsewhere — say so and block*". The reviewer **cannot evaluate that condition**: `review.sh:147-190` passes no PR author, and `review.yml:71-75` passes only `BASE_SHA`, `HEAD_SHA`, `HEAD_REF`. Its most likely reading is that the check is green so the condition does not apply.

**WHAT THE HUMAN SEES:** In the morning, a pull request they authored, containing a design edit they did not write, with a green check whose log line asserts the document was landed by its owner.

**WHY NO GATE CATCHES IT:**
- **`owner-authored.sh`** — its input is the GitHub PR author field, and that field is true. The check is not defeated; the proxy is.
- **`review`** — is asked to make exactly this judgement (criterion 5) and is given none of the information required. See Finding 11.
- **`unattended-ready.sh`** — the one preflight designed to read repository settings back does not read `require_code_owner_review`.
- **`plan`/`template-sync`/`test-the-tests`/`secrets`** — none has an opinion on document ownership.
- **`spawn-worker.sh`'s role grants** — do not apply: orchestrate sessions are launched by `orch_cmd` (`deliver-loop.sh:114-119`), not by `spawn-worker.sh`, and therefore bypass `ORACLE_TOOLS`/`STEWARD_TOOLS` entirely.

---

### FINDING 11 — The review payload omits the three facts criteria 1, 2 and 5 are keyed on: the branch prefix, who opened the pull request, and whether the change was orchestrated

**ADVERSARY:** confused
**SILENCE RANK:** 11

**MECHANISM:**
- `template/.github/workflows/review.yml:71-75` — the only PR context passed is `BASE_SHA`, `HEAD_SHA`, `HEAD_REF`.
- `template/.github/scripts/review.sh:147-190` — the assembled `CONTEXT` is: `AGENTS.md`@base, `docs/DESIGN.md`@base, `docs/DESIGN.oracle.md`@base, the resolved plan@base, the facts block, the optional template-sync note, and the diff. `HEAD_REF` reaches the payload **only** through the `template/*` note at `review.sh:128-136`.
- `review.sh:114` — `plan-resolve.sh` is run with `2>/dev/null || true`, collapsing "exempt branch" and "resolution failed" into the same empty `PLAN_PATH`.
- `review.sh:165-170` — the reviewer is then told the plan is missing "*or the plan check has failed separately*".

**SEAM:** Between `review.yml` (owns what the gate is given) and `review-prompt.md` (owns what the gate is asked). Three criteria ask questions whose inputs `review.yml` does not pass:
- **Criterion 1** (`review-prompt.md:76-83`): "*A branch prefixed `chore/` or `docs/` is exempt from planning because it is supposed to be too small to plan… So ask whether this change is actually that… That is a BLOCKING finding.*" The reviewer is never told the branch prefix, so it cannot distinguish an exempt branch from a broken `plan` check — and `review.sh:165-170` explicitly offers it both readings.
- **Criterion 2** (`review-prompt.md:113-115`): "*the tests may have been written by the same agent that wrote the code*" — requires knowing whether the change was orchestrated. Nothing in the payload says.
- **Criterion 5** (`review-prompt.md:161-166`): "*if you are reading an agent-opened diff that touches either file*" — requires the PR author login. Not passed.

**ATTACK TRACE:**

1. Branch `docs/tidy-the-store-layer`, 48 added lines of real implementation under `pkg/` plus a README paragraph.
2. `plan-resolve.sh:146-166` — exempt prefix, 48 ≤ 50 ⇒ exit 0, no plan.
3. `review.sh:114` — `PLAN_PATH=""`. The reviewer receives: "*(no plan resolved — this branch is exempt from planning, **or the plan check has failed separately**. Review against docs/DESIGN.md instead…)*"
4. A good-faith reviewer reads the second disjunct, concludes the `plan` check will report the wiring fault as its own clearly-named red check (which `review.sh:111-113` says is the intended division of labour), and declines to duplicate it. Criterion 1's blocking condition — "real work arriving on an exempt branch" — is never evaluated, because the reviewer cannot confirm it *is* an exempt branch.
5. `plan-metrics.sh:107` prints `Plan: none (branch exempt from planning) — no slice estimates to check.` This is the well-formed-but-vacuous facts section: it is not empty, contains no `PLAN PARSE FAILED`, and reports no script failure, so `review-prompt.md:36-42`'s blocking rule does not fire on it.

**CI OUTPUT ON SUCCESS:** `plan`: exempt-prefix pass. `template-sync`: nothing to do. `secrets`, `checks` green; `test-the-tests: SKIP — this PR changes no files under src/`. `review`: facts show `Plan: none (branch exempt from planning)`, `Total added lines: 48`, `New dependencies: none`, no blind-authoring commits with the benign explanation. Findings: typically one non-blocking note that the change is unplanned. Final line `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** A merged `docs/`-prefixed pull request carrying 48 lines of unplanned implementation, with a review that noted the absence of a plan and passed anyway.

**WHY NO GATE CATCHES IT:**
- **`plan`** — exempt by prefix, under the cap. Working exactly as designed.
- **`review`** — asked to make the judgement and structurally unable to; its own context text supplies the alternative explanation that makes declining reasonable.
- **`plan-metrics.sh`** — a vacuous facts section is not a failed one, and the prompt's blocking rule (`review-prompt.md:36-42`) is written against `PLAN PARSE FAILED` and missing regions, neither of which occurs.
- **`test-the-tests`** — skips.
- **`CODEOWNERS`** — the change is in `pkg/` and `README.md`, neither owned.

---

### FINDING 12 — Past 400 KB the reviewer reads "the 20 smallest changed files", and the author decides which files those are

**ADVERSARY:** hostile-input
**SILENCE RANK:** 12

**MECHANISM:**
- `template/.github/scripts/review.sh:72-75` — `MAX_DIFF_BYTES=400000`; over the cap, `$DIFF` is replaced.
- `review.sh:84-95` — the replacement is `--numstat` for every file, plus the **full text of the 20 files with the fewest added lines** (`sort -n -k1 | head -20`).
- `review.sh:194-201` — the reviewer is told it is reading a summary and asked to say so.
- `review-prompt.md` — truncation is nowhere listed as a blocking condition; `:36-42`'s blocking rule covers a *failed or missing facts region*, which is unaffected by truncation.

**SEAM:** Between `review.sh`'s degradation policy and `review-prompt.md`'s blocking bar. `review.sh:66-73` argues that a summary is "degraded, but still a review, and still able to catch scope and gate-tampering problems, which are visible at file level" — an argument that holds only if *which* files get full text is not under the author's control. It is: the selection key is added-line count, computed from the same diff.

**ATTACK TRACE:**

1. A slice legitimately adds a large fixture or generated artefact — a test corpus, a schema dump — pushing the diff over 400 000 bytes. (`uv.lock` etc. are excluded from the byte count, so this must be a non-lockfile file; a fixture directory the plan names is the natural cover.)
2. The change the author does not want read — say 60 lines relaxing a validation path in `pkg/auth.py` — is placed in a file with a large added-line count, or the file is written so its added-line count exceeds that of at least 20 other changed files. Adding 20 trivially small files (one-line docstring fixes across modules) is sufficient and reads as tidying.
3. `review.sh:93-94` selects the 20 smallest. `pkg/auth.py` is not among them; it appears only as a `--numstat` row: `62  8  pkg/auth.py`.

**CI OUTPUT ON SUCCESS:** `plan`, `template-sync`, `secrets`, `checks`, `test-the-tests` green (the fixture is large but valid; the auth change is covered by its own test). `review`: the payload opens with "*The full diff is 431204 bytes, over this gate's 400000-byte cap, so it has been replaced by a summary. You are reviewing LESS than the whole change.*" The facts block is complete and healthy: the slice is inside its estimate, no new dependencies, blind tests unmodified. Findings section contains the required disclosure — "*the diff was truncated; I could not read the full text of pkg/auth.py or the fixture directory*" — and, since nothing in the visible material is blocking, the final line is `REVIEW_VERDICT: PASS`.

**WHAT THE HUMAN SEES:** Six green checks and a review that transparently states it could not read part of the change and passed it anyway. The honesty of the disclosure is what makes this quiet: it reads as diligence.

**WHY NO GATE CATCHES IT:**
- **`review`** — the truncation notice is an instruction to *disclose*, not to block; `review-prompt.md:217-218`'s "fail toward BLOCK if genuinely unsure" is a general disposition that the explicit truncation handling at `:194-201` reframes as a known, tolerated degradation.
- **`plan-metrics.sh`** — reports the slice's line total against its estimate. If the plan named the fixture directory, no `OVER` fires; if it does, criterion 1 says "never block on the number alone".
- **`test-the-tests`** — passes; the auth change is exercised.
- **`checks`** — passes; the change is valid code.
- **`secrets`** — no credential involved.

---

## 3. HANDOFF: CONTENT-DEPENDENT THREADS

These are gates whose behaviour is set by the per-project documents rather than by the machinery. I have named the mechanism and stopped.

**H1 — `vision-complete.sh`'s emptiness predicate is one non-blank line per section.**
`template/.github/scripts/vision-complete.sh:71-83` (and the identical awk at `unattended-ready.sh:186-198`): a `##` section is "filled" if it contains any line that is not blank, not a heading, and not inside an HTML comment. `TBD` passes. This is the sole gate standing between an unattended run and a vision the oracle will quote as a tiebreaker.
*Question for a document-shape review:* what sections does the shipped `docs/VISION.md` skeleton declare, and does its prompting text make a one-token fill a plausible good-faith outcome rather than an obvious cheat?

**H2 — the oracle's vision field is validated by the presence of a `"` character.**
`template/.github/scripts/oracle-decisions.sh:206-216`: the value must either be exactly `(no vision statement decided this)` or contain a double-quote. Nothing checks that the quoted text appears in `docs/VISION.md`, at base or at all.
*Question:* what does the shipped `docs/DESIGN.oracle.md` schema block model as a quoted statement, and is a fragment-level quote (three words) distinguishable from a sentence-level one by any rule a document review could propose?

**H3 — requirement granularity sets the whole coverage bar.**
`template/.github/scripts/coverage.sh:90-114` extracts ids from `docs/DESIGN.md` §5. Finding 1's severity is a direct function of how coarse those requirements are: twenty fine-grained requirements make a padded `covers:` list conspicuous; four coarse ones make it invisible.
*Question:* does the `docs/DESIGN.md` template force requirements at a granularity a single 100-line plan cannot plausibly swallow, and does §5's guidance say anything about atomicity?

**H4 — §13 success criteria (`S<n>`) are read by nothing.**
`coverage.sh:124` flags a malformed `S<digit>` id and `coverage.sh` never uses `S` ids for anything else; no script in `template/.github/scripts/` or `template/.claude/scripts/` opens `docs/acceptance.md`. The entire acceptance half of `AGENTS.md:240-249`'s definition of done is prose enforced by nothing.
*Question:* what shape does `docs/acceptance.md` impose per row, and is there a document-level shape (one row per `S` id, with a `Verified by:` field) that a future mechanical check could key on?

**H5 — plan estimates set the only scope tripwire, and the plan sets them.**
`template/.github/scripts/plan-metrics.sh:29-30,91-94`: `FACTOR=3`, `FLOOR=80`; a slice is flagged only when actual exceeds `max(3 × estimate, 80)`. On the unattended path the estimate is written by an agent into an un-owned file.
*Question:* does `_TEMPLATE.md`'s estimate guidance ("a slice you estimate at ~1400 lines is the plan telling you this is really three slices") have a document-shape counterpart that would make an inflated estimate legible to a reader — a stated per-slice ceiling, say?

**H6 — the `docs/BACKLOG.md` "Approved" section is described as an authorisation and read by no gate.**
`template/docs/BACKLOG.md.jinja:5-9` and `AGENTS.md.jinja:232-238`: "the owner has said yes. An agent working unattended implements these top to bottom." `deliver-phase.sh` reads the backlog only for `BL-` ids (`:101-133`) and never distinguishes the three sections except for the uncertainties heading (`:108`). Nothing enforces that an item is in "Approved" before it is worked, and nothing prevents an agent from moving an item between sections.
*Question:* what does the document shape intend a token in "Approved" to authorise, and should the section boundary be a mechanically-readable one?

---

## 4. CLOSED ANGLES

- **Verdict forgery from diff content.** `review.sh:256` takes the last non-empty, trailing-whitespace-stripped line and matches it whole against two exact strings. Diff content cannot be the last line of the model's reply. Genuinely closed.
- **Nonce/delimiter forgery in the diff section.** `review.sh:145` generates the nonce *after* `$DIFF` is read, and `review-prompt.md:19-29` tells the reviewer the token. Closed as designed.
- **Injecting a forged fact into the MECHANICAL FACTS block.** The author-controlled strings that reach it are commit subjects (`blind-tests.sh:76`), trailer values (`:77`), and added-file paths (`plan-metrics.sh:115-118`). `git log %s` folds the subject to one line and `git diff --name-only` C-quotes control characters, so no newline can be smuggled in and no delimiter can be forged. Single-line content injection remains, but I could not construct a payload that changes a verdict. Closed enough to not be worth the next reviewer's time.
- **Shell injection via a plan's `Files:` line.** `plan-metrics.sh:85-88` splits on `IFS` rather than eval, and both `plan-metrics.sh:44-51` and `review.sh:58` use `--literal-pathspecs`. A `:(exclude)src` path is inert. Closed.
- **Raising a slice estimate in the pull request that overran it.** `plan-metrics.sh:67,78` read the plan at `BASE_SHA`, and `plan-resolve.sh:217-227` requires the plan to pre-exist. Closed *within one pull request*. Across two pull requests on the un-owned `docs/plans/oracle/` path it is open, but that is Finding 1's mechanism rather than a separate one.
- **Rewriting the escapes ledger or an oracle decision.** `escapes-append-only.sh:66-84` enforces byte-identity and relative order of landed rows; `oracle-decisions.sh:130-160` enforces the same for decision blocks plus monotonic ids. Both are correct and I found no bypass.
- **Deleting `docs/VISION.md` to satisfy `vision-complete.sh`'s opt-out** (`vision-complete.sh:63-66`). The deletion is a diff touching `docs/VISION.md`, which `owner-authored.sh:55-57` catches (a deletion is still a name in `--name-only`). Closed.
- **Fork pull requests reaching auto-merge.** `auto-merge.yml:78-82` requires `head.repo.full_name == github.repository`. Closed, and the comment correctly identifies that the secret-scoping accident is not the load-bearing part.
- **Overriding `EXEMPT_MAX_ADDED`, `MAX_DIFF_BYTES`, `MAX_DECISIONS`, `REQ_OFFSET` from a pull request.** All are read from the environment, and no workflow step sets them; a repository variable would require settings access. Closed for a pull-request author.
- **Duplicate rulesets unioning stale required checks.** `setup-github.sh:231-239` updates in place by name. Closed.

---

## 5. Two structural notes

Not findings, but they bear on how the list above should be read.

**Five of the twelve findings share one root.** `CODEOWNERS.jinja:60`'s deliberate release of `docs/plans/oracle/`, combined with `CODEOWNERS.jinja:69`'s failure to extend past `settings.json` into `.claude/`. The un-owned oracle path is a considered trade and the file argues for it well; `.claude/scripts/` appears to be an oversight of the same kind that `ESC-22` records for `docs/VISION.md` — a path added after the list that names paths.

**Nothing anywhere compares what was asked for to what was built.** Every gate compares an artefact to a document, and every document on the unattended path is an artefact. That is the posture the brief predicted the system would be least defended against, and reading the machinery confirms it.
