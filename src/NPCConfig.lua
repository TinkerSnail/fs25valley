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
        walkLoop = {
            waypoints = {
                { x = 412.66, z = -669.52 },                              -- [1] home
                { x = 413.54, z = -686.39 },                             -- [2] door threshold
                { x = 413.52, z = -688.02 },                             -- [3] clear of door
                { x = 411.21, z = -688.28, pauseMinutes = 20 },          -- [4] destination
                { x = 423.66, z = -660.75 },                             -- [5] return leg
            },
            speed = 1.2,  -- m/s
        }
    },
}

-- Save file key prefix
VLConfig.SAVE_KEY = "valleyLife"
VLConfig.SAVE_VERSION = "0.1"
