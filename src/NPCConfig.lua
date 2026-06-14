VLConfig = {}

-- Interaction distance (meters)
VLConfig.INTERACT_DISTANCE     = 3.0
VLConfig.ACTIVATE_DISTANCE     = 200.0  -- beyond this, NPC updates are skipped

-- Relationship
VLConfig.REL_MIN  = 0
VLConfig.REL_MAX  = 100
VLConfig.REL_TIERS = {
    { label = "Stranger",     min = 0  },
    { label = "Acquaintance", min = 20 },
    { label = "Friend",       min = 40 },
    { label = "Good Friend",  min = 60 },
    { label = "Close Friend", min = 80 },
}

-- Relationship deltas per interaction
VLConfig.REL_DELTA_TALK      = 1
VLConfig.REL_DELTA_GIFT      = 8
VLConfig.REL_DELTA_HEART_EVENT = 10  -- awarded on first completion of a heart event

-- Heart event trigger thresholds (relationship value required)
VLConfig.HEART_EVENT_THRESHOLDS = { 20, 40, 60, 80 }

-- Elmcreek spawn points for each authored villager.
-- TODO: open GIANTS Editor on Elmcreek, click each intended spawn location,
--       read coordinates from the Transform panel, and paste here.
-- Format: { x, y, z, ry }  (ry = Y-axis rotation in radians, 0 = facing +Z)
VLConfig.VILLAGER_SPAWNS = {
    elara  = { x = 0,   y = 0, z = 0,   ry = 0 },   -- TODO: set real coords
    henryk = { x = 10,  y = 0, z = 0,   ry = 0 },   -- TODO: set real coords
    marta  = { x = -10, y = 0, z = 0,   ry = 0 },   -- TODO: set real coords
}

-- Save file key prefix
VLConfig.SAVE_KEY = "valleyLife"
VLConfig.SAVE_VERSION = "0.1"
