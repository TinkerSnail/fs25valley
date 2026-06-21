-- Drives GRANDPA along a waypoint loop with direct graphicsNode translation + walk animation.
-- animCharSet is on graphicsRootNode (confirmed = 97 after isActive=true).
-- Uses the same clearAnimTrackClip / assignAnimTrackClip / enableAnimTrack pattern as NPCEntity.

WalterWalker = {}
WalterWalker.__index = WalterWalker

local ARRIVAL_DIST       = 1.5
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
    self._lastLog     = 0
    self._origPlayerGraphicsUpdate = nil
    self._patchedClass             = nil
    self._dbgNodes                 = nil
    self._probeT                   = 0
    self._lastWrittenRy            = 0
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
            local invoked = false
            local patched = function(self_pg, dt)
                local grn    = self_pg.graphicsRootNode
                local active = walker._active and self_pg == walker.grandpa.playerGraphics
                               and grn and entityExists(grn)

                if not invoked then
                    invoked = true
                    print("[ValleyLife][Walter] CLASS patch wrapper INVOKED (R17 skip-orig-when-active)")
                end

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
                walker._lastWrittenRy = walker._ry

                -- Light verification trace (1/sec): is the body still following our _ry?
                local now = (getTimeSec and getTimeSec()) or 0
                if (now - (walker._probeT or 0)) > 1.0 then
                    walker._probeT = now
                    local hipW = (walker._hipsNode and entityExists(walker._hipsNode))
                        and select(2, getWorldRotation(walker._hipsNode)) or 0
                    print(string.format("[ValleyLife][Walter] R17 grnRy=%.3f hipsW=%.3f _ry=%.3f state=%s",
                        select(2, getRotation(grn)) or 0, hipW or 0, walker._ry,
                        (walker.walk and walker.walk.state) or "none"))
                end
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

    -- Dump playerGraphics + grandpa scalar fields once, hunting for the rotation/heading
    -- INPUT the C update reads to recompute graphicsRootNode rotation each frame. Same
    -- strategy that found spot.node — find the input, feed it our facing, stop fighting output.
    local function dumpScalars(label, obj)
        if type(obj) ~= "table" then return end
        local fields = {}
        for k, v in pairs(obj) do
            local t = type(v)
            if t == "number" or t == "boolean" then
                fields[#fields+1] = string.format("%s=%s", tostring(k), tostring(v))
            end
        end
        table.sort(fields)
        print(string.format("[ValleyLife][Walter] %s scalars: %s", label, table.concat(fields, " | ")))
    end
    pcall(function() dumpScalars("playerGraphics", grandpa.playerGraphics) end)
    pcall(function() dumpScalars("grandpa", grandpa) end)
    pcall(function()
        if grandpa.playerGraphics and grandpa.playerGraphics.model then
            dumpScalars("pg.model", grandpa.playerGraphics.model)
        end
    end)

    -- Build a list of candidate rotation-carrying nodes and dump their hierarchy + live ry.
    -- The node whose ry oscillates against our _ry during walk is the one the C animation
    -- pass writes — i.e. the real handle for visible facing.
    self._dbgNodes = {}
    local function addDbg(name, n)
        if type(n) == "number" and n ~= 0 and entityExists(n) then
            self._dbgNodes[#self._dbgNodes+1] = { name = name, id = n }
            local p = -1
            pcall(function() p = getParent(n) or -1 end)
            local rx, ry, rz = 0, 0, 0
            pcall(function() rx, ry, rz = getRotation(n) end)
            print(string.format("[ValleyLife][Walter] node %-20s id=%d parent=%d ry=%.3f",
                name, n, p, ry or 0))
        else
            print(string.format("[ValleyLife][Walter] node %-20s = nil/invalid (%s)", name, tostring(n)))
        end
    end
    local pgm = grandpa.playerGraphics and grandpa.playerGraphics.model
    addDbg("graphicsRootNode",     grandpa.playerGraphics and grandpa.playerGraphics.graphicsRootNode)
    addDbg("model.rootNode",       pgm and pgm.rootNode)
    addDbg("model.skeleton",       pgm and pgm.skeleton)
    addDbg("model.skeletonRoot",   pgm and pgm.skeletonRootNode)
    addDbg("model.animRoot3rd",    pgm and pgm.animRootThirdPerson)
    addDbg("model.mesh",           pgm and pgm.mesh)
    addDbg("model.hips3rd",        pgm and pgm.thirdPersonHipsNode)
    addDbg("grandpa.node",         grandpa.node)

    -- R13: capture the visible-body nodes so the wrapper can log their WORLD orientation each
    -- frame. graphicsRootNode.ry is proven stable (R12); if a body node's WORLD ry twitches while
    -- the graphicsRootNode is steady, the animation/skeleton drives facing, not the node.
    self._meshNode = (pgm and pgm.mesh and pgm.mesh ~= 0 and entityExists(pgm.mesh)) and pgm.mesh or nil
    self._hipsNode = (pgm and pgm.thirdPersonHipsNode and pgm.thirdPersonHipsNode ~= 0
                      and entityExists(pgm.thirdPersonHipsNode)) and pgm.thirdPersonHipsNode or nil

    print(string.format("[ValleyLife][Walter] acquired: pos=(%.1f,%.1f,%.1f) graphicsNode=%s spotNode=%s ry=%.2f",
        self._wx, self._wy, self._wz, tostring(self.graphicsNode), tostring(self.spotNode), self._ry))
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
        print("[ValleyLife][Walter] R15 disabled competing anim tracks 1..4")
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

function WalterWalker:update(dt)
    if not self:_acquireNode() then return end
    self:_tryResolveAnim()

    local cfg  = VLConfig.WALTER_WALK
    local hour = TimeHelper.getHour()

    if hour < cfg.startHour or hour >= cfg.endHour then
        if self._active then
            self:_stopWalkAnim()
            self.walk    = nil
            self._active = false
        end
        return
    end

    if not self._active then
        self.walk    = { state = "walking", targetIdx = 1 }
        self._active = true
        print(string.format("[ValleyLife][Walter] walk started at pos=(%.1f,%.1f)", self.grandpa.x or 0, self.grandpa.z or 0))
    end

    if self.walk then
        self:_updateWalk(cfg, dt)
    end
end

function WalterWalker:_updateWalk(cfg, dt)
    local walk      = self.walk
    local waypoints = cfg.waypoints

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

    local target   = waypoints[walk.targetIdx]
    local gx, gz   = self._wx, self._wz
    local dx       = target.x - gx
    local dz       = target.z - gz
    local dist     = math.sqrt(dx*dx + dz*dz)

    if dist > 0.05 then
        local targetRy = math.atan2(dx, dz)
        local maxStep  = WALK_TURN_RATE * (dt / 1000)
        self._ry       = lerpAngle(self._ry, targetRy, maxStep)

        local diff = targetRy - self._ry
        while diff >  math.pi do diff = diff - 2 * math.pi end
        while diff < -math.pi do diff = diff + 2 * math.pi end

        self:_startWalkAnim()
        if math.abs(diff) <= WALK_TURN_THRESHOLD then
            local step = math.min((cfg.speed or 0.8) * (dt / 1000), dist)
            self._wx = gx + (dx/dist)*step
            self._wz = gz + (dz/dist)*step
            self._wy = terrainY(self._wx, self._wz, self._wy)
            setTranslation(self.graphicsNode, self._wx, self._wy, self._wz)
        end
        -- Rotation written to graphicsRootNode in the playerGraphics:update wrapper (last line).
    end

    local now = getTimeSec and getTimeSec() or 0
    if (now - self._lastLog) > 3 then
        self._lastLog = now
        local rgx, _, rgz = 0, 0, 0
        if self.graphicsNode and entityExists(self.graphicsNode) then
            rgx, _, rgz = getTranslation(self.graphicsNode)
        end
        print(string.format("[ValleyLife][Walter] wp%d dist=%.1f want=(%.1f,%.1f) mesh=(%.1f,%.1f) anim=%s _ry=%.3f",
            walk.targetIdx, dist, gx, gz, rgx, rgz, self._isWalking and "walk" or "idle", self._ry))
        -- Per-node ry snapshot: which node is the engine actually steering?
        if self._dbgNodes then
            local parts = {}
            for _, nd in ipairs(self._dbgNodes) do
                if entityExists(nd.id) then
                    local _, ry, _ = getRotation(nd.id)
                    parts[#parts+1] = string.format("%s=%.3f", nd.name, ry or 0)
                end
            end
            local gry = self.grandpa and self.grandpa.rotY or 0
            print(string.format("[ValleyLife][Walter]   rots: grandpa.rotY=%.3f | %s", gry, table.concat(parts, " ")))
        end
    end

    if dist <= ARRIVAL_DIST then
        self:_stopWalkAnim()
        local pauseMin = target.pauseMinutes
        if pauseMin and pauseMin > 0 then
            walk.state                = "pausing"
            walk.pauseStartHour       = TimeHelper.getHour()
            walk.pauseMinutesRequired = pauseMin
            walk.pauseTargetRy        = target.pauseRy
            print(string.format("[ValleyLife][Walter] reached wp%d, pausing %.0f min", walk.targetIdx, pauseMin))
        else
            local nextIdx = walk.targetIdx + 1
            if nextIdx > #waypoints then nextIdx = 1 end
            walk.targetIdx = nextIdx
            print(string.format("[ValleyLife][Walter] reached wp%d -> wp%d", walk.targetIdx - 1, walk.targetIdx))
        end
    end
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
end
