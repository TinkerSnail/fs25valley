-- ValleyLife: social and narrative layer for FS25.
-- Entry point — sources all modules in dependency order, hooks mission lifecycle.

local modDir = g_currentModDirectory

-- 1. Utilities (no dependencies)
source(modDir .. "src/utils/VectorHelper.lua")
source(modDir .. "src/utils/TimeHelper.lua")

-- 2. Config (depends on nothing)
source(modDir .. "src/NPCConfig.lua")

-- 3. Core subsystems (depend on config + utils)
source(modDir .. "src/scripts/NPCRelationshipManager.lua")
source(modDir .. "src/scripts/NPCEntity.lua")
source(modDir .. "src/scripts/NPCScheduler.lua")
source(modDir .. "src/scripts/NPCEventSequencer.lua")

-- 4. GUI (depends on subsystems)
source(modDir .. "src/gui/NPCDialog.lua")

-- 5. Main coordinator (references all subsystems)
source(modDir .. "src/NPCSystem.lua")

-- 6. Authored content — registers heart events into the sequencer at load time.
source(modDir .. "src/content/Elara.lua")
source(modDir .. "src/content/Henryk.lua")
source(modDir .. "src/content/Marta.lua")

-- Mission lifecycle

local function isCareerMission()
    return g_currentMission ~= nil
        and (FSCareerMission == nil or g_currentMission:isa(FSCareerMission))
end

local function onMissionLoaded(mission, node)
    if g_valleyLife ~= nil then return end   -- guard against double-init
    if not isCareerMission() then return end

    g_valleyLife = VLNPCSystem.new()
    g_valleyLife:initialize()

    -- Load saved state if a savegame exists (new games have no savegameDirectory yet).
    g_valleyLife:loadFromFile(g_currentMission.missionInfo)
end

local function onMissionUpdate(mission, dt)
    if g_valleyLife then
        g_valleyLife:update(dt)
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
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, henryk, marta."
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
    npcId = npcId or "elara"
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, henryk, marta."
    end
    g_valleyLife.sequencer:checkTriggers(npcId, VLConfig.REL_MAX)
    if g_valleyLife.sequencer.active then
        local msg = "[ValleyLife] Triggered next event for " .. npcId .. "."
        print(msg)
        return msg
    end
    local msg = "[ValleyLife] No available event for " .. npcId .. " (all completed?)."
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
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, henryk, marta."
    end
    local cleared = g_valleyLife.sequencer:resetNPC(npcId)
    g_valleyLife.relationships.values[npcId] = 0
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

if addConsoleCommand ~= nil then
    addConsoleCommand("vlPos", "Print player world position (ValleyLife spawn coords)", "printPlayerPos", VLConsole)
    addConsoleCommand("vlRel", "Set villager relationship: vlRel <npcId> <value>", "setRelationship", VLConsole)
    addConsoleCommand("vlEvent", "Force-trigger next heart event: vlEvent <npcId>", "triggerEvent", VLConsole)
    addConsoleCommand("vlNear", "Report nearest villager + distance (proximity debug)", "printNearest", VLConsole)
    addConsoleCommand("vlReset", "Reset a villager's events + relationship: vlReset <npcId>", "resetNpc", VLConsole)
    addConsoleCommand("vlDlg", "Probe available native dialog/choice widgets", "probeDialogs", VLConsole)
    print("[ValleyLife] Console commands registered: vlPos, vlRel, vlEvent, vlNear, vlReset, vlDlg.")
end

print("[ValleyLife] main.lua loaded; lifecycle hooks installed.")
