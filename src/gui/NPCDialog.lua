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

local modGui = (g_currentModDirectory or "") .. "gui/"

-- Right-pointing triangle mask (the font has no ▶ glyph, so we draw it as a texture).
local VL_TRI = modGui .. "vl_tri.png"

-- Dedicated input context entered while the reply selector is open. Switching to a
-- fresh context (the same technique text-input fields use) suspends on-foot player
-- movement, so the arrow keys navigate the replies instead of walking the character.
local VL_REPLY_CONTEXT = "FS25_ValleyLife_REPLY"

-- Context entered to freeze on-foot movement while a scripted speech sequence plays
-- (e.g. Walter's post-tour intro), matching how the base-game tour locks the player
-- while an NPC is talking. Enter/Space still advance because the speech box registers
-- its own MENU_ACCEPT event inside this context.
local VL_SPEECH_LOCK_CONTEXT = "FS25_ValleyLife_SPEECHLOCK"

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

-- Layout shared by the narration popup and reply selector (normalized screen coords).
local SPEECH_BOX_W     = 0.58
local SPEECH_BOX_BOTTOM = 0.052
local SPEECH_PAD_X   = 0.022
local SPEECH_PAD_Y   = 0.016
local SPEECH_PAD_TOP = 0.032
local SPEECH_PAD_BOTTOM = 0.024
local SPEECH_BODY_HINT_GAP = 0.006
local REPLY_PILL_PAD_X = 0.022
local REPLY_PILL_PAD_Y = 0.010
local REPLY_MARKER_GAP = 0.014
local REPLY_ROW_GAP_PX = 18   -- vertical space between choice rows (~px at 1080p)
local REPLY_TRI_W = 0.009
local REPLY_MARKER_W = 0.016
local SPEECH_TEXT_SIZE = 0.017
local SPEECH_LINE_H  = SPEECH_TEXT_SIZE * 1.25
local SPEECH_TITLE_SIZE = 0.0185
local SPEECH_HINT_SIZE  = 0.014
local SPEECH_HINT_COLOR = { 0.72, 0.72, 0.72, 1 }

-- Visual styling (pixel values for corner radius).
-- drawFilledRectRound uses engine units: cornerSize 1.0 = 20px (see RoundCornerElement).
local ENGINE_CORNER_PX = 20
local DIALOG_PANEL_CORNER_PX = 28   -- main speech / reply box; try 16–40
local REPLY_PILL_CORNER_PX   = nil  -- nil = full capsule (half the pill height)

local function cornerSizeFromPx(px)
    return px / ENGINE_CORNER_PX
end

local function normalizedHeightToPx(nh)
    if g_pixelSizeY ~= nil and g_pixelSizeY > 0 then
        return nh / g_pixelSizeY
    end
    return nh * 1080
end

local function scaledScreenHeight(px)
    if g_currentMission ~= nil and g_currentMission.scalePixelToScreenHeight ~= nil then
        local ok, scaled = pcall(g_currentMission.scalePixelToScreenHeight, g_currentMission, px)
        if ok and type(scaled) == "number" then return scaled end
    end
    return px / 1080
end

local function hudDrawAvailable()
    return drawFilledRectRound ~= nil or drawFilledRect ~= nil
end

local function panelCornerSize(_w, _h)
    return cornerSizeFromPx(DIALOG_PANEL_CORNER_PX)
end

local function pillCornerSize(w, h)
    if REPLY_PILL_CORNER_PX ~= nil then
        return cornerSizeFromPx(REPLY_PILL_CORNER_PX)
    end
    return cornerSizeFromPx(normalizedHeightToPx(h) * 0.5)
end

local function renderRoundedPanel(left, bottom, w, h, r, g, b, a)
    if drawFilledRectRound ~= nil then
        drawFilledRectRound(left, bottom, w, h, panelCornerSize(w, h), r, g, b, a)
        return true
    end
    if drawFilledRect ~= nil then
        drawFilledRect(left, bottom, w, h, r, g, b, a)
        return true
    end
    return false
end

local function renderPill(left, bottom, w, h, r, g, b, a)
    if drawFilledRectRound ~= nil then
        drawFilledRectRound(left, bottom, w, h, pillCornerSize(w, h), r, g, b, a)
        return true
    end
    if drawFilledRect ~= nil then
        drawFilledRect(left, bottom, w, h, r, g, b, a)
        return true
    end
    return false
end

local function l10n(key, fallback)
    if g_i18n ~= nil then
        local text = g_i18n:getText(key)
        if text ~= nil and text ~= "" and text ~= key
        and not text:lower():match("^missing ") then
            return text
        end
    end
    return fallback
end

local function speechHintOrText()
    return l10n("vl_dialog_continue_or", "or")
end

local function speechHintSuffix()
    return l10n("vl_dialog_continue_suffix", "to continue")
end

local function speechHintFallback()
    return l10n("vl_dialog_continue_fallback", "Press Enter or left click to continue")
end

local function scaledHintGlyphSize()
    if g_currentMission ~= nil and g_currentMission.scalePixelToScreenVector ~= nil then
        local ok, w, h = pcall(g_currentMission.scalePixelToScreenVector, g_currentMission, 36, 36)
        if ok and type(w) == "number" then return w, h end
    end
    return 0.015, 0.022
end

-- Shared vertical layout for the continue hint row. InputGlyphElement uses posY as
-- the icon bottom; hint text shares the row center with the glyphs.
local function hintRowLayout()
    local _, glyphH = scaledHintGlyphSize()
    local rowH = math.max(glyphH, SPEECH_HINT_SIZE * 1.25)
    local rowBottom = SPEECH_BOX_BOTTOM + SPEECH_PAD_BOTTOM
    local rowCenter = rowBottom + rowH * 0.5
    local glyphY = rowCenter - glyphH * 0.5
    local textY = rowCenter - SPEECH_HINT_SIZE * 0.35
    return glyphH, rowH, glyphY, textY
end

-- Greedy word-wrap: split text into lines that each fit within maxW (normalized
-- screen width) at the given text size. Falls back to a single line if the engine's
-- text measurement isn't available. A lone word wider than maxW is left on its own
-- line (it'll overflow slightly rather than vanish).
local function wrapText(text, size, maxW)
    text = tostring(text or "")
    if getTextWidth == nil or maxW == nil or maxW <= 0 then return { text } end
    local lines, cur = {}, nil
    for word in text:gmatch("%S+") do
        if cur == nil then
            cur = word
        else
            local try = cur .. " " .. word
            if getTextWidth(size, try) <= maxW then
                cur = try
            else
                lines[#lines + 1] = cur
                cur = word
            end
        end
    end
    if cur ~= nil then lines[#lines + 1] = cur end
    if #lines == 0 then lines[1] = "" end
    return lines
end

-- Widest rendered line in a set (used to center a left-aligned text column).
local function maxTextWidth(lines, size, extraLine, extraSize)
    local maxW = 0
    if getTextWidth == nil then return 0 end
    if extraLine ~= nil and extraSize ~= nil then
        maxW = getTextWidth(extraSize, tostring(extraLine)) or 0
    end
    for _, line in ipairs(lines) do
        local w = getTextWidth(size, line) or 0
        if w > maxW then maxW = w end
    end
    return maxW
end

-- Widest reply row (marker + gap + label), optionally including a prompt line above.
local function maxReplyBlockWidth(wrapped, textSize, markerW, markerGap, innerW, promptLabel, promptSize)
    local maxW = markerW + markerGap
    if getTextWidth ~= nil and promptLabel ~= nil and #promptLabel > 0 then
        maxW = math.max(maxW, getTextWidth(promptSize, promptLabel) or 0)
    end
    for _, lines in ipairs(wrapped) do
        for _, line in ipairs(lines) do
            maxW = math.max(maxW, markerW + markerGap + (getTextWidth(textSize, line) or 0))
        end
    end
    return math.min(maxW, innerW + markerW + markerGap)
end

local function replyRowContentWidth(lines, textSize, markerW, markerGap)
    local maxLineW = 0
    if getTextWidth ~= nil then
        for _, line in ipairs(lines) do
            maxLineW = math.max(maxLineW, getTextWidth(textSize, line) or 0)
        end
    end
    return markerW + markerGap + maxLineW
end

local function centeredBlockLeft(boxLeft, boxW, blockW)
    return boxLeft + (boxW - blockW) * 0.5
end

local function navRowLayout(panelBottom)
    local _, glyphH = scaledHintGlyphSize()
    local rowH = math.max(glyphH, SPEECH_HINT_SIZE * 1.25)
    local rowBottom = panelBottom + SPEECH_PAD_BOTTOM
    local rowCenter = rowBottom + rowH * 0.5
    local glyphY = rowCenter - glyphH * 0.5
    local textY = rowCenter - SPEECH_HINT_SIZE * 0.35
    return rowH, glyphY, textY
end

local function replyChooseSuffix()
    return l10n("vl_dialog_reply_choose", "to choose")
end

local function replyConfirmSuffix()
    return l10n("vl_dialog_reply_confirm", "to confirm")
end

local function replyNavFallback()
    return l10n("vl_dialog_reply_nav_fallback", "↑↓ to choose · Enter to confirm")
end

-- The bottom-center HUD popup (HUDPopupMessage). Field casing varies by build.
local function getPopup()
    local hud = g_currentMission and g_currentMission.hud
    if hud == nil then return nil end
    return hud.ingameMessage or hud.inGameMessage
end

-- Show one spoken line in our bottom panel with word wrap. Falls back to the
-- native HUD popup (which truncates long lines) only if drawFilledRectRound is unavailable.
function VLNPCDialog:closeSpeech()
    if self.speech == nil then return end
    if g_inputBinding ~= nil then
        for _, id in ipairs(self.speech.eventIds or {}) do
            g_inputBinding:removeActionEvent(id)
        end
    end
    self:destroySpeechHintGlyphs(self.speech.hintGlyphs)
    self.speech = nil
end

function VLNPCDialog:destroySpeechHintGlyphs(glyphs)
    if glyphs == nil then return end
    if glyphs.enter ~= nil then pcall(function() glyphs.enter:delete() end) end
    if glyphs.mouse ~= nil then pcall(function() glyphs.mouse:delete() end) end
    if glyphs.up ~= nil then pcall(function() glyphs.up:delete() end) end
    if glyphs.down ~= nil then pcall(function() glyphs.down:delete() end) end
end

function VLNPCDialog:createReplyNavGlyphs()
    if InputGlyphElement == nil or g_inputDisplayManager == nil or InputAction == nil then
        return nil
    end
    local ok, glyphs = pcall(function()
        local gw, gh = scaledHintGlyphSize()
        local up = InputGlyphElement.new(g_inputDisplayManager, gw, gh)
        up:setAction(InputAction.VL_UP, nil, SPEECH_HINT_SIZE, true)
        up:setKeyboardGlyphColor(SPEECH_HINT_COLOR, { 0, 0, 0, 0.80 })

        local down = InputGlyphElement.new(g_inputDisplayManager, gw, gh)
        down:setAction(InputAction.VL_DOWN, nil, SPEECH_HINT_SIZE, true)
        down:setKeyboardGlyphColor(SPEECH_HINT_COLOR, { 0, 0, 0, 0.80 })

        local enter = InputGlyphElement.new(g_inputDisplayManager, gw, gh)
        enter:setAction(InputAction.MENU_ACCEPT, nil, SPEECH_HINT_SIZE, true)
        enter:setKeyboardGlyphColor(SPEECH_HINT_COLOR, { 0, 0, 0, 0.80 })
        return { up = up, down = down, enter = enter }
    end)
    if ok then return glyphs end
    return nil
end

function VLNPCDialog:drawReplyNavHint(r)
    setTextColor(unpack(SPEECH_HINT_COLOR))
    local hintSize = SPEECH_HINT_SIZE
    local textY = r.navTextY
    local glyphY = r.navGlyphY
    local centerX = r.boxCenterX or (r.boxLeft + r.boxW * 0.5)

    if r.navGlyphs ~= nil and r.navGlyphs.up ~= nil and r.navGlyphs.down ~= nil
    and r.navGlyphs.enter ~= nil then
        local sep = " · "
        local chooseText = " " .. replyChooseSuffix()
        local confirmText = sep .. replyConfirmSuffix()
        local upW = r.navGlyphs.up:getGlyphWidth()
        local downW = r.navGlyphs.down:getGlyphWidth()
        local enterW = r.navGlyphs.enter:getGlyphWidth()
        local chooseW = getTextWidth(hintSize, chooseText) or 0
        local confirmW = getTextWidth(hintSize, confirmText) or 0
        local totalW = upW + downW + chooseW + enterW + confirmW
        local x = centerX - totalW * 0.5

        r.navGlyphs.up:setPosition(x, glyphY)
        r.navGlyphs.up:draw()
        x = x + upW

        r.navGlyphs.down:setPosition(x, glyphY)
        r.navGlyphs.down:draw()
        x = x + downW

        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(x, textY, hintSize, chooseText)
        x = x + chooseW

        r.navGlyphs.enter:setPosition(x, glyphY)
        r.navGlyphs.enter:draw()
        x = x + enterW

        renderText(x, textY, hintSize, confirmText)
    else
        local fallback = replyNavFallback()
        local fbW = getTextWidth(hintSize, fallback) or 0
        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(centerX - fbW * 0.5, textY, hintSize, fallback)
    end
end

function VLNPCDialog:createSpeechHintGlyphs()
    if InputGlyphElement == nil or g_inputDisplayManager == nil or InputAction == nil then
        return nil
    end
    local ok, glyphs = pcall(function()
        local gw, gh = scaledHintGlyphSize()
        local enter = InputGlyphElement.new(g_inputDisplayManager, gw, gh)
        enter:setAction(InputAction.MENU_ACCEPT, nil, SPEECH_HINT_SIZE, true)
        enter:setKeyboardGlyphColor(SPEECH_HINT_COLOR, { 0, 0, 0, 0.80 })

        local mouse = InputGlyphElement.new(g_inputDisplayManager, gw, gh)
        mouse:setAction(InputAction.SKIP_MESSAGE_BOX, nil, SPEECH_HINT_SIZE, true)
        mouse:setButtonGlyphColor(SPEECH_HINT_COLOR)
        return { enter = enter, mouse = mouse }
    end)
    if ok then return glyphs end
    return nil
end

function VLNPCDialog:drawSpeechHint(s)
    setTextColor(unpack(SPEECH_HINT_COLOR))
    local hintSize = s.hintSize
    local textY = s.hintTextY or s.hintY
    local glyphY = s.hintGlyphY or textY
    local centerX = s.boxCenterX or (s.boxLeft + s.boxW * 0.5)

    if s.hintGlyphs ~= nil and s.hintGlyphs.enter ~= nil and s.hintGlyphs.mouse ~= nil then
        local orText = " " .. speechHintOrText() .. " "
        local suffix = " " .. speechHintSuffix()
        local enterW = s.hintGlyphs.enter:getGlyphWidth()
        local mouseW = s.hintGlyphs.mouse:getGlyphWidth()
        local orW = getTextWidth(hintSize, orText) or 0
        local suffixW = getTextWidth(hintSize, suffix) or 0
        local totalW = enterW + orW + mouseW + suffixW
        local x = centerX - totalW * 0.5

        s.hintGlyphs.enter:setPosition(x, glyphY)
        s.hintGlyphs.enter:draw()
        x = x + enterW

        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(x, textY, hintSize, orText)
        x = x + orW

        s.hintGlyphs.mouse:setPosition(x, glyphY)
        s.hintGlyphs.mouse:draw()
        x = x + mouseW

        renderText(x, textY, hintSize, suffix)
    else
        local fallback = speechHintFallback()
        local fbW = getTextWidth(hintSize, fallback) or 0
        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(centerX - fbW * 0.5, textY, hintSize, fallback)
    end
end

function VLNPCDialog:onSpeechConfirm()
    local s = self.speech
    if s == nil then return end
    local cb = s.onClose
    self:closeSpeech()
    if cb then cb() end
end

function VLNPCDialog:registerSpeechInput()
    local s = self.speech
    if s == nil or g_inputBinding == nil then return end
    s.eventIds = {}
    local function reg(action, callback)
        if action == nil then return end
        local ok, id = g_inputBinding:registerActionEvent(action, self, callback,
            false, true, false, true)
        if ok then
            g_inputBinding:setActionEventTextVisibility(id, false)
            table.insert(s.eventIds, id)
        end
    end
    reg(InputAction.MENU_ACCEPT,      VLNPCDialog.onSpeechConfirm)
    reg(InputAction.SKIP_MESSAGE_BOX, VLNPCDialog.onSpeechConfirm)
end

-- Speaker is rendered inline ("Speaker: text…") in one flow, matching the base
-- game's tutorial dialogue, so every conversation feels cohesive. This is the
-- default; pass opts.inlineSpeaker = false for the old bold header-line style.
function VLNPCDialog:showSpeechBox(speaker, text, onClose, opts)
    onClose = onClose or function() end
    text = tostring(text or "")
    speaker = tostring(speaker or "")
    local inlineSpeaker = not (opts ~= nil and opts.inlineSpeaker == false)

    self:closeSpeech()

    local boxW     = SPEECH_BOX_W
    local boxLeft  = (1.0 - boxW) * 0.5
    local boxCenterX = boxLeft + boxW * 0.5
    local innerW   = boxW - SPEECH_PAD_X * 2

    if not hudDrawAvailable() then
        local nativeText = inlineSpeaker and speaker ~= ""
            and (speaker .. ": " .. text) or text
        return self:showSpeechBoxNative(inlineSpeaker and "" or speaker, nativeText, onClose)
    end

    -- In inline mode the speaker is folded into the body and no header row is drawn.
    local headerSpeaker = inlineSpeaker and "" or speaker
    local bodyText = text
    if inlineSpeaker and speaker ~= "" then
        bodyText = speaker .. ": " .. text
    end

    local lines = wrapText(bodyText, SPEECH_TEXT_SIZE, innerW)
    local contentW = math.min(maxTextWidth(lines, SPEECH_TEXT_SIZE,
        inlineSpeaker and nil or headerSpeaker,
        inlineSpeaker and nil or SPEECH_TITLE_SIZE), innerW)
    local textX = boxLeft + (boxW - contentW) * 0.5
    local titleH = inlineSpeaker and 0 or (SPEECH_TITLE_SIZE * 1.35)
    local bodyH  = #lines * SPEECH_LINE_H
    local _, hintRowH, hintGlyphY, hintTextY = hintRowLayout()
    local boxH   = SPEECH_PAD_TOP + titleH + bodyH + SPEECH_BODY_HINT_GAP
        + hintRowH + SPEECH_PAD_BOTTOM
    local boxTop = SPEECH_BOX_BOTTOM + boxH

    self.speech = {
        speaker    = headerSpeaker,
        inlineSpeaker = inlineSpeaker,
        lines      = lines,
        onClose    = onClose,
        ttl        = opts and opts.ttl or nil,  -- seconds; auto-dismiss (ambient barks). nil = manual.
        tag        = opts and opts.tag or nil,  -- caller id (e.g. "ambientGreet") so a caller can close ONLY its own box.
        eventIds   = {},
        boxLeft     = boxLeft,
        boxBottom   = SPEECH_BOX_BOTTOM,
        boxW        = boxW,
        boxH        = boxH,
        boxCenterX  = boxCenterX,
        textX       = textX,
        titleY      = boxTop - SPEECH_PAD_TOP - SPEECH_TITLE_SIZE,
        firstLineY  = boxTop - SPEECH_PAD_TOP - titleH - SPEECH_TEXT_SIZE,
        hintGlyphY  = hintGlyphY,
        hintTextY   = hintTextY,
        hintGlyphs  = self:createSpeechHintGlyphs(),
        textSize    = SPEECH_TEXT_SIZE,
        titleSize  = SPEECH_TITLE_SIZE,
        hintSize   = SPEECH_HINT_SIZE,
        lineH      = SPEECH_LINE_H,
    }
    self:registerSpeechInput()
    return true
end

function VLNPCDialog:showSpeechBoxNative(speaker, text, onClose)
    onClose = onClose or function() end
    local popup = getPopup()
    if popup ~= nil and type(popup.showMessage) == "function" then
        popup:showMessage(speaker or "", text or "", -1, nil, function() onClose() end, nil)
        return true
    end
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

function VLNPCDialog:drawSpeech()
    local s = self.speech
    if s == nil then return end

    renderRoundedPanel(s.boxLeft, s.boxBottom, s.boxW, s.boxH, 0, 0, 0, 0.85)

    setTextAlignment(RenderText.ALIGN_LEFT)
    if not s.inlineSpeaker then
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(s.textX, s.titleY, s.titleSize, s.speaker)
        setTextBold(false)
    end
    setTextColor(1, 1, 1, 1)

    local y = s.firstLineY
    for _, line in ipairs(s.lines) do
        renderText(s.textX, y, s.textSize, line)
        y = y - s.lineH
    end

    self:drawSpeechHint(s)

    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextWrapWidth(0)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

-- Show a two-choice box. onResult is called with 1 (first choice) or 2 (second).
-- Returns true if a real GUI dialog was shown.
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
    self.speech         = nil   -- active narration panel (see showSpeechBox)
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

    -- Layout matches the narration popup: same panel width, padding, centered
    -- left-aligned text column, lime pill on the selected row, nav hint below.
    local n        = #options
    local hasQ     = promptText ~= nil and #promptText > 0
    local boxW     = SPEECH_BOX_W
    local boxLeft  = (1.0 - boxW) * 0.5
    local boxBottom = SPEECH_BOX_BOTTOM
    local boxCenterX = boxLeft + boxW * 0.5

    local textSize = SPEECH_TEXT_SIZE
    local lineH    = SPEECH_LINE_H
    local markerW  = REPLY_MARKER_W
    local markerGap = REPLY_MARKER_GAP
    local innerW   = boxW - SPEECH_PAD_X * 2 - markerW - markerGap

    local wrapped, maxLines = {}, 1
    for i = 1, n do
        wrapped[i] = wrapText(options[i], textSize, innerW)
        if #wrapped[i] > maxLines then maxLines = #wrapped[i] end
    end

    local promptLabel = hasQ and ((speaker and (speaker .. ": ") or "") .. promptText) or nil
    local blockW = maxReplyBlockWidth(wrapped, textSize, markerW, markerGap, innerW,
        promptLabel, SPEECH_TITLE_SIZE)
    local blockLeft = centeredBlockLeft(boxLeft, boxW, blockW)
    local markerX = blockLeft
    local textX = blockLeft + markerW + markerGap

    local rowGap     = scaledScreenHeight(REPLY_ROW_GAP_PX)
    local rowContent = maxLines * lineH
    local rowH       = rowContent + rowGap
    local optionsH   = n * rowH
    local qH         = hasQ and (SPEECH_TITLE_SIZE * 1.35 + 0.008) or 0
    local navRowH, navGlyphY, navTextY = navRowLayout(boxBottom)
    local boxH       = SPEECH_PAD_TOP + qH + optionsH + SPEECH_BODY_HINT_GAP
        + navRowH + SPEECH_PAD_BOTTOM
    local boxTop     = boxBottom + boxH
    local firstOptY  = boxTop - SPEECH_PAD_TOP - qH - rowGap * 0.5 - textSize
    local questionY  = boxTop - SPEECH_PAD_TOP - SPEECH_TITLE_SIZE

    local bg = hudDrawAvailable()

    local tri = nil
    if Overlay ~= nil and Overlay.new ~= nil then
        local okT, ovT = pcall(Overlay.new, VL_TRI, markerX, boxBottom, REPLY_TRI_W, 0.016)
        if okT and ovT ~= nil then
            ovT:setColor(0.07, 0.10, 0.0, 1)   -- dark, sits on the lime pill
            tri = ovT
        end
    end

    self.reply = {
        speaker    = speaker,
        prompt     = promptText,
        options    = options,
        lines      = wrapped,
        index      = 1,
        onResult   = onResult,
        eventIds   = {},
        bg         = bg,
        tri        = tri,
        boxLeft    = boxLeft,
        boxBottom  = boxBottom,
        boxW       = boxW,
        boxH       = boxH,
        boxCenterX = boxCenterX,
        blockLeft  = blockLeft,
        blockW     = blockW,
        pillPadX   = REPLY_PILL_PAD_X,
        pillPadY   = REPLY_PILL_PAD_Y,
        markerGap  = markerGap,
        markerW    = markerW,
        markerX    = markerX,
        textX      = textX,
        textSize   = textSize,
        lineH      = lineH,
        innerW     = innerW,
        questionY  = questionY,
        firstOptY  = firstOptY,
        rowH       = rowH,
        rowGap     = rowGap,
        rowContent = rowContent,
        pillH      = rowContent + REPLY_PILL_PAD_Y * 2,
        navGlyphY  = navGlyphY,
        navTextY   = navTextY,
        navGlyphs  = self:createReplyNavGlyphs(),
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
    if r.contextActive then
        self._inReplyContext = true
    end

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
            self._inReplyContext = false
        end
    end
    if self.reply.tri ~= nil and self.reply.tri.delete ~= nil then
        pcall(function() self.reply.tri:delete() end)
    end
    self:destroySpeechHintGlyphs(self.reply.navGlyphs)
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
    self:drawSpeech()

    local r = self.reply
    if r == nil then return end

    if r.bg then
        renderRoundedPanel(r.boxLeft, r.boxBottom, r.boxW, r.boxH, 0, 0, 0, 0.85)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)

    -- Optional prompt above the replies (omitted when already spoken via popup).
    if r.prompt and #r.prompt > 0 then
        local label = (r.speaker and (r.speaker .. ": ") or "") .. r.prompt
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(r.blockLeft, r.questionY, SPEECH_TITLE_SIZE, label)
        setTextBold(false)
    end

    -- Reply options; the selected one gets the lime pill, a ▶ marker, and dark text.
    local y = r.firstOptY
    for i, lines in ipairs(r.lines) do
        local selected = (i == r.index)
        if selected then
            local contentW = replyRowContentWidth(lines, r.textSize, r.markerW, r.markerGap)
            local pillW = contentW + r.pillPadX * 2
            local pillH = r.pillH
            local pillLeft = r.blockLeft - r.pillPadX
            local lineCount = #lines
            local textMidY = y - (math.max(lineCount, 1) - 1) * r.lineH * 0.5
            local pillY = textMidY - pillH * 0.5 + r.textSize * 0.35
            renderPill(pillLeft, pillY, pillW, pillH, 0.62, 0.80, 0.10, 0.92)
            if r.tri ~= nil then
                r.tri:setPosition(r.markerX, y + r.textSize * 0.05)
                r.tri:render()
            end
            setTextColor(0.07, 0.10, 0.0, 1)
        else
            setTextColor(0.93, 0.93, 0.93, 1)
        end
        local ly = y
        for _, line in ipairs(lines) do
            renderText(r.textX, ly, r.textSize, line)
            ly = ly - r.lineH
        end
        y = y - r.rowH
    end

    self:drawReplyNavHint(r)

    -- Reset render state so we don't leak settings into other HUD draws.
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextWrapWidth(0)
    setTextAlignment(RenderText.ALIGN_LEFT)
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

function VLNPCDialog:restoreInputContextIfStuck()
    if not self._inReplyContext or g_inputBinding == nil then return end
    if self.reply ~= nil then return end
    pcall(function() g_inputBinding:revertContext(true) end)
    self._inReplyContext = false
    print("[ValleyLife] Restored default input context (reply selector was stuck).")
end

-- Freeze on-foot movement for a scripted speech sequence. Enter a fresh, empty
-- input context (same technique as the reply selector) so movement actions are
-- suspended; the speech box's own MENU_ACCEPT/SKIP_MESSAGE_BOX events, registered
-- after this, still advance the line. Call unlockMovement() when the sequence ends.
function VLNPCDialog:lockMovement()
    if self._speechLockActive or g_inputBinding == nil then return end
    local ok = pcall(function()
        g_inputBinding:setContext(VL_SPEECH_LOCK_CONTEXT, true, false)
    end)
    self._speechLockActive = ok
end

function VLNPCDialog:unlockMovement()
    if not self._speechLockActive or g_inputBinding == nil then return end
    pcall(function() g_inputBinding:revertContext(true) end)
    self._speechLockActive = false
end

function VLNPCDialog:delete()
    self:closeReply()
    self:closeSpeech()
    self:unregisterActionEvent()
    self:restoreInputContextIfStuck()
    self:unlockMovement()
end

function VLNPCDialog:update(dt)
    -- Auto-dismiss timed speech (ambient barks): tick the TTL and close when it runs out.
    if self.speech ~= nil and self.speech.ttl ~= nil then
        self.speech.ttl = self.speech.ttl - dt / 1000
        if self.speech.ttl <= 0 then
            local onClose = self.speech.onClose
            self:closeSpeech()
            if onClose then pcall(onClose) end
        end
    end

    -- Don't offer interaction while an event is playing.
    if self.npcSystem.sequencer.active then
        self:setPrompt(nil)
        return
    end

    self:restoreInputContextIfStuck()

    -- Stale reply UI after an event reset/abort (speech closes via its own callback).
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
    -- Check for a triggerable heart event first.
    local rel = g_valleyLife.relationships:get(npc.id)
    g_valleyLife.sequencer:checkTriggers(npc.id, rel)
    if g_valleyLife.sequencer.active then
        npc.isTalking = true
        return
    end

    local speaker = self:displayName(npc.id)
    local text, awardRel = g_valleyLife.casualDialogue:pickLine(npc.id)
    if text == nil then
        g_valleyLife.relationships:tryTalk(npc.id)
        return
    end

    npc.isTalking = true
    local function onClose()
        if awardRel then
            g_valleyLife.relationships:tryTalk(npc.id)
        end
        npc.isTalking = false
    end

    if not self:showSpeechBox(speaker, text, onClose) then
        print(string.format("[ValleyLife] %s: %s", speaker, text))
        onClose()
    end
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
            if not self:showSpeechBox(speaker, step.text, function() nextFrame(openSelector) end) then
                print(string.format("[ValleyLife][Event] %s: %s", speaker, step.text))
                openSelector()
            end
        else
            openSelector()
        end
        return
    end

    -- Plain line -> bottom-center speech popup (advance on Continue).
    local shown = self:showSpeechBox(speaker, step.text, function() sequencer:resolveDialogue(step, nil) end)
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
    self:closeSpeech()
    if self.activeNPC then
        self.activeNPC.isTalking = false
    end
end
