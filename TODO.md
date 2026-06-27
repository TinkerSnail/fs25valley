# Valley Life — Project TODO

Living backlog. Check items off, add freely. Grounded in the project goals
(`project-overview` memory) and open threads as of 2026-06-22. For *what's already
built*, see the journals — especially [walter-daily-life.md](journals/walter-daily-life.md).

**Priority reminder:** Walter is the most important character (player's grandfather) and gets the
deepest schedule + dialog by design; other villagers stay lighter.

---

## Walter (priority character)

### Dialog / content
- [x] Write his **real time-of-day lines** (2026-06-25) — morning / midday / evening / night +
      `alreadyTalked` rewritten in his settled warm-with-dry-edge voice; `firstMeet` /
      `nightWoodshop` kept (already on-voice). Taskmaster/scolding tone removed.
- [ ] **Relationship-aware greetings** — tone warms as the bond grows (the tier pools exist; add them).
- [ ] **Activity/location-specific lines** — once the schedule is locked (e.g. at the gas pump vs the
      mailbox vs inside the woodshop). Deferred on purpose while routes are still moving.
- [ ] **Heart events for Walter** (most of anyone). Standout hook: the **woodshop project** — his
      2–4pm shed visits are him building the player a gift, revealed over a multi-day arc.

### Schedule / behavior
- [ ] **Finalize the daytime schedule** — capture/refine more routes, lock timings. (Only
      `morningDeparture` + `eveningReturn` are "set"; the daytime loops are still being tuned.)
- [ ] Optional polish: **no-"press Enter" ambient styling** for the greeting popup (it currently
      reuses the standard speech box).
- [ ] **Occasional middle-of-the-night "checking pumps" wander** — sometimes he can't sleep and
      emerges from the house in the dead of night (flashlight lit) to walk the `checkingPumps` yard
      route, then back inside. Reuses the `nightWoodshop` machinery (reveal-at-door + deterministic
      per-night roll + hideOnEnd) pointed at the existing `checkingPumps` waypoints — cheap to add.

### Truck / driving (see [walter-truck-driving.md](journals/walter-truck-driving.md))
- [x] **Seated driver pose** — `setVehicleCharacter(grandpa.playerStyle)` (sit + hands-on-wheel IK,
      dressed as Walter). `vlWalterInTruck` / `vlWalterOutTruck`. (2026-06-26, R52)
- [x] **AI road driving** — `vlWalterDrive [<name>|<x z>]` via the base-game AI "Go To" job; confirmed
      driving cross-map on the AI road splines. Named target `farmersMarket` baked. `vlWalterStopDrive`.
- [x] **Full farm⇄market round trip** baked both directions (`vlWalterDrive farmersMarket` / `vlWalterDriveHome`).
- [ ] **Map tag doesn't follow him in the truck** (2026-06-27) — Walter's map hotspot gets stuck at the end
      of leg 1. Cause: the hotspot shadows WalterWalker's *driven* graphicsNode position, which freezes once
      `_inTruck` (the truck drives independently as its own vehicle). Fix: while `_inTruck`, point the hotspot's
      `getWorldPosition` at the TRUCK's rootNode instead (or hide his pin and show the truck's vehicle hotspot).
- [ ] **Ride-along: let the player ride in the PASSENGER seat while Walter drives** (user request
      2026-06-26). The truck has `spec_enterablePassenger`, so hook the base-game passenger-seat system
      rather than hand-roll — research how the player enters a passenger seat (vs driver `enterVehicle`),
      and make it available while Walter is the AI driver. A scenic "ride into town with Grandpa" beat.
- [ ] **Wire the drive into his daily schedule** — timed departure → drive to `farmersMarket` → park →
      (errand) → drive home → re-hide, mirroring the `morningDeparture` edge-trigger pattern.

## Cast — PRIORITIZE the base-game NPCs Walter introduces (user direction 2026-06-25)
Build the characters the player canonically MEETS first: the base-game town NPCs Walter name-drops in
the tutorial. Grounded by mention-frequency in Walter's dialogue (Ben 74×, Katie 51×, Noah/David 20×;
great-uncle **Paul** 152× = off-map family lore). They're the same hookable NPC type as Walter, each
with a full base conversation + help/smalltalk tree to extend additively. See memory
`reference-basegame-npc-roster` + journal `map-riverbend-springs.md`.
- [ ] **Ben (HELPER)** FIRST — Walter's explicit tutorial hand-off ("ask Ben… my most trusted helper").
      Confirm live + hookable (`vlNpcDump`), then layer our dialogue/role (the grain/teaching side).
- [ ] **Katie (ANIMAL_DEALER)** — research done; she already delivers the voiced cow tutorial. Hook her,
      point Walter/others to her, extend additively.
- [ ] **Noah (FORESTER) / David (FARMER)** — the forestry + crops branches of the economy web.
- [ ] **Great-uncle Paul** — weave the canon comic family figure (sugar-beet stand, B&B dreams) into
      lore; reconcile with our pinned debt-uncle (different generation — see `project-walter-story`).
- [ ] **OPEN:** how do these base NPCs relate to our fabricated **Elara / Kenji / Marta**? Join them,
      or do the base NPCs become the core cast and the fabricated ones step back? (Decide before deep
      content — affects whose heart events we write.)

## Other (fabricated) villagers — Elara, Kenji, Marta
- [ ] Lighter-but-real **schedules / routes** (Marta has stop-and-face + a loop; flesh out the rest).
- [ ] **Casual dialogue + at least one heart event each** (vertical-slice target: 3–4 deep characters).
- [ ] Time-of-day greeting pools for them too (the casual-dialogue axis is general now).

## Heart-event framework (keystone)
- [ ] Author **more events end-to-end** — the cutscene sequencer is the single most important system.
- [ ] Confirm branching gated on **relationship + calendar** works across multiple events.

## Player controls
- [ ] **Toggle crouch** (user request 2026-06-26) — make the crouch/squat input a TOGGLE: press Control
      once → character squats and STAYS squatted; press Control again → stand back up. (Base game is
      hold-to-crouch.) Intercept the crouch input action and latch the crouched state. The `isCrouching`
      animation param already exists (`animationsM.xml`); the player crouch state is in
      `PlayerOnFootStateMachine` / `Player.lua` (decompiled refs) — research the input binding + state there.

## Polish / tech debt
- [ ] **Gate dev console commands** before any public release (the `vl*` set is wide open).
- [ ] NPC **appearance isn't persisted** in `valleyLife.xml` (only relationships + events) — decide if
      it needs saving.
- [ ] `vlDoorTest` / `vlLightTest` are kept as **generic testers** for future buildings — reuse them
      when wiring doors/lights elsewhere (method in [engine-api.md](journals/engine-api.md)).

## Later / someday
- [ ] Festivals, marriage, expanded cast (post vertical-slice).
- [ ] Multiplayer (deferred — singleplayer first).

---

## Recently completed (2026-06-22)
Walter's full daily life: schedule, door disappear + 5am morning departure, stairs, stop-and-face,
map icon follow, ESC-map Visit teleport, woodshop door + lights (`woodshopVisit`), time-of-day
ambient greetings. Marta stop-and-face. Fixed the `TimeHelper.getDay` crash that froze all NPCs.
Docs: `engine-api.md`, `console-commands.md` (master directory), `walter-daily-life.md`.
