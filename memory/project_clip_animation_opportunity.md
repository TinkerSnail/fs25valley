---
name: project-clip-animation-opportunity
description: Clip-driving technique + existing expressive-clip library = foundation for animated heart-event cutscenes (the keystone)
metadata: 
  node_type: memory
  type: project
  originSessionId: 7501f58b-a7fd-4079-bf95-649cdf932bb8
---

**The real takeaway from the 2026-06-23 flashlight work** (which started as "can Walter hold a
flashlight"): we proved a **clip-driving technique** and found a **library of expressive base-game
clips** — together a foundation for the KEYSTONE heart-event/cutscene framework.

**The technique:** drive any animation clip on an NPC by assigning it to anim track 0 —
`clearAnimTrackClip / assignAnimTrackClip(charSet, 0, idx) / setAnimTrackLoopState / enableAnimTrack`
(see `WalterWalker:_startWalkAnim` + `setClipOverride`; console `vlWalterClip`, `vlAnimClips grandpa`).
This works WITH the engine (same path as the walk). **Bone OVERRIDE does NOT work** — `setRotation` on
skeleton bones is wiped by the clip at render every frame (R13, [[walter-walker-history]]). Props
ATTACH to a bone and ride it; you reshape a character by SWAPPING THE CLIP, not posing bones.

**The library (from `vlAnimClips grandpa`, 87 clips):** expressive ones usable with NO custom Blender —
`NPCTalkingMale01/02Source` (gesturing while talking), the **sitting** idles (`NPCMaleSittingIdle01-03`),
the **chainsaw** set (`chainsaw_idle/walk/cut*` — a working/tool pose, fitting for Walter's woodshop),
turn-in-place, etc.

**Why it matters:** the heart-event framework currently plans "NPC stands at a mark and talks" (idle
only — see [[project-open-decisions]]). Clip-driving upgrades that to characters that ACT: the
woodshop-gift reveal could use `chainsaw_cut`/a working pose; dialogue beats could use the talking
clips so they gesture; a quiet beat could use a sitting idle. Reuse base clips before authoring custom.

**Open implementation nuance:** `vlWalterClip` only showed while Walter was WALKING — in the active/
skip-orig regime (R17). When idle/standing, `orig()` runs and re-poses over track 0. So for a STANDING
cutscene pose, the sequencer must hold the skip-orig regime (or drive the clip on a path `orig()`
doesn't overwrite) for the duration. Solve this when wiring clips into the event sequencer.

**How to apply:** when building heart events, reach for `assignAnimTrackClip` on track 0 with an
expressive base clip — not bone posing. Tools to explore the library are already in (kept as dormant
dev commands). Related: [[walter-walker-history]] (R43), [[project-walter-story]] (woodshop-gift arc).
