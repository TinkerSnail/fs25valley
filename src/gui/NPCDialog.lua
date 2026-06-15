-- Press-R interaction and heart-event dialogue rendering.
--
-- Interaction is driven by the VL_INTERACT input action (KEY_r, declared in
-- modDesc.xml). When the player is within range of a villager we activate the
-- action event and show a "Press R to talk to <name>" prompt; pressing it opens
-- a conversation or hands off to the heart-event sequencer.
--
-- Heart-event dialogue is rendered with FS25's built-in dialogs: a plain line
-- uses InfoDialog, and a two-choice step uses YesNoDialog (every authored choice
-- is binary, so yes -> choice 1, no -> choice 2). This build exposes the dialog
-- classes' static show() methods rather than g_gui convenience wrappers; if those
-- are unavailable the layer falls back to console output so tests still complete.

VLNPCDialog = {}
VLNPCDialog.__index = VLNPCDialog

VLNPCDialog.INPUT_ACTION = "VL_INTERACT"

-- Show a single-line info box. onClose runs when the player dismisses it.
-- Returns true if a real GUI dialog was shown.
--   InfoDialog.show(text, callback, target, dialogType, okText, ...)
local function showInfoBox(text, onClose)
    onClose = onClose or function() end
    if InfoDialog ~= nil and type(InfoDialog.show) == "function" then
        InfoDialog.show(text, function() onClose() end)
        return true
    end
    if g_gui ~= nil and type(g_gui.showInfoDialog) == "function" then
        g_gui:showInfoDialog({ text = text, callback = onClose })
        return true
    end
    return false
end

-- Show a two-choice box. onResult is called with 1 (first choice) or 2 (second).
-- Returns true if a real GUI dialog was shown.
--   YesNoDialog.show(callback, target, text, yesText, noText, ...) -> callback(yes)
local function showChoiceBox(text, label1, label2, onResult)
    if YesNoDialog ~= nil and type(YesNoDialog.show) == "function" then
        YesNoDialog.show(function(yes) onResult(yes and 1 or 2) end, nil, text, label1, label2)
        return true
    end
    if g_gui ~= nil and type(g_gui.showYesNoDialog) == "function" then
        g_gui:showYesNoDialog({
            text     = text,
            yesText  = label1,
            noText   = label2,
            callback = function(yes) onResult(yes and 1 or 2) end,
        })
        return true
    end
    return false
end

function VLNPCDialog.new(npcSystem)
    local self = setmetatable({}, VLNPCDialog)
    self.npcSystem      = npcSystem
    self.activeNPC      = nil
    self.actionEventId  = nil
    self.promptName     = nil   -- name currently shown in the action prompt
    return self
end

-- Action events registered at mission-load land in the wrong input context and
-- never fire/show during on-foot play. Instead we register on demand from the
-- per-frame update (which runs in the active gameplay context) when the player
-- enters range, and remove it when they leave.
function VLNPCDialog:registerInput()
    if g_inputBinding == nil or InputAction == nil or InputAction.VL_INTERACT == nil then
        print("[ValleyLife] Input binding unavailable; Press-R interaction disabled.")
        self.inputAvailable = false
        return
    end
    self.inputAvailable = true
end

function VLNPCDialog:removeInput()
    self:unregisterActionEvent()
end

function VLNPCDialog:registerActionEvent(name)
    if not self.inputAvailable then return end
    self:unregisterActionEvent()
    local success, eventId = g_inputBinding:registerActionEvent(
        InputAction.VL_INTERACT, self, VLNPCDialog.onInteractInput,
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true    -- startActive
    )
    if success then
        self.actionEventId = eventId
        local label = string.format(g_i18n:getText("vl_interact_prompt"), name)
        g_inputBinding:setActionEventText(eventId, label)
        g_inputBinding:setActionEventTextVisibility(eventId, true)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventActive(eventId, true)
    else
        print("[ValleyLife] Failed to register VL_INTERACT action event.")
    end
end

function VLNPCDialog:unregisterActionEvent()
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

-- Show/hide the "Press R to talk to <name>" prompt by (re)registering the action
-- event in the active gameplay context when the player enters/leaves range.
function VLNPCDialog:setPrompt(name)
    if name == self.promptName then return end
    self.promptName = name
    if name then
        self:registerActionEvent(name)
    else
        self:unregisterActionEvent()
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

    if not showInfoBox(body, function() end) then
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
        local shown = showChoiceBox(body, step.choices[1].label, step.choices[2].label,
            function(choiceIndex) sequencer:resolveDialogue(step, choiceIndex) end)
        if not shown then
            print(string.format("[ValleyLife][Event] %s: %s", speaker, step.text))
            for i, choice in ipairs(step.choices) do
                print(string.format("  [%d] %s", i, choice.label))
            end
            sequencer:resolveDialogue(step, 1)
        end
        return
    end

    -- Plain line -> info box (advance on dismiss).
    local shown = showInfoBox(body, function() sequencer:resolveDialogue(step, nil) end)
    if not shown then
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
