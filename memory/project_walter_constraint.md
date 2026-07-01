---
name: project-walter-constraint
description: "FOUNDATIONAL constraint: Walter must be the REAL base-game GRANDPA, not a Marta-style doppelganger. The user ruled out the look-alike approach."
metadata:
  node_type: memory
  type: project
  originSessionId: faaa0e39-d931-4477-a4f2-5a8ee0b14972
---

**The user EXPLICITLY RULED OUT spawning a new VL look-alike entity (a "doppelganger" /
HumanGraphicsComponent styled like grandpa, the way Marta is built).** They chose to control
GRANDPA's EXISTING base-game model instead. This decision is the entire reason `WalterWalker.lua`
hijacks `grandpa.playerGraphics` rather than spawning a Marta-style NPC.

**Why this matters:** Do NOT re-propose "make Walter a mod-owned HumanGraphicsComponent like Marta"
as if it were a new idea. It was considered and rejected in session faaa0e39. Re-suggesting it is
the exact looping the user is frustrated by. (This was rediscovered and wrongly re-proposed on
2026-06-21 because the constraint was not in memory — that gap is now closed.)

**The reason the user ruled it out (confirmed 2026-06-21):** A doppelganger would mean Walter
randomly despawns and a COPY reappears in the same place — and that copy has NONE of the base game's
original GRANDPA dialog/interaction. The user will not accept a Walter that loses the real grandpa's
built-in conversation. Walter must remain the actual base-game GRANDPA NPC.

**PRINCIPLE — never override or erase base-game dialog (confirmed 2026-06-22):** All mod dialog is
**ADDITIVE**. Do NOT suppress, replace, or block any base-game conversation/interaction (Walter's
GRANDPA "press to talk", or any NPC's). Mod lines layer ON TOP — e.g. Walter's time-of-day greetings
are an **ambient popup on approach** while his base "press to talk" conversation stays fully intact.
This generalizes the Walter constraint: preserving base-game content is a standing rule, not just for
Walter. When designing any dialog feature, the base interaction must remain reachable and unchanged.

**Status to revisit (2026-06-21):** R0–R13 proved the real-GRANDPA path is fighting
`g_npcManager`'s per-frame conversation/standing controller (`playerGraphics:update`), which
re-drives the skeleton every frame → sub-second hips vibration. The control-the-real-model path may
be a genuine dead end because of this. IF the user is open to revisiting the doppelganger decision,
that is a conversation to have explicitly — but the default is the constraint HOLDS. See
[[walter-walker-history]].
