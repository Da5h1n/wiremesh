local blocks = require("blocks")
local perlin = require("perlin")
local biomeDefs = require("biomes_definitions")
local structures = require("structures")

local world = {}

world.debugBiomes = false

world.chunks = {}
world.chunkSize = 16
world.chunkHeight = 256
world.generatedChunks = {}
world.SEA_LEVEL = 62
world.BEDROCK_LEVEL = -64

world.generationQueue = {}

local BIOMES = biomeDefs.list

-- Check your winding order alignment here:
local faces = {
    up    = { normal={0,1,0},  neighbor={0,1,0},  corners={4,3,7,8} },
    down  = { normal={0,-1,0}, neighbor={0,-1,0}, corners={1,5,6,2} }, -- Adjusted winding
    north = { normal={0,0,-1}, neighbor={0,0,-1}, corners={1,2,3,4} },
    south = { normal={0,0,1},  neighbor={0,0,1},  corners={6,5,8,7} }, -- Adjusted winding
    west  = { normal={-1,0,0}, neighbor={-1,0,0}, corners={5,1,4,8} }, -- Adjusted winding
    east  = { normal={1,0,0},  neighbor={1,0,0},  corners={2,6,7,3} }  -- Adjusted winding
}

local function getChunkKey(cx, cz)
    return string.format("%d,%d", cx, cz)
end

local function getBiomeDebug(x, z)
    local cs = world.chunkSize
    local cx = math.floor(x / cs)
    local cz = math.floor(z / cs)
    
    -- Pick a valid index dynamically from our sequential array list
    local index = (math.abs(cx) + math.abs(cz) * 3) % #BIOMES + 1
    return BIOMES[index]
end

function world.queueChunk(cx, cz)
    local chunkId = getChunkKey(cx, cz)
    if world.generatedChunks[chunkId] then return end

    for _, task in ipairs(world.generationQueue) do
        if task.cx == cx and task.cz == cz then return end
    end

    table.insert(world.generationQueue, {cx = cx, cz = cz})
end

function world.processQueue()
    if #world.generationQueue == 0 then return end

    local task = table.remove(world.generationQueue, 1)
    world.generateChunk(task.cx, task.cz)
end

local function getBiome6D(t, h, c, e, w, d)
    local bestBiome = nil
    local minDistance = math.huge

    for i = 1, #BIOMES do
        local biome = BIOMES[i]
        local range = biome.ranges
        if range then
            local inside = true
            if range.t and (t < range.t[1] or t > range.t[2]) then inside = false end
            if range.h and (h < range.h[1] or h > range.h[2]) then inside = false end
            if range.c and (c < range.c[1] or c > range.c[2]) then inside = false end
            if range.e and (e < range.e[1] or e > range.e[2]) then inside = false end
            if range.w and (w < range.w[1] or w > range.w[2]) then inside = false end
            if range.d and (d < range.d[1] or d > range.d[2]) then inside = false end

            if inside then return biome end
        end

        local ideal = biome.ideal
        if ideal then
            local dt = t - (ideal.t or 0)
            local dh = h - (ideal.h or 0)
            local dc = c - (ideal.c or 0)
            local de = e - (ideal.e or 0)
            local dw = w - (ideal.w or 0)
            local dd = d - (ideal.d or 0)
            local dist = dt*dt + dh*dh + dc*dc + de*de + dw*dw + dd*dd

            if dist < minDistance then
                minDistance = dist
                bestBiome = biome
            end
        end
    end

    return bestBiome or BIOMES[3]
end

function world.buildChunkMesh(cx, cz)
    local key = getChunkKey(cx, cz)
    local chunk = world.chunks[key]
    if not chunk or not chunk.data then return end

    chunk.mesh = {}
    local cs = world.chunkSize
    local minX, maxX = cx * cs, cx * cs + cs - 1
    local minZ, maxZ = cz * cs, cz * cs + cs - 1

    for x = minX, maxX do
        for z = minZ, maxZ do
            for y = world.BEDROCK_LEVEL, world.chunkHeight + world.BEDROCK_LEVEL - 1 do
                local id = world.getBlock(x, y, z)
                if id and id > 0 then
                    local def = blocks.list[id]
                    if def then
                        for faceName, f in pairs(faces) do
                            local nx = x + f.neighbor[1]
                            local ny = y + f.neighbor[2]
                            local nz = z + f.neighbor[3]

                            -- FIX: Check chunk boundaries carefully. 
                            -- If neighboring chunk isn't loaded yet, show face to avoid missing walls.
                            local neighborBlock = world.getBlock(nx, ny, nz)
                            if not neighborBlock or neighborBlock == 0 then
                                local corners = {
                                    {x, y, z},     {x+1, y, z},     {x+1, y+1, z},     {x, y+1, z},
                                    {x, y, z+1},   {x+1, y, z+1},   {x+1, y+1, z+1},   {x, y+1, z+1}
                                }
                                table.insert(chunk.mesh, {
                                    c1 = corners[f.corners[1]],
                                    c2 = corners[f.corners[2]],
                                    c3 = corners[f.corners[3]],
                                    c4 = corners[f.corners[4]],
                                    normal = f.normal,
                                    tex = def.textures[faceName]
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

function world.getBiomeAt(x, y, z)
    if not z then
        z = y
        y = world.SEA_LEVEL
    end

    local t = perlin.fbm2d(x * 0.001,  z * 0.001,  4, 0.5)
    local h = perlin.fbm2d(x * 0.001,  z * 0.001,  4, 0.5)
    local c = perlin.fbm2d(x * 0.005,  z * 0.005,  2, 0.5)
    local e = perlin.fbm2d(x * 0.01,   z * 0.01,   3, 0.4)
    local w = perlin.fbm2d(x * 0.002,  z * 0.002,  2, 0.5)

    local surfaceNoise = perlin.fbm2d(x * 0.01, z * 0.01, 3, 0.4)
    local estimatedSurfaceY = math.floor(surfaceNoise * 20 + 62)

    local d = 0.0
    if y < estimatedSurfaceY then
        d = (estimatedSurfaceY - y) / 128.0
    end

    return getBiome6D(t, h, c, e, w, d)
end

function world.setBlock(x, y, z, id)
    local cs = world.chunkSize
    local cx = math.floor(x / cs)
    local cz = math.floor(z / cs)
    local key = getChunkKey(cx, cz)

    if not world.chunks[key] then
        world.chunks[key] = { data = {} }
    end

    local lx = x - (cx * cs)
    local lz = z - (cz * cs)

    world.chunks[key].data[lx] = world.chunks[key].data[lx] or {}
    world.chunks[key].data[lx][lz] = world.chunks[key].data[lx][lz] or {}
    world.chunks[key].data[lx][lz][y] = id
end

function world.getBlock(x, y, z)
    if y < world.BEDROCK_LEVEL or y >= world.chunkHeight then return nil end

    local cs = world.chunkSize
    local cx, cz = math.floor(x / cs), math.floor(z / cs)
    local key = getChunkKey(cx, cz)

    if not world.chunks[key] then return nil end
    local lx, lz = x - (cx * cs), z - (cz * cs)

    return world.chunks[key].data[lx] and world.chunks[key].data[lx][lz] and world.chunks[key].data[lx][lz][y]
end

function world.generateChunk(cx, cz)
    local chunkId = getChunkKey(cx, cz)
    if world.generatedChunks[chunkId] then return end

    local cs = world.chunkSize
    local startX = cx * cs
    local startZ = cz * cs
    local seed = perlin.getSeed()

    for x = startX, startX + cs - 1 do
        for z = startZ, startZ + cs - 1 do

            local t = perlin.fbm2d(x * 0.002,  z * 0.002,  4, 0.5)
            local h = perlin.fbm2d(x * 0.002,  z * 0.002,  4, 0.5)
            local c = perlin.fbm2d(x * 0.005,  z * 0.005,  2, 0.5)
            local e = perlin.fbm2d(x * 0.01,   z * 0.01,   3, 0.4)
            local w = perlin.fbm2d(x * 0.002,  z * 0.002,  2, 0.5)
            
            local pv = 1.0 - math.abs((3.0 * math.abs(w)) - 2.0)

            local baseH = perlin.fbm2d(x * 0.005, z * 0.005, 3, 0.4)
            
            local surfaceBiome = getBiome6D(t, h, c, e, w, 0.0)
            local surfaceY = surfaceBiome.heightMap(baseH)

            local effectiveMinY = math.max(world.BEDROCK_LEVEL, surfaceY - 15)
            local executionMaxY = math.max(world.SEA_LEVEL, surfaceY + 5)

            local columnSeed = math.floor(x * 131071 + z * 524287 + seed)


            for y = world.BEDROCK_LEVEL, executionMaxY do
                math.randomseed(columnSeed + y * 31)

                if y < world.BEDROCK_LEVEL + 5 then
                    if y == world.BEDROCK_LEVEL then
                        world.setBlock(x, y, z, blocks.bedrock)
                    else
                        world.setBlock(x, y, z, blocks.deepslate)
                    end
                

                elseif y <= surfaceY then
                    local d = (surfaceY - y) / 128.0
                    local activeBiome = getBiome6D(t, h, c, e, w, d)
                    local blockType = activeBiome.surface(x, y, z, surfaceY)

                    if (not blockType or blockType == blocks.stone) then
                        
                        if y <= 0 then
                            blockType = blocks.deepslate
                        elseif y > 0 and y <= 8 then

                            local stoneChance = y / 8.0
                            if math.random() < stoneChance then
                                blockType = blocks.stone
                            else
                                blockType = blocks.deepslate
                            end
                        else
                            blockType = blocks.stone
                        end
                    end

                    if blockType then
                        world.setBlock(x, y, z, blockType)
                    end

                elseif y <= world.SEA_LEVEL then
                    world.setBlock(x, y, z, blocks.water)
                end
            end

            math.randomseed(columnSeed)
            local roll = math.random()
            for i = 1, #surfaceBiome.decorations do
                local deco = surfaceBiome.decorations[i]
                if roll < deco.rate then
                    if deco.type == "tree" and structures.spawnTree then
                        structures.spawnTree(x, surfaceY + 1, z)
                    end
                end
            end
        end
    end
    
    world.generatedChunks[chunkId] = true

    -- Remesh surrounding chunk edges
    world.buildChunkMesh(cx, cz)
    world.buildChunkMesh(cx - 1, cz)
    world.buildChunkMesh(cx + 1, cz)
    world.buildChunkMesh(cx, cz - 1)
    world.buildChunkMesh(cx, cz + 1)
end

function world.generateArea(minX, maxX, minZ, maxZ)
    local cs = world.chunkSize
    for cx = math.floor(minX / cs), math.floor(maxX / cs) do
        for cz = math.floor(minZ / cs), math.floor(maxZ / cs) do
            world.generateChunk(cx, cz)
        end
    end
end

return world