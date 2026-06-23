# Character systems — how our characters operate (the map)

The big-picture model of how Valley Life's characters work, so the per-topic journals
(movement, dialog, appearance, engine-api) have a frame to hang on. Start here, then follow
the pointers for detail.

---

## The one idea that explains everything

**Every character — the player, Walter, Marta, Elara, Kenji — is the SAME GIANTS human rig**
(`HumanGraphicsComponent` → `graphicsRootNode` → the `playerM` skeleton + animation clips).
There is no separate "NPC engine." NPCs are the player's character system with a different
*owner/driver*.

> **Rule of thumb (proven):** anything the player character can do, an NPC can do too — base-game
> (Walter) or fabricated (Marta). Capability is never the question; *plumbing* is. When asked
> "can an NPC do X?", go find how the PLAYER does X and port that path to the NPC's
> `graphicsRootNode`/skeleton. See [[feedback-npc-can-do-what-player-can]].

Confirmed concretely this session: GRANDPA's skeleton has the full named `playerM` rig
(`...root/Hips/Spine/.../RightShoulder/RightArm/RightForeArm/RightHand` + every finger) — the
*identical* bones the player uses, animated by his clips. (`vlWalterBones` dumps it; see
[npc-movement.md](npc-movement.md) "Hand props".)

---

## Two implementation paths (the only real split)

| | **Walter** (the hard case) | **Fabricated NPCs** (Marta, Elara, Kenji) |
|---|---|---|
| What he/they are | the **real base-game GRANDPA** NPC — must STAY him ([[project-walter-constraint]]) | mod-spawned `VLNPCEntity` instances we create and own |
| Driver | `WalterWalker` hand-drives the shared skeleton; **`g_npcManager` also owns him** and fights us | `VLNPCEntity`; no external manager updating it → much simpler to drive |
| Consequence | needs special care: skip `orig()` (the npcManager graphics update) while walking to avoid the twitch; yield to it during conversation | `setRotation(graphicsRootNode)` just sticks; clean by construction |
| Detail | [walter-daily-life.md](walter-daily-life.md), [[walter-walker-history]] | mining notes in [[walter-walker-history]] "Marta vs Walter" |

Both drive movement through the **same** `WorkLoopHelper` (named, hour-windowed waypoint loops),
so the schedule convention can't drift between them. Walter is the deepest character by design;
the others are lighter ([[project-overview]], [[project-walter-story]]).

---

## Capability catalog (what a character can do, and where it's documented)

| Capability | Status | Where |
|---|---|---|
| Spawn + appearance (style, face/hair/clothing, `appearanceSeed`) | ✅ | [character-appearance.md](character-appearance.md), [lifecycle-and-hooks.md](lifecycle-and-hooks.md) |
| Walk loops / daily schedule (named loops, waypoints, `pauseMinutes`, turn-then-walk) | ✅ Walter full; Marta loop; Elara/Kenji light | [npc-movement.md](npc-movement.md), [walter-daily-life.md](walter-daily-life.md) |
| Stop-and-face on approach + talk — **base dialog preserved** | ✅ Walter, Marta | [walter-daily-life.md](walter-daily-life.md) §3 |
| Casual dialogue (relationship tiers + time-of-day pools + named pools) | ✅ all | `NPCCasualDialogue`, content `src/content/*.lua` |
| Heart events (cutscene sequencer, thresholds, branching) | ✅ authored Marta/Elara/Kenji; Walter planned (woodshop-gift arc) | `NPCEventSequencer`, [[project-walter-story]] |
| Hide / reveal ("step inside", reversible `setVisibility`) — NOT a despawn | ✅ Walter; Marta `despawnOnEnd` (same mechanism) | [walter-daily-life.md](walter-daily-life.md) §1 |
| Map icon follow + ESC-map "Visit" teleport-to-live-position | ✅ Walter (his solve) | [engine-api.md](engine-api.md), [walter-daily-life.md](walter-daily-life.md) §5–6 |
| World interaction — doors (AnimatedObject `setDirection`), lights (`spec_lights`) | ✅ Walter's woodshop | [engine-api.md](engine-api.md), [[walter-woodshop-door]] |
| **Hand props (flashlight etc.) — link to the `RightHand` bone** | ✅ DONE — Walter holds a lit flashlight, seated in his grip (first NPC hand-prop in the project) | [npc-movement.md](npc-movement.md) "Hand props" |
| Hand SHAPES / grip poses (curl finger bones — the `<pose>` system) | 🔬 author our own (base-game pose list is sealed in `.gar`) | [npc-movement.md](npc-movement.md) "Hand SHAPES" |
| Relationship state (0–100) + savegame persistence | ✅ | `NPCRelationshipManager`, [lifecycle-and-hooks.md](lifecycle-and-hooks.md) |

---

## Governing principles (don't break these)

1. **Additive.** Never override or erase base-game dialog/behavior. Walter's base "press to talk"
   GRANDPA conversation and intro tour stay fully reachable; everything we add layers on top.
   ([dialog-boxes.md](dialog-boxes.md), [[project-walter-constraint]])
2. **Walter is the real GRANDPA.** No Marta-style doppelganger copy — ruled out. Hide/reveal is a
   visibility toggle on the real entity, never deletion + replacement. ([[project-walter-constraint]])
3. **Character story lives in the `src/content/<Name>.lua` header** (epithet + bio + four-beat arc),
   co-located with that character's content. ([[project-walter-story]])
4. **Resolve node ids BY NAME, never hardcode.** Every runtime node handle changes per session.
5. **Player-can ⇒ NPC-can.** (The rule of thumb above. Use the base-game asset/path the player uses.)
