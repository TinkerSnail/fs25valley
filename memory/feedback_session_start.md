---
name: feedback-session-start
description: Mandatory session-start research protocol — read this before touching any code
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ca8380d2-ce9f-46de-9065-56bc5b987e75
---

Read session history before every session, no exceptions.

**Why:** Cumulative knowledge across sessions is the core value of the working relationship. Rediscovering already-proven findings wastes hours and tokens and is a trust failure.

**How to apply:**

Step 0 — Read the relevant `journals/` files (in the repo). They are the distilled engine knowledge
and OFTEN ALREADY CONTAIN THE ANSWER. Start with `journals/README.md` (the index), then read whichever
match the task. For ANYTHING about NPC walking/animation, `journals/npc-movement.md` and
`journals/lifecycle-and-hooks.md` are mandatory — they document direct-track animation and the
"skip `gfx:update()` in direct mode / **do not** call full `gfx:update()` per NPC per frame" rule that
WAS the R17 Walter fix. (2026-06-21: that fix sat unread in these journals while we burned ~17 attempts.
Do not repeat that.)

Step 1 — Read MEMORY.md and any relevant memory files.

Step 2 — Find relevant prior sessions:
```
mcp__ccd_session_mgmt__list_sessions
```

Step 3 — Read the JSONL transcript for each relevant session. Files are at:
```
~/.claude/projects/-Users-christina-Dropbox-Mac-Documents-FS25Valley/<cliSessionId>.jsonl
```
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

**After any significant finding:** write it to the appropriate memory file immediately, before context compacts.

**Never guess:** every change must be grounded in a confirmed finding from this session or a prior one.
