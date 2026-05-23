local blocks = require("blocks")
local structures = require("structures")

local biomes = {}

ANY = {-1.0, 1.0}
NONE = {0,0}

T0 = {-1.0, -0.45}   -- frozen
T1 = {-0.45, -0.15}  -- cold
T2 = {-0.15, 0.2}    -- neutral
T3 = {0.2, 0.55}     -- warm
T4 = {0.55, 1.0}     -- hot

H0 = {-1.0, -0.35}   -- driest
H1 = {-0.35, -0.1}
H2 = {-0.1, 0.1}
H3 = {0.1, 0.3}
H4 = {0.3, 1.0}      -- wettest

MUSHROOM_FIELDS = {-1.2, -1.05}

DEEP_OCEAN = {-1.2, -0.51}
OCEAN       = {-0.51, -0.19}

COAST       = {-0.19, -0.11}

NEAR_INLAND = {-0.11, 0.03}
MID_INLAND  = {0.03, 0.3}
FAR_INLAND  = {0.3, 1.0}

E0 = {-1.0, -0.78}      -- extreme mountains
E1 = {-0.78, -0.375}
E2 = {-0.375, -0.2225}
E3 = {-0.2225, 0.05}
E4 = {0.05, 0.45}
E5 = {0.45, 0.55}
E6 = {0.55, 1.0}        -- very flat

SURFACE      = {0,0}

SHALLOW_CAVE = {0.2, 0.9}

DEEP_CAVE    = {1.1, 3.0}


biomes.list = {
    -- OCEAN BIOMES
    {
        name = "FROZEN_OCEAN",
        ranges = { t = T0, h = ANY, c = OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(52 + baseH * 10)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },
    {
        name = "DEEP_FROZEN_OCEAN",
        ranges = { t = T0, h = ANY, c = DEEP_OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(30 + baseH * 15)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },

    {
        name = "COLD_OCEAN",
        ranges = { t = T1, h = ANY, c = OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(52 + baseH * 10)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },
    {
        name = "DEEP_COLD_OCEAN",
        ranges = { t = T1, h = ANY, c = DEEP_OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(30 + baseH * 15)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },

    {
        name = "OCEAN",
        ranges = { t = T2, h = ANY, c = OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(52 + baseH * 10)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },
    {
        name = "DEEP_OCEAN",
        ranges = { t = T2, h = ANY, c = DEEP_OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(30 + baseH * 15)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },

    {
        name = "LUKEWARM_OCEAN",
        ranges = { t = T3, h = ANY, c = OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(52 + baseH * 10)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },
    {
        name = "DEEP_LUKEWARM_OCEAN",
        ranges = { t = T3, h = ANY, c = DEEP_OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(30 + baseH * 15)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },

    {
        name = "WARM_OCEAN",
        ranges = { t = T4, h = ANY, c = OCEAN, e = ANY, w = ANY, d = SURFACE },
        heightMap = function(baseH)
            return math.floor(52 + baseH * 10)
        end,
        surface = function(x, y, z, surfaceY) return blocks.stone end,
        decorations = {}
    },

    --BEACHES
    {
        name = "SNOWY_BEACH",
        ranges = { t = T0, h = ANY, c = COAST, e = E6, w = {-1.0, 0.0}, d = {0.0, 0.2} },
        heightMap = function(baseH) return math.floor(62 + baseH * 2) end,
        surface = function(x, y, z, surfaceY) return blocks.sand end,
        decorations = {}
    },
    {
        name = "BEACH",
        ranges = { t = {T1[1], T3[2]}, h = ANY, c = COAST, e = E6, w = {-1.0, 0.0}, d = {0.0, 0.2} },
        heightMap = function(baseH) return math.floor(62 + baseH * 2) end,
        surface = function(x, y, z, surfaceY)
            if y >= surfaceY - 3 then return blocks.sand end
            return blocks.sandstone
        end,
        decorations = {}
    },

    -- VALLEY AND FLATLAND BIOMES

    {
        name = "PLAINS",
        ranges = {
            { t = {T1[1], T3[2]}, h = {H1[1], H3[2]}, c = {NEAR_INLAND[1], 1.0}, e = {E4[1], E6[2]}, w = ANY, d = SURFACE },
            { t = T1, h = H0, c = {NEAR_INLAND[1], MID_INLAND[2]}, e = ANY, w = ANY, d = SURFACE},
            { t = T3, h = H2, c = {NEAR_INLAND[1], 1.0}, e = ANY, w = {0, 1.0}, d = SURFACE}
        },
        heightMap = function(baseH)
            return math.floor(64 + baseH * 4)
        end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.005, type = "tree" } }
    },
    {
        name = "SUNFLOWER_PLAINS",
        ranges = {
            { t = T2, h = {H1[1], H2[2]}, c = {MID_INLAND[1], 1.0}, e = {E4[1], E5[2]}, w = {0.3, 1.0}, d = SURFACE},

            {t = T2, h = H0, c = NEAR_INLAND, e = ANY, w = {0, 1.0}, d = SURFACE}
        },
        heightMap = function(baseH) return math.floor(64 + baseH * 3) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = {} 
    },
    {
        name = "FLOWER_FOREST",
        ranges = {
            { t = T2, h = H0, c = NEAR_INLAND, e = ANY, w = {-1.0, 0.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(66 + baseH * 5) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.02, type = "tree" } }
    },
    {
        name = "SWAMP",
        ranges = {
            { t = T3, h = H4, c = {COAST[1], 1.0}, e = {E4[1], E6[2]}, w = ANY, d = SURFACE}
        },
        heightMap = function(baseH) return math.floor(62 + baseH * 2) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.04, type = "swamp_tree" } }
    },
    {
        name = "MANGROVE_SWAMP",
        -- The hot, hyper-humid alternative valley basin
        ranges = {
            { t = T4, h = H4, c = {COAST[1], 1.0}, e = {E4[1], E6[2]}, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(61 + baseH * 2) end,
        surface = function(x, y, z, surfaceY)
            return blocks.mud
        end,
        decorations = { { rate = 0.06, type = "mangrove_tree" } }
    },
    {
        name = "DESERT",
        -- The opposite extreme of swamps: Hot, bone-dry valleys and dune fields
        ranges = {
            { t = T4, h = H0, c = {NEAR_INLAND[1], 1.0}, e = {E4[1], E6[2]}, w = ANY, d = SURFACE },
            { t = T4, h = {H0[1], H4[2]}, c = {FAR_INLAND[1], 1.0}, e = {E5[1], E6[2]}, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Rolling desert dunes
            return math.floor(65 + baseH * 6) 
        end,
        surface = function(x, y, z, surfaceY)
            if y >= surfaceY - 3 then return blocks.sand end
            return blocks.sandstone
        end,
        decorations = {} -- Cactus/dead bush distribution layers
    },
    {
        name = "SAVANNA",
        -- Warm, dry-to-neutral flatlands transitional to deserts
        ranges = {
            { t = T3, h = H0, c = {NEAR_INLAND[1], 1.0}, e = {E4[1], E6[2]}, w = ANY, d = SURFACE },
            { t = {T3[1], T4[2]}, h = H1, c = {NEAR_INLAND[1], 1.0}, e = {E4[1], E6[2]}, w = ANY, d = SURFACE },
            { t = T3, h = {H0[1], H1[2]}, c = {NEAR_INLAND[1], 1.0}, e = ANY, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(64 + baseH * 4) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.01, type = "acacia_tree" } }
    },
    {
        name = "WINDSWEPT_SAVANNA",
        -- Highly dynamic variant appearing where erosion lessens slightly alongside high weirdness
        ranges = {
            { t = T3, h = H0, c = {MID_INLAND[1], 1.0}, e = E3, w = {0.4, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Aggressive windswept cliffs breaking out of flat terrain
            return math.floor(72 + baseH * 22) 
        end,
        surface = function(x, y, z, surfaceY)
            if math.random() < 0.2 then return blocks.stone end
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.01, type = "acacia_tree" } }
    },


    --PLATEU BIOMES:
    {
        name = "SNOWY_PLAINS",
        ranges = {
            { t = T0, h = {H0[1], H2[2]}, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T0, h = {H0[1], H2[2]}, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE  },
            { t = T0, h = {H0[1], H2[2]}, c = {NEAR_INLAND[1], MID_INLAND[2]}, e = ANY, w = {-1.0, 0.0}, d = {0.0, 0.3} }
        },
        heightMap = function(baseH) return math.floor(78 + baseH * 6) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = {}
    },
    {
        name = "ICE_SPIKES",
        ranges = {
            { t = T0, h = H0, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T0, h = H0, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE },
            { t = T0, h = H0, c = {NEAR_INLAND[1], MID_INLAND[2]}, e = ANY, w = {0, 1.0}, d = SURFACE}
        },
        heightMap = function(baseH) return math.floor(84 + baseH * 28) end, -- Jagged values
        surface = function(x, y, z, surfaceY)
            if y >= surfaceY - 4 then return blocks.cobblestone end -- Substitute for ice blocks
            return blocks.stone
        end,
        decorations = {}
    },
    {
        name = "MEADOW",
        ranges = {
            { t = {T1[1], T2[2]}, h = {H0[1], H1[2]}, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = {T1[1], T2[2]}, h = {H0[1], H1[2]}, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE },
            -- Variant slice fallbacks for neutral temperatures
            { t = T2, h = {H2[1], H3[2]}, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T2, h = {H2[1], H3[2]}, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Rolling alpine meadows sitting high in mountain passes
            return math.floor(82 + baseH * 10) 
        end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = {} -- Vanilla meadows primarily generate a dense layer of flowers
    },
    {
        name = "CHERRY_GROVE",
        -- PLATEAU_BIOMES_VARIANT Row 1: Col 0 | Row 2: Cols 0, 1 (Positive weirdness)
        ranges = {
            { t = T1, h = H0, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T1, h = H0, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE },
            { t = T2, h = {H0[1], H1[2]}, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T2, h = {H0[1], H1[2]}, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Elevated mountain terraces
            return math.floor(80 + baseH * 12) 
        end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.05, type = "tree" } }
    },
    {
        name = "SAVANNA_PLATEAU",
        -- PLATEAU_BIOMES Row 3 (Warm): Cols 0, 1
        ranges = {
            { t = T3, h = {H0[1], H1[2]}, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T3, h = {H0[1], H1[2]}, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Classic flat tableland! Heavy base offset with barely any multiplier vertical variance
            return math.floor(92 + baseH * 3) 
        end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.02, type = "tree" } }
    },
    {
        name = "BADLANDS",
        -- PLATEAU_BIOMES Row 4 (Hot): Cols 0, 1, 2 (Negative weirdness base)
        ranges = {
            { t = T4, h = {H0[1], H2[2]}, c = {0.03, 1.0}, e = E2, w = {-1.0, 0.0}, d = SURFACE },
            { t = T4, h = {H0[1], H2[2]}, c = FAR_INLAND, e = E3, w = {-1.0, 0.0}, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Layered high terracotta structures
            return math.floor(86 + baseH * 8) 
        end,
        surface = function(x, y, z, surfaceY) 
            return blocks.red_sandstone 
        end,
        decorations = {}
    },
    {
        name = "ERODED_BADLANDS",
        -- PLATEAU_BIOMES_VARIANT Row 4 (Hot): Cols 0, 1 (Positive weirdness variant)
        ranges = {
            { t = T4, h = {H0[1], H1[2]}, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T4, h = {H0[1], H1[2]}, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) 
            -- Highly jagged, deep canyons gouging through the elevated badlands plateau
            return math.floor(82 + baseH * 26) 
        end,
        surface = function(x, y, z, surfaceY) 
            return blocks.red_sandstone 
        end,
        decorations = {}
    },
    {
        name = "FOREST",
        ranges = {
            -- Row 1 & 2 Neutral/Cold forested plateau zones
            { t = T1, h = H2, c = {0.03, 1.0}, e = E2, w = {-1.0, 0.0}, d = SURFACE },
            { t = T1, h = H2, c = FAR_INLAND, e = E3, w = {-1.0, 0.0}, d = SURFACE },
            { t = T2, h = H2, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T2, h = H2, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE },
            -- Row 3 Warm forested plateaus (Humidities 2 & 3)
            { t = T3, h = {H2[1], H3[2]}, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T3, h = {H2[1], H3[2]}, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE },

            { t = {T1[1], T2[2]}, h = H2, c = FAR_INLAND, e = ANY, w = ANY, d = SURFACE},
            { t = T3, h = H2, c = {NEAR_INLAND[1], 1.0}, e = ANY, w = {-1.0,0}, d = SURFACE}
        },
        heightMap = function(baseH) return math.floor(76 + baseH * 8) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.04, type = "tree" } }
    },
    {
        name = "SNOWY_TAIGA",
        -- PLATEAU_BIOMES Row 0: Cols 3 & 4
        ranges = {
            { t = T0, h = {H3[1], H4[2]}, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T0, h = {H3[1], H4[2]}, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE },
            { t = T0, h = {H2[1], H3[2]}, c = {NEAR_INLAND[1], MID_INLAND[2]}, e = ANY, w = {0.0, 1.0}, d = SURFACE}
        },
        heightMap = function(baseH) return math.floor(78 + baseH * 10) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.06, type = "tree" } }
    },
    {
        name = "TAIGA",
        -- PLATEAU_BIOMES Row 1: Cols 3 & 4 (Negative weirdness base)
        ranges = {
            { t = T1, h = H3, c = {0.03, 1.0}, e = E2, w = {-1.0, 0.0}, d = SURFACE },
            { t = T1, h = H3, c = FAR_INLAND, e = E3, w = {-1.0, 0.0}, d = SURFACE },
            { t = T0, h = H4, c = {NEAR_INLAND[1], MID_INLAND[2]}, e = ANY, w = ANY, d = SURFACE},

            {t = T1, h = H3, c = FAR_INLAND, e = ANY, w = ANY, d = SURFACE}
        },
        heightMap = function(baseH) return math.floor(76 + baseH * 12) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.05, type = "tree" } }
    },
    {
        name = "BIRCH_FOREST",
        -- PLATEAU_BIOMES_VARIANT Row 2: Col 3 (Positive weirdness variant)
        ranges = {
            { t = T2, h = H3, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T2, h = H3, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE },

            { t = T2, h = H3, c = {NEAR_INLAND[1], FAR_INLAND[2]}, e = ANY, w = {-1.0, 0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(75 + baseH * 9) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.04, type = "tree" } }
    },
    {
        name = "OLD_GROWTH_BIRCH_FOREST",
        ranges = {
            { t = T2, h = H3, c = {NEAR_INLAND[1], FAR_INLAND[2]}, e = ANY, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(78 + baseH * 11) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.05, type = "tall_birch_tree" } }
    },
    {
        name = "DARK_FOREST",
        ranges = {
            { t = T2, h = H4, c = {NEAR_INLAND[1], 1.0}, e = {E2[1], E4[2]}, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(74 + baseH * 6) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.08, type = "dark_oak_tree" } }
    },
    {
        name = "WOODED_BADLANDS",
        -- PLATEAU_BIOMES Row 4: Cols 3 & 4
        ranges = {
            { t = T4, h = {H3[1], H4[2]}, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T4, h = {H3[1], H4[2]}, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(88 + baseH * 6) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.03, type = "tree" } }
    },
    {
        name = "OLD_GROWTH_SPRUCE_TAIGA",
        -- PLATEAU_BIOMES Row 1: Col 4 (Negative weirdness base)
        ranges = {
            { t = T1, h = H4, c = {0.03, 1.0}, e = E2, w = {-1.0, 0.0}, d = SURFACE },
            { t = T1, h = H4, c = FAR_INLAND, e = E3, w = {-1.0, 0.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(82 + baseH * 14) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.07, type = "tree" } }
    },
    {
        name = "OLD_GROWTH_PINE_TAIGA",
        -- PLATEAU_BIOMES_VARIANT Row 1: Col 4 (Positive weirdness variant)
        ranges = {
            { t = T1, h = H4, c = {0.03, 1.0}, e = E2, w = {0.0, 1.0}, d = SURFACE },
            { t = T1, h = H4, c = FAR_INLAND, e = E3, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(82 + baseH * 14) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.07, type = "tree" } }
    },
    {
        name = "PALE_GARDEN",
        -- PLATEAU_BIOMES Row 2: Col 4 (Wettest slice)
        ranges = {
            { t = T2, h = H4, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T2, h = H4, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(72 + baseH * 5) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.06, type = "tree" } }
    },
    {
        name = "JUNGLE",
        -- PLATEAU_BIOMES Row 3: Col 4 (Hot & Wet plateau variant)
        ranges = {
            { t = T3, h = H4, c = {0.03, 1.0}, e = E2, w = ANY, d = SURFACE },
            { t = T3, h = H4, c = FAR_INLAND, e = E3, w = ANY, d = SURFACE },

            { t = T3, h = {H3[1], H4[2]}, c = {NEAR_INLAND[1], 1.0}, e = ANY, w = {-1.0, 0.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(84 + baseH * 15) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.08, type = "tree" } }
    },
    {
        name = "SPARSE_JUNGLE",
        ranges = {
            { t = T3, h = H3, c = {NEAR_INLAND[1], 1.0}, e = ANY, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(78 + baseH * 8) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.02, type = "tree" } }
    },
    {
        name = "BAMBOO_JUNGLE",
        ranges = {
            { t = T3, h = H4, c = {NEAR_INLAND[1], 1.0}, e = ANY, w = {0.0, 1.0}, d = SURFACE }
        },
        heightMap = function(baseH) return math.floor(80 + baseH * 10) end,
        surface = function(x, y, z, surfaceY)
            if y == surfaceY then return blocks.grass end
            return blocks.dirt
        end,
        decorations = { { rate = 0.1, type = "bamboo" } }
    },

    
    {
        -- SUBTERRANEAN CAVE BIOMES (Triggered dynamically by depth constraints)
        name = "DRIPSTONE_CAVES",
        ranges = { t = ANY, h = ANY, c = {0.8, 1.0}, e = ANY, w = ANY, d = {0.2, 0.9} },
        heightMap = function(baseH) return math.floor(62 + baseH * 15) end,
        surface = function(x, y, z, surfaceY)
            return blocks.sandstone
        end,
        decorations = {
            { rate = 0.04, type = "dripstone" }
        }
    },
    {
        name = "LUSH_CAVES",
        ranges = { t = ANY, h = {0.7, 1.0}, c = ANY, e = ANY, w = ANY, d = {0.2, 0.9} },
        heightMap = function(baseH) return math.floor(62 + baseH * 10) end,
        surface = function(x, y, z, surfaceY)
            if math.random() < 0.4 then return blocks.grass end
            return blocks.dirt
        end,
        decorations = {}
    },
    {
        name = "SULFUR_CAVES",
        -- Triggers underground when local weirdness sits outside typical valley zones
        ranges = { t = {-1.5, 1.5}, h = {-1.5, 1.5}, c = {-1.5, 1.5}, e = {-1.5, 1.5}, w = {-1.1, 0.95}, d = {0.2, 0.9} },
        heightMap = function(baseH) return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.stone end, -- Fallback
        decorations = {
            { rate = 0.04, type = "dripstone" }
        }
    },
    {
        name = "DEEP_DARK",
        -- Matches D >= 1.1: Triggers strictly deep under jagged, low-erosion mountain roots
        ranges = { t = ANY, h = ANY, c = ANY, e = {-1.0, -0.225}, w = ANY, d = {0.9, 3.0} },
        heightMap = function(baseH) return 62 end,
        surface = function(x,y,z,surfaceY) return blocks.deepslate end, -- Fallback
        decorations = {}
    }
}







return biomes