BirthdayHelper = {}

local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

local function hashNpcId(npcId)
    local h = 0
    if type(npcId) ~= "string" then return 0 end
    for i = 1, #npcId do
        h = h + string.byte(npcId, i) * i
    end
    return h
end

-- Deterministic pseudo-random birthday per npc id (stable across saves).
function BirthdayHelper.fromNpcId(npcId)
    local seed = hashNpcId(npcId)
    local month = (seed % 12) + 1
    local maxDay = DAYS_IN_MONTH[month] or 28
    local day = (seed % maxDay) + 1
    return { month = month, day = day }
end

function BirthdayHelper.isValid(birthday)
    if type(birthday) ~= "table" then return false end
    local month = birthday.month
    local day = birthday.day
    if type(month) ~= "number" or type(day) ~= "number" then return false end
    if month < 1 or month > 12 then return false end
    local maxDay = DAYS_IN_MONTH[month] or 28
    return day >= 1 and day <= maxDay
end

function BirthdayHelper.isToday(birthday)
    if not BirthdayHelper.isValid(birthday) then return false end
    return birthday.month == TimeHelper.getCalendarMonth()
        and birthday.day == TimeHelper.getCalendarDayOfMonth()
end

function BirthdayHelper.format(birthday)
    if not BirthdayHelper.isValid(birthday) then return "?" end
    local name = MONTH_NAMES[birthday.month] or tostring(birthday.month)
    return string.format("%s %d", name, birthday.day)
end
