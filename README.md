# grimsverk-template

A [Copier](https://copier.readthedocs.io/) template for new GrimsVerk projects.
This repository is the template itself — nothing in it ships directly; it
*generates* project repositories.

Supported languages:

- `python` — uv-managed package, src layout, ruff + mypy + pytest
- `swift-ios` — SwiftUI iOS app, XcodeGen-managed project, SwiftFormat + SwiftLint

## Before you start: GitHub Pro is required

> **The gate design does not work on a Free plan private repository.** Branch
> protection and rulesets are Pro-only for private repos, and *everything* here
> depends on them: required status checks, `CODEOWNERS` enforcement, auto-merge.
> You will get all the way to step 6, open the ruleset page, and find nothing to
> configure.
>
> Two ways through:
>
> - **Pay for GitHub Pro.** Per-user, and it covers every private repo on the
>   account — one subscription, not one per project.
> - **Make the repo public.** Branch protection is free on public repos. Note
>   what that means here: this template ships no `LICENSE` by design, so a public
>   repo is public **and unlicensed** — readable by anyone, with no permissions
>   granted to anyone.

## Starting a new project

**You never clone this template.** Copier reads it from GitHub and *renders* a
fresh project into a new local directory. That directory is not a git repo and
has no remote — you turn it into one and push it to a brand-new, empty GitHub
repo. Steps 1–5 get you a working local project on GitHub; step 6 turns on the
merge gates, and its order matters.

Set the project name once. **Every command below uses `$PROJECT`, so nothing
after this needs editing** — copy them verbatim.

```sh
PROJECT=find_best_mobo
```

> `$PROJECT` lives in the shell that set it. Open a new terminal, or come back
> tomorrow, and you need to run that line again before any command below works.

### 0. System readiness (once per machine)

```sh
# Arch
sudo pacman -S uv git github-cli
```

```sh
# macOS
brew install uv git gh
```

Then, either OS — `copier` and `pre-commit` are installed as **machine tools**,
not project dependencies:

```sh
uv tool install copier
uv tool install pre-commit
```

`pre-commit` bootstraps its own isolated environments for each hook, so it does
not belong in a project's dependencies. It also has to work for the `swift-ios`
scaffold, which has no Python virtual environment to install into at all.

You also need the **Claude Code CLI** for `claude setup-token` in step 6a — see
[the install docs](https://docs.claude.com/en/docs/claude-code/setup).

**Verify SSH.** `<ssh_host>` below is your personal SSH host alias for
GitHub (for example `github.com-yourname` in `~/.ssh/config`; the owner keeps
theirs, with the other machine-local values, in an identity register at
`~/.config/grimsverk/identity.json`). Everything downstream depends on this
answering with your name:

```sh
ssh -T git@<ssh_host>
```

Expect `Hi <you>! You've successfully authenticated...`. If instead you get
a permission error, stop and fix the key before going further — every git and
`gh` command below will fail in ways that look like something else.

> `ssh -T git@github.com` (without the alias) failing is **normal**
> and not a problem. The alias is what carries the right key; the bare host has
> no key attached.

**Route the template's HTTPS URL over SSH.** You will generate projects from
`https://github.com/GrimsVerk/grimsverk-template.git` — because that is the URL
CI has to be able to fetch — but your key is what authenticates you locally. One
rule bridges the two:

```sh
git config --global \
  url."ssh://git@<ssh_host>/GrimsVerk/grimsverk-template.git".insteadOf \
  "https://github.com/GrimsVerk/grimsverk-template.git"
```

It is scoped to that single URL, so no other GitHub remote is affected. Check it
with `git config --global --get-regexp insteadOf`.

> This lives in `~/.gitconfig`, so it is **per machine** — a new laptop needs it
> again, and the symptom there is a password prompt on `copier copy` or
> `copier update`. Do not "fix" that by generating from the SSH URL instead: that
> writes the alias into `_src_path`, which resolves on exactly one machine and
> breaks `template-sync` for everyone including CI.

**Verify the GitHub CLI:**

```sh
gh auth status
```

It must show `GrimsVerk`. If not, `gh auth login` and answer:
**SSH** for the protocol · **Skip** the public key upload (the key is already on
the account, and uploading asks for an `admin:public_key` scope the CLI does not
need) · **Login with a web browser**.

> The browser grant follows whichever account is *currently signed in*. If that
> is not GrimsVerk, you will authorise the wrong account without being told.
> Check the browser session first.

### 1. Generate the project

```sh
copier copy https://github.com/GrimsVerk/grimsverk-template.git $PROJECT
cd $PROJECT
```

**Use the `https://` URL, even though you authenticate over SSH.** Copier records
whatever URL you type into `.copier-answers.yml` as `_src_path`, and that value
is later read by *CI* — which has no SSH key and cannot resolve a host alias from
your personal `~/.ssh/config`. Hand it an `ssh://git@<ssh_host>/…` URL
and the `template-sync` check fails with `Could not resolve hostname` before
copier even starts, and no token can fix it.

The `insteadOf` rule from step 0 is what makes this work on your machine: git
quietly routes that one HTTPS URL back over SSH, so your key is still what
authenticates. Neither side has to know about the other.

> Do not use `gh:GrimsVerk/grimsverk-template` either. That shorthand also
> expands to HTTPS, but it is not the URL your `insteadOf` rule matches, so it
> prompts for a password — and passwords have not worked for git operations
> since 2021.

Copier asks five questions, and the first one answers itself:

| Question | Notes |
| --- | --- |
| `project_name` | **Press Enter** — it defaults to `$PROJECT`, the directory you just named. Becomes the repo name, the Python package, and the name in every generated document. It is asked rather than simply taken from the folder because Copier only remembers answers it asked for, and `copier update` runs in a scratch directory where the folder name is meaningless |
| `language` | `python` or `swift-ios` |
| `description` | One line; lands in the README, the package metadata, and the module docstring |
| `auto_merge` | `true` (default) = green PRs merge themselves. Choose `false` for anything real people download, or that touches payments, secrets, or user data — those keep a human merge |
| `code_owner` | Defaults to `@GrimsVerk`. Owns the merge gates in `CODEOWNERS`: changes to CI, the review check, pre-commit and the rule files need this owner's review, even under auto-merge. Must be a real `@handle` or `@org/team` — GitHub silently ignores entries that don't resolve |

If the name cannot be a Python package name, generation stops before writing
anything and tells you so. `find_best_mobo` and `find-best-mobo` are both fine;
`My App 2.0` is not.

### 2. Make it a git repo

`git init` comes **before** `pre-commit install`, because `pre-commit install`
writes into `.git/hooks/` and fails with `FatalError: git failed` outside a
repository. **The first commit comes AFTER step 3**, not here — the CI `checks`
job runs `uv sync --locked`, which demands a committed `uv.lock`, and `uv.lock`
does not exist until step 3's `uv sync` creates it. A scaffold committed before
the toolchain ran ships a project whose very first push is red (ESC-47).

```sh
git init -b main
```

### 3. Bootstrap the toolchain, then make the first commit

```sh
uv sync                     # python — this creates uv.lock, which MUST be committed
uv run pre-commit install   # pre-commit is a dev dependency, installed by uv sync (ESC-55)
```

```sh
brew install xcodegen swiftformat swiftlint   # swift-ios
xcodegen generate
pre-commit install
```

Now the scaffold commit, carrying `uv.lock` with it:

```sh
git add -A
git commit -m "Initial scaffold from grimsverk-template"
```

The generated `AGENTS.md` forbids committing directly to `main`; this initial
scaffold commit is the one exception, made before the gates exist.

**Check the commit went in under the right identity:**

```sh
git log -1 --format='%an <%ae>'
```

It must show the GrimsVerk identity — the conditional include in `~/.gitconfig`
handles that for anything under your `<repos_root>`. If it shows something else,
fix it now:

```sh
git config user.email 'your-grimsverk-email'
git commit --amend --reset-author --no-edit
```

One command now, or a `git filter-repo` run over a whole history later.

### 4–6, scripted: `scripts/setup-github.sh`

Everything from here through step 6 is one idempotent run of the script every
generated project ships:

```sh
scripts/setup-github.sh --ssh-host <ssh_host> --app --verify
```

It creates the repository and pushes (step 4), sets the merge settings and
prompts for the missing secrets (silently — a value never touches an argument
list or a log), creates or updates the `grimsverk-gates` ruleset with the
required checks for the project's language (step 6), and with `--verify` runs
the throwaway-PR dance so every PR-only check reports once. Re-running it
finishes a partial setup instead of duplicating anything. Afterwards, read the
configuration back before trusting it:

```sh
.github/scripts/unattended-ready.sh
```

**What stays manual, each for a security reason rather than a missing
feature:** typing the secret *values* (`claude setup-token` is an interactive
OAuth flow, and the script never fetches or stores a credential), creating the
GitHub App in the GitHub UI (the App form has no API — `--app` prints the
exact URL and permission list; there are deliberately no PATs to mint any
more), `gh auth login`'s browser grant, and
the Pro-vs-public choice at the top of this file.

The REST API accepts required-check contexts that have not reported yet — the
"must report once" constraint is a UI-dropdown limitation — which is what lets
the script create the ruleset before the first pull request. That claim is
flagged unverified-live in the script header; `--verify` is the belt to its
braces.

### The GitHub App, and both places its credentials live

The App is not a convenience for tidying up branches. It is the **identity the
unattended driver opens pull requests as**, and without it the driver opens them
as you — which makes `.github/scripts/owner-authored.sh` compare your login to
your login and pass, for every pull request, including one carrying an agent's
edit to `docs/DESIGN.md`. `unattended-ready.sh` refuses a run until the App
exists, and that refusal is deliberate.

**1. Create it, once per account** (not per project):

<https://github.com/settings/apps/new>

| Field | Value |
| --- | --- |
| GitHub App name | anything unique — `grimsverk-driver` is fine |
| Homepage URL | anything; your GitHub profile URL will do |
| Webhook → Active | **uncheck it** |
| Repository permissions → Contents | **Read and write** |
| Repository permissions → Pull requests | **Read and write** |
| Repository permissions → Checks | **Read-only** (a web-session driver reads CI results through the App) |
| Where can this GitHub App be installed? | **Only on this account** |

Keep it at exactly those three permissions — the App is the identity the
unattended driver acts as, so it must never hold Administration or Secrets.

Nothing else needs changing. Create it, then on the App's page:

- note the **App ID** (a number near the top — not the Client ID);
- **Generate a private key**, which downloads a `.pem`;
- **Install App** → install it on this repository **and on the template
  repository** (`template-sync` reads the template through this App; there is
  no PAT path).

**2. Give the credentials their two homes.** This is the part that is easy to
half-do, because the two halves are read by different things:

| Home | Read by | Set by |
| --- | --- | --- |
| Repository secrets `APP_ID`, `APP_PRIVATE_KEY` | `auto-merge.yml`, inside Actions | `scripts/setup-github.sh --app` |
| A local file or two env vars | `.claude/scripts/app-token.sh`, on your machine | you, once |

Actions cannot read your laptop and your laptop cannot read repository secrets,
so both are required — and **one command does both**:

```sh
scripts/setup-github.sh --app
```

It asks for the App ID and the path to the `.pem`, sets the two repository
secrets, and writes `.claude/app-identity` (gitignored, `chmod 600`) with the
same values for the driver. Setting one home and not the other is the failure
worth naming: the App looks configured and every unattended run still refuses.

Doing the local half by hand — on a second machine, say, where the secrets
already exist — means copying the skeleton that ships beside it:

```sh
cp .claude/app-identity.example .claude/app-identity
```

and filling in its two values. Or export them instead:

```sh
export GRIMSVERK_APP_ID=123456
export GRIMSVERK_APP_PRIVATE_KEY=/absolute/path/to/your-app.private-key.pem
```

> **Keep the `.pem`.** That path is read on **every run** — this is not a
> one-time import. Put it somewhere durable outside any repository;
> `~/.config/grimsverk/` is a good home. `chmod 600` it. It is a credential:
> treat it like an SSH key.
>
> A directory beside your repositories works too, and `*.pem` is gitignored in
> both this repository and every generated one, so it cannot be committed by
> accident. Outside the code tree is still better — a key that lives next to
> code travels with the code when you copy, archive, or share a folder.

**3. Check it works** before you rely on it:

```sh
.claude/scripts/app-token.sh >/dev/null && echo "App identity OK"
```

That mints a real installation token and throws it away. It prints nothing on
success. Its failures are specific on purpose — exit 3 means "not configured
yet" and names what is missing; exit 4 means "configured, but the exchange
failed" and distinguishes a wrong ID/key pair (401) from an App that exists but
is not installed here (404).

Then `.github/scripts/unattended-ready.sh` should stop refusing.

Steps 4–6 below remain as the reference for what the script does and for doing
it by hand.

### 4. Create the GitHub repo

```sh
gh repo create GrimsVerk/$PROJECT --private --source=.
git remote set-url origin git@<ssh_host>:GrimsVerk/$PROJECT.git
git push -u origin main
```

The `set-url` line is not optional and not a fix for a failure. `gh repo create`
will report that it added a `git@github.com:` remote — that plain host has no key
attached, so a push against it fails. Rewriting it to the `<ssh_host>`
alias is what makes the push work.

> Do **not** use `gh repo create --remote=origin --push`. It sets the remote to
> the keyless plain host and pushes in the same breath, so it fails with no
> opportunity to correct the URL first.

### 5. Confirm the first CI run

Watch the push land green before configuring anything else — the checks have to
report once before they can be marked required.

```sh
gh run watch
```

### 6. Turn on the gates — in this order

GitHub only lets you mark a status check *required* after it has reported at
least once, and the checks first report at different times:

| Check | Runs on | First reports after |
| --- | --- | --- |
| `checks` (python) / `test` (swift-ios), `secrets` | every push | your first push |
| `plan`, `template-sync`, `test-the-tests`, `acceptance-criteria`, `review` | pull requests only | your first **PR** |

So most of the list cannot be marked required straight after step 4 — the names
won't be in the dropdown yet. Hence the order:

**a. Add the review credential first.** *Settings → Secrets and variables →
Actions → New repository secret*, named `CLAUDE_CODE_OAUTH_TOKEN`. Get the
value by running `claude setup-token` locally (uses your subscription, not a
metered API key). Do this *before* making `review` required — the job fails
closed without a credential, so every PR would block.

**a2. Install the App on the template repository too.** The `template-sync`
check fetches this template to verify an update, and a project's built-in CI
token cannot reach another repository — so the workflow mints a read-only token
from the GitHub App, scoped to this template alone. That works only if the App
is installed here as well as on the project (App settings → Install App).
There is deliberately no `TEMPLATE_TOKEN` PAT any more: a PAT expires, a year
at most, and when it did, template updates failed in every project at once.

**b. Enable the merge settings.** *Settings → General → Pull Requests*:

- **Allow auto-merge** — on. Without it, `auto-merge.yml` cannot arm anything.
- **Allow merge commits** — on (the default). Merge commits are what make the
  one-line `git revert -m 1 <merge-sha>` rollback work, so keep them even when
  `auto_merge` is `false`.
- **Automatically delete head branches** — on. Off by default, and every
  orchestrated feature leaves a stale branch behind without it.

  **This setting alone does not cover auto-merge, and the reason is worth
  knowing.** GitHub does not create workflow runs from events caused by the
  built-in `GITHUB_TOKEN` — a guard against a workflow triggering itself. So an
  auto-merge armed with that token completes as `github-actions[bot]`, the
  `pull_request: closed` event dispatches nothing, and nothing cleans up.
  Observed downstream as twenty-two stale branches from bot merges alongside two
  human merges that tidied up correctly, which reads exactly like the setting
  being broken and is not.

  Two answers, and they compose:

  - **The GitHub App** — `auto-merge.yml` prefers an App-minted token over
    `GITHUB_TOKEN`, so merges are attributed to the App, the close event
    fires, and cleanup happens immediately. (An `AUTO_MERGE_TOKEN` PAT used to
    be the alternative and is gone deliberately: it acted as you and expired,
    and the ruling is that the App is the only GitHub credential a project
    configures.)
  - **Always on: the scheduled sweep** in `auto-merge.yml` deletes branches whose
    pull requests have merged, daily. Scheduled runs are not suppressed by the
    token rule, so this works with no secret configured. It skips any branch an
    open pull request still uses as head or base, and never touches a
    closed-but-unmerged branch — that work is unmerged by definition and the
    branch is often the only copy.

**c. Open one throwaway PR** so the PR-only checks register:

```sh
git checkout -b chore/register-checks
git commit --allow-empty -m "Register the pull-request checks"
git push -u origin chore/register-checks
gh pr create --fill
```

The `chore/` prefix matters: it exempts the branch from the `plan` check, which
would otherwise fail an empty commit that has no plan. Let every check run.

**d. Add the ruleset.** *Settings → Rules → New ruleset → New branch ruleset*.

- **Target branches — this is empty by default and enforces nothing.** Add
  target → **Include default branch**. A saved ruleset with no target displays
  `This ruleset does not target any resources and will not be applied`, which is
  easy to read past. Prefer *Include default branch* over naming `main`: it is a
  pointer, so it survives a default-branch rename.
- **Enforcement status: Active.** Not *Disabled*, and not *Evaluate* —
  *Evaluate* reports what it *would* have blocked and blocks nothing.
- **Restrict deletions** and **Block force pushes** — leave both on. Block force
  pushes is what protects the revert-based rollback. A deliberate history rewrite
  means toggling the rule off and back on, which is the intended amount of
  friction.
- **Do NOT enable "Require linear history."** It sits directly beside rules you
  do want, and it blocks merge commits — which breaks `git revert -m 1`, the
  rollback the whole auto-merge design leans on.
- **Bypass list** — leave it empty. Anyone on it can push straight past every
  rule below; an empty list means the rules apply to you too, which is the point
  when you are the only author. It can be edited on a live ruleset whenever you
  actually need an exception.
- **Require a pull request before merging** — on, with **Required approvals: 0**
  and **Require review from Code Owners** on.
- **Require branches to be up to date before merging** — recommended on. The
  merge queue that normally absorbs its friction is not available on Pro for
  private repos (the rule simply does not appear), but at one-PR-at-a-time per
  base branch — which the orchestration design already enforces — the friction
  is negligible.
- **Require status checks to pass** → add `checks` (or `test` for swift-ios),
  `secrets`, `plan`, `template-sync`, `test-the-tests`, `acceptance-criteria`,
  and `review`.
- **Do not enable** code scanning, code quality, coverage, or deployment rules.
  No workflow in this template emits those results, so every PR would wait
  forever on a check that never arrives.

> The approvals number is the setting most likely to be got wrong. Anything ≥ 1
> gates *every* PR on a human approval, and auto-merge never fires. `0` **plus**
> *Require review from Code Owners* is the intent: ordinary PRs merge on green,
> while PRs touching the gate paths in `CODEOWNERS` still need your approval.

**e. Merge or close the throwaway PR.**

> **Changing the required-check list does not re-evaluate open PRs.** A PR opened
> before you edited the list keeps waiting on the old one, forever, with no
> indication why. Close and reopen it, or push an empty commit, to re-evaluate.

### The CODEOWNERS self-approval deadlock

**GitHub never requests review from, or accepts an approval by, the author of a
pull request.** You own the gate paths in `CODEOWNERS` and you author every pull
request, so **a PR that touches `.github/`, `AGENTS.md`, `docs/plans/` or the
other owned paths cannot be merged normally.** Code Owners review is required,
and the only eligible reviewer is you, and you are disqualified.

This is GitHub working as designed, not a misconfiguration, and there is no
setting that fixes it. The ways through:

- **Admin bypass** — merge it yourself with admin rights, which is what the
  bypass list exists for if you decide to use it.
- **Toggle the ruleset to Disabled**, merge, and switch it back to Active.

Expect this the first time you change a workflow. It is the cost of having the
gate paths owned at all, and the alternative — leaving them unowned — is what the
whole design is built to avoid.

### 7. Start working

Run `/design` in the project and rant your idea at it — it writes
`docs/DESIGN.md`, which the review gate then checks every PR against. After
that it's branch → PR → green → merge. The generated `README.md` carries the
per-project details, including the `git revert -m 1 <merge-sha>` rollback
recipe that is the real safety net under auto-merge.

### What you get

```
AGENTS.md            agent guidelines (CLAUDE.md is a one-line pointer to it)
GLOSSARY.md          how agents talk to you + the vocabulary you've settled
docs/DESIGN.md       design doc skeleton + the /design interview kit
docs/VISION.md       what you value and what you'd trade away — the tiebreaker
docs/DESIGN.oracle.md  design decisions an agent may make from logged evidence
.github/             CI, the LLM review gate, CODEOWNERS, auto-merge
.pre-commit-config.yaml
.claude/             optional convenience layer — deletable, nothing breaks
.copier-answers.yml  lets `copier update` pull in template changes later
```

## Glossary and communication rules

`GLOSSARY.md` carries two word lists — vocabulary you're still learning, which
agents explain, and vocabulary you've settled, which they must not re-explain —
plus the rules for how they write to you: dense while working, high level in
summaries. A word in neither list counts as unknown, so the agent glosses it and
asks where it belongs, which fills the lists in as you work rather than needing
an authoring session up front.

It is deliberately **two** files. `GLOSSARY.md` ships from the template and is
replaced wholesale by `copier update`, so projects never edit it.
`GLOSSARY.project.md` is created on first use inside a project, grows there, and
— because the template never ships it — can never be clobbered by an update.
`GLOSSARY.project.md` is a **staging buffer, not a record**: it exists only
because a project session may not have this repository attached, so it is the
one place a word can be added mid-project. When its list has grown usefully,
fold the words into the template's `GLOSSARY.md` and **wipe the project file
back to empty**; they return to that project, and reach every other project, on
the next `copier update`. There are deliberately no lasting project-specific
glossaries. Sequence the wipe with the update that carries the words back down —
wiping first leaves the project with no definitions in between.

## Design-doc workflow

Every generated project ships a design-doc kit under `docs/`. Open the
project and run the `/design` slash command (or just point the agent at
`docs/idea-to-design-doc.md`), rant your idea at it, answer its questions,
and it writes the finished doc into `docs/DESIGN.md`. `docs/DESIGN.md` is
the skeleton and single source of truth for the doc's shape.

## The second design document

`docs/DESIGN.md` is yours: `CODEOWNERS` puts it behind your review, so a design
change waits for you. That is correct — it is the standard every pull request is
judged against — and it is also why unattended work stops at the first thing the
evidence contradicts. Real runs produce evidence that the design is wrong, and
without somewhere for that to land, it queues up until you are free.

`docs/DESIGN.oracle.md` is where it lands. Append-only, mechanically checked, and
deliberately **not** owned — ownership there would stop overnight work, which is
the point of having it. Requirements are the union of both documents; oracle ids
start at **R1000** because they share one integer space with yours.

What makes it safe is `.github/scripts/oracle-decisions.sh`, wired into the
existing `plan` job so **no new required check has to be added to branch
protection**:

- every decision cites evidence that already landed — an `ESC-<n>` from
  `docs/escapes.md` or a `BL-<n>` from `docs/BACKLOG.md`. A design change can
  only ever *metabolise something logged*; it can never be invented;
- decisions are append-only, superseded rather than revised, with increasing ids;
- each carries a date, its evidence, the requirement ids it adds or supersedes,
  the alternatives weighed, its rationale, and **the `docs/VISION.md` statement
  it relied on**;
- a runaway-loop cap of 150.

`docs/VISION.md` is the tiebreaker: what you value, in order, and what you would
trade away. It is `CODEOWNERS`-owned and **no agent may edit it**.

**Write it whenever suits you, as long as it is done before the first plan.**
`/design` offers it up front and takes "after the design" for an answer — often
the better order, since a vision written before you have seen the design is a
guess about your own priorities. The deadline is implementation, and
implementation starts at the plan, so `.github/scripts/vision-complete.sh` fails
a pull request that adds or edits a plan while any section is still empty.
Design-doc pull requests pass freely. Delete a section you do not want rather
than leaving it blank, and delete the file entirely to opt out of the oracle. That pairing
is the whole mechanism — when a decision comes out wrong, you edit the statement
that produced it rather than arguing with the decision, and every future decision
moves with it.

## Orchestration (optional Claude layer)

Generated projects also carry a single-layer orchestration setup under
`.claude/`: run `/orchestrate <slug>` and the session builds **one** planned
feature. It gets its own branch, a pair of headless workers per slice of its
plan (a coder and a test-writer, each in its own git worktree), and one pull
request. The orchestrator assembles the worker branches and opens the PR — it
never merges; that stays mechanical, driven by the required checks going green.

**The orchestration path has its own smoke test, and it is not in CI.**
`tests/smoke-worker.sh [engine…]` spawns one trivial worker per engine against
the real CLI and asserts it committed. It is deliberately outside `tests/run.sh`
— it needs an authenticated engine and spends subscription budget — but it
exists because this path shipped with four independently fatal faults, every one
of which survived because nothing ever ran it until a human needed it. Run it
after changing `spawn-worker.sh` and after any engine CLI upgrade;
`tests/test-spawn-worker.sh` pins the script's own logic with stub engines on
every push.

Exactly one layer of spawning: the orchestrator drives every worker directly and
never spawns another orchestrator. To build two features at once, open a second
session — that keeps each orchestrator's context clean for assembly, and you
remain the one place that knows what is running. See `.claude/orchestration.md`
in a generated project for the one-layer rule, the two concurrency limits, the
requirement that concurrently-built features not touch the same files, sandbox
defaults, and safety notes. Like the rest of `.claude/`, it is deletable without breaking the
project.

## The build loop

Generated projects carry a full path from idea to evidenced delivery, each stage
leaving an artifact the next one checks against:

| Command | Produces | Checked by |
| --- | --- | --- |
| `/design` | `docs/DESIGN.md` — what and why, requirements `R1…`, criteria `S1…` | the owner, through the interview itself |
| `/plan` | `docs/plans/<slug>.md` — vertical slices, files, signatures, estimates | the owner, at a hard uncertainty stop, then by merging the plan |
| `/orchestrate` | one branch and PR per feature; per slice a coder and a blind test-writer in parallel | CI, `plan`, `test-the-tests`, the review gate |
| `/deliver` | drives the loop attended, then `docs/acceptance.md` | the owner, for anything an agent can't observe |
| `deliver-loop.sh` / `/deliver-loop` | the same loop **unattended**: phase-detects, dispatches one session at a time, waits mechanically on CI | `unattended-ready.sh` (refuses an impossible run), then every gate above; stops say why (pattern, budget, blocked-on-owner) |

Plans land before the code that implements them, on their own `docs/` pull
request — `CODEOWNERS` puts `docs/plans/` behind your review, so merging a plan
*is* the ruling on it, and CI rejects any PR whose plan isn't already at its
base commit. No agent merges at any point; merges are triggered by checks going
green.

**Unattended, the owner's three jobs are the whole surface**: land the vision
and design, optionally steer mid-run by editing those two documents (they stay
owner-authored — that is the steering lever), and review at the end. Everything
between runs through the driver: `.claude/scripts/deliver-loop.sh` locally, or
the `/deliver-loop` command in a Claude Code web session — same phase detector,
so the modes cannot drift. Mid-run rulings the owner used to make belong to the
oracle: uncertainties are filed as `BL-<n>` backlog items and ruled as `OD-<n>`
decisions (HIGH-risk ones block planning until ruled; LOW proceed on a recorded
default), and unattended plans land on the un-owned `docs/plans/oracle/` path,
constrained mechanically — they can implement landed requirements and can never
propose work. The rulings behind all of this ship pre-recorded in every
generated project's `docs/DECISIONS.md`.

**One feature per orchestrator.** `/orchestrate` builds a single feature start to
finish. To work on two at once, open a second session and run it there — each
keeps a clean context for assembly, which is the step that degrades quietly as
diffs pile up, and neither has to police the other. Two limits apply inside one
session: **12 concurrent workers** (machine and subscription — workers share the
rate limit with the review gate, which fails closed) and **6 slices assembled per
session** (your context). A 3–5 slice plan sits inside both.

## Updating generated projects

Every generated project contains a `.copier-answers.yml` file. To pull in
template improvements later, run inside the project:

```sh
copier update
```

Re-run it after changing an answer too — e.g. flipping `auto_merge` on an
existing project.

**Put it on a `template/` branch.** A template update is a third kind of change:
not planned work, not a trivial chore. It was specified and reviewed *here*, in
this repository, at the merge that produced the version being pulled in — so no
plan in the target project could ever describe it, and the `plan` check would
block it forever.

Every generated project ships a script that does the whole thing:

```sh
scripts/update-from-template.sh
```

Run it on a clean default branch. It updates, works out which template version
it landed on, branches as `template/<version>`, commits, pushes, and opens the
pull request — no further input. `--no-pr` stops before the pull request;
`--ref HEAD` pulls in a change that has merged here but is not tagged yet.

It hands back to you in one case only: a **conflict**, where the template
changed a file the project also changed. Copier leaves both versions in the file
with markers around them and no script can pick a side. Nothing is committed at
that point, so `git checkout -- .` backs the update out cleanly.

The prefix exempts it from `plan` and hands verification to **`template-sync`**,
which replays `copier update` from the PR's base commit and fails unless the
result is byte-for-byte the pull request. That is a stronger guarantee than a
plan — a plan says someone intended a change; this proves nothing hand-written
rode along with the sync. So the branch carries the template's output and
**nothing else**; a hand fix on top goes in its own later PR, with a plan.

Two things to expect:

- **You will approve it yourself.** Template updates touch `.github/` and
  `AGENTS.md`, which `CODEOWNERS` owns, and GitHub refuses your approval on your
  own PR. That is the deadlock described above, working as intended — a change to
  your own gates is exactly what a human should look at. `template-sync` green is
  what makes that a read of the release notes rather than an audit of 40 files.
- **Each project needs the App installed on this template.** This template is
  private, and a project's built-in CI token is scoped to that project — it
  cannot read another repository. So `template-sync` mints a short-lived token
  from the GitHub App (the `APP_ID` / `APP_PRIVATE_KEY` secrets every project
  already carries), down-scoped to Contents: Read-only on this template alone.
  That works only while the App is installed on `grimsverk-template` as well
  as on the project — one click, once, on the App's Install App page.

  There is deliberately no `TEMPLATE_TOKEN` PAT any more. A fine-grained token
  expires, a year at most, and when it did, template updates started failing
  in every project simultaneously with an error that never said "expired
  token". An App key does not expire, and a fallback that must be set up
  defeats the point of having less to set up.

> `--trust` is not needed for either command: this template renders files only
> and runs no tasks or migrations. If a future version adds one, Copier will
> refuse and tell you to re-run with `--trust`.

## Releases and versions

**Tagging and releasing are automatic.** Every merge to `main` gets a tag *and*
a GitHub release from `.github/workflows/release-tag.yml`; there is nothing to
run by hand. The bump is patch by default, and the merged pull request's
**title** escalates it: a `feat:` prefix bumps the minor, a `feat!:`-style `!`
or a `BREAKING CHANGE:` footer bumps the major.

Copier only needs the tag — it resolves refs. The release is the human-facing
half: it is what appears as **Latest** on the repository page and what carries
the generated notes.

This matters because **Copier resolves a template to its latest tag, not to the
tip of `main`.** That is why `copier copy` and `.copier-answers.yml` show a
version like `v0.4.0` rather than a commit. It also used to be a trap: a change
could merge, sit untagged on `main`, and reach no new project and no
`copier update` — which is exactly how `find_best_mobo` came to be generated from
`v0.3.0` while `main` was several merges ahead of it. The workflow closes that.

To test a template change that has merged but is not tagged yet — or to try an
unmerged branch — point Copier at a ref explicitly:

```sh
copier update --vcs-ref=HEAD
```

## Layout

```
copier.yml     Copier config + questions
template/      the ONLY directory rendered into generated projects
```

Everything outside `template/` (this README, `.gitignore`, `copier.yml`)
belongs to the template repo and never leaks into generated projects.

## Design decisions

- **Vendor-neutral.** Agent guidelines live in the generated `AGENTS.md`
  (cross-tool standard); `CLAUDE.md` is a one-line pointer to it.
  Enforcement lives in pre-commit hooks and CI, never in agent-specific
  hooks. The `.claude/` directory in generated projects is an optional
  convenience layer — deleting it leaves a fully functional project.
- **Multi-language, additive.** Language scaffolds are gated by the
  `language` answer; adding a third language means adding a choice and a
  new set of conditional files, nothing else changes.
- **Centrally updatable.** The answers file is mandatory so `copier update`
  works in every generated project.
- **Soft review gate + mechanical merge.** Generated projects gate merges on
  CI (hard) plus an independent read-only LLM review of the PR diff (soft,
  `.github/workflows/review.yml`), both vendor-neutral and surviving deletion
  of `.claude/`. When `auto_merge` is `true` (the default), green PRs merge
  via GitHub native auto-merge — triggered by check status, never by an agent;
  `CODEOWNERS` keeps the gate-defining paths human-owned. Set `auto_merge` to
  `false` (e.g. the iOS app, or anything touching payments/secrets/user data)
  to keep a human merge step while still running the review gate. `code_owner`
  supplies the CODEOWNERS handle.
- **Deliberately unlicensed.** There is no `license` question, and generated
  projects carry no `LICENSE` file and no `license` field in package metadata.
  Every project is assessed on its own terms, by the owner, when licensing
  actually matters — publication, distribution, accepting outside
  contributions. A template-chosen default would silently attach terms to
  every project that never revisits the choice, which is worse than shipping
  nothing. The rule is restated in the generated `AGENTS.md` ("Licensing") and
  in `copier.yml`, so agents stop re-proposing it.
- **No marketplace, no plugin.** Deliberately excluded.

## Adding a language

1. Add the choice to `language` in `copier.yml`.
2. Add scaffold files under `template/` wrapped in
   `{% if language == '<new>' %}…{% endif %}` path conditionals.
3. Extend the conditionals in `.pre-commit-config.yaml.jinja`,
   `ci.yml.jinja`, `.gitignore.jinja`, `README.md.jinja`,
   `AGENTS.md.jinja` (Enforcement + Language-specific sections), and
   `.claude/settings.json.jinja`.
4. Add the language to the matrix in `.github/workflows/template-ci.yml`, and
   check that `description` — the one free-text answer — cannot overflow any
   line length the new language's linter enforces. That bug has shipped twice.
