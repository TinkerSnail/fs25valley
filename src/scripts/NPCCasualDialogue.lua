-- Daily greeting pools: first meet, tier lines, already-talked, post-event callbacks.
-- Content files register per-villager tables via VLCasualDialogue.register().

VLCasualDialogue = {}
VLCasualDialogue.__index = VLCasualDialogue

local POOLS = {}

local DEFAULT_ALREADY = {
    "We already talked today.",
    "Catch me tomorrow - I've got nothing new to say.",
}

function VLCasualDialogue.register(npcId, def)
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    POOLS[npcId] = def
end

local function asPool(entry)
    if entry == nil then return {} end
    if type(entry) == "string" then return { entry } end
    return entry
end

-- Time-of-day bucket from the in-game hour. Lets a villager carry morning/midday/evening/night
-- line pools that get mixed into their greeting (schedule-independent — robust to route changes).
local function timeBucket()
    local h = (TimeHelper and TimeHelper.getHour and TimeHelper.getHour()) or 12
    if     h >= 5  and h < 11 then return "morning"
    elseif h >= 11 and h < 16 then return "midday"
    elseif h >= 16 and h < 20 then return "evening"
    else                           return "night" end
end

function VLCasualDialogue.new()
    local self = setmetatable({}, VLCasualDialogue)
    self.met       = {}   -- npcId -> bool (first-meet intro shown)
    self.rotation  = {}   -- npcId -> last index used in a rotating pool
    return self
end

function VLCasualDialogue:nextFromPool(npcId, pool)
    if #pool == 0 then return nil end
    local nextIdx = ((self.rotation[npcId] or 0) % #pool) + 1
    self.rotation[npcId] = nextIdx
    return pool[nextIdx]
end

function VLCasualDialogue:buildGreetingPool(npcId, tierKey)
    local def = POOLS[npcId]
    if def == nil then return {} end

    local pool = {}
    for _, line in ipairs(asPool(def[tierKey] or def.stranger)) do
        table.insert(pool, line)
    end

    -- Mix in the current time-of-day pool if the villager defines one (morning/midday/evening/night).
    for _, line in ipairs(asPool(def[timeBucket()])) do
        table.insert(pool, line)
    end

    if def.afterEvent ~= nil and g_valleyLife ~= nil and g_valleyLife.sequencer ~= nil then
        local completed = g_valleyLife.sequencer.completed
        for eventId, lines in pairs(def.afterEvent) do
            if completed[eventId] then
                for _, line in ipairs(asPool(lines)) do
                    table.insert(pool, line)
                end
            end
        end
    end

    return pool
end

-- Returns text, awardRelationship (true when this talk should grant the daily bump).
function VLCasualDialogue:pickLine(npcId)
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    local def = POOLS[npcId]
    if def == nil then return nil, false end

    local relMgr = g_valleyLife.relationships

    if not self.met[npcId] then
        self.met[npcId] = true
        local line = self:nextFromPool(npcId, asPool(def.firstMeet))
        if line == nil then
            line = self:nextFromPool(npcId, asPool(def.stranger))
        end
        return line, true
    end

    if relMgr:hasTalkedToday(npcId) then
        local pool = asPool(def.alreadyTalked)
        if #pool == 0 then pool = DEFAULT_ALREADY end
        return self:nextFromPool(npcId, pool), false
    end

    local tier = relMgr:getTier(npcId)
    local pool = self:buildGreetingPool(npcId, tier.key)
    if #pool == 0 then
        pool = asPool(def.stranger)
    end
    if #pool == 0 then return nil, false end
    return self:nextFromPool(npcId, pool), true
end

-- A line from the current time-of-day pool only (no first-meet / already-talked gating). Used by
-- the vlWalterSay tester and a good entry point for schedule-independent ambient greetings.
function VLCasualDialogue:pickTimeOfDayLine(npcId)
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    local def = POOLS[npcId]
    if def == nil then return nil end
    local pool = asPool(def[timeBucket()])
    if #pool == 0 then return nil end
    return self:nextFromPool(npcId, pool)
end

-- A line from an arbitrarily-named pool (e.g. "nightWoodshop"), rotated, no first-meet/already-talked
-- gating. For ambient event barks that aren't tied to a time-of-day bucket.
function VLCasualDialogue:pickNamedPool(npcId, key)
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    local def = POOLS[npcId]
    if def == nil then return nil end
    local pool = asPool(def[key])
    if #pool == 0 then return nil end
    return self:nextFromPool(npcId, pool)
end

function VLCasualDialogue:resetNPC(npcId)
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    self.met[npcId] = nil
    self.rotation[npcId] = nil
end

-- Persistence

function VLCasualDialogue:saveToXML(xmlFile, baseKey)
    local key = baseKey .. ".casual"
    local i = 0
    for npcId, met in pairs(self.met) do
        if met then
            local k = string.format("%s.state(%d)", key, i)
            xmlFile:setValue(k .. "#npcId", npcId)
            xmlFile:setValue(k .. "#rot", self.rotation[npcId] or 0)
            i = i + 1
        end
    end
    xmlFile:setValue(key .. "#count", i)
end

function VLCasualDialogue:loadFromXML(xmlFile, baseKey)
    local key = baseKey .. ".casual"
    local count = xmlFile:getValue(key .. "#count", 0)
    for i = 0, count - 1 do
        local k = string.format("%s.state(%d)", key, i)
        local npcId = xmlFile:getValue(k .. "#npcId")
        if npcId then
            self.met[npcId] = true
            self.rotation[npcId] = xmlFile:getValue(k .. "#rot", 0)
        end
    end
end

-- Saves written before casual dialogue existed have no .casual block. Infer first-meet
-- from relationship progress or completed heart events so veterans don't re-intro.
function VLCasualDialogue:syncLegacyMet(relMgr, sequencer)
    if relMgr == nil then return end
    for npcId, _ in pairs(POOLS) do
        if not self.met[npcId] then
            if relMgr:get(npcId) > 0 then
                self.met[npcId] = true
            elseif sequencer ~= nil and sequencer.completed ~= nil then
                for eventId, done in pairs(sequencer.completed) do
                    if done and type(eventId) == "string" and eventId:find("^" .. npcId .. "_") then
                        self.met[npcId] = true
                        break
                    end
                end
            end
        end
    end
end
