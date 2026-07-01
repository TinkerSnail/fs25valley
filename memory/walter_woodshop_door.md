---
name: walter-woodshop-door
description: "Walter woodshop-door feature: open the woodshop (tinyShed01) door so he can walk in and hang out. Investigation + findings."
metadata: 
  node_type: memory
  type: project
  originSessionId: 250d8e53-6bd2-499c-b093-795014748ef3
---

GOAL (user, 2026-06-22): On a daytime route, Walter walks to the woodshop, OPENS its door (key-press
interactive for the player), walks through, and hangs out inside for a bit, then comes back out. User
will capture extra waypoints to align him with the door.

KEY FINDINGS (vlDoorScan, build 03:16):
- The woodshop = base-game placeable **`data/placeables/mapUS/tinySheds/tinyShed01.xml`** at world
  ~(-778.6, 106.7). (Nearby: stable01 at (-759.3,129.2) — NOT the woodshop.) The `woodShop` route
  waypoint (-773.35, 111.71) is ~7m from the shed.
- The door is an **AnimatedObject**: placeable has `getAnimatedObjectBySaveId`,
  `getCanTriggerAnimatedObject` (AnimatedObjects placeable spec). So the door is a triggerable
  animated object — that's the lever to open it in code.
- Placeable also has **`loadIndoorArea`** → the shed has a real indoor area he can stand in.

PLAN:
1. (in progress) vlDoorObj — dump the shed's animated-object list + each AO's state fields + the
   open/close/animation/trigger methods on the AO class + placeable, to find the exact "open" call.
2. Trigger the door open programmatically as Walter arrives (likely AnimatedObject:setState/playMove
   or placeable trigger), close after he's through.
3. Route waypoints (user captures): align to door → through doorway → inside waypoint (pause "hang
   out") → back out.

DOOR MODEL (vlDoorObj/AO/Act, builds 03:21-03:29): tinyShed01 has 2 animated objects saveId
`doorRotate01` + `doorRotate02` (double doors). Each AO is a DATA descriptor (only Lua method:
getCanBeTriggered) driven by the placeable's AnimatedObjects spec. Each AO has:
- `animation` table: direction (0 idle / +1 open / -1 close), time (0=closed .. maxTime=1 open),
  duration=3500ms, parts (the rotating nodes). 
- `activatable` (the interaction; activateText) + `controls` (posActionText "Open door",
  negActionText "Close door", posAction ACTIVATE_HANDTOOL). Pressing the key flips direction.
- triggerNode, nodeId, isMoving, isServer/isClient=true (singleplayer).
HYPOTHESIS: set `ao.animation.direction = 1` (+ isMoving=true) and the spec's per-frame update
animates the door open; -1 closes. TEST cmd added: `vlDoorTest <1|-1|0> [x][z]` (acts on both doors).
If direct-field doesn't animate, look for the spec/module control fn the activatable calls.

UNKNOWNS / RISKS: calling the open without the player; driving Walter (graphicsRootNode) cleanly
through the doorway (collision/clipping); whether the indoor area needs loading for him to be visible
inside. Treat like the map-teleport hunt: find the function, call it, then handle the follow-ons.

IMPLEMENTED (build 03:59, PENDING IN-GAME TEST):
- WalterWalker:_setWoodshopDoor(dir) resolves the AO (tinyShed01 nearest woodshopDoor.near + saveId
  doorRotate02, cached in self._woodshopDoorAO) and calls ao:setDirection(dir). Confirmed setDirection
  works hands-free (vlDoorTest, doorRotate02 = entry door).
- Waypoint flags openDoor/closeDoor in _updateWalk arrival branch call _setWoodshopDoor(+1/-1).
- Config VLConfig.WALTER_WALK.woodshopDoor = { near={-778.6,106.7}, config="tinyShed01", saveId="doorRotate02" }.
- Route `woodshopVisit` (manualOnly): home → woodShop → shedApproach(openDoor) → shedDoor →
  shedInside(pause 45) → shedDoorB → shedApproachB(closeDoor) → woodShopB → home. Test:
  `vlWalk grandpa woodshopVisit`. Test cmd vlWalterDoor <1|-1>.
LIGHTS (build 04:23, confirmed via=manual): spec_lights.groups[1] "Shed lights". Toggle =
set group.isActive + placeable:updateLightState(group.index) + placeable:lightSetupChanged()
(setLightState/setLightsState don't exist on this build). WalterWalker:_setWoodshopLights(on) does
this via the shared _resolveShed() (caches the tinyShed01 placeable; both door + lights use it).
Waypoint flags lightsOn/lightsOff added. woodshopVisit route now: shedApproach(openDoor) → shedInside
(lightsOn + pause45) → shedDoorB(lightsOff) → shedApproachB(closeDoor). Test: vlWalterLights <1/0>.

DONE: woodshopVisit slotted into the schedule (14-16, "craftsman hour"; produceStand shrank to
12-14). Lights toggle = placeable:setGroupIsActive (clean, no red text). Hunt dump-probes stripped;
kept vlDoorTest/vlLightTest + vlWalterDoor/vlWalterLights. Engine APIs documented in
journals/engine-api.md; commands in journals/console-commands.md. Feature COMPLETE.
Full day: 5am morningDeparture · 6-9 checkingPumps · 9-12 mailbox · 12-14 produceStand ·
14-16 woodshopVisit · 16-19 home · 19 eveningReturn (inside for the night).

Diagnostics added in main.lua: vlDoorScan, vlDoorObj, vlDoorAO, vlDoorAct, vlDoorTest, vlWalterDoor.
Strip the vlDoor* probes when done (like the Visit-hunt diagnostics); keep vlWalterDoor.
