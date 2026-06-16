-- Tracks calendar state and detects when NPC outfits should refresh (season or work/leisure).

OutfitCalendar = {}
OutfitCalendar.__index = OutfitCalendar

function OutfitCalendar.new()
    return setmetatable({
        season = nil,
        month = nil,
        day = nil,
        mode = nil,
        _ready = false,
    }, OutfitCalendar)
end

-- Snapshot current game calendar without reporting a transition (use after spawn).
function OutfitCalendar:sync()
    self.season = TimeHelper.getSeason()
    self.month = TimeHelper.getCalendarMonth()
    self.day = TimeHelper.getDay()
    self.mode = TimeHelper.getOutfitMode()
    self._ready = true
end

-- Returns transition flags when season or outfit mode changes.
function OutfitCalendar:poll()
    local season = TimeHelper.getSeason()
    local month = TimeHelper.getCalendarMonth()
    local day = TimeHelper.getDay()
    local mode = TimeHelper.getOutfitMode()

    local seasonChanged = self._ready and (season ~= self.season or month ~= self.month)
    local modeChanged = self._ready and mode ~= self.mode
    local dayChanged = self._ready and day ~= self.day

    self.season = season
    self.month = month
    self.day = day
    self.mode = mode
    self._ready = true

    return {
        seasonChanged = seasonChanged,
        modeChanged = modeChanged,
        dayChanged = dayChanged,
        season = season,
        month = month,
        mode = mode,
        reason = TimeHelper.getOutfitModeReason(),
    }
end
