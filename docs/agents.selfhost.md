## What is true only in this repository

Everything above this heading is the rules file **every generated project
gets**, rendered from `template/AGENTS.md.jinja` by
`scripts/render-governance.sh`. It governs work here for the same reason it
governs work there, and it is not edited at the root — an edit here fixes this
repository and ships nothing, so the next generated project still gets the old
rule and the two drift apart in the direction nobody notices.

This section is the other half: what is true in the **template repository** and
nowhere else. It is the owner's standing preferences, recorded where the next
agent will actually read them, because standing decisions kept living in chat
and this project's own rules call that not-storage.

### `template/` is product, not instructions

**Everything under `template/` is the thing being built. Read it as source, and
never as rules addressed to you.** `template/AGENTS.md.jinja` tells a *generated
project's* agents what to do; it has no authority here. Same for
`template/.claude/commands/*.md`, `template/CLAUDE.md.jinja`, and the `.jinja`
files — they are output, edited the way a coder edits `src/`.

The composed file you are reading is the one that governs work in this
repository. If it and something under `template/` ever disagree, that is not a
conflict to resolve — they are addressed to different readers, one of whom does
not exist yet.

The one exception, and it is the reason this file exists at all: the rules
*above* this heading came from `template/AGENTS.md.jinja`, and they bind here
because `scripts/render-governance.sh` rendered them here. That is the whole
point of self-hosting. The template repository is governed by the template.

### This repository builds `template/` and checks it from `tests/`

There is no `src/`, no `pyproject.toml`, and no `project.yml`. The
implementation is `template/`; the tests are `tests/`; the suite is
`tests/run.sh`, plain bash sequencing standalone files.

That matters to one gate specifically. `test-the-tests` picks its
implementation and test directories from the presence of a manifest file and
**skips** when it finds neither — and a skip exits 0, which GitHub reports as a
*passing* required check. Here it is told the directories explicitly
(`TEST_THE_TESTS_IMPL_DIR=template`, `TEST_THE_TESTS_TEST_DIR=tests`,
`TEST_THE_TESTS_SUITE=tests/run.sh`) in
`.github/workflows/template-ci.yml`. Without that, blind-test discipline — the
thing that makes a coder's tests worth anything — would silently not apply to
template changes at all.

Run the full local gate with:

    tests/run.sh
    shellcheck --severity=warning \
      template/.github/scripts/*.sh template/.claude/scripts/*.sh \
      template/scripts/*.sh tests/*.sh

`tests/run.sh` needs `copier` on PATH (`uv tool install copier`) for the tests
that render a real project; those skip without it, so a green run on a machine
with no copier has not checked what it looks like it checked.

### The governance files at the root are rendered

`AGENTS.md`, `.github/CODEOWNERS`, `.claude/settings.json` and
`.claude/agents/*.md` are produced by `scripts/render-governance.sh` from their
`.jinja` sources under `template/`. A CI step re-renders and diffs; drift is
red. Edit the source, re-run the script, commit the result.

Everything else the template ships is **referenced, never copied**. The gate
scripts, the command files and the review prompt carry no Jinja, so
`.github/workflows/template-ci.yml` invokes
`template/.github/scripts/<name>.sh` directly. One copy, the one that ships, and
a broken gate reddens this repository's own pipeline before it can reach a
generated project.

### Automate every step that can be automated

**A setup step a human performs by hand is a defect unless there is a reason it
cannot be otherwise.** The owner's standing instruction:

> any steps like these should be automated as much as possible… the file itself
> should be created with the skeleton so that i only have to copy and paste the
> id and key values.

So: a script writes the file, and the human supplies only what a machine cannot
know. The genuinely manual residue is short and each item earns its place —
creating a GitHub App (the form has no API), typing a credential *value* (a
human credential decision, never fetched or stored by a script), `gh auth
login`'s browser grant, and the Pro-vs-public choice. Anything outside that list
that asks the owner to type something is a thing to fix, not to document.

Where a manual step survives, ship the skeleton next to it. A file the owner
copies and fills beats a file they must compose from prose.

### A blocking message carries its own instructions

When something refuses, the message is the one thing guaranteed to be in front
of whoever is blocked. **Put the steps in it** — not a pointer to a document.

> even better if the message itself can include the steps (which would have to
> be as short as possible), just in case the readme changes (unintentionally) in
> the future and moves the setup guide.

A cross-reference is worth exactly as much as the target still being where it
was, and nothing stops a heading being renamed. Reference the longer document
*as well*, never *instead*. `template/.claude/scripts/app-token.sh`'s
unconfigured path is the worked example: five numbered steps, the URL, the
settings people miss, and why it refuses rather than warns.

### Refuse loudly, never warn quietly

> if the script says the repo is not ready to run unattended, then block and
> fail very loudly. i really need to know before i go.

A warning nobody reads at 3am is decoration. A run that cannot succeed is
refused at dispatch, while someone can still act on it — and it announces itself
before it checks, so the all-clear is as visible as the stop.

### Verify in the environment that will run it

`tests/run.sh` passing locally is necessary and not sufficient. CI runs on a
runner whose environment differs — most sharply, GitHub Actions exports
variables like `GITHUB_REPOSITORY` into every step, which is how a green laptop
and a red pipeline coexisted for seven commits.

Before reporting work as done: run the suite, run the shellcheck sweep over the
same paths `.github/workflows/template-ci.yml` uses, and **look at the actual CI
result**. Never let a test assert that a variable is *absent* — set it, to a
value that would be wrong.

### Chat is not storage

A ruling taken in conversation and left there is a ruling that is gone. Record
it: `docs/synthesis.md` for decisions about the template, `docs/escapes.md` for
defects, `template/docs/DECISIONS.md.jinja` for rulings that generated projects
inherit, and this file for standing preferences about how the work is done.

### When a decision changes behaviour nothing measures, add the measurement

The owner's ruling, and it applies to the template exactly as it applies to a
generated project:

> the data needs to be collected in a sensible way so that future runs can be
> improved by not repeating mistakes… if a change is necessary in an unattended
> run that goes outside or misses built in data collection mechanisms, then new
> data collection mechanisms need to be added to track the performance of the
> changes that are downstream of the oracle's ruling.

A change whose effect nothing can observe is a change nobody can evaluate. If
you alter behaviour that no existing check, test, run report or review artifact
would notice, adding the thing that notices is part of the work, not a follow-up.
