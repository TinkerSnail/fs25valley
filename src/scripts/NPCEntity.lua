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
    self.appearance  = data.appearance   -- optional per-villager look (hair/clothing/colors)
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
    -- FS25's getTerrainHeightAtWorldPos takes 4 args (node, x, y, z); the y is a
    -- search seed and is ignored for the returned height. pcall guards against
    -- any signature drift so a bad call can never flood the per-frame update.
    local ok, y = pcall(getTerrainHeightAtWorldPos, g_currentMission.terrainRootNode, x, 0, z)
    if not ok or type(y) ~= "number" then return fallback or 0 end
    return y
end

-- How many selectable items a PlayerStyleConfig exposes, across API variants.
local function configItemCount(cfg)
    if type(cfg) ~= "table" then return 0 end
    local n
    for _, getter in ipairs({ "getNumOfItems", "getNumItems", "getItemCount" }) do
        if type(cfg[getter]) == "function" then
            local ok, v = pcall(cfg[getter], cfg)
            if ok and type(v) == "number" then n = v; break end
        end
    end
    if n == nil and type(cfg.items) == "table" then n = #cfg.items end
    return n or 0
end

-- How many color swatches a PlayerStyleConfig exposes. On FS25 each config owns
-- its color list (loaded from the player XML), exposed via getNumColors/getColors.
local function configColorCount(cfg)
    if type(cfg) ~= "table" then return 0 end
    for _, getter in ipairs({ "getNumColors", "getNumOfColors", "getColorCount" }) do
        if type(cfg[getter]) == "function" then
            local ok, v = pcall(cfg[getter], cfg)
            if ok and type(v) == "number" then return v end
        end
    end
    if type(cfg.getColors) == "function" then
        local ok, v = pcall(cfg.getColors, cfg)
        if ok and type(v) == "table" then return #v end
    end
    if type(cfg.colors) == "table" then return #cfg.colors end
    return 0
end

-- One-time deep dump of a config's fields + methods, so we can see exactly how
-- this build exposes its color list (the getNumColors-style probes return 0).
local dumpedConfig = false
local function dumpConfigOnce(cfg, name)
    if dumpedConfig or type(cfg) ~= "table" then return end
    dumpedConfig = true
    local fields = {}
    for k, v in pairs(cfg) do fields[#fields + 1] = string.format("%s:%s", tostring(k), type(v)) end
    table.sort(fields)
    print("[ValleyLife] DUMP " .. name .. " fields: " .. table.concat(fields, ", "))
    local mt = getmetatable(cfg)
    if mt and type(mt.__index) == "table" then
        local methods = {}
        for k, v in pairs(mt.__index) do
            if type(v) == "function" then methods[#methods + 1] = tostring(k) end
        end
        table.sort(methods)
        print("[ValleyLife] DUMP " .. name .. " methods: " .. table.concat(methods, ", "))
    end
end

-- Apply a per-villager appearance to a PlayerStyle. Every step is guarded so a
-- bad index or a missing config silently falls back to the default look rather
-- than breaking the spawn. `spec` maps config name -> { item = n, color = n }.
local function applyAppearance(style, spec, label)
    if type(style) ~= "table" or type(style.configs) ~= "table" or type(spec) ~= "table" then
        return
    end
    for name, choice in pairs(spec) do
        local cfg = style.configs[name]
        if type(cfg) == "table" then
            if name == "hairStyle" then dumpConfigOnce(cfg, name) end
            local itemCount  = configItemCount(cfg)
            local colorCount = configColorCount(cfg)
            if choice.item and itemCount > 0 then
                local idx = ((choice.item - 1) % itemCount) + 1
                pcall(function() cfg.selectedItemIndex = idx end)
            end
            -- Attempt the color directly (don't gate on colorCount, which reads 0
            -- on this build). If colorCount is known, wrap; else pass as-is and let
            -- the engine clamp. Read back what actually stuck for diagnostics.
            if choice.color then
                local cidx = choice.color
                if colorCount > 0 then cidx = ((choice.color - 1) % colorCount) + 1 end
                pcall(function()
                    if type(cfg.setSelectedColorIndex) == "function" then
                        cfg:setSelectedColorIndex(cidx)
                    elseif type(cfg.selectedColorIndex) == "number" then
                        cfg.selectedColorIndex = cidx
                    end
                end)
            end
            if label then
                local gotColor
                pcall(function()
                    if type(cfg.getSelectedColorIndex) == "function" then
                        gotColor = cfg:getSelectedColorIndex()
                    else
                        gotColor = cfg.selectedColorIndex
                    end
                end)
                print(string.format("[ValleyLife]   %s.%s: items=%d colors=%d (set item=%s color=%s -> colorIdx=%s)",
                    tostring(label), name, itemCount, colorCount,
                    tostring(choice.item), tostring(choice.color), tostring(gotColor)))
            end
        end
    end
    if label then
        local names = {}
        for name, _ in pairs(style.configs) do names[#names + 1] = name end
        table.sort(names)
        print(string.format("[ValleyLife] Appearance for %s; available configs: %s",
            tostring(label), table.concat(names, ", ")))
    end
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

    -- Build a FRESH style per NPC. PlayerStyle.defaultStyle() is a shared
    -- singleton — mutating it makes every NPC (and the player) look identical and
    -- race on async load. loadConfigurationXML populates configs + per-config
    -- color lists from the base-game player XML (male/female).
    local xmlFilename = self.isFemale and PLAYER_XML_FEMALE or PLAYER_XML_MALE
    local style = PlayerStyle.new()
    pcall(function()
        if style.loadConfigurationXML then style:loadConfigurationXML(xmlFilename) end
    end)
    pcall(function() style.xmlFilename = xmlFilename end)

    -- loadConfigurationXML's cached path copies configs but NOT the color palettes
    -- (style.hairColors / style.defaultClothingColors). Without them, a config's
    -- selectedColorIndex resolves against an empty palette and the default color
    -- renders. Pull the palettes from the game's cached base style.
    pcall(function()
        if PlayerSystem ~= nil and PlayerSystem.PLAYER_STYLES_BY_FILENAME ~= nil then
            local key = Utils.getFilename and Utils.getFilename(xmlFilename) or xmlFilename
            local entry = PlayerSystem.PLAYER_STYLES_BY_FILENAME[key]
            local src = entry and entry.style
            if src ~= nil then
                style.hairColors = src.hairColors
                style.defaultClothingColors = src.defaultClothingColors
                local nh = type(src.hairColors) == "table" and #src.hairColors or 0
                local nc = type(src.defaultClothingColors) == "table" and #src.defaultClothingColors or 0
                print(string.format("[ValleyLife] %s palettes: hairColors=%d clothingColors=%d",
                    self.name, nh, nc))
                if not VLNPCEntity._dumpedPalette and type(src.hairColors) == "table" then
                    VLNPCEntity._dumpedPalette = true
                    local function stringify(v, depth)
                        if type(v) ~= "table" then return tostring(v) end
                        if depth <= 0 then return "{...}" end
                        local parts = {}
                        for k, vv in pairs(v) do
                            parts[#parts + 1] = string.format("%s=%s", tostring(k), stringify(vv, depth - 1))
                        end
                        return "{" .. table.concat(parts, ", ") .. "}"
                    end
                    for i, c in ipairs(src.hairColors) do
                        print(string.format("[ValleyLife]   hairColor[%d] = %s", i, stringify(c, 2)))
                    end
                end
            else
                print("[ValleyLife] WARNING: no cached base style for " .. tostring(key))
            end
        end
    end)

    -- Give each villager a distinct look (guarded; falls back to default style).
    if self.appearance then
        applyAppearance(style, self.appearance, self.name)
    end

    if gfx.setStyleAsync then
        -- Signature: setStyleAsync(style, callback, callbackObject, callbackArgs,
        --   isTempStyle, xmlFile, isOwner). isTempStyle=true: this is a one-off NPC
        --   look, not an owned/persisted player style.
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
        end, self, nil, true, nil, false)
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
