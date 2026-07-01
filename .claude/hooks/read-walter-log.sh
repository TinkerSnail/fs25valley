#!/bin/bash
# Verified log reader: ALWAYS run this instead of grepping log.txt directly. It refuses to print
# log data unless verify-build.sh confirms the running FS25 session loaded the currently-packed
# build. This makes "analyzing a stale build" impossible — the single most repeated failure of
# 2026-06-20/21.
#
# Usage:  read-walter-log.sh [grep-pattern] [tail-count]
#   pattern    : extended-regex to grep for in the live log (default: all [ValleyLife][Walter] lines)
#   tail-count : how many matching lines to show (default: 25)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_common.sh"
LOG="$(fs25_base)/log.txt"
PATTERN="${1:-\[ValleyLife\]\[Walter\]}"
TAIL="${2:-25}"

# Freshness gate first — refuse on stale.
if ! "$HERE/verify-build.sh"; then
  echo "" >&2
  echo "REFUSING to read log: running build is STALE (or FS25 not running). Relaunch FS25, then retry." >&2
  exit 1
fi

echo ""
echo "=== live log.txt matches for /$PATTERN/ (last $TAIL) ==="
grep -E "$PATTERN" "$LOG" | tail -"$TAIL" | sed 's/.*\[ValleyLife\]\[Walter\] /[Walter] /'
