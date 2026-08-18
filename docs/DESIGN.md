---
title: grimsverk-template
status: approved
created: 2026-08-18
related: [docs/VISION.md, docs/synthesis.md, docs/plans/closing-the-loop.md]
---

# grimsverk-template — Design Doc

Written when the template began hosting its own gates. Until then this document
did not exist, which was itself worth noticing: the system's whole claim is that
a design document is what makes work checkable, and the template had never had
one. Everything here is a description of what is built and shipping, not a
proposal — the requirement ids exist so `coverage.sh`, the plans, and the
acceptance criteria have something to be keyed on.

## 1. Summary

A Copier template that generates a project repository whose gates make
agent-written work checkable by someone who will not read the diffs. It ships
the CI workflows, the branch-and-plan discipline, the review gate, the delivery
driver, the oracle's evidence ledger, and the documents those all read from. As
of `docs/plans/closing-the-loop.md` it also renders its own governance from
itself, so template development is governed by the template.

## 2. Problem & motivation

Agents produce plausible work quickly, and reviewing it costs more attention
than the owner has. The failure that matters is not bad code — it is a run that
reports success while the thing asked for was not done: a green pipeline, an
honest-looking summary, and a table of criteria nobody ran.

Every mechanism here exists to make some part of that outcome mechanically
impossible or mechanically visible. Nothing here is about code quality.

## 3. Goals and non-goals

**Goals**
- Generate a repository where a change is judged against standards read at the
  commit it started from, never against its own revision of them.
- Let a delivery run proceed overnight without a human, and stop loudly rather
  than degrade quietly when it cannot.
- Make "done" a thing that runs, not a thing an agent says.
- Govern the template itself with the machinery it ships.

**Non-goals**
- Being a general-purpose scaffold. Two languages, chosen because the owner uses
  them.
- Measuring code quality, style, or architecture. The gates check *conformance
  to what was specified*, not craft.
- Preventing a determined human from bypassing anything. Every control here
  assumes the owner is cooperative and the agents are not adversarial, only
  incentivised.
- Shipping a licence, or choosing one on a project's behalf.

## 4. Users & core use cases

One user: the owner, who starts a run and walks away.

- **Generate.** `copier copy <this> <name>` produces a repository with gates
  live from the first pull request.
- **Design, then deliver.** The owner writes `docs/DESIGN.md` and
  `docs/VISION.md` and lands them personally; the driver plans, builds, merges
  and finally checks the built system against §13.
- **Read one document.** In the morning, `docs/acceptance.md` — the one artifact
  whose pull request requires their review.
- **Improve the template.** A defect found in a real project becomes a check
  here, and every generated project gets it through `copier update`.

## 5. Requirements

**Most of these were built before this document existed.** The plans that built
them were implemented and deleted (`docs/synthesis.md`, revision 4), and their
claim on these requirements went with them — so `coverage.sh` reported twelve
requirements as work nobody had scheduled, which was false.
`docs/plans/template-foundations.md` restores the true answer: it is a
retrospective record, every slice names the files that ARE the delivery, and its
estimates are measured rather than forecast. Coverage now reports 16/16.

It is still a report rather than a gate. What it *is* load-bearing for is the
delivery driver, which reads an uncovered requirement as work to plan — see §11
for the one thing that still blocks a run here.

**Functional**

- **R1** — A pull request is judged against the rules, design, plan and ledgers
  as they exist at its base commit, never as it leaves them. — *Evidenced by:* S1
- **R2** — Non-trivial work has a plan that landed before the code, resolved
  from the branch name, with `chore/`, `docs/` and `template/` exemptions that
  are size-capped or replaced by a stronger check. — *Evidenced by:* S2
- **R3** — A slice's tests are written by an agent that cannot see the
  implementation, and a suite that passes without its implementation fails the
  pull request. — *Evidenced by:* S3
- **R4** — An agent may correct the design from logged evidence while nobody is
  awake, in an append-only ledger where every decision cites evidence that
  already landed and quotes the vision statement it relied on. — *Evidenced by:* S4
- **R5** — The two intent documents — `docs/DESIGN.md` and `docs/VISION.md` —
  are landed by the owner personally, and no agent session can write them. —
  *Evidenced by:* S5
- **R6** — A delivery run recomputes its state from the tree and the open pull
  requests each iteration, dispatches one pull request at a time, and every stop
  says which stop it is. — *Evidenced by:* S6
- **R7** — A run refuses to start when the repository is not configured to
  survive it, loudly and before anything is dispatched. — *Evidenced by:* S7
- **R8** — Success criteria are scripts that run on every pull request, and the
  claim that one passed cannot be made without the thing that re-runs it. —
  *Evidenced by:* S8
- **R9** — A run leaves behind durable evidence — the run report, and the review
  gate's payloads and verdicts — committed to the repository rather than to a
  container that is reclaimed. — *Evidenced by:* S9
- **R10** — The template's own governance files are rendered from the template
  and checked for drift, and the gate scripts it ships are invoked directly
  rather than copied. — *Evidenced by:* S10
- **R11** — Every ledger an agent may write is append-only and enforced:
  escapes, the backlog, its done-log, and the oracle's decisions. —
  *Evidenced by:* S11
- **R12** — A template update lands as a `template/` branch whose tree is proved
  byte-for-byte to be `copier update`'s output. — *Evidenced by:* S12

**Non-functional**

- **R13** — Platform / targets: the generated project targets Python (uv, ruff,
  mypy, pytest) or iOS (XcodeGen, SwiftFormat, SwiftLint, XCTest); the template
  itself is bash and runs on Linux and macOS. *(non-functional)* —
  *Evidenced by:* S13
- **R14** — Cost: a run has a ceiling the owner chooses each time, and the rate
  limit is the only stop that applies by default. *(non-functional)* —
  *Evidenced by:* S14
- **R15** — Offline: the template's own test suite runs with no network beyond
  what `copier` needs to read this repository. *(non-functional)* —
  *Evidenced by:* S15
- **R16** — Privacy / security: no credential is ever written to a log, an
  argument vector, or a committed file, and secret scanning runs in CI as well
  as in the local hook. *(non-functional)* — *Evidenced by:* S16

## 6. Constraints & assumptions

- GitHub is the only platform. Branch protection, CODEOWNERS, rulesets and
  Actions are load-bearing, and several guarantees cannot be expressed in a file
  a pull request can diff.
- Copier is the rendering engine, and `copier update` is how improvements reach
  existing projects. That makes the shape of `template/` an interface.
- The unattended driver runs inside the repository it drives. There is no remote
  driver, so unattended work on the template requires the driver in the template.
- Agents are assumed to be incentivised, not adversarial: they take the cheapest
  path that reports success. Every gate is designed against that, not against
  sabotage.
- A GitHub App identity is required for unattended runs and does not exist yet,
  so that path ships dormant and refuses.

## 7. Proposed approach (high level)

Three layers, and each one only works because the layer below is mechanical.

**Documents that cannot move under a change.** Every gate reads its standard at
the base commit; CODEOWNERS puts the intent documents behind the owner;
append-only checks stop a landed record being reworded. This is what makes any
later claim checkable at all.

**Gates that compute rather than judge.** Plan resolution, slice deltas,
blind-test authorship, dependency deltas, template-sync replay, acceptance
criteria — all scripts, all deterministic, all reported to the one judged gate
(the LLM reviewer) as facts it is told nothing in the diff can influence.

**A driver that holds no model.** `deliver-phase.sh` reads the world and names
the next phase; `deliver-loop.sh` branches on exit codes and dispatches one
session. Waiting is `gh pr checks --watch`, so no model budget is spent on
information that has not changed.

## 8. Key design decisions & alternatives

- **Base-commit reads everywhere**, rather than working-tree reads. Alternative:
  trust the diff to be honest about what it changed. Rejected — a change that
  restates its own standard passes every shape check.
- **A second design document the oracle may write**, rather than letting an
  agent edit `docs/DESIGN.md`. Alternative: own nothing and move fast. Rejected
  — an agent that can edit the design does not need an evidence ledger, so the
  ledger only means something while the design is out of reach.
- **Immutability and provenance on the backlog, not approval.** Alternative: an
  owner-approval gate before an item is citable. Rejected on the owner's ruling:
  it stops work at 3am, which is the failure the arrangement exists to prevent.
- **Self-hosting rather than a second driver repository.** Alternative: a
  separate repository running the automation against this one. Rejected — gates
  are per-repository and the driver runs inside the repository it drives, so the
  second repository would have to become this one.
- **Reference the plain files, render the Jinja ones.** Alternative: copy the
  scripts to the root. Rejected — a copy drifts, and there is nothing to drift
  from if there is only one.
- **A criterion the oracle cannot mark passed.** Alternative: let the oracle
  close a criterion it judges met. Rejected — the last checkpoint before the
  human would become something an agent can talk its way past.

## 9. Data model / key entities

- **Requirement** `R<n>` — §5 here, or `R1000`+ from an oracle decision. One
  integer space, which is why the offset is enforced.
- **Success criterion** `S<n>` — §13 here; a script at `acceptance/S<n>.sh`
  unless marked `(owner)`.
- **Plan** — `docs/plans/<slug>.md`, front-matter `slug` and `covers`, 3–5
  vertical slices with files and estimates.
- **Escape** `ESC-<n>`, **backlog item** `BL-<n>`, **oracle decision** `OD-<n>`,
  **vision statement** `V<n>` — all rigid ids, all cited backward only, all
  resolved at the base commit.
- **Run** — `docs/runs/<timestamp>/`, the report and the review evidence.

## 10. External dependencies & integrations

Copier, `gh`, git, bash, GitHub Actions, gitleaks, shellcheck, and one coding
agent CLI (`claude`, or `codex` behind `REVIEW_ENGINE`). Generated projects add
their language toolchain. Nothing else, deliberately.

## 11. Risks & open questions

- **Nothing here has been observed live.** Every mechanism is tested against
  fixtures; no unattended run has happened. `docs/synthesis.md` records this.
- **The GitHub App does not exist**, so the identity that makes
  `owner-authored.sh` bind is dormant.
- **`ESC-21`** — a branch vanishing after auto-merge — has been closed and
  reopened around five theories and never reproduced.
- **The reviewer is nondeterministic**, and slice 5's fixtures are worth exactly
  as much as its verdict stability, which is unmeasured.
- **Committed run evidence grows without bound** until a retention rule exists.
  The owner has accepted that risk deliberately (V8).
- **The delivery driver cannot be pointed at this repository yet, and one thing
  is left.** Coverage is settled — `docs/plans/template-foundations.md` covers
  the twelve requirements that landed before this document existed. What remains
  is the other half of the same reading: `.claude/scripts/deliver-phase.sh` calls
  a plan BUILT when a merged `feat/<slug>` branch exists, and no such branch will
  ever exist for a retrospective plan, so once the phases ahead of it clear the
  detector emits `PHASE=ORCHESTRATE SLUG=template-foundations` and commissions an
  orchestrator to build what is already here. The smallest honest fix is for the
  detector to treat `status: merged` as built, which is what the field already
  means; that is a change to shipped behaviour and so the owner's to rule on.
  Ahead of it sits a second, older precondition: run the detector here today and
  it answers `PHASE=ORACLE` over thirty-four uncited escape ids, because this
  repository has kept that ledger since long before the oracle existed. Neither
  is a defect in the machinery; both are what self-hosting a design layer onto an
  existing repository actually costs. Until both are ruled on, do not start the
  driver here. Slice 3 of `docs/plans/closing-the-loop.md` makes an
  unattended run here *possible*; it does not make it correct to start one.

## 12. Milestones / phasing

**MVP** *(landed)*
- Scope: render a project with live gates, a plan discipline, blind tests, a
  review gate, and append-only ledgers.
- Acceptance criteria: S1–S3, S5, S11–S12.

**Later** *(landed or landing)*
- Unattended delivery, the oracle, readiness refusal, budget ceilings — S4,
  S6–S7, S14.
- `docs/plans/closing-the-loop.md`: executable criteria, self-hosting, durable
  evidence, reviewer fixtures — S8–S10.

## 13. Success criteria

- **S1** — *(covers R1)* — For each of `review.sh`, `plan-metrics.sh`,
  `oracle-decisions.sh`, `escape-refs.sh`, `acceptance-criteria.sh` and
  `vision-complete.sh`, a fixture in which the head commit rewrites the standard
  is judged by the base-commit version and fails.
- **S2** — *(covers R2)* — A pull request whose plan does not exist at its base
  commit fails; an oversized `chore/` branch fails; a planning-document branch
  passes at any size; a plan travelling with code fails.
- **S3** — *(covers R3)* — With the implementation reverted and the tests kept,
  the suite fails; a suite that still passes fails the check. Exercised in both
  the manifest-detected and the explicitly-named directory modes.
- **S4** — *(covers R4)* — A decision citing evidence that has not landed fails;
  one quoting a sentence absent from `docs/VISION.md` fails; a landed decision
  modified or reordered fails; a well-formed append passes.
- **S5** — *(covers R5)* — A pull request touching `docs/DESIGN.md` or
  `docs/VISION.md` that the owner did not open fails `owner-authored.sh`, and
  `.claude/settings.json` denies both paths to every session.
- **S6** — *(covers R6)* — `deliver-phase.sh` returns the documented phase for
  each of the seven world-states in its fixture suite, and `deliver-loop.sh`
  exits with the documented code for each stop.
- **S7** — *(covers R7)* — `unattended-ready.sh` refuses for each of its refusal
  conditions and prints the all-clear when every one is satisfied.
- **S8** — *(covers R8)* — A failing `acceptance/S<n>.sh` fails the pull
  request; a landed script deleted while its criterion stands fails; a
  `pass / agent` row with no script fails; a landed oracle waiver skips exactly
  one criterion.
- **S9** — *(covers R9)* — After a run, `docs/runs/<timestamp>/` contains the
  run report and one directory per reviewed pull request holding the payload the
  reviewer was given and the reply it produced, committed.
- **S10** — *(covers R10)* — `scripts/render-governance.sh --check` reports no
  drift on a clean tree and fails after an edit to any of the five rendered
  files; the root CI invokes the shipped gate scripts from `template/` rather
  than from a copy.
- **S11** — *(covers R11)* — For each of `docs/escapes.md`, `docs/BACKLOG.md`,
  `docs/BACKLOG.done.md` and `docs/DESIGN.oracle.md`, editing, reordering or
  deleting a landed entry fails its check while appending passes.
- **S12** — *(covers R12)* — A `template/` branch whose tree is not
  `copier update`'s output fails `template-sync.sh`, including when only
  `_src_path` changed.
- **S13** — *(covers R13)* — `copier copy` renders both languages, and the
  Python render passes its own gate (`ruff`, `mypy`, `pytest`) unmodified.
  The Swift render is validated for shape only; building it needs a macOS
  runner and is a stated gap.
- **S14** — *(covers R14)* — `deliver-loop.sh` refuses to start with no ceiling,
  and stops with exit 6 when the weekly allowance, pull-request count or
  wall-clock limit is reached.
- **S15** — *(covers R15)* — `tests/run.sh` passes with no network reachable
  other than this repository, and the tests that need `copier` skip visibly
  rather than failing.
- **S16** — *(covers R16)* — **(owner)** No credential appears in a run report,
  a committed review payload, an argument vector, or `ps` output, checked by
  reading a real run's artifacts. Gitleaks is green in CI.
