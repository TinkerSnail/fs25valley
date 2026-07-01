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
- [x] **Map tag follows him in the truck** (2026-06-27, c57ce21) — the hotspot's `getWorldPosition` shadow
      now returns the truck's rootNode world x,z while `_inTruck`, so the icon tracks the moving truck instead
      of freezing at leg 1. (ESC-map "Visit"/teleport still reads a deeper snapshot — known limit.)
- [ ] **Ride-along: let the player ride in the PASSENGER seat while Walter drives** (user request
      2026-06-26). The truck has `spec_enterablePassenger`, so hook the base-game passenger-seat system
      rather than hand-roll — research how the player enters a passenger seat (vs driver `enterVehicle`),
      and make it available while Walter is the AI driver. A scenic "ride into town with Grandpa" beat.
- [x] **Wire the drive into his weekly schedule** (2026-06-28) — `VLConsole._marketSchedule`: Walter goes to
      the market **twice a week** (default Tue 06:00 early-morning, Fri 13:00 afternoon). Departure-only — the
      market `stroll` loop self-terminates (1 circuit → walk back to the truck → drive home → resume farm
      loops), so no return to manage; a 19:00 backstop covers a stuck stroll. Market trip PREEMPTS the farm
      loop in its window; the rest of the day is the normal farm loops. `vlWalterSchedule [on|off|now|today <hr>]`,
      `vlWalterMarketReturn` (force the ending). Narrative = drop-off for Marta / bulletin board / stalls / mail
      a letter (the captured stroll). Tunable: the two days/hours, `loopsBeforeReturn` (1), pause lengths.
- [ ] **Market stroll should start at Marta, not the parking lot** — when Walter arrives at the market he
      currently begins the stroll from the parking-lot waypoint (`wp1 marketParkinglot`, by the truck);
      he should head straight to Marta first. Address at some point (stroll-loop ordering / dismount spot).

## Cast — PRIORITIZE the base-game NPCs Walter introduces (user direction 2026-06-25)
Build the characters the player canonically MEETS first: the base-game town NPCs Walter name-drops in
the tutorial. Grounded by mention-frequency in Walter's dialogue (Ben 74×, Katie 51×, Noah/David 20×;
great-uncle **Paul** 152× = off-map family lore). They're the same hookable NPC type as Walter, each
with a full base conversation + help/smalltalk tree to extend additively. See memory
`reference-basegame-npc-roster` + journal `map-riverbend-springs.md`.
- [ ] **Ben (HELPER)** FIRST — Walter's explicit tutorial hand-off ("ask Ben… my most trusted helper").
      Confirm live + hookable (`vlNpcDump`), then layer our dialogue/role (the grain/teaching side).
- [ ] **Extract + explore Ben's backstory** — mine his base-game conversation lines (extract `dataS2.gar`)
      and build a character bible the way we did for **Katie** and **Dave** (see memory `project-katie-character`
      / `project-david-character`). Grounds his characterization before we write his role.
- [ ] **Extract + explore Noah's backstory** — same treatment as Ben/Katie/Dave: mine Noah (FORESTER)'s
      base-game conversation lines and build a character bible before writing his role.
- [ ] **Katie (ANIMAL_DEALER)** — research done; she already delivers the voiced cow tutorial. Hook her,
      point Walter/others to her, extend additively.
- [ ] **Noah (FORESTER) / David (FARMER)** — the forestry + crops branches of the economy web.
- [ ] **Great-uncle Paul** — weave the canon comic family figure (sugar-beet stand, B&B dreams) into
      lore; reconcile with our pinned debt-uncle (different generation — see `project-walter-story`).
- [ ] **Town routes for Dave / Katie / Ben / Noah** — give each their own walk-around-town routes (the
      Walter walker model applies to all base NPCs — same rig).
- [ ] **Social visiting / co-presence** — have them occasionally visit the farm, and visit each other's
      houses, to idle together for a while or take walks together (Katie references walks together in her
      dialog). Makes the town feel alive; build on the route system + a light "who's where" scheduler.
- [ ] **Joint conversation dialog when two NPCs are together** (Stardew-like; user request 2026-06-30) —
      when you talk to an NPC who's hanging out next to another (e.g. Walter + Marta), offer a short
      **group line** that acknowledges the pair instead of the usual solo line. Doesn't need to be long or
      branching — a beat or two of the two of them riffing / reacting to each other. The NPC **chooser
      already knows who's co-present** (`getNearbyNPCs` returns every talkable target in range — see
      `dialog-boxes.md` §"Choosing between overlapping NPCs"), so the plumbing to detect a pair is in
      place; this is mostly a small content system (per-pair or generic "two people" pools + a pick rule).
      **It's a one-off beat, not a mode:** once the joint line finishes, both NPCs go straight back to
      normal 1-on-1 conversations with the player (and the cycle-target chooser) as usual — nothing stays
      locked. So the group line is just an alternate pick inside `openConversation` when a neighbour is
      present; it must not disable/latch either character's regular solo dialogue afterward.
      **HARD CONSTRAINT (additive rule):** never block or replace the **base-game** characters' native
      in-game conversation. For base NPCs (Walter, and later Ben/Katie/Noah/David) the joint beat must
      layer on top and always leave their normal "press to talk" dialog fully reachable — same principle
      as the whole mod (see `dialog-boxes.md` top + `project_walter_constraint`).
- [ ] **Basic business NPCs (ambient town life)** — create simple NPCs for each town business; even without
      enterable interiors, show people coming and going from the business doors. Reuse the SAME door
      spawn/despawn (hide/reveal-at-door) machinery used for Marta and Walter at their home doors.
- [ ] **OPEN:** how do these base NPCs relate to our fabricated **Elara / Kenji / Marta**? Join them,
      or do the base NPCs become the core cast and the fabricated ones step back? (Decide before deep
      content — affects whose heart events we write.)

## Other (fabricated) villagers — Elara, Kenji, Marta
- [ ] **Redo Kenji entirely** — he overlaps too much with base-game **Ben** (HELPER). Rethink Kenji from
      scratch (role / personality / hook) so the two aren't redundant. Whole-character redo, at some point.
- [ ] **Figure out the new Kenji story** — still TBD. One option: lean into the near-identical look and make
      him **Ben's family member** (turn the resemblance into the hook) rather than fighting it.
- [ ] **Marta's full schedule** — build out her complete daily schedule/routes (she currently has only
      stop-and-face + a single loop).
- [x] **Rework Marta's dialog for the market setting** (2026-07-01) — removed the last diner holdovers
      ("kitchen"/"counter") from her heart events + casual greetings and wove in the sunflower farm she
      runs out back of the market (feeds the oil chain). See `src/content/Marta.lua`.
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
- [ ] **Research: do base-game child models exist?** The town has playgrounds but no kids. Dig through the
      base-game character/i3d assets for any child/youth models — if they exist, ambient kids at the
      playgrounds become possible. (Investigation first; populating is a later step.)
- [ ] **Seasonal town events (Stardew-like, but more involved)** — recurring seasonal festivals/celebrations.
      Decorate the WHOLE town seasonally (there's an existing seasonal-decor mod the user likes — go further
      than it). Set-piece idea: **parades** where all the NPCs gather to watch other NPCs march down the town
      streets. (Builds on the route system + a gathering/spectator scheduler; post vertical-slice.)
- [ ] **Building interiors via GIANTS Editor** (pie-in-the-sky) — if feasible, use the GIANTS Editor to
      refine the town buildings and add walk-in interiors for some of them. Big undertaking; depends on what
      the editor allows for base-map buildings.
- [ ] Festivals, marriage, expanded cast (post vertical-slice).
- [ ] Multiplayer (deferred — singleplayer first).

---

## Recently completed (2026-06-22)
Walter's full daily life: schedule, door disappear + 5am morning departure, stairs, stop-and-face,
map icon follow, ESC-map Visit teleport, woodshop door + lights (`woodshopVisit`), time-of-day
ambient greetings. Marta stop-and-face. Fixed the `TimeHelper.getDay` crash that froze all NPCs.
Docs: `engine-api.md`, `console-commands.md` (master directory), `walter-daily-life.md`.
