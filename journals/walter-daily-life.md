# Walter's daily life — system reference & 2026-06-22 session log

Everything that makes Walter (the real base-game **GRANDPA**) feel alive: a full daily
schedule, disappearing into the house, emerging at dawn, climbing his porch stairs,
checking the pumps, visiting the woodshop (opening the door + flicking the lights), a map
icon that follows him, fast-travel that lands where he actually is, stopping to face you
when you approach, and time-of-day greetings. Built across the 2026-06-22 session.

Implementation: `src/scripts/WalterWalker.lua`, `src/NPCConfig.lua` (`VLConfig.WALTER_WALK`),
`src/content/Walter.lua`, `src/scripts/NPCCasualDialogue.lua`, `src/gui/NPCDialog.lua`.
Engine-API specifics (doors/lights/hotspots/teleport) live in [engine-api.md](engine-api.md);
the walk-loop basics in [npc-movement.md](npc-movement.md); commands in
[console-commands.md](console-commands.md).

> **Standing principle (this session):** mod dialog/behavior is **ADDITIVE** — never override or
> erase base-game dialog or interaction. Walter's base "press to talk" GRANDPA conversation stays
> fully reachable; everything we add (greetings, schedule, door/lights) layers on top.

---

## His daily schedule

| Time | Loop | What he does |
|---|---|---|
| 5:00 | `morningDeparture` (manual, fired by the 5am wake) | If he slept inside, he **emerges from the woodshed-style farmhouse door** and walks down to home. |
| 6–9 | `checkingPumps` | Out-and-back across the yard: bench → swingset → orangeCone → pumphouse → **gaspump** (15-min pause) → home. |
| 9–12 | `mailbox` | woodShop → entryDrive → mailApproach → **mailbox** (20-min pause) → home. |
| 12–14 | `produceStand` | Shares the mailbox approach, branches to the **produce stand** (20-min pause). |
| 14–16 | `woodshopVisit` | Walks to `tinyShed01`, **opens the door**, steps inside, **lights on**, hangs out 45 min, **lights off**, **closes the door**, home. His craftsman hour. |
| 16–19 | (idle) | Deliberate **home stretch** — he relaxes around the farm. |
| 19:00 | `eveningReturn` | Walks to the door and **steps inside** (vanishes) for the night. |

Loops are `VLConfig.WALTER_WALK.loops`, selected by hour via `WorkLoopHelper.getActiveLoop`
(re-fires on the 2-hour tick). `morningDeparture` + `woodshopVisit` carry no hour window when
manual; `morningDeparture` stays `manualOnly` (the wake triggers it). `vlWalk grandpa <loop>`
forces any loop; `vlSkipPause grandpa` skips a pause.

---

## 1. Disappear through the door + morning departure

- **Evening:** `eveningReturn`'s final waypoint (`houseDoor`) has `hideOnEnd = true`. On arrival he
  `_hide()` = `setVisibility(graphicsRootNode, false)` and the loop ends. This mirrors Marta's
  `despawnOnEnd` (NPCEntity), which is itself a **reversible visibility toggle, not entity deletion**
  — so Walter stays the real GRANDPA. Confirmed in-game: the hide **persists** (g_npcManager does not
  re-show him), so no per-frame re-assert is needed. (The 2-minute door pause was later removed — he
  steps in on arrival.)
- **Morning (5am):** edge-triggered once per calendar day via `TimeHelper.getMonotonicDay()` (a level
  window was tried first and instantly reverted a daytime hide — don't do that). If `_hidden`, runs
  `_startMorningDeparture`: places him at the door, faces him down the steps, reveals, and runs the
  `morningDeparture` loop (door → stairMid → doorApproach → **home**, ending via `endOnArrival`).
- New waypoint flags: **`hideOnEnd`** (hide + end), **`endOnArrival`** (stop & idle here, don't loop
  back to wp[1] — for one-way routes). New `WorkLoopHelper` flag **`manualOnly`** (skipped by the
  hourly auto-selector; still resolvable by name).

## 2. Stairs

`_surfaceY` interpolates Y between waypoint endpoints that carry captured `y` (porches/stairs aren't
in the terrain heightmap), and adds a **convex "bow" lift** on sloped segments (`stairLift * 4·frac·
(1-frac)`, zero at endpoints) so his feet clear the tread noses. Tunables: `stairLift`, `yOffset`
(+ live `vlWalterStairLift` / `vlWalterYOffset`). Lesson: correct Y **per-waypoint**, not with a
global offset (a global that grounded the porch made him wade through flat ground).

## 3. Stop-and-face (talk mid-route) — base conversation preserved

When the player is within `approachRange` (**4m**), Walter stops, lerps to face them, and holds;
resumes when they leave. Crucially, **while `grandpa.isInConversation` he yields fully to the base
game** — `_updateWalk` reverts to idle and returns, and the wrapper **runs `orig()`** so the base
conversation animates. (See gliding fix below — a route active during a conversation starved it of
`orig()`.) His base "press to talk" GRANDPA conversation is untouched.

## 4. Gliding fixes (two, don't confuse them)

- **Real cause:** calling a walk route **while talking** made him glide — an active route skips
  `orig()` (the R17 twitch fix), but a conversation NEEDS `orig()`. Fix: wrapper runs `orig()` when
  `isInConversation`; the route yields during a conversation.
- **Red herring:** a "glides at 10m+" report led to a distance-culling theory + a distance-gated-orig
  attempt — **wrong**, removed. The trigger was always route-while-talking; the distance was
  incidental. (Lesson: trust the user's precise repro — "fine unless I call a route while talking.")

## 5. Map icon follows him

The NPC map icon is `grandpa.mapHotspot`. Its **`getWorldPosition()` is a static instance field**
(returns his spawn point) and ignores `worldX/worldZ`, `setWorldPosition`, `grandpa.x/z`, and all
nodes — **both the minimap and the ESC map render through it**. Fix: **override `getWorldPosition` on
the hotspot instance** to return his driven position while active (restore on delete). Also keep
`grandpa.x/y/z` + `worldX/Z` synced (`_syncFollowers`) for other readers.

## 6. ESC-map "Visit" teleport

The Visit/fast-travel goes through **`Player:teleportToNPC(npc)`** (not the hotspot, not
`onClickVisitPlace`). Hook it: when the NPC is our Walter and he's active, `teleportTo` his live
position offset **`visitOffset` (2m)** in front of him (his facing) so the player doesn't land inside
his model. Other NPCs/idle Walter fall through to vanilla. (Finding this required the `_G[name]`
metatable quirk + a multi-step hunt — see engine-api.md.)

## 7. Woodshop door + lights (the `woodshopVisit` route)

- **Shed:** `tinyShed01` placeable (resolved by `configFileName` + nearest to a config point, cached
  in `_resolveShed`). It has `loadIndoorArea` (real interior).
- **Door:** AnimatedObject `doorRotate02` (the entry side; `doorRotate01` is the other side). Open/
  close with **`ao:setDirection(1 / -1)`**. Walter has no collider so the door is **cosmetic** for
  him — we just swing it on cue. Waypoint flags **`openDoor` / `closeDoor`** call `_setWoodshopDoor`.
- **Lights:** one group "Shed lights" in `spec_lights`. Toggle with **`placeable:setGroupIsActive(
  group.index, on)`** (the call the "press R" activatable uses — clean, no warning). The manual
  `group.isActive = on` + `updateLightState` path works too but emits a red `setVisibility(nil)`
  warning, so it's only a fallback. Waypoint flags **`lightsOn` / `lightsOff`** call `_setWoodshopLights`.
- **Route:** woodShop → shedApproach (`openDoor`) → shedDoor → shedInside (`lightsOn`, 45-min pause) →
  shedDoorB (`lightsOff`) → shedApproachB (`closeDoor`) → home.

## 8. Time-of-day dialogue + ambient greeting

- **Content axis:** `VLCasualDialogue` gained a time-of-day axis — any villager can define
  `morning` (5–11) / `midday` (11–16) / `evening` (16–20) / `night` (20–5) pools; they mix into the
  normal greeting (`pickLine`) and have a gating-free `pickTimeOfDayLine`.
- **Walter's lines:** `src/content/Walter.lua` registers `grandpa` with placeholder lines per bucket
  in his gruff-grandfather voice (rewrite freely) + `firstMeet` / `alreadyTalked`.
- **Delivery — ambient greeting:** `WalterWalker:_maybeGreet` speaks a time-of-day line as an
  **auto-dismissing popup** when the player enters `greetRange` (5m, just before he stops to face you),
  edge-triggered + `greetCooldownMs` (20s). It's **additive** — base conversation untouched —
  suppressed during a conversation, while hidden, or when a mod speech/heart event is on screen.
  Delivery uses a new `NPCDialog.showSpeechBox` option **`opts.ttl`** (auto-dismiss seconds).
- `vlWalterSay` previews the current bucket's line on demand.

---

## Also this session (not Walter)

- **Marta stop-and-face:** mirrored Walter's behavior in `VLNPCEntity:_updateWalkLoop`
  (`APPROACH_RANGE` 4m): stops, faces, holds, resumes; keyed on her `isTalking` flag + proximity.
- **Crash fix — `TimeHelper.getDay()` did not exist:** `NPCRelationshipManager.tryTalk/hasTalkedToday`
  called it, throwing "attempt to call a nil value" **inside the per-frame update `pcall`**, which
  aborted the **entire** `VLNPCSystem:update` every frame → all NPCs froze (Marta wouldn't resume
  after a conversation). Switched to `TimeHelper.getMonotonicDay()`. Also repaired the per-talk
  relationship gain that had been silently broken. **Lesson:** one missing call in an update path
  freezes everything.
- **Docs:** new [engine-api.md](engine-api.md) (the sealed-API cracking *method* + door/light/hotspot/
  teleport calls); [console-commands.md](console-commands.md) rebuilt as the master command directory;
  the additive-dialog principle added to [dialog-boxes.md](dialog-boxes.md). Diagnostic dump-probes
  stripped after journaling (kept `vlDoorTest`/`vlLightTest`).

## New `VLConfig.WALTER_WALK` knobs

`speed`, `homeRy`, `home`, `yOffset`, `stairLift`, `dayStartHour` (5), `approachRange` (4),
`greetRange` (5), `greetCooldownMs` (20000), `visitOffset` (2), `woodshopDoor` (`{near, config,
saveId}`), and `loops` (the schedule).

## Design intent

**Walter is the most important character** to the player and gets the deepest schedule + dialog by
design; other villagers stay lighter (see `project-overview` memory). This session built the
behavioral foundation; the next frontier is **content** — writing his real time-of-day lines and
authoring heart events (the woodshop project — he's building the player a gift — is the standout hook).
