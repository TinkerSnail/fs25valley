# Valley Life - Journals

Reference notes captured during development so we don't have to re-derive game
internals (style configs, palettes, API quirks) every time.

For project overview, install, and controls, see the root [README.md](../README.md).

## Index

- [character-systems.md](character-systems.md) - **START HERE for characters**: the big-picture
  model — every character is the same player rig (player-can ⇒ NPC-can), the two implementation
  paths (Walter/GRANDPA vs fabricated `VLNPCEntity`), a **capability catalog**, and the governing
  principles. Ties the per-topic journals together.
- [outfits-and-schedule.md](outfits-and-schedule.md) - **work/leisure rules**,
  holidays, seasons, birthdays, per-villager assignment matrix, baking checklist.
- [character-appearance.md](character-appearance.md) - character style configs
  (face/hair/beard/clothing), the `vlStyle` dump, palettes, and per-villager
  appearance item indices.
- [console-commands.md](console-commands.md) - all `vl*` dev console commands,
  **outfit testing loop**, and clothing-layer command tables.
- [dialog-boxes.md](dialog-boxes.md) - bottom-screen narration popup and reply
  selector: `drawFilledRectRound`, layout constants, input handling, and what
  *not* to do (PNG 9-slice corners).
- [lifecycle-and-hooks.md](lifecycle-and-hooks.md) - **mission hooks**,
  per-frame update/draw chain, save/load, NPC spawn, idle animation.
- [walter-daily-life.md](walter-daily-life.md) - **Walter's full system + 2026-06-22 session
  log**: daily schedule, disappear/morning-departure, stairs, stop-and-face, map icon, Visit
  teleport, woodshop door+lights, time-of-day greetings, the `getDay` crash fix, and config knobs.
- [walter-guided-tour.md](walter-guided-tour.md) - base-game intro tour: why
  Walter's `.gar` dialog is **un-editable**, his reconstructed closing speech,
  and the `GuidedTour.finish`/`cancel` **injection seam** for a post-tour town beat.
- [npc-movement.md](npc-movement.md) - **work loop system**: waypoints, walk
  animation clips, turn-then-walk behavior, `pauseMinutes` (game time), `pauseRy`,
  and hand props research.
- [engine-api.md](engine-api.md) - **runtime introspection** of sealed (`.gar`) APIs: the
  `_G[name]` metatable quirk, placeable **doors** (`ao:setDirection`), **lights**
  (`spec_lights` groups + `updateLightState`), **map hotspots** (override
  `getWorldPosition`), and **ESC-map Visit teleport** (`Player:teleportToNPC`).
- [game-files-and-xml.md](game-files-and-xml.md) - **how to research base-game
  behavior**: resource directory paths, key XML files (`maps_npcs.xml`,
  `guidedTour_intro.xml`, `pedestrianSystem.xml`), search patterns, and what is
  vs. isn't readable (`.gar` extraction — NPC dialogue text IS readable).
- [animal-husbandry-intro.md](animal-husbandry-intro.md) - **base-game husbandry onboarding, full flow**:
  the two parallel systems (Walter→Katie NPC referral+tutorial, and the static help-line menu), the
  consistent per-species branch shape, the cow branch verbatim, and the mechanics (buying/pens/feeding/
  TMR/manure) the tutorial points at. Reference before extending it.
- [map-riverbend-springs.md](map-riverbend-springs.md) - **the whole-map picture**: Riverbend
  Springs = `mapUS`; the named NPCs own the farmland (GRANDPA owns the starting farm), the
  inherited farm cluster (woodshop + **3 Angus cows** + beehives), the economy (sell points,
  production chains, shops incl. Katie's animal trader), ambient life, collectibles, and what it
  all unlocks for our features.
- [walter-truck-driving.md](walter-truck-driving.md) - **Walter sits in & drives his truck**: the seated
  DRIVER pose (NOT a clip — it's `setVehicleCharacter` + SPINE_ROTATION hips bend + hands-on-wheel IK on the
  vehicle's own HumanModel, dressed in `grandpa.playerStyle`), and ROAD DRIVING via the base-game AI "Go To"
  job (`AIJobGoTo` + nav agent; re-assert Walter after `startJob` because it swaps in a random helper). Code
  recipes + console commands + the decompiled-source map.
- [development-process.md](development-process.md) - **`.claude` failsafes**: auto-repack
  hook, session-context injection, the **R-table gate** (how to operate it, multi-edit
  gotcha), build verifier, and which `log.txt` to read.
- [dumps/](dumps/) - raw captured output from in-game diagnostic commands.

## Where API knowledge lives (the capture pipeline)

API findings flow through three tiers — there is no single monolithic API doc:

1. **Raw dumps** → `dumps/api/` (decompiled GIANTS `.lua` + extracted config XML),
   mapped by [dumps/api/INDEX.md](dumps/api/INDEX.md). **Local-only, gitignored —
   GIANTS-copyrighted, never push.** Re-derivable anytime with the `fs-unpack` /
   `fs-luau-decompile` toolchain in [game-files-and-xml.md](game-files-and-xml.md).
2. **Distilled, committed reference** → [engine-api.md](engine-api.md): the
   "cracking a sealed API" playbook plus the clean results (doors, lights, map
   hotspots, teleport, handtool-holder, IK). This is the closest thing to a central
   API doc — start here.
3. **Applied details** → captured inline in the relevant feature journal as they're
   discovered (e.g. `walter-truck-driving.md` for aiDrivable/AIJobGoTo,
   `dialog-boxes.md` for `drawFilledRectRound`, `npc-movement.md`).

So: **raw dump (indexed, gitignored) → distill into `engine-api.md` (committed) →
apply into per-feature journals.**

## Conventions

- Current mod version: **0.1.0.70** (check `modDesc.xml` / log line
  `Valley Life 0.1.0.XX loaded` — displayed version may be stale/cached, but new
  code IS running if log messages reflect recent changes).
- When a diagnostic command (e.g. `vlStyle`, `vlHairColors`) produces output we
  want to keep, paste the raw log block into `journals/dumps/` with a dated
  filename, and summarize the takeaway in the relevant topic file.
- Record *decisions* (e.g. "Kenji uses face 8") alongside the raw data so the
  reasoning is preserved.
- **Bake outfits** in `src/NPCSystem.lua`; console tweaks are live-only. Repack
  with `./repack.sh` → full FS25 relaunch.
- **After every code edit: repack then relaunch.** Run `./repack.sh` from the
  project root immediately after any `.lua` change — Claude should do this
  automatically after edits without being asked.

## Villagers

| id | name | birthday |
|---|---|---|
| `elara` | Elara | February 10 |
| `kenji` | Kenji | May 8 |
| `marta` | Marta | November 5 |
