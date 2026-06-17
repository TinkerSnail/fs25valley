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

function TimeHelper.getDay()
    local env = getEnvironment()
    if not env then return 1 end
    return env.currentDay or env.currentMonotonicDay or 1
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

-- 0 = Sunday, 1 = Monday, … 6 = Saturday (matches FS25_NPCFavor convention).
function TimeHelper.getWeekday()
    return TimeHelper.getDay() % 7
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

local function isFloatingHoliday(month, day, weekday)
    -- Memorial Day: last Monday in May.
    if month == 5 and weekday == 1 and day >= 25 then return true end
    -- Labor Day: first Monday in September.
    if month == 9 and weekday == 1 and day <= 7 then return true end
    -- Thanksgiving: fourth Thursday in November.
    if month == 11 and weekday == 4 and day >= 22 and day <= 28 then return true end
    return false
end

function TimeHelper.isHoliday()
    local month = TimeHelper.getCalendarMonth()
    local day = TimeHelper.getCalendarDayOfMonth()
    local weekday = TimeHelper.getWeekday()
    if isFloatingHoliday(month, day, weekday) then return true end
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
