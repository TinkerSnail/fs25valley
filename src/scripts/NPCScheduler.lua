-- Daily schedule: where each NPC is and what they're doing at a given hour.
-- Stub - will drive NPC pathfinding once the road spline system is wired up.

VLNPCScheduler = {}
VLNPCScheduler.__index = VLNPCScheduler

-- Activity definitions per NPC id.
-- Each entry: { start=hour, ["end"]=hour, location={x,z}, label="..." }
-- TODO: fill these in once Riverbend Springs spawn coordinates are confirmed.
local SCHEDULES = {
    elara = {
        { start = 7,  ["end"] = 9,  label = "morning routine" },
        { start = 9,  ["end"] = 12, label = "shop"            },
        { start = 12, ["end"] = 13, label = "lunch"           },
        { start = 13, ["end"] = 18, label = "shop"            },
        { start = 18, ["end"] = 22, label = "home"            },
        { start = 22, ["end"] = 7,  label = "sleep"           },
    },
    kenji = {
        { start = 6,  ["end"] = 12, label = "field work"      },
        { start = 12, ["end"] = 13, label = "lunch"           },
        { start = 13, ["end"] = 17, label = "field work"      },
        { start = 17, ["end"] = 20, label = "workshop"        },
        { start = 20, ["end"] = 6,  label = "sleep"           },
    },
    marta = {
        { start = 8,  ["end"] = 12, label = "errands"         },
        { start = 12, ["end"] = 14, label = "lunch"           },
        { start = 14, ["end"] = 19, label = "park"            },
        { start = 19, ["end"] = 22, label = "home"            },
        { start = 22, ["end"] = 8,  label = "sleep"           },
    },
}

function VLNPCScheduler.new()
    return setmetatable({}, VLNPCScheduler)
end

function VLNPCScheduler:getCurrentActivity(npcId)
    local schedule = SCHEDULES[npcId]
    if not schedule then return nil end
    local hour = TimeHelper.getHour()
    for _, slot in ipairs(schedule) do
        local s, e = slot.start, slot["end"]
        local inSlot = (e > s) and (hour >= s and hour < e)
                    or (e < s) and (hour >= s or hour < e)
        if inSlot then return slot end
    end
    return nil
end
