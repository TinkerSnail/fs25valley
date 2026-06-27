# Walter Drives the Truck — seated driver + AI road driving

How Walter (the base-game GRANDPA NPC) sits in and drives his truck. This is the distilled engine
knowledge so we never have to re-derive it. Everything here is grounded in the **decompiled GIANTS
scripts** under [`dumps/api/decompiled/`](dumps/api/decompiled/) (gitignored, GIANTS-copyrighted;
re-derivable with the toolchain in [game-files-and-xml.md](game-files-and-xml.md):
`fs-unpack dataS.gar` → `fs-luau-decompile <file>.l64`).

Related: [character-systems.md](character-systems.md) (player-can ⇒ NPC-can), [npc-movement.md](npc-movement.md)
(WalterWalker), and the `project-walter-truck` memory (truck data + R52).

---

## ⭐ THE MODEL for character driving routes (use this for ALL of them)

The established, WORKING template (✅ farm⇄market round trip, 2026-06-27, commit a9c56b8). Any NPC driving a
vehicle between two off-network spots = **three legs each way**, because the AI road network is **on-spline
ONLY** and the yard/parking bays are OFF it:

1. **Leg 1 — manual EXIT drive.** The start (yard/bay) is OFF the spline network, so the road pathfinder
   rejects it. We DRIVE the truck ourselves along a **recorded** waypoint path out to the road
   (`AIVehicleUtil.driveToPoint` via `setAITarget(..., useManualDriving=true)`), advancing point-to-point.
   The final point must land **ON a spline**. (Steering needs a trick — see Manual-drive mechanics below.)
2. **Leg 2 — road AI.** A real `AIJobGoTo` from the on-spline exit point to an **on-spline destination** —
   base-game nav follows the road graph, steering + braking + obstacle-avoiding for free. **The destination
   MUST be on a spline** (off-spline = instant "unreachable"; `getIsPositionReachable` is a LIAR, ignore it).
3. **Leg 3 — manual PARK drive.** The bay is off-network again, so manual-drive a recorded path from the
   on-spline drop-off into the spot. Runs automatically after the road legs (`vlWalterDrive` queues `_pendingPark`).

**The splines are ONE-WAY.** The return trip is NOT the forward route reversed — it needs its OWN on-spline
points on the **opposite-direction lane**. So the reverse is its own three legs: a **crossing** (bay → across
the road to the return spline), a road AI to a **return drop-off** near home, and a **return park** into the
yard. Confirm direction/connectivity with `gsAISplinesShow` (base-game command; shows the AI road graph).

Walter stays seated the whole trip via `setVehicleCharacter` (Part 1), re-asserted on each AI leg + on abort
so he never vanishes. Captured paths are **baked into code** (FS25 `io` is write-only — see Recorder workflow).

### How to build a NEW character's route (the recipe)

Per direction (use `vlTruckTeleport` to jump the vehicle to each test spot — don't drive the whole way):
1. **Record leg-1 exit:** sit in the vehicle at its parked spot → `vlWalterRecord on` → drive out to the
   road, ending **on a spline** (toggle `gsAISplinesShow` to see it) → `vlWalterRecord off`.
2. **Capture the on-spline destination:** stand/park ON the destination spline → `vlPos` → that's the leg-2
   target (a `VL_DRIVE_TARGETS` entry).
3. **Record leg-3 park:** teleport to the destination drop-off → `vlWalterRecord on park` → drive into the
   bay, stop where it should park (final heading = parked facing) → `vlWalterRecord off`.
4. For the **return**, repeat with the `home` slot (crossing to the opposite-lane spline), a `farmReturn`-style
   on-spline drop-off near home, and the `homepark` slot (drop-off → yard).
5. **Bake:** every `…Record off` prints the points to the log; read them out and hardcode into the route's
   `VLConsole._…Wps` tables + `VL_DRIVE_TARGETS` in `main.lua`. Test, commit.

### Manual-drive mechanics (the non-obvious engineering)

- **Steering won't engage** for `setAITarget(useManualDriving=true)` unless `getIsAIActive()` is true — the
  wheels ignore AI steering otherwise and the truck just creeps straight. `AIJobVehicle:getIsAIActive` returns
  true iff `spec_aiJobVehicle.job ~= nil` (line 277). So during a manual leg we set `spec_aiJobVehicle.job` to
  an **unstarted** `AIJobGoTo` purely as that flag (NOT the road pathfinder), and clear it before the real
  road AI runs (`driveStart`/`vlDriveClearJob`).
- **Advance by PROGRESS, not heading.** Step to the next waypoint when close to the current OR the next is
  already closer. A "is this point behind me" heading test wrongly skips every point when the vehicle starts
  parked facing AWAY from the path (e.g. facing into the bay while the path pulls out) → it beelines the last
  point. (`driveTick`.)
- **Stuck-detect by PROGRESS, not crow-flies distance.** Declare stuck only if the target waypoint index
  hasn't advanced for ~6 s. Distance-to-final-point falsely grows on a WINDING path and used to kill good
  drives near the buildings.
- **Recording first point matters:** `driveStart` begins at the waypoint NEAREST the vehicle (not always #1),
  so re-running while already partway/parked-at-the-end doesn't drive backward.

### Recorder workflow + persistence (FS25 io is WRITE-ONLY)

`vlWalterRecord on [home|homepark|park] … off` samples the vehicle's pose every ~3 m into the named slot
(`_scratchWps`=exit / `_homeExitWps`=crossing / `_homeParkWps`=return-park / `_parkWps`=forward-park).
**FS25 sandboxes `io.open` to WRITE mode only — opening for READ is forced to write and TRUNCATES the file**
(this destroyed a route once). So: only the `exit` slot auto-saves to a CSV; the others are in-memory and,
on `…Record off`, **dumped as `{ x=, z=, angle= }` lines to the log** for baking. In-memory recordings are
lost on relaunch — so **capture and bake in the same session**. Vehicle-aware capture: `vlPos`/`vlWalterAddWp`
read the VEHICLE's position when you're seated in it (the on-foot player node parks at the origin → (0,0)).

### The BAKED routes — Walter's farm ⇄ farmers market (2026-06-27)

All waypoints live in `main.lua` (the durable record); anchor coords for reference. `vlWalterDrive farmersMarket` / `vlWalterDriveHome`.

| Leg | Slot | pts | from → to |
|---|---|---|---|
| Forward exit | `_scratchWps` | 15 | park spot (-763.3,116.6) → on-spline (-800.99,132.15) |
| Forward road | `VL_DRIVE_TARGETS.farmersMarket` | — | → on-spline drop-off (398.29,-708.97) |
| Forward park | `_parkWps` | 19 | drop-off → bay (390.77,-669.42) |
| Reverse crossing | `_homeExitWps` | 19 | bay → return-lane spline (386.56,-712.49) |
| Reverse road | `VL_DRIVE_TARGETS.farmReturn` | — | → on-spline drop-off (-801.17,83.33) |
| Reverse park | `_homeParkWps` | 59 | drop-off → yard (-762.96,117.33) |

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

## Part 2 — DRIVING THE ROUTE via the AI "Go To" job (✅ working — see THE MODEL above for the full recipe)

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

### Resolved (was "open risks")

1. **Does the AI network connect farm↔downtown?** YES, but the splines are ONE-WAY — the forward and return
   use opposite-lane on-spline points (hence the separate crossing). The yard/bays are off-network (manual legs).
2. **Fuel / motor start** — `prepareForAIDriving` starts the engine; not an issue in practice.
3. **No helper-walks-to-door** — we set the vehicleCharacter directly; the AI just drives.

---

## Console commands (current, after cleanup a9c56b8)

| Command | Usage | What it does |
|---|---|---|
| `vlWalterDrive` | `[<name>\|<x z>]` | Drive the FORWARD route: manual exit → road AI to dest → manual park. `farmersMarket`, an `x z`, or no-args = to where you stand. |
| `vlWalterDriveHome` | — | Drive the REVERSE route (crossing → road AI to `farmReturn` → return park into the yard). |
| `vlWalterStopDrive` | — | Stop the drive (any leg) + restore the standing Walter. |
| `vlTruckTeleport` | `[market\|farm\|<name>\|<x z>\|me]` | Instantly place the truck for testing (no long drive). |
| `vlWalterRecord` | `on [home\|homepark\|park] … off` | Record a dense drive path into a slot; on `off` it dumps the points to the log for baking. Default slot = forward exit. |
| `vlWalterAddWp` / `vlWalterListWp` / `vlWalterClearRoute` | — | Point-by-point exit-path capture/list/clear (alt to the recorder). |
| `vlTruckParkAddWp` / `vlTruckParkList` / `vlTruckParkClear` | — | Point-by-point forward-park capture (alt to `vlWalterRecord on park`). |
| `vlWalterInTruck` / `vlWalterOutTruck` | — | Seat / un-seat Walter as the parked-truck driver (the standalone seated-pose POC). |
| `vlTruckRoadTo` | `[<name>\|<x z>]` | DIAGNOSTIC: road-AI the truck from its current spot to a target (no manual leg) — isolates start-vs-target reachability when building a new route. |
| `vlDumpTruck` / `vlDumpDriver` / `vlDumpVehicle` | — | Discovery probes (seat node, IK targets, vehicleCharacter tracks). Dormant dev tools. |
| `gsAISplinesShow` | — | **Base-game** command: toggle the AI road-spline overlay (find on-spline points / check connectivity). |

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
