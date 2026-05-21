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

    world.setBlock(x, y, z, nil)
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

return structures
