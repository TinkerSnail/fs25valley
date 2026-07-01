---
name: feedback-npc-can-do-what-player-can
description: "Rule of thumb — anything the PLAYER character can do, an NPC can do too (Walter or Marta); research the player's path"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4307b9b7-fe94-4f9f-bd09-b06b6a152de2
---

**Proven rule of thumb (user, 2026-06-22):** In FS25 and this mod, *anything the player
character can do is something the NPCs can also do* — regardless of whether the NPC is a
base-game character (Walter / GRANDPA) or a fabricated one (Marta). Treat NPC capability
as a SUPERSET-equals-player question, not an open "is it even possible" question.

**Why:** The player and all NPCs run the SAME GIANTS character system — `HumanGraphicsComponent`
→ `graphicsRootNode` → the same skeleton/clip pipeline (this is the core insight already proven
in [[walter-walker-history]]: Marta and Walter differ only in WHO calls `:update`, not in what
the system can do). Hand tools (e.g. the flashlight in `data/handTools/`), lights, animations,
attachments — if it works in the player's hands, the same nodes/calls exist on the NPC.

**How to apply:** When asked "can an NPC do X?", do NOT answer "unproven/maybe." Instead go find
HOW THE PLAYER DOES X (the player handtool code, the activatable, the attach/link call) and port
that path to the NPC's `graphicsRootNode`/skeleton. The only real work is plumbing (loading a
mod-bundled i3d to dodge the pak-runtime-load limit, finding the right bone node, linking a
child), not feasibility. Don't hedge feasibility on things the player demonstrably does.

Caveat that remains true: a CAPABILITY existing ≠ a good GRIP POSE. We drive idle/walk clips,
not bone-level grip animation, so a held prop follows the hand but may look ungripped up close.
That's an animation-polish issue, not a "can't do it" issue. Related: [[project-open-decisions]].
