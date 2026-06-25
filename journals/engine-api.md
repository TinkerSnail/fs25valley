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

## Handtool holder system — give an NPC a REAL handtool (2026-06-24/25)

Discovered by decompiling the sealed handtool scripts (toolchain in
[game-files-and-xml.md](game-files-and-xml.md); raw dumps in `dumps/api/`, gitignored). A character holds
a tool by being its **holder/carrier**, NOT by us linking an i3d — same path every multiplayer body uses.

**Spawn a real handtool** (`HandToolLoadingData`):
```lua
local data = HandToolLoadingData.new()
data:setFilename(Utils.getFilename("$data/handTools/brandless/flashlight/flashlight.xml", nil)) -- RESOLVE $data first; setFilename does fileExists()
data:setOwnerFarmId(farmId); data:setIsRegistered(false)
data:load(function(_, handTool, state) ... end, target)   -- async; cb(target, handTool, state)
```
**Attach it to a character's hand** — the handtool links its `handNode` to
`carryingPlayer.graphicsComponent.model.thirdPersonRightHandNode` (or `…LeftHandNode` if `useLeftHand`):
```lua
handTool:setCarryingPlayer(carrier)   -- carrier needs: .graphicsComponent(=model owner), getIsControlled()->false,
handTool.isHeld = true                --   getForceHandToolFirstPerson()->false, camera={isFirstPerson=false}, setCurrentHandTool=noop
handTool:attachToolToHand()           -- the real link (skip the owner/camera ceremony of startHolding)
-- attachToolToHand only LINKS; flip visibility yourself (recursively over the tool subtree).
```
For Walter we build a thin `carrier` table wrapping **`grandpa.playerGraphics.model`** (a real `HumanModel`
with the `thirdPerson*Node`s) — see [[project_walter_as_handtool_holder]]. Tools drive the body only if they
set a param (`chainsaw` → `carryingPlayer:setIsHoldingChainsaw(true)`); the flashlight is pure light mgmt.

## Character model (`HumanModel`) surface

`grandpa.playerGraphics.model` (or `.graphicsComponent.model`) exposes: `thirdPersonRightHandNode`,
`thirdPersonLeftHandNode`, `thirdPersonHeadNode`, `thirdPersonSpineNode`, `getSkeletonNode()`, `ikChains`,
`getModelYaw()`. NPCs load with the **arm/foot IK chains STRIPPED** (`loadIKChains(…, isRealPlayer)` deletes
rightArm/leftArm/feet/spine) — so `model.ikChains` is empty on Walter; we re-add the chain ourselves.

## IK chains — drive a limb (rightArm), and BREAK THE R42 WALL

The "arm extends to hold the tool out" is the **`rightArm` IK chain** (`playerM.xml`), not a clip. API in
`IKUtil`:
```lua
IKUtil.loadIKChain(xmlHandle, "player.ikChains.ikChain(0)", base, base, model.ikChains)  -- base = getParent(getSkeletonNode())!
IKUtil.setIKChainActive(ik, "rightArm")
IKUtil.setTarget(ik, "rightArm", { targetNode = node, poseId = "narrowFingers" })   -- node the hand reaches toward
IKUtil.setIKChainDirty(ik, "rightArm"); IKUtil.updateIKChains(ik, false)   -- solve (C-backed ikChainSolver)
```
- **Base node gotcha:** the chain's node indices are relative to the **i3d root = `getParent(skeletonNode)`**,
  NOT the skeleton node (one extra leading `0`). Passing the skeleton binds the chain into the FACE.
- **`alignToTarget`** forces the hand to the target's *rotation* (the player aims where they look). For a
  carry pose set it `false` (natural wrist) or orient the target with `setDirection(target, fwd, up)` to aim.

**⭐ THE KEY FINDING — `addPostAnimationCallback` breaks R13/R42.** Driving the IK (or any bone write) from a
normal update/wrapper LOSES to the clip at render (R42 — "runtime bone posing is dead"). But the engine
exposes **`addPostAnimationCallback(fn, target, nil)`** → fires AFTER the animation evaluates, BEFORE render
(the facial system uses it to write the head node, and it persists). **Solve the IK in that callback and it
WINS over the clip.** `removePostAnimationCallback(handle)` to stop.
```lua
self._cb = addPostAnimationCallback(MyClass.solveIK, self, nil)   -- solveIK(self, dt): setIKChainDirty + updateIKChains
```
This reopens EVERYTHING R13/R42 declared impossible (grip poses, arm steadying, limb IK on NPCs). Player
body IK is otherwise engine-C-side (no Lua script calls `updateIKChains` for the player — only the vehicle
spec does, for the driver's hands). Full saga: [[walter_walker_history]] R42–R47;
[[project_flashlight_arm_is_ik_not_clip]]. Target the IK off the **stable graphicsRootNode** (+ smoothed
spine offset), not the spine bone, or the walk-bob jitters the arm.

---

## Mod-code gotcha (surfaced same way)

- **`TimeHelper.getDay()` does NOT exist** — use **`TimeHelper.getMonotonicDay()`** (total
  days since save start) for "which day" / daily-reset logic. Calling the missing `getDay`
  throws `attempt to call a nil value`; because `NPCRelationshipManager.tryTalk` /
  `hasTalkedToday` run during the per-frame update (which is wrapped in one `pcall` at
  `onMissionUpdate`), the throw **aborts the entire `VLNPCSystem:update` every frame** →
  all NPCs freeze. A single missing call in an update path can stall everything.
