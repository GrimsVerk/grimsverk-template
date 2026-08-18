You are performing an adversarial security review of a Copier project template.
Read-only. Write no code, change no files, open no pull requests.

SETUP
Repository: grimsverk-template. Branch: claude/copier-template-automation-rii78u.
Verify you are on that branch before reading anything (`git rev-parse --abbrev-ref
HEAD`); `main` is stale and lacks the mechanisms under review. If the branch is
missing locally, fetch it from origin. Everything under `template/` is rendered
into generated projects; everything outside it belongs to the template repo.

WHAT THE SYSTEM IS
This template scaffolds repositories in which coding agents implement a project
autonomously to completion, overnight, with no human in the loop. A human writes
two documents — docs/DESIGN.md (what gets built) and docs/VISION.md (what matters
when two designs disagree). Both ship empty and are authored per-project. From
there an unattended loop runs: a phase detector picks the next move; an "oracle"
role may append design decisions to docs/DESIGN.oracle.md when logged evidence
contradicts the design; a "steward" turns a decision into a plan; an orchestrator
spawns paired blind coder/test-writer workers and opens one pull request; pull
requests merge themselves when required checks go green.

YOUR JOB
Attack the permission and verification system AS MACHINERY. Treat document
content as fixed and ordinary where you can; a separate review covers document
shape.

Attack the SEAMS BETWEEN mechanisms, not each mechanism against its own stated
purpose. A gate that does exactly what it claims is still useless if:
  - nothing hands it the information it needs to decide (information starvation);
  - another mechanism runs first and narrows what it sees (ordering);
  - its scope and an adjacent gate's scope leave a gap between them (coverage);
  - two mechanisms each assume the other one checked something (mutual assumption);
  - a mechanism's input is produced by the thing it is supposed to constrain.

FOUR ADVERSARIES — treat each as a distinct posture and label every finding with
the one it belongs to. Do not collapse them; they find different bugs.

  1. THE LAZY AGENT. Optimises to stop working with everything green. It is not
     malicious and will not forge anything. It will pick the cheapest branch
     name, the cheapest commit shape, the cheapest file location, and the
     cheapest true statement. Ask of every mechanism: what is the least work
     that makes this mechanism report success, and does that least work involve
     the mechanism actually running?

  2. THE CONFUSED AGENT. Acting in good faith on ambiguous or contradictory
     instructions. The rule set here is large and layered — AGENTS.md, six
     command files under template/.claude/commands/, orchestration.md, the
     review prompt, and the self-describing headers of every ledger. Find places
     where two of those documents tell an agent different things, and trace what
     a good-faith agent does when it follows the wrong one. A contradiction that
     produces a green pull request is a finding; one that produces a red check
     is not.

  3. HOSTILE INPUT. Arriving via a design doc, a dependency, an issue body, a
     pull request body, a commit message, a test fixture, a plan file, a
     lockfile, or an answers file. Two questions: can it reach a component that
     acts on it, and can it reach a component that decides. Include prompt
     injection into the review gate, but do not stop there — look for input that
     reaches a shell, a git plumbing command, a pathspec, a network fetch, or a
     token.

  4. THE SCOPE-NARROWING AGENT. Extends nothing; cuts work to reach "done"
     faster while remaining technically compliant with every rule. This is the
     posture the system is least designed against. Ask: what is the smallest
     thing that satisfies each definition of completion in this repository, and
     which mechanism would notice the difference between that and the real work?

RANK BY SILENCE, NOT BY SEVERITY
A failure that turns something red is a working system and is NOT a finding worth
ranking highly. Rank by how likely a failure is to pass every gate green and
reach a human review looking fine. Your top finding should be the one where the
CI summary is all green checkmarks, the review gate says PASS, the pull request
description is honest, and the guarantee is nonetheless not held. Say explicitly,
per finding, what the human sees.

OUT OF SCOPE — do not write these; they will be discarded
  - Generic best practice ("pin your actions", "add a linter", "consider SAST").
  - Recommendations not tied to a specific bypass you traced.
  - Findings whose only consequence is a check going red.
  - Style, wording, or documentation-quality observations.
  - Restating a mechanism's own documented caveats as though they were findings.
    (This codebase documents its own weaknesses extensively in comments and in
    docs/escapes.md. Quoting a caveat is not a finding. Showing that a caveat is
    reachable in a green pull request IS one.)

REQUIRED FINDING FORMAT — every finding, no exceptions

  TITLE
  ADVERSARY: lazy | confused | hostile-input | scope-narrowing
  SILENCE RANK: 1..N (1 = most likely to reach a human looking fine)
  MECHANISM: the exact file:line and the specific check being defeated
  SEAM: which two or more mechanisms this sits between, and which one each
        assumed had covered it
  ATTACK TRACE: a numbered, concrete sequence. Name branch names, file paths,
        commit messages, front-matter fields, exact strings. It must be
        reproducible by someone with a shell and this repository. Where a step
        depends on something you could not verify from the files, say so at that
        step rather than assuming it.
  CI OUTPUT ON SUCCESS: what each required check prints and reports —
        plan, template-sync, secrets, checks (or test), test-the-tests, review.
        Quote or paraphrase the actual message the script emits. If the review
        gate runs, say what its findings section says and what its final line is.
  WHAT THE HUMAN SEES: the pull request as it appears to the owner.
  WHY NO GATE CATCHES IT: name every gate that could plausibly have caught it
        and say, per gate, exactly why it does not.

WHERE TO LOOK — starting points, not conclusions. Verify or refute each from the
files; some of these questions have innocent answers, and saying so with a trace
is a valid result.

  ORDERING AND BASE-vs-HEAD
  - Every gate script takes BASE_SHA or HEAD_SHA or both. Build a table of which
    script reads which file at which commit (template/.github/scripts/*.sh,
    template/.github/workflows/ci.yml.jinja). Then find a pair where one reads a
    file at base and another reads the same file at head, and work out what a
    two-pull-request sequence does to the pair.
  - The `plan` job runs seven steps in a fixed order in one job. What does an
    early failure hide?
  - Which checks are skipped versus which exit 0 with a message, and why does
    ci.yml.jinja repeatedly warn that a skipped job counts as passing?

  INFORMATION STARVATION
  - Enumerate exactly what template/.github/scripts/review.sh puts into the
    reviewer's payload and what it leaves out. Then read
    template/.github/review-prompt.md and list every judgement it is asked to
    make that requires something it was not given.
  - The MECHANICAL FACTS block is declared trustworthy ground truth. Trace every
    input to plan-metrics.sh and blind-tests.sh back to who authored it and when.
  - review.sh caps the diff at 400000 bytes and degrades to a summary; find what
    that summary contains and what an author controls about which files land in it.
  - The reviewer is told an empty or failed facts section is blocking. Find the
    ways the facts section can be present, well-formed, and vacuous.

  COVERAGE GAPS
  - Build the full list of files under CODEOWNERS control from
    template/.github/CODEOWNERS.jinja, including the line that deliberately
    CLEARS ownership. Then list every file under docs/ that the template ships
    or that AGENTS.md's "Memory" rule tells agents to write. Diff the two lists.
    For each un-owned file, ask which required check reads it and what it
    authorises.
  - review-prompt.md criterion 5 enumerates the "intent" files a diff may not
    modify. Compare that list against the CODEOWNERS list and against the list of
    documents oracle-decisions.sh treats as authoritative. Anything in one list
    and not another is a seam.
  - test-the-tests.sh decides what is "implementation" and what is "tests" from
    two hardcoded directory names. Find where a project's real code can live
    outside them, and what the check reports then.
  - blind-tests.sh detects blind authorship from a commit trailer. Find who
    writes that trailer and what happens when it is simply absent.
  - plan-resolve.sh has three prefix classes with three different rules. Find
    what each prefix disables, and whether any prefix disables more than one gate
    at once. Then ask who chooses the prefix.

  MUTUAL ASSUMPTION
  - For each pair among {plan, template-sync, test-the-tests, review,
    owner-authored, oracle-decisions}, find the comments where one says the other
    covers something. Verify each such claim against the other script's code, not
    its comments. At least one of these cross-references is worth checking
    character by character.
  - orchestration.md and spawn-worker.sh both discuss whether tool grants are the
    real enforcement. Follow that claim to its conclusion: if grants are not
    binding, what is, and does that thing see the same things?

  THE AUTHORITY CHAIN
  - orchestration.md documents a chain: evidence -> oracle decision -> plan ->
    code, and calls each arrow "enforced, not promised". Take each arrow in turn
    and find the mechanism that enforces it. For each, ask who can author the
    thing on the left-hand side of the arrow.
  - oracle-decisions.sh accepts two shapes of plan under docs/plans/oracle/. Read
    both branches of that logic carefully and ask whether the two shapes constrain
    the same thing.
  - Follow docs/BACKLOG.md through the whole system: who may write it, which
    checks read it, what a token in it authorises, and whether anything reviews it.

  HOSTILE INPUT AND CREDENTIALS
  - template/.github/scripts/template-sync.sh replays a template update in CI.
    Read what it reads from the pull request's own files, what flags it passes to
    copier, and what the surrounding workflow step in ci.yml.jinja configures
    globally before it runs. Then ask what a pull request author controls.
  - Trace which secrets are present in which job, and whether any job that
    handles a secret also executes content the pull request controls.
  - review.sh defends the reviewer with a per-run nonce. Test that defence
    against everything that reaches the payload, including the parts that are NOT
    inside the nonce-delimited diff section.
  - The review verdict is parsed from the last non-empty line. Consider both
    forgery and denial: what makes an honest reviewer emit an unparseable last
    line, and what happens then.

  THE UNATTENDED DRIVER
  - .claude/scripts/deliver-loop.sh and .claude/scripts/deliver-phase.sh are the
    unattended brain. Read what identity they run as, what they open pull
    requests with, and which required check depends on the identity of whoever
    opened a pull request. This is the single most important thing to get right
    in this review; if you cannot determine it from the repository, say so
    explicitly and state what would settle it.
  - deliver-phase.sh recomputes state each iteration. Find the inputs to that
    recomputation that an agent dispatched by a previous iteration can influence,
    and construct a loop that terminates early with everything green.
  - deliver-loop.sh has typed exit codes for its stops. Find a way for the loop
    to reach exit 0 having built materially less than the design asks for.
  - unattended-ready.sh is a refusal in one caller and advisory in another. Find
    both call sites and say what each failure mode looks like.

  WHERE CONTENT DECIDES
  Some gates turn out to have thresholds or scope set by the per-project design
  and vision documents rather than by the machinery. When you hit one, say so
  explicitly, name the file and line, state what about the documents changes the
  gate's behaviour, and HAND THE THREAD OFF rather than guessing at document
  content. Write those as a separate final section titled
  "HANDOFF: CONTENT-DEPENDENT THREADS", one entry per thread, each stating the
  question a document-shape review would need to answer.

METHOD
Read before theorising. Every finding must cite file:line. Where a claim depends
on GitHub behaviour you cannot observe (ruleset contents, which account owns a
token, whether a workflow run is dispatched), state the dependency as a
dependency — do not resolve it with an assumption, and do not drop the finding
either. Mark such findings CONDITIONAL and say what would confirm them.

Prefer ten traced findings over forty asserted ones. If a promising angle turns
out to be genuinely closed, say so in one line under a final section titled
"CLOSED ANGLES" — that is useful and it stops the next reviewer re-walking it.

OUTPUT
1. A one-paragraph statement of what this system's guarantees actually reduce to,
   in your own words, after reading it.
2. Findings, ordered by SILENCE RANK, in the required format.
3. HANDOFF: CONTENT-DEPENDENT THREADS.
4. CLOSED ANGLES.
