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
--    (Henryk and Marta content files come next; Elara ships the vertical slice.)
source(modDir .. "src/content/Elara.lua")

-- Mission lifecycle

local function onMissionLoaded(mission)
    if not g_currentMission or not g_currentMission:isa(FSCareerMission) then return end
    g_valleyLife = VLNPCSystem.new()
    g_valleyLife:initialize()

    -- Load saved state if a savegame exists.
    local saveFile = g_currentMission.missionInfo.savegameDirectory .. "/valleyLife.xml"
    local xmlFile = XMLFile.loadIfExists("valleyLifeSave", saveFile, "valleyLife")
    if xmlFile then
        g_valleyLife:loadFromXML(xmlFile, "valleyLife")
        xmlFile:delete()
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

Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, onMissionLoaded)
Mission00.update         = Utils.appendedFunction(Mission00.update,         onMissionUpdate)
FSBaseMission.delete     = Utils.prependedFunction(FSBaseMission.delete,    onMissionUnload)
