-- Drives GRANDPA along a waypoint loop with direct graphicsNode translation + walk animation.
-- animCharSet is on graphicsRootNode (confirmed = 97 after isActive=true).
-- Uses the same clearAnimTrackClip / assignAnimTrackClip / enableAnimTrack pattern as NPCEntity.

WalterWalker = {}
WalterWalker.__index = WalterWalker

local WALK_TURN_RATE      = math.rad(240)
local WALK_TURN_THRESHOLD = math.rad(25)

local function lerpAngle(current, target, maxStep)
    local diff = target - current
    while diff >  math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end
    if math.abs(diff) <= maxStep then return target end
    return current + (diff > 0 and maxStep or -maxStep)
end

local WALK_CLIP_CANDIDATES = {
    "NPCWalkMale01Source", "NPCWalkMale02Source", "NPCWalkMale03Source",
    "NPCWalkSource", "walkFwd1Source", "walk1Source", "walkForward1Source",
}
local IDLE_CLIP_CANDIDATES = {
    "idle1Source", "idle2Source", "idleSource", "idle1FemaleSource",
}

local function terrainY(x, z, fallback)
    if g_currentMission == nil or g_currentMission.terrainRootNode == nil then
        return fallback or 0
    end
    local ok, y = pcall(getTerrainHeightAtWorldPos, g_currentMission.terrainRootNode, x, 0, z)
    if not ok or type(y) ~= "number" then return fallback or 0 end
    return y
end

local function playerWorldPos()
    local player = g_localPlayer or (g_currentMission and g_currentMission.player)
    if player == nil or player.rootNode == nil then return nil end
    local ok, px, py, pz = pcall(getWorldTranslation, player.rootNode)
    if not ok or type(px) ~= "number" then return nil end
    return px, py, pz
end

local function findClip(charSet, candidates)
    if charSet == nil or charSet == 0 then return -1, nil end
    for _, name in ipairs(candidates) do
        local ok, idx = pcall(getAnimClipIndex, charSet, name)
        if ok and type(idx) == "number" and idx >= 0 then
            return idx, name
        end
    end
    return -1, nil
end

function WalterWalker.new()
    local self = setmetatable({}, WalterWalker)
    self.grandpa      = nil
    self.graphicsNode = nil
    self.spotNode     = nil
    self.triggerNode  = nil   -- grandpa.interactionTriggerNode; moved to follow him so you can talk mid-walk
    self.hotspot      = nil   -- grandpa.mapHotspot; we shadow its instance getWorldPosition so the icon follows
    self._origGetWP   = nil   -- saved original hotspot getWorldPosition (restored on delete)
    self._shed        = nil   -- cached woodshop placeable (door + lights live on it)
    self._woodshopDoorAO = nil -- cached AnimatedObject for the woodshop door (openDoor/closeDoor waypoints)
    self.animCharSet  = nil
    self._walkClipIdx = -1
    self._idleClipIdx = -1
    self._isWalking   = false
    self._ry          = 0
    self._wx          = 0
    self._wy          = 0
    self._wz          = 0
    self.walk         = nil
    self._active      = false
    self._hidden      = false  -- true while Walter has "stepped inside" (graphicsRootNode invisible)
    self._stoppedForPlayer = false  -- true while he's halted to face a nearby player (logs once)
    self._lastWakeDay = nil    -- monotonicDay of his last 5am wake-up (so it fires once per day)
    self._loop        = nil
    self._lastTick    = -1
    self._yOffset     = nil   -- lazy-init from VLConfig.WALTER_WALK.yOffset; live-tunable via vlWalterYOffset
    self._stairLift   = nil   -- lazy-init from VLConfig.WALTER_WALK.stairLift; live-tunable via vlWalterStairLift
    self._origPlayerGraphicsUpdate = nil
    self._patchedClass             = nil
    return self
end

function WalterWalker:_acquireNode()
    if self.grandpa ~= nil then return true end
    local grandpa = g_npcManager and g_npcManager:getNPCByName("GRANDPA")
    if grandpa == nil or grandpa.node == nil or not entityExists(grandpa.node) then
        return false
    end
    if not grandpa.isActive then return false end

    self.grandpa = grandpa

    local grn = nil
    pcall(function()
        local pg = grandpa.playerGraphics or grandpa.graphicsComponent
        if pg then grn = pg.graphicsRootNode end
    end)
    self.graphicsNode = (grn ~= nil and grn ~= 0 and entityExists(grn)) and grn or nil

    -- Capture spot.node (43446) — the engine's INPUT transform. With isNPC=true,
    -- playerGraphics:update snaps graphicsRootNode to this node every frame. By driving
    -- spot.node ourselves (before the snap), the engine writes our values into the mesh —
    -- no fight, because we feed its input instead of overwriting its output.
    local sn = grandpa.spot and grandpa.spot.node
    self.spotNode = (sn ~= nil and sn ~= 0 and entityExists(sn)) and sn or nil

    -- Interaction trigger (the "press to talk" zone). Base-game it sits at his home spot;
    -- we move it to his driven position each active frame so he's talkable mid-walk.
    local tn = grandpa.interactionTriggerNode
    self.triggerNode = (tn ~= nil and tn ~= 0 and entityExists(tn)) and tn or nil

    -- Map icon: the NPC hotspot's getWorldPosition (an INSTANCE field, R34) returns a STATIC value
    -- (GRANDPA's spawn) ignoring worldX/Z, setWorldPosition, grandpa.x/z and all nodes (R29).
    -- Shadow it on the instance so the icon render (hs:getWorldPosition()) reads his driven
    -- position while walking, and the base value when idle. (The ESC-map "Visit" reads a deeper
    -- snapshot we can't reach here — known limitation, R35.)
    local hs = grandpa.mapHotspot
    self.hotspot = hs
    if hs ~= nil and self._origGetWP == nil and type(hs.getWorldPosition) == "function" then
        local walker = self
        local orig   = hs.getWorldPosition
        hs.getWorldPosition = function(selfHs)
            if walker._active then return walker._wx, walker._wz end
            return orig(selfHs)
        end
        self._origGetWP = orig
        print("[ValleyLife][Walter] hotspot getWorldPosition overridden")
    end

    -- Seed facing + world position from the current graphicsNode so he doesn't snap.
    if self.graphicsNode then
        pcall(function()
            local _, ry, _ = getRotation(self.graphicsNode)
            if type(ry) == "number" then self._ry = ry end
            local wx, wy, wz = getTranslation(self.graphicsNode)
            if type(wx) == "number" then self._wx, self._wy, self._wz = wx, wy, wz end
        end)
    end

    -- Patch playerGraphics:update at the CLASS level. Our writes to spot.node happen
    -- BEFORE orig() runs, so the engine's snap (inside orig) reads our values.
    local pg  = grandpa.playerGraphics
    local cls = pg and (getmetatable(pg) or {})
    cls       = (type(cls.__index) == "table" and cls.__index) or cls
    if pg and self._origPlayerGraphicsUpdate == nil then
        local orig = cls.update or pg.update
        if type(orig) == "function" then
            local walker  = self
            local patched = function(self_pg, dt)
                local grn    = self_pg.graphicsRootNode
                local active = walker._active and self_pg == walker.grandpa.playerGraphics
                               and grn and entityExists(grn)

                -- R17: while Walter is actively walking, SKIP orig() (the GIANTS graphics update) so
                -- its ConditionalAnimation doesn't fight our direct track-0 clip = the twitch.
                -- BUT a CONVERSATION needs orig() to animate (face/gestures); if a route is active
                -- during a conversation, skipping orig() starves it → he glides. So also run orig()
                -- when in conversation, and let _updateWalk yield the route to the base game.
                local inConvo = walker.grandpa and walker.grandpa.isInConversation
                if (not active) or inConvo then
                    orig(self_pg, dt)
                    return
                end

                -- Active walk (not in conversation): drive facing ourselves; orig stays dormant.
                setRotation(grn, 0, walker._ry, 0)
            end
            if cls.update then
                cls.update = patched
            else
                pg.update = patched
            end
            self._origPlayerGraphicsUpdate = orig
            self._patchedClass = cls.update and cls or nil
            print(string.format("[ValleyLife][Walter] patched %s.update",
                cls.update and "CLASS" or "instance"))
        end
    end

    return true
end

-- Mirror of NPCEntity.setupDirectIdleAnimation — resolves charSet via model.skeleton,
-- cloning from g_animCache if needed (same fallback Marta uses).
function WalterWalker:_tryResolveAnim()
    if self.animCharSet ~= nil then return end
    local pg = self.grandpa and self.grandpa.playerGraphics
    if pg == nil or pg.model == nil then return end
    local skeleton = pg.model.skeleton
    if skeleton == nil or skeleton == 0 then return end

    local function resolveCharSet(sk)
        local acs = 0
        pcall(function() acs = getAnimCharacterSet(sk) end)
        if (acs == nil or acs == 0) then
            pcall(function()
                local child = getChildAt(sk, 0)
                if child and child ~= 0 then acs = getAnimCharacterSet(child) end
            end)
        end
        return acs or 0
    end

    local acs = resolveCharSet(skeleton)

    -- If still 0, clone the full animation library onto the skeleton (same as NPCEntity)
    if acs == 0 and g_animCache ~= nil and AnimationCache ~= nil and cloneAnimCharacterSet ~= nil then
        pcall(function()
            local animNode = g_animCache:getNode(AnimationCache.CHARACTER)
            if animNode and animNode ~= 0 then
                local src = getChildAt(animNode, 0)
                if src and src ~= 0 then
                    cloneAnimCharacterSet(src, skeleton)
                end
            end
        end)
        acs = resolveCharSet(skeleton)
    end

    if acs == 0 then return end

    -- R15: silence any competing base-game animation tracks (Marta does disableAnimTrack(cs,1),
    -- NPCEntity.lua:827). GRANDPA's playerGraphics may drive its own anim on another track that
    -- poses the body at world-0; we only want OUR track 0. Disable 1..4 defensively.
    if disableAnimTrack ~= nil then
        for t = 1, 4 do pcall(function() disableAnimTrack(acs, t) end) end
    end

    self.animCharSet  = acs
    local wi, wn = findClip(acs, WALK_CLIP_CANDIDATES)
    local ii, in_ = findClip(acs, IDLE_CLIP_CANDIDATES)
    self._walkClipIdx = wi
    self._idleClipIdx = ii
    print(string.format("[ValleyLife][Walter] charSet=%d walk=%s[%d] idle=%s[%d]",
        acs, tostring(wn), wi, tostring(in_), ii))
end

-- Mirror of NPCEntity:applyIdleAnimationParameters — drives the ConditionalAnimation
-- blend tree on playerGraphics (g_npcManager calls playerGraphics:update(dt) for us).
function WalterWalker:_setAnimParams(walking)
    local pg = self.grandpa and self.grandpa.playerGraphics
    if pg == nil then return end
    local nameToIdx = pg.animationParameters
    local paramObjs = pg.animation and pg.animation.parameters
    if type(nameToIdx) ~= "table" or type(paramObjs) ~= "table" then return end
    local speed = walking and (VLConfig.WALTER_WALK.speed or 0.8) or 0
    local function set(name, value)
        local idx = nameToIdx[name]
        if idx == nil then return end
        local p = paramObjs[idx]
        if type(p) == "table" then p.value = value end
    end
    set("isNPC",             false)  -- engine must NOT pin position; we move graphicsNode directly
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

function WalterWalker:_startWalkAnim()
    if self._isWalking then return end
    self._isWalking = true
    self:_setAnimParams(true)
    if self.animCharSet ~= nil and self._walkClipIdx >= 0 then
        pcall(function()
            clearAnimTrackClip(self.animCharSet, 0)
            assignAnimTrackClip(self.animCharSet, 0, self._walkClipIdx)
            setAnimTrackLoopState(self.animCharSet, 0, true)
            enableAnimTrack(self.animCharSet, 0)
        end)
    end
end

function WalterWalker:_stopWalkAnim()
    if not self._isWalking then return end
    self._isWalking = false
    self:_setAnimParams(false)
    if self.animCharSet ~= nil and self._idleClipIdx >= 0 then
        pcall(function()
            clearAnimTrackClip(self.animCharSet, 0)
            assignAnimTrackClip(self.animCharSet, 0, self._idleClipIdx)
            setAnimTrackLoopState(self.animCharSet, 0, true)
            enableAnimTrack(self.animCharSet, 0)
        end)
    end
end

-- Keep everything that should travel with Walter pinned to his driven position each active frame.
-- The base game leaves all of these at grandpa.x/z (his home spot) and never tracks our
-- graphicsRootNode walk (R21). We run AFTER g_npcManager.update, so our writes win.
function WalterWalker:_syncFollowers()
    local grandpa = self.grandpa
    if grandpa == nil then return end
    local x, y, z = self._wx, self._wy, self._wz

    -- NPC position fields (base game derives range/trigger logic from these; body is separate).
    grandpa.x, grandpa.y, grandpa.z = x, y, z

    -- Map icon RENDER follows via the getWorldPosition override installed in _acquireNode (R30).
    -- The map's "Visit"/teleport reads the hotspot's worldX/worldZ FIELDS instead (R31), so keep
    -- those updated too or Visit warps to his spawn spot.
    local hs = self.hotspot
    if hs ~= nil then
        if type(hs.setWorldPosition) == "function" then pcall(function() hs:setWorldPosition(x, z) end) end
        pcall(function() hs.worldX = x; hs.worldZ = z end)
    end

    -- Interaction trigger follows too (setWorldTranslation does move it — R28).
    if self.triggerNode and entityExists(self.triggerNode) then
        pcall(function() setWorldTranslation(self.triggerNode, x, y, z) end)
    end

    -- Mark him in range by our own distance check (the physics trigger won't fire while dragged,
    -- R26). Harmless on its own; kept for systems that read isPlayerInRange.
    local range = (VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.interactRange) or 4.5
    local px, _, pz = playerWorldPos()
    if px ~= nil then
        local dx, dz = px - x, pz - z
        grandpa.isPlayerInRange = (dx * dx + dz * dz) <= (range * range)
    end
end

-- Resolve + cache the woodshop placeable (tinyShed01 nearest the configured point). Both the door
-- and the lights live on it. Re-resolves if the cached placeable is gone.
function WalterWalker:_resolveShed()
    local dcfg = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.woodshopDoor
    if type(dcfg) ~= "table" then return nil end
    local shed = self._shed
    if shed ~= nil and shed.rootNode and entityExists(shed.rootNode) then return shed end
    shed = nil
    local placeables = g_currentMission and g_currentMission.placeableSystem
                       and g_currentMission.placeableSystem.placeables
    if type(placeables) == "table" then
        local best, bestd
        for _, p in ipairs(placeables) do
            local nameOk = true
            if dcfg.config then
                local cf = p.configFileName
                nameOk = type(cf) == "string" and cf:find(dcfg.config, 1, true) ~= nil
            end
            if nameOk then
                local px, pz
                pcall(function() local a, _, c = getWorldTranslation(p.rootNode); px, pz = a, c end)
                if px then
                    local d = (px - dcfg.near.x)^2 + (pz - dcfg.near.z)^2
                    if bestd == nil or d < bestd then best, bestd = p, d end
                end
            end
        end
        shed = best
    end
    self._shed = shed
    return shed
end

-- Open (+1) / close (-1) the woodshop door by driving its AnimatedObject directly. The door is
-- purely cosmetic for Walter (he has no collider), so this just plays the swing animation on cue.
function WalterWalker:_setWoodshopDoor(dir)
    local dcfg = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.woodshopDoor
    local shed = self:_resolveShed()
    if shed == nil or dcfg == nil then return false end
    local ao = self._woodshopDoorAO
    if ao == nil or ao.nodeId == nil or not entityExists(ao.nodeId) then
        ao = nil
        local aos = shed.spec_animatedObjects and shed.spec_animatedObjects.animatedObjects
        if type(aos) == "table" then
            for _, a in ipairs(aos) do if a.saveId == dcfg.saveId then ao = a; break end end
        end
        self._woodshopDoorAO = ao
    end
    if ao == nil or type(ao.setDirection) ~= "function" then return false end
    pcall(function() ao:setDirection(dir) end)
    print(string.format("[ValleyLife][Walter] woodshop door setDirection(%d)", dir))
    return true
end

-- Turn the woodshop lights on/off. setLightState/setLightsState aren't exposed on this build, so we
-- replicate the manual toggle the activatable does: set each group's isActive + updateLightState +
-- lightSetupChanged (confirmed working via vlLightTest).
function WalterWalker:_setWoodshopLights(on)
    local shed = self:_resolveShed()
    local sp = shed and shed.spec_lights
    local groups = sp and sp.groups
    if type(groups) ~= "table" then return false end
    for _, g in ipairs(groups) do
        pcall(function() g.isActive = on end)
        if type(shed.updateLightState) == "function" then
            pcall(function() shed:updateLightState(g.index or 1) end)
        end
    end
    if type(shed.lightSetupChanged) == "function" then pcall(function() shed:lightSetupChanged() end) end
    print(string.format("[ValleyLife][Walter] woodshop lights %s", on and "on" or "off"))
    return true
end

function WalterWalker:_loopRunnable(loop)
    return type(loop) == "table" and type(loop.waypoints) == "table" and #loop.waypoints >= 2
end

-- Reversible hide / reveal of GRANDPA's visual mesh. NOT a despawn (the entity stays — same
-- mechanism Marta uses, NPCEntity.lua:1108/1022). "Stepping inside" = setVisibility(false);
-- starting any loop (or vlWalterShow) brings him back.
function WalterWalker:_hide()
    if self.graphicsNode and entityExists(self.graphicsNode) then
        setVisibility(self.graphicsNode, false)
    end
    self._hidden = true
    print("[ValleyLife][Walter] stepped inside (hidden)")
end

function WalterWalker:_reveal()
    if self.graphicsNode and entityExists(self.graphicsNode) then
        setVisibility(self.graphicsNode, true)
    end
    self._hidden = false
    print("[ValleyLife][Walter] revealed (visible)")
end

-- Morning wake-up: put him back at his farmhouse spot, then reveal. We set the position
-- ourselves so he doesn't flash in at last night's door spot; if the base game also keeps
-- GRANDPA at his rest spot, our write simply agrees (home == GRANDPA_FARMHOUSE spot).
function WalterWalker:_revealAtHome(cfg)
    local home = cfg and cfg.home
    if home and self.graphicsNode and entityExists(self.graphicsNode) then
        self._wx, self._wy, self._wz = home.x, home.y, home.z
        self._ry = cfg.homeRy or self._ry
        pcall(function()
            setTranslation(self.graphicsNode, home.x, home.y - (self._yOffset or 0), home.z)
            setRotation(self.graphicsNode, 0, self._ry, 0)
        end)
        self:_syncFollowers()  -- put the map point + trigger back at home with him
    end
    self:_reveal()
    print("[ValleyLife][Walter] started his day (revealed at home)")
end

-- Morning departure: at 5am he steps out the door and walks down to home. Reveal him AT the door
-- (waypoint[1] of the morningDeparture loop), face the next waypoint, then run the loop. Falls back
-- to a plain home-reveal if the loop is missing. Mirror of eveningReturn (which ends by hiding at
-- the door); this ends at home via the endOnArrival waypoint.
function WalterWalker:_startMorningDeparture(cfg)
    local loop = cfg and WorkLoopHelper.findByName(cfg.loops, "morningDeparture")
    if loop == nil or not self:_loopRunnable(loop) then
        self:_revealAtHome(cfg)  -- no morning loop captured → just appear at home
        return
    end
    local door = loop.waypoints[1]
    local nxt  = loop.waypoints[2]
    self._wx, self._wy, self._wz = door.x, door.y or self._wy, door.z
    if nxt then self._ry = math.atan2(nxt.x - door.x, nxt.z - door.z) end  -- face down the steps
    if self.graphicsNode and entityExists(self.graphicsNode) then
        pcall(function()
            setTranslation(self.graphicsNode, self._wx, self._wy - (self._yOffset or 0), self._wz)
            setRotation(self.graphicsNode, 0, self._ry, 0)
        end)
    end
    self:_reveal()        -- make him visible at the door
    self:_beginLoop(loop) -- walk door -> stairMid -> doorApproach -> home (ends there)
    self:_syncFollowers()
    print("[ValleyLife][Walter] morning departure: stepping out the door")
end

function WalterWalker:_beginLoop(loop)
    if self._hidden then self:_reveal() end  -- a loop start always brings him back outside
    self._loop   = loop
    self.walk    = { state = "walking", targetIdx = 2 }  -- wp[1] is home; head out first
    self._active = true
    print(string.format("[ValleyLife][Walter] loop '%s' started", loop.name or "?"))
end

function WalterWalker:_endLoop(cfg)
    self:_stopWalkAnim()
    self._active = false
    self.walk    = nil
    self._loop   = nil
    -- Settle facing to home heading; the base game resumes idle control next frame
    -- (orig() runs again once _active is false) so conversation/face stay intact.
    if cfg and cfg.homeRy then self._ry = cfg.homeRy end
    print("[ValleyLife][Walter] loop complete; idling at home")
end

-- Force-start a loop now (vlWalk), bypassing the timer. `selector` is a loop name,
-- an index, or nil (= the loop active at the current hour). Returns name/index or nil.
function WalterWalker:forceWalkLoop(selector)
    local cfg = VLConfig.WALTER_WALK
    if type(cfg) ~= "table" or type(cfg.loops) ~= "table" then return nil end
    local loop = WorkLoopHelper.resolve(cfg.loops, selector, TimeHelper.getHour())
    if loop == nil or not self:_loopRunnable(loop) then return nil end
    self:_beginLoop(loop)
    self._lastTick = math.floor(TimeHelper.getHour() / 2)  -- avoid an immediate auto re-fire
    return loop.name or selector
end

-- End the current mid-route pause now (vlSkipPause grandpa). Zeroing the required time makes the
-- pausing branch advance next frame via its normal path (so hideOnEnd/endOnArrival still apply).
function WalterWalker:skipPause()
    if self.walk ~= nil and self.walk.state == "pausing" then
        self.walk.pauseMinutesRequired = 0
        return true
    end
    return false
end

function WalterWalker:loopNames()
    local cfg = VLConfig.WALTER_WALK
    return WorkLoopHelper.names(cfg and cfg.loops)
end

function WalterWalker:update(dt)
    if not self:_acquireNode() then return end
    self:_tryResolveAnim()

    local cfg = VLConfig.WALTER_WALK
    if type(cfg) ~= "table" or type(cfg.loops) ~= "table" then return end
    if self._yOffset    == nil then self._yOffset   = cfg.yOffset   or 0    end
    if self._stairLift  == nil then self._stairLift = cfg.stairLift or 0.15 end

    if self._active then
        self:_updateWalk(cfg, dt)
        return
    end

    local hour = TimeHelper.getHour()

    -- Start his day at dayStartHour. EDGE-triggered, once per calendar day: the first time
    -- we see hour >= dayStartHour on a new monotonicDay, mark the day woken and — if he
    -- stepped inside last evening — bring him back out at home. A daytime hide (vlWalterHide)
    -- then STAYS hidden until the next day's 5am (or vlWalterShow), instead of being undone
    -- the next frame the way a level-triggered window did (R19).
    if hour >= (cfg.dayStartHour or 5) then
        local day = TimeHelper.getMonotonicDay() or 0
        if day ~= self._lastWakeDay then
            self._lastWakeDay = day
            -- If he stepped inside last evening, walk him back out the door (morning departure).
            if self._hidden then self:_startMorningDeparture(cfg); return end
        end
    end

    -- Not walking: auto-start the loop whose window contains this hour, re-firing on
    -- the 2-hour tick (same cadence as Marta). Never interrupt a conversation.
    if self.grandpa and self.grandpa.isInConversation then return end
    local loop = WorkLoopHelper.getActiveLoop(cfg.loops, hour)
    if loop and self:_loopRunnable(loop) then
        local tick = math.floor(hour / 2)
        if tick ~= self._lastTick then
            self._lastTick = tick
            self:_beginLoop(loop)
        end
    end
end

-- Height for the current position. If BOTH the current segment's endpoints carry a
-- captured `y` (from vlPos), interpolate between them so Walter rises/descends with
-- porches and stairs the terrain heightmap doesn't include. Otherwise snap to terrain.
function WalterWalker:_surfaceY(waypoints, walk, target)
    local prevIdx = walk.targetIdx - 1
    if prevIdx < 1 then prevIdx = #waypoints end
    local a = waypoints[prevIdx]
    if target.y and a and a.y then
        local sdx, sdz = target.x - a.x, target.z - a.z
        local segLen   = math.sqrt(sdx*sdx + sdz*sdz)
        if segLen > 0.001 then
            local pdx, pdz = self._wx - a.x, self._wz - a.z
            local along    = math.sqrt(pdx*pdx + pdz*pdz)
            local frac     = math.min(math.max(along / segLen, 0), 1)
            local linear   = a.y + (target.y - a.y) * frac
            -- On sloped segments, add a convex bow to lift feet over stair-tread noses.
            -- The parabola 4*frac*(1-frac) is zero at both endpoints and peaks at mid-segment.
            local dy = math.abs(target.y - a.y)
            if dy > 0.05 then
                linear = linear + (self._stairLift or 0) * 4 * frac * (1 - frac)
            end
            return linear
        end
        return target.y
    end
    return terrainY(self._wx, self._wz, self._wy)
end

function WalterWalker:_updateWalk(cfg, dt)
    local walk = self.walk
    local loop = self._loop
    if loop == nil then self._active = false; return end
    local waypoints = loop.waypoints
    local speed     = loop.speed or cfg.speed or 0.8

    -- Keep his map point + interaction trigger on him every active frame (R21).
    self:_syncFollowers()

    -- In conversation: YIELD fully to the base game. The wrapper runs orig() so the conversation
    -- animates (face/gestures); we just revert our walk clip to idle once and stop driving. (Driving
    -- the walk while talking starves the conversation of orig() → gliding.) He holds position because
    -- orig() with isNPC=false doesn't move him. Resume the route when the conversation ends.
    if self.grandpa.isInConversation then
        self:_stopWalkAnim()
        return
    end

    -- Stop & face the player when he's near (not talking), and hold there. His trigger is now
    -- stationary, so walking up to him fires the normal base-game talk prompt + conversation.
    local approach   = cfg.approachRange or 6.0
    local px, _, pz  = playerWorldPos()
    local playerNear = false
    if px ~= nil then
        local dx, dz = px - self._wx, pz - self._wz
        playerNear = (dx * dx + dz * dz) <= (approach * approach)
    end
    if playerNear then
        self:_stopWalkAnim()
        if px ~= nil then
            local targetRy = math.atan2(px - self._wx, pz - self._wz)
            local maxTurn  = WALK_TURN_RATE * (dt / 1000)
            self._ry = lerpAngle(self._ry, targetRy, maxTurn)
        end
        setTranslation(self.graphicsNode, self._wx, self._wy - (self._yOffset or 0), self._wz)
        if not self._stoppedForPlayer then
            self._stoppedForPlayer = true
            print(string.format("[ValleyLife][Walter] player near; stopping to face them at (%.1f, %.1f)", self._wx, self._wz))
        end
        return
    elseif self._stoppedForPlayer then
        self._stoppedForPlayer = false
        print("[ValleyLife][Walter] player left; resuming walk")
    end

    if walk.state == "pausing" then
        self:_stopWalkAnim()
        if walk.pauseTargetRy then
            local maxStep = WALK_TURN_RATE * (dt / 1000)
            self._ry = lerpAngle(self._ry, walk.pauseTargetRy, maxStep)
        end
        -- Rotation applied via applyPosition() which runs from the g_npcManager.update hook,
        -- immediately after playerGraphics:update — before this FSBaseMission.update hook.
        -- Nothing here so we don't double-write rotation and position in the same phase.
        local elapsed = TimeHelper.getHour() - walk.pauseStartHour
        if elapsed < 0 then elapsed = elapsed + 24 end
        if elapsed >= walk.pauseMinutesRequired / 60 then
            -- A hideOnEnd waypoint (e.g. houseDoor): pause first ("at the door"), then step
            -- inside — hide him and end the circuit instead of looping back.
            local cur = waypoints[walk.targetIdx]
            if cur and cur.hideOnEnd then
                self:_hide()
                self:_endLoop(cfg)
                return
            end
            local nextIdx = walk.targetIdx + 1
            if nextIdx > #waypoints then nextIdx = 1 end
            walk.targetIdx = nextIdx
            walk.state     = "walking"
        end
        return
    end

    local target = waypoints[walk.targetIdx]
    local dx     = target.x - self._wx
    local dz     = target.z - self._wz
    local dist   = math.sqrt(dx*dx + dz*dz)
    local step   = speed * (dt / 1000)

    -- Within one frame's travel → snap exactly onto the waypoint (same as Marta,
    -- NPCEntity.lua:1093) so he lands on the recorded spot instead of cutting the
    -- corner 1.5 m short. Then handle end / pause / advance.
    if dist <= step or dist <= 0.05 then
        self._wx = target.x
        self._wz = target.z
        self._wy = (target.y ~= nil) and target.y or terrainY(self._wx, self._wz, self._wy)
        setTranslation(self.graphicsNode, self._wx, self._wy - (self._yOffset or 0), self._wz)

        -- Reached a waypoint that opens/closes the woodshop door (cosmetic swing on cue).
        if target.openDoor  then self:_setWoodshopDoor(1)  end
        if target.closeDoor then self:_setWoodshopDoor(-1) end
        -- ...and lights on/off as he enters/leaves.
        if target.lightsOn  then self:_setWoodshopLights(true)  end
        if target.lightsOff then self:_setWoodshopLights(false) end

        -- Back at waypoint [1] (home) → circuit done; idle, base game resumes control.
        if walk.targetIdx == 1 then
            self:_endLoop(cfg)
            return
        end
        self:_stopWalkAnim()
        local pauseMin = target.pauseMinutes
        -- endOnArrival: a one-way route's final waypoint (e.g. morningDeparture's home) — stop &
        -- idle here, base game resumes control. Don't loop back to waypoint[1].
        if target.endOnArrival then
            self:_endLoop(cfg)
            return
        end
        -- hideOnEnd with no pause: step inside the moment he arrives.
        if target.hideOnEnd and not (pauseMin and pauseMin > 0) then
            self:_hide()
            self:_endLoop(cfg)
            return
        end
        if pauseMin and pauseMin > 0 then
            walk.state                = "pausing"
            walk.pauseStartHour       = TimeHelper.getHour()
            walk.pauseMinutesRequired = pauseMin
            walk.pauseTargetRy        = target.pauseRy
            print(string.format("[ValleyLife][Walter] reached '%s', pausing %.0f min",
                target.name or ("wp" .. walk.targetIdx), pauseMin))
        else
            local nextIdx = walk.targetIdx + 1
            if nextIdx > #waypoints then nextIdx = 1 end
            walk.targetIdx = nextIdx
            print(string.format("[ValleyLife][Walter] reached '%s' -> '%s'",
                target.name or "?", (waypoints[nextIdx] and waypoints[nextIdx].name) or ("wp" .. nextIdx)))
        end
        return
    end

    -- Not there yet: turn toward the target (pivot in place first if the turn is
    -- sharp), then advance once roughly aligned.
    local targetRy = math.atan2(dx, dz)
    local maxTurn  = WALK_TURN_RATE * (dt / 1000)
    self._ry       = lerpAngle(self._ry, targetRy, maxTurn)

    local diff = targetRy - self._ry
    while diff >  math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end

    self:_startWalkAnim()
    if math.abs(diff) <= WALK_TURN_THRESHOLD then
        self._wx = self._wx + (dx/dist)*step
        self._wz = self._wz + (dz/dist)*step
        self._wy = self:_surfaceY(waypoints, walk, target)
        setTranslation(self.graphicsNode, self._wx, self._wy - (self._yOffset or 0), self._wz)
    end
    -- Rotation written to graphicsRootNode in the playerGraphics:update wrapper (last line).
end

function WalterWalker:applyPosition()
    -- Drive spot.node only. The wrapper feeds spot.node before the engine snaps; this hook
    -- keeps spot.node parked at our target between frames. NEVER touch graphicsNode rotation
    -- directly — that fights the engine's snap and is the source of all prior twitching.
    if not self._active then return end
    if self.graphicsNode == nil or not entityExists(self.graphicsNode) then return end
    setRotation(self.graphicsNode, 0, self._ry, 0)
end

function WalterWalker:delete()
    if self._origPlayerGraphicsUpdate then
        if self._patchedClass then
            self._patchedClass.update = self._origPlayerGraphicsUpdate
        elseif self.grandpa and self.grandpa.playerGraphics then
            self.grandpa.playerGraphics.update = self._origPlayerGraphicsUpdate
        end
        self._origPlayerGraphicsUpdate = nil
        self._patchedClass = nil
    end
    -- Restore the hotspot's original getWorldPosition (we shadowed it on the instance).
    if self._origGetWP and self.hotspot then
        pcall(function() self.hotspot.getWorldPosition = self._origGetWP end)
    end
    self._origGetWP = nil
    self.hotspot    = nil
    self:_stopWalkAnim()
    self.grandpa      = nil
    self.graphicsNode = nil
    self.animCharSet  = nil
    self.walk         = nil
    self._loop        = nil
    self._active      = false
end
