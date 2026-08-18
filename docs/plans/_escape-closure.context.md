# Context for `escape-closure.md` — what the session knew that the plan does not say

Written 2026-08-18 by the session that produced the plan, for whoever reviews or
implements it. The plan records *what* was decided. This records **provenance**:
which sentences are the owner's, where the numbers came from, what was measured
versus assumed, and the one place a mechanism in this plan could be turned
against its own purpose.

Not a specification. If the two disagree, the plan is the artifact.

Underscore-prefixed so `plan-lint.sh` skips it — this is prose about a plan, not
a plan, and the parser is right to refuse it.

---

## 1. How this plan came to exist

It was not planned. It came out of the owner asking one question about work that
had just landed:

> "first, all the escapes, have none really been implemented fixes for?"

The honest answer turned out to be the opposite of what the session had implied a
message earlier. The session had described the delivery driver's `PHASE=ORACLE`
over thirty-four escape ids as a cost of self-hosting — true — while leaving the
impression that thirty-four unresolved problems were sitting in the ledger. They
are not. Thirty-one are fixed.

The owner's follow-up is the plan's whole design:

> "all the ones that are actually closed need to have a ledger or something so
> that the oracle can then see that it is good and does not need a ruling. does
> that ledger not exist?"

It does not. That is the finding, and the owner found it, not the session.

## 2. The numbers, and how they were produced

Counted by parsing the **Check added** column of every `ESC-<n>` row in
`docs/escapes.md`, taking the last non-empty cell per id — because a correction
row repeats the id and supersedes the earlier one.

- **34** distinct ids.
- **31** whose check column names a real check.
- **3** whose check column literally begins `unverified — pending`, the
  documented stub marker: **ESC-14, ESC-16, ESC-17**.
- **2** of the 31 that still say they are unobserved live: **ESC-21, ESC-26**.

**The first classification the session produced was wrong**, and it is worth
recording because the same mistake is easy to repeat. It matched the word
`unverified` anywhere in the cell and returned eleven "open" escapes. Several of
those name a demonstrated check and then honestly state a residual limit — for
instance ESC-18's *"What a fixture CANNOT prove is that a live headless engine
honours a path-scoped `Write(...)` grant; that stays unverified here."* That is a
closed escape being careful, not an open one.

The corrected rule anchors on the marker at the **start** of the cell.
Whoever implements the backfill in slice 5 should re-derive the list rather than
trust either number here, and should expect the anchored rule to be right and
the keyword rule to be wrong.

`ESC-23` is a closed escape whose closure lives in the **What escaped** column of
a correction row, with the check column empty. A naive parser reads it as still
open. The backfill has to read corrections as corrections.

## 3. The one place this plan could be turned against itself

**A closure ledger is a mechanism for making the oracle skip evidence.** That is
its purpose and it is also the risk. If an agent can append `ESC-99 — closed`,
the oracle never looks at ESC-99 again, and the thing that decided it was fine is
the party that wanted it to be.

Three properties are meant to hold that, and only the third is mechanical:

1. It is append-only, so a closure cannot be quietly rewritten later.
2. It is visible in a diff the review gate reads.
3. **A closure row must name at least one repository path, and that path must
   exist at HEAD.** This is the load-bearing one, and it is the reason the plan
   specifies it rather than leaving the row free-form.

Property 3 is deliberately weak: it proves a file exists, not that the file
checks anything. A closure naming `README.md` would pass. It was chosen anyway,
because the stronger versions all fail for reasons this repository has already
logged — requiring the named check to *run* would need a test harness inside a
gate, and requiring the owner's approval would put them back in the loop at 3am,
which `ESC-28` records as the failure the whole arrangement exists to prevent.

**If a bogus closure is ever observed, that is an escape and the ratchet applies.**
The next check worth building is the one the log points at, and this is the
paragraph that will point at it.

## 4. Interpretation calls a reviewer should check

- **ESC-16 is declined, not deferred.** The ledger proposed running the review
  gate on an agent's own diff before it opens a pull request. The session read
  this as a *cost* fix rather than a *safety* fix — the gate did catch the
  original defect, correctly, and `orchestrate.md:298` already carries the
  behavioural instruction with ESC-16 cited in it. What remains is one wasted
  cycle on the rare repeat, against a model call on every pull request. The
  owner's `V5` — cost is a ceiling, not a preference — is what tipped it. **That
  reading is the session's**, and declining a check the ledger proposed is
  exactly the kind of thing to disagree with; the closure row states the reason
  so disagreeing is cheap.
- **ESC-17 advisory rather than red** follows the owner's own ruling pattern on
  plan adequacy — *"yes, note, not red"* — and one specific hazard: two pull
  requests opened seconds apart would each observe the other open and not green,
  and both would fail. The tiebreak that fixes it (oldest wins, plus a carve-out
  so it never blocks the owner personally) is more machinery than the residual
  problem, given the driver already prevents the unattended case.
- **ESC-14 at file level rather than hunk level** is a real loss and the plan says
  so. Hunk level was not rejected as wrong; it was deferred as harder, and the
  file-level version reports the exempt files by name so the reviewer inherits
  the judgement the check gave up.
- **`status: merged` as the "already built" signal** (slice 2) reuses a word the
  plan template already ships in its status vocabulary (`draft | in-flight |
  merged`). The session read that vocabulary as meaning the *work* merged. If the
  owner reads it as meaning the *plan document* merged, the field is ambiguous
  and slice 2 needs a distinct one instead. This is the plan's one open question
  and it is asked there rather than assumed.

## 5. What is asserted rather than observed

- **No conflicted `copier update` has been replayed** through slice 3's code, or
  through the current code. ESC-14 was reported from a real project twice; the
  fix is written against the ledger's description of it.
- **The oracle has never run in this repository.** `docs/DESIGN.oracle.md` does
  not exist here. Slice 5 predicts the oracle phase drops to a small number of
  ids; that is arithmetic on the ledger, not an observation of a run.
- **Whether one oracle run can metabolise even three escapes usefully is
  unknown.** The role has never been exercised on real accumulated evidence.
- **The review gate has never been shown a queue fact** (slice 4), and whether a
  reviewer does anything sensible with it is the same open question every other
  advisory fact in the payload has.

## 6. Where the driver stands after this

Two preconditions were named in `docs/DESIGN.md` §11. This plan removes the
mechanical half of both. What is left after it lands:

- the App identity still does not exist, so `unattended-ready.sh` refuses;
- one oracle run still has to actually happen, watched, on the remaining ids;
- ESC-21 and ESC-26 still need a real merge and a real App to close.

None of those is code. The plan is a precondition, not a permission, and it says
so in its last section.

## 7. Related records

- `docs/escapes.md` — ESC-14, ESC-16 and ESC-17 in full, including the checks
  each proposed, which this plan either builds or declines by name.
- `docs/BACKLOG.done.md` and `docs/BACKLOG.approved.md` — the idiom slice 1
  copies, and the reasoning in their headers applies here unchanged.
- `docs/DESIGN.md` §11 — the two preconditions this plan addresses.
- `docs/synthesis.md` §1.3 — "nothing anywhere compares what was asked for to
  what was built", which is the same family of defect one level down.
