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
