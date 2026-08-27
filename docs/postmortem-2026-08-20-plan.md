# Prevention plan — what the 2026-08-20 stress test demands of the template

Status: **proposal, plan only.** Nothing in this document has been implemented.
Written 2026-08-26 from the post-mortem of the two-repo delivery experiment of
2026-08-20 (grimsverk-anvil, seeded adversarially on purpose; find_best_mobo, a
good-faith project with an honestly-written design and vision). This file is
strategy: it decides *what kind* of work the template needs next and in what
order. Each workstream below becomes its own `docs/plans/<slug>.md` when it is
picked up; none of them exists yet.

**Evidence read** (all read-only, at the branches' tips on 2026-08-26):

- grimsverk-anvil `postmortem_backlog_lifecycle` @ `1a03148` — the merged
  post-mortem: `postmortem/SYNTHESIS.md` (the ranked recommendations),
  `postmortem/analysis/results.md` (40 hypotheses: 4 confirmed, 11 falsified,
  23 inconclusive, 2 not run), `postmortem/backlog-lifecycle/` (mint/retire),
  `postmortem/scout/RECON_anvil.md` and `SCOUTREPORT_find_best_mobo.md`,
  `POSTMORTEM.md` (1034-event extraction), the six qualitative arms.
- This repository: `AGENTS.md`, `docs/DESIGN.md`, `docs/VISION.md`,
  `docs/synthesis.md` (the owner's standing rulings), the shipped driver
  (`template/.claude/scripts/deliver-phase.sh`, `deliver-loop.sh`), the gate
  scripts, `docs/projects/find_best_mobo/template-bugs.md` and
  `docs/plans/first-run-defects.md` (the *previous* run's defects — TB-1..TB-7,
  planned, distinct from what this document responds to).

---

## 0. The verdict, first

**Keep the trust layer. Rebuild the loop's economy. Make the run measurable.**

The parts of the template that exist to make agent work *trustworthy* worked
under stress: the oracle's rulings resolved what they were asked (85–90% in
every qualitative arm), stayed inside the vision's authority, the append-only
ledgers held, checkpoint-and-resume survived six session kills, and the
two-lane comparison reached the same decisions from the same documents. None
of that is rebuilt.

The part that turns decisions into product — the delivery loop's *economy* —
failed completely: across a full day, four lanes, 1650 recorded events and
dozens of merged pull requests, **zero product source code survived on any
branch**. The one feature slice that was built and merged (anvil web PR
#30, +541 lines of product code) was merged under a broken gate, erased by a
force-rebuild, and reachable today from zero refs. This is not a tuning
problem in any one prompt. It is a structural property: the loop has a
design-layer attractor and no build attractor, and it holds on a good-faith
project exactly as it holds on the adversarial one.

So the answer to "rethink the architecture, or hunker down and fine-tune?" is:
**both, in a narrow sense.** Re-architect one thing — the driver's phase
economy and the contract that closes a ruling — and fortify everything else in
place. A ground-up rebuild is not warranted by the evidence and would discard
the parts that demonstrably work.

---

## 1. What the stress test established

Each finding carries its strongest evidence pointer and an honest confidence.
"Confirmed" means the hypothesis pass confirmed it mechanically; findings from
the qualitative arms or the scouts say so.

### F-A. The oracle answered well — *keep it* (all six qualitative arms)

Rulings resolved their question in 61–68 of 74 reader verdicts per arm;
"did not resolve" was 0–3 in every arm. Authority stayed within the vision in
≥65 of 74 everywhere. The owner's fear that rulings restate the question is
unsupported in every arm. (`postmortem/SYNTHESIS.md` §1.2.)

### F-B. Rulings did not become plans or code (H012 falsified in the useful direction; confirmed leak)

The count of rulings with no plan was **never zero at any phase-selection
point**. Of 58 scoped OD keys, 23 were closed by a plan (all in find_best_mobo)
and **35 were never planned at all**. No backlog item in either repository was
ever filed by a coder — the coder role essentially never ran. ORCHESTRATE
fired **once in 1650 events**, and that once was inside the round-3.2 window
where branch protection was off. (`analysis/results.md` H012, H037;
`backlog-lifecycle/analysis.md` §4, §6.)

Structural cause, visible in the shipped detector: `deliver-phase.sh` reaches
STEWARD only through a *coverage gap* — i.e. only when a ruling **added a
requirement** (R1000+). A ruling that decides something without minting a
requirement creates no downstream work the detector can see. And ORCHESTRATE
is reachable only when the *entire* design layer is quiet: any uncited id
anywhere in the ledgers routes to ORACLE first.

### F-C. The design layer is an attractor (backlog-lifecycle; confirmed pattern)

The open-uncertainty count **did** return to zero — in 7 of 7 runs that had
rulings landing, repeatedly (amplification per ruling: mean 0.71 new items in
the next two iterations; the open count never exceeded 3). The loop did not
drown in questions. What happened at every zero was worse: **each return to
zero was followed by a PLAN or STEWARD phase that filed new uncertainties
instead of producing code, or by a mechanical stop.** The queue emptied; the
loop refilled it or died. Separately, the queue *rule* — an item leaves only by
being cited from a decision — forced full rulings onto items that were already
decided (LOW items whose filer had "proceeded on the default" still got
45–78-line rulings). (`backlog-lifecycle/analysis.md` "The answer";
`SYNTHESIS.md` finding 7.)

The code and the rules also disagree here, verified against this repository:
`AGENTS.md` promises that a LOW uncertainty "proceeds on the recorded default
and the oracle reviews it next cycle" — but `deliver-phase.sh` routes *any*
uncited id to ORACLE ahead of every planning and build phase, so "next cycle"
in practice means "before anything else happens". The prose describes the
economy W1 proposes; the detector implements the one that failed.

### F-D. Rulings bound themselves to things that did not exist (five arms agree)

mobo OD-6 ordered a fixture from "BL-8's measured 52-variant set" — present in
no commit. mobo OD-7 pinned a regression to "the real B850I review's title" —
in a gitignored file. anvil local OD-1 named `acceptance/S1.sh` before it
existed. Each cost a full unattended session plus at least one further ruling
to declare a reconstruction; the two longest rulings in the mobo ledger exist
to untangle these. (`SYNTHESIS.md` §1.2 story 3.)

The same class of defect sits one layer up: the good-faith design/vision docs
themselves referenced data and artifacts that were not in any commit, and
nothing lints for that at setup time.

### F-E. One correct decision livelocked the loop, and the oracle had no brake (scout + ledger; concrete script defect)

mobo OD-13 superseded R1001 — correctly. `coverage.sh` reads
`**Requirements added:**` and nothing reads `**Requirements superseded:**`, so
R1001 stayed a coverage gap forever; the gap maps back to OD-5 every cycle;
the detector emits STEWARD for it before the plan walk, forever. OD-19..OD-22
— 27% of the mobo ledger — exist only to make the stuck driver harmless.
OD-21 states the structural point exactly: *"This does not unstick the driver —
nothing an oracle may write can."* Gate scripts are owner-owned (correctly),
so from inside the run this was terminal. The oracle knew the loop was stuck
and had no mechanism to act on that knowledge.
(`SCOUTREPORT_find_best_mobo.md` §2; `SYNTHESIS.md` finding 4.)

### F-F. Delivery mechanics burned whole rounds (recorded tier)

- Eight of nine anvil local rounds retired nothing for what the lifecycle
  analysis calls "a landing problem": the oracle's own pull request never
  landed — the same checks red three times, or `gh pr create` failing six
  times in a row (round 3.2), each failure consuming a full dispatch.
  (`backlog-lifecycle/analysis.md` §6, rounds 2.0–3.5.)
- **The shipped driver has since grown typed stops** — exit 3 (same failure
  signature three times), exit 4 (owner-action check, first strike, ESC-206),
  exit 5 (two consecutive dispatches with no pull request, ESC-66) — and the
  later ones demonstrably fired in round 3.6. **But the mobo livelock defeats
  every one of them, at today's HEAD too**: each stuck STEWARD dispatch
  *did* open a pull request (containing only a new backlog filing — PR #129,
  "Plan for OD-5", "contains no plan and only the BL-22 filing itself"), so
  `NO_PROGRESS` reset to zero every cycle, no check failed, and no signature
  repeated. The guard that is actually missing keys on the *detector*, not
  the dispatch: the same phase with the same scope emitted N times with no
  closure event in between. (Verified against
  `template/.claude/scripts/deliver-loop.sh` `note_dispatch_outcome()`.)
- The three-strikes counter is not a bound: PR #133 consumed ≥4 fix dispatches
  before exit-3 (H004, confirmed).
- The same OD dispatched twice produced two different outcomes at the same
  template version (H034, confirmed: mobo OD-6 → a backlog-only PR, then a
  plan PR, 957 s apart) — dispatch outcome is stochastic and nothing records
  the prompt that went in.
- One dispatch was killed by the account session limit, produced no commit, no
  PR and no table row, and its 1h31m hole was invisible to a git-only read
  (`POSTMORTEM.md`).

### F-G. Work and evidence were lost, silently (H024 confirmed; scouts)

Merged product code became unreachable (PR #30: merge commit in the object
store, zero refs, nothing reported it). `run/*` force-rebuilds erased
round-scoped `BACKLOG.md` / `DESIGN.oracle.md` copies — most rounds cannot be
checked at all. All 11 web review payloads for the final anvil round are
`MISSING.md` tombstones. Worker transcripts died gitignored in reclaimed
containers. A 2026-08-24 cleanup commit **edited window `run.md` files in
place**, so a branch-tip read silently returns post-hoc text.

### F-H. The loop is nearly unmeasurable as shipped (23 of 40 hypotheses inconclusive)

`pr_number` was null on all 18 dispatch rows; `ids_referenced` empty on 53 of
53 steward rows; no anvil ruling carries a byte count; the web lane has **no
machine driver log at all** — every web phase, iteration and wait exists only
as hand-typed prose; the two lanes' `run.md` formats need two different
parsers; verdict vocabulary differs (`PASS` vs `success`). More than half of
the hypothesis pass could not reach a verdict because the fields it needed
were never written. The post-mortem itself — five sessions of extraction,
reconciliation, glossing and analysis — is the price of that.

### F-I. The words were not frozen (six-arm spread)

Six independent readings of the same brief over the same 37 rulings answered
the headline question ("was the escalation warranted?") anywhere from ~1% YES
to ~50% YES — because "escalation" was never defined and each arm built its
own yardstick. The template's own prompts have the same exposure: the agents
in the factory read `steward.md`, `plan.md`, `oracle.md` the same way those
readers read the brief. The ruling schema itself forks (HALT entries carry a
different field set than decisions), and a mandated vision citation that the
vision cannot supply produces filler (`(no vision statement decided this)`) —
which one arm found correlates perfectly with rulings nobody needed.

### F-J. Ids are not namespaced (extraction; scouts)

`OD-1`..`OD-3` mean different rulings per lane *and per round within one
lane*; `BL`/`F` collide across lanes; `ESC-` deliberately spans the template
and project repositories, so a project ledger cites ids that do not resolve
inside it. Only `<lane>:<round>:<family>-<n>` was unique. Every measurement
and every citation pays this tax.

### F-K. What did *not* fail — protect these from the fix

- **Waiting.** 83 WAIT gaps, median 0 s, p90 3 s, max 554 s (H003 confirmed).
  The hours went into design-layer work, not into waiting on checks. Do not
  spend this plan optimising merge latency (H016 landed inconclusive; measure
  first).
- **Checkpoint-and-resume.** Six session kills, six clean resumes, where
  write-through-per-unit was practised.
- **The two-lane split.** Same decisions from the same documents; the
  difference was verbosity (~4× on the web lane), not substance.
- **The reserved-gap pattern.** Every escalation five of six arms called
  necessary was one the owner had reserved in writing (the TEST NOTE), and
  all of them resolved.
- **Mint-versus-retire.** Uncertainty amplification is *not* runaway (mean
  0.71, max open 3). The loop does not need a filing cap.

---

## 2. Diagnosis — why a good-faith project still churned

The user-level question behind this plan: anvil was *built* to generate
uncertainty, so churn there is partly the test working. find_best_mobo was
not — its design and vision were written in good faith — and it churned the
same way. Why?

**Because the loop's economy pays for questions and does not pay for code.**
Four mutually reinforcing properties, all of them design decisions that are
individually defensible:

1. **Design work strictly outranks build work.** The detector's precedence is
   WAIT → ORACLE(uncertainties) → ORACLE(evidence) → STEWARD/PLAN →
   ORCHESTRATE → ACCEPTANCE, and any uncited id anywhere forces ORACLE. Build
   is reachable only at *global* design-layer quiescence — a state the loop
   visited only when a broken gate let it sprint there.
2. **Every role upstream of the coder is rewarded for filing and forbidden to
   self-rule.** The planning rule (correctly) makes guessing illegal; the
   gates (correctly) block self-ruled uncertainties; so plans and stewards
   file. Filing is cheap and compliant. Nothing symmetric makes *closing*
   cheap: an item leaves the queue only through a full ruling.
3. **Nothing owns the ruling → plan → slice chain.** A ruling that mints no
   requirement creates no detectable work; 35 of 58 rulings evaporated. The
   one artifact that would have said so — a per-iteration count of unplanned
   rulings — did not exist in any `run.md`.
4. **Correct rules are missing their counterparts.** Supersession exists with
   no reader (`coverage.sh`). Append-only exists with a done-marker for
   escapes but the join back from decisions to the backlog is one-directional.
   Gate immutability exists with no in-run repair or surrender path. The
   oracle has halt *vocabulary* but no halt *effect*. Each half-rule turned a
   small defect into a session-burning loop.

Add the operational layer — PR-landing failures with no typed stop, evidence
that only exists on one lane, ids that collide, force-rebuilds that eat
merges — and the observed outcome is over-determined. The vision doc's honesty
was never the variable. **A perfect design document would not have saved this
run**, and that is the strongest argument that the fix belongs in the
template, not in better project authoring.

One more diagnosis, about *us* rather than the run: the template's CI tests
every gate in isolation and has never run the loop's economy end to end.
Every failure above — never-reaches-build, livelock, silent evaporation of
rulings — is invisible to a per-script fixture test. The ratchet ("which gate
should have caught this?") has to be applied to the loop itself.

---

## 3. The plan — seven workstreams, ranked by leverage

Ranked: doing only W1 is worth more than doing W2–W7 without it. Each
workstream states the failure it answers, the change at the level that
matters, what makes the change *checkable* (the ratchet), and what it
deliberately does not change. Implementation detail — exact precedence
tables, field names, script diffs — belongs to the per-workstream plans, not
here.

### W1. Close the loop: a ruling is open until it ends in work or an explicit "no work" *(answers F-B, F-C — the single largest leak)*

**Change.**

- **A ruling gets a closure state, mechanically.** Every OD must end in
  exactly one of: (a) a plan that cites it, (b) an explicit disposition
  recorded in the decision itself — "no work: <why>", "superseded by OD-n",
  or "artifact ordered: <what>" — or (c) a halt. "Ruling with no closure"
  becomes a first-class queue the detector reads, exactly as "uncited
  evidence" is today.
- **Rebalance the detector's precedence around one invariant: work already
  decided outranks new questions.** After WAIT and HIGH-blocking
  uncertainties, the driver first closes open rulings (STEWARD), then builds
  merged-but-unbuilt plans (ORCHESTRATE), and only then feeds new
  non-blocking evidence to the oracle. Only a HIGH uncertainty may block the
  build path. The exact ordering is the implementation plan's to fix; the
  invariant is not.
- **Score the run on output, visibly.** Every `run.md` iteration line carries
  the four counters that describe the economy: open rulings without closure,
  merged plans with unbuilt slices, evidence backlog, and product lines
  merged so far. A run that ends with zero product code must say so in its
  first screen, as a headline, not be discoverable only by forensics.

**Ratchet.** The fixture-loop test (W7) asserts that a clean small project
reaches a merged feature slice within a bounded number of iterations, and
that a ruling with no plan pulls a STEWARD dispatch before any new-evidence
ORACLE dispatch.

**The trade this makes, named.** Letting build outrank non-blocking evidence
means a slice can be built against a design that a pending LOW item would
have corrected. That risk is deliberate and bounded — the cost is one slice,
reworkable, where the current arrangement's cost was the entire run — and it
is the economy `AGENTS.md` already promises for LOW items. HIGH keeps its
veto precisely so the unbounded version of this risk cannot happen.

**Not changed.** The mid-run authority chain (oracle → plan → code, never
sideways) stays exactly as is. This workstream changes *scheduling*, not
authority.

### W2. Ground the design layer in the repository's reality *(answers F-D, and the mobo cascades specifically)*

**Change.**

- **A referent check on rulings.** A decision may bind a requirement to a
  path, fixture, dataset or verbatim string only if it resolves in a commit
  at ruling time. Otherwise the decision must say "artifact ordered" (a W1
  closure state), which becomes the steward's first slice. Enforced in
  `oracle-decisions.sh` beside the existing evidence-citation check — same
  shape, same place.
- **The same check at the mouth of the funnel.** A setup-time lint over
  `docs/DESIGN.md` / `docs/VISION.md` (and the project's seed backlog):
  every referenced file, dataset or measurement either resolves in the repo
  or is explicitly marked as to-be-created. Report-only at first (it judges
  owner documents), but it runs before the first unattended dispatch, so the
  owner learns about phantom referents while they are awake. This is the
  change that respects find_best_mobo's good faith: the doc was honest; the
  system never told anyone which of its nouns were real.

**Ratchet.** Fixtures: a ruling naming a nonexistent path fails; the same
ruling with "artifact ordered" passes and produces steward work; the lint
flags a design doc citing a file no commit contains.

**Not changed.** The oracle's authority to order new artifacts. The point is
to make "this does not exist yet" explicit and cheap, not to forbid it.

### W3. Give the loop brakes, and give every writer a reader *(answers F-E, F-F)*

**Change.**

- **Supersession becomes effective.** `coverage.sh`'s `ids_from()` collects
  requirement ids from `**Requirements added:**` lines and nothing subtracts
  the `**Requirements superseded:**` ones (verified at HEAD) — while
  `oracle-decisions.sh` **requires** every decision to write that superseded
  field. The schema mandates a write that no script reads; that is the
  livelock's whole mechanism. Fix the reader, then generalise it as a rule
  with a test: *no write-only fields* — every field the ruling schema
  requires is named by at least one script that reads it, checked
  mechanically across the shipped scripts.
- **A brake the oracle can pull — scoped, not a run-stop.** The owner's
  standing rulings (synthesis R10/R11: the rate limit is the only default
  stop; anomalies are signals) are respected by making the brake *per
  target*: the oracle may mark a specific OD / plan / PR as
  "do-not-redispatch: <reason>", the driver honours it each cycle, routes
  around it, and reports it loudly in `run.md`. Whether a full run-halt file
  should also exist is put to the owner as open question Q1 — it contradicts
  R10 as ruled, so it is not assumed here.
- **Complete the typed-stop taxonomy where F-F showed it leaks.** Exits 3, 4
  and 5 already exist; what is missing is the guard the mobo livelock walked
  through: the detector emitting the **same phase with the same scope** N
  times with no closure event in between becomes its own typed stop, however
  productive the dispatches look. And the three-strikes counter gets a test
  that proves it is actually a bound (H004 showed ≥4 dispatches before it
  fired).
- **A surrender path for gate defects.** A generated project must not edit
  its gates — correct, keep it. Therefore when a typed stop's signature
  points at gate machinery, the driver's stop writes a mechanical
  template-defect report (the `template-bugs.md` pattern, but structured and
  automatic) and ends the run as "blocked on template defect". Eight anvil
  rounds and the entire mobo livelock end in minutes under this rule instead
  of hours.

**Ratchet.** Fixture for the R1001 shape: a superseded requirement stops
appearing as a coverage gap. Fixture for the livelock shape: a driver whose
dispatch produces no PR twice for the same cause stops with the typed code,
not a third dispatch.

**Not changed.** Gate immutability from inside a project. R10/R11 as ruled.

### W4. Never lose work or evidence again *(answers F-G)*

**Change.**

- **The factory's own output is evidence.** Every merge the pipeline makes is
  recorded at merge time with PR number, merge SHA, files and added/removed
  lines. The local driver today logs only a one-line "PR #n merged", and the
  web mode logs whatever the session types — which for PR #30 was nothing.
  The structured merge record becomes a required event in the W5 stream, on
  both drivers. (The vision already demands this: "a change nothing can
  observe is a change nobody can evaluate.")
- **No ref becomes unreachable by teardown.** `sweep-branches.sh` already
  refuses to delete unmerged work — the loss went through a different door:
  PR #30's merge landed on a run base branch that was later force-rebuilt,
  which no guard covers. So: whenever work merges into a base that is not
  the default branch, the driver tags the merge commit under a preserved
  namespace; and any tooling this repository ships that resets or rebuilds a
  base refuses unless the old tip is so preserved. PR #30 stays reachable
  under this rule.
- **Evidence parity across environments.** Worker transcripts, the driver
  console, and review payloads are committed into `docs/runs/<ts>/` on both
  the local and the web path, or the run says loudly which of them this
  environment cannot capture. No evidence path is gitignored (extends TB-7,
  which fixed one instance).
- **Run evidence is append-only like every other ledger.** Editing a landed
  `docs/runs/` file fails a check; corrections are new files that cite the
  old (the 2026-08-24 in-place cleanup becomes impossible to do silently).

**Ratchet.** Fixtures per bullet; the sweep-refusal one is red against
today's script.

**Not changed.** V8 stands: keep too much rather than too little.

### W5. One observability contract, both drivers *(answers F-H — and makes every other workstream measurable)*

**Change.** The driver — local shell loop and web session alike — writes one
machine-readable event stream (`docs/runs/<ts>/events.jsonl`) with a frozen
small schema: timestamp, base/lane, run id, iteration, phase, worker id,
role, ids referenced, plan path, pr number, exit code, bytes written,
verdict, and the dispatched prompt (by committed path or hash — H034 showed
the same OD dispatched twice yields different outcomes, and nothing recorded
what either dispatch was actually asked). Write-through at every transition (the post-mortem's own harness
proved that discipline survives kills). The rule for the schema is exactly
the list of fields the hypothesis pass starved for: it could not join
dispatches to PRs, rulings to bytes, or web anything to clock time. Hand-typed
prose remains welcome as commentary; it stops being the primary record.
Verdict and phase vocabulary are single-sourced (W6) so the stream needs one
parser, not one per lane.

**Ratchet.** A conformance test replays a rehearsal run and asserts zero
nulls on required fields; the post-mortem's own query scripts (they exist,
frozen, in the anvil repo) run against the stream as the acceptance suite.

**Not changed.** `run.md` as the human-readable report. This adds the
machine layer under it.

### W6. Freeze the words *(answers F-I; cheap, do it alongside W5)*

**Change.** One loop lexicon, single-sourced and referenced — never
paraphrased — by every command file, gate script and document: the phase
names, the verdict set, "uncertainty", "derivation" vs "guess", "HIGH",
"escalation", "resolved", "artifact", the closure states W1 adds. The ruling
schema is unified (one field set; HALT a kind, not a fork — today
`oracle-decisions.sh` enforces two different field sets). The honest empty
for the vision citation **already exists** — `(no vision statement decided
this)` is a legitimate, machine-recognisable value at HEAD — so the new work
is downstream of it: one qualitative arm found that rulings carrying it got
*zero* "this escalation was needed" verdicts, so the value becomes a triage
signal feeding the LOW fast-path below, not just a permitted spelling.
Dispatch hygiene rides along: prompts by stdin, never argv; sizes tested
(the 128 KB argv death); `state.json`-style caches lose to the filesystem on
resume, by rule.

**And the LOW fast-path, here because it is a vocabulary change as much as a
mechanism:** an item filed "Risk: LOW — proceeded on the default" is closed
by a one-line citation at the oracle's next pass — batchable, no eight-field
ruling. The full schema is reserved for decisions that decide something.
This removes most of the "why are you even asking" set that every
qualitative arm agreed on.

**Ratchet.** A drift check: command files and scripts quote the lexicon
verbatim or fail; a fixture LOW item costs one line, not a ruling.

**Not changed.** The ruling schema's *content* for genuine decisions — every
arm found it produces good rulings. The reserved-gap TEST NOTE pattern.

### W7. Rehearse the loop before trusting it *(the ratchet applied to the loop itself; answers the "why did no test catch any of this" question)*

**Change.**

- **A fixture project the CI can drive end to end.** Small, honest design
  doc; `gh` and the model stubbed or budget-capped; the whole detector +
  driver economy exercised: reaches ORCHESTRATE within N iterations, closes
  every ruling, self-clears LOW items, survives a supersession, stops typed
  on a repeated dispatch failure, honours a do-not-redispatch mark. Every
  economy defect the stress test found becomes a red fixture here first.
- **Scoped ids.** Ids carry the run scope (or a single allocator issues
  them): `OD-3` alone never again names four different rulings. The
  post-mortem's `<lane>:<round>:<family>-<n>` key is the shape that worked.
- **A run pins its template version.** Mid-run template bumps ended runs and
  forced restarts three times in one day downstream; a run records its
  version at start and upgrades between runs, not during.

**Ratchet.** This workstream *is* the ratchet. Its acceptance: rerunning the
2026-08-20 shapes (the R1001 supersession, the phantom-referent ruling, the
pr-create failure storm) against the fixture loop reproduces each historical
failure red before its fix and green after.

**Not changed.** The real-run requirement stands — `docs/synthesis.md`'s
"next action" (create the App, one watched run at `--max-prs 3`) is still the
only thing that closes ESC-21/ESC-26. The fixture loop is what makes that
watched run cheap instead of another forensic exercise.

---

## 4. Explicitly left alone

- **The ruling schema for genuine decisions**, the two-document design, the
  append-only ledgers, base-commit reads, owner-only DESIGN/VISION, blind
  tests, the review gate. All held or performed under stress.
- **The two-lane capability.** Same decisions both lanes; keep it for future
  tests, with W5 making the lanes actually comparable.
- **The one-PR-per-base rule and PR granularity.** H016 (latency floor ×
  PR count) landed inconclusive; waiting was measurably *not* the cost
  (F-K). Measure with W5 before touching this.
- **Checkpoint-and-resume.** Extend the write-through discipline (W5), do
  not redesign it.
- **The mint/retire balance.** No filing caps, no quotas — amplification is
  already < 1 and the failure was elsewhere.

---

## 5. Sequencing, and how we will know it worked

**Stage 1 — the leak and the livelock.** W1 (closure states + precedence +
scoreboard), plus W3's supersession reader and typed stops, plus the minimal
W5 event stream (without it, Stage 1's effect is unmeasurable). These three
remove the two failure modes that consumed the majority of both runs.

**Stage 2 — grounding and brakes.** W2 (referent checks, design-doc lint),
rest of W3 (do-not-redispatch, surrender path), W4 (evidence preservation).

**Stage 3 — words and rehearsal.** W6, W7, then the watched live run the
synthesis already calls for (App + `--max-prs 3`), which doubles as this
plan's acceptance run.

**Before/after metrics** (all computable from the W5 stream; baseline values
are the post-mortem's):

| metric | 2026-08-20 baseline | target |
| --- | --- | --- |
| rulings with no closure at run end | 35 of 58 | 0 |
| ORCHESTRATE dispatches per run | 1 in 1650 events (gate broken) | ≥1 per merged plan |
| product LOC merged and still reachable | 0 (of +541 built) | >0, never lost |
| sessions burned on one repeated failure signature | 6 (`gh pr create`), 4 (PR #133) | ≤ typed-stop bound |
| dispatch rows with null `pr_number` | 18 of 18 | 0 |
| full rulings on LOW/defaulted items | dozens (per arms) | 0 (one-line closures) |
| hypothesis-style questions answerable post-run | 15 of 40 reached a verdict | the W5 conformance suite |

**Cost note, honestly.** Stage 1 touches the most load-bearing script in the
template (`deliver-phase.sh`) and the ruling schema. That is the point: the
highest-leverage change is exactly the one the fixture-loop (W7) must exist
to protect, which is why W7's fixture project should be drafted *with* Stage
1, not after it — its first fixtures are Stage 1's red/green pairs.

---

## 6. Open questions for the owner (three, no more)

- **Q1 — The brake's blast radius.** W3 proposes a per-target
  do-not-redispatch mark, because a whole-run halt file contradicts standing
  ruling R10 ("the rate limit is the only default stop"). If you want the
  oracle to be able to stop a *run* (the mobo oracle plainly wanted to, and
  arguably should have been able to), that is an amendment to R10 only you
  can make. Recommended: per-target now; revisit run-halt after the first
  watched run.
- **Q2 — Who closes a LOW item.** W6's fast-path has the oracle close
  defaulted-LOW items with a one-line citation at its next pass
  (recommended: keeps "only the oracle metabolises evidence" intact, costs
  one batched line). The alternative — the driver auto-closes them with no
  oracle touch — is cheaper still but breaks that invariant.
- **Q3 — Where the closure state lives.** Recommended: inside
  `docs/DESIGN.oracle.md` entries themselves (append a closure line, same
  append-only discipline), read by the detector — no new ledger. The
  alternative (a separate work-state file) is cleaner to parse but adds a
  document that can drift from the ledger it mirrors.

### Rulings so far (2026-08-27)

- **Q2 — ruled.** The owner accepted the recommendation: the oracle closes
  defaulted-LOW items with a one-line citation at its next pass. The
  "only the oracle metabolises evidence" invariant stands.
- **Q3 — ruled.** The owner accepted the recommendation: closure state lives
  inside `docs/DESIGN.oracle.md` entries, append-only, read by the detector.
  No new ledger.
- **Q1 — open, under discussion.** The owner asked for the per-target brake
  and the halt question to be laid out in full before ruling.

---

## Appendix A — finding → workstream traceability

| finding | answered by |
| --- | --- |
| F-A oracle answered well | keep (§4) |
| F-B rulings → no plans/code | **W1**, W7 fixture |
| F-C design-layer attractor, forced rulings | **W1**, W6 LOW fast-path |
| F-D phantom referents | **W2** |
| F-E supersession livelock, no brake | **W3** (reader, brake, surrender), W7 fixture |
| F-F PR-landing burns, unbounded retries, stochastic dispatch | **W3** typed stops; W5 records prompt/dispatch; W7 fixture |
| F-G lost work/evidence | **W4** |
| F-H unmeasurable loop | **W5** |
| F-I unfrozen words | **W6** |
| F-J id collisions | **W7** (scoped ids) |
| F-K what worked | §4 left alone |
| synthesis §3.1–§3.8 | 3.1→W1 · 3.2→W2 · 3.3→W6 · 3.4→W3 · 3.5→W4 · 3.6→W5 · 3.7→W6 · 3.8→W6 |

## Appendix B — confidence notes

The quantitative pass reached a verdict on 15 of 40 hypotheses (4 confirmed,
11 falsified; 2 more were blocked on missing data, 23 inconclusive) — the
inconclusive majority is itself finding F-H, and is why W5 ranks above
everything except W1. The
qualitative arms disagreed on the *judgment* question (was an escalation
warranted) by 1%–50% but agreed on every *structural* story this plan builds
on: the four cascades of §1.2, the livelock, the resolution rate, the
authority rate. Claims in this plan lean only on the agreed layer and on the
mechanically confirmed hypotheses; where a lead landed inconclusive (merge
latency, batching, tier bias) this plan deliberately proposes measurement
(W5) rather than change.

## Appendix C — the verification pass, and what it changed

After the first draft of this plan was committed, every code-level claim in
it was re-checked against the shipped scripts at this branch's HEAD, and
every headline number against the post-mortem files. Four things were wrong
or too weak in the draft and are corrected above; they are recorded here
because a plan that silently repairs itself is the exact shape this
repository distrusts.

1. **The draft proposed a typed-stop taxonomy the driver already largely
   has.** `deliver-loop.sh` at HEAD carries exit 3 (same failure signature
   three times), exit 4 (owner-action red check, first strike), and exit 5
   (two consecutive no-PR dispatches). The correction made the finding
   *sharper*, not moot: the mobo livelock defeats all three at today's HEAD,
   because its stuck dispatches each opened a pull request and so reset the
   no-progress counter every cycle. W3 now names the guard that is actually
   missing — detector-state repetition — instead of re-proposing the ones
   that exist. (F-F, W3.)
2. **The draft proposed the `(no vision statement decided this)` opt-out as
   new.** It exists at HEAD, alternatives-obligation and all. W6 now builds
   on it (as a triage signal) rather than inventing it. (W6.)
3. **The draft implied `sweep-branches.sh` could drop unmerged work.** It
   refuses to, by design. PR #30 was lost through a lane force-rebuild —
   a path no guard covers — so W4's rule is now aimed at base-branch
   teardown and at tagging merges into non-default bases, which is the door
   the work actually left through. (F-G, W4.)
4. **A count error:** 15 of 40 hypotheses reached a verdict, not 17.

Two claims came out of the re-check *stronger* than drafted, and the text
above now says so: `oracle-decisions.sh` **requires** every decision to
write the `Requirements superseded` field that no shipped script reads —
the livelock is a mandated write-only field, which is why W3's "no
write-only fields" rule is a class fix rather than a spot fix. And
`AGENTS.md`'s own words promise the LOW-uncertainty economy that W1
proposes ("proceeds on the recorded default and the oracle reviews it next
cycle") while `deliver-phase.sh` implements the one that failed — W1 is in
that sense the code catching up to the rules, not a new philosophy.

What was *not* re-verifiable from here is stated as such in the text: web
timings are reconstructed tier throughout, the anvil round-3.2 gate story is
the ledger's own account, and the "zero product code" framing is the task
brief's, qualified by H024's confirmed exception.
