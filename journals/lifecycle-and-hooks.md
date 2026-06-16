# Lifecycle & hooks

How Valley Life attaches to FS25 and what runs each frame. Implementation lives
in `main.lua`, `src/NPCSystem.lua`, `src/scripts/NPCEntity.lua`, and
`src/gui/NPCDialog.lua`.

**Mod version:** 0.1.0.42 - confirm in log: `Valley Life 0.1.0.42 loaded`.

---

## Module load order (`main.lua`)

`main.lua` is the only `extraSourceFiles` entry in `modDesc.xml`. It `source()`s
modules in dependency order:

1. Utils - `VectorHelper`, `TimeHelper`, `BirthdayHelper`, `OutfitCalendar`
2. `NPCConfig.lua`
3. Scripts - `NPCRelationshipManager`, `NPCEntity`, `NPCScheduler`, `NPCEventSequencer`
4. `gui/NPCDialog.lua`
5. `NPCSystem.lua`
6. Content - `Elara.lua`, `Kenji.lua`, `Marta.lua` (register heart events)

Console commands register at the bottom of `main.lua` (`VLConsole` + `addConsoleCommand`).

---

## Mission lifecycle hooks

All hooks use `Utils.appendedFunction` / `Utils.prependedFunction` (never replace
the base function outright).

| Hook | When | Callback | What it does |
|------|------|----------|--------------|
| `Mission00.loadMission00Finished` | Map / terrain ready (career only) | `onMissionLoaded` | `VLNPCSystem.new()` → `initialize()` → `loadFromFile()` |
| `FSBaseMission.update` | Every frame | `onMissionUpdate` | `g_valleyLife:update(dt)` inside `pcall` |
| `FSBaseMission.draw` | Every frame (HUD pass) | `onMissionDraw` | `g_valleyLife.dialog:draw()` |
| `FSBaseMission.delete` | Mission teardown (**prepended**) | `onMissionUnload` | `g_valleyLife:delete()` → `g_valleyLife = nil` |

**Not hooked:** `Mission00.update` - per-frame work uses `FSBaseMission.update`.

**Career guard:** `onMissionLoaded` only runs when `g_currentMission` is a
`FSCareerMission` (or `FSCareerMission` is undefined). Menu / non-career maps
skip init.

**Startup log lines** (one per successful hook):

```
[ValleyLife] Hooked Mission00.loadMission00Finished.
[ValleyLife] Hooked FSBaseMission.update.
[ValleyLife] Hooked FSBaseMission.draw.
[ValleyLife] Valley Life 0.1.0.42 loaded; lifecycle hooks installed.
```

---

## Per-frame update chain

```
FSBaseMission.update(dt)
  └─ onMissionUpdate (pcall)
       └─ VLNPCSystem:update(dt)
            ├─ OutfitCalendar:poll() → applyOutfitCalendarChange on season/mode transition
            ├─ for each NPC: VLNPCEntity:update(dt)
            │     ├─ terrain snap (rootNode Y)
            │     └─ updateGraphics(dt) - idle animation (see below)
            └─ VLNPCDialog:update(dt)
                  ├─ if heart event active: hide Press-R prompt, return
                  ├─ restoreInputContextIfStuck()
                  ├─ close stale reply selector if event ended
                  └─ register/unregister VL_INTERACT prompt by proximity
```

`dt` is engine delta time (milliseconds), same as the base mission update.

---

## Draw pass

```
FSBaseMission.draw()
  └─ onMissionDraw
       └─ VLNPCDialog:draw()
            ├─ drawSpeech() - narration panel + continue hints
            └─ reply selector panel (if open)
```

Dialog is drawn in normalized screen space (`0–1`, bottom-left origin), not via
`g_gui` XML. See [dialog-boxes.md](dialog-boxes.md).

---

## Save / load

| When | Path | Hook |
|------|------|------|
| Mission load (after init) | `{savegame}/valleyLife.xml` | `VLNPCSystem:loadFromFile` from `onMissionLoaded` |
| Game save | same file | `FSCareerMissionInfo.saveToXMLFile` appended in `VLNPCSystem:hookSaveLoad()` |

Persisted: relationship values, completed heart events (`VLConfig.SAVE_KEY` in
`NPCConfig.lua`). NPC positions and outfits are **not** saved yet - they come
from `VILLAGERS` spawn data + live calendar.

---

## NPC spawn & animation (`VLNPCEntity`)

**Spawn:** `VLNPCSystem:initialize()` → `VLNPCEntity:spawn()` →
`buildAnimatedCharacter()` for each villager in `VILLAGERS`.

**Mesh:** `HumanGraphicsComponent.new()` → `initialize()` → `setStyleAsync(style, …)`.
- `isTempStyle = false`, `isOwner = false` (matches working NPC mod pattern).
- `gfx.soundsEnabled = false` - NPCs do not run footstep / HumanSounds updates.

**Idle animation (0.1.0.42):** direct anim-track mode (NPCFavor / VehicleCharacter
pattern), not per-frame `gfx:update()` alone:

1. On model load OK: `cloneAnimCharacterSet` from `g_animCache` (`AnimationCache.CHARACTER`)
   onto `gfx.model.skeleton`.
2. Find idle clip (`idle1Source`, `idle1FemaleSource`, …).
3. `assignAnimTrackClip` on track 0 → `enableAnimTrack` - engine advances enabled
   tracks automatically; **no** `gfx:update()` needed in direct mode.

Log on success:

```
[ValleyLife] 'Elara' idle animation: idle1FemaleSource (direct track)
```

**Fallback:** if direct setup fails (retried up to 8 frames), set ConditionalAnimation
params (`isIdling`, `isNPC`, …) and call `gfx:update(dt)` with sounds still off.

**Do not** call full `gfx:update()` on every NPC every frame without `soundsEnabled =
false` - `HumanSounds:update` inside `gfx:update` caused broken player controls on
some builds (0.1.0.40).

**Outfit reload:** `reapplyAppearance()` → `delete()` → `buildAnimatedCharacter()` again
(direct idle setup runs in the new load callback).

---

## Dialog input (summary)

| Action | Binding | When active |
|--------|---------|-------------|
| `VL_INTERACT` | `KEY_r` | Near villager - dynamic `registerActionEvent` from `dialog:update` |
| `VL_UP` / `VL_DOWN` | Arrow keys | Reply selector only (`modDesc.xml` + reply context) |
| `MENU_ACCEPT` / `SKIP_MESSAGE_BOX` | Enter / click | Speech box or reply confirm |

Reply selector enters input context `FS25_ValleyLife_REPLY` (`setContext` /
`revertContext`). `VLNPCDialog:delete()` and `restoreInputContextIfStuck()` prevent
stuck movement if the selector tears down oddly.

Details: [dialog-boxes.md](dialog-boxes.md).

---

## Global state

| Global | Set | Cleared |
|--------|-----|---------|
| `g_valleyLife` | `onMissionLoaded` | `onMissionUnload` |

Double-init guard: `onMissionLoaded` returns if `g_valleyLife ~= nil`.

---

## Testing hooks

- Mod loaded: log version string above.
- Update loop: `vlNear` (player + nearest NPC distance).
- Animation: spawn log lines per villager (`idle animation: … (direct track)`).
- Dialog draw: `vlEvent elara` during a heart event.
- Save: save game → check `{savegame}/valleyLife.xml` and `[ValleyLife] Saved to …` log.
