# Developer Console Commands — master directory

**This is the central directory of every `vl*` command** the mod registers (source of
truth: the `addConsoleCommand` calls in `main.lua` / `VLConsole`). Open the console with
**`~`** and type a command. Most print to the console **and**
`~/Library/Application Support/FarmingSimulator2025/log.txt`.

After code changes, run `./repack.sh` from the project root, then **fully quit
and relaunch** FS25. Confirm the log shows the expected mod version.

`npcId` is one of: **`elara`**, **`kenji`**, **`marta`** (the mod NPCs). Walter is the
base-game **`grandpa`** — `vlWalk` / `vlSkipPause` accept `grandpa`, and he has his own
`vlWalter*` commands (see the **Walter (GRANDPA)** section).

Sections: Outfit testing · Calendar & outfits · Relationship & events · World & spawn ·
NPC movement · **Walter (GRANDPA)** · Appearance · **Diagnostics & API probes**. The probes
are how we crack `.gar`-sealed engine APIs — the repeatable method is in
[engine-api.md](engine-api.md).

## Outfit testing (start here)

1. **Relaunch** after repack; check mod version in log.
2. **`vlSeason`** - calendar month, season, hour, active **work/leisure** mode, and why.
3. **`vlOutfit <npcId> work`** or **`vlOutfit <npcId> leisure`** - preview a slot (pauses
   calendar auto-switch for that NPC). **`vlOutfit <npcId> auto`** resumes calendar.
4. **Tweak clothing** - each command reloads the NPC immediately:
   - `vlTop`, `vlTopColor`
   - `vlBottom`, `vlBottomColor`
   - `vlOnepiece`, `vlOnepieceColor`
   - `vlShoe`, `vlShoeColor`
   - `vlGlove`, `vlGlovesColor`
   - `vlGlass`, `vlGlassesColor`
   - `vlHat`, `vlHatColor`
5. **List indices** - `vlTops`, `vlBottoms`, `vlOnepieces`, `vlShoes`, `vlGloves`,
   `vlGlasses`, `vlHats`, `vlStyle`.
6. **Base appearance** (not outfit slots): `vlFace`, `vlHair`, `vlHairColor`, `vlBeard`.
7. **Bake** - copy `item` / `color` into the right key in `src/NPCSystem.lua`
   (`appearanceSummerWork`, `appearanceFallLeisure`, etc.), then repack.

Clothing commands always edit the **active outfit mode** (work or leisure) for the
**current calendar season** (summer Jun–Aug, fall Sep–Nov, winter Dec–Feb, spring
Mar–May). Use `vlOutfit` to preview a different slot while tuning.

Watch `log.txt` for mesh paths (e.g. `tweedSportsJacket.i3d`) after each change.

## Calendar & outfits

| Command | Usage | What it does |
|---|---|---|
| `vlSeason` | `vlSeason` | Month, season, hour, outfit mode (work/leisure), reason. |
| `vlOutfit` | `vlOutfit <npcId> <work\|leisure\|auto>` | Preview work/leisure (pauses calendar) or `auto` to resume. |
| `vlBirthdays` | `vlBirthdays` | List villager birthdays; marks **(today!)** when applicable. |

**Automatic outfit mode** (`TimeHelper.getOutfitMode`):

- **Work** - Mon–Fri, 5:30 AM–4:30 PM, not a holiday.
- **Leisure** - before 5:30 AM, from 4:30 PM, all weekend, all holidays.

Holidays: fixed dates in `VLConfig.OUTFIT_HOLIDAYS` plus Memorial Day, Labor Day,
Thanksgiving (see `character-appearance.md`). Birthdays are tracked but do **not**
yet change outfit mode.

## Relationship & events

| Command | Usage | What it does |
|---|---|---|
| `vlRel` | `vlRel <npcId> <value>` | Set relationship (thresholds 20/40/60/80 for heart events). |
| `vlEvent` | `vlEvent <npcId>` | Force-start next uncompleted heart event. |
| `vlReset` | `vlReset <npcId>` | Clear completed events, relationship 0, abort in-progress scene. |
| `vlNear` | `vlNear` | Player pos, nearest villager, distance. |
| `vlWalterIntro` | `vlWalterIntro` | Force-play Walter's post-tour market intro (ignores the once-only flag). |
| `vlGuidedTour` | `vlGuidedTour` | Probe `GuidedTour` class/instance methods (hook-name discovery). |

## World & spawn

| Command | Usage | What it does |
|---|---|---|
| `vlPos` | `vlPos` | Player world position formatted for `VLConfig.VILLAGER_SPAWNS`. |

## NPC movement (work loop)

| Command | Usage | What it does |
|---|---|---|
| `vlWalk` | `vlWalk <npcId> [loopName\|index]` | Force-start a walk loop now (bypasses the 2-hour tick). `npcId` = `marta`/etc. **or `grandpa`** (Walter). With no loop arg, starts the loop active at the current hour; otherwise by name (e.g. `vlWalk grandpa mailbox`) or index. |
| `vlSkipPause` | `vlSkipPause <npcId>` | Skip the current mid-route pause and send them to the next waypoint. Works for the mod NPCs **and `grandpa`**. |
| `vlAnimClips` | `vlAnimClips <npcId>` | Enumerate all animation clip names (indices 0–120) on the NPC's char set. Useful for discovering walk/idle clip names. |

Work loops only run during **work mode** (Mon–Fri 5:30 AM–4:30 PM). Use `vlWalk`
to test without waiting for the 2-hour trigger. Use `vlSkipPause` to fast-forward
through a `pauseMinutes` stop without touching the clock. Both Marta and Walter
**stop & face the player** within ~4 m mid-route, then resume.

See [npc-movement.md](npc-movement.md) for full work loop documentation.

## Walter (GRANDPA)

Walter is the real base-game GRANDPA, hand-driven by `WalterWalker`. His loops:
`checkingPumps` (6–9), `mailbox` (9–12), `produceStand` (12–16), `eveningReturn` (19),
plus `morningDeparture` and `woodshopVisit` (manual-only).

| Command | Usage | What it does |
|---|---|---|
| `vlWalk grandpa` | `vlWalk grandpa [loop]` | Start one of his loops now (e.g. `woodshopVisit`). |
| `vlSkipPause grandpa` | `vlSkipPause grandpa` | Skip his current pause (e.g. the 45-min woodshop hang-out). |
| `vlWalterShow` | `vlWalterShow` | Reveal him if he "stepped inside" (door disappear). |
| `vlWalterHide` | `vlWalterHide` | Hide him on demand (test the door disappear). |
| `vlWalterMorning` | `vlWalterMorning` | Trigger the 5am morning departure (door → home) now. |
| `vlWalterDoor` | `vlWalterDoor <1\|-1>` | Open (1) / close (-1) the woodshop door via his own code. |
| `vlWalterLights` | `vlWalterLights <1\|0>` | Turn the woodshop lights on (1) / off (0). |
| `vlWalterYOffset` | `vlWalterYOffset <m>` | Live-tune his driven height (positive lowers); fixes float. |
| `vlWalterStairLift` | `vlWalterStairLift <m>` | Live-tune the convex bow lift on stair segments. |
| `vlWalterIntro` | `vlWalterIntro` | Force-play his post-tour market intro (ignores the once flag). |
| `vlWalterDump` | `vlWalterDump` | Dump GRANDPA runtime state (spot, components, graphicsNode). |
| `vlGrandpa` | `vlGrandpa` | Probe runtime paths to GRANDPA's rootNode (walk-loop research). |
| `vlMoveGrandpa` | `vlMoveGrandpa <x> <z>` | Teleport GRANDPA to a world position (research). |

## Appearance diagnostics

| Command | Usage | What it does |
|---|---|---|
| `vlStyle` | `vlStyle` | Dump style configs (item/color counts) for male + female. |
| `vlHairColors` | `vlHairColors` | Print hair color palette (index → RGB). |
| `vlDlg` | `vlDlg` | Probe native dialog/choice widgets. |

### Face, hair, beard (base - always worn)

| Command | Usage |
|---|---|
| `vlFace` | `vlFace <npcId> <index>` - male 1–10, female 1–6 |
| `vlHair` | `vlHair <npcId> <item>` (0 = none) |
| `vlHairs` | `vlHairs <npcId>` |
| `vlHairsForHat` | `vlHairsForHat <npcId>` - hair that works under hats |
| `vlBeard` | `vlBeard <npcId> <item>` (0 = none, males only) |
| `vlBeards` | `vlBeards <npcId>` - compatible with current face |
| `vlHairColor` | `vlHairColor <npcId> <index>` - hair + beard unified |
| `vlBeardColor` | `vlBeardColor <npcId> <hair> <beard>` - experimental split |

### Clothing layers (outfit slot - use after `vlOutfit`)

| Layer | List | Set | Color |
|---|---|---|---|
| Top | `vlTops` | `vlTop` | `vlTopColor` |
| Bottom | `vlBottoms` | `vlBottom` | `vlBottomColor` |
| Onepiece | `vlOnepieces` | `vlOnepiece` | `vlOnepieceColor` |
| Footwear | `vlShoes` / `vlFootwears` | `vlShoe` | `vlShoeColor` |
| Gloves | `vlGloves` | `vlGlove` | `vlGlovesColor` |
| Glasses | `vlGlasses` | `vlGlass` | `vlGlassesColor` |
| Headgear | `vlHats` | `vlHat` | `vlHatColor` |
| Socks | `vlSocks` | `vlSock` | `vlSockColor` |

`vlFacegear` / `vlFacegears` - empty in base FS25; socks may route through footwear.

## Diagnostics & API probes

These probe live engine objects / state. The **method** for cracking `.gar`-sealed APIs
with this kind of dump (the `_G[name]` quirk, walking metatables, calling hidden methods)
is in [engine-api.md](engine-api.md) — read that before re-deriving anything. (The one-off
door/light *dump* probes used to find those APIs were stripped after journaling; the two
generic *testers* below remain for future buildings.)

| Command | Usage | What it dumps / does |
|---|---|---|
| `vlPos` | `vlPos` | Player world position (for capturing waypoints / spawn coords). |
| `vlNear` | `vlNear` | Player pos + nearest villager + distance. |
| `vlStyle` | `vlStyle` | Character style configs (item/color counts) — skin/age research. |
| `vlHairColors` | `vlHairColors` | Hair color palette (index → RGB). |
| `vlAnimClips` | `vlAnimClips <npcId>` | All anim clip names 0–120 (walk/idle clip discovery). |
| `vlConvo` | `vlConvo` | Probe the NPC conversation system. |
| `vlDlg` | `vlDlg` | Probe native dialog/choice widgets. |
| `vlGuidedTour` | `vlGuidedTour` | Probe `GuidedTour` class/instance methods (hook discovery). |
| `vlDoorTest` | `vlDoorTest <1\|-1\|0> [which]` | Open/close the nearest placeable's door(s) directly — generic tester. |
| `vlLightTest` | `vlLightTest <1\|0>` | Toggle the nearest placeable's lights directly — generic tester. |

## Notes

- Console tweaks are **live only** - they do not persist. Bake into
  `src/NPCSystem.lua` (`VILLAGERS` table).
- **Galoshes** and some tops need both `item` and `color` in the baked spec
  (e.g. `footwear = { item = 4, color = 1 }`); without color the mesh may not load.
- NPC appearance is **not** saved in `valleyLife.xml` (relationships and events only).
- Dev commands; consider gating before a public release.
