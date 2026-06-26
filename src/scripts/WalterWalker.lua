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
    self._clipOverride = nil   -- if set, _startWalkAnim plays this clip index on track 0 (clip testing)
    self._isWalking   = false
    self._ry          = 0
    self._wx          = 0
    self._wy          = 0
    self._wz          = 0
    self.walk         = nil
    self._active      = false
    self._hidden      = false  -- true while Walter has "stepped inside" (graphicsRootNode invisible)
    self._stoppedForPlayer = false  -- true while he's halted to face a nearby player (logs once)
    self._convoFrozen   = false  -- true once we've frozen followers for the current conversation (R49 FIX-5: park once, not per-frame)
    self._greetNear   = false  -- true while the player is within greet range (edge-trigger the bark)
    self._greetCooldown = 0    -- ms remaining before he'll greet again
    self._greetActive   = false -- true while OUR ambient greeting popup is up (tag-guarded close on walk-away)
    self._lastWakeDay = nil    -- monotonicDay of his last 5am wake-up (so it fires once per day)
    self._nightShopDay    = nil   -- monotonicDay of his last night-woodshop roll (fires/decides once per night)
    self._nightShopActive = false -- true while he's out for the occasional night visit (gates the "couldn't sleep" quip)
    self._handBone            = nil   -- cached RightHand skeleton bone (hand props link here)
    self._flashlightNode      = nil   -- loaded flashlight i3d root, linked under the hand bone
    self._flashlightLightNode = nil   -- its spotlight node (toggled on/off with the model)
    self._flashlightGraphics  = nil   -- the visible model subtree (0>0); visibility toggled here
    self._flashlightBaseRot   = nil   -- auto grip rotation (-handNode.rot); fc.rot adjusts on top (vlFlashRot)
    self._flashlightOn        = false
    self._flashlightFailed    = false -- i3d load failed once; don't retry it every frame
    self._flashlightForce     = nil   -- console override: true/false forces, nil = automatic (seasonal dusk)
    self._flashlightClipIdx   = nil   -- resolved index of cfg.flashlightWalkClip (carry pose); cached on first success
    self._armIKLoaded         = false -- rightArm IK chain loaded onto model.ikChains (the game strips it from NPCs)
    self._armIKActive         = false -- driving the chain each frame (vlWalterArmIK) → arm extends to hold a tool out
    self._armIKFailed         = false
    self._armIKTarget         = nil   -- transformGroup the hand reaches toward (his "hold it out" point)
    self._armIKRefOff         = nil   -- low-pass-smoothed spine offset relative to graphicsRootNode (kills walk-bob jitter, keeps pose)
    self._armIKCbHandle       = nil   -- addPostAnimationCallback handle: solve the IK after the clip (the winning stage)
    self._armIKTargetPos      = { x = 0.000, y = -1.500, z = 1.050 }  -- BAKED flashlight-carry pose (right, up, forward) meters — low/far target = full arm extension; tune live (vlArmTarget)
    self._armIKTargetRot      = { x = math.rad(15), y = math.rad(-105), z = math.rad(15) } -- BAKED aim: x=yaw, y=wrist roll, z=tilt (vlArmTargetRot)
    self._htFlashlight        = nil   -- the REAL flashlight HandTool, loaded once + attached to his right hand
    self._htCarrier           = nil   -- thin carryingPlayer adapter the handtool system attaches against
    self._htLoading           = false -- async handtool load in flight
    self._htFailed            = false -- handtool load failed once; don't retry every dusk
    self._gripActive          = false -- re-apply posed digits each frame (the anim re-poses the skeleton)
    self._digits              = nil   -- per-digit { bones, angle{x,y,z} } for independent finger/thumb posing
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
                if inConvo then
                    if active then
                        -- R49 FIX-9: SKIP orig() while _active and in conversation. The probe series
                        -- (FIX-1 through FIX-8) eliminated position, params, clip state, and per-frame writes.
                        -- The 10 Hz Hips oscillation (3-frame alternating cycle at 30fps) is the
                        -- ConditionalAnimation inside orig() producing a walk blend at his non-home position.
                        -- Truly-idle Walter doesn't shimmy because he IS at home; the cow pen is not home.
                        -- Skipping orig(): track-0 idle clip drives the body stably. Cost = face freezes
                        -- during conversation; that is preferable to the shimmy.
                        -- _updateWalk handles clip state once on conversation entry (see _convoFrozen).
                        return
                    else
                        -- Truly idle (not _active): orig() runs normally — no shimmy because he's at home.
                        orig(self_pg, dt)
                        if walker._gripActive then walker:_applyHandPose() end
                        return
                    end
                elseif not active then
                    orig(self_pg, dt)
                    if walker._gripActive then walker:_applyHandPose() end
                    return
                end

                -- Active walk (not in conversation): drive facing ourselves; orig stays dormant.
                setRotation(grn, 0, walker._ry, 0)
                if walker._gripActive then walker:_applyHandPose() end
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

-- During a base-game conversation, hand the ConditionalAnimation back to the engine in NPC mode so its
-- TALK animation runs exactly as it does for truly-idle Walter (which never flops). The R49 shimmy probe
-- (2026-06-26, cow pen) proved the flop is PURE SKELETON motion — grn/pin/spot frozen + identical every
-- frame, only the Hips oscillates ~12cm — so it is NOT a position fight (FIX-1/2/3 chased writes that the
-- probe shows were never moving). The ONE difference from the flop-free idle state is that while _active
-- we forced isNPC=false (+ walk-velocity params) via _setAnimParams for direct-drive walking; the base
-- talk blend then runs in player mode and weight-shifts the Hips. Restoring isNPC=true (+ zeroed idle
-- params) makes orig()'s talk blend behave like idle Walter. spot.node is parked on his stopped position
-- (FIX-2), so the isNPC=true position snap lands where he already is = no jump.
function WalterWalker:_setConversationParams()
    local pg = self.grandpa and self.grandpa.playerGraphics
    if pg == nil then return end
    local nameToIdx = pg.animationParameters
    local paramObjs = pg.animation and pg.animation.parameters
    if type(nameToIdx) ~= "table" or type(paramObjs) ~= "table" then return end
    local function set(name, value)
        local idx = nameToIdx[name]
        if idx == nil then return end
        local p = paramObjs[idx]
        if type(p) == "table" then p.value = value end
    end
    set("isNPC",             true)   -- hand position + talk blend back to the engine (NPC mode = no Hips flop)
    set("isGrounded",        true)
    set("isCloseToGround",   true)
    set("isIdling",          true)
    set("isWalking",         false)
    set("isRunning",         false)
    set("absSpeed",          0)
    set("distanceToGround",  0)
    set("relativeVelocityX", 0)
    set("relativeVelocityY", 0)
    set("relativeVelocityZ", 0)
    set("movementDirX",      0)
    set("movementDirZ",      0)
    set("rotationVelocity",  0)
end

-- Test lever (R43): force a specific animation clip index onto track 0 instead of the walk clip,
-- e.g. a chainsaw (tool-holding) walk. Only visible in the active/skip-orig regime (while walking);
-- idle runs orig() which re-poses over track 0. Pass nil to clear.
function WalterWalker:setClipOverride(idx)
    self._clipOverride = idx
    if self._isWalking and self.animCharSet ~= nil then
        local clip = idx or self._walkClipIdx
        if clip and clip >= 0 then
            pcall(function()
                clearAnimTrackClip(self.animCharSet, 0)
                assignAnimTrackClip(self.animCharSet, 0, clip)
                setAnimTrackLoopState(self.animCharSet, 0, true)
                enableAnimTrack(self.animCharSet, 0)
            end)
        end
    end
end

function WalterWalker:_startWalkAnim()
    if self._isWalking then return end
    self._isWalking = true
    self:_setAnimParams(true)
    local clip = self._clipOverride or self._walkClipIdx  -- _clipOverride lets us test a tool-holding clip
    if self.animCharSet ~= nil and clip and clip >= 0 then
        pcall(function()
            clearAnimTrackClip(self.animCharSet, 0)
            assignAnimTrackClip(self.animCharSet, 0, clip)
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
    -- R49 FLOP FIX: do NOT re-write these every frame DURING a conversation. The probe proved the body
    -- container is dead-stable and pin==spot, yet the Hips still flop ~12cm — caused by feeding the base
    -- game his position each frame while it runs the talk animation (its ConditionalAnimation flickers).
    -- Skipping the pin while talking stops that; the spot (below) holds him in place so we don't yank.
    if not grandpa.isInConversation then
        grandpa.x, grandpa.y, grandpa.z = x, y, z
    end

    -- Park the base game's positional SPOT on him — ALWAYS, including during the conversation. With the
    -- spot at his position, the base game positions him there (no movement to animate) instead of pulling
    -- him back to his home spot (which was the FIX-1 vibrate when we dropped the pin without this).
    if grandpa.spot ~= nil and grandpa.spot.node ~= nil and entityExists(grandpa.spot.node) then
        pcall(function() setWorldTranslation(grandpa.spot.node, x, y, z) end)
    end

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
        if type(shed.setGroupIsActive) == "function" then
            -- The proper toggle (what the "press R" activatable calls). Sets the state cleanly so
            -- updateLightState no longer feeds nil to setVisibility (no red console warning).
            pcall(function() shed:setGroupIsActive(g.index, on) end)
        else
            -- Fallback (older builds): manual poke. Emits a harmless setVisibility(nil) warning.
            pcall(function() g.isActive = on end)
            if type(shed.updateLightState) == "function" then pcall(function() shed:updateLightState(g.index or 1) end) end
            if type(shed.lightSetupChanged) == "function" then pcall(function() shed:lightSetupChanged() end) end
        end
    end
    print(string.format("[ValleyLife][Walter] woodshop lights %s", on and "on" or "off"))
    return true
end

-- ───────────────────────── Hand SHAPE / arm pose ─────────────────────────
-- "Hand shapes" in FS25 are <pose> = bone rotations (the base list is sealed in dataS2.gar), so we
-- author our own. Each PART is posed INDEPENDENTLY: rotate its joint(s) about a local axis, re-applied
-- each frame while _gripActive. The 5 digits have 3 joints each. The ARM parts (shoulder/arm/forearm/
-- wrist) extend the hand out front + freezing them counters the walk-swing — BUT the arm is
-- clip-DRIVEN, so per R13 our override may lose to the render-time clip (fingers may be exempt if the
-- clip doesn't keyframe them).
WalterWalker.POSE_PARTS = {
    thumb    = { "RightHandThumb1",  "RightHandThumb2",  "RightHandThumb3"  },
    index    = { "RightHandIndex1",  "RightHandIndex2",  "RightHandIndex3"  },
    middle   = { "RightHandMiddle1", "RightHandMiddle2", "RightHandMiddle3" },
    ring     = { "RightHandRing1",   "RightHandRing2",   "RightHandRing3"   },
    pinky    = { "RightHandPinky1",  "RightHandPinky2",  "RightHandPinky3"  },
    shoulder = { "RightShoulder" },
    arm      = { "RightArm" },      -- upper arm: lift to raise the hand out front
    forearm  = { "RightForeArm" },  -- elbow: bend to bring the flashlight forward
    wrist    = { "RightHand" },     -- the flashlight is linked here, so it follows this bone
}

-- Resolve (and cache) a digit's 3 joints, each with its rest rotation + its OWN accumulated delta
-- (dx/dy/dz) so joints pose independently. d.bones is ordered joint 1 → 2 → 3 (knuckle → tip).
function WalterWalker:_resolveDigit(name)
    self._digits = self._digits or {}
    local d = self._digits[name]
    if d and d.bones then return d end
    local boneNames = WalterWalker.POSE_PARTS[name]
    if boneNames == nil or self.graphicsNode == nil then return nil end
    local bones = {}
    for _, bn in ipairs(boneNames) do
        local n = self:_findNodeByName(self.graphicsNode, bn)
        if n then
            local ox, oy, oz = 0, 0, 0
            pcall(function() ox, oy, oz = getRotation(n) end)
            bones[#bones + 1] = { node = n, ox = ox, oy = oy, oz = oz, dx = 0, dy = 0, dz = 0 }
        end
    end
    if #bones == 0 then return nil end
    self._digits[name] = { bones = bones }
    return self._digits[name]
end

-- Apply a digit: each joint = its rest rotation + its own accumulated delta.
function WalterWalker:_applyDigit(name)
    local d = self._digits and self._digits[name]
    if d == nil then return end
    for _, b in ipairs(d.bones) do
        pcall(function() setRotation(b.node, b.ox + b.dx, b.oy + b.dy, b.oz + b.dz) end)
    end
end

-- Console-driven: nudge a digit. joint = 1|2|3 targets that joint; joint = nil moves all three.
-- axis "reset" zeroes the targeted joint(s) back to rest.
function WalterWalker:nudgeDigit(name, joint, axis, deltaRad)
    local d = self:_resolveDigit(name)
    if d == nil then return nil end
    local targets = (joint and d.bones[joint]) and { d.bones[joint] } or d.bones
    if axis == "reset" then
        for _, b in ipairs(targets) do b.dx, b.dy, b.dz = 0, 0, 0 end
    else
        local key = "d" .. axis  -- dx / dy / dz
        for _, b in ipairs(targets) do b[key] = (b[key] or 0) + deltaRad end
        self._gripActive = true
    end
    self:_applyDigit(name)
    return d
end

-- Re-assert every posed digit each frame (the anim re-poses the skeleton otherwise).
function WalterWalker:_applyHandPose()
    if self._digits == nil then return end
    for name in pairs(self._digits) do self:_applyDigit(name) end
end

-- ───────────────────────── Hand prop: flashlight ─────────────────────────
-- First prop attached to an NPC hand in this project. Loads the BASE-GAME flashlight i3d and links
-- it under the RightHand skeleton bone so it follows the animated hand (player-can ⇒ NPC-can; the
-- bone was confirmed by vlWalterBones). The i3d carries its own spotlight (lightNode); we toggle the
-- model + light together. UNPROVEN engine path — every step is pcall-wrapped + logged. Eyeball the
-- in-hand pose live with vlWalterFlashlightPose, then bake offset/rot into NPCConfig.

function WalterWalker:_findNodeByName(root, name)
    if root == nil or not entityExists(root) then return nil end
    if getName(root) == name then return root end
    for i = 0, getNumOfChildren(root) - 1 do
        local found = self:_findNodeByName(getChildAt(root, i), name)
        if found then return found end
    end
    return nil
end

function WalterWalker:_resolveHandBone(name)
    if self._handBone ~= nil and entityExists(self._handBone) then return self._handBone end
    if self.graphicsNode == nil then return nil end
    self._handBone = self:_findNodeByName(self.graphicsNode, name or "RightHand")
    return self._handBone
end

-- Set visibility on a node AND its whole subtree (root-only setVisibility didn't show the model —
-- the graphics mesh sub-node carried its own hidden flag).
function WalterWalker:_setTreeVisibility(node, on)
    if node == nil or not entityExists(node) then return end
    setVisibility(node, on)
    for i = 0, getNumOfChildren(node) - 1 do
        self:_setTreeVisibility(getChildAt(node, i), on)
    end
end

-- Diagnostic: log the prop subtree (name / visible / local pos) so we can see what loaded and where
-- each piece sits relative to the hand.
function WalterWalker:_dumpFlashlightTree(node, depth)
    if node == nil or not entityExists(node) or depth > 4 then return end
    local vis, x, y, z = nil, 0, 0, 0
    pcall(function() vis = getVisibility(node) end)
    pcall(function() x, y, z = getTranslation(node) end)
    print(string.format("[FlashTree]%s%s vis=%s pos(%.3f,%.3f,%.3f)",
        string.rep("  ", depth), tostring(getName(node)), tostring(vis), x, y, z))
    for i = 0, getNumOfChildren(node) - 1 do
        self:_dumpFlashlightTree(getChildAt(node, i), depth + 1)
    end
end

-- R49 SHIMMY PROBE (toggle with vlShimmy 1). While talking, log his body each frame so we can SEE what
-- moves: the CONTAINER (graphicsRootNode world pos + local ry — if THIS oscillates, WE/the base game are
-- fighting over his position/facing = our bug) vs the HIPS bone (the clip's own weight-shift — if only
-- Hips moves while grn is stable, the shimmy is the base TALK CLIP, not a position fight). Plus our pin
-- (grandpa.x/z) vs the base game's spot (where it wants him). Read [Shimmy] lines in log.txt; strip after.
function WalterWalker:_logShimmy()
    local grn, g = self.graphicsNode, self.grandpa
    if grn == nil or not entityExists(grn) then return end
    if self._shimmyHips == nil then pcall(function() self._shimmyHips = self:_findNodeByName(grn, "Hips") end) end
    local gx, gy, gz, gry, hx, hz, spx, spz = 0, 0, 0, 0, 0, 0, 0, 0
    pcall(function() gx, gy, gz = getWorldTranslation(grn) end)
    pcall(function() local _, ry = getRotation(grn); gry = ry end)
    if self._shimmyHips and entityExists(self._shimmyHips) then
        pcall(function() hx, _, hz = getWorldTranslation(self._shimmyHips) end)
    end
    if g and g.spot and g.spot.node and entityExists(g.spot.node) then
        pcall(function() spx, _, spz = getWorldTranslation(g.spot.node) end)
    end
    local dx, dz = 0, 0
    if self._shimmyLast then dx = gx - self._shimmyLast.x; dz = gz - self._shimmyLast.z end
    self._shimmyLast = { x = gx, z = gz }
    -- Live ConditionalAnimation params (FIX-4 confirm): is the talk blend running in NPC mode (isNPC=true)
    -- or player mode (false)? If isNPC reads false here despite _setConversationParams, orig overwrites
    -- our write each frame → the lever is elsewhere.
    local pNPC, pIdle, pWalk, pSpd = "?", "?", "?", "?"
    local pg = g and g.playerGraphics
    if pg and type(pg.animationParameters) == "table" and pg.animation and type(pg.animation.parameters) == "table" then
        local function getp(name)
            local idx = pg.animationParameters[name]; if idx == nil then return "?" end
            local pp = pg.animation.parameters[idx]
            return (type(pp) == "table") and tostring(pp.value) or "?"
        end
        pNPC, pIdle, pWalk, pSpd = getp("isNPC"), getp("isIdling"), getp("isWalking"), getp("absSpeed")
    end
    print(string.format("[Shimmy] grn(%.3f,%.3f ry%.4f) dGrn(%.4f,%.4f) Hips(%.3f,%.3f) pin(%.3f,%.3f) spot(%.3f,%.3f) active=%s isNPC=%s idle=%s walk=%s spd=%s",
        gx, gz, gry, dx, dz, hx, hz, (g and g.x) or 0, (g and g.z) or 0, spx, spz, tostring(self._active),
        pNPC, pIdle, pWalk, pSpd))
end

-- Resolve an i3dMapping index (e.g. "0>0") to a node under root; nil if unavailable.
function WalterWalker:_i3dIndex(root, s)
    local n = nil
    pcall(function()
        if I3DUtil and I3DUtil.indexToObject then n = I3DUtil.indexToObject(root, s) end
    end)
    if n ~= nil and n ~= 0 and entityExists(n) then return n end
    return nil
end

-- Load the flashlight i3d, trying several loaders/path forms (the bare global loadI3DFile does NOT
-- expand "$data/" — R41 build 00:11). Logs which method wins so we can simplify later. Returns a
-- root node or nil.
function WalterWalker:_loadFlashlightI3D(path)
    local dataRel = path:gsub("^%$data/", "data/")   -- the form the engine logs on its own loads
    local attempts = {}
    if g_i3DManager ~= nil then
        if g_i3DManager.loadI3DFile then
            attempts[#attempts+1] = { "g_i3DManager:loadI3DFile $data",
                function() return g_i3DManager:loadI3DFile(path, false, false, false) end }
            attempts[#attempts+1] = { "g_i3DManager:loadI3DFile data/",
                function() return g_i3DManager:loadI3DFile(dataRel, false, false, false) end }
        end
        if g_i3DManager.loadSharedI3DFile then
            attempts[#attempts+1] = { "g_i3DManager:loadSharedI3DFile $data",
                function() return g_i3DManager:loadSharedI3DFile(path, false, false, false) end }
        end
    end
    attempts[#attempts+1] = { "loadI3DFile data/", function() return loadI3DFile(dataRel, false, false, false) end }

    for _, a in ipairs(attempts) do
        local node = nil
        pcall(function() node = a[2]() end)
        if node ~= nil and node ~= 0 and entityExists(node) then
            print("[ValleyLife][Walter] flashlight loaded via " .. a[1])
            return node
        end
        print("[ValleyLife][Walter] flashlight load failed via " .. a[1])
    end
    return nil
end

-- Lazy-load the flashlight i3d ONCE and link it under the hand bone. Returns true when it's ready.
function WalterWalker:_ensureFlashlight(cfg)
    if self._flashlightNode ~= nil then return true end
    if self._flashlightFailed then return false end
    local fc = cfg and cfg.flashlight
    if fc == nil then return false end
    local hand = self:_resolveHandBone(fc.handBone or "RightHand")
    if hand == nil then return false end  -- skeleton not ready yet; caller retries later

    local root = self:_loadFlashlightI3D(fc.i3d)
    if root == nil then
        self._flashlightFailed = true
        print("[ValleyLife][Walter] flashlight i3d FAILED to load (all methods): " .. tostring(fc.i3d))
        return false
    end

    pcall(function() link(hand, root) end)

    -- Resolve model / spotlight / grip nodes BY NAME. I3DUtil.indexToObject proved unreliable here
    -- (returned nil though the nodes exist — build 00:35); the getChildAt name search always finds them.
    local graphics  = self:_findNodeByName(root, "graphics")  or root
    local lightNode = self:_findNodeByName(root, "lightNode")
    local handNode  = self:_findNodeByName(root, "handNode")

    -- SEAT IT THE WAY THE PLAYER DOES. The tool defines a `handNode` (its grip origin) that the game
    -- aligns to the hand. So place root so handNode lands ON the bone: offset by -handNode.pos and
    -- counter-rotate by -handNode.rot. A non-zero config offset/rot OVERRIDES (manual fine-tune/bake).
    local hp = { x = 0, y = 0, z = 0 }
    local hr = { x = 0, y = 0, z = 0 }
    if handNode then
        pcall(function() hp.x, hp.y, hp.z = getTranslation(handNode) end)
        pcall(function() hr.x, hr.y, hr.z = getRotation(handNode) end)
        print(string.format("[ValleyLife][Walter] flashlight handNode local pos(%.3f,%.3f,%.3f) rot(%.1f,%.1f,%.1f deg)",
            hp.x, hp.y, hp.z, math.deg(hr.x), math.deg(hr.y), math.deg(hr.z)))
    end
    -- ROTATION: the grip orientation from handNode — this got the beam facing forward, so keep it
    -- ALWAYS. POSITION: a non-zero config.offset (set live via vlWalterFlashlightPose) wins; otherwise
    -- start from the handNode-derived seat (-handNode.pos). Position tunes without touching rotation.
    local o, r = fc.offset or {}, fc.rot or {}
    local hasOffset = (o.x or 0) ~= 0 or (o.y or 0) ~= 0 or (o.z or 0) ~= 0
    self._flashlightBaseRot = { x = -hr.x, y = -hr.y, z = -hr.z }  -- auto grip rotation; fc.rot adjusts it
    pcall(function()
        local br = self._flashlightBaseRot
        setRotation(root, br.x + (r.x or 0), br.y + (r.y or 0), br.z + (r.z or 0))
        if hasOffset then
            setTranslation(root, o.x or 0, o.y or 0, o.z or 0)
        else
            setTranslation(root, -hp.x, -hp.y, -hp.z)
        end
    end)

    self._flashlightNode      = root
    self._flashlightGraphics  = graphics
    self._flashlightLightNode = lightNode

    self:_dumpFlashlightTree(root, 0)
    self:_setFlashlight(false)  -- start OFF (visibility applied to the graphics subtree)
    print(string.format("[ValleyLife][Walter] flashlight ready (%s pos): graphics=%s light=%s on %s",
        hasOffset and "config" or "handNode", tostring(graphics), tostring(lightNode), tostring(getName(hand))))
    return true
end

-- Load the REAL flashlight HandTool ONCE (async) and attach it to his RIGHT hand via the game's own
-- holder path (the validated approach). Cached + reused across on/off. Returns true once the tool exists.
function WalterWalker:_ensureRealFlashlight()
    if self._htFlashlight ~= nil then return true end
    if self._htLoading or self._htFailed then return false end
    local g  = self.grandpa
    local pg = g and g.playerGraphics
    if pg == nil or pg.model == nil or HandToolLoadingData == nil then return false end
    local raw      = "$data/handTools/brandless/flashlight/flashlight.xml"
    local resolved = (Utils and Utils.getFilename) and Utils.getFilename(raw, nil) or raw
    if not fileExists(resolved) then self._htFailed = true; return false end
    -- thin carryingPlayer adapter: enough surface for attachToolToHand + the flashlight's updateTransform
    local carrier = { graphicsComponent = pg, isOwner = false, camera = { isFirstPerson = false } }
    function carrier:getIsControlled() return false end
    function carrier:getForceHandToolFirstPerson() return false end
    function carrier:setCurrentHandTool() end
    self._htCarrier = carrier
    self._htLoading = true
    local data = HandToolLoadingData.new()
    data:setFilename(resolved)
    pcall(function() data:setOwnerFarmId(g.ownerFarmId or 1) end)
    data:setIsRegistered(false)
    data:load(function(_, handTool, loadingState)
        self._htLoading = false
        if handTool == nil then
            self._htFailed = true
            print("[ValleyLife][Walter] real flashlight handtool load FAILED: " .. tostring(loadingState)); return
        end
        self._htFlashlight   = handTool
        handTool.useLeftHand = false                                  -- authored grip = right hand
        pcall(function() handTool:setCarryingPlayer(self._htCarrier) end)
        handTool.isHeld = true
        pcall(function() handTool:attachToolToHand() end)
        self:_applyRealFlashlight(self._flashlightOn == true)          -- apply state (may have toggled during load)
        print("[ValleyLife][Walter] real flashlight handtool ready (right hand)")
    end, self)
    return false
end

-- Show/hide the loaded handtool subtree + toggle its light.
function WalterWalker:_applyRealFlashlight(on)
    local ht = self._htFlashlight
    if ht == nil or ht.rootNode == nil or not entityExists(ht.rootNode) then return end
    pcall(function() self:_setTreeVisibility(ht.rootNode, on) end)
    pcall(function() ht:setFlashlightIsActive(on, true) end)
end

-- Flashlight ON/OFF (driven by the dusk schedule via _updateFlashlight). Uses the REAL handtool in his
-- right hand + extends his right arm (rightArm IK) to hold it out — the validated multiplayer-style hold.
function WalterWalker:_setFlashlight(on)
    self._flashlightOn = on
    if on then self:_ensureRealFlashlight() end   -- async first time; _applyRealFlashlight runs on load
    self:_applyRealFlashlight(on)                 -- show/hide + light (no-op until loaded)
    self:setArmIK(on)                             -- extend/retract the arm to hold the flashlight out
    return true
end

-- Switch the flashlight to the other hand (e.g. LeftHand to pair with chainsaw_walk). Drops the
-- loaded prop so it re-loads + re-seats (handNode auto-seat) on the new bone. Offset is per-hand —
-- re-tune with vlFlash after switching. Returns true if it (re)attached.
function WalterWalker:setFlashlightHand(boneName)
    local fc = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.flashlight
    if fc == nil then return false end
    fc.handBone = boneName
    self._handBone = nil  -- force re-resolve of the hand bone
    if self._flashlightNode ~= nil then
        pcall(function() if entityExists(self._flashlightNode) then delete(self._flashlightNode) end end)
        self._flashlightNode      = nil
        self._flashlightGraphics  = nil
        self._flashlightLightNode = nil
        self._flashlightOn        = false
        self._flashlightFailed    = false
    end
    return self:_setFlashlight(true)  -- reload + seat on the new hand, turned on
end

-- Re-apply the flashlight's local rotation = auto grip rotation + fc.rot adjustment (vlFlashRot). The
-- prop is a child we control (not a clip-driven bone), so setting it once holds — no per-frame redo.
function WalterWalker:_applyFlashlightRot()
    if self._flashlightNode == nil or self._flashlightBaseRot == nil then return end
    local fc = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.flashlight
    local r  = (fc and fc.rot) or {}
    local br = self._flashlightBaseRot
    pcall(function()
        setRotation(self._flashlightNode, br.x + (r.x or 0), br.y + (r.y or 0), br.z + (r.z or 0))
    end)
end

function WalterWalker:_duskHour(cfg)
    local season = (TimeHelper.getSeason and TimeHelper.getSeason()) or "summer"
    local t = (cfg and cfg.flashlightDusk) or {}
    return t[season] or 19
end

-- While the flashlight is OUT, carry it with the steady tool-holding walk clip (cfg.flashlightWalkClip,
-- e.g. chainsaw_walkSource: both hands forward, no arm swing) so his LEFT hand holds the light forward.
-- Off → clear the override, back to the normal walk. Only visible while actively walking (idle runs
-- orig() over track 0); reuses the R43 clip-swap lever via setClipOverride — no bone posing. Set the
-- config knob to nil/"" to keep the open-hand swing.
function WalterWalker:_applyFlashlightWalkClip(on)
    local name = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.flashlightWalkClip
    if name == nil or name == "" then return end
    if on then
        if self._flashlightClipIdx == nil or self._flashlightClipIdx < 0 then
            self._flashlightClipIdx = (findClip(self.animCharSet, { name }))  -- parens: take the index only
        end
        if self._flashlightClipIdx and self._flashlightClipIdx >= 0 then
            self:setClipOverride(self._flashlightClipIdx)
        end
    else
        self:setClipOverride(nil)
    end
end

-- On while he's OUT WALKING (active route) and visible, after the seasonal dusk hour. A console force
-- (vlWalterFlashlight 1/0) overrides; vlWalterFlashlight auto clears it.
function WalterWalker:_updateFlashlight(cfg, hour)
    if cfg.flashlight == nil then return end
    local want = self._active and (not self._hidden) and (hour >= self:_duskHour(cfg))
    if self._flashlightForce ~= nil then want = self._flashlightForce end
    if want ~= self._flashlightOn then self:_setFlashlight(want) end  -- _setFlashlight also swaps the carry clip
end

-- ───────────────────── rightArm IK: extend his arm to hold a tool out ─────────────────────
-- The MP "arm reaches out to hold the flashlight" is the rightArm IK CHAIN (C-backed solver), which the
-- engine STRIPS from NPCs (model.ikChains is empty on Walter). We load the base-game chain (bundled
-- src/ik/rightArmChain.xml, copied from playerM.xml) onto his model.ikChains and drive it. node indices
-- are relative to the model skeleton root (same playerM rig). OPEN RISK: the R42 wall — if the walk/idle
-- clip re-poses the arm at render, the IK loses; the C solver MAY compose where setRotation lost (untested).
function WalterWalker:_ensureArmIK()
    if self._armIKLoaded then return true end
    if self._armIKFailed then return false end
    local model = self.grandpa and self.grandpa.playerGraphics and self.grandpa.playerGraphics.model
    if model == nil or model.ikChains == nil then return false end
    -- The ikChain node indices are relative to the i3d ROOT (one level ABOVE the skeleton "0>" node) —
    -- the chain's hand index has one more leading "0" than playerM.xml's rightHandNode mapping. So the
    -- base = the skeleton node's PARENT (passing the skeleton itself bound the chain into the face).
    local skel = (model.getSkeletonNode and model:getSkeletonNode()) or model.skeleton
    local base = (skel ~= nil and getParent(skel)) or skel
    if base == nil or not entityExists(base) then self._armIKFailed = true; return false end

    local path   = (g_valleyLifeModDir or "") .. "src/ik/rightArmChain.xml"
    local handle = loadXMLFile("vlRightArmIK", path)
    if handle == nil or handle == 0 then
        print("[ValleyLife][ArmIK] FAILED to load chain xml: " .. tostring(path)); self._armIKFailed = true; return false
    end
    local ok = pcall(function()
        IKUtil.loadIKChain(handle, "player.ikChains.ikChain(0)", base, base, model.ikChains)
    end)
    pcall(function() delete(handle) end)
    local chain = model.ikChains.rightArm
    if not ok or chain == nil then
        print("[ValleyLife][ArmIK] loadIKChain FAILED ok=" .. tostring(ok) .. " chain=" .. tostring(chain))
        self._armIKFailed = true; return false
    end
    -- Base-node sanity: log the bones the chain bound to (should be RightArm / RightForeArm / RightHand).
    local names = {}
    for i, n in ipairs(chain.nodes or {}) do
        names[i] = (n.node and entityExists(n.node)) and (getName(n.node) or "?") or "nil"
    end
    print(string.format("[ValleyLife][ArmIK] chain loaded; base=%s(%s) nodes=%s",
        tostring(base), tostring(getName(base)), table.concat(names, " / ")))

    -- Keep alignToTarget ON, but we orient the target to AIM ahead (setDirection in _applyArmTarget) so
    -- the hand/flashlight point forward. (alignToTarget=false gave a natural wrist but the flashlight then
    -- pointed up; aiming the target the right way gives forward-point without the earlier Euler twist.)
    chain.alignToTarget = true

    -- Target the hand reaches toward: a WORLD-space node (parented to root) repositioned each frame from
    -- his torso + facing, so the offset reads as (right, up, forward) regardless of bone axes.
    local target = createTransformGroup("vlArmIKTarget")
    link(getRootNode(), target)
    self._armIKTarget = target
    self:_applyArmTarget()
    self._armIKLoaded = true
    return true
end

-- Place the IK target in WORLD space: spine position + (right, up, forward) using his facing. Recomputed
-- each frame so it tracks his turn. alignToTarget then orients the hand to the target's rotation.
function WalterWalker:_applyArmTarget()
    local t = self._armIKTarget
    if t == nil or not entityExists(t) then return end
    local pg    = self.grandpa and self.grandpa.playerGraphics
    local model = pg and pg.model
    local grn   = pg and pg.graphicsRootNode
    local ref = model and (model.thirdPersonSpineNode or model.skeleton)
    if model == nil or grn == nil or ref == nil or not entityExists(ref) or not entityExists(grn) then return end
    -- Pose is dialed against the SPINE position, but the spine BOBS with the walk clip → jitter. Reconstruct
    -- it as grn (stable container, glides along the path = no bob, no forward-motion lag) + the spine's full
    -- offset relative to grn, LOW-PASS smoothed (the bob lives in that offset). Keeps the pose, kills the jump.
    local gx, gy, gz   = getWorldTranslation(grn)
    local spx, spy, spz = getWorldTranslation(ref)
    local offX, offY, offZ = spx - gx, spy - gy, spz - gz
    local s = self._armIKRefOff
    if s == nil then s = { x = offX, y = offY, z = offZ }; self._armIKRefOff = s end
    local a = 0.12
    s.x = s.x + (offX - s.x) * a; s.y = s.y + (offY - s.y) * a; s.z = s.z + (offZ - s.z) * a
    local sx, sy, sz   = gx + s.x, gy + s.y, gz + s.z
    local fx, fy, fz   = localDirectionToWorld(grn, 0, 0, 1)    -- forward (his model faces +Z — verified: -Z put the arm behind him)
    local rx, ry2, rz  = localDirectionToWorld(grn, -1, 0, 0)   -- his right (+X put the hand across his body)
    local p = self._armIKTargetPos                              -- (x=right, y=up, z=forward)
    setWorldTranslation(t, sx + rx*p.x + fx*p.z, sy + p.y + fy*p.z, sz + rz*p.x + fz*p.z)
    -- Aim the hand/flashlight AHEAD: orient the target's forward along his facing, tilted down a touch.
    -- alignToTarget then rotates the hand to match → the beam points where he's walking.
    local r   = self._armIKTargetRot
    local afx, afy, afz = localDirectionToWorld(grn, r.x, -0.20 + r.z, 1)               -- forward (+slight down); r.x=yaw, r.z=tilt
    local aux, auy, auz = localDirectionToWorld(grn, math.sin(r.y), math.cos(r.y), 0)   -- up rolled around forward by r.y → wrist roll (vlArmTargetRot y)
    setDirection(t, afx, afy, afz, aux, auy, auz)
    local ik = model.ikChains
    if ik then IKUtil.setIKChainDirty(ik, "rightArm") end
end

-- Live-nudge the IK target: position (5cm/tap) or rotation (15deg/tap). dir = x+/x-/y+/y-/z+/z- (or 0 to
-- reset rotation). Dial the arm to hold the flashlight out front, then bake _armIKTargetPos/_armIKTargetRot.
function WalterWalker:nudgeArmTarget(dir, isRot)
    local step = isRot and math.rad(15) or 0.05
    local tbl  = isRot and self._armIKTargetRot or self._armIKTargetPos
    dir = string.lower(tostring(dir or ""))
    if     dir == "x+" then tbl.x = tbl.x + step
    elseif dir == "x-" then tbl.x = tbl.x - step
    elseif dir == "y+" then tbl.y = tbl.y + step
    elseif dir == "y-" then tbl.y = tbl.y - step
    elseif dir == "z+" then tbl.z = tbl.z + step
    elseif dir == "z-" then tbl.z = tbl.z - step
    elseif dir == "0"  then tbl.x, tbl.y, tbl.z = 0, 0, 0
    else return nil end
    self:_applyArmTarget()
    return tbl
end

function WalterWalker:setArmIK(on)
    if on then
        if not self:_ensureArmIK() then return false end
        local ik = self.grandpa.playerGraphics.model.ikChains
        IKUtil.setIKChainActive(ik, "rightArm")
        IKUtil.setTarget(ik, "rightArm", { targetNode = self._armIKTarget, poseId = "narrowFingers" })
        -- Solve the chain in a POST-ANIMATION callback = the engine's after-clip / pre-render stage
        -- (the facial system writes the head node there and it persists). Solving in the normal update
        -- ran BEFORE the clip eval and lost (R42); this stage is where bone writes WIN.
        if self._armIKCbHandle == nil and addPostAnimationCallback ~= nil then
            self._armIKCbHandle = addPostAnimationCallback(WalterWalker._armIKPostAnim, self, nil)
            print("[ValleyLife][ArmIK] post-animation callback registered: " .. tostring(self._armIKCbHandle))
        elseif addPostAnimationCallback == nil then
            print("[ValleyLife][ArmIK] addPostAnimationCallback global MISSING — cannot reach the post-anim stage")
        end
        self._armIKActive = true
    else
        if self._armIKCbHandle ~= nil then
            pcall(function() removePostAnimationCallback(self._armIKCbHandle) end)
            self._armIKCbHandle = nil
        end
        local model = self.grandpa and self.grandpa.playerGraphics and self.grandpa.playerGraphics.model
        if model and model.ikChains and model.ikChains.rightArm then
            IKUtil.setTarget(model.ikChains, "rightArm", nil)
            IKUtil.setIKChainInactive(model.ikChains, "rightArm")
        end
        self._armIKActive = false
    end
    return true
end

-- POST-ANIMATION callback (engine after-clip / pre-render stage). Solving the IK HERE beats the clip,
-- where solving in the normal update lost to it (R42). Signature: called as (self, dt) by the engine.
function WalterWalker:_armIKPostAnim(dt)
    if not self._armIKActive then return end
    local model = self.grandpa and self.grandpa.playerGraphics and self.grandpa.playerGraphics.model
    if model == nil or model.ikChains == nil then return end
    self:_applyArmTarget()   -- reposition the target to his current torso + facing (also re-dirties the chain)
    IKUtil.updateIKChains(model.ikChains, false)
end

-- Close ONLY our own ambient greeting popup. Tag-guarded (opts.tag="ambientGreet") so we never close a
-- heart-event or other dialog that happens to be on screen.
function WalterWalker:_closeGreet()
    if not self._greetActive then return end
    local dlg = g_valleyLife and g_valleyLife.dialog
    if dlg and dlg.speech and dlg.speech.tag == "ambientGreet" then
        dlg:closeSpeech()
    end
    self._greetActive = false
end

-- True when WALTER himself is standing at the cow pen (e.g. paused there on his checkingCows route), so
-- his greeting switches to cow-context lines when you come up to him. Pen center + range from config.
function WalterWalker:_nearCowPen()
    if self._wx == nil then return false end
    local pen = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.cowPen
    if pen == nil then return false end
    local dx, dz = self._wx - pen.x, self._wz - pen.z
    return (dx * dx + dz * dz) <= ((pen.range or 18.0) ^ 2)
end

-- Ambient greeting: when the player approaches (entering greetRange), Walter speaks a time-of-day
-- line as a popup that STAYS until you dismiss it (Enter/click) or walk out of greetRange — or auto-
-- dismisses after greetTtl seconds if that knob is set. ADDITIVE — his base-game "press to talk" conversation is left
-- fully intact. Edge-triggered + cooldown so it never spams; suppressed during a conversation, while
-- he's inside (hidden), or when a mod speech / heart event is already on screen.
function WalterWalker:_maybeGreet(dt)
    if self._greetCooldown and self._greetCooldown > 0 then
        self._greetCooldown = self._greetCooldown - dt
    end
    local grandpa = self.grandpa
    if grandpa == nil or self.graphicsNode == nil or not entityExists(self.graphicsNode) then return end
    if self._hidden or grandpa.isInConversation then self:_closeGreet(); self._greetNear = false; return end

    local px, _, pz = playerWorldPos()
    if px == nil then self._greetNear = false; return end
    local gx, _, gz = getWorldTranslation(self.graphicsNode)
    local range = (VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.greetRange) or 5
    local near  = ((px - gx)^2 + (pz - gz)^2) <= (range * range)

    if near and not self._greetNear and (self._greetCooldown or 0) <= 0 then
        local vl  = g_valleyLife
        local dlg = vl and vl.dialog
        local busy = (dlg and dlg.speech ~= nil) or (vl and vl.sequencer and vl.sequencer.active)
        if dlg and not busy and vl.casualDialogue then
            -- While out for the occasional night woodshop visit, address it directly ("couldn't
            -- sleep") instead of the generic night line; fall back to the time-of-day line.
            local line = nil
            if self:_nearCowPen() then
                line = vl.casualDialogue:pickNamedPool("grandpa", "cows")  -- contextual: he's out at the herd
            end
            if line == nil and self._nightShopActive then
                line = vl.casualDialogue:pickNamedPool("grandpa", "nightWoodshop")
            end
            if line == nil then
                line = vl.casualDialogue:pickTimeOfDayLine("grandpa")
            end
            if line then
                local gttl = VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.greetTtl  -- nil = persist until dismissed / walk-away
                dlg:showSpeechBox("Walter", line, nil, { tag = "ambientGreet", ttl = gttl })
                self._greetActive = true
                self._greetCooldown = (VLConfig.WALTER_WALK and VLConfig.WALTER_WALK.greetCooldownMs) or 20000
            end
        end
    end
    if self._greetNear and not near then self:_closeGreet() end  -- walked out of range → dismiss our greeting
    self._greetNear = near
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

-- Deterministic pseudo-random in [0,1) from an integer (the calendar day). Lets the "occasional"
-- night visit decide ONCE per night and STAY decided across a save/reload, instead of rerolling
-- every frame. Simple integer hash; no global randomseed side effect.
function WalterWalker._nightRoll(n)
    local x = ((n or 0) * 1103515245 + 12345) % 2147483648
    return x / 2147483648
end

-- Occasional night visit: he couldn't sleep, so he slips out the door and walks to the woodshop
-- (lights glowing in the dark), works a while, then comes back and steps inside again. Mirror of
-- _startMorningDeparture: reveal him AT the door (wp[1]), face down the steps, run the nightWoodshop
-- loop (which ends by hiding at the door). _nightShopActive flags the "couldn't sleep" ambient quip.
function WalterWalker:_startNightWoodshop(cfg)
    local loop = cfg and WorkLoopHelper.findByName(cfg.loops, "nightWoodshop")
    if loop == nil or not self:_loopRunnable(loop) then return false end
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
    self:_reveal()
    self:_beginLoop(loop)         -- clears _nightShopActive...
    self._nightShopActive = true  -- ...so set it AFTER _beginLoop
    self:_syncFollowers()
    print("[ValleyLife][Walter] couldn't sleep — heading out to the woodshop")
    return true
end

function WalterWalker:_beginLoop(loop)
    if self._hidden then self:_reveal() end  -- a loop start always brings him back outside
    self._nightShopActive = false            -- cleared by default; _startNightWoodshop re-sets it after this
    self._loop   = loop
    self.walk    = { state = "walking", targetIdx = 2 }  -- wp[1] is home; head out first
    self._active = true
    print(string.format("[ValleyLife][Walter] loop '%s' started", loop.name or "?"))
end

function WalterWalker:_endLoop(cfg)
    self:_stopWalkAnim()
    self._active = false
    self._nightShopActive = false
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

    -- R49 shimmy diagnostic: log his body each frame while talking (vlShimmy 1). Read-only.
    if self._shimmyProbe and self.grandpa and self.grandpa.isInConversation then self:_logShimmy() end

    local cfg = VLConfig.WALTER_WALK
    if type(cfg) ~= "table" or type(cfg.loops) ~= "table" then return end
    if self._yOffset    == nil then self._yOffset   = cfg.yOffset   or 0    end
    if self._stairLift  == nil then self._stairLift = cfg.stairLift or 0.15 end

    -- Ambient time-of-day greeting on approach (whether he's walking or idle). Base convo untouched.
    self:_maybeGreet(dt)

    -- Flashlight: on while he's out walking after the seasonal dusk hour. Runs whether active or idle
    -- so it switches off the moment he settles at home or steps inside.
    local hour = TimeHelper.getHour()
    self:_updateFlashlight(cfg, hour)

    -- Re-assert posed digits each frame (the anim clip may re-pose the fingers otherwise).
    if self._gripActive then self:_applyHandPose() end

    if self._active then
        self:_updateWalk(cfg, dt)
        return
    end

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

    -- Occasional NIGHT WOODSHOP visit: some nights he can't sleep and slips out to the lit shed.
    -- Only while he's hidden (asleep inside), after nightWoodshopHour, edge-triggered once per night
    -- via its own day marker, with a deterministic per-night chance so it's occasional but never
    -- rerolls per frame or on reload. Ends by stepping back inside (hideOnEnd) — re-hidden for the night.
    if self._hidden and hour >= (cfg.nightWoodshopHour or 22) then
        local nightDay = TimeHelper.getMonotonicDay() or 0
        if nightDay ~= self._nightShopDay then
            self._nightShopDay = nightDay
            if WalterWalker._nightRoll(nightDay) < (cfg.nightWoodshopChance or 0.4) then
                self:_startNightWoodshop(cfg); return
            end
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

    -- R49 SHIMMY FIX-5 (probe-driven, cow pen): replicate truly-idle Walter, who NEVER flops while talking.
    -- The probes eliminated, in order: position (grn/pin/spot FROZEN), track-0 clip state (FIX-1: enabled
    -- AND disabled both flop), and ConditionalAnimation params (FIX-4: isNPC=true/idle identical to idle,
    -- still flops). The ONLY remaining difference from the flop-free idle-convo is that we ran
    -- _syncFollowers() EVERY frame during the talk (per-frame setWorldTranslation on spot.node + the trigger
    -- node — same value, but re-written each frame while the base talk anim evaluates). So during a
    -- conversation do EVERYTHING ONCE on entry, then NOTHING per frame: clear the walk clip, disable
    -- track 0 (orig owns the skeleton for the talk), restore NPC-mode params, and park the followers a
    -- SINGLE time (the spot park is load-bearing — it stops the g_npcManager home-yank vibrate — but it
    -- doesn't need re-writing every frame). Resets on conversation end; the route resumes below.
    if self.grandpa.isInConversation then
        if not self._convoFrozen then
            self._convoFrozen = true
            -- R49 FIX-9: orig() is SKIPPED in the wrapper while _active+inConvo. That means track-0 is
            -- NOT cleared/disabled by the wrapper. _stopWalkAnim here restores the idle clip on track 0 so
            -- it drives the body stably (no ConditionalAnimation, no shimmy). _setAnimParams keeps params
            -- consistent with direct-drive (isNPC=false). _syncFollowers parks spot.node / trigger once.
            self:_stopWalkAnim()     -- reverts to idle clip; no-op if already paused
            self:_setAnimParams(false) -- isNPC=false, idle params
            self:_syncFollowers()    -- ONE-TIME park of spot.node / trigger / hotspot onto his stopped position
        end
        return
    end
    if self._convoFrozen then
        -- Conversation ended: reset so _startWalkAnim re-assigns the walk clip cleanly.
        self._convoFrozen = false
        self._isWalking = false
    end

    -- Keep his map point + interaction trigger on him every active frame (R21). NOTE: the spot park inside
    -- here is LOAD-BEARING — without it the base game yanks grandpa.x/z back to his home spot. During a
    -- conversation it runs only ONCE (above) so the per-frame writes don't perturb the talk animation.
    self:_syncFollowers()

    -- Stop & face the player when he's near (not talking), and hold there. His trigger is now
    -- stationary, so walking up to him fires the normal base-game talk prompt + conversation.
    local approach   = cfg.approachRange or 6.0
    local px, _, pz  = playerWorldPos()
    local playerNear = false
    -- noStopForPlayer routes (e.g. cowHandoff, where Walter is LEADING the player somewhere) keep walking
    -- even as the player follows closely — otherwise he'd halt every step and never arrive.
    if px ~= nil and not loop.noStopForPlayer then
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
    -- Drop the flashlight prop we loaded + linked to his hand.
    if self._flashlightNode ~= nil then
        pcall(function() if entityExists(self._flashlightNode) then delete(self._flashlightNode) end end)
        self._flashlightNode      = nil
        self._flashlightLightNode = nil
        self._handBone            = nil
    end
    self:_stopWalkAnim()
    self.grandpa      = nil
    self.graphicsNode = nil
    self.animCharSet  = nil
    self.walk         = nil
    self._loop        = nil
    self._active      = false
end
