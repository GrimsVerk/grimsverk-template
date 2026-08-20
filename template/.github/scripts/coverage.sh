#!/usr/bin/env bash
#
# coverage.sh — is every requirement in the design actually planned?
#
# Reads the requirement ids (R1, R2, ...) from docs/DESIGN.md and the `covers:`
# field from every plan under docs/plans/, and reports which requirements no plan
# claims. Also reports the reverse: plans covering ids the design doesn't define,
# which usually means a requirement was renumbered or a typo crept in.
#
# This answers the question "all the slices merged, so are we done?" — which the
# backlog cannot answer. An empty backlog is a statement about the backlog. A
# requirement no plan covers is work nobody scheduled, and it stays invisible
# right up until someone goes looking for the feature.
#
# NOT a CI gate and deliberately not wired into one: mid-project, uncovered
# requirements are the normal state. It exits non-zero when gaps exist so the
# project loop can branch on it, not so a pull request can fail on it.
#
# IT ALSO REPORTS PLAN ADEQUACY, AND ONLY REPORTS IT.
#
# "Covered" means some plan's `covers:` names the id. That is a CLAIM, and
# nothing downstream compares the claim to what the plan's slices actually
# build: a plan naming twelve requirements and building three passes every gate
# green, and the run then walks to acceptance reporting "every requirement is
# covered by a plan". So this additionally reports which covered ids no slice in
# the claiming plan ever mentions.
#
# A NOTE, NEVER A FAILURE — the owner's ruling, in one word: "yes, note, not
# red." And it is the right call. A platform requirement, an offline
# requirement, a privacy constraint: these are legitimately owned by no single
# slice, so a strict check would fire on honest plans and teach authors to route
# around it by padding slice text with ids. A requirement marked
# `*(non-functional)*` in the design's section 5 is reported as an EXPECTED
# absence rather than a gap, which is what keeps the signal readable.
#
# THE UNIVERSE IS THE SURVIVING REQUIREMENTS. The oracle ledger is append-only,
# so a decision that turns out wrong is superseded rather than edited away and
# the id it retires stays on its page forever. Those ids are subtracted here and
# reported as design history, never as a gap: a retired requirement's behaviour
# is deliberately not being built, so a permanent "NOT PLANNED" is a script
# limitation reported as unscheduled work — and the delivery loop, which
# dispatches a planner for every gap, livelocks on one (ESC-200).
#
# Usage:  coverage.sh
#
# Exit codes are distinct because /deliver branches on them, and "there is work
# left to plan" is a completely different situation from "this project is not
# set up yet". Collapsing both into 1, as this once did, made the delivery loop
# unable to tell a to-do list from a broken repository.
#
#   0  every requirement is covered by a plan
#   1  gaps: some requirement has no plan (NORMAL mid-project — this is the
#      to-do list, not a failure)
#   2  setup problem: no docs/DESIGN.md, its section 5 has no requirement ids, or
#      the design or a plan contains a MALFORMED id (see below)
#
# A GATE THAT IGNORES WHAT IT CANNOT PARSE FAILS OPEN.
#
# This once recognised `**R<digits>**` and nothing else, and silently skipped
# anything else — `R2a`, a typo, a renumbering slip. Such an id was never
# counted as covered and never reported as missing: it simply did not exist as
# far as this script was concerned, while reading like a requirement to every
# human. A plan claiming it was then rejected with no hint why.
#
# So a malformed id is now an error. "Malformed" is anchored on a digit: an id
# is `R` or `S` followed by digits, and a bold token that starts `R<digit>` or
# `S<digit>` but is not all digits after the letter is a broken id. Prose is
# untouched by that rule — `**Rationale**` and `**Scope**` do not have a digit
# after the letter — which is why the check is anchored there rather than on any
# bold word beginning with R or S. It cannot catch every conceivable typo; it
# catches every id-shaped one, and it never guesses about ordinary prose.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
# A LIST, space-separated. There are two design documents: the owner's, and the
# oracle's evidence-driven ledger (docs/DESIGN.oracle.md), which an agent may
# append to unattended. Requirements are the UNION of both — a plan covering an
# oracle requirement was otherwise reported as "an id the design doesn't
# define", which reads as a typo and is not one.
DESIGN="${DESIGN:-$ROOT/docs/DESIGN.md $ROOT/docs/DESIGN.oracle.md}"
PLANS_DIR="${PLANS_DIR:-$ROOT/docs/plans}"

read -r -a DESIGN_DOCS <<< "$DESIGN"
declare -a PRESENT=()
for doc in "${DESIGN_DOCS[@]}"; do
  [[ -f "$doc" ]] && PRESENT+=("$doc")
done

[[ ${#PRESENT[@]} -gt 0 ]] || {
  echo "coverage: no ${DESIGN_DOCS[0]} — run /design first" >&2
  exit 2
}

# Requirement ids from one document. Two rules, applied uniformly to every
# design document so there is no per-file magic:
#
#   - section 5 only, so that an "R1" mentioned in prose elsewhere doesn't
#     invent a requirement. This is what docs/DESIGN.md uses;
#   - `**Requirements added:**` lines, which is how a decision in the oracle
#     ledger declares the ids it introduces. That document is a list of dated
#     decisions and has no section 5, and its rationales legitimately mention
#     ids they did NOT define — a superseded one, for instance — so reading the
#     whole file would invent requirements out of prose.
#
#     The line must START with a list marker, and that is not cosmetic. The
#     shipped ledger skeleton documents its own schema in an INDENTED code
#     block, example ids and all — so a rule that matched the label anywhere
#     defined R1000 and R1001 in every generated project on day one, as
#     requirements no plan would ever cover and that no amount of work could
#     clear. Column-anchoring excludes the indented example and matches every
#     real decision, which writes the field at column 0.
#
# A document that has neither shape simply contributes nothing.
ids_from() {
  awk '
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
        # Split on non-alphanumerics rather than using a word-boundary escape:
        # \b is a backspace to awk, not a boundary, and the difference is
        # silent — the pattern simply never matches and every oracle
        # requirement vanishes from the coverage report.
        n = split(line, parts, /[^A-Za-z0-9]+/)
        for (i = 1; i <= n; i++) if (parts[i] ~ /^R[0-9]+$/) print parts[i]
      }
    }' "$1"
}

mapfile -t REQS < <(
  for doc in "${PRESENT[@]}"; do ids_from "$doc"; done | awk '!seen[$0]++'
)

# Requirements the design marks `*(non-functional)*`. A platform, offline,
# privacy or cost requirement is legitimately owned by no single slice, so the
# adequacy report below calls its absence expected rather than a gap. The mark
# is the design's, and the design is CODEOWNERS-owned, so what counts as
# "expected" stays the owner's rather than the planner's.
declare -A NONFUNCTIONAL=()
while IFS= read -r id; do
  [[ -n "$id" ]] && NONFUNCTIONAL["$id"]=1
done < <(
  for doc in "${PRESENT[@]}"; do
    awk '
      /^## 5\./ { in5 = 1; next }
      /^## /    { in5 = 0 }
      in5 && /\*\(non-functional\)\*/ {
        line = $0
        while (match(line, /\*\*R[0-9]+\*\*/)) {
          print substr(line, RSTART + 2, RLENGTH - 4)
          line = substr(line, RSTART + RLENGTH)
        }
      }' "$doc"
  done | sort -u
)

# Malformed ids anywhere in a design document — not just section 5. An id-shaped
# token in section 12's milestones or section 13's criteria is read as an id by
# every human who passes it, so it has to be one.
#
# EXCEPT IN THE ORACLE LEDGER, WHERE WHOLE-FILE SCANNING IS A TRAP (ESC-82).
# That document is APPEND-ONLY and `oracle-decisions.sh` enforces it, so a
# malformed id landed in a decision's prose can never be repaired: editing the
# line fails the append-only gate, and superseding the decision cannot remove
# text that is already there. Both gates are required checks, so the repository
# deadlocks — observed live, a lane stuck at SETUP with no sequence of legal
# actions able to clear it.
#
# It is also wrong on its own terms. A decision that declares R1000 on its
# `**Requirements added:**` line and then writes `**R1000 — Output precision.**`
# as the body's label is following the house style, not inventing an id. The
# id-collection pass one screen up already refuses to read this file's prose,
# with a comment explaining exactly why ("its rationales legitimately mention
# ids they did NOT define"); the malformed pass was never given the same care.
#
# So in the ledger only DECLARATION lines are scanned — the same lines the
# collection pass reads. A malformed id there is still caught, and that is the
# place where it means something. Every other design document is owner-editable,
# so the whole-file scan stays: an owner can always fix their own file.
mapfile -t BAD_IDS < <(
  for doc in "${PRESENT[@]}"; do
    ledger=0
    [[ "$(basename "$doc")" == "DESIGN.oracle.md" ]] && ledger=1
    awk -v doc="${doc#"$ROOT"/}" -v ledger="$ledger" '
      ledger && !/^[-*] \*\*Requirements (added|superseded):\*\*/ { next }
      {
        line = $0
        while (match(line, /\*\*[RS][0-9][^*]*\*\*/)) {
          id = substr(line, RSTART + 2, RLENGTH - 4)
          if (id !~ /^[RS][0-9]+$/ && !(id in seen)) {
            seen[id] = 1; print id " (in " doc ")"
          }
          line = substr(line, RSTART + RLENGTH)
        }
      }' "$doc"
  done
)

if [[ ${#BAD_IDS[@]} -gt 0 ]]; then
  echo "coverage: malformed requirement id(s):" >&2
  printf '  %s\n' "${BAD_IDS[@]}" >&2
  cat >&2 <<'MSG'

An id is R or S followed by digits — R1, R12, S3. Anything else cannot be
matched against a plan's `covers:` field, and the failure is silent in the worst
direction: the id is neither counted as covered nor reported as missing, so it
reads like a tracked requirement while being tracked by nothing.

Renumber it (R2a and R2b become R2 and R3), or if it is deliberately not a
requirement id, write it without the bold id form.
MSG
  exit 2
fi

if [[ ${#REQS[@]} -eq 0 ]]; then
  echo "coverage: no requirement ids (R1, R2, ...) found in ${PRESENT[*]#"$ROOT"/}."
  echo "          Give each requirement a stable id so coverage can be checked."
  exit 2
fi

# ---------------------------------------------- retired ids, and who says so
# The oracle ledger is APPEND-ONLY by design — a decision that turns out wrong is
# superseded by a new one, never edited away — so a requirement a later decision
# reverses stays on its page reading exactly like a live requirement forever.
# Counting it as one is not a cosmetic wrong number: the delivery driver
# commissions planning for every gap this script reports, so a permanent gap
# dispatched a planner for the dead decision every cycle and the loop could never
# walk past it. A full unattended session per turn, observed live.
#
# docs/BACKLOG.md and docs/escapes.md each hit this and each got a done-log.
# This is the same answer for the same reason, and the oracle ledger was the last
# of the three append-only machine-parsed files without one.
#
# TWO FILES, AND ONLY ONE OF THEM HAS AUTHORITY. The ledger DECIDES a retirement;
# docs/DESIGN.oracle.done.md RECORDS it. Both directions are refused below, and
# the second is the one that matters: without it a single appended line would
# delete a requirement from the universe, and "every requirement is covered"
# would become true by emptying the design.
#
# Column-anchored, exactly like the `**Requirements added:**` rule one screen up
# and for the identical reason — the shipped skeleton documents its format in an
# INDENTED code block, example id and all.
DONE_DOC="$ROOT/docs/DESIGN.oracle.done.md"
declare -A RETIRED=()        # retired id -> the decision that retired it
declare -A REPLACED_BY=()    # retired id -> the id that took its place, if any
if [[ -f "$DONE_DOC" ]]; then
  while IFS=$'\t' read -r id od rep; do
    [[ -n "$id" ]] || continue
    RETIRED["$id"]="${od:-the oracle ledger}"
    REPLACED_BY["$id"]="$rep"
  done < <(awk '
    /^[-*][[:space:]]+`R[0-9]+`/ {
      line = $0
      id = ""; od = ""; rep = ""
      if (match(line, /`R[0-9]+`/))
        id = substr(line, RSTART + 1, RLENGTH - 2)
      rest = substr(line, RSTART + RLENGTH)
      if (match(rest, /`OD-[0-9]+`/))
        od = substr(rest, RSTART + 1, RLENGTH - 2)
      if (match(rest, /replaced by[[:space:]]+`R[0-9]+`/)) {
        seg = substr(rest, RSTART, RLENGTH)
        match(seg, /R[0-9]+/); rep = substr(seg, RSTART, RLENGTH)
      }
      if (id != "") print id "\t" od "\t" rep
    }' "$DONE_DOC")
fi

# What the LEDGER says it retired. Read only to be compared with the file above:
# nothing is subtracted on this evidence alone, because a decision's declaration
# and the design's current shape are two different facts and the whole point of
# the pair is that neither can be revised to suit the other.
declare -A LEDGER_RETIRED=()
if [[ -f "$ROOT/docs/DESIGN.oracle.md" ]]; then
  while IFS=$'\t' read -r id od; do
    [[ -n "$id" ]] || continue
    LEDGER_RETIRED["$id"]="$od"
  done < <(awk '
    function flush(   i) {
      for (i = 1; i <= nsup; i++) print sup[i] "\t" od
      nsup = 0
    }
    /^## / { flush(); od = ($2 ~ /^OD-/) ? $2 : "the oracle ledger" }
    /^[-*] \*\*Requirements superseded:\*\*/ {
      line = $0
      sub(/^.*\*\*Requirements superseded:\*\*/, "", line)
      # Split on non-alphanumerics rather than a word-boundary escape: \b is a
      # backspace to awk, and the difference is silent.
      n = split(line, parts, /[^A-Za-z0-9]+/)
      for (i = 1; i <= n; i++)
        if (parts[i] ~ /^R[0-9]+$/) sup[++nsup] = parts[i]
    }
    END { flush() }
  ' "$ROOT/docs/DESIGN.oracle.md")
fi

declare -a UNRECORDED=()
for id in "${!LEDGER_RETIRED[@]}"; do
  [[ -n "${RETIRED[$id]:-}" ]] \
    || UNRECORDED+=("$id — superseded by ${LEDGER_RETIRED[$id]}")
done
declare -a UNBACKED=()
for id in "${!RETIRED[@]}"; do
  [[ -n "${LEDGER_RETIRED[$id]:-}" ]] \
    || UNBACKED+=("$id — retired by ${RETIRED[$id]} here, and by no decision there")
done

if [[ ${#UNRECORDED[@]} -gt 0 ]]; then
  echo "coverage: a landed decision retires a requirement that docs/DESIGN.oracle.done.md does not record:" >&2
  printf '  %s\n' "$(printf '%s\n' "${UNRECORDED[@]}" | sort -V)" >&2
  cat >&2 <<'MSG'

The ledger is append-only, so the retirement cannot be recorded there. Until it
is recorded, this script must treat the id as a live requirement of the design —
which reports it unplanned forever and sends the delivery loop to commission
planning for a behaviour that is deliberately not being built.

Append one line per id to docs/DESIGN.oracle.done.md:

  - `R<n>` — retired by `OD-<n>`, replaced by `R<m>` — YYYY-MM-DD — why it went

Write "no replacement" in place of the replacement clause where nothing took
the behaviour over.
MSG
  exit 2
fi

if [[ ${#UNBACKED[@]} -gt 0 ]]; then
  echo "coverage: docs/DESIGN.oracle.done.md retires an id no landed decision supersedes:" >&2
  printf '  %s\n' "$(printf '%s\n' "${UNBACKED[@]}" | sort -V)" >&2
  cat >&2 <<'MSG'

That file RECORDS retirements; it does not make them. Retiring a requirement is
a decision — evidenced, gated, and naming the vision statement it leaned on — so
it happens in docs/DESIGN.oracle.md and nowhere else.

Without this refusal one appended line would remove a requirement from the
design's universe, and "every requirement is covered by a plan" would become
true by emptying the design.

Either write the decision that retires it, or remove the line.
MSG
  exit 2
fi

if [[ ${#RETIRED[@]} -gt 0 ]]; then
  mapfile -t REQS < <(
    for id in "${REQS[@]}"; do [[ -z "${RETIRED[$id]:-}" ]] && echo "$id"; done
  )
fi

# id -> space-separated list of plan slugs claiming it
declare -A CLAIMED=()
declare -a UNKNOWN=()
declare -a MALFORMED=()
declare -a UNSLICED=()
declare -a EXPECTED_ABSENCES=()
declare -a RETIRED_CLAIMS=()
declare -A DELIVERED=()
if [[ -d "$PLANS_DIR" ]]; then
  while IFS= read -r file; do
    [[ "$(basename "$file")" == _* ]] && continue
    plan="$(basename "$file" .md)"
    covers="$(awk '
      NR==1 && $0=="---" { infm = 1; next }
      infm && $0=="---"  { exit }
      infm && /^covers:/ { sub(/^covers:[[:space:]]*/, ""); gsub(/[][,]/, " "); print; exit }
    ' "$file")"
    # DELIVERED IS COMPUTED, NEVER WRITTEN DOWN. `status:` is already in the
    # plan template's vocabulary (draft | in-flight | merged) and
    # deliver-phase.sh already reads it to decide whether a plan still needs
    # building. Recording delivery a second time by hand would be two sources
    # for one fact that can disagree, which is the shape of nearly every defect
    # in this project's log.
    #
    # It is a declaration and not a proof, which is the honest description of
    # it. What makes it worth reporting is where it lives: docs/plans/ is
    # CODEOWNERS-owned, so setting the word is the owner's.
    status="$(awk '
      NR==1 && $0=="---" { infm = 1; next }
      infm && $0=="---"  { exit }
      infm && /^status:/ { sub(/^status:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/["'"'"']/, ""); print; exit }
    ' "$file")"

    # Which of the ids this plan CLAIMS does its own slice text ever mention?
    # From the first slice heading onward, so the summary's prose — which
    # legitimately restates the covers list — cannot satisfy the check on the
    # body's behalf. An id a plan claims and never speaks of again is the
    # over-claim this reports.
    sliced="$(awk '
      /^#+[[:space:]]*Slice[[:space:]]/ { inslices = 1 }
      inslices {
        line = $0
        n = split(line, parts, /[^A-Za-z0-9]+/)
        for (i = 1; i <= n; i++) if (parts[i] ~ /^R[0-9]+$/) print parts[i]
      }' "$file" | sort -u)"
    for id in $covers; do
      # Same rule as the design side, and for the same reason: an id this cannot
      # parse must not be quietly dropped. It was, and a plan covering `R2a`
      # counted for nothing while looking like it counted for something.
      if [[ ! "$id" =~ ^R[0-9]+$ ]]; then
        MALFORMED+=("$id (in $plan)")
        continue
      fi
      # A retired id is not in the universe any more, so without this it would
      # fall into "ids the design doesn't define" — which reads as a typo and is
      # not one. Naming it as a retirement is the whole point: this is the
      # over-claim the false gap used to pressure authors into writing.
      if [[ -n "${RETIRED[$id]:-}" ]]; then
        RETIRED_CLAIMS+=("$id (in $plan) — retired by ${RETIRED[$id]}")
        continue
      fi
      if printf '%s\n' "${REQS[@]}" | grep -qx "$id"; then
        CLAIMED["$id"]="${CLAIMED[$id]:-}${CLAIMED[$id]:+ }$plan"
        [[ "$status" == "merged" ]] && DELIVERED["$id"]="$plan"
        if ! grep -qxF "$id" <<<"$sliced"; then
          if [[ -n "${NONFUNCTIONAL[$id]:-}" ]]; then
            EXPECTED_ABSENCES+=("$id (in $plan) — marked non-functional")
          else
            UNSLICED+=("$id (in $plan)")
          fi
        fi
      else
        UNKNOWN+=("$id (in $plan)")
      fi
    done
    # No -maxdepth: plans also live in subdirectories (docs/plans/oracle/),
    # and a depth limit made those invisible to coverage — silently, which is
    # the worst way for a coverage report to be wrong.
  done < <(find "$PLANS_DIR" -name '*.md' | sort)
fi

if [[ ${#MALFORMED[@]} -gt 0 ]]; then
  echo "coverage: malformed id(s) in a plan's covers: field:" >&2
  printf '  %s\n' "${MALFORMED[@]}" >&2
  echo >&2
  echo "An id is R followed by digits. One that is not can never match a" >&2
  echo "requirement, so the plan claims coverage it will never be credited with." >&2
  exit 2
fi

echo "===== REQUIREMENT COVERAGE ====="
echo
covered=0
declare -a GAPS=()
for id in "${REQS[@]}"; do
  if [[ -n "${CLAIMED[$id]:-}" ]]; then
    printf '  %-5s covered by  %s\n' "$id" "${CLAIMED[$id]}"
    covered=$((covered + 1))
  else
    printf '  %-5s NOT PLANNED\n' "$id"
    GAPS+=("$id")
  fi
done

echo
echo "Covered: ${covered}/${#REQS[@]}"

if [[ ${#UNKNOWN[@]} -gt 0 ]]; then
  echo
  echo "Plans covering ids the design doesn't define:"
  printf '  %s\n' "${UNKNOWN[@]}"
  echo "  (a renumbered requirement or a typo — one of the two is wrong)"
fi

# ------------------------------------------------------- plan adequacy (NOTE)
# Reported, never failed, on the owner's ruling — "yes, note, not red." A
# requirement legitimately owned by no single slice is common enough that a
# strict check would fire on honest plans and teach authors to pad slice text
# with ids, which would make the report worthless in exactly the way that keeps
# a green pipeline meaningless.
echo
echo "----- plan adequacy (a NOTE, never a failure) -----"
if [[ ${#UNSLICED[@]} -gt 0 ]]; then
  echo
  echo "Claimed by a plan, mentioned by none of its slices:"
  printf '  %s\n' "${UNSLICED[@]}"
  echo
  echo "  'Covered' means a plan NAMED the id. Nothing else compares that claim"
  echo "  to what the plan's slices build, so a plan naming twelve requirements"
  echo "  and building three passes every gate green. Either a slice delivers"
  echo "  each id above and should say so, or the covers: list is over-claimed."
else
  echo "  Every claimed requirement is mentioned by a slice of the plan claiming it."
fi
if [[ ${#EXPECTED_ABSENCES[@]} -gt 0 ]]; then
  echo
  echo "Expected absences (marked *(non-functional)* in the design):"
  printf '  %s\n' "${EXPECTED_ABSENCES[@]}"
  echo "  A platform, offline, privacy or cost requirement is owned by no single"
  echo "  slice by nature. Listed so the absence reads as a decision."
fi

# ------------------------------------------------------------ what is DELIVERED
# Reported next to the coverage count because "covered" has never meant built,
# and the report said so in a closing note nobody reads. A requirement whose plan
# declares itself merged is the strongest statement this script can make.
echo
printf 'Delivered: %s/%s (a merged plan claims it — "covered" above means PLANNED)\n' \
  "${#DELIVERED[@]}" "${#REQS[@]}"
if [[ ${#DELIVERED[@]} -gt 0 ]]; then
  for id in $(printf '%s\n' "${!DELIVERED[@]}" | sort -V); do
    printf '  %s — %s\n' "$id" "${DELIVERED[$id]}"
  done
fi

if [[ ${#RETIRED[@]} -gt 0 ]]; then
  echo
  echo "Retired (no longer part of the design), per docs/DESIGN.oracle.done.md:"
  for id in $(printf '%s\n' "${!RETIRED[@]}" | sort -V); do
    if [[ -n "${REPLACED_BY[$id]:-}" ]]; then
      printf '  %s — retired by %s, replaced by %s\n' \
        "$id" "${RETIRED[$id]}" "${REPLACED_BY[$id]}"
    else
      printf '  %s — retired by %s, with no replacement\n' "$id" "${RETIRED[$id]}"
    fi
  done
  echo "  The ledger is append-only, so the decision retiring these stays on its"
  echo "  page forever and the id reads like a live requirement. Listed here so"
  echo "  the retirement reads as a decision rather than a disappearance."
fi

if [[ ${#RETIRED_CLAIMS[@]} -gt 0 ]]; then
  echo
  echo "Claimed by a plan, and retired by a decision:"
  printf '  %s\n' "${RETIRED_CLAIMS[@]}"
  echo "  'covers:' reads as 'this plan delivers this id', and a retired id's"
  echo "  behaviour is deliberately not being built — so the claim is false the"
  echo "  day it is written. Drop it from the covers: list, or name the"
  echo "  requirement that replaced it."
fi

if [[ ${#GAPS[@]} -gt 0 ]]; then
  echo
  echo "${#GAPS[@]} requirement(s) with no plan: ${GAPS[*]}"
  echo "Mid-project this is normal — it is the list of what to plan next."
  exit 1
fi

echo
echo "Every requirement is covered by a plan."
echo "Note: covered means PLANNED, not delivered and not verified. Whether the"
echo "built system satisfies the success criteria is the acceptance pass —"
echo "see docs/acceptance.md."
exit 0
