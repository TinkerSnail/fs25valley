---
name: project-overview
description: "FS25 Stardew-like mod — goals, scope, tech stack, reference implementation"
metadata: 
  node_type: memory
  type: project
  originSessionId: 29d7c3ec-c15b-4feb-93a7-6a2409cd72ae
---

Building the social/narrative half of Stardew Valley as a FS25 mod. FS25 handles farming natively; this mod adds authored characters, relationships, and scripted heart events.

**CORE MOTIVATION (the user's stated "why", 2026-06-29):** there is a TON of untapped potential in the base
game — the parts are "right there for the taking." GIANTS built capable raw material (voiced NPCs with full
backstories, a rig that does everything the player can, schedules, road-navmesh pathfinding, conversation
trees, door/light placeables, the AI driver job, handtool-holder system) and then barely wired it together —
the raw material is more capable than the assembled product. This mod COMPLETES something half-built rather
than fabricating from scratch or fighting the engine. This thesis IS the working method everywhere: Walter is
the REAL GRANDPA (not a double), he drives via the base AI job + `setVehicleCharacter` IK, holds tools via the
real holder system, and the base NPCs' sealed dialogue is extracted and extended — "use what's there" beats
hand-rolling every time. The town-life corollary: GIANTS' NPC attempt landed poorly (players HIDE them) only
because a player's lever is on/off — the schedule/dialogue/route layer we operate on is exactly what's missing.
See [[project-townlife-opportunity]], [[feedback-npc-can-do-what-player-can]], [[project-walter-constraint]].

**Target scope:** Vertical slice — 3–4 deeply authored villagers, one living town corner, working heart-event/cutscene framework with real scripted moments.

**Tech stack:** Lua + XML, GIANTS Editor/Studio, .dds textures, .i3d models. No compile step. Mods drop into `~/Library/Application Support/FarmingSimulator2025/mods/` on macOS.

**Key engine primitives:** `HumanGraphicsComponent`, road spline pathfinding, `g_gui`, save/load hooks.

**Reference pattern library:** FS25_NPCFavor (github.com/TheCodingDad-TisonK/FS25_NPCFavor) — all-rights-reserved license, so reimplement patterns, do not copy. Has NPC spawning, needs-based AI, relationship tiers, gift dialog, save/load persistence. Missing: authored narrative, cutscenes, hand-written character dialog.

**Keystone system:** Heart-event framework (cutscene sequencer) — camera takeover, NPC marks, branching dialog gated on relationship + calendar. Nothing like this exists natively in FS25. This is the single hardest and most important piece.

**Build order:**
1. Spawn one NPC at fixed placeable (walk/idle animation)
2. Schedule + pathfinding along spline route
3. Press-E dialog via g_gui (name + static line)
4. Relationship state 0–100, persisted to savegame
5. Heart-event framework — ship ONE event end-to-end (keystone proof)
6. Authored content pass — 3–4 deep characters with ≥1 heart event each
7. Later: festivals, marriage, expanded cast

**Character priority (2026-06-22):** **Walter is the most important character** to the player/main
character, so he gets the **most elaborate, built-out schedule and dialog** of anyone — deepest
investment by design. Other villagers are lighter by comparison. When allocating effort or deciding
how much depth a feature warrants, Walter is the one that justifies going deep. (He's also the real
base-game GRANDPA — see [[project-walter-constraint]] — and now has a full day: morningDeparture →
checkingPumps → mailbox → produceStand → woodshopVisit → home → eveningReturn.)

**True cost:** Content authoring (writing + 3D character work), not code.

**Why:** Singleplayer-only first (strongly recommended). Multiplayer deferred.
