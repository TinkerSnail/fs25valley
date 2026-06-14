-- One authored villager: 3D presence, position, animation state.

VLNPCEntity = {}
VLNPCEntity.__index = VLNPCEntity

-- Character model loaded from the mod's models/ folder.
-- Provide a retextured FS25 human i3d exported via GIANTS Exporter.
-- Falls back gracefully if the file is missing (NPC is invisible but position logic still runs).
local CHARACTER_MODEL = g_currentModDirectory .. "models/character.i3d"

function VLNPCEntity.new(data)
    local self = setmetatable({}, VLNPCEntity)
    self.id          = data.id
    self.name        = data.name
    self.personality = data.personality  -- "hardworking"|"lazy"|"social"|"grumpy"|"generous"
    self.position    = { x = data.x, y = data.y, z = data.z }
    self.rotation    = { y = data.ry or 0 }
    self.rootNode    = nil
    self.graphics    = nil
    self.isLoaded    = false
    self.isTalking   = false
    return self
end

function VLNPCEntity:spawn()
    g_i3DManager:cloneSharedI3D(CHARACTER_MODEL, self, VLNPCEntity.onModelLoaded)
end

function VLNPCEntity.onModelLoaded(self, node, failedReason)
    if not node or node == 0 then
        print(string.format("[ValleyLife] WARNING: model failed for NPC '%s' (%s). NPC will be invisible.", self.name, tostring(failedReason)))
        self.isLoaded = true
        return
    end

    self.rootNode = node
    link(getRootNode(), self.rootNode)

    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.position.x, self.position.z)
    setWorldTranslation(self.rootNode, self.position.x, y, self.position.z)
    setWorldRotation(self.rootNode, 0, self.rotation.y, 0)

    -- HumanGraphicsComponent drives walk/idle animation clips.
    -- If the API isn't available on this FS25 build the NPC will be a static mesh.
    if HumanGraphicsComponent ~= nil then
        local style = PlayerStyle.new()
        if PlayerStyle.defaultStyle then
            style:copyFrom(PlayerStyle.defaultStyle)
        end
        self.graphics = HumanGraphicsComponent.new(self.rootNode)
        if self.graphics and self.graphics.setPlayerStyle then
            self.graphics:setPlayerStyle(style)
        end
    end

    self.isLoaded = true
    print(string.format("[ValleyLife] Spawned NPC '%s' at (%.1f, %.1f, %.1f)", self.name, self.position.x, y, self.position.z))
end

function VLNPCEntity:update(dt)
    if not self.isLoaded or not self.rootNode then return end
    -- Snap Y to terrain every frame (prevents floating/sinking on uneven ground).
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.position.x, self.position.z)
    setWorldTranslation(self.rootNode, self.position.x, y, self.position.z)
    self.position.y = y
end

function VLNPCEntity:setPosition(x, y, z, ry)
    self.position.x = x
    self.position.y = y
    self.position.z = z
    if ry then self.rotation.y = ry end
    if self.rootNode then
        setWorldTranslation(self.rootNode, x, y, z)
        if ry then setWorldRotation(self.rootNode, 0, ry, 0) end
    end
end

function VLNPCEntity:getWorldPosition()
    if self.rootNode then
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
        self.graphics:delete()
        self.graphics = nil
    end
    if self.rootNode and self.rootNode ~= 0 then
        delete(self.rootNode)
        self.rootNode = nil
    end
    self.isLoaded = false
end
