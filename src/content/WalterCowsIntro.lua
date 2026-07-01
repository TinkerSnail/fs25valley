-- Animal-husbandry handoff — the one-time "your cows / go see Katie" beat, fired by proximity to the pen.
--
-- The base game introduces husbandry as a menu referral; the starting farm ships 3 Angus in the little
-- barn but nobody frames it. The first time the player comes up to the cow pen, Walter (in voice) names
-- the inherited herd, admits animals were never his craft (wood was), and points them to Katie. ADDITIVE;
-- the base conversation + Katie's tutorial stay intact. Fires ONCE per save (walterCowsHandoff flag).
--
-- Pairs with his daily `checkingCows` route (he strolls out to look the herd over); this is the player's
-- side — walk up to the cows and get the handoff. Ticked from VLNPCSystem:update.

VLWalterCowsIntro = {}

local FLAG    = "walterCowsHandoff"
local SPEAKER = "Walter"

local LINES = {
    "Those cattle here came with the land, three head of Angus. Beef stock, not milkers, so don't go looking for a pail. They're yours now.",
    "I'll be straight with you: I learned the wood, never quite learned the animals. Kept 'em more out of habit than know-how.",
    "Katie's your woman for that. Animal farmer, down the way, knows livestock better than I ever did. Go on and introduce yourself, and tell her I sent you.",
}

-- Resolve the cow barn/pen by configFileName + nearest to its preplaced point, and fire when the player
-- gets within RANGE of it. RANGE pulled in to ~10m so it triggers AT the pen, not way out across the yard.
local BARN_CONFIG = "cowBarnSmall"
local BARN_NEAR   = { x = -670.8, z = 136.0 }
local RANGE       = 10.0

local _barn = nil  -- cached {x, z}

local function playerWorldPos()
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    if player == nil or player.rootNode == nil then return nil end
    local ok, px, py, pz = pcall(getWorldTranslation, player.rootNode)
    if not ok or type(px) ~= "number" then return nil end
    return px, py, pz
end

local function resolveBarn()
    if _barn ~= nil then return _barn.x, _barn.z end
    local ps = g_currentMission and g_currentMission.placeableSystem
               and g_currentMission.placeableSystem.placeables
    if ps == nil then return nil end
    local best, bestD
    for _, p in ipairs(ps) do
        local cf = p.configFileName
        if cf ~= nil and cf:find(BARN_CONFIG, 1, true) and p.rootNode ~= nil then
            local ok, x, _, z = pcall(getWorldTranslation, p.rootNode)
            if ok and type(x) == "number" then
                local d = (x - BARN_NEAR.x) ^ 2 + (z - BARN_NEAR.z) ^ 2
                if bestD == nil or d < bestD then best, bestD = { x = x, z = z }, d end
            end
        end
    end
    if best == nil then return nil end
    _barn = best
    return best.x, best.z
end

-- Show line i, chaining to the next on Continue; release the movement lock at the end.
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

-- Play the handoff. force=true bypasses the once-only flag (console test). Movement is frozen for the
-- duration, matching the base-game tour / the market intro.
function VLWalterCowsIntro.play(force)
    if g_valleyLife == nil or g_valleyLife.dialog == nil then return false end
    if not force and g_valleyLife:getFlag(FLAG) then return false end
    g_valleyLife:setFlag(FLAG, true)
    local dialog = g_valleyLife.dialog
    dialog:lockMovement()
    print("[ValleyLife] Walter cow/husbandry handoff" .. (force and " (forced)." or "."))
    showLine(dialog, 1)
    return true
end

-- Per-frame proximity trigger (from VLNPCSystem:update). Fires once when the player reaches the pen;
-- guarded so it never interrupts an active conversation / heart event / another speech box.
function VLWalterCowsIntro.update(dt)
    local vl = g_valleyLife
    if vl == nil or vl:getFlag(FLAG) then return end
    local dialog = vl.dialog
    if dialog == nil or dialog.speech ~= nil then return end
    if vl.sequencer ~= nil and vl.sequencer.active then return end
    local bx, bz = resolveBarn()
    if bx == nil then return end
    local px, _, pz = playerWorldPos()
    if px == nil then return end
    local dx, dz = px - bx, pz - bz
    if (dx * dx + dz * dz) <= (RANGE * RANGE) then
        VLWalterCowsIntro.play(false)
    end
end
