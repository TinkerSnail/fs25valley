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

-- Walter (GRANDPA) walk loop — waypoints are world X/Z; Y is read from terrain.
-- startHour/endHour use in-game hours (0-24). speed is units/sec.
-- pauseMinutes is in in-game minutes. pauseRy is optional facing rotation (radians).
-- Add waypoints by walking the route in-game and recording positions with vlPos.
VLConfig.WALTER_WALK = {
    startHour = 0,      -- set to real hours once waypoints are confirmed
    endHour   = 24,
    speed     = 0.8,
    waypoints = {
        { x = -758.2, z = 94.3,  pauseMinutes = 2  },  -- home (farmhouse)
        { x = -752.0, z = 94.3,  pauseMinutes = 2  },  -- placeholder: replace with vlPos
    },
}

-- Save file key prefix
VLConfig.SAVE_KEY = "valleyLife"
VLConfig.SAVE_VERSION = "0.1"
