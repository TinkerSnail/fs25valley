-- Main coordinator: owns all NPCs, wires subsystems together.

VLNPCSystem = {}
VLNPCSystem.__index = VLNPCSystem

-- Authored villager definitions.
-- personality: "hardworking"|"lazy"|"social"|"grumpy"|"generous"
-- birthday: optional { month = 1-12, day = 1-31 }; omitted ids get a deterministic random date.
-- appearanceBase: face, hairStyle, beard (always worn).
-- appearanceWork / appearanceLeisure: clothing layers swapped by schedule.
-- Item indices wrap to the available count; color indexes use the style palette.
local VILLAGERS = {
    -- Elara: summer work = tank/shorts; fall work = sweater/skirt (seasonal).
    -- Leisure = cozy sweater/skirt at home (no glasses) year-round.
    { id = "elara",  name = "Elara",  personality = "social",      isFemale = true,
      appearanceBase = {
        face = { item = 4 },
        hairStyle = { item = 8, color = 3 },
      },
      appearanceSummerWork = {
        top = { item = 3 },
        bottom = { item = 9 },
        footwear = { item = 13, color = 1 },
        glasses = { item = 7 },
      },
      appearanceFallWork = {
        top = { item = 5, color = 9 },
        bottom = { item = 11, color = 9 },
        footwear = { item = 6, color = 3 },
        glasses = { item = 7 },
      },
      appearanceSpringWork = {
        top = { item = 23 },
        bottom = { item = 4, color = 2 },
        footwear = { item = 8 },
        glasses = { item = 7 },
      },
      appearanceWinterWork = {
        top = { item = 21, color = 1 },
        bottom = { item = 3, color = 7 },
        footwear = { item = 17 },
        gloves = { item = 4, color = 9 },
        glasses = { item = 7 },
      },
      appearanceLeisure = {
        top = { item = 5, color = 9 },
        bottom = { item = 11, color = 9 },
        footwear = { item = 13, color = 1 },
        glasses = { item = 0 },
      },
      appearanceSummerLeisure = {
        top = { item = 3, color = 9 },
        bottom = { item = 10, color = 9 },
        footwear = { item = 13, color = 1 },
        glasses = { item = 7 },
      },
      appearanceFallLeisure = {
        top = { item = 20, color = 6 },
        bottom = { item = 4, color = 4 },
        footwear = { item = 6, color = 3 },
        glasses = { item = 7 },
      },
      appearanceWinterLeisure = {
        top = { item = 21, color = 1 },
        bottom = { item = 3, color = 7 },
        footwear = { item = 17 },
        gloves = { item = 4, color = 9 },
        glasses = { item = 7 },
      },
      x = VLConfig.VILLAGER_SPAWNS.elara.x,  y = VLConfig.VILLAGER_SPAWNS.elara.y,
      z = VLConfig.VILLAGER_SPAWNS.elara.z,  ry = VLConfig.VILLAGER_SPAWNS.elara.ry  },
    -- Kenji: summer work = t-shirt, cargo shorts, sandals, reading glasses.
    -- Fall work (autumn season): mechanic coveralls + galoshes + gloves.
    { id = "kenji", name = "Kenji", personality = "hardworking", isFemale = false,
      appearanceBase = {
        face = { item = 8 },
        hairStyle = { item = 9, color = 22 },
        beard = { item = 0 },
      },
      appearanceSummerWork = {
        top = { item = 1 },
        bottom = { item = 9, color = 2 },
        footwear = { item = 11, color = 0 },
        gloves = { item = 0 },
        glasses = { item = 3 },
      },
      appearanceFallWork = {
        onepiece = { item = 6, color = 3 },
        footwear = { item = 4, color = 1 },
        gloves = { item = 5 },
      },
      appearanceSpringWork = {
        onepiece = { item = 6, color = 3 },
        footwear = { item = 4, color = 1 },
        gloves = { item = 5 },
      },
      appearanceWinterWork = {
        top = { item = 12 },
        bottom = { item = 2, color = 5 },
        footwear = { item = 8 },
        gloves = { item = 0 },
        glasses = { item = 3 },
      },
      appearanceFallLeisure = {
        top = { item = 11 },
        bottom = { item = 2, color = 2 },
        footwear = { item = 8 },
        gloves = { item = 0 },
        glasses = { item = 3 },
      },
      appearanceSummerLeisure = {
        top = { item = 25, color = 1 },
        bottom = { item = 2, color = 2 },
        footwear = { item = 10, color = 1 },
        gloves = { item = 0 },
        glasses = { item = 3 },
      },
      appearanceWinterLeisure = {
        top = { item = 20 },
        bottom = { item = 2, color = 5 },
        footwear = { item = 8 },
        gloves = { item = 0 },
        glasses = { item = 3 },
      },
      appearanceSpringLeisure = {
        top = { item = 5, color = 1 },
        bottom = { item = 2, color = 1 },
        footwear = { item = 7, color = 1 },
        gloves = { item = 0 },
        glasses = { item = 3 },
      },
      appearanceLeisure = {
        onepiece = { item = 3, color = 1 },
        footwear = { item = 1 },
        gloves = { item = 0 },
      },
      x = VLConfig.VILLAGER_SPAWNS.kenji.x, y = VLConfig.VILLAGER_SPAWNS.kenji.y,
      z = VLConfig.VILLAGER_SPAWNS.kenji.z, ry = VLConfig.VILLAGER_SPAWNS.kenji.ry },
    -- Marta: summer work = blouse/capris; summer leisure = collared shirt/skirt.
    { id = "marta",  name = "Marta",  personality = "generous",    isFemale = true,
      appearanceBase = {
        face = { item = 5 },
        hairStyle = { item = 16, color = 23 },
      },
      appearanceSummerWork = {
        onepiece = { item = 4, color = 6 },
        gloves   = { item = 2 },
        glasses  = { item = 1 },
      },
      appearanceFallWork = {
        top = { item = 18 },
        bottom = { item = 10 },
        footwear = { item = 15 },
        glasses = { item = 1 },
      },
      appearanceWinterWork = {
        top = { item = 13 },
        bottom = { item = 5 },
        footwear = { item = 4, color = 1 },
        gloves = { item = 3 },
        glasses = { item = 0 },
      },
      appearanceWork = {
        top = { item = 7 },
        bottom = { item = 8 },
        footwear = { item = 10 },
        glasses = { item = 1 },
      },
      appearanceSummerLeisure = {
        top = { item = 4 },
        bottom = { item = 11 },
        footwear = { item = 12 },
        glasses = { item = 1 },
      },
      appearanceLeisure = {
        top = { item = 7 },
        bottom = { item = 8 },
        footwear = { item = 10 },
        glasses = { item = 0 },
      },
      appearanceSpringLeisure = {
        top = { item = 5 },
        bottom = { item = 11 },
        footwear = { item = 10 },
        glasses = { item = 1 },
      },
      appearanceFallLeisure = {
        top = { item = 15 },
        bottom = { item = 14 },
        footwear = { item = 15 },
        glasses = { item = 1 },
      },
      appearanceWinterLeisure = {
        top = { item = 10 },
        bottom = { item = 5 },
        footwear = { item = 9 },
        gloves = { item = 3 },
        glasses = { item = 0 },
      },
      x = VLConfig.VILLAGER_SPAWNS.marta.x,  y = VLConfig.VILLAGER_SPAWNS.marta.y,
      z = VLConfig.VILLAGER_SPAWNS.marta.z,  ry = VLConfig.VILLAGER_SPAWNS.marta.ry,
      workLoop = VLConfig.VILLAGER_SPAWNS.marta.workLoop },
}

function VLNPCSystem.new()
    local self = setmetatable({}, VLNPCSystem)
    self.npcs          = {}   -- id -> VLNPCEntity
    self.relationships = VLRelationshipManager.new()
    self.scheduler     = VLNPCScheduler.new()
    self.sequencer     = VLEventSequencer.new(self)
    self.casualDialogue = VLCasualDialogue.new()
    self.dialog        = VLNPCDialog.new(self)
    self._outfitCalendar = OutfitCalendar.new()
    self.flags         = {}   -- name -> true; persisted story flags (e.g. walterMentionedMarket)
    return self
end

-- One-shot story flags (persisted). Used to fire a beat exactly once across a
-- save, e.g. Walter's post-tour market introduction.
function VLNPCSystem:getFlag(name)
    return self.flags[name] == true
end

function VLNPCSystem:setFlag(name, value)
    self.flags[name] = value and true or nil
end

function VLNPCSystem:initialize()
    print("[ValleyLife] Initializing...")
    for _, def in ipairs(VILLAGERS) do
        local npc = VLNPCEntity.new(def)
        self.npcs[def.id] = npc
        npc:setOutfitMode(npc:desiredOutfitMode(), { skipReapply = true })
        npc:spawn()
    end
    self:hookSaveLoad()
    self.dialog:registerInput()
    self._outfitCalendar:sync()
    print(string.format("[ValleyLife] %d villagers queued for spawn.", #VILLAGERS))
end

function VLNPCSystem:applyOutfitCalendarChange(change)
    if change.seasonChanged then
        print(string.format(
            "[ValleyLife] Season -> %s (month %d); refreshing villager outfits.",
            change.season, change.month))
    end
    if change.modeChanged then
        print(string.format(
            "[ValleyLife] Outfit mode -> %s (%s).",
            change.mode, change.reason))
    end
    for _, npc in pairs(self.npcs) do
        if npc.isLoaded then
            npc:applyCalendarOutfit(change)
        end
    end
end

function VLNPCSystem:update(dt)
    local change = self._outfitCalendar:poll()
    if change.seasonChanged or change.modeChanged then
        self:applyOutfitCalendarChange(change)
    end
    for _, npc in pairs(self.npcs) do
        if npc.isLoaded then
            npc:update(dt)
        end
    end
    self.dialog:update(dt)
end

function VLNPCSystem:getNPC(id)
    if type(id) == "string" then id = string.lower(id) end
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
    s:register(XMLValueType.INT,    root .. ".casual#count")
    s:register(XMLValueType.STRING, root .. ".casual.state(?)#npcId")
    s:register(XMLValueType.INT,    root .. ".casual.state(?)#rot")
    s:register(XMLValueType.INT,    root .. ".flags#count")
    s:register(XMLValueType.STRING, root .. ".flags.flag(?)#name")
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
    self.casualDialogue:saveToXML(xmlFile, key)
    self:saveFlagsToXML(xmlFile, key)
end

function VLNPCSystem:loadFromXML(xmlFile, missionKey)
    local key = missionKey or VLConfig.SAVE_KEY
    self.relationships:loadFromXML(xmlFile, key)
    self.sequencer:loadFromXML(xmlFile, key)
    self.casualDialogue:loadFromXML(xmlFile, key)
    self.casualDialogue:syncLegacyMet(self.relationships, self.sequencer)
    self:loadFlagsFromXML(xmlFile, key)
end

function VLNPCSystem:saveFlagsToXML(xmlFile, baseKey)
    local key = baseKey .. ".flags"
    local i = 0
    for name, set in pairs(self.flags) do
        if set then
            xmlFile:setValue(string.format("%s.flag(%d)#name", key, i), name)
            i = i + 1
        end
    end
    xmlFile:setValue(key .. "#count", i)
end

function VLNPCSystem:loadFlagsFromXML(xmlFile, baseKey)
    local key = baseKey .. ".flags"
    local count = xmlFile:getValue(key .. "#count", 0)
    for i = 0, count - 1 do
        local name = xmlFile:getValue(string.format("%s.flag(%d)#name", key, i))
        if name then self.flags[name] = true end
    end
end

function VLNPCSystem:delete()
    if self.dialog then self.dialog:delete() end
    for _, npc in pairs(self.npcs) do
        npc:delete()
    end
    self.npcs = {}
    print("[ValleyLife] Cleaned up.")
end
