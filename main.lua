-- ValleyLife: social and narrative layer for FS25.
-- Entry point - sources all modules in dependency order, hooks mission lifecycle.

local modDir = g_currentModDirectory

-- 1. Utilities (no dependencies)
source(modDir .. "src/utils/VectorHelper.lua")
source(modDir .. "src/utils/TimeHelper.lua")
source(modDir .. "src/utils/BirthdayHelper.lua")
source(modDir .. "src/utils/OutfitCalendar.lua")
source(modDir .. "src/utils/WorkLoopHelper.lua")

-- 2. Config (depends on nothing)
source(modDir .. "src/NPCConfig.lua")

-- 3. Core subsystems (depend on config + utils)
source(modDir .. "src/scripts/NPCRelationshipManager.lua")
source(modDir .. "src/scripts/NPCEntity.lua")
source(modDir .. "src/scripts/NPCScheduler.lua")
source(modDir .. "src/scripts/NPCEventSequencer.lua")
source(modDir .. "src/scripts/NPCCasualDialogue.lua")
source(modDir .. "src/scripts/WalterWalker.lua")

-- 4. GUI (depends on subsystems)
source(modDir .. "src/gui/NPCDialog.lua")

-- 5. Main coordinator (references all subsystems)
source(modDir .. "src/NPCSystem.lua")

-- 6. Authored content - registers heart events into the sequencer at load time.
source(modDir .. "src/content/Elara.lua")
source(modDir .. "src/content/Kenji.lua")
source(modDir .. "src/content/Marta.lua")

-- Post-tour beat: hooks GuidedTour.finish/cancel to introduce Marta + the market.
source(modDir .. "src/content/WalterIntro.lua")

-- Mission lifecycle

local function isCareerMission()
    return g_currentMission ~= nil
        and (FSCareerMission == nil or g_currentMission:isa(FSCareerMission))
end

local function vlApplyWalterPosition()
    if g_valleyLife and g_valleyLife.walterWalker then
        pcall(function() g_valleyLife.walterWalker:applyPosition() end)
    end
end

local function onMissionLoaded(mission, node)
    if g_valleyLife ~= nil then return end   -- guard against double-init
    if not isCareerMission() then return end

    g_valleyLife = VLNPCSystem.new()
    g_valleyLife:initialize()

    -- Load saved state if a savegame exists (new games have no savegameDirectory yet).
    g_valleyLife:loadFromFile(g_currentMission.missionInfo)

    -- Hook g_npcManager after mission load so we run after HumanGraphicsComponent.
    -- This is later than our FSBaseMission.draw hook, so the game can't append after us.
    if g_npcManager then
        if type(g_npcManager.update) == "function" then
            g_npcManager.update = Utils.appendedFunction(g_npcManager.update, function(mgr, dt)
                vlApplyWalterPosition()
            end)
            print("[ValleyLife] Hooked g_npcManager.update for WalterWalker.")
        end
        if type(g_npcManager.draw) == "function" then
            g_npcManager.draw = Utils.appendedFunction(g_npcManager.draw, function(mgr)
                vlApplyWalterPosition()
            end)
            print("[ValleyLife] Hooked g_npcManager.draw for WalterWalker.")
        end
    end
end

local function onMissionUpdate(mission, dt)
    if g_valleyLife then
        local ok, err = pcall(g_valleyLife.update, g_valleyLife, dt)
        if not ok then
            print("[ValleyLife] ERROR in update: " .. tostring(err))
        end
    end
end

local function onMissionUnload(mission)
    if g_valleyLife then
        g_valleyLife:delete()
        g_valleyLife = nil
    end
end

-- Renders the bottom-screen reply selector on top of the HUD each frame.
local function onMissionDraw(mission)
    if g_valleyLife and g_valleyLife.dialog then
        g_valleyLife.dialog:draw()
    end
    -- Apply Walter's position in draw phase so we run after all NPC update logic.
    if g_valleyLife and g_valleyLife.walterWalker then
        pcall(function() g_valleyLife.walterWalker:applyPosition() end)
    end
end

-- Initialization hook: Mission00.loadMission00Finished is the proven entry point
-- (fires once the map/terrain is ready), with g_currentMission as a fallback.
if Mission00 ~= nil and Mission00.loadMission00Finished ~= nil then
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, onMissionLoaded)
    print("[ValleyLife] Hooked Mission00.loadMission00Finished.")
else
    print("[ValleyLife] WARNING: Mission00.loadMission00Finished not found.")
end

-- Per-frame update lives on FSBaseMission.update (not Mission00.update).
if FSBaseMission ~= nil and FSBaseMission.update ~= nil then
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, onMissionUpdate)
    print("[ValleyLife] Hooked FSBaseMission.update.")
else
    print("[ValleyLife] WARNING: FSBaseMission.update not found.")
end

if FSBaseMission ~= nil and FSBaseMission.delete ~= nil then
    FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, onMissionUnload)
end

-- Draw hook for the bottom-screen reply selector (renders on top of the HUD).
if FSBaseMission ~= nil and FSBaseMission.draw ~= nil then
    FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, onMissionDraw)
    print("[ValleyLife] Hooked FSBaseMission.draw.")
end

-- Console command: prints the player's current world position, formatted ready
-- to paste into VLConfig.VILLAGER_SPAWNS. Stand where a villager should be and
-- type "vlPos" in the developer console (~).
-- Console command target. FS25 runs each mod in its own environment, so a bare
-- top-level function is NOT a true _G global and addConsoleCommand(..., nil)
-- can't find it. Registering against an explicit target object makes the engine
-- call target:method() directly, which works reliably.
VLConsole = {}

function VLConsole:printPlayerPos()
    -- Collect every plausible player node source; FS25 builds vary on whether the
    -- foot player lives on g_localPlayer, g_currentMission.player, or a graphics
    -- component, so try them all and use the first that yields a valid node.
    local candidates = {}
    local p1 = g_localPlayer
    local p2 = g_currentMission ~= nil and g_currentMission.player or nil
    for _, p in ipairs({ p1, p2 }) do
        if p ~= nil then
            candidates[#candidates + 1] = p.rootNode
            candidates[#candidates + 1] = p.graphicsComponent and p.graphicsComponent.graphicsRootNode or nil
            candidates[#candidates + 1] = p.positionNode
        end
    end

    local node
    for _, n in ipairs(candidates) do
        if n ~= nil and n ~= 0 and entityExists(n) then node = n; break end
    end

    if node == nil then
        local msg = string.format(
            "[ValleyLife] vlPos: no player node (g_localPlayer=%s, mission.player=%s).",
            tostring(p1), tostring(p2))
        print(msg)
        return msg
    end

    local x, y, z = getWorldTranslation(node)
    local _, ry, _ = getWorldRotation(node)
    local msg = string.format(
        "[ValleyLife] vlPos -> { x = %.2f, y = %.2f, z = %.2f, ry = %.4f }",
        x, y, z, ry)
    print(msg)
    return msg
end

-- vlRel <npcId> <value>: set a villager's relationship directly so heart-event
-- thresholds (20/40/60/80) can be reached for testing. Then walk up and press R.
function VLConsole:setRelationship(npcId, value)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    if npcId == nil then return "[ValleyLife] Usage: vlRel <npcId> <value>  (e.g. vlRel elara 20)" end
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, kenji, marta."
    end
    local v = math.max(VLConfig.REL_MIN, math.min(VLConfig.REL_MAX, tonumber(value) or 0))
    g_valleyLife.relationships.values[npcId] = v
    local msg = string.format("[ValleyLife] %s relationship set to %d.", npcId, v)
    print(msg)
    return msg
end

-- vlEvent <npcId>: force-start the next uncompleted heart event for a villager,
-- bypassing proximity and relationship. Fastest way to test authored dialogue.
function VLConsole:triggerEvent(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    npcId = npcId and string.lower(tostring(npcId)) or "elara"
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, kenji, marta."
    end
    local ok, eventId = g_valleyLife.sequencer:forceTriggerNext(npcId)
    if ok then
        local msg = string.format("[ValleyLife] Started %s for %s.", eventId, npcId)
        print(msg)
        return msg
    end
    local msg = "[ValleyLife] No available event for " .. npcId .. " (all completed?). Try: vlReset " .. npcId
    print(msg)
    return msg
end

-- vlReset <npcId>: clear a villager's completed heart events, reset their
-- relationship to 0, and abort any in-progress scene, so the conversation/events
-- can be replayed from the top during testing.
function VLConsole:resetNpc(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    npcId = npcId or "elara"
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, kenji, marta."
    end
    local cleared = g_valleyLife.sequencer:resetNPC(npcId)
    g_valleyLife.relationships.values[npcId] = 0
    g_valleyLife.casualDialogue:resetNPC(npcId)
    local npc = g_valleyLife:getNPC(npcId)
    if npc then npc.isTalking = false end
    local msg = string.format("[ValleyLife] Reset %s: cleared %d event(s), relationship -> 0.",
        npcId, cleared)
    print(msg)
    return msg
end

-- vlNear: report the player position, nearest villager, and distance, so we can
-- verify the Press-R proximity detection.
function VLConsole:printNearest()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local px, py, pz = g_valleyLife:getPlayerPosition()
    local nearest, dist = g_valleyLife:getNearestNPC()
    local msg = string.format(
        "[ValleyLife] player=(%s,%s,%s) nearest=%s dist=%.2f (interact<=%.1f)",
        tostring(px and string.format("%.1f", px)),
        tostring(py and string.format("%.1f", py)),
        tostring(pz and string.format("%.1f", pz)),
        nearest and nearest.name or "none", dist or -1, VLConfig.INTERACT_DISTANCE)
    print(msg)
    return msg
end

-- vlDlg: probe which native dialog/choice widgets this build exposes, so we can
-- reuse the same one Walter's "anything I can help with?" menu uses instead of our
-- hand-drawn reply box. Reports each candidate global, whether it's a table/class,
-- and which show-style methods it carries.
function VLConsole:probeDialogs()
    local candidates = {
        -- multi-option / list pickers (what we actually want for choices)
        "MultiChoiceDialog", "SelectionDialog", "OptionDialog", "ListSelectionDialog",
        "AnswerDialog", "DialogElement", "MessageDialog", "RadioButtonDialog",
        -- known-good fallbacks already in use
        "InfoDialog", "YesNoDialog", "TextInputDialog",
        -- the helper / guided-tour systems that may own Walter's flow
        "GuidedTourMission", "HelpMenuMission", "TutorialMission",
    }
    local methods = { "show", "new", "createFromExistingGui", "setTexts", "setOptions",
                      "setMenuOptions", "setCallback", "setOptionTexts" }
    print("[ValleyLife] ---- dialog widget probe ----")
    for _, name in ipairs(candidates) do
        local g = _G[name]
        if g == nil then
            print(string.format("  %-22s : (absent)", name))
        else
            local found = {}
            for _, m in ipairs(methods) do
                if type(g) == "table" and type(g[m]) == "function" then
                    table.insert(found, m)
                end
            end
            print(string.format("  %-22s : %s  methods=[%s]",
                name, type(g), table.concat(found, ",")))
        end
    end
    -- Also report what g_gui can open by name.
    if g_gui ~= nil then
        local guiMethods = {}
        for _, m in ipairs({ "showDialog", "showInfoDialog", "showYesNoDialog",
                             "showSelectionDialog", "showOptionDialog", "showMessageDialog" }) do
            if type(g_gui[m]) == "function" then table.insert(guiMethods, m) end
        end
        print("  g_gui methods=[" .. table.concat(guiMethods, ",") .. "]")
    end
    print("[ValleyLife] ---- end probe (see above) ----")
    return "[ValleyLife] Dialog probe written to log/console."
end

-- vlGuidedTour: probe the GuidedTour class and active instance so we can find
-- the right method names to hook (finish, skip, cancel, etc.) for post-Walter
-- dialog injection.
function VLConsole:probeGuidedTour()
    if GuidedTour == nil then return "[ValleyLife] GuidedTour: (absent from _G)" end
    local classMethods = {}
    for k, v in pairs(GuidedTour) do
        if type(v) == "function" then classMethods[#classMethods + 1] = k end
    end
    table.sort(classMethods)
    print("[ValleyLife] GuidedTour class methods: " .. table.concat(classMethods, ", "))

    local inst = g_currentMission and g_currentMission.guidedTour
    print("[ValleyLife] g_currentMission.guidedTour = " .. tostring(inst))
    if inst ~= nil then
        local instMethods = {}
        for k, v in pairs(inst) do
            if type(v) == "function" then instMethods[#instMethods + 1] = k end
        end
        table.sort(instMethods)
        print("[ValleyLife] instance methods: " .. table.concat(instMethods, ", "))
        -- Also report any bool/string fields that look like state flags
        local fields = {}
        for k, v in pairs(inst) do
            local t = type(v)
            if t == "boolean" or t == "string" or t == "number" then
                fields[#fields + 1] = string.format("%s=%s", k, tostring(v))
            end
        end
        table.sort(fields)
        print("[ValleyLife] instance state: " .. table.concat(fields, ", "))
    end
    return "[ValleyLife] GuidedTour probe done — check log."
end

-- vlAnimClips: enumerate animation clips on a villager's character set.
-- Tries engine enumeration APIs first, then brute-forces a wide name list.
function VLConsole:dumpAnimClips(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = g_valleyLife.npcs[npcId or "marta"]
    if npc == nil then return "[ValleyLife] NPC not found." end
    local charSet = npc.animCharSet
    if charSet == nil or charSet == 0 then return "[ValleyLife] No animCharSet (model not loaded yet?)." end

    -- Try engine APIs that enumerate clips by index.
    local enumerated = false
    for _, numFn in ipairs({ "getNumAnimClips", "getNumOfClips", "getAnimNumClips" }) do
        if type(_G[numFn]) == "function" then
            local ok, n = pcall(_G[numFn], charSet)
            if ok and type(n) == "number" and n > 0 then
                print(string.format("[ValleyLife] %s(%s) = %d clips:", numFn, tostring(charSet), n))
                for nameFn, fn in pairs({ getAnimClipName = getAnimClipName, getClipName = getClipName }) do
                    if type(fn) == "function" then
                        for i = 0, n - 1 do
                            local ok2, name = pcall(fn, charSet, i)
                            if ok2 and name then
                                print(string.format("  [%d] %s", i, tostring(name)))
                            end
                        end
                        enumerated = true
                        break
                    end
                end
                if not enumerated then
                    print("[ValleyLife] Count found but no name getter available; trying brute-force.")
                end
                break
            end
        end
    end

    -- Try to enumerate all clips by index using engine APIs.
    print("[ValleyLife] Enumerating clips by index (getAnimClipName / getAnimClip):")
    local enumHits = 0
    for i = 0, 120 do
        for _, fn in ipairs({ getAnimClipName, getAnimClip }) do
            if type(fn) == "function" then
                local ok, result = pcall(fn, charSet, i)
                if ok and result ~= nil and result ~= "" and result ~= -1 then
                    print(string.format("  [%d] = %s", i, tostring(result)))
                    enumHits = enumHits + 1
                end
                break
            end
        end
    end
    if enumHits == 0 then print("  (getAnimClipName / getAnimClip not available or returned nothing)") end

    -- Also try the player character's charSet for comparison.
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    if player ~= nil and player.rootNode ~= nil and player.rootNode ~= 0 then
        local pCharSet = 0
        pcall(function()
            pCharSet = getAnimCharacterSet(player.rootNode)
            if pCharSet == 0 then
                local child = getChildAt(player.rootNode, 0)
                if child and child ~= 0 then pCharSet = getAnimCharacterSet(child) end
            end
        end)
        if pCharSet ~= 0 then
            print(string.format("[ValleyLife] Player charSet = %s (NPC charSet = %s)", tostring(pCharSet), tostring(charSet)))
            -- Probe the player charSet for walk clips
            local WALK_PROBE = {
                "walkSource","walk1Source","walk2Source","walkFemaleSource",
                "walkForwardSource","walkForward1Source","walkForward2Source",
                "walkForwardFemaleSource","walkForward1FemaleSource",
                "walk1MSource","walk1FSource","walkForward1MSource","walkForward1FSource",
                "moveForwardSource","moveForward1Source","moveSource",
                "runSource","run1Source","runForwardSource","runForward1Source",
                "locomotionSource","locoWalkSource",
            }
            print("[ValleyLife] Walk probe on PLAYER charSet:")
            local pHits = 0
            for _, name in ipairs(WALK_PROBE) do
                local ok, idx = pcall(getAnimClipIndex, pCharSet, name)
                if ok and type(idx) == "number" and idx >= 0 then
                    print(string.format("  HIT  [%d] %s", idx, name))
                    pHits = pHits + 1
                end
            end
            if pHits == 0 then print("  (no hits on player charSet either)") end
            -- Also try index enumeration on player charSet
            print("[ValleyLife] Player charSet index enum:")
            local pEnumHits = 0
            for i = 0, 80 do
                for _, fn in ipairs({ getAnimClipName, getAnimClip }) do
                    if type(fn) == "function" then
                        local ok, result = pcall(fn, pCharSet, i)
                        if ok and result ~= nil and result ~= "" and result ~= -1 then
                            print(string.format("  [%d] = %s", i, tostring(result)))
                            pEnumHits = pEnumHits + 1
                        end
                        break
                    end
                end
            end
            if pEnumHits == 0 then print("  (no index enum available on player charSet)") end
        else
            print("[ValleyLife] Could not resolve player charSet.")
        end
    end

    return "[ValleyLife] Clip enum done — check log."
end

-- vlWalk <npcId> [loopNameOrIndex]: force-start a walk loop (bypasses the timer).
-- `loopNameOrIndex` may be a loop name ("morningRounds"), an index ("2"), or be
-- omitted (= the loop active at the current hour). Works for the mod NPCs (Marta)
-- and for Walter, who is the base-game GRANDPA driven by WalterWalker.
function VLConsole:forceWalk(npcId, loopSelector)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    if npcId == nil then return "[ValleyLife] Usage: vlWalk <npcId> [loopName|index]" end

    -- Walter lives in walterWalker, not g_valleyLife.npcs.
    if npcId == "grandpa" or npcId == "walter" then
        local ww = g_valleyLife.walterWalker
        if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
        local which = ww:forceWalkLoop(loopSelector)
        if which == nil then
            return string.format("[ValleyLife] Walter has no loop '%s'. Loops: %s",
                tostring(loopSelector), table.concat(ww:loopNames(), ", "))
        end
        return string.format("[ValleyLife] Walk loop '%s' started for Walter.", tostring(which))
    end

    local npc = g_valleyLife.npcs[npcId]
    if npc == nil then return string.format("[ValleyLife] Unknown NPC '%s'.", tostring(npcId)) end
    if not npc._workLoops then return string.format("[ValleyLife] '%s' has no walk loops.", npcId) end
    local which = npc:forceWalkLoop(loopSelector)
    if which == nil then
        return string.format("[ValleyLife] '%s' has no loop '%s'. Loops: %s",
            npcId, tostring(loopSelector), table.concat(WorkLoopHelper.names(npc._workLoops), ", "))
    end
    return string.format("[ValleyLife] Walk loop '%s' started for '%s'.", tostring(which), npcId)
end

-- vlWalterYOffset <meters>: live-tune the vertical offset subtracted from Walter's
-- driven height (positive lowers him). Fixes floating/sinking while we drive him.
-- Bake the value you settle on into VLConfig.WALTER_WALK.yOffset.
function VLConsole:setWalterYOffset(value)
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    local ww = g_valleyLife.walterWalker
    local n = tonumber(value)
    if n == nil then
        return string.format("[ValleyLife] Usage: vlWalterYOffset <meters>  (current=%.3f)", ww._yOffset or 0)
    end
    ww._yOffset = n
    return string.format("[ValleyLife] Walter Y offset = %.3f m (positive = lower). Re-run vlWalk grandpa to see it.", n)
end

-- vlWalterStairLift <value>: live-tune the convex bow lift added on sloped segments (e.g. stairs).
-- A parabola peaking at mid-segment lifts his feet over stair-tread noses without changing
-- arrival/departure heights. Bake the settled value into VLConfig.WALTER_WALK.stairLift.
function VLConsole:setWalterStairLift(value)
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    local ww = g_valleyLife.walterWalker
    local n = tonumber(value)
    if n == nil then
        return string.format("[ValleyLife] Usage: vlWalterStairLift <meters>  (current=%.3f)", ww._stairLift or 0)
    end
    ww._stairLift = n
    return string.format("[ValleyLife] Walter stairLift = %.3f m. Re-run vlWalk grandpa to see it.", n)
end

-- vlWalterShow: bring Walter back if he has "stepped inside" (hideOnEnd at the door). For testing
-- the disappear without relaunching. vlWalterHide hides him on demand to test the visibility toggle.
function VLConsole:walterShow()
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    g_valleyLife.walterWalker:_reveal()
    return "[ValleyLife] Walter revealed."
end

function VLConsole:walterHide()
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    g_valleyLife.walterWalker:_hide()
    return "[ValleyLife] Walter hidden."
end

-- vlWalterDoor <dir>: TEST Walter's own woodshop-door control (resolve + setDirection). 1=open/-1=close.
function VLConsole:walterDoor(dir)
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    local ok = g_valleyLife.walterWalker:_setWoodshopDoor(tonumber(dir) or 1)
    return ok and "[ValleyLife] Walter woodshop door triggered." or "[ValleyLife] door not resolved."
end

-- vlWalterLights <1=on|0=off>: TEST Walter's own woodshop-lights control.
function VLConsole:walterLights(on)
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    local ok = g_valleyLife.walterWalker:_setWoodshopLights(tonumber(on) == 1)
    return ok and "[ValleyLife] Walter woodshop lights triggered." or "[ValleyLife] lights not resolved."
end

-- vlWalterMorning: trigger the morning departure now (reveal at the door, walk down to home) for
-- testing without waiting for the 5am wake.
function VLConsole:walterMorning()
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    g_valleyLife.walterWalker:_startMorningDeparture(VLConfig.WALTER_WALK)
    return "[ValleyLife] Walter morning departure triggered."
end

-- vlDoorTest <dir> [x] [z]: TEST. Set the woodshop doors' animation direction (1=open, -1=close,
-- 0=stop) directly and let the AnimatedObjects spec animate them. Confirms the open mechanism before
-- wiring it into Walter. Acts on BOTH doorRotate01/02.
-- vlDoorTest <dir> [which]: dir 1=open/-1=close/0=stop; which = door index 1 or 2 (omit = both).
-- Logs each door's saveId + world position so we can identify which side is Walter's entry.
function VLConsole:doorTest(dir, which)
    local d  = tonumber(dir) or 1
    local wi = tonumber(which)
    local cx, cz = -778.6, 106.7
    local mission = g_currentMission
    local placeables = mission and mission.placeableSystem and mission.placeableSystem.placeables
    if type(placeables) ~= "table" then return "[ValleyLife] no placeables." end
    local best, bestd
    for _, p in ipairs(placeables) do
        local px, pz
        pcall(function() local a, _, c = getWorldTranslation(p.rootNode); px, pz = a, c end)
        if px then local dd = (px-cx)^2 + (pz-cz)^2; if bestd == nil or dd < bestd then best, bestd = p, dd end end
    end
    local aos
    pcall(function() aos = best.spec_animatedObjects and best.spec_animatedObjects.animatedObjects end)
    if aos == nil then pcall(function() aos = best.animatedObjects end) end
    if type(aos) ~= "table" then return "[ValleyLife] no animated objects." end
    for i, ao in ipairs(aos) do
        if wi == nil or wi == i then
            local how = "none"
            if type(ao.setDirection) == "function" then
                if pcall(function() ao:setDirection(d) end) then how = "setDirection" end
            end
            if how == "none" and type(ao.setAnimTime) == "function" then
                if pcall(function() ao:setAnimTime(d > 0 and 1 or 0, true) end) then how = "setAnimTime" end
            end
            if how == "none" and type(ao.animation) == "table" then
                ao.animation.direction = d; ao.isMoving = (d ~= 0); how = "field"
            end
            local nx, nz
            pcall(function() local a, _, c = getWorldTranslation(ao.nodeId); nx, nz = a, c end)
            print(string.format("[ValleyLife][DoorT] AO[%d] saveId=%s via=%s pos=(%.1f,%.1f)",
                i, tostring(ao.saveId), how, nx or 0, nz or 0))
        end
    end
    return string.format("[ValleyLife] door test dir=%d which=%s fired.", d, tostring(wi or "both"))
end

-- vlLightTest <1=on|0=off> [x] [z]: TEST turning the woodshop lights (group 1) on/off in code.
-- Tries placeable:setLightState, then setLightsState, then a manual isActive + updateLightState.
function VLConsole:lightTest(on, x, z)
    local state = tonumber(on) == 1
    local cx, cz = tonumber(x) or -778.6, tonumber(z) or 106.7
    local mission = g_currentMission
    local placeables = mission and mission.placeableSystem and mission.placeableSystem.placeables
    if type(placeables) ~= "table" then return "[ValleyLife] no placeables." end
    local best, bestd
    for _, p in ipairs(placeables) do
        local px, pz
        pcall(function() local a, _, c = getWorldTranslation(p.rootNode); px, pz = a, c end)
        if px then local d = (px-cx)^2 + (pz-cz)^2; if bestd == nil or d < bestd then best, bestd = p, d end end
    end
    local sp = best and best.spec_lights
    local group = sp and sp.groups and sp.groups[1]
    if group == nil then return "[ValleyLife] no light group." end
    local how = "none"
    if type(best.setLightState) == "function" then
        if pcall(function() best:setLightState(1, state, true) end) then how = "setLightState" end
    end
    if how == "none" and type(best.setLightsState) == "function" then
        if pcall(function() best:setLightsState(1, state, true) end) then how = "setLightsState" end
    end
    if how == "none" then
        pcall(function() group.isActive = state end)
        if type(best.updateLightState) == "function" then pcall(function() best:updateLightState(1) end) end
        if type(best.lightSetupChanged) == "function" then pcall(function() best:lightSetupChanged() end) end
        how = "manual"
    end
    print(string.format("[ValleyLife][LightT] state=%s via=%s isActive=%s", tostring(state), how, tostring(group.isActive)))
    return string.format("[ValleyLife] light test on=%s via=%s.", tostring(state), how)
end

-- vlSkipPause: end the current mid-route pause immediately and send the NPC to their next waypoint.
function VLConsole:skipPause(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    -- Walter (GRANDPA) is driven by WalterWalker, not g_valleyLife.npcs.
    if npcId == "grandpa" or npcId == "walter" then
        local ww = g_valleyLife.walterWalker
        if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
        return ww:skipPause() and "[ValleyLife] Walter pause skipped."
            or "[ValleyLife] Walter is not pausing right now."
    end
    local npc = g_valleyLife.npcs[npcId]
    if npc == nil then return string.format("[ValleyLife] Unknown NPC '%s'.", tostring(npcId)) end
    local walk = npc._walk
    if walk == nil then return string.format("[ValleyLife] '%s' is not on a walk loop right now.", npcId) end
    if walk.state ~= "pausing" then
        return string.format("[ValleyLife] '%s' is not pausing (state = %s).", npcId, tostring(walk.state))
    end
    walk.state = "walking"
    npc:_onWalkStart()
    return string.format("[ValleyLife] '%s' is now walking to waypoint %d.", npcId, tostring(walk.targetIdx))
end

-- vlWalterIntro: force-play Walter's post-tour market introduction (bypasses the
-- once-only walterMentionedMarket flag), so we can test the lines without redoing
-- the whole guided tour.
function VLConsole:playWalterIntro()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    if VLWalterIntro == nil then return "[ValleyLife] WalterIntro unavailable." end
    VLWalterIntro.play(true)
    return "[ValleyLife] Played Walter market intro (forced)."
end

-- vlStyle: enumerate the base-game character style configs (hair, beard, face,
-- skin, clothing, ...) with how many items/colors each exposes and the default
-- selected index. Use this to find which config controls skin/age and which item
-- indices read "older", then plug those into VILLAGERS[*].appearance.
function VLConsole:dumpStyles()
    if PlayerStyle == nil or PlayerStyle.new == nil then
        return "[ValleyLife] PlayerStyle API unavailable."
    end
    local function countItems(cfg)
        for _, g in ipairs({ "getNumOfItems", "getNumItems", "getItemCount" }) do
            if type(cfg[g]) == "function" then
                local ok, v = pcall(cfg[g], cfg)
                if ok and type(v) == "number" then return v end
            end
        end
        if type(cfg.items) == "table" then return #cfg.items end
        return -1
    end
    local function countColors(cfg)
        for _, g in ipairs({ "getNumColors", "getNumOfColors", "getColorCount" }) do
            if type(cfg[g]) == "function" then
                local ok, v = pcall(cfg[g], cfg)
                if ok and type(v) == "number" then return v end
            end
        end
        if type(cfg.getColors) == "function" then
            local ok, v = pcall(cfg.getColors, cfg)
            if ok and type(v) == "table" then return #v end
        end
        if type(cfg.colors) == "table" then return #cfg.colors end
        return -1
    end
    local sets = {
        { "MALE",   "dataS/character/playerM/playerM.xml" },
        { "FEMALE", "dataS/character/playerF/playerF.xml" },
    }
    print("[ValleyLife] ---- character style configs ----")
    for _, set in ipairs(sets) do
        local label, xml = set[1], set[2]
        local style = PlayerStyle.new()
        pcall(function()
            if style.loadConfigurationXML then style:loadConfigurationXML(xml) end
        end)
        print(string.format("  [%s] %s", label, xml))
        if type(style.configs) == "table" then
            local names = {}
            for name, _ in pairs(style.configs) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do
                local cfg = style.configs[name]
                local sel = type(cfg) == "table" and cfg.selectedItemIndex or "?"
                print(string.format("    %-18s items=%-3s colors=%-3s selected=%s",
                    name, tostring(countItems(cfg)), tostring(countColors(cfg)), tostring(sel)))
            end
        else
            print("    (no configs table)")
        end
    end
    print("[ValleyLife] ---- end style dump ----")
    return "[ValleyLife] Style dump written to log/console."
end

local VL_NPC_IDS = "elara, kenji, marta"

local function styleConfigItemCount(cfg)
    if type(cfg) ~= "table" then return 0 end
    for _, g in ipairs({ "getNumOfItems", "getNumItems", "getItemCount" }) do
        if type(cfg[g]) == "function" then
            local ok, v = pcall(cfg[g], cfg)
            if ok and type(v) == "number" then return v end
        end
    end
    if type(cfg.items) == "table" then return #cfg.items end
    return 0
end

local function getNpcStyleConfig(npc, configName)
    if type(npc.buildPreviewStyle) ~= "function" then return nil end
    local style = npc:buildPreviewStyle()
    return style and style.configs and style.configs[configName]
end

function VLConsole:resolveNpc(npcId, usage)
    if g_valleyLife == nil then return nil, "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return usage or string.format("[ValleyLife] Unknown villager. Try: %s.", VL_NPC_IDS)
    end
    return npc
end

function VLConsole:listStyleConfig(npcId, configName, listCmd, setCmd)
    local usage = string.format("[ValleyLife] Usage: %s <npcId>  (npcId: %s)", listCmd, VL_NPC_IDS)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local cfg = style and style.configs and style.configs[configName]
    if type(cfg) ~= "table" or type(cfg.items) ~= "table" then
        return string.format("[ValleyLife] No %s config.", configName)
    end
    local itemCount = #cfg.items
    if itemCount == 0 then
        print(string.format("[ValleyLife] ---- %s (0 items) ----", configName))
        if configName == "facegear" then
            print("[ValleyLife] Base FS25 has an empty facegear slot (no socks/masks in playerF/playerM.xml).")
            print("[ValleyLife] Use vlFootwears / vlShoe for shoes; there is no separate sock layer.")
        else
            print("[ValleyLife] This slot has no catalog items for this character rig.")
        end
        return string.format("[ValleyLife] %s: %s has 0 items.", npcId, configName)
    end
    print(string.format("[ValleyLife] ---- %s (%d items) ----", configName, itemCount))
    for i = 1, math.min(itemCount, 40) do
        local item = cfg.items[i]
        if type(item) == "table" then
            print(string.format("  %2d : %s", i, tostring(item.name or "?")))
        end
    end
    if itemCount > 40 then
        print(string.format("  ... (%d more)", itemCount - 40))
    end
    setCmd = setCmd or listCmd:gsub("s$", "")
    print(string.format("[ValleyLife] ---- use %s %s <index>; %sColor for swatch ----",
        setCmd, tostring(npcId), setCmd))
    return string.format("[ValleyLife] Listed %s for %s.", configName, npcId)
end

local function itemNameLooksLikeSock(item)
    if type(item) ~= "table" then return false end
    local n = string.lower(tostring(item.name or ""))
    return string.find(n, "sock", 1, true) ~= nil
        or string.find(n, "stocking", 1, true) ~= nil
        or string.find(n, "ankle", 1, true) ~= nil
end

function VLConsole:listFootwear(npcId, mode)
    local listCmd = mode == "shoe" and "vlShoes" or (mode == "sock" and "vlSocks" or "vlFootwears")
    local usage = string.format("[ValleyLife] Usage: %s <npcId>  (npcId: %s)", listCmd, VL_NPC_IDS)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local cfg = style and style.configs and style.configs.footwear
    if type(cfg) ~= "table" or type(cfg.items) ~= "table" then
        return "[ValleyLife] No footwear config."
    end
    local label = mode == "shoe" and "footwear (shoes)" or (mode == "sock" and "footwear (socks)" or "footwear (all)")
    print(string.format("[ValleyLife] ---- %s (%d items) ----", label, #cfg.items))
    local shown = 0
    for i = 1, #cfg.items do
        local item = cfg.items[i]
        if type(item) == "table" then
            local isSock = itemNameLooksLikeSock(item)
            if mode == "all" or (mode == "sock" and isSock) or (mode == "shoe" and not isSock) then
                shown = shown + 1
                if shown <= 40 then
                    print(string.format("  %2d : %s%s", i, tostring(item.name or "?"),
                        isSock and " (sock)" or ""))
                end
            end
        end
    end
    if shown > 40 then
        print(string.format("  ... (%d more)", shown - 40))
    end
    if mode == "sock" then
        local fg = style.configs and style.configs.facegear
        if type(fg) == "table" and type(fg.items) == "table" and #fg.items > 0 then
            print(string.format("[ValleyLife] ---- facegear (%d items, may include socks) ----", #fg.items))
            for i = 1, math.min(#fg.items, 20) do
                local item = fg.items[i]
                if type(item) == "table" then
                    print(string.format("  %2d : %s", i, tostring(item.name or "?")))
                end
            end
            print("[ValleyLife] ---- try vlFacegear for facegear slot; vlSock for footwear sock names ----")
        end
        if shown == 0 then
            print("[ValleyLife] No sock-named footwear found - run vlFootwears for the full list.")
        end
    end
    if mode == "shoe" then
        print(string.format("[ValleyLife] ---- use vlShoe %s <index>; vlShoeColor for swatch ----", npcId))
    elseif mode == "sock" then
        print(string.format("[ValleyLife] ---- use vlSock %s <index>; vlSockColor for swatch ----", npcId))
    else
        print(string.format("[ValleyLife] ---- use vlShoe or vlSock %s <index> ----", npcId))
    end
    return string.format("[ValleyLife] Listed footwear for %s.", npcId)
end

function VLConsole:sockUsesFacegear(npc)
    if type(npc.buildPreviewStyle) ~= "function" then return false end
    local style = npc:buildPreviewStyle()
    local fg = style and style.configs and style.configs.facegear
    return type(fg) == "table" and type(fg.items) == "table" and #fg.items > 0
end

function VLConsole:patchAppearanceLayer(npc, configName, patch)
    if type(npc.setAppearanceLayer) == "function" then
        npc:setAppearanceLayer(configName, patch)
    else
        npc.appearance = npc.appearance or {}
        npc.appearance[configName] = npc.appearance[configName] or {}
        for k, v in pairs(patch) do npc.appearance[configName][k] = v end
    end
end

function VLConsole:setStyleConfigItem(npcId, configName, item, setCmd)
    local usage = string.format("[ValleyLife] Usage: %s <npcId> <index>  (0 = none)", setCmd)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    local idx = tonumber(item)
    if idx == nil then
        return string.format("[ValleyLife] Usage: %s %s <index>", setCmd, tostring(npcId))
    end
    if idx > 0 then
        local cfg = getNpcStyleConfig(npc, configName)
        local itemCount = styleConfigItemCount(cfg)
        if itemCount == 0 then
            local hint = configName == "facegear"
                and " Base FS25 facegear is empty - use vlShoe/vlFootwears instead."
                or ""
            local msg = string.format(
                "[ValleyLife] %s: %s has 0 items; index %d ignored.%s",
                tostring(npcId), configName, idx, hint)
            print(msg)
            return msg
        end
    end
    self:patchAppearanceLayer(npc, configName, { item = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s %s -> item %d (reloading).", npcId, configName, idx)
    print(msg)
    return msg
end

function VLConsole:setStyleConfigColor(npcId, configName, color, setCmd)
    local usage = string.format("[ValleyLife] Usage: %s <npcId> <colorIndex>", setCmd)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    local idx = tonumber(color)
    if idx == nil then
        return string.format("[ValleyLife] Usage: %s %s <colorIndex>", setCmd, tostring(npcId))
    end
    self:patchAppearanceLayer(npc, configName, { color = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s %s color -> %d (reloading).", npcId, configName, idx)
    print(msg)
    return msg
end

-- vlFace <npcId> <index>: live-swap a spawned villager's face/skin preset so you
-- can flip through the variants (male 1..10, female 1..6) and pick the oldest-
-- looking one. Once chosen, bake it into VILLAGERS[*].appearance.face.item.
function VLConsole:setFace(npcId, index)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlFace <npcId> <index>  (npcId: elara, kenji, marta)"
    end
    local idx = tonumber(index)
    if idx == nil then
        return "[ValleyLife] Usage: vlFace " .. tostring(npcId) .. " <index>  (e.g. vlFace kenji 6)"
    end
    self:patchAppearanceLayer(npc, "face", { item = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s face -> item %d (reloading model).", npcId, idx)
    print(msg)
    return msg
end

-- vlHairs <npcId>: list available hairStyle items (index + internal name). Some
-- head meshes include baked scalp/hair; a full hairStyle wig on top = "hair on hair".
function VLConsole:listHairs(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHairs <npcId>  (e.g. vlHairs kenji)"
    end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local hairCfg = style and style.configs and style.configs.hairStyle
    if type(hairCfg) ~= "table" or type(hairCfg.items) ~= "table" then
        return "[ValleyLife] No hairStyle config."
    end
    print(string.format("[ValleyLife] ---- hairStyles (%d items) ----", #hairCfg.items))
    for i = 1, math.min(#hairCfg.items, 30) do
        local item = hairCfg.items[i]
        if type(item) == "table" then
            print(string.format("  %2d : %s%s", i, tostring(item.name or "?"),
                item.forHat and " (forHat)" or ""))
        end
    end
    if #hairCfg.items > 30 then
        print(string.format("  ... (%d more)", #hairCfg.items - 30))
    end
    print(string.format("[ValleyLife] ---- use vlHair %s <index>; try receding/bald/buzz for baked-in head hair ----", npcId))
    return string.format("[ValleyLife] Listed hairStyles for %s.", npcId)
end

-- vlHairsForHat <npcId>: hairStyle items that work under hats (forHat flag).
function VLConsole:listHairsForHat(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHairsForHat <npcId>  (npcId: " .. VL_NPC_IDS .. ")"
    end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local hairCfg = style and style.configs and style.configs.hairStyle
    if type(hairCfg) ~= "table" or type(hairCfg.items) ~= "table" then
        return "[ValleyLife] No hairStyle config."
    end
    local count = 0
    print("[ValleyLife] ---- hairStyles forHat (work under headgear) ----")
    for i = 1, #hairCfg.items do
        local item = hairCfg.items[i]
        if type(item) == "table" and item.forHat then
            count = count + 1
            print(string.format("  %2d : %s", i, tostring(item.name or "?")))
        end
    end
    print(string.format("[ValleyLife] ---- %d forHat styles (vlHat auto-picks one if needed) ----", count))
    return string.format("[ValleyLife] Listed forHat hairStyles for %s.", npcId)
end

-- vlHair <npcId> <item>: live-swap hairStyle mesh (0 = none/bald slot if available).
function VLConsole:setHair(npcId, item)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHair <npcId> <item>"
    end
    local idx = tonumber(item)
    if idx == nil then
        return "[ValleyLife] Usage: vlHair " .. tostring(npcId) .. " <item>"
    end
    self:patchAppearanceLayer(npc, "hairStyle", { item = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s hairStyle -> item %d (reloading).", npcId, idx)
    print(msg)
    return msg
end

-- vlBeards <npcId>: list beard items compatible with the villager's current face.
-- Incompatible beards often show as a permanent white/ghost layer on the jaw.
function VLConsole:listBeards(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlBeards <npcId>  (e.g. vlBeards kenji)"
    end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    if style == nil or type(style.configs) ~= "table" then
        return "[ValleyLife] Could not build preview style."
    end
    local faceCfg = style.configs.face
    local beardCfg = style.configs.beard
    local faceName = nil
    if faceCfg and faceCfg.getSelectedItem then
        local ok, faceItem = pcall(faceCfg.getSelectedItem, faceCfg)
        if ok and faceItem then faceName = faceItem.name end
    end
    print(string.format("[ValleyLife] ---- beards for face '%s' (item %s) ----",
        tostring(faceName), tostring(faceCfg and faceCfg.selectedItemIndex)))
    if type(beardCfg) ~= "table" or type(beardCfg.items) ~= "table" then
        print("  (no beard config)")
        return "[ValleyLife] No beard config."
    end
    local count = 0
    for i = 1, math.min(#beardCfg.items, 40) do
        local item = beardCfg.items[i]
        if type(item) == "table" then
            local universal = item.faceName == nil
            local match = universal or item.faceName == faceName
            if match then
                count = count + 1
                print(string.format("  %3d : %s%s", i, tostring(item.name or "?"),
                    universal and " (any face)" or ""))
            end
        end
    end
    if #beardCfg.items > 40 then
        print(string.format("  ... (%d more beards not listed)", #beardCfg.items - 40))
    end
    print(string.format("[ValleyLife] ---- %d compatible beards (use vlBeard %s <index>) ----",
        count, npcId))
    return string.format("[ValleyLife] Listed compatible beards for %s.", npcId)
end

-- vlBeard <npcId> <item>: live-swap a villager's beard mesh (male: 1..91, or 0 for
-- none) and respawn. Use it to find a beard that sits cleanly on the chosen face,
-- or set 0 to confirm whether a "ghost chin" artifact comes from the beard or face.
function VLConsole:setBeard(npcId, item)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlBeard <npcId> <item>  (item 0 = none)"
    end
    local idx = tonumber(item)
    if idx == nil then
        return "[ValleyLife] Usage: vlBeard " .. tostring(npcId) .. " <item>  (0 = none)"
    end
    local color = npc.appearance and npc.appearance.beard and npc.appearance.beard.color
    self:patchAppearanceLayer(npc, "beard", { item = idx, color = color })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s beard -> item %d (reloading).", npcId, idx)
    print(msg)
    return msg
end

-- vlBeardColor <npcId> <hairColor> <beardColor>: EXPERIMENTAL - apply hair and
-- beard colors separately (hair first, beard second, no engine unification).
-- Tests whether FS25 can render different shades, e.g. vlBeardColor kenji 23 24.
function VLConsole:setBeardColor(npcId, hairColor, beardColor)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlBeardColor <npcId> <hairColor> <beardColor>"
    end
    local hc = tonumber(hairColor)
    local bc = tonumber(beardColor)
    if hc == nil or bc == nil then
        return "[ValleyLife] Usage: vlBeardColor " .. tostring(npcId) .. " <hairColor> <beardColor>  (e.g. vlBeardColor kenji 23 24)"
    end
    self:patchAppearanceLayer(npc, "hairStyle", { color = hc })
    local beardItem = npc.appearance and npc.appearance.beard and npc.appearance.beard.item
    self:patchAppearanceLayer(npc, "beard", { item = beardItem or 2, color = bc })
    npc:reapplyAppearance({ splitHairBeardColors = true })
    local msg = string.format("[ValleyLife][exp] %s hair=%d beard=%d (split, no unify).", npcId, hc, bc)
    print(msg)
    return msg
end

-- vlHairColor <npcId> <index>: live-swap a villager's hair AND beard color together
-- (so a beard stays matched to the hair) and reload the model. Use it to find the
-- grey index, then bake it into VILLAGERS[*].appearance.hairStyle/beard.color.
function VLConsole:setHairColor(npcId, index)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHairColor <npcId> <index>  (npcId: elara, kenji, marta)"
    end
    local idx = tonumber(index)
    if idx == nil then
        return "[ValleyLife] Usage: vlHairColor " .. tostring(npcId) .. " <index>  (e.g. vlHairColor kenji 20)"
    end
    self:patchAppearanceLayer(npc, "hairStyle", { color = idx })
    if npc.appearance ~= nil and npc.appearance.beard ~= nil then
        self:patchAppearanceLayer(npc, "beard", { color = idx })
    end
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s hair+beard color -> %d (reloading).", npcId, idx)
    print(msg)
    return msg
end

-- vlHairColors: print the hair color palette (index -> RGB) so we can pick a grey
-- by value instead of cycling through all of them blindly.
function VLConsole:dumpHairColors()
    if PlayerStyle == nil or PlayerStyle.new == nil then
        return "[ValleyLife] PlayerStyle API unavailable."
    end
    local xml = "dataS/character/playerM/playerM.xml"
    local style = PlayerStyle.new()
    pcall(function() if style.loadConfigurationXML then style:loadConfigurationXML(xml) end end)
    pcall(function()
        if PlayerSystem ~= nil and PlayerSystem.PLAYER_STYLES_BY_FILENAME ~= nil then
            local key = Utils.getFilename and Utils.getFilename(xml) or xml
            local entry = PlayerSystem.PLAYER_STYLES_BY_FILENAME[key]
            if entry and entry.style then style.hairColors = entry.style.hairColors end
        end
    end)
    local colors = style.hairColors
    if type(colors) ~= "table" then
        return "[ValleyLife] No hairColors palette found (got " .. type(colors) .. ")."
    end
    -- Each palette entry is { primary = <color>, secondary = <color> }. Format a
    -- color table as "r,g,b"; if the components aren't where we expect, dump the
    -- raw key=value pairs so we can see the real shape.
    local function fmtColor(col)
        if type(col) ~= "table" then return tostring(col) end
        local r = col[1] or col.r or col.x
        local g = col[2] or col.g or col.y
        local b = col[3] or col.b or col.z
        if type(r) == "number" then
            return string.format("%.2f,%.2f,%.2f", r, g or 0, b or 0)
        end
        local parts = {}
        for k, v in pairs(col) do
            parts[#parts + 1] = string.format("%s=%s", tostring(k),
                type(v) == "number" and string.format("%.2f", v) or type(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    print(string.format("[ValleyLife] ---- hair color palette (%d entries) ----", #colors))
    for i, c in ipairs(colors) do
        local p = type(c) == "table" and c.primary or nil
        local s = type(c) == "table" and c.secondary or nil
        print(string.format("  %2d : primary=[%s] secondary=[%s]", i, fmtColor(p), fmtColor(s)))
    end
    print("[ValleyLife] ---- end hair color palette ----")
    return "[ValleyLife] Hair color palette written to log/console."
end

-- Clothing / accessories (live preview; bake into VILLAGERS[*].appearance.*)

function VLConsole:listTops(npcId)
    return self:listStyleConfig(npcId, "top", "vlTops")
end
function VLConsole:setTop(npcId, item)
    return self:setStyleConfigItem(npcId, "top", item, "vlTop")
end
function VLConsole:setTopColor(npcId, color)
    return self:setStyleConfigColor(npcId, "top", color, "vlTopColor")
end

function VLConsole:listBottoms(npcId)
    return self:listStyleConfig(npcId, "bottom", "vlBottoms")
end
function VLConsole:setBottom(npcId, item)
    return self:setStyleConfigItem(npcId, "bottom", item, "vlBottom")
end
function VLConsole:setBottomColor(npcId, color)
    return self:setStyleConfigColor(npcId, "bottom", color, "vlBottomColor")
end

function VLConsole:listOnepieces(npcId)
    return self:listStyleConfig(npcId, "onepiece", "vlOnepieces")
end
function VLConsole:setOnepiece(npcId, item)
    return self:setStyleConfigItem(npcId, "onepiece", item, "vlOnepiece")
end
function VLConsole:setOnepieceColor(npcId, color)
    return self:setStyleConfigColor(npcId, "onepiece", color, "vlOnepieceColor")
end

function VLConsole:listGloves(npcId)
    return self:listStyleConfig(npcId, "gloves", "vlGloves")
end
function VLConsole:setGloves(npcId, item)
    return self:setStyleConfigItem(npcId, "gloves", item, "vlGloves")
end
function VLConsole:setGlovesColor(npcId, color)
    return self:setStyleConfigColor(npcId, "gloves", color, "vlGlovesColor")
end

function VLConsole:listGlasses(npcId)
    return self:listStyleConfig(npcId, "glasses", "vlGlasses", "vlGlass")
end
function VLConsole:setGlasses(npcId, item)
    return self:setStyleConfigItem(npcId, "glasses", item, "vlGlass")
end
function VLConsole:setGlassesColor(npcId, color)
    return self:setStyleConfigColor(npcId, "glasses", color, "vlGlassesColor")
end

function VLConsole:listHats(npcId)
    return self:listStyleConfig(npcId, "headgear", "vlHats")
end
function VLConsole:setHat(npcId, item)
    return self:setStyleConfigItem(npcId, "headgear", item, "vlHat")
end
function VLConsole:setHatColor(npcId, color)
    return self:setStyleConfigColor(npcId, "headgear", color, "vlHatColor")
end

function VLConsole:listFootwears(npcId)
    return self:listFootwear(npcId, "all")
end
function VLConsole:listShoes(npcId)
    return self:listFootwear(npcId, "shoe")
end
function VLConsole:listSocks(npcId)
    return self:listFootwear(npcId, "sock")
end
function VLConsole:setShoe(npcId, item)
    return self:setStyleConfigItem(npcId, "footwear", item, "vlShoe")
end
function VLConsole:setShoeColor(npcId, color)
    return self:setStyleConfigColor(npcId, "footwear", color, "vlShoeColor")
end
function VLConsole:setSock(npcId, item)
    local usage = "[ValleyLife] Usage: vlSock <npcId> <index>  (0 = none)"
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if self:sockUsesFacegear(npc) then
        return self:setStyleConfigItem(npcId, "facegear", item, "vlSock")
    end
    return self:setStyleConfigItem(npcId, "footwear", item, "vlSock")
end
function VLConsole:setSockColor(npcId, color)
    local usage = "[ValleyLife] Usage: vlSockColor <npcId> <colorIndex>"
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if self:sockUsesFacegear(npc) then
        return self:setStyleConfigColor(npcId, "facegear", color, "vlSockColor")
    end
    return self:setStyleConfigColor(npcId, "footwear", color, "vlSockColor")
end

function VLConsole:listFacegears(npcId)
    return self:listStyleConfig(npcId, "facegear", "vlFacegears")
end
function VLConsole:setFacegear(npcId, item)
    return self:setStyleConfigItem(npcId, "facegear", item, "vlFacegear")
end
function VLConsole:setFacegearColor(npcId, color)
    return self:setStyleConfigColor(npcId, "facegear", color, "vlFacegearColor")
end

-- vlGrandpa: probe every plausible runtime path to the base-game GRANDPA NPC object
-- so we can get his rootNode and move him. Run in-game; read log.txt for results.
function VLConsole:probeGrandpa()
    local found = {}

    local function tryNode(label, obj)
        if obj == nil then return end
        local node = nil
        pcall(function()
            node = obj.rootNode or obj.graphicsRootNode
                or (obj.graphicsComponent and obj.graphicsComponent.graphicsRootNode)
        end)
        if node ~= nil and node ~= 0 and entityExists(node) then
            local x, y, z = getWorldTranslation(node)
            print(string.format("[ValleyLife][Grandpa] HIT %s  node=%s  pos=(%.1f, %.1f, %.1f)",
                label, tostring(node), x, y, z))
            found[#found + 1] = { label = label, node = node, obj = obj }
        else
            -- Still print the object type so we know the path resolved but had no node
            if obj ~= nil then
                print(string.format("[ValleyLife][Grandpa] PARTIAL %s  obj=%s  node=%s",
                    label, type(obj), tostring(node)))
            end
        end
    end

    local function tryNPCsByName(label, container)
        if type(container) ~= "table" then return end
        for k, v in pairs(container) do
            local name = nil
            pcall(function()
                name = v.npcName or v.name or v.typeName or (type(v.getName) == "function" and v:getName())
            end)
            if type(name) == "string" and string.upper(name) == "GRANDPA" then
                tryNode(label .. "[" .. tostring(k) .. "]", v)
            end
        end
    end

    print("[ValleyLife][Grandpa] ---- probing for GRANDPA node ----")

    -- Path 1: FarmlandManager owns NPC references (farmlands.xml npcName="GRANDPA")
    local fm = g_currentMission and g_currentMission.farmlandManager
    if fm then
        print("[ValleyLife][Grandpa] farmlandManager = " .. type(fm))
        -- Try direct npcsByName table
        pcall(function()
            local byName = fm.npcsByName or fm.npcs or fm.npcObjects
            if type(byName) == "table" then
                tryNode("farmlandManager.npcsByName[GRANDPA]", byName["GRANDPA"] or byName["grandpa"])
                tryNPCsByName("farmlandManager.npcs", byName)
            end
        end)
        -- Try getFarmlandById and inspect the npc field
        pcall(function()
            for _, getFn in ipairs({ "getFarmlandById", "getFarmland" }) do
                if type(fm[getFn]) == "function" then
                    local fl = fm[getFn](fm, 1)  -- farmland 1 = GRANDPA's first
                    if fl then
                        print("[ValleyLife][Grandpa] farmland[1] = " .. type(fl))
                        tryNode("farmland[1].npc", fl.npc)
                        tryNode("farmland[1].npcObject", fl.npcObject)
                        if type(fl.npcName) == "string" then
                            print("[ValleyLife][Grandpa] farmland[1].npcName = " .. fl.npcName)
                        end
                    end
                    break
                end
            end
        end)
    else
        print("[ValleyLife][Grandpa] g_currentMission.farmlandManager = nil")
    end

    -- Path 2: Dedicated NPC system on the mission
    for _, key in ipairs({ "npcSystem", "npcs", "npcManager", "npcHandler" }) do
        local sys = g_currentMission and g_currentMission[key]
        if sys ~= nil then
            print(string.format("[ValleyLife][Grandpa] mission.%s = %s", key, type(sys)))
            -- Try by-name lookup methods
            pcall(function()
                for _, fn in ipairs({ "getNPCByName", "getNPC", "getByName", "getObject" }) do
                    if type(sys[fn]) == "function" then
                        local obj = sys[fn](sys, "GRANDPA")
                        if obj then
                            tryNode(string.format("mission.%s:%s(GRANDPA)", key, fn), obj)
                        end
                    end
                end
            end)
            -- Try iterating if it's a table of NPCs
            if type(sys) == "table" then
                tryNPCsByName("mission." .. key, sys)
            end
        end
    end

    -- Path 3: Global NPC manager / farmland manager — dump methods and try lookups
    for _, gname in ipairs({ "g_npcManager", "g_npcs", "g_npcSystem", "g_farmlandManager" }) do
        local g = _G[gname]
        if g ~= nil then
            print(string.format("[ValleyLife][Grandpa] %s = %s", gname, type(g)))
            pcall(function()
                -- Dump all keys so we can see the structure
                local fns, fields = {}, {}
                for k, v in pairs(g) do
                    if type(v) == "function" then fns[#fns+1] = k
                    elseif type(v) ~= "table" and type(v) ~= "userdata" then
                        fields[#fields+1] = k .. "=" .. tostring(v)
                    else
                        fns[#fns+1] = k .. "(" .. type(v) .. ")"
                    end
                end
                table.sort(fns); table.sort(fields)
                print(string.format("[ValleyLife][Grandpa] %s keys: %s", gname, table.concat(fns, ", ")))
                if #fields > 0 then
                    print(string.format("[ValleyLife][Grandpa] %s fields: %s", gname, table.concat(fields, ", ")))
                end

                -- Try direct key lookup
                local obj = g["GRANDPA"] or g["grandpa"]
                if obj then tryNode(gname .. "[GRANDPA]", obj) end
                tryNPCsByName(gname, g)

                -- Try common getter methods
                for _, fn in ipairs({ "getNPCByName", "getNPC", "getByName", "getObject", "getNPCObject" }) do
                    if type(g[fn]) == "function" then
                        local ok, result = pcall(g[fn], g, "GRANDPA")
                        if ok and result ~= nil then
                            print(string.format("[ValleyLife][Grandpa] %s:%s(GRANDPA) = %s", gname, fn, type(result)))
                            tryNode(gname .. ":" .. fn .. "(GRANDPA)", result)
                        end
                    end
                end

                -- g_farmlandManager: try getFarmlandById(1) and inspect deeper
                if gname == "g_farmlandManager" then
                    for _, getFn in ipairs({ "getFarmlandById", "getFarmland", "getFarmlandByIndex" }) do
                        if type(g[getFn]) == "function" then
                            local ok, fl = pcall(g[getFn], g, 1)
                            if ok and fl ~= nil then
                                print(string.format("[ValleyLife][Grandpa] %s:%s(1) = %s", gname, getFn, type(fl)))
                                -- Dump farmland fields
                                local flkeys = {}
                                for k, v in pairs(fl) do flkeys[#flkeys+1] = k .. "=" .. type(v) end
                                table.sort(flkeys)
                                print("[ValleyLife][Grandpa] farmland[1] keys: " .. table.concat(flkeys, ", "))
                                tryNode("farmland[1].npc",       fl.npc)
                                tryNode("farmland[1].npcObject", fl.npcObject)
                                tryNode("farmland[1].owner",     fl.owner)
                            end
                            break
                        end
                    end
                end

                -- g_npcManager: dump the NPC object fields to find the node property name
                if gname == "g_npcManager" then
                    -- Get GRANDPA via getNPCByName and dump every field
                    local npcObj = nil
                    pcall(function()
                        npcObj = g:getNPCByName("GRANDPA")
                    end)
                    if npcObj == nil then
                        -- Try nameToNPC direct table
                        pcall(function() npcObj = g.nameToNPC and g.nameToNPC["GRANDPA"] end)
                    end
                    if npcObj ~= nil then
                        print("[ValleyLife][Grandpa] GRANDPA NPC object fields:")
                        local flds = {}
                        for k, v in pairs(npcObj) do
                            flds[#flds+1] = string.format("  %s = %s", tostring(k), type(v))
                            -- Try anything that looks like it could be a scene node
                            if type(v) == "number" and v ~= 0 then
                                pcall(function()
                                    if entityExists(v) then
                                        local x, y, z = getWorldTranslation(v)
                                        print(string.format("[ValleyLife][Grandpa] HIT npcObj.%s is a valid entity node! pos=(%.1f,%.1f,%.1f)", tostring(k), x, y, z))
                                        found[#found+1] = { label = "g_npcManager:getNPCByName(GRANDPA)." .. tostring(k), node = v, obj = npcObj }
                                    end
                                end)
                            elseif type(v) == "table" or type(v) == "userdata" then
                                -- Check one level deeper for a node
                                pcall(function()
                                    for k2, v2 in pairs(v) do
                                        if type(v2) == "number" and v2 ~= 0 and entityExists(v2) then
                                            local x, y, z = getWorldTranslation(v2)
                                            print(string.format("[ValleyLife][Grandpa] HIT npcObj.%s.%s is a valid entity node! pos=(%.1f,%.1f,%.1f)", tostring(k), tostring(k2), x, y, z))
                                            found[#found+1] = { label = "npcObj." .. tostring(k) .. "." .. tostring(k2), node = v2, obj = npcObj }
                                        end
                                    end
                                end)
                            end
                        end
                        table.sort(flds)
                        for _, l in ipairs(flds) do print(l) end
                    end

                    -- Also try spots/startSpots which may hold scene node references
                    for _, subkey in ipairs({ "spots", "startSpots", "npcs" }) do
                        local sub = g[subkey]
                        if type(sub) == "table" and #sub > 0 then
                            print(string.format("[ValleyLife][Grandpa] g_npcManager.%s[1] fields:", subkey))
                            local sflds = {}
                            for k, v in pairs(sub[1]) do
                                sflds[#sflds+1] = string.format("  %s = %s", tostring(k), type(v))
                                if type(v) == "number" and v ~= 0 then
                                    pcall(function()
                                        if entityExists(v) then
                                            local x, y, z = getWorldTranslation(v)
                                            print(string.format("[ValleyLife][Grandpa] HIT %s[1].%s entity pos=(%.1f,%.1f,%.1f)", subkey, tostring(k), x, y, z))
                                            found[#found+1] = { label = subkey .. "[1]." .. tostring(k), node = v, obj = sub[1] }
                                        end
                                    end)
                                end
                            end
                            table.sort(sflds)
                            for _, l in ipairs(sflds) do print(l) end
                        end
                    end

                    -- Use farmland npcIndex to get GRANDPA's entry
                    pcall(function()
                        local fl = g_farmlandManager and g_farmlandManager:getFarmlandById(1)
                        local idx = fl and fl.npcIndex
                        if idx ~= nil then
                            print(string.format("[ValleyLife][Grandpa] farmland[1].npcIndex = %s", tostring(idx)))
                            local npcByIdx = g.npcs and g.npcs[idx]
                            if npcByIdx then
                                print("[ValleyLife][Grandpa] g_npcManager.npcs[npcIndex] fields:")
                                for k, v in pairs(npcByIdx) do
                                    print(string.format("  %s = %s", tostring(k), type(v)))
                                    if type(v) == "number" and v ~= 0 then
                                        pcall(function()
                                            if entityExists(v) then
                                                local x, y, z = getWorldTranslation(v)
                                                print(string.format("[ValleyLife][Grandpa] HIT npcs[npcIndex].%s entity pos=(%.1f,%.1f,%.1f)", tostring(k), x, y, z))
                                                found[#found+1] = { label = "npcs[npcIndex]." .. tostring(k), node = v, obj = npcByIdx }
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end)
                end
            end)
        end
    end

    -- Path 4: GuidedTour instance (only present during the tour, but try anyway)
    local gt = g_currentMission and g_currentMission.guidedTour
    if gt then
        print("[ValleyLife][Grandpa] guidedTour instance present")
        pcall(function()
            if type(gt.getNPCSpot) == "function" then
                local spot = gt:getNPCSpot("GRANDPA")
                if spot then
                    print("[ValleyLife][Grandpa] getNPCSpot(GRANDPA) = " .. type(spot))
                    tryNode("guidedTour.getNPCSpot(GRANDPA)", spot)
                    -- Spot may wrap the NPC object
                    if type(spot) == "table" then
                        for k, v in pairs(spot) do
                            if type(v) == "table" or type(v) == "userdata" then
                                tryNode("guidedTour.spot." .. tostring(k), v)
                            end
                        end
                    end
                end
            end
        end)
    end

    if #found == 0 then
        print("[ValleyLife][Grandpa] No rootNode found on any path. GRANDPA may not be loaded yet, or needs a different lookup.")
    else
        print(string.format("[ValleyLife][Grandpa] Found %d node(s). See HIT lines above.", #found))
    end

    -- Dump the spot table on the GRANDPA NPC object
    local grandpa = g_npcManager and g_npcManager:getNPCByName("GRANDPA")
    if grandpa and grandpa.spot then
        print("[ValleyLife][Grandpa] grandpa.spot fields:")
        local spotFields = {}
        for k, v in pairs(grandpa.spot) do
            spotFields[#spotFields+1] = string.format("  %s = %s (%s)", tostring(k), tostring(v), type(v))
        end
        table.sort(spotFields)
        for _, l in ipairs(spotFields) do print(l) end
    else
        print("[ValleyLife][Grandpa] grandpa.spot is nil or GRANDPA not found")
    end

    print("[ValleyLife][Grandpa] ---- end probe ----")
    return "[ValleyLife] Grandpa probe done — check log.txt."
end

-- vlMoveGrandpa x z: move the base-game GRANDPA to a world position by writing
-- his x/z/needPositionUpdate fields, letting his own update loop move the node.
-- vlMoveGrandpa with no args: teleport to player's current position.
-- vlMoveGrandpa x z: teleport to explicit world coords.
function VLConsole:moveGrandpa(x, z)
    local px, pz
    if x == nil then
        -- No args — use player position
        local camera = getCamera()
        if camera == nil then
            return "[ValleyLife] No camera found."
        end
        px, _, pz = getWorldTranslation(camera)
    else
        px, pz = tonumber(x), tonumber(z)
        if px == nil or pz == nil then
            return "[ValleyLife] Usage: vlMoveGrandpa [x z]"
        end
    end
    local grandpa = g_npcManager and g_npcManager:getNPCByName("GRANDPA")
    if grandpa == nil then
        return "[ValleyLife] GRANDPA not found in g_npcManager."
    end
    local oldX, oldZ = grandpa.x, grandpa.z
    -- Move spot anchor and NPC node together using world coordinates so the
    -- NPC is already at the destination before the walk system can activate.
    local py = grandpa.y or 47.0
    if grandpa.spot and grandpa.spot.node and entityExists(grandpa.spot.node) then
        setWorldTranslation(grandpa.spot.node, px, py, pz)
    end
    if grandpa.node and grandpa.node ~= 0 and entityExists(grandpa.node) then
        setWorldTranslation(grandpa.node, px, py, pz)
    end
    grandpa.x = px
    grandpa.y = py
    grandpa.z = pz
    grandpa.needPositionUpdate = true
    local msg = string.format("[ValleyLife] GRANDPA moved (%.1f,%.1f) -> (%.1f,%.1f)", oldX, oldZ, px, pz)
    print(msg)
    return msg
end

-- vlWalterDump: dump everything about the GRANDPA NPC at runtime — spot fields,
-- graphicsComponent, components, and all scalar fields. Run after load to see
-- whether spot.node is populated and which child nodes carry animCharSets.
function VLConsole:dumpWalter()
    local grandpa = g_npcManager and g_npcManager:getNPCByName("GRANDPA")
    if grandpa == nil then
        return "[ValleyLife] GRANDPA not found in g_npcManager."
    end

    print("[ValleyLife][Walter] ---- GRANDPA dump ----")
    print(string.format("  isActive=%s  needPositionUpdate=%s", tostring(grandpa.isActive), tostring(grandpa.needPositionUpdate)))
    print(string.format("  pos=(%.2f, %.2f, %.2f)", grandpa.x or 0, grandpa.y or 0, grandpa.z or 0))
    print(string.format("  pendingSpotUniqueId=%s", tostring(grandpa.pendingSpotUniqueId)))
    print(string.format("  node=%s  exists=%s", tostring(grandpa.node),
        tostring(grandpa.node ~= nil and entityExists(grandpa.node))))

    -- Spot
    if grandpa.spot then
        print("[ValleyLife][Walter] spot fields:")
        for k, v in pairs(grandpa.spot) do
            if type(v) == "number" and v ~= 0 then
                local isEnt = false
                pcall(function() isEnt = entityExists(v) end)
                if isEnt then
                    local x, y, z = getWorldTranslation(v)
                    print(string.format("  .%s = %d (entity pos=%.1f,%.1f,%.1f)", k, v, x, y, z))
                    local ok2, acs = pcall(getAnimCharacterSet, v)
                    if ok2 and acs and acs ~= 0 then
                        print(string.format("    -> animCharSet=%d", acs))
                    end
                else
                    print(string.format("  .%s = %s", k, tostring(v)))
                end
            else
                print(string.format("  .%s = %s (%s)", k, tostring(v), type(v)))
            end
        end
    else
        print("[ValleyLife][Walter] spot = nil")
    end

    -- playerGraphics / graphicsComponent — dump ALL fields so we can find charSet/animCharSet
    for _, key in ipairs({ "playerGraphics", "graphicsComponent" }) do
        local pg = grandpa[key]
        if pg ~= nil then
            print(string.format("[ValleyLife][Walter] %s (all fields):", key))
            local pgFields = {}
            for k, v in pairs(pg) do
                local t = type(v)
                if t == "number" then
                    -- Could be an entity node or the charSet handle — test both
                    local isEnt = false
                    pcall(function() isEnt = v ~= 0 and entityExists(v) end)
                    if isEnt then
                        local x2, y2, z2 = getWorldTranslation(v)
                        pgFields[#pgFields+1] = string.format("  .%s = %d (entity pos=%.1f,%.1f,%.1f)", k, v, x2, y2, z2)
                        local ok2, acs = pcall(getAnimCharacterSet, v)
                        if ok2 and acs and acs ~= 0 then
                            pgFields[#pgFields+1] = string.format("    -> getAnimCharacterSet=%d  *** FOUND ***", acs)
                        end
                        -- Try children
                        local nc = getNumOfChildren(v)
                        for i = 0, math.min(nc-1, 7) do
                            local child = getChildAt(v, i)
                            if child and child ~= 0 then
                                local ok3, acs3 = pcall(getAnimCharacterSet, child)
                                if ok3 and acs3 and acs3 ~= 0 then
                                    pgFields[#pgFields+1] = string.format("    -> child[%d]=%d animCharSet=%d  *** FOUND ***", i, child, acs3)
                                end
                            end
                        end
                    else
                        -- Non-entity number — could be animCharSet handle (not a scene node)
                        pgFields[#pgFields+1] = string.format("  .%s = %d (non-entity number)", k, v)
                    end
                elseif t == "boolean" or t == "string" then
                    pgFields[#pgFields+1] = string.format("  .%s = %s (%s)", k, tostring(v), t)
                elseif t == "table" then
                    pgFields[#pgFields+1] = string.format("  .%s = table", k)
                elseif t ~= "function" then
                    pgFields[#pgFields+1] = string.format("  .%s = %s (%s)", k, tostring(v), t)
                end
            end
            table.sort(pgFields)
            for _, l in ipairs(pgFields) do print(l) end
        end
    end

    -- components table
    if type(grandpa.components) == "table" then
        print(string.format("[ValleyLife][Walter] components (%d):", #grandpa.components))
        for i, comp in ipairs(grandpa.components) do
            if type(comp) == "table" then
                local parts = {}
                for k, v in pairs(comp) do
                    if type(v) == "number" and v ~= 0 then
                        local isEnt = false
                        pcall(function() isEnt = entityExists(v) end)
                        if isEnt then
                            local x, _, z = getWorldTranslation(v)
                            parts[#parts+1] = string.format("%s=%d@(%.0f,%.0f)", k, v, x, z)
                            local ok2, acs = pcall(getAnimCharacterSet, v)
                            if ok2 and acs and acs ~= 0 then
                                print(string.format("  comp[%d].%s -> animCharSet=%d", i, k, acs))
                            end
                        else
                            parts[#parts+1] = string.format("%s=%s", k, tostring(v))
                        end
                    elseif type(v) ~= "function" and type(v) ~= "table" then
                        parts[#parts+1] = string.format("%s=%s", k, tostring(v))
                    end
                end
                print(string.format("  [%d] {%s}", i, table.concat(parts, ", ")))
            else
                print(string.format("  [%d] %s", i, type(comp)))
            end
        end
    else
        print("[ValleyLife][Walter] components = " .. type(grandpa.components))
    end

    -- All scalar fields on grandpa
    print("[ValleyLife][Walter] scalar fields:")
    local fields = {}
    for k, v in pairs(grandpa) do
        local t = type(v)
        if t == "boolean" or t == "string" or t == "number" then
            fields[#fields+1] = string.format("  %s = %s", k, tostring(v))
        end
    end
    table.sort(fields)
    for _, l in ipairs(fields) do print(l) end

    print("[ValleyLife][Walter] ---- end dump ----")
    return "[ValleyLife] Walter dump done — check log."
end

function VLConsole:printSeason()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local env = g_currentMission and g_currentMission.environment
    local rawPeriod = env and env.currentPeriod
    local rawSeason = env and env.currentSeason
    local mday = env and env.currentMonotonicDay
    local month = TimeHelper.getCalendarMonth()
    local dayOfMonth = TimeHelper.getCalendarDayOfMonth()
    local season = TimeHelper.getSeason()
    local hour = TimeHelper.getHour()
    local weekday = TimeHelper.getWeekday()
    local WDNAMES = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}
    local outfit = TimeHelper.getOutfitMode()
    local reason = TimeHelper.getOutfitModeReason()
    local msg = string.format(
        "[ValleyLife] period=%s engineSeason=%s -> month %d day %d, season '%s'. monotonicDay=%s weekday=%d(%s) hour=%.1f. Outfit: %s (%s).",
        tostring(rawPeriod), tostring(rawSeason), month, dayOfMonth, season,
        tostring(mday), weekday, WDNAMES[weekday + 1] or "?", hour, outfit, reason)
    print(msg)
    return msg
end

function VLConsole:printBirthdays()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local lines = { "[ValleyLife] Villager birthdays:" }
    for id, npc in pairs(g_valleyLife.npcs) do
        local b = npc.birthday
        local today = BirthdayHelper.isToday(b) and " (today!)" or ""
        lines[#lines + 1] = string.format(
            "  %s: %s%s", id, BirthdayHelper.format(b), today)
    end
    local msg = table.concat(lines, "\n")
    print(msg)
    return msg
end

function VLConsole:setOutfitMode(npcId, mode)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlOutfit <npcId> <work|leisure|auto>  (auto = resume calendar)"
    end
    local m = type(mode) == "string" and string.lower(mode) or nil
    if m == "auto" then
        if type(npc.syncOutfitToCalendar) ~= "function" then
            return "[ValleyLife] Calendar outfit sync unavailable on this NPC."
        end
        npc:syncOutfitToCalendar()
        local season = TimeHelper.getSeason()
        local outfit = TimeHelper.getOutfitMode()
        local msg = string.format(
            "[ValleyLife] %s outfit -> calendar (%s, %s %s look).",
            npcId, outfit, season, outfit == "work" and "work" or "leisure")
        print(msg)
        return msg
    end
    if m ~= "work" and m ~= "leisure" and m ~= "date" then
        return "[ValleyLife] Usage: vlOutfit " .. tostring(npcId) .. " <work|leisure|date|auto>"
    end
    if type(npc.setOutfitMode) ~= "function" then
        return "[ValleyLife] Outfit modes unavailable on this NPC."
    end
    npc:setOutfitMode(m, { force = true })
    if type(npc.setOutfitCalendarLocked) == "function" then
        npc:setOutfitCalendarLocked(true)
    end
    local season = TimeHelper.getSeason()
    local seasonLabel = m == "work" and (season .. " work") or (m == "date" and (season .. " date") or (season .. " leisure"))
    local msg = string.format(
        "[ValleyLife] %s outfit -> %s (preview; calendar paused). Clothing commands edit %s look.",
        npcId, m, seasonLabel)
    print(msg)
    return msg
end

if addConsoleCommand ~= nil then
    addConsoleCommand("vlSeason", "Print in-game season (for seasonal outfit tuning)", "printSeason", VLConsole)
    addConsoleCommand("vlBirthdays", "List villager birthdays", "printBirthdays", VLConsole)
    addConsoleCommand("vlOutfit", "Preview work/leisure or resume calendar: vlOutfit <npcId> <work|leisure|auto>", "setOutfitMode", VLConsole)
    addConsoleCommand("vlPos", "Print player world position (ValleyLife spawn coords)", "printPlayerPos", VLConsole)
    addConsoleCommand("vlRel", "Set villager relationship: vlRel <npcId> <value>", "setRelationship", VLConsole)
    addConsoleCommand("vlEvent", "Force-trigger next heart event: vlEvent <npcId>", "triggerEvent", VLConsole)
    addConsoleCommand("vlNear", "Report nearest villager + distance (proximity debug)", "printNearest", VLConsole)
    addConsoleCommand("vlReset", "Reset a villager's events + relationship: vlReset <npcId>", "resetNpc", VLConsole)
    addConsoleCommand("vlDlg", "Probe available native dialog/choice widgets", "probeDialogs", VLConsole)
    addConsoleCommand("vlGuidedTour", "Probe GuidedTour class/instance methods (find hook names)", "probeGuidedTour", VLConsole)
    addConsoleCommand("vlGrandpa", "Probe runtime paths to GRANDPA's rootNode (for walk loop research)", "probeGrandpa", VLConsole)
    addConsoleCommand("vlMoveGrandpa", "Move GRANDPA to world position: vlMoveGrandpa <x> <z>", "moveGrandpa", VLConsole)
    addConsoleCommand("vlWalterDump", "Dump GRANDPA NPC runtime state (spot, components, graphicsNode)", "dumpWalter", VLConsole)
    addConsoleCommand("vlAnimClips", "Dump animation clip names for a villager: vlAnimClips <npcId>", "dumpAnimClips", VLConsole)
    addConsoleCommand("vlWalk", "Force-start a walk loop: vlWalk <npcId> [loopName|index] (npcId: marta, grandpa, ...)", "forceWalk", VLConsole)
    addConsoleCommand("vlWalterYOffset", "Tune Walter's driven height offset (meters, +lowers): vlWalterYOffset <n>", "setWalterYOffset", VLConsole)
    addConsoleCommand("vlWalterStairLift", "Tune Walter's stair bow-lift on sloped segments: vlWalterStairLift <n>", "setWalterStairLift", VLConsole)
    addConsoleCommand("vlWalterShow", "Reveal Walter if he stepped inside (hidden): vlWalterShow", "walterShow", VLConsole)
    addConsoleCommand("vlWalterHide", "Hide Walter on demand (test the door disappear): vlWalterHide", "walterHide", VLConsole)
    addConsoleCommand("vlWalterMorning", "Trigger Walter's morning departure (door -> home): vlWalterMorning", "walterMorning", VLConsole)
    addConsoleCommand("vlWalterDoor", "TEST Walter's woodshop door control: vlWalterDoor <1=open|-1=close>", "walterDoor", VLConsole)
    addConsoleCommand("vlWalterLights", "TEST Walter's woodshop lights control: vlWalterLights <1on/0off>", "walterLights", VLConsole)
    addConsoleCommand("vlDoorTest", "TEST: open/close woodshop doors: vlDoorTest <1=open|-1=close|0=stop> [x] [z]", "doorTest", VLConsole)
    addConsoleCommand("vlLightTest", "TEST woodshop lights on/off: vlLightTest <1on/0off>", "lightTest", VLConsole)
    addConsoleCommand("vlSkipPause", "Skip current mid-route pause and send NPC to next waypoint: vlSkipPause <npcId>", "skipPause", VLConsole)
    addConsoleCommand("vlWalterIntro", "Force-play Walter's post-tour market introduction", "playWalterIntro", VLConsole)
    addConsoleCommand("vlConvo", "Probe NPC conversation system (find hook for 'Who can help me?')", "probeConversation", VLConsole)
    addConsoleCommand("vlStyle", "Dump character style configs (find skin/age options)", "dumpStyles", VLConsole)
    addConsoleCommand("vlFace", "Live-swap a villager's face: vlFace <npcId> <index>", "setFace", VLConsole)
    addConsoleCommand("vlHair", "Live-swap hairStyle mesh: vlHair <npcId> <item> (0=none)", "setHair", VLConsole)
    addConsoleCommand("vlHairs", "List hairStyle items: vlHairs <npcId>", "listHairs", VLConsole)
    addConsoleCommand("vlHairsForHat", "List forHat hairStyles (under hats): vlHairsForHat <npcId>", "listHairsForHat", VLConsole)
    addConsoleCommand("vlBeard", "Live-swap a villager's beard: vlBeard <npcId> <item> (0=none)", "setBeard", VLConsole)
    addConsoleCommand("vlBeards", "List beards compatible with villager's face", "listBeards", VLConsole)
    addConsoleCommand("vlHairColor", "Live-swap hair+beard color: vlHairColor <npcId> <index>", "setHairColor", VLConsole)
    addConsoleCommand("vlBeardColor", "EXPERIMENTAL split hair/beard color: vlBeardColor <npcId> <hair> <beard>", "setBeardColor", VLConsole)
    addConsoleCommand("vlHairColors", "Print the hair color palette (index -> RGB)", "dumpHairColors", VLConsole)
    addConsoleCommand("vlTops", "List shirt/top items: vlTops <npcId>", "listTops", VLConsole)
    addConsoleCommand("vlTop", "Live-swap shirt/top: vlTop <npcId> <index> (0=none)", "setTop", VLConsole)
    addConsoleCommand("vlTopColor", "Live-swap shirt/top color: vlTopColor <npcId> <index>", "setTopColor", VLConsole)
    addConsoleCommand("vlBottoms", "List pants/bottom items: vlBottoms <npcId>", "listBottoms", VLConsole)
    addConsoleCommand("vlBottom", "Live-swap pants/bottom: vlBottom <npcId> <index> (0=none)", "setBottom", VLConsole)
    addConsoleCommand("vlBottomColor", "Live-swap pants/bottom color: vlBottomColor <npcId> <index>", "setBottomColor", VLConsole)
    addConsoleCommand("vlOnepieces", "List onepiece/jumper items: vlOnepieces <npcId>", "listOnepieces", VLConsole)
    addConsoleCommand("vlOnepiece", "Live-swap onepiece: vlOnepiece <npcId> <index> (0=none)", "setOnepiece", VLConsole)
    addConsoleCommand("vlOnepieceColor", "Live-swap onepiece color: vlOnepieceColor <npcId> <index>", "setOnepieceColor", VLConsole)
    addConsoleCommand("vlGloves", "List glove items: vlGloves <npcId>", "listGloves", VLConsole)
    addConsoleCommand("vlGlove", "Live-swap gloves: vlGlove <npcId> <index> (0=none)", "setGloves", VLConsole)
    addConsoleCommand("vlGlovesColor", "Live-swap gloves color: vlGlovesColor <npcId> <index>", "setGlovesColor", VLConsole)
    addConsoleCommand("vlGlasses", "List glasses/sunglasses items: vlGlasses <npcId>", "listGlasses", VLConsole)
    addConsoleCommand("vlGlass", "Live-swap glasses/sunglasses: vlGlass <npcId> <index> (0=none)", "setGlasses", VLConsole)
    addConsoleCommand("vlGlassesColor", "Live-swap glasses color: vlGlassesColor <npcId> <index>", "setGlassesColor", VLConsole)
    addConsoleCommand("vlHats", "List headgear/hat items: vlHats <npcId>", "listHats", VLConsole)
    addConsoleCommand("vlHat", "Live-swap hat/headgear: vlHat <npcId> <index> (0=none)", "setHat", VLConsole)
    addConsoleCommand("vlHatColor", "Live-swap hat color: vlHatColor <npcId> <index>", "setHatColor", VLConsole)
    addConsoleCommand("vlFootwears", "List all footwear: vlFootwears <npcId>", "listFootwears", VLConsole)
    addConsoleCommand("vlShoes", "List shoe-like footwear: vlShoes <npcId>", "listShoes", VLConsole)
    addConsoleCommand("vlSocks", "List sock-like footwear + facegear: vlSocks <npcId>", "listSocks", VLConsole)
    addConsoleCommand("vlShoe", "Live-swap shoes/footwear: vlShoe <npcId> <index> (0=none)", "setShoe", VLConsole)
    addConsoleCommand("vlShoeColor", "Live-swap shoe color: vlShoeColor <npcId> <index>", "setShoeColor", VLConsole)
    addConsoleCommand("vlSock", "Live-swap socks (facegear or footwear): vlSock <npcId> <index>", "setSock", VLConsole)
    addConsoleCommand("vlSockColor", "Live-swap sock color: vlSockColor <npcId> <index>", "setSockColor", VLConsole)
    addConsoleCommand("vlFacegears", "List facegear (empty in base FS25): vlFacegears <npcId>", "listFacegears", VLConsole)
    addConsoleCommand("vlFacegear", "Facegear slot (empty in base FS25): vlFacegear <npcId> <index>", "setFacegear", VLConsole)
    addConsoleCommand("vlFacegearColor", "Facegear color (empty in base FS25): vlFacegearColor <npcId> <index>", "setFacegearColor", VLConsole)
    print("[ValleyLife] Console commands registered (vlPos ... vlHatColor, vlFootwears, vlShoe, vlSock, vlFacegear, ...).")
end

-- ESC-map "Visit" on an NPC hotspot calls Player:teleportToNPC, which sends the player to GRANDPA's
-- static spawn (R37+). Hook it: when the NPC is our walking Walter, redirect the player to his LIVE
-- position via teleportTo. Also log teleportTo's args (to confirm its signature). Other NPCs and idle
-- Walter fall through to the original.
do
    local P = _G["Player"]
    if type(P) == "table" then
        if type(P.teleportToNPC) == "function" then
            local orig = P.teleportToNPC
            P.teleportToNPC = function(self, npc, ...)
                local ww = g_valleyLife and g_valleyLife.walterWalker
                local isWalter = ww ~= nil and ww.grandpa ~= nil and npc == ww.grandpa
                if isWalter and ww._active and type(self.teleportTo) == "function" then
                    -- Land a couple meters in front of him (his facing), not inside his model.
                    local off = (VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.visitOffset) or 2.0
                    local ry  = ww._ry or 0
                    local tx  = ww._wx + math.sin(ry) * off
                    local tz  = ww._wz + math.cos(ry) * off
                    if pcall(function() self:teleportTo(tx, ww._wy, tz) end) then return end
                end
                return orig(self, npc, ...)
            end
        end
        print("[ValleyLife] Hooked Player.teleportToNPC (Visit -> live Walter position).")
    else
        print("[ValleyLife] Player class not found; Visit redirect skipped.")
    end
end

print("[ValleyLife] Valley Life 0.1.0.48 loaded; lifecycle hooks installed.")
