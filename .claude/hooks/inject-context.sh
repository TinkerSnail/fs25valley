#!/bin/bash
# SessionStart failsafe: force the project's distilled knowledge into context every session, so
# work can never start cold. The JOURNALS are loaded first because they are the engine knowledge
# and OFTEN ALREADY CONTAIN THE ANSWER (the Walter walk fix lived in them, unread, for ~17 attempts).
# Output goes to the model as additionalContext. Also drops a .session-start marker the preflight
# gate keys off (you cannot edit code until you've written a .preflight note this session).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_common.sh"

# Repo root: prefer the env Claude Code sets, else derive from this script's location (.claude/hooks).
PROJ="${CLAUDE_PROJECT_DIR:-$(cd "$HERE/../.." && pwd)}"
# Memory now lives IN the repo so it syncs across machines via git (was ~/.claude on the Mac).
MEM="$PROJ/memory"
JRN="$PROJ/journals"

emit() {
  if [ -f "$1" ]; then
    printf '\n===== %s =====\n' "$2"
    cat "$1"
  fi
}

BODY="$(
  printf 'MANDATORY: read the relevant journals/ files for THIS task BEFORE touching code, then write a .claude/.preflight note (the preflight gate blocks code edits until you do). The journals below are the distilled engine knowledge and frequently already contain the solution.\n'

  # Journals — index first so you know everything that exists, then the high-value engine ones.
  emit "$JRN/README.md"               "journals/README.md (INDEX — read the ones relevant to the task)"
  emit "$JRN/npc-movement.md"         "journals/npc-movement.md (walk loop, walk anim, direct tracks)"
  emit "$JRN/lifecycle-and-hooks.md"  "journals/lifecycle-and-hooks.md (mission hooks, NPC spawn/anim, gfx:update rule)"
  emit "$JRN/development-process.md"   "journals/development-process.md (.claude failsafes, the gates)"

  # Memory.
  emit "$MEM/MEMORY.md"                "MEMORY.md (index — read relevant memory files too)"
  emit "$MEM/walter_walker_history.md" "walter_walker_history.md (R-table + attempt log)"
  emit "$MEM/feedback_session_start.md" "session start protocol"
)"

# Drop the per-session marker used by the preflight gate.
mkdir -p "$PROJ/.claude"
date +%s > "$PROJ/.claude/.session-start" 2>/dev/null || true

# Wrap as SessionStart additionalContext so it is injected, not just printed.
# Pass via a file (--rawfile), not --arg: the journals can exceed the command-line
# argument-length limit on Windows (Git Bash), which fails with "Argument list too long".
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
printf '%s' "$BODY" > "$TMP"
jq -n --rawfile ctx "$TMP" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
