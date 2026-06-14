-- Main coordinator: owns all NPCs, wires subsystems together.

VLNPCSystem = {}
VLNPCSystem.__index = VLNPCSystem

-- Authored villager definitions.
-- personality: "hardworking"|"lazy"|"social"|"grumpy"|"generous"
local VILLAGERS = {
    { id = "elara",  name = "Elara",  personality = "social",      x = VLConfig.VILLAGER_SPAWNS.elara.x,  y = VLConfig.VILLAGER_SPAWNS.elara.y,  z = VLConfig.VILLAGER_SPAWNS.elara.z,  ry = VLConfig.VILLAGER_SPAWNS.elara.ry  },
    { id = "henryk", name = "Henryk", personality = "hardworking", x = VLConfig.VILLAGER_SPAWNS.henryk.x, y = VLConfig.VILLAGER_SPAWNS.henryk.y, z = VLConfig.VILLAGER_SPAWNS.henryk.z, ry = VLConfig.VILLAGER_SPAWNS.henryk.ry },
    { id = "marta",  name = "Marta",  personality = "generous",    x = VLConfig.VILLAGER_SPAWNS.marta.x,  y = VLConfig.VILLAGER_SPAWNS.marta.y,  z = VLConfig.VILLAGER_SPAWNS.marta.z,  ry = VLConfig.VILLAGER_SPAWNS.marta.ry  },
}

function VLNPCSystem.new()
    local self = setmetatable({}, VLNPCSystem)
    self.npcs          = {}   -- id -> VLNPCEntity
    self.relationships = VLRelationshipManager.new()
    self.scheduler     = VLNPCScheduler.new()
    self.sequencer     = VLEventSequencer.new(self)
    self.dialog        = VLNPCDialog.new(self)
    return self
end

function VLNPCSystem:initialize()
    print("[ValleyLife] Initializing...")
    for _, def in ipairs(VILLAGERS) do
        local npc = VLNPCEntity.new(def)
        self.npcs[def.id] = npc
        npc:spawn()
    end
    self:hookSaveLoad()
    self.dialog:registerInput()
    print(string.format("[ValleyLife] %d villagers queued for spawn.", #VILLAGERS))
end

function VLNPCSystem:update(dt)
    for _, npc in pairs(self.npcs) do
        if npc.isLoaded then
            npc:update(dt)
        end
    end
    self.dialog:update(dt)
end

function VLNPCSystem:getNPC(id)
    return self.npcs[id]
end

function VLNPCSystem:getNearestNPC()
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    if not player then return nil, math.huge end
    local px, _, pz = getWorldTranslation(player.rootNode)
    local nearest, bestDist = nil, math.huge
    for _, npc in pairs(self.npcs) do
        if npc.isLoaded then
            local nx, _, nz = npc:getWorldPosition()
            local dx, dz = nx - px, nz - pz
            local d = math.sqrt(dx*dx + dz*dz)
            if d < bestDist then
                nearest, bestDist = npc, d
            end
        end
    end
    return nearest, bestDist
end

-- Save / load

function VLNPCSystem:hookSaveLoad()
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(
        FSCareerMissionInfo.saveToXMLFile,
        function(info, xmlFile, key)
            if g_valleyLife then g_valleyLife:saveToXML(xmlFile, key) end
        end
    )
end

function VLNPCSystem:saveToXML(xmlFile, missionKey)
    local key = missionKey .. "." .. VLConfig.SAVE_KEY
    xmlFile:setValue(key .. "#version", VLConfig.SAVE_VERSION)
    self.relationships:saveToXML(xmlFile, key)
    self.sequencer:saveToXML(xmlFile, key)
end

function VLNPCSystem:loadFromXML(xmlFile, missionKey)
    local key = missionKey .. "." .. VLConfig.SAVE_KEY
    self.relationships:loadFromXML(xmlFile, key)
    self.sequencer:loadFromXML(xmlFile, key)
end

function VLNPCSystem:delete()
    if self.dialog then self.dialog:removeInput() end
    for _, npc in pairs(self.npcs) do
        npc:delete()
    end
    self.npcs = {}
    print("[ValleyLife] Cleaned up.")
end
