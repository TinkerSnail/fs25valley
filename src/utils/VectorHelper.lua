VectorHelper = {}

function VectorHelper.distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function VectorHelper.distance2D(a, b)
    local dx = a.x - b.x
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dz*dz)
end

function VectorHelper.lerp(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t,
    }
end

function VectorHelper.angleToward(from, to)
    local dx = to.x - from.x
    local dz = to.z - from.z
    return math.atan2(dx, dz)
end

function VectorHelper.offsetForward(pos, angle, dist)
    return {
        x = pos.x + math.sin(angle) * dist,
        y = pos.y,
        z = pos.z + math.cos(angle) * dist,
    }
end
