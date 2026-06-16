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

local function getSelectedFaceName(style)
    local faceCfg = style.configs and style.configs.face
    if type(faceCfg) ~= "table" or type(faceCfg.getSelectedItem) ~= "function" then
        return nil
    end
    local ok, item = pcall(faceCfg.getSelectedItem, faceCfg)
    if ok and type(item) == "table" and item.name then return item.name end
    return nil
end

-- FS25 beards can be tied to a specific face mesh (beard.faceName). An incompatible
-- beard often renders as a permanent white/ghost layer on top of the jaw.
local function beardMatchesFace(beardItem, faceName)
    if type(beardItem) ~= "table" then return false end
    if beardItem.faceName == nil then return true end
    return faceName ~= nil and beardItem.faceName == faceName
end

local function findFirstCompatibleBeardIndex(beardCfg, faceName)
    if type(beardCfg) ~= "table" or type(beardCfg.items) ~= "table" then return 0 end
    for i = 1, #beardCfg.items do
        if beardMatchesFace(beardCfg.items[i], faceName) then return i end
    end
    return 0
end

local function applyConfigChoice(cfg, choice, configName)
    if type(cfg) ~= "table" or type(choice) ~= "table" then return end
    local itemCount = configItemCount(cfg)
    if choice.item == 0 then
        pcall(function() cfg.selectedItemIndex = 0 end)
    elseif choice.item and itemCount > 0 then
        local idx = ((choice.item - 1) % itemCount) + 1
        pcall(function() cfg.selectedItemIndex = idx end)
    end
    -- hairStyle/beard colors are applied AFTER the beard mesh is chosen (see below).
    if choice.color and configName ~= "hairStyle" and configName ~= "beard" then
        local colorCount = configColorCount(cfg)
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
end

local function applyHairBeardColors(style, spec, splitColors)
    local hair = style.configs.hairStyle
    local beard = style.configs.beard
    local hc = spec.hairStyle and spec.hairStyle.color
    local bc = spec.beard and spec.beard.color

    if splitColors then
        if hc and type(hair) == "table" and type(hair.setSelectedColorIndex) == "function" then
            pcall(function() hair:setSelectedColorIndex(hc) end)
        end
        if bc and type(beard) == "table" and type(beard.setSelectedColorIndex) == "function" then
            pcall(function() beard:setSelectedColorIndex(bc) end)
        end
        print(string.format("[ValleyLife][exp] split colors: hair=%s beard=%s (no unify)",
            tostring(hc), tostring(bc)))
        return
    end

    -- Normal: tint AFTER face + hair mesh + beard mesh are all selected. Coloring
    -- before the beard mesh is picked often leaves a permanent white/default beard.
    if hc and type(hair) == "table" and type(hair.setSelectedColorIndex) == "function" then
        pcall(function() hair:setSelectedColorIndex(hc) end)
    elseif type(hair) == "table"
        and type(hair.getSelectedColorIndex) == "function"
        and type(hair.setSelectedColorIndex) == "function" then
        pcall(function() hair:setSelectedColorIndex(hair:getSelectedColorIndex()) end)
    end
    -- Belt-and-suspenders: push the same palette index onto the beard config too.
    if type(beard) == "table" and beard.selectedItemIndex and beard.selectedItemIndex > 0
        and type(hair) == "table" and type(hair.getSelectedColorIndex) == "function"
        and type(beard.setSelectedColorIndex) == "function" then
        local ok, cidx = pcall(hair.getSelectedColorIndex, hair)
        if ok and cidx then
            pcall(function() beard:setSelectedColorIndex(cidx) end)
        end
    end
end

-- Apply a per-villager appearance to a PlayerStyle. Every step is guarded so a
-- bad index or a missing config silently falls back to the default look rather
-- than breaking the spawn. `spec` maps config name -> { item = n, color = n }.
-- Item indices wrap to the available count; color indexes into the style's
-- palette (hairColors / defaultClothingColors), which must be populated first.
-- opts.splitHairBeardColors: apply hair color first, then beard color, and skip
-- the engine's unification step (experimental — tests whether different shades stick).
local function applyAppearance(style, spec, opts)
    if type(style) ~= "table" or type(style.configs) ~= "table" or type(spec) ~= "table" then
        return
    end
    opts = opts or {}
    local splitColors = opts.splitHairBeardColors == true

    -- Apply face before beard so compatibility checks see the correct face mesh.
    if spec.face then
        applyConfigChoice(style.configs.face, spec.face, "face")
    end
    if spec.hairStyle then
        applyConfigChoice(style.configs.hairStyle, spec.hairStyle, "hairStyle")
    end
    if spec.beard then
        applyConfigChoice(style.configs.beard, spec.beard, "beard")
        local beardCfg = style.configs.beard
        local faceName = getSelectedFaceName(style)
        local idx = beardCfg and beardCfg.selectedItemIndex
        local item = beardCfg and beardCfg.items and idx and beardCfg.items[idx]
        if idx and idx > 0 and item and not beardMatchesFace(item, faceName) then
            local alt = findFirstCompatibleBeardIndex(beardCfg, faceName)
            print(string.format(
                "[ValleyLife] Beard item %d incompatible with face '%s' (needs face-specific mesh) -> item %d",
                idx, tostring(faceName), alt))
            pcall(function() beardCfg.selectedItemIndex = alt end)
        end
    end
    for name, choice in pairs(spec) do
        if name ~= "face" and name ~= "hairStyle" and name ~= "beard" then
            applyConfigChoice(style.configs[name], choice, name)
        end
    end

    applyHairBeardColors(style, spec, splitColors)
end

-- Build a FRESH PlayerStyle for this villager. PlayerStyle.defaultStyle() is a
-- shared singleton — mutating it makes every NPC (and the player) look identical
-- and race on async load. loadConfigurationXML populates configs from the base
-- player XML, but NOT the color palettes (hairColors / defaultClothingColors), so
-- we copy those from the game's cached base style or per-config color lists fail.
local function buildStyle(self)
    local xmlFilename = self.isFemale and PLAYER_XML_FEMALE or PLAYER_XML_MALE
    local style = PlayerStyle.new()
    pcall(function()
        if style.loadConfigurationXML then style:loadConfigurationXML(xmlFilename) end
    end)
    pcall(function() style.xmlFilename = xmlFilename end)
    pcall(function()
        if PlayerSystem ~= nil and PlayerSystem.PLAYER_STYLES_BY_FILENAME ~= nil then
            local key = Utils.getFilename and Utils.getFilename(xmlFilename) or xmlFilename
            local entry = PlayerSystem.PLAYER_STYLES_BY_FILENAME[key]
            local src = entry and entry.style
            if src ~= nil then
                style.hairColors = src.hairColors
                style.defaultClothingColors = src.defaultClothingColors
            end
        end
    end)
    if self.appearance then
        applyAppearance(style, self.appearance, self._applyOpts)
    end
    -- Spawn diagnostic: confirms mesh + color indices after the full apply pass.
    pcall(function()
        local hair = style.configs.hairStyle
        local beard = style.configs.beard
        local face = style.configs.face
        local hairColor, beardColor = "?", "?"
        local hairName, faceName = "?", "?"
        if hair and hair.getSelectedColorIndex then
            local ok, v = pcall(hair.getSelectedColorIndex, hair)
            if ok then hairColor = tostring(v) end
        end
        if hair and hair.getSelectedItem then
            local ok, item = pcall(hair.getSelectedItem, hair)
            if ok and item then hairName = tostring(item.name or "?") end
        end
        if face and face.getSelectedItem then
            local ok, item = pcall(face.getSelectedItem, face)
            if ok and item then faceName = tostring(item.name or "?") end
        end
        if beard and beard.getSelectedColorIndex then
            local ok, v = pcall(beard.getSelectedColorIndex, beard)
            if ok then beardColor = tostring(v) end
        end
        print(string.format(
            "[ValleyLife] %s style: face=%s item=%s | hair '%s' item=%s color=%s | beard item=%s color=%s",
            self.name, faceName, tostring(face and face.selectedItemIndex),
            hairName, tostring(hair and hair.selectedItemIndex), hairColor,
            tostring(beard and beard.selectedItemIndex), beardColor))
    end)
    return style
end

-- Build a preview style for console diagnostics (vlBeards, etc.).
function VLNPCEntity:buildPreviewStyle()
    return buildStyle(self)
end

-- Re-apply the current self.appearance to a spawned NPC by fully respawning the
-- model. Used by the vlFace / vlHairColor console commands to preview variants
-- live. We delete + rebuild rather than calling setStyleAsync again on the same
-- graphics component, because re-applying onto the existing component stacks the
-- new meshes on top of the old ones (e.g. two beards colliding).
-- opts: optional table passed to applyAppearance (e.g. splitHairBeardColors).
function VLNPCEntity:reapplyAppearance(opts)
    if not humanApiAvailable() then return false end
    self._applyOpts = opts
    self:delete()
    local ok, err = pcall(function() self:buildAnimatedCharacter() end)
    self._applyOpts = nil
    if not ok then
        print("[ValleyLife] reapplyAppearance failed: " .. tostring(err))
        return false
    end
    return true
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

    -- Build a FRESH style per NPC (see buildStyle); falls back to default look.
    local style = buildStyle(self)

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
