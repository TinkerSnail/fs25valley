# FS25 game files & XML research

Where to look when you need to understand base-game behavior — NPC placement,
schedules, tour steps, map config — without running the game.

---

## Root paths

```
# Game resources (readable)
~/Library/Application Support/Steam/steamapps/common/Farming Simulator 25/
  Farming Simulator 2025.app/Contents/Resources/

# Shorthand used below:
$RESOURCES = .../Contents/Resources/
$DATA      = $RESOURCES/data/
```

The packed binary archives `dataS.gar` (3.2 G — **models, the player rig + animations**, clothing) and
`dataS2.gar` (373 M — **NPC XML, dialogue, voice/conversation files**) sit next to the app binary. They
can't be read as files directly and mods can't load from them — BUT they **can be extracted locally** for
study (see below). Everything in `$DATA/` is loose and readable.

## Extracting the `.gar` archives (2026-06-23)

Sealed at runtime, but unpackable on disk with the community Rust tool **[`scfmod/fs-utils`](https://github.com/scfmod/fs-utils)**
(cross-platform; the one Windows-only crate is `fs-patch-process`, which we don't build). Extracting your
OWN installed `.gar` for personal study is standard modder practice — the EULA line is *redistribution*,
not local inspection. One-time setup + use:

```bash
brew install rust                                   # cargo/rustc (rustup curl|sh got mangled here)
git clone --depth 1 https://github.com/scfmod/fs-utils.git ~/fs25_tools
cd ~/fs25_tools && cargo build --release -p fs-unpack   # ~11s
# whole-archive only (no subpath); ~5G uncompressed for dataS.gar — extract then prune
~/fs25_tools/target/release/fs-unpack ".../Resources/dataS.gar" ~/scratch -s
```

`.i3d.shapes` (mesh data) stays locked → needs `fs-shapes-unlock`; but `.i3d` (scene/skeleton, XML) and
**`.i3d.anim` (animation keyframes)** come out directly — no unlock needed for animations.

**Where the player animations live (extracted from `dataS.gar`):** `character/playerAnimations/`
- `animations.i3d.anim` (14.7 M) — **binary keyframes for ALL the player clips** (`chainsaw_walkSource`,
  the walks, idles, etc. — the same 87-clip set GRANDPA loads into its `animCharSet`).
- `animationsM.xml` / `animationsF.xml` — the male/female **clip MAP**: `<clip clipName="chainsaw_walkSource"/>`
  etc., with blend/speedScale params. The human-readable index into the binary.
- `animations.i3d` (9.9 K) — the scene/skeleton the clips drive.
- `animationsPedestrians.*` (ambient walkers), `animationsVehicleCharacter.*` (driver IK poses).
- `npcBase.i3d` = `$dataS/character/npc/npcBase.i3d`; `playerM.xml` = `dataS/character/playerM/playerM.xml`
  (from `grandpa.xml` in dataS2). A kept copy of just `playerAnimations/` (23 M) is at `~/fs25_player_anims`.

---

## Key files for NPC research

| File | What it tells you |
|------|-------------------|
| `$DATA/maps/maps_npcs.xml` | Names all base-game NPC types and their `.gar` paths (`GRANDPA`, `FARMER`, `FORESTER`, `HELPER`, `ANIMAL_DEALER`, `FISHERMAN`) |
| `$DATA/maps/mapUS/config/pedestrianSystem.xml` | Ambient walkers — style, walk/idle animations, group schedules. These are *not* named NPCs like GRANDPA |
| `$DATA/maps/mapUS/guidedTour/guidedTour_intro.xml` | Every step of the intro tour: `npcMove`, `npcStartConversation`, `npcConversationFinished` for GRANDPA. His positions and behavior during the tour are all here |
| `$DATA/maps/mapUS/mapUS.xml` | Map config: which NPC list file, fish spots, etc. |
| `$DATA/maps/mapUS/config/*.xml` | Fields, placeables, vehicles, farmlands, traffic, AI system |

---

## How to research a base-game NPC

**Example: figuring out what GRANDPA does after the tour.**

1. Check `maps_npcs.xml` — confirms the NPC exists and its `.gar` path.
2. Search `guidedTour_intro.xml` for `npcMove` and `npcConversation` to map out
   his positions and behavior *during* the tour.
3. Look at the `<finish>` block at the end of the tour XML — this fires when
   `GuidedTour.finish` is called. For GRANDPA: `<npcMove npc="GRANDPA" reset="true" />`
   snaps him to his default spawn (defined in the `.gar`).
4. Check `pedestrianSystem.xml` to confirm whether a named NPC shares the
   ambient pedestrian system — GRANDPA does not, he's entirely tour/`.gar`-driven.
5. If the answer is in `dataS2.gar`, you can't read it directly. Observe in-game
   or infer from the absence of any schedule in the accessible XML.

**GRANDPA conclusion (confirmed 2026-06-19):** He teleports (never walks) between
positions during the tour via `npcMove`. After the tour, `reset="true"` returns him
to his `.gar` home position and nothing in any accessible XML moves him again. He
stands in one fixed spot on the player's farm for the rest of the save.

---

## Searching the resources directory

```bash
# Find all XML files mentioning a term
grep -r "GRANDPA" "$DATA/maps/mapUS/" --include="*.xml" -l

# Dump all npcMove lines from the tour
grep -n "npcMove\|npcConversation" "$DATA/maps/mapUS/guidedTour/guidedTour_intro.xml"

# List all loose lua files (very few — almost everything is in .gar)
find "$DATA" -name "*.lua"
```

Most game logic (NPC classes, GuidedTour, etc.) is compiled into the binary or
packed in `.gar`. The accessible Lua files in `$DATA` are only map-generation
scripts (procedural placement). **Mod-hookable Lua classes like `GuidedTour` run
in the interpreter but their source isn't readable as files.**

---

## What you can and cannot get from files alone

| Question | Accessible? | Where |
|----------|-------------|-------|
| NPC type names | Yes | `maps_npcs.xml` |
| Tour step positions and actions | Yes | `guidedTour_intro.xml` |
| Ambient pedestrian styles/schedules | Yes | `pedestrianSystem.xml` |
| GRANDPA's home/reset position | **No** — in `.gar` | Observe in-game |
| GRANDPA's post-tour schedule | **No** — in `.gar` | Infer from XML absence |
| NPC conversation text | **No** — `.bin` voice files in `.gar` | Log filenames give hints |
| GuidedTour Lua class surface | Partial — use `vlGuidedTour` console command | See [walter-guided-tour.md](walter-guided-tour.md) |
