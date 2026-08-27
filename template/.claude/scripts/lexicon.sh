#!/usr/bin/env bash
#
# lexicon.sh — the loop's vocabularies, defined once (ESC-225).
#
# Six independent readings of one brief about the 2026-08-20 runs answered
# its headline question anywhere from ~1% to ~50% — because the judgment
# words were never defined and every reader built a private yardstick. The
# factory's own agents read the command files the same way those readers
# read that brief, and its scripts had already grown two verdict spellings
# and two decision schemas. This file is the correction at the layer where
# it is enforceable: the MACHINE vocabularies, sourced by the scripts that
# speak them and pinned by a drift test (tests/test-lexicon.sh) so a new
# phase, event kind or risk class cannot ship as a private spelling.
#
# Sourceable, side-effect-free, `set -u`-clean. Prose definitions of the
# judgment words (uncertainty, derivation vs guess, escalation) live where
# prose belongs — AGENTS.md and the command files — and each of THOSE files
# defers to the lists here for the machine words.

# The phases the detector may emit and the driver may branch on. The order
# here is documentation only; the precedence lives in deliver-phase.sh.
LOOP_PHASES="WAIT ORACLE STEWARD PLAN ORCHESTRATE ACCEPTANCE SETUP"

# The event kinds the machine record carries (emit-event.sh refuses others).
LOOP_EVENT_KINDS="start detect dispatch result merge stop"

# The risk classes a filed uncertainty may carry. HIGH blocks until a ruling
# cites it; LOW proceeds on the recorded default and may be closed by a
# one-line clearance. There is deliberately no MEDIUM: a class nobody can
# act on differently is a word, not a class.
LOOP_RISK_CLASSES="HIGH LOW"

# The dispositions a ledger decision may end in (oracle-decisions.sh
# enforces that every new decision has one).
LOOP_DISPOSITIONS="added superseded waived halted closure"

# The verdict pair every gate reports in. Downstream one lane wrote PASS and
# the other wrote success for the same fact, and the reconciliation needed
# two parsers.
LOOP_VERDICTS="PASS FAIL"

export LOOP_PHASES LOOP_EVENT_KINDS LOOP_RISK_CLASSES LOOP_DISPOSITIONS LOOP_VERDICTS
