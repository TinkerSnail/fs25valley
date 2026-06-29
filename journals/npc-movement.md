# NPC Movement & Walk Loops

How Valley Life moves NPCs through the world. Implementation in
`src/scripts/NPCEntity.lua` and `src/NPCConfig.lua`.

---

## Engine spline networks (2026-06-28) — there IS a pedestrian spline system

The base game's `mapUS.i3d` carries **three separate spline families** (all under the map root,
authored as `<Shape>` nodes):

| Network | Group node / hook | Count | Per-spline userAttributes | What it drives |
|---|---|---|---|---|
| **AI / traffic roads** | `trafficSplines` (nodeId 20826) → `TrafficSystem.onCreate` + AISystem | ~1222 `spline###` shapes | `speedLimit`, `maxSpeedScale` | Ambient traffic vehicles AND AI workers/helpers. This is what `gsAISplinesShow` toggles ([[console-commands]]). |
| **Pedestrian walk paths** | `pedestrianSystem` (nodeId 22247, `visibility="false"`) → `PedestrianSystem.onCreate`, reads `config/pedestrianSystem.xml` | 26 shapes: **18 `…Loop` + 8 `…Connetion`** (sic) | `density` (e.g. 0.2), `groupName` ("standard"), `width` (2) | **Ambient townsfolk walking around town.** |
| non-character | — | fences, `ShipMover_spline` | — | static geometry / scenery animation, not characters |

**Answer to "are there walk splines, not just AI-driving ones?": YES.** The pedestrian network is
a *distinct* spline system from the AI/traffic road network. `…Loop` splines are walking circuits;
`…Connetion` splines join loops together. Eight `pedestrianCrossing` TransformGroups sit where the
walk paths meet roads.

**Split of responsibility:**
- The **geometry** (where they walk) = the splines baked into `mapUS.i3d`. Each spline's userAttributes
  set spawn `density`, the `groupName` (→ time window / weather rules), and path `width`.
- The **roster** (who walks) = `config/pedestrianSystem.xml`: appearance variations + walk/idle clips +
  `<group>`s with `timeFrom/timeTo` (e.g. `standard` = 08:00–17:25) and `<prevent rain/snow>` weather gates.
  Note `standardStatic` group = pedestrians that just stand and idle (the `staticIdleAnimation` list).

**These are NOT the named NPCs** (GRANDPA/Walter, ANIMAL_DEALER/Katie, etc. — [[reference-basegame-npc-roster]]).
They're anonymous crowd-fill, spawned by `density` along the splines, but built on the **same
`playerM`/`playerF` rig and the same `NPCWalkMale01Source` / `NPCWalkFemale01Source` clips** our own
NPCs use (player-can ⇒ NPC-can). The engine handles their path-following automatically — no per-waypoint
Lua like our `workLoop`.

**For Valley Life:** our NPCs (Walter, Marta) use hand-authored `workLoop` waypoints (below), not these
splines, because `PedestrianSystem`/`TrafficSystem` are engine-driven off map-i3d spline nodes + their
`onCreate` callbacks (sealed in `dataS.gar`). To ride the pedestrian system we'd need pedestrian-spline
`<Shape>`s with the right userAttributes in our own map i3d. Plausible future lever for ambient
background townsfolk; not a path for a *scripted, named, conversational* NPC.

### Can our named NPCs walk these pedestrian splines? (deep dive, 2026-06-28)

**Hypothesis (user):** make Walter (GRANDPA) + Marta walk the base-game pedestrian splines "the same way
we got Walter to drive the truck on the AI splines" ([[walter-truck-driving]]).

**Correcting the analogy first.** The truck does NOT literally "ride a spline." It uses the **vehicle AI
navigation map** — a costmap baked from the road splines via `addRoadsToVehicleNavigationMap` — plus
`AIJobGoTo` pathfinding and C-level vehicle steering/braking. The splines are just the *source data*; the
off-network yard legs are hand-driven recorded waypoints. So "the truck way" = (a) a sealed engine
subsystem for the on-network part + (b) our own waypoint follower for the off-network part.

**Mapping that onto walking gives two paths:**

- **Mechanism A — ride the `PedestrianSystem` engine** (the literal truck-analog: a sealed subsystem like
  the vehicle AI). **Uncertain / not recommended.** `PedestrianSystem.lua` is sealed in `dataS.gar` (NOT in
  our decompiled dumps — would have to `fs-luau-decompile` it to even know the API). And it appears to
  **spawn and own its own anonymous pedestrians** by `density`; nothing shows it can *adopt* an existing
  named `Human`/NPC, and if it could it would likely strip our control the way `AIJobVehicle:aiJobStarted`
  re-randomized the truck driver. Walter/Marta need to keep their schedule, stop-and-face, conversation,
  and clip-swap behavior — an engine crowd system fights all of that.

- **Mechanism B — SAMPLE the spline geometry and feed our existing walker. ✅ RECOMMENDED.** This is the
  in-spirit analog of the *controlled* half of the truck work (recorded waypoints → our own driver) and
  needs **no sealed API**. The engine exposes public spline primitives (used by `AISystem`, confirmed in
  `dumps/api/decompiled/AISystem.lua`):

  ```lua
  local len = getSplineLength(spline)            -- meters
  local step = desiredMeters / len               -- normalize a meter-step into spline-time
  for t = 0, 1, step do
      local wx, wy, wz = getSplinePosition(spline, t)   -- world XYZ at param t ∈ [0,1]
      local dx, dy, dz = getSplineDirection(spline, t)  -- tangent = facing at t
      -- → emit { x = wx, z = wz } as a waypoint (our walker terrain-snaps y)
  end
  ```

  Resolve a `pedestrianSpline##Loop` node **by name** with the walker's existing
  `WalterWalker:_findNodeByName(root, name)` (already used for bones), sample it into a waypoint list, and
  hand it to the **existing** `WalterWalker:_updateWalk` / `VLNPCEntity:_updateWalkLoop` — which already do
  turn-then-walk, stop-and-face, pause, and walk-clip swap. We only swap the *source* of waypoints from
  hand-captured `vlPos` to the authored spline. **Loops are closed circuits** (ideal for a repeating route);
  `Connetion` splines join loops if we want a longer path. Bonus: authored, sidewalk-correct town routes
  for free instead of hand-capturing every point.

**What B reuses vs. the truck:** same idea (ride the base game's authored route network) but with the
**fully public `getSpline*` primitives** instead of a sealed subsystem, and our proven walker instead of
the vehicle nav agent. Walking is kinematically trivial next to driving (no steering/braking/collision
physics), so we do NOT need the PedestrianSystem at all.

**Confirmed preconditions (all ✅):**
1. Valley Life runs on **mapUS / Riverbend Springs** ([[map-riverbend-springs]]), so the
   `pedestrianSpline##` nodes are present in the live scene and resolvable by name. (`visibility="false"`
   on the `pedestrianSystem` group hides the debug geometry; it does NOT remove the nodes.)
2. `getSplineLength` / `getSplinePosition(spline,t∈[0,1])` / `getSplineDirection` / `I3DUtil.getIsSpline`
   are native and callable from mod Lua (AISystem uses exactly this).
3. The mod already resolves scene nodes by name (`_findNodeByName`) and terrain-snaps y in the walker.

**Open items to settle in a POC (the only real unknowns):**
- **Find the map ROOT to start the name-walk.** Bones search from the character's `graphicsNode`; for map
  splines we need the map i3d root (try `getRootNode()` / the map's loaded root; the `pedestrianSystem`
  group is nodeId 22247 *at author time* — IDs change per session, so resolve BY NAME, never by id).
- **Which spline sits where.** A few have explicit translations in `mapUS.i3d` (e.g. `…17Loop` at
  x≈45.3 z≈-122; `…15Loop` at x≈-82 z≈-95). Pick the loop nearest Walter's woodshop / Marta's office.
- **Sampling density + smoothing** so the gait reads natural (start ~2–3 m steps; our turn-then-walk
  handles corners).

**POC plan:** a `vlPedSpline <name>` console command that (1) resolves the named spline, (2) samples it
with the loop above, (3) drops debug markers / dumps the points, then (4) feeds them to Walter's walker as
a one-off route. If the markers trace the sidewalk and Walter follows them, the hypothesis is proven and
we generalize to a config knob (`workLoop = { splineName = "pedestrianSpline17Loop" }`).

**POC BUILT (2026-06-29).** `vlPedSpline <splineName> [stepMeters]` ([[console-commands]]) is implemented in
`main.lua` (`VLConsole:pedSpline`). It resolves the spline by name from `getRootNode()` (reusing the
`vlPedSplinesShow` recursive `findByName`), confirms `I3DUtil.getIsSpline`, then samples with the AISystem loop
(`stepSize = stepMeters/getSplineLength`, default 2.5 m, `getSplinePosition(spline, clamp(t,0,1))`). It builds a
synthetic loop and calls `ww:_beginLoop(loop)` — the same synthetic-loop injection `_startReturnToTruck` uses.

**Placement (2026-06-29, user chose "nearest point"):** the command does NOT require pre-positioning Walter,
and `vlMoveGrandpa` does NOT combine with it — the walker drives off its cached `_wx/_wz` (seeded ONCE in
`_acquireNode`, WalterWalker.lua:181), which `vlMoveGrandpa` (moves the engine GRANDPA node only) leaves stale,
so the first walk frame snaps him back. Instead `vlPedSpline` finds the spline sample NEAREST his current
`_wx/_wz`, sets `_wx/_wy/_wz` + `setTranslation` directly (terrain-height snap, the same write `_updateWalk`
does), so he "steps onto" the closest sidewalk. The route then runs the circuit from that index, WRAPS around,
and ends just before the start (`endOnArrival` → idle). Every wp logged `[PedSpline] <name> wpN -> sIDX =(x,z)`.

**Not yet verified in-game** — next: `vlPedSplinesShow` → pick a loop near the woodshop → `vlPedSpline <that>`,
watch him snap onto it and trace it; then promote to a `workLoop = { splineName = "pedestrianSpline17Loop" }` knob.

---

## Work loop overview

An NPC with a `workLoop` table in `VLConfig.VILLAGER_SPAWNS` will walk a
waypoint circuit during work hours. The loop restarts every **2 game hours**
(measured in game time, not real time) once the NPC has returned to waypoint 1.
The trigger only fires during work mode (Mon–Fri 5:30 AM–4:30 PM, not a
holiday) and will not start a new loop while one is already running.

```lua
workLoop = {
    waypoints = {
        { x = 412.66, z = -669.52 },                              -- [1] office wall (loop start/end)
        { x = 413.54, z = -686.39 },                              -- [2] door threshold
        { x = 413.52, z = -688.02 },                              -- [3] clear of door
        { x = 411.21, z = -688.28, pauseMinutes = 30 },          -- [4] mailbox
        ...
        { x = 423.66, z = -660.75, pauseMinutes = 30, pauseRy = math.rad(-45) }, -- bulletin board
    },
    speed = 1.2,  -- m/s
}
```

Waypoint `[1]` is always the home/start position. When the NPC reaches it the
loop ends; it restarts at the next 2-hour tick.

---

## Waypoint fields

| Field | Type | Description |
|---|---|---|
| `x`, `z` | number | World position (y auto-snapped to terrain). |
| `pauseMinutes` | number | How long to idle at this waypoint (in **game minutes**). |
| `pauseRy` | number | If set, NPC smoothly rotates to this facing (radians) during the pause. |

### `pauseMinutes` is game time, not real time

At the default FS25 time scale (~5×), one real second ≈ 5 game seconds. A
30-game-minute pause is about **6 real minutes** at 5× — or as little as a few
seconds at 120×. Tune for how your save is configured.

---

## Walk animation

NPCs use **direct-track animation** (same pattern as idle):

- At walk start: `assignAnimTrackClip` / `enableAnimTrack` swaps track 0 from
  the idle clip to the walk clip.
- At walk end / pause: reverts track 0 to the idle clip.
- `gfx:update()` is skipped while either track is direct — the engine advances
  it automatically.

**Clip names discovered via `vlAnimClips`:**

| Clip | Slot | Notes |
|---|---|---|
| `idle1FemaleSource` [32] | Female idle | Default female idle |
| `idle1Source` [22] | Male idle | Default male idle |
| `NPCWalkFemale01Source` | Female walk | NPC-quality gait ✓ |
| `NPCWalkFemale02Source` | Female walk | Alternative NPC gait |
| `NPCWalkMale01Source` | Male walk | NPC-quality gait ✓ |
| `NPCWalkMale02Source` | Male walk | Alternative NPC gait |
| `walkFwd1FemaleSource` [33] | Player walk | Looks like jogging — avoid for NPCs |

Clip indices are from `getAnimClipName(charSet, index)` enumeration (0–120).
NPC clips are prioritized in `WALK_CLIP_CANDIDATES_FEMALE/MALE` arrays.

### Swapping the clip to change POSE (2026-06-23) — the lever for a held/steady arm

The body is driven by whichever clip is on track 0 — **NOT** by bone posing (runtime `setRotation` on
bones loses to the clip at render: R13, see [[walter-walker-history]]). So to change his whole-body
pose you assign a DIFFERENT clip. `vlWalterClip <name|index|off>` does this (sets `_clipOverride`;
`_startWalkAnim` plays it instead of the walk clip — visible only while he's actively WALKING, since
idle runs `orig()` over track 0). Full `vlAnimClips grandpa` dump = 87 clips (0–86); the prop-relevant ones:

| Clip | Poses | Use / catch |
|---|---|---|
| `chainsaw_walkSource` [56] / `chainsaw_idleSource` [31] (+ strafe/backward/cut) | walk/idle **gripping a tool**, arms steady & forward, NO swing | the only COMPLETE walk-while-holding (legs AND arms correct) — but **two-handed**, imperfect for a 1-handed flashlight |
| `horse*` [4–21] (horseIdle02, horseWalk/Canter/Trot…) | arms **bent at the elbow, hands forward** (reins) — nicer "holding" shape | but poses the LEGS astride → breaks the walk. Good arms, wrong legs |

- **There is NO flashlight / generic one-handed-hold clip** — confirmed by the full 87-clip charset
  dump: the only tool-holding anims are the two-handed `chainsaw_*` family (walk/idle/strafe/cut/
  backward). No one-handed carry/hold/lantern clip exists. (`plyrFlashlightOn_01` in the dump is the
  toggle SOUND from `flashlight.xml`, not an animation.)
- **CORRECTION (2026-06-23): "first person only" was WRONG.** `lockFirstPerson="true"` is on the
  `<graphics>` node of EVERY handtool (all 3 chainsaws, sprayCans, the kärcher lance, horseBrush — not
  just the flashlight), so it is NOT a "this tool only exists in first person" marker. It's a per-camera
  visibility flag: hide the full model when the FP camera is active and use the separate `<firstPersonNode>`
  instead. In THIRD person / for remote MP players, the full `graphics` model IS drawn, attached to the
  hand via `handNode`. **So a remote player holding a flashlight looks like: normal walk/idle clip (open
  hand, arm swinging) + flashlight stuck to the hand bone — the engine does NOT steady or pose the arm.**
  ⇒ The AUTHENTIC "player holding a flashlight" look is the OPEN-HAND swing (option b). `chainsaw_walk`
  (option a, our current `flashlightWalkClip` default) is MORE posed than the real game — reads as a
  two-handed chainsaw grip up close. Pure style call; the `flashlightWalkClip` knob flips between them
  (clip name = chainsaw carry; nil/"" = authentic open-hand swing). Player rig IK/arm-pose logic that
  could aim a one-handed hold lives in the sealed `.gar` (player controller), not borrowable for the
  NPC-manager-driven GRANDPA — which is why attach-to-hand + clip-swap is our only lever.
- **"Held arms + walking legs" would need clip BLENDING** (walk on one track + an arm pose on a higher
  track with a bone mask) — possible in principle, a real step up, and the base clips aren't masked for
  it. Practical flashlight options: (a) `chainsaw_walk` if the two-handed look passes, or (b) accept
  the open hand + natural swing.

---

## Rotation & turn-then-walk

**Turn rate:** `WALK_TURN_RATE = math.rad(240)` (240°/sec)

**Turn-before-walk:** If the angle gap between current facing and the next
waypoint is > `WALK_TURN_THRESHOLD` (25°), the NPC pivots in place first
before advancing position. This prevents moonwalking/sideways sliding when
changing direction sharply.

```lua
local targetRy = math.atan2(nx, nz)
self.rotation.y = lerpAngle(self.rotation.y, targetRy, maxStep)

local diff = targetRy - self.rotation.y  -- (clamped to [-π, π])
if math.abs(diff) <= WALK_TURN_THRESHOLD then
    self.position.x = self.position.x + nx * step
    self.position.z = self.position.z + nz * step
end
```

**`lerpAngle`** handles wrap-around correctly (diff clamped to `[-π, π]`).

### Rotation at pause (`pauseRy`)

If a waypoint has `pauseRy`, the NPC smoothly rotates to that facing during
the idle pause using the same `lerpAngle` + `WALK_TURN_RATE`. This is set
in the waypoint config, not the code.

---

## Stop-and-face (talk while mid-route)

Both Marta (`VLNPCEntity:_updateWalkLoop`) and Walter (`WalterWalker:_updateWalk`) **stop walking and
turn to face the player** when he comes within `APPROACH_RANGE` (6 m), or while she/he is talking, then
**resume** when he leaves. This makes them "ready to talk" mid-route. Marta: reverts to the idle clip
(`_onWalkEnd`), lerps `rotation.y` toward the player, holds position, `return`s (no waypoint advance);
`_stoppedForPlayer` flag restarts the walk clip on resume. Walter: same, plus he must run `orig()`
during a base-game conversation or the conversation can't animate (he'd glide).

## Waypoint design tips

- **Door frames need 3 waypoints**: one just before the door, one at the
  threshold, one clear of the door on the other side. Without the intermediate
  point the NPC clips through the wall while rotating.
- **Sharp corners need intermediate waypoints** to prevent wall clipping. Add
  a waypoint after every ~90° turn.
- **Capture coords with `vlPos`** while standing in-game at each desired point.
- **Return path**: if the NPC enters a doorway, the return trip needs the same
  waypoints in reverse order.
- Waypoint `[1]` ends the loop. Place it at the NPC's spawn position.

---

## Console commands for work loops

| Command | What it does |
|---|---|
| `vlWalk <npcId>` | Force-start the work loop from waypoint 2 immediately. |
| `vlSkipPause <npcId>` | Skip a current pause and trigger movement to the next waypoint. |
| `vlAnimClips <npcId>` | Enumerate all animation clip names (0–120) on the NPC's char set. |

---

## Marta's work loop (0.1.0.70)

Route: **office wall → door threshold → clear of door → mailbox (30 min) →
clear of door → door threshold → path to bulletin board × 3 waypoints →
bulletin board (30 min, faces north-west) → path home → office wall**

Full waypoint table in `src/NPCConfig.lua` under `VLConfig.VILLAGER_SPAWNS.marta.workLoop`.

---

## Hand props (research finding)

No clipboard or paper-based prop exists in FS25 base `data/handTools/`.
Available hand tools: flashlight, horse brush (Husqvarna, Jonsered, McCulloch,
Stihl chainsaw variants), Kärcher pressure washer lance, and spray cans.
A custom i3d prop would be needed to give Marta something to hold.

### CONFIRMED: NPCs have named, animated hand bones (2026-06-22, `vlWalterBones`)

Dumped GRANDPA's full node tree (`vlWalterBones` in main.lua — recursive walk of
`graphicsRootNode`, kept as a reusable research command). He uses the standard **`playerM`**
rig — **the same skeleton the player uses** (confirms [[feedback-npc-can-do-what-player-can]]:
a player handtool attaches to an NPC the same way). Named bones, Mixamo-style:

```
playerM/player_skeletonRootNode/animationRootNode/root/Hips/Spine/Spine1/Spine2/
  RightShoulder/RightArm/RightForeArm/RightHand   ← the grip bone (this session id=21916)
  ...                                LeftHand      ← (id=21896)  + every finger joint
```

- **The hand bone is REAL and ANIMATED.** It lives under `animationRootNode/root/Hips`, so the
  walk/idle clips pose it every frame → a node `link()`ed as a child of `RightHand` follows the
  hand through the arm swing for free. No bone-driving code needed.
- **Resolve it BY NAME, never by id** — node ids change every session (the iron rule of this
  project). Walk the named path or `getChild`/`I3DUtil.indexToObject` from `graphicsRootNode`.
- Beware NON-bone decoys named "hands": `playerM/GEO/bodyParts/mBody01/hands` and
  `.../GEO/attachments/.../hands` are **mesh groups**, not the skeleton. The bone is the one
  under `player_skeletonRootNode/animationRootNode/root/Hips/...`.

**To actually hold a flashlight (remaining work, NOT yet built):** (1) **use the BASE-GAME
flashlight** — the player equips `data/handTools/.../flashlight` at runtime, so that i3d
demonstrably loads on demand (player-can ⇒ NPC-can). The "i3d can't load from a pak at runtime"
limit is about VEHICLES ([[project-open-decisions]]), a different/narrower case — do NOT assume it
blocks handtools; default to the base asset and only fall back to a mod-bundled copy if a real load
attempt fails. The most faithful path is to reuse the player's flashlight **handtool** itself (it
already carries its hand-link node + spotlight); attaching just the i3d is the simpler fallback.
(2) load/resolve it, `link(RightHand, prop)`, set a small local translation/rotation so it sits in
the palm; (3) the beam comes with the handtool, or attach/enable a spotlight. Caveat: the walk/idle
clips pose an OPEN, swinging hand (no grip pose — we don't drive bone-level animation), so the prop
follows the hand but won't look gripped up close.

### Full base-game handtool palette (dump, 2026-06-22)

Everything a character could plausibly hold, from `$DATA/handTools/` (readable; path in
[game-files-and-xml.md](game-files-and-xml.md)). Six functional types, ~13 model variants:

| Holdable | `type` | XML (under `$DATA/handTools/`) | Notes |
|---|---|---|---|
| **Flashlight** | `flashlight` | `brandless/flashlight/flashlight.xml` | model + **real spotlight** (IES beam, 50 m, 60° cone) + lens self-illum. **Our target.** |
| Horse brush | `horseBrush` | `brandless/horseBrush/horseBrush.xml` | small handheld brush |
| Chainsaw — Husqvarna XP550 | `chainsaw` | `husqvarna/xp550/xp550.xml` | + shared `treeCutters/` + exhaust i3ds. Thematic for Walter (woodshop). |
| Chainsaw — Jonsered CS2252 | `chainsaw` | `jonsered/cs2252/cs2252.xml` | |
| Chainsaw — McCulloch CS410 | `chainsaw` | `mcCulloch/cs410/cs410.xml` | |
| Chainsaw — Stihl MS261 | `chainsaw` | `stihl/ms261/ms261.xml` | |
| Pressure-washer lance | `highPressureWasherLance` | `kaercher/hds9184M/hds9184MLance.xml` | Kärcher lance |
| Spray can (7 colors) | `sprayCan` | `stihl/sprayCan/sprayCan{Blue,Green,Orange,Pink,Red,White,Yellow}.xml` | marking spray |
| (empty hands) | `hands` | `hands.xml` | the default "nothing held" |

**Universal attach pattern** (from `flashlight.xml` `<base>`):

```xml
<base>
  <filename>$data/handTools/brandless/flashlight/flashlight.i3d</filename>
  <graphics  node="graphics"/>        <!-- the visible model -->
  <handNode  node="handNode"/>        <!-- the GRIP-MOUNT node — align THIS to the hand bone -->
  <firstPersonNode node="firstPersonNode"/>
</base>
<flashlight>
  <light node="lightNode" mesh="selfIllum" distance="50" coneAngle="60" iesProfile="...flashlight.ies"/>
</flashlight>
```

Every handtool defines a **`handNode`** (its grip origin) — that's the lever for putting any of these
in `RightHand`: load the tool's i3d, position so `handNode` coincides with `RightHand`, link it as a
child so it follows the animated hand. The flashlight additionally has a `lightNode` we enable for the
beam.

**Can't copy the LOCAL player's hold — but MP players DO hold it on the body (2026-06-23, corrected):**
FS25 locks **your own** view to first person while you hold a handtool, so the LOCAL player's tool is on
the FP camera/arms rig (the i3d's `firstPersonNode`), camera-relative and useless for a body. That's why
`vlPlayerFlashlight` found no `flash` node under `g_localPlayer.rootNode`/`graphicsRootNode`. **But a
REMOTE player in multiplayer is rendered in THIRD person and DOES hold the tool on the body skeleton** —
the tool's `graphics` model attached to the hand via `handNode`. We just can't observe a remote player in
single-player. So there IS an authored third-person hold; it's the tool's `handNode` grip (exactly what
we seat to) + the body's normal locomotion clip. Use `handNode` + manual seating.

**Per-tool third-person behavior (2026-06-23). ⚠️ CORRECTED — earlier "only the chainsaw is posed" was
WRONG.** The 87-clip dump only catches KEYFRAMED named animations. It says NOTHING about **procedural IK**,
which the engine ALSO uses to pose/aim the arm with no clip (same mechanism as vehicle drivers gripping
the wheel; the player config carries an IK-chain system — see the `<pose>`/IK note below). So "no clip"
≠ "no arm pose." Two distinct mechanisms produce a posed body:

1. **Keyframed clip set** — only the `chainsaw` has one (`chainsaw_walk/idle/strafe/cut`), a full
   two-handed hold + use animation. Appears in the clip dump.
2. **Procedural arm-aim IK** — the rig HAS `rightArm`/`leftArm` IK chains (`playerM.xml`
   `player.ikChains.ikChain`, applied via `IKUtil`/`HumanModel`).
   **CORRECTED 2026-06-23 by decompiling the actual game scripts** (via `fs-luau-decompile`, see
   game-files-and-xml.md): `HandToolSprayCan.lua` has **ZERO** arm/pose/IK/`setRotation` calls — it only
   raycasts a target tree via the player `targeter`, **shakes the can node** (sine wobble), and fires a
   `SprayCanEvent` decal. AND `HumanModel:loadIKChains` does `if isRealPlayer then deleteIKChain("rightArm"/
   "leftArm"/feet/spine)` — the player loads with `isRealPlayer=true` (`HumanGraphicsComponent` line 310/312),
   so those arm-IK chains are DELETED for players. ⇒ **There is no spray-can usage CLIP, and the spray-can
   does not pose the arm at all.** The earlier "arm fully animated to lift and point" (a Gemini summary)
   is NOT borne out by the source — the can shakes, paint emits, the targeted tree gets a decal; the arm
   stays in the normal hold pose. (The kept IK chains are for non-real characters — NPCs/pedestrians,
   likely foot-planting; whether anything drives a non-player's arm aim is untraced.)

| Tool `type` | Body in 3rd person | Action |
|---|---|---|
| `chainsaw` | **Keyframed** two-handed hold/use clips; `handNode`=`cutHandNode`, `useLeftHand="true"`; `runMultiplier="0"` | cut anim + chips/dust particles + chain-scroll shader |
| `sprayCan` | **Procedural IK arm-aim** — lifts & points at the target (CONFIRMED) | paint mist particle + instant decal on the bark |
| `highPressureWasherLance` | **IK aim** (`mustBeHeld`, `runMultiplier="0"`) — supported: FS25 **Patch 1.7 changelog** fixed "player character placement when controlling high pressure washer" (you only fix character *placement* if the body is posed) | water-jet particle |
| `horseBrush` | grooming an animal — likely an arm motion too; UNCONFIRMED | effect on the HORSE |
| `flashlight` | **Passive** (no target to aim at) → most likely just held in the hand, beam follows the hand. Web search (2026-06-23) confirmed flashlights HAVE a third-person view but did NOT document the exact arm pose, so this stays "probably held," not confirmed | light cone (networked) |

*(Evidence basis: spray-can arm-aim is user/community-confirmed; washer is the Patch 1.7 character-placement
fix; flashlight third-person-visible but arm pose undocumented. Sources logged in the 2026-06-23 session.)*

**Corrected rule:** a posed body in 3rd person comes from EITHER a keyframed clip (chainsaw only) OR
procedural arm-aim IK (action tools that point at a target — spray can confirmed). The flashlight is the
odd one out: passive, no target, so probably the open-hand-held case — but even that is now "probably,"
not confirmed. **Walter implication unchanged:** that player IK lives in the sealed handtool controller
and is driven by the player USING the tool on a target; it is NOT invoked for our NPC-manager-driven
GRANDPA, and runtime bone posing on him is the R13 wall. So our only levers remain **clip-swap**
(chainsaw set) + **attach-to-hand**; faking an aim pose for a non-chainsaw tool would need a custom clip.
### Hand SHAPES / grip poses — the `<pose>` system (2026-06-23)

A "hand shape" in FS25 is a **`<pose>`** (defined in `player.xsd`): an `id`, an `isDefaultPose` flag,
and a list of **`<rotationNode index="…" rotation="…"/>`** — i.e. *curl these finger bones by these
rotations*. The player config also carries an **IK chain** system (`target`, `targetOffset`,
`numIterations`, `positionThreshold`) for reaching. So a grip = a named set of finger-bone rotations.

**The base-game pose LIST is NOT dumpable — it's sealed.** No loose player/character config exists
under `$DATA` (no `player*.xml`/`playerModels.xml` data, no `<pose>` in loose XML, no `character/`
dir — verified 2026-06-23); `playerModels.xsd` points to a `filename` that resolves into `dataS2.gar`.
We have the SCHEMA (structure) but not the concrete pose ids/rotations. NPCs (GRANDPA via g_npcManager)
likely don't even load the player pose system.

**Walter's finger bones are all named and addressable** (`RightHandIndex1/2/3`,
`…Middle/Ring/Pinky/Thumb1/2/3` — from `vlWalterBones`), and a `vlGrip` tester `setRotation`s them.

**RESULT (2026-06-23): runtime finger posing FAILS — the ATTACH-vs-OVERRIDE rule.** `setRotation` on
the finger bones is wiped by the animation clip every render frame (the R13 wall — the engine
re-poses the whole skeleton from the active clip *after* all Lua). This also explains why the
flashlight works but a grip doesn't:

> **You can ATTACH a child to an animated bone (`link(RightHand, prop)`) — it INHERITS the animated
> pose and rides along. You CANNOT OVERRIDE a bone's own transform while a clip drives it — the clip
> wins.** Hanging props off the hand ✅; reshaping the hand itself ❌ (without baked animation clips).

So Walter holds the flashlight in an **open hand** — accepted. `vlGrip` is kept as an inert tester.
**DO NOT re-attempt finger posing via `setRotation`** (it's the same battle as R0–R17). The same rule
covers any future hand prop: attach it to `RightHand`, never try to curl the fingers around it.

**Working recipe (DONE, build 01:30):** load via `g_i3DManager:loadI3DFile("data/handTools/.../flashlight.i3d")`
(bare `loadI3DFile`/`$data` fails); resolve sub-nodes BY NAME (`graphics`/`handNode`/`lightNode` — NOT
`I3DUtil.indexToObject`, which returned nil); `link(RightHand, root)`; rotation = `-handNode.rot`
(beam faces forward ✅); position = an eyeballed offset into the palm — for the flashlight on GRANDPA:
**`(-0.102, 0.004, -0.079)`**; toggle visibility on the **graphics subtree recursively** (root-only
isn't enough) + the `lightNode`. Implemented in `WalterWalker` `_ensureFlashlight`/`_setFlashlight`.

**OFFICIAL POSE — LEFT hand (baked 2026-06-23).** The flashlight now lives in his **LEFT** hand so it
pairs with the `chainsaw_walk` carry (both hands forward, no arm swing — solves the swing the right way:
clip-swap + hand switch, no bone-fighting). Switch hands live with `vlWalterFlashHand left|right`
(drops + reloads the prop on the new bone). The left hand's bone axes are **mirrored** from the right, so
the auto grip rotation (`-handNode.rot`) alone points the beam wrong → a manual `rot` adjustment is needed
on top (tap `vlFlashRot x±/y±/z±`, 15°/tap; `vlFlashRot 0` resets; stored in `fc.rot` as **radians**).
Final values, tuned live and read from `log.txt` (the in-game console prints them, but the numbers only
survive in the live log — not the chat transcript), baked into `NPCConfig.WALTER_WALK.flashlight`:
- `handBone = "LeftHand"`
- `offset = { x = 0.078, y = 0.004, z = 0.061 }`  (meters; `vlFlash` nudges 1cm/tap)
- `rot = { x = 0.2618, y = 3.1416, z = 0.5236 }`  = **deg(15, 180, 30)** (radians; on top of auto grip)

The old right-hand offset `(-0.102, 0.004, -0.079)` is **obsolete** — there is a single shared `offset`,
so the left-hand numbers replace it.

**AUTO carry-clip (2026-06-23).** The `chainsaw_walk` pairing is now **automatic**, not a manual test
lever: whenever the flashlight is OUT he walks with the steady tool-holding clip (left hand forward,
no swing), reverting to the normal walk when it goes off. Wired at the single on/off chokepoint —
`_setFlashlight(on)` calls `_applyFlashlightWalkClip(on)`, which resolves the clip by name via
`findClip` (cached in `_flashlightClipIdx`) and toggles it through the existing R43 `setClipOverride`
lever (override on / nil off). So it fires for the auto seasonal-dusk path, the `vlWalterFlashlight 1`
force, AND `vlWalterFlashHand`. Clip name is the config knob `flashlightWalkClip = "chainsaw_walkSource"`
— set it to `nil`/`""` to ship the plain open-hand swing instead. The override only renders while he's
actively WALKING (idle runs `orig()` over track 0), so idle = open hand, walking = steady carry.
