local textures = require("textures")
local blocks = {}

function blocks.register(def)
    blocks[#blocks+1] = def
    return #blocks
end

blocks.list = blocks

-- BASIC TERRAIN
blocks.grass = blocks.register{ name="grass", textures={ up=textures.grass_top, down=textures.dirt, north=textures.grass_side, south=textures.grass_side, west=textures.grass_side, east=textures.grass_side } }
blocks.dirt  = blocks.register{ name="dirt",  textures={ up=textures.dirt, down=textures.dirt, north=textures.dirt, south=textures.dirt, west=textures.dirt, east=textures.dirt } }
blocks.stone = blocks.register{ name="stone", textures={ up=textures.stone, down=textures.stone, north=textures.stone, south=textures.stone, west=textures.stone, east=textures.stone } }
blocks.deepslate = blocks.register{ name="deepslate", textures={ up=textures.deepslate, down=textures.deepslate, north=textures.deepslate, south=textures.deepslate, west=textures.deepslate, east=textures.deepslate } }

blocks.cobblestone = blocks.register{ name="cobblestone", textures={ up=textures.cobblestone, down=textures.cobblestone, north=textures.cobblestone, south=textures.cobblestone, west=textures.cobblestone, east=textures.cobblestone } }

-- ORES
blocks.coal_ore    = blocks.register{ name="coal_ore",    textures={ up=textures.coal_ore,    down=textures.coal_ore,    north=textures.coal_ore,    south=textures.coal_ore,    west=textures.coal_ore,    east=textures.coal_ore } }
blocks.iron_ore    = blocks.register{ name="iron_ore",    textures={ up=textures.iron_ore,    down=textures.iron_ore,    north=textures.iron_ore,    south=textures.iron_ore,    west=textures.iron_ore,    east=textures.iron_ore } }
blocks.gold_ore    = blocks.register{ name="gold_ore",    textures={ up=textures.gold_ore,    down=textures.gold_ore,    north=textures.gold_ore,    south=textures.gold_ore,    west=textures.gold_ore,    east=textures.gold_ore } }
blocks.diamond_ore = blocks.register{ name="diamond_ore", textures={ up=textures.diamond_ore, down=textures.diamond_ore, north=textures.diamond_ore, south=textures.diamond_ore, west=textures.diamond_ore, east=textures.diamond_ore } }

-- NATURAL BLOCKS
blocks.sand      = blocks.register{ name="sand",      textures={ up=textures.sand, down=textures.sand, north=textures.sand, south=textures.sand, west=textures.sand, east=textures.sand } }
blocks.sandstone = blocks.register{ name="sandstone", textures={ up=textures.sandstone, down=textures.sandstone, north=textures.sandstone, south=textures.sandstone, west=textures.sandstone, east=textures.sandstone } }
blocks.snow      = blocks.register{ name="snow",      textures={ up=textures.snow, down=textures.stone, north=textures.snow, south=textures.snow, west=textures.snow, east=textures.snow } }
blocks.gravel    = blocks.register{ name="gravel",    textures={ up=textures.gravel, down=textures.gravel, north=textures.gravel, south=textures.gravel, west=textures.gravel, east=textures.gravel } }
blocks.clay      = blocks.register{ name="clay",      textures={ up=textures.clay, down=textures.clay, north=textures.clay, south=textures.clay, west=textures.clay, east=textures.clay } }

blocks.bedrock = blocks.register{
    name="bedrock",
    textures={ up=textures.bedrock, down=textures.bedrock,
               north=textures.bedrock, south=textures.bedrock,
               west=textures.bedrock, east=textures.bedrock }
}

blocks.ice = blocks.register{
    name="ice",
    textures={ up=textures.ice, down=textures.ice,
               north=textures.ice, south=textures.ice,
               west=textures.ice, east=textures.ice }
}

blocks.red_sand = blocks.register{
    name="red_sand",
    textures={ up=textures.red_sand, down=textures.red_sand,
               north=textures.red_sand, south=textures.red_sand,
               west=textures.red_sand, east=textures.red_sand }
}

blocks.red_sandstone = blocks.register{ name="red_sandstone", textures={ up=textures.red_sandstone, down=textures.red_sandstone, north=textures.red_sandstone, south=textures.red_sandstone, west=textures.red_sandstone, east=textures.red_sandstone }}


-- TREES
blocks.wood   = blocks.register{ name="wood",   textures={ up=textures.wood, down=textures.wood, north=textures.wood, south=textures.wood, west=textures.wood, east=textures.wood } }
blocks.leaves = blocks.register{ name="leaves", textures={ up=textures.leaves, down=textures.leaves, north=textures.leaves, south=textures.leaves, west=textures.leaves, east=textures.leaves } }

-- WATER
blocks.water = blocks.register{ name="water", textures={ up=textures.water, down=textures.water, north=textures.water, south=textures.water, west=textures.water, east=textures.water } }

-- MARKERS
blocks.marker_pyramid = blocks.register{ name="marker_pyramid", textures={ up=textures.marker_orange, down=textures.marker_orange, north=textures.marker_orange, south=textures.marker_orange, west=textures.marker_orange, east=textures.marker_orange } }
blocks.marker_dungeon = blocks.register{ name="marker_dungeon", textures={ up=textures.marker_magenta, down=textures.marker_magenta, north=textures.marker_magenta, south=textures.marker_magenta, west=textures.marker_magenta, east=textures.marker_magenta } }

return blocks
