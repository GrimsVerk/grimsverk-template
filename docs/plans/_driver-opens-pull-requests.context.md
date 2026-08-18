# Context for `driver-opens-pull-requests.md`

Written 2026-08-18 by the session that produced the plan. The plan records
*what* was decided; this records provenance, the reasoning that did not survive
compression, and what is asserted rather than seen.

Underscore-prefixed so `plan-lint.sh` skips it: prose about a plan is not a plan.

---

## 1. How this was found

The owner asked, after fixing the GitHub App locally:

> "since the app is working now, didnt we have an issue with the agents being
> able to make pr's as if they were me? would using this app be able to prevent
> that? just investigate, no implementation now"

The honest answer was "partly, and there is a gap the fix never reached". The
investigation was five greps; the defect had been sitting in `ORCH_TOOLS` since
the driver existed, through the whole of `ESC-26`'s remediation and through two
adversarial reviews.

**Nobody was looking for it, and that is the interesting part.** `ESC-26` was
written about `mechanical_pr()` and its fix was verified against
`mechanical_pr()`. The question "which OTHER things open pull requests" was
never asked, because the entry framed the defect as being about that function
rather than about the property — *no unattended pull request is authored by the
owner*. A fix scoped to the instance rather than the property is how the same
defect survives its own remediation, which is `ESC-22` and `ESC-27` and now this.

## 2. The acceptance deadlock is the load-bearing argument, and it is ASSERTED

The provenance argument alone would justify this plan but not urgently. The
acceptance argument is what makes it a bug rather than a tidiness:

- `docs/acceptance.md` is `CODEOWNERS`-owned (`CODEOWNERS.jinja:65`).
- `setup-github.sh:251-252` configures `required_approving_review_count: 0` with
  `require_code_owner_review: true`.
- GitHub does not let a pull request's author approve it.
- The acceptance pull request is opened by a session running as the owner.

Therefore the one pull request whose review is the entire point of an unattended
run cannot be approved by the only person entitled to approve it.

**That chain is reasoned, not observed.** No unattended run has ever reached
acceptance in any repository here. The first three links are read out of the
files; the fourth is documented GitHub behaviour; the conclusion is inference.
If it turns out GitHub permits it under some setting combination, the plan is
still right for provenance and this paragraph is the thing to correct.

A reviewer who wants to check it cheaply: open a pull request touching
`docs/acceptance.md` as the owner, on a repository with the ruleset
`setup-github.sh` creates, and try to merge it.

## 3. Why the token is moved rather than shared

The obvious fix is one line — `GH_TOKEN="$(app-token.sh)"` in `run_session()`.
It was rejected for a reason that is not obvious:

**An installation token lasts an hour, and `SESSION_TIMEOUT` is an hour by
default.** A session that runs long would hold an expired token and its
`gh pr create` would fail at the very end, after all the work. The failure would
be rare, late, and would look like a GitHub outage rather than a design flaw —
the worst combination for something that only happens unattended.

Minting per-call inside the session is not available either: the session would
need `Bash(.claude/scripts/app-token.sh:*)` in its grant, which hands every
orchestrate session the ability to mint an App token for any purpose. That is a
much larger grant than the one being removed.

So the button moves to the driver, which already mints per pull request
(`mechanical_pr()` comments say exactly why) and already opens pull requests for
every worker. The shape was already there; the feature and acceptance paths just
never used it.

## 4. Interpretation calls a reviewer should check

- **Attended `/orchestrate` keeps opening as the owner.** This is the session's
  call. The argument: a human running a command and a pull request appearing
  under their name is an accurate record, and making it an App pull request
  would put a bot's name on a human's decision. The counter-argument, which is
  real: one identity everywhere is simpler to reason about, and "attended" is a
  mode nobody verifies. The plan asks the owner rather than settling it.
- **Idempotency over refusal.** If a pull request already exists for the head
  ref, the driver reports and continues rather than failing the phase. A driver
  that hard-failed there would turn a harmless race — an attended session that
  already opened one, a retried iteration — into a stopped run. The cost is that
  a session which somehow still opens its own pull request would go unnoticed;
  the fixture asserting the grant is absent is what covers that.
- **The `UNATTENDED RUN` marker is load-bearing and cheap.** The worker
  dispatches carry it and were fixed by `ESC-26`; the orchestrate and acceptance
  dispatches do not, and were not. That is not a coincidence — a command file
  that cannot tell which mode it is in has to write prose that is right for
  both, and "open the pull request" was right for one of them.

## 5. What is asserted rather than observed

- The approval deadlock (§2).
- That removing `gh pr create` from `ORCH_TOOLS` does not break `/orchestrate`
  in some way the command file does not describe. The grant list is a fence, not
  a contract, and the session's actual behaviour under it has never been watched
  end to end — `ESC-18`'s note applies: a fixture cannot prove a live headless
  engine honours a grant.
- That the App identity works at all. The owner reports fixing it locally today;
  no pull request has yet been opened by it in this repository, and `ESC-26`
  remains open in `docs/escapes.md` for exactly that reason. **This plan does not
  close `ESC-26`** — it closes a different, newly-found gap beside it.

## 6. Related records

- `docs/escapes.md` `ESC-26` — the original identity defect and its fix.
- `docs/escapes.md` `ESC-22`, `ESC-27` — the same "a path added after the list
  that names paths" shape, twice before.
- `docs/DESIGN.md` R5 — the property this restores, stated as a requirement.
- `docs/plans/_escape-closure.context.md` §3 — the closure-ledger trust boundary,
  which slice 3's row is written under.
