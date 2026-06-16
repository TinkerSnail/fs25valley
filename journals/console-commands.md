# Developer Console Commands

The mod registers these `vl*` commands (see `main.lua`, `VLConsole`). Open the
console with **`~`** and type a command. Most print to the console **and**
`~/Library/Application Support/FarmingSimulator2025/log.txt`.

After code changes, run `./repack.sh` from the project root, then **fully quit
and relaunch** FS25. Confirm the log shows the expected mod version (e.g.
`Valley Life 0.1.0.42 loaded`).

`npcId` is one of: **`elara`**, **`kenji`**, **`marta`**.

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

## World & spawn

| Command | Usage | What it does |
|---|---|---|
| `vlPos` | `vlPos` | Player world position formatted for `VLConfig.VILLAGER_SPAWNS`. |

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

## Notes

- Console tweaks are **live only** - they do not persist. Bake into
  `src/NPCSystem.lua` (`VILLAGERS` table).
- **Galoshes** and some tops need both `item` and `color` in the baked spec
  (e.g. `footwear = { item = 4, color = 1 }`); without color the mesh may not load.
- NPC appearance is **not** saved in `valleyLife.xml` (relationships and events only).
- Dev commands; consider gating before a public release.
