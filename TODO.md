# Valley Life — Project TODO

Living backlog. Check items off, add freely. Grounded in the project goals
(`project-overview` memory) and open threads as of 2026-06-22. For *what's already
built*, see the journals — especially [walter-daily-life.md](journals/walter-daily-life.md).

**Priority reminder:** Walter is the most important character (player's grandfather) and gets the
deepest schedule + dialog by design; other villagers stay lighter.

---

## Walter (priority character)

### Dialog / content
- [ ] Write his **real time-of-day lines** (replace placeholders in `src/content/Walter.lua`:
      morning / midday / evening / night, plus `firstMeet` / `alreadyTalked`).
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

## Other villagers (Elara, Kenji, Marta)
- [ ] Lighter-but-real **schedules / routes** (Marta has stop-and-face + a loop; flesh out the rest).
- [ ] **Casual dialogue + at least one heart event each** (vertical-slice target: 3–4 deep characters).
- [ ] Time-of-day greeting pools for them too (the casual-dialogue axis is general now).

## Heart-event framework (keystone)
- [ ] Author **more events end-to-end** — the cutscene sequencer is the single most important system.
- [ ] Confirm branching gated on **relationship + calendar** works across multiple events.

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
