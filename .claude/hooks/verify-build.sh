#!/bin/bash
# Build-load verifier: confirms the FS25 session currently logging actually loaded the
# build we last packed — so we never analyze a stale build again. Run this FIRST whenever
# the user says "check".
#
# CRITICAL: FS25 writes the LIVE log to log.txt in the PARENT folder. It only renames it into
# logs/log_<timestamp>.txt on exit. So the running session is ALWAYS log.txt; the logs/ files
# are closed/archived sessions (one build stale). Reading logs/ was the root cause of every
# false STALE on 2026-06-20/21. This script reads log.txt.
set -euo pipefail

BASE="$HOME/Library/Application Support/FarmingSimulator2025"
ZIP="$BASE/mods/FS25_ValleyLife.zip"
LOG="$BASE/log.txt"

[ -f "$LOG" ] || { echo "STALE: live log.txt not found — is FS25 running?"; exit 1; }

# zip pack time (epoch)
zip_epoch=$(stat -f %m "$ZIP")
zip_human=$(stat -f '%Sm' -t '%H:%M:%S' "$ZIP")

# mod-load timestamp from inside the log: "YYYY-MM-DD HH:MM:SS ... Load mod: FS25_ValleyLife"
load_line="$(grep -m1 'Load mod: FS25_ValleyLife' "$LOG" || true)"
if [ -z "$load_line" ]; then
  echo "STALE: live log.txt has not loaded FS25_ValleyLife yet (still in early init?)."
  exit 1
fi
load_ts="$(printf '%s' "$load_line" | cut -c1-19)"          # 2026-06-21 02:24:33
load_epoch=$(date -j -f '%Y-%m-%d %H:%M:%S' "$load_ts" +%s 2>/dev/null || echo 0)

echo "live log:     log.txt (mtime $(stat -f '%Sm' -t '%H:%M:%S' "$LOG"))"
echo "mod loaded:   $load_ts"
echo "zip packed:   $zip_human"

if [ "$load_epoch" -ge "$zip_epoch" ]; then
  echo "RESULT: FRESH — the running session loaded the current build. Safe to analyze."
  exit 0
else
  echo "RESULT: STALE — the running session loaded an OLDER build than what is packed."
  echo "        Do NOT analyze. Tell the user to fully relaunch FS25 first."
  exit 1
fi
