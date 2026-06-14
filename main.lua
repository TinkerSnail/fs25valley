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
    local info = g_currentMission.missionInfo
    if info ~= nil and info.savegameDirectory ~= nil then
        local saveFile = info.savegameDirectory .. "/valleyLife.xml"
        local xmlFile = XMLFile.loadIfExists("valleyLifeSave", saveFile, "valleyLife")
        if xmlFile then
            g_valleyLife:loadFromXML(xmlFile, "valleyLife")
            xmlFile:delete()
        end
    end
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

-- Console command: prints the player's current world position, formatted ready
-- to paste into VLConfig.VILLAGER_SPAWNS. Stand where a villager should be and
-- type "vlPos" in the developer console (~).
function vlPrintPlayerPos()
    local player = g_localPlayer or (g_currentMission ~= nil and g_currentMission.player) or nil
    local node = player and player.rootNode
    if node == nil then
        local msg = "[ValleyLife] vlPos: no player found."
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

if addConsoleCommand ~= nil then
    addConsoleCommand("vlPos", "Print player world position (ValleyLife spawn coords)", "vlPrintPlayerPos", nil)
    print("[ValleyLife] Console command 'vlPos' registered.")
end

print("[ValleyLife] main.lua loaded; lifecycle hooks installed.")
