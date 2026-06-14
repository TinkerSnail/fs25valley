-- Press-E interaction dialog and heart event dialogue display.
-- Stub — full XML layout and button wiring come in the next step.

VLNPCDialog = {}
VLNPCDialog.__index = VLNPCDialog

VLNPCDialog.INPUT_ACTION = "VL_INTERACT"

function VLNPCDialog.new(npcSystem)
    local self = setmetatable({}, VLNPCDialog)
    self.npcSystem       = npcSystem
    self.activeNPC       = nil
    self.eventSequencer  = nil
    return self
end

function VLNPCDialog:update(dt)
    -- Find nearest NPC and show a press-E prompt when in range.
    local nearest, dist = self.npcSystem:getNearestNPC()
    if nearest and dist <= VLConfig.INTERACT_DISTANCE then
        self.activeNPC = nearest
        -- TODO: draw "Press E to talk to <name>" HUD element via g_gui
    else
        self.activeNPC = nil
    end
end

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
        -- Event sequencer took over — dialog will be driven step-by-step.
        return
    end
    -- Normal conversation: relationship bump + static dialogue line.
    g_valleyLife.relationships:tryTalk(npc.id)
    print(string.format("[ValleyLife] Talking to %s (relationship: %d)", npc.name, rel))
    -- TODO: open g_gui MessageDialog with character name, portrait, and dialogue text.
    npc.isTalking = false
end

function VLNPCDialog:showEventDialogue(step, sequencer)
    -- Display a dialogue step from the heart event sequencer.
    -- step.text, step.speaker, step.choices[]
    -- TODO: drive g_gui dialog; call sequencer:resolveDialogue(step, idx) on selection.
    print(string.format("[ValleyLife][Event] %s: %s", step.speaker, step.text))
    if step.choices then
        for i, choice in ipairs(step.choices) do
            print(string.format("  [%d] %s", i, choice.label))
        end
        -- Placeholder: auto-pick the first choice so the branch fires during testing.
        sequencer:resolveDialogue(step, 1)
    else
        sequencer:resolveDialogue(step, nil)
    end
end

function VLNPCDialog:closeConversation()
    if self.activeNPC then
        self.activeNPC.isTalking = false
    end
end
