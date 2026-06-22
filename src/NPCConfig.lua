VLConfig = {}

-- Interaction distance (meters)
VLConfig.INTERACT_DISTANCE     = 3.0
VLConfig.ACTIVATE_DISTANCE     = 200.0  -- beyond this, NPC updates are skipped

-- NPC outfit schedule: work vs leisure (see TimeHelper.getOutfitMode).
-- Work hours Mon–Fri only, excluding holidays; weekends and holidays are leisure all day.
VLConfig.OUTFIT_WORK_START_HOUR = 5.5   -- 5:30 AM
VLConfig.OUTFIT_WORK_END_HOUR   = 16.5  -- 4:30 PM (leisure from 4:30 PM onward)

-- Fixed calendar holidays (month 1–12, day of month). Floating US holidays are detected in TimeHelper.
VLConfig.OUTFIT_HOLIDAYS = {
    { month = 1,  day = 1,  label = "New Year's Day" },
    { month = 7,  day = 4,  label = "Independence Day" },
    { month = 12, day = 25, label = "Christmas" },
    { month = 12, day = 26, label = "Day after Christmas" },
}

-- Relationship
VLConfig.REL_MIN  = 0
VLConfig.REL_MAX  = 100
VLConfig.REL_TIERS = {
    { key = "stranger",     label = "Stranger",     min = 0  },
    { key = "acquaintance", label = "Acquaintance", min = 20 },
    { key = "friend",       label = "Friend",       min = 40 },
    { key = "goodFriend",   label = "Good Friend",  min = 60 },
    { key = "closeFriend",  label = "Close Friend", min = 80 },
}

-- Relationship deltas per interaction
VLConfig.REL_DELTA_TALK      = 1
VLConfig.REL_DELTA_GIFT      = 8
VLConfig.REL_DELTA_HEART_EVENT = 10  -- awarded on first completion of a heart event

-- Heart event trigger thresholds (relationship value required)
VLConfig.HEART_EVENT_THRESHOLDS = { 20, 40, 60, 80 }

-- Riverbend Springs spawn points for each authored villager.
-- Captured in-game with the `vlPos` console command.
-- y is auto-snapped to terrain at spawn, so the value here is just a reference.
-- Format: { x, y, z, ry }  (ry = Y-axis rotation in radians, 0 = facing +Z)
VLConfig.VILLAGER_SPAWNS = {
    elara  = { x = -707.46, y = 47.34, z = 142.0, ry = math.pi },
    kenji = { x = -704.46, y = 47.34, z = 142.0, ry = math.pi },
    marta  = { x = 412.66, y = 71.39, z = -669.52, ry = math.pi - math.rad(30),
        workLoops = {
            {
                name = "morningRounds",
                startHour = 6, endHour = 9,
                speed = 1.2,
                waypoints = {
                    { x = 412.66, z = -669.52 },                             -- [1] office wall
                    { x = 413.54, z = -686.39 },                             -- [2] door threshold
                    { x = 413.52, z = -688.02 },                             -- [3] clear of door
                    { x = 411.21, z = -688.28, pauseMinutes = 30 },         -- [4] mailbox
                    { x = 413.52, z = -688.02 },                             -- [5] clear of door (return)
                    { x = 413.54, z = -686.39 },                             -- [6] door threshold (return)
                    { x = 414.01, z = -676.89 },                             -- [7] path to bulletin board
                    { x = 419.96, z = -674.78 },                             -- [8] path to bulletin board
                    { x = 420.60, z = -660.64 },                             -- [9] path to bulletin board
                    { x = 423.66, z = -660.75, pauseMinutes = 30, pauseRy = math.rad(-45) }, -- [10] bulletin board
                    { x = 413.61, z = -660.48 },                             -- [11] path to office wall
                },
            },
            {
                name = "afternoonRounds",
                startHour = 13, endHour = 16,
                speed = 1.2,
                waypoints = {
                    { x = 412.66, z = -669.52 },                             -- [1] office wall
                    { x = 413.07, z = -658.99 },                             -- [2] north extension
                    { x = 431.16, z = -645.66 },                             -- [3] path to ring toss
                    { x = 430.28, z = -640.32, pauseMinutes = 5, pauseRy = math.rad(-90) }, -- [4] ring toss
                    { x = 449.85, z = -636.69, pauseMinutes = 10 },          -- [5] flower stand
                    { x = 426.84, z = -605.53 },                             -- [6] door of barn
                    { x = 426.92, z = -588.86 },                             -- [7] back of barn
                    { x = 427.83, z = -583.20 },                             -- [8] barn path
                    { x = 460.05, z = -582.60 },                             -- [9] driveway
                    { x = 459.75, z = -607.23 },                             -- [10] driveway2
                    { x = 467.26, z = -607.22 },                             -- [11] playground1
                    { x = 469.93, z = -618.51 },                             -- [12] playground2
                    { x = 471.87, z = -630.27 },                             -- [13] playground3
                    { x = 473.03, z = -638.19 },                             -- [14] playground4
                    { x = 482.45, z = -638.47 },                             -- [15] shed1
                    { x = 483.02, z = -652.93 },                             -- [16] shed2
                    { x = 486.21, z = -652.32, pauseMinutes = 3, pauseRy = math.rad(135) }, -- [17] shed3
                    { x = 483.90, z = -653.60 },                             -- [18] shed4
                    { x = 484.05, z = -656.97 },                             -- [19] shed5
                    { x = 482.02, z = -657.10 },                             -- [20] shed6
                    { x = 482.46, z = -666.37 },                             -- [21] shed7
                    { x = 479.71, z = -666.77 },                             -- [22] house1
                    { x = 479.33, z = -671.07 },                             -- [23] house2
                    { x = 460.48, z = -670.69 },                             -- [24] house3
                    { x = 460.36, z = -628.44 },                             -- [25] house4
                },
            },
            {
                name = "eveningHome",
                startHour = 16,
                speed = 1.2,
                despawnOnEnd = true,
                waypoints = {
                    { x = 462.89, z = -652.53 },                             -- [1] door threshold (despawn)
                    { x = 413.07, z = -658.99 },                             -- [2] north extension
                    { x = 460.36, z = -628.44 },                             -- [3] house4
                    { x = 460.28, z = -652.39 },                             -- [4] house5
                },
            },
            {
                name = "morningCommute",
                startHour = 5.5, endHour = 6,
                speed = 1.2,
                waypoints = {
                    { x = 412.66, z = -669.52 },                             -- [1] office wall (termination)
                    { x = 460.28, z = -652.39 },                             -- [2] house5
                    { x = 460.36, z = -628.44 },                             -- [3] house4
                    { x = 413.07, z = -658.99 },                             -- [4] north extension
                },
            },
        },
    },
}

-- Walter (GRANDPA) walk schedule — named, callable loops (same convention as
-- Marta's workLoops; both resolve through WorkLoopHelper).
--   * loops is an ORDERED array; each loop is auto-selected by [startHour,endHour)
--     and re-fires on the 2-hour tick, or force-started with: vlWalk grandpa <name>
--   * waypoint [1] is always "home" — it starts AND ends the circuit; when Walter
--     returns to it the base game resumes idle control (he stays the real GRANDPA,
--     so there is NO despawn, unlike Marta's eveningHome).
--   * x/z are world coords (vlPos). Optional y (also from vlPos) is interpolated
--     along a segment to follow porches/stairs the terrain heightmap omits; without
--     y, height snaps to terrain. pauseMinutes is in-game minutes; pauseRy is an
--     optional facing (radians) held during the pause.
-- TODO: every stop below tagged PLACEHOLDER needs real coords — stand on the spot
--       in-game, run vlPos, and paste { x, z } here. Tune startHour/endHour to taste.
VLConfig.WALTER_WALK = {
    speed        = 0.8,
    homeRy       = 0.5236,  -- idle facing when a loop ends (GRANDPA's spawn heading, ~30°)
    yOffset      = 0,       -- meters subtracted from his driven height (fixes float; tune live with vlWalterYOffset)
    stairLift    = 0.15,    -- bow-lift on sloped segments to clear step noses; tune live with vlWalterStairLift
    dayStartHour = 5,       -- he "starts his day" at 5am: fires once per day (edge-triggered) to reappear at home if he stepped inside last evening
    interactRange = 4.5,    -- meters: how close the player must be to his walked position for the talk prompt (we set isPlayerInRange ourselves; the physics trigger is unreliable while walking)
    approachRange = 6.0,    -- meters: he stops walking & turns to face the player within this range, so his stationary trigger fires the normal base conversation; resumes when they leave
    visitOffset   = 2.0,    -- meters: ESC-map "Visit" drops the player this far in front of Walter (his facing) instead of inside his model
    home         = { x = -758.2, y = 47.0, z = 94.3 },  -- GRANDPA_FARMHOUSE spot; where the morning reveal places him
    -- Woodshop door (cosmetic): the placeable tinyShed01 nearest `near`, animated object `saveId`.
    -- A waypoint with openDoor/closeDoor triggers it via ao:setDirection(+1/-1). doorRotate02 = entry side.
    woodshopDoor = { near = { x = -778.6, z = 106.7 }, config = "tinyShed01", saveId = "doorRotate02" },
    loops = {
        -- Captured 2026-06-21 with vlPos. Other loops (morningRounds, middayPorch,
        -- afternoonStroll, ...) get added back here as we record their stops.
        {
            name = "eveningReturn", startHour = 19, endHour = 20,
            waypoints = {
                { name = "home",         x = -758.2,  y = 47.0,  z = 94.3 },                    -- [1] start/end (GRANDPA_FARMHOUSE spot)
                { name = "doorApproach", x = -760.32, y = 47.0,  z = 97.06 },                   -- [2] base of the stairs; ground level so home->here stays flat
                { name = "stairMid",     x = -760.90, y = 47.0,  z = 96.23 },                   -- [3] foot of the stairs at ground level → incline begins here (not before)
                { name = "houseDoor",    x = -761.73, y = 47.69, z = 94.61, hideOnEnd = true }, -- [4] threshold; step inside on arrival (setVisibility false); porch floor (vlPos read 47.99 high by ~0.3, corrected)
            },
        },
        -- Morning version of the door run, REVERSED: he emerges from the house at 5am and walks
        -- down to home. Triggered by the wake-up (placed at the door, then this runs) — manualOnly
        -- so the hourly auto-selector never fires it. Ends at home (endOnArrival), no hide.
        {
            name = "morningDeparture", manualOnly = true,
            waypoints = {
                { name = "houseDoor",    x = -761.73, y = 47.69, z = 94.61 },                  -- [1] start: at the door (revealed here)
                { name = "stairMid",     x = -760.90, y = 47.0,  z = 96.23 },                  -- [2] foot of the stairs
                { name = "doorApproach", x = -760.32, y = 47.0,  z = 97.06 },                  -- [3] base of the stairs
                { name = "home",         x = -758.2,  y = 47.0,  z = 94.3, endOnArrival = true }, -- [4] home: stop & idle (base game resumes)
            },
        },
        -- MORNING (6-9): out-and-back across the yard, "checking the pumps". Captured 2026-06-21
        -- with vlPos (outbound leg, mirrored for the return). y omitted so he grounds to terrain
        -- (flat yard). ~67m out, ~130m round trip. `vlWalk grandpa checkingPumps`.
        {
            name = "checkingPumps", startHour = 6, endHour = 9,
            waypoints = {
                { name = "home",        x = -758.2,  z = 94.3 },                      -- [1] start/end (GRANDPA_FARMHOUSE spot)
                { name = "bench",       x = -749.15, z = 91.74 },                     -- [2]
                { name = "swingset",    x = -745.95, z = 93.36 },                     -- [3]
                { name = "orangeCone",  x = -740.93, z = 90.31 },                     -- [4]
                { name = "pumphouse",   x = -698.67, z = 63.05 },                     -- [5] farthest (~67m), but 4th stop
                { name = "gaspump",     x = -699.08, z = 86.38, pauseMinutes = 15 },  -- [6] turnaround (last), pause a moment
                { name = "pumphouseB",  x = -698.67, z = 63.05 },                     -- [7] retrace
                { name = "orangeConeB", x = -740.93, z = 90.31 },                     -- [8]
                { name = "swingsetB",   x = -745.95, z = 93.36 },                     -- [9]
                { name = "benchB",      x = -749.15, z = 91.74 },                     -- [10] → auto-return to home
            },
        },
        -- MIDDAY (9-12): out to the mailbox and back, pause to check the mail. Captured 2026-06-22
        -- with vlPos (outbound leg, mirrored). y omitted → terrain grounding. `vlWalk grandpa mailbox`.
        {
            name = "mailbox", startHour = 9, endHour = 12,
            waypoints = {
                { name = "home",         x = -758.2,  z = 94.3 },                     -- [1] start/end
                { name = "woodShop",     x = -773.35, z = 111.71 },                   -- [2]
                { name = "entryDrive",   x = -778.71, z = 128.54 },                   -- [3]
                { name = "mailApproach", x = -793.01, z = 136.04 },                   -- [4]
                { name = "mailbox",      x = -795.10, z = 128.02, pauseMinutes = 20 },-- [5] mailbox (pause to check mail)
                { name = "mailApproachB",x = -793.01, z = 136.04 },                   -- [6] retrace
                { name = "entryDriveB",  x = -778.71, z = 128.54 },                   -- [7]
                { name = "woodShopB",    x = -773.35, z = 111.71 },                   -- [8] → auto-return to home
            },
        },
        -- AFTERNOON (12-16): same approach as the mailbox route (woodShop/entryDrive/mailApproach)
        -- but the final stop is the produce stand instead. New endpoint captured 2026-06-22 with
        -- vlPos. y omitted → terrain grounding. `vlWalk grandpa produceStand`.
        {
            name = "produceStand", startHour = 12, endHour = 16,
            waypoints = {
                { name = "home",         x = -758.2,  z = 94.3 },                       -- [1] start/end
                { name = "woodShop",     x = -773.35, z = 111.71 },                     -- [2] (shared w/ mailbox)
                { name = "entryDrive",   x = -778.71, z = 128.54 },                     -- [3] (shared)
                { name = "mailApproach", x = -793.01, z = 136.04 },                     -- [4] (shared)
                { name = "produceStand", x = -797.59, z = 140.01, pauseMinutes = 20 },  -- [5] the stand (pause)
                { name = "mailApproachB",x = -793.01, z = 136.04 },                     -- [6] retrace
                { name = "entryDriveB",  x = -778.71, z = 128.54 },                     -- [7]
                { name = "woodShopB",    x = -773.35, z = 111.71 },                     -- [8] → auto-return to home
            },
        },
        -- WOODSHOP VISIT: walk to the shed, OPEN its door (doorRotate02), step inside and hang out,
        -- then come back out and close it. Reuses the woodShop approach point; new points captured
        -- 2026-06-22 with vlPos. manualOnly (test with `vlWalk grandpa woodshopVisit`) until we slot
        -- a time. Door is cosmetic (Walter has no collider) — openDoor/closeDoor just swing it on cue.
        {
            name = "woodshopVisit", manualOnly = true,
            waypoints = {
                { name = "home",         x = -758.2,  z = 94.3 },                       -- [1] start/end
                { name = "woodShop",     x = -773.35, z = 111.71 },                     -- [2] recycled approach
                { name = "shedApproach", x = -777.09, z = 111.10, openDoor = true },    -- [3] just outside — open the door
                { name = "shedDoor",     x = -776.41, z = 108.35 },                     -- [4] threshold
                { name = "shedInside",   x = -780.44, z = 106.55, pauseMinutes = 45, lightsOn = true },  -- [5] inside — lights on, hang out
                { name = "shedDoorB",    x = -776.41, z = 108.35, lightsOff = true },   -- [6] exit threshold — lights off
                { name = "shedApproachB",x = -777.09, z = 111.10, closeDoor = true },   -- [7] just outside — close behind him
                { name = "woodShopB",    x = -773.35, z = 111.71 },                     -- [8] → auto-return to home
            },
        },
    },
}

-- Save file key prefix
VLConfig.SAVE_KEY = "valleyLife"
VLConfig.SAVE_VERSION = "0.1"
