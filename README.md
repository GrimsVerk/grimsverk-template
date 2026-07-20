# grimsverk-template

A [Copier](https://copier.readthedocs.io/) template for new GrimsVerk projects.
This repository is the template itself — nothing in it ships directly; it
*generates* project repositories.

## Usage

```sh
uv tool install copier   # or: pipx install copier
copier copy --trust gh:GrimsVerk/grimsverk-template my-project
```

Copier asks a handful of questions (name, slug, language, description,
license) and renders a ready-to-work-in project.

Supported languages:

- `python` — uv-managed package, src layout, ruff + mypy + pytest
- `swift-ios` — SwiftUI iOS app, XcodeGen-managed project, SwiftFormat + SwiftLint

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
copier update --trust
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
- **No marketplace, no plugin.** Deliberately excluded.

## Adding a language

1. Add the choice to `language` in `copier.yml`.
2. Add scaffold files under `template/` wrapped in
   `{% if language == '<new>' %}…{% endif %}` path conditionals.
3. Extend the conditionals in `.pre-commit-config.yaml.jinja`,
   `ci.yml.jinja`, `.gitignore.jinja`, `README.md.jinja`,
   `AGENTS.md.jinja` (Enforcement + Language-specific sections), and
   `.claude/settings.json.jinja`.
