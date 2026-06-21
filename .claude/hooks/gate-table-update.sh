#!/bin/bash
# PreToolUse failsafe: enforce that each ATTEMPT's result is recorded in the R-table before the
# NEXT attempt's code edits begin. An "attempt" = a build that gets TESTED (loaded by FS25), not a
# single edit. So: unlimited code edits while assembling one build, but once you relaunch and TEST
# a build, you must record its result (code-change summary + reported visual outcome) before editing
# WalterWalker.lua again.
#
# Trigger signal = FS25's mod-load time in the LIVE log (log.txt), NOT the code file's mtime.
# Block iff: a build was loaded/tested MORE RECENTLY than the last update to walter_walker_history.md.
#
# Exit 2 = block the tool call and feed the message back to the model.
set -euo pipefail

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')"

case "$FILE" in
  *WalterWalker.lua) ;;   # only gate the Walter build file
  *) exit 0 ;;
esac

HIST="/Users/christina/.claude/projects/-Users-christina-Dropbox-Mac-Documents-FS25Valley/memory/walter_walker_history.md"
LOG="$HOME/Library/Application Support/FarmingSimulator2025/log.txt"

[ -f "$HIST" ] || exit 0          # no table yet → allow
[ -f "$LOG" ]  || exit 0          # no running/last session info → allow (nothing tested)

# When did FS25 last LOAD (i.e. test) a build?
load_line="$(grep -m1 'Load mod: FS25_ValleyLife' "$LOG" 2>/dev/null || true)"
[ -n "$load_line" ] || exit 0     # mod not loaded in current session yet → allow

load_ts="$(printf '%s' "$load_line" | cut -c1-19)"                       # 2026-06-21 03:34:36
load_epoch=$(date -j -f '%Y-%m-%d %H:%M:%S' "$load_ts" +%s 2>/dev/null || echo 0)
hist_mtime=$(stat -f %m "$HIST")

if [ "$load_epoch" -gt "$hist_mtime" ]; then
  echo "BLOCKED: FS25 loaded/tested a build at $load_ts, but walter_walker_history.md has not been updated since." >&2
  echo "Record that attempt's RESULT — a summary of the code changes AND the visual outcome the user reported —" >&2
  echo "as an R# row in walter_walker_history.md BEFORE editing WalterWalker.lua again." >&2
  echo "(Multiple code edits within ONE not-yet-tested build are fine; this only blocks after a build was tested.)" >&2
  exit 2
fi
exit 0
