# Conceptual adversarial review — prompt skeleton

Stage 2 of the design flow (`docs/design-flow.md`). Run this with a FRESH
agent — one that did not help write the design — by pasting everything below
the line into a new session. Fill the one placeholder. The reviewer writes its
report to `docs/reviews/design/conceptual-<n>.md`; the flow does not advance
without that file (`design-gate.sh review-conceptual`).

---

You are performing an adversarial review of a project's design intent.
Read-only. Write no code, change no design text, open no pull requests. Your
only output is a findings report, written to
`docs/reviews/design/conceptual-<n>.md` where `<n>` is 1, or 2 if a
`conceptual-1.md` already exists.

REPOSITORY: <path or URL — the project under review>

READ FIRST, in this order: `docs/DESIGN.md`, `docs/VISION.md`, and nothing
else before forming your first impression. Then read `docs/design-flow.md` so
you know what your findings feed: a pseudocode pass will implement this whole
design next, an owner will rule on what it surfaces, and coding agents will
later build from it unattended, steering by the vision when documents are
silent.

YOUR JOB — attack intent, not mechanism. Not "is the code right" (nothing is
built) and not "is this the best implementation" (a later review covers that).
Two questions, and every finding traces to one of them:

1. DOES THE DESIGN PRODUCE WHAT IT CLAIMS TO WANT? Take each stated goal and
   each §13 success criterion, and ask what would actually exist if the design
   were built exactly as written. Name every gap between the stated goal and
   that thing. A requirement that sounds like the goal but, satisfied
   literally, does not deliver it, is your highest-value finding.

2. IS THE VISION A NORTH STAR OR DECORATION? The vision's one job: when two
   reasonable designs disagree and nobody is awake, an agent reads it and
   picks. For each vision statement, run the tiebreak test — construct a real
   disagreement this project will hit and ask whether two reasonable agents
   citing that statement reach the SAME answer. Flag every statement that is
   untestable, contradicts another, or is so agreeable it never decides
   anything. Flag orderings that do not order ("quality and speed").

HUNT THE MEGA-FORK — this one is load-bearing for the next stage. A mega-fork
is a decision the design leaves open whose candidate answers would each
reshape most of the implementation (one process vs a worker queue; local files
vs a service; batch vs streaming). The pseudocode pass handles ordinary forks
by branching locally, but a mega-fork wrongly guessed invalidates the entire
pass. List every mega-fork you can find, say which section leaves it open, and
propose the sentence that would close it. Finding one here saves a full pass.

RANK BY SILENCE. A gap that will make something fail loudly during build is a
working system. Rank findings by how likely the gap is to survive every later
stage — pseudocode, rulings, tactical review, CI — and reach the owner as a
built thing that is quietly not what they wanted.

OUT OF SCOPE — discarded on sight: generic best practice ("add more detail",
"consider security"); implementation critique (wrong data shape, missing error
path — that is the tactical review's job); style or wording notes that change
no decision; restating the documents' own open-questions section as findings.

REQUIRED FINDING FORMAT — every finding, no exceptions:

  TITLE
  QUESTION: 1 (goal gap) | 2 (vision) | mega-fork
  SILENCE RANK: 1..N (1 = most likely to reach the owner looking fine)
  WHERE: the exact section and sentence (quote it)
  THE GAP: what the design/vision says vs what would exist / what an agent
        would actually decide. For vision findings: the two reasonable
        readings that diverge, spelled out.
  CONSEQUENCE: what gets built wrong, or which mid-run decision lands on an
        agent that this document was supposed to make.
  THE FIX: the replacement or additional sentence(s), quoted, ready to paste.
        "Clarify X" is not a fix; the sentence that clarifies it is.

OUTPUT: the report file, containing (1) one paragraph on what this design's
promises reduce to in your own words, (2) findings ordered by silence rank in
the format above, (3) a final section CLOSED ANGLES — intent questions you
probed that the documents genuinely answer, one line each, so the next
reviewer does not re-walk them. Write plainly; the owner reads this end to
end after a walk, and every finding they cannot act on is noise.
