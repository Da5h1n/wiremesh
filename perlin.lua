local perlin = {}

local p = {}
local seed = 0

local function parseSeed(newSeed)
    seed = tonumber(newSeed) or os.epoch("utc")
    math.randomseed(seed)

    local tags = {}
    for i = 0, 255 do tags[i] = i end

    for i = 255, 1, -1 do
        local j = math.random(0, i)
        tags[i], tags[j] = tags[j], tags[i]
    end

    for i = 0, 255 do
        p[i] = tags[i]
        p[i + 256] = tags[i]
    end
end

local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
    return a + t * (b - a)
end

local function grad(hash, x, y)
    local h = bit32.band(hash, 7)
    local u = h < 4 and x or y
    local v = h < 4 and y or x
    return ((bit32.band(h, 1) == 0) and u or -u) + ((bit32.band(h, 2) == 0) and 2.0 * v or -2.0 * v)
end

parseSeed()

function perlin.init(customSeed)
    parseSeed(customSeed)
end

function perlin.getSeed()
    return seed
end

function perlin.noise2d(x, y)
    local X = bit32.band(math.floor(x), 255)
    local Y = bit32.band(math.floor(y), 255)

    x = x - math.floor(x)
    y = y - math.floor(y)

    local u = fade(x)
    local v = fade(y)

    local A  = p[X] + Y
    local AA = p[A]
    local AB = p[A + 1]
    local B  = p[X + 1] + Y
    local BA = p[B]
    local BB = p[B + 1]

    return lerp(v, lerp(u, grad(p[AA], x, y),
                           grad(p[BA], x - 1, y)),
                   lerp(u, grad(p[AB], x, y - 1),
                           grad(p[BB], x - 1, y - 1)))
end

function perlin.fbm2d(x, y, octaves, persistence)
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0
    for i = 1, octaves do
        total = total + perlin.noise2d(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return total / maxValue
end

return perlin