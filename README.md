# grimsverk-template

A [Copier](https://copier.readthedocs.io/) template for new GrimsVerk projects.
This repository is the template itself — nothing in it ships directly; it
*generates* project repositories.

Supported languages:

- `python` — uv-managed package, src layout, ruff + mypy + pytest
- `swift-ios` — SwiftUI iOS app, XcodeGen-managed project, SwiftFormat + SwiftLint

## Starting a new project

**You never clone this template.** Copier reads it from GitHub and *renders* a
fresh project into a new local directory. That directory is not a git repo and
has no remote — you turn it into one and push it to a brand-new, empty GitHub
repo. Steps 1–4 get you a working local project; step 5 turns on the merge
gates, and its order matters (see below).

### 0. Install Copier (once per machine)

```sh
uv tool install copier   # or: pipx install copier
```

### 1. Generate the project

```sh
copier copy gh:GrimsVerk/grimsverk-template my-project
cd my-project
```

Copier asks six questions:

| Question | Notes |
| --- | --- |
| `project_name` | Human-readable, e.g. `My App` |
| `project_slug` | Defaults to a slugified `project_name`; used for the repo, package, and paths |
| `language` | `python` or `swift-ios` |
| `description` | One line; lands in the README and package metadata |
| `auto_merge` | `true` (default) = green PRs merge themselves. Choose `false` for anything real people download, or that touches payments, secrets, or user data |
| `code_owner` | Required. A real `@handle` or `@org/team` — GitHub silently ignores `CODEOWNERS` entries that don't resolve |

### 2. Bootstrap the toolchain

```sh
uv sync                                            # python
brew install xcodegen swiftformat swiftlint \
  && xcodegen generate                             # swift-ios
```

Then, either language:

```sh
pre-commit install
```

### 3. Make it a git repo

```sh
git init -b main
git add -A
git commit -m "Initial scaffold from grimsverk-template"
```

The generated `AGENTS.md` forbids committing directly to `main`; this initial
scaffold commit is the one exception, made before the gates exist.

### 4. Create an empty GitHub repo and push

Create the repo with **no** README, `.gitignore`, or license — any of those
gives it a commit your local `main` doesn't have, and the first push is
rejected. Either use the web UI and then:

```sh
git remote add origin git@github.com:GrimsVerk/my-project.git
git push -u origin main
```

…or do both at once:

```sh
gh repo create my-project --private --source=. --remote=origin --push
```

### 5. Turn on the gates — in this order

GitHub only lets you mark a status check *required* after it has reported at
least once, and the two gates first report at different times:

| Check | Runs on | First reports after |
| --- | --- | --- |
| `checks` (python) / `test` (swift-ios) | every push | your first push |
| `review` | pull requests only | your first **PR** |

So `review` cannot be marked required straight after step 4 — it won't be in
the dropdown yet. Hence:

**a. Add the review credential first.** *Settings → Secrets and variables →
Actions → New repository secret*, named `CLAUDE_CODE_OAUTH_TOKEN`. Get the
value by running `claude setup-token` locally (needs the Claude Code CLI; it
uses your subscription, not a metered API key). Do this *before* making
`review` required — the job fails closed without a credential, so every PR
would block.

**b. Enable the merge settings.** *Settings → General → Pull Requests*: tick
**Allow auto-merge**, and leave **Allow merge commits** on. Merge commits are
what make the one-line revert in the generated README work, so keep them even
when `auto_merge` is `false`.

**c. Open one throwaway PR** so the `review` check registers:

```sh
git checkout -b setup-gates
git commit --allow-empty -m "Register the review check"
git push -u origin setup-gates
```

Open the PR on GitHub and let both checks run.

**d. Now add branch protection** (*Settings → Branches → Add branch ruleset*,
or classic *Add rule*) on `main`:

- Require a pull request before merging — with **Required approvals: `0`**
- **Require review from Code Owners** ✅
- Require status checks to pass ✅ → select `checks` (or `test` for swift-ios),
  `plan`, **and** `review`

> The approvals number is the setting to get right. Anything ≥ 1 gates *every*
> PR on a human approval, and auto-merge never fires. `0` **plus** *Require
> review from Code Owners* is the intent: ordinary PRs merge on green, while
> PRs touching the gate paths in `CODEOWNERS` still need your approval.

**e. Merge or close the setup-gates PR.**

### 6. Start working

Run `/design` in the project and rant your idea at it — it writes
`docs/DESIGN.md`, which the review gate then checks every PR against. After
that it's branch → PR → green → merge. The generated `README.md` carries the
per-project details, including the `git revert -m 1 <merge-sha>` rollback
recipe that is the real safety net under auto-merge.

### What you get

```
AGENTS.md            agent guidelines (CLAUDE.md is a one-line pointer to it)
docs/DESIGN.md       design doc skeleton + the /design interview kit
.github/             CI, the LLM review gate, CODEOWNERS, auto-merge
.pre-commit-config.yaml
.claude/             optional convenience layer — deletable, nothing breaks
.copier-answers.yml  lets `copier update` pull in template changes later
```

## Design-doc workflow

Every generated project ships a design-doc kit under `docs/`. Open the
project and run the `/design` slash command (or just point the agent at
`docs/idea-to-design-doc.md`), rant your idea at it, answer its questions,
and it writes the finished doc into `docs/DESIGN.md`. `docs/DESIGN.md` is
the skeleton and single source of truth for the doc's shape.

## Orchestration (optional Claude layer)

Generated projects also carry a single-layer orchestration setup under
`.claude/`: run `/orchestrate <task>` and the main session fans the work
out to a few headless worker agents, each in its own git worktree, then
merges the good branches. See `.claude/orchestration.md` in a generated
project for the one-layer rule, sandbox defaults, and safety notes. Like
the rest of `.claude/`, it is deletable without breaking the project.

## Updating generated projects

Every generated project contains a `.copier-answers.yml` file. To pull in
template improvements later, run inside the project:

```sh
copier update
```

Re-run it after changing an answer too — e.g. flipping `auto_merge` on an
existing project.

> `--trust` is not needed for either command: this template renders files only
> and runs no tasks or migrations. If a future version adds one, Copier will
> refuse and tell you to re-run with `--trust`.

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
