# Context for `closing-the-loop.md` — what the session knew that the plan does not say

Written 2026-08-18 by the session that produced the plan, for whoever reviews or
implements it. The plan records *what* was decided. This records **provenance**:
which sentences are the owner's verbatim rulings, which are the session's
reading, where a ruling was extended, and what is asserted rather than observed.

Not a specification. If the two disagree, the plan is the artifact and this is
commentary.

---

## 1. The owner's rulings, verbatim

Collected across one conversation, in the owner's words:

- **Self-hosting:** *"fair, self host it is."* Preceded by their own reasoning
  for the alternative, which is worth keeping because it was a good argument:
  *"the second repo would be so that i can run unattended… i thought all the
  jinja files would mess it up for an agent trying to read skills etc."*
- **The composed rules file:** *"the template repo agents file (running the
  self-host) should be a combo = template agent (the one every project gets) +
  template self-host specific agent stuff."*
- **Coverage adequacy:** *"yes, note, not red."*
- **Acceptance tests:** *"success criteria needs tests."* And on ownership:
  *"i do not mind having it be codeowners as long as it does not block work. it
  might though, if one feature depends on another being completed… additionally
  if the agents think they are done, but the success criteria says no, that is
  info that should go back to the orc so they can troubleshoot and continue
  fixing until it is actually done."*
- **Failing criteria go to the oracle:** *"if they fail, can we send it to the
  oracle and the oracle decides if a.: the tests are actually measuring a real
  success criteria that is in line with the vision, design doc. and b.: is the
  implementation actually failing, or did the implementation solve the problem
  in such a creative way that the success criteria fails even though the
  criteria is actually met in reality?"*
- **Reviewer fixtures:** *"if there are generally relevant and good fixtures,
  then yes, and also yes if there are stuff in the error logs already that would
  inform good fixtures."* Plus a condition the plan honours in slice 4: *"we
  have to make sure that the info we need to make good fixtures after is
  actually collected during the long run."*
- **Backlog approval:** *"i would make it advisory i guess. it might be worth
  making a distinction between approved by me and approved by the oracle. both
  allows work to be done, but if a reviewer is looking at it, it is genuinely
  more informative for the reviewer to know who approved, as the oracle might be
  wrong."*
- **Data collection**, quoted in full in the plan's rulings section, and the
  sentence that matters most is the second one: new behaviour that existing
  measurements do not cover requires a *new* measurement, specifically for
  *"changes that are downstream of the oracle's ruling."*

## 2. The one place this plan goes beyond what the owner said

**The oracle may not mark a success criterion passed.** The owner asked whether
a failing test could be sent to the oracle to decide, among other things, whether
the implementation *"solve[d] the problem in such a creative way that the success
criteria fails even though the criteria is actually met in reality."* That case
is real and worth handling.

The plan handles it by letting the oracle rule and record, while the acceptance
row stays `pending / owner` rather than becoming `pass`. **That limit is the
session's, not the owner's**, and it should be confirmed rather than assumed.

The reasoning, so it can be argued with: `docs/acceptance.md` is the one artifact
in an unattended run whose pull request requires the owner's review — established
in `docs/reviews/document-shape/README.md` and reinforced in `docs/synthesis.md`
§1.4, where three separate findings each independently severed it. If the oracle
can rule a failing criterion as met, then the last checkpoint before the human
becomes something an agent can talk its way past, and the owner's own definition
of done is adjudicated by the party whose work is being judged.

Note what the limit does **not** cost: the run does not stop. The oracle rules,
the reasoning lands in the ledger, the loop proceeds to the next phase. Only the
word `pass` waits for the owner. If the owner judges that too conservative, the
alternative worth considering is a distinct status — `met-otherwise`, ruled by
the oracle and visibly not `pass` — rather than removing the limit.

## 3. Interpretation calls a reviewer should check

- **"Reference the plain files, render the Jinja ones"** is the session's design,
  not the owner's instruction. The owner asked whether the Jinja files could be
  generated in the template repository; this answers a slightly different
  question, because the honest finding was that most of the files that matter do
  not need generating at all. Twenty-nine files carry Jinja; none of the sixteen
  gate scripts, seven command files, or two driver scripts is among them.
- **The exclusion list in slice 3 is load-bearing and easy to get wrong.**
  Rendering the document skeletons to the root would overwrite `docs/escapes.md`
  — a 36-row ledger cited by id from landed decisions — with a three-line stub.
  Whoever implements this should treat the list as an allowlist and never a
  denylist.
- **`docs/runs/` being committed is a judgement.** It makes evidence durable,
  which is the ruling; it also means every unattended run writes a file to the
  repository forever. If that turns out to be noise, the fallback is a retention
  rule rather than reverting to gitignored logs, because the gitignored log is
  the thing being fixed.
- **Slice 1 exists because of a specific near-miss.** Self-hosting without it
  would have turned on a pipeline in which `test-the-tests` skips every time and
  reports green. Nobody asked for slice 1; it was found while checking whether
  slice 3 was safe.

## 4. What is asserted rather than observed

Everything. No part of this plan has been run.

More precisely, and in the template's own idiom — these are hypotheses, not
findings:

- That `copier` will render a chosen subset of `template/` cleanly into the
  repository root without disturbing what is already there. The render is
  ordinary; the *subsetting* is new and the collision risk is real.
- That the reviewer fixtures will produce stable verdicts. A nondeterministic
  gate under test is a test that will sometimes be wrong, and slice 5's value
  depends on the failure rate being low enough that a red result means something.
  If it is not, the fixtures become a thing people re-run rather than read —
  the exact failure the template's own shellcheck-severity reasoning warns about.
- That acceptance criteria are *usually* expressible as a script. Some are
  ("byte-identical output over two runs"); some are not ("both of us use it
  daily for two weeks"). The §13 split already anticipates this, and slice 2
  inherits whatever that split gets wrong.

## 5. The state this plan is being written into

Worth knowing, because it changes how much to trust the surrounding machinery:

- `docs/synthesis.md` records twenty-two review findings and eight of the
  session's own, of which the ones ruled on are implemented and logged as
  `ESC-26` … `ESC-33`. Those fixes are tested against stubs and **none has been
  observed live**.
- `ESC-21` — a branch vanishing after an auto-merge — has now been closed and
  reopened around five theories, and no branch has ever been seen to disappear
  under any identity.
- The GitHub App does not exist yet, so the identity path ships dormant and the
  readiness check refuses every unattended run until it does. That is the owner's
  ruling working, not a defect.
- CI on this branch was red for seven consecutive commits while the local suite
  was green, because a test assumed an environment variable was absent that
  GitHub Actions always sets. The lesson is in the root `AGENTS.md` and in
  `tests/test-app-token.sh`'s header, and it applies to every slice here.

## 6. The sequence this plan sits inside

The owner's, in their words, and the plan deliberately does not try to shortcut
it: land this, then run `find_best_mobo` unattended, fix what it surfaces in the
template, and repeat *"until there are no more issues. only then can we run the
template unattended, which i am sure will surface more weird bugs cause it is
self-hosting, so we do the same loop for the template on itself."*

A separate proving-ground repository — a real project built with the template
purely to exercise it — was discussed and deferred. It is not needed while a
real project is available to serve the same purpose.

## 7. Related records

- `docs/synthesis.md` — the reviews reconciled, the sixteen rulings, and the
  open items this plan closes: 1, 2, 3, 5 and 7. Item 4 (plan estimate
  legibility) is folded into slice 6's reporting rather than given its own.
- `docs/escapes.md` — `ESC-26` … `ESC-33` are the defects this branch fixed and
  the checks that now name them.
- `docs/reviews/gate-seams/findings.md` — slice 5's fixtures come from here.
- `AGENTS.md` — the standing preferences this plan was written under.
