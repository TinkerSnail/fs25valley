-- Press-E interaction and heart-event dialogue rendering.
--
-- Interaction is driven by the VL_INTERACT input action (KEY_e, declared in
-- modDesc.xml). When the player is within range of a villager we activate the
-- action event and show a "Press E to talk to <name>" prompt; pressing it opens
-- a conversation or hands off to the heart-event sequencer.
--
-- Heart-event dialogue is rendered with FS25's built-in dialogs: a plain line
-- uses an info dialog, and a two-choice step uses a yes/no dialog (every
-- authored choice is binary, so yes -> choice 1, no -> choice 2). If g_gui is
-- unavailable the layer falls back to console output so tests still complete.

VLNPCDialog = {}
VLNPCDialog.__index = VLNPCDialog

VLNPCDialog.INPUT_ACTION = "VL_INTERACT"

function VLNPCDialog.new(npcSystem)
    local self = setmetatable({}, VLNPCDialog)
    self.npcSystem      = npcSystem
    self.activeNPC      = nil
    self.actionEventId  = nil
    self.promptName     = nil   -- name currently shown in the action prompt
    return self
end

-- Register the VL_INTERACT action event. Called once the mission/player exist.
function VLNPCDialog:registerInput()
    if g_inputBinding == nil or InputAction == nil or InputAction.VL_INTERACT == nil then
        print("[ValleyLife] Input binding unavailable; Press-E interaction disabled.")
        return
    end
    local success, eventId = g_inputBinding:registerActionEvent(
        InputAction.VL_INTERACT, self, VLNPCDialog.onInteractInput,
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true    -- startActive
    )
    if success then
        self.actionEventId = eventId
        g_inputBinding:setActionEventActive(eventId, false)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
        print("[ValleyLife] VL_INTERACT action event registered.")
    else
        print("[ValleyLife] Failed to register VL_INTERACT action event.")
    end
end

function VLNPCDialog:removeInput()
    if self.actionEventId and g_inputBinding then
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end
end

function VLNPCDialog:update(dt)
    -- Don't offer interaction while an event is playing.
    if self.npcSystem.sequencer.active then
        self:setPrompt(nil)
        return
    end

    local nearest, dist = self.npcSystem:getNearestNPC()
    if nearest and dist <= VLConfig.INTERACT_DISTANCE then
        self.activeNPC = nearest
        self:setPrompt(nearest.name)
    else
        self.activeNPC = nil
        self:setPrompt(nil)
    end
end

-- Show/hide the "Press E to talk to <name>" action prompt.
function VLNPCDialog:setPrompt(name)
    if self.actionEventId == nil or g_inputBinding == nil then return end
    if name == self.promptName then return end
    self.promptName = name
    if name then
        local label = string.format(g_i18n:getText("vl_interact_prompt"), name)
        g_inputBinding:setActionEventActive(self.actionEventId, true)
        g_inputBinding:setActionEventText(self.actionEventId, label)
        g_inputBinding:setActionEventTextVisibility(self.actionEventId, true)
    else
        g_inputBinding:setActionEventActive(self.actionEventId, false)
        g_inputBinding:setActionEventTextVisibility(self.actionEventId, false)
    end
end

-- Input callback (also reachable directly for testing).
function VLNPCDialog:onInteractInput()
    if not self.activeNPC or self.activeNPC.isTalking then return end
    self:openConversation(self.activeNPC)
end

function VLNPCDialog:openConversation(npc)
    npc.isTalking = true
    -- Check for a triggerable heart event first.
    local rel = g_valleyLife.relationships:get(npc.id)
    g_valleyLife.sequencer:checkTriggers(npc.id, rel)
    if g_valleyLife.sequencer.active then
        -- Event sequencer took over; it drives dialogue step-by-step.
        npc.isTalking = false
        return
    end

    -- Normal conversation: relationship bump + a static line with the tier shown.
    g_valleyLife.relationships:tryTalk(npc.id)
    local tier = g_valleyLife.relationships:getTier(npc.id)
    local relNow = g_valleyLife.relationships:get(npc.id)
    local body = string.format(g_i18n:getText("vl_relationship_label"), npc.name, tier.label, relNow)

    if g_gui ~= nil and g_gui.showInfoDialog ~= nil then
        g_gui:showInfoDialog({
            text = body,
            callback = function() end,
        })
    else
        print(string.format("[ValleyLife] Talking to %s — %s (%d)", npc.name, tier.label, relNow))
    end
    npc.isTalking = false
end

-- Render one dialogue step from the heart-event sequencer.
function VLNPCDialog:showEventDialogue(step, sequencer)
    local speaker = self:displayName(step.speaker)
    local body = string.format("%s:\n%s", speaker, step.text or "")

    -- Two-choice step -> yes/no dialog (yes = choice 1, no = choice 2).
    if step.choices and #step.choices >= 2 then
        if g_gui ~= nil and g_gui.showYesNoDialog ~= nil then
            g_gui:showYesNoDialog({
                text    = body,
                yesText = step.choices[1].label,
                noText  = step.choices[2].label,
                callback = function(yes)
                    sequencer:resolveDialogue(step, yes and 1 or 2)
                end,
            })
        else
            print(string.format("[ValleyLife][Event] %s: %s", speaker, step.text))
            for i, choice in ipairs(step.choices) do
                print(string.format("  [%d] %s", i, choice.label))
            end
            sequencer:resolveDialogue(step, 1)
        end
        return
    end

    -- Plain line -> info dialog (advance on dismiss).
    if g_gui ~= nil and g_gui.showInfoDialog ~= nil then
        g_gui:showInfoDialog({
            text = body,
            callback = function() sequencer:resolveDialogue(step, nil) end,
        })
    else
        print(string.format("[ValleyLife][Event] %s: %s", speaker, step.text))
        sequencer:resolveDialogue(step, nil)
    end
end

-- Resolve a speaker id ("elara") to a display name ("Elara").
function VLNPCDialog:displayName(speakerId)
    local npc = self.npcSystem:getNPC(speakerId)
    if npc and npc.name then return npc.name end
    if type(speakerId) == "string" and #speakerId > 0 then
        return speakerId:sub(1, 1):upper() .. speakerId:sub(2)
    end
    return "???"
end

function VLNPCDialog:closeConversation()
    if self.activeNPC then
        self.activeNPC.isTalking = false
    end
end
