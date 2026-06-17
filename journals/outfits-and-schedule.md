# Outfits & Schedule

Quick reference for work/leisure outfits, calendar rules, birthdays, and what's
baked per villager. Source of truth for indices: `src/NPCSystem.lua`. Deeper
appearance notes: [character-appearance.md](character-appearance.md). Console
workflow: [console-commands.md](console-commands.md).

## How outfit mode is chosen

NPCs wear **work** or **leisure** clothing based on calendar + clock
(`TimeHelper.getOutfitMode`):

| Condition | Outfit mode |
|---|---|
| Mon–Fri, 5:30 AM – 4:30 PM, not a holiday | **Work** |
| Before 5:30 AM or from 4:30 PM | **Leisure** |
| Saturday or Sunday | **Leisure** (all day) |
| Holiday | **Leisure** (all day) |

Configured in `src/NPCConfig.lua`:

- `OUTFIT_WORK_START_HOUR = 5.5` (5:30 AM)
- `OUTFIT_WORK_END_HOUR = 16.5` (4:30 PM)

### Holidays

**Fixed** (`VLConfig.OUTFIT_HOLIDAYS`):

- Jan 1 - New Year's Day
- Jul 4 - Independence Day
- Dec 25 - Christmas
- Dec 26 - Day after Christmas

**Auto-detected** (`TimeHelper.isHoliday`):

- Memorial Day (last Monday in May)
- Labor Day (first Monday in September)
- Thanksgiving (fourth Thursday in November)

### Engine calendar: periods, not months (gotcha)

FS25's `g_currentMission.environment` counts in **periods**, not calendar months:

| Field | Meaning |
|---|---|
| `env.currentPeriod` | 1-12, where **period 1 = March**, period 12 = February |
| `env.currentSeason` | 0=spring, 1=summer, 2=autumn, 3=winter (0-indexed) |
| `env.currentDayInPeriod` | day within the current period (1 … `daysPerPeriod`) |
| `env.daysPerPeriod` | season length in days (configurable) |

**There is no `env.currentMonth`.** Reading it returns `nil`. Until 0.1.0.44,
`TimeHelper` read `currentMonth`, defaulted the month to `1`, and pinned every
save to **winter** - so the season never changed and outfits never swapped. Fixed
in `TimeHelper.getCalendarMonth` by converting period → real month
(`((period + 1) % 12) + 1`: period 1 → 3/March, 11 → 1/Jan, 12 → 2/Feb), the same
offset every other seasonal mod (e.g. Critters' `correctMonth`) uses. `vlSeason`
prints the raw `period=`/`engineSeason=` for verification.

### Seasons (which baked slot is active)

Calendar month → season (`TimeHelper.getSeason`):

| Months | Season | Work key suffix | Leisure key suffix |
|---|---|---|---|
| Mar–May | spring | `appearanceSpringWork` | `appearanceSpringLeisure` |
| Jun–Aug | summer | `appearanceSummerWork` | `appearanceSummerLeisure` |
| Sep–Nov | autumn / fall | `appearanceFallWork` | `appearanceFallLeisure` |
| Dec–Feb | winter | `appearanceWinterWork` | `appearanceWinterLeisure` |

Generic fallbacks: `appearanceWork`, `appearanceLeisure` (year-round if no
seasonal slots). If a season slot is missing, `NPCEntity` falls back to other
seasons (see `SEASON_WORK_FALLBACK` / `SEASON_LEISURE_FALLBACK` in
`src/scripts/NPCEntity.lua`).

**Face, hair, beard** always come from `appearanceBase` regardless of mode.

**Mod version:** 0.1.0.47

## Automatic outfit triggers (runtime)

Outfits refresh automatically each frame via `OutfitCalendar` (`src/utils/OutfitCalendar.lua`)
polled from `VLNPCSystem:update` (hooked on `FSBaseMission.update`).

| Trigger | Detection | NPC action |
|---|---|---|
| **Work ↔ leisure** | `TimeHelper.getOutfitMode()` changes (work hours, weekend, holiday) | Swap `appearance*Work` vs `appearance*Leisure` for current season; `reapplyAppearance()` |
| **Season change** | Calendar month changes → `TimeHelper.getSeason()` updates | Re-resolve seasonal slot (`appearanceSummerWork`, etc.); `reapplyAppearance()` |

Log lines when triggers fire:

- `Outfit mode -> leisure (after work hours).`
- `Season -> winter (month 12); refreshing villager outfits.`

**Work hours** (`VLConfig.OUTFIT_WORK_START_HOUR` / `OUTFIT_WORK_END_HOUR`): Mon–Fri
5:30 AM–4:30 PM, excluding holidays. Weekends and holidays are leisure all day.

**Console preview** (`vlOutfit <npc> work|leisure`) pauses calendar auto-switch for that
NPC until `vlOutfit <npc> auto` resumes calendar-driven mode + seasonal layers.

## Birthdays

Deterministic per `npcId` (`BirthdayHelper.fromNpcId`) unless overridden in
`NPCSystem.lua` as `birthday = { month, day }`. `vlBirthdays` lists them.

| Villager | Birthday |
|---|---|
| Elara | February 10 |
| Kenji | May 8 |
| Marta | November 5 |

Birthdays do not yet trigger leisure all day or special events.

## Assignment matrix (what's baked)

Legend: ✓ baked · - missing (uses fallback) · (all) = same outfit every season

### Elara

| Slot | Spring | Summer | Fall | Winter |
|---|---|---|---|---|
| **Work** | ✓ tweed/equestrian | ✓ tank/shorts | ✓ sweater/skirt | ✓ puffy/cargo |
| **Leisure** | (fallback → summer) | ✓ top3/bottom10 | ✓ wool coat/equestrian | ✓ puffy/cargo |

**Base:** face 4, hair 8 c3

Note: spring leisure has no dedicated slot, so it now falls back to **summer
leisure** (chain `{summer, autumn, winter}` hits summer first). The generic
`appearanceLeisure` (sweater/skirt) is dead code while any seasonal leisure slot
exists - it's only reached if every seasonal slot is empty.

### Kenji

| Slot | Spring | Summer | Fall | Winter |
|---|---|---|---|---|
| **Work** | ✓ coveralls | ✓ t-shirt/shorts | ✓ coveralls | ✓ vest/chinos |
| **Leisure** | ✓ sweater/chinos | ✓ merino tee | ✓ vest/chinos | ✓ slim coat |

Plus **default leisure** (synthetic onepiece) if no seasonal leisure matches.

**Base:** face 8, hair 9 c22, beard 0

### Marta

| Slot | Spring | Summer | Fall | Winter |
|---|---|---|---|---|
| **Work** | (fallback) blouse/capris | ✓ blouse/capris | ✓ vest/yoga | ✓ farm jacket |
| **Leisure** | ✓ sweater/skirt | ✓ collared/skirt | ✓ pullover/wrap skirt | ✓ leather/chelsea |

**Base:** face 5, hair 16 c23

## Gaps (TODO)

- Elara: spring **seasonal leisure** (currently falls back to summer; summer baked 0.1.0.45)
- Birthday → leisure or event hooks

## Baking checklist

1. `vlSeason` + `vlOutfit <npc> work|leisure`
2. Tune with `vlTop`, `vlBottom`, `vlShoe`, etc.
3. Add to `NPCSystem.lua` under the correct key, e.g.:

```lua
appearanceSummerWork = {
  top = { item = 3 },
  bottom = { item = 9 },
  footwear = { item = 13, color = 1 },
  glasses = { item = 7 },
},
```

4. `./repack.sh` → full relaunch → verify in log.
