---
name: project_walter_as_handtool_holder
description: "Walter should HOLD real handtools via the game's handtool system (use what's there), not our hand-rolled attach/clip plumbing"
metadata: 
  node_type: memory
  type: project
  originSessionId: 211d3e5e-9ba5-4834-8c74-82189c2eb107
---

**Decision (user, 2026-06-24, emphatic — "use what is there"):** The way to give Walter (and any NPC)
a flashlight / chainsaw / any handtool is to make him a **holder of the REAL `HandTool` object through
the game's existing handtool system** — exactly how every multiplayer character model holds a tool.
NOT by loading an i3d ourselves, `link`-ing it to a bone, and forcing a clip (the hand-rolled
`WalterWalker` flashlight, R0–R45 puppeteering). That whole approach reimplements, badly, what the
handtool architecture does natively.

**The architecture (ground truth — observed in MP + confirmed by decompiling the player path):**
A multiplayer remote character holding a flashlight is NOT "a model with an i3d attached." It's a
**complete character entity that is the HOLDER/carrier of a real `HandTool` object**, and the handtool +
character system does everything: attach, third-person animation, light, network sync. It's
**holder-based, not attachment-based.**

Confirmed API pieces (decompiled `dataS.gar` via `fs-luau-decompile` — see [[feedback_use_internet_for_observable_behavior]] for the toolchain, files at `~/fs25_player_anims/decompiled/`):
- `handTool:setHolder(holder)` — `HandToolHolder.lua:84` (`handTool:setHolder(self, true)`). Holders are
  objects (storage mounts, and the player as carrier).
- `HandTool.lua` third-person attach links the tool's `handNode` to
  `carryingPlayer.graphicsComponent.model.thirdPersonRightHandNode` (or `thirdPersonLeftHandNode` if
  `useLeftHand`). So a carrier just needs a `graphicsComponent.model` with those hand nodes — which
  GRANDPA/`playerM` has (every character runs `HumanGraphicsComponent`, per [[feedback_npc_can_do_what_player_can]]).
- `Player.lua` keeps `self.carriedHandTools` / `self.currentHandTool` — the character-carry path.

**Why the flashlight has no special "hold animation":** because there ISN'T one — `HandToolFlashlight.lua`
is pure light management; the body just plays normal idle/walk and the flashlight is held via the
holder/attach. The chainsaw is special only because `HandToolChainsaw.lua` calls
`carryingPlayer:setIsHoldingChainsaw(true)` → drives the `conditionalAnimation`. Tools drive the body by
setting PARAMETERS on the character, not by carrying clips.

**The work is PLUMBING, not feasibility** (per the rule): make Walter a valid carrier/holder so the
handtool system accepts him — i.e., present the `carryingPlayer`-shaped surface the handtool expects
(`graphicsComponent.model` + hand nodes at minimum; possibly `targeter`/`camera` for active tools).
NEXT detail to confirm: the exact setter the PLAYER uses to become a handtool's `carryingPlayer`
(add-to-`carriedHandTools` / `setCarryingPlayer`), then port that onto Walter. Then RETIRE the hand-rolled
`WalterWalker` flashlight code. Don't relitigate whether it's possible — the player demonstrably does it
and Walter is the same rig. Related: [[walter_walker_history]], [[project_clip_animation_opportunity]].
