-- Main coordinator: owns all NPCs, wires subsystems together.

VLNPCSystem = {}
VLNPCSystem.__index = VLNPCSystem

-- Authored villager definitions.
-- personality: "hardworking"|"lazy"|"social"|"grumpy"|"generous"
-- appearance: per-config { item = index, color = index }; applied defensively and
--   wrapped to the available item count, so values are starting points to tune.
-- Age is suggested (FS25 has no aging morph): grey/white hair + grey beard +
-- accessories read "older". color indices are best-guess greys until the spawn
-- diagnostic confirms each config's real item/color counts.
local VILLAGERS = {
    -- Elara, late 20s: natural hair color, no grey, younger face.
    { id = "elara",  name = "Elara",  personality = "social",      isFemale = true,  appearance = { hairStyle = { item = 3, color = 4 }, top = { item = 2, color = 5 }, bottom = { item = 2, color = 2 }, face = { item = 2 } }, x = VLConfig.VILLAGER_SPAWNS.elara.x,  y = VLConfig.VILLAGER_SPAWNS.elara.y,  z = VLConfig.VILLAGER_SPAWNS.elara.z,  ry = VLConfig.VILLAGER_SPAWNS.elara.ry  },
    -- Henryk, ~58: salt-and-pepper hair + beard (color 22), no hat (hair shows age), weathered face.
    { id = "henryk", name = "Henryk", personality = "hardworking", isFemale = false, appearance = { hairStyle = { item = 2, color = 22 }, beard = { item = 2, color = 22 }, top = { item = 3, color = 3 }, bottom = { item = 1, color = 1 }, face = { item = 4 } }, x = VLConfig.VILLAGER_SPAWNS.henryk.x, y = VLConfig.VILLAGER_SPAWNS.henryk.y, z = VLConfig.VILLAGER_SPAWNS.henryk.z, ry = VLConfig.VILLAGER_SPAWNS.henryk.ry },
    -- Marta, ~55: silver-white hair (color 21), mature face, warm clothing.
    { id = "marta",  name = "Marta",  personality = "generous",    isFemale = true,  appearance = { hairStyle = { item = 6, color = 21 }, top = { item = 5, color = 1 }, bottom = { item = 3, color = 4 }, face = { item = 4 } }, x = VLConfig.VILLAGER_SPAWNS.marta.x,  y = VLConfig.VILLAGER_SPAWNS.marta.y,  z = VLConfig.VILLAGER_SPAWNS.marta.z,  ry = VLConfig.VILLAGER_SPAWNS.marta.ry  },
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

-- Robust player world position. On this build the controlled player exposes its
-- authoritative position via getPosition() (capsule controller); rootNode can be
-- stale, so prefer getPosition() and fall back to the node only if needed.
function VLNPCSystem:getPlayerPosition()
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    if player == nil then return nil end
    if type(player.getPosition) == "function" then
        local ok, x, y, z = pcall(player.getPosition, player)
        if ok and type(x) == "number" then return x, y, z end
    end
    local node = player.rootNode
    if node ~= nil and node ~= 0 and entityExists(node) then
        return getWorldTranslation(node)
    end
    return nil
end

function VLNPCSystem:getNearestNPC()
    local px, _, pz = self:getPlayerPosition()
    if px == nil then return nil, math.huge end
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

-- FS25's object XMLFile API requires a registered schema before setValue/getValue
-- will work ("Unable to get schema for xml file" otherwise). Build it once and
-- reuse it for both save and load. "(?)" is FS25's wildcard for array indices.
local saveSchema
local function getSaveSchema()
    if saveSchema ~= nil then return saveSchema end
    local root = VLConfig.SAVE_KEY
    local s = XMLSchema.new(root)
    s:register(XMLValueType.STRING, root .. "#version")
    s:register(XMLValueType.INT,    root .. ".relationships#count")
    s:register(XMLValueType.STRING, root .. ".relationships.rel(?)#npcId")
    s:register(XMLValueType.INT,    root .. ".relationships.rel(?)#value")
    s:register(XMLValueType.INT,    root .. ".events#count")
    s:register(XMLValueType.STRING, root .. ".events.done(?)#id")
    saveSchema = s
    return s
end

function VLNPCSystem:hookSaveLoad()
    -- FSCareerMissionInfo.saveToXMLFile fires whenever the game saves. We don't
    -- write into the career XML (its args vary across builds and the key arg is
    -- nil here); instead we persist to our own valleyLife.xml in the savegame
    -- directory, mirroring the load path in main.lua.
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(
        FSCareerMissionInfo.saveToXMLFile,
        function(info)
            if g_valleyLife then g_valleyLife:saveToFile(info) end
        end
    )
end

function VLNPCSystem:saveToFile(info)
    info = info or (g_currentMission and g_currentMission.missionInfo)
    if info == nil or info.savegameDirectory == nil then
        print("[ValleyLife] Save skipped: no savegame directory yet.")
        return
    end

    local path = info.savegameDirectory .. "/valleyLife.xml"
    local ok, err = pcall(function()
        local xmlFile = XMLFile.create("valleyLifeSave", path, VLConfig.SAVE_KEY, getSaveSchema())
        if xmlFile == nil then
            error("could not create " .. path)
        end
        self:saveToXML(xmlFile)
        xmlFile:save()
        xmlFile:delete()
    end)

    if ok then
        print("[ValleyLife] Saved to " .. path)
    else
        print("[ValleyLife] ERROR saving: " .. tostring(err))
    end
end

function VLNPCSystem:loadFromFile(info)
    info = info or (g_currentMission and g_currentMission.missionInfo)
    if info == nil or info.savegameDirectory == nil then
        return  -- new game; nothing to load yet
    end

    local path = info.savegameDirectory .. "/valleyLife.xml"
    local ok, err = pcall(function()
        local xmlFile = XMLFile.loadIfExists("valleyLifeSave", path, getSaveSchema())
        if xmlFile then
            self:loadFromXML(xmlFile, VLConfig.SAVE_KEY)
            xmlFile:delete()
            print("[ValleyLife] Loaded save from " .. path)
        end
    end)

    if not ok then
        print("[ValleyLife] ERROR loading: " .. tostring(err))
    end
end

function VLNPCSystem:saveToXML(xmlFile)
    local key = VLConfig.SAVE_KEY
    xmlFile:setValue(key .. "#version", VLConfig.SAVE_VERSION)
    self.relationships:saveToXML(xmlFile, key)
    self.sequencer:saveToXML(xmlFile, key)
end

function VLNPCSystem:loadFromXML(xmlFile, missionKey)
    local key = missionKey or VLConfig.SAVE_KEY
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
