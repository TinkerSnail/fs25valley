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

                -- R17: while Walter is actively walking, SKIP orig() (the GIANTS graphics update).
                -- orig() runs the ConditionalAnimation state machine, which flickers between walk and
                -- garbage states (swim/fall/horse, R16) and fights our direct track-0 clip = the twitch.
                -- Marta is clean because she never runs gfx:update during her walk (NPCEntity.lua:888-895).
                -- The engine still advances our enabled track-0 clip without orig(). When NOT active
                -- (idle/home), run orig() normally so conversation/facial/IK are untouched.
                if not active then
                    orig(self_pg, dt)
                    return
                end

                -- Active: drive facing ourselves; ConditionalAnimation stays dormant.
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

function WalterWalker:_loopRunnable(loop)
    return type(loop) == "table" and type(loop.waypoints) == "table" and #loop.waypoints >= 2
end

function WalterWalker:_beginLoop(loop)
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

    -- Not walking: auto-start the loop whose window contains this hour, re-firing on
    -- the 2-hour tick (same cadence as Marta). Never interrupt a conversation.
    if self.grandpa and self.grandpa.isInConversation then return end
    local hour = TimeHelper.getHour()
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

        -- Back at waypoint [1] (home) → circuit done; idle, base game resumes control.
        if walk.targetIdx == 1 then
            self:_endLoop(cfg)
            return
        end
        self:_stopWalkAnim()
        local pauseMin = target.pauseMinutes
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
    self:_stopWalkAnim()
    self.grandpa      = nil
    self.graphicsNode = nil
    self.animCharSet  = nil
    self.walk         = nil
    self._loop        = nil
    self._active      = false
end
