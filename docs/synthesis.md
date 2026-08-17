# Synthesis — the plans and the reviews, reconciled

A working document, not a record. It exists to be walked top to bottom, with
decisions taken at the bottom. Nothing here is authorization: as
`docs/reviews/README.md` says, a finding becomes binding when it becomes an
`ESC-<n>` row and the check that row names.

- **First written:** 2026-08-17, against `claude/copier-template-automation-rii78u` @ `b56ed76`
- **Revision 2:** 2026-08-17 — the owner walked the register and ruled. Part 5
  now carries fifteen rulings in the owner's own words; Part 4 records what each
  decision became; Part 2 gains six findings that were not in any review,
  discovered while answering the owner's questions.
- **Covers:** `docs/plans/` (2 plans + 2 context documents) and `docs/reviews/`
  (5 sessions, 14 distinct documents — `testbed-vs-template-report.md` and
  `comparative-report.md` are byte-identical copies of one file)
- **Source material:** ~63,000 words of review, plus one working session.

> **On why the rulings are written down.** They were taken in a chat session and
> exist nowhere else. `AGENTS.md` says chat is not storage. Part 5 is that rule
> applied to this conversation.

---

## Part 1 — The reconciled picture

### 1.1 The plans are not outdated. They are finished.

This is the first thing to correct, because it changes how everything below
should be read.

- `docs/plans/unattended-operation.md` — **superseded**, by its own banner. Its
  six slices, its sequencing argument, its readiness check, its no-vision
  decision class and its lifecycle fixture all survive inside the other plan.
- `docs/plans/automation-loop-plan.md` — **implemented**, across six commits on
  this branch. Its own banner says so, and adds the honest part: five behaviours
  ship **unverified-live**.

So the reviews did not overtake the plans. The plans landed, and then the
reviews examined what landed. There is no plan-versus-review conflict to
adjudicate — there is a built system and twenty-two traced findings against it.

The plans do overclaim in one narrow place, and a review caught it: the
verification section lists `tests/test-deliver-loop.sh` as covering the driver,
and `gate-seams` verified by grep that the file **contains no occurrence of
"acceptance"** — the driver's single most consequential decision path is
untested. Treat the plans' "Tests" and "Verification" sections as claims of the
same kind the reviews were sent to check. Revision 2 adds a second instance:
§2's Root H shows the budget ceiling was never exercised either.

The five unverified-live items, unchanged and still unobserved:

1. A branch actually vanishing under the App token (would close `ESC-21`, which
   has now been closed and reopened around **four** wrong theories, and **no
   branch has ever been seen to disappear, under any identity**).
2. REST ruleset creation before checks first report.
3. `budget-probe.sh` against a real subscription. — **Revision 2: now
   disproven rather than unverified. See Root H.**
4. One live smoke-probe of the driver's session command lines.
5. `/deliver-loop` web mode, once, watched.

### 1.2 What the reviews are, and the split that was never joined

Five sessions, three of them independent of each other:

| Session | What it did |
| --- | --- |
| `adversarial-review/` | Read 98 files and produced the **mechanism inventory** (34 mechanisms) plus the two attack prompts. The inventory's content-dependence table is the most useful single artifact in the whole corpus. |
| `gate-seams/` | **Prompt A** executed: 12 findings against the seams *between* gates, + 6 handoffs, + 10 closed angles. |
| `document-shape/` | **Prompt B** executed against the same commit: 10 findings, 6 constructed document pairs, 4 "shapes that hold". Ships a `reproduce.sh`; findings 1, 2 and 6 were run against real scripts. |
| `report-review/` | An assessment of the comparative report — verified its citations, ranked its transfers, added 4 gaps the report missed. |
| `template-review/` | A blind reconstruction of the template's intent, and the comparative report against a testbed built cold from the same brief. |

`gate-seams` and `document-shape` are two halves of one split, run
independently, **never reconciled against each other** — the reviews README
says so explicitly and asks for exactly that before either becomes an `ESC` row.
Part 3 does it.

### 1.3 The one sentence

Nineteen of the twenty-two review findings are the same defect wearing different
clothes, and `gate-seams` states it in its closing line:

> **Nothing anywhere compares what was asked for to what was built.** Every gate
> compares an artefact to a document, and every document on the unattended path
> is an artefact.

Unpacked: the gates are genuinely excellent at **ordering** (the plan existed at
base, the evidence existed at base, the ledger row was not rewritten) and at
**shape** (seven fields present, an id matches `R<digits>`, a plan parses). Each
one takes its standard from a file. On the unattended path, every one of those
files is written by the same pipeline the gate constrains, on paths CODEOWNERS
deliberately releases so overnight work can proceed.

The system therefore guarantees that **a coherent paper trail exists and was
written in the right order.** It does not guarantee that anything in it is true,
adequate, or seen by a human.

### 1.4 The sharpest thing the split produced, which neither half saw alone

`document-shape` establishes that `docs/acceptance.md` is **the one artifact in
the entire unattended run whose PR requires the owner's review**
(`CODEOWNERS.jinja:65`) — the single guaranteed human read, and the only place
the built system is compared to the design rather than to a plan.

Three findings, from both halves, each independently prevent that read:

1. **It may never be dispatched.** `deliver-loop.sh:374` writes the
   `acceptance-dispatched` marker *before* line 375 dispatches the session, the
   dispatch is `|| true`, and run-start never clears the marker. A timed-out,
   failed, or no-op acceptance session produces `exit 0` — "the run is complete"
   — with `docs/acceptance.md` left as the shipped skeleton. Every later run in
   that clone short-circuits to `exit 0` immediately. *(`gate-seams` F5)*
2. **It may be structurally unable to land.** `docs/acceptance.md` and
   `docs/architecture.md` are **not** in `plan-resolve.sh`'s planning-path
   carve-out, so the acceptance branch is capped at 50 added lines. On any
   project big enough for acceptance to matter, the branch dies, three fix
   attempts die identically, the driver exits 3 — and the sentinel from (1) is
   already set. *(`document-shape` F10; the fourth instance of `ESC-22`'s exact
   pattern.)*
3. **If it does land, it can be hollow.** The agent running the pass decides
   which criteria it is forbidden from checking. Marking a row `owner` costs one
   sentence and ends the run at exit 4 — a *documented successful stop*. Marking
   it `agent` costs a command that has to really run. Every incentive points one
   way; no document warns about that direction. *(`document-shape` F4)*

And what reaches acceptance is already less than the design, because
`coverage.sh` calls a requirement "covered" when a plan's `covers:` names it —
a claim, never compared to the plan's slices or the merged code.

Two reviews that never spoke found three independent ways to sever the system's
only guaranteed connection to the human. That is the headline.

### 1.5 The good news, stated as plainly as the bad

The comparative review is strong external validation and should not be lost
underneath the findings:

- A capable agent, given the same brief cold, reconstructed roughly the
  template's **CI tier only** — and none of its two deeper tiers (the execution
  engine; the unattended-authority model). On nearly every shared mechanism the
  template's version was stronger and evidence-hardened.
- The **blind reconstruction succeeded without guessing** — the template is
  legible as a spec, which was the actual test.
- Of ~10 apparent testbed advantages, the equivalence search killed all but 3.
- **Candidate scar tissue was scarce**: four minor, self-aware items (the R1000
  offset, the glossary wipe protocol, the SSH `insteadOf` ceremony, the
  `project_name` copier workaround). Nothing structural.
- The autonomy ceiling difference is **architectural, not incremental**: ~4
  touchpoints per *design revision* spanning many zero-touch PRs, versus ≥1
  human action per PR forever.

The machinery is sound. The gap is uniformly one thing, and it is the thing in
§1.3.

---

## Part 2 — The findings in one order

Twenty-two traced review findings collapse into seven roots. Revision 2 adds
**Root H**, six findings that no review contained — they surfaced while
answering the owner's questions and were verified directly against the code and
the live CLI. `GS-n` = `gate-seams`, `DS-n` = `document-shape`, `N-n` = new in
revision 2.

### Root A — "Done" is a claim, and nothing compares it to delivery
**GS-1, GS-7, DS-1, DS-4, GS-5, GS-H3, GS-H4**

The largest cluster, and both reviews independently ranked their half of it
**#1**. `coverage.sh` reports a requirement covered when some plan's `covers:`
front-matter names it; `oracle-decisions.sh` checks only that the ids *exist* at
base, so a padded list is **strictly easier to pass than an honest one**;
`plan-metrics.sh` flags only over-delivery, never under; the review gate's
question is fixed at "does this diff match the plan", explicitly not "is this
plan enough"; and `review-prompt.md:157-159` tells the reviewer to *let plans
through*. Nobody reviews plan adequacy. Twenty requirements can be "covered" by
100 lines of code, all-green, with honest PR bodies.

Add `GS-7`: `deliver-phase.sh:188` derives a plan's slug from the **filename**
while `plan-resolve.sh` uses the front-matter `slug:` field, and "built" is
`grep -qE "^feat/.*${slug}"` against merged branch names. A plan named `sync.md`
is silently considered built by an earlier `feat/sync-index-1`. No PR is ever
opened for it, so no gate ever gets a chance.

**Plan alignment:** the plans built exactly this and never claimed otherwise —
`coverage.sh`'s own header says covered means planned, not delivered, and
`AGENTS.md:240` says "everything merged" is a statement about the queue. Three
separate places worry about this posture; no mechanism addresses it. The reviews
turn a documented caveat into a traced, reachable, green-CI bypass.

### Root B — The vision is unenforceable as a tiebreaker
**DS-2, DS-3, DS-5, DS-6, DS-7, DS-8, GS-H2**

`docs/VISION.md` is the declared tiebreaker and the owner's only mid-run
steering lever. The oracle **does** read it (`oracle.md:54`, step 1). **Nothing
checks what the oracle then says about it.**

- `oracle-decisions.sh:213` verifies that the "Vision statement relied on" field
  contains a `"` character. That is the entire check. Verified in fixture: the
  value `"s"` passes, with `Alternatives considered: (none)`, **in a repository
  containing no `docs/VISION.md` at all**.
- `review.sh` never puts `docs/VISION.md` in the reviewer's payload.
- The oracle writes the decision, picks the evidence, picks the vision sentence,
  and writes its own rationale. **The party that wants the change is the only
  party that evaluates whether the vision supports it.** The
  separation-of-duties argument in `orchestration.md:58` separates deciding from
  *commissioning*; the separation that matters here is deciding from
  *adjudicating*, and there is none.
- **Core tenets are not stops.** A tenet halt and an oracle finding nothing
  worth doing produce the identical artifact — no decision — and
  `record_dismissed_evidence` marks the evidence processed either way. A
  perfectly sharp tenet has the same mechanical footprint as a vague one:
  nothing. Sharper tenets make stops *more likely*, so they make the silent
  path *more* trafficked.
- **Deleting `docs/VISION.md` is documented as opting out of the oracle. It does
  not.** The oracle still runs, still rules, and still writes a vision field —
  now quoting a file that is not in the tree.
- When the two documents genuinely conflict, **the design wins structurally**,
  because the design is immovable (owner-owned) and the vision is the one the
  oracle is permitted to interpret. No artifact anywhere records the conflict.
- `DS-2`'s worked example: a six-word fragment lifted from *"I would trade any
  feature for a design I can hold in my head"* is used to justify **adding**
  complexity. The fragment inverts the sentence. The ledger reads as a clean
  derivation from the owner's own words.

**Plan alignment:** the merged plan's Phase 3 deliberately widened what the
oracle may decide (the *no-vision* class with mandatory alternatives). The
`unattended-operation` context document flagged the exact residual risk in
advance and asked a reviewer to judge whether mandatory-alternatives was
sufficient countermeasure. **`DS-2` and `DS-3` are that judgment, and the answer
is no.**

**Owner's ruling (R4, R5) reframes this root entirely.** The risk is accepted on
purpose. Every fix below is now a *camera*, not a gate — see Part 4, D6.

### Root C — The perimeter has two holes
**GS-2, GS-6, GS-H6, T3, and N-1**

`gate-seams` notes that five of its twelve findings share one root:
`CODEOWNERS.jinja:60`'s deliberate release of `docs/plans/oracle/` (a considered
trade, well argued in the file) combined with `:69`'s failure to extend past
`settings.json` into `.claude/`.

- **The entire unattended driver is outside every gate-path list.** CODEOWNERS,
  review criterion 5, and `AGENTS.md`'s own "gate paths are off-limits" list all
  enumerate `.github/` and stop. `.claude/scripts/deliver-loop.sh` holds
  `ORCH_TOOLS` — the tool grant every orchestrate session runs under — and
  `.claude/commands/*.md` are read at dispatch time and become the literal
  prompts of unattended agents. A 3-line `chore/` branch adding
  `Bash(gh pr merge:*)` to that list is under the 50-line cap, matches no
  CODEOWNERS rule, and merges green. *(Amplifier: the cap sums `git diff
  --numstat`, which prints `-` for binary files; awk sums that as 0.)*
- **`docs/BACKLOG.md` is the left-hand side of the authority chain's first
  arrow, and it is unowned, un-append-only, and read by nothing but a
  `grep -oE 'BL-[0-9]+'`.** `escapes.md` got an append-only enforcer (`ESC-15`);
  the backlog did not. So a planner can file `BL-7` in one PR and, two PRs
  later, the pipeline amends the design layer on evidence it authored itself
  forty minutes earlier — every check green, nothing indicating provenance.

**Plan alignment:** the un-owned oracle path is `C4` of the merged plan, adopted
deliberately so unattended plans can land. `.claude/` looks like the same class
of oversight `ESC-22` already records for `docs/VISION.md` — a path added after
the list that names paths.

**Owner's ruling (R3) rejects the backlog approval gate**; see Part 4, D4. The
provenance half survives as a camera.

### Root D — The review gate is starved, and nothing validates it
**GS-11, GS-8, GS-12, GS-10, plus the assessment's gap (a)**

The gate is asked questions whose inputs it is not given. It *can* read files —
`review.sh:214` grants `Read,Grep,Glob` — but two separate things defeat that:
some facts are not files at all, and its own brief tells it the standards it
judges by are the base-commit copies it was handed.

- Criterion 1 asks whether an exempt branch is carrying real work — the reviewer
  is **never told the branch prefix**, and `review.sh:165-170` explicitly offers
  it the alternative reading that "the plan check has failed separately".
- Criterion 2 asks about blind test authorship — nothing says whether the change
  was orchestrated.
- Criterion 5 asks it to block "an agent-opened diff" touching DESIGN/VISION —
  **the PR author login is not passed.**
- `review.sh:44-49` excludes lockfiles *on the stated grounds that
  `plan-metrics.sh` reports them*. **It does not** — `deps_at()` reads
  `pyproject.toml`/`project.yml` and never opens `uv.lock`, and `NEW_FILES` uses
  `--diff-filter=A` so a *modified* lockfile is invisible to both.
- Past 400 KB the reviewer reads the **20 smallest changed files**, and the
  author controls that selection.
- **The review gate is the only load-bearing gate with no fixtures.** Nothing
  checks that the reviewer actually BLOCKs a gate-tampering diff.

### Root E — Test integrity reports success by not running
**GS-3, GS-4**

`ci.yml.jinja` twice takes deliberate care to avoid job-level `if:` because "a
skipped job counts as PASSING for a required check" — then hands the same power
to a script-level `exit 0`, which is indistinguishable to branch protection.
`test-the-tests` skips unless the diff touches **both** hardcoded directories
(`src`/`tests` or `Sources`/`Tests`), so a PR with no tests at all, or one whose
code lives in `pkg/`, reports a green check. `plan-metrics.sh` computes its
test:impl ratio from the same two directory names, so it *corroborates* the
wrong picture rather than contradicting it.

And `Blind-Tests:` is a self-asserted commit trailer, presented to the reviewer
inside the block labelled "Nobody wrote it, and nothing in the diff can
influence it."

### Root F — Two supply-chain seams
**GS-9, T2**

`template-sync.sh` compares `_commit` between base and head and **never compares
`_src_path`** — the template repository the replay runs against is chosen by the
pull request's own answers file, then run with `copier update --trust` (which
executes `_migrations`), after the workflow has installed a global git
credential rewrite carrying `TEMPLATE_TOKEN`. `plan-resolve.sh` steps aside by
prefix, `test-the-tests` skips by prefix, and the review gate is told by the
`TEMPLATE SYNC:` note that provenance is mechanically settled. All four defer to
one comparison that does not happen. One line closes it.

Separately, T2: `AGENTS.md:212` says "No new dependencies without the owner's
approval — ask first, **in chat**", and `:251` says "**Chat is not storage.**"

### Root G — Nothing has been observed
**The 5 unverified-live items; the assessment's gap (d)**

Three separate reviews independently reached the same conclusion about the next
action: running one real project through the loop is worth more than any fix on
any list.

The counterweight, which those reviews could not see because they predate this
reconciliation: **Roots A and the §1.4 cluster mean a live run can exit 0 having
built almost nothing and tell you it succeeded.** A live run right now measures
the merge cycle honestly and measures *delivery* not at all.

### Root H — Six findings no review contained *(new in revision 2)*

Verified directly against the code and, where noted, against the live CLI.

**N-1 — The permission model is inverted.** `ORACLE_TOOLS`
(`spawn-worker.sh:204`) is correctly narrow: `Write(docs/DESIGN.oracle.md)`,
`Edit(docs/DESIGN.oracle.md)`, `Write(docs/oracle/**)`. It cannot touch
`docs/DESIGN.md`. But `ORCH_TOOLS` (`deliver-loop.sh:104-109`) is bare
`Write,Edit` — **every path in the repository** — under
`--permission-mode acceptEdits`. So the orchestrator can write `docs/DESIGN.md`
and `docs/VISION.md` while the oracle cannot. The role the owner intended to
constrain most is the only one carrying a leash. This is the mechanism behind
`GS-10` step 3, stated as its own finding because the owner's ruling (R1, R2)
makes it load-bearing.

**N-2 — The budget ceiling has never worked, and cannot work as written.**
`budget-probe.sh:51` runs `claude usage --json`. Verified live in this
container: `--json` returns `error: unknown option '--json'`, and there is **no
`usage` subcommand at all** — bare `claude usage` treats the word as a prompt
and opens a chat. The probe therefore always fails and always falls back to
`--max-prs` and `--max-hours`. **The one ceiling the owner specified is the one
that does nothing; the two they never chose are the only ones running.** The
script's own header flags the surface as unverified, honestly. Upgrade from
*unverified* to *disproven*.

**N-3 — The probe reads the wrong window.** `deliver-loop.sh:176` extracts
`session=` — the 5-hour window. The owner's ruling is **weekly**. Separately,
the 5-hour window resets mid-run and makes the delta go negative; the 7-day
window rarely does, so the ruling is also the more robust choice.

**N-4 — There are three limits and only one is read.** A real reading returns
`Session (5-hour)`, `Weekly (all models)` and `Weekly (Fable)`. The oracle runs
on Fable 5 (`DECISIONS.md` model tiers), which has its **own separate cap**. A
run can exhaust the Fable weekly limit while the all-models number still looks
healthy, and stop dead for a reason no configured limit predicted.

**N-5 — Probing costs budget.** `deliver-loop.sh:303` re-probes **every
iteration**. The working headless command, `claude -p "/usage"`, starts a small
session to answer. At the 20-iteration default that is 21 sessions spent
measuring spend. `omarchy-agent-usage-claude --limits-only --force` reads
Anthropic's endpoint directly and costs nothing; it belongs in
`BUDGET_PROBE_CMD`. The reading is also cached for 15 seconds, so `--force` is
required or two consecutive probes return an identical number.

**N-6 — The usage numbers are account-wide.** They include work done on other
machines and on claude.ai. That makes them wrong for "what did this run cost"
and **right** for "how much of my quota may this run spend", which is what the
owner asked for. The per-run cost, if wanted, comes from the session transcript
under `~/.claude/projects/`, and is a separate report line rather than a stop.

**One piece of good news in this root.** `ORCH_TOOLS` is a **whitelist**, and
`Bash(claude:*)` is not on it. The orchestrator therefore cannot invoke `claude`
at all — it cannot run `/design`, `/usage`, or any other command. Its single
door to starting an agent is `Bash(.claude/scripts/spawn-worker.sh:*)`. A
whitelist cannot be dodged by quoting or aliasing the way a blocklist can. This
holds only while `.claude/` is un-editable by the pipeline (Root C) and while
`spawn-worker.sh` refuses `--role architect`, which is why those two fixes
belong together.

---

## Part 3 — The handoff reconciliation

`gate-seams` handed six content-dependent threads to `document-shape`. Neither
side has ever checked whether they were answered. They were not, entirely.

| Thread | Question handed off | Answered? |
| --- | --- | --- |
| **H1** — `vision-complete.sh`'s emptiness predicate is one non-blank line per section; `TBD` passes | Does the VISION skeleton's prompting make a one-token fill a plausible good-faith outcome? | **Partially.** DS-6 and DS-8 answer the *deletion* half thoroughly. The "a competent author writes `TBD`" case was never constructed — the brief's ban on self-sabotaging pairs pushed away from it. |
| **H2** — the vision field is validated by a `"` character | Is a fragment-level quote distinguishable from a sentence-level one by any document rule? | **Yes, fully.** DS-2, verified in fixture: `"s"` passes. And DS-2 answers the sharper version — a six-word fragment **inverts** the sentence it came from and reads as a clean derivation. |
| **H3** — requirement granularity sets the whole coverage bar | Does the DESIGN template force requirements at a granularity one 100-line plan cannot swallow? | **Yes, fully.** DS-1: no, and §5 says nothing about atomicity. *"A template defect, not a document defect."* |
| **H4** — §13 `S<n>` ids are read by nothing | Is there a document shape a future mechanical check could key on? | **Yes, fully.** DS-1 + DS-4 + "shapes that hold" #2: an `R`→`S` back-reference, because `docs/acceptance.md` is the one CODEOWNERS-owned artifact. Named **the single highest-leverage document property in the system**. |
| **H5** — plan estimates set the only scope tripwire, and the plan sets them | Is there a document-shape counterpart that makes an inflated estimate legible? | **Not answered.** No `document-shape` finding addresses estimates. Still open. |
| **H6** — `docs/BACKLOG.md`'s "Approved" section is described as an authorisation and read by no gate | What should a token in "Approved" authorise, and should the boundary be machine-readable? | **Not answered** by the review — and **partly ruled** since: R3 says the boundary must not become a gate. What "Approved" now means is an open question. |

**Net:** three answered fully, one partially, **two never picked up**.

---

## Part 4 — The decision register, and what each became

Revision 2 records outcomes. The rulings themselves are Part 5; this is what
they mean for the code.

### Decided

**D1 — sequencing. → Superseded by R9.** The original recommendation was three
small fixes, then a live run. The identity ruling (R9) makes the App the first
piece of work instead, because without it `owner-authored.sh` is a formality and
an unattended run is not safe. The three small fixes stay; they moved down one
tier, not out.

**D2 — `template-sync.sh` must compare `_src_path`. → Yes (R6).** Both fields
checked; fail if `_src_path` changed. Plus R7: agents may not grant themselves
repository access. Two different layers, both built.

**D3 — the `review.sh` lockfile comment. → Fix the code, not the claim.** Keep
lockfile *text* out of the reviewed diff; let the *filename* through in the
numstat summary so `New dependencies: none` stops being a false statement.

**D4 — the perimeter. → Partly reversed (R3).** Locking `.claude/` and making
the backlog append-only with numbered entries plus a separate append-only
done-log: **build**. The "only `Approved` items may be cited" gate: **rejected**,
because it puts the owner back in the loop at 03:00 and defeats unattended
operation. The provenance line — who filed this evidence, in which PR — survives
as a camera and carries what the gate would have carried.

**D5 — Root A, "covered" must mean something. → Document layer now, mechanical
half still open.** `DS-1`'s fix (every `R` names the `S<n>` that would notice its
absence; §13 back-references) is free and routes the failure into the one
artifact the owner must approve. Owning `docs/plans/oracle/` is rejected for the
same reason as D4. A mechanical adequacy check remains undecided — the
non-functional-requirement case (a platform or offline requirement no slice ever
owns) has to be solved first.

**D6 — Root B, the vision field. → Cameras, not gates (R4, R5).** Build: `V<n>`
ids on vision statements; whole sentences required in the ledger; a two-line
`grep -qF` of the quoted span against the base-commit `docs/VISION.md`, failing
closed when the file is absent; `DS-3`'s eighth schema field ("Vision statements
**against**"); `DS-5`'s HALT entries; evidence provenance; a digest that reaches
the owner. Only the quote check can block anything, and it blocks only a
decision quoting words the owner never wrote — which is never legitimate work.

**D7 — tenet halts become ledger entries. → Yes.** Folded into D6.

**D8 — `test-the-tests` skipping. → Report, never fail (R8).** Print the skip and
its reason into the MECHANICAL FACTS block; add a reviewer criterion asking
whether code-without-tests is justified. Do **not** fail the check: legitimate
refactors, renames and dead-code deletions change code and no tests, and
blocking them produces junk tests rather than more testing. This follows the
template's own doctrine that semantic checks beat syntactic ones. Also fix the
hardcoded `src`/`tests` assumption.

**D9 — reviewer eval fixtures. → Still open.** Not yet discussed with the owner.

**D10 — T1, executable acceptance criteria. → Still open.** Not yet discussed.
`DS-4` strengthens the case: the narrator also picks which rows it must narrate.

**D11 — T2, dependency rulings as repo artifacts. → Build.** One `AGENTS.md`
sentence, one review-prompt clause, reusing `DECISIONS.md`/`BL-<n>`. No separate
`DEPENDENCIES.md`.

**D12 — T3, the gate-path backstop. → Build the cheap version.** Run the
`codeowners/errors` probe `unattended-ready.sh` already uses as a CI step, rather
than porting a second protected-path list that can drift.

**D13 — the live run. → After identity and permissions.** `--max-prs 3`,
watched, on a real project. Blocked on the GitHub App existing (R14).

### New decisions taken in revision 2

**D14 — the architect role. → Build (R2).** A role whose grant is
`Write(docs/DESIGN.md)`, `Write(docs/VISION.md)` plus read; no other role holds
those paths; `spawn-worker.sh` refuses to spawn it, so it exists only in the
owner's interactive session. The role name is documentation — the enforcement is
the path list plus D15.

**D15 — driver identity. → Build (R9, R14).** `mechanical_pr()`
(`deliver-loop.sh:183-193`) currently runs `gh pr create` under the owner's local
credentials, so `github.event.pull_request.user.login` is the owner and
`owner-authored.sh:89` passes for every driver-opened PR. Open driver PRs as the
GitHub App instead. Then an `app[bot]` PR touching `docs/DESIGN.md` or
`docs/VISION.md` **fails**, and a browser-opened PR passes. The check becomes
real for the first time. Build the path dormant; refuse the run loudly when the
App is absent or cannot authenticate.

**D16 — the budget system. → Rebuild (R10–R12).** Read all three limits and stop
when any passes its allowance. Use the weekly window. Detect the environment by
*probing the gauge* rather than guessing: if the probe returns numbers it is a
terminal, if it fails it is web. Ask the owner every run — terminal: what
percentage of the weekly limit may this run spend; web: which of pull requests,
iterations or wall-clock hours, with exact numbers, at least one required. No
silent defaults. Snapshot the reset timestamp and discard a reading whose window
rolled over. Prefer `omarchy-agent-usage-claude --limits-only --force` via
`BUDGET_PROBE_CMD`; fall back to parsing `claude -p "/usage"`.

**D17 — readiness UX. → Build (R13).** Print `Checking whether this repo can run
unattended…` before the run; on failure print an unmissable block listing every
failed item and its fix; on success print a clear all-clear. The check already
refuses on 11 conditions and notes on 5; missing App identity moves from note to
refuse.

### Still open, in priority order

1. **D5's mechanical half** — an adequacy check comparing `covers:` to slices.
2. **D10 / T1** — success criteria as runnable tests.
3. **D9** — fixtures that test the reviewer itself.
4. **H5** — making an inflated plan estimate legible.
5. **H6** — what `docs/BACKLOG.md`'s "Approved" section means now that it is not
   a gate.
6. **Whether the missing-App refusal gets a testing override.** Recommendation:
   no. Attended mode needs no App, and an override on a security control becomes
   the normal way to run it.

---

## Part 5 — The owner's rulings

Taken 2026-08-17. Verbatim where quoted. These supersede any contrary
recommendation earlier in this document.

**R1 — The oracle's reach.** *"oracle can only write to (append only)
docs/DESIGN.oracle.md. oracle should never be able to edit in any way DESIGN.md,
that is solely for me."* Read access to `docs/DESIGN.md` is explicitly granted:
*"the oracle needs to know what is in design.md"*. This confirms the
implementing session's interpretation, which its context document called the
single most consequential reading on the branch. **The question is closed.**

**R2 — Who may write the vision and the design.** A new **architect** role writes
both, and only when the owner invokes `/design`. *"the orc does not have and will
never ever have write access in any way on the design and vision doc."* The
owner still opens the pull request. Note the history this must not repeat:
`ESC-24` records that "no agent may edit it" once made `docs/VISION.md`
impossible to fill in, and `ESC-25` records that the opposite fix went too far.
The architect role is the boundary neither wording found.

**R3 — No approval gate on the backlog.** Rejected, in the owner's reasoning:
*"if the priority is that the agents need to be able to run unattended after the
design doc and vision doc is created, is this not a bug that one cannot solve
without letting the oracle have rights to make these decisions."* A coder that
hits a bad spec must be able to file evidence, and the oracle must be able to
rule on it. That is the main path, not an attack.

**R4 — Oracle drift is an accepted risk.** *"i am accepting the risk that the
oracle might cause drift (and only the oracle) in order to gain the benefits of
unattended development."* Deliberately scoped to one role so that a drifting
project has one suspect: *"if it is other agents that causes the drift, then we
have a different kind of bug that has more to do with the architecture and the
permissions."*

**R5 — The vision doc is an experiment, and needs instrumenting.** *"my plan
would be to use that failure information to further refine the vision doc, or
implement other gates or tests to prevent the oracle from straying off course."*
This is why Root B's fixes are cameras. The experiment cannot run while the
oracle is both unsupervised **and** unobservable, which is its state today.

**R6 — `template-sync.sh` checks both fields.** `_commit` **and** `_src_path`.

**R7 — Agents may not grant themselves repository access.**

**R8 — `test-the-tests` reports, never fails.** The skip and its reason go to the
reviewer. A script cannot tell a refactor from a dodge; a reader can.

**R9 — The driver gets its own identity.** The owner's question — *"the agents
can do pr's as me? what do you mean? can we have a different driver, like
claude-driver or something?"* — is the fix. Driver-opened pull requests come
from the GitHub App, not from the owner's credentials.

**R10 — The rate limit is the only default stop.** *"the orc is never supposed to
stop themselves due to any other limit than the rate limit i specified."* Pull
requests, iterations and wall clock remain available, opt-in, for testing runs
where an early answer is all that is wanted.

**R11 — Anomaly limits are signals, not stops.** A coding agent making twenty
commits for simple work is *"a strong signal that something has gone wrong"* —
it belongs in the report, and it must never halt a run.

**R12 — Ask about limits every single run.** Terminal: *"how many percent of your
weekly limit are you willing to spend?"* Web: *"do you want a limit on
pull-requests, counts, or wall clock, or any combination? specify exact
numbers."*

**R13 — Readiness blocks, loudly.** *"if the script says the repo answers that
the repo is not ready to run unattended, then block and fail very loudly. i
really need to know before i go."* With a visible "verifying…" message first, and
an explicit all-clear so the owner knows they can walk away.

**R14 — The App path ships dormant, with a loud failure.** *"yes please build the
code path, but also build in a loud failure if the github app does not connect
properly or does not exist. i will not set up the github app now, so we need the
reminder when the time comes."* Consequence, accepted knowingly: no unattended
run is possible until the App exists. Attended mode is unaffected.

**R15 — Silence means assent.** *"if i say nothing about certain points, that
means that i agree… if i am arguing or adding info, then those points still need
revising."*

### Corrections the owner supplied

Recorded because this document was wrong and the record should say so.

- **`/usage` does have a headless surface.** This document's first revision
  concluded none existed. That conclusion came from testing the command the
  script uses (`claude usage --json`, genuinely broken) and generalising. The
  owner supplied two working readers: `claude -p "/usage"`, and
  `omarchy-agent-usage-claude --limits-only`. N-2 stands; the generalisation
  did not.
- **The backlog approval gate.** Recommended in revision 1, rejected in R3, and
  the rejection is correct.

---

## Appendix — finding index

| Finding | Rank | Root | Decision |
| --- | --- | --- | --- |
| GS-1 "Done" is one front-matter field and one substring match | 1 | A | D5 |
| GS-2 The unattended driver is outside every gate-path list | 2 | C | D4 |
| GS-3 `test-the-tests` reports success by not running | 3 | E | D8 |
| GS-4 `Blind-Tests:` is a self-asserted trailer in the "trustworthy" block | 4 | E | D8 |
| GS-5 Acceptance marker written before the session runs | 5 | A / §1.4 | D1 |
| GS-6 The evidence authorising design amendments is pipeline-written | 6 | C | D4 (camera half only) |
| GS-7 A plan is "built" by a substring of a branch name | 7 | A | D1 |
| GS-8 `review.sh` says `plan-metrics.sh` reports lockfiles; it does not | 8 | D / F | D3 |
| GS-9 `template-sync` verifies against a template the PR chooses | 9 | F | D2 |
| GS-10 `owner-authored.sh` checks who *opened* the PR | 10 | D | **D15** |
| GS-11 The review payload omits the facts criteria 1, 2, 5 are keyed on | 11 | D | D3 / open |
| GS-12 Past 400 KB the reviewer reads the 20 smallest files | 12 | D | open |
| DS-1 A plan can claim ids it does not deliver | 1 | A | D5 |
| DS-2 The vision field verifies a `"` character | 2 | B | D6 |
| DS-3 The proponent is the sole adjudicator | 3 | B | D6 |
| DS-4 The acceptance agent picks which rows it need not check | 4 | A / §1.4 | D10 (open) |
| DS-5 A tenet stop and a dismissal are the same artifact | 5 | B | D6 / D7 |
| DS-6 Deleting `VISION.md` does not opt out of the oracle | 6 | B | D6 |
| DS-7 Conflict resolves silently in the design's favour | 7 | B | D6 |
| DS-8 Deleting a vision section removes a capability, announced nowhere | 8 | B | D6 |
| DS-9 The interview's six consistency properties are verified by nothing | 9 | B | D6 (doc half) |
| DS-10 The acceptance branch's size cap is set by design size | 10 | A / §1.4 | D1 |
| **N-1 The permission model is inverted** | — | H | **D14 / D15** |
| **N-2 The budget ceiling has never worked** | — | H | **D16** |
| **N-3 The probe reads the session window, not weekly** | — | H | **D16** |
| **N-4 Three limits exist; one is read** | — | H | **D16** |
| **N-5 Probing costs budget** | — | H | **D16** |
| **N-6 Usage numbers are account-wide** | — | H | **D16** |

Transfers: T1 → D10 (open), T2 → D11, T3 → D12, T4 → opportunistic. Assessment
gaps: (a) reviewer fixtures → D9 (open), (b) stale acceptance rows → D10 (open),
(c) validation — no action, (d) live run → D13.

### Build order

1. **Identity** — driver opens PRs as the App; loud refusal when it is absent (D15).
2. **Permissions** — architect role; path lists on every role; `.claude/` locked;
   backlog numbered + append-only + done-log (D14, D4).
3. **Small safe fixes** — `_src_path`; the acceptance marker; the slug match; the
   two missing planning paths (D2, D1).
4. **Budget and readiness** — the whole of D16, plus D17.
5. **Oracle cameras** — D6 and D7.
6. **"Done" means built** — D5's document half.
7. **Reviewer** — D3, D11, D12, and the skip reason from D8.
