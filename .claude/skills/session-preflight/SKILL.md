---
name: session-preflight
description: Run the mandatory FS25Valley start-of-session research ritual before touching any code — read the task-relevant journals, MEMORY.md + relevant memory files, and prior session transcripts, then write the .claude/.preflight note that satisfies the preflight gate. Use at the start of any session that will edit mod code, or whenever the preflight gate blocks an edit with "session preflight not done".
---

# Session preflight

The project's hooks **enforce** this: the PreToolUse `preflight-gate.sh` blocks the
first `.lua` edit of the session until `.claude/.preflight` exists and is newer than
`.claude/.session-start`. This skill does the research the gate is standing in for —
the single step that would have prevented the Walter ordeal (~17 attempts on a fix that
was already written in the journals). **Do the reading for real. Do not write a
preflight note you haven't earned.**

The task for this session is in the skill arguments (or ask the user if absent).

## Procedure

Work through these in order. Steps 0–3 are research; step 4 writes the note.

### Step 0 — Journals (the engine knowledge; often already contains the answer)
1. Read `journals/README.md` — the index. It tells you every journal that exists and
   what each covers.
2. From the index, pick the journals relevant to **this task** and read them in full.
   - **Anything touching NPC walking / animation → `journals/npc-movement.md` AND
     `journals/lifecycle-and-hooks.md` are mandatory** (direct-track animation; the
     "don't call full `gfx:update()` per NPC per frame" rule that was the R17 fix).
   - Characters/appearance/schedule → `character-systems.md`, `character-appearance.md`,
     `outfits-and-schedule.md`.
   - Walter features → `walter-daily-life.md`, `walter-guided-tour.md`,
     `walter-truck-driving.md`.
   - Sealed-API / reverse-engineering → `engine-api.md`, `game-files-and-xml.md`.
   - The `.claude` failsafes / gates themselves → `development-process.md`.

### Step 1 — Memory
1. Read `MEMORY.md` (path:
   `/Users/christina/.claude/projects/-Users-christina-Dropbox-Mac-Documents-FS25Valley/memory/MEMORY.md`).
2. Read the individual memory files whose index line is relevant to the task. For NPC
   work, `walter_walker_history.md` (the R-table attempt log) is almost always relevant.

### Step 2 — Find relevant prior sessions
```
mcp__ccd_session_mgmt__list_sessions
```
Scan titles/summaries for sessions touching this task or a sibling feature.

### Step 3 — Read the transcripts that matter
Files live at
`~/.claude/projects/-Users-christina-Dropbox-Mac-Documents-FS25Valley/<cliSessionId>.jsonl`.
Parse with:
```python
python3 -c "
import json, sys
for line in open('SESSION.jsonl'):
    try:
        obj = json.loads(line)
        msg = obj.get('message', obj)
        role = msg.get('role','')
        content = msg.get('content','')
        if isinstance(content, list):
            content = ' '.join(c.get('text','') if isinstance(c,dict) else str(c) for c in content)
        if content and len(str(content).strip()) > 10:
            print(f'[{role}] {str(content)[:400]}')
    except: pass
"
```
You're looking for: what was already tried, what the confirmed root cause was, and
whether a **sibling feature already does this** (port it; don't reinvent it).

### Step 4 — Write the preflight note
Write `.claude/.preflight`. The gate only checks the file is newer than
`.session-start`, but the note's *purpose* is to force you to confront whether the
answer already exists. It must record, concretely:

- **TASK:** one or two lines on what this session is doing.
- **JOURNALS/SOURCE READ:** which journals you read and the relevant finding from each.
- **MEMORY READ:** which memory files, and the relevant fact.
- **EXISTING APPROACH:** what the current code / a sibling feature already does here
  (cite the function/file). If something already does this, say so.
- **WHY THE NEW WORK / HOW IT DIFFERS:** why a change is needed and what it changes.
  If a journal or memory already contains the fix, the "new work" is applying it — say
  that, don't re-derive it.

Match the format of any existing `.claude/.preflight` (it follows exactly this shape).

## Guardrails
- **Never guess.** Every planned change must trace to a confirmed finding from this
  session's reading or a prior session. If the basis is unclear, read more history
  before writing the note.
- Don't write the note before doing the reading — the note is the *output* of the
  research, not a box to tick.
- This gates only the first code edit per session; once written you're clear for the
  rest of the session.
