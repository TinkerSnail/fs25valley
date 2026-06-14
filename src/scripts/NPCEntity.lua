-- One authored villager: an animated human built from FS25's own character
-- assets via HumanGraphicsComponent (no custom i3d model required).
--
-- Spawn flow (mirrors the proven NPCFavor approach):
--   HumanGraphicsComponent.new() -> :initialize() creates graphicsRootNode
--   position the node + set idle animation parameters
--   build a PlayerStyle pointing at the base-game player XML (male/female)
--   :setStyleAsync(style, cb) loads the mesh; on OK we make it visible

VLNPCEntity = {}
VLNPCEntity.__index = VLNPCEntity

local PLAYER_XML_MALE   = "dataS/character/playerM/playerM.xml"
local PLAYER_XML_FEMALE = "dataS/character/playerF/playerF.xml"

function VLNPCEntity.new(data)
    local self = setmetatable({}, VLNPCEntity)
    self.id          = data.id
    self.name        = data.name
    self.personality = data.personality
    self.isFemale    = data.isFemale == true
    self.position    = { x = data.x, y = data.y, z = data.z }
    self.rotation    = { y = data.ry or 0 }
    self.rootNode    = nil
    self.graphics    = nil
    self.isLoaded    = false
    self.modelLoaded = false
    self.isTalking   = false
    return self
end

local function humanApiAvailable()
    return HumanGraphicsComponent ~= nil
        and HumanGraphicsComponent.new ~= nil
        and PlayerStyle ~= nil
        and HumanModelLoadingState ~= nil
end

function VLNPCEntity:spawn()
    if not humanApiAvailable() then
        print(string.format("[ValleyLife] WARNING: HumanGraphicsComponent API unavailable; '%s' will not be visible.", self.name))
        self.isLoaded = true
        return
    end

    local ok, err = pcall(function() self:buildAnimatedCharacter() end)
    if not ok then
        print(string.format("[ValleyLife] ERROR spawning '%s': %s", self.name, tostring(err)))
        if self.graphics then
            pcall(function() self.graphics:delete() end)
            self.graphics = nil
        end
        self.rootNode = nil   -- node is gone; skip it in update/position logic
        self.isLoaded = true  -- keep relationship/dialog logic alive even if invisible
    end
end

local function nodeValid(node)
    return node ~= nil and node ~= 0 and entityExists(node)
end

-- Always returns a number. getTerrainHeightAtWorldPos can return nil for
-- positions off the terrain (e.g. placeholder 0,0,0 coords), which would
-- otherwise poison setTranslation/print with a nil y.
local function terrainY(x, z, fallback)
    if g_currentMission == nil or g_currentMission.terrainRootNode == nil then
        return fallback or 0
    end
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, z)
    if type(y) ~= "number" then return fallback or 0 end
    return y
end

function VLNPCEntity:buildAnimatedCharacter()
    local gfx = HumanGraphicsComponent.new()
    gfx:initialize()
    if not gfx.graphicsRootNode or gfx.graphicsRootNode == 0 then
        error("graphicsRootNode creation failed")
    end

    self.graphics = gfx
    self.rootNode = gfx.graphicsRootNode

    -- Snap to terrain and place.
    local y = terrainY(self.position.x, self.position.z, 0)
    self.position.y = y
    setTranslation(self.rootNode, self.position.x, y, self.position.z)
    setRotation(self.rootNode, 0, self.rotation.y, 0)

    -- Idle, grounded NPC animation state. These params are optional hints;
    -- on some builds they are raw handles (numbers) rather than objects, so
    -- only call setValue when it's actually a settable parameter object.
    local p = gfx.animationParameters
    if type(p) == "table" then
        local function setParam(param, value)
            if type(param) == "table" and type(param.setValue) == "function" then
                param:setValue(value)
            end
        end
        setParam(p.isNPC, true)
        setParam(p.isGrounded, true)
        setParam(p.isCloseToGround, true)
        setParam(p.isIdling, true)
    end

    -- Build a style from the base-game player definition.
    local style
    if PlayerStyle.defaultStyle then
        local okStyle, s = pcall(PlayerStyle.defaultStyle)
        if okStyle then style = s end
    end
    if not style then style = PlayerStyle.new() end

    local xmlFilename = self.isFemale and PLAYER_XML_FEMALE or PLAYER_XML_MALE
    pcall(function() style.xmlFilename = xmlFilename end)
    pcall(function()
        if style.loadConfigurationXML then style:loadConfigurationXML(xmlFilename) end
    end)

    if gfx.setStyleAsync then
        gfx:setStyleAsync(style, function(target, loadingState, loadedNewModel, args)
            if loadingState == HumanModelLoadingState.OK then
                self.modelLoaded = true
                pcall(function() gfx:setModelVisibility(true) end)
                print(string.format("[ValleyLife] Spawned NPC '%s' at (%.1f, %.1f, %.1f)",
                    self.name, self.position.x, self.position.y, self.position.z))
            else
                print(string.format("[ValleyLife] Model load failed for '%s' (state=%s)",
                    self.name, tostring(loadingState)))
            end
        end, self, nil, false, nil, false)
    end

    self.isLoaded = true
end

function VLNPCEntity:update(dt)
    if not nodeValid(self.rootNode) then return end
    -- Keep grounded on uneven terrain.
    local y = terrainY(self.position.x, self.position.z, self.position.y or 0)
    self.position.y = y
    setTranslation(self.rootNode, self.position.x, y, self.position.z)
end

function VLNPCEntity:setPosition(x, y, z, ry)
    self.position.x = x
    self.position.y = y
    self.position.z = z
    if ry then self.rotation.y = ry end
    if self.rootNode then
        setTranslation(self.rootNode, x, y, z)
        if ry then setRotation(self.rootNode, 0, ry, 0) end
    end
end

function VLNPCEntity:getWorldPosition()
    if nodeValid(self.rootNode) then
        local wx, wy, wz = getWorldTranslation(self.rootNode)
        return wx, wy, wz
    end
    return self.position.x, self.position.y, self.position.z
end

function VLNPCEntity:isNearPlayer(radius)
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    if not player then return false end
    local px, py, pz = getWorldTranslation(player.rootNode)
    local nx, ny, nz = self:getWorldPosition()
    local dx, dz = nx - px, nz - pz
    return (dx*dx + dz*dz) <= (radius * radius)
end

function VLNPCEntity:delete()
    if self.graphics then
        pcall(function() self.graphics:delete() end)
        self.graphics = nil
    end
    self.rootNode = nil
    self.isLoaded = false
end
