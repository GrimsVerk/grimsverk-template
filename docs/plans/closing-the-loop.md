---
slug: closing-the-loop
status: draft
created: 2026-08-18
covers: []
---

# Closing the loop — the template runs itself, and "done" starts meaning something

## Summary

Three things, and they are one thing.

The template ships machinery that only becomes live once a project is
*rendered*, so the template's own development is governed by nothing it sells.
Acceptance is narrated rather than run, so "done" is an agent's sentence about
itself. And a run produces almost no durable evidence, so the next run repeats
the last one's mistakes. Each is a place where the system talks about work
instead of measuring it.

Six slices. The order is chosen: the prerequisite first, then the thing that
makes "done" real, then self-hosting, then the smaller closures.

Costs: one rendering step and its drift check, a new test directory, one more
required check, and a `docs/VISION.md` section that did not exist. Nothing here
adds a recurring obligation for the owner — that standing constraint, recorded
in `docs/synthesis.md`, still binds.

---

## The owner's rulings behind this

Collected 2026-08-18, verbatim where quoted. The context document records which
sentences are the owner's and which are the implementing session's reading.

1. **Self-host rather than split.** *"fair, self host it is."* The proposal for
   a second repository to run the automation is withdrawn: the driver runs
   inside the repository it drives, so a second repository could not have driven
   this one.
2. **The root `AGENTS.md` is a composition.** *"the template repo agents file
   (running the self-host) should be a combo = template agent (the one every
   project gets) + template self-host specific agent stuff."*
3. **The coverage adequacy check reports, never fails.** *"yes, note, not red."*
4. **Success criteria get tests.** *"success criteria needs tests."*
5. **The acceptance tests are not CODEOWNERS-owned**, because ownership would
   block a dependent feature and because a failing criterion is information the
   orchestrator needs rather than a stop.
6. **A failing acceptance test goes to the oracle**, which rules on whether the
   test measures a real criterion and whether the implementation genuinely
   failed. See slice 2 for the boundary this plan puts on that.
7. **Reviewer fixtures are built now**, because the material already exists.
8. **The backlog's "Approved" section becomes advisory**, and approval records
   *who* — owner or oracle — because a reviewer reading an item is better served
   by provenance than by a gate.
9. **Data collection is a first-class concern of unattended operation**, and
   belongs in `docs/VISION.md`: *"the data needs to be collected in a sensible
   way so that future runs can be improved by not repeating mistakes… if a
   change is necessary in an unattended run that goes outside or misses built in
   data collection mechanisms, then new data collection mechanisms need to be
   added to track the performance of the changes that are downstream of the
   oracle's ruling."*

---

## Slice 1 — `test-the-tests` can name its own directories

- **Delivers:** the check works in a repository whose implementation is not
  `src/`, which is the precondition for every later slice that runs it here.
- **Files:** `template/.github/scripts/test-the-tests.sh`,
  `tests/test-gates.sh`
- **Estimate:** ~30 lines

It picks `IMPL_DIR`/`TEST_DIR` from the presence of `pyproject.toml` or
`project.yml`, and skips when neither exists. This repository has neither, so
the check would skip on every pull request — and a skip is reported to GitHub as
a **passing required check**. Blind-test discipline, the thing that makes a
coder's tests worth anything, would silently not apply to template changes at
all.

Add `TEST_THE_TESTS_IMPL_DIR` / `TEST_THE_TESTS_TEST_DIR` overrides. Here they
are `template` and `tests`, which is the honest mapping: `template/` is what
this repository builds, `tests/` is what checks it.

First because slice 3 must not turn self-hosting on while the check that makes
tests trustworthy is inert.

## Slice 2 — success criteria become executable, and a failure is routed

- **Delivers:** every agent-verifiable `S<n>` is a script that runs, rather than
  a sentence an agent wrote about itself; and a failing one moves the run
  forward instead of stopping it.
- **Files:** `template/acceptance/README.md`,
  `template/acceptance/.gitkeep`, `template/docs/acceptance.md.jinja`,
  `template/docs/DESIGN.md.jinja`, `template/docs/DESIGN.oracle.md.jinja`,
  `template/.claude/commands/deliver.md`,
  `template/.claude/commands/oracle.md`,
  `template/.claude/scripts/deliver-phase.sh`,
  `template/.github/scripts/acceptance-criteria.sh`,
  `template/.github/scripts/oracle-decisions.sh`,
  `template/.github/workflows/ci.yml.jinja`, `tests/test-acceptance-criteria.sh`,
  `tests/test-oracle-decisions.sh`
- **Estimate:** ~280 lines

**Why this is the heaviest slice.** `docs/acceptance.md` is the one artifact in
an unattended run whose pull request requires the owner's review — the single
guaranteed connection between the run and a human. Today its evidence is an
agent's narration: *"I ran X and it printed Y."* Everywhere else this template
rigorously separates computed facts from judged verdicts; this is the one place
narration is admitted as evidence, and it is the last thing the owner reads.

Each `S<n>` marked agent-verifiable in `docs/DESIGN.md` §13 gets
`acceptance/S<n>.sh` — exit 0 is pass, non-zero is fail, stdout is the evidence.
`acceptance-criteria.sh` **runs them on every pull request**, as a required
check, and additionally asserts that every agent-verifiable `S` id in §13 has a
script and that no landed script was deleted. §13 is CODEOWNERS-owned, so the
*set* of criteria stays the owner's even though the scripts are not owned.

Running them per pull request rather than only at acceptance is the whole point:
a criterion checked once and trusted thereafter is exactly the "verified once,
trusted forever" shape this template distrusts everywhere else. A criterion that
passed in the acceptance pass and regressed three merges later is otherwise
caught by nothing until the next acceptance pass, which may be the last one.

**Not CODEOWNERS-owned, on the owner's ruling**, and the reasoning is theirs: a
feature that depends on another would block waiting for a review, and a failing
criterion is diagnostic information the orchestrator should act on rather than a
door it waits at.

**A failing criterion goes to the oracle**, which is the owner's ruling, and this
plan puts one boundary on it. The oracle may rule:

- **the test is wrong** — it measures something §13 did not ask for, or measures
  it badly. Records a decision citing the evidence; the test is corrected on its
  own pull request.
- **the implementation is wrong** — back to `ORCHESTRATE`, which is the ordinary
  loop doing its job.
- **the criterion is met by other means** — the implementation solved the problem
  in a way the test does not recognise. This is the case the owner raised and it
  is the one that needs a limit.

**The oracle may not mark a criterion passed.** In the third case it writes its
reasoning into the ledger and the row in `docs/acceptance.md` stays
`pending / owner`, carrying that reasoning. The owner's own success criterion is
adjudicated by the owner. Without this, the last artifact before the human
becomes negotiable by an agent, which is the failure the whole acceptance
mechanism exists to prevent.

**And a ruling has to actually unblock the run, which needs one more part.**
The owner caught this: if the criteria are a required check, then a criterion
the oracle ruled "met by other means" still exits non-zero, so every later pull
request stays red and work stops — the ruling would have unblocked nothing.

So a decision may carry an optional eighth field:

    - **Criterion waived:** S3 — <why the test does not recognise what was built>

`acceptance-criteria.sh` reads landed decisions at the base commit and skips a
waived criterion. Four properties make this an exception rather than a hole:

- **Per-criterion, never per-check.** A waiver on `S3` does nothing for `S4`;
  every other criterion still gates.
- **Cited, append-only, permanent.** It lives in the ledger `oracle-decisions.sh`
  already guards, so it inherits evidence-citation and immutability for free —
  no new file and no new trust boundary. Same idiom as `docs/escapes.md`: an
  exception that is written down rather than silent.
- **Visible twice**, in the ledger and as `pending / owner` in the acceptance
  table. The gate goes green; the claim of doneness does not.
- **Self-clearing.** If a later change makes `S3` genuinely pass, the next
  acceptance pass records `pass` and the waiver is moot. Nothing to tidy up.

The boundary — rule, record, waive, but never mark passed — is the implementing
session's, not the owner's words. The context document flags it.

## Slice 3 — the template hosts its own gates

- **Delivers:** work on this repository is governed by the machinery it ships,
  and an unattended run here is possible.
- **Files:** `scripts/render-governance.sh`, `AGENTS.md`,
  `docs/agents.selfhost.md`, `.github/CODEOWNERS`, `.claude/settings.json`,
  `.claude/agents/`, `.github/workflows/template-ci.yml`, `docs/DESIGN.md`,
  `docs/VISION.md`, `docs/plans/`, `tests/test-render-governance.sh`
- **Estimate:** ~260 lines

Two mechanisms, chosen by what the file *is*:

**Plain files are referenced, never copied.** All sixteen gate scripts, all
seven command files, `review-prompt.md` and both driver scripts contain no
Jinja. The root CI invokes `template/.github/scripts/<name>.sh` directly. There
is one copy, it is the one that ships, and drift is impossible by construction
rather than by checking.

**Jinja files are rendered to the root, and the render is checked.**
`scripts/render-governance.sh` renders exactly `AGENTS.md.jinja`,
`settings.json.jinja`, `CODEOWNERS.jinja` and the two agent definitions, then
writes them to the root. A CI step re-renders and diffs; drift is red. Rendering
flows one way — `template/` to root — so there is no cycle.

**Nothing else is rendered.** Not the document skeletons, which would overwrite
a real `docs/escapes.md` with a three-line stub. Not `src/` or `tests/`, which
would collide with this repository's own suite. Not `ci.yml`, whose generated
form expects `pyproject.toml` and `src/`.

**`AGENTS.md` is composed, per the owner's ruling:** the rendered shipped rules,
which are universal — branch discipline, plan-before-code, blind tests, the
ratchet, the gate-path list — plus `docs/agents.selfhost.md`, which holds what
is true only here: `template/` is product and not instructions, automate every
setup step, put the steps in the blocking message, verify in the environment
that will run it.

This repository also needs `docs/DESIGN.md` and `docs/VISION.md`, and has
neither. That is worth stating plainly rather than treating as overhead: the
system's whole claim is that a design document is what makes work checkable, and
the template has never had one.

## Slice 4 — evidence survives the run

- **Delivers:** a run leaves behind enough for the next one to be better, and
  the obligation to keep it that way is written where the oracle will read it.
- **Files:** `template/docs/VISION.md.jinja`,
  `template/.claude/scripts/deliver-loop.sh`,
  `template/.claude/scripts/collect-evidence.sh`,
  `template/.claude/commands/deliver-loop.md`,
  `template/.claude/commands/oracle.md`, `template/AGENTS.md.jinja`,
  `template/.gitignore.jinja`, `template/.github/scripts/review.sh`,
  `template/.github/workflows/review.yml`, `tests/test-collect-evidence.sh`
- **Estimate:** ~240 lines

The owner's ruling, and the gap it names: an unattended run produces a run log
that is **gitignored**, and in web mode lives in a container that is reclaimed.
The review gate's output is retained nowhere. So the evidence that would tell
the next run what went wrong is destroyed by default, and the loop the owner
described — run, learn, fix the template, run again — has nothing to learn from.

- `docs/VISION.md.jinja` gains a section stating that durable evidence is a
  requirement of unattended operation, not a nicety. It goes in the vision
  because it is a thing the oracle must be able to *cite*: a decision to add a
  measurement needs a vision statement behind it, and there is none today.
- The run report moves from `.claude/deliver-loop/run.md` (gitignored) to a
  committed `docs/runs/<timestamp>/run.md`, appended by the driver at each stop.
- **The review gate stops discarding its own work.** `review.sh` currently
  assembles a payload — a comment inside it calls that payload "an artifact of
  what the gate was shown" — and then throws it away along with the model's
  reply. Nothing is uploaded, nothing is committed, nothing is posted. So the
  one gate with no fixtures is also the one gate that leaves no trace to build
  fixtures from, which is what slice 5 needs.

  `review.sh` writes both the payload and the full reply to files. The workflow
  uploads them as run artifacts and posts the verdict and findings as a pull
  request comment, where they sit against the diff they judged.
  `collect-evidence.sh` then gathers them at run end into
  `docs/runs/<timestamp>/reviews/`, **committed to the repository**, on the
  owner's ruling — see the context document, because this overrode a
  recommendation to leave the bulky payloads in expiring artifacts.

  Collection happens once per run rather than per pull request, and that is
  deliberate: a review job that committed its own output would push to the
  branch it is reviewing and retrigger itself. The driver already opens pull
  requests and already runs once per stop, so it is the right place.
- **The rule that generalises it**, in `AGENTS.md` and `oracle.md`: when a
  decision changes behaviour that no existing measurement covers, adding the
  measurement is part of the decision. An oracle ruling whose effect nothing can
  observe is a ruling nobody can evaluate — which is precisely the position the
  owner is in with respect to the oracle itself.

## Slice 5 — the reviewer is tested

- **Delivers:** the one load-bearing gate with no fixtures gets some.
- **Files:** `tests/reviewer-fixtures/`, `tests/test-reviewer.sh`
- **Estimate:** ~180 lines

The review gate is the only gate nothing checks, and it is the single point where
one judgement failure plus auto-merge equals a silent breach. The material is
already written: `docs/reviews/gate-seams/findings.md` carries twelve traced
attack recipes, each a concrete diff with a stated expected verdict — the
three-line `chore/` branch that widens the orchestrator's grants, the `docs/`
branch carrying forty-eight lines of implementation, the lockfile swapped with no
manifest change. Each becomes a fixture the reviewer must BLOCK, plus honest
diffs it must PASS, because a fixture set that only tests blocking teaches the
reviewer to block.

Run on demand and nightly, never per pull request: it costs a model call per
fixture and it is nondeterministic.

## Slice 6 — the two small closures

- **Delivers:** plan adequacy is visible, and backlog approval is recorded.
- **Files:** `template/.github/scripts/coverage.sh`,
  `template/.github/scripts/plan-metrics.sh`,
  `template/.github/review-prompt.md`, `template/docs/DESIGN.md.jinja`,
  `template/docs/BACKLOG.md.jinja`, `template/docs/BACKLOG.approved.md.jinja`,
  `template/.github/scripts/backlog-append-only.sh`,
  `tests/test-coverage.sh`, `tests/test-backlog-append-only.sh`
- **Estimate:** ~150 lines

**Plan adequacy, as a note.** A requirement named in a plan's `covers:` that no
slice mentions is reported to the reviewer, never failed — the owner's ruling,
and the right one: a platform or offline requirement is legitimately owned by no
slice, so a strict check would fire on honest plans and teach authors to route
around it. §5 gains a way to mark a requirement non-functional so the report can
say which absences are expected.

**Backlog approval, as an append.** `docs/BACKLOG.approved.md`, held append-only
alongside the other two ledgers. Sections cannot carry this: moving an item from
Proposed to Approved changes its position, and `backlog-append-only.sh` fails on
reordering — so approval by moving is already structurally impossible. Each line
records who approved, owner or oracle, which is what a reviewer actually needs:
the oracle can be wrong, and an item it blessed reads differently from one the
owner did.

---

## What this cannot ship

The same asymmetry the superseded plans named, recorded in `docs/synthesis.md`
§1.1. Slice 3 makes an
unattended run *possible* here; it cannot make it *safe*, because that depends on
the App identity existing and on repository settings no file can reach. The
readiness check already refuses without them.

And nothing in this plan is observed. Every slice is tested against fixtures and
none against a live run, which is the state the whole `docs/synthesis.md`
exercise was about. The sequence after this plan lands is the owner's: run
`find_best_mobo` unattended, fix what it surfaces here, repeat until it is quiet,
and only then run this repository against itself.

## Verification

- `tests/run.sh` green, under both a laptop environment and CI's — with
  `GITHUB_REPOSITORY` set to a wrong value, since a test that depends on a
  variable being absent passes only where nobody is looking.
- The shellcheck sweep clean over the same paths `template-ci.yml` uses.
- `copier copy --vcs-ref=HEAD` renders both languages; the python render passes
  its own gate.
- `scripts/render-governance.sh` produces a tree identical to what is committed
  at the root, asserted in CI.
- **Flagged unverified-live, to observe on the first real run:** every criterion
  in slice 2 against a project that actually has success criteria; the oracle's
  adjudication of a failing one, and whether a waiver actually unblocks the
  pipeline; whether `docs/runs/` grows at a rate anyone wants to read, and how
  fast committed review payloads accumulate.
