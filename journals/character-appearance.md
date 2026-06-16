# Character Appearance

How FS25 builds NPC looks, what's adjustable, and the choices we've made per
villager.

## How it works (summary)

- Every human (player, helpers, story NPCs like Grandpa Walter) is the **same
  shared character rig** driven by a `PlayerStyle`. There is **no unique mesh**
  per named character - they differ only by style preset (face, hair, beard,
  clothing) and colors.
- We build a fresh `PlayerStyle` per villager from the base-game player XML and
  apply a per-villager `appearance` spec. See
  `src/scripts/NPCEntity.lua` (`buildStyle`, `applyAppearance`).
  - Male:   `dataS/character/playerM/playerM.xml`
  - Female: `dataS/character/playerF/playerF.xml`
- `appearance` format: `configName = { item = <index>, color = <index> }`.
- **Animation** - villagers use `HumanGraphicsComponent` for the mesh/outfit;
  idle motion uses **direct anim tracks** on the skeleton (`setupDirectIdleAnimation`
  in `NPCEntity.lua`). Do not rely on setting `isIdling` once at spawn without
  enabling a clip. See [lifecycle-and-hooks.md](lifecycle-and-hooks.md#npc-spawn--animation-vlnpcentity).
- **Work / leisure outfits** - see [outfits-and-schedule.md](outfits-and-schedule.md) for
  the full calendar rules, assignment matrix, birthdays, and testing loop.
  Summary:
  - `appearanceBase` - face, hair, beard (always on).
  - `appearanceWork` / `appearanceLeisure` - year-round defaults.
  - `appearanceSummerWork`, `appearanceFallLeisure`, etc. - per-season overrides.
  - Mode: **work** Mon–Fri 5:30 AM–4:30 PM (excl. holidays); **leisure** otherwise.
  - Console: `vlOutfit <npcId> work|leisure`, `vlSeason`, clothing `vlTop` / `vlBottom` …
- Item indices wrap to the available count; color indexes into the style's
  palette (`hairColors` / `defaultClothingColors`), which we copy from the
  game's cached base style or colors fall back to default.

## Hair + beard color is UNIFIED (can't be set independently)

Confirmed from the FS25 SDK (`PlayerStyle` in `documentation_scripting_fs25`,
class 418): the engine forces **hair, beard, and mustache to share one color**.
It does this by re-applying the hairStyle color through its setter:

```lua
-- Unify the hair colors.
self.configs.hairStyle:setSelectedColorIndex(self.configs.hairStyle:getSelectedColorIndex())
```

This runs in `PlayerStyle.new`, `copyFrom`, `copySelectionFrom`, and
`readStream`. Consequences for us:

- Setting a separate `beard.color` is **pointless** - it gets overridden, and a
  beard left "uncolored" renders as a washed-out, semi-transparent **"ghost
  chin"**. That was the bug behind Kenji's doubled/odd beard color.
- Fix: in `applyAppearance` (`src/scripts/NPCEntity.lua`), after applying all
  configs we call `hairStyle:setSelectedColorIndex(hairStyle:getSelectedColorIndex())`
  so the beard inherits the hair color. The beard always matches the hair.
- So: only set `hairStyle.color`. The beard follows. `vlHairColor` changes both
  because it's really just the one hair color.

Other useful palette facts:
- `style.hairColors` entries are `{ primary = <color>, secondary = <color> }`,
  not flat `{r,g,b}` - see `journals/dumps/2026-06-15-vlHairColors.md`.
- Beard config colors are loaded from the same `hairColors` palette.

## Face-specific beards (white / ghost chin)

Some beard meshes are tied to a specific face (`beard.faceName` must match
`face.name`). Using the wrong beard on a face (e.g. beard item 2 on face item 8 /
`head07`) often renders a **permanent white or semi-transparent layer** on the
jaw. With `vlBeard kenji 0`, if white remains, it's **baked into the head mesh**
(not our beard config).

## Hair on hair (baked scalp + hairStyle wig)

Some **head meshes include baked scalp/hair geometry** that does not take the
hairStyle color. Adding a full `hairStyle` wig on top produces **hair on hair** -
often a white/default under-layer plus the tinted wig on top. When cycling faces
with `vlFace`, logs show only `mHeadXX.i3d` reloading, not a separate
`hairStyles/*.i3d`, which suggests the under-layer stays while the wig may not
rebind cleanly.

Mitigation: use **minimal hairStyle meshes** (receding, buzz cut, bald top) on
faces with baked hair, or pick a face without prominent baked hair. Console:
`vlHairs kenji` lists indices/names; try items whose names contain Receding,
Buzz, Bald, Unkempt.

At spawn we now log the resolved hairStyle **name** alongside indices (see
`Kenji style: face=head07 ... hair 'hairStyleXXX' ...` in log.txt).

## Male faces: 6 customizable + 4 special (items 7–10)

Confirmed in-game (character creation UI + `vlStyle` dump):

| Source | Male faces | Female faces |
|---|---|---|
| Character creation UI | **6** (fully customizable hair/beard) | **6** |
| `playerM.xml` / `vlStyle` config | **10** items total | **6** items |

So male items **7–10** exist in the style config but are **not** the normal wardrobe
faces - they behave like **preset / story-style heads** with baked hair and/or
facial hair (limited or no modular `hairStyle` / `beard` support). Female has no
extra faces; all 6 are customizable.

**Index → mesh (from `vlFace` + logs):**

| Face item | Mesh | In creation UI? | Modular hair/beard? |
|---:|---|---|---|
| 1 | `mHead01` | Yes | Yes (`facialHair/mHead01/`) |
| 2 | `mHead02` | Yes | Yes |
| 3 | `mHead03` | Yes | Yes |
| 4 | `mHead04` | Yes | Yes |
| 5 | `mHead05` | Yes | Yes |
| 6 | `mHead06` | Yes | Yes (partial) |
| 7 | `mHead??` | No | Baked / limited |
| 8 | `mHead07` / `head07` | No | **Kenji's pick - white jaw, hair-on-hair issues** |
| 9–10 | (not fully logged) | No | Baked / limited |

**Story NPC heads** (`npcQG01`, `npcFisherman`, Walter's `grandpa.xml`) are a
**fourth** category - not in the creation picker at all.

**For authored villagers:** use face items **1–6** only, then layer
`hairStyle` + compatible `beard` + color like character creation does. Avoid
items 7–10 unless we want a fixed baked look and accept no modular hair/beard.

The only config that affects the face/skin is **`face`**, which swaps between
**distinct face presets** (different individuals, not a young→old morph). Age is
conveyed by choosing an older-looking face + grey hair/beard + clothing. Faces
have **no color/tone swatches**.

## Style config dump (`vlStyle`, 2026-06-15)

Columns: `items` = selectable presets, `colors` = swatches (−1 means the
per-config color getter isn't exposed; colors come from the shared palette),
`selected` = default index.

### MALE - `dataS/character/playerM/playerM.xml`

| config    | items | colors | default |
|-----------|------:|-------:|--------:|
| beard     | 91    | −1     | 0       |
| bottom    | 30    | −1     | 0       |
| face      | 10    | −1     | 1       |
| facegear  | 0     | −1     | 0       |
| footwear  | 30    | −1     | 0       |
| glasses   | 7     | −1     | 0       |
| gloves    | 13    | −1     | 0       |
| hairStyle | 17    | −1     | 2       |
| headgear  | 38    | −1     | 0       |
| onepiece  | 20    | −1     | 0       |
| top       | 62    | −1     | 0       |

### FEMALE - `dataS/character/playerF/playerF.xml`

| config    | items | colors | default |
|-----------|------:|-------:|--------:|
| beard     | 0     | −1     | 0       |
| bottom    | 30    | −1     | 0       |
| face      | 6     | −1     | 1       |
| facegear  | 0     | −1     | 0       |
| footwear  | 30    | −1     | 0       |
| glasses   | 7     | −1     | 0       |
| gloves    | 13    | −1     | 0       |
| hairStyle | 17    | −1     | 2       |
| headgear  | 38    | −1     | 0       |
| onepiece  | 19    | −1     | 0       |
| top       | 62    | −1     | 0       |

> Faces: males have **1–10**, females have **1–6**. Beard only exists for males.

## Per-villager decisions

Defined in `src/NPCSystem.lua` (`VILLAGERS`).

### Elara (female, late 20s - younger)

**Summer work look** (Jun–Aug):
- `top = { item = 3 }` (topTankTop)
- `bottom = { item = 9 }` (botCargoShorts)
- `footwear = { item = 13, color = 1 }` (sandalF04)
- `glasses = { item = 7 }` (vintage)

**Fall work look** (Sep–Nov):
- `top = { item = 5, color = 9 }` (topLightSweater)
- `bottom = { item = 11, color = 9 }` (botModernSkirt01)
- `footwear = { item = 6, color = 3 }`
- `glasses = { item = 7 }` (vintage)

**Spring work look** (Mar–May):
- `top = { item = 23 }` (tweedSportsJacket)
- `bottom = { item = 4, color = 2 }` (botEquestrian)
- `footwear = { item = 8 }` (leatherChelsea01)
- `glasses = { item = 7 }` (vintage)

**Winter work look** (Dec–Feb):
- `top = { item = 21, color = 1 }` (topPuffyJacket)
- `bottom = { item = 3, color = 7 }` (botCargo)
- `footwear = { item = 17 }`
- `gloves = { item = 4, color = 9 }` (leather)
- `glasses = { item = 7 }` (vintage)

**Leisure look** (default - seasons without seasonal leisure):
- `top = { item = 5, color = 9 }` (topLightSweater)
- `bottom = { item = 11, color = 9 }` (botModernSkirt01)
- `footwear = { item = 13, color = 1 }` (sandalF04)
- `glasses = { item = 0 }` (none)

**Fall leisure look** (Sep–Nov off-hours):
- `top = { item = 20, color = 6 }` (topWoolCoat)
- `bottom = { item = 4, color = 4 }` (botEquestrian)
- `footwear = { item = 6, color = 3 }` (riding)
- `glasses = { item = 7 }` (vintage)

**Winter leisure look** (Dec–Feb off-hours):
- Same as winter work (puffy jacket, cargo, footwear 17, leather gloves, vintage glasses)

### Kenji (male, ~58 - older)

**Base:** `face = { item = 8 }`, `hairStyle = { item = 9, color = 22 }`, `beard = { item = 0 }`

**Summer work look** (baked - active Jun–Aug):
- `top = { item = 1 }` (topTShirt01)
- `bottom = { item = 9, color = 2 }` (botCargoShorts)
- `footwear = { item = 11, color = 0 }` (sandalM02)
- `gloves = { item = 0 }` (none)
- `glasses = { item = 3 }` (glassesReading)

**Fall work look** (active Sep–Nov):
- `onepiece = { item = 6, color = 3 }` (onePieceMechanic)
- `footwear = { item = 4, color = 1 }` (galoshes)
- `gloves = { item = 5 }` (glovesMechanic)

**Spring work look** (Mar–May - same as fall):
- `onepiece = { item = 6, color = 3 }` (onePieceMechanic)
- `footwear = { item = 4, color = 1 }` (galoshes)
- `gloves = { item = 5 }` (glovesMechanic)

**Winter work look** (active Dec–Feb):
- `top = { item = 12 }` (topVestM)
- `bottom = { item = 2, color = 5 }` (botChinos)
- `footwear = { item = 8 }` (leatherChelsea01)
- `gloves = { item = 0 }` (none)
- `glasses = { item = 3 }` (glassesReading)

**Default leisure look** (seasons without a seasonal leisure outfit):
- `onepiece = { item = 3, color = 1 }` (onePieceSynthetic)
- `footwear = { item = 1 }` (default / bare)
- `gloves = { item = 0 }` (none)

**Fall leisure look** (Sep–Nov):
- `top = { item = 11 }` (topVest)
- `bottom = { item = 2, color = 2 }` (botChinos)
- `footwear = { item = 8 }` (leatherChelsea01)
- `gloves = { item = 0 }` (none)
- `glasses = { item = 3 }` (glassesReading)

**Summer leisure look** (Jun–Aug):
- `top = { item = 25 }` (straussTShirtMerino)
- `bottom = { item = 2, color = 2 }` (botChinos)
- `footwear = { item = 8 }` (leatherChelsea01)
- `gloves = { item = 0 }` (none)
- `glasses = { item = 3 }` (glassesReading)

**Winter leisure look** (Dec–Feb):
- `top = { item = 20 }` (topSlimCoat)
- `bottom = { item = 2, color = 5 }` (botChinos)
- `footwear = { item = 8 }` (leatherChelsea01)
- `gloves = { item = 0 }` (none)
- `glasses = { item = 3 }` (glassesReading)

**Spring leisure look** (Mar–May):
- `top = { item = 5, color = 1 }` (topLightSweater)
- `bottom = { item = 2, color = 1 }` (botChinos)
- `footwear = { item = 7, color = 1 }` (laceUpSneaker)
- `gloves = { item = 0 }` (none)
- `glasses = { item = 3 }` (glassesReading)

Note: face item 8 is outside the 6 character-creation heads; baked stubble on the mesh
can cause white jaw / hair-on-hair with some hair styles. Revisit if it becomes visible.

### Marta (female, ~55 - older)

**Base:** `face = { item = 5 }`, `hairStyle = { item = 16, color = 23 }`

**Summer work look** (Jun–Aug):
- `top = { item = 7 }` (topBlouse)
- `bottom = { item = 8 }` (botJeansCapris)
- `footwear = { item = 10 }` (sandalF01)
- `glasses = { item = 1 }` (aviator)

**Fall work look** (Sep–Nov):
- `top = { item = 18 }` (topWinterVest)
- `bottom = { item = 10 }` (botYogaPants)
- `footwear = { item = 15 }` (sneaker01)
- `glasses = { item = 1 }` (aviator)

**Winter work look** (Dec–Feb):
- `top = { item = 13 }` (topFarmJacketF)
- `bottom = { item = 5 }`
- `footwear = { item = 4, color = 1 }` (galoshes)
- `gloves = { item = 3 }` (glovesKevlar)
- `glasses = { item = 0 }` (none)

**Work look** (fallback - seasons without seasonal work):
- Same as summer work

**Summer leisure look** (Jun–Aug off-hours):
- `top = { item = 4 }` (topCollaredShirt01)
- `bottom = { item = 11 }` (botModernSkirt01)
- `footwear = { item = 12 }` (sandalF03)
- `glasses = { item = 1 }` (aviator)

**Leisure look** (default - seasons without seasonal leisure):
- Same as work except `glasses = { item = 0 }`

**Spring leisure look** (Mar–May off-hours):
- `top = { item = 5 }` (topLightSweater)
- `bottom = { item = 11 }` (botModernSkirt01)
- `footwear = { item = 10 }` (sandalF01)
- `glasses = { item = 1 }` (aviator)

**Fall leisure look** (Sep–Nov off-hours):
- `top = { item = 15 }` (zipNeckPullover)
- `bottom = { item = 14 }` (botWrapSkirt)
- `footwear = { item = 15 }` (sneaker01)
- `glasses = { item = 1 }` (aviator)

**Winter leisure look** (Dec–Feb off-hours):
- `top = { item = 10 }` (topLeatherJacket - may need `color` if jacket invisible)
- `bottom = { item = 5 }` (mesh not confirmed in logs)
- `footwear = { item = 9 }` (leatherChelsea02)
- `gloves = { item = 3 }` (glovesKevlar)
- `glasses = { item = 0 }` (none)

## Open TODOs

- [ ] Confirm Kenji's beard renders correctly with face 8.
- [x] Pick Marta's face and hair (face 5 / fHead05, hair16 color 23).
- [x] Capture the `vlHairColors` palette dump into `journals/dumps/`.
- [ ] Elara: spring/summer **seasonal leisure** (fall + winter leisure baked).
- [x] Kenji: all seasonal work and leisure slots baked.
- [x] Marta: all seasonal work and leisure slots baked.
- [ ] Marta winter leisure: verify top 10 / bottom 5 render in-game.
- [ ] Birthday hooks (leisure all day or events).
