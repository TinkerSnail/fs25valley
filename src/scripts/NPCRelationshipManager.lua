-- Player-NPC relationship: 0-100 scale, persisted per savegame.

VLRelationshipManager = {}
VLRelationshipManager.__index = VLRelationshipManager

function VLRelationshipManager.new()
    local self = setmetatable({}, VLRelationshipManager)
    self.values = {}       -- npcId -> 0-100
    self.talkedToday = {}  -- npcId -> bool (reset on day change)
    self.lastDay = -1
    return self
end

function VLRelationshipManager:get(npcId)
    return self.values[npcId] or 0
end

function VLRelationshipManager:change(npcId, delta)
    local cur = self:get(npcId)
    self.values[npcId] = math.max(VLConfig.REL_MIN, math.min(VLConfig.REL_MAX, cur + delta))
    return self.values[npcId]
end

function VLRelationshipManager:getTier(npcId)
    local val = self:get(npcId)
    local tier = VLConfig.REL_TIERS[1]
    for _, t in ipairs(VLConfig.REL_TIERS) do
        if val >= t.min then tier = t end
    end
    return tier
end

function VLRelationshipManager:hasTalkedToday(npcId)
    local today = TimeHelper.getMonotonicDay()
    if today ~= self.lastDay then return false end
    return self.talkedToday[npcId] == true
end

function VLRelationshipManager:tryTalk(npcId)
    local today = TimeHelper.getMonotonicDay()
    if today ~= self.lastDay then
        self.talkedToday = {}
        self.lastDay = today
    end
    if self.talkedToday[npcId] then return false end
    self.talkedToday[npcId] = true
    self:change(npcId, VLConfig.REL_DELTA_TALK)
    return true
end

function VLRelationshipManager:giveGift(npcId)
    self:change(npcId, VLConfig.REL_DELTA_GIFT)
end

function VLRelationshipManager:heartEventCompleted(npcId)
    self:change(npcId, VLConfig.REL_DELTA_HEART_EVENT)
end

-- Persistence

function VLRelationshipManager:saveToXML(xmlFile, baseKey)
    local key = baseKey .. ".relationships"
    local i = 0
    for npcId, val in pairs(self.values) do
        local k = string.format("%s.rel(%d)", key, i)
        xmlFile:setValue(k .. "#npcId", npcId)
        xmlFile:setValue(k .. "#value", val)
        i = i + 1
    end
    xmlFile:setValue(key .. "#count", i)
end

function VLRelationshipManager:loadFromXML(xmlFile, baseKey)
    local key = baseKey .. ".relationships"
    local count = xmlFile:getValue(key .. "#count", 0)
    for i = 0, count - 1 do
        local k = string.format("%s.rel(%d)", key, i)
        local npcId = xmlFile:getValue(k .. "#npcId")
        local val   = xmlFile:getValue(k .. "#value", 0)
        if npcId then
            self.values[npcId] = val
        end
    end
end
