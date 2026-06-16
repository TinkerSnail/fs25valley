-- Heart event sequencer: camera takeover, NPC marks, branching dialogue.
-- This is the architectural keystone. Ship one complete event end-to-end first.
--
-- Event definition format:
--   {
--     id        = "elara_01",
--     npcId     = "elara",
--     threshold = 20,          -- minimum relationship to trigger
--     steps     = {            -- the main line, played first
--       { type="move_npc",   npcId="elara", x=0, y=0, z=0, ry=0 },
--       { type="camera",     x=0, y=2, z=-5, lookAt={x=0,y=1,z=0} },
--       { type="dialogue",   speaker="elara", text="...",
--         choices = {
--           { label="Sure.",    next="accept" },   -- jumps to branches.accept
--           { label="Not now.", next="decline" },  -- jumps to branches.decline
--         }
--       },
--       -- a dialogue WITHOUT choices.next just advances to the next step
--       { type="end" },
--     },
--     branches  = {            -- optional named sub-sequences a choice can jump to
--       accept  = { { type="dialogue", speaker="elara", text="..." }, { type="end" } },
--       decline = { { type="dialogue", speaker="elara", text="..." }, { type="end" } },
--     }
--   }

VLEventSequencer = {}
VLEventSequencer.__index = VLEventSequencer

-- All authored heart events. Populated by separate content files (not yet written).
local HEART_EVENTS = {}

-- Run fn on the next frame. Opening a new dialog from inside another dialog's
-- close callback conflicts with FS25's dialog teardown (the new dialog gets
-- swallowed and the scene stalls), so we wait one frame for the old dialog to
-- finish closing before advancing.
local function nextFrame(fn)
    if g_currentMission == nil or g_currentMission.addUpdateable == nil then
        fn()
        return
    end
    local updateable = {}
    function updateable:update(dt)
        g_currentMission:removeUpdateable(self)
        fn()
    end
    g_currentMission:addUpdateable(updateable)
end

function VLEventSequencer.new(npcSystem)
    local self = setmetatable({}, VLEventSequencer)
    self.npcSystem    = npcSystem
    self.active       = false
    self.currentEvent = nil
    self.stepIndex    = 1
    self.completed    = {}   -- eventId -> bool
    self.savedCamera  = nil
    return self
end

-- Register an event definition (called by content files).
function VLEventSequencer.registerEvent(def)
    table.insert(HEART_EVENTS, def)
end

-- Called each frame; checks whether any event should trigger.
function VLEventSequencer:checkTriggers(npcId, relationship)
    if self.active then return end
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    for _, event in ipairs(HEART_EVENTS) do
        if event.npcId == npcId
        and not self.completed[event.id]
        and relationship >= event.threshold then
            self:startEvent(event)
            return
        end
    end
end

-- Abort a stuck or in-progress scene (console/debug). Does not mark complete.
function VLEventSequencer:abortActive()
    if not self.active then return end
    print("[ValleyLife] Aborting in-progress event: " .. tostring(self.currentEvent and self.currentEvent.id))
    if g_valleyLife and g_valleyLife.dialog then
        g_valleyLife.dialog:closeReply()
        g_valleyLife.dialog:closeSpeech()
    end
    self:releaseCameraControl()
    self.active       = false
    self.currentEvent = nil
    self.currentSteps = nil
    self.stepIndex    = 1
end

-- Force-start the next uncompleted heart event for a villager (lowest threshold
-- first). Used by vlEvent; bypasses relationship and proximity checks.
function VLEventSequencer:forceTriggerNext(npcId)
    if type(npcId) == "string" then npcId = string.lower(npcId) end
    if self.active then self:abortActive() end
    local best = nil
    for _, event in ipairs(HEART_EVENTS) do
        if event.npcId == npcId and not self.completed[event.id] then
            if best == nil or (event.threshold or 0) < (best.threshold or 0) then
                best = event
            end
        end
    end
    if best == nil then return false, nil end
    print(string.format("[ValleyLife] Starting event %s for %s.", best.id, npcId))
    self:startEvent(best)
    return true, best.id
end

function VLEventSequencer:startEvent(event)
    self.active        = true
    self.currentEvent  = event
    self.currentSteps  = event.steps   -- which sequence is playing (main line or a branch)
    self.stepIndex     = 1
    self:advanceStep()
end

function VLEventSequencer:advanceStep()
    if not self.active then return end
    local steps = self.currentSteps
    if self.stepIndex > #steps then
        self:endEvent()
        return
    end
    local step = steps[self.stepIndex]
    self.stepIndex = self.stepIndex + 1
    self:executeStep(step)
end

-- Jump into a named branch (declared in event.branches) and play it from the top.
function VLEventSequencer:gotoBranch(label)
    local branches = self.currentEvent and self.currentEvent.branches
    local steps = branches and branches[label]
    if not steps then
        print("[ValleyLife] Missing branch '" .. tostring(label) .. "' — ending event.")
        self:endEvent()
        return
    end
    self.currentSteps = steps
    self.stepIndex    = 1
    self:advanceStep()
end

-- Called by the dialog when a dialogue step is dismissed. choiceIndex is the
-- 1-based selected choice, or nil for a plain (choiceless) line.
function VLEventSequencer:resolveDialogue(step, choiceIndex)
    -- Defer one frame: this runs from inside the dismissed dialog's callback, and
    -- the next step often opens a different dialog which would otherwise be eaten
    -- by FS25 closing the current one.
    nextFrame(function()
        if not self.active then return end
        if step.choices and choiceIndex then
            local choice = step.choices[choiceIndex]
            if choice and choice.next then
                self:gotoBranch(choice.next)
                return
            end
        end
        self:advanceStep()
    end)
end

function VLEventSequencer:executeStep(step)
    if step.type == "move_npc" then
        local npc = self.npcSystem:getNPC(step.npcId)
        -- Placeholder (0,0,0) marks aren't authored against the map yet; leave the
        -- NPC where it stands so the scene plays in place instead of teleporting
        -- the villager to the map origin.
        if npc and not (step.x == 0 and step.z == 0) then
            npc:setPosition(step.x, step.y, step.z, step.ry)
        end
        self:advanceStep()

    elseif step.type == "camera" then
        self:takeCameraControl(step)
        self:advanceStep()

    elseif step.type == "dialogue" then
        -- Hand off to dialog system; it calls advanceStep when dismissed.
        if g_valleyLife and g_valleyLife.dialog then
            g_valleyLife.dialog:showEventDialogue(step, self)
        else
            print("[ValleyLife] ERROR: dialog system unavailable — skipping dialogue step.")
            self:advanceStep()
        end

    elseif step.type == "wait" then
        -- step.duration in seconds
        g_currentMission:addUpdateable({
            update = function(updateSelf, dt)
                updateSelf._elapsed = (updateSelf._elapsed or 0) + dt * 0.001
                if updateSelf._elapsed >= step.duration then
                    g_currentMission:removeUpdateable(updateSelf)
                    self:advanceStep()
                end
            end
        })

    elseif step.type == "end" then
        self:endEvent()
    else
        print("[ValleyLife] Unknown event step type: " .. tostring(step.type))
        self:advanceStep()
    end
end

function VLEventSequencer:takeCameraControl(step)
    -- TODO: implement full camera takeover using FS25 camera API.
    -- Placeholder: just prints so we can verify the step fires.
    print(string.format("[ValleyLife] Camera step: pos=(%.1f,%.1f,%.1f)", step.x, step.y, step.z))
end

function VLEventSequencer:releaseCameraControl()
    -- TODO: restore saved camera state
end

function VLEventSequencer:endEvent()
    if not self.active then return end
    local event = self.currentEvent   -- capture before clearing state
    self.completed[event.id] = true
    self:releaseCameraControl()
    self.active       = false
    self.currentEvent = nil
    self.currentSteps = nil
    -- Award relationship bonus for completing this event.
    if g_valleyLife and g_valleyLife.relationships then
        g_valleyLife.relationships:heartEventCompleted(event.npcId)
    end
end

-- Clear completion state for a villager's events so their scenes can be replayed
-- (debug/testing). Also aborts an in-progress event for that villager so a stuck
-- or half-played scene is unstuck.
function VLEventSequencer:resetNPC(npcId)
    if self.active and (self.currentEvent == nil or self.currentEvent.npcId == npcId) then
        self.active       = false
        self.currentEvent = nil
        self.currentSteps = nil
        self:releaseCameraControl()
    end
    local cleared = 0
    for _, event in ipairs(HEART_EVENTS) do
        if event.npcId == npcId and self.completed[event.id] then
            self.completed[event.id] = nil
            cleared = cleared + 1
        end
    end
    return cleared
end

-- Persistence

function VLEventSequencer:saveToXML(xmlFile, baseKey)
    local key = baseKey .. ".events"
    local i = 0
    for id, _ in pairs(self.completed) do
        xmlFile:setValue(string.format("%s.done(%d)#id", key, i), id)
        i = i + 1
    end
    xmlFile:setValue(key .. "#count", i)
end

function VLEventSequencer:loadFromXML(xmlFile, baseKey)
    local key = baseKey .. ".events"
    local count = xmlFile:getValue(key .. "#count", 0)
    for i = 0, count - 1 do
        local id = xmlFile:getValue(string.format("%s.done(%d)#id", key, i))
        if id then self.completed[id] = true end
    end
end
