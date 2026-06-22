TimeHelper = {}

local function getEnvironment()
    if not g_currentMission or not g_currentMission.environment then return nil end
    return g_currentMission.environment
end

function TimeHelper.getHour()
    local env = getEnvironment()
    if not env then return 12 end
    return env.dayTime / 3600000
end

-- FS25's environment counts in "periods" (1-12) where period 1 = March, NOT
-- calendar months. (env.currentMonth does not exist - reading it returns nil,
-- which previously defaulted the month to 1 and pinned every save to winter.)
-- Convert period -> real calendar month so season + holiday logic line up.
function TimeHelper.getSeason()
    local month = TimeHelper.getCalendarMonth()
    if month >= 3 and month <= 5 then return "spring"
    elseif month >= 6 and month <= 8 then return "summer"
    elseif month >= 9 and month <= 11 then return "autumn"
    else return "winter"
    end
end

-- 0 = Sunday, 1 = Monday, … 6 = Saturday.
-- Uses currentMonotonicDay (total days since save start, 1-based) so day 1 of
-- any save is always Monday, regardless of starting period or daysPerPeriod.
-- Falls back to the calendar formula only when currentMonotonicDay is unavailable.
function TimeHelper.getWeekday()
    local env = getEnvironment()
    if not env then return 1 end
    local mday = env.currentMonotonicDay
    if type(mday) == "number" and mday >= 1 then
        return mday % 7
    end
    local month = TimeHelper.getCalendarMonth()
    local dayOfMonth = TimeHelper.getCalendarDayOfMonth()
    local daysPerPeriod = env.daysPerPeriod or 28
    return ((month - 1) * daysPerPeriod + dayOfMonth) % 7
end

-- Total days since save start (1-based). Stable per-day key for once-a-day events.
-- Returns nil if the engine field is unavailable (caller decides the fallback).
function TimeHelper.getMonotonicDay()
    local env = getEnvironment()
    if not env then return nil end
    local mday = env.currentMonotonicDay
    if type(mday) == "number" and mday >= 1 then return mday end
    return nil
end

function TimeHelper.isWeekend()
    local wd = TimeHelper.getWeekday()
    return wd == 0 or wd == 6
end

-- Real calendar month (1-12) from FS25's period (1-12, period 1 = March).
-- period 1 -> 3 (March); period 11 -> 1 (Jan); period 12 -> 2 (Feb).
function TimeHelper.getCalendarMonth()
    local env = getEnvironment()
    if not env then return 1 end
    local period = env.currentPeriod or 1
    return ((period + 1) % 12) + 1
end

function TimeHelper.getCalendarDayOfMonth()
    local env = getEnvironment()
    if not env then return 1 end
    if type(env.currentDayInPeriod) == "number" then return env.currentDayInPeriod end
    if type(env.getDayInPeriodFromDay) == "function" and env.currentMonotonicDay ~= nil then
        local ok, day = pcall(env.getDayInPeriodFromDay, env, env.currentMonotonicDay)
        if ok and type(day) == "number" then return day end
    end
    return env.currentDay or 1
end

local function isFloatingHoliday(month, day, weekday, daysPerPeriod)
    -- Memorial Day: last Monday in May.
    if month == 5 and weekday == 1 and day > daysPerPeriod - 7 then return true end
    -- Labor Day: first Monday in September.
    if month == 9 and weekday == 1 and day <= 7 then return true end
    -- Thanksgiving: last Thursday in November (= 4th Thursday when daysPerPeriod >= 28).
    if month == 11 and weekday == 4 and day > daysPerPeriod - 7 then return true end
    return false
end

function TimeHelper.isHoliday()
    local env = getEnvironment()
    local month = TimeHelper.getCalendarMonth()
    local day = TimeHelper.getCalendarDayOfMonth()
    local weekday = TimeHelper.getWeekday()
    local daysPerPeriod = (env and env.daysPerPeriod) or 28
    if isFloatingHoliday(month, day, weekday, daysPerPeriod) then return true end
    local holidays = VLConfig and VLConfig.OUTFIT_HOLIDAYS
    if type(holidays) ~= "table" then return false end
    for _, entry in ipairs(holidays) do
        if entry.month == month and entry.day == day then return true end
    end
    return false
end

function TimeHelper.isWorkHours()
    local startH = VLConfig and VLConfig.OUTFIT_WORK_START_HOUR or 5.5
    local endH = VLConfig and VLConfig.OUTFIT_WORK_END_HOUR or 16.5
    local h = TimeHelper.getHour()
    return h >= startH and h < endH
end

-- Returns "work" or "leisure" for NPC outfit selection.
function TimeHelper.getOutfitMode()
    if TimeHelper.isWeekend() or TimeHelper.isHoliday() then
        return "leisure"
    end
    if TimeHelper.isWorkHours() then
        return "work"
    end
    return "leisure"
end

function TimeHelper.getOutfitModeReason()
    if TimeHelper.isWeekend() then return "weekend" end
    if TimeHelper.isHoliday() then return "holiday" end
    if TimeHelper.isWorkHours() then return "work hours" end
    return "after work hours"
end

function TimeHelper.isNight()
    local h = TimeHelper.getHour()
    return h < 6 or h >= 22
end

function TimeHelper.hoursBetween(h1, h2)
    if h2 >= h1 then return h2 - h1 end
    return (24 - h1) + h2
end
