# Synthesis — the plans and the reviews, reconciled

A working document, not a record. It exists to be walked top to bottom once,
with decisions taken at the bottom. Nothing here is authorization: as
`docs/reviews/README.md` says, a finding becomes binding when it becomes an
`ESC-<n>` row and the check that row names.

- **Written:** 2026-08-17, against `claude/copier-template-automation-rii78u` @ `b56ed76`
- **Covers:** `docs/plans/` (2 plans + 2 context documents) and `docs/reviews/`
  (5 sessions, 14 distinct documents — `testbed-vs-template-report.md` and
  `comparative-report.md` are byte-identical copies of one file)
- **Source material:** ~63,000 words. This is ~6,000.

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
same kind the reviews were sent to check.

The five unverified-live items, unchanged and still unobserved:

1. A branch actually vanishing under the App token (would close `ESC-21`, which
   has now been closed and reopened around **four** wrong theories, and **no
   branch has ever been seen to disappear, under any identity**).
2. REST ruleset creation before checks first report.
3. `budget-probe.sh` against a real subscription.
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

Nineteen of the twenty-two findings are the same defect wearing different
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

Twenty-two traced findings collapse into seven roots. Ranked by how quietly each
reaches you, which is the standard both reviews were given. `GS-n` =
`gate-seams`, `DS-n` = `document-shape`.

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
turn a documented caveat into a traced, reachable, green-CI bypass, which is the
one thing the briefs said counted.

### Root B — The vision is unenforceable as a tiebreaker
**DS-2, DS-3, DS-5, DS-6, DS-7, DS-8, GS-H2**

`docs/VISION.md` is the declared tiebreaker and your only mid-run steering
lever. **No mechanism reads its contents against anything.**

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
  oracle is permitted to interpret. No artifact anywhere records that a conflict
  existed.

**Plan alignment:** the merged plan's Phase 3 deliberately widened what the
oracle may decide (the *no-vision* class with mandatory alternatives). The
`unattended-operation` context document flagged the exact residual risk in
advance — routing preference questions to the oracle is cheaper than asking you,
and "the failure mode is a design ledger full of decisions the owner never made,
each formally well-formed" — and asked a reviewer to judge whether
mandatory-alternatives was sufficient countermeasure. **`DS-2` and `DS-3` are
that judgment, and the answer is no.**

### Root C — The perimeter has two holes
**GS-2, GS-6, GS-H6, T3**

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
  the backlog did not. The steward role has an explicit write grant for it. So a
  planner can file `BL-7` in one PR and, two PRs later, the pipeline amends the
  design layer end-to-end on evidence it authored itself forty minutes earlier —
  every check green, nothing indicating the provenance.

**Plan alignment:** the un-owned oracle path is `C4` of the merged plan, adopted
deliberately so unattended plans can land. `.claude/` looks like the same class
of oversight `ESC-22` already records for `docs/VISION.md` — a path added after
the list that names paths.

### Root D — The review gate is starved, and nothing validates it
**GS-11, GS-8, GS-12, GS-10, plus the assessment's gap (a)**

The gate is asked questions whose inputs it is not given:

- Criterion 1 asks whether an exempt branch is carrying real work — the reviewer
  is **never told the branch prefix**, and `review.sh:165-170` explicitly offers
  it the alternative reading that "the plan check has failed separately", which
  makes declining to judge the reasonable choice.
- Criterion 2 asks about blind test authorship — nothing in the payload says
  whether the change was orchestrated.
- Criterion 5 asks it to block "an agent-opened diff" touching DESIGN/VISION —
  **the PR author login is not passed.**
- `review.sh:44-49` excludes lockfiles from the diff *on the stated grounds that
  `plan-metrics.sh` reports them*. **It does not** — `deps_at()` reads
  `pyproject.toml`/`project.yml` and never opens `uv.lock`, and `NEW_FILES` uses
  `--diff-filter=A` so a *modified* lockfile is invisible to both. The reviewer
  is told "New dependencies: none" about a changed transitive dependency it
  cannot see. This is the cross-reference the brief asked to check character by
  character, and it is wrong.
- Past 400 KB the reviewer reads the **20 smallest changed files**, and the
  author controls that selection.
- And the assessment's own gap: **the review gate is the only load-bearing gate
  with no fixtures.** `test-the-tests` validates the tests, the offline suite
  validates the scripts; nothing checks that the reviewer actually BLOCKs a
  gate-tampering diff. One judgment failure plus auto-merge equals a silent gate
  breach.

### Root E — Test integrity reports success by not running
**GS-3, GS-4**

`ci.yml.jinja` twice takes deliberate care to avoid job-level `if:` because "a
skipped job counts as PASSING for a required check" — then hands the same power
to a script-level `exit 0`, which is indistinguishable to branch protection.
`test-the-tests` skips unless the diff touches **both** hardcoded directories,
so a PR with no tests at all, or one whose code lives in `pkg/` instead of
`src/`, reports a green `test-the-tests` check. `plan-metrics.sh` computes its
test:impl ratio from the same two directory names, so it *corroborates* the
wrong picture rather than contradicting it.

And `Blind-Tests:` is a self-asserted commit trailer, presented to the reviewer
inside the block labelled "Nobody wrote it, and nothing in the diff can
influence it." A coder writing code and tests together and adding the trailer
produces the affirmative sentence "Every blind-written test is unmodified since
its authoring commit."

### Root F — Two supply-chain seams
**GS-9, T2**

`template-sync.sh` compares `_commit` between base and head and **never compares
`_src_path`** — the template repository the replay runs against is chosen by the
pull request's own answers file, then run with `copier update --trust` (which
executes `_migrations`), after the workflow has installed a global git
credential rewrite carrying `TEMPLATE_TOKEN`. `plan-resolve.sh` steps aside by
prefix, `test-the-tests` skips by prefix, and the review gate is told by the
`TEMPLATE SYNC:` note that provenance is mechanically settled. All four defer to
one comparison that does not happen. **Marked CONDITIONAL** by the reviewer on
copier's `_tasks`-during-update behaviour; the `_migrations` path is documented
and sufficient. One line closes it.

Separately, T2: `AGENTS.md:212` says "No new dependencies without the owner's
approval — ask first, **in chat**", and `:251` says "**Chat is not storage.**"
The template contradicts its own recorded maxim at exactly the point a future
session most needs the record.

### Root G — Nothing has been observed
**The 5 unverified-live items; the assessment's gap (d); the comparative
report's closing note**

Three separate reviews independently reached the same conclusion about the *next
action*: running one real project through the loop is worth more than any fix on
any list. The template's own epistemics — "a check must be observed working, not
inferred", stated six independent times — apply to the template itself.

The counterweight, which those reviews could not see because they predate this
reconciliation: **Roots A and the §1.4 cluster mean a live run can exit 0 having
built almost nothing and tell you it succeeded.** A live run right now measures
the merge cycle honestly and measures *delivery* not at all.

---

## Part 3 — The handoff reconciliation

`gate-seams` handed six content-dependent threads to `document-shape`. Neither
side has ever checked whether they were answered. They were not, entirely.

| Thread | Question handed off | Answered? |
| --- | --- | --- |
| **H1** — `vision-complete.sh`'s emptiness predicate is one non-blank line per section; `TBD` passes | Does the VISION skeleton's prompting make a one-token fill a plausible good-faith outcome? | **Partially.** DS-6 and DS-8 answer the *deletion* half thoroughly. The specific "a competent author writes `TBD` and the gate passes" case was never constructed — the brief's ban on self-sabotaging pairs pushed away from it. |
| **H2** — the vision field is validated by a `"` character | Is a fragment-level quote distinguishable from a sentence-level one by any document rule? | **Yes, fully.** DS-2, verified in fixture: `"s"` passes. And DS-2 answers the sharper version — a *six-word* fragment lifted from Pair F **inverts the sentence it came from** and reads as a clean derivation. Fix: `V<n>` ids + full-sentence requirement. |
| **H3** — requirement granularity sets the whole coverage bar | Does the DESIGN template force requirements at a granularity one 100-line plan cannot swallow? | **Yes, fully.** DS-1: no, it does not, and §5 says nothing about atomicity. Holds for the narrow-deep pairs, fails for the ordinary broad one — *"a template defect, not a document defect."* |
| **H4** — §13 `S<n>` ids are read by nothing | Is there a document shape a future mechanical check could key on? | **Yes, fully.** DS-1 + DS-4 + "shapes that hold" #2: an `R`→`S` back-reference, because `docs/acceptance.md` is the one CODEOWNERS-owned artifact, so an over-claimed `covers:` becomes a visible empty evidence cell instead of a green coverage line. Named **the single highest-leverage document property in the system**. |
| **H5** — plan estimates set the only scope tripwire, and the plan sets them | Is there a document-shape counterpart that makes an inflated estimate legible — a stated per-slice ceiling? | **Not answered.** No `document-shape` finding addresses estimates. Open thread. |
| **H6** — `docs/BACKLOG.md`'s "Approved" section is described as an authorisation and read by no gate | What should a token in "Approved" authorise, and should the boundary be machine-readable? | **Not answered.** Open thread — and `GS-6` shows it is load-bearing, since the backlog is the authority chain's first input. |

**Net:** three answered fully, one partially, **two never picked up** — and one
of the two (H6) sits directly under Root C.

---

## Part 4 — The decision register

Ordered so the cheap irreversible-to-skip things come first. Each is a real
choice; my recommendation is stated, not hidden.

### Tier 1 — Do before anything else (all small, all block the live run's honesty)

**D1. Do we fix the three "silent success" defects before the first live run, or run first?**
Every review says run live next. But `GS-5` (acceptance marker written before
dispatch, never cleared), `GS-7` (slug substring match) and `DS-10` (acceptance
branch exceeds the 50-line cap) each independently produce **exit 0 or exit 3
with nothing built and a report that reads like success**. A live run under
those conditions cannot distinguish "the loop works" from "the loop terminated
early and said it was done".
- *Options:* (a) run live now, accept the ambiguity; (b) fix these three, then
  run; (c) fix these three plus Root A's adequacy check, then run.
- **Recommendation: (b).** The three are perhaps 15 lines total — move a
  `touch` after the dispatch and clear it at run start; compare the front-matter
  `slug:` instead of the filename, with the same collision guard
  `plan-resolve.sh` already has; add `docs/acceptance.md` and
  `docs/architecture.md` to `PLANNING_PATHS`. Not (c): Root A needs design
  thought and would delay the observation indefinitely.

**D2. `template-sync.sh` — compare `_src_path`?**
One line. Today the PR chooses which template repository CI replays under
`--trust`, with `TEMPLATE_TOKEN` in the global git config.
- **Recommendation: yes, unconditionally.** This is the only finding with a
  remote-code-execution shape, and the fix has no design content to argue about.

**D3. The `review.sh` lockfile comment — fix the code or fix the claim?**
The exclusion is justified by a cross-reference to behaviour that does not
exist.
- *Options:* (a) make `plan-metrics.sh` actually report lockfile changes;
  (b) stop excluding lockfiles from the reviewer's numstat summary; (c) correct
  the comment and accept the gap knowingly.
- **Recommendation: (b) plus corrected comment.** Keeping lockfile *text* out of
  the diff is right — it is noise. Letting the reviewer see the *filename* in
  the numstat costs one line and removes the false "New dependencies: none".

### Tier 2 — Structural, decide now, build in order

**D4. `.claude/` and `docs/BACKLOG.md`: extend the perimeter?**
Root C. Three lists (`CODEOWNERS`, review criterion 5, `AGENTS.md`'s gate-path
rule) all stop at `.github/`.
- *Options:* (a) add `.claude/scripts/`, `.claude/commands/`, `.claude/agents/`,
  `.claude/orchestration.md` to all three, plus an append-only check and a
  CODEOWNERS rule for `docs/BACKLOG.md`; (b) `.claude/` only; (c) leave, on the
  grounds the driver is template-shipped so real changes arrive via
  `template-sync`.
- **Recommendation: (a).** The cost of (a) is low precisely because of (c)'s
  reasoning — legitimate driver changes come down the template-sync path, which
  already has its exemption, so owning these paths mostly blocks the *illegitimate*
  edit. The backlog half is the more important one: it is the authority chain's
  first input and the only unprotected ledger.

**D5. Root A — how do we make "covered" mean something?**
This is the biggest decision on the page and the one I would not decide quickly.
Three genuinely different shapes:
- *(a) Document layer only.* `DS-1`'s fix: every `R` names the `S<n>` that would
  notice its absence, and §13 back-references. Moves the failure from
  `coverage.sh` (a summary line you skim) into `docs/acceptance.md` (a diff you
  must approve). Zero new machinery. Called the highest-leverage document
  property in the system.
- *(b) Mechanical adequacy check.* Something that compares a plan's `covers:` to
  its slices — e.g. every claimed `R` must be named by at least one slice's
  prose or `Files:`. Real teeth; also real false-positive risk on non-functional
  requirements (`R11` platform, `R12` offline) that no slice ever owns by
  construction, which is exactly the case `DS-1` used.
- *(c) Own `docs/plans/oracle/`.* Closes it completely and **ends unattended
  operation**, since that path exists so overnight plans can land.
- **Recommendation: (a) now, (b) designed but held.** (a) is free and routes the
  failure to the one artifact you are guaranteed to see. (c) trades away the
  whole point. (b) is right eventually but needs the non-functional-requirement
  case solved first — and one live run would tell us how often padding actually
  happens, which is better evidence than a guess.

**D6. Root B — what do we do about the vision field?**
- *Options:* (a) document-layer only — `V<n>` ids on vision statements, full
  sentences required in the ledger, plus `DS-3`'s eighth schema field ("Vision
  statements **against**", naming the statement that most nearly forbids the
  decision and why it does not); (b) (a) plus the mechanical half — a `grep -qF`
  of the quoted span against the base-commit `docs/VISION.md`, failing closed
  when the file is absent, plus adding `docs/VISION.md` to the review payload;
  (c) accept that it is advisory and **stop presenting it as a steering lever**
  in `DESIGN.oracle.md.jinja` and `AGENTS.md`.
- **Recommendation: (b).** `document-shape` was constrained to document-layer
  fixes and said so honestly: *"the field's entire value today rests on the
  document layer, and the document layer is structurally incapable of validating
  it."* The grep is roughly two lines. (c) is the intellectually honest fallback
  if we decline (b) — what we must not do is keep telling the owner the field is
  a steering lever while nothing connects the sentence they edit to the next
  decision.

**D7. Root B — do tenet halts become ledger entries?**
Today a tenet stop and an oracle shrug are the same artifact: nothing. `DS-5`
proposes a `HALTED` entry in the same append-only ledger, same id sequence.
- **Recommendation: yes.** It is the cheapest fix on this page relative to what
  it protects — the one moment the vision actually does its job is currently the
  one moment nothing records. Note it interacts with `record_dismissed_evidence`,
  which currently marks any id the newest handoff mentions as processed forever.

**D8. Root E — does `test-the-tests` skipping stay invisible?**
- *Options:* (a) report the skip into the MECHANICAL FACTS block so the reviewer
  can see the check did not run; (b) additionally fail when implementation
  changed and no test file did; (c) leave it — the skip conditions are
  documented.
- **Recommendation: (a) now, (b) considered.** (a) is nearly free and directly
  repairs a stated-but-false trust boundary. (b) is a real policy change that
  would fire on legitimate refactors; it wants an `ESC` row behind it first.

### Tier 3 — Needs your ruling, or your calendar

**D9. The reviewer eval fixtures — build, or wait for an escape?**
The assessment names this the check it would most want before trusting a long
unattended run, and flags honestly that it is speculative machinery by the
template's own ratchet doctrine.
- **Recommendation: hold as designed, build after the first live run** — unless
  we start long unattended runs before then, in which case build it first. The
  ratchet is right that speculative guardrails are slop; it is also true that
  this particular escape class is discovered by you, in use, weeks later, with
  no attribution.

**D10. T1 — executable acceptance criteria.**
Both the report and its assessment rank this the most valuable transfer, and the
assessment sharpens the argument: **the acceptance ledger is the one place in
the template where agent narration is admitted as evidence**, everywhere else
computed facts and judged verdicts are rigorously split. `DS-4` strengthens it
further — the narrator also picks which rows it must narrate.
- **Recommendation: T1-lite** — `Verified by: agent` criteria as small scripts,
  run at ACCEPTANCE phase entry, ledger cites them instead of narrating them.
  Promote to per-PR CI on the first observed regression. This also dissolves the
  assessment's gap (b), stale acceptance rows under §13 churn.

**D11. T2 — dependency rulings as repo artifacts.**
One sentence in `AGENTS.md`, one clause in the review prompt, reusing
`DECISIONS.md`/`BL-<n>`. Do **not** add a separate `DEPENDENCIES.md`.
- **Recommendation: do it now.** Cheapest unambiguous win in the corpus. Watch
  the `DECISIONS.md` cap; `BL-<n>` is the escape valve.

**D12. T3 — the gate-path backstop.**
The report proposed porting a ~40-line path-diff script; the assessment
correctly objects that it creates **two protected-path lists that can drift**.
- **Recommendation: the assessment's version** — run the `codeowners/errors`
  probe that `unattended-ready.sh` already uses as a CI step on every PR, so we
  check the platform config instead of replicating it. Verify by observation
  that an unresolvable owner really surfaces through that API before trusting
  it. Genuinely low priority: needs silent unbind **and** reviewer miss **and**
  auto-merge simultaneously.

**D13. When is the live run, and under what settings?**
- **Recommendation:** after Tier 1, with `--max-prs 3`, watched, on a real
  project. It is the only thing that closes `ESC-21` (four wrong theories, no
  branch ever observed to vanish), settles the ruleset and budget-probe
  questions, and produces the evidence D5(b) and D9 are waiting on. Also settles
  the two things both review prompts deliberately left unresolved: whether the
  deployed ruleset actually binds `require_code_owner_review`, and which
  identity `gh` carries when the driver opens a PR.

---

## Part 5 — Four things only you can answer

These come from the plans' context documents, not the reviews. They were flagged
for a reviewer and never ruled on. Two of them are load-bearing.

1. **The single most consequential interpretation on this branch.** Your words
   were *"oracle can alter the design doc"*. The implementing session read that
   as `docs/DESIGN.oracle.md` — the design *layer* — **not** `docs/DESIGN.md`,
   in order to keep `owner-authored.sh` and your steering lever intact. Its
   context document says plainly: if you meant the oracle may amend
   `docs/DESIGN.md` itself, *"that is a different (and gate-breaking) design, and
   the implementation does not do it."* Please confirm the reading.
2. **The budget numbers are not yours.** You ruled "percentage points of my
   subscription rate limit". Everything else — delta-from-run-start on the
   *session* window, **25 points**, `--max-prs 10`, `--max-hours 8` — was the
   session's design around a one-line ruling. You chose none of those figures.
3. **"Readiness refuses rather than warns" is consent by silence.** The session
   stated it would implement refuse and invited objection; you did not object.
   Both source plans agreed, so this is probably right — but it is not on record
   as your ruling.
4. **An owner answer was lost twice by the chat client mid-session.** The
   rulings were re-collected afterwards, but the context document asks
   explicitly: if any recorded ruling surprises you, ask rather than trust the
   record — there may have been nuance in the lost text that never arrived.

---

## Appendix — finding index

Every traced finding, its root, and the decision that disposes of it.

| Finding | Rank | Root | Decision |
| --- | --- | --- | --- |
| GS-1 "Done" is one front-matter field and one substring match | 1 | A | D5 |
| GS-2 The unattended driver is outside every gate-path list | 2 | C | D4 |
| GS-3 `test-the-tests` reports success by not running | 3 | E | D8 |
| GS-4 `Blind-Tests:` is a self-asserted trailer in the "trustworthy" block | 4 | E | D8 |
| GS-5 Acceptance marker written before the session runs | 5 | A / §1.4 | **D1** |
| GS-6 The evidence authorising design amendments is pipeline-written | 6 | C | D4 |
| GS-7 A plan is "built" by a substring of a branch name | 7 | A | **D1** |
| GS-8 `review.sh` says `plan-metrics.sh` reports lockfiles; it does not | 8 | D / F | D3 |
| GS-9 `template-sync` verifies against a template the PR chooses | 9 | F | **D2** |
| GS-10 `owner-authored.sh` checks who *opened* the PR | 10 | D | D13 (conditional on live run) |
| GS-11 The review payload omits the facts criteria 1, 2, 5 are keyed on | 11 | D | D3 / open |
| GS-12 Past 400 KB the reviewer reads the 20 smallest files | 12 | D | open |
| DS-1 A plan can claim ids it does not deliver | 1 | A | D5 |
| DS-2 The vision field verifies a `"` character | 2 | B | D6 |
| DS-3 The proponent is the sole adjudicator | 3 | B | D6 |
| DS-4 The acceptance agent picks which rows it need not check | 4 | A / §1.4 | D10 |
| DS-5 A tenet stop and a dismissal are the same artifact | 5 | B | D7 |
| DS-6 Deleting `VISION.md` does not opt out of the oracle | 6 | B | D6 |
| DS-7 Conflict resolves silently in the design's favour | 7 | B | D6 |
| DS-8 Deleting a vision section removes a capability, announced nowhere | 8 | B | D6 |
| DS-9 The interview's six consistency properties are verified by nothing | 9 | B | D6 (doc half) |
| DS-10 The acceptance branch's size cap is set by design size | 10 | A / §1.4 | **D1** |

Transfers: T1 → D10, T2 → D11, T3 → D12, T4 → opportunistic. Assessment gaps:
(a) reviewer fixtures → D9, (b) stale acceptance rows → D10, (c) validation —
no action, (d) live run → D13. Open threads with no decision yet: **GS-H5**
(estimate legibility), **GS-H6** (backlog "Approved" semantics — partly D4),
**GS-12** (truncation selection), **GS-11**'s payload additions.
