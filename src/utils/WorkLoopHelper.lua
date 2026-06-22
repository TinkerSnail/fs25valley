-- WorkLoopHelper: shared work-loop selection so every villager resolves loops
-- the SAME way. Marta (VLNPCEntity), Walter (WalterWalker), and the vlWalk console
-- command all call through here, so the named/callable convention can't drift
-- between them.
--
-- A "loops" value is an ORDERED array of loop tables, each optionally carrying
-- name / startHour / endHour fields. Order matters: hour-selection returns the
-- first loop whose window matches, so list loops in a sensible time order.

WorkLoopHelper = {}

-- The loop whose [startHour, endHour) window contains `hour`. Returns loop, index.
function WorkLoopHelper.getActiveLoop(loops, hour)
    if type(loops) ~= "table" then return nil end
    for i, loop in ipairs(loops) do
        if hour >= (loop.startHour or 0) and hour < (loop.endHour or 24) then
            return loop, i
        end
    end
    return nil
end

-- Loop with a matching `name` field (case-sensitive). Returns loop, index.
function WorkLoopHelper.findByName(loops, name)
    if type(loops) ~= "table" or name == nil then return nil end
    for i, loop in ipairs(loops) do
        if loop.name == name then return loop, i end
    end
    return nil
end

-- Resolve a loop from a selector that may be:
--   * a string loop name      -> "morningRounds"
--   * an index (number or numeric string) -> 2 or "2"
--   * nil                     -> the loop active at `hour`
-- Returns loop, index (or nil if nothing matches).
function WorkLoopHelper.resolve(loops, selector, hour)
    if type(loops) ~= "table" then return nil end
    if selector == nil then
        return WorkLoopHelper.getActiveLoop(loops, hour)
    end
    local n = tonumber(selector)
    if n ~= nil then
        return loops[n], n
    end
    return WorkLoopHelper.findByName(loops, selector)
end

-- List loop names (falls back to "#index" for unnamed loops) for console feedback.
function WorkLoopHelper.names(loops)
    local out = {}
    if type(loops) == "table" then
        for i, loop in ipairs(loops) do
            out[#out + 1] = loop.name or ("#" .. i)
        end
    end
    return out
end
