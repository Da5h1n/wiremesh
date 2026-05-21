local m = {}

function m.deg2rad(a) return a * math.pi / 180 end

function m.rotateY(x, y, z, yaw)
    local cy, sy = math.cos(yaw), math.sin(yaw)
    return x * cy - z * sy, y, x * sy + z * cy
end

function m.rotateX(x, y, z, pitch)
    local cp, sp = math.cos(pitch), math.sin(pitch)
    return x, y * cp - z * sp, y * sp + z * cp
end

function m.dot(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end

return m