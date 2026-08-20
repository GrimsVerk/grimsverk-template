#!/usr/bin/env bash
#
# collect-evidence.sh — fixture tests.
#
# The defect this repairs: an unattended run produced a run log that was
# gitignored, in a container that gets reclaimed, and a review gate that
# assembled a payload, sent it to a model, and threw both away. So the evidence
# that would tell the next run what went wrong was destroyed by default.
#
# Two things have to hold for the repair to be worth anything, and one of them
# is easy to get wrong:
#
#   - what it collects lands where the driver said, with an index a human can
#     read;
#   - a review that ran but whose artifact cannot be fetched leaves a MARKER,
#     not a silent gap. "No evidence" and "no review" look identical otherwise,
#     and only one of them is a problem.
#
# Plus the recorder's own contract: it never fails the run. A recorder that
# fails a run because there was nothing to record has inverted its job.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SCRIPT="$HERE/../template/.claude/scripts/collect-evidence.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== collect-evidence.sh ==="

R="$WORK/repo"
init_repo "$R"
echo seed > "$R/README.md"
git -C "$R" add -A && git -C "$R" commit -qm seed

mkdir -p "$WORK/bin"

# A gh stub. RUNS is the TSV the real `gh run list --jq ... | @tsv` produces;
# ARTIFACTS is a directory per run id, or absent to simulate an expired one.
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "run list "*) printf '%s\n' "$STUB_RUNS" ;;
  "run download "*)
    id="$3"; dest=""
    while [[ $# -gt 0 ]]; do [[ "$1" == "--dir" ]] && dest="$2"; shift; done
    [[ -d "$STUB_ARTIFACTS/$id" ]] || exit 1
    mkdir -p "$dest/review-artifact"
    cp -r "$STUB_ARTIFACTS/$id/." "$dest/review-artifact/"
    ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$WORK/bin/gh"

mk_artifact() { # mk_artifact <run-id> <verdict>
  mkdir -p "$WORK/artifacts/$1"
  echo "$2" > "$WORK/artifacts/$1/verdict.txt"
  printf 'the payload the reviewer was shown for run %s\n' "$1" > "$WORK/artifacts/$1/payload.txt"
  printf 'findings...\nREVIEW_VERDICT: %s\n' "$2" > "$WORK/artifacts/$1/reply.txt"
  printf 'head: deadbeef\n' > "$WORK/artifacts/$1/meta.txt"
}

run() { ( cd "$R" && GH="$WORK/bin/gh" STUB_RUNS="$STUB_RUNS" \
  RUN_BASE="${RUN_BASE:-}" \
  STUB_ARTIFACTS="$WORK/artifacts" bash "$SCRIPT" "$@" 2>&1 ); }

# ------------------------------------------------------- nothing to collect
STUB_RUNS=""
out="$(run --run-dir docs/runs/T1)"
expect_rc "no runs at all is not a failure" 0 $?
expect_contains "and it says so" "$out" "no runs of review.yml"

# ------------------------------------------------------ two completed reviews
mk_artifact 101 PASS
mk_artifact 102 BLOCK
STUB_RUNS="$(printf '%s\n' \
  "101	2026-08-18T10:00:00Z	aaaaaaaaaaaaaaaa	feat/notes	success	completed" \
  "102	2026-08-18T11:00:00Z	bbbbbbbbbbbbbbbb	feat/sync	failure	completed")"
out="$(run --run-dir docs/runs/T2)"
expect_rc "collecting two reviews succeeds" 0 $?
expect_contains "and counts them" "$out" "2 review(s)"

D="$R/docs/runs/T2/reviews"
for f in feat-notes-aaaaaaaaaaaa/payload.txt feat-notes-aaaaaaaaaaaa/reply.txt \
         feat-sync-bbbbbbbbbbbb/verdict.txt index.md; do
  if [[ -s "$D/$f" ]]; then ok "$f is collected"; else no "$f is collected"; fi
done

# The payload is what makes reviewer fixtures possible at all, so it has to be
# the real thing rather than a placeholder the collector invented.
expect_contains "the payload is the payload, not a summary" \
  "$(cat "$D/feat-notes-aaaaaaaaaaaa/payload.txt")" "the payload the reviewer was shown"

idx="$(cat "$D/index.md")"
expect_contains "the index names the branch" "$idx" "feat/notes"
expect_contains "and carries the verdict, not just the CI conclusion" "$idx" "BLOCK"
expect_contains "and links the directory" "$idx" "feat-sync-bbbbbbbbbbbb"

# The artifact arrives inside a subdirectory of its own; the paths the index
# points at have to be the paths that exist.
if [[ -f "$D/feat-notes-aaaaaaaaaaaa/verdict.txt" ]]; then
  ok "the artifact subdirectory is flattened"
else
  no "the artifact subdirectory is flattened" "$(find "$D" -maxdepth 3 | head -10)"
fi

# ------------------------------------------- a missing artifact leaves a marker
# The one that matters. An expired artifact, a job that died before uploading,
# a run whose upload step never fired — all produce no files, and a collector
# that stayed quiet would make those indistinguishable from "the gate never
# ran". Only one of those is a problem, and the run report is where somebody
# finds out which.
STUB_RUNS="$(printf '%s\n' "999	2026-08-18T12:00:00Z	cccccccccccccccc	feat/gone	success	completed")"
out="$(run --run-dir docs/runs/T3)"
expect_rc "an unfetchable artifact is still not a failure" 0 $?
marker="$R/docs/runs/T3/reviews/feat-gone-cccccccccccc/MISSING.md"
if [[ -s "$marker" ]]; then
  ok "an unfetchable artifact leaves a marker"
  expect_contains "which says the run happened" "$(cat "$marker")" "The run happened"
  expect_contains "and names the commit" "$(cat "$marker")" "cccccccccccccccc"
else
  no "an unfetchable artifact leaves a marker"
fi

# ---------------------------------------------------------------- --since
# Collection is per RUN, so a repository with months of review history must not
# have all of it swept into one run's directory.
mk_artifact 201 PASS
mk_artifact 202 PASS
STUB_RUNS="$(printf '%s\n' \
  "201	2026-01-01T00:00:00Z	1111111111111111	feat/old	success	completed" \
  "202	2026-08-18T13:00:00Z	2222222222222222	feat/new	success	completed")"
out="$(run --run-dir docs/runs/T4 --since 2026-08-18T09:00:00Z)"
expect_contains "only this run's reviews are collected" "$out" "1 review(s)"
if [[ -d "$R/docs/runs/T4/reviews/feat-new-222222222222" ]]; then
  ok "the review from this run is there"
else no "the review from this run is there"; fi
if [[ ! -d "$R/docs/runs/T4/reviews/feat-old-111111111111" ]]; then
  ok "and an older one is not swept in"
else no "and an older one is not swept in"; fi

# ------------------------------------------------ a run still in flight waits
STUB_RUNS="$(printf '%s\n' "301	2026-08-18T14:00:00Z	3333333333333333	feat/live		in_progress")"
out="$(run --run-dir docs/runs/T5)"
expect_contains "an in-flight review is skipped, not half-collected" "$out" "0 review(s)"

# ------------------------------------------------------------- worker logs
# The per-session logs under .claude/orchestration-logs/ are the only record of
# what a dispatched worker actually did, and they are gitignored where they are
# written — the same evidence-dies-with-the-container defect the run report
# had, fixed for the report and not for the logs feeding it (ESC-42). On the
# first unattended run, every diagnosis came from these files.
mkdir -p "$R/.claude/orchestration-logs"
echo "an old worker's story" > "$R/.claude/orchestration-logs/old-worker.log"
touch -t 202601010000 "$R/.claude/orchestration-logs/old-worker.log"
echo "this run's worker story" > "$R/.claude/orchestration-logs/oracle-1.log"
STUB_RUNS=""
out="$(run --run-dir docs/runs/T6 --since 2026-08-18T09:00:00Z)"
expect_rc "collecting worker logs succeeds" 0 $?
if [[ -s "$R/docs/runs/T6/workers/oracle-1.log" ]]; then
  ok "this run's worker log is collected"
else no "this run's worker log is collected" \
  "$(find "$R/docs/runs/T6" 2>/dev/null | head -5)"; fi
if [[ ! -e "$R/docs/runs/T6/workers/old-worker.log" ]]; then
  ok "and an older run's log is not swept in"
else no "and an older run's log is not swept in"; fi

# Without --since, everything is considered — same rule as the reviews.
out="$(run --run-dir docs/runs/T7)"
if [[ -s "$R/docs/runs/T7/workers/old-worker.log" ]]; then
  ok "no --since collects every log"
else no "no --since collects every log"; fi

# ---------------------------------------------- lane scoping (ESC-54)
# Review runs are listed repo-wide; on a twin-run repository, a lane must
# collect ONLY its own. Observed live: the web lane's run directory held the
# local lane's review payload.
mk_artifact 501 PASS
mk_artifact 502 PASS
STUB_RUNS="$(printf '%s\n' \
  "501	2026-08-18T15:00:00Z	dddddddddddddddd	feat/notes--run-web	success	completed" \
  "502	2026-08-18T15:30:00Z	eeeeeeeeeeeeeeee	feat/notes	success	completed")"
out="$(RUN_BASE=run/web run --run-dir docs/runs/T8)"
expect_rc "a lane collects with RUN_BASE set" 0 $?
if [[ -d "$R/docs/runs/T8/reviews/feat-notes--run-web-dddddddddddd" ]]; then
  ok "the lane's own suffixed branch is collected"
else no "the lane's own suffixed branch is collected" \
  "$(find "$R/docs/runs/T8" 2>/dev/null | head -8)"; fi
if [[ ! -d "$R/docs/runs/T8/reviews/feat-notes-eeeeeeeeeeee" ]]; then
  ok "the OTHER lane's branch is not swept in"
else no "the OTHER lane's branch is not swept in"; fi

# ...and the default lane skips any branch carrying a lane suffix.
out="$(run --run-dir docs/runs/T9)"
expect_rc "the default lane collects without RUN_BASE" 0 $?
if [[ -d "$R/docs/runs/T9/reviews/feat-notes-eeeeeeeeeeee" ]]; then
  ok "the default lane keeps its own unsuffixed branch"
else no "the default lane keeps its own unsuffixed branch" \
  "$(find "$R/docs/runs/T9" 2>/dev/null | head -8)"; fi
if [[ ! -d "$R/docs/runs/T9/reviews/feat-notes--run-web-dddddddddddd" ]]; then
  ok "and skips the suffixed lane branch"
else no "and skips the suffixed lane branch"; fi

# ------------------------------------------------------------- the contract
out="$(run 2>&1)"
expect_rc "no --run-dir is a setup error" 2 $?
expect_contains "and says which argument" "$out" "--run-dir is required"

summary
