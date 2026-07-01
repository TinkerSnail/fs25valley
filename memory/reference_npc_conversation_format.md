---
name: reference-npc-conversation-format
description: FS25 base-game NPC conversation system — conversation.xml textFlow/options + per-language readable text (NOT sealed)
metadata: 
  node_type: memory
  type: reference
  originSessionId: d300dc87-aa70-4230-899e-6879787ac90d
---

How the base-game NPC dialogue system is authored (decoded 2026-06-25 by extracting dataS2.gar). Broadly
useful for ALL our dialogue work, not just cows. Lives under `$dataS2/npc/<npc>/...`.

**An NPC's `<npc>.xml`** lists `<conversations>` — each `<conversation uniqueId="hex">path/conversation.xml`.
Plus `<title>` (display name, e.g. "Katie"), `<playerStyle filename=...>` (the rig+outfit),
`<interactionTrigger node="triggerNode"/>`, `<sounds>`, `<i3dMappings>`.

**Each `conversation.xml`:**
```
<conversation><class>NPCConversation</class><type>DEFAULT|HELP</type><probability>1</probability>
  <isActive>true</isActive>
  <textFlow startId="..">
    <item id=".." nextId="..">      <!-- linear step: text then go to nextId -->
      <text>$dataS2/.../<textKey></text>     <!-- key = folder path, NOT inline text -->
    </item>
    <item id="..">                    <!-- terminal item (no nextId) -->
      <text>.../<key></text>
      <actions><startConversationById uniqueId="hex"/></actions>   <!-- jump to another conversation -->
    </item>
  </textFlow>
</conversation>
```
DEFAULT conversations branch via `<next><option id=".."><text>..</text><actions><startConversationById/>`
= a player reply MENU (this is how the "ask about cows → feed/keep/breeds/equipment" tree works).

**The text strings ARE READABLE — correcting the old journal claim that NPC text is sealed in .bin.**
Each `<text>` key resolves to sibling files in that folder: `<key>_en.xml` (+ ~28 languages),
`<key>_en.ogg` (voice audio), `<key>_en.bin` (TTS data). The `_en.xml` content:
```
<text><emotional>Display text, with inline [happiness, low]...[/happiness] emotion tags.</emotional>
      <silence>phonetic/timed version for TTS, {.}=short {...}=long pauses</silence></text>
```
The `<emotional>` block is what shows on screen; emotion tags drive face/voice. So base-game NPC dialogue
can be READ and studied directly (extract dataS2.gar; per-language text is loose XML). Sample (Katie,
cows): "You can feed your cows with grass, hay or TMR... you shouldn't only feed them hay or grass." /
"I have had the best results with TMR." / "Cows... need a pasture or a barn." / "You need to deliver fresh
water to your cow pasture, as it has no access to water."

Relevance to us: our hand-rolled [[project-clip-animation-opportunity]]-era VLCasualDialogue/NPCDialog is
separate from this, but this is the base pattern to either interoperate with or learn from for the additive
Katie work. See [[reference-basegame-npc-roster]].

**STARTING a base NPC's conversation FROM A MOD (confirmed from source 2026-07-01, R66):** the native
"press to talk" prompt is `NPCActivatable:run()` (dataS/scripts/ai/npcs/NPCActivatable.lua:37) =
**`npc:requestConversation(g_localPlayer)`**. `NPC:requestConversation(player)` (NPC.lua:783) auto-selects
the conversation (FIRST_CONTACT → INTRO → DEFAULT via `getRandomConversation`) and, on the SP host
(`isServer`), calls `NPC:startConversation(player, conversation, useFacialAnimation, isPhoneConversation)`
(4 args — a no-arg `startConversation()` does nothing). So one line — `npc:requestConversation(g_localPlayer)`
— opens ANY base NPC's real dialogue. Used for Walter in `WalterWalker:startBaseConversation()`; the SAME
call will hook **Katie** (ANIMAL_DEALER) and any other [[reference-basegame-npc-roster]] NPC. The NPC object
comes from `g_npcManager:getNPCByName("GRANDPA"/"ANIMAL_DEALER"/...)`. Its `.activatable` can be unregistered
from `g_currentMission.activatableObjectsSystem` (NPC.lua:572/577) to suppress the native prompt if a custom
chooser replaces it.
