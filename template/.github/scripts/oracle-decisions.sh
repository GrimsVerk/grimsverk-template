#!/usr/bin/env bash
#
# oracle-decisions.sh — the oracle's design ledger is append-only, and every
# decision in it metabolises evidence that already exists.
#
# `docs/DESIGN.md` is CODEOWNERS-owned, so design corrections wait for the
# owner. That is correct and it is also the reason unattended work stops at the
# first thing the evidence contradicts. `docs/DESIGN.oracle.md` is the second
# design document: an agent may append to it while nobody is awake, and this
# check is what makes that safe. It is deliberately NOT CODEOWNERS-owned —
# ownership there would stop overnight work, which is the whole point.
#
# Four duties, and the first is the load-bearing one.
#
# 1. EVERY DECISION CITES EVIDENCE THAT EXISTS AT THE BASE COMMIT.
#
#    The oracle cannot invent a design change. It can only act on something the
#    process already logged: an escape (`ESC-<n>` in docs/escapes.md) or a
#    backlog item (`BL-<n>` in docs/BACKLOG.md). Citing nothing fails; citing
#    something that sits unmerged in another pull request fails, for the same
#    reason escape-refs.sh exists — a claim about a ledger must be true at the
#    only moment anything checks it.
#
#    This is what separates "the design was corrected by data" from "an agent
#    rewrote the design". Rigid ids make it a dumb string match, safe to fail
#    closed on; prose would not be.
#
# 2. APPEND-ONLY. A decision present at the base commit may not be modified or
#    removed. Supersession is a NEW decision naming the old id — the lifecycle
#    docs/escapes.md already uses. Without this, an oracle could quietly revise
#    yesterday's ruling and the diff would read as an edit rather than a
#    reversal. Ids must also increase: reusing an id is how a modification
#    disguises itself as an addition.
#
# 3. SCHEMA. Each decision carries a date, its evidence, the requirement ids it
#    adds or supersedes, the alternatives it weighed, its rationale, and the
#    `docs/VISION.md` statement it relied on. The last field is the point of the
#    whole role: when the owner disagrees with a decision they can see which
#    vision statement produced it and edit THAT, rather than guessing which of
#    ten sentences was doing the work.
#
#    One OPTIONAL field, `Criterion waived`, is checked too — it is the only
#    thing in this ledger that changes what another gate does, so it must name
#    a criterion and carry a reason. See the block around it.
#
# 4. A CAP. 150 decisions. Not a real bound — a runaway-loop backstop.
#
# Two smaller duties over the artifacts around the ledger:
#
#   - every plan under docs/plans/oracle/ cites a decision id that exists at the
#     base commit, so a steward cannot invent work either;
#   - a handoff file under docs/oracle/ present at the base commit is never
#     modified. Handoffs are per-run files, so they are append-only by
#     construction — a new file per run, never an edit to an old one.
#
# REQUIREMENT IDS SHARE ONE INTEGER SPACE with docs/DESIGN.md — the grammar is
# `R<digits>` with no namespace mechanism — so oracle requirements start at
# R1000 and this check enforces the offset. Without it the two documents would
# silently collide on R7 and coverage.sh would union two different requirements
# into one.
#
# Required env:
#   BASE_SHA        the PR's base commit — evidence and decisions are resolved
#                   against the tree as it exists here
# Optional env:
#   ORACLE_DOC      default: docs/DESIGN.oracle.md
#   ORACLE_DIR      default: docs/oracle       (handoffs)
#   PLANS_DIR       default: docs/plans        (oracle plans in <dir>/oracle/)
#   LEDGER          default: docs/escapes.md
#   BACKLOG         default: docs/BACKLOG.md
#   DESIGN_DOC      default: docs/DESIGN.md    (for the covers-only plan rule)
#   MAX_DECISIONS   default: 150
#   REQ_OFFSET      default: 1000

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
: "${BASE_SHA:?BASE_SHA is required (the PR base commit)}"
ORACLE_DOC="${ORACLE_DOC:-docs/DESIGN.oracle.md}"
ORACLE_DIR="${ORACLE_DIR:-docs/oracle}"
PLANS_DIR="${PLANS_DIR:-docs/plans}"
LEDGER="${LEDGER:-docs/escapes.md}"
BACKLOG="${BACKLOG:-docs/BACKLOG.md}"
# Read to verify that a decision's quoted vision statement is actually IN it.
# Until that check existed the field was validated by the presence of a "
# character, so a one-letter quote passed in a repository with no vision file.
VISION_DOC="${VISION_DOC:-docs/VISION.md}"
DESIGN_DOC="${DESIGN_DOC:-docs/DESIGN.md}"
MAX_DECISIONS="${MAX_DECISIONS:-150}"
REQ_OFFSET="${REQ_OFFSET:-1000}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

declare -a PROBLEMS=()
fail() { PROBLEMS+=("$1"); }

# The tree as the base commit has it. A file absent there is not an error: it
# just means everything in it is new, which is the correct reading for a
# document that did not exist yet.
show_base() { git -C "$ROOT" show "${BASE_SHA}:$1" 2>/dev/null || true; }

# Decision ids in a document, in file order.
ids_in() { grep -oE '^## OD-[0-9]+' "$1" 2>/dev/null | sed 's/^## //' || true; }

# One decision's block: its heading through to the next `## ` heading or EOF.
block_of() { # block_of <file> <id>
  awk -v id="$2" '
    $0 ~ "^## " id "([^0-9]|$)" { inb = 1; print; next }
    inb && /^## /                { exit }
    inb                          { print }
  ' "$1"
}

# ---------------------------------------------------------------- the ledger

BASE_DOC="$WORK/base-oracle.md"
show_base "$ORACLE_DOC" > "$BASE_DOC"
HEAD_DOC="$ROOT/$ORACLE_DOC"

mapfile -t BASE_IDS < <(ids_in "$BASE_DOC")
mapfile -t HEAD_IDS < <([[ -f "$HEAD_DOC" ]] && ids_in "$HEAD_DOC")

# Evidence that exists at the base commit. Read once; every decision resolves
# against these two sets.
# The `|| true` on each grep is load-bearing under `set -e`: a ledger with no
# ESC ids yet made the first pipeline fail, which aborted this brace group
# BEFORE the backlog was read — so on a young project every BL citation
# "did not exist" (latent until the clearance check exercised it).
mapfile -t HAVE_EVIDENCE < <(
  { show_base "$LEDGER"  | grep -oE 'ESC-[0-9]+' || true
    show_base "$BACKLOG" | grep -oE 'BL-[0-9]+' || true
  } | sort -u
)
has_evidence() {
  local id
  for id in "${HAVE_EVIDENCE[@]:-}"; do [[ "$id" == "$1" ]] && return 0; done
  return 1
}

# --- 2. append-only: nothing at base may be modified or removed -------------
for id in "${BASE_IDS[@]:-}"; do
  [[ -z "$id" ]] && continue
  if [[ ! -f "$HEAD_DOC" ]]; then
    fail "$id was removed ($ORACLE_DOC no longer exists)"
    continue
  fi
  before="$(block_of "$BASE_DOC" "$id")"
  after="$(block_of "$HEAD_DOC" "$id")"
  if [[ -z "$after" ]]; then
    fail "$id was removed — decisions are append-only"
  elif [[ "$before" != "$after" ]]; then
    fail "$id was modified — decisions are append-only; supersede it with a new decision citing $id"
  fi
done

# --- ids are unique, and new ones increase ---------------------------------
HIGHEST_AT_BASE=0
for id in "${BASE_IDS[@]:-}"; do
  [[ -z "$id" ]] && continue
  n="${id#OD-}"
  [[ "$n" -gt "$HIGHEST_AT_BASE" ]] && HIGHEST_AT_BASE="$n"
done

declare -a SEEN=()
for id in "${HEAD_IDS[@]:-}"; do
  [[ -z "$id" ]] && continue
  for prev in "${SEEN[@]:-}"; do
    [[ "$prev" == "$id" ]] && fail "$id appears more than once — ids identify a decision, so they cannot repeat"
  done
  SEEN+=("$id")
done

# --- 1, 3: every NEW decision cites resolvable evidence and carries the schema
declare -i NEW=0
for id in "${HEAD_IDS[@]:-}"; do
  [[ -z "$id" ]] && continue
  is_new=1
  for old in "${BASE_IDS[@]:-}"; do [[ "$old" == "$id" ]] && is_new=0; done
  [[ "$is_new" -eq 1 ]] || continue
  NEW+=1

  n="${id#OD-}"
  if [[ "$n" -le "$HIGHEST_AT_BASE" ]]; then
    fail "$id is not above the highest id at the base commit (OD-$HIGHEST_AT_BASE) — a reused or backdated id is how a modification disguises itself as an addition"
  fi

  block="$(block_of "$HEAD_DOC" "$id")"

  # A HALT is a decision NOT to decide, recorded. It exists because a tenet stop
  # and an oracle finding nothing worth acting on used to produce the identical
  # artifact — no decision — while deliver-loop.sh marked the evidence processed
  # either way. So the one moment docs/VISION.md actually did its job was the
  # one moment nothing recorded, and the owner learned about it only by not
  # seeing something. A halt does not stop the run; it stops the silence.
  is_halt=0
  printf '%s\n' "$block" | head -1 | grep -q 'HALTED' && is_halt=1

  # ONE SCHEMA, WITH HALT AS A KIND, NOT A FORK (ESC-225). The legacy halt
  # field set stays legal — landed halts cannot be repaired in an append-only
  # ledger — but a halt written with the full decision schema is equally
  # legal, so the vocabulary stops forking: new tooling reads one shape.
  legacy_halt_ok="$is_halt"
  if [[ "$is_halt" -eq 1 ]]; then
    for field in "Date" "Evidence" "Tenet relied on" \
                 "What a decision would have said" "What it needs from the owner"; do
      value="$(printf '%s\n' "$block" \
        | sed -n "s/^[[:space:]]*[-*][[:space:]]*\*\*${field}:\*\*[[:space:]]*//p" | head -1)"
      if ! printf '%s\n' "$block" | grep -qF "**${field}:**" || [[ -z "$value" ]]; then
        legacy_halt_ok=0
      fi
    done
  fi
  if [[ "$legacy_halt_ok" -eq 1 ]]; then
    : # the legacy HALT shape, complete — nothing further to check here
  else
  halt_fails_before=${#PROBLEMS[@]}

  # Schema. Each field is asserted to be present AND to say something: a label
  # with nothing after it is the shape a schema check is most often satisfied by
  # and least often helped by.
  #
  # "Vision statements against" is the newest, and it is the one that makes the
  # field above it honest. A decision naming only the statement that supports it
  # has not weighed the vision, it has searched it — and the owner cannot tell
  # those apart, because both produce one quoted sentence. Naming the statement
  # that most nearly forbids the decision, and why it does not, is the only part
  # of this schema the deciding agent cannot produce without having read the
  # whole file.
  for field in "Date" "Evidence" "Requirements added" "Requirements superseded" \
               "Vision statement relied on" "Vision statements against" \
               "Alternatives considered" "Rationale"; do
    value="$(printf '%s\n' "$block" \
      | sed -n "s/^[[:space:]]*[-*][[:space:]]*\*\*${field}:\*\*[[:space:]]*//p" | head -1)"
    if ! printf '%s\n' "$block" | grep -qF "**${field}:**"; then
      fail "$id has no **${field}:** field"
    elif [[ -z "$value" ]]; then
      fail "$id has an empty **${field}:** field"
    fi
  done

  # 3b. The vision field carries the steering, so its VALUE has a shape, not
  # just a presence: either a verbatim quote from docs/VISION.md — recognisable
  # by its quotation marks — or the one explicit opt-out, verbatim:
  #
  #     (no vision statement decided this)
  #
  # The opt-out exists for the ruling class the vision genuinely does not
  # decide — an uncertainty a plan filed, say — which under the old rule could
  # not be written at all without paraphrasing something into existence. It is
  # a class, not an escape hatch: using it obliges the decision to say what
  # else was weighed, because guessing is allowed and guessing SILENTLY is not
  # (docs/DECISIONS.md, the mid-run authority ruling).
  vision_value="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Vision statement relied on:\*\*[[:space:]]*//p' | head -1)"
  if [[ -n "$vision_value" ]]; then
    if [[ "$vision_value" == "(no vision statement decided this)" ]]; then
      alts_value="$(printf '%s\n' "$block" \
        | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Alternatives considered:\*\*[[:space:]]*//p' | head -1)"
      if [[ "$alts_value" == *"(none)"* ]]; then
        fail "$id uses the no-vision class with no alternatives — say what else was weighed and why it lost, or the owner cannot see what a different vision sentence would have changed"
      fi
    elif [[ "$vision_value" != *'"'* ]]; then
      fail "$id's vision field neither quotes a statement nor declares '(no vision statement decided this)' — a paraphrase is the decision restating itself"
    else
      # THE QUOTE MUST BE IN THE FILE. Until this existed the entire check was
      # "does the value contain a double-quote character", so `"s"` passed — in
      # a fixture with no docs/VISION.md at all. The field is what the owner is
      # told to steer by ("edit the sentence that produced the decision"), and
      # nothing connected the sentence they edit to the next decision.
      #
      # Whitespace is collapsed on both sides because a vision sentence wraps
      # across lines in the file and appears on one line in the ledger. Matching
      # is fixed-string, not regex: a quoted sentence is data.
      norm() { tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }
      vision_at_base="$(git -C "$ROOT" show "${BASE_SHA}:${VISION_DOC}" 2>/dev/null | norm || true)"
      if [[ -z "$vision_at_base" ]]; then
        fail "$id quotes a vision statement, but there is no ${VISION_DOC} at the base commit.

Deleting the file is a legitimate choice and it means this project has no
tiebreaker — so the honest field value is the opt-out class, which then obliges
'Alternatives considered' to carry the whole reasoning. Quoting a sentence from
a file that is not in the tree produces a ledger that reads as steerable by a
document the owner removed."
      else
        # Every quoted span must be real. Multiple spans are allowed — a
        # decision may legitimately lean on more than one sentence.
        mapfile -t QUOTED < <(printf '%s\n' "$vision_value" \
          | grep -oE '"[^"]+"' | sed 's/^"//; s/"$//')
        for q in "${QUOTED[@]:-}"; do
          [[ -z "$q" ]] && continue
          q_norm="$(printf '%s' "$q" | norm)"
          # A fragment short enough to invert is a fragment too short to cite:
          # six words lifted out of "I would trade any feature for a design I
          # can hold in my head" reverse what the owner said, and read as a
          # clean derivation from it.
          if [[ "${#q_norm}" -lt "${MIN_QUOTE_CHARS:-25}" ]]; then
            fail "$id's vision quote is ${#q_norm} characters — too short to be the statement it leans on. Quote the whole sentence: a fragment can be read against the sense of the sentence it came from, and the owner reading the ledger cannot tell."
          fi
          grep -qF -- "$q_norm" <<<"$vision_at_base" \
            || fail "$id quotes a vision statement that is not in ${VISION_DOC} at the base commit:

  \"${q_norm}\"

Quote it verbatim, or use '(no vision statement decided this)' and say in
'Alternatives considered' what you weighed instead. This field is the owner's
steering lever — they are told that editing the sentence changes what comes
next — so a sentence they never wrote makes the lever a decoration."
        done
      fi
    fi
  fi

  # An OPTIONAL eighth field, and the only one that changes what a gate does:
  #
  #     - **Criterion waived:** S3 — <why the test does not recognise what was built>
  #
  # acceptance-criteria.sh reads landed waivers at the base commit and skips
  # that criterion. It exists because the owner found the hole in the first
  # version of this arrangement: a criterion the oracle ruled "met by other
  # means" still exits non-zero, so every later pull request would stay red and
  # the ruling would have unblocked nothing.
  #
  # It is an exception rather than a hole because it NAMES A CRITERION AND NEVER
  # THE CHECK — a waiver on S3 leaves S4 gating — and because it lives here,
  # where it inherits evidence-citation, immutability and permanence for free.
  # A future version that let a waiver name a directory, a prefix or a whole run
  # would be the bypass this design is carefully not.
  #
  # Two rules, and both are about the waiver still being an argument:
  #   - it names at least one S id, or it waives nothing while reading as though
  #     it did;
  #   - it says WHY, in more than the id. A bare "- **Criterion waived:** S3"
  #     is the oracle overruling the owner's definition of done with no
  #     reasoning the owner can disagree with, which is exactly the shape the
  #     'may not mark it passed' limit exists to prevent.
  waived_line="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Criterion waived:\*\*[[:space:]]*//p' | head -1)"
  if printf '%s\n' "$block" | grep -qF "**Criterion waived:**"; then
    mapfile -t WAIVED_IDS < <(printf '%s\n' "$waived_line" | grep -oE '\bS[0-9]+\b' | sort -u)
    if [[ ${#WAIVED_IDS[@]} -eq 0 ]]; then
      fail "$id has a **Criterion waived:** field naming no criterion — write ids as S<n>, or drop the field"
    fi
    rest="$waived_line"
    for w in "${WAIVED_IDS[@]:-}"; do rest="${rest//$w/}"; done
    rest="$(printf '%s' "$rest" | tr -cd '[:alnum:]')"
    if [[ "${#rest}" -lt 20 ]]; then
      fail "$id waives ${WAIVED_IDS[*]:-a criterion} with no reasoning — a waiver is the one field here that changes what a gate does, and the owner reading it has to be able to disagree with something. Say what the criterion's script does not recognise about what was built."
    fi
  fi

  # EVERY NEW DECISION SAYS WHAT BECOMES OF IT (ESC-217). In the 2026-08-20
  # experiment, 35 of 58 decisions were never planned and nothing could say
  # whether that was a leak or a judgment: a decision that answers a question
  # without minting a requirement schedules no work and closes nothing, so it
  # simply evaporates. The disposition rule makes the outcome explicit at
  # ruling time — a decision either creates work, retires work, or says in so
  # many words that there is none:
  #
  #   - `- **Requirements added:**` names an id  -> work exists; the steward
  #     chain and coverage own its closure;
  #   - `- **Requirements superseded:**` names an id -> work is retired
  #     (coverage moves it to the awaiting-retirement class, ESC-219);
  #   - `- **Closure:** <why there is nothing to build>` -> no work, said
  #     aloud rather than implied by silence.
  #
  # A HALT is its own disposition and is checked in its own branch above. The
  # rule binds NEW decisions only — the ledger is append-only, so a legacy
  # decision without a disposition cannot be repaired and is not failed.
  added_says="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Requirements added:\*\*[[:space:]]*//p' \
    | head -1 | grep -oE '\bR[0-9]+\b' | head -1 || true)"
  sup_says="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Requirements superseded:\*\*[[:space:]]*//p' \
    | head -1 | grep -oE '\bR[0-9]+\b' | head -1 || true)"
  closure_value="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Closure:\*\*[[:space:]]*//p' | head -1)"
  if printf '%s\n' "$block" | grep -qF "**Closure:**"; then
    if [[ -z "$closure_value" ]]; then
      fail "$id has an empty **Closure:** field — say why there is nothing to build, or drop the field and add a requirement"
    fi
  elif [[ -z "$added_says" && -z "$sup_says" && "$is_halt" -eq 0 ]] \
    && ! printf '%s\n' "$block" | grep -qF "**Criterion waived:**"; then
    # A waiver is a disposition too — it changes what the acceptance gate does,
    # which is this ledger's one directly-effective outcome.
    fail "$id has no disposition: it adds no requirement, supersedes none, waives nothing, and carries no **Closure:** field. A decision that creates no work must say so — add '- **Closure:** <why there is nothing to build>' — or it evaporates the way 35 of 58 did on 2026-08-20 (ESC-217)"
  fi

  if [[ "$is_halt" -eq 1 && ${#PROBLEMS[@]} -gt ${halt_fails_before:-0} ]]; then
    fail "$id is a HALT satisfying NEITHER shape — write either the halt fields (Date, Evidence, Tenet relied on, What a decision would have said, What it needs from the owner) or the full decision schema; the failures above are the full-schema reading"
  fi
  fi  # end of the unified schema branch

  # A DECISION DECLARES WHAT IT FASTENS WORK TO, AND THE GATE RESOLVES IT
  # (ESC-222). Downstream, one ruling bound a requirement to a fixture in no
  # commit and another to a string in a gitignored file; each phantom cost a
  # full unattended session plus further rulings declaring reconstructions —
  # the two longest rulings in that ledger exist only to untangle them. The
  # optional field:
  #
  #     - **Binds:** path:acceptance/S1.sh, ordered:fixtures/variants.csv
  #
  # `path:` entries must exist at the BASE COMMIT — the same tree every other
  # citation here resolves against. `ordered:` entries are the honest other
  # case: the artifact does not exist yet and the decision ORDERS it, which
  # is work a plan must deliver, said out loud instead of discovered by the
  # session that reaches for a file that is not there. The field is optional
  # because not every decision fastens to an artifact; the PROMPT carries the
  # duty to declare (oracle.md), and this gate verifies what is declared.
  binds_line="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Binds:\*\*[[:space:]]*//p' | head -1)"
  if printf '%s\n' "$block" | grep -qF "**Binds:**"; then
    if [[ -z "$binds_line" ]]; then
      fail "$id has an empty **Binds:** field — name what the decision fastens to (path:<existing> / ordered:<to-create>), or drop the field"
    fi
    for entry in ${binds_line//,/ }; do
      [[ -n "$entry" ]] || continue
      case "$entry" in
        path:*)
          bp="${entry#path:}"
          if ! git -C "$ROOT" cat-file -e "${BASE_SHA}:${bp}" 2>/dev/null; then
            fail "$id binds path:$bp, which exists in no commit at the base — a ruling fastened to a phantom referent cost a session per phantom downstream (ESC-222). If the decision ORDERS its creation, write 'ordered:$bp' and let a plan deliver it"
          fi ;;
        ordered:*) : ;;
        *)
          fail "$id has a Binds entry '$entry' with no prefix — every entry is 'path:<existing-at-base>' or 'ordered:<to-be-created>' (ESC-222)" ;;
      esac
    done
  fi

  # 1. Evidence must exist at the base commit. Both shapes cite it: a halt is a
  # record of evidence the oracle READ and declined to act on, which is exactly
  # the thing that used to vanish.
  evidence_line="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Evidence:\*\*[[:space:]]*//p' | head -1)"
  mapfile -t CITED < <(printf '%s\n' "$evidence_line" | grep -oE '(ESC|BL)-[0-9]+' | sort -u)
  if [[ ${#CITED[@]} -eq 0 ]]; then
    fail "$id cites no evidence — an oracle decision resolves something already logged (ESC-<n> in $LEDGER, BL-<n> in $BACKLOG), never something it thought of"
  fi
  for cite in "${CITED[@]:-}"; do
    has_evidence "$cite" \
      || fail "$id cites $cite, which does not exist at the base commit"
  done

  # 3. Requirement ids: shape, and the offset that keeps the two design
  # documents out of each other's integer space. A halt adds no requirements —
  # deciding not to decide cannot extend the work queue, which is half of why
  # recording it is safe to do unattended.
  if [[ "$is_halt" -eq 0 ]]; then
  added="$(printf '%s\n' "$block" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Requirements added:\*\*[[:space:]]*//p' | head -1)"
  if [[ "$added" != *"(none)"* ]]; then
    mapfile -t ADDED_IDS < <(printf '%s\n' "$added" | grep -oE '\bR[0-9]+\b' | sort -u)
    if [[ ${#ADDED_IDS[@]} -eq 0 ]]; then
      fail "$id has a **Requirements added:** field that names no id — write ids as R<n>, or '(none)'"
    fi
    for req in "${ADDED_IDS[@]:-}"; do
      if [[ "${req#R}" -lt "$REQ_OFFSET" ]]; then
        fail "$id adds $req, below the oracle offset R$REQ_OFFSET — requirement ids share ONE integer space with $ORACLE_DOC's counterpart, so a low id silently collides with a requirement the owner wrote"
      fi
    done
  fi
  fi  # end of the requirement-id checks, skipped for a HALT
done

# --- 4. the runaway-loop backstop ------------------------------------------
TOTAL=${#HEAD_IDS[@]}
if [[ "$TOTAL" -gt "$MAX_DECISIONS" ]]; then
  fail "$TOTAL decisions, over the cap of $MAX_DECISIONS — this is a runaway-loop backstop, not a real bound; if it has been reached legitimately, the owner raises it"
fi

# --------------------------- clearances: the LOW fast-path (ESC-226)
# An item the filer had already resolved — "Risk: LOW … proceeded on the
# default" — used to cost a full eight-field ruling anyway, because citation
# from a decision was the only door out of the queue. Downstream that bought
# dozens of rulings every reader later agreed nobody needed. The fast path:
#
#     ## Clearances
#
#     - **Cleared:** BL-7 — LOW, default stood: the flag shipped as proposed
#
# One line, appended under a `## Clearances` heading (never bare at the end
# of the file — a bare trailing line would extend the last decision's block
# and trip the append-only check). The detector already counts any cited id
# as metabolised, so a clearance closes the item the moment it lands. The
# rules that keep the fast path from becoming a trapdoor:
#   - the id exists in the backlog at the base commit — a clearance closes a
#     real filed item, it cannot invent one;
#   - the item is not HIGH — a HIGH is ruled, never cleared;
#   - the one line of WHY is present — it is the whole price;
#   - landed clearance lines are immutable, like everything else here.
clearance_lines() { grep -E '^[-*] \*\*Cleared:\*\*' "$1" 2>/dev/null || true; }
if [[ -f "$HEAD_DOC" ]]; then
  while IFS= read -r cl; do
    [[ -n "$cl" ]] || continue
    grep -qxF -- "$cl" "$HEAD_DOC" \
      || fail "a landed clearance line was modified or removed — clearances are append-only: '$cl'"
  done < <(clearance_lines "$BASE_DOC")
  while IFS= read -r cl; do
    [[ -n "$cl" ]] || continue
    cid="$(grep -oE 'BL-[0-9]+' <<<"$cl" | head -1 || true)"
    if [[ -z "$cid" ]]; then
      fail "a clearance line names no BL id: '$cl'"
      continue
    fi
    if ! has_evidence "$cid"; then
      fail "clearance of $cid: no such item in $BACKLOG at the base commit — a clearance closes a real filed item, it cannot invent one"
      continue
    fi
    if show_base "$BACKLOG" | awk -v id="$cid" '
        $0 ~ "^- \\*\\*" id "\\*\\*" { inb = 1; print; next }
        inb && (/^- / || /^## /)             { inb = 0 }
        inb                                  { print }' \
      | grep -qE '(^|[^A-Za-z0-9_])HIGH([^A-Za-z0-9_]|$)'; then
      fail "clearance of $cid: the item is classified HIGH — a HIGH is ruled, never cleared; the one-line path is for defaulted LOW items only (ESC-226)"
      continue
    fi
    rest="${cl#*Cleared:\*\*}"
    rest="${rest//$cid/}"
    rest="$(printf '%s' "$rest" | tr -cd '[:alnum:]')"
    if [[ "${#rest}" -lt 5 ]]; then
      fail "clearance of $cid says nothing — one line of why is the whole price of the fast path; pay it"
    fi
  done < <(clearance_lines "$HEAD_DOC")
fi

# ------------------------------------------------------- handoffs, per run
# A handoff is written once and never modified. It is a new file per run, which
# is what makes it append-only by construction rather than by promise.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ ! -f "$ROOT/$f" ]]; then
    fail "$f was removed — a handoff is a record of one run and is never deleted"
  elif ! diff -q <(show_base "$f") "$ROOT/$f" >/dev/null 2>&1; then
    fail "$f was modified — a handoff is written once; a later run writes a NEW file"
  fi
done < <(git -C "$ROOT" ls-tree -r --name-only "$BASE_SHA" -- "$ORACLE_DIR" 2>/dev/null \
         | grep -E '/handoff-[^/]+\.md$' || true)

# ------------------------------------------------- plans built on a decision
# Plans under docs/plans/oracle/ are the ones that merge with nobody awake, so
# each must trace to something owner-controlled that ALREADY LANDED. Two
# accepted forms, and nothing else:
#
#   1. a steward's plan, citing a decision id (`OD-<n>`) that exists at the
#      base commit — the original rule;
#   2. a milestone plan the unattended loop landed here, citing no decision
#      but whose `covers:` list consists solely of requirement ids that exist
#      at the base commit in either design document. Both documents are
#      owner-controlled ($DESIGN_DOC by owner-authored.sh, $ORACLE_DOC by the
#      evidence rule above), so this is still "the design layer rules": the
#      plan implements requirements somebody already landed, it does not
#      propose them. The requirement-id extraction mirrors coverage.sh —
#      section 5 ids for the design doc, column-anchored `Requirements added`
#      lines for the ledger — so the two checks cannot disagree about what a
#      requirement is.
ORACLE_PLANS="$ROOT/$PLANS_DIR/oracle"

# Requirement ids that exist at the base commit, lazily built on first use.
BASE_REQS=""
base_reqs() {
  if [[ -z "$BASE_REQS" ]]; then
    show_base "$DESIGN_DOC"  > "$WORK/base-design.md"
    # base-oracle.md already holds the ledger at base.
    BASE_REQS="$(awk '
      /^## 5\./ { in5 = 1; next }
      /^## /    { in5 = 0 }
      in5 || /^[-*] \*\*Requirements added:\*\*/ {
        line = $0
        if (!in5) sub(/^.*\*\*Requirements added:\*\*/, "", line)
        while (match(line, /\*\*R[0-9]+\*\*/)) {
          print substr(line, RSTART + 2, RLENGTH - 4)
          line = substr(line, RSTART + RLENGTH)
        }
        if (!in5) {
          n = split(line, parts, /[^A-Za-z0-9]+/)
          for (i = 1; i <= n; i++) if (parts[i] ~ /^R[0-9]+$/) print parts[i]
        }
      }' "$WORK/base-design.md" "$BASE_DOC" | sort -u)"
    [[ -n "$BASE_REQS" ]] || BASE_REQS=$'\n'
  fi
  printf '%s\n' "$BASE_REQS"
}

if [[ -d "$ORACLE_PLANS" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ "$(basename "$f")" == _* ]] && continue
    rel="${f#"$ROOT"/}"
    mapfile -t PLAN_CITES < <(grep -oE '\bOD-[0-9]+\b' "$f" | sort -u)
    if [[ ${#PLAN_CITES[@]} -eq 0 ]]; then
      # Form 2: no decision cited, so the covers list must carry the trace.
      covers_line="$(sed -n 's/^covers:[[:space:]]*//p' "$f" | head -1)"
      mapfile -t COVERS < <(printf '%s\n' "$covers_line" | grep -oE 'R[0-9]+' | sort -u)
      if [[ ${#COVERS[@]} -eq 0 ]]; then
        fail "$rel cites no oracle decision and covers no requirement — a plan here implements a landed OD-<n>, or covers requirement ids that already landed in $DESIGN_DOC or $ORACLE_DOC; it never proposes work"
        continue
      fi
      for req in "${COVERS[@]}"; do
        grep -qxF "$req" <(base_reqs) \
          || fail "$rel covers $req, which exists in neither design document at the base commit — a plan implements requirements somebody landed, it does not propose them"
      done
      continue
    fi
    resolved=0
    for cite in "${PLAN_CITES[@]}"; do
      for old in "${BASE_IDS[@]:-}"; do [[ "$old" == "$cite" ]] && resolved=1; done
    done
    [[ "$resolved" -eq 1 ]] || fail "$rel cites ${PLAN_CITES[*]}, none of which exists at the base commit — land the decision first, then plan it"
  done < <(find "$ORACLE_PLANS" -name '*.md' | sort)
fi

# --------------------------------------------------------------------- verdict

if [[ ${#PROBLEMS[@]} -gt 0 ]]; then
  echo "oracle-decisions: ${#PROBLEMS[@]} problem(s):" >&2
  printf '  %s\n' "${PROBLEMS[@]}" >&2
  cat >&2 <<MSG

$ORACLE_DOC is the one design document an agent may write unattended, and these
are the conditions that make that safe: every decision metabolises evidence that
already landed, nothing already decided is quietly revised, and each decision
says which docs/VISION.md statement it leaned on so the owner can steer by
editing that statement rather than by arguing with the decision.

Relaxing this check to get a decision through is gate tampering.
MSG
  exit 1
fi

echo "oracle-decisions: ${TOTAL} decision(s), ${NEW} new in this pull request, all resolve at ${BASE_SHA:0:12}."
