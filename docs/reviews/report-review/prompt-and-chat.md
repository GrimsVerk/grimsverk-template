# Report review — session record

Date: 2026-08-16. This file preserves, verbatim, the prompts the owner gave in
this session and the assessment produced in chat. The full written assessment
is in `assessment.md`; the report under review is `testbed-vs-template-report.md`
(authored by a separate agent in a separate session, included here for
self-containment).

---

## Owner's first message (context: how the report came to exist)

> i asked an agent to build something similar to grimsverk-template. i gave it
> almost no information, just said i wanted essentially a software factory,
> where the human is part of the design process, then the human is absent while
> agents implement the thing, human comes back to review and see if the project
> is in line with what they envisioned, if not, designs get updated and the
> loop continues until the human is satisfied with the result.
>
> then i gave it this prompt:
>
> are you able to add the template repo below yourself? or at least ask for
> permission? you need access to the template repo before proceeding so if you
> cannot ask for access, dont do anything until i open my desktop and add you.
> from my previous memory, you should be able to ask for repo read permissions.
> anyway, heres your task:
>
> TESTBED_PATH: repo-name: testingbed, branch: claude/agent-design-doc-template-1nr7jl
>
> TEMPLATE_PATH: repo-name: grimsverk-template, branch: claude/copier-template-automation-rii78u
>
> really make sure you are on the correct branches before doing anything,
> especially for grimsverk-template, as main does not have the latest features.
>
> You built the repo at \<TESTBED_PATH\> from a short, deliberately
> underspecified brief. I have now added a second repo at
> \<TEMPLATE_PATH\>: a Copier template I have been developing for
> months toward the same goal. You have never seen it before.
>
> Both are attempts at the same thing: a scaffold where I write a
> design document, hand it to a coding agent, and the agent runs to
> completion autonomously. I review the output; if it is wrong I
> revise the design doc and re-run. Constraints on both: security,
> minimal scope drift, maximal autonomy after the design phase.
>
> The testbed will be discarded. Its only value is what it reveals
> about the template. Note that you authored the testbed — actively
> correct for the bias that creates. Where you favor it, say why in
> terms of the artifact, not the authorship.
>
> Work through these in order. Do not skip ahead; section 1 must be
> written before you form comparative opinions.
>
> 1. BLIND RECONSTRUCTION
> Read \<TEMPLATE_PATH\> only. From the artifacts alone — not from my
> description above — reconstruct: what problem does this template
> appear to be solving, what workflow does it assume, and what does
> it expect of the human? Write this before comparing anything.
> This is a test of whether the template is legible as a spec.
>
> 2. WHAT THE TESTBED DOES BETTER
> For each mechanism present in the testbed but absent from the
> template: name the specific failure mode it prevents, then check
> whether the template prevents that same failure by other means
> elsewhere. Report all three parts. Do not list a mechanism as an
> advantage until you have searched the template for a functional
> equivalent under a different name or in a different layer.
>
> 3. UNJUSTIFIED MACHINERY IN THE TEMPLATE
> List every mechanism in the template with no counterpart in the
> testbed. For each, justify its existence from first principles —
> what breaks without it. If you cannot justify it without appealing
> to how it probably got there historically, flag it as candidate
> scar tissue.
>
> 4. PLACEMENT DISAGREEMENTS
> Find concerns both repos address but locate differently — agent
> instructions vs. pre-commit hook vs. CI vs. prompt vs. review
> gate. For each, argue which placement is correct and why.
>
> 5. AUTONOMY CEILING
> For each repo, count the human touchpoints required per
> design-doc-to-merged-code loop. Include implicit ones: anything
> requiring a human decision, unblock, or judgment call, whether or
> not it is labeled as a gate. Report the honest number, not the
> aspirational one.
>
> 6. TRANSFER LIST
> Ranked list of what should move from testbed to template, each
> with: the change, what it costs, and what it buys. Rank by
> (failure prevented) / (machinery added). Include an explicit
> "do not transfer" section for testbed ideas that look appealing
> but would not survive contact with the template's constraints.
>
> Output: a single markdown report. Cite file paths for every claim.
> No code changes. Where you are uncertain, say so rather than
> asserting. If a section turns up nothing, say that plainly instead
> of manufacturing findings.
>
> i will give you the markdown file it created, but i will send this message
> first. dont do or say anything until i share the md file.

## Owner's second message (the request this session answered)

> [attached: the report, preserved here as `testbed-vs-template-report.md`]
> if you need to look at the template repo, make sure you are on the correct
> branch, specified in the report (apparently there was a typo in the prompt i
> gave)
>
> i do not want you to write any code at all. i just want your honest opinion
> on this report and if there is anything that should be implemented to
> strengthen the template? are the suggestions the report makes good and
> valuable, or not? are there other insights that are valuable?
>
> no code, just your thoughts. if you want, you can put it in a markdown file,
> should be easier to save somewhere should we decide that is necessary.

## Owner's third message (why this record exists in the repo)

> i want you to save both the prompt i gave you with all the details, and all
> the information you produced in chat into a markdown file. then i want you
> make a commit, named after what you did specifically in one or two words, on
> the grimsverk-template repo on branch claude/copier-template-automation-rii78u.
> this commit should contain that markdown file plus any other files you may
> have created (reports or whatever). those files should be added under
> docs/reviews/{what you did specifically in one or two words}/{files here}
>
> tests will fail, that is fine, i will deal with it manually.

---

## Assessment as delivered in chat

Method note: the assessing session checked out
`claude/copier-template-automation-rii78u` at commit `21c8eae` — the same
commit the report analyzed — and spot-checked the report's load-bearing
citations directly against the files before forming an opinion. No code was
written or changed. The chat reply, verbatim:

---

I checked out the branch the report analyzed (`claude/copier-template-automation-rii78u`, commit `21c8eae`), verified its key citations against the actual files, and wrote up my full assessment in the attached markdown file. Here's the substance:

**The report is trustworthy.** Every citation I spot-checked is accurate — the "ask first, in chat" vs. "Chat is not storage" contradiction, the CODEOWNERS silent-ignore warning in `copier.yml`, the acceptance ledger's structure, `unattended-ready.sh`'s doctrine, the five unverified-live flags. And the method was followed honestly: the equivalence search killed most of the testbed's apparent advantages, which is what rigor looks like. If anything, residual bias runs *toward* the template, but the report justifies that deference legitimately (evidence-hardened mechanisms vs. same-session speculation).

**On the suggestions:**

- **T2 (dependency rulings in the repo) — implement now.** Cheapest, clearest win; it fixes a real self-contradiction using ledgers the template already has. Only note: entries will consume the `DECISIONS.md` cap — fine given rarity.
- **T1 (executable acceptance criteria) — the most valuable finding, and the report actually undersells it.** Its frame is "observed once vs. continuously." The sharper frame, in the template's own vocabulary: the acceptance ledger is the *one place* where agent narration is admitted as evidence — everywhere else the template splits computed facts from judged verdicts. An acceptance row is self-graded homework in exactly the sense the template refuses from test suites. I also push back on the report's hedge to "hold T1 until the first escape": the ratchet doctrine is rational when escapes are cheap to observe, and this escape class is the expensive kind (a regressed "done" found by you, in use, weeks later, unattributed). My recommendation: a lite version now — `Verified by: agent` criteria as small scripts run mechanically at the ACCEPTANCE phase — promote to per-PR CI only if a regression is actually observed.
- **T3 (gate-path backstop) — right intent, wrong design.** The proposed port duplicates the protected-path list and carve-out logic in two places that can drift — the exact duplication the template avoids elsewhere. Cheaper, in-idiom alternative: run the codeowners-errors probe `unattended-ready.sh` already uses as a CI step on PRs, so the platform config is checked rather than replicated. Verify by observation that unbound owners actually surface through that API first.
- **T4 — marginal, do it opportunistically.** The report says so itself.
- **Do-not-transfer list — agree with all five.** That section is quietly the best reasoning in the report.

**What the report missed:**

1. **Nothing validates the reviewer.** It calls the review gate the most security-serious file in either repo, then doesn't notice it's the only load-bearing gate with zero fixtures. A small set of known-bad diffs the reviewer must BLOCK (run nightly/manually, not per-PR) is the check I'd most want before a long unattended run — flagged honestly as speculative by the template's own standards.
2. **Stale acceptance rows under design revision.** Your loop's main input is §13 churn, and nothing I found checks that acceptance rows match the *current* §13 ids. T1's executable version dissolves this.
3. **The implicit headline: the template won.** A capable agent given the same brief cold reconstructed only the template's CI tier, none of its two deeper tiers, and lost on nearly every shared mechanism. Plus the blind reconstruction succeeded — the template is legible as a spec. That's real external validation.
4. **The best next action isn't a transfer at all** — it's running one real project through the unattended loop. Five behaviors are still unverified-live, and the live run also generates the evidence that settles T1-full and the reviewer-eval question.

My priority order: T2 now → T3-lite now → live run → T1-lite → reviewer fixtures → T4 opportunistically. No code was changed; the assessment file is attached if you want to keep it.
