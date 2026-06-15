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

-- Riverbend Springs spawn points for each authored villager.
-- Captured in-game with the `vlPos` console command from the farmhouse area:
--   player stood at { x = -707.46, y = 47.34, z = 138.98, ry = 0 }, facing +Z.
-- The three villagers are clustered ~3 m apart, a few meters ahead of that spot
-- (+Z), all facing back toward the player (ry = pi). y is auto-snapped to terrain
-- at spawn, so the value here is just a reference.
-- Format: { x, y, z, ry }  (ry = Y-axis rotation in radians, 0 = facing +Z)
VLConfig.VILLAGER_SPAWNS = {
    elara  = { x = -707.46, y = 47.34, z = 142.0, ry = math.pi },
    henryk = { x = -704.46, y = 47.34, z = 142.0, ry = math.pi },
    marta  = { x = -710.46, y = 47.34, z = 142.0, ry = math.pi },
}

-- Save file key prefix
VLConfig.SAVE_KEY = "valleyLife"
VLConfig.SAVE_VERSION = "0.1"
