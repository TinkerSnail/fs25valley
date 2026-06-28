-- ValleyLife: social and narrative layer for FS25.
-- Entry point - sources all modules in dependency order, hooks mission lifecycle.

local modDir = g_currentModDirectory
g_valleyLifeModDir = modDir   -- exposed for runtime file loads (e.g. the rightArm IK chain xml)

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
source(modDir .. "src/content/Walter.lua")  -- Walter casual/time-of-day lines (grandpa)

-- Post-tour beat: hooks GuidedTour.finish/cancel to introduce Marta + the market.
source(modDir .. "src/content/WalterIntro.lua")
source(modDir .. "src/content/WalterCowsIntro.lua")  -- one-time cow/husbandry handoff near the barn

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
    -- Pump the physical line-follower + path recorder + the daily truck schedule (all on the global VLConsole).
    if VLConsole ~= nil then
        if VLConsole.driveTick ~= nil then pcall(VLConsole.driveTick, dt) end
        if VLConsole.recordTick ~= nil then pcall(VLConsole.recordTick, dt) end
        if VLConsole.truckScheduleTick ~= nil then pcall(VLConsole.truckScheduleTick, dt) end
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

-- Capture a world pose for vlPos / vlWalterAddWp. Returns x, y, z, ry, source.
-- IMPORTANT: while you're SEATED in a vehicle, the on-foot player node parks at the ORIGIN (0,0,0) — that
-- is why vlPos used to log (0,0). So if you're in a vehicle, capture the VEHICLE's pose instead. This makes
-- capturing a DRIVING route work: drive the truck along the path and tag points from the truck itself.
function VLConsole.capturePose()
    -- Prefer the vehicle you're currently in (driving the route IS the route).
    local veh = g_localPlayer and g_localPlayer.getCurrentVehicle and g_localPlayer:getCurrentVehicle() or nil
    if veh ~= nil and veh.rootNode ~= nil and veh.rootNode ~= 0 and entityExists(veh.rootNode) then
        local x, y, z = getWorldTranslation(veh.rootNode)
        local _, ry, _ = getWorldRotation(veh.rootNode)
        return x, y, z, ry, "vehicle"
    end
    -- On foot: FS25 builds vary on where the player node lives, so try them all.
    local p1 = g_localPlayer
    local p2 = g_currentMission ~= nil and g_currentMission.player or nil
    for _, p in ipairs({ p1, p2 }) do
        if p ~= nil then
            for _, n in ipairs({ p.rootNode,
                                 p.graphicsComponent and p.graphicsComponent.graphicsRootNode or nil,
                                 p.positionNode }) do
                if n ~= nil and n ~= 0 and entityExists(n) then
                    local x, y, z = getWorldTranslation(n)
                    local _, ry, _ = getWorldRotation(n)
                    return x, y, z, ry, "player"
                end
            end
        end
    end
    return nil
end

function VLConsole:printPlayerPos()
    local x, y, z, ry, src = VLConsole.capturePose()
    if x == nil then
        local msg = "[ValleyLife] vlPos: no player/vehicle node found."
        print(msg)
        return msg
    end
    local msg = string.format(
        "[ValleyLife] vlPos -> { x = %.2f, y = %.2f, z = %.2f, ry = %.4f } (%s)",
        x, y, z, ry, src)
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
    local lid = string.lower(tostring(npcId or "marta"))
    local charSet
    if lid == "grandpa" or lid == "walter" then
        local ww = g_valleyLife.walterWalker  -- Walter's charSet lives on the walker, not g_valleyLife.npcs
        charSet = ww and ww.animCharSet
    else
        local npc = g_valleyLife.npcs[npcId or "marta"]
        if npc == nil then return "[ValleyLife] NPC not found." end
        charSet = npc.animCharSet
    end
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

-- vlWalterSay: show Walter's current time-of-day line (morning/midday/evening/night) in the speech
-- box — for previewing/iterating his dialog. Cycles the bucket; no first-meet/already-talked gating.
function VLConsole:walterSay()
    if g_valleyLife == nil or g_valleyLife.casualDialogue == nil then
        return "[ValleyLife] casual dialogue unavailable."
    end
    local text = g_valleyLife.casualDialogue:pickTimeOfDayLine("grandpa")
    if text == nil then return "[ValleyLife] No Walter line for this time of day (check Walter.lua)." end
    if g_valleyLife.dialog then g_valleyLife.dialog:showSpeechBox("Walter", text, nil) end
    return "[ValleyLife] Walter: " .. text
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

-- vlWalterNight: force the occasional night woodshop visit now (reveal at door -> lit shed -> back
-- inside) for testing, without waiting for the random ~10pm roll.
function VLConsole:walterNight()
    if g_valleyLife == nil or g_valleyLife.walterWalker == nil then
        return "[ValleyLife] WalterWalker unavailable."
    end
    local ok = g_valleyLife.walterWalker:_startNightWoodshop(VLConfig.WALTER_WALK)
    return ok and "[ValleyLife] Walter night woodshop visit triggered."
        or "[ValleyLife] nightWoodshop loop missing/unrunnable (check NPCConfig)."
end

-- vlWalterRig: RESEARCH SPIKE for the handtool-HOLDER build. The game's handtool system attaches a tool
-- to `carryingPlayer.graphicsComponent.model.thirdPersonRightHandNode` and drives it via the carrier's
-- methods (setCurrentHandTool/getIsControlled/...). This dumps what GRANDPA's LIVE object already exposes
-- vs. what a carrier adapter must provide. Read-only. Ground-truth the surface before writing the adapter.
function VLConsole:walterRig()
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local g = ww.grandpa
    if g == nil then pcall(function() ww:_acquireNode() end); g = ww.grandpa end
    if g == nil then return "[ValleyLife] GRANDPA object not available (is he spawned/active?)." end

    local function nodeInfo(label, node)
        if node == nil then print(string.format("[Rig] %-30s = nil", label)); return end
        local ok = entityExists(node)
        print(string.format("[Rig] %-30s = node %s exists=%s name=%s", label, tostring(node),
            tostring(ok), ok and (getName(node) or "?") or "(dead)"))
    end
    local function fieldInfo(label, v)
        print(string.format("[Rig] %-30s = %s", label, type(v) == "function" and "function ✓" or tostring(v)))
    end

    local pg = g.playerGraphics or g.graphicsComponent
    print(string.format("[Rig] grandpa.playerGraphics/graphicsComponent = %s", tostring(pg)))
    local model = pg and pg.model
    print(string.format("[Rig] model (pg.model)                = %s", tostring(model)))
    if model ~= nil then
        nodeInfo("model.thirdPersonRightHandNode", model.thirdPersonRightHandNode)
        nodeInfo("model.thirdPersonLeftHandNode",  model.thirdPersonLeftHandNode)
        nodeInfo("model.thirdPersonHeadNode",      model.thirdPersonHeadNode)
        nodeInfo("model.thirdPersonSpineNode",     model.thirdPersonSpineNode)
        nodeInfo("model.skeleton",                 model.skeleton)
        fieldInfo("model.getSkeletonNode",         model.getSkeletonNode)
    end

    -- IK chains = the arm-extend "hold" mechanism. rightArm/leftArm/feet/spine are DELETED for the local
    -- player (isRealPlayer) but KEPT for NPCs — so Walter should have rightArm. Confirm it live.
    local ik = model and model.ikChains
    print(string.format("[Rig] model.ikChains = %s", tostring(ik)))
    if type(ik) == "table" then
        local keys = {}
        for k in pairs(ik) do keys[#keys + 1] = tostring(k) end
        print("[Rig] ikChains keys: " .. (next(ik) and table.concat(keys, ", ") or "(empty)"))
        print("[Rig] rightArm chain present = " .. tostring(ik.rightArm ~= nil) ..
              "  leftArm = " .. tostring(ik.leftArm ~= nil))
    end

    print("[Rig] ---- carrier surface the handtool expects on carryingPlayer ----")
    fieldInfo("grandpa.graphicsComponent",         g.graphicsComponent)
    fieldInfo("grandpa.carriedHandTools",          g.carriedHandTools)
    fieldInfo("grandpa.currentHandTool",           g.currentHandTool)
    fieldInfo("grandpa.setCurrentHandTool",        g.setCurrentHandTool)
    fieldInfo("grandpa.getIsControlled",           g.getIsControlled)
    fieldInfo("grandpa.getForceHandToolFirstPerson", g.getForceHandToolFirstPerson)
    fieldInfo("grandpa.targeter",                  g.targeter)
    fieldInfo("grandpa.camera",                    g.camera)
    return "[ValleyLife] dumped GRANDPA rig/carrier surface — see [Rig] log lines."
end

-- vlNpcDump: survey the base-game NPC roster (g_npcManager) for HOOKABILITY — the same surface we already
-- drive on GRANDPA (Walter). No arg = one summary line per roster NPC; <NAME> = full detail for one.
-- Roster names are from data/maps/maps_npcs.xml: GRANDPA, FORESTER, FARMER, HELPER, ANIMAL_DEALER, FISHERMAN.
-- ANIMAL_DEALER = Katie (livestock NPC). Confirms whether she's spawned/active and carries the drivable
-- playerM rig + a conversation we can extend ADDITIVELY — exactly like Walter. Friendly aliases accepted.
VLConsole.NPC_ROSTER = { "GRANDPA", "FORESTER", "FARMER", "HELPER", "ANIMAL_DEALER", "FISHERMAN" }
VLConsole.NPC_ALIAS  = { WALTER = "GRANDPA", KATIE = "ANIMAL_DEALER", BEN = "HELPER", NOAH = "FORESTER" }

function VLConsole:npcDump(name)
    if g_npcManager == nil then return "[ValleyLife] g_npcManager unavailable (not in a loaded career?)." end

    local function rigOf(npc)
        local pg = npc and (npc.playerGraphics or npc.graphicsComponent)
        return pg, pg and pg.model
    end

    local function summary(nm)
        local npc = g_npcManager:getNPCByName(nm)
        if npc == nil then print(string.format("[NPC] %-14s = (not in g_npcManager)", nm)); return end
        local nodeOK     = npc.node ~= nil and entityExists(npc.node)
        local _, model   = rigOf(npc)
        local hasRig     = model ~= nil and model.thirdPersonRightHandNode ~= nil
        local ik         = model and model.ikChains
        local hasArm     = type(ik) == "table" and ik.rightArm ~= nil
        print(string.format(
            "[NPC] %-14s active=%-5s node=%-5s rig=%-5s rightArmIK=%-5s hotspot=%-5s trigger=%-5s inConvo=%-5s pos=(%.0f,%.0f,%.0f)",
            nm, tostring(npc.isActive), tostring(nodeOK), tostring(hasRig), tostring(hasArm),
            tostring(npc.mapHotspot ~= nil), tostring(npc.interactionTriggerNode ~= nil),
            tostring(npc.isInConversation), npc.x or 0, npc.y or 0, npc.z or 0))
    end

    if name == nil or name == "" then
        print("[ValleyLife] ---- base-game NPC roster: hookability survey (compare each against GRANDPA) ----")
        for _, nm in ipairs(VLConsole.NPC_ROSTER) do summary(nm) end
        return "[ValleyLife] roster surveyed — see [NPC] lines. Detail one: vlNpcDump <NAME> (e.g. vlNpcDump katie)."
    end

    local nm  = string.upper(tostring(name))
    nm        = VLConsole.NPC_ALIAS[nm] or nm
    local npc = g_npcManager:getNPCByName(nm)
    if npc == nil then
        return string.format("[ValleyLife] '%s' not found. Roster: %s", nm, table.concat(VLConsole.NPC_ROSTER, ", "))
    end

    print(string.format("[ValleyLife] ---- %s detail ----", nm))
    print(string.format("  isActive=%s  node=%s exists=%s  pos=(%.2f,%.2f,%.2f)",
        tostring(npc.isActive), tostring(npc.node), tostring(npc.node ~= nil and entityExists(npc.node)),
        npc.x or 0, npc.y or 0, npc.z or 0))

    local pg, model = rigOf(npc)
    print(string.format("  playerGraphics/graphicsComponent=%s  model=%s", tostring(pg), tostring(model)))
    if model ~= nil then
        local function nodeInfo(label, node)
            print(string.format("    %-28s = %s", label, node == nil and "nil"
                or string.format("node %s exists=%s", tostring(node), tostring(entityExists(node)))))
        end
        nodeInfo("thirdPersonRightHandNode", model.thirdPersonRightHandNode)
        nodeInfo("thirdPersonLeftHandNode",  model.thirdPersonLeftHandNode)
        nodeInfo("skeleton",                 model.skeleton)
        local ik = model.ikChains
        print(string.format("    ikChains=%s  rightArm=%s leftArm=%s", tostring(ik),
            tostring(type(ik) == "table" and ik.rightArm ~= nil),
            tostring(type(ik) == "table" and ik.leftArm ~= nil)))
    end
    print(string.format("  mapHotspot=%s  interactionTriggerNode=%s  spot=%s",
        tostring(npc.mapHotspot), tostring(npc.interactionTriggerNode), tostring(npc.spot)))

    -- Discover the conversation/dialog surface WITHOUT guessing exact names — scan keys.
    print("  -- npc keys matching convers/dialog/talk/speak/greet (the additive-dialog hook surface) --")
    for k, v in pairs(npc) do
        local lk = string.lower(tostring(k))
        if lk:find("convers") or lk:find("dialog") or lk:find("talk") or lk:find("speak") or lk:find("greet") then
            print(string.format("    .%s = %s (%s)", k, tostring(v), type(v)))
        end
    end
    return string.format("[ValleyLife] dumped %s — same hookable surface as GRANDPA ⇒ extend additively like Walter.", nm)
end

-- vlWalterArmIK: BUILD PROBE — load + drive the base-game rightArm IK chain on Walter so his arm extends
-- to hold a tool out (the real MP mechanism; the engine strips this chain from NPCs). Usage: vlWalterArmIK <on|off>.
function VLConsole:walterArmIK(arg)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local on = not (arg ~= nil and (tostring(arg) == "0" or string.lower(tostring(arg)) == "off"))
    local ok = ww:setArmIK(on)
    return string.format("[ValleyLife] rightArm IK %s%s — watch his arm + the [ArmIK] log.",
        on and "ON" or "OFF", ok and "" or " (setArmIK failed — see log)")
end

-- vlArmTarget / vlArmTargetRot: live-tune the rightArm IK target (vlWalterArmIK must be on). Position 5cm/tap,
-- rotation 15deg/tap. Dial his arm to hold the flashlight out front, then bake _armIKTargetPos/Rot.
function VLConsole:armTarget(dir)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil or ww.nudgeArmTarget == nil then return "[ValleyLife] WalterWalker unavailable." end
    local p = ww:nudgeArmTarget(dir, false)
    if p == nil then return "[ValleyLife] usage: vlArmTarget <x+|x-|y+|y-|z+|z->" end
    return string.format("[ValleyLife] arm IK target pos (%.3f, %.3f, %.3f)", p.x, p.y, p.z)
end
function VLConsole:armTargetRot(dir)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil or ww.nudgeArmTarget == nil then return "[ValleyLife] WalterWalker unavailable." end
    local r = ww:nudgeArmTarget(dir, true)
    if r == nil then return "[ValleyLife] usage: vlArmTargetRot <x+|x-|y+|y-|z+|z-|0>" end
    return string.format("[ValleyLife] arm IK target rot deg(%.0f, %.0f, %.0f)", math.deg(r.x), math.deg(r.y), math.deg(r.z))
end

-- vlWalterHoldFlashlight: BUILD PROBE — give Walter a REAL flashlight `HandTool` through the game's own
-- loader (`HandToolLoadingData`) and attach it with the real `attachToolToHand`, instead of our hand-rolled
-- i3d link. Carrier = a thin adapter exposing GRANDPA's `playerGraphics` (its `.model` already has the
-- thirdPerson hand nodes — confirmed by vlWalterRig). v1: spawn -> setCarryingPlayer -> attach to LEFT hand
-- -> light on. Heavy logging + pcall so the [HoldFlash] log shows exactly where it stands. Additive: does
-- not touch the existing auto-flashlight.
function VLConsole:walterHoldFlashlight()
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local g = ww.grandpa
    if g == nil then pcall(function() ww:_acquireNode() end); g = ww.grandpa end
    local pg = g and g.playerGraphics
    if pg == nil or pg.model == nil then return "[ValleyLife] GRANDPA model not ready (is he spawned/active?)." end
    if HandToolLoadingData == nil then return "[ValleyLife] HandToolLoadingData global missing." end

    -- Thin carryingPlayer adapter: just enough surface for attachToolToHand + the flashlight's updateTransform.
    local carrier = {
        graphicsComponent = pg,                 -- pg.model = HumanModel (thirdPerson*Node + getModelYaw)
        isOwner           = false,
        camera            = { isFirstPerson = false },
    }
    function carrier:getIsControlled() return false end
    function carrier:getForceHandToolFirstPerson() return false end
    function carrier:setCurrentHandTool() end
    ww._htCarrier = carrier

    -- HandToolLoadingData:setFilename does fileExists() on the path, so $data must be RESOLVED first
    -- (the bare "$data/..." symbol isn't expanded by fileExists — that was the v1 failure). Resolve it
    -- like HandToolHolder does (Utils.getFilename), and guard so a miss doesn't crash data:load.
    local raw = "$data/handTools/brandless/flashlight/flashlight.xml"
    local resolved = (Utils and Utils.getFilename) and Utils.getFilename(raw, nil) or raw
    print(string.format("[ValleyLife][HoldFlash] config raw=%s resolved=%s exists=%s",
        raw, tostring(resolved), tostring(fileExists(resolved))))
    if not fileExists(resolved) then
        return "[ValleyLife] flashlight handtool config not found at " .. tostring(resolved) .. " — see [HoldFlash] log."
    end
    local data = HandToolLoadingData.new()
    data:setFilename(resolved)
    pcall(function() data:setOwnerFarmId(g.ownerFarmId or 1) end)
    data:setIsRegistered(false)
    data:load(function(_, handTool, loadingState)
        if handTool == nil then
            print("[ValleyLife][HoldFlash] LOAD FAILED state=" .. tostring(loadingState)); return
        end
        ww._htFlashlight = handTool
        print(string.format("[ValleyLife][HoldFlash] loaded handtool=%s handNode=%s root=%s",
            tostring(handTool), tostring(handTool.handNode), tostring(handTool.rootNode)))
        handTool.useLeftHand = false   -- authored grip is for the RIGHT hand; left mirrors → backwards/forearm
        pcall(function() handTool:setCarryingPlayer(carrier) end)
        handTool.isHeld = true
        local ok, err = pcall(function() handTool:attachToolToHand() end)
        print(string.format("[ValleyLife][HoldFlash] attachToolToHand ok=%s err=%s", tostring(ok), tostring(err)))
        -- attachToolToHand only LINKS the tool; visibility is normally flipped by attachTool/setHolder,
        -- which we bypassed. Show the whole tool subtree (root-only wasn't enough for the flashlight in
        -- the hand-rolled version — it needs to be recursive).
        local function showTree(node)
            if node == nil or not entityExists(node) then return end
            setVisibility(node, true)
            for i = 0, getNumOfChildren(node) - 1 do showTree(getChildAt(node, i)) end
        end
        if handTool.rootNode ~= nil then showTree(handTool.rootNode) end
        local par = handTool.rootNode and getParent(handTool.rootNode)
        print(string.format("[ValleyLife][HoldFlash] vis-set; rootParent=%s (%s)",
            tostring(par), par and getName(par) or "?"))
        pcall(function() handTool:setFlashlightIsActive(true, true) end)   -- light on so it's easy to spot
    end, ww)

    return "[ValleyLife] spawning a REAL flashlight handtool + attaching to his LEFT hand — watch the [HoldFlash] log and his hand."
end

-- vlWalterBones: RESEARCH SPIKE — recursively dump GRANDPA's node/skeleton tree (name + id + depth)
-- so we can find an addressable HAND bone to attach a hand prop (e.g. a flashlight) to. Read-only.
-- Look at the [Bones] log lines, especially the "candidate HAND nodes" summary at the end.
function VLConsole:walterBones()
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local root = ww.graphicsNode
    if root == nil or not entityExists(root) then
        pcall(function() ww:_acquireNode() end)  -- try once more
        root = ww.graphicsNode
    end
    if root == nil or not entityExists(root) then
        return "[ValleyLife] Walter graphicsRootNode not available (is he spawned/active?)."
    end

    local count, MAX = 0, 800
    local hands = {}
    local function walk(node, depth, path)
        if count >= MAX or node == nil or not entityExists(node) then return end
        local name = getName(node) or "?"
        print(string.format("[Bones]%s%s  (id=%s)", string.rep("  ", depth), name, tostring(node)))
        count = count + 1
        local lname = string.lower(name)
        if lname:find("hand") or lname:find("wrist") or lname:find("palm") or lname:find("finger") then
            table.insert(hands, path .. "/" .. name .. "  (id=" .. tostring(node) .. ")")
        end
        local n = getNumOfChildren(node)
        for i = 0, n - 1 do
            walk(getChildAt(node, i), depth + 1, path .. "/" .. name)
        end
    end
    walk(root, 0, "")

    print("[Bones] ===== candidate HAND nodes (hand/wrist/palm/finger) =====")
    if #hands == 0 then
        print("[Bones] (none matched — scan the full tree above for the right bone)")
    else
        for _, h in ipairs(hands) do print("[Bones] " .. h) end
    end
    return string.format("[ValleyLife] dumped %d nodes; %d hand candidate(s). See log [Bones] lines.",
        count, #hands)
end

-- vlPedSplinesShow: toggle a colored debug overlay over the base-game PEDESTRIAN walk splines (the
-- `pedestrianSystem` group in mapUS.i3d, authored visibility=false). There is NO base-game command for
-- this (only roads have gsAISplinesShow), so we mirror exactly how gsAISplinesShow draws the road net:
-- a per-spline DebugSpline added to g_debugManager (AISystem.lua:658). Read-only — it only draws.
-- The [PedSpline] log lines give each spline's name + start position + length so we can map a loop to a
-- town location (e.g. pick the one nearest Walter's woodshop / Marta's office) for spline-driven routes.
VLConsole.PED_SPLINE_DBG_GROUP = "VLPedestrianSplines"
VLConsole._pedSplinesShown = false
VLConsole._pedSplineNodes = nil
VLConsole._pedSplineGroup = nil

function VLConsole:pedSplinesShow()
    -- toggle OFF
    if VLConsole._pedSplinesShown then
        pcall(function() g_debugManager:removeGroup(VLConsole.PED_SPLINE_DBG_GROUP) end)
        for _, s in ipairs(VLConsole._pedSplineNodes or {}) do
            if entityExists(s) then setVisibility(s, false) end
        end
        if VLConsole._pedSplineGroup ~= nil and entityExists(VLConsole._pedSplineGroup) then
            setVisibility(VLConsole._pedSplineGroup, false)
        end
        VLConsole._pedSplinesShown = false
        VLConsole._pedSplineNodes = nil
        VLConsole._pedSplineGroup = nil
        return "[ValleyLife] pedestrian splines: OFF"
    end

    -- find the 'pedestrianSystem' group by NAME from the scene root (node ids change every session)
    local function findByName(node, name)
        if node == nil or not entityExists(node) then return nil end
        if getName(node) == name then return node end
        for i = 0, getNumOfChildren(node) - 1 do
            local f = findByName(getChildAt(node, i), name)
            if f then return f end
        end
        return nil
    end

    local group = findByName(getRootNode(), "pedestrianSystem")
    if group == nil then
        return "[ValleyLife] Could not find the 'pedestrianSystem' group in the scene (map not loaded yet?)."
    end

    -- collect the spline children (filter by getIsSpline, fall back to a name match)
    local splines = {}
    for i = 0, getNumOfChildren(group) - 1 do
        local child = getChildAt(group, i)
        local isSpline = false
        pcall(function() isSpline = I3DUtil.getIsSpline(child) end)
        if not isSpline and (getName(child) or ""):find("[Ss]pline") then isSpline = true end
        if isSpline then table.insert(splines, child) end
    end
    if #splines == 0 then
        return "[ValleyLife] 'pedestrianSystem' found but it has no spline children."
    end

    -- the parent group is authored invisible → reveal it so the ribbon meshes can render too
    pcall(function() setVisibility(group, true) end)

    for _, spline in ipairs(splines) do
        local r, g, b = 1, 1, 0
        pcall(function() r, g, b = DebugUtil.getDebugColor(spline):unpack() end)
        -- engine-blessed spline overlay — identical pattern to gsAISplinesShow (AISystem.lua:658)
        pcall(function()
            local ds = DebugSpline.new():createWithNode(spline):setColorRGBA(r, g, b):setClipDistance(250)
            g_debugManager:addElement(ds, VLConsole.PED_SPLINE_DBG_GROUP)
        end)
        pcall(function() setVisibility(spline, true) end)

        local nm = getName(spline) or "?"
        local sx, _, sz, len = 0, 0, 0, 0
        pcall(function() sx, _, sz = getSplinePosition(spline, 0) end)
        pcall(function() len = getSplineLength(spline) end)
        print(string.format("[PedSpline] %-26s start=(%.1f, %.1f)  len=%.1fm", nm, sx, sz, len))
    end

    VLConsole._pedSplineNodes = splines
    VLConsole._pedSplineGroup = group
    VLConsole._pedSplinesShown = true
    return string.format(
        "[ValleyLife] pedestrian splines: ON — %d splines overlaid (see [PedSpline] log for names/positions). Run again to hide.",
        #splines)
end

-- vlWalterFlashlight: force Walter's flashlight ON/OFF, or 'auto' to resume the seasonal-dusk rule.
function VLConsole:walterFlashlight(arg)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    if arg == nil or string.lower(tostring(arg)) == "auto" then
        ww._flashlightForce = nil
        return "[ValleyLife] flashlight: AUTO (on while walking after the seasonal dusk hour)."
    end
    local a  = string.lower(tostring(arg))
    local on = (a == "1" or a == "on" or a == "true")
    ww._flashlightForce = on
    local ok = ww:_setFlashlight(on)
    return string.format("[ValleyLife] flashlight forced %s%s (vlWalterFlashlight auto to release).",
        on and "ON" or "OFF", ok and "" or " — but _setFlashlight failed (see log)")
end

-- vlWalterFlashlightPose: live-tune the flashlight's POSITION in his hand (rotation stays the auto
-- grip orientation from handNode, which is already correct). Usage: vlWalterFlashlightPose <x> <y> <z>
function VLConsole:walterFlashlightPose(x, y, z)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil or ww._flashlightNode == nil then
        return "[ValleyLife] flashlight not loaded yet — force it on first: vlWalterFlashlight 1"
    end
    local px, py, pz = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
    pcall(function() setTranslation(ww._flashlightNode, px, py, pz) end)  -- position only; rotation untouched
    local fc = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.flashlight
    if fc then fc.offset = { x = px, y = py, z = pz } end
    return string.format("[ValleyLife] flashlight offset (%.3f, %.3f, %.3f) — bake into NPCConfig.flashlight.offset.",
        px, py, pz)
end

-- vlFlash: dead-simple 1cm nudger for seating the flashlight in Walter's hand without typing decimals.
-- Usage: vlFlash x+   (or x-, y+, y-, z+, z-). No arg = print current offset. Live; prints the offset.
function VLConsole:flashNudge(dir)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil or ww._flashlightNode == nil then
        return "[ValleyLife] flashlight not loaded — run vlWalterFlashlight 1 first."
    end
    local fc = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.flashlight
    if fc == nil then return "[ValleyLife] no flashlight config." end
    local o = fc.offset or { x = 0, y = 0, z = 0 }
    o.x, o.y, o.z = o.x or 0, o.y or 0, o.z or 0
    local step = 0.01
    dir = string.lower(tostring(dir or ""))
    if     dir == "x+" then o.x = o.x + step
    elseif dir == "x-" then o.x = o.x - step
    elseif dir == "y+" then o.y = o.y + step
    elseif dir == "y-" then o.y = o.y - step
    elseif dir == "z+" then o.z = o.z + step
    elseif dir == "z-" then o.z = o.z - step
    elseif dir ~= "" then
        return "[ValleyLife] usage: vlFlash x+ (or x- y+ y- z+ z-). 1cm steps."
    end
    fc.offset = o
    pcall(function() setTranslation(ww._flashlightNode, o.x, o.y, o.z) end)
    return string.format("[ValleyLife] flashlight offset (%.3f, %.3f, %.3f)", o.x, o.y, o.z)
end

-- vlPose: pose a finger/thumb independently, 10deg per tap, optionally ONE joint at a time. Usage:
--   vlPose <thumb|index|middle|ring|pinky> [joint 1-3] <x+|x-|y+|y-|z+|z-|0>
--   (short digit: t/i/m/r/p; joint omitted = all 3 joints; joint 1=knuckle..3=tip; 0 = reset)
function VLConsole:pose(digit, a, b)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local map = { t = "thumb", i = "index", m = "middle", r = "ring", p = "pinky",
                  thumb = "thumb", index = "index", middle = "middle", ring = "ring", pinky = "pinky",
                  shoulder = "shoulder", arm = "arm", upperarm = "arm",
                  forearm = "forearm", elbow = "forearm", wrist = "wrist", hand = "wrist" }
    local name = map[string.lower(tostring(digit or ""))]
    if name == nil then
        return "[ValleyLife] usage: vlPose <thumb|index|middle|ring|pinky|shoulder|arm|forearm|wrist> [1-3] <x+|x-|y+|y-|z+|z-|0>"
    end
    -- Optional joint number as the 2nd token; otherwise the 2nd token is the direction (all joints).
    local joint, dir
    local jn = tonumber(a)
    if jn ~= nil and jn >= 1 and jn <= 3 then joint, dir = math.floor(jn), b else joint, dir = nil, a end
    dir = string.lower(tostring(dir or ""))
    local step = math.rad(10)
    local axis, sign
    if     dir == "x+" then axis, sign = "x",  1
    elseif dir == "x-" then axis, sign = "x", -1
    elseif dir == "y+" then axis, sign = "y",  1
    elseif dir == "y-" then axis, sign = "y", -1
    elseif dir == "z+" then axis, sign = "z",  1
    elseif dir == "z-" then axis, sign = "z", -1
    elseif dir == "0" or dir == "reset" then
        if ww:nudgeDigit(name, joint, "reset") == nil then return "[ValleyLife] couldn't resolve " .. name .. " bones." end
        return string.format("[ValleyLife] %s%s reset.", name, joint and (" joint " .. joint) or "")
    else
        return "[ValleyLife] usage: vlPose " .. name .. " [1-3] <x+|x-|y+|y-|z+|z-|0>"
    end
    local d = ww:nudgeDigit(name, joint, axis, sign * step)
    if d == nil then return "[ValleyLife] couldn't resolve " .. name .. " bones (is Walter spawned?)." end
    local bn = d.bones[joint or 1]
    return string.format("[ValleyLife] %s %s deg(%.0f, %.0f, %.0f)",
        name, joint and ("joint " .. joint) or "all (j1)", math.deg(bn.dx), math.deg(bn.dy), math.deg(bn.dz))
end

-- vlWalterFlashHand: move the flashlight to his left or right hand (left pairs with chainsaw_walk).
function VLConsole:walterFlashHand(side)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local s = string.lower(tostring(side or ""))
    local bone = (s == "left" or s == "l") and "LeftHand" or (s == "right" or s == "r") and "RightHand" or nil
    if bone == nil then return "[ValleyLife] usage: vlWalterFlashHand <left|right>" end
    local ok = ww:setFlashlightHand(bone)
    return string.format("[ValleyLife] flashlight -> %s%s. Re-tune offset with vlFlash.",
        bone, ok and "" or " (load/seat FAILED — see log)")
end

-- vlWalterReset: undo all live hand/arm posing + clip override + restore stop-and-face, in one shot.
function VLConsole:walterReset()
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    if ww._digits then
        for _, d in pairs(ww._digits) do
            if d.bones then
                for _, b in ipairs(d.bones) do pcall(function() setRotation(b.node, b.ox, b.oy, b.oz) end) end
            end
        end
        ww._digits = {}
    end
    ww._gripActive = false
    if ww.setClipOverride then ww:setClipOverride(nil) end  -- back to the normal walk clip
    local cfg = VLConfig.WALTER_WALK
    if cfg then cfg.approachRange = 4.0 end
    return "[ValleyLife] Walter reset: pose cleared, clip override off, stop-and-face restored (4 m)."
end

-- vlWalterApproach: live-set his stop-and-face range. 0 = OFF, so he keeps walking even when you
-- stand right next to him — lets you observe his hand up close while he's in the walking (skip-orig)
-- regime. Restore with vlWalterApproach 4.
function VLConsole:walterApproach(m)
    local cfg = VLConfig.WALTER_WALK
    if cfg == nil then return "[ValleyLife] no WALTER_WALK config." end
    local v = tonumber(m)
    if v == nil then
        return string.format("[ValleyLife] approachRange = %s m. Usage: vlWalterApproach <meters> (0 = stop-and-face OFF).",
            tostring(cfg.approachRange))
    end
    cfg.approachRange = v
    return string.format("[ValleyLife] approachRange = %.1f m%s.",
        v, (v <= 0) and " — stop-and-face OFF (he walks past you)" or "")
end

-- vlWalterClip: play a specific animation clip on Walter (by index from vlAnimClips, or by name) so
-- we can test tool-holding clips like chainsaw_walk. "off" clears it. Test while he's WALKING
-- (vlWalterNight) — idle re-poses over it. e.g. vlWalterClip 56  /  vlWalterClip chainsaw_walk
function VLConsole:walterClip(arg)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local cs = ww.animCharSet
    if cs == nil or cs == 0 then return "[ValleyLife] Walter animCharSet not ready (is he spawned?)." end
    if arg == nil or string.lower(tostring(arg)) == "off" then
        ww:setClipOverride(nil)
        return "[ValleyLife] clip override OFF (back to the normal walk/idle)."
    end
    local idx = tonumber(arg)
    if idx == nil then
        local q = string.lower(tostring(arg))
        for i = 0, 200 do
            local nm = nil
            pcall(function() nm = getAnimClipName(cs, i) end)
            if type(nm) == "string" and string.find(string.lower(nm), q, 1, true) then idx = i; break end
        end
        if idx == nil then return "[ValleyLife] no clip matching '" .. tostring(arg) .. "' (try an index from vlAnimClips grandpa)." end
    end
    ww:setClipOverride(math.floor(idx))
    local nm = nil; pcall(function() nm = getAnimClipName(cs, math.floor(idx)) end)
    return string.format("[ValleyLife] Walter clip override -> [%d] %s. Walk him (vlWalterNight) to see it.",
        math.floor(idx), tostring(nm))
end

-- vlFlashRot: rotate the flashlight 15deg/tap to aim the beam (on top of the auto grip rotation —
-- needed e.g. for the LEFT hand, whose axes are mirrored). Usage: vlFlashRot <x+|x-|y+|y-|z+|z-|0>
function VLConsole:flashRot(dir)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil or ww._flashlightNode == nil then
        return "[ValleyLife] flashlight not loaded — run vlWalterFlashlight 1 first."
    end
    local fc = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.flashlight
    if fc == nil then return "[ValleyLife] no flashlight config." end
    local r = fc.rot or { x = 0, y = 0, z = 0 }
    r.x, r.y, r.z = r.x or 0, r.y or 0, r.z or 0
    local step = math.rad(15)
    dir = string.lower(tostring(dir or ""))
    if     dir == "x+" then r.x = r.x + step
    elseif dir == "x-" then r.x = r.x - step
    elseif dir == "y+" then r.y = r.y + step
    elseif dir == "y-" then r.y = r.y - step
    elseif dir == "z+" then r.z = r.z + step
    elseif dir == "z-" then r.z = r.z - step
    elseif dir == "0" or dir == "reset" then r.x, r.y, r.z = 0, 0, 0
    else
        return "[ValleyLife] usage: vlFlashRot x+ (or x- y+ y- z+ z- 0). 15deg/tap, on top of the auto grip rotation."
    end
    fc.rot = r
    ww:_applyFlashlightRot()
    return string.format("[ValleyLife] flashlight rot adjust deg(%.0f, %.0f, %.0f)", math.deg(r.x), math.deg(r.y), math.deg(r.z))
end

-- vlPlayerFlashlight: while the PLAYER is holding a flashlight, find that node in the player's
-- hierarchy and report its parent bone + exact LOCAL transform — so we can copy how the player holds
-- it onto Walter verbatim. Read-only research spike.
function VLConsole:playerFlashlight()
    -- Discovery: surface any tool/hand/flashlight references on the player object (the held handtool
    -- lives there even if it's not under the body skeleton in first-person view).
    if g_localPlayer ~= nil then
        local keys = {}
        pcall(function()
            for k, v in pairs(g_localPlayer) do
                local lk = string.lower(tostring(k))
                if lk:find("tool") or lk:find("hand") or lk:find("flash") then
                    keys[#keys+1] = tostring(k) .. "(" .. type(v) .. ")"
                end
            end
        end)
        if #keys > 0 then print("[PlayerFlash] g_localPlayer fields: " .. table.concat(keys, ", ")) end
    end

    local roots = {}
    local function addRoot(n) if type(n) == "number" and n ~= 0 and entityExists(n) then roots[#roots+1] = n end end
    pcall(function() addRoot(g_localPlayer and g_localPlayer.rootNode) end)
    pcall(function() addRoot(g_localPlayer and g_localPlayer.graphicsComponent and g_localPlayer.graphicsComponent.graphicsRootNode) end)

    local matches = {}
    local function search(n, depth)
        if n == nil or n == 0 or not entityExists(n) or depth > 18 then return end
        local nm = nil; pcall(function() nm = getName(n) end)
        if nm and string.find(string.lower(nm), "flash") then matches[#matches+1] = n end
        local cn = 0; pcall(function() cn = getNumOfChildren(n) end)
        for i = 0, cn - 1 do
            local c = nil; pcall(function() c = getChildAt(n, i) end)
            search(c, depth + 1)
        end
    end
    for _, r in ipairs(roots) do search(r, 0) end

    if #matches == 0 then
        return "[ValleyLife] no 'flash' node under the player body. Switch to THIRD-PERSON camera while "
            .. "holding it (first-person attaches to the camera rig, not the body skeleton), then retry. "
            .. "See the [PlayerFlash] fields line above for the handtool object."
    end

    for _, found in ipairs(matches) do
        local lx, ly, lz, rx, ry, rz = 0, 0, 0, 0, 0, 0
        pcall(function() lx, ly, lz = getTranslation(found) end)
        pcall(function() rx, ry, rz = getRotation(found) end)
        local p, pName, nm = nil, "?", "?"
        pcall(function() nm = getName(found) end)
        pcall(function() p = getParent(found) end)
        if p then pcall(function() pName = getName(p) end) end
        print(string.format("[PlayerFlash] '%s' id=%s parent='%s' LOCAL pos(%.4f,%.4f,%.4f) rotDeg(%.2f,%.2f,%.2f)",
            tostring(nm), tostring(found), tostring(pName), lx, ly, lz, math.deg(rx), math.deg(ry), math.deg(rz)))
        local chain, cur, n = {}, p, 0
        while cur and n < 8 do
            local cnm = "?"; pcall(function() cnm = getName(cur) end)
            chain[#chain+1] = cnm
            local nxt = nil; pcall(function() nxt = getParent(cur) end)
            cur, n = nxt, n + 1
        end
        print("[PlayerFlash]   chain: " .. table.concat(chain, " <- "))
    end
    return string.format("[ValleyLife] found %d 'flash' node(s) under the player — see [PlayerFlash] log.", #matches)
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

-- vlShimmy: toggle the R49 body probe — logs grn/Hips/pin/spot each frame while Walter is talking.
function VLConsole:shimmyProbe(arg)
    local ww = g_valleyLife and g_valleyLife.walterWalker
    if ww == nil then return "[ValleyLife] WalterWalker unavailable." end
    local on = not (arg ~= nil and (tostring(arg) == "0" or string.lower(tostring(arg)) == "off"))
    ww._shimmyProbe = on
    ww._shimmyHips = nil
    ww._shimmyLast = nil
    return "[ValleyLife] Shimmy probe " .. (on
        and "ON — talk to Walter while he's paused on a route, then read the [Shimmy] lines in log.txt."
        or "OFF.")
end

-- vlDumpVehicle: dump the filename, uniqueId, class, and world position of the vehicle the player
-- is currently sitting in. Run while seated in Grandpa's truck to capture the data we need to
-- reference it at runtime for the Walter-drives-truck feature.
function VLConsole:dumpVehicle()
    local player = g_localPlayer
    if player == nil then return "[ValleyLife] no local player" end

    -- Try every known path to the controlled vehicle.
    local v = nil
    pcall(function() v = player:getCurrentVehicle() end)
    if v == nil then v = player.currentVehicle or player.vehicle end
    if v == nil then pcall(function() v = g_currentMission and g_currentMission.controlledVehicle end) end

    -- If still nil, scan player fields for anything that looks like a vehicle.
    if v == nil then
        print("[VL][Truck] currentVehicle=nil — scanning player fields for vehicle refs:")
        local found = {}
        pcall(function()
            for k, val in pairs(player) do
                local lk = string.lower(tostring(k))
                if lk:find("vehicle") or lk:find("enterable") or lk:find("driving") then
                    found[#found+1] = string.format("  .%s = %s (%s)", k, tostring(val), type(val))
                end
            end
        end)
        if #found > 0 then for _, f in ipairs(found) do print(f) end
        else print("  (no vehicle-like fields on g_localPlayer)") end
        -- Also check g_currentMission
        pcall(function()
            for k, val in pairs(g_currentMission) do
                local lk = string.lower(tostring(k))
                if lk:find("vehicle") or lk:find("controlled") then
                    print(string.format("  mission.%s = %s (%s)", k, tostring(val), type(val)))
                end
            end
        end)
        return "[VL][Truck] no vehicle found — check log for available fields"
    end

    local filename = tostring(v.configFileName or v.xmlFilename or v.filename or "?")
    local uid      = tostring(v.uniqueId or "?")
    local cls      = tostring(v.className or "?")
    local x, y, z, ry = 0, 0, 0, 0
    pcall(function()
        local root = v.components and v.components[1] and v.components[1].node
        if root and entityExists(root) then
            x, y, z = getWorldTranslation(root)
            local _, ry2 = getRotation(root); ry = ry2 or 0
        end
    end)
    print(string.format("[VL][Truck] filename: %s", filename))
    print(string.format("[VL][Truck] uniqueId: %s", uid))
    print(string.format("[VL][Truck] class:    %s", cls))
    print(string.format("[VL][Truck] pos:      x=%.3f y=%.3f z=%.3f ry=%.4f", x, y, z, ry))
    -- Configurations: paint, rims, license plate, etc.
    pcall(function()
        local cfgs = v.configurations
        if type(cfgs) == "table" then
            local out = {}
            for name, idx in pairs(cfgs) do
                out[#out+1] = string.format("%s=%s", tostring(name), tostring(idx))
            end
            table.sort(out)
            print("[VL][Truck] configurations: " .. (next(cfgs) and table.concat(out, ", ") or "(empty)"))
        else
            print("[VL][Truck] configurations: (field not a table: " .. type(cfgs) .. ")")
        end
        -- Try the getter too
        if type(v.getActiveConfiguration) == "function" then
            print("[VL][Truck] getActiveConfiguration exists")
        end
        -- License plate text
        local lp = v.spec_licensePlates
        if type(lp) == "table" then
            for k, val in pairs(lp) do
                local t = type(val)
                if t == "string" or t == "number" or t == "boolean" then
                    print(string.format("[VL][Truck] licensePlate.%s = %s", tostring(k), tostring(val)))
                end
            end
        end
    end)
    local specs = {}
    pcall(function()
        for k in pairs(v) do if type(k) == "string" and k:find("^spec_") then specs[#specs+1] = k end end
    end)
    if #specs > 0 then print("[VL][Truck] specs: " .. table.concat(specs, ", ")) end
    return string.format("[VL][Truck] done — filename=%s uid=%s pos=(%.1f,%.1f,%.1f)", filename, uid, x, y, z)
end

-- vlDumpTruck: probe spec_enterable, spec_aiDrivable, and spec_ikChains on Grandpa's truck.
-- Find the truck by uniqueId, then dump driver seat node, AI driver state, and IK chain info.
function VLConsole:dumpTruck()
    local TRUCK_UID = "vehiclea0e0823360da9410fb4db3ebcbbfc489"
    local truck = nil
    pcall(function()
        local vs = g_currentMission and g_currentMission.vehicleSystem
        if vs and vs.vehicles then
            for _, v in ipairs(vs.vehicles) do
                if tostring(v.uniqueId) == TRUCK_UID then truck = v break end
            end
        end
    end)
    if truck == nil then
        return "[VL][Truck] truck not found — is it loaded? (uniqueId=" .. TRUCK_UID .. ")"
    end
    print("[VL][Truck] found: " .. tostring(truck.configFileName or "?"))

    -- Helper: dump a table's keys (all types, truncated)
    local function dumpTable(prefix, tbl, maxDepth)
        if type(tbl) ~= "table" then
            print(prefix .. " = " .. type(tbl) .. ": " .. tostring(tbl)) return
        end
        local count = 0
        for k, v in pairs(tbl) do
            count = count + 1
            if count > 60 then print(prefix .. "  ...(truncated)") break end
            local t = type(v)
            if t == "userdata" then
                local ok, name = pcall(getName, v)
                local ox, oy, oz = 0, 0, 0
                pcall(function() ox, oy, oz = getWorldTranslation(v) end)
                if ok then
                    print(string.format("%s  .%s = NODE '%s' @ (%.2f,%.2f,%.2f)", prefix, tostring(k), name, ox, oy, oz))
                else
                    print(string.format("%s  .%s = userdata", prefix, tostring(k)))
                end
            elseif t == "function" then
                print(string.format("%s  .%s = function", prefix, tostring(k)))
            elseif t == "table" then
                print(string.format("%s  .%s = table", prefix, tostring(k)))
                if maxDepth and maxDepth > 0 then dumpTable(prefix .. "  [" .. tostring(k) .. "]", v, maxDepth - 1) end
            else
                print(string.format("%s  .%s = %s", prefix, tostring(k), tostring(v)))
            end
        end
        if count == 0 then print(prefix .. "  (empty)") end
    end

    -- spec_enterable
    pcall(function()
        local se = truck.spec_enterable
        print("[VL][Truck] spec_enterable (" .. type(se) .. "):")
        dumpTable("[VL][Truck][enterable]", se, 0)
    end)

    -- Top-level truck fields with "character", "driver", "seat", "enter" in key name
    pcall(function()
        print("[VL][Truck] truck fields matching character/driver/seat/enter:")
        for k, v in pairs(truck) do
            local lk = string.lower(tostring(k))
            if lk:find("character") or lk:find("driver") or lk:find("seat") or lk:find("enter") then
                local t = type(v)
                if t == "userdata" then
                    local ok, name = pcall(getName, v)
                    print(string.format("  .%s = NODE '%s'", k, ok and name or "?"))
                else
                    print(string.format("  .%s = %s: %s", k, t, tostring(v):sub(1,60)))
                end
            end
        end
    end)

    -- spec_aiDrivable
    pcall(function()
        local sad = truck.spec_aiDrivable
        print("[VL][Truck] spec_aiDrivable (" .. type(sad) .. "):")
        dumpTable("[VL][Truck][aiDriv]", sad, 0)
    end)

    -- spec_ikChains
    pcall(function()
        local sik = truck.spec_ikChains
        print("[VL][Truck] spec_ikChains (" .. type(sik) .. "):")
        dumpTable("[VL][Truck][ikChains]", sik, 1)
    end)

    -- Probe vehicleCharacter and the character node position
    pcall(function()
        local se = truck.spec_enterable
        if se == nil then return end

        -- defaultCharacterNode: where does the driver character sit?
        local cn = se.defaultCharacterNode
        if cn and entityExists(cn) then
            local wx, wy, wz = getWorldTranslation(cn)
            local name = getName(cn) or "?"
            print(string.format("[VL][Truck] defaultCharacterNode '%s' @ world (%.3f,%.3f,%.3f)", name, wx, wy, wz))
        end

        -- enterReferenceNode
        local en = se.enterReferenceNode
        if en and entityExists(en) then
            local wx, wy, wz = getWorldTranslation(en)
            print(string.format("[VL][Truck] enterReferenceNode '%s' @ world (%.3f,%.3f,%.3f)", getName(en) or "?", wx, wy, wz))
        end

        -- vehicleCharacter: dump its fields
        local vc = se.vehicleCharacter
        if type(vc) == "table" then
            print("[VL][Truck] vehicleCharacter fields:")
            for k, v in pairs(vc) do
                local t = type(v)
                if t == "userdata" then
                    local ok, name = pcall(getName, v)
                    local wx, wy, wz = 0, 0, 0
                    pcall(function() wx, wy, wz = getWorldTranslation(v) end)
                    print(string.format("  .%s = NODE '%s' @ (%.3f,%.3f,%.3f)", k, ok and name or "?", wx, wy, wz))
                elseif t == "function" then
                    -- skip
                elseif t == "table" then
                    print(string.format("  .%s = table", k))
                else
                    print(string.format("  .%s = %s", k, tostring(v)))
                end
            end
        end

        -- defaultCharacterTargets: IK targets for hands on wheel etc.
        local dct = se.defaultCharacterTargets
        if type(dct) == "table" then
            print("[VL][Truck] defaultCharacterTargets:")
            for i, t in ipairs(dct) do
                if type(t) == "table" then
                    for k, v in pairs(t) do
                        local vt = type(v)
                        if vt == "userdata" then
                            local ok, name = pcall(getName, v)
                            local wx, wy, wz = 0, 0, 0
                            pcall(function() wx, wy, wz = getWorldTranslation(v) end)
                            print(string.format("  [%d].%s = NODE '%s' @ (%.3f,%.3f,%.3f)", i, k, ok and name or "?", wx, wy, wz))
                        elseif vt ~= "function" then
                            print(string.format("  [%d].%s = %s", i, k, tostring(v)))
                        end
                    end
                end
            end
        end
    end)

    -- poseData from aiDrivable
    pcall(function()
        local pd = truck.spec_aiDrivable and truck.spec_aiDrivable.poseData
        if type(pd) == "table" then
            print("[VL][Truck] aiDrivable.poseData:")
            for k, v in pairs(pd) do
                if type(v) ~= "function" then
                    print(string.format("  .%s = %s (%s)", k, tostring(v):sub(1,60), type(v)))
                end
            end
        end
    end)

    -- Active animation on the playerSkin (defaultCharacterNode) — most useful while seated
    pcall(function()
        local se = truck.spec_enterable
        local cn = se and se.defaultCharacterNode
        if cn == nil or not entityExists(cn) then
            print("[VL][Truck] playerSkin node not found for anim probe") return
        end
        print("[VL][Truck] playerSkin anim probe (run while seated for useful output):")
        -- Try to find the skeleton child and read its clip
        local nChildren = getNumOfChildren(cn)
        print(string.format("  playerSkin has %d children", nChildren))
        for i = 0, nChildren - 1 do
            local child = getChildAt(cn, i)
            local cname = getName(child) or "?"
            print(string.format("  child[%d] = '%s'", i, cname))
        end
        -- Try getAnimCharacterClipName on the node itself
        for track = 0, 3 do
            local ok, clipName = pcall(getAnimCharacterClipName, cn, track)
            if ok and clipName and clipName ~= "" then
                print(string.format("  track[%d] clip = '%s'", track, clipName))
            end
        end
    end)

    -- Probe the local player's character while seated — find the driving animation clip
    pcall(function()
        local player = g_localPlayer
        if player == nil then print("[VL][Truck] no local player for char probe") return end
        print("[VL][Truck] player char probe (best while seated):")

        -- Try graphicsComponent path
        local gc = player.graphicsComponent
        if gc == nil then print("  no graphicsComponent") return end

        local model = gc.model
        if model == nil then print("  no gc.model") return end
        print("  gc.model type=" .. type(model))

        local skel = model.skeleton
        if skel then
            print("  model.skeleton = " .. tostring(skel))
            -- Try to read animation clips on tracks 0-5
            for track = 0, 5 do
                local ok, clip = pcall(getAnimCharacterClipName, skel, track)
                if ok and clip and clip ~= "" then
                    print(string.format("  skel track[%d] = '%s'", track, clip))
                end
            end
        else
            print("  no model.skeleton")
        end

        -- Also try the graphicsRootNode
        local rootNode = gc.rootNode or (model and model.rootNode)
        if rootNode and entityExists(rootNode) then
            local wx, wy, wz = getWorldTranslation(rootNode)
            print(string.format("  rootNode '%s' @ world (%.3f,%.3f,%.3f)", getName(rootNode) or "?", wx, wy, wz))
            for track = 0, 5 do
                local ok, clip = pcall(getAnimCharacterClipName, rootNode, track)
                if ok and clip and clip ~= "" then
                    print(string.format("  rootNode track[%d] = '%s'", track, clip))
                end
            end
        end

        -- Probe gc.animation for current clip name
        local anim = gc.animation
        if type(anim) == "table" then
            print("  gc.animation fields:")
            for k, v in pairs(anim) do
                local t = type(v)
                if t ~= "function" then
                    print(string.format("    .%s = %s (%s)", k, tostring(v):sub(1,80), t))
                end
            end
        end

        -- Try graphicsRootNode directly + its children for clip names
        local grn = gc.graphicsRootNode
        if grn and entityExists(grn) then
            local wx, wy, wz = getWorldTranslation(grn)
            print(string.format("  graphicsRootNode '%s' @ world (%.3f,%.3f,%.3f)", getName(grn) or "?", wx, wy, wz))
            for track = 0, 5 do
                local ok, clip = pcall(getAnimCharacterClipName, grn, track)
                if ok and clip and clip ~= "" then
                    print(string.format("  grn track[%d] = '%s'", track, clip))
                end
            end
            local nc = getNumOfChildren(grn)
            for i = 0, math.min(nc-1, 10) do
                local child = getChildAt(grn, i)
                local cname = getName(child) or "?"
                for track = 0, 2 do
                    local ok, clip = pcall(getAnimCharacterClipName, child, track)
                    if ok and clip and clip ~= "" then
                        print(string.format("  grn.child[%s] track[%d] = '%s'", cname, track, clip))
                    end
                end
            end
        end
    end)

    return "[VL][Truck] dumpTruck done — check log"
end

-- vlDumpDriver: while seated in ANY vehicle, dump the player's animCharSet + active clips.
-- Used to find exactly which clip produces the correct seated pose so Walter can mirror it.
function VLConsole:dumpDriver()
    local player = g_localPlayer
    if player == nil then return "[VL] no local player" end
    local vehicle = player:getCurrentVehicle()
    if vehicle == nil then return "[VL] not in a vehicle" end
    local pg = player.graphicsComponent
    if pg == nil then return "[VL] no player graphicsComponent" end

    print(string.format("[VL][DumpDriver] vehicle=%s", tostring(vehicle.configFileName or vehicle.filename)))

    pcall(function()
        local model = pg.model
        local skel  = model and model.skeleton
        print(string.format("[VL][DumpDriver] player skeleton=%s", tostring(skel)))
        if skel and skel ~= 0 then
            local acs = getAnimCharacterSet(skel)
            print(string.format("[VL][DumpDriver] player animCharSet=%s", tostring(acs)))
            if acs and acs ~= 0 then
                -- Check which tracks are enabled and what clips are on them
                for t = 0, 5 do
                    local ok, weight = pcall(getAnimTrackBlendWeight, acs, t)
                    if ok and weight and weight > 0 then
                        print(string.format("  track[%d] weight=%.2f", t, weight))
                    end
                end
                -- Try known clip names to see which ones exist on this charset
                local CANDIDATES = {
                    "idle1Source","idle2Source","idle1FemaleSource","idle1MaleSource",
                    "drive1Source","driveSource","drivingSource","vehicleDrive1Source",
                    "sit1Source","seated1Source","sitIdle1Source","vehicleSit1Source",
                    "NPCWalkMale01Source","walkFwd1Source",
                }
                for _, name in ipairs(CANDIDATES) do
                    local ok2, idx = pcall(getAnimClipIndex, acs, name)
                    if ok2 and type(idx) == "number" and idx >= 0 then
                        print(string.format("  clip '%s' = index %d", name, idx))
                    end
                end
            end
        end
    end)

    -- Probe vehicleCharacter methods (find the activation method for Walter)
    pcall(function()
        local vc = vehicle.spec_enterable and vehicle.spec_enterable.vehicleCharacter
        if vc == nil then print("[VL][DumpDriver] no vehicleCharacter") return end
        print("[VL][DumpDriver] vehicleCharacter methods:")
        for k, v in pairs(vc) do
            if type(v) == "function" then
                print(string.format("  vc.%s()", k))
            elseif type(v) ~= "table" then
                print(string.format("  vc.%s = %s", k, tostring(v)))
            end
        end
        -- Check metatable for inherited methods
        local mt = getmetatable(vc)
        if mt and mt.__index then
            local idx = mt.__index
            if type(idx) == "table" then
                for k, v in pairs(idx) do
                    if type(v) == "function" then
                        print(string.format("  vc[meta].%s()", k))
                    end
                end
            end
        end
    end)

    pcall(function()
        local vc = vehicle.spec_enterable and vehicle.spec_enterable.vehicleCharacter
        if vc == nil then return end
        local vcAcs = vc.animationCharsetId
        print(string.format("[VL][DumpDriver] vc.animationCharsetId=%s idleClipIndex=%s driveClipIndex=%s",
            tostring(vcAcs), tostring(vc.idleClipIndex), tostring(vc.driveClipIndex)))
        if vcAcs and vcAcs ~= 0 then
            -- Active tracks on the vehicleCharacter charset — print weight AND clip index
            for t = 0, 8 do
                local ok, weight = pcall(getAnimTrackBlendWeight, vcAcs, t)
                if ok and weight and weight > 0 then
                    -- Try to read what clip is on this track
                    local clipIdx = -1
                    pcall(function()
                        -- getAnimTrackClipIndex doesn't exist, but we can try getAnimCharacterClipName on this track
                        -- Instead, brute-check which clip index lands on this track
                        for ci = 0, 20 do
                            local ok2, name = pcall(getAnimCharacterClipName, vcAcs, ci)
                            if ok2 and name and name ~= "" then
                                clipIdx = ci
                                print(string.format("  vc track[%d] weight=%.2f clipName='%s' idx=%d", t, weight, name, ci))
                                break
                            end
                        end
                    end)
                    if clipIdx < 0 then
                        print(string.format("  vc track[%d] weight=%.2f (clip unknown)", t, weight))
                    end
                end
            end
            -- All clip names on this charset via getAnimClipIndex
            local VC_CANDIDATES = {
                "idle1Source","idle2Source","idle1FemaleSource","idle1MaleSource",
                "drive1Source","driveSource","drivingSource","vehicleDrive1Source",
                "sit1Source","sitIdle1Source","seated1Source","vehicleSit1Source",
                "idleUpper1Source","driveUpper1Source","idleUpperSource",
                "idleLegs1Source","driveLegs1Source","idleLegsSource",
                "handBrakeSource","steerSource","throttleSource",
                "rightArmSource","leftArmSource","rightLegSource","leftLegSource",
                "rightHandSource","leftHandSource","rightFootSource","leftFootSource",
                "armRightSource","armLeftSource","legRightSource","legLeftSource",
            }
            for _, name in ipairs(VC_CANDIDATES) do
                local ok2, idx = pcall(getAnimClipIndex, vcAcs, name)
                if ok2 and type(idx) == "number" and idx >= 0 then
                    print(string.format("  vc clip '%s' = index %d", name, idx))
                end
            end
        end
    end)

    return "[VL][DumpDriver] done — check log"
end

-- vlWalterInTruck: seat Walter as the truck's DRIVER using the engine's own vehicleCharacter system.
-- Run while NOT in the truck yourself, standing a few metres away (the driver is hidden under ~1.5 m).
--
-- HOW IT WORKS (decompiled VehicleCharacter.lua + Enterable.lua, 2026-06-26 / R52):
--   The seated driver pose is NOT a clip. `truck:setVehicleCharacter(style)` builds the vehicle's OWN
--   HumanModel, links it to the seat node, rotates the hips by SPINE_ROTATION (the sit bend) and solves
--   IK chains (hands->wheel, feet->pedals). We feed it WALTER's playerStyle (grandpa.playerStyle) so the
--   driver wears his face/clothes — exactly how AI helpers get seated (setRandomVehicleCharacter). Then we
--   hide the standing GRANDPA. The IK is re-solved each frame by WalterWalker (it pumps vc:update while
--   _inTruck, because Enterable only pumps it while a player is controlling the vehicle).
function VLConsole:walterInTruck()
    local TRUCK_UID = "vehiclea0e0823360da9410fb4db3ebcbbfc489"

    -- Find the truck
    local truck = nil
    pcall(function()
        local vs = g_currentMission and g_currentMission.vehicleSystem
        if vs and vs.vehicles then
            for _, v in ipairs(vs.vehicles) do
                if tostring(v.uniqueId) == TRUCK_UID then truck = v break end
            end
        end
    end)
    if truck == nil then return "[VL] truck not found" end
    if type(truck.setVehicleCharacter) ~= "function" then
        return "[VL] truck has no Enterable spec (setVehicleCharacter missing)"
    end

    -- WalterWalker + the GRANDPA NPC (carries the playerStyle we dress the driver in)
    local walker = g_valleyLife and g_valleyLife.walterWalker
    if walker == nil then return "[VL] WalterWalker not found" end
    pcall(function() walker:_acquireNode() end)
    local grandpa = walker.grandpa
    if grandpa == nil then return "[VL] GRANDPA not resolved yet (try once he's spawned)" end

    -- Walter's appearance: NPC.lua stores self.playerStyle (loaded from npc.playerStyle XML).
    local style = grandpa.playerStyle
    if style == nil then
        return "[VL] grandpa.playerStyle is nil — cannot dress the driver as Walter"
    end
    print(string.format("[VL][WalterTruck] using Walter playerStyle xml=%s", tostring(style.xmlFilename)))

    -- Seat the driver as Walter via the engine's own API (deletes old, builds + IK-poses + dresses).
    -- loadCharacter is ASYNC; vehicleCharacterLoaded() runs updateIKChains() once it finishes.
    truck:setVehicleCharacter(style)

    local vc = truck.spec_enterable and truck.spec_enterable.vehicleCharacter
    if vc == nil then return "[VL] no vehicleCharacter on truck (cannot seat)" end

    -- Force the seated driver visible (updateVisibility hides it when the camera is < cameraMinDistance).
    pcall(function()
        vc.isVisible = true
        vc:setCharacterVisibility(true)
    end)

    -- Suppress WalterWalker's route + hide the standing GRANDPA so there aren't two Walters.
    walker._inTruck     = true
    walker._truck       = truck
    walker._vehicleChar = vc
    pcall(function() walker:_hide() end)

    return "[VL][WalterTruck] setVehicleCharacter(Walter) called (async load) — check the seated driver, hands on wheel"
end

-- vlWalterOutTruck: undo vlWalterInTruck. Removes the seated driver and brings the standing GRANDPA back.
function VLConsole:walterOutTruck()
    local walker = g_valleyLife and g_valleyLife.walterWalker
    if walker == nil then return "[VL] WalterWalker not found" end

    local truck = walker._truck
    if truck ~= nil and type(truck.deleteVehicleCharacter) == "function" then
        pcall(function() truck:deleteVehicleCharacter() end)
    end

    walker._inTruck     = false
    walker._truck       = nil
    walker._vehicleChar = nil
    pcall(function() walker:_reveal() end)

    return "[VL][WalterTruck] driver removed, standing Walter revealed"
end

-- Shared: find Walter's truck (International series200) by its uniqueId.
local function vlFindWalterTruck()
    local TRUCK_UID = "vehiclea0e0823360da9410fb4db3ebcbbfc489"
    local truck = nil
    pcall(function()
        local vs = g_currentMission and g_currentMission.vehicleSystem
        if vs and vs.vehicles then
            for _, v in ipairs(vs.vehicles) do
                if tostring(v.uniqueId) == TRUCK_UID then truck = v break end
            end
        end
    end)
    return truck
end

-- Named drive destinations for vlWalterDrive (captured in-game with vlPos). `angle` = parked facing in
-- radians (from the logged ry), optional; omit to face the approach direction. Add new spots here.
local VL_DRIVE_TARGETS = {
    farmersMarket = { x = 398.29, z = -708.97, angle = 0.0 },     -- vlPos 2026-06-27 (on the AI road spline)
    farmReturn    = { x = -801.17, z = 83.33, angle = 0.2724 },   -- vlPos 2026-06-27 (RETURN-spline drop-off near farm; vlWalterDriveHome road target)
}
local function vlDriveTargetNames()
    local names = {}
    for k in pairs(VL_DRIVE_TARGETS) do names[#names + 1] = k end
    table.sort(names)
    return table.concat(names, ", ")
end

-- ── Multi-leg drive route engine ────────────────────────────────────────────────────────────────
-- The farm YARD is not on the AI road-spline network, so a single GoTo to a far target fails to prepare.
-- A route drives through a sequence of waypoints (e.g. a farm-EXIT node on the road, then the destination),
-- chaining one AIJobGoTo per leg: when a leg's job finishes (AIMessageSuccessFinishedJob, AIJob.lua:100) we
-- start the next leg. Only the FINAL leg honors a parked-facing angle; pass-through legs use the approach
-- heading so the truck doesn't fight to align mid-route.
VLConsole._route = nil        -- active route: { truck, farmId, wps = {{x,z,angle?}...}, idx, label }
-- Off-farm EXIT path (captured with vlWalterAddWp). These are DRIVEN DIRECTLY (manual steering,
-- AIVehicleUtil.driveToPoint) by vlWalterDrive — NOT fed to the road pathfinder, because the farm yard is
-- off the AI network and the pathfinder rejects off-network points as "unreachable". The truck follows this
-- exact line out of the yard; once at the last point it hands off to the AI road pathfinder for the
-- destination. Captured 2026-06-26 (valleyLife_truckRoute.csv); clear with vlWalterClearRoute. angles=rad.
VLConsole._scratchWps = {  -- recorded 2026-06-26 (vlWalterRecord): dense farm→road exit curve
    { x = -763.3461, z = 116.5770, angle = -1.527859 },
    { x = -766.3161, z = 117.0569, angle = -1.389225 },
    { x = -768.7081, z = 119.0661, angle = -0.858598 },
    { x = -770.8188, z = 121.4021, angle = -0.760723 },
    { x = -772.8961, z = 123.5836, angle = -0.760738 },
    { x = -775.0599, z = 125.8563, angle = -0.760746 },
    { x = -777.4482, z = 127.8486, angle = -0.900927 },
    { x = -779.8639, z = 129.6503, angle = -0.941476 },
    { x = -782.7901, z = 130.5732, angle = -1.299625 },
    { x = -785.8408, z = 131.0978, angle = -1.361054 },
    { x = -788.9559, z = 131.6668, angle = -1.395604 },
    { x = -792.0306, z = 132.2042, angle = -1.391509 },
    { x = -795.0502, z = 131.6433, angle = -1.308738 },
    { x = -797.5992, z = 129.8796, angle = -0.998268 },
    { x = -800.9898, z = 132.1523, angle = -1.236277 },  -- on-spline endpoint (2026-06-27; replaced pt15)
}

-- PERSISTENCE (write-only): captured waypoints are appended to a CSV in the FS25 user profile dir as a
-- durable record. IMPORTANT FS25 SANDBOX QUIRK: `io.open` allows ONLY write mode ('w'); opening in read
-- mode is forced to write and TRUNCATES the file. So we NEVER read it back in-engine (that destroyed a
-- saved route once). The CSV is for OUT-OF-GAME recovery: read it with a tool and bake the route into code
-- (VL_DRIVE_TARGETS / a named route) for true permanence. In-session, waypoints live in memory.
local function vlRouteFilePath()
    local ok, base = pcall(getUserProfileAppPath)
    if not ok or base == nil or base == "" then return nil end
    return base .. "valleyLife_truckRoute.csv"
end
local function vlSaveScratch()
    local path = vlRouteFilePath()
    if path == nil then return end
    pcall(function()
        local f = io.open(path, "w")  -- write mode only (FS25 blocks read mode)
        if f == nil then return end
        for _, w in ipairs(VLConsole._scratchWps or {}) do
            f:write(string.format("%.4f,%.4f,%.6f\n", w.x, w.z, w.angle or 0))
        end
        f:close()
    end)
end

local vlDriveNextLeg  -- forward declaration (referenced by the AI_JOB_STOPPED handler)

-- Re-assert Walter as the seated driver (each startJob re-randomizes the helper) + hide standing Walter.
local function vlReassertWalterDriver(truck)
    local walker = g_valleyLife and g_valleyLife.walterWalker
    if walker == nil then return end
    pcall(function() walker:_acquireNode() end)
    local grandpa = walker.grandpa
    local style = grandpa and grandpa.playerStyle
    if style ~= nil and type(truck.setVehicleCharacter) == "function" then
        truck:setVehicleCharacter(style)
        local vc = truck.spec_enterable and truck.spec_enterable.vehicleCharacter
        if vc ~= nil then pcall(function() vc.isVisible = true; vc:setCharacterVisibility(true) end) end
    end
    walker._inTruck     = true
    walker._away        = false  -- back in the truck → clear any "out at the market" state
    walker._truck       = truck
    walker._vehicleChar = truck.spec_enterable and truck.spec_enterable.vehicleCharacter
    pcall(function() walker:_hide() end)
end

-- Start ONE Go-To leg to (tx,tz); angle = parked facing (rad) or nil to face the approach. Returns ok, err.
local function vlStartGoToLeg(truck, farmId, tx, tz, angle)
    return pcall(function()
        local job = AIJobGoTo.new(true)  -- isServer
        job:applyCurrentState(truck, g_currentMission, farmId, true)
        local cx, _, cz = getWorldTranslation(truck.rootNode)
        local a = angle or MathUtil.getYRotationFromDirection(tx - cx, tz - cz)
        job.positionAngleParameter:setSnappingAngle(0)
        job.positionAngleParameter:setPosition(tx, tz)
        job.positionAngleParameter:setAngle(a)
        job:setValues()
        local valid, vErr = job:validate(farmId)
        if not valid then error("validate: " .. tostring(vErr), 0) end
        g_currentMission.aiSystem:startJob(job, farmId)
    end)
end

-- Advance to the next leg of VLConsole._route (or finish). Called to begin a route and after each leg.
vlDriveNextLeg = function()
    local r = VLConsole._route
    if r == nil then return end
    r.idx = r.idx + 1
    local wp = r.wps[r.idx]
    if wp == nil then
        local truck, farmId = r.truck, r.farmId
        VLConsole._route = nil
        -- Road legs done. If a PARK approach was queued, manual-drive it into the (off-spline) parking spot.
        if VLConsole._pendingPark ~= nil and #VLConsole._pendingPark >= 2 then
            local pk = VLConsole._pendingPark
            VLConsole._pendingPark = nil
            print(string.format("[VL][WalterDrive] road legs done — easing into the parking (%d pts).", #pk))
            VLConsole.driveStart(truck, farmId, pk, nil)  -- manual park drive, no further destination
        else
            print(string.format("[VL][WalterDrive] route '%s' COMPLETE — parked.", r.label or "?"))
        end
        return
    end
    local ty = getTerrainHeightAtWorldPos(g_terrainNode, wp.x, 0, wp.z)
    local reachable = true
    pcall(function() reachable = g_currentMission.aiSystem:getIsPositionReachable(wp.x, ty, wp.z) end)
    local isLast = (r.idx == #r.wps)
    local ok, err = vlStartGoToLeg(r.truck, r.farmId, wp.x, wp.z, isLast and wp.angle or nil)
    print(string.format("[VL][WalterDrive] leg %d/%d → (%.1f,%.1f) reachable=%s start=%s",
        r.idx, #r.wps, wp.x, wp.z, tostring(reachable), ok and "ok" or ("FAIL " .. tostring(err))))
    if ok then vlReassertWalterDriver(r.truck) else VLConsole._route = nil end
end

-- Subscribe once to AI_JOB_STOPPED (logs the stop reason AND chains the next route leg on success).
local function vlEnsureAIStopSub()
    if not VLConsole._aiStopSubscribed and g_messageCenter ~= nil and MessageType ~= nil and MessageType.AI_JOB_STOPPED ~= nil then
        VLConsole._aiStopSubscribed = true
        g_messageCenter:subscribe(MessageType.AI_JOB_STOPPED, VLConsole.onAIJobStopped, VLConsole)
    end
end

-- Logs WHY an AI job stopped (CouldNotPrepare / NotReachable / OutOfFuel / NoPathFound / FinishedJob …) and,
-- if a route is active for our truck, advances to the next leg on success or aborts on error.
function VLConsole:onAIJobStopped(job, aiMessage)
    -- Resolve the class name and message text in SEPARATE pcalls — a throwing getMessage() must not wipe the
    -- class name (the earlier single-pcall bug logged "?" for a successful FinishedJob → false abort).
    local cls = "nil"
    local txt = nil
    local isSuccess = false
    if aiMessage ~= nil then
        pcall(function() cls = ClassUtil.getClassNameByObject(aiMessage) or "?" end)
        pcall(function() if type(aiMessage.getMessage) == "function" then txt = aiMessage:getMessage() end end)
        -- Authoritative success test: the natural completion message class.
        pcall(function()
            if AIMessageSuccessFinishedJob ~= nil and aiMessage.isa and aiMessage:isa(AIMessageSuccessFinishedJob) then
                isSuccess = true
            end
        end)
    end
    if not isSuccess and string.find(tostring(cls), "Success") then isSuccess = true end
    local reason = tostring(cls) .. (txt ~= nil and (" — " .. tostring(txt)) or "")
    print(string.format("[VL][WalterDrive] AI job STOPPED — reason: %s (success=%s)", reason, tostring(isSuccess)))

    local r = VLConsole._route
    if r == nil then return end
    -- Only react to OUR truck's job.
    if job ~= nil and job.vehicleParameter ~= nil then
        local jv = nil
        pcall(function() jv = job.vehicleParameter:getVehicle() end)
        if jv ~= nil and jv ~= r.truck then return end
    end
    if isSuccess then
        vlDriveNextLeg()  -- finished this leg → next leg (or COMPLETE)
    else
        print(string.format("[VL][WalterDrive] route '%s' ABORTED at leg %d — %s", r.label or "?", r.idx, reason))
        local truck = r.truck
        VLConsole._route = nil
        -- The aborting job ran restoreVehicleCharacter, which deleted the seated driver. Re-seat Walter so he
        -- DOESN'T vanish — he stays sitting in the (now stopped) truck instead of disappearing.
        pcall(function() vlReassertWalterDriver(truck) end)
    end
end

-- ── Manual physical exit drive (NOT the AI, NOT a glide) ─────────────────────────────────────────────────
-- The yard is OFF the AI spline network, so the road pathfinder can't take it (rejects yard targets as
-- "unreachable"). So we DRIVE the truck physically (motor + wheels + real physics) along the recorded exit
-- line: each frame we feed the engine's manual driving (setAITarget useManualDriving=true →
-- AIVehicleUtil.driveToPoint) a target = the next recorded point, advancing one point at a time. At the end
-- of the line (on the road) we hand the DESTINATION to the road AI. Pumped by onMissionUpdate.
-- KNOWN ISSUE (the open problem): manual steering only actually turns the wheels when getIsAIActive()=true
-- (a real job running); standalone it crept straight. Solving that steering engagement is the live work.
VLConsole._drive = nil  -- { truck, farmId, wps, dest, targetIdx, phase, prepT, logT, bestEnd, stuckT }
VLConsole._driveTask = { onTargetReached = function() end, onError = function() end }
local DRIVE_SPEED = 10   -- manual-drive max speed (km/h); tune
local DRIVE_REACH = 2.5  -- advance to the next recorded point when within this many metres (or once passed)

-- Aim the truck's manual-drive target STRAIGHT at a recorded point.
local function vlDriveAimAt(truck, tx, tz)
    local ty = getTerrainHeightAtWorldPos(g_terrainNode, tx, 0, tz)
    local x, _, z = getWorldTranslation(truck.rootNode)
    local dirX, dirZ = tx - x, tz - z
    local len = math.sqrt(dirX * dirX + dirZ * dirZ)
    if len > 0.01 then dirX, dirZ = dirX / len, dirZ / len else dirX, dirZ = 0, 1 end
    pcall(function() truck:setAITarget(VLConsole._driveTask, tx, ty, tz, dirX, 0, dirZ, DRIVE_SPEED, true) end)
end

-- Clear the AI-control "job flag" we set to engage steering (so the real road AI can start clean later).
local function vlDriveClearJob(d)
    if d ~= nil and d.setJob and d.truck ~= nil and d.truck.spec_aiJobVehicle ~= nil then
        pcall(function() d.truck.spec_aiJobVehicle.job = nil end)
    end
end

function VLConsole.driveStart(truck, farmId, wps, dest)
    if truck == nil or wps == nil or #wps < 2 then return false end
    -- Put the truck in AI-CONTROL mode so manual steering actually turns the wheels. The wheels only accept
    -- AI steering input when getIsAIActive() is true, which needs spec_aiJobVehicle.job ~= nil
    -- (AIJobVehicle.lua:277). We set a real (UNSTARTED) job purely as that flag — NOT the road pathfinder
    -- driving; we steer manually toward our recorded points. Cleared on finish before the real road AI runs.
    local setJob = false
    pcall(function()
        local spec = truck.spec_aiJobVehicle
        if spec ~= nil and spec.job == nil and AIJobGoTo ~= nil then
            local j = AIJobGoTo.new(true)
            pcall(function() j:applyCurrentState(truck, g_currentMission, farmId, true) end)
            spec.job = j
            setJob = true
        end
    end)
    pcall(function() truck:prepareForAIDriving() end)
    -- Start from the waypoint NEAREST the truck, not always point 1 — so re-running when the truck is already
    -- partway along (or parked at the end) doesn't drive it BACKWARD to point 1 and get stuck.
    local cx, _, cz = getWorldTranslation(truck.rootNode)
    local startIdx, bestD = 1, math.huge
    for i, w in ipairs(wps) do
        local d2 = MathUtil.vector2Length(cx - w.x, cz - w.z)
        if d2 < bestD then bestD = d2; startIdx = i end
    end
    VLConsole._drive = { truck = truck, farmId = farmId, wps = wps, dest = dest,
                         targetIdx = startIdx, phase = "prep", prepT = 0, logT = 0, setJob = setJob }
    print(string.format("[VL][WalterDrive] manual exit drive: %d points from idx %d (AI-control=%s) — starting motor…",
        #wps, startIdx, tostring(setJob)))
    return true
end

-- Walter GETS OUT of the truck and stands beside it (driver/left side). Called whenever a manual drive ENDS
-- — clean finish OR stuck/incomplete — so the truck is NEVER left with a seated NPC `vehicleCharacter` on it
-- (that non-vanilla state hangs the savegame). No-op if he isn't currently seated.
local function vlDismountAtTruck(truck, away)
    local walker = g_valleyLife and g_valleyLife.walterWalker
    if walker == nil or not walker._inTruck then return end
    if truck == nil or truck.rootNode == nil or not entityExists(truck.rootNode) then return end
    local tx, _, tz = getWorldTranslation(truck.rootNode)
    local _, ry, _  = getWorldRotation(truck.rootNode)
    local lx, _, lz = localDirectionToWorld(truck.rootNode, -1, 0, 0)  -- step out the driver (left) side
    local px, pz    = tx + lx * 2.0, tz + lz * 2.0
    local py        = getTerrainHeightAtWorldPos(g_terrainNode, px, 300, pz)
    pcall(function() if type(truck.deleteVehicleCharacter) == "function" then truck:deleteVehicleCharacter() end end)
    pcall(function() walker:_dismountAt(px, py, pz, ry, away) end)
end

local function vlDriveFinish()
    local d = VLConsole._drive
    if d == nil then return end
    VLConsole._drive = nil
    local truck, farmId, dest = d.truck, d.farmId, d.dest
    pcall(function() truck:unsetAITarget() end)
    vlDriveClearJob(d)  -- drop the steering-mode job so the real road AI starts clean
    print("[VL][WalterDrive] reached end of recorded exit line.")
    if dest == nil then
        -- FINAL leg done (parked at the destination) → Walter gets out.
        vlDismountAtTruck(truck, VLConsole._tripAway ~= false)
        return
    end
    print(string.format("[VL][WalterDrive] handing off to road AI → '%s' (%.1f,%.1f).", dest.label or "dest", dest.x, dest.z))
    VLConsole._route = { truck = truck, farmId = farmId, idx = 0, label = dest.label or "dest",
                         wps = { { x = dest.x, z = dest.z, angle = dest.angle } } }
    vlDriveNextLeg()
end

function VLConsole.driveTick(dt)
    local d = VLConsole._drive
    if d == nil or d.truck == nil or not entityExists(d.truck.rootNode) then return end
    pcall(function() d.truck:raiseActive() end)
    local x, _, z = getWorldTranslation(d.truck.rootNode)

    if d.phase == "prep" then
        d.prepT = d.prepT + dt
        local ready = false
        pcall(function() ready = d.truck:getIsAIReadyToDrive() end)
        if ready or d.prepT > 3000 then
            d.phase = "drive"
            print(string.format("[VL][WalterDrive] motor ready (%dms, ready=%s); driving the line.", math.floor(d.prepT), tostring(ready)))
        end
        return
    end

    -- Advance the target by PROGRESS ALONG THE PATH, not by heading: step forward while we're close to the
    -- current point OR the NEXT point is already closer (we've moved past this one). A heading-based "is this
    -- point behind me" test wrongly skipped every point when the truck started parked facing the OPPOSITE way
    -- to the path (e.g. facing into the bay while the crossing pulls out) → it jumped to the last point.
    while d.targetIdx < #d.wps do
        local cur, nxt = d.wps[d.targetIdx], d.wps[d.targetIdx + 1]
        local dCur  = MathUtil.vector2Length(x - cur.x, z - cur.z)
        local dNext = MathUtil.vector2Length(x - nxt.x, z - nxt.z)
        if dCur < DRIVE_REACH or dNext < dCur then d.targetIdx = d.targetIdx + 1 else break end
    end
    local tgt = d.wps[d.targetIdx]
    -- Finished once we're close to the FINAL point.
    if d.targetIdx >= #d.wps and MathUtil.vector2Length(x - tgt.x, z - tgt.z) < DRIVE_REACH then
        vlDriveFinish(); return
    end

    -- Stuck detector by PATH PROGRESS, not crow-flies distance to the end: if the target waypoint index keeps
    -- advancing, the truck is progressing — even on a WINDING path where straight-line distance to the final
    -- point temporarily grows (which used to false-trigger "STUCK" near the buildings). Only stuck if we
    -- can't reach the NEXT waypoint for a while.
    if d.targetIdx > (d.lastProgIdx or 0) then
        d.lastProgIdx = d.targetIdx; d.stuckT = 0
    else
        d.stuckT = (d.stuckT or 0) + dt
    end
    if (d.stuckT or 0) > 6000 then
        print(string.format("[VL][WalterDrive] STUCK at idx %d/%d (no waypoint reached in 6s) — stopping.", d.targetIdx, #d.wps))
        local truck = d.truck
        vlDriveClearJob(d)
        VLConsole._drive = nil
        VLConsole._route = nil
        VLConsole._pendingPark = nil
        pcall(function() truck:unsetAITarget() end)
        -- Get him OUT even on an incomplete park, so the truck is never left with a seated driver (save-safe).
        vlDismountAtTruck(truck, VLConsole._tripAway ~= false)
        return
    end

    vlDriveAimAt(d.truck, tgt.x, tgt.z)  -- drive straight at the current recorded point
    -- Log only when the target waypoint advances (not every frame) — keeps the console readable.
    if d.targetIdx ~= d.loggedIdx then
        d.loggedIdx = d.targetIdx
        print(string.format("[VL][WalterDrive] → point %d/%d", d.targetIdx, #d.wps))
    end
end

-- ── Path RECORDER: drive the truck along the exit route once; samples a dense path that hugs the drive ──
-- Manual driving goes straight point-to-point, so sparse waypoints cut corners (into the shed). Recording
-- samples the truck's position every few metres so the straight segments follow the curve you actually drove.
VLConsole._recording = false
VLConsole._recLast = nil
local REC_STEP = 3.0  -- metres between recorded samples

function VLConsole.recordTick(dt)
    if not VLConsole._recording then return end
    local x, _, z, ry = VLConsole.capturePose()
    if x == nil then return end
    local last = VLConsole._recLast
    if last == nil or MathUtil.vector2Length(x - last.x, z - last.z) >= REC_STEP then
        local t = VLConsole._recTarget
        local list
        if t == "home" then
            VLConsole._homeExitWps = VLConsole._homeExitWps or {}; list = VLConsole._homeExitWps
        elseif t == "homepark" then
            VLConsole._homeParkWps = VLConsole._homeParkWps or {}; list = VLConsole._homeParkWps
        elseif t == "park" then
            VLConsole._parkWps = VLConsole._parkWps or {}; list = VLConsole._parkWps
        else
            VLConsole._scratchWps = VLConsole._scratchWps or {}; list = VLConsole._scratchWps
        end
        list[#list + 1] = { x = x, z = z, angle = ry or 0 }
        VLConsole._recLast = { x = x, z = z }
        if t ~= "home" and t ~= "homepark" and t ~= "park" then vlSaveScratch() end
    end
end

-- vlWalterDrive [<name>|<x z>]: THE drive command. Walter drives his truck to a destination, automatically
-- using your captured exit waypoints (vlWalterAddWp) to get off the farm to the road first, then the AI
-- pathfinds the rest on the road network. He's seated/dressed as Walter for the whole trip.
--   vlWalterDrive farmersMarket   → exit waypoints, then AI to the named destination (VL_DRIVE_TARGETS)
--   vlWalterDrive 398 -679        → exit waypoints, then AI to an explicit x z
--   vlWalterDrive                 → just the exit waypoints (get to the road); if none captured, drive-to-me
-- Server/host only. See project_walter_truck memory + journals/walter-truck-driving.md.
function VLConsole:walterDrive(arg1, arg2)
    local truck = vlFindWalterTruck()
    if truck == nil then return "[VL] truck not found" end
    if AIJobGoTo == nil then return "[VL] AIJobGoTo class unavailable" end
    if g_currentMission == nil or g_currentMission.aiSystem == nil then return "[VL] no aiSystem" end
    if not g_currentMission:getIsServer() then return "[VL] must be server/host to start an AI job" end
    vlEnsureAIStopSub()

    -- The captured exit waypoints are driven by the REAL AI (one AIJobGoTo leg per point — it steers).
    local exit = {}
    for _, w in ipairs(VLConsole._scratchWps or {}) do exit[#exit + 1] = { x = w.x, z = w.z, angle = w.angle } end
    local nExit = #exit

    -- Resolve the optional final destination (named or "x z"); none → drive-to-me only if no exit path.
    local dest = nil
    local named = arg1 ~= nil and VL_DRIVE_TARGETS[tostring(arg1)] or nil
    if named ~= nil then
        dest = { x = named.x, z = named.z, angle = named.angle, label = tostring(arg1) }
    elseif tonumber(arg1) ~= nil and tonumber(arg2) ~= nil then
        dest = { x = tonumber(arg1), z = tonumber(arg2), label = "xz" }
    elseif arg1 ~= nil then
        return "[VL] unknown destination '" .. tostring(arg1) .. "'. Known: " .. vlDriveTargetNames()
               .. " — or pass 'x z', or no args."
    elseif nExit == 0 then
        local px, _, pz = VLConsole.capturePose()
        if px == nil then return "[VL] no destination, no waypoints, no position to drive to." end
        dest = { x = px, z = pz, label = "drive-to-me" }
    end

    local farmId = (truck.getOwnerFarmId and truck:getOwnerFarmId())
                   or (g_localPlayer and g_localPlayer.farmId) or 1

    -- Seat Walter for the whole trip (hides standing Walter; WalterWalker keeps his IK solved while _inTruck).
    VLConsole._tripAway = true   -- driving OUT to a destination → he gets out "away" (idles there, no farm route)
    vlReassertWalterDriver(truck)

    -- Queue the PARK approach (leg 3) to run after the road legs reach the on-spline drop-off.
    VLConsole._pendingPark = nil
    if VLConsole._parkWps ~= nil and #VLConsole._parkWps >= 2 then
        local pk = {}
        for _, w in ipairs(VLConsole._parkWps) do pk[#pk + 1] = { x = w.x, z = w.z, angle = w.angle } end
        VLConsole._pendingPark = pk
    end

    if nExit >= 2 then
        -- FIRST LEG = manual physical drive along the recorded exit line (NOT the AI — the yard is off the
        -- spline network; NOT the glide). The AI only takes the destination once we're on the road.
        VLConsole._route = nil
        if VLConsole.driveStart(truck, farmId, exit, dest) then
            return string.format("[VL][WalterDrive] manual-driving the recorded exit line (%d pts)%s.",
                nExit, dest and (", then road AI to " .. dest.label) or "")
        end
        return "[VL][WalterDrive] exit-drive start failed — check log."
    end

    -- No exit path → straight to the road AI for the destination.
    VLConsole._drive = nil
    VLConsole._route = { truck = truck, farmId = farmId, idx = 0, label = dest.label,
                         wps = { { x = dest.x, z = dest.z, angle = dest.angle } } }
    vlDriveNextLeg()
    return string.format("[VL][WalterDrive] road AI driving to '%s' (%.1f,%.1f).", dest.label, dest.x, dest.z)
end

-- vlWalterDriveHome: drive the route IN REVERSE — market parking → road → farm yard. Run while the truck is
-- at the market parking. Reuses the baked FORWARD waypoints reversed: reverse(_parkWps)+market drop-off as
-- the off-park exit onto the spline, road AI back to the farm on-spline point, then reverse(_scratchWps) to
-- ease into the yard. Tests that the route works both directions.
function VLConsole:walterDriveHome()
    local truck = vlFindWalterTruck()
    if truck == nil then return "[VL] truck not found" end
    if AIJobGoTo == nil then return "[VL] AIJobGoTo unavailable" end
    if g_currentMission == nil or g_currentMission.aiSystem == nil then return "[VL] no aiSystem" end
    if not g_currentMission:getIsServer() then return "[VL] server/host only" end
    vlEnsureAIStopSub()

    local fwdExit = VLConsole._scratchWps or {}
    local fwdPark = VLConsole._parkWps or {}
    if #fwdExit < 2 then return "[VL] no baked exit path to reverse." end
    local mkt = VL_DRIVE_TARGETS.farmersMarket

    -- Reverse EXIT: prefer a RECORDED home-exit/road-crossing path (vlWalterRecord on home) — it ends on the
    -- RETURN-direction spline (one-way splines need the opposite lane). Else auto-reverse the park to the
    -- forward drop-off (only works if the splines are bidirectional).
    local exit = {}
    local home = VLConsole._homeExitWps or {}
    if #home >= 2 then
        for _, w in ipairs(home) do exit[#exit + 1] = { x = w.x, z = w.z, angle = w.angle } end
    else
        for i = #fwdPark, 1, -1 do exit[#exit + 1] = { x = fwdPark[i].x, z = fwdPark[i].z, angle = fwdPark[i].angle } end
        exit[#exit + 1] = { x = mkt.x, z = mkt.z, angle = mkt.angle }
    end

    -- Road dest = a settable RETURN drop-off on the return spline near the farm (VL_DRIVE_TARGETS.farmReturn);
    -- else the forward exit point (which the AI may get "blocked" approaching from the return direction).
    local fr = VL_DRIVE_TARGETS.farmReturn
    local farmPt = fr or fwdExit[#fwdExit]
    local dest = { x = farmPt.x, z = farmPt.z, angle = farmPt.angle, label = "farmYard" }

    -- Reverse PARK: prefer a RECORDED return-park path (vlWalterRecord on homepark) from the return drop-off
    -- into the yard; else reverse the forward exit path.
    local park = {}
    local hp = VLConsole._homeParkWps or {}
    if #hp >= 2 then
        for _, w in ipairs(hp) do park[#park + 1] = { x = w.x, z = w.z, angle = w.angle } end
    else
        for i = #fwdExit, 1, -1 do park[#park + 1] = { x = fwdExit[i].x, z = fwdExit[i].z, angle = fwdExit[i].angle } end
    end

    local farmId = (truck.getOwnerFarmId and truck:getOwnerFarmId()) or (g_localPlayer and g_localPlayer.farmId) or 1
    VLConsole._tripAway = false   -- driving HOME → dismount resumes his normal farm routines
    vlReassertWalterDriver(truck)
    VLConsole._route = nil
    VLConsole._pendingPark = (#park >= 2) and park or nil
    if #exit >= 2 then
        if VLConsole.driveStart(truck, farmId, exit, dest) then
            return "[VL][WalterDrive] HOME (reverse): market parking → road → farm yard."
        end
        return "[VL][WalterDrive] home-drive start failed — check log."
    end
    VLConsole._drive = nil
    VLConsole._route = { truck = truck, farmId = farmId, idx = 0, label = dest.label, wps = { { x = dest.x, z = dest.z, angle = dest.angle } } }
    vlDriveNextLeg()
    return "[VL][WalterDrive] HOME (reverse): road → farm yard."
end

-- ── Daily truck schedule (first pass) ────────────────────────────────────────────────────────────────────
-- What we have so far: each day Walter drives to the market in the morning, idles there (his farm routes are
-- suppressed while `_away`), and drives home in the evening. Edge-triggered once per day each way. Pumped from
-- onMissionUpdate. Toggle/tune with `vlWalterSchedule`. (His broader daily roster isn't designed yet.)
VLConsole._truckSchedule = { enabled = true, departHour = 10, returnHour = 16, dest = "farmersMarket" }

function VLConsole.truckScheduleTick(dt)
    local sch = VLConsole._truckSchedule
    if sch == nil or not sch.enabled then return end
    if g_currentMission == nil or not g_currentMission:getIsServer() then return end
    local walker = g_valleyLife and g_valleyLife.walterWalker
    if walker == nil then return end
    -- Never interrupt a drive already in progress (manual leg or road leg).
    if VLConsole._drive ~= nil or VLConsole._route ~= nil then return end
    local hour = TimeHelper and TimeHelper.getHour and TimeHelper.getHour() or nil
    if hour == nil then return end
    local day  = (TimeHelper.getMonotonicDay and TimeHelper.getMonotonicDay()) or 0

    -- DEPART to the market: once/day in [departHour, returnHour), while he's home, settled, out, not talking.
    if hour >= (sch.departHour or 10) and hour < (sch.returnHour or 16)
       and not walker._inTruck and not walker._away and not walker._active and not walker._hidden
       and not (walker.grandpa and walker.grandpa.isInConversation) then
        if VLConsole._lastDepartDay ~= day then
            VLConsole._lastDepartDay = day
            print(string.format("[VL][Schedule] %02d:00 — Walter heads to %s.", hour, sch.dest or "market"))
            pcall(function() VLConsole:walterDrive(sch.dest or "farmersMarket") end)
        end
        return
    end

    -- RETURN home: once/day at returnHour, while he's out at the market.
    if walker._away and hour >= (sch.returnHour or 16) then
        if VLConsole._lastReturnDay ~= day then
            VLConsole._lastReturnDay = day
            print(string.format("[VL][Schedule] %02d:00 — Walter heads home.", hour))
            pcall(function() VLConsole:walterDriveHome() end)
        end
    end
end

-- vlWalterSchedule [on|off|now|<departHr> <returnHr>]: toggle/tune the daily truck schedule; `now` forces
-- the departure immediately (skip the wait for departHour). Setting the hours clears the once-per-day marker
-- so it can re-fire today.
function VLConsole:walterSchedule(arg1, arg2)
    local sch = VLConsole._truckSchedule
    local a = arg1 ~= nil and string.lower(tostring(arg1)) or nil
    if a == "on" then sch.enabled = true
    elseif a == "off" then sch.enabled = false
    elseif a == "now" then
        VLConsole._lastDepartDay = nil
        return "[VL][Schedule] forcing departure → " .. tostring(VLConsole:walterDrive(sch.dest or "farmersMarket"))
    elseif tonumber(arg1) ~= nil and tonumber(arg2) ~= nil then
        sch.departHour = math.floor(tonumber(arg1)); sch.returnHour = math.floor(tonumber(arg2))
        VLConsole._lastDepartDay = nil; VLConsole._lastReturnDay = nil
    end
    return string.format("[VL][Schedule] %s — depart %02d:00 → %s, return %02d:00. (on|off|now|<departHr> <returnHr>)",
        sch.enabled and "ON" or "OFF", sch.departHour or 10, sch.dest or "market", sch.returnHour or 16)
end

-- vlTruckTeleport [market|farm|<name>|<x z>|me]: instantly drop the truck at a spot (no long drive) for fast
-- testing. market = the baked market parking; farm = the yard park spot; a VL_DRIVE_TARGETS name; an x z; or
-- your position (default). Uses removeFromPhysics + setRelativePosition (snaps to terrain) + addToPhysics.
function VLConsole:truckTeleport(arg1, arg2)
    local truck = vlFindWalterTruck()
    if truck == nil then return "[VL] truck not found" end
    local tx, tz, ry
    local a = arg1 ~= nil and string.lower(tostring(arg1)) or nil
    if a == "market" then
        local p = (VLConsole._parkWps or {})[#(VLConsole._parkWps or {})]
        if p then tx, tz, ry = p.x, p.z, p.angle end
    elseif a == "farm" then
        local p = (VLConsole._scratchWps or {})[1]
        if p then tx, tz, ry = p.x, p.z, p.angle end
    elseif a ~= nil and VL_DRIVE_TARGETS[a] then
        local t = VL_DRIVE_TARGETS[a]; tx, tz, ry = t.x, t.z, t.angle or 0
    elseif tonumber(arg1) ~= nil and tonumber(arg2) ~= nil then
        tx, tz, ry = tonumber(arg1), tonumber(arg2), 0
    else
        local px, _, pz, pry = VLConsole.capturePose(); tx, tz, ry = px, pz, pry
    end
    if tx == nil then return "[VL] no teleport target (market|farm|<name>|<x z>|me)" end

    local cx, cy, cz = getWorldTranslation(truck.rootNode)
    local cth = getTerrainHeightAtWorldPos(g_terrainNode, cx, 300, cz)
    local offsetY = math.max((cy or 0) - (cth or 0), 0.4)  -- keep the truck's resting height; min 0.4 so it settles
    pcall(function()
        truck:removeFromPhysics()
        truck:setRelativePosition(tx, offsetY, tz, ry or 0)
        truck:addToPhysics()
        truck:raiseActive()
    end)
    return string.format("[VL][Teleport] truck → (%.1f, %.1f). Now: vlWalterDriveHome (or vlWalterDrive farmersMarket).", tx, tz)
end

-- vlTruckRoadTo [<name>|<x z>]: DIAGNOSTIC — road-AI the truck straight from its CURRENT position to a target
-- with NO manual exit leg. Use it to isolate the "unreachable" failure: stand on a spline a short way down
-- the road and run it (no args = drive to you). If the truck road-drives to a NEARBY on-spline point but
-- NOT to the market, the local network works and the farm↔downtown connection is the gap.
function VLConsole:truckRoadTo(arg1, arg2)
    local truck = vlFindWalterTruck()
    if truck == nil then return "[VL] truck not found" end
    if AIJobGoTo == nil then return "[VL] AIJobGoTo unavailable" end
    if g_currentMission == nil or g_currentMission.aiSystem == nil then return "[VL] no aiSystem" end
    if not g_currentMission:getIsServer() then return "[VL] server/host only" end
    vlEnsureAIStopSub()

    local tx, tz, ang, label
    local named = arg1 ~= nil and VL_DRIVE_TARGETS[tostring(arg1)] or nil
    if named ~= nil then
        tx, tz, ang, label = named.x, named.z, named.angle, tostring(arg1)
    elseif tonumber(arg1) ~= nil and tonumber(arg2) ~= nil then
        tx, tz, label = tonumber(arg1), tonumber(arg2), "xz"
    elseif arg1 ~= nil then
        return "[VL] unknown dest '" .. tostring(arg1) .. "'. Known: " .. vlDriveTargetNames() .. " (or 'x z', or no args)."
    else
        local px, _, pz = VLConsole.capturePose()
        if px == nil then return "[VL] no position to drive to." end
        tx, tz, label = px, pz, "to-me"
    end

    local farmId = (truck.getOwnerFarmId and truck:getOwnerFarmId()) or (g_localPlayer and g_localPlayer.farmId) or 1
    local cx, _, cz = getWorldTranslation(truck.rootNode)
    print(string.format("[VL][RoadTo] truck @ (%.1f,%.1f) → '%s' (%.1f,%.1f), straight-line %.1fm",
        cx, cz, label, tx, tz, MathUtil.vector2Length(cx - tx, cz - tz)))
    VLConsole._drive = nil
    vlReassertWalterDriver(truck)
    VLConsole._route = { truck = truck, farmId = farmId, idx = 0, label = label, wps = { { x = tx, z = tz, angle = ang } } }
    vlDriveNextLeg()
    return string.format("[VL][RoadTo] road AI from truck's CURRENT spot → '%s' (no manual leg).", label)
end


-- ── Leg 3: PARK approach — manual-drive from the on-spline drop-off into the off-spline parking spot ──────
-- The road AI gets the truck to the market's on-spline point; the actual parking bay is off the network, so
-- (like leg 1) we manual-drive a short recorded path into it. Captured into _parkWps; runs automatically
-- after the road legs complete (vlWalterDrive queues it). Final point's angle = the parked facing.
-- BAKED farm→farmersMarket leg-3 park approach (captured 2026-06-27 via vlWalterAddWp; final facing -89°).
VLConsole._parkWps = {
    { x = 386.5400, z = -709.2910, angle = 1.554216 },
    { x = 389.7004, z = -708.8970, angle = 1.406507 },
    { x = 392.8297, z = -708.0846, angle = 1.327422 },
    { x = 395.5779, z = -706.6807, angle = 1.049923 },
    { x = 396.8713, z = -703.9274, angle = 0.438137 },
    { x = 396.4803, z = -700.8323, angle = -0.155440 },
    { x = 395.3679, z = -697.8796, angle = -0.294149 },
    { x = 394.8630, z = -694.7869, angle = -0.187368 },
    { x = 394.3015, z = -691.8260, angle = -0.187365 },
    { x = 393.7438, z = -688.7507, angle = -0.172058 },
    { x = 393.6155, z = -685.6883, angle = -0.048104 },
    { x = 393.4672, z = -682.6128, angle = -0.048108 },
    { x = 393.3128, z = -679.3972, angle = -0.048095 },
    { x = 393.1624, z = -676.2853, angle = -0.048092 },
    { x = 393.1518, z = -673.2100, angle = 0.018883 },
    { x = 394.4728, z = -670.2803, angle = 0.486733 },
    { x = 396.5570, z = -668.0878, angle = 0.727450 },
    { x = 393.7876, z = -669.2560, angle = 1.525647 },
    { x = 390.7666, z = -669.4153, angle = 1.525634 },
}

-- REVERSE exit / road CROSSING (leg 1 of the reverse trip): from the market parking out onto the road and
-- across to the RETURN-direction spline at (386.56,-712.49). Recorded 2026-06-27 (home) after the new park.
VLConsole._homeExitWps = {
    { x = 388.2173, z = -669.5255, angle = 1.529534 },
    { x = 391.2346, z = -669.7141, angle = 1.469820 },
    { x = 394.1827, z = -670.7712, angle = 1.200742 },
    { x = 396.1203, z = -673.1003, angle = 0.642579 },
    { x = 396.8555, z = -676.0177, angle = 0.273189 },
    { x = 397.2067, z = -679.2219, angle = 0.085902 },
    { x = 397.3864, z = -682.3426, angle = 0.065090 },
    { x = 397.4572, z = -685.6701, angle = 0.011375 },
    { x = 397.4933, z = -688.8867, angle = 0.011386 },
    { x = 397.5284, z = -691.9496, angle = 0.011383 },
    { x = 397.5631, z = -694.9759, angle = 0.011384 },
    { x = 397.5987, z = -698.0898, angle = 0.011381 },
    { x = 397.6343, z = -701.2228, angle = 0.011382 },
    { x = 397.5529, z = -704.2310, angle = -0.042930 },
    { x = 396.9418, z = -707.3372, angle = -0.188444 },
    { x = 395.4961, z = -710.0640, angle = -0.532964 },
    { x = 392.6584, z = -711.3098, angle = -1.151408 },
    { x = 389.5245, z = -711.8829, angle = -1.368043 },
    { x = 386.5579, z = -712.4910, angle = -1.368395 },
}

-- RETURN park (leg 3 of the reverse trip): from the farmReturn drop-off (-801.17,83.33) winding into the
-- farm yard, ending at the park spot (-762.96,117.33). Recorded 2026-06-27 via vlWalterRecord (homepark).
VLConsole._homeParkWps = {
    { x = -801.1721, z = 83.3294, angle = 0.272426 },
    { x = -800.3591, z = 86.4961, angle = 0.238500 },
    { x = -799.7362, z = 89.4944, angle = 0.198931 },
    { x = -799.1914, z = 92.6372, angle = 0.161504 },
    { x = -798.9583, z = 95.6521, angle = 0.073891 },
    { x = -798.9376, z = 98.6814, angle = 0.020484 },
    { x = -799.1690, z = 101.6908, angle = -0.075035 },
    { x = -799.5638, z = 104.7931, angle = -0.135377 },
    { x = -800.0227, z = 107.9550, angle = -0.146768 },
    { x = -800.7153, z = 111.0372, angle = -0.220999 },
    { x = -801.4133, z = 114.0328, angle = -0.234033 },
    { x = -802.3121, z = 117.0551, angle = -0.278314 },
    { x = -803.1470, z = 119.9736, angle = -0.278320 },
    { x = -803.9791, z = 122.8933, angle = -0.276570 },
    { x = -803.9150, z = 125.9874, angle = 0.097074 },
    { x = -802.2433, z = 128.5729, angle = 0.564768 },
    { x = -799.6946, z = 130.1987, angle = 0.991575 },
    { x = -796.9897, z = 131.7417, angle = 1.037410 },
    { x = -793.9686, z = 132.7491, angle = 1.315313 },
    { x = -790.8336, z = 132.3579, angle = 1.470478 },
    { x = -787.8639, z = 131.6716, angle = 1.330882 },
    { x = -784.7318, z = 130.8766, angle = 1.316366 },
    { x = -782.0157, z = 129.4395, angle = 1.042107 },
    { x = -779.6831, z = 127.4917, angle = 0.906483 },
    { x = -777.2036, z = 125.5504, angle = 0.906482 },
    { x = -774.8797, z = 123.6493, angle = 0.868788 },
    { x = -773.2906, z = 121.0470, angle = 0.558268 },
    { x = -772.0778, z = 118.1790, angle = 0.427286 },
    { x = -770.8150, z = 115.4063, angle = 0.427280 },
    { x = -769.3196, z = 112.6221, angle = 0.503652 },
    { x = -767.7626, z = 109.7991, angle = 0.503913 },
    { x = -766.1912, z = 107.1242, angle = 0.547673 },
    { x = -763.9041, z = 105.0012, angle = 0.866942 },
    { x = -761.0062, z = 103.6759, angle = 1.106201 },
    { x = -758.4805, z = 101.9781, angle = 0.976576 },
    { x = -755.8325, z = 100.4083, angle = 1.060703 },
    { x = -753.0366, z = 99.0031, angle = 1.093967 },
    { x = -750.1912, z = 97.8546, angle = 1.220728 },
    { x = -747.1736, z = 96.9319, angle = 1.260810 },
    { x = -743.9957, z = 96.0395, angle = 1.318982 },
    { x = -740.9853, z = 96.0964, angle = 1.517195 },
    { x = -738.0981, z = 97.1001, angle = 1.266153 },
    { x = -735.0280, z = 98.0661, angle = 1.266037 },
    { x = -732.1511, z = 99.5832, angle = 1.035576 },
    { x = -730.7488, z = 102.2837, angle = 0.431164 },
    { x = -730.6240, z = 105.3474, angle = 0.043999 },
    { x = -731.5930, z = 108.1886, angle = -0.307720 },
    { x = -732.6796, z = 111.0604, angle = -0.348979 },
    { x = -733.8716, z = 114.1436, angle = -0.382534 },
    { x = -735.6500, z = 116.6244, angle = -0.662556 },
    { x = -738.3207, z = 118.5594, angle = -0.923330 },
    { x = -741.2502, z = 119.7471, angle = -1.231081 },
    { x = -744.3778, z = 119.3549, angle = -1.438036 },
    { x = -747.3951, z = 118.7089, angle = -1.377537 },
    { x = -750.4176, z = 118.1796, angle = -1.398410 },
    { x = -753.5905, z = 117.6277, angle = -1.398389 },
    { x = -756.8203, z = 117.3867, angle = -1.522095 },
    { x = -759.9003, z = 117.2842, angle = -1.536010 },
    { x = -762.9613, z = 117.3274, angle = -1.550872 },
}

function VLConsole:truckParkAddWp(angleDeg)
    local px, _, pz, ry, src = VLConsole.capturePose()
    if px == nil then return "[VL] no player/vehicle node to capture" end
    local angle = (tonumber(angleDeg) ~= nil) and math.rad(tonumber(angleDeg)) or ry
    VLConsole._parkWps = VLConsole._parkWps or {}
    table.insert(VLConsole._parkWps, { x = px, z = pz, angle = angle })
    return string.format("[VL][Park] +park point %d at (%.2f, %.2f) facing %.0f° [%s] — total %d.",
        #VLConsole._parkWps, px, pz, math.deg(angle), src, #VLConsole._parkWps)
end

function VLConsole:truckParkClear()
    VLConsole._parkWps = {}
    return "[VL][Park] park approach cleared."
end

function VLConsole:truckParkList()
    local w = VLConsole._parkWps or {}
    if #w == 0 then return "[VL][Park] no park points." end
    print(string.format("[VL][Park] %d park points:", #w))
    for i, p in ipairs(w) do print(string.format("  [%d] x=%.2f z=%.2f angle=%.0f°", i, p.x, p.z, math.deg(p.angle or 0))) end
    return string.format("[VL][Park] listed %d (see log).", #w)
end

-- vlWalterAddWp [angleDeg]: append your CURRENT position as a route waypoint (capture like the walk routes
-- with vlPos). Stand on the road just off the farm for the first one, then at the destination. Optional
-- angleDeg = parked facing for the FINAL waypoint (default = your current facing). Then: vlWalterDrive <dest>.
function VLConsole:walterAddWp(angleDeg)
    local px, _, pz, ry, src = VLConsole.capturePose()
    if px == nil then return "[VL] no player/vehicle node to capture" end
    local angle = (tonumber(angleDeg) ~= nil) and math.rad(tonumber(angleDeg)) or ry
    VLConsole._scratchWps = VLConsole._scratchWps or {}
    table.insert(VLConsole._scratchWps, { x = px, z = pz, angle = angle })
    vlSaveScratch()  -- persist immediately so a relaunch keeps it
    return string.format("[VL][WalterDrive] +waypoint %d at (%.2f, %.2f) facing %.0f° [%s] — total %d (saved). Drive: vlWalterDrive <dest>.",
        #VLConsole._scratchWps, px, pz, math.deg(angle), src, #VLConsole._scratchWps)
end

-- vlWalterRecord [on|off] [home]: record a dense drive path by driving the truck. `on` clears that slot and
-- samples your position every few metres; `off` stops. Default slot = the forward EXIT path (_scratchWps).
-- Pass `home` to record the REVERSE-exit / road-crossing path instead (_homeExitWps, used by vlWalterDriveHome).
function VLConsole:walterRecord(mode, target)
    mode = mode ~= nil and string.lower(tostring(mode)) or "toggle"
    local tgt = target ~= nil and string.lower(tostring(target)) or "exit"
    if tgt ~= "home" and tgt ~= "homepark" and tgt ~= "park" then tgt = "exit" end
    local turnOn = (mode == "on") or (mode == "toggle" and not VLConsole._recording)
    if turnOn then
        VLConsole._recTarget = tgt
        if tgt == "home" then VLConsole._homeExitWps = {}
        elseif tgt == "homepark" then VLConsole._homeParkWps = {}
        elseif tgt == "park" then VLConsole._parkWps = {}
        else VLConsole._scratchWps = {} end
        VLConsole._recLast = nil
        VLConsole._recording = true
        return string.format("[VL][WalterDrive] RECORDING (%s slot) — drive the path; vlWalterRecord off when done.", tgt)
    end
    VLConsole._recording = false
    local recTgt = VLConsole._recTarget or "exit"
    VLConsole._recTarget = nil
    if recTgt == "exit" then vlSaveScratch() end
    local list = (recTgt == "home") and VLConsole._homeExitWps
              or (recTgt == "homepark") and VLConsole._homeParkWps
              or (recTgt == "park") and VLConsole._parkWps
              or VLConsole._scratchWps
    list = list or {}
    -- Dump the captured points to the log for the home/homepark slots (no CSV for those) so they can be
    -- read out and BAKED into code — they're otherwise in-memory only and lost on relaunch.
    if recTgt ~= "exit" then
        print(string.format("[VL][WalterDrive] %s-slot points (bake these):", recTgt))
        for i, p in ipairs(list) do
            print(string.format("    { x = %.4f, z = %.4f, angle = %.6f },  -- %s %d", p.x, p.z, p.angle or 0, recTgt, i))
        end
    end
    return string.format("[VL][WalterDrive] recording stopped — %d waypoints (%s slot).", #list, recTgt)
end

-- vlWalterClearRoute: discard the captured scratch waypoints.
function VLConsole:walterClearRoute()
    VLConsole._scratchWps = {}
    vlSaveScratch()  -- persist the empty list
    return "[VL][WalterDrive] scratch waypoints cleared."
end

-- vlWalterListWp: print the captured waypoints (persisted across relaunch) so you can verify / I can bake them.
function VLConsole:walterListWp()
    local wps = VLConsole._scratchWps or {}
    if #wps == 0 then return "[VL][WalterDrive] no captured waypoints." end
    print(string.format("[VL][WalterDrive] %d captured waypoints:", #wps))
    for i, w in ipairs(wps) do
        print(string.format("  [%d] x=%.2f z=%.2f angle=%.0f°", i, w.x, w.z, math.deg(w.angle or 0)))
    end
    return string.format("[VL][WalterDrive] listed %d waypoints (see log).", #wps)
end

-- vlWalterStopDrive: stop the AI drive (any leg) and bring the standing Walter back.
function VLConsole:walterStopDrive()
    local truck = vlFindWalterTruck()
    if truck == nil then return "[VL] truck not found" end

    VLConsole._route = nil  -- clear FIRST so the stop isn't treated as a leg-completion → next leg
    VLConsole._drive = nil  -- stop the physical line-follower
    pcall(function() truck:unsetAITarget() end)

    local job = truck.spec_aiJobVehicle and truck.spec_aiJobVehicle.job
    if job ~= nil and g_currentMission and g_currentMission.aiSystem then
        pcall(function()
            g_currentMission.aiSystem:stopJob(job, AIMessageSuccessStoppedByUser.new())
        end)
    end

    local walker = g_valleyLife and g_valleyLife.walterWalker
    if walker ~= nil then
        walker._inTruck     = false
        walker._truck       = nil
        walker._vehicleChar = nil
        pcall(function() walker:_reveal() end)
    end

    return "[VL][WalterDrive] job stopped" .. (job ~= nil and "" or " (no active job found)") .. "; standing Walter restored"
end

-- vlWalterCows: force-play Walter's one-time cow/husbandry handoff (bypasses the once-only flag).
function VLConsole:playWalterCows(arg)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    if VLWalterCowsIntro == nil then return "[ValleyLife] WalterCowsIntro unavailable." end
    if arg ~= nil and (tostring(arg) == "0" or string.lower(tostring(arg)) == "reset") then
        g_valleyLife:setFlag("walterCowsHandoff", false)  -- clear the once-only flag → re-arm the proximity trigger
        return "[ValleyLife] Cow handoff RE-ARMED — walk up to the pen to trigger it at the new range."
    end
    VLWalterCowsIntro.play(true)
    return "[ValleyLife] Played Walter cow/husbandry handoff (forced)."
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
    addConsoleCommand("vlPedSplinesShow", "Toggle a debug overlay over the base-game pedestrian walk splines (like gsAISplinesShow for roads)", "pedSplinesShow", VLConsole)
    addConsoleCommand("vlWalterYOffset", "Tune Walter's driven height offset (meters, +lowers): vlWalterYOffset <n>", "setWalterYOffset", VLConsole)
    addConsoleCommand("vlWalterStairLift", "Tune Walter's stair bow-lift on sloped segments: vlWalterStairLift <n>", "setWalterStairLift", VLConsole)
    addConsoleCommand("vlWalterShow", "Reveal Walter if he stepped inside (hidden): vlWalterShow", "walterShow", VLConsole)
    addConsoleCommand("vlWalterHide", "Hide Walter on demand (test the door disappear): vlWalterHide", "walterHide", VLConsole)
    addConsoleCommand("vlWalterMorning", "Trigger Walter's morning departure (door -> home): vlWalterMorning", "walterMorning", VLConsole)
    addConsoleCommand("vlWalterNight", "Trigger Walter's occasional night woodshop visit (door -> lit shed -> inside): vlWalterNight", "walterNight", VLConsole)
    addConsoleCommand("vlWalterBones", "Dump GRANDPA's node/skeleton tree to find the hand bone (hand-prop research): vlWalterBones", "walterBones", VLConsole)
    addConsoleCommand("vlWalterRig", "Dump GRANDPA's model + carrier surface for the handtool-holder build: vlWalterRig", "walterRig", VLConsole)
    addConsoleCommand("vlNpcDump", "Survey base-game NPC roster for hookability (no arg) or detail one: vlNpcDump [katie|walter|ben|noah|ANIMAL_DEALER|...]", "npcDump", VLConsole)
    addConsoleCommand("vlWalterHoldFlashlight", "PROBE: give Walter a REAL flashlight handtool via the game's loader + attach to his left hand: vlWalterHoldFlashlight", "walterHoldFlashlight", VLConsole)
    addConsoleCommand("vlWalterArmIK", "PROBE: load+drive the rightArm IK chain so his arm extends to hold a tool out: vlWalterArmIK <on|off>", "walterArmIK", VLConsole)
    addConsoleCommand("vlArmTarget", "Live-tune the arm IK target POSITION 5cm/tap: vlArmTarget <x+|x-|y+|y-|z+|z->", "armTarget", VLConsole)
    addConsoleCommand("vlArmTargetRot", "Live-tune the arm IK target ROTATION 15deg/tap: vlArmTargetRot <x+|x-|y+|y-|z+|z-|0>", "armTargetRot", VLConsole)
    addConsoleCommand("vlWalterFlashlight", "Force Walter's flashlight on/off or auto: vlWalterFlashlight <1|0|auto>", "walterFlashlight", VLConsole)
    addConsoleCommand("vlWalterFlashlightPose", "Tune flashlight POSITION in hand (rotation stays auto): vlWalterFlashlightPose <x y z>", "walterFlashlightPose", VLConsole)
    addConsoleCommand("vlPlayerFlashlight", "While holding a flashlight, dump its parent bone + local transform (to copy onto Walter): vlPlayerFlashlight", "playerFlashlight", VLConsole)
    addConsoleCommand("vlFlash", "Nudge Walter's flashlight 1cm: vlFlash <x+|x-|y+|y-|z+|z->", "flashNudge", VLConsole)
    addConsoleCommand("vlPose", "Pose a digit/arm part 10deg: vlPose <thumb|index|middle|ring|pinky|shoulder|arm|forearm|wrist> [1-3] <x+|..|0>", "pose", VLConsole)
    addConsoleCommand("vlWalterClip", "Play a clip on Walter (test tool-holding anims): vlWalterClip <index|name|off>", "walterClip", VLConsole)
    addConsoleCommand("vlWalterApproach", "Set Walter's stop-and-face range (0=off, so he walks past you): vlWalterApproach <m>", "walterApproach", VLConsole)
    addConsoleCommand("vlWalterReset", "Undo all live pose/clip/approach tweaks on Walter in one shot: vlWalterReset", "walterReset", VLConsole)
    addConsoleCommand("vlWalterFlashHand", "Move the flashlight to his left/right hand (left pairs with chainsaw_walk): vlWalterFlashHand <left|right>", "walterFlashHand", VLConsole)
    addConsoleCommand("vlFlashRot", "Aim the flashlight beam 15deg/tap (on top of auto grip rotation): vlFlashRot <x+|x-|y+|y-|z+|z-|0>", "flashRot", VLConsole)
    addConsoleCommand("vlWalterSay", "Preview Walter's current time-of-day line: vlWalterSay", "walterSay", VLConsole)
    addConsoleCommand("vlWalterDoor", "TEST Walter's woodshop door control: vlWalterDoor <1=open|-1=close>", "walterDoor", VLConsole)
    addConsoleCommand("vlWalterLights", "TEST Walter's woodshop lights control: vlWalterLights <1on/0off>", "walterLights", VLConsole)
    addConsoleCommand("vlDoorTest", "TEST: open/close woodshop doors: vlDoorTest <1=open|-1=close|0=stop> [x] [z]", "doorTest", VLConsole)
    addConsoleCommand("vlLightTest", "TEST woodshop lights on/off: vlLightTest <1on/0off>", "lightTest", VLConsole)
    addConsoleCommand("vlSkipPause", "Skip current mid-route pause and send NPC to next waypoint: vlSkipPause <npcId>", "skipPause", VLConsole)
    addConsoleCommand("vlWalterIntro", "Force-play Walter's post-tour market introduction", "playWalterIntro", VLConsole)
    addConsoleCommand("vlWalterCows", "Force-play Walter's one-time cow/husbandry handoff", "playWalterCows", VLConsole)
    addConsoleCommand("vlShimmy", "Probe Walter's body each frame while talking (R49 shimmy diag): vlShimmy <1|0>", "shimmyProbe", VLConsole)
    addConsoleCommand("vlDumpDriver", "While seated in a vehicle, dump player animCharSet + active clips to find the seated pose", "dumpDriver", VLConsole)
    addConsoleCommand("vlDumpVehicle", "While seated in a vehicle, dump its filename/uniqueId/class/position: vlDumpVehicle", "dumpVehicle", VLConsole)
    addConsoleCommand("vlDumpTruck", "Probe Grandpa's truck spec_enterable/aiDrivable/ikChains for the Walter-drives feature", "dumpTruck", VLConsole)
    addConsoleCommand("vlWalterInTruck", "Seat Walter as the truck driver via setVehicleCharacter (sit + hands on wheel)", "walterInTruck", VLConsole)
    addConsoleCommand("vlWalterOutTruck", "Remove the seated Walter driver and bring the standing Walter back", "walterOutTruck", VLConsole)
    addConsoleCommand("vlWalterDrive", "Drive Walter's truck: exit waypoints then AI to a dest. vlWalterDrive [<name>|<x z>]", "walterDrive", VLConsole)
    addConsoleCommand("vlWalterStopDrive", "Stop Walter's truck AI drive (any leg) and restore standing Walter", "walterStopDrive", VLConsole)
    addConsoleCommand("vlWalterDriveHome", "Drive the route IN REVERSE: market parking → road → farm yard (run while at the market)", "walterDriveHome", VLConsole)
    addConsoleCommand("vlWalterSchedule", "Daily truck schedule: vlWalterSchedule [on|off|now|<departHr> <returnHr>] (Walter drives to market AM, home PM)", "walterSchedule", VLConsole)
    addConsoleCommand("vlTruckTeleport", "Instantly drop the truck at a spot for testing: vlTruckTeleport [market|farm|<name>|<x z>|me]", "truckTeleport", VLConsole)
    addConsoleCommand("vlTruckRoadTo", "DIAGNOSTIC: road-AI the truck from its current spot to a dest, no manual leg: vlTruckRoadTo [<name>|<x z>]", "truckRoadTo", VLConsole)
    addConsoleCommand("vlTruckParkAddWp", "Capture current position as a leg-3 park-approach point (drive into the lot): vlTruckParkAddWp [angleDeg]", "truckParkAddWp", VLConsole)
    addConsoleCommand("vlTruckParkClear", "Clear the captured park-approach points", "truckParkClear", VLConsole)
    addConsoleCommand("vlTruckParkList", "List the captured park-approach points", "truckParkList", VLConsole)
    addConsoleCommand("vlWalterAddWp", "Capture an off-farm exit waypoint at your current position: vlWalterAddWp [angleDeg]", "walterAddWp", VLConsole)
    addConsoleCommand("vlWalterRecord", "Record a dense drive path: vlWalterRecord on [home] … off (add 'home' for the reverse-exit/road-crossing path)", "walterRecord", VLConsole)
    addConsoleCommand("vlWalterClearRoute", "Discard the captured exit waypoints", "walterClearRoute", VLConsole)
    addConsoleCommand("vlWalterListWp", "List the captured exit waypoints", "walterListWp", VLConsole)
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
                -- While he's driving, "Visit" lands beside the moving TRUCK (his _wx/_wz are frozen).
                if isWalter and ww._inTruck and ww._truck ~= nil and ww._truck.rootNode ~= nil
                   and entityExists(ww._truck.rootNode) and type(self.teleportTo) == "function" then
                    local tx, ty, tz = getWorldTranslation(ww._truck.rootNode)
                    local rx, _, rz = localDirectionToWorld(ww._truck.rootNode, 1, 0, 0)  -- truck's right side
                    if pcall(function() self:teleportTo(tx + rx * 3.0, ty, tz + rz * 3.0) end) then return end
                end
                if isWalter and (ww._active or ww._away) and type(self.teleportTo) == "function" then
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
