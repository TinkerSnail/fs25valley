# Walter Drives the Truck — seated driver + AI road driving

How Walter (the base-game GRANDPA NPC) sits in and drives his truck. This is the distilled engine
knowledge so we never have to re-derive it. Everything here is grounded in the **decompiled GIANTS
scripts** under [`dumps/api/decompiled/`](dumps/api/decompiled/) (gitignored, GIANTS-copyrighted;
re-derivable with the toolchain in [game-files-and-xml.md](game-files-and-xml.md):
`fs-unpack dataS.gar` → `fs-luau-decompile <file>.l64`).

Related: [character-systems.md](character-systems.md) (player-can ⇒ NPC-can), [npc-movement.md](npc-movement.md)
(WalterWalker), and the `project-walter-truck` memory (truck data + R52).

---

## The truck (confirmed runtime data)

- **Vehicle:** International Series 200 — `data/vehicles/international/series200/series200.xml`
- **uniqueId:** `vehiclea0e0823360da9410fb4db3ebcbbfc489` (find via
  `g_currentMission.vehicleSystem.vehicles` → match `tostring(v.uniqueId)`)
- **Park spot:** x=-764.821 y=46.891 z=119.663 ry=-1.5671 (≈ facing west)
- **Specs wired in:** `spec_enterable` (+ `vehicleCharacter`), `spec_aiDrivable`, `spec_aiJobVehicle`,
  `spec_motorized`, `spec_drivable`, `spec_ikChains`.
- Player API to read the seated vehicle: `g_localPlayer:getCurrentVehicle()` (a **method**, not a field).

---

## Part 1 — the SEATED DRIVER POSE (✅ done, R52, commit 6f8a126)

### The key truth: the driver pose is NOT an animation clip

We chased a "seated clip" and it does not exist. `idle1Source` (from the `VEHICLE_CHARACTER` charset) is a
**standing** idle that only adds breathing micro-motion. What makes a driver look *seated* is two things,
applied to a **separate `HumanModel` the vehicle owns** (NOT the player's / NPC's walking body):

1. a **spine/hips rotation** — `VehicleCharacter.SPINE_ROTATION = {-π/2, -0.2461787, π/2}` written to
   `thirdPersonHipsNode` (the sit bend), and
2. **IK chains** — hands→steering wheel, feet→pedals, loaded from the vehicle XML and **solved every
   frame** via `IKUtil.updateIKChains` (`VehicleCharacter:update` → `setDirty` + `updateIKChains`).

Source: `VehicleCharacter.lua:loadCharacter` / `:update`. ⇒ The earlier "hijack" idea — point the
vehicleCharacter's `characterNode`/`animationCharsetId` at Walter's GRANDPA skeleton — **cannot work**:
`characterNode` is only the LINK PARENT; posing happens on `self.playerModel` (the vehicle's own model).

### The correct API: `truck:setVehicleCharacter(style)`

This is the exact path the game uses for every driver, including AI helpers
(`Enterable:setRandomVehicleCharacter(helper)` → `setVehicleCharacter(helper.playerStyle)`). It deletes the
old driver, builds a `HumanModel` from `style.xmlFilename`, links it to the seat, applies SPINE_ROTATION +
IK, dresses it in `style`, and `vehicleCharacterLoaded` runs `updateIKChains()` once on load.

**Walter's appearance** = `grandpa.playerStyle` — the base-game NPC stores its `PlayerStyle` here
(`NPC.lua:100-101`, loaded from the `npc.playerStyle` XML). `grandpa = g_npcManager:getNPCByName("GRANDPA")`.

```lua
local grandpa = walterWalker.grandpa                 -- g_npcManager:getNPCByName("GRANDPA")
truck:setVehicleCharacter(grandpa.playerStyle)       -- seats + IK-poses + dresses the driver as Walter
local vc = truck.spec_enterable.vehicleCharacter
vc.isVisible = true; vc:setCharacterVisibility(true) -- force-show (else hidden when camera < ~1.5 m)
```

### Hiding the standing GRANDPA + keeping IK solved

There are now potentially TWO Walters (the seated driver model + his standing WalterWalker body), so hide
the standing one: `walterWalker:_hide()` + set `walterWalker._inTruck = true` (suppresses his route logic).
`Enterable` only pumps `vehicleCharacter:update(dt)` while the vehicle is **controlled**; for a PARKED,
un-entered truck it isn't, so **WalterWalker pumps `_vehicleChar:update(dt)` itself each frame while
`_inTruck`** (keeps the hands-on-wheel IK solved). While an AI job runs, `getIsControlled()` is true so
Enterable pumps it too — harmless double-solve.

### Gotcha

If the seated driver shows a *generic* face, the truck XML defines `enterable#customPlayerStylePresetName`
which overrides appearance — handle by stripping/ignoring that preset. (series200: not observed.)

---

## Part 2 — DRIVING THE ROUTE via the AI "Go To" job (built, pending in-game test)

Decision: use the **base-game AI system** (the hired-worker "drive to a point" job), not a hand-rolled
kinematic path. It does **full road pathfinding** — `AIDrivable:createAgent` builds a
`createVehicleNavigationAgent(navMapId, turningRadius, …)` and `setAITarget` calls
`setVehicleNavigationAgentTarget(agentId, x,y,z, dir)`; the C nav system steers/brakes the truck along the
map's AI road network. Files: `ai/jobs/AIJobGoTo.lua`, `ai/tasks/AITaskDriveTo.lua`, `ai/AISystem.lua`,
`vehicles/specializations/{AIDrivable,AIJobVehicle,AIVehicle}.lua`.

### What "the AI road network" is — we ride the base game's own routes

The pathfinder navigates a **navigation map** into which the base game registers the map's **AI road
splines**: `AISystem.onCreateAIRoadSpline` / `AISystem:addRoadSpline(spline, maxWidth, maxTurningRadius,
maxHeight)` → `addRoadsToVehicleNavigationMap(navigationMap, subSpline, …)`. Those splines are authored into
the Riverbend Springs map i3d (flagged with the `isAISpline` user attribute) — **the same road network the
base-game hired workers and town traffic use** (the left-hand-traffic note in `aiSystem.xml` says "traffic
and ai splines need to be set up … in map itself"). So `AIJobGoTo` does NOT hand-author a path; it snaps the
truck onto the shipped AI road graph and pathfinds across it to the target. We provide only a destination;
the roads, turning radius, braking and obstacle avoidance are all base-game. It is on-demand pathfinding
(reroutes around blockages), not a fixed scripted spline.

**See the network in-game:** `gsAISplinesShow` (base-game console command, registered in `AISystem`) toggles
AI-spline visibility — use it to confirm the farm↔downtown connection and pick a reachable target coord.

### Starting a Go-To job from Lua (SERVER/host only)

```lua
local job = AIJobGoTo.new(true)                              -- isServer
job:applyCurrentState(truck, g_currentMission, farmId, true) -- sets vehicle param + default target = truck pos
local cx,_,cz = getWorldTranslation(truck.rootNode)
local angle = MathUtil.getYRotationFromDirection(tx - cx, tz - cz)  -- approach heading
job.positionAngleParameter:setSnappingAngle(0)
job.positionAngleParameter:setPosition(tx, tz)               -- world target (x,z); y is terrain-snapped
job.positionAngleParameter:setAngle(angle)
job:setValues()                                              -- pushes vehicle + target into the driveToTask
local valid, err = job:validate(farmId)
if valid then g_currentMission.aiSystem:startJob(job, farmId) end   -- server-side; bypasses the GUI permission pre-check
```

- `aiSystem:startJob` → `job:start` → `truck:createAgent()` (nav agent) + `truck:aiJobStarted()`.
- **GOTCHA:** `AIJobVehicle:aiJobStarted` calls `self:setRandomVehicleCharacter(helper)` (`AIJobVehicle.lua:206`)
  → the driver becomes a RANDOM helper. So **right after `startJob`, re-assert Walter** with
  `truck:setVehicleCharacter(grandpa.playerStyle)` (Part 1).
- **Reachability probe:** `g_currentMission.aiSystem:getIsPositionReachable(x,y,z)`.
- **Stop:** `g_currentMission.aiSystem:stopJob(truck.spec_aiJobVehicle.job, AIMessageSuccessStoppedByUser.new())`.
  On stop the spec restores the prior vehicleCharacter (`restoreVehicleCharacter`).
- `farmId` = `truck:getOwnerFarmId()` (fallback to the player's farm).

### Drive-to task states (for debugging)

`AITaskDriveTo`: `prepareForAIDriving()` → STATE_PREPARE_DRIVING → `getIsAIReadyToDrive()` →
`setAITarget(...)`. `PREPARE_TIMEOUT = 2000 ms` (if it can't prepare — blocked/no fuel — it stops with an
`AIMessageError*`). `maxSpeed` default 10. Errors surface as `AIMessageError*` (NotReachable, OutOfFuel,
BlockedByObject, CouldNotPrepare, NoPermission…).

### Staging waypoints — the farm yard is NOT on the spline network (2026-06-26)

`vlWalterDrive farmersMarket` (a far cross-town target) **failed**: the truck did nothing and the seated
Walter appeared for ~2 s then vanished. Log showed the job started (`reachable=true`, "driving…") then went
silent. **Diagnosis:** `aiSystem:getIsPositionReachable` only tells you the target point is on the nav map —
NOT that a drivable path connects the *parked truck* to it. The farm yard isn't on the AI road-spline
network, so the GoTo can't prepare a path from the parked spot and the job stops within ~2 s
(`AITaskDriveTo.PREPARE_TIMEOUT = 2000 ms`). When the job stops, `restoreVehicleCharacter` removes the
seated driver — that's the "vanish." The short *drive-to-me* worked only because it was a road-connected hop.

**Fix = multi-leg routes.** Drive to a **farm-EXIT waypoint on the road first**, then to the destination,
chaining one `AIJobGoTo` per leg. Completion fires `AI_JOB_STOPPED` with `AIMessageSuccessFinishedJob`
(`AIJob.lua:100`); we subscribe and start the next leg on a *Success* message, abort on an *Error* message.
Each leg re-asserts Walter (every `startJob` re-randomizes the helper). Only the FINAL leg honors a parked
facing; pass-through legs use the approach heading.

**Diagnostic:** `VLConsole:onAIJobStopped` (subscribed to `MessageType.AI_JOB_STOPPED`) logs the exact stop
reason — `[VL][WalterDrive] AI job STOPPED — reason: <AIMessage class> — <text>` (CouldNotPrepare /
NotReachable / OutOfFuel / NoPathFound / FinishedJob …).

### Open risks to verify in-game

1. Does the map's AI road nav network cover the farm→downtown route? (else `NotReachable`.) The first
   "drive to me" test (`vlWalterDrive` no-args) is the reachability probe.
2. Fuel / motor start (`prepareForAIDriving` starts the engine).
3. Whether the AI tries to walk a helper to the door first before driving.

---

## Console commands (the truck feature)

| Command | Usage | What it does |
|---|---|---|
| `vlDumpVehicle` | while seated | Dump the seated vehicle's filename / uniqueId / class / pos / configs. |
| `vlDumpTruck` | anywhere | Probe the truck's `spec_enterable` / `aiDrivable` / `ikChains` (seat node, IK targets). |
| `vlDumpDriver` | while seated in any vehicle | Dump the player's seated charset + the vehicleCharacter's active tracks (how the seated pose is built). |
| `vlWalterInTruck` | standing near the truck | Seat Walter as the driver via `setVehicleCharacter` (sit + hands on wheel), hide standing Walter. |
| `vlWalterOutTruck` | — | Remove the seated driver, reveal the standing Walter. |
| `vlWalterDrive` | `vlWalterDrive [<name>\|<x z>]` | Single-leg AI Go-To to a named spot (`farmersMarket`), an `x z`, or (no args) **where you stand**; re-asserts Walter as the driver. |
| `vlWalterAddWp` | `vlWalterAddWp [angleDeg]` | Capture your position as a **route waypoint** (road off-farm, then the destination). Optional final-park facing. |
| `vlWalterDriveRoute` | — | Drive the captured waypoints in order (chained legs) — the way to **stage a farm-exit node** before a cross-town target. |
| `vlWalterClearRoute` | — | Discard the captured waypoints. |
| `vlWalterStopDrive` | — | Stop the AI drive (any leg), restore the standing Walter. |

---

## Decompiled-source map (the API surface used here)

See [dumps/api/INDEX.md](dumps/api/INDEX.md) for the full table. The truck-relevant files:
`VehicleCharacter.lua`, `Enterable.lua`, `NPC.lua`, `AnimationCache.lua`, `AIJobGoTo.lua`, `AIJob.lua`,
`AITaskDriveTo.lua`, `AISystem.lua`, `AIJobVehicle.lua`, `AIDrivable.lua`, `AIParameterPositionAngle.lua`.

## Animation-clip note (so we don't re-hunt)

Seated/driving pose = **hips-rotation + IK**, NOT a clip. The only clips that pose a *standing* body for
holding/working are the `chainsaw_*` set (see [npc-movement.md](npc-movement.md)); there is **no** seated
or one-handed-hold clip in the 87-clip GRANDPA charset. Reshape a character by SWAPPING the track-0 clip
(idle/walk/talking/sitting-idle/chainsaw) — runtime bone `setRotation` loses to the clip at render (R13),
except in a `addPostAnimationCallback` stage (R47, used for the flashlight arm IK). The vehicle driver is a
*separate* model entirely, so none of the R13 wall applies to it — it's posed by the engine's own C IK.
