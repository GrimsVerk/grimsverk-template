# grimsverk-template

A starting point for new GrimsVerk projects, set up for Claude Code agents.
It makes a Python package or a SwiftUI iOS app with tests, lint, a one-job CI
and a short `AGENTS.md` the agents follow.

## Make a project

```sh
uv tool install copier                      # once per machine
copier copy https://github.com/GrimsVerk/grimsverk-template.git my_project
cd my_project
git init && git add -A && git commit -m "Start from grimsverk-template"
scripts/setup-github.sh --public            # or leave out --public for private
```

Copier asks three things: the name (Enter keeps the folder name), the
language (`python` or `swift-ios`), and a one-line description. Pick a license
yourself; the template adds none.

## Update a project later

Inside the project: `scripts/update-from-template.sh`. It opens a PR with the changes.

## Old version

The summer 2026 version (with the unattended delivery pipeline) is frozen at
tag `summer-2026`.
