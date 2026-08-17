# Context for docs/automation-loop-plan.md — what the session knew that the plan does not say

For the reviewer making the final decision on this branch. The plan records
*what* was decided; this records *provenance* — which choices are the owner's
verbatim rulings, which are the implementing agent's defaults the owner never
explicitly saw, and where an ambiguous ruling was interpreted. Written by the
session that produced the plan and the implementation (commits `4f332e7` →
`21c8eae`).

## 1. The owner's rulings, verbatim

These were collected interactively; the plan paraphrases them. The originals:

- **Mid-run authority** (free text, answering "how should mid-run oversight
  work?"): *"plans are made from the design doc and cannot be made if there is
  nothing in the design doc that warrants that plan. that is where the oracle
  comes in. if a new thing pops up that needs to be done, oracle can alter the
  design doc (separate pr) so that a plan can be made (separate pr) so that
  the code and test writers can start working again. this should be explained
  somewhere. oracle should rule uncertainies as well."*
- **Merge identity** (free text, before choosing the App): *"we tried the gh
  bot, which worked really well, but it couldnt delete branches after merge
  which was annoying so we tried pat, but that ran into limits all the time,
  so going back to the bot with a scheduled branch cleanup might be the better
  option. if you have a better idea let me know."* The session explained the
  GitHub App as the third option; the owner then chose **"GitHub App
  (Recommended)"** from a three-option question.
- **Loop runtime**: *"i want to be able to run the loop BOTH locally and here
  in the claude code web app/site. of that needs different wiring, fine, just
  make it an explicit choice when i initialize the run."*
- **Budget ceiling**: *"budget/cost measure by the rate limit of my sub, in
  percentage points."* Nothing more — no number, no window (session vs week).
- **Uncertainty risk line**: chose **"Contract test + high default"** from
  three offered options (HIGH if candidate answers change slice boundaries,
  Signatures, external formats, or anything expensive to reverse; unsure ⇒
  HIGH). The contract-test wording itself was the session's proposal.
- **Scope**: *"essentially everything, but if there are legitimate security,
  or other benefits that warrants some manual pre setup time, then that can be
  justified. but really as little manual work as possible... without
  sacrificing security completely."*

## 2. Interpretation calls the reviewer should check

- **"oracle can alter the design doc"** was implemented as the oracle altering
  `docs/DESIGN.oracle.md` — the design *layer* — NOT `docs/DESIGN.md`. The
  owner's words literally say "the design doc"; the session mapped them onto
  the existing two-document architecture so that `owner-authored.sh` and the
  steering lever survive. If the owner actually meant the oracle may amend
  `docs/DESIGN.md` itself, that is a different (and gate-breaking) design, and
  the implementation does not do it. This is the single most consequential
  interpretation in the branch.
- **Budget ceiling mechanics** are entirely the session's design around a
  one-line ruling: delta-from-run-start on the *session* utilization
  percentage, default allowance **25 points**, probe best-effort
  (`budget-probe.sh`, honestly flagged unverified), with `--max-prs 10` /
  `--max-hours 8` backstops that always apply. The owner chose none of those
  numbers.
- **Readiness check refuses (not warns)**: both source plans agreed, and the
  session stated it would implement "refuse" and invited objection; the owner
  did not object. That is consent by silence, not an explicit ruling.
- **Pause-vs-proceed**: the two source plans genuinely disagreed (this
  session's draft: pause everything for the oracle; the other agent's:
  proceed-and-log everything, explicitly rejecting mid-run oracle calls). The
  hybrid is the owner's ruling; the *boundary* is the session's contract test.
  The other plan's "attended stop sentence goes entirely" was NOT adopted —
  attended runs still stop for the owner, deliberately.
- **The other plan's open ruling #2 (scheduler in Actions vs local)** leaned
  toward a GitHub Actions cron; the owner's dual-mode ruling supersedes it. No
  Actions-cron driver exists or is planned.

## 3. Deviations from the approved plan, made during implementation

- The steward role's tool grants gained `Write/Edit(docs/BACKLOG.md)` in
  `spawn-worker.sh` — `steward.md` already required backlog access for
  objections, and the unattended planner (which runs under the steward role)
  files uncertainties there. Pre-existing gap, fixed in passing.
- `unattended-ready.sh` also runs in CI's `plan` job as an advisory `|| true`
  step; in CI some lines legitimately read "cannot list" (the CI token cannot
  see secrets). The binding run is the driver's preflight.
- The lifecycle fixture's template-update seam renders from a **clean clone**
  of the template rather than the working tree: rendering a dirty tree makes
  copier record a synthetic `_commit` no clone contains, and `copier update`
  dies on it. Artifact of running the suite mid-edit; documented in the test.
- ESC-14 (template-sync vs conflicted update) and ESC-17's mechanical CI gate
  were deferred, per the plan; ESC-17's behavioral half (one PR in flight) is
  inherent to the driver.

## 4. Process caveats

- **An owner answer was lost twice** by the chat client mid-session (a typed
  question-box answer, then a re-typed message that never arrived). The
  rulings above were re-collected afterwards and confirmed through delivered
  question-box answers — but if any recorded ruling surprises the owner, ask
  them rather than trusting the record; there may have been nuance in the lost
  text that never reached the session.
- The owner mentioned a third agent's suggestions might exist and that they
  might ask for a review of them; only `docs/plans/unattended-operation.md`
  was ever seen and merged. If other proposals exist, they are not reflected
  here.
- Five claims ship **unverified-live** (listed in the plan's status banner and
  each file's header). The most important for a go/no-go: ESC-21 — no branch
  has ever been observed to vanish, under any identity, across four recorded
  fix attempts. The first real project run, suggested with `--max-prs 3` and
  watched, is the verification run.
