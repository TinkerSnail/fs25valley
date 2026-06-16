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

- Jan 1 — New Year's Day
- Jul 4 — Independence Day
- Dec 25 — Christmas
- Dec 26 — Day after Christmas

**Auto-detected** (`TimeHelper.isHoliday`):

- Memorial Day (last Monday in May)
- Labor Day (first Monday in September)
- Thanksgiving (fourth Thursday in November)

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

**Mod version:** 0.1.0.37

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

Legend: ✓ baked · — missing (uses fallback) · (all) = same outfit every season

### Elara

| Slot | Spring | Summer | Fall | Winter |
|---|---|---|---|---|
| **Work** | ✓ tweed/equestrian | ✓ tank/shorts | ✓ sweater/skirt | ✓ puffy/cargo |
| **Leisure** | (default) sweater/skirt | | ✓ wool coat/equestrian | (default) sweater/skirt |

**Base:** face 4, hair 8 c3

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

- Elara: spring/summer/winter **seasonal leisure**
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
