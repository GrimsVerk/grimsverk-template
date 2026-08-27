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
# THE UNIVERSE IS WHAT THE PROJECT STILL HAS TO SATISFY. Both design documents
# are append-only, so a requirement that turns out wrong cannot be edited away —
# it stays on its page forever and goes on reading like a live requirement. The
# ids the OWNER has retired in docs/DESIGN.oracle.retired.md are subtracted here
# and reported, never treated as a gap: otherwise a permanent "NOT PLANNED"
# reports a script limitation as unscheduled work, and the delivery loop, which
# dispatches a planner for every gap, livelocks on one (ESC-200).
#
# Retiring is the owner's alone (ESC-203). An agent may SUGGEST one, in a file
# under docs/oracle/ that nothing reads but the owner — deliberately not named
# here, because a mention is how a read starts and a test asserts this script
# does not carry one. A suggestion that excused a requirement from this report
# would let an agent take work off its own list by declaring the work
# unnecessary.
#
# IT ALSO REPORTS WHAT SHIPPED, from docs/DESIGN.oracle.done.md, which the
# driver writes from merged pull requests. "Covered" has never meant built, and
# a planner had no other way to find out.
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

# ------------------------------------------ retired ids: the owner's, and only
# Both design documents are append-only, so a requirement that turns out to be
# wrong cannot be edited away — it stays on its page reading exactly like a live
# requirement forever. Counting it as one is not a cosmetic wrong number: the
# delivery driver commissions planning for every gap this script reports, so a
# permanent gap dispatched a planner for the dead requirement every cycle and
# the loop could never walk past it. A full unattended session per turn,
# observed live.
#
# docs/DESIGN.oracle.retired.md is the answer, and it is the OWNER'S file.
# owner-authored.sh requires their authorship of the pull request, not their
# approval — the same lock docs/DESIGN.md carries, for a sharper reason: a line
# here REMOVES a requirement from what the project has to satisfy, which is the
# one route to green that costs a sentence instead of work.
#
# Nothing else grants it. An earlier design let a landed oracle decision retire
# a requirement, and a second let an oracle SUGGESTION excuse one from this
# report — both handed an agent the power to take work off its own list by
# declaring the work unnecessary. A suggestion is now written where only the
# owner reads it, and reaches nothing here.
#
# Column-anchored, like every other ledger rule here, so the file's own indented
# format example retires nothing in a freshly rendered project.
RETIRED_DOC="$ROOT/docs/DESIGN.oracle.retired.md"
declare -A RETIRED=()        # retired id -> the date the owner retired it
if [[ -f "$RETIRED_DOC" ]]; then
  while IFS=$'\t' read -r id when; do
    [[ -n "$id" ]] || continue
    RETIRED["$id"]="${when:-date not given}"
  done < <(awk '
    /^[-*][[:space:]]+`R[0-9]+`/ {
      line = $0
      if (!match(line, /`R[0-9]+`/)) next
      id = substr(line, RSTART + 1, RLENGTH - 2)
      rest = substr(line, RSTART + RLENGTH)
      when = ""
      if (match(rest, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/))
        when = substr(rest, RSTART, RLENGTH)
      print id "\t" when
    }' "$RETIRED_DOC")
fi

if [[ ${#RETIRED[@]} -gt 0 ]]; then
  mapfile -t REQS < <(
    for id in "${REQS[@]}"; do [[ -z "${RETIRED[$id]:-}" ]] && echo "$id"; done
  )
fi

# ------------------------------------- superseded ids: read, never subtracted
# The decision schema REQUIRES every decision to carry a `**Requirements
# superseded:**` line, and until ESC-219 nothing read it — a mandated
# write-only field. The cost was not cosmetic: one correct supersession left a
# permanent "NOT PLANNED" gap, the delivery driver dispatched a planner for
# the dead id every cycle, and the loop livelocked (the same shape ESC-200
# records). A field agents must write and nothing reads is the exact kind of
# gate this template distrusts everywhere else.
#
# WHAT READING IT MAY AND MAY NOT DO is bounded by the owner's ruling above
# (ESC-203): retiring — removing an id from what the project must satisfy —
# is the owner's alone, in docs/DESIGN.oracle.retired.md. So a superseded id
# is NOT subtracted from the universe and NOT counted covered. It moves from
# the DISPATCHABLE gap list to its own reported class, "superseded — awaiting
# the owner's retirement ruling": the delivery loop stops burning a session
# per cycle on work a landed decision says is dead, while the id stays in
# this report, in the run report, and on the owner's desk. The report keeps
# it; only the owner removes it.
#
# Sequential, in document order, because the ledger is append-only and
# therefore chronological: a later decision that re-ADDS a superseded id
# revives it (the last declaration wins), so a supersession is never a
# one-way door an agent can shut by accident. Same column-anchored
# declaration-line rule as the id collection above, for the same ESC-82
# reason.
declare -A SUPERSEDED=()     # superseded id -> the OD that superseded it
while IFS=$'\t' read -r verb id od; do
  [[ -n "$id" ]] || continue
  case "$verb" in
    add)  unset 'SUPERSEDED[$id]' 2>/dev/null || true ;;
    drop) SUPERSEDED["$id"]="${od:-a landed decision}" ;;
  esac
done < <(
  for doc in "${PRESENT[@]}"; do
    awk '
      /^## OD-[0-9]+/ { od = $2; sub(/[^A-Za-z0-9-].*$/, "", od) }
      /^[-*] \*\*Requirements added:\*\*/ || /^[-*] \*\*Requirements superseded:\*\*/ {
        verb = ($0 ~ /superseded/) ? "drop" : "add"
        line = $0
        sub(/^.*:\*\*/, "", line)
        n = split(line, parts, /[^A-Za-z0-9]+/)
        for (i = 1; i <= n; i++) if (parts[i] ~ /^R[0-9]+$/)
          print verb "\t" parts[i] "\t" od
      }' "$doc"
  done
)

# ------------------------------------------------ delivered ids: what SHIPPED
# "Covered" has never meant built, and this report's own closing note said so
# where nobody reads it. A planner therefore had no way to tell which
# requirements were already live: a plan's `status:` field is the nearest thing
# and it is set by hand, so on a real project every plan still read
# `status: draft` long after its work had shipped.
#
# docs/DESIGN.oracle.done.md answers it from the one fact that cannot go stale —
# a merged pull request — and the driver writes it, not a person.
DONE_DOC="$ROOT/docs/DESIGN.oracle.done.md"
declare -A DELIVERED=()      # delivered id -> what landed it
if [[ -f "$DONE_DOC" ]]; then
  while IFS=$'\t' read -r id what; do
    [[ -n "$id" ]] || continue
    DELIVERED["$id"]="${what:-landed}"
  done < <(awk '
    /^[-*][[:space:]]+`R[0-9]+`/ {
      line = $0
      if (!match(line, /`R[0-9]+`/)) next
      id = substr(line, RSTART + 1, RLENGTH - 2)
      rest = substr(line, RSTART + RLENGTH)
      what = ""
      if (match(rest, /(PR #[0-9]+|plan `[^`]+`)/)) {
        what = substr(rest, RSTART)
        sub(/[[:space:]]+$/, "", what)
      }
      print id "\t" what
    }' "$DONE_DOC")
fi

# id -> space-separated list of plan slugs claiming it
declare -A CLAIMED=()
declare -a UNKNOWN=()
declare -a MALFORMED=()
declare -a UNSLICED=()
declare -a EXPECTED_ABSENCES=()
declare -a RETIRED_CLAIMS=()
if [[ -d "$PLANS_DIR" ]]; then
  while IFS= read -r file; do
    [[ "$(basename "$file")" == _* ]] && continue
    plan="$(basename "$file" .md)"
    covers="$(awk '
      NR==1 && $0=="---" { infm = 1; next }
      infm && $0=="---"  { exit }
      infm && /^covers:/ { sub(/^covers:[[:space:]]*/, ""); gsub(/[][,]/, " "); print; exit }
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
        RETIRED_CLAIMS+=("$id (in $plan) — retired by the owner, ${RETIRED[$id]}")
        continue
      fi
      if printf '%s\n' "${REQS[@]}" | grep -qx "$id"; then
        CLAIMED["$id"]="${CLAIMED[$id]:-}${CLAIMED[$id]:+ }$plan"
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
declare -a SUPERSEDED_OPEN=()
for id in "${REQS[@]}"; do
  if [[ -n "${CLAIMED[$id]:-}" ]]; then
    printf '  %-5s covered by  %s\n' "$id" "${CLAIMED[$id]}"
    covered=$((covered + 1))
  elif [[ -n "${SUPERSEDED[$id]:-}" ]]; then
    printf '  %-5s superseded by %s — awaiting the owner'\''s retirement ruling\n' \
      "$id" "${SUPERSEDED[$id]}"
    SUPERSEDED_OPEN+=("$id (by ${SUPERSEDED[$id]})")
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

# --------------------------------------------------- delivered, and retired
# Both reported next to the coverage count, because "covered" has never meant
# built and the closing note that said so was where nobody reads it.
echo
printf 'Delivered: %s/%s (built and merged — "covered" above means PLANNED)\n' \
  "${#DELIVERED[@]}" "${#REQS[@]}"
if [[ ${#DELIVERED[@]} -gt 0 ]]; then
  for id in $(printf '%s\n' "${!DELIVERED[@]}" | sort -V); do
    printf '  %s — %s\n' "$id" "${DELIVERED[$id]}"
  done
fi

if [[ ${#RETIRED[@]} -gt 0 ]]; then
  echo
  echo "Retired by the owner, per docs/DESIGN.oracle.retired.md:"
  for id in $(printf '%s\n' "${!RETIRED[@]}" | sort -V); do
    printf '  %s — retired %s\n' "$id" "${RETIRED[$id]}"
  done
  echo "  Both design documents are append-only, so the text defining these"
  echo "  stays on its page forever and the id goes on reading like a live"
  echo "  requirement. Listed here so the retirement reads as a decision"
  echo "  rather than a disappearance."
fi

if [[ ${#RETIRED_CLAIMS[@]} -gt 0 ]]; then
  echo
  echo "Claimed by a plan, and retired by the owner:"
  printf '  %s\n' "${RETIRED_CLAIMS[@]}"
  echo "  'covers:' reads as 'this plan delivers this id', and a retired id is"
  echo "  no longer required of the project — so the claim is false the day it"
  echo "  is written. Drop it from the covers: list, or name the requirement"
  echo "  that replaced it."
fi

if [[ ${#SUPERSEDED_OPEN[@]} -gt 0 ]]; then
  echo
  echo "Superseded by a landed decision, awaiting the owner's retirement ruling:"
  printf '  %s\n' "${SUPERSEDED_OPEN[@]}"
  echo "  Not a gap to plan — the decision that superseded each id is landed and"
  echo "  gated (ESC-219) — and not gone either: only the owner retires an id"
  echo "  from the universe (docs/DESIGN.oracle.retired.md, ESC-203). Listed"
  echo "  here, every run, until they rule."
fi

if [[ ${#GAPS[@]} -gt 0 ]]; then
  echo
  echo "${#GAPS[@]} requirement(s) with no plan: ${GAPS[*]}"
  echo "Mid-project this is normal — it is the list of what to plan next."
  exit 1
fi

echo
if [[ ${#SUPERSEDED_OPEN[@]} -gt 0 ]]; then
  echo "Every requirement is covered by a plan, except the superseded ids listed"
  echo "above, which wait on the owner's retirement ruling rather than on a plan."
else
  echo "Every requirement is covered by a plan."
fi
echo "Note: covered means PLANNED, not delivered and not verified. Whether the"
echo "built system satisfies the success criteria is the acceptance pass —"
echo "see docs/acceptance.md."
exit 0
