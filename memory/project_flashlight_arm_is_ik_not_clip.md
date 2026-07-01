---
name: project_flashlight_arm_is_ik_not_clip
description: "The MP flashlight 'arm extends and holds it out' is the rightArm IK CHAIN (not a clip); deleted for the local player, KEPT for NPCs — so Walter already has it"
metadata: 
  node_type: memory
  type: project
  originSessionId: 211d3e5e-9ba5-4834-8c74-82189c2eb107
---

**Ground truth (user, repeatedly, 2026-06-24 — and CONFIRMED in the game files):** when a player turns
the flashlight on in multiplayer, OTHER players see their **arm extend and hold the light out steady.**
This is REAL. Do not relitigate it. (I wasted many turns doing exactly that — treating decompiled lua as
truth over the user's observation. See [[feedback_use_internet_for_observable_behavior]], [[feedback_why_we_circled]].)

**Why it's not a clip and why I couldn't find it:**
- It's the **`rightArm` IK chain**, defined in `playerM.xml` → `player.ikChains.ikChain id="rightArm"`
  (3-node shoulder→upperArm→hand, `target`/`targetOffset`/`alignToTarget`, + finger grip POSES:
  `narrowFingers`(default)/`wideFingers`/`flatFingers`). Procedural IK — never a keyframed clip, so it's
  absent from the 81-clip `animations.i3d.anim` list I kept searching.
- `HumanModel:loadIKChains(xmlFile, rootNode, isRealPlayer)` loads all chains, then **`if isRealPlayer`
  DELETES rightArm/leftArm/rightFoot/leftFoot/spine.** So the LOCAL player has the arm chains stripped
  (and is force-locked to first person while using the flashlight) → you can NEVER see it on yourself.
  Only **remote players + NPCs** (isRealPlayer=false) keep the chains. That's why it only shows on other
  players in MP. Files: `~/fs25_player_anims/decompiled/HumanModel.lua` + `playerM_cfg/playerM.xml`.

**Payoff for Walter:** Walter is an NPC ⇒ isRealPlayer=false ⇒ he KEEPS the `rightArm`/`leftArm` IK chains.
The arm-extend mechanism is already on his rig (`grandpa.playerGraphics.model.ikChains`). To make him
"hold the flashlight out" we DRIVE the existing chain (set its target to a forward/aim point + apply a
grip pose), via the IK solver in `IKUtil`/`IKChain` — we do NOT author or import an animation. Confirm
in-game with vlWalterRig (now dumps `model.ikChains` keys + rightArm present). Then drive it.

NOTE: corrects the earlier (wrong) note in journals/npc-movement.md that the flashlight is "probably
open-hand, no arm pose" — that was the LOCAL-player view; the third-person/NPC body DOES extend the arm
via IK. Fix that journal table. Related: [[project_walter_as_handtool_holder]], [[feedback_npc_can_do_what_player_can]].
