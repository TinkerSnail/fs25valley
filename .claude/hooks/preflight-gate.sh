#!/bin/bash
# PreToolUse failsafe: you cannot edit mod code (*.lua) until you've done a session preflight —
# i.e. read the relevant journals/memory and written a fresh .claude/.preflight note recording
# WHICH journals/memory you consulted and the EXISTING approach they describe. This forces the
# single step that would have prevented the Walter ordeal: check whether the answer is already
# written down (and whether a sibling feature already does this) BEFORE writing new code.
#
# The .preflight must be newer than .claude/.session-start (dropped by the SessionStart hook),
# so a stale note from a previous session does not count. Once written, all edits this session
# pass — it gates only the first code edit per session.
#
# Exit 2 = block and feed the message back to the model.
set -euo pipefail

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')"

# Only gate mod Lua source.
case "$FILE" in
  *.lua) ;;
  *) exit 0 ;;
esac

PROJ="${CLAUDE_PROJECT_DIR:-/Users/christina/Dropbox/Mac/Documents/FS25Valley}"
START="$PROJ/.claude/.session-start"
PRE="$PROJ/.claude/.preflight"

# No session marker → cannot anchor the check; allow rather than block work spuriously.
[ -f "$START" ] || exit 0

start_m=$(stat -f %m "$START")
pre_m=0
[ -f "$PRE" ] && pre_m=$(stat -f %m "$PRE")

if [ "$pre_m" -lt "$start_m" ]; then
  echo "BLOCKED: session preflight not done. Before editing mod code this session you must:" >&2
  echo "  1. Read journals/README.md and the journals relevant to this task (NPC/anim → npc-movement.md + lifecycle-and-hooks.md)." >&2
  echo "  2. Read the relevant memory files, and check whether a SIBLING feature already does this (e.g. NPCEntity/Marta)." >&2
  echo "  3. Write $PRE listing: which journals/memory you read, the existing approach they describe, and why the new work differs." >&2
  echo "Then retry. (This gates only the FIRST code edit per session.)" >&2
  exit 2
fi
exit 0
