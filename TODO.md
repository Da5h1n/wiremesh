Depth is a parameter not based directly on noise, instead it corresponds approximately to the terrain height. It is roughly 0 at the surface and increases by 1⁄128 (0.0078125) for every 1 block down. The depth parameter affects whether a surface biome or a cave biome is placed.

The table below lists the defined depth values for Overworld biomes, and any additional noise values required for cave biomes to generate. Any other values result in the closest biome interval being used instead. Note that regions of lush caves and dripstone caves overlap.

Depth	Additional requirement	Biomes
Any	N/A	Surface biomes
D=0.2~0.9	Continentalness=0.8~1.0	Dripstone Caves
D=0.2~0.9	Humidity=0.7~1.0	Lush Caves
D=0.2~0.9	Weirdness=-1.1~-0.95	Sulfur Caves​
D≥1.1	Erosion=-1.0~-0.375	Deep Dark

The generation of non-inland biomes is not based on humidity, erosion, or weirdness. The following table lists the relation between non-inland surface biomes and continentalness and temperature.

Temperature	Oceans	Deep oceans	Mushroom fields
T=0	Frozen Ocean	Deep Frozen Ocean	Mushroom Fields
T=1	Cold Ocean	Deep Cold Ocean Mushroom Fields
T=2	Ocean	Deep Ocean Mushroom Fields
T=3	Lukewarm Ocean	Deep Lukewarm Ocean Mushroom Fields
T=4	Warm Ocean Mushroom Fields

In which, the specific biome generation of beach biomes, badland biomes, middle biomes, plateau biomes, and shattered biomes is determined by the temperature, humidity, and weirdness values.

Beach biomes generate in low lying terrain along the coast, and the specific biome generation is related only to the temperature value.

T=0	Snowy Beach
T=1,2,3	Beach
T=4	Desert

Badland biomes usually generate inland with low erosion value, and can also generate along the coast with high terrain and low erosion. The specific biome generation is related to humidity and weirdness.

Humidity	Biomes
H=0,1	Badlands（W<0, Eroded Badlands（W>0）
H=2	Badlands
H=3,4	Wooded Badlands

other biomes are hard to paste in. as they rely on exact temperature and humididy .. etc


at this link: https://minecraft.wiki/w/World_generation

look at the lists.


need to add randimisation to :

deepslate spawn
bedrock spawn.

bedrock spawns randomly but has a cap at -64
BEDROCK HAS 5 LAYERS (THE LOWEST BEING COMPLETLEY SOLID) the 4 layers above have randomisation depending on seed.


Deepslate makes up the majority of the solid blocks generated below Y=0 in the Overworld. Stone is gradually replaced from Y=8 to Y=0 until it is completely replaced by deepslate.


in biome_definitions.lua We should allow ranges for the generation settings..





Weirdness (also known as ridges) affects whether to generate a biome variant or not, as well as whether or not terrain generates shattered. If the weirdness value is greater than 0, the generated biome becomes weirder. For example, weirdness could cause a jungle biome to become a bamboo jungle instead, or could cause a taiga to generate with more shattered terrain akin to a windswept savanna. A biome and its variant often do not appear on the same bank of a river.

The PV (peaks and valleys, aka. ridges folded) value is calculated through the formula 

1−|(3|weirdness|)−2|

If -1.0~-0.85: Valleys
If -0.85~-0.2: Low
If -0.2~0.2: Mid
If 0.2~0.7: High
If 0.7~1.0: Peaks










BELOW OLD BIOMES LIST:

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
        decorations = { 
            { rate = 0.02,  type = "cactus" },
            { rate = 0.001, type = "desert_well" } 
        }
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



}