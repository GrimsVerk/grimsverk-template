# Context for `unattended-operation.md`

Written 2026-08-16 alongside the plan, by the agent that wrote it, for whoever
reviews it. The plan states what to build. This states **where it came from,
what is actually verified, and where its author has been wrong before** — so the
reviewer can weigh its confident sentences correctly.

Not a specification. Nothing here overrides the plan; if the two disagree, the
plan is the artifact and this is commentary.

---

## 1. How the plan came about

It was not derived from the design. It came out of a working session in which
the owner asked, near midnight and while trying to go to sleep, *"is there
anything else I need to make it so that an agent just goes and goes and goes?"*
The plan is that answer, written up.

That origin cuts both ways. The items are grounded in failures observed the same
day rather than imagined, which is the strongest evidence available. But nothing
in the plan has been through a night's reflection, and the ordering argument
(prove the merge cycle before removing the stops) was composed in one pass.

## 2. The owner's rulings this session, and their reasoning

Recorded because the reasoning matters more than the ruling when a reviewer has
to extend either to a new case.

- **Three jobs, and no fourth.** "Approve vision and design, and then after the
  work has been done: review to see if I am satisfied, if not, I loop back to
  editing and approving updated vision and design and around the loop we go
  until we are done. **Always automate.**" Anything that adds a recurring
  obligation for the owner is against this, whatever its other merits.
- **Uncertainties go to the oracle, not to the owner.** The owner rejected the
  plan-level `## Uncertainties` gate specifically because it woke them up. The
  agent argued against this — see §4 — and the owner's answer resolved the
  objection rather than overruling it: **when the vision cannot decide, the
  oracle makes its best guess and logs the reasoning, the alternatives
  considered, and why each was rejected.** The owner reads those when they have
  time, and that is what tells them which part of the vision or design to edit.
- **Design and vision land only in a pull request the owner opened.** An agent
  may write and commit them to a branch; the owner opens and merges. Their
  reason, verbatim: *"if any agent can edit design, why have design oracle?"*
  This is a deliberate stop and is NOT one of the stops slice 4 removes.
- **Vision may be written after the design.** The owner finds it easier that
  way. Both must be complete before implementation.
- **Model tiers.** Only Opus 5 and Fable 5 are in consideration; `xhigh` and
  `max` are ruled out — *"xhigh is really just wasteful."* Oracle on Fable 5
  high; orchestrator, steward, test-writer, reviewer on Opus 5 high; coder on
  Opus 5 **medium**, deliberately, because blind tests make a coder failure
  diagnostic of a weak task definition rather than of weak coding. A reviewer
  proposing to raise tiers for the unattended loop should read that reasoning
  first.

## 3. How the owner reads, which changes how to read quotes from them

**The owner replies as they read, not after.** A response to an early paragraph
is often overtaken by a later sentence in the same message; instructions get
retracted mid-message once they reach the part that answers them. They have
explicitly invited being told when an instruction contradicts something already
established.

Consequence for a reviewer: **do not treat a quoted instruction from the session
as final without checking whether a later message revised it.** This already
happened once — an instruction to "copy the logs up and leave a pointer" was
retracted two sentences later in the same message.

## 4. The argument the agent lost, and why it is still worth knowing

The agent argued that plan uncertainties should stay with the owner, on the
grounds that the oracle is constrained to cite logged evidence and quote a
`VISION.md` statement, and a preference question (*"is `curl | sh` from a
third-party host acceptable on your machine?"*) supplies neither.

The owner's ruling in §2 answers that: a decision that says *"the vision did not
decide this; I chose X over Y and Z, for these reasons"* is honest on its face
and is reviewable later.

**The residual risk the argument was pointing at is real and is not fully
handled by the plan.** If routing an uncertainty to the oracle is cheaper than
asking the owner, every agent has an incentive to reclassify preference
questions as oracle questions, and the oracle — being a role that decides rather
than one that asks — will produce an answer. The failure mode is a design ledger
full of decisions the owner never made, each formally well-formed.

Slice 4's mandatory-alternatives rule is the countermeasure: guessing is
allowed, guessing silently is not. **A reviewer should judge whether that is
sufficient.** It was the agent's proposal, not the owner's ruling, and it has
not been tested against a real run.

## 5. What is verified, and what is asserted

The plan reads with uniform confidence. It should not.

**Observed directly this session:**

- `arm-auto-merge` failing with `GraphQL: API rate limit already exceeded for
  user ID 304928293`, on three separate pull requests, over more than an hour.
- The review gate blocking a pull request because the plan **at the base commit**
  still carried `**Ruling:** _pending_`, even though the rulings had merged to
  `main` before the review ran. See §6 — this is a live hazard for slice 5.
- `copier update` producing zero conflicts and a passing `template-sync` on five
  consecutive template releases (v0.4.13 through v0.4.19).
- Environment restrictions on the agent: **force-push, remote branch deletion,
  and `git push origin --delete` are all blocked** — the last with a 403 from
  the egress proxy, the others by a local classifier. Every branch cleanup this
  session was performed by the owner by hand.

**Asserted from general knowledge, NOT verified against this repository:**

- That GitHub creates no workflow runs from events caused by `GITHUB_TOKEN`, and
  that this is why the branch-deletion job never ran. The behaviour is
  documented; that it is *the* cause here is inference.
- That `gh pr merge --auto --delete-branch` is a no-op because `gh` deletes the
  branch itself after merging, which never happens under `--auto`.
- That an unticked **Allow auto-merge** repository setting would make
  `gh pr merge --auto` fail. General truth; this repository's setting was never
  read. Slice 3 exists precisely to stop this class of guess.
- That a GitHub App would receive its own rate-limit budget and its own identity.
  Believed true; the consequences for `owner-authored.sh` need checking rather
  than assuming.

**Never observed at all: a branch deleting itself after an auto-merge.**
`ESC-21` has been closed and reopened around three different theories and no
branch has ever been seen to vanish. This is why slice 1 is defined by an
observation and not by a diff.

## 6. A hazard the plan names only indirectly

Gates in this template resolve **at the pull request's base commit**: the plan
must exist there, the branch name must carry the plan's slug, and cited evidence
ids must resolve there. A branch cut from a stale `main` fails these even when
`main` itself is correct.

A human notices and rebases. **An unattended loop opening several pull requests
per night will meet this constantly**, and the symptom is a review BLOCK whose
stated reason (*"shipped against un-ruled decisions"*) describes the base commit
rather than anything wrong with the work. Slice 5's driver has to refresh from
`main` before cutting each branch. This is not in the plan's slice text and
should be.

## 7. The agent's own track record on this subsystem

Offered because a reviewer weighing the plan's confident claims should know the
base rate. In this session the agent:

- gave **three** confident and wrong mechanisms for the branch-deletion failure
  before the fourth;
- wrote toothless test fixtures **three** times — each asserting a string that
  was also present in a comment or in the instructions, so the test passed
  against the defect; each was caught only by running it against the defect
  deliberately;
- shipped a `coverage.sh` change that read an indented schema example as real
  requirement ids, defining phantom requirements in every generated project
  (`ESC-19`);
- stated that the oracle role was not installed in this repository. It is;
- diagnosed a `uv self update` failure as a package-manager-owned install when
  the actual output said "GitHub API rate limit exceeded".

The pattern is consistent: **the errors are confident mechanism claims about
systems the agent had not observed directly.** Sections of the plan that name a
cause should be treated as hypotheses to verify. Sections that name an
observation (slice 1's completion criterion, slice 6's fixture) are the
load-bearing ones and were written precisely because of this pattern.

## 8. Explicitly not decided

- **Where the scheduler lives**, and whether the loop is triggered by cron or by
  merge events.
- **The budget number.** The mechanism is specified; no figure was proposed,
  because none would have been more than a guess at the owner's tolerance.
- **PAT versus GitHub App.** Recommended in the plan, not ruled on. It is the
  single change that would address the rate limit, the agent-identity hole in
  `owner-authored.sh`, and part of slice 1 at once — which is a reason to look
  at it hard rather than a reason to trust the recommendation.
- **Whether the planner may call the oracle mid-run.** Deferred deliberately;
  both of this session's real uncertainties would have proceeded fine on a
  default, so building it now would be speculation.

## 9. Related records

- `docs/escapes.md` — `ESC-14` through `ESC-25` were logged this session.
  `ESC-21` (branch deletion) and `ESC-23` (defects found by use, not by tests)
  are both open and are the direct evidence for slices 1 and 6.
- `docs/projects/find_best_mobo/` — the mirrored records of the project that
  produced this evidence.
