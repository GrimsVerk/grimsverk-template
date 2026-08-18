# Opinion on the testbed-vs-template report

Assessment written against `grimsverk-template` @ `claude/copier-template-automation-rii78u` (commit `21c8eae`), the same commit the report analyzed. I spot-checked the report's load-bearing citations directly against the files; no code was written or changed.

---

## 1. Is the report trustworthy?

Yes, unusually so. Every citation I verified is accurate:

- The dependency-approval contradiction is real and quoted exactly: `template/AGENTS.md.jinja:212-213` says "ask first, in chat" while `:251` says "Chat is not storage."
- The CODEOWNERS silent-ignore warning is in `copier.yml` exactly as described ("the rule simply never binds, and the gate paths quietly become writable by anything that passes CI").
- `docs/acceptance.md.jinja` is the one-shot narrated ledger the report says it is, including the honest `agent`/`owner` split.
- `unattended-ready.sh` carries the refuse-vs-note doctrine verbatim, and it does probe the CODEOWNERS errors API on the driver path only.
- The five unverified-live behaviors are flagged in `docs/automation-loop-plan.md`'s header, as cited.
- `DECISIONS.md.jinja` exists and is the right home for durable rulings, as T2 assumes.

The method was also followed honestly: the equivalence search in §2 killed most of the testbed's apparent advantages (only 3 of ~10 survived), and the do-not-transfer section rejects the testbed's most superficially appealing ideas with correct reasoning. If residual bias exists, it runs *toward* the template — an overcorrection — but the report justifies its deference legitimately: the template's mechanisms are postmortems of observed failures with a test suite; the testbed's are same-session speculation.

**Verdict: you can act on this report. The question is only which items are worth acting on.**

---

## 2. The transfer list, item by item

### T2 (dependency rulings as repo artifacts) — implement now. The clearest win.

It fixes a genuine self-contradiction at near-zero cost: one sentence in `AGENTS.md.jinja`, one clause in the review prompt, reusing `DECISIONS.md`/`BL-<n>` homes that already exist. The report is also right to reject the testbed's separate `DEPENDENCIES.md` file — the template already has ledgers with id discipline; a parallel file would be slop. Detection stays where it is (`plan-metrics.sh`); only the *ruling* moves into the repo.

One small note the report misses: `DECISIONS.md` has a decision cap, and dependency approvals will consume it. Rare by policy, so probably fine — but if it ever chafes, `BL-<n>` entries cited by the PR are the alternative the report already allows for.

### T1 (executable acceptance criteria) — the most valuable finding, and the report *undersells* it.

The report's frame is "observed once vs. observed continuously." There is a sharper frame available, in the template's own vocabulary: **the acceptance ledger is the one place in the template where agent narration is admitted as evidence.** Everywhere else the template rigorously splits computed facts from judged verdicts — `plan-metrics.sh` computes, `blind-tests.sh` computes, the reviewer judges, and the report itself praises this split in §4.8. But an acceptance row is "an agent ran a command and wrote down what it printed" — self-graded homework in exactly the sense the template refuses to accept from test suites. Converting the `Verified by: agent` rows into executable checks doesn't just make verification continuous; it moves the "done" claim from the narrated side of the line to the computed side. That is a stronger argument than regression-prevention, and it comes from the template's own doctrine.

Where I part with the report: its hedge that "the honest version is to hold T1 until the first regression-after-acceptance escape, then build it." That over-applies the ratchet doctrine. The ratchet exists to prevent speculative slop in the guardrail layer, and it is rational **when escapes are cheap to observe**. This escape class is the expensive kind: a silently regressed "done" is discovered by the owner, in use, possibly weeks later, with no attribution to the PR that caused it — the worst discovery channel the system has. Waiting for that escape means paying its full price once to justify a check the template's own epistemics already demand. T1 is also arguably not a *new* guardrail but a placement fix for an existing mechanism, which is not what the ratchet rule is guarding against.

Practical middle path: implement the **lite version first** — the `Verified by: agent` criteria live as small executable scripts, run mechanically at each ACCEPTANCE phase entry by the driver (the phase already exists in `deliver-phase.sh`), with the ledger citing them rather than narrating them. No per-PR CI cost yet, minimal machinery, and the narration→computation fix lands immediately. Promote to a per-PR or nightly CI job only if a mid-cycle regression is actually observed — that half of the report's ratchet instinct is right.

### T3 (deterministic gate-path backstop) — agree with the intent, but there is a cheaper design than the one proposed.

The report proposes porting the testbed's ~40-line path-diff script with carve-out logic mirroring `plan-resolve.sh`. That creates **two protected-path lists (CODEOWNERS + the script) and two copies of the carve-out logic that can drift** — precisely the duplication the template avoids elsewhere (one phase detector shared by both drivers, for exactly this reason).

Cheaper and more in the template's idiom: the failure being insured against is *silent CODEOWNERS unbinding*, and `unattended-ready.sh` already knows how to detect it via the codeowners-errors API — it just only runs on the driver path. Run that same probe as a small CI step on every PR (or every PR touching gate paths), failing red when the binding is broken. That checks the platform config instead of replicating it, covers the attended path, and adds no second path list. Caveat in the template's own idiom: verify by observation that an unresolvable owner actually surfaces through that API before trusting it — if it doesn't, fall back to the report's path-diff design, but have the script parse CODEOWNERS itself so there is a single source of truth for the path list.

Either way this is genuinely low priority: the exposure requires silent unbind AND an LLM-reviewer miss AND auto-merge, simultaneously.

### T4 (requirement-shaped stop reports) — agree with the report's own ranking: a convenience, not failure-prevention.

Do it opportunistically whenever the run-report artifact is next touched. Not worth a dedicated change.

### Do-not-transfer — agree with all five, and this section is quietly the best part of the report.

The skip-grep rejection (false positives train people to ignore red), the hard-size-cap rejection (Goodhartable in both directions, and the template's tripwire doctrine measures the right quantity — deviation from an approved plan, not absolute size), and the self-narrated-report rejection (would re-blend computed facts with agent claims) are all correct on the template's terms. Nothing on this list should move.

---

## 3. What the report missed

**a. Nothing validates the reviewer.** The report calls the review gate "the most security-serious file in either repo" and then doesn't notice it is the only load-bearing gate with no fixtures of its own. `test-the-tests` validates the tests; the offline suite validates the scripts; nothing ever checks that the LLM reviewer actually BLOCKs a gate-tampering diff, a smuggled second slice, or an unapproved dependency. The review gate is the single point where one judgment failure plus auto-merge equals a silent gate breach — the same "expensive escape" category that justifies T1. A small fixture set of known-bad diffs the reviewer must block, run nightly or manually (not per-PR — cost and nondeterminism), would be the ratchet applied to the judge itself. I flag this honestly as speculative machinery by the template's standards; but of everything in this document, it is the check I would most want to exist before trusting a long unattended run.

**b. What invalidates stale acceptance rows when the design is revised?** The whole product loop is "owner revises `DESIGN.md` §13 → re-run" — §13 churn is the loop's main input. The report never asks whether the next acceptance pass fully re-verifies old rows or only fills new ones, and I could not find a check that acceptance rows match the *current* §13 ids. Small, but it sits directly on the loop's main path. Note that T1's executable version dissolves this question: criteria-as-checks are edited when §13 is edited, and the path is already CODEOWNERS-owned.

**c. The headline result is implicit and worth stating plainly: the template won, and the comparison is real validation.** A capable agent, given the same brief cold, reconstructed roughly the template's CI tier — and none of its two deeper tiers (the execution engine, the unattended-authority model) — and on nearly every shared mechanism the template's version was stronger and evidence-hardened. Separately, the blind reconstruction in §1 succeeded without guessing, which was the actual test of the template's legibility as a spec. The testbed did its job as a probe; discard it as planned.

**d. The best next action is not on the transfer list.** Five behaviors are still unverified-live, and the template's own epistemics ("a check must be observed working, not inferred") apply to the template itself. Running one real project through the full unattended loop is worth more than any transfer, and it also generates the evidence that settles T1's full-CI question and the reviewer-eval question.

---

## 4. Recommended order

1. **T2** — now. Trivial, pure win.
2. **T3-lite** — now, if the codeowners-errors probe pans out under observation; it's a few lines in an existing job.
3. **Live run of a real project** — before, or interleaved with, everything below. This is the template's own stated next step and the report's implicit one.
4. **T1-lite** — executable `Verified by: agent` criteria run at ACCEPTANCE phase; design now, land with or immediately after the first live run. Promote to CI on first observed regression.
5. **Reviewer eval fixtures** — hold as a designed candidate; build after the first live run, or immediately if long unattended runs start before then.
6. **T4** — opportunistic only.
