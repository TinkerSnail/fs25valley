-- Post-tour "meet the town" beat.
--
-- The base-game guided tour ends with Walter (GRANDPA) naming only Ben for field
-- help and pointing the player at the grain elevator to sell - the Farmer's Market
-- is never mentioned. This extends that exact seam: right after his native farewell
-- we add a short Walter-voiced aside that names Marta, the market, and that it's a
-- second place to sell produce.
--
-- We deliberately keep it a *pointer*, not an explanation - Marta's firstMeet still
-- owns the empty-shelves reveal. "Tell her I sent you" sets up a possible future
-- firstMeet variant gated on the walterMentionedMarket flag.
--
-- Walter's lines are sealed inside dataS2.gar and cannot be edited; instead we hook
-- the GuidedTour Lua class (finish = completed, cancel = skipped) and draw our own
-- bottom-panel speech. See journals/walter-guided-tour.md.

VLWalterIntro = {}

local FLAG = "walterMentionedMarket"

-- Shown one box at a time in our bottom panel. Speaker is a raw string ("Walter") -
-- he isn't a VL villager, and showSpeechBox accepts a plain speaker label.
local LINES = {
    "Oh - one more thing before I let you get to it. Ben'll see you right in the fields, but he's not the only friendly face in Riverbend.",
    "There's a farmers market in town, and Marta runs it. Good woman, salt of the earth. You can sell your produce right to her stand - same as the grain elevator, just closer to home.",
    "Truth is, her shelves could use the help. Go introduce yourself when you get the chance, and tell her I sent you. She'll look after you.",
}

local SPEAKER = "Walter"

-- Show line i, chaining to the next on Continue. When the lines run out, release
-- the movement lock so the player can walk again.
local function showLine(dialog, i)
    if dialog == nil then return end
    local line = LINES[i]
    if line == nil then
        dialog:unlockMovement()
        return
    end
    dialog:showSpeechBox(SPEAKER, line, function()
        showLine(dialog, i + 1)
    end, { inlineSpeaker = true })
end

-- Play the sequence. force=true bypasses the once-only flag (console test command).
-- Returns true if it started. Movement is frozen for the duration, matching the
-- way the base-game tour locks the player while Walter is talking.
function VLWalterIntro.play(force)
    if g_valleyLife == nil or g_valleyLife.dialog == nil then return false end
    if not force and g_valleyLife:getFlag(FLAG) then return false end
    g_valleyLife:setFlag(FLAG, true)
    local dialog = g_valleyLife.dialog
    dialog:lockMovement()
    showLine(dialog, 1)
    return true
end

-- Defer one frame so we don't collide with the guided tour's own end-of-tour UI
-- teardown (centered messages, conversation close), then play once.
local function playDeferred(reason)
    if g_valleyLife == nil then return end
    if g_valleyLife:getFlag(FLAG) then return end
    local function go()
        if g_valleyLife == nil or g_valleyLife:getFlag(FLAG) then return end
        print("[ValleyLife] Walter market intro (" .. tostring(reason) .. ").")
        VLWalterIntro.play(false)
    end
    if g_currentMission ~= nil and g_currentMission.addUpdateable ~= nil then
        local u = {}
        function u:update(dt)
            g_currentMission:removeUpdateable(self)
            go()
        end
        g_currentMission:addUpdateable(u)
    else
        go()
    end
end

-- Hook the guided tour endpoints. finish = tour completed; cancel = tour skipped.
-- Both leave the player in free play having heard only about Ben.
if GuidedTour ~= nil then
    if GuidedTour.finish ~= nil then
        GuidedTour.finish = Utils.appendedFunction(GuidedTour.finish, function()
            playDeferred("tour finished")
        end)
        print("[ValleyLife] Hooked GuidedTour.finish.")
    end
    if GuidedTour.cancel ~= nil then
        GuidedTour.cancel = Utils.appendedFunction(GuidedTour.cancel, function()
            playDeferred("tour skipped")
        end)
        print("[ValleyLife] Hooked GuidedTour.cancel.")
    end
else
    print("[ValleyLife] GuidedTour absent; Walter market intro hooks skipped.")
end
