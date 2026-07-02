---
name: project-npc-chooser-walter-talk
description: NPC cycle-target chooser (VL_CYCLE) shipped; Walter's base conversation (requestConversation) verified in-game and his native prompt now suppressed while he's a chooser target
metadata:
  type: project
---

Built the **cycle-target NPC chooser** (2026-06-30) so overlapping villagers (the reported
Marta+Walter case) can be picked between, replacing the single-nearest `getNearestNPC`.

**Why:** interaction snapped to whoever was marginally closer; two NPCs together = the other
was unreachable. User chose "cycle-target key" + "include Walter" (base-game GRANDPA).

**How to apply / where it lives:**
- `NPCSystem:getNearbyNPCs()` = distance-sorted in-range targets, folds Walter in via
  `WalterWalker:getTalkTarget()`. `NPCDialog` cycle logic + `VL_CYCLE` (KEY_x) input action
  (modDesc.xml + lang_en.xml `vl_cycle_prompt`). See [[reference-npc-conversation-format]] and
  journal `dialog-boxes.md` §"Choosing between overlapping NPCs".

**✅ RESOLVED — R66 (2026-07-01), CONFIRMED FROM DECOMPILED SOURCE.** The `vlWalterTalk` probe
(2026-07-01) failed all candidates BUT proved the surface: GRANDPA has `.activatable`,
`.interactionTriggerNode`, `.availableConversations`, and `startConversation` EXISTS but returned nil
with no args (its methods are hidden behind a function `__index`, so the probe couldn't enumerate
them). Re-extracted dataS.gar and read the real source:
- `NPCActivatable:run()` (dataS/scripts/ai/npcs/NPCActivatable.lua:37) — the exact call the native
  "press to talk" prompt executes — is literally **`self.npc:requestConversation(g_localPlayer)`**.
- `NPC:requestConversation(player)` (NPC.lua:783) auto-picks the conversation (FIRST_CONTACT → INTRO →
  DEFAULT) and, on the SP host (`isServer`), calls `startConversation(player, conv, true, false)`.
- `NPC:startConversation` takes **4 args** `(player, conversation, useFacialAnimation, isPhoneConversation)`
  — that's why our no-arg call did nothing. The activatable's text = `g_i18n:getText("action_startConversation")`
  = the "START CONVERSATION" prompt.

**BAKED:** `WalterWalker:startBaseConversation()` now = `g:requestConversation(g_localPlayer)` (probe +
`_tryTriggerActivatable` deleted). Fire-and-forget like `run()` (UI comes up via NPCConversationStartEvent,
so don't gate the return on `isInConversation`). This is his REAL base dialogue — no doppelganger
([[project_walter_constraint]]).

**NATIVE PROMPT SUPPRESSION — IMPLEMENTED (2026-07-01, after in-game verify of the R path).** The native
"START CONVERSATION" activatable was both a UI duplicate AND a correctness bug (it always talked to Walter
even when the chooser had Marta selected — both on R). Now that R-on-Walter → real base dialog is CONFIRMED
in-game, the suppression is live:
- `WalterWalker:getActivatable()` returns `grandpa.activatable`.
- `VLNPCDialog:suppressWalterNative(walterTarget)` removes it from
  `g_currentMission.activatableObjectsSystem` (`removeActivatable`) whenever a `kind=="walter"` target is in
  chooser range — **count-independent: fires when Walter is alone too**, not just in the multi-NPC case (the
  native prompt is always redundant once our R owns him).
- We deliberately **do NOT re-add during play**: the base game removes the activatable on interaction-trigger
  leave and re-adds it on the next trigger enter, so forgetting it keeps us in sync and avoids duplicate/stray
  entries. `VLNPCDialog:restoreWalterNative()` (called from `delete()`) puts it back on mod teardown so
  disabling the mod never strands him.
- Guarded with `type()` + `pcall`, so if the base method name differs it fails safe (native prompt just stays)
  rather than crashing.
Clean end state: one **PRESS R TO TALK TO \<selected\>** (+ one **PRESS X TO SWITCH TO \<other\>** when 2+ in
range), no stray base prompt.

**✅ FULLY CONFIRMED IN-GAME 2026-07-01** (user "everything looks good"): near Walter the native
"START CONVERSATION" prompt is gone, only our R-to-talk (+ X-to-switch) remain, R opens his real base
dialogue and respects the chooser selection (Marta ≠ Walter). Chooser + `requestConversation` bake +
suppression all verified and shipped to `main`.

**REUSABLE:** `npc:requestConversation(g_localPlayer)` is THE mod-callable way to start ANY base-game NPC's
conversation (applies to Katie/[[reference_basegame_npc_roster]] too). See [[reference_npc_conversation_format]].
