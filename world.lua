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
world.chunkSaveFormat = 3

local BIOMES = biomeDefs.list

-- Tracks what generation step a chunk has safely completed
world.chunkStates = {} 
world.saveDirectory = ".world"

local faces = {
    up    = { normal={0,1,0},  neighbor={0,1,0},  corners={4,3,7,8} },
    down  = { normal={0,-1,0}, neighbor={0,-1,0}, corners={1,5,6,2} },
    north = { normal={0,0,-1}, neighbor={0,0,-1}, corners={1,2,3,4} },
    south = { normal={0,0,1},  neighbor={0,0,1},  corners={6,5,8,7} },
    west  = { normal={-1,0,0}, neighbor={-1,0,0}, corners={5,1,4,8} },
    east  = { normal={1,0,0},  neighbor={1,0,0},  corners={2,6,7,3} }
}

local function getChunkKey(cx, cz)
    local row = world.chunkStates[cx]
    return row and row[cz] or "empty"
end

-- ==========================================
-- MULTI-STEP PIPELINE ENGINE
-- ==========================================

function world.getChunkState(cx, cz)
    local row = world.chunkStates[cx]
    return row and row[cz] or "empty"
end

function world.advanceChunkTo(cx, cz, targetState)
    local currentState = world.getChunkState(cx, cz)

    if currentState == "empty" and world.loadChunkFromDisk(cx, cz) then
        currentState = world.getChunkState(cx, cz)
        if currentState == "full" then
            world.buildChunkMesh(cx, cz)
            world.rebuildAdjacentChunkMeshes(cx, cz)
        end
    end

    if currentState == "empty" and targetState ~= "empty" then
        -- Initialize nested rows if they don't exist yet
        if not world.chunks[cx] then world.chunks[cx] = {} end
        if not world.chunkStates[cx] then world.chunkStates[cx] = {} end

        world.chunks[cx][cz] = { data = {}, biomes = {} }
        world.chunkStates[cx][cz] = "biomes"
        world.pipeline_Biomes(cx, cz)
        currentState = "biomes"
    end

    if currentState == "biomes" and (targetState == "noise" or targetState == "surface" or targetState == "carvers" or targetState == "full") then
        world.pipeline_Noise(cx, cz)
        world.chunkStates[cx][cz] = "noise"
        currentState = "noise"
    end
    
    if currentState == "noise" and (targetState == "surface" or targetState == "carvers" or targetState == "full") then
        world.pipeline_Surface(cx, cz)
        world.chunkStates[cx][cz] = "surface"
        currentState = "surface"
    end
    
    if currentState == "surface" and (targetState == "carvers" or targetState == "full") then
        world.pipeline_Carvers(cx, cz)
        world.chunkStates[cx][cz] = "carvers"
        currentState = "carvers"
    end
    
    if currentState == "carvers" and targetState == "full" then
        world.pipeline_Features(cx, cz)
        world.chunkStates[cx][cz] = "full"
        
        -- Build meshes safely now that all structural blocks and local carves are finalized
        world.buildChunkMesh(cx, cz)
        world.rebuildAdjacentChunkMeshes(cx, cz)
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

    local chunk = world.chunks[cx] and world.chunks[cx][cz]
    if not chunk then return end

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

    local chunkRow = world.chunks[cx]
    local chunk = chunkRow and chunkRow[cz]
    if not chunk or not chunk.biomes then return end

    for lx = 0, cs - 1 do
        for lz = 0, cs - 1 do
            local x = startX + lx
            local z = startZ + lz

            local infoRow = chunk.biomes[lx]
            local info = infoRow and infoRow[lz]

            if info then

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
end

-- ==========================================
-- PIPELINE STEP 3: SURFACE (Biome Dressing)
-- ==========================================
function world.pipeline_Surface(cx, cz)
    local cs = world.chunkSize
    local startX, startZ = cx * cs, cz * cs
    local seed = perlin.getSeed()

    local chunkRow = world.chunks[cx]
    local chunk = chunkRow and chunkRow[cz]
    if not chunk or not chunk.biomes then return end

    for lx = 0, cs - 1 do
        for lz = 0, cs - 1 do
            local x = startX + lx
            local z = startZ + lz

            local infoRow = chunk.biomes[lx]
            local info = infoRow and infoRow[lz]

            if info then
                
            

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
                        
                        -- FIX: Only process layer rules if the underlying block is stone base 
                        -- (Prevents overwriting air or wiping out open oceans from your noise loop)
                        if currentBlock == blocks.stone then
                            local blocksBelowTerrain = surfaceY - y
                            local d = math.min(blocksBelowTerrain / 64, 1.5)

                            local activeBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, d)
                            local biomeSurfaceBlock = activeBiome.surface(x, y, z, surfaceY)

                            -- Assume the biome block is perfect by default
                            local blockType = biomeSurfaceBlock or blocks.stone

                            -- 3. Inverted filter: ONLY run dressing rules for explicit generic crust blocks
                            -- Rule A: If it's a generic grass/dirt profile, compress it into dirt/deepslate underground
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
                            
                            -- 4. Set the block cleanly *inside* our valid filter structure
                            world.setBlock(x, y, z, blockType)
                        end
                    end
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

    local activeChunk = world.chunks[cx] and world.chunks[cx][cz]
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

    local chunk = world.chunks[cx] and world.chunks[cx][cz]
    if not chunk then return nil end
    
    -- Iterate across every horizontal block coordinate in the chunk
    for lx = 0, cs - 1 do
        for lz = 0, cs - 1 do
            local x = startX + lx
            local z = startZ + lz
            
            -- Extract the multi-noise profile calculated in step 1
            local info = chunk.biomes[lx][lz]
            
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
                        if deco.type == "tree" or deco.type == "swamp_tree" or deco.type == "acacia_tree" or
                           deco.type == "tall_birch_tree" or deco.type == "dark_oak_tree" or deco.type == "mangrove_tree" then
                            -- Ensure the block beneath is grass or dirt before spawning
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.grass or groundBlock == blocks.dirt or groundBlock == blocks.mud then
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
                        elseif deco.type == "grass" or deco.type == "short_grass" then
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.grass or groundBlock == blocks.dirt then
                                structures.spawnGrass(x, surfaceY + 1, z)
                            end
                        elseif deco.type == "flower" then
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.grass or groundBlock == blocks.dirt then
                                structures.spawnFlower(x, surfaceY + 1, z)
                            end
                        elseif deco.type == "bamboo" then
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.grass or groundBlock == blocks.dirt then
                                structures.spawnBamboo(x, surfaceY + 1, z)
                            end
                        elseif deco.type == "dead_bush" then
                            local groundBlock = world.getBlock(x, surfaceY, z)
                            if groundBlock == blocks.sand or groundBlock == blocks.red_sand then
                                structures.spawnDeadBush(x, surfaceY + 1, z)
                            end
                        end
                    end
                end
            end
            
            -- Process Underground Cave-Specific Biomes separately
            -- Cave biomes depend on depth (e.g., d > 0.2)
            local caveBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, 0.5)
            if caveBiome and caveBiome.decorations then
                for _, deco in ipairs(caveBiome.decorations) do
                    if deco.type == "dripstone" then
                        -- Check random spots inside subterranean space (e.g., around Y = -20)
                        -- Instead of checking just one height, we scatter check vertical cave positions
                        if math.random() < deco.rate then
                            local targetCaveY = math.random(-40, 0)
                            structures.spawnDripstoneFeature(x, targetCaveY, z)
                        end
                    elseif deco.type == "grass" or deco.type == "flower" then
                        if math.random() < deco.rate then
                            local targetCaveY = math.random(-35, 20)
                            local blockBelow = world.getBlock(x, targetCaveY - 1, z)
                            if blockBelow == blocks.grass or blockBelow == blocks.dirt then
                                if deco.type == "flower" then
                                    structures.spawnFlower(x, targetCaveY, z)
                                else
                                    structures.spawnGrass(x, targetCaveY, z)
                                end
                            end
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

    local chunk = world.chunks[cx] and world.chunks[cx][cz]
    if not chunk then return end

    local lx = x - (cx * cs)
    local lz = z - (cz * cs)

    chunk.data[lx] = chunk.data[lx] or {}
    chunk.data[lx][lz] = chunk.data[lx][lz] or {}
    chunk.data[lx][lz][y] = id
end

function world.getBlock(x, y, z)
    if y < world.BEDROCK_LEVEL or y >= world.chunkHeight then return nil end

    local cs = world.chunkSize
    local cx, cz = math.floor(x / cs), math.floor(z / cs)


    local chunk = world.chunks[cx] and world.chunks[cx][cz]
    if not chunk then return nil end

    local lx = x - (cx * cs)
    local lz = z - (cz * cs)

    local col = chunk.data[lx]
    return col and col[lz] and col[lz][y]
end

local function getBlockDef(id)
    return id and id > 0 and blocks.list[id] or nil
end

local function shouldDrawFace(id, neighborId)
    local def = getBlockDef(id)
    if not def then return false end

    local neighborDef = getBlockDef(neighborId)
    if not neighborDef then return true end
    if neighborId == id and def.renderLayer == "transparent" then return false end
    return not neighborDef.opaque
end

local function addQuad(chunk, layer, faceName, tex, normal, c1, c2, c3, c4, uMax, vMax)
    local target = (layer == "transparent") and chunk.transparentMesh or chunk.mesh
    target[#target + 1] = {
        c1 = c1,
        c2 = c2,
        c3 = c3,
        c4 = c4,
        normal = normal,
        tex = tex,
        uMax = uMax,
        vMax = vMax,
        layer = layer,
        faceName = faceName
    }
end

local function addCustomModelBlock(chunk, def, x, y, z)
    local model = def.model
    if type(model) ~= "table" or not model.faces then return end

    for i = 1, #model.faces do
        local face = model.faces[i]
        local tex = face.tex or (def.textures and def.textures[face.texture or face.face or "north"])
        if tex and face.c1 and face.c2 and face.c3 and face.c4 and face.normal then
            addQuad(
                chunk,
                def.renderLayer,
                face.face or "custom",
                tex,
                face.normal,
                { x + face.c1[1], y + face.c1[2], z + face.c1[3] },
                { x + face.c2[1], y + face.c2[2], z + face.c2[3] },
                { x + face.c3[1], y + face.c3[2], z + face.c3[3] },
                { x + face.c4[1], y + face.c4[2], z + face.c4[3] },
                face.uMax or 1,
                face.vMax or 1
            )
        end
    end
end

local function greedyMask(maskW, maskH, getEntry, emit)
    local used = {}

    for v = 0, maskH - 1 do
        used[v] = used[v] or {}
        for u = 0, maskW - 1 do
            if not used[v][u] then
                local entry = getEntry(u, v)
                if entry then
                    local width = 1
                    while u + width < maskW and not used[v][u + width] do
                        local other = getEntry(u + width, v)
                        if not other or other.tex ~= entry.tex or other.layer ~= entry.layer then break end
                        width = width + 1
                    end

                    local height = 1
                    local growing = true
                    while v + height < maskH and growing do
                        used[v + height] = used[v + height] or {}
                        for du = 0, width - 1 do
                            local other = getEntry(u + du, v + height)
                            if used[v + height][u + du] or not other or other.tex ~= entry.tex or other.layer ~= entry.layer then
                                growing = false
                                break
                            end
                        end
                        if growing then height = height + 1 end
                    end

                    for dv = 0, height - 1 do
                        used[v + dv] = used[v + dv] or {}
                        for du = 0, width - 1 do
                            used[v + dv][u + du] = true
                        end
                    end

                    emit(u, v, width, height, entry)
                end
            end
        end
    end
end

function world.buildChunkMesh(cx, cz)
    local chunk = world.chunks[cx] and world.chunks[cx][cz]
    if not chunk or not chunk.data then return end

    chunk.mesh = {}
    chunk.transparentMesh = {}

    local cs = world.chunkSize
    local minX, maxX = cx * cs, cx * cs + cs - 1
    local minZ, maxZ = cz * cs, cz * cs + cs - 1
    local minY = world.BEDROCK_LEVEL
    local maxY = world.chunkHeight + world.BEDROCK_LEVEL - 1
    local height = world.chunkHeight

    local function entryFor(x, y, z, faceName, nx, ny, nz)
        local id = world.getBlock(x, y, z)
        local def = getBlockDef(id)
        if not def then return nil end
        if def.model ~= "cube" then
            return nil
        end
        if not shouldDrawFace(id, world.getBlock(nx, ny, nz)) then
            return nil
        end
        return {
            tex = def.textures[faceName],
            layer = def.renderLayer,
        }
    end

    for z = minZ, maxZ do
        greedyMask(cs, height, function(u, v)
            local x, y = minX + u, minY + v
            return entryFor(x, y, z, "north", x, y, z - 1)
        end, function(u, v, qw, qh, entry)
            local x, y, planeZ = minX + u, minY + v, z
            addQuad(chunk, entry.layer, "north", entry.tex, faces.north.normal,
                {x, y, planeZ}, {x + qw, y, planeZ}, {x + qw, y + qh, planeZ}, {x, y + qh, planeZ}, qw, qh)
        end)

        greedyMask(cs, height, function(u, v)
            local x, y = minX + u, minY + v
            return entryFor(x, y, z, "south", x, y, z + 1)
        end, function(u, v, qw, qh, entry)
            local x, y, planeZ = minX + u, minY + v, z + 1
            addQuad(chunk, entry.layer, "south", entry.tex, faces.south.normal,
                {x + qw, y, planeZ}, {x, y, planeZ}, {x, y + qh, planeZ}, {x + qw, y + qh, planeZ}, qw, qh)
        end)
    end

    for x = minX, maxX do
        greedyMask(cs, height, function(u, v)
            local z, y = minZ + u, minY + v
            return entryFor(x, y, z, "west", x - 1, y, z)
        end, function(u, v, qw, qh, entry)
            local z, y, planeX = minZ + u, minY + v, x
            addQuad(chunk, entry.layer, "west", entry.tex, faces.west.normal,
                {planeX, y, z + qw}, {planeX, y, z}, {planeX, y + qh, z}, {planeX, y + qh, z + qw}, qw, qh)
        end)

        greedyMask(cs, height, function(u, v)
            local z, y = minZ + u, minY + v
            return entryFor(x, y, z, "east", x + 1, y, z)
        end, function(u, v, qw, qh, entry)
            local z, y, planeX = minZ + u, minY + v, x + 1
            addQuad(chunk, entry.layer, "east", entry.tex, faces.east.normal,
                {planeX, y, z}, {planeX, y, z + qw}, {planeX, y + qh, z + qw}, {planeX, y + qh, z}, qw, qh)
        end)
    end

    for y = minY, maxY do
        greedyMask(cs, cs, function(u, v)
            local x, z = minX + u, minZ + v
            return entryFor(x, y, z, "down", x, y - 1, z)
        end, function(u, v, qw, qh, entry)
            local x, z, planeY = minX + u, minZ + v, y
            addQuad(chunk, entry.layer, "down", entry.tex, faces.down.normal,
                {x, planeY, z}, {x, planeY, z + qh}, {x + qw, planeY, z + qh}, {x + qw, planeY, z}, qw, qh)
        end)

        greedyMask(cs, cs, function(u, v)
            local x, z = minX + u, minZ + v
            return entryFor(x, y, z, "up", x, y + 1, z)
        end, function(u, v, qw, qh, entry)
            local x, z, planeY = minX + u, minZ + v, y + 1
            addQuad(chunk, entry.layer, "up", entry.tex, faces.up.normal,
                {x, planeY, z}, {x + qw, planeY, z}, {x + qw, planeY, z + qh}, {x, planeY, z + qh}, qw, qh)
        end)
    end

    for x = minX, maxX do
        for z = minZ, maxZ do
            for y = minY, maxY do
                local id = world.getBlock(x, y, z)
                local def = getBlockDef(id)
                if def and def.model ~= "cube" then
                    addCustomModelBlock(chunk, def, x, y, z)
                end
            end
        end
    end
end

function world.rebuildAdjacentChunkMeshes(cx, cz)
    local offsets = {
        { 1, 0 },
        { -1, 0 },
        { 0, 1 },
        { 0, -1 },
    }

    for i = 1, #offsets do
        local nx = cx + offsets[i][1]
        local nz = cz + offsets[i][2]
        if world.getChunkState(nx, nz) == "full" then
            world.buildChunkMesh(nx, nz)
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

function world.setSaveDirectory(path)
    world.saveDirectory = path or ".world"
end

local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function getChunkFileName(cx, cz)
    return fs.combine(world.saveDirectory, string.format("chunk_%d_%d.wchunk", cx, cz))
end

local function getLegacyChunkFileName(cx, cz)
    return fs.combine(world.saveDirectory, string.format("chunk_%d_%d.dat", cx, cz))
end

local function serializeTable(value)
    if textutils.serialise then
        return textutils.serialise(value)
    end
    return textutils.serialize(value)
end

local function unserializeTable(value)
    if textutils.unserialise then
        return textutils.unserialise(value)
    end
    return textutils.unserialize(value)
end

local function encodeBlocksRLE(chunk)
    local runs = {}
    local lastId = nil
    local count = 0
    local cs = world.chunkSize
    local minY = world.BEDROCK_LEVEL
    local maxY = world.BEDROCK_LEVEL + world.chunkHeight - 1

    local function pushRun()
        if lastId ~= nil and count > 0 then
            runs[#runs + 1] = lastId
            runs[#runs + 1] = count
        end
    end

    for lx = 0, cs - 1 do
        local xCol = chunk.data[lx]
        for lz = 0, cs - 1 do
            local zCol = xCol and xCol[lz]
            for y = minY, maxY do
                local id = zCol and zCol[y] or 0
                if id == lastId then
                    count = count + 1
                else
                    pushRun()
                    lastId = id
                    count = 1
                end
            end
        end
    end

    pushRun()
    return runs
end

local function decodeBlocksRLE(runs)
    local data = {}
    if type(runs) ~= "table" then
        return data
    end

    local cs = world.chunkSize
    local minY = world.BEDROCK_LEVEL
    local total = cs * cs * world.chunkHeight
    local index = 0

    for i = 1, #runs, 2 do
        local id = runs[i] or 0
        local count = runs[i + 1] or 0
        for _ = 1, count do
            if index >= total then
                return data
            end

            if id ~= 0 then
                local columnIndex = math.floor(index / world.chunkHeight)
                local lx = math.floor(columnIndex / cs)
                local lz = columnIndex % cs
                local y = minY + (index % world.chunkHeight)

                data[lx] = data[lx] or {}
                data[lx][lz] = data[lx][lz] or {}
                data[lx][lz][y] = id
            end

            index = index + 1
        end
    end

    return data
end

local base36Chars = "0123456789abcdefghijklmnopqrstuvwxyz"

local function toBase36(value)
    value = math.floor(value or 0)
    if value == 0 then
        return "0"
    end

    local out = ""
    while value > 0 do
        local digit = (value % 36) + 1
        out = base36Chars:sub(digit, digit) .. out
        value = math.floor(value / 36)
    end
    return out
end

local function fromBase36(value)
    local result = 0
    value = tostring(value or "0"):lower()
    for i = 1, #value do
        local c = value:sub(i, i)
        local digit = base36Chars:find(c, 1, true)
        if not digit then
            return 0
        end
        result = result * 36 + digit - 1
    end
    return result
end

local function encodeRunsCompact(runs)
    local parts = {}
    for i = 1, #runs, 2 do
        parts[#parts + 1] = toBase36(runs[i]) .. "x" .. toBase36(runs[i + 1])
    end
    return table.concat(parts, ",")
end

local function decodeRunsCompact(value)
    local runs = {}
    for id, count in tostring(value or ""):gmatch("([0-9a-z]+)x([0-9a-z]+)") do
        runs[#runs + 1] = fromBase36(id)
        runs[#runs + 1] = fromBase36(count)
    end
    return runs
end

local function writeCompactChunk(path, payload)
    local file = fs.open(path, "w")
    if not file then return false end

    file.writeLine("WMCHUNK3")
    file.writeLine("state=" .. tostring(payload.state or "empty"))
    file.writeLine("minY=" .. tostring(payload.minY))
    file.writeLine("height=" .. tostring(payload.height))
    file.write("blocks=" .. encodeRunsCompact(payload.blocks))
    file.close()
    return true
end

local function readCompactChunk(data)
    if data:sub(1, 8) ~= "WMCHUNK3" then
        return nil
    end

    local payload = {
        format = 3,
        encoding = "rle-yxz-compact",
    }

    for line in (data .. "\n"):gmatch("([^\n]*)\n") do
        local key, value = line:match("^([%w_]+)=(.*)$")
        if key == "state" then
            payload.state = value
        elseif key == "minY" then
            payload.minY = tonumber(value)
        elseif key == "height" then
            payload.height = tonumber(value)
        elseif key == "blocks" then
            payload.blocks = decodeRunsCompact(value)
        end
    end

    return payload
end

function world.saveChunkToDisk(cx, cz)
    local chunk = world.chunks[cx] and world.chunks[cx][cz]
    if not chunk then return false end

    local payload = {
        format = world.chunkSaveFormat,
        encoding = "rle-yxz",
        minY = world.BEDROCK_LEVEL,
        height = world.chunkHeight,
        blocks = encodeBlocksRLE(chunk),
        state  = world.chunkStates[cx] and world.chunkStates[cx][cz] or "empty"
    }

    ensureDir(world.saveDirectory)

    return writeCompactChunk(getChunkFileName(cx, cz), payload)
end

function world.loadChunkFromDisk(cx, cz)
    local path = getChunkFileName(cx, cz)
    if not fs.exists(path) then
        path = getLegacyChunkFileName(cx, cz)
    end
    if not fs.exists(path) then return nil end

    local file = fs.open(path, "r")
    if not file then return nil end

    local data = file.readAll()
    file.close()

    local payload = readCompactChunk(data) or unserializeTable(data)
    if not payload then return nil end

    local blocksData
    if (payload.format == 2 and payload.encoding == "rle-yxz") or
       (payload.format == 3 and payload.encoding == "rle-yxz-compact") then
        blocksData = decodeBlocksRLE(payload.blocks)
    else
        blocksData = payload.blocks or {}
    end

    world.chunks[cx] = world.chunks[cx] or {}
    world.chunks[cx][cz] = {
        data = blocksData,
        biomes = payload.biomes or {}
    }

    if not payload.biomes then
        world.pipeline_Biomes(cx, cz)
    end

    world.chunkStates[cx] = world.chunkStates[cx] or {}
    world.chunkStates[cx][cz] = payload.state

    return true
end

function world.saveAllChunksToDisk()
    local saved = 0
    for cx, row in pairs(world.chunks) do
        for cz in pairs(row) do
            if world.saveChunkToDisk(cx, cz) then
                saved = saved + 1
            end
        end
    end
    return saved
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
