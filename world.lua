local blocks = require("blocks")
local perlin = require("perlin")
local biomeDefs = require("biomes_definitions")
local structures = require("structures")

local world = {}

world.chunks = {}
world.chunkSize = 16
world.chunkHeight = 256
world.SEA_LEVEL = 62
world.BEDROCK_LEVEL = -64

local BIOMES = biomeDefs.list

-- Tracks what generation step a chunk has safely completed
world.chunkStates = {} 

local faces = {
    up    = { normal={0,1,0},  neighbor={0,1,0},  corners={4,3,7,8} },
    down  = { normal={0,-1,0}, neighbor={0,-1,0}, corners={1,5,6,2} },
    north = { normal={0,0,-1}, neighbor={0,0,-1}, corners={1,2,3,4} },
    south = { normal={0,0,1},  neighbor={0,0,1},  corners={6,5,8,7} },
    west  = { normal={-1,0,0}, neighbor={-1,0,0}, corners={5,1,4,8} },
    east  = { normal={1,0,0},  neighbor={1,0,0},  corners={2,6,7,3} }
}

local function getChunkKey(cx, cz)
    return string.format("%d,%d", cx, cz)
end

-- ==========================================
-- MULTI-STEP PIPELINE ENGINE
-- ==========================================

function world.getChunkState(cx, cz)
    return world.chunkStates[getChunkKey(cx, cz)] or "empty"
end

function world.advanceChunkTo(cx, cz, targetState)
    local currentState = world.getChunkState(cx, cz)
    
    if currentState == "empty" and targetState ~= "empty" then
        world.chunks[getChunkKey(cx, cz)] = { data = {}, biomes = {} }
        world.chunkStates[getChunkKey(cx, cz)] = "biomes"
        world.pipeline_Biomes(cx, cz)
        currentState = "biomes"
    end
    
    if currentState == "biomes" and (targetState == "noise" or targetState == "surface" or targetState == "carvers" or targetState == "full") then
        world.pipeline_Noise(cx, cz)
        world.chunkStates[getChunkKey(cx, cz)] = "noise"
        currentState = "noise"
    end
    
    if currentState == "noise" and (targetState == "surface" or targetState == "carvers" or targetState == "full") then
        world.pipeline_Surface(cx, cz)
        world.chunkStates[getChunkKey(cx, cz)] = "surface"
        currentState = "surface"
    end
    
    if currentState == "surface" and (targetState == "carvers" or targetState == "full") then
        world.pipeline_Carvers(cx, cz)
        world.chunkStates[getChunkKey(cx, cz)] = "carvers"
        currentState = "carvers"
    end
    
    if currentState == "carvers" and targetState == "full" then
        world.pipeline_Features(cx, cz)
        world.chunkStates[getChunkKey(cx, cz)] = "full"
        
        -- Build meshes safely now that all structural blocks and local carves are finalized
        world.buildChunkMesh(cx, cz)
    end
end

function world.getTerrainHeight(x, z, info)

    local terrainNoise = perlin.warpedNoise2d(x, z, 0.004, 0.001, 120, 4, 0.5)

    local continentalness = info.c
    local erosion = info.e
    local weirdness = info.w

    local continentHeight = continentalness * 64

    local erosionFactor = 1.0 - math.abs(erosion)
    erosionFactor = erosionFactor * erosionFactor

    local peakMask = math.max(continentalness, 0)

    local weirdnessShape = 1.0 - math.abs(weirdness)
    weirdnessShape = 1.0 - weirdnessShape
    weirdnessShape = weirdnessShape * weirdnessShape

    local terrainVariation =
        terrainNoise *
        42 *
        erosionFactor *
        (0.35 + peakMask)

    terrainVariation =
        terrainVariation +
        weirdnessShape * 38 * peakMask

    local surfaceY =
        math.floor(
            world.SEA_LEVEL +
            continentHeight +
            terrainVariation
        )

    return surfaceY
end

-- ==========================================
-- PIPELINE STEP 1: BIOMES
-- ==========================================
function world.pipeline_Biomes(cx, cz)
    local key = getChunkKey(cx, cz)
    local chunk = world.chunks[key]
    local cs = world.chunkSize
    
    for lx = 0, cs - 1 do
        chunk.biomes[lx] = {}
        for lz = 0, cs - 1 do
            local x = cx * cs + lx
            local z = cz * cs + lz
            
            -- Apply distinct coordinate offsets to decouple environmental maps.
            -- This ensures a cold zone isn't automatically forced to have matching humidity.
            local t = perlin.fbm2d((x + 1250) * 0.002, (z + 4120) * 0.002, 4, 0.5)
            local h = perlin.fbm2d((x - 8530) * 0.002, (z + 1940) * 0.002, 4, 0.5)
            local c = perlin.fbm2d((x + 4500) * 0.005, (z - 7100) * 0.005, 2, 0.5)
            local e = perlin.fbm2d((x - 3100) * 0.01,  (z + 8900) * 0.01,  3, 0.4)
            local w = perlin.fbm2d((x + 9200) * 0.002, (z - 5300) * 0.002, 2, 0.5)
            
            -- NOTE: If your perlin library outputs [0.0, 1.0], map it to [-1.0, 1.0] like this:
            -- t = t * 2.0 - 1.0
            -- h = h * 2.0 - 1.0
            -- c = c * 2.0 - 1.0
            -- e = e * 2.0 - 1.0
            -- w = w * 2.0 - 1.0
            
            -- Save decoupled 2D multi-noise profile
            chunk.biomes[lx][lz] = { t = t, h = h, c = c, e = e, w = w }
        end
    end
end

-- ==========================================
-- PIPELINE STEP 2: NOISE (Base Terrain Shape)
-- ==========================================
function world.pipeline_Noise(cx, cz)

    local cs = world.chunkSize
    local startX, startZ = cx * cs, cz * cs

    for lx = 0, cs - 1 do
        for lz = 0, cs - 1 do

            local x = startX + lx
            local z = startZ + lz

            local info = world.chunks[getChunkKey(cx, cz)].biomes[lx][lz]

            local surfaceY = world.getTerrainHeight(x, z, info)

            for y = world.BEDROCK_LEVEL, world.chunkHeight + world.BEDROCK_LEVEL - 1 do

                if y <= surfaceY then
                    world.setBlock(x, y, z, blocks.stone)

                elseif y <= world.SEA_LEVEL then
                    world.setBlock(x, y, z, blocks.water)

                end
            end
        end
    end
end

-- ==========================================
-- PIPELINE STEP 3: SURFACE (Biome Dressing)
-- ==========================================
function world.pipeline_Surface(cx, cz)
    local cs = world.chunkSize
    local startX, startZ = cx * cs, cz * cs
    local seed = perlin.getSeed()

    for lx = 0, cs - 1 do
        for lz = 0, cs - 1 do
            local x = startX + lx
            local z = startZ + lz

            local info = world.chunks[getChunkKey(cx, cz)].biomes[lx][lz]
            local surfaceY = world.getTerrainHeight(x, z, info)
            local columnSeed = math.floor(x * 131071 + z * 524287 + seed)

            for y = world.BEDROCK_LEVEL, surfaceY do
                math.randomseed(columnSeed + y * 31)

                -- 1. Bedrock floor layer is a universal absolute rule
                if y < world.BEDROCK_LEVEL + 5 then
                    if y == world.BEDROCK_LEVEL then
                        world.setBlock(x, y, z, blocks.bedrock)
                    else
                        local bedrockChance = 1.0 - ((y - world.BEDROCK_LEVEL) / 5.0)
                        local finalBlock = (math.random() < bedrockChance) and blocks.bedrock or blocks.deepslate
                        world.setBlock(x, y, z, finalBlock)
                    end
                else
                    -- 2. Fetch data & default straight to whatever the biome requested
                    local currentBlock = world.getBlock(x, y, z)
                    local blocksBelowTerrain = surfaceY - y
                    local d = math.min(blocksBelowTerrain / 64, 1.5)

                    local activeBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, d)
                    local biomeSurfaceBlock = activeBiome.surface(x, y, z, surfaceY)

                    -- Assume the biome block is perfect by default
                    local blockType = biomeSurfaceBlock or blocks.stone

                    -- 3. Inverted filter: ONLY run dressing rules for explicit generic crust blocks
                    if currentBlock == blocks.stone then
                        
                        -- Rule A: If it's a generic grass/dirt profile, compress it into dirt underground
                        if biomeSurfaceBlock == blocks.grass or biomeSurfaceBlock == blocks.dirt then
                            if blocksBelowTerrain > 3 then
                                -- Underground crust deep-swap
                                if y <= 0 then
                                    blockType = blocks.deepslate
                                elseif y > 0 and y <= 8 then
                                    blockType = (math.random() < (y / 8.0)) and blocks.stone or blocks.deepslate
                                else
                                    blockType = blocks.stone
                                end
                            elseif blocksBelowTerrain > 0 and biomeSurfaceBlock == blocks.grass then
                                -- Sub-surface grass transitions cleanly to dirt soil
                                blockType = blocks.dirt
                            end

                        -- Rule B: If the biome literally returned raw stone (or nothing), dress the global layers
                        elseif biomeSurfaceBlock == blocks.stone or not biomeSurfaceBlock then
                            if y <= 0 then
                                blockType = blocks.deepslate
                            elseif y > 0 and y <= 8 then
                                blockType = (math.random() < (y / 8.0)) and blocks.stone or blocks.deepslate
                            end
                        end
                        
                        -- NOTE: Any other block (sand, sandstone, etc.) automatically slips 
                        -- past these filters completely untouched!
                    end

                    -- 4. Set the block cleanly out in the open
                    world.setBlock(x, y, z, blockType)
                end
            end
        end
    end
end

-- ==========================================
-- PIPELINE STEP 4: CARVERS (Caves & Ravines)
-- ==========================================
function world.pipeline_Carvers(cx, cz)
    local cs = world.chunkSize
    local startX, startZ = cx * cs, cz * cs

    local chunkKey = string.format("%d,%d", cx, cz)
    local activeChunk = world.chunks[chunkKey]
    if not activeChunk or not activeChunk.biomes then return end

    local getBlock = world.getBlock
    local setBlock = world.setBlock
    local fbm2d = perlin.fbm2d
    local math_abs = math.abs
    local math_random = math.random

    local blk_water = blocks.water
    local blk_bedrock = blocks.bedrock
    local blk_stone  = blocks.stone
    local blk_deepslate = blocks.deepslate

    local MIN_CARVE_Y = -50
    local MAX_CARVE_Y = 50

    for lx = 0, cs - 1 do
        local x = startX + lx
        local x_003 = x * 0.03
        local x_0006 = x * 0.006
        local x_0015 = x * 0.015

        for lz = 0, cs - 1 do
            local z = startZ + lz
            local z_003 = z * 0.03
            local z_0006 = z * 0.006

            local info = activeChunk.biomes[lx][lz]

            local surfaceY = world.getTerrainHeight(x, z, info)

            local currentMaxY = (surfaceY - 5 < MAX_CARVE_Y) and (surfaceY - 5) or MAX_CARVE_Y

            local ravineNoiseW = fbm2d(x_0006, z_0006, 2, 0.6)
            local isRavineHorizontalMatch = math_abs(ravineNoiseW) < 0.03

            for y = MIN_CARVE_Y, currentMaxY do
                local currentBlock = getBlock(x, y, z)

                if currentBlock and currentBlock ~= blk_water and currentBlock ~= blk_bedrock then
                    
                    local caveNoise1 = fbm2d(x_003, (y + z) * 0.03, 2, 0.5)
                    local cheeseCave = 0

                    if math_abs(caveNoise1) > 0.15 then -- Early skip check before calculating second noise function
                        local caveNoise2 = fbm2d((x + 50) * 0.03, (y - z) * 0.03, 2, 0.5)
                        cheeseCave = math_abs(caveNoise1 * caveNoise2)
                    end

                    local isRavine = false
                    if isRavineHorizontalMatch then
                        local ravineNoiseH = fbm2d(x_0015, y * 0.05, 1, 0.5)
                        isRavine = math_abs(ravineNoiseH) < 0.25
                    end

                    if (cheeseCave > 0.22) or isRavine then
                        setBlock(x, y, z, 0)

                        local depthVal = math.min((surfaceY - y) / 64, 1.5)
                        local caveBiome = nil

                        local blockBelow = getBlock(x, y - 1, z)
                        if blockBelow and blockBelow > 0 and blockBelow ~= blk_water then
                            caveBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, depthVal)

                            if caveBiome.name == "LUSH_CAVES" then
                                setBlock(x, y - 1, z, (math_random() < 0.5) and blocks.grass or blocks.dirt)
                            elseif caveBiome.name == "SULFUR_CAVES" then
                                setBlock(x, y - 1, z, blocks.coal_ore)
                            elseif caveBiome.name == "DEEP_DARK" then
                                setBlock(x, y - 1, z, blk_deepslate)
                            elseif caveBiome.name == "DRIPSTONE_CAVES" then
                                setBlock(x, y - 1, z, blocks.sandstone)
                            end
                        end

                        local blockAbove = getBlock(x, y + 1, z)
                        if blockAbove and blockAbove > 0 and blockAbove ~= blk_water then
                            if not caveBiome then
                                caveBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, depthVal)
                            end

                            if caveBiome.name == "DRIPSTONE_CAVES" then
                                setBlock(x, y + 1, z, blk_stone)
                            elseif caveBiome.name == "DEEP_DARK" then
                                setBlock(x, y + 1, z, blk_deepslate)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ==========================================
-- PIPELINE STEP 5: FEATURES & DECORATIONS
-- ==========================================
function world.pipeline_Features(cx, cz)
    local cs = world.chunkSize
    local startX, startZ = cx * cs, cz * cs
    local seed = perlin.getSeed()
    
    -- Iterate across every horizontal block coordinate in the chunk
    for lx = 0, cs - 1 do
        for lz = 0, cs - 1 do
            local x = startX + lx
            local z = startZ + lz
            
            -- Extract the multi-noise profile calculated in step 1
            local info = world.chunks[getChunkKey(cx, cz)].biomes[lx][lz]
            
            -- Get the active surface biome profile
            local surfaceY = world.getTerrainHeight(x, z, info)

            local activeBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, 0.0)
            
            -- Seed a local random number generator unique to this coordinate column
            -- This prevents decorations in chunk A from shifting if chunk B alters its order
            local columnSeed = math.floor(x * 73856093 + z * 19349663 + seed)
            math.randomseed(columnSeed)
            
            -- Process decorations attached to this biome profile
            if activeBiome.decorations then
                for _, deco in ipairs(activeBiome.decorations) do
                    -- Roll a percentage die against the feature frequency rate
                    if math.random() < deco.rate then
                        
                        -- Execute surface decorations
                        if deco.type == "tree" then
                            -- Ensure the block beneath is grass or dirt before spawning
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.grass or groundBlock == blocks.dirt then
                                structures.spawnTree(x, surfaceY + 1, z)
                            end
                            
                        elseif deco.type == "cactus" then
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.sand then
                                structures.spawnCactus(x, surfaceY + 1, z)
                            end
                            
                        elseif deco.type == "desert_well" then
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.sand then
                                structures.spawnDesertWell(x, surfaceY, z)
                            end
                        end
                    end
                end
            end
            
            -- Process Underground Cave-Specific Biomes separately
            -- Cave biomes depend on depth (e.g., d > 0.2)
            local caveBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, 0.5)
            if caveBiome and caveBiome.name == "SULFUR_CAVES" and caveBiome.decorations then
                for _, deco in ipairs(caveBiome.decorations) do
                    if deco.type == "dripstone" then
                        -- Check random spots inside subterranean space (e.g., around Y = -20)
                        -- Instead of checking just one height, we scatter check vertical cave positions
                        if math.random() < deco.rate then
                            local targetCaveY = math.random(-40, 0)
                            structures.spawnDripstoneFeature(x, targetCaveY, z)
                        end
                    end
                end
            end
            
        end
    end
end

-- ==========================================
-- UTILITIES & UTILITY MATCHES
-- ==========================================


-- Determines the exact biome block context at a 3D coordinate point
function world.getBiomeAt3D(x, y, z, surfaceY)
    -- 1. Sample your horizontal environmental noise maps
    local t = perlin.noise2d(x * 0.005,         z * 0.005)
    local h = perlin.noise2d(z * 0.005 + 1000,  x * 0.005 - 1000)
    local c = perlin.noise2d(x * 0.002 + 5000,  z * 0.002 + 5000)
    local e = perlin.noise2d(x * 0.01 - 3000,   z * 0.01 + 3000)
    local w = perlin.noise2d(x * 0.007 + 8000,  z * 0.007 - 8000)
    
    -- 2. Dynamically calculate Depth (d) based on vertical location
    local d = -0.5 -- Default value representing open sky / surface air
    
    if y < surfaceY then
        local blocksBelowTerrain = surfaceY - y
        
        -- Minecraft style scale: Smoothly transitions deeper into the earth.
        -- At 20 blocks deep, d = 0.5 (Triggers Sulfur Caves)
        -- At 44+ blocks deep, d >= 1.1 (Triggers Deep Dark)
        d = math.min(blocksBelowTerrain / 64, 1.5)
    end

    -- 3. Run the bounding-box range check against your definitions
    for i = 1, #BIOMES do
        local b = BIOMES[i]
        local r = b.ranges

        -- Check if all 6 metrics fall cleanly inside the biome's matrix box
        if t >= r.t[1] and t <= r.t[2] and
           h >= r.h[1] and h <= r.h[2] and
           c >= r.c[1] and c <= r.c[2] and
           e >= r.e[1] and e <= r.e[2] and
           w >= r.w[1] and w <= r.w[2] and
           d >= r.d[1] and d <= r.d[2] then
            
            return b
        end
    end

    -- Return a generic surface biome fallback if nothing catches it
    return BIOMES[3] -- Fallback to PLAINS
end

function world.getBiome6D(t, h, c, e, w, d)

    for i = 1, #BIOMES do
        local b = BIOMES[i]
        local r = b.ranges

        local match = false
        if r[1] then
            for _, rangeSet in ipairs(r) do
                if t >= rangeSet.t[1] and t <= rangeSet.t[2] and
                   h >= rangeSet.h[1] and h <= rangeSet.h[2] and
                   c >= rangeSet.c[1] and c <= rangeSet.c[2] and
                   e >= rangeSet.e[1] and e <= rangeSet.e[2] and
                   w >= rangeSet.w[1] and w <= rangeSet.w[2] and
                   d >= rangeSet.d[1] and d <= rangeSet.d[2] then
                    return b
                end
            end
        else
            if t >= r.t[1] and t <= r.t[2] and
               h >= r.h[1] and h <= r.h[2] and
               c >= r.c[1] and c <= r.c[2] and
               e >= r.e[1] and e <= r.e[2] and
               w >= r.w[1] and w <= r.w[2] and
               d >= r.d[1] and d <= r.d[2] then
                return b
            end
        end
    end

    return BIOMES[11] or BIOMES[1]
end

function world.setBlock(x, y, z, id)
    local cs = world.chunkSize
    local cx = math.floor(x / cs)
    local cz = math.floor(z / cs)
    local key = getChunkKey(cx, cz)

    if not world.chunks[key] then return end

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

-- ==========================================
-- AREA GENERATION ENTRYPOINT
-- ==========================================
function world.generateArea(minX, maxX, minZ, maxZ)
    local cs = world.chunkSize
    local startCx = math.floor(minX / cs)
    local endCx = math.floor(maxX / cs)
    local startCz = math.floor(minZ / cs)
    local endCz = math.floor(maxZ / cs)
    
    -- Pass 1: Bring all chunks in the radius to 'carvers' status 
    -- (This allows carving lines to evaluate smoothly without dropping edges)
    for cx = startCx, endCx do
        for cz = startCz, endCz do
            world.advanceChunkTo(cx, cz, "carvers")
        end
    end
    
    -- Pass 2: Finish to 'full', compiling finalized decorations and building visual meshes
    for cx = startCx, endCx do
        for cz = startCz, endCz do
            world.advanceChunkTo(cx, cz, "full")
        end
    end
end

-- Add these functions to world.lua

local function getChunkFileName(cx, cz)
    -- Saves inside a world folder in your local computer directory
    return string.format(".world/chunk_%d_%d.dat", cx, cz)
end

function world.saveChunkToDisk(cx, cz)
    local key = string.format("%d,%d", cx, cz)
    local chunk = world.chunks[key]
    
    if not chunk then return false end
    
    -- Structure the data payload we actually need to preserve
    local payload = {
        blocks = chunk.blocks, -- If this is a flat 3D array or compressed RLE string
        biomes = chunk.biomes,
        state  = world.chunkStates[key]
    }
    
    -- Ensure the directory exists
    if not fs.exists(".world") then
        fs.makeDir(".world")
    end
    
    local file = fs.open(getChunkFileName(cx, cz), "w")
    if file then
        file.write(textutils.serialize(payload))
        file.close()
        return true
    end
    return false
end

function world.loadChunkFromDisk(cx, cz)
    local path = getChunkFileName(cx, cz)
    if not fs.exists(path) then return nil end
    
    local file = fs.open(path, "r")
    if not file then return nil end
    
    local data = file.readAll()
    file.close()
    
    local payload = textutils.unserialize(data)
    if payload then
        local key = string.format("%d,%d", cx, cz)
        
        -- Restore to game memory
        world.chunks[key] = {
            blocks = payload.blocks,
            biomes = payload.biomes
        }
        world.chunkStates[key] = payload.state
        return true
    end
    return nil
end

return world


--[[
function world.pipeline_Biomes(cx, cz)
    local key = getChunkKey(cx, cz)
    local chunk = world.chunks[key]
    local cs = world.chunkSize
    
    for lx = 0, cs - 1 do
        chunk.biomes[lx] = {}
        for lz = 0, cs - 1 do
            local x = cx * cs + lx
            local z = cz * cs + lz
            
            -------------------------------------------------------------------
            -- FIX PLACEMENT: Quantization Factor, Expanded Bounds, and Ridged Noise
            -------------------------------------------------------------------
            -- 1. Apply Minecraft's 1/10000 macro coordinate sampling scale
            local climateScale = 0.0001 
            local qX = x * climateScale
            local qZ = z * climateScale

            -- 2. Sample Rolling Noise for Temperature & Humidity
            -- Scaled by 1.25 to expand limits to [-1.25, 1.25] for snapshot parameters
            local rawTemp = perlin.fbm2d(qX + 0.125, qZ + 0.412, 4, 0.5)
            local t = rawTemp * 1.25

            local rawHumid = perlin.fbm2d(qX - 0.853, qZ + 0.194, 4, 0.5)
            local h = rawHumid * 1.25

            -- 3. Sample Ridged Multi-Fractal Noise for Erosion & Weirdness
            -- This creates sharp valley trenches and structural alpine peaks
            local e = perlin.ridgedFBM2d(qX - 0.310, qZ + 0.890, 5, 0.5)
            local w = perlin.ridgedFBM2d(qX + 0.920, qZ - 0.530, 5, 0.5)

            -- 4. Simulate Continentalness (Blends macro landmass distributions)
            local c = perlin.fbm2d(qX + 0.450, qZ - 0.710, 5, 0.5) * 1.25
            -------------------------------------------------------------------
            
            -- Save decoupled 2D multi-noise profile
            chunk.biomes[lx][lz] = { t = t, h = h, c = c, e = e, w = w }
        end
    end
end
]]--
