-- Press-R interaction and heart-event dialogue rendering.
--
-- Interaction is driven by the VL_INTERACT input action (KEY_r, declared in
-- modDesc.xml). When the player is within range of a villager we activate the
-- action event and show a "Press R to talk to <name>" prompt; pressing it opens
-- a conversation or hands off to the heart-event sequencer.
--
-- Spoken lines are rendered with FS25's bottom-center HUD popup message (the same
-- widget Walter/Ben use for tips), so dialogue sits at the bottom of the screen
-- and never covers the villager's face. The base game's conversation-with-options
-- UI is a bespoke HUD element that isn't exposed to mods, and the only mod-callable
-- choice widgets (YesNoDialog / MultiOptionDialog) are centred modals -- so to keep
-- the whole conversation at the bottom we draw our own reply selector there, styled
-- to match the narration popup. It falls back to a modal choice box only if the
-- on-foot input surface is unavailable.

VLNPCDialog = {}
VLNPCDialog.__index = VLNPCDialog

VLNPCDialog.INPUT_ACTION = "VL_INTERACT"

-- White texture (tinted at draw time) used to paint the reply panel background, the
-- same technique the engine uses for its own HUD popup background.
local VL_PIXEL = (g_currentModDirectory or "") .. "gui/vl_pixel.png"

-- Rounded-rectangle mask (white + alpha) tinted lime at draw time to paint the
-- highlight pill behind the selected reply, matching the base-game NPC menu.
local VL_PILL = (g_currentModDirectory or "") .. "gui/vl_pill.png"

-- Right-pointing triangle mask (the font has no ▶ glyph, so we draw it as a texture).
local VL_TRI = (g_currentModDirectory or "") .. "gui/vl_tri.png"

-- Dedicated input context entered while the reply selector is open. Switching to a
-- fresh context (the same technique text-input fields use) suspends on-foot player
-- movement, so the arrow keys navigate the replies instead of walking the character.
local VL_REPLY_CONTEXT = "FS25_ValleyLife_REPLY"

-- Defer a function to the next frame. Used when opening the reply selector right
-- after dismissing the narration popup, so the same Enter press that closed the
-- popup doesn't immediately confirm the freshly-registered selector.
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

-- The bottom-center HUD popup (HUDPopupMessage). Field casing varies by build.
local function getPopup()
    local hud = g_currentMission and g_currentMission.hud
    if hud == nil then return nil end
    return hud.ingameMessage or hud.inGameMessage
end

-- Show one spoken line as a Walter-style bottom popup: title = speaker name,
-- body = line. A negative duration keeps it up until the player presses Continue
-- (MENU_ACCEPT / SKIP_MESSAGE_BOX), then onClose advances the scene. Returns true
-- if a surface was shown.
local function showSpeechBox(speaker, text, onClose)
    onClose = onClose or function() end
    local popup = getPopup()
    if popup ~= nil and type(popup.showMessage) == "function" then
        -- duration < 0 -> stays until acknowledged; callback fires on confirm.
        popup:showMessage(speaker or "", text or "", -1, nil, function() onClose() end, nil)
        return true
    end
    -- Fallback: modal info dialog (centered, but keeps the scene playable).
    local body = speaker and (speaker .. ":\n" .. (text or "")) or (text or "")
    if InfoDialog ~= nil and type(InfoDialog.show) == "function" then
        InfoDialog.show(body, function() onClose() end)
        return true
    end
    if g_gui ~= nil and type(g_gui.showInfoDialog) == "function" then
        g_gui:showInfoDialog({ text = body, callback = onClose })
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
    self.reply          = nil   -- active reply-selector state (see showReplySelector)
    return self
end

-- ---------------------------------------------------------------------------
-- Bottom-screen reply selector
--
-- The base game's bottom conversation UI isn't exposed to mods, so we draw our own
-- at the bottom of the screen (matching the narration popup's placement). The NPC's
-- question shows above the choices and the selected reply is highlighted. While the
-- selector is open we switch into a dedicated input context (VL_REPLY_CONTEXT) so the
-- character stops moving and the player can navigate with Up/Down and confirm with
-- Enter/Space.
-- Returns true if the selector was shown.
-- ---------------------------------------------------------------------------
function VLNPCDialog:showReplySelector(speaker, promptText, options, onResult)
    -- Fall back to the modal choice box if the on-foot input surface is missing.
    if g_inputBinding == nil or InputAction == nil or InputAction.VL_INTERACT == nil then
        local body = (speaker and (speaker .. ":\n") or "") .. (promptText or "")
        return showChoiceBox(body, options[1], options[2], onResult)
    end

    -- Layout (normalized screen coords, origin bottom-left), styled after the base
    -- game's NPC menu: a dark panel sitting along the bottom (horizontally centered to
    -- line up with the narration popup), left-aligned replies, and a lime highlight
    -- pill behind the selected one. An optional question line sits above the replies
    -- (omitted when the line was already spoken via popup).
    local n        = #options
    local hasQ     = promptText ~= nil and #promptText > 0
    local padX     = 0.013
    local padY     = 0.016
    local rowH     = 0.034
    local qH       = hasQ and 0.040 or 0.0
    local boxW     = 0.46
    local boxLeft  = (1.0 - boxW) * 0.5   -- centered horizontally
    local boxBottom = 0.052
    local boxH     = padY * 2 + qH + n * rowH
    local boxTop   = boxBottom + boxH

    local textSize = 0.0175
    local textX    = boxLeft + padX + 0.014   -- leave room for the ▶ marker
    -- Baseline of the first (top) reply, then step downward by rowH.
    local firstOptY = boxTop - padY - qH - (rowH - textSize) * 0.5 - textSize

    local bg = nil
    local pill = nil
    if Overlay ~= nil and Overlay.new ~= nil then
        local okBg, ovBg = pcall(Overlay.new, VL_PIXEL, boxLeft, boxBottom, boxW, boxH)
        if okBg and ovBg ~= nil then
            ovBg:setColor(0, 0, 0, 0.62)
            bg = ovBg
        end
        local pillW, pillH = boxW - padX, rowH * 0.96
        local okP, ovP = pcall(Overlay.new, VL_PILL, boxLeft + padX * 0.5, boxBottom, pillW, pillH)
        if okP and ovP ~= nil then
            ovP:setColor(0.62, 0.80, 0.10, 0.92)   -- lime, like Walter's highlight
            pill = ovP
        end
    end

    local tri = nil
    if Overlay ~= nil and Overlay.new ~= nil then
        local okT, ovT = pcall(Overlay.new, VL_TRI, boxLeft + padX, boxBottom, 0.009, 0.016)
        if okT and ovT ~= nil then
            ovT:setColor(0.07, 0.10, 0.0, 1)   -- dark, sits on the lime pill
            tri = ovT
        end
    end

    self.reply = {
        speaker   = speaker,
        prompt    = promptText,
        options   = options,
        index     = 1,
        onResult  = onResult,
        eventIds  = {},
        bg        = bg,
        pill      = pill,
        tri       = tri,
        boxLeft   = boxLeft,
        padX      = padX,
        textX     = textX,
        textSize  = textSize,
        questionY = boxTop - padY - 0.018,
        firstOptY = firstOptY,
        rowH      = rowH,
        pillH     = rowH * 0.96,
    }
    self:registerReplyInput()
    return true
end

function VLNPCDialog:registerReplyInput()
    local r = self.reply
    if r == nil then return end

    -- Enter a fresh GUI input context so the player's on-foot movement events are no
    -- longer active while the selector is open (the same approach text-input fields
    -- use). With movement suspended, the arrow keys are free to drive the selector and
    -- the character no longer walks around. revertContext() in closeReply restores it.
    r.contextActive = pcall(function()
        g_inputBinding:setContext(VL_REPLY_CONTEXT, true, false)
    end)

    local function reg(action, callback)
        if action == nil then return end
        local ok, id = g_inputBinding:registerActionEvent(action, self, callback,
            false, true, false, true)
        if ok then
            g_inputBinding:setActionEventTextVisibility(id, false)
            table.insert(r.eventIds, id)
        end
    end

    -- Up/Down (the mod's own arrow actions) navigate; Enter/Space confirm. We avoid
    -- the stock MENU_UP/MENU_DOWN actions because they share the arrow keys and would
    -- double-step the highlight on each press. We deliberately do NOT reuse VL_INTERACT
    -- here: it's owned by the "Press R to talk" prompt, and registering it on this same
    -- target would leave the action slot occupied, breaking the prompt afterwards.
    reg(InputAction.VL_UP,           VLNPCDialog.onReplyUp)
    reg(InputAction.VL_DOWN,         VLNPCDialog.onReplyDown)
    reg(InputAction.MENU_ACCEPT,     VLNPCDialog.onReplyConfirm)
    reg(InputAction.SKIP_MESSAGE_BOX, VLNPCDialog.onReplyConfirm)
end

function VLNPCDialog:closeReply()
    if self.reply == nil then return end
    if g_inputBinding ~= nil then
        for _, id in ipairs(self.reply.eventIds) do
            g_inputBinding:removeActionEvent(id)
        end
        -- Leave the reply context and restore on-foot movement controls.
        if self.reply.contextActive then
            pcall(function() g_inputBinding:revertContext(true) end)
        end
    end
    if self.reply.bg ~= nil and self.reply.bg.delete ~= nil then
        pcall(function() self.reply.bg:delete() end)
    end
    if self.reply.pill ~= nil and self.reply.pill.delete ~= nil then
        pcall(function() self.reply.pill:delete() end)
    end
    if self.reply.tri ~= nil and self.reply.tri.delete ~= nil then
        pcall(function() self.reply.tri:delete() end)
    end
    self.reply = nil
end

-- Up moves the highlight to the previous reply (wrapping to the last).
function VLNPCDialog:onReplyUp()
    local r = self.reply
    if r == nil then return end
    r.index = (r.index - 2) % #r.options + 1
end

-- Down moves the highlight to the next reply (wrapping to the first).

function VLNPCDialog:onReplyDown()
    local r = self.reply
    if r == nil then return end
    r.index = r.index % #r.options + 1
end

function VLNPCDialog:onReplyConfirm()
    local r = self.reply
    if r == nil then return end
    local index, callback = r.index, r.onResult
    self:closeReply()
    if callback then callback(index) end
end

-- Drawn every frame from the mission draw hook.
function VLNPCDialog:draw()
    local r = self.reply
    if r == nil then return end

    if r.bg ~= nil then
        r.bg:render()
    end

    setTextAlignment(RenderText.ALIGN_LEFT)

    -- Optional question line above the replies (omitted when already spoken).
    if r.prompt and #r.prompt > 0 then
        local label = (r.speaker and (r.speaker .. ": ") or "") .. r.prompt
        setTextBold(true)
        setTextWrapWidth(r.bg and 0.44 or 0)
        setTextColor(1, 1, 1, 1)
        renderText(r.boxLeft + r.padX, r.questionY, 0.0165, label)
        setTextWrapWidth(0)
        setTextBold(false)
    end

    -- Reply options; the selected one gets the lime pill, a ▶ marker, and dark text.
    local y = r.firstOptY
    for i, opt in ipairs(r.options) do
        local selected = (i == r.index)
        if selected then
            if r.pill ~= nil then
                local pillY = y - (r.pillH - r.textSize) * 0.5
                r.pill:setPosition(r.boxLeft + r.padX * 0.5, pillY)
                r.pill:render()
            end
            if r.tri ~= nil then
                r.tri:setPosition(r.boxLeft + r.padX, y + r.textSize * 0.05)
                r.tri:render()
            end
            setTextColor(0.07, 0.10, 0.0, 1)
            renderText(r.textX, y, r.textSize, opt)
        else
            setTextColor(0.93, 0.93, 0.93, 1)
            renderText(r.textX, y, r.textSize, opt)
        end
        y = y - r.rowH
    end

    -- Reset render state so we don't leak settings into other HUD draws.
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextWrapWidth(0)
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
    local function tryRegister()
        return g_inputBinding:registerActionEvent(
            InputAction.VL_INTERACT, self, VLNPCDialog.onInteractInput,
            false,  -- triggerUp
            true,   -- triggerDown
            false,  -- triggerAlways
            true    -- startActive
        )
    end
    local success, eventId = tryRegister()
    -- Self-heal: if the action slot is still occupied (e.g. a stale VL_INTERACT event
    -- leaked onto this target), purge our events for it and retry once so the prompt
    -- never gets permanently stuck on screen.
    if not success and type(g_inputBinding.removeActionEventsByTarget) == "function" then
        pcall(function() g_inputBinding:removeActionEventsByTarget(self) end)
        success, eventId = tryRegister()
    end
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

    -- Safety: if a reply selector is somehow still open with no active event
    -- (e.g. the event was reset), tear it down.
    if self.reply ~= nil then
        self:closeReply()
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
    local body = string.format("%s (%d)", tier.label, relNow)

    if not showSpeechBox(npc.name, body, function() end) then
        print(string.format("[ValleyLife] Talking to %s — %s (%d)", npc.name, tier.label, relNow))
    end
    npc.isTalking = false
end

-- Render one dialogue step from the heart-event sequencer.
function VLNPCDialog:showEventDialogue(step, sequencer)
    local speaker = self:displayName(step.speaker)

    -- Choice step. Like Walter: the NPC first speaks their line as a bottom popup,
    -- then (on Continue) the reply options appear in the bottom selector with no
    -- redundant question header. If there's no line, show the selector immediately.
    if step.choices and #step.choices >= 2 then
        local labels = {}
        for i, choice in ipairs(step.choices) do labels[i] = choice.label end
        local function openSelector()
            local shown = self:showReplySelector(speaker, nil, labels,
                function(choiceIndex) sequencer:resolveDialogue(step, choiceIndex) end)
            if not shown then
                print(string.format("[ValleyLife][Event] %s (choose): %s", speaker, step.text or ""))
                sequencer:resolveDialogue(step, 1)
            end
        end
        if step.text and #step.text > 0 then
            if not showSpeechBox(speaker, step.text, function() nextFrame(openSelector) end) then
                print(string.format("[ValleyLife][Event] %s: %s", speaker, step.text))
                openSelector()
            end
        else
            openSelector()
        end
        return
    end

    -- Plain line -> bottom-center speech popup (advance on Continue).
    local shown = showSpeechBox(speaker, step.text, function() sequencer:resolveDialogue(step, nil) end)
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
