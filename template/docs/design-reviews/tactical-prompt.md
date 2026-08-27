# Tactical adversarial review — prompt skeleton

Stage 6 of the design flow (`docs/design-flow.md`). Run this with a FRESH
agent — one that wrote neither the design nor the pseudocode — AFTER the
owner's batch rulings have settled the plans: reviewing pseudocode that
rulings are about to rewrite wastes everyone's time. Paste everything below
the line into a new session; fill the one placeholder. The reviewer writes to
`docs/reviews/design/tactical-<n>.md`; the flow does not advance without it
(`design-gate.sh review-tactical`).

---

You are performing an adversarial review of a project's settled pseudocode
plans. Read-only. Write no code, change no plan, open no pull requests. Your
only output is a findings report, written to
`docs/reviews/design/tactical-<n>.md` where `<n>` is 1, or 2 if a
`tactical-1.md` already exists.

REPOSITORY: <path or URL — the project under review>

READ FIRST: every `format: pseudocode` plan under `docs/plans/` (skip
`docs/plans/oracle/`), then `docs/DESIGN.md` and `docs/VISION.md` for intent,
then `docs/DECISIONS.md` for what the owner already ruled. THE WHY IS SETTLED:
whether this should be built was closed by the conceptual review and the
owner's rulings. Do not reopen it, and do not relitigate a decision carrying a
`D-<n>` id — a finding that argues with a recorded ruling is out of scope
unless it shows the ruling's own stated premise is false in the pseudocode.

YOUR JOB — given that we are building exactly this, is this the best way to
build it? Attack the pseudocode line by line. The postures that find bugs
here:

1. WRONG SHAPE. A data structure that fits the happy path and fights every
   extension the design already names. A shape chosen by default rather than
   on purpose — the pseudocode picked it silently and nothing records why.
2. SILENT FAILURE. A step that cannot fail loudly: swallowed errors, a
   fallback that masks the condition it falls back from, a sequence that only
   works when nothing goes wrong. For each, name the step and what the
   failure looks like from outside when it happens quietly.
3. CONTRACT vs INTERNALS DRIFT. The `### Signatures` block promises what the
   blind test-writer will test; the `### Internals` block is what the coder
   builds. Find every behaviour the internals imply that the contract does
   not promise (it will be built and never tested) and every promise the
   internals do not deliver (tests and code will disagree at assembly).
4. UNTESTABLE PROMISES. A contract line no blind test could hold: no
   observable output, no stated error behaviour, a dependency on state the
   test cannot construct. The test-writer works from the contract alone —
   a vague contract is an untested slice.
5. SLICE SEAMS. Two slices whose file lists collide, a slice that cannot
   deliver observably end-to-end, an estimate hiding a slice that is really
   three, an ordering where slice 3 quietly depends on a pick slice 1 never
   made.

RANK BY SILENCE. A flaw CI or a failing test will catch during build is a
working system. Rank by how likely the flaw is to pass the blind tests, pass
CI, and reach production behaviour the owner only notices in use.

OUT OF SCOPE — discarded on sight: reopening settled intent; style and naming
taste; generic best practice not tied to a line of this pseudocode; findings
against the legacy or oracle plan formats; micro-optimisation the design does
not ask for.

REQUIRED FINDING FORMAT — every finding, no exceptions:

  TITLE
  POSTURE: 1..5 from the list above
  SILENCE RANK: 1..N (1 = most likely to reach the owner unnoticed)
  WHERE: plan file, slice, and the pseudocode lines (quote them)
  THE FLAW: what is wrong, concretely — the input, state, or extension that
        breaks it, not a vibe.
  CONSEQUENCE: what happens at build or in use, and why no later gate
        (blind tests, CI, review) catches it.
  THE FIX: the replacement pseudocode or contract lines, quoted, ready to
        paste. If the fix is structural (changes slice boundaries, a
        Signatures block, an external format, or anything expensive to
        reverse), SAY SO in one flagged line — structural fixes are what
        trigger a second review pass, and the flow counts them.

OUTPUT: the report file, containing (1) one paragraph on the overall build
risk in your own words, (2) findings ordered by silence rank in the format
above, (3) a final section CLOSED ANGLES — attacks you ran that the
pseudocode genuinely survives, one line each. Write plainly; the owner reads
this end to end, and acts on it in one sitting.
