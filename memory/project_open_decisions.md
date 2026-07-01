---
name: project-open-decisions
description: Design decisions — settled and pending
metadata: 
  node_type: memory
  type: project
  originSessionId: 29d7c3ec-c15b-4feb-93a7-6a2409cd72ae
---

## Settled

- **Target map**: **Riverbend Springs** = the FS25 US base map, which is **`mapUS`** in the game files
  (`data/maps/mapUS/`). CORRECTED 2026-06-25 (was wrongly recorded as "Elmcreek", an FS22 carryover —
  base FS25 ships mapUS/mapEU/mapAS, no Elmcreek). All Walter work already lives on it: the guided-tour
  hooks, GRANDPA's coords, `tinyShed01` woodshop, NPCConfig waypoints. `Walter.lua` header says
  "Riverbend Springs". Base-game NPCs (GRANDPA, ANIMAL_DEALER/Katie, etc.) are placed in `mapUS.i3d`.
- **Singleplayer only**: Yes — no multiplayer infrastructure. NPCFavor's MP took significant effort and is still untested; skip it entirely.
- **Art budget**: Reuse FS25 existing human assets via `HumanGraphicsComponent` + `PlayerStyle.defaultStyle` + `appearanceSeed` for deterministic per-character variation. No custom Blender characters for the vertical slice.
- **ASSET CONSTRAINT — base game + DLC models ONLY (user goal, 2026-06-29)**: use NO models that aren't part of the FS25 base game or official DLC. No custom-modeled assets, NO third-party / community / prop-pack mods. The project is meant to be an EXAMPLE of leveraging in-game assets as much as possible — a sharper, generalized form of the art-budget rule and the [[project-overview]] "complete the half-built" thesis. Implications: interiors must be kit-bashed from base+DLC decoration assets + the base buildings' own interior meshes (accept sparse/rustic; community furniture packs are RULED OUT). No child NPCs (no base model — see [[reference-no-child-models]]). DLC IS allowed (note: DLC assets the player doesn't own won't load — gate on availability).
- **GIANTS Editor is WINDOWS-ONLY (confirmed 2026-06-29 via GDN downloads)**: every Editor build (v10 FS25, v9 FS22, v8 FS19) is Windows; no macOS/Linux version exists. The user is on an **Apple M1 Pro MacBook Pro (arm64)** → editor-dependent work (building INTERIORS, map editing, placing NPC spawn nodes in `mapUS.i3d`, spline authoring) is BLOCKED on this machine. **Parallels/VM is NOT a workaround on Apple Silicon (confirmed via community reports 2026-06-29): GE runs through x86→ARM emulation + a virtualized GPU, and the 3D VIEWPORT fails — modders report no success in Parallels/VMware/VirtualBox. Boot Camp is gone on Apple Silicon.** ⇒ editor work needs a NATIVE Windows PC. **The user HAS a Windows PC and will switch to it for editor work (2026-06-29)** — so the map/world-authoring TODO items (interiors, world set-pieces, spawn nodes, spline authoring) are NOT blocked, they just move to the Windows machine when that phase comes. Workflow split: hook-based work (Walter, routes, dialogue, truck, save logic — most of the project) on the Mac; GIANTS Editor work on Windows.
- **NPC vehicles**: Not possible — hard engine limitation (i3d models cannot be loaded from game pak archives at runtime). Confirmed by NPCFavor ROADMAP. All heart events must be on-foot.
- **Bone animation**: NPCFavor doesn't drive bone animations yet either. Cutscene sequencer will control NPC position/rotation (walk to mark, face camera) using idle animation only. Custom animation is a phase-2 problem.

## Pending

- **Who are the 3–4 villagers?** Names, occupations, personality type (hardworking/lazy/social/grumpy/generous), narrative hook, first scripted heart event. This drives all authored content. Not settled yet.
