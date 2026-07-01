---
name: project-walter-truck
description: "Walter's International Series 200 truck — confirmed in-game data for the driving feature"
metadata: 
  node_type: memory
  type: project
  originSessionId: e230aa83-2549-45d3-bdd3-0f04b2c66e04
---

Walter's truck is the **International Series 200** (classic American farm truck aesthetic).

## ⭐ ESTABLISHED MODEL for ALL character driving routes (user decision 2026-06-27)
Walter's truck drive is the TEMPLATE for every future NPC vehicle route. A route = **3 legs**:
**(1) manual EXIT** — drive a recorded waypoint path off the off-network yard to the road (manual
`driveToPoint`; steering needs `spec_aiJobVehicle.job` set for getIsAIActive; ends ON a spline);
**(2) road AI** — a real `AIJobGoTo` to an **on-spline** destination (off-spline = instant "unreachable");
**(3) manual PARK** — short recorded manual drive from the on-spline drop-off into the off-network bay.
Walter stays seated via `setVehicleCharacter` (re-asserted each AI leg + on abort). Captured paths are
recorded in-session then BAKED into code (FS25 io is write-only). Full detail + tooling commands in the
journal **journals/walter-truck-driving.md → "THE MODEL for character driving routes"**. Build 00:41
(2026-06-27) = working leg-1+2+3 scaffold; farm→farmersMarket (on-spline 398.29,-708.97) confirmed driving.
✅ FULL ROUTE CONFIRMED (build 00:47, user: "perfect run!"): farm yard → road → farmers-market parking bay,
all three legs, Walter seated throughout. Committed + pushed.

✅✅ ROUND TRIP CONFIRMED (build 03:20, 2026-06-27, user: "looks great"): BOTH directions fully baked.
FORWARD (`vlWalterDrive farmersMarket`): exit `_scratchWps` (15) → road to `farmersMarket` (398.29,-708.97)
→ park `_parkWps` (19, re-recorded dense). REVERSE (`vlWalterDriveHome`): crossing `_homeExitWps` (19, market
bay → return spline) → road to `farmReturn` (-801.17,83.33) → return park `_homeParkWps` (59, winding into the
yard). Recorder slots: exit/marketexit/homepark/park (all dump points to log on `off` for baking). `vlTruckTeleport
[market|farm|<name>|<x z>|me]` for instant test positioning.

## 2026-06-28 — polish pass (all ✅ CONFIRMED by user)
- **SAVE HANG #1 FIXED** (user: "saving seems fixed"): a stuck/incomplete park used to leave Walter SEATED — an
  NPC `vehicleCharacter` HumanModel on the parked truck — which HANGS the savegame. Fix: `vlDismountAtTruck`
  now runs on ANY drive end (clean OR stuck), never leaving a seated driver. **Replication gotcha: never leave
  a `setVehicleCharacter` driver on a vehicle you're not actively controlling — it breaks save.**
- **SAVE HANG #2 — `spec.lastJob` (2026-06-29, R62, fix build 02:19, ✅ CONFIRMED user "save hang didnt seem to happen this time"):** a SECOND, distinct
  save-hang from leftover truck AI state. Log: `onSaveStartComplete → AIJobVehicle.lua:671: attempt to index nil
  with 'name'`. The base `AIJobVehicle:saveToXMLFile` writes `getJobTypeByIndex(spec.lastJob.jobTypeIndex).name`.
  Our road legs start a MANUALLY-constructed `AIJobGoTo.new(true)` (no `jobTypeIndex`); the base `aiJobStarted`
  stashes it as `spec.lastJob` and `aiJobFinished` never clears it → at save, `getJobTypeByIndex(nil).name`
  CRASHES → hang. **Fix: nil `spec.lastJob` right after `aiSystem:startJob` in `vlStartGoToLeg` (it's only the
  base "repeat last job" memory, unused by our scripted drive; spec.job/active steering untouched) + defensive
  clears in `vlDriveClearJob` and `vlDismountAtTruck`. GOTCHA: never leave a manually-`new`'d AI job as
  spec.job/lastJob on a vehicle at save — clear it, or build via `aiJobTypeManager:createJob` for a valid
  jobTypeIndex.** See [[walter-walker-history]] R62.

## 2026-07-01 — REGRESSION: `AIJobGoTo.new()` now crashes on `.title`, corrupts Active Workers + blocks hiring
The truck drive that worked 2026-06-27/28 now BREAKS (likely an FS25 game patch tightened AIJob). Confirmed
from log.txt: `vlWalterDrive farmersMarket` → road leg `start=FAIL dataS/scripts/ai/jobs/AIJob.lua:329:
attempt to index nil with 'title'`. Our `vlStartGoToLeg` builds the job with `AIJobGoTo.new(true)` (no
jobType/title/name) → AIJob.lua:329 throws; a malformed "AI worker **Unknown**" still registers → the ESC-map
**Active Workers** list crashes every frame (`SmoothListElement.lua:873: attempt to compare nil < number`),
rendering a corrupted giant glyph, AND the player can't start a new hire. **Three symptoms, one bug.** FIX
DIRECTION (same as the R62 note): build the GoTo job via `g_currentMission.aiJobTypeManager:createJob(...)`
so it has a valid jobTypeIndex + title + name, NOT `AIJobGoTo.new()`. Confirmed via computer-use: I can drive
FS25 + the GIANTS Editor on the Windows PC directly.
**FIXED — R65 (2026-07-01):** re-extracted the Jun-29 dataS.gar here (prebuilt `fs-utils-windows-x64` binaries
in scratchpad) → confirmed AIJob.lua:329 = `getJobTypeByIndex(jobTypeIndex).title` and AIJobTypeManager.lua:68
`createJob` sets `job.jobTypeIndex`. Added `vlNewGoToJob()` in main.lua (`getJobTypeIndexByName("GOTO")` →
`createJob`) used at BOTH GoTo build sites (road leg + manual-drive flag job). Repacked. Also retro-cures the
R61/R62 save-hang. PENDING in-game verify (start=ok / Active Workers renders / hire works while driving). Full
detail: journals/walter-truck-driving.md → "REGRESSION (2026-07-01)". See [[walter_walker_history]] R65.
- **OTHER NPCs JITTERED FIXED** (user: "ben and dave dont jitter anymore"): WalterWalker's `playerGraphics:update`
  patch is CLASS-shared; its `_inTruck` skip-orig() had no per-NPC guard → it starved Ben/Dave/Katie's animation
  whenever Walter drove. Fix: guard with `self_pg == walker.grandpa.playerGraphics`. (See [[walter-walker-history]] R55.)
- **ROUTES RE-RECORDED + RENAMED**: `_parkWps` now **9 pts** (monotonic into the bay, no doubling-back tail that
  parked him short). `_homeExitWps` **renamed `_marketExitWps`** (slot `home`→`marketexit`), **17 pts**, starts at
  the new park spot (403.88,-690.48) → return spline (420.57,-712.81). Slots named by ORIGIN so future routes home
  (woodshop, etc.) don't collide. PENDING: confirm both new routes drive cleanly end-to-end.

## 2026-06-28 — MARKET STROLL + WEEKLY SCHEDULE (the trip woven into his day; user design)
- **Market stroll** (`market` loop, NPCConfig): 11 vlPos-captured waypoints he walks while `_away` — Marta
  (drop-off, longest pause) → bulletin board → 3 stalls (socialize) → mailbox (mail a letter) → back. New loop
  flags: `continuous` (restart at wp1 instead of idling) + `loopsBeforeReturn` (after N circuits, `_startReturnToTruck`
  walks him to the truck's driver door — captured at dismount — then `driveHomeOnArrival` fires `walterDriveHome`).
  Wired in WalterWalker `_away` branch + `_updateWalk`. `vlWalterMarketReturn` forces the ending. See [[walter-walker-history]] R58.
- **Weekly schedule** (`VLConsole._marketSchedule`, replaced the old daily `_truckSchedule`): Walter goes to
  market **TWICE a week** — `days = { [2]=depart 06:00 "Tue morning", [5]=depart 13:00 "Fri afternoon" }` (weekday
  0=Sun..6=Sat via TimeHelper.getWeekday). **Departure-only** — the stroll self-terminates home, so no returnHour;
  19:00 backstop if stuck. The market run PREEMPTS the farm loop in its window (he's seated from wherever he is);
  the rest of the day + non-market days = normal farm walk loops. `vlWalterSchedule [on|off|now|today <hr>]`.
  Tunable: the two days/hours, `loopsBeforeReturn` (now 1 = one purposeful circuit), pause minutes. **PENDING TEST.** KEY FIXES this session: manual-drive advance is
PROGRESS-based not heading-based (a truck parked facing AWAY from the path now follows it, doesn't beeline to
the last point); stuck-detector tracks waypoint progress not crow-flies distance (winding paths no longer
false-trigger). Splines are ONE-WAY → reverse needs the opposite-lane crossing. Committed + pushed.

**SPAWN-ON-NEW-GAME (2026-06-28, user "same with the truck"):** the truck MUST be spawned by the mod on a
fresh game — a new player's save won't have it, and without it the whole market-drive feature is dead. Same
approach + defaults as Bonnie's doghouse (spawn once if missing, free, don't re-spawn if removed) — see
[[project-bonnie-dog]]. Vehicle analog of the placeable loader = **`VehicleLoadingData`** (confirm via `vlDog`
probe, build 16:09, which dumps it + `vehicleSystem` load methods + the truck's `.configurations` to replicate
the visual config below). Replicate the config: baseColor=37, rimColor=38, design=2, wheel=1, etc.

**Confirmed runtime data (2026-06-26):**
- filename:  `data/vehicles/international/series200/series200.xml`
- uniqueId:  `vehiclea0e0823360da9410fb4db3ebcbbfc489`
- Park spot:  x=-764.821  y=46.891  z=119.663  ry=-1.5671 (≈ facing west / -π/2)

**Visual configuration (all indices confirmed in-game):**
- baseColor=37, rimColor=38, design=2, wheel=1
- tensionBelts=2, attacherJoint=1, fillUnit=1, folding=1, motor=1
- licensePlate.defaultPlacementIndex=1 (plate text stored in savegame XML)

**How to find it at runtime:**
```lua
local vs = g_currentMission and g_currentMission.vehicleSystem
-- iterate vs or call vs:getVehicleByUniqueId("vehiclea0e0823360da9410fb4db3ebcbbfc489")
-- OR find by filename match on vs vehicles table
```

**Player API (confirmed):** `g_localPlayer:getCurrentVehicle()` — NOT `g_localPlayer.currentVehicle` (that field is nil; it's a method call).

**Key specs on this vehicle:**
- `spec_aiDrivable` + `spec_aiFieldWorker` — base-game AI driver system is wired in; research path for Walter driving
- `spec_ikChains` — driver hand-on-wheel IK, same system as Walter's arm IK (R47)
- `spec_enterable` + `spec_enterablePassenger` — enterable as driver or passenger
- `spec_drivable`, `spec_motorized` — fully drivable vehicle

**Why:** Walter's personality beat — he drives his old International into town. The AI driver system (`spec_aiDrivable`) is the research path for making him actually drive it rather than hand-rolling movement.

## SEATED DRIVER POSE — SOLVED FROM ENGINE SOURCE (2026-06-26, R52)

Decompiled `VehicleCharacter.lua` + `Enterable.lua` (from dataS.gar via fs-luau-decompile).
**The seated/driving pose is NOT an animation clip.** The prior session burned time hunting for a
"seated clip" — there is none. `idle1Source` (from the `VEHICLE_CHARACTER` charset) is a STANDING idle;
it only adds breathing micro-motion. What actually makes a driver look seated =
**(a) a spine/hips rotation + (b) IK chains** solved every frame:

- `VehicleCharacter:loadCharacter(playerStyle, ...)` builds its OWN `HumanModel` (NOT the player's body),
  `link()`s it to the seat node (`characterNode`), sets `thirdPersonHipsNode` rotation to
  `SPINE_ROTATION = {-π/2, -0.2461787, π/2}` (bends him into sitting), then `IKUtil.setTarget` for each
  `ikChainTarget` (hands→wheel, feet→pedals, loaded from the vehicle XML).
- `VehicleCharacter:update(dt)` each frame: `setDirty(false)` + `updateIKChains()` (solves the limb IK).
  Enterable only pumps this while `getIsControlled()` — so for a PARKED/un-entered truck we must call
  `vc:update(dt)` ourselves. `vehicleCharacterLoaded` calls `updateIKChains()` ONCE on load (enough to
  seat a stationary Walter).

**⇒ The prior `vlWalterInTruck` hijack (link GRANDPA node + set `vc.characterNode`/`animationCharsetId`)
is WRONG and should be abandoned.** The vehicleCharacter ignores `characterNode` for posing — it drives
its own `self.playerModel` skeleton, and IK runs on `self.playerModel:getIKChains()`. You cannot point it
at Walter's existing GRANDPA skeleton.

**THE CORRECT PATH (the engine's own API — "use what's there"):**
`truck:setVehicleCharacter(playerStyle)` → deletes old, calls `loadCharacter`, seats + IK-poses + dresses
the driver in `playerStyle`. This is EXACTLY how AI helpers get seated: `Enterable:setRandomVehicleCharacter(helper)`
→ `setVehicleCharacter(helper.playerStyle)`. For Walter, feed it WALTER's playerStyle so the seated driver
wears his face/clothes; then hide the standing WalterWalker GRANDPA (`_inTruck` guards already suppress his
route). Resolve Walter's style from his HumanModel (`walker.grandpa…model.style`) or fall back to a
helper/player style to first PROVE the seated pose. See [[project-clip-animation-opportunity]] (clips) vs
this (pose = hips-rot + IK, a different mechanism).

## SEATED POSE — DONE (2026-06-26, R52, committed 6f8a126)
`vlWalterInTruck` = `truck:setVehicleCharacter(grandpa.playerStyle)` + force visible + `walker:_hide()`;
WalterWalker pumps `_vehicleChar:update(dt)` while `_inTruck`. `vlWalterOutTruck` restores. User: "it worked."

## DRIVING THE ROUTE — MECHANISM (2026-06-26, decompiled, user CHOSE the AI-driver path)
Use the base-game AI "Go To" job = the hired-worker drive-to-a-point feature. Full ROAD pathfinding (it
calls `createVehicleNavigationAgent` + `setVehicleNavigationAgentTarget` — the C nav system steers/brakes
the truck along the map's AI road network). Files: `ai/jobs/AIJobGoTo.lua`, `ai/tasks/AITaskDriveTo.lua`,
`vehicles/specializations/{AIDrivable,AIJobVehicle,AIVehicle}.lua`, `ai/AISystem.lua` (all decompiled →
journals/dumps/api/decompiled/). How to start one from Lua (SERVER only):
```lua
local job = AIJobGoTo.new(true)                          -- isServer
job:applyCurrentState(truck, g_currentMission, farmId, true)  -- sets vehicle param + default target=truck pos
job.positionAngleParameter:setSnappingAngle(0)
job.positionAngleParameter:setPosition(tx, tz)           -- target (world x,z)
job.positionAngleParameter:setAngle(approachAngleRad)
job:setValues()                                          -- pushes vehicle+target into driveToTask
local ok,err = job:validate(farmId); if ok then g_currentMission.aiSystem:startJob(job, farmId) end
```
`aiSystem:startJob` (server) → `job:start` → `truck:createAgent()` (nav agent) + `truck:aiJobStarted()`.
**GOTCHA:** `AIJobVehicle:aiJobStarted` calls `self:setRandomVehicleCharacter(helper)` (AIJobVehicle.lua:206)
→ the driver becomes a RANDOM HELPER. So RIGHT AFTER startJob, re-assert Walter: `truck:setVehicleCharacter(grandpa.playerStyle)`.
While a job runs `getIsControlled()`=true so Enterable pumps `vc:update` (IK) + visibility itself — Walter
stays seated/posed. Stop a job: `g_currentMission.aiSystem:stopJob(truck.spec_aiJobVehicle.job, AIMessageSuccessStoppedByUser.new())`.
Reachability probe: `g_currentMission.aiSystem:getIsPositionReachable(x,y,z)`.

**OPEN RISKS to verify in-game:** (1) does the map's AI road nav network cover the farm→downtown route
(else NotReachable)? (2) truck fuel/permission (startJob bypasses the GUI permission pre-check). (3) does
the AI start animation try to walk a helper to the door first? — watch on first test.

## DRIVING — ✅ CONFIRMED WORKING (2026-06-26, user: "he hopped in the car and drove a few feet and turned then stopped")
`vlWalterDrive` (no-args drive-to-me) END TO END: Walter seated as driver, AI Go-To job started, the
base-game nav pathfinder drove the truck along the AI road splines and stopped at the target (short
distance because the target was where the user stood). The whole AIJobGoTo + setVehicleCharacter(Walter)
approach is PROVEN. `commit d5feba7` (docs); command scaffold in main.lua. NOTE: `vlWalterDrive` seats him
itself — you do NOT need `vlWalterInTruck` first. Stop with `vlWalterStopDrive` (stops job + reveals
standing Walter), not `vlWalterOutTruck`.

## FAR-DRIVE FAILS (2026-06-26): `vlWalterDrive farmersMarket` (387.4,-669.6) — truck did NOTHING, Walter
appeared ~2s then vanished. Log: job started, `reachable=true`, "driving… Walter at the wheel", then
silence. Diagnosis: `reachable=true` (getIsPositionReachable) only means the target is ON the nav map, NOT
that a drivable path connects the parked truck (farm, -764,119) to it. Job stops within ~2s (likely
`AITaskDriveTo.PREPARE_TIMEOUT=2000ms` → `AIMessageErrorCouldNotPrepare`, or no path) → on stop the spec
runs `restoreVehicleCharacter` → seated Walter removed (that's the "vanish"). The short drive-to-me worked
because it was a road-connected hop near the truck. **Prime suspect: farm driveway ↔ downtown roads are
NOT joined on the AI road-spline network** (check with `gsAISplinesShow`). Added a one-shot diagnostic
(`VLConsole:onAIJobStopped`, subscribed to `MessageType.AI_JOB_STOPPED`) → next run logs the exact stop
reason `[VL][WalterDrive] AI job STOPPED — reason: …`. Build repacked 20:16.

## MULTI-LEG ROUTE ENGINE (2026-06-26, build 20:23) — staging waypoints
User domain knowledge: the farm YARD isn't on the AI road splines, so you must give the truck a node to
"get off the farm" before it can route to a far destination. Built a multi-leg route engine in main.lua:
chains one `AIJobGoTo` per waypoint, advancing on the `AIMessageSuccessFinishedJob` `AI_JOB_STOPPED`
message (`VLConsole:onAIJobStopped` → `vlDriveNextLeg`), re-asserting Walter each leg, only the FINAL leg
honoring a parked facing. New commands: `vlWalterAddWp [angleDeg]` (capture current pos as a waypoint — like
vlPos for walk routes), `vlWalterDriveRoute` (drive the captured waypoints chained), `vlWalterClearRoute`.
`vlWalterDrive <name|x z|none>` is now a 1-leg route through the same engine. `vlWalterStopDrive` clears the
route first. Stop-reason diagnostic logs `[VL][WalterDrive] AI job STOPPED — reason: …`.

## OFF-NETWORK YARD → MANUAL DRIVING (2026-06-26, build 21:35)
KEY FINDING: the AI road pathfinder (`AIJobGoTo`/nav agent) ONLY accepts targets ON the AI road-spline
network. The farm yard is OFF it, so feeding captured yard waypoints to the pathfinder fails: leg aborts
`AIMessageError... "target is unreachable!"` in ~0.1 s → restoreVehicleCharacter removes Walter → "appears
1 s then vanishes". ALSO: `aiSystem:getIsPositionReachable` is UNRELIABLE — it returned true for a point the
agent rejected. Don't trust it.
USER INSIGHT (I kept ignoring it): the captured multi-point path is a path to DRIVE ALONG out of the yard,
NOT a list of pathfinder targets. FIX = drive the exit waypoints with MANUAL driving:
`truck:setAITarget(task, x,y,z, dir, speed, useManualDriving=true)` → `AIDrivable:onUpdate` (lines 210-216)
runs `AIVehicleUtil.driveToPoint` straight at the point (NO network), fires `reachedAITarget` within 0.5 m →
`task:onTargetReached`. Chain the exit waypoints, then hand the FINAL destination to the road AI (vlDriveNextLeg).
Implementation (main.lua): `VLConsole._manual`/`_manualTask`/`manualAdvance`/`manualTick`; pumped from
`onMissionUpdate` (raiseActive each frame + prepareForAIDriving + wait getIsAIReadyToDrive, then drive). No
WalterWalker edit. `vlWalterDrive` now: seat Walter → manual-drive the captured exit path → road AI to dest.
PENDING TEST: does the truck follow the yard path (manual) then road-pathfind to the market?

## ⭐ STEERING GATE — the real lesson (2026-06-26): use the REAL AI JOB, don't hand-roll
The base-game AI driving (a REAL `AIJobGoTo`) STEERS and drives correctly — PROVEN by the very first
`vlWalterDrive` (no-args drive-to-me): the truck turned and drove. Steering only applies when
`Vehicle:getIsAIActive()` is TRUE, and `AIJobVehicle:getIsAIActive` returns true only when
`spec_aiJobVehicle.job ~= nil` (i.e. a real job is running). My STANDALONE `setAITarget(useManualDriving=true)`
did NOT set that → `getIsAIActive=false` → the motor crept the truck forward but **steering input was ignored
(rolled straight into the shed, never turned)**. Likewise kinematic `setRelativePosition` glide works but no
wheels. **CONCLUSION: stop hand-rolling movement. Drive the truck with a REAL AI job** (which steers + avoids
obstacles). The only open problem is the off-road YARD start (the job rejects off-network targets as
"unreachable"), BUT the job CAN drive the truck within the yard toward a REACHABLE on-network target (a 28s
drive toward (-776.25,125.73) was observed). So the likely answer: a real AIJobGoTo to an on-network point at
the farm exit (the recorded path's endpoint, if it's on a spline) → the real AI steers the truck out around
the shed → then to the market. User was right: "you know how to do this, you're just flubbing the execution."
DO NOT propose the kinematic glide again. (User rewound the session here, 2026-06-26 ~23:15.)

## ⛔ KINEMATIC GLIDE REJECTED AGAIN (2026-06-26, build 23:43) — back to REAL AI steering
I (Claude) misread an edited .preflight and re-implemented the kinematic glide; USER STOPPED me: "you are
going with the weird gliding thing i told you not to do?". REVERTED. `vlWalterDrive` now drives the captured
exit waypoints with the REAL AI: one `AIJobGoTo` per waypoint via the route engine (vlDriveNextLeg →
vlStartGoToLeg), which STEERS, then the road AI to the destination. The stop-reason parsing bug is fixed
(separate pcalls + isa(AIMessageSuccessFinishedJob)) so leg outcomes are now readable. The kinematic
driveStart/driveTick are left INERT (not called). OPEN RISK to watch in the test: early YARD waypoints may be
OFF the AI spline network → a leg aborts "unreachable"; if so the ⭐ STEERING GATE answer applies — target the
ON-NETWORK exit point (last waypoint) and let the real AI steer out around the shed, then the market.
LESSON: follow the user's explicit instruction; the ⭐ STEERING GATE note is authoritative; do NOT glide.

## STEERING-ENGAGE FIX for the manual first leg (2026-06-26, build 23:59)
User corrected the plan: FIRST LEG = manual physical drive (NOT the road AI — yard is off-network; NOT the
glide). The known blocker = manual `setAITarget(useManualDriving=true)` crept the truck STRAIGHT (no wheel
steering) because steering needs `getIsAIActive()`=true. CONFIRMED in source: `AIJobVehicle:getIsAIActive`
returns `superFunc or spec_aiJobVehicle.job ~= nil` (line 277). FIX: in `driveStart`, set
`truck.spec_aiJobVehicle.job` = a real but UNSTARTED `AIJobGoTo` purely as the getIsAIActive flag (no nav
agent, no pathfinder), then drive manually toward each recorded point; `vlDriveClearJob` clears it on
finish/stuck before the real road AI takes the destination. PENDING TEST: do the wheels now STEER toward the
waypoints (follow the recorded curve around the shed) instead of creeping straight? If it STILL creeps
straight, getIsAIActive isn't the only gate → decompile `AIVehicleUtil.driveToPoint` (not yet decompiled) to
find the real steering gate. NOTE: AIDrivable:onUpdate (line 210-216) DOES call driveToPoint in manual mode,
so the steering code runs — the question is whether the wheel layer honors it without AI-active.

## (superseded — kept for history) MANUAL driveToPoint FAILS near the shed → KINEMATIC PLAYBACK
Manual `setAITarget(useManualDriving=true)` MOVES the truck (confirmed) but naive waypoint-following CUTS
CORNERS (truck's turning radius + overshoot) and drifts off the recorded line INTO the shed; the per-leg
distance log showed it reaching ~5 m from a waypoint then driving AWAY, then wedging at constant 10 m on the
shed. Denser points don't fix it — it's a control problem. The road AI (AIJobGoTo) HAS obstacle avoidance but
only accepts on-network targets. **USER CHOSE: trace the EXACT recorded line via KINEMATIC PLAYBACK** (force
truck position+heading along the recorded waypoints each frame, bypassing physics for that stretch), then
hand off to the road AI for the destination leg. Path RECORDER works great (`vlWalterRecord on/off` →
vehicle-aware capturePose → dense path → CSV). 14-pt farm→road exit path baked into `VLConsole._scratchWps`.
NOTE: FS25 io sandbox = WRITE-ONLY (`io.open` read mode is forced to write → truncates!); persist by baking
into code from the CSV (read it with a tool). Implementing kinematic playback next (removeFromPhysics +
setWorldTranslation along the path + addToPhysics at the road end → road AI).

**Next steps:**
1. ✅ short drive works; ❌ single far market drive fails (yard not on splines). TEST the route flow:
   `vlWalterAddWp` on the road JUST OFF the farm → `vlWalterAddWp` at the market → `vlWalterDriveRoute`.
   Read the `[VL][WalterDrive] leg N/M` + `AI job STOPPED — reason:` log lines.
2. Once a working farm-exit + market sequence is found, bake it as a named route (replace the scratch flow).
3. Wire into his daily schedule (depart → drive route → park → … → home).
2. Capture a downtown target coord with `vlPos` (pick a point ON an AI road spline — `gsAISplinesShow` to
   see the network); bake the farm→downtown route. (User doing this part.)
3. Wrap it into Walter's daily schedule (timed departure → drive → arrive → park, like the walk loops).
   Likely a `truckRoute`/`truckDepartHour` config + a WalterWalker edge-trigger that calls the drive,
   then re-hides/handles arrival. Mirror the morningDeparture pattern.
4. **WANT (user request 2026-06-26): player RIDE-ALONG in the PASSENGER seat while Walter drives.** The
   truck has `spec_enterablePassenger` → use the base-game passenger-seat system (don't hand-roll).
   Research how the player enters a passenger seat (vs `enterVehicle` as driver) and make it available
   while Walter is the AI driver — a "ride into town with Grandpa" beat. Logged in TODO.md too.

**Named drive targets** live in `VL_DRIVE_TARGETS` (main.lua): `farmersMarket = {x=387.40, z=-669.62,
angle=0.0}` (vlPos 2026-06-26). `vlWalterDrive farmersMarket` | `vlWalterDrive <x z>` | no-arg drive-to-me.
