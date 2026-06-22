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

local APPEARANCE_BASE_KEYS = { face = true, hairStyle = true, beard = true }

local function isAppearanceBaseKey(name)
    return APPEARANCE_BASE_KEYS[name] == true
end

local function splitAppearance(appearance)
    local base, outfit = {}, {}
    if type(appearance) ~= "table" then return base, outfit end
    for name, choice in pairs(appearance) do
        if isAppearanceBaseKey(name) then
            base[name] = choice
        else
            outfit[name] = choice
        end
    end
    return base, outfit
end

local function mergeAppearance(base, outfit)
    local merged = {}
    if type(base) == "table" then
        for name, choice in pairs(base) do merged[name] = choice end
    end
    if type(outfit) == "table" then
        for name, choice in pairs(outfit) do merged[name] = choice end
    end
    return merged
end

function VLNPCEntity.new(data)
    local self = setmetatable({}, VLNPCEntity)
    self.id          = data.id
    self.name        = data.name
    self.personality = data.personality
    self.birthday = data.birthday
    if not BirthdayHelper.isValid(self.birthday) then
        self.birthday = BirthdayHelper.fromNpcId(self.id)
    end
    self.isFemale    = data.isFemale == true
    self.appearanceBase  = data.appearanceBase
    self.appearanceWork  = data.appearanceWork
    self.appearanceLeisure = data.appearanceLeisure
    if data.appearance ~= nil then
        local base, work = splitAppearance(data.appearance)
        self.appearanceBase = self.appearanceBase or base
        self.appearanceWork = self.appearanceWork or work
    end
    self.appearanceBase = self.appearanceBase or {}
    self.appearanceWork = self.appearanceWork or {}
    self.appearanceLeisure = self.appearanceLeisure or {}
    self.seasonalWorkOutfits = data.seasonalWorkOutfits or {}
    self.seasonalLeisureOutfits = data.seasonalLeisureOutfits or {}
    if data.appearanceSummerWork ~= nil then
        self.seasonalWorkOutfits.summer = data.appearanceSummerWork
    end
    if data.appearanceFallWork ~= nil then
        self.seasonalWorkOutfits.autumn = data.appearanceFallWork
    end
    if data.appearanceWinterWork ~= nil then
        self.seasonalWorkOutfits.winter = data.appearanceWinterWork
    end
    if data.appearanceSpringWork ~= nil then
        self.seasonalWorkOutfits.spring = data.appearanceSpringWork
    end
    if data.appearanceSummerLeisure ~= nil then
        self.seasonalLeisureOutfits.summer = data.appearanceSummerLeisure
    end
    if data.appearanceFallLeisure ~= nil then
        self.seasonalLeisureOutfits.autumn = data.appearanceFallLeisure
    end
    if data.appearanceWinterLeisure ~= nil then
        self.seasonalLeisureOutfits.winter = data.appearanceWinterLeisure
    end
    if data.appearanceSpringLeisure ~= nil then
        self.seasonalLeisureOutfits.spring = data.appearanceSpringLeisure
    end
    self.appearanceDate = data.appearanceDate or nil
    self.seasonalDateOutfits = data.seasonalDateOutfits or {}
    if data.appearanceSummerDate ~= nil then
        self.seasonalDateOutfits.summer = data.appearanceSummerDate
    end
    if data.appearanceFallDate ~= nil then
        self.seasonalDateOutfits.autumn = data.appearanceFallDate
    end
    if data.appearanceWinterDate ~= nil then
        self.seasonalDateOutfits.winter = data.appearanceWinterDate
    end
    if data.appearanceSpringDate ~= nil then
        self.seasonalDateOutfits.spring = data.appearanceSpringDate
    end
    if type(self.appearanceWork) == "table" and next(self.appearanceWork) ~= nil
        and self.seasonalWorkOutfits.summer == nil then
        self.seasonalWorkOutfits.summer = self.appearanceWork
    end
    self._outfitMode = "work"
    self._outfitCalendarLocked = false
    self.appearance = {}
    self:refreshMergedAppearance()
    self.position    = { x = data.x, y = data.y, z = data.z }
    self.rotation    = { y = data.ry or 0 }
    self.rootNode    = nil
    self.graphics    = nil
    self.isLoaded    = false
    self.modelLoaded = false
    self.isTalking   = false
    self.useDirectAnimation = false
    self.animCharSet = nil
    self._animSetupRetries = 0
    self._idleClipIdx = nil
    self._walkClipIdx = nil
    self._workLoops         = data.workLoops or (data.workLoop and {data.workLoop} or nil)
self._workLoop          = nil
    self._walk              = nil
    self._walkLastHour      = -1
    self._homeRy            = data.ry or 0
    self._directTrackWalking = false
    self._walkDirectTrack   = false
    return self
end

local function humanApiAvailable()
    return HumanGraphicsComponent ~= nil
        and HumanGraphicsComponent.new ~= nil
        and PlayerStyle ~= nil
        and HumanModelLoadingState ~= nil
end

local SEASON_WORK_FALLBACK = {
    winter = { "autumn", "summer", "spring" },
    spring = { "summer", "autumn", "winter" },
    summer = { "spring", "autumn", "winter" },
    autumn = { "summer", "spring", "winter" },
}

local SEASON_LEISURE_FALLBACK = {
    winter = { "autumn", "summer", "spring" },
    spring = { "summer", "autumn", "winter" },
    summer = { "spring", "autumn", "winter" },
    autumn = { "summer", "spring", "winter" },
}

local function outfitHasLayers(outfit)
    return type(outfit) == "table" and next(outfit) ~= nil
end

function VLNPCEntity:usesSeasonalWorkOutfits()
    if type(self.seasonalWorkOutfits) ~= "table" then return false end
    for _, outfit in pairs(self.seasonalWorkOutfits) do
        if outfitHasLayers(outfit) then return true end
    end
    return false
end

function VLNPCEntity:usesSeasonalLeisureOutfits()
    if type(self.seasonalLeisureOutfits) ~= "table" then return false end
    for _, outfit in pairs(self.seasonalLeisureOutfits) do
        if outfitHasLayers(outfit) then return true end
    end
    return false
end

function VLNPCEntity:getActiveLeisureOutfit()
    if not self:usesSeasonalLeisureOutfits() then
        return self.appearanceLeisure
    end
    local season = TimeHelper.getSeason()
    local primary = self.seasonalLeisureOutfits[season]
    if outfitHasLayers(primary) then return primary end
    local fallbacks = SEASON_LEISURE_FALLBACK[season]
    if fallbacks ~= nil then
        for _, fb in ipairs(fallbacks) do
            local o = self.seasonalLeisureOutfits[fb]
            if outfitHasLayers(o) then return o end
        end
    end
    return self.appearanceLeisure
end

function VLNPCEntity:getEditableLeisureOutfit()
    if self:usesSeasonalLeisureOutfits() then
        local season = TimeHelper.getSeason()
        if self.seasonalLeisureOutfits[season] == nil then
            self.seasonalLeisureOutfits[season] = {}
        end
        return self.seasonalLeisureOutfits[season]
    end
    return self.appearanceLeisure
end

function VLNPCEntity:usesSeasonalDateOutfits()
    if type(self.seasonalDateOutfits) ~= "table" then return false end
    for _, outfit in pairs(self.seasonalDateOutfits) do
        if outfitHasLayers(outfit) then return true end
    end
    return false
end

function VLNPCEntity:getActiveDateOutfit()
    if self:usesSeasonalDateOutfits() then
        local season = TimeHelper.getSeason()
        local primary = self.seasonalDateOutfits[season]
        if outfitHasLayers(primary) then return primary end
        local fallbacks = SEASON_LEISURE_FALLBACK[season]
        if fallbacks ~= nil then
            for _, fb in ipairs(fallbacks) do
                local o = self.seasonalDateOutfits[fb]
                if outfitHasLayers(o) then return o end
            end
        end
    end
    if outfitHasLayers(self.appearanceDate) then return self.appearanceDate end
    return self:getActiveLeisureOutfit()
end

function VLNPCEntity:getEditableDateOutfit()
    if self:usesSeasonalDateOutfits() then
        local season = TimeHelper.getSeason()
        if self.seasonalDateOutfits[season] == nil then
            self.seasonalDateOutfits[season] = {}
        end
        return self.seasonalDateOutfits[season]
    end
    self.appearanceDate = self.appearanceDate or {}
    return self.appearanceDate
end

function VLNPCEntity:getActiveWorkOutfit()
    if not self:usesSeasonalWorkOutfits() then
        return self.appearanceWork
    end
    local season = TimeHelper.getSeason()
    local primary = self.seasonalWorkOutfits[season]
    if outfitHasLayers(primary) then return primary end
    local fallbacks = SEASON_WORK_FALLBACK[season]
    if fallbacks ~= nil then
        for _, fb in ipairs(fallbacks) do
            local o = self.seasonalWorkOutfits[fb]
            if outfitHasLayers(o) then return o end
        end
    end
    return self.appearanceWork
end

function VLNPCEntity:getEditableWorkOutfit()
    if self:usesSeasonalWorkOutfits() then
        local season = TimeHelper.getSeason()
        if self.seasonalWorkOutfits[season] == nil then
            self.seasonalWorkOutfits[season] = {}
        end
        return self.seasonalWorkOutfits[season]
    end
    return self.appearanceWork
end

function VLNPCEntity:refreshMergedAppearance()
    local outfit
    if self._outfitMode == "date" then
        outfit = self:getActiveDateOutfit()
    elseif self._outfitMode == "leisure" then
        outfit = self:getActiveLeisureOutfit()
    else
        outfit = self:getActiveWorkOutfit()
    end
    self.appearance = mergeAppearance(self.appearanceBase, outfit)
end

function VLNPCEntity:refreshSeasonalOutfit()
    self:refreshMergedAppearance()
    if self.graphics ~= nil or self.isLoaded then
        return self:reapplyAppearance()
    end
    return true
end

function VLNPCEntity:refreshSeasonalWorkOutfit()
    if self._outfitMode ~= "work" then return false end
    return self:refreshSeasonalOutfit()
end

function VLNPCEntity:getOutfitMode()
    return self._outfitMode or "work"
end

function VLNPCEntity:setAppearanceLayer(configName, patch)
    if type(configName) ~= "string" or type(patch) ~= "table" then return end
    if isAppearanceBaseKey(configName) then
        self.appearanceBase[configName] = self.appearanceBase[configName] or {}
        for k, v in pairs(patch) do self.appearanceBase[configName][k] = v end
    else
        local outfit = self._outfitMode == "leisure" and self:getEditableLeisureOutfit() or self:getEditableWorkOutfit()
        outfit[configName] = outfit[configName] or {}
        for k, v in pairs(patch) do outfit[configName][k] = v end
    end
    self:refreshMergedAppearance()
end

function VLNPCEntity:desiredOutfitMode()
    return TimeHelper.getOutfitMode()
end

function VLNPCEntity:setOutfitMode(mode, opts)
    if mode ~= "work" and mode ~= "leisure" and mode ~= "date" then return false end
    opts = opts or {}
    if mode == self._outfitMode and not opts.force then
        return false
    end
    self._outfitMode = mode
    self:refreshMergedAppearance()
    if opts.skipReapply then return true end
    if self.graphics ~= nil or self.isLoaded then
        return self:reapplyAppearance()
    end
    return true
end

function VLNPCEntity:updateOutfitForTime()
    local want = self:desiredOutfitMode()
    if want ~= self._outfitMode then
        self:setOutfitMode(want)
    end
end

-- Apply calendar-driven work/leisure mode and/or seasonal outfit layers; reapply model once.
function VLNPCEntity:applyCalendarOutfit(change)
    if type(change) ~= "table" then return false end
    local needReapply = false

    if not self._outfitCalendarLocked and change.modeChanged then
        local want = self:desiredOutfitMode()
        if want ~= self._outfitMode then
            self._outfitMode = want
            needReapply = true
        end
    end

    if change.seasonChanged or needReapply then
        self:refreshMergedAppearance()
        if self.graphics ~= nil or self.isLoaded then
            self:reapplyAppearance()
            return true
        end
    end
    return needReapply
end

function VLNPCEntity:setOutfitCalendarLocked(locked)
    self._outfitCalendarLocked = locked == true
end

function VLNPCEntity:isOutfitCalendarLocked()
    return self._outfitCalendarLocked == true
end

function VLNPCEntity:syncOutfitToCalendar()
    if self._outfitCalendarLocked then
        self._outfitCalendarLocked = false
    end
    local want = self:desiredOutfitMode()
    local modeChanged = want ~= self._outfitMode
    if modeChanged then
        self._outfitMode = want
    end
    self:refreshMergedAppearance()
    if self.graphics ~= nil or self.isLoaded then
        return self:reapplyAppearance()
    end
    return modeChanged
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

local function findForHatHairIndex(hairCfg, currentIdx)
    if type(hairCfg) ~= "table" or type(hairCfg.items) ~= "table" then
        return currentIdx
    end
    local items = hairCfg.items
    local current = currentIdx and items[currentIdx]
    if type(current) == "table" and current.forHat then
        return currentIdx
    end
    local currentName = type(current) == "table" and current.name or ""
    local forHatList = {}
    for i, item in ipairs(items) do
        if type(item) == "table" and item.forHat then
            forHatList[#forHatList + 1] = i
            if currentName ~= "" and item.name and string.find(item.name, currentName, 1, true) then
                return i
            end
        end
    end
    if #forHatList == 0 then return currentIdx end
    local best, bestDist = forHatList[1], math.huge
    local target = currentIdx or 0
    for _, i in ipairs(forHatList) do
        local d = math.abs(i - target)
        if d < bestDist then
            bestDist = d
            best = i
        end
    end
    return best
end

-- FS25 hides regular hair meshes when headgear is worn. Character creation uses
-- hairStyle items marked forHat (shorter / cap-friendly). Swap at apply time so
-- authored appearance.hairStyle.item stays the "no hat" choice.
local function ensureHairCompatibleWithHeadgear(style)
    local headgear = style.configs and style.configs.headgear
    local hair = style.configs and style.configs.hairStyle
    if type(headgear) ~= "table" or type(hair) ~= "table" then return end
    local hgIdx = headgear.selectedItemIndex
    if hgIdx == nil or hgIdx <= 0 then return end
    local hairIdx = hair.selectedItemIndex
    if hairIdx == nil or hairIdx <= 0 then return end
    local newIdx = findForHatHairIndex(hair, hairIdx)
    if newIdx ~= hairIdx then
        pcall(function() hair.selectedItemIndex = newIdx end)
        local name = hair.items and hair.items[newIdx] and hair.items[newIdx].name
        print(string.format(
            "[ValleyLife] headgear worn: hair item %d -> forHat item %d (%s)",
            hairIdx, newIdx, tostring(name or "?")))
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
-- the engine's unification step (experimental - tests whether different shades stick).
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
    -- Only apply clothing layers explicitly listed in appearance. Unset layers keep
    -- loadConfigurationXML defaults (selectedItemIndex 0 = no shirt/pants mesh).
    -- Underwear is NOT a top/bottom catalog item - it is bodyParts on the base
    -- player i3d, shown when no clothing is selected. Do not force item 0 here;
    -- that bypasses updateDisabledOptions and can leave body parts hidden (transparent).
    for name, choice in pairs(spec) do
        if name ~= "face" and name ~= "hairStyle" and name ~= "beard" then
            applyConfigChoice(style.configs[name], choice, name)
        end
    end

    ensureHairCompatibleWithHeadgear(style)

    applyHairBeardColors(style, spec, splitColors)

    pcall(function()
        if type(style.updateDisabledOptions) == "function" then
            style:updateDisabledOptions()
        end
    end)
end

-- Build a FRESH PlayerStyle for this villager. PlayerStyle.defaultStyle() is a
-- shared singleton - mutating it makes every NPC (and the player) look identical
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

local function setAnimParam(param, value)
    -- Guard the type first: indexing a number/boolean (param.setValue) throws
    -- "attempt to index number" before a `type(param.setValue)` test can run.
    if type(param) ~= "table" and type(param) ~= "userdata" then return end
    if type(param.setValue) ~= "function" then return end
    pcall(function() param:setValue(value) end)
end

local IDLE_CLIP_CANDIDATES_FEMALE = {
    "idle1FemaleSource", "idle1Source", "idle2FemaleSource", "idle2Source", "idleSource",
}
local IDLE_CLIP_CANDIDATES_MALE = {
    "idle1Source", "idle2Source", "idleSource", "idle1FemaleSource",
}
local WALK_CLIP_CANDIDATES_FEMALE = {
    "NPCWalkFemale01Source",   -- NPC walk female variant 1 (may exist past index 80)
    "NPCWalkFemale02Source",   -- [52] NPC walk female variant 2
    "NPCWalkFemale03Source",   -- [53] NPC walk female variant 3
    "walkFwd1FemaleSource",    -- [33] player walk female (faster, fallback only)
}
local WALK_CLIP_CANDIDATES_MALE = {
    "NPCWalkMale01Source",     -- NPC walk male variant 1 (may exist past index 80)
    "NPCWalkMale02Source",     -- [54] NPC walk male variant 2
    "NPCWalkMale03Source",     -- [55] NPC walk male variant 3
    "walkFwd1Source",          -- player walk male (may exist past index 80, fallback)
}

local function findAnimClip(charSet, candidates)
    if charSet == nil or charSet == 0 or getAnimClipIndex == nil then return -1, nil end
    for _, name in ipairs(candidates) do
        local ok, idx = pcall(getAnimClipIndex, charSet, name)
        if ok and type(idx) == "number" and idx >= 0 then
            return idx, name
        end
    end
    return -1, nil
end

local function resolveAnimCharacterSet(skeleton)
    if skeleton == nil or skeleton == 0 or getAnimCharacterSet == nil then return 0 end
    local charSet = 0
    pcall(function()
        charSet = getAnimCharacterSet(skeleton)
        if charSet == 0 then
            local child = getChildAt(skeleton, 0)
            if child ~= nil and child ~= 0 then
                charSet = getAnimCharacterSet(child)
            end
        end
    end)
    return charSet or 0
end

-- VehicleCharacter / NPCFavor pattern: clone character clips onto the skeleton and
-- enable the idle track. The engine advances enabled tracks without gfx:update().
function VLNPCEntity:setupDirectIdleAnimation()
    local gfx = self.graphics
    if gfx == nil or gfx.model == nil then return false end
    local skeleton = gfx.model.skeleton
    if skeleton == nil or skeleton == 0 then return false end

    -- Prefer the character set already loaded by setStyleAsync — it contains the full
    -- animation library (idle + walk + run). Only fall back to cloning from AnimationCache
    -- if nothing is there yet, since cloning overwrites the rich set with idle clips only.
    local charSet = resolveAnimCharacterSet(skeleton)

    if charSet == 0 and g_animCache ~= nil and AnimationCache ~= nil and cloneAnimCharacterSet ~= nil then
        pcall(function()
            local animNode = g_animCache:getNode(AnimationCache.CHARACTER)
            if animNode ~= nil and animNode ~= 0 then
                local src = getChildAt(animNode, 0)
                if src ~= nil and src ~= 0 then
                    cloneAnimCharacterSet(src, skeleton)
                end
            end
        end)
        charSet = resolveAnimCharacterSet(skeleton)
    end

    if charSet == 0 then return false end

    local idleCandidates = self.isFemale and IDLE_CLIP_CANDIDATES_FEMALE or IDLE_CLIP_CANDIDATES_MALE
    local idleClip, idleName = findAnimClip(charSet, idleCandidates)
    if idleClip < 0 then return false end

    local ok = pcall(function()
        clearAnimTrackClip(charSet, 0)
        assignAnimTrackClip(charSet, 0, idleClip)
        setAnimTrackLoopState(charSet, 0, true)
        enableAnimTrack(charSet, 0)
        if disableAnimTrack ~= nil then
            disableAnimTrack(charSet, 1)
        end
    end)
    if not ok then return false end

    self.useDirectAnimation = true
    self.animCharSet = charSet
    self._idleClipIdx = idleClip

    -- Cache the walk clip index now so _onWalkStart can assign it without a search.
    local walkCandidates = self.isFemale and WALK_CLIP_CANDIDATES_FEMALE or WALK_CLIP_CANDIDATES_MALE
    local walkClip, walkName = findAnimClip(charSet, walkCandidates)
    self._walkClipIdx = walkClip
    if walkClip >= 0 then
        print(string.format("[ValleyLife] '%s' idle: %s | walk: %s (direct tracks)", self.name, idleName, walkName))
    else
        print(string.format("[ValleyLife] '%s' idle: %s (direct track; no walk clip found)", self.name, idleName))
    end
    return true
end

function VLNPCEntity:applyIdleAnimationParameters()
    local gfx = self.graphics
    if gfx == nil or not self.modelLoaded then return end
    local nameToIdx  = gfx.animationParameters
    local paramObjs  = gfx.animation and gfx.animation.parameters
    if type(nameToIdx) ~= "table" or type(paramObjs) ~= "table" then return end

    local function set(name, value)
        local idx = nameToIdx[name]
        if idx == nil then return end
        local p = paramObjs[idx]
        if type(p) == "table" then p.value = value end
    end

    local walking = self._directTrackWalking
    local speed   = walking and (self._workLoop and self._workLoop.speed or 1.2) or 0
    set("isNPC",             not walking)
    set("isGrounded",        true)
    set("isCloseToGround",   true)
    set("isIdling",          not walking)
    set("isWalking",         walking)
    set("isRunning",         false)
    set("absSpeed",          speed)
    set("distanceToGround",  0)
    set("relativeVelocityX", 0)
    set("relativeVelocityY", 0)
    set("relativeVelocityZ", speed)
    set("movementDirX",      0)
    set("movementDirZ",      walking and 1 or 0)
    set("rotationVelocity",  0)
end

function VLNPCEntity:updateGraphics(dt)
    if not self.modelLoaded then return end

    if not self.useDirectAnimation and (self._animSetupRetries or 0) < 8 then
        self._animSetupRetries = (self._animSetupRetries or 0) + 1
        self:setupDirectIdleAnimation()
    end

    -- Direct track mode: engine advances enabled clips; no per-frame gfx update.
    -- Skip for both idle and walk when walk is on direct track too.
    if self.useDirectAnimation and self.animCharSet ~= nil then
        if not self._directTrackWalking or self._walkDirectTrack then
            return
        end
        -- Walking but no walk clip on direct track: fall through to ConditionalAnimation fallback.
    end

    local gfx = self.graphics
    if gfx == nil then return end
    -- Run gfx:update first so any internal physics-driven param writes happen,
    -- then re-apply our params so they win the frame's ConditionalAnimation read.
    local ok, err = pcall(function()
        gfx.soundsEnabled = false
        if type(gfx.update) == "function" then
            gfx:update(dt)
        elseif gfx.animation ~= nil and type(gfx.animation.update) == "function" then
            gfx.animation:update(dt)
        end
    end)
    if not ok then
        self._gfxUpdateErrors = (self._gfxUpdateErrors or 0) + 1
        if self._gfxUpdateErrors <= 3 then
            print(string.format("[ValleyLife] gfx:update error on '%s': %s", self.name, tostring(err)))
        end
    end
    self:applyIdleAnimationParameters()
end

function VLNPCEntity:buildAnimatedCharacter()
    self.useDirectAnimation = false
    self.animCharSet = nil
    self._idleClipIdx = nil
    self._walkClipIdx = nil
    self._directTrackWalking = false
    self._walkDirectTrack = false
    self._animSetupRetries = 0
    self.modelLoaded = false

    local gfx = HumanGraphicsComponent.new()
    gfx:initialize()
    gfx.soundsEnabled = false
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

    -- Idle flags are refreshed every frame in updateGraphics; prime them before async load.
    self:applyIdleAnimationParameters()

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
                self:applyIdleAnimationParameters()
                if not self:setupDirectIdleAnimation() then
                    print(string.format("[ValleyLife] '%s': direct idle setup deferred (retrying).", self.name))
                end
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

function VLNPCEntity:_onWalkStart()
    self._directTrackWalking = true
    if self.animCharSet ~= nil and (self._walkClipIdx or -1) >= 0 then
        -- Swap track 0 from idle to walk clip — same direct-track pattern as idle setup.
        pcall(function()
            clearAnimTrackClip(self.animCharSet, 0)
            assignAnimTrackClip(self.animCharSet, 0, self._walkClipIdx)
            setAnimTrackLoopState(self.animCharSet, 0, true)
            enableAnimTrack(self.animCharSet, 0)
        end)
        self._walkDirectTrack = true
        print(string.format("[ValleyLife] '%s' walk start: direct track (walk clip)", self.name))
    else
        -- Fallback: disable idle track and let ConditionalAnimation drive the walk clip.
        self._walkDirectTrack = false
        if self.animCharSet ~= nil then
            pcall(function()
                if disableAnimTrack ~= nil then
                    disableAnimTrack(self.animCharSet, 0)
                elseif clearAnimTrackClip ~= nil then
                    clearAnimTrackClip(self.animCharSet, 0)
                end
            end)
        end
        print(string.format("[ValleyLife] '%s' walk start: no walk clip cached; ConditionalAnimation fallback", self.name))
    end
end

function VLNPCEntity:_onWalkEnd()
    if not self._directTrackWalking then return end
    if self.animCharSet ~= nil and (self._idleClipIdx or -1) >= 0 then
        pcall(function()
            clearAnimTrackClip(self.animCharSet, 0)
            assignAnimTrackClip(self.animCharSet, 0, self._idleClipIdx)
            setAnimTrackLoopState(self.animCharSet, 0, true)
            enableAnimTrack(self.animCharSet, 0)
        end)
    elseif self.animCharSet ~= nil then
        pcall(function()
            if enableAnimTrack ~= nil then enableAnimTrack(self.animCharSet, 0) end
        end)
    end
    self._directTrackWalking = false
    self._walkDirectTrack = false
end

function VLNPCEntity:_startWalk()
    if self._walk ~= nil then return end
    if self.rootNode and entityExists(self.rootNode) then
        setVisibility(self.rootNode, true)
    end
    self._walk = { state = "walking", targetIdx = 2 }
    self:_onWalkStart()
end

-- Turn rate in radians/sec while pivoting to face the next waypoint.
local WALK_TURN_RATE = math.rad(240)
-- If she needs to turn more than this before walking, she pivots in place first.
local WALK_TURN_THRESHOLD = math.rad(25)
-- Mid-walk, she stops and turns to face the player within this range (ready to talk), then resumes
-- when they leave. A bit larger than INTERACT_DISTANCE so she's already facing you by talk range.
local APPROACH_RANGE = 4.0

local function lerpAngle(current, target, maxStep)
    local diff = target - current
    while diff >  math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end
    if math.abs(diff) <= maxStep then return target end
    return current + (diff > 0 and maxStep or -maxStep)
end

function VLNPCEntity:_getActiveWorkLoop()
    return (WorkLoopHelper.getActiveLoop(self._workLoops, TimeHelper.getHour()))
end

-- Force-start a loop now, bypassing the 2-hour timer. `selector` may be a loop
-- name, an index, or nil (= the loop active at the current hour). Returns the
-- started loop's name/index, or nil if no matching loop. Used by vlWalk.
function VLNPCEntity:forceWalkLoop(selector)
    if not self._workLoops then return nil end
    local loop, idx = WorkLoopHelper.resolve(self._workLoops, selector, TimeHelper.getHour())
    if loop == nil then return nil end
    if self._walk then self:_onWalkEnd() end
    self._walk = nil
    self._walkLastHour = -1
    self._workLoop = loop
    self:_startWalk()
    return loop.name or idx
end

function VLNPCEntity:_updateWalkLoop(dt)
    if self._walk == nil then
        if not self.isTalking and TimeHelper.getOutfitMode() == "work" then
            local activeLoop = self:_getActiveWorkLoop()
            if activeLoop then
                local twoHourTick = math.floor(TimeHelper.getHour() / 2)
                if twoHourTick ~= self._walkLastHour then
                    self._walkLastHour = twoHourTick
                    self._workLoop = activeLoop
                    self:_startWalk()
                end
            end
        end
        return
    end

    local walk = self._walk
    local waypoints = self._workLoop.waypoints

    -- Stop & turn to face the player when he's near (or she's already talking), ready to talk; hold
    -- in place and resume the loop once he leaves. Mirrors Walter's stop-and-face.
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    local px, pz
    if player and player.rootNode then
        local a, _, c = getWorldTranslation(player.rootNode)
        px, pz = a, c
    end
    local near = false
    if px ~= nil then
        local ddx, ddz = px - self.position.x, pz - self.position.z
        near = (ddx * ddx + ddz * ddz) <= (APPROACH_RANGE * APPROACH_RANGE)
    end
    if self.isTalking or near then
        self:_onWalkEnd()  -- revert to idle clip (idempotent)
        if px ~= nil then
            local maxStep = WALK_TURN_RATE * (dt / 1000)
            self.rotation.y = lerpAngle(self.rotation.y, math.atan2(px - self.position.x, pz - self.position.z), maxStep)
        end
        if not self._stoppedForPlayer then
            self._stoppedForPlayer = true
            print(string.format("[ValleyLife] '%s' stopping to face player", self.name))
        end
        return  -- hold; don't advance the loop
    elseif self._stoppedForPlayer then
        self._stoppedForPlayer = false
        if walk.state == "walking" then self:_onWalkStart() end  -- resume the walk clip
    end

    if walk.state == "pausing" then
        if walk.pauseTargetRy then
            local maxStep = WALK_TURN_RATE * (dt / 1000)
            self.rotation.y = lerpAngle(self.rotation.y, walk.pauseTargetRy, maxStep)
        end
        local hour = TimeHelper.getHour()
        local elapsed = hour - walk.pauseStartHour
        if elapsed < 0 then elapsed = elapsed + 24 end
        if elapsed >= walk.pauseMinutesRequired / 60 then
            walk.state = "walking"
            self:_onWalkStart()
        end
        return
    end

    local target = waypoints[walk.targetIdx]
    local dx = target.x - self.position.x
    local dz = target.z - self.position.z
    local dist = math.sqrt(dx * dx + dz * dz)
    local step = (self._workLoop.speed or 1.2) * (dt / 1000)

    if dist <= step then
        self.position.x = target.x
        self.position.z = target.z
        if walk.targetIdx == 1 then
            self._walk = nil
            self.rotation.y = self._homeRy
            self:_onWalkEnd()
            if self._workLoop.despawnOnEnd and self.rootNode and entityExists(self.rootNode) then
                setVisibility(self.rootNode, false)
            end
            return
        end
        local pauseMin = target.pauseMinutes
        local nextIdx = walk.targetIdx + 1
        if nextIdx > #waypoints then nextIdx = 1 end
        walk.targetIdx = nextIdx
        if pauseMin then
            walk.state = "pausing"
            walk.pauseStartHour = TimeHelper.getHour()
            walk.pauseMinutesRequired = pauseMin
            walk.pauseTargetRy = target.pauseRy
            self:_onWalkEnd()
        end
    else
        local nx = dx / dist
        local nz = dz / dist

        -- Rotate toward movement direction. If the angle gap is large, pivot in
        -- place first so she doesn't moonwalk sideways to the next waypoint.
        local targetRy = math.atan2(nx, nz)
        local maxStep = WALK_TURN_RATE * (dt / 1000)
        self.rotation.y = lerpAngle(self.rotation.y, targetRy, maxStep)

        local diff = targetRy - self.rotation.y
        while diff >  math.pi do diff = diff - 2 * math.pi end
        while diff < -math.pi do diff = diff + 2 * math.pi end
        if math.abs(diff) <= WALK_TURN_THRESHOLD then
            self.position.x = self.position.x + nx * step
            self.position.z = self.position.z + nz * step
        end
    end
end

function VLNPCEntity:update(dt)
    if not nodeValid(self.rootNode) then return end
    if self._workLoops then
        self:_updateWalkLoop(dt)
    end
    local y = terrainY(self.position.x, self.position.z, self.position.y or 0)
    self.position.y = y
    setTranslation(self.rootNode, self.position.x, y, self.position.z)
    setRotation(self.rootNode, 0, self.rotation.y, 0)
    self:updateGraphics(dt)
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
    self.useDirectAnimation = false
    self.animCharSet = nil
    self._idleClipIdx = nil
    self._walkClipIdx = nil
    self._directTrackWalking = false
    self._walkDirectTrack = false
    if self.graphics then
        pcall(function() self.graphics:delete() end)
        self.graphics = nil
    end
    self.rootNode = nil
    self.isLoaded = false
end
