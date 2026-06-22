# Engine API & runtime introspection

How we discovered the sealed (`.gar`) GIANTS APIs for placeable doors, lights, map
hotspots, and player teleport — and the exact calls that work. Captured 2026-06-21/22
during the Walter woodshop + map-icon work so we never re-derive them.

---

## Method (playbook): cracking a sealed API

Engine classes/logic live in `.gar` and **can't be read as source**. Repeatable process,
proven on doors, lights, map icons, and the Visit teleport:

1. **Get a live reference to the object.** Either a known global via **`_G[name]`** (see the
   `_G` quirk below) or navigate from one (`g_currentMission.placeableSystem.placeables`,
   `npc.mapHotspot`, `g_localPlayer`, …). Pick the instance by `configFileName` + nearest
   coordinate when there are many.
2. **Dump it** with a throwaway `vl*` console command:
   - Fields: iterate `pairs(obj)` (print numbers/strings/bools; note tables to recurse).
   - Methods: walk `getmetatable(obj).__index` (a table) and `pairs` it.
   - Recurse into promising sub-tables (`spec_*`, `animation`, `activatable`, `groups`).
3. **If the dump is thin, the methods are behind a function `__index`** — they won't
   enumerate. **Call the expected method by name anyway** (`ao:setDirection(1)` worked
   though only `getCanBeTriggered` showed).
4. **Identify the lever** — a method (`setDirection`) or a field-then-refresh
   (`group.isActive = true` then `updateLightState`). When unsure which call the *player's*
   interaction uses, find/hook the handler (Visit → `Player:teleportToNPC`).
5. **Confirm with a TEST command** (`vlDoorTest`, `vlLightTest`): fire it, watch the log
   line + the in-game result, from a distance so player proximity isn't a factor.
6. **Bake the confirmed call into the feature, then strip the diagnostics.** Record the
   working call here so it's a lookup next time.

> Some calls log a non-fatal red **`Warning (script)`** (e.g. `updateLightState` →
> `setVisibility(nil)`). `pcall` does **not** suppress these C-side warnings — avoid
> triggering them rather than trying to catch them.

### The `_G` quirk (cost us a cycle — remember it)
Engine globals and classes are **NOT in the standard `_G` table**. `pairs(_G)` and
`rawget(_G, name)` both **miss** them (they returned `nil` for `g_currentMission`!).
They resolve through `_G`'s metatable `__index`, so:

- Use **`_G[name]`** (plain index, not `rawget`) to reach `g_currentMission`, `Player`,
  `InGameMenuMapFrame`, `PlaceableLights`, `AnimatedObject`, etc.
- You can't *enumerate* them, so probe candidate names directly.

### Methods hidden behind a function `__index`
Many GIANTS classes expose methods via a **function** `__index`, so `pairs` can't list
them — **but they're still callable by name**. If a dump shows few/no methods (e.g. an
AnimatedObject showed only `getCanBeTriggered`), **try calling the expected method
anyway** (`ao:setDirection(1)` worked despite not appearing).

---

## Placeables

- List: **`g_currentMission.placeableSystem.placeables`** (array). Each has `.rootNode`,
  `.configFileName` (e.g. `data/placeables/mapUS/tinySheds/tinyShed01.xml`),
  and you can `getWorldTranslation(p.rootNode)`.
- Find a specific one: filter by `p.configFileName:find("tinyShed01", 1, true)` **and**
  nearest to a known coord — there can be several of a stock model (cache the result).
- Spec tables on the placeable: `p.spec_animatedObjects`, `p.spec_lights`,
  `p.spec_indoorAreas`, `p.spec_hotspots`, …
- `p:loadIndoorArea()` exists — sheds/buildings have a navigable indoor area.

---

## Openable doors = AnimatedObjects

A placeable's doors are in **`p.spec_animatedObjects.animatedObjects`** (array). Each is a
data descriptor:

- `.saveId` — e.g. `doorRotate01`, `doorRotate02` (the tiny shed has **two separate single
  doors on different sides**, not a double door).
- `.animation = { direction (0 idle / +1 opening / -1 closing), time (0 closed … maxTime),
  maxTime (1), duration (ms, e.g. 3500), parts }`.
- `.activatable`, `.controls` ("Open door"/"Close door", `posAction = ACTIVATE_HANDTOOL`).
- `.nodeId`, `.triggerNode`, `.isMoving`.

**Open / close in code:**
```lua
ao:setDirection(1)   -- open  (animates over .duration; works hands-free, any distance)
ao:setDirection(-1)  -- close
```
`setDirection` is hidden behind the metatable but callable. (Poking `ao.animation.direction`
directly does NOT reliably animate — use `setDirection`.) The placeable also has
`getAnimatedObjectBySaveId` / `getCanTriggerAnimatedObject`.

> NPCs we hand-drive (e.g. Walter) have no collider, so a door is **cosmetic** for them —
> they pass through regardless; we just play the swing on cue at a waypoint.

---

## Placeable lights

**`p.spec_lights`** = `{ groups, activatable, triggerToGroup, realLights, lightShapes,
sharedLights }`.

- `spec_lights.groups[i]` = `{ index, isActive (on/off), name ("Shed lights"), triggerNode,
  inputAction ("INTERACT"), hasManualLights, activateText "Turn on %s", deactivateText }`.

**Toggle in code:**
```lua
p:setGroupIsActive(group.index, on)   -- the proper call (what "press R" invokes)
```
`setGroupIsActive` is a `PlaceableLights` module fn (found via `vlLightFns`). It sets the
state cleanly — no console warning. (`setLightState` / `setLightsState` do **not** exist here.)

> **Avoid** the manual `group.isActive = on` + `p:updateLightState(index)` +
> `p:lightSetupChanged()` path — it toggles the lights but `updateLightState` then calls
> `setVisibility(node, nil)`, spamming a red `'setVisibility' ... Expected: Bool. Actual: Nil`
> warning. `setGroupIsActive` does the setup `updateLightState` expects, so no nil.

---

## Map hotspots (NPC icons) + ESC-map "Visit"

- An NPC's map icon is **`npc.mapHotspot`** (a MapHotspot); `npc.isHotspotAdded = true`.
- **Its `getWorldPosition()` is an INSTANCE field returning a STATIC value** (the NPC's
  spawn point). It **ignores** `worldX/worldZ` fields, `setWorldPosition()`, `npc.x/z`, and
  every node. **Both the minimap and the ESC map render via this method.**
- **To make the icon follow a moving NPC:** shadow `getWorldPosition` on the hotspot
  **instance** to return the live position; restore the original on cleanup:
  ```lua
  local orig = hs.getWorldPosition
  hs.getWorldPosition = function(self) if active then return wx, wz else return orig(self) end end
  ```
- **ESC-map "Visit" / teleport** goes through **`Player:teleportToNPC(npc)`** — NOT the
  hotspot, NOT `onClickVisitPlace`. Hook it and redirect:
  ```lua
  Player.teleportToNPC = Utils.overwrittenFunction-style: if npc is ours and active,
      self:teleportTo(x, y, z)  -- offset ~2m in front so you don't land inside the model
  ```
- Player teleport API: `Player:teleportTo`, `teleportToNPC`, `teleportToExitPoint`,
  `teleportToSpawnPoint`, `findEmptyAreaAroundPosition`; `PlayerMover:setPosition/teleportTo`.
- `InGameMenuMapFrame` methods (for reference): `onClickVisitPlace`, `getCanGoTo` /
  `tryStartGoToJob` / `startGoToJob` (the "Go To" fast-travel), `onClickHotspot`,
  `setTargetPointHotspotPosition`. The map-frame action methods are at the **class** level
  (`_G["InGameMenuMapFrame"]`), but the teleport itself is on the Player.

---

## Mod-code gotcha (surfaced same way)

- **`TimeHelper.getDay()` does NOT exist** — use **`TimeHelper.getMonotonicDay()`** (total
  days since save start) for "which day" / daily-reset logic. Calling the missing `getDay`
  throws `attempt to call a nil value`; because `NPCRelationshipManager.tryTalk` /
  `hasTalkedToday` run during the per-frame update (which is wrapped in one `pcall` at
  `onMissionUpdate`), the throw **aborts the entire `VLNPCSystem:update` every frame** →
  all NPCs freeze. A single missing call in an update path can stall everything.
