TimeHelper = {}

function TimeHelper.getHour()
    if not g_currentMission or not g_currentMission.environment then return 12 end
    return g_currentMission.environment.dayTime / 3600000
end

function TimeHelper.getDay()
    if not g_currentMission or not g_currentMission.environment then return 1 end
    return g_currentMission.environment.currentDay
end

function TimeHelper.getSeason()
    if not g_currentMission or not g_currentMission.environment then return "spring" end
    local month = g_currentMission.environment.currentMonth
    if month >= 3 and month <= 5 then return "spring"
    elseif month >= 6 and month <= 8 then return "summer"
    elseif month >= 9 and month <= 11 then return "autumn"
    else return "winter"
    end
end

function TimeHelper.isNight()
    local h = TimeHelper.getHour()
    return h < 6 or h >= 22
end

function TimeHelper.hoursBetween(h1, h2)
    if h2 >= h1 then return h2 - h1 end
    return (24 - h1) + h2
end
