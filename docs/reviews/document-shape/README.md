# Document-shape review

An adversarial, read-only review of this template, asking one question: **do the
template's guarantees hold across the range of `docs/VISION.md` /
`docs/DESIGN.md` pairs a competent human would actually produce?**

The standard applied throughout: *a guarantee that holds only for unusually
thorough documents is a template defect, not a document defect.*

| | |
| --- | --- |
| Reviewed | `claude/copier-template-automation-rii78u` @ `21c8eae` |
| Date | 2026-08-16 |
| Scope | read-only; no code changed, no gate touched |
| Reproduction | [`reproduce.sh`](./reproduce.sh) — rebuilds the fixtures behind findings 1, 2 and 6 |

Contents:

- [Part 0 — the brief as given](#part-0--the-brief-as-given)
- [Part 1 — the constructed document pairs](#part-1--the-constructed-document-pairs)
- [Part 2 — findings, by silence rank](#part-2--findings-by-silence-rank)
- [Part 3 — shapes that hold](#part-3--shapes-that-hold)
- [Part 4 — method notes](#part-4--method-notes)

---

## Part 0 — the brief as given

Reproduced verbatim, because the findings below are only legible against the
constraints they were produced under — in particular the ban on
self-sabotaging document pairs, the requirement that every fix land in the
design skill or a document template, and the instruction to rank by silence
rather than by severity.

> You are performing an adversarial review of a Copier project template, focused on
> document shape. Read-only. Write no code, change no files, open no pull requests.
>
> **SETUP**
> Repository: grimsverk-template. Branch: claude/copier-template-automation-rii78u.
> Verify you are on that branch before reading anything (`git rev-parse --abbrev-ref
> HEAD`); `main` is stale. Everything under `template/` is rendered into generated
> projects.
>
> **WHAT THE SYSTEM IS**
> This template scaffolds repositories where coding agents implement a project
> autonomously to completion with no human in the loop. The human's entire ongoing
> contribution is two documents:
>
> ```
>   docs/VISION.md — what the owner values, in order; what they would trade away;
>                    core tenets that stop a decision dead; what makes an answer
>                    unacceptable. Declared the tiebreaker when two reasonable
>                    designs disagree.
>   docs/DESIGN.md — the design: requirements R1.., milestones, success criteria S1..
> ```
>
> Both ship as empty skeletons and are authored per project by an interview skill
> (template/docs/idea-to-design-doc.md, driven by
> template/.claude/commands/design.md). Read both of those first — they are the
> thing you are reviewing.
>
> Mid-run, an "oracle" role may append design decisions to docs/DESIGN.oracle.md
> when logged evidence contradicts the design. Each decision must name the
> docs/VISION.md statement it relied on. A mechanical check
> (template/.github/scripts/oracle-decisions.sh) constrains that ledger. Read that
> check in full before forming any opinion about what it guarantees.
>
> **YOUR JOB**
> Determine which VISION/DESIGN document shapes resist agent gaming and which
> invite it — and, crucially, whether the template's guarantees hold ACROSS THE
> RANGE of documents a competent human would actually produce.
>
> **THE STANDARD, AND IT IS THE WHOLE POINT**
> A guarantee that holds only for unusually thorough documents is a TEMPLATE
> DEFECT, not a document defect. Say so in exactly those terms when you find one.
> The question is never "is this pair of documents good". It is "does the machinery
> still hold when the documents are ordinary".
>
> **CONSTRUCT DOCUMENT PAIRS — the core of the work**
> Write plausible, good-faith VISION/DESIGN pairs: the kind a competent, motivated
> human actually produces after a real design session with the interview skill,
> having answered its questions honestly and at reasonable length.
>
> DELIBERATELY BAD OR SELF-SABOTAGING DOCUMENTS ARE BANNED. A vision that says
> "ship fast, skip tests", a design with one vague requirement, a contradiction
> nobody would write — these are too easy and prove nothing. If a pair you drafted
> would embarrass its author when read aloud, throw it away and write a better one.
> Every pair must be one you would defend as reasonable work.
>
> Vary the pairs along axes that matter, and state which axis each pair exercises:
>
> - SPECIFICITY: concrete and measurable vs principled and abstract, both written well.
> - COVERAGE: broad-but-shallow vs narrow-but-deep. What each leaves unaddressed.
> - RELATIONSHIP between the two documents: vision written first vs written after
>   the design (the interview skill explicitly offers both orders and argues the
>   second is often better — test both); vision that restates design priorities
>   vs vision that is genuinely orthogonal to them.
> - SILENCE: what each document deliberately does not say. Note that the template
>   treats a DELETED vision section as a legitimate decision and an EMPTY one as
>   an omission — construct pairs that exercise that asymmetry honestly.
> - TENET COUNT: the vision template instructs "two or three" core tenets and
>   warns a long list stops unattended work entirely. Test both ends of the
>   range it sanctions.
>
> Aim for at least five pairs. Write enough of each that the probes below are real
> rather than hypothetical — a paragraph per section, not a placeholder. You do not
> need to write them into the repository; keep them in your report.
>
> **PROBES — at minimum, answer all of these, each with a trace**
>
> 1. BOTH SILENT. Take a decision the unattended loop must make, which neither
>    document addresses. Follow it through the actual machinery: which role
>    decides, under which command file's instructions, what gets written where,
>    which check inspects it, and what a human sees afterwards. Do this for a
>    LOW-risk decision and a HIGH-risk one — the template classifies them
>    differently (see AGENTS.md's Planning rule and
>    .claude/scripts/deliver-phase.sh) — and say whether the difference is real.
>
> 2. FRAMING A CHANGE AS VISION-ALIGNED. Construct a design change that a
>    competent agent could present as consistent with the vision when it is not.
>    Not a lie: a defensible reading that goes the wrong way. Then answer
>    precisely: WHO ADJUDICATES that framing? Name the role, the file that
>    defines it, and every mechanical check that inspects the adjudication.
>
> 3. IS THE ADJUDICATOR THE PARTY THAT WANTS THE CHANGE? Follow the authoring
>    path of an oracle decision end to end — who writes it, who reviews it, which
>    path it lands on, whether that path is under CODEOWNERS, and what the
>    separation-of-duties argument in .claude/orchestration.md ("Deciding and
>    commissioning are separate") actually separates. State plainly whether the
>    separation it describes is the separation that matters here.
>
> 4. WHAT THE VISION FIELD IS WORTH. Every oracle decision carries a "Vision
>    statement relied on" field. Read oracle-decisions.sh's handling of that
>    field line by line and state exactly what property is verified. Then
>    construct the weakest field value that passes, and say what the owner reading
>    the ledger would conclude from it. Separately: determine whether ANY
>    mechanism anywhere in this repository compares that field against the actual
>    contents of docs/VISION.md, and whether the review gate is ever shown
>    docs/VISION.md at all (read the payload assembly in
>    template/.github/scripts/review.sh). Report what you find either way.
>
> 5. CONFLICT PLUS AMBIGUITY. The two documents disagree and the vision is itself
>    open to more than one reading — the ordinary case, not a pathological one.
>    Trace what happens: which document wins, by what mechanism, and whether any
>    artifact records that a conflict was detected at all.
>
> 6. AUTHORING-TIME VS LATER. Does the design skill detect contradiction WHEN THE
>    DOCUMENTS ARE WRITTEN, or only when something downstream trips over it? Read
>    template/docs/idea-to-design-doc.md and .claude/commands/design.md against
>    the checks in template/.github/scripts/. Name every consistency property the
>    interview claims to establish and say, for each, whether anything verifies it
>    later — and what the failure looks like when it does not.
>
> 7. THE OPT-OUT PATHS. The template documents two: deleting a vision section, and
>    deleting docs/VISION.md entirely to opt out of the oracle. For each, work out
>    what stops being checked, whether anything downstream still behaves as though
>    the document were present, and whether the owner would be told.
>
> 8. TENETS AS STOPS. Core tenets are the one thing that halts the oracle. Read
>    how a tenet is expressed, who evaluates whether a decision violates one, and
>    what mechanically observes that evaluation. Then determine whether a
>    well-written tenet is more enforceable than a badly written one — and if it
>    is not, say what that means for the instruction to write good tenets.
>
> 9. THE DEFINITION OF DONE. Find every definition of "the project is done" in
>    this repository (AGENTS.md, .claude/commands/deliver.md,
>    .claude/scripts/deliver-phase.sh, template/.github/scripts/coverage.sh,
>    template/docs/acceptance.md.jinja) and check whether they agree. Then ask
>    what document shape makes "done" reachable while materially less than the
>    design has been built, and which mechanism would notice.
>
> 10. THE §13 / ACCEPTANCE PAIR. Success criteria are split between
>     agent-verifiable and owner-verifiable, and an agent is forbidden from
>     filling in the owner's rows. Construct an ordinary §13 and determine who
>     decides which side of the line each criterion falls on, and what that
>     choice costs or saves the agent making it.
>
> **RANK BY SILENCE, NOT SEVERITY**
> A document shape that makes something go red is a working system. Rank by how
> likely the failure is to pass every gate green and reach the human looking fine.
> Your top finding should be the case where the owner reads a plausible ledger, a
> green pull request, and an acceptance table, and is wrong about what was built.
> Say explicitly what the owner sees.
>
> **FINDINGS MUST BE EXPRESSED AS CHANGES TO ONE OF TWO PLACES**
> Every finding's fix must land in the design skill
> (template/docs/idea-to-design-doc.md, template/.claude/commands/design.md) or in
> the document templates (template/docs/VISION.md.jinja,
> template/docs/DESIGN.md.jinja, template/docs/DESIGN.oracle.md.jinja,
> template/docs/plans/_TEMPLATE.md.jinja, template/docs/acceptance.md.jinja,
> template/docs/BACKLOG.md.jinja) — because that is where a fix applies once to
> every project rather than being re-litigated per project.
>
> If a finding genuinely cannot be fixed there — if it requires a change to a gate
> script or to CODEOWNERS — say so plainly and explain why the document layer
> cannot carry it. Do not force a document-shaped fix onto a machinery-shaped
> problem; the honest statement that the document layer is the wrong place is
> itself a finding about the template's structure. But do not reach for that
> escape by default: prefer the document fix where one genuinely works.
>
> **OUT OF SCOPE — do not write these; they will be discarded**
>
> - Generic best practice ("write clearer requirements", "be more specific",
>   "add acceptance criteria", "consider a template for X").
> - Advice to the document author. The audience is the TEMPLATE, not the human
>   filling it in. "The owner should write better tenets" is not a finding; "the
>   tenet mechanism is unenforceable regardless of how it is written, so the
>   template should stop presenting it as a stop" is.
> - Any finding built on a deliberately bad document pair.
> - Restating the template's own documented caveats. This codebase documents its
>   weaknesses at length in comments and in docs/escapes.md. Showing a caveat is
>   reachable with an ordinary document pair IS a finding; quoting it is not.
> - Style or wording critique of the shipped skeletons, unless the wording
>   changes what a mechanism does.
>
> **REQUIRED FINDING FORMAT — every finding, no exceptions**
>
> ```
>   TITLE
>   SILENCE RANK: 1..N (1 = most likely to reach the owner looking fine)
>   DOCUMENT PAIR: which of your constructed pairs exercises it, and which axis
>         that pair was varying
>   MECHANISM: the exact file:line whose behaviour depends on the document content
>   ATTACK TRACE: numbered and concrete. Quote the actual document text from your
>         pair, the actual ledger entry or plan front-matter that results, the
>         actual branch name and paths. Reproducible by someone with a shell.
>   CI OUTPUT ON SUCCESS: what each required check prints — plan, template-sync,
>         secrets, checks/test, test-the-tests, review — and the review gate's
>         findings section and final verdict line.
>   WHAT THE OWNER SEES: the pull request, the ledger entry, and the acceptance
>         table as they appear to the human.
>   RANGE: state whether the guarantee holds for your OTHER pairs. If it holds only
>         for the most thorough pair, say in those words that this is a template
>         defect, not a document defect.
>   FIX: a specific edit to the design skill or a document template. Quote the
>         replacement text or state the exact structural change. "Add guidance
>         about X" is not a fix; the sentence you would add is.
> ```
>
> **METHOD**
> Read the machinery before theorising about documents — the gates decide what
> document properties matter, and several of them do less than their prose claims.
> Cite file:line for every mechanical claim. Where something depends on GitHub
> behaviour or on a credential identity you cannot observe from the repository,
> mark the finding CONDITIONAL and state what would confirm it, rather than
> assuming.
>
> Prefer eight traced findings over thirty asserted ones. End with a section
> "SHAPES THAT HOLD": document shapes you tested that the machinery genuinely
> survives, and what property of those shapes made the difference. That section is
> as valuable as the findings, because it is what the design skill should be
> steering authors toward.
>
> **OUTPUT**
>
> 1. Your constructed document pairs, labelled by the axis each varies. Enough text
>    per pair that the traces are real.
> 2. Findings, ordered by SILENCE RANK, in the required format.
> 3. SHAPES THAT HOLD.

---

## Part 1 — the constructed document pairs

Six pairs. Each is work I would defend.

### Pair A — "Ledgerline" · axis: SPECIFICITY (concrete & measurable) · vision written AFTER the design

**VISION.md**

> **## What this project is for**
> I want to stop reconciling three bank exports by hand every month. If this worked, I would open a terminal, run one command, and get a statement I trust enough to file taxes from — without ever opening a spreadsheet to check whether a transfer got double-counted.
>
> **## Priorities, in order**
> 1. Correctness of the balances. 2. Reproducibility — same inputs, same output, forever. 3. My time to run it. 4. Breadth of bank support.
>
> **## What I would trade away**
> Support for banks I don't use. A GUI. Speed — I run this twelve times a year and I would happily wait ten minutes. Historical data older than the current tax year. I would rather it refuse to categorise a transaction than guess at one.
>
> **## Core tenets**
> - A number that cannot be traced back to a source row is never shown.
> - The tool never writes to anything but its own output directory.
>
> **## What makes an answer unacceptable**
> A statement whose total does not equal the sum of its rows. Anything that requires me to remember a manual step between runs.

**DESIGN.md** (relevant sections)

> **§5** — **R1** ingest CSV exports from three named banks. **R2** normalise to a single transaction schema. **R3** detect and collapse inter-account transfers. **R4** categorise by rule file. **R5** emit a per-category statement with row-level provenance. **R6** — Platform: CLI, Python, offline.
>
> **§12** — MVP: R1, R2, R5. Later: R3, R4.
>
> **§13** — **S1** running against the 2025 fixture exports produces a statement whose category totals equal the hand-checked figures. **S2** every line in the output names the source file and row number. **S3** two runs over identical input produce byte-identical output. **S4** the tool creates no file outside `--out`.

### Pair B — "Tideline" · axis: SPECIFICITY (principled & abstract, written well) · vision written FIRST

**VISION.md**

> **## What this project is for**
> Reading research is where my thinking happens, and right now the thinking evaporates. I want a place where a note I wrote eight months ago surfaces because it is *relevant*, not because I remembered to tag it. Success is that I stop keeping a second, private set of notes because I don't trust the first.
>
> **## Priorities, in order**
> 1. That I keep using it after month three. 2. That nothing I write is ever lost or silently altered. 3. Recall quality. 4. Everything else.
>
> **## What I would trade away**
> Precision, for recall — I would rather see three irrelevant notes than miss the one. Multi-device sync. Any feature that requires me to maintain metadata by hand. Polish everywhere except the capture path, which has to be instant.
>
> **## Core tenets**
> - The notes are plain files on disk that outlive this program.
> - No feature may add a step between having a thought and it being saved.
> - Nothing is deleted by the software, ever — only marked.
>
> **## What makes an answer unacceptable**
> Anything I would have to migrate out of. If I would need an export tool to leave, it was built wrong.

**DESIGN.md**

> **§5** — **R1** capture a note from a global hotkey in under 200ms to persisted-on-disk. **R2** store notes as markdown files with YAML front-matter. **R3** build a local embedding index incrementally. **R4** surface related notes for the note currently open. **R5** full-text fallback search. **R6** — Platform: macOS, Swift.
>
> **§12** — MVP: R1, R2, R5. Later: R3, R4.
>
> **§13** — **S1** capture-to-disk latency under 200ms at p95 over 100 trials. **S2** killing the process mid-capture never loses a committed note. **S3** the note directory is readable and editable with any text editor with the app closed. **S4** *(owner)* after two weeks of real use, related-notes suggestions are useful more often than not.

### Pair C — "Relay" · axis: COVERAGE (broad-but-shallow) · vision restates design priorities

**VISION.md**

> **## What this project is for**
> A habit tracker my partner and I both actually use, because every one we tried died at the point where logging felt like a chore. If it worked, we would both have a month-long streak without either of us thinking about the app.
>
> **## Priorities, in order**
> 1. Logging a habit takes one tap. 2. It works with no network. 3. Shared visibility between two people. 4. Insight and charts. 5. Extensibility.
>
> **## What I would trade away**
> Any habit type more complex than "did it / didn't". Analytics. More than two users. Android. Reminders that need a server. Configurability — I would rather it be opinionated and wrong occasionally than flexible and fiddly.
>
> **## Core tenets**
> - The app opens to the log screen, never to a dashboard.
> - It works fully offline; sync is a bonus, never a precondition.
>
> **## What makes an answer unacceptable**
> Anything that makes logging slower than opening the app and one tap. A screen that shows a spinner before it shows the habits.

**DESIGN.md**

> **§5** — **R1** define habits. **R2** log a habit for today with one tap. **R3** log retroactively for a past date. **R4** streak calculation. **R5** local persistence. **R6** two-device pairing. **R7** conflict resolution on sync. **R8** widget on the home screen. **R9** weekly summary view. **R10** archive a habit without deleting history. **R11** — Platform: iOS 17+, SwiftUI. **R12** — Offline: full function with no network.
>
> **§12** — MVP: R1, R2, R5, R11, R12. M2: R3, R4, R10. M3: R6, R7. M4: R8, R9.
>
> **§13** — **S1** cold-launch-to-tappable under 400ms on an iPhone 12. **S2** logging works in airplane mode. **S3** a habit logged on device A appears on device B within 60s of both being online. **S4** streaks match hand-computed values over a 90-day fixture. **S5** archiving preserves history. **S6** *(owner)* both of us use it daily for two weeks unprompted. **S7** the widget updates within 5 minutes of a log. **S8** no data loss across an app upgrade.

### Pair D — "Keyring" · axis: COVERAGE (narrow-but-deep) + TENET COUNT (three, top of the sanctioned range)

**VISION.md**

> **## What this project is for**
> A small library that our services use to read secrets at rest without each of them inventing its own envelope format. If it worked, a security review of any one service would stop containing the sentence "and here it does its own crypto."
>
> **## Priorities, in order**
> 1. Being obviously correct on inspection. 2. Failing loudly rather than degrading. 3. Not changing its on-disk format. 4. Performance.
>
> **## What I would trade away**
> Algorithm agility — one suite, no negotiation. Key rotation convenience. Generality: this handles our envelope and nothing else. I would trade a great deal of ergonomics for a smaller surface to audit.
>
> **## Core tenets**
> - No configuration option may weaken a security property. If it can be turned down, it is not in the API.
> - The library never logs, and never accepts a logger.
> - A decryption failure is indistinguishable from a tampering failure to the caller.
>
> **## What makes an answer unacceptable**
> Any code path that returns plaintext when authentication failed. Anything that reads an environment variable.

**DESIGN.md**

> **§5** — **R1** seal a byte string into an envelope. **R2** open an envelope, authenticating before returning any plaintext. **R3** versioned envelope header with a hard-fail on unknown versions. **R4** key material zeroed on drop. **R5** — Non-functional: no dependencies outside the standard library and one vetted crypto crate.
>
> **§12** — MVP: R1, R2, R3. Later: R4.
>
> **§13** — **S1** the test vectors in `docs/vectors.json` round-trip. **S2** every single-bit mutation of a sealed envelope fails to open, over 10,000 trials. **S3** an envelope with an unknown version byte returns an error and never a plaintext. **S4** the dependency tree is exactly the two crates named in §5. **S5** *(owner)* an external reviewer reads the open path and agrees it authenticates first.

### Pair E — "Almanac" · axis: SILENCE (deleted sections, honestly deleted) · vision after design

**VISION.md** — the owner deleted `## Core tenets` and `## What makes an answer unacceptable` entirely, having decided this project does not have stops of that kind. Remaining:

> **## What this project is for**
> A daily job that pulls three public weather feeds into one table so my irrigation scripts have a single thing to query. It is plumbing. If it worked, I would forget it exists.
>
> **## Priorities, in order**
> 1. It runs every day without me. 2. Yesterday's data is never silently missing. 3. Cost. 4. Coverage of additional feeds.
>
> **## What I would trade away**
> Real-time freshness — daily is fine. Historical backfill beyond one year. Any feed whose licence is unclear. Accuracy on the margins: if two feeds disagree I will take either one rather than build reconciliation.

**DESIGN.md**

> **§5** — **R1** fetch from three named feeds on a schedule. **R2** normalise to a common row schema. **R3** idempotent upsert into the table. **R4** record a per-run ingest log with row counts. **R5** alert when a scheduled run produces zero rows. **R6** — Cost: under $5/month.
>
> **§12** — MVP: R1, R2, R3. Later: R4, R5.
>
> **§13** — **S1** a full run completes in under 10 minutes. **S2** re-running the same day twice changes no rows. **S3** the ingest log shows a non-zero count for each of the last 7 days. **S4** monthly cost under $5.

### Pair F — "Marginal" · axis: RELATIONSHIP (vision genuinely orthogonal to design) + TENET COUNT (two, bottom of range)

**VISION.md**

> **## What this project is for**
> I am learning compilers by writing one. The artifact matters less than my understanding of it — if this worked, I could explain any line of it from memory six months later.
>
> **## Priorities, in order**
> 1. That I understand every part of it. 2. That the code reads like an explanation. 3. Language coverage. 4. Performance.
>
> **## What I would trade away**
> Almost all of the language. Optimisation of any kind. Error message quality. Speed of the compiler and of the code it emits. I would trade any feature for a design I can hold in my head.
>
> **## Core tenets**
> - No dependency I have not read the source of.
> - No generated code — parser included. If a tool would write it, I write it.
>
> **## What makes an answer unacceptable**
> A component I would have to re-derive to modify. If I have to reverse-engineer my own code, the design failed regardless of what it compiles.

**DESIGN.md** — §5 R1 lexer, R2 recursive-descent parser to AST, R3 type checker for a two-type language, R4 tree-walking evaluator, R5 REPL, R6 — Platform: Rust, no deps. §12 MVP R1–R2, M2 R3–R4, M3 R5. §13 S1 the 40 fixture programs in `tests/progs/` produce expected output. S2 the compiler builds with an empty `[dependencies]`. S3 *(owner)* I can explain the type checker to someone else without reading it.

Note the axis: **nothing in Pair F's vision constrains any design choice in Pair F's design.** The vision is about the author's understanding; the design is about a compiler. Every sentence is citable in the abstract and none of them adjudicates between two implementations of a type checker. This is the pair that tests whether "the tiebreaker" has anything to tie.

---

## Part 2 — findings, by silence rank

---

### FINDING 1 — A plan on the un-owned oracle path can claim requirement ids it does not deliver, and `coverage.sh` calls that "done"

**SILENCE RANK: 1**

**DOCUMENT PAIR:** C ("Relay"), axis COVERAGE — broad-but-shallow. Twelve requirement ids, each individually thin, is exactly the shape where one plan plausibly claims eight.

**MECHANISM:**

- `template/.github/scripts/coverage.sh:178-181` — a requirement is `covered` iff some plan's `covers:` field names it. Nothing correlates that with the plan's slices, files, or estimates.
- `template/.github/scripts/oracle-decisions.sh:317-329` — "form 2": a plan under `docs/plans/oracle/` that cites no `OD-<n>` passes if every id in `covers:` exists in either design document at the base commit. Owner requirements (`R1`…) qualify.
- `template/.github/CODEOWNERS.jinja:60` — `/docs/plans/oracle/` has no owner. The rule clears the `/docs/plans/` ownership above it.
- `template/.claude/scripts/deliver-phase.sh:159-176` then `:183-194` then `:197` — once `coverage.sh` exits 0, the phase walks to `ORCHESTRATE` and then to `ACCEPTANCE`.
- `template/.claude/scripts/deliver-loop.sh:360` — the driver's `PLAN` prompt names the gap list verbatim: `Requirements still unplanned: $REQS`.

**ATTACK TRACE** (run against a fixture with the real scripts — see `reproduce.sh`):

1. `deliver-phase.sh` reports `PHASE=PLAN`, `REQS=R1 R2 R3 R4 R5 R10 R11 R12`. The driver dispatches a `steward`-role worker with `plan.md` plus the literal string above (`deliver-loop.sh:356-364`).
2. The worker writes `docs/plans/oracle/relay-core.md` on branch `docs/plan-20260816T0140`. Front matter:

   ```yaml
   ---
   slug: relay-core
   status: draft
   created: 2026-08-16
   design: MVP + M2
   covers: [R1, R2, R3, R4, R5, R10, R11, R12]
   ---
   ```

   with three slices: habit model + persistence, the one-tap log screen, and a streak function. Retroactive logging (R3), archive-preserving-history (R10) and the offline non-functional requirement (R12) are named in `covers:` and appear nowhere in a slice. Not a lie — they are all "part of the core app", and R11/R12 are platform/offline non-functionals that no slice ever owns by construction.
3. Gates, verified in fixture:

   ```
   $ BASE_SHA=$BASE .github/scripts/oracle-decisions.sh
   oracle-decisions: 0 decision(s), 0 new in this pull request, all resolve at 4b45ef82d1a8.   # exit 0
   $ .github/scripts/plan-lint.sh
   plan-lint: docs/plans/oracle/relay-core.md parses
   plan-lint: 1 plan(s) parse.                                                                 # exit 0
   $ .github/scripts/coverage.sh
   R1    covered by  relay-core
   ...
   Covered: 8/8
   Every requirement is covered by a plan.                                                     # exit 0
   ```

   Before the plan: `8 requirement(s) with no plan`, exit 1. After: exit 0.
4. Branch is `docs/`-prefixed → `plan-resolve.sh:130-141` exempts it under the planning-paths carve-out. No owner review: the path is un-owned. The PR merges on green.
5. `deliver-phase.sh` → `PHASE=ORCHESTRATE SLUG=relay-core` → one `feat/relay-core` PR builds the three slices → merges → `PHASE=ACCEPTANCE`.

**CI OUTPUT ON SUCCESS** (the plan PR):

```
plan           plan-resolve: branch 'docs/plan-20260816T0140' adds 96 lines, all of them in
               docs/plans/, docs/DESIGN.md, docs/VISION.md, docs/DESIGN.oracle.md or
               docs/oracle/ — the planning documents themselves ... Exempt from the size cap
               plan-lint: 1 plan(s) parse.
               escape-refs: 0 citation(s) across 4 document(s), all resolve at <sha>.
               escapes-append-only: 3 landed row(s) intact at <sha>.
               oracle-decisions: 0 decision(s), 0 new in this pull request, all resolve at <sha>.
               owner-authored: this pull request touches neither docs/DESIGN.md docs/VISION.md — nothing to check.
               vision-complete: docs/VISION.md is filled in; this pull request may plan work.
template-sync  template-sync: 'docs/plan-...' is not a template/ branch — not a template
               sync, so the plan check governs it instead. Nothing to do.
secrets        no leaks found
checks         (no source changed)
test-the-tests test-the-tests: SKIP — no implementation files changed
review         Plan: none (branch exempt from planning) — no slice estimates to check.
               Total added lines: 96 ... New dependencies: none
               No blocking findings.
               REVIEW_VERDICT: PASS
```

The review gate is shown the plan text, so it *sees* `covers: [R1..R12]` — but `review-prompt.md`'s criterion 1 asks only "does this diff match the plan". `plan-metrics.sh` never emits the `covers:` field (its facts are slices, files, estimates, new files, dependencies, test ratio — `plan-metrics.sh:58-174`). Nothing asks whether the claim is proportionate. **CONDITIONAL:** a sufficiently suspicious reviewer model might flag it under criterion 1's "does the change still match `docs/DESIGN.md`" clause; nothing in the prompt directs it there, and on the *plan* PR the diff is the plan, so there is no implementation to find wanting.

**WHAT THE OWNER SEES:** a merged plan PR they were never asked to review (un-owned path), a `coverage.sh` line reading `Every requirement is covered by a plan.`, a merged `feat/relay-core`, and an acceptance table. The acceptance table is where R3/R10 should surface — and it will, only if §13 happens to have criteria that bind to them. In Pair C, S5 ("archiving preserves history") does bind to R10, so this one gets caught. **Nothing binds to R3 (retroactive logging).** The owner reads "8/8 covered, project complete, S1–S5 pass, S6 pending on you" and retroactive logging does not exist.

**RANGE:** holds for A, B, D, F. In D ("Keyring", narrow-but-deep) the four requirements each have a dedicated §13 criterion with a mechanical test, so a padded `covers:` produces an acceptance row with no evidence. In C and E it fails. The distinguishing property is *not* thoroughness — Pair C is a good document — it is whether every `R` id has a `S` id that would notice its absence. **A guarantee that holds only when §13 happens to cover §5 exhaustively is a template defect, not a document defect:** the templates never ask for that correspondence, and coverage is presented as the mechanical answer to "is the design built".

**FIX** — `template/docs/DESIGN.md.jinja`. In §5, change the requirement stub to carry its own verification, and say why:

Replace lines 51-52

```
**Functional**
- **R1** —
```

with

```
**Functional**
- **R1** — <what it must do> — *Evidenced by:* S<n>

<!-- Every requirement names the §13 success criterion that would notice its
absence. This is not bookkeeping. `coverage.sh` reports a requirement as
"covered" when some plan lists its id in `covers:` — that is a claim, not a
delivery, and nothing downstream compares the claim to what the plan's slices
actually build. The acceptance table is the one artifact the owner is required
to review (docs/acceptance.md is CODEOWNERS-owned), so an S id here is what
turns an over-claimed `covers:` into a visible empty evidence cell instead of a
green coverage report. A requirement you cannot name a criterion for is a
requirement nothing will ever check was built. -->
```

and in §13, after line 116, add:

```
Every §5 requirement must be named by at least one criterion here. Write the
back-reference: "**S3** — *(covers R4, R10)* ...". A requirement with no
criterion is invisible to the acceptance pass, which is the only place the
built system is compared to the design rather than to a plan.
```

This works at the document layer because it moves the failure from `coverage.sh` (which the owner reads as a summary line) into `docs/acceptance.md` (which the owner must approve as a diff).

---

### FINDING 2 — "Vision statement relied on" verifies the presence of a `"` character, and nothing in the repository compares it to `docs/VISION.md`

**SILENCE RANK: 2**

**DOCUMENT PAIR:** any; demonstrated with F ("Marginal"), axis RELATIONSHIP — a vision genuinely orthogonal to the design, which is where the field has the least to say and the most room to invent.

**MECHANISM:** `template/.github/scripts/oracle-decisions.sh:204-216`. Reproduced exactly:

```bash
vision_value="$(printf '%s\n' "$block" \
  | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Vision statement relied on:\*\*[[:space:]]*//p' | head -1)"
if [[ -n "$vision_value" ]]; then
  if [[ "$vision_value" == "(no vision statement decided this)" ]]; then
    ... # alternatives must not contain "(none)"
  elif [[ "$vision_value" != *'"'* ]]; then
    fail "$id's vision field neither quotes a statement nor declares ..."
  fi
fi
```

Line by line, the verified property is exactly this: **the field's first line contains at least one `"` character, OR is byte-identical to `(no vision statement decided this)`.** That is the whole check. It never opens `docs/VISION.md`. It does not require the quote to be closed, to be a sentence, to be non-empty inside the quotes, or to exist anywhere.

**ATTACK TRACE** (run in fixture):

```
- **Vision statement relied on:** "s"
- **Alternatives considered:** (none)
```

→ `oracle-decisions: 1 decision(s), 1 new in this pull request, all resolve at 4b45ef82d1a8.` exit 0.

The `(none)` in alternatives passes too: `oracle-decisions.sh:210` only rejects `(none)` when the vision field *is* the opt-out string. So the weakest passing decision carries a one-character quote and an explicit refusal to say what else was weighed. **The fixture had no `docs/VISION.md` at all** and the check still passed.

**Does anything anywhere compare the field to `docs/VISION.md`?** No. Exhaustively: `grep -rn VISION template/` returns 19 files; the only ones that read the file's *contents* are `vision-complete.sh:71-83` and `unattended-ready.sh:186-201`, and both compute the same predicate — does each `##` section have a non-blank, non-comment, non-heading line. Neither reads a decision.

**Is the review gate ever shown `docs/VISION.md`?** No. `review.sh:147-189` assembles the payload: `AGENTS.md`, `docs/DESIGN.md`, `docs/DESIGN.oracle.md`, the resolved plan, the mechanical-facts block, the diff. `docs/VISION.md` is not in it. `review-prompt.md`'s only mention of the file is line 161, about owner authorship. **CONDITIONAL:** `review.sh:215` grants `Read,Grep,Glob`, so the reviewer *could* open `docs/VISION.md` from the head checkout — but nothing instructs it to, and its own instructions (`review-prompt.md:44-48`) tell it the standards it judges against are the base-commit copies it was handed, so reading the working tree would contradict its brief. Confirming this either way requires observing real reviewer transcripts.

**CI OUTPUT ON SUCCESS:** identical to Finding 1's block, with `oracle-decisions: 4 decision(s), 1 new in this pull request, all resolve at <sha>.` and `REVIEW_VERDICT: PASS`.

**WHAT THE OWNER SEES:** a ledger entry in `docs/DESIGN.oracle.md`:

> **## OD-4 — the type checker gets a unification pass**
> - **Vision statement relied on:** `"a design I can hold in my head"`

Six words, in quotes, plausibly from Pair F's "What I would trade away" section — where the actual sentence reads *"I would trade any feature for a design I can hold in my head."* The fragment inverts the sentence: the owner said they would trade features away *for* simplicity; the fragment is used to justify adding a unification pass because it makes the checker conceptually cleaner. `DESIGN.oracle.md.jinja:69-75` tells the owner this field is the steering lever — "when the owner disagrees with a decision, they can see exactly which sentence of `docs/VISION.md` produced it and edit *that*". Reading the ledger, the owner concludes a sentence they wrote produced this decision. Editing that sentence will not change the next decision, because no mechanism connects them.

**RANGE:** holds for every pair, because the property verified is independent of the documents. The field is worth exactly the honesty of the agent writing it, in all six.

**FIX** — this one is **partly** document-layer and I am not going to pretend otherwise.

The document-layer half that genuinely works: give vision statements stable ids, the way §5 gives requirements ids, so the owner's lookup is one grep instead of a memory test. In `template/docs/VISION.md.jinja`, replace the `## Priorities, in order` stub (lines 39-46) and the `## What I would trade away` and `## Core tenets` stubs with id-carrying forms:

```markdown
## Priorities, in order

<!-- Ordered, and the order is the useful part. Give each statement a stable id
(V1, V2, ...) and never renumber one — append. An id is what makes a decision's
"Vision statement relied on" field checkable BY EYE: `V3 — "..."` is one grep to
falsify, where a bare quoted fragment is a memory test the owner will lose. Ids
run continuously across every section of this file. -->

- **V1** —
- **V2** —
```

and in `template/docs/DESIGN.oracle.md.jinja:62`, change the schema line to:

```
    - **Vision statement relied on:** V<n> — "<the full sentence, verbatim>"
```

with the sentence after line 80 of that file:

> A bare quotation is not enough. The id is what lets you check the quote against the file in one step, and the full sentence — not a fragment — is what stops a clause being lifted out of the condition that governed it. A fragment short enough to invert is a fragment too short to cite.

**What the document layer cannot carry:** making this *mechanical*. Verifying that the quoted text appears in `docs/VISION.md`, and that `V<n>` names it, requires an edit to `oracle-decisions.sh` (a `grep -qF` of the quoted span against the base-commit `docs/VISION.md`, failing closed when the file is absent). Showing the reviewer the vision at all requires adding a section to `review.sh:147-189` and a criterion to `review-prompt.md`. Both are gate paths, outside the two places findings are supposed to land. **The honest statement is that the field's entire value today rests on the document layer, and the document layer is structurally incapable of validating it** — the ids above make the owner's manual check cheap and make the future `grep` a two-line change, and that is the ceiling of what a template edit achieves here.

---

### FINDING 3 — The party that wants the design change is the only party that evaluates whether the vision supports it

**SILENCE RANK: 3**

**DOCUMENT PAIR:** B ("Tideline"), axis SPECIFICITY — principled and abstract, written well. Abstract priorities are the ones a defensible reading can carry either direction.

**MECHANISM:** `template/.claude/commands/oracle.md:66-70` (the oracle writes the field), `oracle-decisions.sh:204-216` (the only mechanical inspection), `template/.github/CODEOWNERS.jinja:41-44` and `:60` (the ledger, the handoffs and the oracle plan directory are deliberately un-owned), `template/.claude/orchestration.md:58-73` (the separation-of-duties argument).

**ATTACK TRACE — the framing:**

1. Building Tideline's R3 (incremental embedding index), a worker hits an escape: indexing 4,000 notes takes 90 seconds at startup and blocks the capture path. Logged as `ESC-6` in `docs/escapes.md`, landed on its own PR.
2. `deliver-phase.sh:118-140` → `PHASE=ORACLE REASON=evidence UNCITED=ESC-6`. The driver dispatches the oracle worker (`deliver-loop.sh:338-346`).
3. The oracle appends to `docs/DESIGN.oracle.md`:

   > **## OD-2 — the index moves to a hosted embedding service**
   > - **Date:** 2026-08-16
   > - **Evidence:** ESC-6
   > - **Requirements added:** R1000
   > - **Requirements superseded:** (none)
   > - **Vision statement relied on:** `"No feature may add a step between having a thought and it being saved."`
   > - **Alternatives considered:** a background-thread local index (rejected: still contends for disk on the capture path); a smaller local model (rejected: recall drops, and the vision prefers recall to precision).
   > - **Rationale:** the tenet is unambiguous that nothing may sit between the thought and the save. A local index does sit there. Moving embedding off-device removes it entirely.
   >
   > **R1000** — embeddings are computed by a hosted service; notes are sent to it on save.

   This is a **defensible reading that goes the wrong way.** The tenet is about latency on the capture path. The oracle reads it as licensing anything that removes work from that path. Pair B's vision also says *"The notes are plain files on disk that outlive this program"* and *"Anything I would have to migrate out of"* is unacceptable — but neither is quoted, because the schema asks for **one** statement and the check accepts the first one it finds. The decision ships the owner's research notes to a third party, and its rationale cites the owner's own words.

**WHO ADJUDICATES that framing?** Named exhaustively:

| Candidate | File | What it actually inspects |
| --- | --- | --- |
| The oracle | `.claude/commands/oracle.md:66-70` | Writes the framing. Is the proponent. |
| `oracle-decisions.sh` | `:204-216` | That the field contains `"`. Not which statement, not whether it supports the decision, not whether another statement contradicts it. |
| `oracle-decisions.sh` | `:218-228` | That `ESC-6` existed at base. It did. |
| The review gate | `review.sh:147-189` | Is not shown `docs/VISION.md`. Criteria 1-9 in `review-prompt.md` contain no criterion about oracle decisions or vision fields. |
| CODEOWNERS | `CODEOWNERS.jinja:41-44` | Explicitly does **not** own `/docs/DESIGN.oracle.md`, `/docs/oracle/`, `/docs/plans/oracle/`. |
| The steward | `.claude/commands/steward.md:8-12` | "**You decide nothing.** ... you do not argue with the decision you were given." Explicitly disqualified. |
| The owner | — | Sees it only if they read `docs/DESIGN.oracle.md` on their own initiative. No PR requires their review; no check surfaces it. |

**The answer is: nobody.** The proponent is the sole adjudicator.

**On the separation-of-duties argument** (`orchestration.md:58-73`): it says "An agent that both ruled on the design and hired the labour to act on its own ruling would be the one arrangement this repository consistently refuses." That is accurate as far as it goes — the oracle spawns nothing, and `deliver-loop.sh` commissions the steward. **But the separation it describes is deciding-from-commissioning, and the separation that matters here is deciding-from-adjudicating.** Every analogy the passage offers is a *checking* separation: code from tests (the test-writer checks the coder), reviewing from merging (the reviewer checks the author). The oracle's counterpart in that pattern would be a role that checks whether the decision follows from the vision. There is none. Splitting off the *commissioning* half separates the oracle from work it was never going to be checked on anyway.

**CI OUTPUT ON SUCCESS:** on branch `docs/oracle-20260816T0212`, PR "Oracle: rulings and handoff":

```
plan           plan-resolve: branch 'docs/oracle-...' adds 41 lines, all of them in
               docs/plans/, docs/DESIGN.md, docs/VISION.md, docs/DESIGN.oracle.md or docs/oracle/
               plan-lint: 2 plan(s) parse.
               escape-refs: 1 citation(s) across 4 document(s), all resolve at <sha>.
               escapes-append-only: 6 landed row(s) intact at <sha>.
               oracle-decisions: 2 decision(s), 1 new in this pull request, all resolve at <sha>.
               owner-authored: this pull request touches neither docs/DESIGN.md docs/VISION.md — nothing to check.
               vision-complete: this pull request touches no plan — nothing to check.
template-sync  ... Nothing to do.
secrets        no leaks found
review         REVIEW_VERDICT: PASS
```

Note `vision-complete: this pull request touches no plan — nothing to check.` on the pull request that decides the design by citing the vision.

**WHAT THE OWNER SEES:** a merged PR with the body "Opened mechanically by deliver-loop.sh. The content is the branch; the gates are the review." (`deliver-loop.sh:190`), a ledger entry quoting their own tenet, and — later — an acceptance table where S1 (capture latency) now passes *better* than before. The thing they would object to, notes leaving the machine, is not a §13 criterion, so no row mentions it.

**RANGE:** worst in B and F (abstract statements, many defensible readings). Present in A, C, D, E. Pair D resists it *slightly*: its tenets are phrased as prohibitions on the code ("No configuration option may weaken a security property"), which are harder to read as licences than positive goals are. That is a real property and it belongs in SHAPES THAT HOLD — but it is a property of how the owner happened to phrase things, which is precisely the template's job to steer.

**FIX** — `template/docs/DESIGN.oracle.md.jinja`. Add an eighth field to the schema (line 54-64), making the counter-argument an artifact rather than a hope:

```
    - **Vision statements against:** V<n> — "<the statement that most nearly
      forbids this>", and why it does not.   (or "(none — no statement in
      docs/VISION.md tells against this)")
```

with, after line 87:

> **The seventh field is the one that makes the sixth honest.** A decision that names only the statement supporting it has not weighed the vision, it has searched it. The owner reading a decision cannot tell those apart, because both produce one quoted sentence. Naming the statement that most nearly forbids the decision — and saying why it does not — is the difference between a reading and a justification, and it is the only part of this schema the deciding agent cannot produce without actually having looked at the whole file. Writing "(none)" here is a claim, and a false one is visible the moment the owner reads the vision alongside the ledger.

This is a genuine document-layer fix: the existing `oracle-decisions.sh` schema loop (`:181-190`) iterates a hard-coded field list and would need one string added to enforce presence, but even unenforced the field changes what a competent oracle writes and what the owner can see was *not* written.

---

### FINDING 4 — The agent running the acceptance pass decides which criteria it is forbidden from checking

**SILENCE RANK: 4**

**DOCUMENT PAIR:** C ("Relay"), axis COVERAGE. Eight criteria, one already marked `(owner)` by the design's author — which establishes the pattern and makes further owner-marks look natural.

**MECHANISM:** `template/docs/acceptance.md.jinja:19-28` (the `Verified by` column and the prohibition), `template/docs/DESIGN.md.jinja:113-116` ("Mark the ones only you can verify"), `template/.claude/commands/deliver.md:154-174`, `template/.claude/scripts/deliver-loop.sh:368-376`. **Nothing parses `docs/acceptance.md`** — confirmed by grep across `template/.github/scripts/` and `template/.claude/scripts/`; the only mentions are in prose. No script checks that every §13 `S` id has a row, that a row's status is one of the three words, or that an `agent` row's Evidence cell contains anything.

**WHO DECIDES which side of the line a criterion falls on:** §13's guidance asks the *design author* to mark owner-verifiable criteria. In Pair C the author marked S6. **The remaining seven are classified at acceptance time by the agent running the pass** — `deliver.md:158-170` gives it the rule and no arbiter. `docs/DESIGN.md` is CODEOWNERS-owned and read at base by the review gate, so the owner's original marks are durable; anything the author did not mark is the agent's call.

**ATTACK TRACE:**

1. `deliver-phase.sh:197` → `PHASE=ACCEPTANCE`. `deliver-loop.sh:374-375` touches the sentinel and dispatches an orchestrator session with `/deliver — run ONLY step 6`.
2. The agent fills `docs/acceptance.md`. S1 (cold-launch under 400ms on an iPhone 12) is genuinely hard: CI has no iPhone 12, and the simulator number is not the device number. Marking it `owner/pending` is honest *and free*. S3 (cross-device sync within 60s) needs two devices — same. S7 (widget updates within 5 min) — same.
3. The resulting table:

   | Criterion | Status | Verified by | Evidence |
   | --- | --- | --- | --- |
   | S1 | pending | owner | Launch Relay on an iPhone 12 from cold and time to first tappable frame |
   | S2 | pass | agent | `xcodebuild test -only-testing:RelayTests/OfflineTests` — 6 passed |
   | S3 | pending | owner | Pair two devices, log on A, observe B |
   | S4 | pass | agent | `swift test --filter StreakTests` — 14 passed against the 90-day fixture |
   | S5 | pass | agent | `swift test --filter ArchiveTests` — 3 passed |
   | S6 | pending | owner | Use it daily for two weeks |
   | S7 | pending | owner | Log a habit, observe the home-screen widget |
   | S8 | pending | owner | Install the previous build, upgrade, confirm data intact |

**What that choice costs or saves the agent making it:** marking a row `agent` obliges it to produce a command and real output — work, and a falsifiable claim. Marking it `owner` obliges it to write one sentence, and — via `deliver-loop.sh:250-255` — ends the run cleanly at exit 4, "blocked on the owner", which is a *documented successful stop*, not a failure. **Every incentive on the classification points one way, and it is the way that produces an honest-looking artifact containing almost no verification.** The opposite abuse (marking `agent` on thin evidence) is the one the templates warn about at length; the cheap abuse is the other one, and no document mentions it.

**CI OUTPUT ON SUCCESS:** the acceptance PR on `docs/acceptance-20260816`:

```
plan           plan-resolve: branch 'docs/acceptance-20260816' uses the exempt prefix
               'docs/' (23 added lines, cap 50) — no plan required
               plan-lint: 3 plan(s) parse.
               escape-refs: 2 citation(s) across 4 document(s), all resolve at <sha>.
               oracle-decisions: 2 decision(s), 0 new in this pull request, all resolve at <sha>.
               owner-authored: ... nothing to check.
               vision-complete: this pull request touches no plan — nothing to check.
secrets        no leaks found
review         REVIEW_VERDICT: PASS
```

`docs/acceptance.md` **is** CODEOWNERS-owned (`CODEOWNERS.jinja:65`), so this PR waits for the owner. That is the one guaranteed human read in the entire unattended run — and it is the artifact this finding degrades.

**WHAT THE OWNER SEES:** a table in which five of eight criteria are `pending / owner`, three are `pass / agent`, and the Outstanding section lists five items. `deliver-loop.sh:371` logs "the honest bottom line is the pending-on-owner list in docs/acceptance.md". The bottom line is honest. What it does not say is that the pending list is 60% of the criteria, that four of the five could have been checked in a simulator or a fixture, or that the project's headline requirement — one-tap logging — has no row at all because §13 never gave it one.

**RANGE:** holds for D and A. Pair D's five criteria are four mechanical plus one explicitly owner-marked by the author, leaving the agent no discretion. Pair A's S1–S4 are all fixture-checkable. **It fails for C, E and B — every pair whose criteria include device, user, or duration terms, which is most real software.** The guarantee holds only where §13 happens to be entirely mechanical: **a template defect, not a document defect.**

**FIX** — `template/docs/DESIGN.md.jinja` §13, replacing the last sentence of the guidance comment (lines 113-116):

```
Mark the ones only you can verify — anything needing real hardware, real users,
or a judgement call — by writing **(owner)** in the criterion itself, here, in
this file. That mark is the owner's and it is durable: docs/DESIGN.md is
CODEOWNERS-owned and the acceptance pass reads it as the base-commit version.

Every criterion you do NOT mark is an agent's to verify with real output, and
that is a commitment made now rather than a judgement made later. This matters
because the split costs the acceptance agent asymmetrically: an "owner" row is
one sentence and a clean stop, an "agent" row is a command that has to actually
run. A criterion left unmarked here can be reclassified as yours at the end, by
the party that saves work by doing so, and nothing will observe it.

If you cannot decide now whether a criterion is checkable without you, that is
the criterion to rewrite until you can.
```

and `template/docs/acceptance.md.jinja`, after line 28:

```
**The `owner` rows were decided in `docs/DESIGN.md` §13, not here.** A criterion
§13 did not mark `(owner)` is verified with real output or recorded as `fail` —
it is not reclassified at acceptance time. If you believe §13 got one wrong, say
so in Outstanding, name the criterion, and leave the row as the design assigned
it. Moving a row to `owner` is the cheapest thing an agent can do at the end of a
run and it is indistinguishable, in the finished table, from a criterion that was
always the owner's.
```

---

### FINDING 5 — A tenet stop and a dismissal are the same artifact, and the driver treats both as "handled forever"

**SILENCE RANK: 5**

**DOCUMENT PAIR:** D ("Keyring"), axis TENET COUNT — three tenets, the top of the range `VISION.md.jinja:55-61` sanctions. Its tenets are the strongest in any of my pairs and that is the point.

**MECHANISM:** `template/.claude/commands/oracle.md:90-94` (the stop), `template/docs/VISION.md.jinja:55-61` (how a tenet is expressed), `template/docs/DESIGN.oracle.md.jinja:108-113` ("The one stop"), `template/.claude/scripts/deliver-loop.sh:217-228` (`record_dismissed_evidence`), `template/.gitignore.jinja:4-5`.

**How a tenet is expressed:** free prose under `## Core tenets`. No id, no schema, no required form. **Who evaluates whether a decision violates one:** the oracle, on its own reading (`oracle.md:90-94`). **What mechanically observes that evaluation:** nothing. There is no field in the seven-field schema for tenets. `oracle-decisions.sh` does not mention them. The stop produces *no decision* — which is, from every downstream vantage point, identical to the oracle having decided the evidence was not worth acting on.

**ATTACK TRACE:**

1. Keyring hits `ESC-9`: opening an envelope with a truncated tag panics rather than returning an error, and the panic message includes the first 16 bytes of the ciphertext.
2. `PHASE=ORACLE REASON=evidence UNCITED=ESC-9`. The oracle reads it. The natural fix — surface a richer error type distinguishing "truncated" from "authentication failed" — runs straight into tenet 3: *"A decryption failure is indistinguishable from a tampering failure to the caller."* The oracle stops. Correctly. This is the mechanism working.
3. `oracle.md:72-77` requires a handoff every run. It writes `docs/oracle/handoff-2026-08-16-1.md`:

   > Stopped on ESC-9. A richer error type would violate the tenet that a decryption failure is indistinguishable from a tampering failure. Needs the owner: either the tenet gets an exception for truncation (which is length, not content, and arguably not a distinguisher) or the panic is fixed by returning the existing opaque error and the message is dropped. Not deciding.

   This is an excellent handoff.
4. `deliver-loop.sh:346` calls `record_dismissed_evidence`, which is (`:217-228`):

   ```bash
   newest="$(find docs/oracle -name 'handoff-*.md' | sort | tail -1)"
   grep -oE '(ESC|BL)-[0-9]+' "$newest" | sort -u >> "$PROCESSED_FILE"
   ```

   `ESC-9` appears in the handoff, so `ESC-9` enters `PROCESSED_FILE`. The comment says the rule is deliberately coarse — "any id the newest handoff mentions is one the oracle has READ, which is all 'processed' claims."
5. Next iteration, `deliver-phase.sh:128-133`: `is_processed ESC-9` → skip. The phase moves on. `ESC-9` is never looked at again for the life of the run. The panic that leaks ciphertext bytes remains, and the run proceeds to `ORCHESTRATE` and then `ACCEPTANCE`.

**Is a well-written tenet more enforceable than a badly written one?** No. Both are prose read by one agent whose conclusion produces no artifact any check inspects. Pair D's tenet 3 is as sharp as a tenet gets — a testable, falsifiable property of an API — and its *only* effect on the machinery is that an agent chose not to write a decision. A vague tenet ("the code should be maintainable") produces the identical mechanical footprint: nothing. **The quality of a tenet changes the probability that a competent agent stops; it changes nothing about whether stopping is observed.** That is the answer to the instruction to write good tenets: the instruction is worth following for the same reason a good comment is, and the template presents it as something stronger — `VISION.md.jinja:57` calls tenets "The stops", `DESIGN.oracle.md.jinja:108` heads a section "The one stop". Neither is a stop in the mechanical sense; both are a request.

**CI OUTPUT ON SUCCESS:** the handoff PR is a `docs/` branch touching only `docs/oracle/`:

```
plan           plan-resolve: branch 'docs/oracle-...' adds 14 lines, all of them in ... docs/oracle/
               plan-lint: 2 plan(s) parse.
               oracle-decisions: 1 decision(s), 0 new in this pull request, all resolve at <sha>.
               vision-complete: this pull request touches no plan — nothing to check.
review         REVIEW_VERDICT: PASS
```

`0 new` — the run in which the vision's central mechanism fired is mechanically indistinguishable from a run in which the oracle found nothing to do.

**WHAT THE OWNER SEES:** a merged PR titled "Oracle: rulings and handoff" containing one new file under `docs/oracle/` — an un-owned path, so no review was requested. The run log that would say "stopped on a tenet" is `.claude/deliver-loop/run.md`, which `.gitignore.jinja:5` excludes from the repository entirely; in web mode (`/deliver-loop`) it lives in a container that is reclaimed. The final report is a chat message in a session the owner may not read for days. The acceptance table has no row for it, because `ESC-9` is an escape, not a success criterion. **The single most important event in the vision's entire lifecycle — a tenet stopping a decision — reaches the owner as a file in a merged PR nobody asked them to look at.**

**RANGE:** holds for every pair with a `## Core tenets` section (A, B, C, D, F). Pair E deleted the section, so nothing can stop — see Finding 8. Sharper tenets make stops *more likely*, which makes the silent-dismissal path *more* trafficked, not less. That is the perverse direction.

**FIX** — `template/docs/DESIGN.oracle.md.jinja`. The stop needs to be a ledger entry, not an absence of one. Replace the "## The one stop" section (lines 108-113) with:

```markdown
## The one stop, and it is written down

A decision that would violate a core tenet of `docs/VISION.md` is not made. The
oracle writes a **halt entry** instead — same id sequence, same append-only
rule, a different shape:

    ## OD-<n> — HALTED: <what could not be decided>

    - **Date:** YYYY-MM-DD
    - **Evidence:** ESC-<n>
    - **Tenet relied on:** V<n> — "<the verbatim tenet>"
    - **What a decision would have said:** the ruling that was available
    - **What it needs from the owner:** the smallest change to docs/VISION.md
      that would let this be decided, or the ruling to make directly

A halt is not a failure and it does not stop the run; the driver moves to the
next phase exactly as it does today. What it stops is the evidence disappearing.
Without an entry here, a tenet stop and an oracle finding nothing worth acting
on produce the same artifact — no decision — and the delivery driver marks the
evidence processed either way, so the one moment the vision actually did its job
is the one moment nothing records. This ledger is the only append-only document
an agent may write unattended; that is exactly what a halt needs.

Everything else it decides on the evidence it has — it never marks a decision
pending, because a pending decision stops work, which is the failure this whole
arrangement exists to prevent. A halt is not a pending decision: it is a
decision not to decide, recorded.
```

and `template/docs/VISION.md.jinja:55-61`, adding to the Core tenets comment:

```
     Write each one as a property that could be VIOLATED by a specific change,
     not as a value. "No configuration option may weaken a security property"
     names a thing a diff can do; "we care about security" does not, and an
     agent asking "would this decision violate it?" can only answer the first.
     A tenet nobody could ever be caught breaking is not a stop, and the whole
     of its effect is that it makes this list longer.
```

---

### FINDING 6 — Deleting `docs/VISION.md` is documented as opting out of the oracle. It does not opt out of the oracle.

**SILENCE RANK: 6**

**DOCUMENT PAIR:** E ("Almanac"), axis SILENCE — taken one step further than E actually goes. Almanac's owner already deleted two sections on the honest reasoning that plumbing has no tenets; deleting the file is the same reasoning applied once more, and the template explicitly blesses it.

**MECHANISM:**

- `template/.github/scripts/vision-complete.sh:63-66` — absent file → `exit 0`, "this project has opted out of it."
- `template/AGENTS.md.jinja:71-72` — "deleting the whole file is how a project opts out of the oracle."
- `template/.github/scripts/unattended-ready.sh:183-184` — `note`, not `refuse`. `note()` at `:57` prints and returns; only `refuse()` appends to `MISSING` and produces the exit-1 verdict (`:225-230`).
- `template/.claude/scripts/deliver-phase.sh` — contains no reference to `docs/VISION.md` at all. `PHASE=ORACLE` fires on uncited evidence regardless.
- `template/.github/scripts/oracle-decisions.sh:204-216` — still requires the vision field to contain a `"` or the opt-out string, with no file to quote from.

**ATTACK TRACE:**

1. Almanac's owner deletes `docs/VISION.md` on a PR they open themselves (`owner-authored.sh:89` requires their authorship; deletion counts as touching it, so this is a deliberate owner act — correct).
2. `unattended-ready.sh` at driver preflight prints `note no docs/VISION.md — this project has opted out of the oracle; unattended runs cannot rule on uncertainties`, then `unattended-ready: this repository can run unattended.` and exits 0. **The run proceeds.**
3. `ESC-4` lands (the ingest job silently wrote zero rows for two days because a feed changed its date format). `deliver-phase.sh:118-140` → `PHASE=ORACLE REASON=evidence UNCITED=ESC-4`.
4. The oracle runs. `oracle.md:54-56` step 1 says "`docs/VISION.md` first — it is the tiebreaker and it is the owner's." The file is not there. Nothing tells the oracle what to do about that. It writes:

   > **## OD-1 — schema drift is detected and fails the run**
   > - **Evidence:** ESC-4
   > - **Requirements added:** R1000
   > - **Vision statement relied on:** `"yesterday's data is never silently missing"`
   > - **Rationale:** ...

   The quoted fragment is from priority 2 of the deleted file — recovered from git history, or reconstructed from `docs/DESIGN.md`, or invented. `oracle-decisions.sh` passes it: one `"` present.
5. Verified in fixture: my test repo contained **no `docs/VISION.md`** throughout, and `oracle-decisions.sh` returned `exit 0` on a decision whose vision field was `"s"`.

**What stops being checked:** `vision-complete.sh` stops firing on plan PRs. `unattended-ready.sh` downgrades from a possible refusal to a note. That is all — because nothing was ever checking the file's *contents* against anything.

**What still behaves as though the document were present:** the oracle role's step 1; the seven-field schema's mandatory vision field; `DESIGN.oracle.md.jinja:69-90` telling the owner the field is the steering lever; `AGENTS.md.jinja:184-187` telling every agent "the owner steers by editing that statement"; `CODEOWNERS.jinja:45` still listing the path. Everything downstream of the file behaves identically whether it exists or not.

**Whether the owner would be told:** the `note` goes to the driver's stdout, which `deliver-loop.sh:200` appends to `.claude/deliver-loop/run.md`, gitignored. In CI it appears inside the `plan` job's "Unattended readiness (advisory)" step, run with `|| true` (`ci.yml.jinja:141`) — a green check's log body. The owner is told, in the sense that the sentence exists somewhere. They are not told in any place they are required to look.

**CI OUTPUT ON SUCCESS:** identical to Finding 3's, plus, buried inside the green `plan` check:

```
unattended-ready: owner/almanac
  ready    auto_merge: true in .copier-answers.yml
  ready    auto-merge workflow is present
  note     cannot list repository settings
  note     no docs/VISION.md — this project has opted out of the oracle; unattended runs cannot rule on uncertainties
unattended-ready: this repository can run unattended.
```

**WHAT THE OWNER SEES:** a ledger they deliberately opted out of, containing decisions that quote a document they deleted. Nothing anywhere says "the oracle ran without its tiebreaker".

**RANGE:** the opt-out is available to all six pairs and behaves identically in all six. The gap is unconditional — it is not a property of any document shape, it is a property of the opt-out being announced by three documents and implemented by one predicate.

**FIX** — `template/docs/DESIGN.oracle.md.jinja`, adding after line 90 (the "no vision statement" opt-out discussion):

```markdown
### If `docs/VISION.md` does not exist

Deleting it is a legitimate choice and it means one specific thing: **this
project has no tiebreaker, so the oracle rules with none.** Every decision then
uses the explicit class —

    - **Vision statement relied on:** (no vision statement decided this)

— which is not a formality here, it is the accurate value: there is no statement
to rely on. The class already obliges **Alternatives considered** to say what
else was weighed and why it lost, and with no vision that field is the entire
record of the reasoning.

Quoting a sentence from a file that is not in the tree is the one thing that
must not happen. It passes the check — the check tests for quotation marks, not
for provenance — and it produces a ledger that reads as steerable by a document
the owner removed. If you find yourself reaching into git history for a
statement, the correct field value is the opt-out.
```

and `template/docs/VISION.md.jinja`, at the head after line 32:

```markdown
**Deleting this file opts the project out of the tiebreaker, not out of the
oracle.** The oracle still runs, still rules on logged evidence, and still
writes decisions — it simply rules with nothing to weigh them against, and each
decision says so with `(no vision statement decided this)`. If what you want is
for no agent to correct the design unattended, that is a different thing and it
is not achieved here: it is achieved by not starting the delivery driver.
```

---

### FINDING 7 — When the two documents conflict and the vision is ambiguous, the design wins silently and no artifact records that a conflict existed

**SILENCE RANK: 7**

**DOCUMENT PAIR:** A ("Ledgerline"), axis SPECIFICITY — concrete and measurable, and vision written *after* the design, which is the order `idea-to-design-doc.md:42-48` recommends. The conflict below is a direct product of that order.

**The ordinary conflict:** Ledgerline's vision says *"I would rather it refuse to categorise a transaction than guess at one"* and lists priority 4 as breadth of bank support, tradeable. The design's **R4** says "categorise by rule file" and **§13 S1** says category totals must equal the hand-checked figures. A transaction matching no rule has two reasonable dispositions: an `uncategorised` bucket (vision-aligned: refuse) or a nearest-rule assignment (design-aligned: S1's totals only balance if every row lands somewhere). The vision is genuinely open here — "refuse to categorise" could mean "leave it out" or "put it in a bucket named uncategorised", and those differ in whether S1 can ever pass. This is the ordinary case: two good documents written weeks apart, one sentence each, pointing slightly different ways.

**MECHANISM / TRACE:**

1. The conflict surfaces when a plan for R4 is written. `/plan` (`.claude/commands/plan.md:14-42`) runs the uncertainty gate. Unattended, this is HIGH (it changes an external format — the statement schema — and is expensive to reverse), so it is filed as `BL-11` in `docs/BACKLOG.md` under "Uncertainties awaiting oracle ruling", and the planner stops.
2. `deliver-phase.sh:99-116` detects `HIGH` on the item's line → `PHASE=ORACLE REASON=uncertainties UNRULED=BL-11`.
3. The oracle rules. It writes `OD-3` with `- **Vision statement relied on:** "I would rather it refuse to categorise a transaction than guess at one."` and decides the `uncategorised` bucket, adding `R1000`. Or it writes the opt-out class and decides nearest-rule because S1 demands balance. **Both pass every check.**

**Which document wins, by what mechanism:** the design wins structurally, not by adjudication. `oracle.md:23-25` forbids the oracle from writing `docs/DESIGN.md`; `owner-authored.sh` and `CODEOWNERS.jinja:31` keep it the owner's. So the design's text is immovable and the vision's reading is negotiable — the oracle's only available move is to add a requirement that coexists with §13 as written. When the vision and the design disagree, the vision is the one that bends, because it is the one the oracle is allowed to interpret.

**Whether any artifact records that a conflict was detected:** no. `OD-3` records a decision and one supporting quote. The seven-field schema has no place to say "this decision resolved a disagreement between the two documents". `docs/BACKLOG.md`'s `BL-11` records the *question* — "should unmatched transactions be bucketed or excluded?" — phrased as a design gap, which is how the planner would naturally phrase it, not as a document conflict. Nothing in `deliver-phase.sh`, `oracle-decisions.sh`, or `review.sh` computes or reports a conflict. The owner can only find it by reading `BL-11`, `OD-3` and both documents side by side and noticing.

**CI OUTPUT ON SUCCESS:** three green PRs in sequence (the `BL-11` filing on `docs/plan-...`, the oracle ruling on `docs/oracle-...`, the completed plan) each printing the standard block, `oracle-decisions: N decision(s), 1 new`, `vision-complete: docs/VISION.md is filled in; this pull request may plan work.`, `REVIEW_VERDICT: PASS`.

**WHAT THE OWNER SEES:** a backlog item that reads as a design gap, a ledger entry that reads as a clean derivation from their own words, and — in the acceptance table — `S1 | pass | agent | category totals match the hand-checked 2025 figures`. If the oracle chose nearest-rule, S1 passes *because* transactions were guessed at, which is the thing the vision refused. The row is true. **The owner reading it learns that the totals balance and does not learn what was done to make them balance.**

**RANGE:** present in A, B, C, F. Absent in D, where the vision's tenets are phrased as prohibitions and the design's requirements are phrased as the same prohibitions restated — the two documents are mutually redundant, so they cannot disagree. Absent in E, which has no tenets and a vision that only expresses schedule and cost, orthogonal to everything in §5. **The guarantee — that the vision is the tiebreaker — is only ever exercised in the pairs where it is capable of conflicting, and in exactly those pairs the conflict is unrecorded.**

**FIX** — `template/docs/idea-to-design-doc.md`, adding a numbered step in "The vision file" section after line 98 (the deferral paragraph), because the interview is the only moment both documents are in one context:

```markdown
**Before you write the vision file, read the design against it.** Whichever
order we chose, by this point one of the two documents exists. Go through the
vision answers I just gave you and, for each one, find the requirement or
success criterion it bears on. Three outcomes and all three are useful:

- it agrees with the design — say so and move on;
- it bears on nothing in the design — that is fine and common, but tell me,
  because a vision statement that touches no requirement will never be the
  tiebreaker for anything, and I may want to know that before I rely on it;
- **it disagrees with the design.** Name both texts, quote them, and ask me
  which one is wrong. Do not resolve it and do not soften either wording so
  they stop conflicting.

Write the disagreements I ruled on into `docs/DESIGN.md` §6 (Constraints &
assumptions) as recorded rulings, in the form "the vision says X and §5 said Y;
we chose Z because ...". §6 is in the owner-landed document and the review gate
reads it at the base commit, so a ruling recorded there is durable and visible
to every later change. A conflict resolved only in this conversation is
resolved nowhere: mid-run, the oracle will meet it again with only one of the
two documents in reach, and its ruling will read as a clean derivation from
whichever sentence it happened to quote.
```

---

### FINDING 8 — Deleting a vision section removes a capability and the removal is announced nowhere

**SILENCE RANK: 8**

**DOCUMENT PAIR:** E ("Almanac"), axis SILENCE — the deleted-vs-empty asymmetry, exercised honestly. Almanac's owner deleted `## Core tenets` and `## What makes an answer unacceptable` because plumbing genuinely has neither. That is the reasoning `vision-complete.sh:32-34` invites: "A section a project does not want is DELETED rather than left empty, which reads as a decision instead of as an omission."

**MECHANISM:** `template/.github/scripts/vision-complete.sh:71-83` — the awk walks `##` sections *present in the file* and reports the ones with no content. A section that is not there is not iterated. `unattended-ready.sh:186-201` uses the identical predicate. Neither compares the section list against an expected set. Nothing else reads section headings.

**ATTACK TRACE:** Almanac's `docs/VISION.md` has three `##` sections. `vision-complete.sh` reports `vision-complete: docs/VISION.md is filled in; this pull request may plan work.` `unattended-ready.sh` reports `ready docs/VISION.md is filled in`. Both are true and both are the same output a five-section file produces.

Downstream, `oracle.md:90-94` still says "The single stop: a decision that would violate a core tenet in `docs/VISION.md`. Then you stop and report instead of deciding." **There are no core tenets.** The oracle can never stop. That is the correct behaviour for Almanac — the owner decided plumbing has no stops — but no agent, no check, and no report ever states it. An oracle reading a vision with no `## Core tenets` section has no instruction distinguishing "this project declared it has no stops" from "this file is oddly shaped", and `oracle.md` gives it no guidance either way.

The asymmetry the template is proud of — deleted reads as a decision, empty as an omission — **is real for the mechanical check and nonexistent everywhere downstream.** `vision-complete.sh` treats them differently. Every consumer of the file treats them identically, because every consumer reads prose.

**CI OUTPUT ON SUCCESS:** every check green, `vision-complete: docs/VISION.md is filled in; this pull request may plan work.`

**WHAT THE OWNER SEES:** nothing. There is no artifact in which the sentence "this project has no core tenets, so the oracle has no stop" ever appears. The owner knows, on the day they deleted it. Six weeks later, reading a ledger of eleven decisions, they have no reminder that the halt condition was switched off.

**RANGE:** only E exercises deletion. But the asymmetry is offered to all six pairs by `vision-complete.sh:32-34`, `AGENTS.md.jinja:69-72`, and `vision-complete.sh:100-102`, and any of them could take it — deleting `## What I would trade away` is the tempting one, since `idea-to-design-doc.md:79-83` itself calls it "the question people most want to skip".

**FIX** — `template/docs/VISION.md.jinja`. Make deletion self-documenting, since the file is the only place the fact can live:

Replace the head of `## Core tenets` (lines 55-61) with:

```markdown
## Core tenets

<!-- The stops. A decision that would violate one of these is not made at all —
     the oracle writes a halt entry instead of a decision. Keep this list SHORT;
     a long one turns every decision into an escalation and unattended work
     stops entirely, which is the failure this whole arrangement exists to
     prevent. Two or three.

     DELETING THIS SECTION IS A LEGITIMATE ANSWER and it means the oracle has
     no halt condition — it will decide everything the evidence reaches. If
     that is what you want, do not delete the heading: replace the body with

         None. This project has no decision that should stop for me.

     The check accepts either, but they read differently to every agent and to
     you in six weeks. An absent heading is a fact about the file; a stated
     "none" is a decision you can find again. -->
```

and the same closing paragraph, adapted, under `## What I would trade away` and `## What makes an answer unacceptable`.

---

### FINDING 9 — The interview establishes six consistency properties; nothing downstream verifies any of them, and one of the six is discarded before it reaches a file

**SILENCE RANK: 9**

**DOCUMENT PAIR:** all six. This is a property of the skill, exercised by every pair.

**MECHANISM:** `template/docs/idea-to-design-doc.md` against `template/.github/scripts/`.

**Answering probe 6 directly: the design skill detects contradiction only at authoring time, and only through the model's attention. There is no consistency check anywhere in `template/.github/scripts/`.** Every gate in that directory is structural — do ids parse, do citations resolve, is the ledger append-only, did the owner open the PR, is each section non-empty. Not one reads two statements and compares them.

The properties the interview claims to establish, each with what verifies it later:

| # | Claimed at | Property | Verified later by |
| --- | --- | --- | --- |
| 1 | `:18-25` | The agent's restatement of goal, constraints and success condition matches the owner's intent | **Nothing.** The text says so itself: "a misunderstood goal survives every downstream check". |
| 2 | `:26-29` | Every template section is filled to a standard a competent builder could start from | Partially: `coverage.sh:151-155` fails if §5 has no ids. Nothing checks §3 non-goals, §6, §8, §11, §12 exist or say anything. |
| 3 | `:36-37` | Contradictions in the idea were pushed back on | **Nothing.** |
| 4 | `:89-92` | Every sentence in `docs/VISION.md` is one a reasonable agent could cite | **Nothing.** `vision-complete.sh` checks non-emptiness only. |
| 5 | `:100-103` | No vision statement was invented — every sentence is the owner's | **Nothing mechanical.** `owner-authored.sh` checks who *opened the PR*, which is a proxy: it establishes the owner read a diff, not that the sentences are theirs. This is the strongest of the six and it is still a proxy. |
| 6 | `:105-119` | The decisions the agent had to guess at were surfaced and ruled on before writing | **Nothing — and worse, it is discarded.** |

**Property 6 is the finding.** `idea-to-design-doc.md:105-119` sets up the pre-writing uncertainty gate: "list the decisions you are least confident about... Then wait for my rulings." It is emphatic that this is not the same as §11 Risks & open questions — §11 "records what's undecided *in the design*; this surfaces what *you* had to invent to fill the gaps." Then `:126-127` says only: "List any assumptions you made (so I can catch a wrong one)" — **in the report, in chat.** `AGENTS.md.jinja:250-252` is unambiguous that chat is not storage.

Contrast with the plan-level gate, which the same document mandates two sections later (`:174-179`) and which lands in a file: `_TEMPLATE.md.jinja:23-52` gives it a whole `## Uncertainties` section, a risk class, a proposed default, and a recorded ruling — and `deliver-phase.sh:99-116` reads it. **The design-level version of the identical gate, run over the higher-stakes decisions, has no destination.** By the time the design PR is opened, the guesses and the owner's rulings on them exist only in a chat transcript.

**The failure when it is not verified:** three sessions later, a plan is written against §7's proposed approach. The planner runs *its* uncertainty gate, finds nothing to ask — §7 answers its question — and writes `None: every decision derived from the design` (`_TEMPLATE.md.jinja:42-44`, which explicitly blesses this). The claim is true. What §7 does not say is that its approach was one of three the elicitation agent guessed between, and that the owner ruled on it in a conversation nobody can now read. The plan is derived from a guess that has been laundered into a design statement, and every downstream check reports conformance correctly.

**CI OUTPUT ON SUCCESS:** the design PR, opened by the owner:

```
plan           plan-resolve: branch 'docs/design' adds 218 lines, all of them in docs/plans/,
               docs/DESIGN.md, docs/VISION.md, ... Exempt from the size cap
               plan-lint: 0 plan(s) parse.
               owner-authored: 2 owned document(s), opened by 'thomgrims'.
               vision-complete: this pull request touches no plan — nothing to check.
review         REVIEW_VERDICT: PASS
```

**WHAT THE OWNER SEES:** a design doc whose §8 "Key design decisions & alternatives" contains the decisions the *design* records, and §11 the questions it leaves open. Neither section distinguishes a decision the owner made from one the agent guessed and the owner waved through. Six weeks later they are indistinguishable by construction.

**RANGE:** all six pairs. Most acute in B and F, whose designs contain the most agent-supplied structure (an embedding pipeline; a compiler's phase split) because their visions are about outcomes rather than mechanisms.

**FIX** — `template/docs/DESIGN.md.jinja` §11, giving the pre-writing gate a destination in the owner-landed document:

Replace lines 86-88:

```markdown
## 11. Risks & open questions
<!-- Two lists, and they are different things.

RISKS AND OPEN QUESTIONS: what could go wrong, what's still undecided, what
needs research. It's fine — expected — for a draft to leave things open here
rather than inventing answers.

DECIDED BY THE AGENT, RULED BY ME: every choice in this document the elicitation
agent had to guess at rather than derive from what I told it, and how I ruled.
One line each: the choice, the option the agent proposed, what I decided. This
is the pre-writing uncertainty gate (docs/idea-to-design-doc.md, "Before you
write anything") landing somewhere durable instead of in a chat transcript.

It has to be here rather than in the report, and the reason is exact: a later
plan runs the same gate at plan scope and correctly writes "every decision
derived from the design" — because by then the guess IS the design. Nothing
downstream can distinguish a section I decided from one I approved, and the two
fail differently. This list is the only record of which is which. -->

**Risks & open questions**
-

**Decided by the agent, ruled by me**
- <choice> — agent proposed <option>; ruled: <what I decided>
```

and `template/docs/idea-to-design-doc.md:112`, replacing "Then wait for my rulings." with:

```
Then wait for my rulings — and write both the questions and my answers into §11
under "Decided by the agent, ruled by me". Not into your report: the report is
chat, and chat is not storage (`AGENTS.md`, "Memory"). A guess I approved and a
requirement I authored look identical in §7 once written, and the only moment
the difference can be recorded is now.
```

---

### FINDING 10 — The acceptance branch's size cap is set by how large the design was

**SILENCE RANK: 10** — lowest, because this one goes red. I include it because it is the review's own standard in its purest form.

**DOCUMENT PAIR:** C ("Relay"), axis COVERAGE — broad-but-shallow. Twelve requirements produce a large `docs/architecture.md`.

**MECHANISM:** `template/.github/scripts/plan-resolve.sh:85-100` — `PLANNING_PATHS` is `docs/plans/*`, `docs/DESIGN.md`, `docs/VISION.md`, `docs/DESIGN.oracle.md`, `docs/oracle/*`. **`docs/acceptance.md` and `docs/architecture.md` are not in it.** `:130-134`: a `docs/` branch touching anything outside those paths is capped at 50 added lines (`:87`).

**TRACE:** `deliver-loop.sh:375` dispatches the acceptance pass. `deliver.md:172-174` instructs it to "Also confirm `docs/architecture.md` describes the system as it now stands — it is what the owner reads instead of the code, and it is the first thing to go stale across many merged features." After twelve requirements across four milestones, bringing `architecture.md` current is not a 20-line edit. The branch `docs/acceptance-20260816` now carries the acceptance table plus a substantial `architecture.md` rewrite, neither path exempt.

`plan-resolve.sh:146-160` dies:

```
plan: branch 'docs/acceptance-20260816' claims the exempt prefix 'docs/' but adds 137
lines (cap: 50).

The exemption is for changes too small to plan — a typo, a doc tweak. A change
this size needs a plan: copy docs/plans/_TEMPLATE.md to docs/plans/<slug>.md,
land it, then branch with the slug in the branch name.
...
Raising the cap to get this through is gate tampering under AGENTS.md.
```

The instruction is impossible to follow: acceptance is not plannable work, and a plan covering it would have no requirement ids. `deliver-loop.sh:259-266` dispatches a fix session, gets the same failure, three times, and exits 3 — "the same checks failed three times". The `acceptance-dispatched` sentinel (`:369-374`) is already set, so a *later* run reaching `PHASE=ACCEPTANCE` logs "acceptance recorded and nothing is open — the run is complete" and exits 0 with the acceptance table never written.

**RANGE:** does not fire for D (five criteria, small architecture doc) or A. Fires for C, and for any project large enough to need the acceptance pass to matter. **This is the review's standard exactly: the guarantee holds for the small, tight pairs and fails for the ordinary broad one — a template defect, not a document defect.** It is also the fourth instance of a pattern the repository's own log already named at `docs/escapes.md:70` (ESC-22): "a document this process *requires* and that is necessarily long needs its carve-out in the same change that introduces it, or it ships unwritable." `docs/acceptance.md` and `docs/architecture.md` are both required by `AGENTS.md.jinja:240-249` and `:165-171`, and neither has one.

**FIX:** **this one cannot land in the document layer, and I am not going to force it.** The fix is one line in `plan-resolve.sh:85-100`, adding `docs/acceptance.md` and `docs/architecture.md` to the planning-paths carve-out — a gate script, outside the two permitted destinations. No edit to `acceptance.md.jinja` or `DESIGN.md.jinja` changes the cap, and the only document-shaped workaround (splitting the acceptance pass across several under-50-line PRs) would violate the one-PR-in-flight rule and produce a table assembled across four merges. **The honest statement is that the template routes a required, necessarily-long document through a size cap built for typo fixes, and the document layer has no lever on it.**

---

## Part 3 — shapes that hold

Four shapes survived every probe I ran. Each holds for a specific structural reason, not because it is more thorough — that distinction is what makes them worth steering toward.

**1. A vision whose statements are prohibitions on the artifact, not values held by the owner.** Pair D's *"No configuration option may weaken a security property. If it can be turned down, it is not in the API."* survives Finding 3's framing attack, alone among my six. The reason is mechanical rather than moral: a prohibition names something a diff can be observed doing, so an agent constructing a defensible-but-wrong reading has to argue that a specific change does not do a specific thing — which is checkable by anyone reading the ledger next to the diff. Pair B's *"No feature may add a step between having a thought and it being saved"* reads like a prohibition and is not: "adding a step" is not observable in a diff, which is exactly why it carried the hosted-embedding decision. **The property is: could a reader, given only this sentence and a diff, disagree with the oracle's application of it?** If not, the statement is decoration however true it is.

**2. A §13 in which every §5 requirement is named by a criterion, and every criterion is mechanically checkable except the ones the design author explicitly marked.** Pair D and Pair A both have this; it is what defeats Findings 1 and 4 in those pairs. The mechanism is specific: `docs/acceptance.md` is the only artifact in the whole unattended run whose PR *requires* the owner's review (`CODEOWNERS.jinja:65`), so it is the one place a failure is guaranteed to reach a human. A §13 that covers §5 turns a silently over-claimed `covers:` into a visible empty evidence cell. A §13 that does not cover §5 lets the same over-claim reach `Every requirement is covered by a plan.` and stop there. **This is the single highest-leverage document property in the system**, and it is the one Finding 1's fix targets.

**3. A vision written after the design, where the interview was made to read one against the other.** The order `idea-to-design-doc.md:42-48` recommends is genuinely the better one — Pair A's vision is sharper than Pair B's precisely because its author had seen §5 — but the benefit is only realised if the comparison actually happens. Pair A's conflict (Finding 7) exists *because* the vision was written second and nobody diffed them. The order is right; the missing step is the diff, which is Finding 7's fix. Written-first visions (B, C) do not have this problem in the same form — they have the worse one of being guesses.

**4. A design whose milestones are narrow enough that one plan covers one milestone.** Pair D (three requirements in the MVP) and Pair A (three) resist Finding 1 not because their authors were careful about `covers:` but because there is no room to pad — the requirement list is short enough that a plan claiming all of it is a plan that must build all of it. Pair C's twelve requirements across four milestones create the space where a claim and a delivery can differ by six requirements without either looking wrong. **The property is the ratio of requirements to slices, not the count of either.**

What all four have in common: they make a claim falsifiable by someone holding only the repository. That is the standard the design skill should be steering toward, and none of the four is what "be more specific" would produce — Pair B and Pair F are both highly specific and both fail.

---

## Part 4 — method notes

All mechanical claims cite `file:line` in `origin/claude/copier-template-automation-rii78u` @ `21c8eae`.

Findings 1, 2 and 6 were verified by running the real `oracle-decisions.sh`,
`coverage.sh`, `plan-parse.sh` and `plan-lint.sh` against a constructed git
repository; the exact outputs are quoted, and [`reproduce.sh`](./reproduce.sh)
rebuilds that fixture from scratch.

**CONDITIONAL claims, and what would confirm each:**

- Findings 3 and 5 depend on agent behaviour under the shipped prompts and on
  GitHub's CODEOWNERS resolution for the un-owned-path carve-out
  (`CODEOWNERS.jinja:60`). The CODEOWNERS semantics are documented GitHub
  behaviour, but the resolved owner set is not observable from the repository —
  so treat the "no owner review is requested" step as conditional. Confirming it
  takes one pull request touching `docs/plans/oracle/` on a repository with
  branch protection enabled, and checking whether a review is requested.
- Finding 2's claim that the review gate might read `docs/VISION.md` of its own
  accord is conditional on reviewer-model behaviour. Confirming it takes reading
  review-job logs across several real runs.

**What this review did not do:** it did not run a generated project end to end,
did not exercise the delivery driver against a live GitHub repository, and did
not observe a real oracle or review agent. Every trace is composed from the
scripts' actual behaviour plus the shipped prompts' instructions; where the two
are not enough to settle a question, the finding says so above rather than
assuming.
