---
name: reference-no-child-models
description: FS25 base game has NO child/kid character models — the town is adults-only (playgrounds are decor)
metadata: 
  node_type: memory
  type: reference
  originSessionId: c4423422-502a-41db-b890-152a3374e0be
---

**FS25 base game ships NO child/children/kid character models.** Researched 2026-06-29 (TODO: "town has
playgrounds but no kids"). The town can't be populated with kids from base assets.

**File evidence (readable, definitive on the readable side):**
- `$DATA/maps/mapUS/config/pedestrianSystem.xml` — the ambient town walkers — defines ~17 pedestrians, EVERY
  one using the ADULT player rig (`dataS/character/playerM/playerM.xml` or `playerF/playerF.xml`) with adult
  clothing styles and the adult walk clips (`NPCWalkMale01Source` / `NPCWalkFemale01Source`). NO child
  variation, NO child style file, NO child walk animation.
- `~/fs25_l10n/l10n_en.xml` (all player-facing labels) — ZERO child/kid/teen/youth character or clothing
  entries. Only "Playground"/"Playground Maker Hall" entries, and a dog "good boy" line. NOTE (corrected
  2026-06-29): the Riverbend Springs **playground is a FUNCTIONAL sell/delivery point** (deliver planks +
  boards → build wooden toy tractors; a Steam thread reports it "not paying"), NOT pure decor — but it is
  unpopulated (no children present).
- Loose `$DATA/character/` is empty (models sealed in `dataS.gar`); the only character model dirs referenced
  anywhere are `playerM`, `playerF`, `npc/npcBase` — all adult. Nothing references a child model.

**Community/official corroboration:** FS25's named NPCs are adults; children exist ONLY in the SEPARATE
product **"Farming Simulator Kids"** (a different game), never in the FS25 base game. (GIANTS has long kept
children out of the mainline sims.) The Steam "Very 'childish' looking" thread is about the adult NPCs looking
cartoonish, not actual children.

**Caveat / only way to be 100% exhaustive:** an unused/hidden child `.i3d` buried in `dataS.gar` (3.2 G,
sealed) can't be ruled out without a full ~5 G extraction (`fs-unpack` has no list mode — extract-only). But
there's no rig, no animation, no style, and no reference to drive one, so practically there is nothing usable.
⇒ A custom child model (Blender) would be the only path, which conflicts with the "reuse FS25 human assets,
no custom Blender characters for the vertical slice" art-budget decision ([[project-open-decisions]]).
Toolchain to extract if ever revisited: [[project-bonnie-dog]] / journals/game-files-and-xml.md.
