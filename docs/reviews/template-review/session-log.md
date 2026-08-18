# Session log — template review task

Session: Claude Code on the web, 2026-08-16. Model: `claude-fable-5`.
This file preserves (1) the owner's task prompt verbatim and (2) every
user-visible chat message the agent produced while executing it. The full
report the task asked for is `comparative-report.md` in this directory; the
pre-comparison Section 1 draft is `blind-reconstruction.md`.

Context for the reader: earlier in the same session, the agent had built the
"testbed" — `grimsverk/testingbed` @ `claude/agent-design-doc-template-lnr7jl` —
from a short brief asking for a safe, drift-resistant design-doc-to-agent
scaffold. The prompt below then introduced this template repository and asked
for a structured comparison.

---

## 1. The owner's prompt (verbatim)

> are you able to add the template repo below yourself? or at least ask for permission? you need access to the template repo before proceeding so if you cannot ask for access, dont do anything until i open my desktop and add you. from my previous memory, you should be able to ask for repo read permissions. anyway, heres your task:
>
> TESTBED_PATH: repo-name: testingbed, branch: claude/agent-design-doc-template-1nr7jl
>
> TEMPLATE_PATH: repo-name: grimsverk-template, branch: claude/copier-template-automation-rii78u
>
> really make sure you are on the correct branches before doing anything, especially for grimsverk-template, as main does not have the latest features.
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

---

## 2. The agent's chat output (verbatim, in order)

### 2.1 On access and setup

> I should be able to add the repo myself — the session has an `add_repo` mechanism. Let me find those tools.

> The `add_repo` tool is available directly — I'll add the template repo now:

> Access granted — cloning now:

### 2.2 After checkout of the requested branch

> Clone is on the right branch (`claude/copier-template-automation-rii78u`, commit `21c8eae`). One note: you wrote the testbed branch as `...template-1nr7jl` (digit one) — the actual branch I built is `claude/agent-design-doc-template-lnr7jl` (letter L). I'll verify against origin before relying on it.
>
> Now starting section 1 — reading the template repo only, before any comparison:

### 2.3 While reading the template

> Good — origin confirms the testbed branch is `lnr7jl` (letter L), so your `1nr7jl` was a typo for the branch I'm already on. The template is substantial (~95 files), so I'll read it thoroughly, starting with the docs and entry points for the blind reconstruction:

> The README alone reveals a lot. Now I'll read the core generated-project docs myself and fan out subagents to digest the scripts, commands, and tests in parallel:

> The generated `AGENTS.md` is a serious document. Reading the remaining design-layer docs while the subagents grind through scripts:

> I've now read the template's core spec layer directly. Per your ordering constraint, I'll write Section 1 (blind reconstruction) now, before the comparative sections, based purely on the template artifacts:

> Section 1 is drafted (from the template artifacts alone, before any comparison). Three background readers are still digesting the template's ~30 CI/orchestration scripts, the `.claude/` command layer, and the test suite + project-history docs — I'll continue with sections 2–6 as soon as their summaries land.

### 2.4 As reader summaries arrived

> The `.claude/` layer summary is in — it's a much deeper system than the surface suggested (role-tiered models, blind test-writer isolation via worktrees, a budget-capped unattended driver with typed exit codes). Two readers are still working through the CI enforcement scripts and the template's own test suite/history docs; sections 2–6 need both before I can write them honestly.

> Second reader is done — the template's own history is illuminating (a real downstream project, `find_best_mobo`, produced most of its escapes ledger, and the docs are candid that several mechanisms remain "unverified-live"). One reader remains, covering the CI enforcement scripts — that's the layer sections 2 and 4 hinge on, so I'll hold the comparative writing until it lands.

> All three readers are done and I've read the template's core docs directly. Now I'll write the full report — the testbed's mechanisms I know first-hand (I built them this session), and every template claim below is cited to a file I or a reader verified.

### 2.5 Final summary (delivered alongside the report file)

> The report is delivered above. Housekeeping first: yes, I was able to add the repo myself — the session's `add_repo` tool requested and received read access to `grimsverk/grimsverk-template`, so no desktop trip was needed. I'm on `claude/copier-template-automation-rii78u` as instructed (note: your testbed branch had a typo — it's `...-lnr7jl` with a letter L, the only branch on origin). No code was changed in either repo.
>
> The honest headline: **the template wins this comparison decisively, and I can say that in artifact terms rather than authorship terms.** The testbed is a first-principles sketch of one tier — the CI guardrail layer. The template is that tier *plus* two tiers the testbed doesn't have at all: an execution engine (orchestrator, blind test-writers in isolated worktrees, a deterministic unattended driver with budget caps), and an authority model for when nobody is awake (the oracle/vision system). Its mechanisms are also epistemically different in kind: nearly every check cites the observed incident that produced it, is covered by an offline test suite, and was hardened against a real downstream project — where the testbed's checks are speculation I tested against three synthetic cases the same afternoon I wrote them.
>
> Three testbed ideas survived the equivalence search and made the transfer list:
>
> 1. **Executable acceptance criteria** — the template's `docs/acceptance.md` records each success criterion as observed *once*; a criterion that regresses after the acceptance pass is caught by nothing. A CI-run acceptance suite for the agent-verifiable subset closes that, and the template's own "observed, not inferred" doctrine argues for it.
> 2. **Dependency rulings as repo artifacts** — the template approves dependencies "in chat," which violates its own recorded "chat is not storage" lesson. One sentence of `AGENTS.md` change, reusing its existing DECISIONS/backlog ledgers.
> 3. **A deterministic gate-path CI check** — cheap insurance for the one condition that silently kills the template's tamper protection: GitHub ignoring an unresolvable CODEOWNERS handle (a risk its own `copier.yml` documents).
>
> Equally important is the do-not-transfer list: my skip-pattern grep, hard size caps, self-authored build reports, and the design-change label all conflict with template doctrines that are better than mine (semantic test-integrity checks beat syntactic ones; tripwire estimates beat Goodhartable caps; computed facts and judged verdicts stay separated).
>
> On autonomy: per merged PR the testbed requires ≥1 human action forever — that ceiling is architectural. The template's unattended happy path is ~4 touchpoints per *design revision* spanning many PRs at zero touches each — with the honest caveat that this figure rests on five behaviors the repo itself flags as unverified-live, and its own history predicts the first real runs will surface more. Candidate scar tissue in the template was genuinely scarce; the four items I flagged (R1000 offset, the glossary wipe protocol, the SSH ceremony, the copier name-question workaround) are all minor and self-aware.

---

## 3. Method note

The agent read the template's README, `copier.yml`, and the generated-project
spec layer (`AGENTS.md.jinja`, `CLAUDE.md.jinja`, `GLOSSARY.md.jinja`, and
`docs/{DESIGN,VISION,DESIGN.oracle,escapes,acceptance}.md.jinja`) directly, and
dispatched three parallel read-only subagents to produce line-cited summaries
of (a) the `.github/` gate scripts and workflows, (b) the `.claude/` command
and orchestration layer, and (c) the template-repo docs, downstream project
evidence, and test suite. The comparative report's template claims rest on
those direct reads and cited summaries; nothing in either repository was
modified during the review.
