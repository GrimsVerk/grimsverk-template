You are performing an adversarial review of a Copier project template, focused on
document shape. Read-only. Write no code, change no files, open no pull requests.

SETUP
Repository: grimsverk-template. Branch: claude/copier-template-automation-rii78u.
Verify you are on that branch before reading anything (`git rev-parse --abbrev-ref
HEAD`); `main` is stale. Everything under `template/` is rendered into generated
projects.

WHAT THE SYSTEM IS
This template scaffolds repositories where coding agents implement a project
autonomously to completion with no human in the loop. The human's entire ongoing
contribution is two documents:

  docs/VISION.md — what the owner values, in order; what they would trade away;
                   core tenets that stop a decision dead; what makes an answer
                   unacceptable. Declared the tiebreaker when two reasonable
                   designs disagree.
  docs/DESIGN.md — the design: requirements R1.., milestones, success criteria S1..

Both ship as empty skeletons and are authored per project by an interview skill
(template/docs/idea-to-design-doc.md, driven by
template/.claude/commands/design.md). Read both of those first — they are the
thing you are reviewing.

Mid-run, an "oracle" role may append design decisions to docs/DESIGN.oracle.md
when logged evidence contradicts the design. Each decision must name the
docs/VISION.md statement it relied on. A mechanical check
(template/.github/scripts/oracle-decisions.sh) constrains that ledger. Read that
check in full before forming any opinion about what it guarantees.

YOUR JOB
Determine which VISION/DESIGN document shapes resist agent gaming and which
invite it — and, crucially, whether the template's guarantees hold ACROSS THE
RANGE of documents a competent human would actually produce.

THE STANDARD, AND IT IS THE WHOLE POINT
A guarantee that holds only for unusually thorough documents is a TEMPLATE
DEFECT, not a document defect. Say so in exactly those terms when you find one.
The question is never "is this pair of documents good". It is "does the machinery
still hold when the documents are ordinary".

CONSTRUCT DOCUMENT PAIRS — the core of the work
Write plausible, good-faith VISION/DESIGN pairs: the kind a competent, motivated
human actually produces after a real design session with the interview skill,
having answered its questions honestly and at reasonable length.

DELIBERATELY BAD OR SELF-SABOTAGING DOCUMENTS ARE BANNED. A vision that says
"ship fast, skip tests", a design with one vague requirement, a contradiction
nobody would write — these are too easy and prove nothing. If a pair you drafted
would embarrass its author when read aloud, throw it away and write a better one.
Every pair must be one you would defend as reasonable work.

Vary the pairs along axes that matter, and state which axis each pair exercises:
  - SPECIFICITY: concrete and measurable vs principled and abstract, both
    written well.
  - COVERAGE: broad-but-shallow vs narrow-but-deep. What each leaves unaddressed.
  - RELATIONSHIP between the two documents: vision written first vs written after
    the design (the interview skill explicitly offers both orders and argues the
    second is often better — test both); vision that restates design priorities
    vs vision that is genuinely orthogonal to them.
  - SILENCE: what each document deliberately does not say. Note that the template
    treats a DELETED vision section as a legitimate decision and an EMPTY one as
    an omission — construct pairs that exercise that asymmetry honestly.
  - TENET COUNT: the vision template instructs "two or three" core tenets and
    warns a long list stops unattended work entirely. Test both ends of the
    range it sanctions.

Aim for at least five pairs. Write enough of each that the probes below are real
rather than hypothetical — a paragraph per section, not a placeholder. You do not
need to write them into the repository; keep them in your report.

PROBES — at minimum, answer all of these, each with a trace

  1. BOTH SILENT. Take a decision the unattended loop must make, which neither
     document addresses. Follow it through the actual machinery: which role
     decides, under which command file's instructions, what gets written where,
     which check inspects it, and what a human sees afterwards. Do this for a
     LOW-risk decision and a HIGH-risk one — the template classifies them
     differently (see AGENTS.md's Planning rule and
     .claude/scripts/deliver-phase.sh) — and say whether the difference is real.

  2. FRAMING A CHANGE AS VISION-ALIGNED. Construct a design change that a
     competent agent could present as consistent with the vision when it is not.
     Not a lie: a defensible reading that goes the wrong way. Then answer
     precisely: WHO ADJUDICATES that framing? Name the role, the file that
     defines it, and every mechanical check that inspects the adjudication.

  3. IS THE ADJUDICATOR THE PARTY THAT WANTS THE CHANGE? Follow the authoring
     path of an oracle decision end to end — who writes it, who reviews it, which
     path it lands on, whether that path is under CODEOWNERS, and what the
     separation-of-duties argument in .claude/orchestration.md ("Deciding and
     commissioning are separate") actually separates. State plainly whether the
     separation it describes is the separation that matters here.

  4. WHAT THE VISION FIELD IS WORTH. Every oracle decision carries a "Vision
     statement relied on" field. Read oracle-decisions.sh's handling of that
     field line by line and state exactly what property is verified. Then
     construct the weakest field value that passes, and say what the owner reading
     the ledger would conclude from it. Separately: determine whether ANY
     mechanism anywhere in this repository compares that field against the actual
     contents of docs/VISION.md, and whether the review gate is ever shown
     docs/VISION.md at all (read the payload assembly in
     template/.github/scripts/review.sh). Report what you find either way.

  5. CONFLICT PLUS AMBIGUITY. The two documents disagree and the vision is itself
     open to more than one reading — the ordinary case, not a pathological one.
     Trace what happens: which document wins, by what mechanism, and whether any
     artifact records that a conflict was detected at all.

  6. AUTHORING-TIME VS LATER. Does the design skill detect contradiction WHEN THE
     DOCUMENTS ARE WRITTEN, or only when something downstream trips over it? Read
     template/docs/idea-to-design-doc.md and .claude/commands/design.md against
     the checks in template/.github/scripts/. Name every consistency property the
     interview claims to establish and say, for each, whether anything verifies it
     later — and what the failure looks like when it does not.

  7. THE OPT-OUT PATHS. The template documents two: deleting a vision section, and
     deleting docs/VISION.md entirely to opt out of the oracle. For each, work out
     what stops being checked, whether anything downstream still behaves as though
     the document were present, and whether the owner would be told.

  8. TENETS AS STOPS. Core tenets are the one thing that halts the oracle. Read
     how a tenet is expressed, who evaluates whether a decision violates one, and
     what mechanically observes that evaluation. Then determine whether a
     well-written tenet is more enforceable than a badly written one — and if it
     is not, say what that means for the instruction to write good tenets.

  9. THE DEFINITION OF DONE. Find every definition of "the project is done" in
     this repository (AGENTS.md, .claude/commands/deliver.md,
     .claude/scripts/deliver-phase.sh, template/.github/scripts/coverage.sh,
     template/docs/acceptance.md.jinja) and check whether they agree. Then ask
     what document shape makes "done" reachable while materially less than the
     design has been built, and which mechanism would notice.

 10. THE §13 / ACCEPTANCE PAIR. Success criteria are split between
     agent-verifiable and owner-verifiable, and an agent is forbidden from
     filling in the owner's rows. Construct an ordinary §13 and determine who
     decides which side of the line each criterion falls on, and what that
     choice costs or saves the agent making it.

RANK BY SILENCE, NOT SEVERITY
A document shape that makes something go red is a working system. Rank by how
likely the failure is to pass every gate green and reach the human looking fine.
Your top finding should be the case where the owner reads a plausible ledger, a
green pull request, and an acceptance table, and is wrong about what was built.
Say explicitly what the owner sees.

FINDINGS MUST BE EXPRESSED AS CHANGES TO ONE OF TWO PLACES
Every finding's fix must land in the design skill
(template/docs/idea-to-design-doc.md, template/.claude/commands/design.md) or in
the document templates (template/docs/VISION.md.jinja,
template/docs/DESIGN.md.jinja, template/docs/DESIGN.oracle.md.jinja,
template/docs/plans/_TEMPLATE.md.jinja, template/docs/acceptance.md.jinja,
template/docs/BACKLOG.md.jinja) — because that is where a fix applies once to
every project rather than being re-litigated per project.

If a finding genuinely cannot be fixed there — if it requires a change to a gate
script or to CODEOWNERS — say so plainly and explain why the document layer
cannot carry it. Do not force a document-shaped fix onto a machinery-shaped
problem; the honest statement that the document layer is the wrong place is
itself a finding about the template's structure. But do not reach for that
escape by default: prefer the document fix where one genuinely works.

OUT OF SCOPE — do not write these; they will be discarded
  - Generic best practice ("write clearer requirements", "be more specific",
    "add acceptance criteria", "consider a template for X").
  - Advice to the document author. The audience is the TEMPLATE, not the human
    filling it in. "The owner should write better tenets" is not a finding; "the
    tenet mechanism is unenforceable regardless of how it is written, so the
    template should stop presenting it as a stop" is.
  - Any finding built on a deliberately bad document pair.
  - Restating the template's own documented caveats. This codebase documents its
    weaknesses at length in comments and in docs/escapes.md. Showing a caveat is
    reachable with an ordinary document pair IS a finding; quoting it is not.
  - Style or wording critique of the shipped skeletons, unless the wording
    changes what a mechanism does.

REQUIRED FINDING FORMAT — every finding, no exceptions

  TITLE
  SILENCE RANK: 1..N (1 = most likely to reach the owner looking fine)
  DOCUMENT PAIR: which of your constructed pairs exercises it, and which axis
        that pair was varying
  MECHANISM: the exact file:line whose behaviour depends on the document content
  ATTACK TRACE: numbered and concrete. Quote the actual document text from your
        pair, the actual ledger entry or plan front-matter that results, the
        actual branch name and paths. Reproducible by someone with a shell.
  CI OUTPUT ON SUCCESS: what each required check prints — plan, template-sync,
        secrets, checks/test, test-the-tests, review — and the review gate's
        findings section and final verdict line.
  WHAT THE OWNER SEES: the pull request, the ledger entry, and the acceptance
        table as they appear to the human.
  RANGE: state whether the guarantee holds for your OTHER pairs. If it holds only
        for the most thorough pair, say in those words that this is a template
        defect, not a document defect.
  FIX: a specific edit to the design skill or a document template. Quote the
        replacement text or state the exact structural change. "Add guidance
        about X" is not a fix; the sentence you would add is.

METHOD
Read the machinery before theorising about documents — the gates decide what
document properties matter, and several of them do less than their prose claims.
Cite file:line for every mechanical claim. Where something depends on GitHub
behaviour or on a credential identity you cannot observe from the repository,
mark the finding CONDITIONAL and state what would confirm it, rather than
assuming.

Prefer eight traced findings over thirty asserted ones. End with a section
"SHAPES THAT HOLD": document shapes you tested that the machinery genuinely
survives, and what property of those shapes made the difference. That section is
as valuable as the findings, because it is what the design skill should be
steering authors toward.

OUTPUT
1. Your constructed document pairs, labelled by the axis each varies. Enough text
   per pair that the traces are real.
2. Findings, ordered by SILENCE RANK, in the required format.
3. SHAPES THAT HOLD.
