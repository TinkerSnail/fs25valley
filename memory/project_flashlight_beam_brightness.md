---
name: project-flashlight-beam-brightness
description: "Walter's flashlight beam brightness — light SOURCE changed (i3d spotlight → handtool light); dusk washout vs full-dark"
metadata: 
  node_type: memory
  type: project
  originSessionId: d300dc87-aa70-4230-899e-6879787ac90d
---

Walter's flashlight BEAM (the visible light, distinct from the [[project-flashlight-arm-is-ik-not-clip]] arm-extend).

**The light source was swapped during the real-handtool migration.** Original feature (commit 3f0885f)
lit the beam from the flashlight **i3d's own `lightNode` spotlight**, toggled with raw
`setVisibility(lightNode, on)`. Current code lights it via the **real handtool**:
`ht:setFlashlightIsActive(on, true)` in `_applyRealFlashlight` (WalterWalker.lua ~733). They are
DIFFERENT lights (different intensity/cone/range).

**The old path is orphaned but KEPT as a restore lever.** `WalterWalker:_ensureFlashlight` (~628) +
`_flashlightLightNode` still exist but are never called. Do NOT delete — re-enabling that i3d spotlight
(alongside or instead of the handtool light) is the cheap fix if the beam ever needs to be brighter.

**Perceived "dimmer than it used to be" (2026-06-25):** most likely NOT a regression. The dusk
auto-trigger fires at the seasonal dusk hour (`_duskHour`, summer = 19:00) while the sky is still bright
enough to wash the beam out. Likely MECHANISM (researched 2026-06-25): FS25 is HDR with auto-exposure /
eye-adaptation — in daylight the camera stops exposure down, crushing a fixed-intensity artificial light
so it reads faint; at night exposure opens and the same unchanged light blooms. So the dimming is a
relative/exposure effect, not necessarily the engine literally lowering the light's intensity. Could not
confirm any explicit GIANTS "scale light intensity by time of day" mechanism; the existence of a popular
"Auto Light On/Off" mod implies the base engine does NOT auto-manage static-light state by daytime.
The user's "brighter" memory was from FORCING it on at full dark
(`vlWalterFlashlight 1` late). User confirmed brighter-was-full-dark. **Open verification:** nobody has
yet compared the current handtool beam vs the old i3d spotlight AT FULL DARK — if the handtool beam is
weak even at midnight, re-enable `_ensureFlashlight`. Until that test, treat it as a lighting confound,
not a bug.
