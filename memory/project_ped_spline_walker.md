---
name: project-ped-spline-walker
description: "vlPedSpline POC — sample a base-game pedestrian spline into waypoints and walk Walter along it (built 2026-06-29, NOT yet verified in-game)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 66507ee5-dfe0-481a-a65d-c5318841c999
---

Mechanism B from the 2026-06-28 pedestrian-spline deep dive is now BUILT as a console command:
`vlPedSpline <splineName> [stepMeters]` in `main.lua` (`VLConsole:pedSpline`).

What it does: resolves the named spline node by name from `getRootNode()` (reusing `vlPedSplinesShow`'s
recursive `findByName`), confirms `I3DUtil.getIsSpline`, samples it with the AISystem loop
(`stepSize = stepMeters/getSplineLength`, default 2.5 m, `getSplinePosition(spline, clamp(t,0,1))`), then SNAPS
Walter onto the NEAREST sample to his current position (sets `_wx/_wy/_wz` + `setTranslation`, terrain-height),
builds a synthetic loop that runs the circuit from that index, wraps around, and ends just before start
(`endOnArrival`), and injects it via `ww:_beginLoop(loop)` — same path `_startReturnToTruck` uses. Logs every
waypoint as `[PedSpline] <name> wpN …`.

PLACEMENT CAVEAT (important): you do NOT pre-position him, and `vlMoveGrandpa` does NOT combine with this. The
walker drives off its cached `_wx/_wz`, seeded ONCE in `_acquireNode` (WalterWalker.lua:181); `vlMoveGrandpa`
moves only the engine GRANDPA node, leaving `_wx/_wz` stale, so the first walk frame snaps him back. The
nearest-point snap inside `vlPedSpline` is the correct lever — user chose "nearest point" (2026-06-29).

**STATUS: code written + repacked, NOT yet verified in-game.** Next: `vlPedSplinesShow` to get spline names →
pick a loop near the woodshop → `vlPedSpline <that>` → watch him trace it. If it works, promote to a config
knob `workLoop = { splineName = "pedestrianSpline17Loop" }` so scheduled routes can use authored town paths.

No sealed API used — fully public `getSpline*` primitives. The sealed `PedestrianSystem` (Mechanism A) was
ruled out (would strip Walter's schedule/conversation control). See [[walter_walker_history]] for the walker
internals and journals/npc-movement.md for the full deep dive.
