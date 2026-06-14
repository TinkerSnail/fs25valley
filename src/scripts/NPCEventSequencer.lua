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
    for _, event in ipairs(HEART_EVENTS) do
        if event.npcId == npcId
        and not self.completed[event.id]
        and relationship >= event.threshold then
            self:startEvent(event)
            return
        end
    end
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
    if step.choices and choiceIndex then
        local choice = step.choices[choiceIndex]
        if choice and choice.next then
            self:gotoBranch(choice.next)
            return
        end
    end
    self:advanceStep()
end

function VLEventSequencer:executeStep(step)
    if step.type == "move_npc" then
        local npc = self.npcSystem:getNPC(step.npcId)
        if npc then npc:setPosition(step.x, step.y, step.z, step.ry) end
        self:advanceStep()

    elseif step.type == "camera" then
        self:takeCameraControl(step)
        self:advanceStep()

    elseif step.type == "dialogue" then
        -- Hand off to dialog system; it calls advanceStep when dismissed.
        if g_valleyLife and g_valleyLife.dialog then
            g_valleyLife.dialog:showEventDialogue(step, self)
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
