#!/usr/bin/env bash
#
# Render tests — does the template actually produce a valid project?
#
# The bug that motivated these: a project name of "My App 2.0" produced the
# Python package "my_app_2.0", which is not an importable identifier. The
# generated project was broken at render time and nothing noticed, because
# nothing had ever rendered the template in CI.
#
# The name is no longer asked for at all — it is the destination directory — so
# these tests exercise it by choosing the OUTPUT DIRECTORY NAME rather than by
# passing --data.
#
# Requires: copier on PATH (uv tool install copier).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TEMPLATE="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== render ==="

command -v copier >/dev/null || { echo "  SKIP  copier not on PATH"; exit 0; }

render() { # render <outdir> <language> [extra --data args...]
  local out="$1" lang="$2"; shift 2
  # --vcs-ref=HEAD is load-bearing. Pointed at a git repository, copier renders
  # the latest TAG by default — so without this every test here validated the
  # last release instead of the working tree, and a change under test was
  # invisible to its own tests. HEAD also pulls in uncommitted changes, which is
  # exactly what a pre-commit test run needs to see.
  copier copy --defaults --trust --quiet --vcs-ref=HEAD \
    --data language="$lang" \
    --data code_owner="@grimsverk" \
    "$@" "$TEMPLATE" "$out" 2>&1
}

for lang in python swift-ios; do
  out="$WORK/$lang"
  msg="$(render "$out" "$lang")"
  if [[ ! -d "$out" ]]; then no "$lang renders" "$msg"; continue; fi
  ok "$lang renders"

  # No unrendered Jinja anywhere in the output. A stray {{ }} means a file was
  # copied verbatim that should have been a .jinja, or a conditional path did
  # not resolve — both ship broken projects that look fine in a diff.
  #
  # GitHub Actions expressions are spelled ${{ ... }} and are NOT Jinja: the
  # workflows carrying them (review.yml, auto-merge.yml) are deliberately not
  # .jinja files so those expressions reach GitHub intact. Strip them before
  # looking, or every render "fails" for doing exactly the right thing.
  stray=""
  while IFS= read -r f; do
    if perl -pe 's/\$\{\{.*?\}\}//g' "$f" 2>/dev/null | grep -qE '\{\{|\{%'; then
      stray="$stray ${f#"$out"/}"
    fi
  done < <(grep -rlE '\{\{|\{%' "$out" 2>/dev/null || true)
  if [[ -z "$stray" ]]; then ok "$lang has no unrendered Jinja"
  else no "$lang has no unrendered Jinja" "$stray"; fi

  # Every required check must exist as a job. This list is what the READMEs tell
  # you to mark required in branch protection, and a name that drifts out of the
  # workflow leaves a required check that never reports — every PR waits forever
  # on something that cannot arrive.
  ci="$out/.github/workflows/ci.yml"
  for job in plan template-sync secrets test-the-tests acceptance-criteria; do
    if grep -qE "^  ${job}:" "$ci" 2>/dev/null; then ok "$lang ci.yml defines '$job'"
    else no "$lang ci.yml defines '$job'"; fi
  done

  # Every plan in the tree must be parsed, not only the one this pull request
  # resolves to. A plan is written on one pull request and resolved by a later
  # one, so without this step a malformed plan stays invisible until some
  # unrelated branch trips over it — and then the error names a document that
  # branch never touched. Asserted on the wiring, because the script existing
  # and the job calling it are two different things.
  if grep -q 'plan-lint.sh' "$ci" 2>/dev/null; then ok "$lang plan job lints every plan"
  else no "$lang plan job lints every plan"; fi

  # Escape citations must resolve at the base commit. The script existing and
  # the job calling it are two different things, so the wiring is asserted too.
  if grep -q 'escape-refs.sh' "$ci" 2>/dev/null; then ok "$lang plan job resolves escape citations"
  else no "$lang plan job resolves escape citations"; fi

  # The oracle's ledger is the one design document an agent may write while
  # nobody is awake. It is deliberately NOT behind CODEOWNERS — ownership there
  # would stop overnight work, which is the point of having it — so this check
  # is the only thing standing in for the owner. A wiring slip here does not
  # fail loudly: it leaves the document writable and unchecked.
  if grep -q 'oracle-decisions.sh' "$ci" 2>/dev/null; then ok "$lang plan job checks oracle decisions"
  else no "$lang plan job checks oracle decisions"; fi

  # An unfilled docs/VISION.md goes red nowhere on its own — it fails overnight,
  # in the role that exists to keep work moving. The script existing and the job
  # calling it are two different things.
  if grep -q 'vision-complete.sh' "$ci" 2>/dev/null; then ok "$lang plan job checks the vision is finished"
  else no "$lang plan job checks the vision is finished"; fi

  # The design and the vision are landed by their owner. CODEOWNERS gives their
  # approval on a diff someone else opened; this gives their authorship.
  if grep -q 'owner-authored.sh' "$ci" 2>/dev/null; then ok "$lang plan job checks who opened an owned-document PR"
  else no "$lang plan job checks who opened an owned-document PR"; fi

  # The secrets job must be able to read pull requests. gitleaks-action lists a
  # PR's commits through the API, and the default token cannot — it answers 403
  # and the job dies before scanning anything, which is the worst shape a check
  # can fail in: present, red, and having checked nothing. Asserted here because
  # the symptom looks like a broken action rather than a missing permission.
  if python3 - "$ci" <<'PYCHK'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
p = d["jobs"]["secrets"].get("permissions") or {}
sys.exit(0 if p.get("pull-requests") == "read" and p.get("contents") == "read" else 1)
PYCHK
  then ok "$lang secrets job can read pull requests"
  else no "$lang secrets job can read pull requests" \
    "needs permissions: {contents: read, pull-requests: read}"; fi

  # The token rewrites in template-sync must APPEND. They all set one config
  # key, `url.<auth>.insteadOf`, and a plain `git config` replaces a
  # single-valued key rather than adding to it — so every write after the first
  # deletes its predecessor, leaving one rewrite that matches nothing. The step
  # still exits 0; the failure surfaces later as copier's clone asking for a
  # username, which reads as a missing or misscoped token and sends you
  # auditing secrets instead of config. Counted rather than matched by name:
  # exactly one plain write may exist, and every additional one must use --add.
  plain="$(grep -cE '^[[:space:]]*git config --global[[:space:]]+url\."\$AUTH"\.insteadOf' "$ci" || true)"
  added="$(grep -cE '^[[:space:]]*git config --global --add[[:space:]]+url\."\$AUTH"\.insteadOf' "$ci" || true)"
  if [[ "$plain" -eq 1 && "$added" -ge 1 ]]; then
    ok "$lang template-sync appends its insteadOf rewrites"
  else
    no "$lang template-sync appends its insteadOf rewrites" \
      "found $plain plain and $added --add; expected 1 plain (the first) and the rest --add"
  fi

  # Every workflow must parse as YAML.
  bad=""
  for wf in "$out"/.github/workflows/*.yml; do
    [[ -e "$wf" ]] || continue
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$wf" 2>/dev/null \
      || bad="$bad $(basename "$wf")"
  done
  if [[ -z "$bad" ]]; then ok "$lang workflows parse as YAML"
  else no "$lang workflows parse as YAML" "$bad"; fi

  # CODEOWNERS must carry the resolved handle, and cover the gates' inputs.
  co="$out/.github/CODEOWNERS"
  if grep -q '@grimsverk' "$co" 2>/dev/null; then ok "$lang CODEOWNERS resolves the handle"
  else no "$lang CODEOWNERS resolves the handle"; fi
  for path in /AGENTS.md /docs/DESIGN.md /docs/plans/ /.github/ /docs/VISION.md; do
    if grep -qE "^${path}[[:space:]]+@" "$co" 2>/dev/null; then ok "$lang CODEOWNERS covers $path"
    else no "$lang CODEOWNERS covers $path"; fi
  done

  # And the paths that must NOT be owned. Ownership on any of these would stop
  # overnight work, which is the whole point of the arrangement: they are
  # constrained by a required check, which needs nobody awake, rather than by a
  # code owner, who does. /docs/plans/ above would otherwise swallow the
  # steward's directory, since a directory rule covers everything beneath it —
  # the unowned line that releases it is easy to drop and fails silently.
  for path in /docs/plans/oracle/ /docs/DESIGN.oracle.md /docs/oracle/; do
    if grep -qE "^${path}[[:space:]]+@" "$co" 2>/dev/null; then
      no "$lang CODEOWNERS leaves $path unowned" "an owner would stop unattended work"
    else ok "$lang CODEOWNERS leaves $path unowned"; fi
  done
  if grep -qE '^/docs/plans/oracle/[[:space:]]*$' "$co" 2>/dev/null; then
    ok "$lang CODEOWNERS explicitly releases /docs/plans/oracle/"
  else
    no "$lang CODEOWNERS explicitly releases /docs/plans/oracle/" \
      "without it the /docs/plans/ rule owns it by inheritance"
  fi

  # The glossary must ship, with both lists present — the "learned" section is
  # the half that stops the agent over-explaining, so a file missing it is
  # worse than no file.
  g="$out/GLOSSARY.md"
  if [[ -f "$g" ]]; then
    ok "$lang ships GLOSSARY.md"
    for heading in "## How to talk to me" "## Words I'm learning" "## Words I've learned"; do
      if grep -qF "$heading" "$g"; then ok "$lang glossary has '$heading'"
      else no "$lang glossary has '$heading'"; fi
    done
  else
    no "$lang ships GLOSSARY.md"
  fi

  # Both new documents must ship, and the vision file must be the tiebreaker
  # rather than a second requirements list — the oracle cites it by sentence.
  for f in docs/VISION.md docs/DESIGN.oracle.md; do
    if [[ -f "$out/$f" ]]; then ok "$lang ships $f"
    else no "$lang ships $f"; fi
  done

  # The evidence sources and the oracle's directories must exist on day one.
  # AGENTS.md, oracle.md, steward.md and deliver.md all point at these; before
  # they shipped, a fresh project started with half the oracle's evidence space
  # nonexistent and every pointer dangling.
  for f in docs/BACKLOG.md docs/DECISIONS.md docs/oracle/.gitkeep \
           docs/plans/oracle/.gitkeep; do
    if [[ -f "$out/$f" ]]; then ok "$lang ships $f"
    else no "$lang ships $f"; fi
  done

  # The shipped backlog must contain no literal BL id. oracle-decisions.sh
  # greps the WHOLE file for the id pattern with no column anchoring, so an
  # example id in the skeleton is phantom evidence in every project on day one
  # — the ESC-19 failure shape, one file over. Talk about ids as BL-<n> only.
  if grep -qE 'BL-[0-9]+' "$out/docs/BACKLOG.md" 2>/dev/null; then
    no "$lang backlog skeleton has no phantom evidence id" \
      "$(grep -nE 'BL-[0-9]+' "$out/docs/BACKLOG.md" | head -3)"
  else
    ok "$lang backlog skeleton has no phantom evidence id"
  fi

  # The steward's base branch must be real. orchestrate.md used to name
  # docs/oracle-plans, a branch nothing creates — a worker based on it dies at
  # checkout, deep inside a headless run.
  if grep -q 'docs/oracle-plans' "$out/.claude/commands/orchestrate.md" 2>/dev/null; then
    no "$lang orchestrate.md names no phantom base branch"
  else
    ok "$lang orchestrate.md names no phantom base branch"
  fi

  # The shipped oracle ledger must pass the gate it ships with, on day one, in a
  # project that has no decisions and no evidence. A skeleton whose own example
  # rows parsed as real decisions would fail every generated project instantly.
  ( cd "$out" && git init -q -b main . >/dev/null 2>&1 \
    && git config user.email t@e.invalid && git config user.name T \
    && git add -A >/dev/null 2>&1 && git commit -qm scaffold >/dev/null 2>&1 \
    && BASE_SHA="$(git rev-parse HEAD)" .github/scripts/oracle-decisions.sh >/dev/null 2>&1 )
  if [[ $? -eq 0 ]]; then ok "$lang shipped oracle skeleton passes its own gate"
  else no "$lang shipped oracle skeleton passes its own gate" \
    "$( cd "$out" && BASE_SHA="$(git rev-parse HEAD)" .github/scripts/oracle-decisions.sh 2>&1 | head -5 )"; fi

  # The PROJECT glossary must NOT ship. It is created on first use, which is
  # precisely what keeps `copier update` from ever conflicting with it.
  if [[ -e "$out/GLOSSARY.project.md" ]]; then
    no "$lang does not ship GLOSSARY.project.md" "it was rendered, so copier update will fight over it"
  else
    ok "$lang does not ship GLOSSARY.project.md"
  fi

  # ------------------- rules that exist because something actually went wrong
  #
  # These are PRESENCE checks, and worth being clear about what that buys. They
  # cannot tell whether an agent followed a rule — no check can read a prompt
  # that was never written down. What they catch is the rule being dropped or
  # reworded out of existence by a later template edit, silently, after the
  # failure that produced it has been forgotten. Each line below cost a real
  # failure downstream; the phrase asserted on is the load-bearing half.
  ag="$out/AGENTS.md"
  orch="$out/.claude/commands/orchestrate.md"
  del="$out/.claude/commands/deliver.md"

  # Whitespace-collapsed, because these documents are hard-wrapped prose: a
  # phrase spans a line break wherever the paragraph happened to fill up, and a
  # check that broke every time someone reflowed a paragraph would be switched
  # off within a month.
  says() { tr -s '[:space:]' ' ' < "$1" | grep -qF "$2"; }

  # A recorded ratchet check must be demonstrated or marked unverified: an
  # untested proposal in that column reads with the authority of a verified one.
  if says "$ag" "red against the defect, green against the fix"
  then ok "$lang AGENTS.md requires a demonstrated ratchet check"
  else no "$lang AGENTS.md requires a demonstrated ratchet check"; fi

  # Land the ratchet entry first, then the document citing it. The review gate
  # reads escapes.md at the BASE commit, so a citation to an unmerged entry is
  # false at the only moment it is checked — it blocked the same PR twice.
  if says "$ag" "the ratchet entry first"
  then ok "$lang AGENTS.md states the cross-reference ordering"
  else no "$lang AGENTS.md states the cross-reference ordering"; fi

  # And the ruling that keeps that ordering from being renegotiated per PR.
  if says "$ag" "not relitigated"
  then ok "$lang AGENTS.md records the ruling on combined PRs"
  else no "$lang AGENTS.md records the ruling on combined PRs"; fi

  # Escapes entries carry ids, citations point backward only, and the entry
  # authorizes nothing — the three clauses that make the entry-first ordering
  # cheap without giving a self-serving entry anything to buy.
  if says "$ag" "Citations are by id, and they point backward only"
  then ok "$lang AGENTS.md states the id citation rule"
  else no "$lang AGENTS.md states the id citation rule"; fi
  if says "$ag" "Entries are records, never authorization"
  then ok "$lang AGENTS.md states that entries never authorize"
  else no "$lang AGENTS.md states that entries never authorize"; fi
  esc="$out/docs/escapes.md"
  if grep -q '^| Id |' "$esc" 2>/dev/null
  then ok "$lang escapes.md carries the id column"
  else no "$lang escapes.md carries the id column"; fi
  if says "$esc" "unverified — pending"
  then ok "$lang escapes.md documents the stub lifecycle"
  else no "$lang escapes.md documents the stub lifecycle"; fi

  # The second design document, and the three clauses that make an unattended
  # writer safe: evidence must already have landed, decisions are append-only,
  # and each names the vision statement it leaned on — which is what lets the
  # owner steer by editing that statement instead of arguing with decisions one
  # at a time. Dropping any one of them leaves a document an agent may write
  # freely, which is the failure worth catching by presence.
  ora="$out/docs/DESIGN.oracle.md"
  if says "$ag" "The design is two documents"
  then ok "$lang AGENTS.md states there are two design documents"
  else no "$lang AGENTS.md states there are two design documents"; fi
  if says "$ora" "cites evidence that exists at the **base commit**"
  then ok "$lang oracle ledger requires landed evidence"
  else no "$lang oracle ledger requires landed evidence"; fi
  if says "$ora" "Append-only, and superseded rather than revised"
  then ok "$lang oracle ledger states the append-only rule"
  else no "$lang oracle ledger states the append-only rule"; fi
  if says "$ora" "Vision statement relied on"
  then ok "$lang oracle ledger requires the vision citation"
  else no "$lang oracle ledger requires the vision citation"; fi
  if says "$ora" "it never marks a decision pending"
  then ok "$lang oracle ledger states that nothing is left pending"
  else no "$lang oracle ledger states that nothing is left pending"; fi

  # The mid-run authority chain, and the hybrid uncertainty rule that removed
  # the 1am owner stop. Each phrase below is the load-bearing half of a ruling
  # in docs/DECISIONS.md; a template edit that rewords one out of existence
  # silently reinstates a stop (or removes a record) an unattended run depends
  # on. "unsure means HIGH" is the tiebreak that keeps the fast path from
  # eating the safe one; the no-vision class is what lets the oracle rule on
  # questions the vision never answered instead of paraphrasing it.
  if says "$ag" "unsure means HIGH"
  then ok "$lang AGENTS.md carries the risk tiebreak"
  else no "$lang AGENTS.md carries the risk tiebreak"; fi
  if says "$ag" "One pipeline pull request in flight at a time"
  then ok "$lang AGENTS.md states the one-open-PR rule"
  else no "$lang AGENTS.md states the one-open-PR rule"; fi
  if says "$out/.claude/commands/plan.md" "plan pending oracle rulings"
  then ok "$lang plan.md routes unattended uncertainties to the oracle"
  else no "$lang plan.md routes unattended uncertainties to the oracle"; fi
  if says "$ora" "(no vision statement decided this)"
  then ok "$lang oracle ledger documents the no-vision class"
  else no "$lang oracle ledger documents the no-vision class"; fi

  # The delivery driver. deliver.md carried an unresolved OPEN QUESTION block
  # that told every unattended run to stop at each pull request; the ruling
  # replaced it, and its reappearance would silently reinstate the stop.
  if grep -q "OPEN QUESTION" "$del" 2>/dev/null
  then no "$lang deliver.md no longer carries the open question" \
    "the waiting strategy is ruled in docs/DECISIONS.md"
  else ok "$lang deliver.md no longer carries the open question"; fi
  for f in .claude/scripts/deliver-loop.sh .claude/scripts/deliver-phase.sh \
           .claude/scripts/budget-probe.sh .claude/commands/deliver-loop.md; do
    if [[ -f "$out/$f" ]]; then ok "$lang ships $f"
    else no "$lang ships $f"; fi
  done
  for f in deliver-loop deliver-phase budget-probe; do
    if [[ -x "$out/.claude/scripts/$f.sh" ]]; then ok "$lang $f.sh is executable"
    else no "$lang $f.sh is executable"; fi
  done
  if grep -q '^\.claude/deliver-loop/' "$out/.gitignore"
  then ok "$lang gitignores the driver's run state"
  else no "$lang gitignores the driver's run state"; fi
  # ESC-16: the orchestrator looks at its own diff the way the gate will,
  # BEFORE the pull request exists — three of four recent escapes were found
  # by use because nothing looked earlier.
  if says "$orch" "review your own diff the way the gate will"
  then ok "$lang orchestrate.md requires the pre-PR self-review"
  else no "$lang orchestrate.md requires the pre-PR self-review"; fi
  if says "$del" "wait until no check is still pending, never until the pull request is no longer open"
  then ok "$lang deliver.md keeps the exit condition"
  else no "$lang deliver.md keeps the exit condition"; fi
  # WRITING versus LANDING. Two earlier wordings failed in opposite directions:
  # "no agent may edit it" made the file unwritable, since /design fills it in
  # by interviewing the owner; the transcription carve-out that replaced it let
  # an agent land the design, which leaves docs/DESIGN.oracle.md with no reason
  # to exist. The line that survives is the branch/pull-request boundary, and it
  # has to read the same way in all three documents.
  if says "$out/docs/VISION.md" "An agent may WRITE this file. Only the owner LANDS it"
  then ok "$lang VISION.md separates writing from landing"
  else no "$lang VISION.md separates writing from landing"; fi
  if says "$ag" "WRITTEN by agents and LANDED by the owner"
  then ok "$lang AGENTS.md separates writing from landing"
  else no "$lang AGENTS.md separates writing from landing"; fi
  if says "$ag" "has no reason to exist"
  then ok "$lang AGENTS.md gives the reason, not just the rule"
  else no "$lang AGENTS.md gives the reason, not just the rule"; fi

  # ...and the reviewer must NOT have the carve-out any more, or it would wave
  # through the very pull request the new check exists to stop.
  if says "$out/.github/review-prompt.md" "must not be blocked for being agent-opened"
  then no "$lang review prompt no longer carves out the vision" \
    "the v0.4.17 carve-out lets an agent land the design"
  else ok "$lang review prompt no longer carves out the vision"; fi
  if says "$out/.github/review-prompt.md" "have no carve-out at all"
  then ok "$lang review prompt defers to the owner-authored check"
  else no "$lang review prompt defers to the owner-authored check"; fi

  # /design must stop at a pushed branch. An agent that opens the pull request
  # wastes a run and lands nothing.
  if says "$out/.claude/commands/design.md" "Do not open the pull request"
  then ok "$lang design command stops at a pushed branch"
  else no "$lang design command stops at a pushed branch"; fi

  # /design must ELICIT the vision rather than infer it. Every unattended design
  # decision has to quote a statement from docs/VISION.md, so a confident-looking
  # file assembled from guesses is worse than an empty one — it gets cited.
  idea="$out/docs/idea-to-design-doc.md"
  dsg="$out/.claude/commands/design.md"
  if says "$idea" "Ask me for it; do not infer it"
  then ok "$lang design kit asks for the vision rather than inferring it"
  else no "$lang design kit asks for the vision rather than inferring it"; fi

  # ...but does not force it BEFORE the design. Writing the vision after the
  # design is often the better order — one written first is a guess about your
  # own priorities. The deadline is the first plan, not the design doc.
  if says "$idea" "offer both, take my answer, and come back to it if I deferred"
  then ok "$lang design kit offers the vision either side of the design"
  else no "$lang design kit offers the vision either side of the design"; fi
  if says "$idea" "must be finished"
  then ok "$lang design kit puts the deadline at the plan"
  else no "$lang design kit puts the deadline at the plan"; fi
  if says "$idea" "What would you trade away?"
  then ok "$lang design kit asks what the owner would trade away"
  else no "$lang design kit asks what the owner would trade away"; fi
  if says "$dsg" "Two documents, not one"
  then ok "$lang design command writes the vision too"
  else no "$lang design command writes the vision too"; fi

  # The owner answers as they read, so an early instruction may be overtaken by
  # a later paragraph of the same message. Acting on the first paragraph is how
  # an agent builds something the fourth paragraph cancelled.
  if says "$ag" "The owner replies as they read, not after"
  then ok "$lang AGENTS.md states how the owner writes"
  else no "$lang AGENTS.md states how the owner writes"; fi
  if says "$ag" "The last word on a point wins"
  then ok "$lang AGENTS.md states that the last word wins"
  else no "$lang AGENTS.md states that the last word wins"; fi

  # A plan opens with a summary the owner can approve from ALONE. Without the
  # promotion rule the summary decays into an abstract, and then reading the
  # whole plan is once again the only safe way to approve one.
  if says "$ag" "decision-complete summary"
  then ok "$lang AGENTS.md requires a decision-complete plan summary"
  else no "$lang AGENTS.md requires a decision-complete plan summary"; fi
  if says "$ag" "it may never introduce one"
  then ok "$lang AGENTS.md states the promotion rule"
  else no "$lang AGENTS.md states the promotion rule"; fi

  # The project glossary is a staging buffer that gets wiped, not a permanent
  # home for vocabulary. An agent that believes otherwise treats the wipe as
  # data loss and works around it.
  if says "$ag" "staging buffer, not a record"
  then ok "$lang AGENTS.md states the glossary lifecycle"
  else no "$lang AGENTS.md states the glossary lifecycle"; fi

  # The two unattended roles, and the clauses that keep them narrow. These are
  # presence checks: they cannot make an agent obey a rule, but they catch the
  # rule being reworded out of existence by a later template edit, long after
  # the reasoning behind it has been forgotten.
  orc_doc="$out/.claude/commands/oracle.md"
  stw="$out/.claude/commands/steward.md"
  for f in "$orc_doc" "$stw"; do
    if [[ -f "$f" ]]; then ok "$lang ships $(basename "$f")"
    else no "$lang ships $(basename "$f")"; fi
  done
  if says "$orc_doc" "You spawn nothing"
  then ok "$lang oracle.md states that the oracle does not spawn"
  else no "$lang oracle.md states that the oracle does not spawn"; fi
  if says "$orc_doc" "Never mark a decision pending"
  then ok "$lang oracle.md states that nothing is left pending"
  else no "$lang oracle.md states that nothing is left pending"; fi
  if says "$orc_doc" "One clarification round"
  then ok "$lang oracle.md bounds the clarification loop"
  else no "$lang oracle.md bounds the clarification loop"; fi
  if says "$stw" "You decide nothing"
  then ok "$lang steward.md states that the steward decides nothing"
  else no "$lang steward.md states that the steward decides nothing"; fi

  # The orchestrator spawns the stewards, not the oracle. An agent that both
  # ruled on the design and hired the labour to act on its own ruling is the one
  # arrangement this repository refuses everywhere else.
  if says "$orch" "You spawn the stewards; the oracle does not"
  then ok "$lang orchestrate.md keeps deciding and commissioning apart"
  else no "$lang orchestrate.md keeps deciding and commissioning apart"; fi

  # Both blind workers get ONE contract, quoted verbatim. Asymmetric briefs made
  # the two build to different contracts and disagree at assembly about a
  # behaviour the plan never stated.
  if says "$orch" "verbatim into both prompts"
  then ok "$lang orchestrate.md requires a shared contract block"
  else no "$lang orchestrate.md requires a shared contract block"; fi

  # Wait until nothing is pending — never until the PR is no longer open. A
  # failing PR never leaves the open state, so that condition makes red
  # indistinguishable from still-running, and from success where nobody looks.
  for f in "$orch" "$del"; do
    if says "$f" "no check is still pending"
    then ok "$lang $(basename "$f") states the wait condition"
    else no "$lang $(basename "$f") states the wait condition"; fi
  done

  # Auto-merge must ask for the branch deletion explicitly. The repository
  # setting is what the merge UI pre-fills for a human; an auto-merge armed
  # through the API records its own delete-branch choice, and that is what
  # GitHub honours. Without the flag every auto-merged branch survives its own
  # pull request while human merges clean up correctly — which reads exactly
  # like the repository setting being broken, and is not.
  am="$out/.github/workflows/auto-merge.yml"
  if [[ -f "$am" ]]; then
    # A dedicated job keyed on closed+merged, NOT a flag. `gh pr merge --auto
    # --delete-branch` is a no-op: gh deletes the branch itself after merging,
    # and with --auto it never merges, so the step never runs. It exits 0 and
    # says nothing, which is how that fix survived a whole release looking
    # correct. Asserted on the job, and on the flag being GONE, so the no-op
    # cannot creep back in as reassurance.
    if python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
j = d['jobs'].get('delete-merged-branch') or {}
cond = j.get('if', '')
sys.exit(0 if \"merged == true\" in cond and 'closed' in cond else 1)
" "$am"
    then ok "$lang auto-merge deletes a merged head branch"
    else no "$lang auto-merge deletes a merged head branch" \
      "needs a delete-merged-branch job keyed on closed AND merged"; fi

    if python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
sys.exit(0 if 'closed' in d[True]['pull_request']['types'] else 1)
" "$am"
    then ok "$lang auto-merge listens for the close event"
    else no "$lang auto-merge listens for the close event" \
      "without it the delete job can never fire"; fi

    # The close-event job is not enough on its own: GitHub creates no workflow
    # run at all for an event caused by GITHUB_TOKEN, so an auto-merge armed
    # with it dispatches nothing on close. Two answers have to be present — the
    # optional PAT, which makes the event fire, and the scheduled sweep, which
    # works whether or not anyone configured one.
    # Matched on the GH_TOKEN assignment, not anywhere in the file: the comment
    # explaining WHY the token exists names it, and a bare grep would read that
    # explanation as the thing it describes. That exact mistake has now been
    # made twice in this file's history, so it is worth the extra precision.
    if grep -E '^[[:space:]]*GH_TOKEN:' "$am" | grep -q 'AUTO_MERGE_TOKEN'
    then ok "$lang auto-merge prefers a real token when one exists"
    else no "$lang auto-merge prefers a real token when one exists" \
      "GITHUB_TOKEN-driven merges dispatch no events"; fi

    # The App outranks the PAT outranks the built-in token, on the SAME
    # GH_TOKEN line — the App has its own rate budget and its merges are not
    # authored as the owner (docs/DECISIONS.md). Order matters: a ladder that
    # reaches the PAT first quietly keeps the shared-budget problem.
    if grep -E '^[[:space:]]*GH_TOKEN:' "$am" \
       | grep -qE 'app-token.*AUTO_MERGE_TOKEN.*GITHUB_TOKEN'
    then ok "$lang auto-merge tries App, then PAT, then built-in token"
    else no "$lang auto-merge tries App, then PAT, then built-in token"; fi
    if grep -q 'create-github-app-token' "$am"
    then ok "$lang auto-merge can mint an App token"
    else no "$lang auto-merge can mint an App token"; fi

    # Arming retries with backoff and, on giving up, says WHEN the limit
    # resets. The GraphQL limit is hourly and per-identity; an unattended run
    # opening a PR every twenty minutes meets it repeatedly, so a single
    # failed arm is not an edge case and must not be a red check.
    if grep -q 'retrying in' "$am" && grep -q 'rate_limit' "$am"
    then ok "$lang arming retries and reports the rate-limit reset"
    else no "$lang arming retries and reports the rate-limit reset"; fi

    if python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
j = d['jobs'].get('sweep-merged-branches') or {}
sys.exit(0 if 'schedule' in d[True] and 'schedule' in j.get('if', '') else 1)
" "$am"
    then ok "$lang auto-merge sweeps merged branches on a schedule"
    else no "$lang auto-merge sweeps merged branches on a schedule" \
      "the only cleanup path that survives a GITHUB_TOKEN merge"; fi

    # ...and the sweep must not fire the arming job, or every scheduled run
    # re-arms auto-merge on nothing.
    if python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
sys.exit(0 if \"event_name == 'pull_request'\" in d['jobs']['arm-auto-merge'].get('if', '') else 1)
" "$am"
    then ok "$lang arming is scoped to pull request events"
    else no "$lang arming is scoped to pull request events"; fi

    # Matched on the RUN line, not anywhere in the file: the comment explaining
    # why the flag is useless names it, and a bare grep would read that
    # explanation as the mistake it warns about.
    if grep -E '^[[:space:]]*run:.*gh pr merge' "$am" | grep -q -- '--delete-branch'
    then no "$lang auto-merge does not rely on the no-op flag" \
      "gh pr merge --auto --delete-branch never deletes anything"
    else ok "$lang auto-merge does not rely on the no-op flag"; fi

    # The arming job must not fire on close, or every merged pull request
    # re-arms auto-merge on itself.
    if python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
sys.exit(0 if \"!= 'closed'\" in d['jobs']['arm-auto-merge'].get('if', '') else 1)
" "$am"
    then ok "$lang arming skips the close event"
    else no "$lang arming skips the close event"; fi
  fi

  # Every shipped script must be executable — CI invokes them by path.
  nonexec=""
  while IFS= read -r s; do
    [[ -x "$s" ]] || nonexec="$nonexec ${s#"$out"/}"
  done < <(find "$out" -name '*.sh' -type f)
  if [[ -z "$nonexec" ]]; then ok "$lang scripts are executable"
  else no "$lang scripts are executable" "$nonexec"; fi

  # ------------------------------------------------- the intent boundary
  # docs/DESIGN.md and docs/VISION.md are the owner's. Three separate things
  # have to agree for that to be true, and each was wrong at some point in this
  # template's history (ESC-24, ESC-25, and the review that found .claude/
  # outside every gate-path list). These assertions pin all three together, so
  # a future edit cannot quietly restore one of the old wordings.
  #
  # AND THE RULES ARE SPELLED `Edit(...)`. Claude Code matches file-permission
  # rules on Edit(...) only — an Edit rule covers every file-editing tool
  # including Write, and a `Write(path)` rule matches NOTHING. This file shipped
  # with both spellings and this fixture asserted both were present, so it
  # passed while half the deny list was inert; the CLI said so on startup, in a
  # warning nobody read because the list looked complete. Asserting the Write
  # form is ABSENT is the half that has teeth: it is what fails if somebody
  # "restores" it.
  st="$out/.claude/settings.json"
  if [[ -f "$st" ]] && python3 -c "
import json,sys
d = json.load(open(sys.argv[1]))
deny = d['permissions']['deny']
need = ['Edit(docs/DESIGN.md)','Edit(./docs/DESIGN.md)',
        'Edit(docs/VISION.md)','Edit(./docs/VISION.md)']
sys.exit(0 if all(x in deny for x in need) else 1)
" "$st"
  then ok "$lang the two intent documents are denied to every session"
  else no "$lang the two intent documents are denied to every session"; fi

  if [[ -f "$st" ]] && python3 -c "
import json,sys
d = json.load(open(sys.argv[1]))
bad = [r for r in d['permissions']['deny'] if r.startswith('Write(')]
sys.exit(0 if not bad else 1)
" "$st"
  then ok "$lang no deny rule uses the Write(...) form, which binds to nothing"
  else no "$lang no deny rule uses the Write(...) form, which binds to nothing"; fi

  # A session that can spawn a headless agent directly can hand it any grants
  # it likes, which walks around spawn-worker.sh's whole role system.
  if [[ -f "$st" ]] && python3 -c "
import json,sys
d = json.load(open(sys.argv[1]))
allow = ' '.join(d['permissions']['allow'])
sys.exit(0 if 'claude -p' not in allow and 'codex exec' not in allow else 1)
" "$st"
  then ok "$lang no session may spawn a headless agent around the role system"
  else no "$lang no session may spawn a headless agent around the role system"; fi

  co="$out/.github/CODEOWNERS"
  missing=""
  for p in '/.claude/scripts/' '/.claude/commands/' '/.claude/agents/' \
           '/.claude/orchestration.md' '/.claude/settings.json'; do
    grep -q "^${p}" "$co" || missing="$missing $p"
  done
  if [[ -z "$missing" ]]; then ok "$lang the delivery machinery is owned"
  else no "$lang the delivery machinery is owned" "unowned:$missing"; fi

  # docs/BACKLOG.md must NOT be owned: the unattended planner files items there
  # mid-run, so an owner review on that path stops work overnight. This asserts
  # the deliberate absence, so nobody "fixes" it later without reading why.
  if grep -qE '^/docs/BACKLOG\.md[[:space:]]+@' "$co"; then
    no "$lang the backlog stays un-owned so filing never blocks a run" \
       "CODEOWNERS claims /docs/BACKLOG.md — that stops the unattended planner"
  else ok "$lang the backlog stays un-owned so filing never blocks a run"; fi

  for f in AGENTS.md .github/review-prompt.md; do
    if grep -q '\.claude/scripts/' "$out/$f"; then
      ok "$lang $f lists .claude/ among the gate paths"
    else no "$lang $f lists .claude/ among the gate paths"; fi
  done

  if grep -q 'not spawnable' "$out/.claude/scripts/spawn-worker.sh"; then
    ok "$lang the architect role cannot be spawned"
  else no "$lang the architect role cannot be spawned"; fi

  # The backlog pair and its enforcer.
  for f in docs/BACKLOG.done.md .github/scripts/backlog-append-only.sh; do
    if [[ -f "$out/$f" ]]; then ok "$lang $f ships"
    else no "$lang $f ships"; fi
  done
  if grep -q 'backlog-append-only.sh' "$out/.github/workflows/ci.yml"; then
    ok "$lang the backlog check runs in CI"
  else no "$lang the backlog check runs in CI"; fi

  # The setup a human has to do by hand should be reduced to typing values, so
  # the skeleton ships and the script writes the real file. Both halves are
  # asserted because setting one and not the other leaves the App looking
  # configured while every unattended run still refuses.
  if [[ -f "$out/.claude/app-identity.example" ]]; then
    ok "$lang the App identity skeleton ships"
  else no "$lang the App identity skeleton ships"; fi
  if grep -q 'app-identity' "$out/scripts/setup-github.sh"; then
    ok "$lang setup-github.sh writes the driver's half of the identity"
  else no "$lang setup-github.sh writes the driver's half of the identity"; fi
  # The delete advice was wrong once the driver started reading that path on
  # every run; it must not come back.
  if grep -qE "Consider deleting the local .pem|rm '\$pem_path'" "$out/scripts/setup-github.sh"; then
    no "$lang setup no longer tells the owner to delete the key it needs" \
       "the .pem delete advice is back"
  else ok "$lang setup no longer tells the owner to delete the key it needs"; fi

  # The identity minter, and the driver actually using it.
  if [[ -f "$out/.claude/scripts/app-token.sh" ]]; then
    ok "$lang app-token.sh ships"
  else no "$lang app-token.sh ships"; fi
  if grep -q 'GH_TOKEN=' "$out/.claude/scripts/deliver-loop.sh"; then
    ok "$lang the driver opens pull requests with a minted token"
  else no "$lang the driver opens pull requests with a minted token"; fi
done

# --------------------------------- the directory-name validator bites
# The name comes from the destination directory, so an invalid name means an
# invalid directory. It must fail at generation rather than produce a
# pyproject.toml that cannot build.
msg="$(render "$WORK/My App 2.0" python 2>&1)"
if [[ -f "$WORK/My App 2.0/pyproject.toml" ]]; then
  no "a directory name that breaks the package name is rejected" "it rendered anyway"
else
  ok "a directory name that breaks the package name is rejected"
  expect_contains "names the offending directory" "$msg" "cannot be a Python"
fi

# Dashes and underscores are both fine — find_best_mobo is the real case.
if render "$WORK/find_best_mobo" python >/dev/null 2>&1; then
  ok "an underscored directory name renders"
  if [[ -d "$WORK/find_best_mobo/src/find_best_mobo" ]]; then
    ok "package directory matches the project directory"
  else
    no "package directory matches the project directory" \
      "$(ls "$WORK/find_best_mobo/src" 2>/dev/null)"
  fi
  if grep -q '^name = "find_best_mobo"' "$WORK/find_best_mobo/pyproject.toml"; then
    ok "pyproject name matches the project directory"
  else
    no "pyproject name matches the project directory"
  fi
else
  no "an underscored directory name renders"
fi

msg="$(render "$WORK/bad-owner" python --data code_owner="grimsverk" 2>&1)"
if [[ -d "$WORK/bad-owner" ]]; then
  no "a code_owner without @ is rejected" "it rendered anyway"
else
  ok "a code_owner without @ is rejected"
fi

# ------------------- a long description must not overflow a linted line
# The description is free text and lands in files a linter measures. A
# 72-character description once produced a 112-column module docstring, and the
# generated project failed its own CI on the first push, before any code
# existed. Both languages are checked at their configured limits.
LONG="Find the very best AMD motherboard for any given CPU and budget by scraping live prices from a long list of local and international retailers every single night"

if render "$WORK/longdesc" python --data description="$LONG" >/dev/null 2>&1; then
  ok "python renders with a long description"
  worst="$(awk '{ print length }' "$WORK/longdesc/src/longdesc/__init__.py" | sort -rn | head -1)"
  if [[ "$worst" -le 100 ]]; then
    ok "module docstring stays inside ruff's 100 columns ($worst)"
  else
    no "module docstring stays inside ruff's 100 columns" "longest line: $worst"
  fi
  # And exactly one sentence-ending period, not the doubled '..' the template
  # used to emit when the description already ended in one.
  if grep -q '\.\.' "$WORK/longdesc/src/longdesc/__init__.py"; then
    no "no doubled period in the docstring"
  else
    ok "no doubled period in the docstring"
  fi
else
  no "python renders with a long description"
fi

if render "$WORK/swiftlong" swift-ios --data description="$LONG" >/dev/null 2>&1; then
  ok "swift renders with a long description"
  worst="$(awk '{ print length }' "$WORK/swiftlong/Sources/ContentView.swift" | sort -rn | head -1)"
  if [[ "$worst" -le 120 ]]; then
    ok "ContentView stays inside SwiftLint's 120 columns ($worst)"
  else
    no "ContentView stays inside SwiftLint's 120 columns" "longest line: $worst"
  fi
else
  no "swift renders with a long description"
fi

# A description that already ends in a period must not gain a second one.
if render "$WORK/dotdesc" python --data description="Already ends in a period." >/dev/null 2>&1; then
  if grep -q 'period\.$' "$WORK/dotdesc/src/dotdesc/__init__.py"; then
    ok "a description ending in '.' emits exactly one"
  else
    no "a description ending in '.' emits exactly one" \
      "$(grep period "$WORK/dotdesc/src/dotdesc/__init__.py")"
  fi
fi

# ------------------------- a fresh render must pass its own formatter check
# `ruff format` formats Python code blocks inside Markdown, so the illustrative
# snippet in docs/plans/_TEMPLATE.md is subject to it. A generated project that
# fails its own gate before anyone has written a line is the worst possible
# first impression, and it is invisible until someone actually renders and runs.
if command -v uv >/dev/null && [[ -d "$WORK/python" ]]; then
  fmt="$( cd "$WORK/python" && uv sync -q >/dev/null 2>&1 \
    && uv run ruff format --check . 2>&1 )"
  if [[ $? -eq 0 ]]; then ok "a fresh python render is already ruff-format clean"
  else no "a fresh python render is already ruff-format clean" "$fmt"; fi
fi

# A dashed name still renders and yields an importable package.
if render "$WORK/my-second-app" python >/dev/null 2>&1; then
  ok "a dashed directory name renders"
  pkg="$(find "$WORK/my-second-app/src" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)"
  if python3 -c "import sys; sys.exit(0 if sys.argv[1].isidentifier() else 1)" "$pkg"; then
    ok "package name '$pkg' is a valid Python identifier"
  else
    no "package name is a valid Python identifier" "got: $pkg"
  fi
else
  no "a dashed directory name renders"
fi

summary
