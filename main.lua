-- ValleyLife: social and narrative layer for FS25.
-- Entry point — sources all modules in dependency order, hooks mission lifecycle.

local modDir = g_currentModDirectory

-- 1. Utilities (no dependencies)
source(modDir .. "src/utils/VectorHelper.lua")
source(modDir .. "src/utils/TimeHelper.lua")
source(modDir .. "src/utils/BirthdayHelper.lua")
source(modDir .. "src/utils/OutfitCalendar.lua")

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
source(modDir .. "src/content/Kenji.lua")
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
    g_valleyLife:loadFromFile(g_currentMission.missionInfo)
end

local function onMissionUpdate(mission, dt)
    if g_valleyLife then
        local ok, err = pcall(g_valleyLife.update, g_valleyLife, dt)
        if not ok then
            print("[ValleyLife] ERROR in update: " .. tostring(err))
        end
    end
end

local function onMissionUnload(mission)
    if g_valleyLife then
        g_valleyLife:delete()
        g_valleyLife = nil
    end
end

-- Renders the bottom-screen reply selector on top of the HUD each frame.
local function onMissionDraw(mission)
    if g_valleyLife and g_valleyLife.dialog then
        g_valleyLife.dialog:draw()
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

-- Draw hook for the bottom-screen reply selector (renders on top of the HUD).
if FSBaseMission ~= nil and FSBaseMission.draw ~= nil then
    FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, onMissionDraw)
    print("[ValleyLife] Hooked FSBaseMission.draw.")
end

-- Console command: prints the player's current world position, formatted ready
-- to paste into VLConfig.VILLAGER_SPAWNS. Stand where a villager should be and
-- type "vlPos" in the developer console (~).
-- Console command target. FS25 runs each mod in its own environment, so a bare
-- top-level function is NOT a true _G global and addConsoleCommand(..., nil)
-- can't find it. Registering against an explicit target object makes the engine
-- call target:method() directly, which works reliably.
VLConsole = {}

function VLConsole:printPlayerPos()
    -- Collect every plausible player node source; FS25 builds vary on whether the
    -- foot player lives on g_localPlayer, g_currentMission.player, or a graphics
    -- component, so try them all and use the first that yields a valid node.
    local candidates = {}
    local p1 = g_localPlayer
    local p2 = g_currentMission ~= nil and g_currentMission.player or nil
    for _, p in ipairs({ p1, p2 }) do
        if p ~= nil then
            candidates[#candidates + 1] = p.rootNode
            candidates[#candidates + 1] = p.graphicsComponent and p.graphicsComponent.graphicsRootNode or nil
            candidates[#candidates + 1] = p.positionNode
        end
    end

    local node
    for _, n in ipairs(candidates) do
        if n ~= nil and n ~= 0 and entityExists(n) then node = n; break end
    end

    if node == nil then
        local msg = string.format(
            "[ValleyLife] vlPos: no player node (g_localPlayer=%s, mission.player=%s).",
            tostring(p1), tostring(p2))
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

-- vlRel <npcId> <value>: set a villager's relationship directly so heart-event
-- thresholds (20/40/60/80) can be reached for testing. Then walk up and press R.
function VLConsole:setRelationship(npcId, value)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    if npcId == nil then return "[ValleyLife] Usage: vlRel <npcId> <value>  (e.g. vlRel elara 20)" end
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, kenji, marta."
    end
    local v = math.max(VLConfig.REL_MIN, math.min(VLConfig.REL_MAX, tonumber(value) or 0))
    g_valleyLife.relationships.values[npcId] = v
    local msg = string.format("[ValleyLife] %s relationship set to %d.", npcId, v)
    print(msg)
    return msg
end

-- vlEvent <npcId>: force-start the next uncompleted heart event for a villager,
-- bypassing proximity and relationship. Fastest way to test authored dialogue.
function VLConsole:triggerEvent(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    npcId = npcId and string.lower(tostring(npcId)) or "elara"
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, kenji, marta."
    end
    local ok, eventId = g_valleyLife.sequencer:forceTriggerNext(npcId)
    if ok then
        local msg = string.format("[ValleyLife] Started %s for %s.", eventId, npcId)
        print(msg)
        return msg
    end
    local msg = "[ValleyLife] No available event for " .. npcId .. " (all completed?). Try: vlReset " .. npcId
    print(msg)
    return msg
end

-- vlReset <npcId>: clear a villager's completed heart events, reset their
-- relationship to 0, and abort any in-progress scene, so the conversation/events
-- can be replayed from the top during testing.
function VLConsole:resetNpc(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    npcId = npcId or "elara"
    if g_valleyLife:getNPC(npcId) == nil then
        return "[ValleyLife] Unknown villager '" .. tostring(npcId) .. "'. Try: elara, kenji, marta."
    end
    local cleared = g_valleyLife.sequencer:resetNPC(npcId)
    g_valleyLife.relationships.values[npcId] = 0
    local npc = g_valleyLife:getNPC(npcId)
    if npc then npc.isTalking = false end
    local msg = string.format("[ValleyLife] Reset %s: cleared %d event(s), relationship -> 0.",
        npcId, cleared)
    print(msg)
    return msg
end

-- vlNear: report the player position, nearest villager, and distance, so we can
-- verify the Press-R proximity detection.
function VLConsole:printNearest()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local px, py, pz = g_valleyLife:getPlayerPosition()
    local nearest, dist = g_valleyLife:getNearestNPC()
    local msg = string.format(
        "[ValleyLife] player=(%s,%s,%s) nearest=%s dist=%.2f (interact<=%.1f)",
        tostring(px and string.format("%.1f", px)),
        tostring(py and string.format("%.1f", py)),
        tostring(pz and string.format("%.1f", pz)),
        nearest and nearest.name or "none", dist or -1, VLConfig.INTERACT_DISTANCE)
    print(msg)
    return msg
end

-- vlDlg: probe which native dialog/choice widgets this build exposes, so we can
-- reuse the same one Walter's "anything I can help with?" menu uses instead of our
-- hand-drawn reply box. Reports each candidate global, whether it's a table/class,
-- and which show-style methods it carries.
function VLConsole:probeDialogs()
    local candidates = {
        -- multi-option / list pickers (what we actually want for choices)
        "MultiChoiceDialog", "SelectionDialog", "OptionDialog", "ListSelectionDialog",
        "AnswerDialog", "DialogElement", "MessageDialog", "RadioButtonDialog",
        -- known-good fallbacks already in use
        "InfoDialog", "YesNoDialog", "TextInputDialog",
        -- the helper / guided-tour systems that may own Walter's flow
        "GuidedTourMission", "HelpMenuMission", "TutorialMission",
    }
    local methods = { "show", "new", "createFromExistingGui", "setTexts", "setOptions",
                      "setMenuOptions", "setCallback", "setOptionTexts" }
    print("[ValleyLife] ---- dialog widget probe ----")
    for _, name in ipairs(candidates) do
        local g = _G[name]
        if g == nil then
            print(string.format("  %-22s : (absent)", name))
        else
            local found = {}
            for _, m in ipairs(methods) do
                if type(g) == "table" and type(g[m]) == "function" then
                    table.insert(found, m)
                end
            end
            print(string.format("  %-22s : %s  methods=[%s]",
                name, type(g), table.concat(found, ",")))
        end
    end
    -- Also report what g_gui can open by name.
    if g_gui ~= nil then
        local guiMethods = {}
        for _, m in ipairs({ "showDialog", "showInfoDialog", "showYesNoDialog",
                             "showSelectionDialog", "showOptionDialog", "showMessageDialog" }) do
            if type(g_gui[m]) == "function" then table.insert(guiMethods, m) end
        end
        print("  g_gui methods=[" .. table.concat(guiMethods, ",") .. "]")
    end
    print("[ValleyLife] ---- end probe (see above) ----")
    return "[ValleyLife] Dialog probe written to log/console."
end

-- vlStyle: enumerate the base-game character style configs (hair, beard, face,
-- skin, clothing, ...) with how many items/colors each exposes and the default
-- selected index. Use this to find which config controls skin/age and which item
-- indices read "older", then plug those into VILLAGERS[*].appearance.
function VLConsole:dumpStyles()
    if PlayerStyle == nil or PlayerStyle.new == nil then
        return "[ValleyLife] PlayerStyle API unavailable."
    end
    local function countItems(cfg)
        for _, g in ipairs({ "getNumOfItems", "getNumItems", "getItemCount" }) do
            if type(cfg[g]) == "function" then
                local ok, v = pcall(cfg[g], cfg)
                if ok and type(v) == "number" then return v end
            end
        end
        if type(cfg.items) == "table" then return #cfg.items end
        return -1
    end
    local function countColors(cfg)
        for _, g in ipairs({ "getNumColors", "getNumOfColors", "getColorCount" }) do
            if type(cfg[g]) == "function" then
                local ok, v = pcall(cfg[g], cfg)
                if ok and type(v) == "number" then return v end
            end
        end
        if type(cfg.getColors) == "function" then
            local ok, v = pcall(cfg.getColors, cfg)
            if ok and type(v) == "table" then return #v end
        end
        if type(cfg.colors) == "table" then return #cfg.colors end
        return -1
    end
    local sets = {
        { "MALE",   "dataS/character/playerM/playerM.xml" },
        { "FEMALE", "dataS/character/playerF/playerF.xml" },
    }
    print("[ValleyLife] ---- character style configs ----")
    for _, set in ipairs(sets) do
        local label, xml = set[1], set[2]
        local style = PlayerStyle.new()
        pcall(function()
            if style.loadConfigurationXML then style:loadConfigurationXML(xml) end
        end)
        print(string.format("  [%s] %s", label, xml))
        if type(style.configs) == "table" then
            local names = {}
            for name, _ in pairs(style.configs) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do
                local cfg = style.configs[name]
                local sel = type(cfg) == "table" and cfg.selectedItemIndex or "?"
                print(string.format("    %-18s items=%-3s colors=%-3s selected=%s",
                    name, tostring(countItems(cfg)), tostring(countColors(cfg)), tostring(sel)))
            end
        else
            print("    (no configs table)")
        end
    end
    print("[ValleyLife] ---- end style dump ----")
    return "[ValleyLife] Style dump written to log/console."
end

local VL_NPC_IDS = "elara, kenji, marta"

local function styleConfigItemCount(cfg)
    if type(cfg) ~= "table" then return 0 end
    for _, g in ipairs({ "getNumOfItems", "getNumItems", "getItemCount" }) do
        if type(cfg[g]) == "function" then
            local ok, v = pcall(cfg[g], cfg)
            if ok and type(v) == "number" then return v end
        end
    end
    if type(cfg.items) == "table" then return #cfg.items end
    return 0
end

local function getNpcStyleConfig(npc, configName)
    if type(npc.buildPreviewStyle) ~= "function" then return nil end
    local style = npc:buildPreviewStyle()
    return style and style.configs and style.configs[configName]
end

function VLConsole:resolveNpc(npcId, usage)
    if g_valleyLife == nil then return nil, "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return usage or string.format("[ValleyLife] Unknown villager. Try: %s.", VL_NPC_IDS)
    end
    return npc
end

function VLConsole:listStyleConfig(npcId, configName, listCmd, setCmd)
    local usage = string.format("[ValleyLife] Usage: %s <npcId>  (npcId: %s)", listCmd, VL_NPC_IDS)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local cfg = style and style.configs and style.configs[configName]
    if type(cfg) ~= "table" or type(cfg.items) ~= "table" then
        return string.format("[ValleyLife] No %s config.", configName)
    end
    local itemCount = #cfg.items
    if itemCount == 0 then
        print(string.format("[ValleyLife] ---- %s (0 items) ----", configName))
        if configName == "facegear" then
            print("[ValleyLife] Base FS25 has an empty facegear slot (no socks/masks in playerF/playerM.xml).")
            print("[ValleyLife] Use vlFootwears / vlShoe for shoes; there is no separate sock layer.")
        else
            print("[ValleyLife] This slot has no catalog items for this character rig.")
        end
        return string.format("[ValleyLife] %s: %s has 0 items.", npcId, configName)
    end
    print(string.format("[ValleyLife] ---- %s (%d items) ----", configName, itemCount))
    for i = 1, math.min(itemCount, 40) do
        local item = cfg.items[i]
        if type(item) == "table" then
            print(string.format("  %2d : %s", i, tostring(item.name or "?")))
        end
    end
    if itemCount > 40 then
        print(string.format("  ... (%d more)", itemCount - 40))
    end
    setCmd = setCmd or listCmd:gsub("s$", "")
    print(string.format("[ValleyLife] ---- use %s %s <index>; %sColor for swatch ----",
        setCmd, tostring(npcId), setCmd))
    return string.format("[ValleyLife] Listed %s for %s.", configName, npcId)
end

local function itemNameLooksLikeSock(item)
    if type(item) ~= "table" then return false end
    local n = string.lower(tostring(item.name or ""))
    return string.find(n, "sock", 1, true) ~= nil
        or string.find(n, "stocking", 1, true) ~= nil
        or string.find(n, "ankle", 1, true) ~= nil
end

function VLConsole:listFootwear(npcId, mode)
    local listCmd = mode == "shoe" and "vlShoes" or (mode == "sock" and "vlSocks" or "vlFootwears")
    local usage = string.format("[ValleyLife] Usage: %s <npcId>  (npcId: %s)", listCmd, VL_NPC_IDS)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local cfg = style and style.configs and style.configs.footwear
    if type(cfg) ~= "table" or type(cfg.items) ~= "table" then
        return "[ValleyLife] No footwear config."
    end
    local label = mode == "shoe" and "footwear (shoes)" or (mode == "sock" and "footwear (socks)" or "footwear (all)")
    print(string.format("[ValleyLife] ---- %s (%d items) ----", label, #cfg.items))
    local shown = 0
    for i = 1, #cfg.items do
        local item = cfg.items[i]
        if type(item) == "table" then
            local isSock = itemNameLooksLikeSock(item)
            if mode == "all" or (mode == "sock" and isSock) or (mode == "shoe" and not isSock) then
                shown = shown + 1
                if shown <= 40 then
                    print(string.format("  %2d : %s%s", i, tostring(item.name or "?"),
                        isSock and " (sock)" or ""))
                end
            end
        end
    end
    if shown > 40 then
        print(string.format("  ... (%d more)", shown - 40))
    end
    if mode == "sock" then
        local fg = style.configs and style.configs.facegear
        if type(fg) == "table" and type(fg.items) == "table" and #fg.items > 0 then
            print(string.format("[ValleyLife] ---- facegear (%d items, may include socks) ----", #fg.items))
            for i = 1, math.min(#fg.items, 20) do
                local item = fg.items[i]
                if type(item) == "table" then
                    print(string.format("  %2d : %s", i, tostring(item.name or "?")))
                end
            end
            print("[ValleyLife] ---- try vlFacegear for facegear slot; vlSock for footwear sock names ----")
        end
        if shown == 0 then
            print("[ValleyLife] No sock-named footwear found — run vlFootwears for the full list.")
        end
    end
    if mode == "shoe" then
        print(string.format("[ValleyLife] ---- use vlShoe %s <index>; vlShoeColor for swatch ----", npcId))
    elseif mode == "sock" then
        print(string.format("[ValleyLife] ---- use vlSock %s <index>; vlSockColor for swatch ----", npcId))
    else
        print(string.format("[ValleyLife] ---- use vlShoe or vlSock %s <index> ----", npcId))
    end
    return string.format("[ValleyLife] Listed footwear for %s.", npcId)
end

function VLConsole:sockUsesFacegear(npc)
    if type(npc.buildPreviewStyle) ~= "function" then return false end
    local style = npc:buildPreviewStyle()
    local fg = style and style.configs and style.configs.facegear
    return type(fg) == "table" and type(fg.items) == "table" and #fg.items > 0
end

function VLConsole:patchAppearanceLayer(npc, configName, patch)
    if type(npc.setAppearanceLayer) == "function" then
        npc:setAppearanceLayer(configName, patch)
    else
        npc.appearance = npc.appearance or {}
        npc.appearance[configName] = npc.appearance[configName] or {}
        for k, v in pairs(patch) do npc.appearance[configName][k] = v end
    end
end

function VLConsole:setStyleConfigItem(npcId, configName, item, setCmd)
    local usage = string.format("[ValleyLife] Usage: %s <npcId> <index>  (0 = none)", setCmd)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    local idx = tonumber(item)
    if idx == nil then
        return string.format("[ValleyLife] Usage: %s %s <index>", setCmd, tostring(npcId))
    end
    if idx > 0 then
        local cfg = getNpcStyleConfig(npc, configName)
        local itemCount = styleConfigItemCount(cfg)
        if itemCount == 0 then
            local hint = configName == "facegear"
                and " Base FS25 facegear is empty — use vlShoe/vlFootwears instead."
                or ""
            local msg = string.format(
                "[ValleyLife] %s: %s has 0 items; index %d ignored.%s",
                tostring(npcId), configName, idx, hint)
            print(msg)
            return msg
        end
    end
    self:patchAppearanceLayer(npc, configName, { item = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s %s -> item %d (reloading).", npcId, configName, idx)
    print(msg)
    return msg
end

function VLConsole:setStyleConfigColor(npcId, configName, color, setCmd)
    local usage = string.format("[ValleyLife] Usage: %s <npcId> <colorIndex>", setCmd)
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    local idx = tonumber(color)
    if idx == nil then
        return string.format("[ValleyLife] Usage: %s %s <colorIndex>", setCmd, tostring(npcId))
    end
    self:patchAppearanceLayer(npc, configName, { color = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s %s color -> %d (reloading).", npcId, configName, idx)
    print(msg)
    return msg
end

-- vlFace <npcId> <index>: live-swap a spawned villager's face/skin preset so you
-- can flip through the variants (male 1..10, female 1..6) and pick the oldest-
-- looking one. Once chosen, bake it into VILLAGERS[*].appearance.face.item.
function VLConsole:setFace(npcId, index)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlFace <npcId> <index>  (npcId: elara, kenji, marta)"
    end
    local idx = tonumber(index)
    if idx == nil then
        return "[ValleyLife] Usage: vlFace " .. tostring(npcId) .. " <index>  (e.g. vlFace kenji 6)"
    end
    self:patchAppearanceLayer(npc, "face", { item = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s face -> item %d (reloading model).", npcId, idx)
    print(msg)
    return msg
end

-- vlHairs <npcId>: list available hairStyle items (index + internal name). Some
-- head meshes include baked scalp/hair; a full hairStyle wig on top = "hair on hair".
function VLConsole:listHairs(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHairs <npcId>  (e.g. vlHairs kenji)"
    end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local hairCfg = style and style.configs and style.configs.hairStyle
    if type(hairCfg) ~= "table" or type(hairCfg.items) ~= "table" then
        return "[ValleyLife] No hairStyle config."
    end
    print(string.format("[ValleyLife] ---- hairStyles (%d items) ----", #hairCfg.items))
    for i = 1, math.min(#hairCfg.items, 30) do
        local item = hairCfg.items[i]
        if type(item) == "table" then
            print(string.format("  %2d : %s%s", i, tostring(item.name or "?"),
                item.forHat and " (forHat)" or ""))
        end
    end
    if #hairCfg.items > 30 then
        print(string.format("  ... (%d more)", #hairCfg.items - 30))
    end
    print(string.format("[ValleyLife] ---- use vlHair %s <index>; try receding/bald/buzz for baked-in head hair ----", npcId))
    return string.format("[ValleyLife] Listed hairStyles for %s.", npcId)
end

-- vlHairsForHat <npcId>: hairStyle items that work under hats (forHat flag).
function VLConsole:listHairsForHat(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHairsForHat <npcId>  (npcId: " .. VL_NPC_IDS .. ")"
    end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    local hairCfg = style and style.configs and style.configs.hairStyle
    if type(hairCfg) ~= "table" or type(hairCfg.items) ~= "table" then
        return "[ValleyLife] No hairStyle config."
    end
    local count = 0
    print("[ValleyLife] ---- hairStyles forHat (work under headgear) ----")
    for i = 1, #hairCfg.items do
        local item = hairCfg.items[i]
        if type(item) == "table" and item.forHat then
            count = count + 1
            print(string.format("  %2d : %s", i, tostring(item.name or "?")))
        end
    end
    print(string.format("[ValleyLife] ---- %d forHat styles (vlHat auto-picks one if needed) ----", count))
    return string.format("[ValleyLife] Listed forHat hairStyles for %s.", npcId)
end

-- vlHair <npcId> <item>: live-swap hairStyle mesh (0 = none/bald slot if available).
function VLConsole:setHair(npcId, item)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHair <npcId> <item>"
    end
    local idx = tonumber(item)
    if idx == nil then
        return "[ValleyLife] Usage: vlHair " .. tostring(npcId) .. " <item>"
    end
    self:patchAppearanceLayer(npc, "hairStyle", { item = idx })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s hairStyle -> item %d (reloading).", npcId, idx)
    print(msg)
    return msg
end

-- vlBeards <npcId>: list beard items compatible with the villager's current face.
-- Incompatible beards often show as a permanent white/ghost layer on the jaw.
function VLConsole:listBeards(npcId)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlBeards <npcId>  (e.g. vlBeards kenji)"
    end
    if type(npc.buildPreviewStyle) ~= "function" then
        return "[ValleyLife] buildPreviewStyle unavailable."
    end
    local style = npc:buildPreviewStyle()
    if style == nil or type(style.configs) ~= "table" then
        return "[ValleyLife] Could not build preview style."
    end
    local faceCfg = style.configs.face
    local beardCfg = style.configs.beard
    local faceName = nil
    if faceCfg and faceCfg.getSelectedItem then
        local ok, faceItem = pcall(faceCfg.getSelectedItem, faceCfg)
        if ok and faceItem then faceName = faceItem.name end
    end
    print(string.format("[ValleyLife] ---- beards for face '%s' (item %s) ----",
        tostring(faceName), tostring(faceCfg and faceCfg.selectedItemIndex)))
    if type(beardCfg) ~= "table" or type(beardCfg.items) ~= "table" then
        print("  (no beard config)")
        return "[ValleyLife] No beard config."
    end
    local count = 0
    for i = 1, math.min(#beardCfg.items, 40) do
        local item = beardCfg.items[i]
        if type(item) == "table" then
            local universal = item.faceName == nil
            local match = universal or item.faceName == faceName
            if match then
                count = count + 1
                print(string.format("  %3d : %s%s", i, tostring(item.name or "?"),
                    universal and " (any face)" or ""))
            end
        end
    end
    if #beardCfg.items > 40 then
        print(string.format("  ... (%d more beards not listed)", #beardCfg.items - 40))
    end
    print(string.format("[ValleyLife] ---- %d compatible beards (use vlBeard %s <index>) ----",
        count, npcId))
    return string.format("[ValleyLife] Listed compatible beards for %s.", npcId)
end

-- vlBeard <npcId> <item>: live-swap a villager's beard mesh (male: 1..91, or 0 for
-- none) and respawn. Use it to find a beard that sits cleanly on the chosen face,
-- or set 0 to confirm whether a "ghost chin" artifact comes from the beard or face.
function VLConsole:setBeard(npcId, item)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlBeard <npcId> <item>  (item 0 = none)"
    end
    local idx = tonumber(item)
    if idx == nil then
        return "[ValleyLife] Usage: vlBeard " .. tostring(npcId) .. " <item>  (0 = none)"
    end
    local color = npc.appearance and npc.appearance.beard and npc.appearance.beard.color
    self:patchAppearanceLayer(npc, "beard", { item = idx, color = color })
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s beard -> item %d (reloading).", npcId, idx)
    print(msg)
    return msg
end

-- vlBeardColor <npcId> <hairColor> <beardColor>: EXPERIMENTAL — apply hair and
-- beard colors separately (hair first, beard second, no engine unification).
-- Tests whether FS25 can render different shades, e.g. vlBeardColor kenji 23 24.
function VLConsole:setBeardColor(npcId, hairColor, beardColor)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlBeardColor <npcId> <hairColor> <beardColor>"
    end
    local hc = tonumber(hairColor)
    local bc = tonumber(beardColor)
    if hc == nil or bc == nil then
        return "[ValleyLife] Usage: vlBeardColor " .. tostring(npcId) .. " <hairColor> <beardColor>  (e.g. vlBeardColor kenji 23 24)"
    end
    self:patchAppearanceLayer(npc, "hairStyle", { color = hc })
    local beardItem = npc.appearance and npc.appearance.beard and npc.appearance.beard.item
    self:patchAppearanceLayer(npc, "beard", { item = beardItem or 2, color = bc })
    npc:reapplyAppearance({ splitHairBeardColors = true })
    local msg = string.format("[ValleyLife][exp] %s hair=%d beard=%d (split, no unify).", npcId, hc, bc)
    print(msg)
    return msg
end

-- vlHairColor <npcId> <index>: live-swap a villager's hair AND beard color together
-- (so a beard stays matched to the hair) and reload the model. Use it to find the
-- grey index, then bake it into VILLAGERS[*].appearance.hairStyle/beard.color.
function VLConsole:setHairColor(npcId, index)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlHairColor <npcId> <index>  (npcId: elara, kenji, marta)"
    end
    local idx = tonumber(index)
    if idx == nil then
        return "[ValleyLife] Usage: vlHairColor " .. tostring(npcId) .. " <index>  (e.g. vlHairColor kenji 20)"
    end
    self:patchAppearanceLayer(npc, "hairStyle", { color = idx })
    if npc.appearance ~= nil and npc.appearance.beard ~= nil then
        self:patchAppearanceLayer(npc, "beard", { color = idx })
    end
    npc:reapplyAppearance()
    local msg = string.format("[ValleyLife] %s hair+beard color -> %d (reloading).", npcId, idx)
    print(msg)
    return msg
end

-- vlHairColors: print the hair color palette (index -> RGB) so we can pick a grey
-- by value instead of cycling through all of them blindly.
function VLConsole:dumpHairColors()
    if PlayerStyle == nil or PlayerStyle.new == nil then
        return "[ValleyLife] PlayerStyle API unavailable."
    end
    local xml = "dataS/character/playerM/playerM.xml"
    local style = PlayerStyle.new()
    pcall(function() if style.loadConfigurationXML then style:loadConfigurationXML(xml) end end)
    pcall(function()
        if PlayerSystem ~= nil and PlayerSystem.PLAYER_STYLES_BY_FILENAME ~= nil then
            local key = Utils.getFilename and Utils.getFilename(xml) or xml
            local entry = PlayerSystem.PLAYER_STYLES_BY_FILENAME[key]
            if entry and entry.style then style.hairColors = entry.style.hairColors end
        end
    end)
    local colors = style.hairColors
    if type(colors) ~= "table" then
        return "[ValleyLife] No hairColors palette found (got " .. type(colors) .. ")."
    end
    -- Each palette entry is { primary = <color>, secondary = <color> }. Format a
    -- color table as "r,g,b"; if the components aren't where we expect, dump the
    -- raw key=value pairs so we can see the real shape.
    local function fmtColor(col)
        if type(col) ~= "table" then return tostring(col) end
        local r = col[1] or col.r or col.x
        local g = col[2] or col.g or col.y
        local b = col[3] or col.b or col.z
        if type(r) == "number" then
            return string.format("%.2f,%.2f,%.2f", r, g or 0, b or 0)
        end
        local parts = {}
        for k, v in pairs(col) do
            parts[#parts + 1] = string.format("%s=%s", tostring(k),
                type(v) == "number" and string.format("%.2f", v) or type(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    print(string.format("[ValleyLife] ---- hair color palette (%d entries) ----", #colors))
    for i, c in ipairs(colors) do
        local p = type(c) == "table" and c.primary or nil
        local s = type(c) == "table" and c.secondary or nil
        print(string.format("  %2d : primary=[%s] secondary=[%s]", i, fmtColor(p), fmtColor(s)))
    end
    print("[ValleyLife] ---- end hair color palette ----")
    return "[ValleyLife] Hair color palette written to log/console."
end

-- Clothing / accessories (live preview; bake into VILLAGERS[*].appearance.*)

function VLConsole:listTops(npcId)
    return self:listStyleConfig(npcId, "top", "vlTops")
end
function VLConsole:setTop(npcId, item)
    return self:setStyleConfigItem(npcId, "top", item, "vlTop")
end
function VLConsole:setTopColor(npcId, color)
    return self:setStyleConfigColor(npcId, "top", color, "vlTopColor")
end

function VLConsole:listBottoms(npcId)
    return self:listStyleConfig(npcId, "bottom", "vlBottoms")
end
function VLConsole:setBottom(npcId, item)
    return self:setStyleConfigItem(npcId, "bottom", item, "vlBottom")
end
function VLConsole:setBottomColor(npcId, color)
    return self:setStyleConfigColor(npcId, "bottom", color, "vlBottomColor")
end

function VLConsole:listOnepieces(npcId)
    return self:listStyleConfig(npcId, "onepiece", "vlOnepieces")
end
function VLConsole:setOnepiece(npcId, item)
    return self:setStyleConfigItem(npcId, "onepiece", item, "vlOnepiece")
end
function VLConsole:setOnepieceColor(npcId, color)
    return self:setStyleConfigColor(npcId, "onepiece", color, "vlOnepieceColor")
end

function VLConsole:listGloves(npcId)
    return self:listStyleConfig(npcId, "gloves", "vlGloves")
end
function VLConsole:setGloves(npcId, item)
    return self:setStyleConfigItem(npcId, "gloves", item, "vlGloves")
end
function VLConsole:setGlovesColor(npcId, color)
    return self:setStyleConfigColor(npcId, "gloves", color, "vlGlovesColor")
end

function VLConsole:listGlasses(npcId)
    return self:listStyleConfig(npcId, "glasses", "vlGlasses", "vlGlass")
end
function VLConsole:setGlasses(npcId, item)
    return self:setStyleConfigItem(npcId, "glasses", item, "vlGlass")
end
function VLConsole:setGlassesColor(npcId, color)
    return self:setStyleConfigColor(npcId, "glasses", color, "vlGlassesColor")
end

function VLConsole:listHats(npcId)
    return self:listStyleConfig(npcId, "headgear", "vlHats")
end
function VLConsole:setHat(npcId, item)
    return self:setStyleConfigItem(npcId, "headgear", item, "vlHat")
end
function VLConsole:setHatColor(npcId, color)
    return self:setStyleConfigColor(npcId, "headgear", color, "vlHatColor")
end

function VLConsole:listFootwears(npcId)
    return self:listFootwear(npcId, "all")
end
function VLConsole:listShoes(npcId)
    return self:listFootwear(npcId, "shoe")
end
function VLConsole:listSocks(npcId)
    return self:listFootwear(npcId, "sock")
end
function VLConsole:setShoe(npcId, item)
    return self:setStyleConfigItem(npcId, "footwear", item, "vlShoe")
end
function VLConsole:setShoeColor(npcId, color)
    return self:setStyleConfigColor(npcId, "footwear", color, "vlShoeColor")
end
function VLConsole:setSock(npcId, item)
    local usage = "[ValleyLife] Usage: vlSock <npcId> <index>  (0 = none)"
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if self:sockUsesFacegear(npc) then
        return self:setStyleConfigItem(npcId, "facegear", item, "vlSock")
    end
    return self:setStyleConfigItem(npcId, "footwear", item, "vlSock")
end
function VLConsole:setSockColor(npcId, color)
    local usage = "[ValleyLife] Usage: vlSockColor <npcId> <colorIndex>"
    local npc, err = self:resolveNpc(npcId, usage)
    if npc == nil then return err end
    if self:sockUsesFacegear(npc) then
        return self:setStyleConfigColor(npcId, "facegear", color, "vlSockColor")
    end
    return self:setStyleConfigColor(npcId, "footwear", color, "vlSockColor")
end

function VLConsole:listFacegears(npcId)
    return self:listStyleConfig(npcId, "facegear", "vlFacegears")
end
function VLConsole:setFacegear(npcId, item)
    return self:setStyleConfigItem(npcId, "facegear", item, "vlFacegear")
end
function VLConsole:setFacegearColor(npcId, color)
    return self:setStyleConfigColor(npcId, "facegear", color, "vlFacegearColor")
end

function VLConsole:printSeason()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local month = g_currentMission and g_currentMission.environment
        and g_currentMission.environment.currentMonth
    local season = TimeHelper.getSeason()
    local hour = TimeHelper.getHour()
    local outfit = TimeHelper.getOutfitMode()
    local reason = TimeHelper.getOutfitModeReason()
    local msg = string.format(
        "[ValleyLife] Month %s -> season '%s' (hour %.1f). Outfit: %s (%s). Work commands edit %s look.",
        tostring(month), season, hour, outfit, reason,
        outfit == "work" and season or (season .. " leisure"))
    print(msg)
    return msg
end

function VLConsole:printBirthdays()
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local lines = { "[ValleyLife] Villager birthdays:" }
    for id, npc in pairs(g_valleyLife.npcs) do
        local b = npc.birthday
        local today = BirthdayHelper.isToday(b) and " (today!)" or ""
        lines[#lines + 1] = string.format(
            "  %s: %s%s", id, BirthdayHelper.format(b), today)
    end
    local msg = table.concat(lines, "\n")
    print(msg)
    return msg
end

function VLConsole:setOutfitMode(npcId, mode)
    if g_valleyLife == nil then return "[ValleyLife] No active game." end
    local npc = npcId and g_valleyLife:getNPC(npcId)
    if npc == nil then
        return "[ValleyLife] Usage: vlOutfit <npcId> <work|leisure|auto>  (auto = resume calendar)"
    end
    local m = type(mode) == "string" and string.lower(mode) or nil
    if m == "auto" then
        if type(npc.syncOutfitToCalendar) ~= "function" then
            return "[ValleyLife] Calendar outfit sync unavailable on this NPC."
        end
        npc:syncOutfitToCalendar()
        local season = TimeHelper.getSeason()
        local outfit = TimeHelper.getOutfitMode()
        local msg = string.format(
            "[ValleyLife] %s outfit -> calendar (%s, %s %s look).",
            npcId, outfit, season, outfit == "work" and "work" or "leisure")
        print(msg)
        return msg
    end
    if m ~= "work" and m ~= "leisure" then
        return "[ValleyLife] Usage: vlOutfit " .. tostring(npcId) .. " <work|leisure|auto>"
    end
    if type(npc.setOutfitMode) ~= "function" then
        return "[ValleyLife] Outfit modes unavailable on this NPC."
    end
    npc:setOutfitMode(m, { force = true })
    if type(npc.setOutfitCalendarLocked) == "function" then
        npc:setOutfitCalendarLocked(true)
    end
    local season = TimeHelper.getSeason()
    local seasonLabel = m == "work" and season or (season .. " leisure")
    local msg = string.format(
        "[ValleyLife] %s outfit -> %s (preview; calendar paused). Clothing commands edit %s look.",
        npcId, m, seasonLabel)
    print(msg)
    return msg
end

if addConsoleCommand ~= nil then
    addConsoleCommand("vlSeason", "Print in-game season (for seasonal outfit tuning)", "printSeason", VLConsole)
    addConsoleCommand("vlBirthdays", "List villager birthdays", "printBirthdays", VLConsole)
    addConsoleCommand("vlOutfit", "Preview work/leisure or resume calendar: vlOutfit <npcId> <work|leisure|auto>", "setOutfitMode", VLConsole)
    addConsoleCommand("vlPos", "Print player world position (ValleyLife spawn coords)", "printPlayerPos", VLConsole)
    addConsoleCommand("vlRel", "Set villager relationship: vlRel <npcId> <value>", "setRelationship", VLConsole)
    addConsoleCommand("vlEvent", "Force-trigger next heart event: vlEvent <npcId>", "triggerEvent", VLConsole)
    addConsoleCommand("vlNear", "Report nearest villager + distance (proximity debug)", "printNearest", VLConsole)
    addConsoleCommand("vlReset", "Reset a villager's events + relationship: vlReset <npcId>", "resetNpc", VLConsole)
    addConsoleCommand("vlDlg", "Probe available native dialog/choice widgets", "probeDialogs", VLConsole)
    addConsoleCommand("vlStyle", "Dump character style configs (find skin/age options)", "dumpStyles", VLConsole)
    addConsoleCommand("vlFace", "Live-swap a villager's face: vlFace <npcId> <index>", "setFace", VLConsole)
    addConsoleCommand("vlHair", "Live-swap hairStyle mesh: vlHair <npcId> <item> (0=none)", "setHair", VLConsole)
    addConsoleCommand("vlHairs", "List hairStyle items: vlHairs <npcId>", "listHairs", VLConsole)
    addConsoleCommand("vlHairsForHat", "List forHat hairStyles (under hats): vlHairsForHat <npcId>", "listHairsForHat", VLConsole)
    addConsoleCommand("vlBeard", "Live-swap a villager's beard: vlBeard <npcId> <item> (0=none)", "setBeard", VLConsole)
    addConsoleCommand("vlBeards", "List beards compatible with villager's face", "listBeards", VLConsole)
    addConsoleCommand("vlHairColor", "Live-swap hair+beard color: vlHairColor <npcId> <index>", "setHairColor", VLConsole)
    addConsoleCommand("vlBeardColor", "EXPERIMENTAL split hair/beard color: vlBeardColor <npcId> <hair> <beard>", "setBeardColor", VLConsole)
    addConsoleCommand("vlHairColors", "Print the hair color palette (index -> RGB)", "dumpHairColors", VLConsole)
    addConsoleCommand("vlTops", "List shirt/top items: vlTops <npcId>", "listTops", VLConsole)
    addConsoleCommand("vlTop", "Live-swap shirt/top: vlTop <npcId> <index> (0=none)", "setTop", VLConsole)
    addConsoleCommand("vlTopColor", "Live-swap shirt/top color: vlTopColor <npcId> <index>", "setTopColor", VLConsole)
    addConsoleCommand("vlBottoms", "List pants/bottom items: vlBottoms <npcId>", "listBottoms", VLConsole)
    addConsoleCommand("vlBottom", "Live-swap pants/bottom: vlBottom <npcId> <index> (0=none)", "setBottom", VLConsole)
    addConsoleCommand("vlBottomColor", "Live-swap pants/bottom color: vlBottomColor <npcId> <index>", "setBottomColor", VLConsole)
    addConsoleCommand("vlOnepieces", "List onepiece/jumper items: vlOnepieces <npcId>", "listOnepieces", VLConsole)
    addConsoleCommand("vlOnepiece", "Live-swap onepiece: vlOnepiece <npcId> <index> (0=none)", "setOnepiece", VLConsole)
    addConsoleCommand("vlOnepieceColor", "Live-swap onepiece color: vlOnepieceColor <npcId> <index>", "setOnepieceColor", VLConsole)
    addConsoleCommand("vlGloves", "List glove items: vlGloves <npcId>", "listGloves", VLConsole)
    addConsoleCommand("vlGlove", "Live-swap gloves: vlGlove <npcId> <index> (0=none)", "setGloves", VLConsole)
    addConsoleCommand("vlGlovesColor", "Live-swap gloves color: vlGlovesColor <npcId> <index>", "setGlovesColor", VLConsole)
    addConsoleCommand("vlGlasses", "List glasses/sunglasses items: vlGlasses <npcId>", "listGlasses", VLConsole)
    addConsoleCommand("vlGlass", "Live-swap glasses/sunglasses: vlGlass <npcId> <index> (0=none)", "setGlasses", VLConsole)
    addConsoleCommand("vlGlassesColor", "Live-swap glasses color: vlGlassesColor <npcId> <index>", "setGlassesColor", VLConsole)
    addConsoleCommand("vlHats", "List headgear/hat items: vlHats <npcId>", "listHats", VLConsole)
    addConsoleCommand("vlHat", "Live-swap hat/headgear: vlHat <npcId> <index> (0=none)", "setHat", VLConsole)
    addConsoleCommand("vlHatColor", "Live-swap hat color: vlHatColor <npcId> <index>", "setHatColor", VLConsole)
    addConsoleCommand("vlFootwears", "List all footwear: vlFootwears <npcId>", "listFootwears", VLConsole)
    addConsoleCommand("vlShoes", "List shoe-like footwear: vlShoes <npcId>", "listShoes", VLConsole)
    addConsoleCommand("vlSocks", "List sock-like footwear + facegear: vlSocks <npcId>", "listSocks", VLConsole)
    addConsoleCommand("vlShoe", "Live-swap shoes/footwear: vlShoe <npcId> <index> (0=none)", "setShoe", VLConsole)
    addConsoleCommand("vlShoeColor", "Live-swap shoe color: vlShoeColor <npcId> <index>", "setShoeColor", VLConsole)
    addConsoleCommand("vlSock", "Live-swap socks (facegear or footwear): vlSock <npcId> <index>", "setSock", VLConsole)
    addConsoleCommand("vlSockColor", "Live-swap sock color: vlSockColor <npcId> <index>", "setSockColor", VLConsole)
    addConsoleCommand("vlFacegears", "List facegear (empty in base FS25): vlFacegears <npcId>", "listFacegears", VLConsole)
    addConsoleCommand("vlFacegear", "Facegear slot (empty in base FS25): vlFacegear <npcId> <index>", "setFacegear", VLConsole)
    addConsoleCommand("vlFacegearColor", "Facegear color (empty in base FS25): vlFacegearColor <npcId> <index>", "setFacegearColor", VLConsole)
    print("[ValleyLife] Console commands registered (vlPos ... vlHatColor, vlFootwears, vlShoe, vlSock, vlFacegear, ...).")
end

print("[ValleyLife] Valley Life 0.1.0.42 loaded; lifecycle hooks installed.")
