# grimsverk-template: rules for agents

A Copier template. `copier.yml` holds the questions; `template/` is what gets
rendered into a new project (only `*.jinja` files are templated). Nothing at the
root ships.

## Rules

- Keep it as simple as possible. Newer models need less scaffolding, and old
  scaffolding trips them up. Add structure only after the same failure has
  happened twice in real projects.
- Every piece must be removable without breaking the rest.
- Files agents read (the generated `AGENTS.md`, commands, subagents) are written
  for agents and stay short; the generated `AGENTS.md` fits on one screen.
  `README.md` files are for the human: one screen, plain words.
- Never move, delete or edit the tag `summer-2026`.
- Check before pushing: `tests/test-render.sh` (renders both languages, runs the
  Python project's checks, and runs actionlint if installed) and
  `shellcheck template/scripts/*.sh tests/*.sh`.
- Every merge to `main` gets the next `v*` tag automatically (the `tag` job in `template-ci.yml`);
  `copier copy` and `copier update` use the latest tag. Pin actions to a commit SHA
  with the version in a comment.

## Why v2 is small

The summer 2026 version (tag `summer-2026`) was an unattended delivery pipeline:
a long-running driver, an oracle that amended the design, worker spawning,
an LLM review gate, plan and ceremony gates, and about 1 MB of process docs. Its
own postmortem verdict: a day of unattended runs kept no product code. Long
contexts degraded silently, the long-running driver was the part that failed,
and CI was slow because of volume (every push and PR, 9-23 runs per merged PR,
the LLM review the slowest and flakiest check), not because tests were slow.
What survived six session kills was state kept in files. Workers also died
because one lane's `pkill -f` killed another's run and the usage limit ran out
mid fan-out. So v2 keeps file-based memory (`next-steps.md`), fresh sessions per
task, Claude Code's built-in plan mode and subagents, and CI only on `main`.
Don't rebuild the old machinery without a repeated failure that needs it.
