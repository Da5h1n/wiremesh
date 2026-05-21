local blocks = require("blocks")
local structures = require("structures")

local biomes = {}

biomes.list = {
    -- [1] FROZEN_OCEAN (Continentalness: -1.0 to -0.6, Temperature: low)
    {
        name = "FROZEN_OCEAN",
        ideal = { t = -0.8, h = 0.2, c = -0.8, e = 0.0, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 5 + 46) end,
        surface = function(x,y,z,surfaceY) return blocks.stone end,
        decorations = {}
    },
    -- [2] SNOWY_BEACH (Beach with Temperature = 0)
    {
        name = "SNOWY_BEACH",
        ideal = { t = -0.7, h = 0.0, c = -0.1, e = 0.4, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.sand end,
        decorations = {}
    },
    -- [3] PLAINS
    {
        name = "PLAINS",
        ideal = { t = 0.1, h = 0.2, c = 0.2, e = 0.0, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 20 + 62) end,
        surface = function(x,y,z,surfaceY)
            if y == surfaceY then return blocks.grass end
            if y >= surfaceY - 3 then return blocks.dirt end
            return blocks.stone
        end,
        decorations = { { rate = 0.01, type = "tree" } }
    },
    -- [4] BEACH (Beach with Temperature = 1, 2, 3)
    {
        name = "BEACH",
        ideal = { t = 0.2, h = 0.1, c = -0.1, e = 0.5, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.sand end,
        decorations = {}
    },
    -- [5] DESERT / WARM BEACH (Temperature = 4)
    {
        name = "DESERT",
        ideal = { t = 0.9, h = -0.7, c = 0.3, e = 0.1, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 18 + 64) end,
        surface = function(x,y,z,surfaceY)
            if y >= surfaceY - 4 then return blocks.sand end
            return blocks.sandstone
        end,
        decorations = { { rate = 0.003, type = "desert_well" } }
    },
    -- [6] BADLANDS (Humidity H=0,1,2 and Low Erosion)
    {
        name = "BADLANDS",
        ideal = { t = 0.8, h = -0.4, c = 0.4, e = -0.6, w = -0.3, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 22 + 74) end,
        surface = function(x,y,z,surfaceY) return blocks.sandstone end,
        decorations = {}
    },
    -- [7] ERODED_BADLANDS (Humidity H=0,1 and Weirdness > 0)
    {
        name = "ERODED_BADLANDS",
        ideal = { t = 0.8, h = -0.5, c = 0.4, e = -0.7, w = 0.6, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 28 + 78) end,
        surface = function(x,y,z,surfaceY) return blocks.sandstone end,
        decorations = {}
    },
    -- [8] WOODED_BADLANDS (Humidity H=3,4)
    {
        name = "WOODED_BADLANDS",
        ideal = { t = 0.7, h = 0.6, c = 0.4, e = -0.5, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 16 + 72) end,
        surface = function(x,y,z,surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.006, type = "tree" } }
    },
    -- [9] MUSHROOM_FIELDS (High Continentalness Oceanic Islands)
    {
        name = "MUSHROOM_FIELDS",
        ideal = { t = 0.2, h = 0.5, c = -0.9, e = -0.1, w = 0.0, d = 0.0 },
        heightMap = function(baseH) return math.floor(baseH * 10 + 66) end,
        surface = function(x,y,z,surfaceY)
            if y == surfaceY then return blocks.dirt end -- Mycelium substitute
            return blocks.stone
        end,
        decorations = {}
    },

    -- SUBTERRANEAN CAVE BIOMES (Triggered dynamically by depth constraints)
    -- [10] DRIPSTONE_CAVES
    {
        name = "DRIPSTONE_CAVES",
        ranges = { c = {0.8, 1.0}, d = {0.2, 0.9} },
        heightMap = function() return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.sandstone end,
        decorations = {}
    },
    -- [11] LUSH_CAVES
    {
        name = "LUSH_CAVES",
        ranges = { h = {0.7, 1.0}, d = {0.2, 0.9} },
        heightMap = function() return 62 end,
        surface = function(x,y,z,surfaceY)
            if math.random() < 0.4 then return blocks.grass end
            return blocks.dirt
        end,
        decorations = {}
    },
    -- [12] SULFUR_CAVES
    {
        name = "SULFUR_CAVES",
        ranges = { w = {-1.1, -0.95}, d = {0.2, 0.9} },
        heightMap = function() return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.coal_ore end, -- Visual tracker substitute
        decorations = {}
    },
    -- [13] DEEP_DARK
    {
        name = "DEEP_DARK",
        ranges = { e = {-1.0, -0.375}, d = {1.1, 3.0} },
        heightMap = function() return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.cobblestone end,
        decorations = {}
    }
}

return biomes