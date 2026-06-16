local blocks = require("blocks")


local structures = {}

function structures.spawnTree(x, y, z)
    local world = require("world")

    for th = 0, 4 do world.setBlock(x, y + th, z, blocks.wood) end
    for lx = -2, 2 do
        for lz = -2, 2 do
            for ly = 3, 5 do
                if math.abs(lx) + math.abs(lz) < 3 then
                    if world.getBlock(x + lx, y + ly, z + lz) == nil then
                        world.setBlock(x + lx, y + ly, z + lz, blocks.leaves)
                    end
                end
            end
        end
    end
end

function structures.spawnCactus(x, y, z)
    local world = require("world")

    for i = 0, math.random(2,4) do
        world.setBlock(x, y+i, z, blocks.wood) -- replace with cactus block later
    end
end

function structures.spawnDeadBush(x, y, z)
    local world = require("world")

    world.setBlock(x, y, z, blocks.short_grass)
end

function structures.spawnGrass(x, y, z)
    local world = require("world")

    world.setBlock(x, y, z, blocks.short_grass)
end

function structures.spawnFlower(x, y, z)
    local world = require("world")

    world.setBlock(x, y, z, blocks.flower)
end

function structures.spawnBamboo(x, y, z)
    local world = require("world")

    for i = 0, math.random(2, 6) do
        world.setBlock(x, y + i, z, blocks.bamboo)
    end
end

function structures.spawnDesertWell(x, y, z)
    local world = require("world")

    for dx = -1, 1 do
        for dz = -1, 1 do
            world.setBlock(x + dx, y, z + dz, blocks.sandstone)
            world.setBlock(x + dx, y + 3, z + dz, blocks.sandstone)
        end
    end
    world.setBlock(x, y, z, nil) -- Center cutout water hole
    world.setBlock(x - 1, y + 1, z - 1, blocks.stone)
    world.setBlock(x + 1, y + 1, z - 1, blocks.stone)
    world.setBlock(x - 1, y + 1, z + 1, blocks.stone)
    world.setBlock(x + 1, y + 1, z + 1, blocks.stone)
end

-- 2. A growth asset: Dripstone Cave Stalactites and Stalagmites
-- Generates vertical spikes depending on whether it has ceiling or floor clearance
function structures.spawnDripstoneFeature(x, y, z)
    local world = require("world")
    
    -- Vertical Raycast scanning downwards to check for open cavern space
    local ceilingY = nil
    local floorY = nil
    
    -- Look up to 15 blocks above and below to find a cavern air gap
    for checkY = y + 10, y - 10, -1 do
        local block = world.getBlock(x, checkY, z)
        if block == blocks.stone or block == blocks.deepslate then
            if not ceilingY and world.getBlock(x, checkY - 1, z) == nil then
                ceilingY = checkY
            end
        end
    end
    
    -- If we found a ceiling block, let's grow a Stalactite down!
    if ceilingY then
        local length = math.random(1, 4)
        for i = 0, length - 1 do
            local currentY = ceilingY - 1 - i
            if world.getBlock(x, currentY, z) == nil then
                -- In a rich engine, we place a custom block state. 
                -- Lacking that, we stack cobblestone/stone markers to emulate the pillar shape
                world.setBlock(x, currentY, z, blocks.cobblestone) 
            else
                break
            end
        end
    end
    
    -- Find the floor directly below
    for checkY = y - 1, y - 15, -1 do
        local block = world.getBlock(x, checkY, z)
        if block == blocks.stone or block == blocks.deepslate then
            floorY = checkY
            break
        end
    end
    
    -- Grow a Stalagmite up from the floor
    if floorY and world.getBlock(x, floorY + 1, z) == nil then
        local length = math.random(1, 3)
        for i = 0, length - 1 do
            local currentY = floorY + 1 + i
            if world.getBlock(x, currentY, z) == nil then
                world.setBlock(x, currentY, z, blocks.cobblestone)
            else
                break
            end
        end
    end
end

return structures
