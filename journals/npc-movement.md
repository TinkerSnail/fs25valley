# NPC Movement & Walk Loops

How Valley Life moves NPCs through the world. Implementation in
`src/scripts/NPCEntity.lua` and `src/NPCConfig.lua`.

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

- **There is NO flashlight / generic one-handed-hold clip** — the flashlight is a "simple" handtool
  with no third-person body anim (also why the player only holds it in first person). The chainsaw is
  the one tool with full third-person hold/use anims.
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

**Can't copy the player's hold (2026-06-23):** FS25 **blocks third-person view while a handtool is
equipped**, so the player never holds a flashlight on the visible BODY skeleton — it's attached to the
first-person camera/arms rig (the i3d's `firstPersonNode`), whose transform is camera-relative and
useless for a third-person NPC body. So there is no player third-person hold to read off and copy.
Use the tool's own `handNode` (the authored third-person grip) + manual seating instead. `vlPlayerFlashlight`
confirmed: no `flash` node under `g_localPlayer.rootNode`/`graphicsRootNode` while holding it.
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
