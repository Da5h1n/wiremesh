local textures = {}

-- Palette Aliases (16+ indices for custom colors)
local C = {
    G1 = 16, G2 = 17, -- Grass (Lime, Green)
    D1 = 18, D2 = 19, -- Dirt (Brown, Dark Brown)
    S1 = 20, S2 = 21, -- Stone (Gray, Light Gray)
    W1 = 22, W2 = 23, -- Water (Blue, Light Blue)
    W3 = 24,          -- Water/Ice (White/Cyan)
    O1 = 25, O2 = 26, -- Ores (Highlight, Base)
    WD1 = 27, WD2 = 28, -- Wood (Brown, Orange)
    L1 = 29, L2 = 30, -- Leaves (Green, Dark Green)

        -- Terracotta Colors (16)
    T_WHITE = 31,
    T_ORANGE = 32,
    T_MAGENTA = 33,
    T_LIGHT_BLUE = 34,
    T_YELLOW = 35,
    T_LIME = 36,
    T_PINK = 37,
    T_GRAY = 38,
    T_LIGHT_GRAY = 39,
    T_CYAN = 40,
    T_PURPLE = 41,
    T_BLUE = 42,
    T_BROWN = 43,
    T_GREEN = 44,
    T_RED = 45,
    T_BLACK = 46,

    -- Wood Types (6)
    WOAK = 47,
    WBIRCH = 48,
    WSPRUCE = 49,
    WJUNGLE = 50,
    WACACIA = 51,
    WDARKOAK = 52,

    -- Ore Colors (4)
    O_COAL = 53,
    O_IRON = 54,
    O_GOLD = 55,
    O_DIAMOND = 56,

    -- Sandstone / Red Sand Variants (4)
    SAND1 = 57,
    SAND2 = 58,
    RSAND1 = 59,
    RSAND2 = 60,

}

-- Initialize colors in CraftOS Mode 2 (Call this on startup!)
function textures.initPalette()
    term.setPaletteColor(C.G1, 0.4, 0.8, 0.2)  -- Vibrant Grass
    term.setPaletteColor(C.G2, 0.2, 0.5, 0.1)  -- Dark Grass
    term.setPaletteColor(C.D1, 0.4, 0.25, 0.1) -- Dirt
    term.setPaletteColor(C.D2, 0.25, 0.15, 0.05) -- Dark Dirt
    term.setPaletteColor(C.S1, 0.3, 0.3, 0.3)  -- Gray Stone
    term.setPaletteColor(C.S2, 0.5, 0.5, 0.5)  -- Light Gray
    term.setPaletteColor(C.W1, 0.1, 0.3, 0.8)  -- Blue
    term.setPaletteColor(C.W2, 0.2, 0.5, 0.9)  -- Light Blue
    term.setPaletteColor(C.WD1, 0.5, 0.3, 0.1) -- Wood Base
    term.setPaletteColor(C.WD2, 0.6, 0.4, 0.2) -- Wood Highlight
    term.setPaletteColor(C.L1, 0.1, 0.6, 0.1)  -- Leaves
    term.setPaletteColor(C.L2, 0.0, 0.3, 0.0)  -- Dark Leaves
        -- Terracotta Colors
    term.setPaletteColor(C.T_WHITE, 0.90, 0.90, 0.90)
    term.setPaletteColor(C.T_ORANGE, 0.85, 0.45, 0.10)
    term.setPaletteColor(C.T_MAGENTA, 0.80, 0.20, 0.60)
    term.setPaletteColor(C.T_LIGHT_BLUE, 0.40, 0.60, 0.90)
    term.setPaletteColor(C.T_YELLOW, 0.95, 0.85, 0.20)
    term.setPaletteColor(C.T_LIME, 0.50, 0.80, 0.20)
    term.setPaletteColor(C.T_PINK, 0.95, 0.60, 0.70)
    term.setPaletteColor(C.T_GRAY, 0.30, 0.30, 0.30)
    term.setPaletteColor(C.T_LIGHT_GRAY, 0.60, 0.60, 0.60)
    term.setPaletteColor(C.T_CYAN, 0.10, 0.50, 0.60)
    term.setPaletteColor(C.T_PURPLE, 0.50, 0.20, 0.70)
    term.setPaletteColor(C.T_BLUE, 0.20, 0.30, 0.70)
    term.setPaletteColor(C.T_BROWN, 0.40, 0.25, 0.10)
    term.setPaletteColor(C.T_GREEN, 0.20, 0.40, 0.20)
    term.setPaletteColor(C.T_RED, 0.70, 0.20, 0.20)
    term.setPaletteColor(C.T_BLACK, 0.10, 0.10, 0.10)

    -- Wood Types
    term.setPaletteColor(C.WOAK, 0.55, 0.35, 0.15)
    term.setPaletteColor(C.WBIRCH, 0.90, 0.85, 0.70)
    term.setPaletteColor(C.WSPRUCE, 0.30, 0.20, 0.10)
    term.setPaletteColor(C.WJUNGLE, 0.65, 0.45, 0.25)
    term.setPaletteColor(C.WACACIA, 0.80, 0.45, 0.20)
    term.setPaletteColor(C.WDARKOAK, 0.20, 0.10, 0.05)

    -- Ore Colors
    term.setPaletteColor(C.O_COAL, 0.15, 0.15, 0.15)
    term.setPaletteColor(C.O_IRON, 0.80, 0.50, 0.20)
    term.setPaletteColor(C.O_GOLD, 1.00, 0.85, 0.20)
    term.setPaletteColor(C.O_DIAMOND, 0.50, 0.90, 1.00)

    -- Sandstone / Red Sand
    term.setPaletteColor(C.SAND1, 0.90, 0.75, 0.50)
    term.setPaletteColor(C.SAND2, 0.95, 0.85, 0.65)
    term.setPaletteColor(C.RSAND1, 0.80, 0.40, 0.20)
    term.setPaletteColor(C.RSAND2, 0.90, 0.50, 0.30)

end

-- 8x8 Textures
textures.grass_top = {
    {C.G1, C.G1, C.G2, C.G2, C.G1, C.G1, C.G2, C.G2},
    {C.G1, C.G2, C.G2, C.G1, C.G1, C.G2, C.G2, C.G1},
    {C.G2, C.G1, C.G1, C.G2, C.G2, C.G1, C.G1, C.G2},
    {C.G2, C.G1, C.G2, C.G1, C.G1, C.G2, C.G1, C.G2},
    {C.G1, C.G1, C.G2, C.G2, C.G1, C.G1, C.G2, C.G2},
    {C.G1, C.G2, C.G2, C.G1, C.G1, C.G2, C.G2, C.G1},
    {C.G2, C.G1, C.G1, C.G2, C.G2, C.G1, C.G1, C.G2},
    {C.G2, C.G1, C.G2, C.G1, C.G1, C.G2, C.G1, C.G2},
}

textures.grass_side = {
    {C.G2, C.G1, C.G1, C.G2, C.G1, C.G1, C.G2, C.G1},
    {C.G1, C.G2, C.G1, C.G1, C.G2, C.G1, C.G1, C.G2},
    {C.G1, C.G1, C.G2, C.G1, C.G1, C.G2, C.G1, C.G1},
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
    {C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1},
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
}


textures.dirt = {
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
    {C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1},
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
    {C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1},
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
}

textures.stone = {
    {C.S1, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S1},
    {C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S1, C.S2},
    {C.S2, C.S1, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1},
    {C.S1, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S1},
    {C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S1, C.S2},
    {C.S2, C.S1, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1},
    {C.S1, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S1},
    {C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S1, C.S2},
}

textures.grass_side = {
    {C.G2, C.G1, C.G1, C.G2, C.G1, C.G1, C.G2, C.G1},
    {C.G1, C.G2, C.G1, C.G1, C.G2, C.G1, C.G1, C.G2},
    {C.G1, C.G1, C.G2, C.G1, C.G1, C.G2, C.G1, C.G1},
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
    {C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1},
    {C.D1, C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1},
    {C.D1, C.D2, C.D1, C.D1, C.D2, C.D1, C.D1, C.D2},
}


textures.wood = {
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
}

textures.leaves = {
    {C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1},
    {C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2},
    {C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1},
    {C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2},
    {C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1},
    {C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2},
    {C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1},
    {C.L1, C.L2, C.L1, C.L2, C.L1, C.L2, C.L1, C.L2},
}

textures.sand = {
    {C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD2, C.WD1, C.WD2, C.WD2, C.WD1},
}

textures.sandstone = {
    {C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD1, C.WD2, C.WD1, C.WD1, C.WD2},
}

textures.snow = {
    {C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3},
    {C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2},
    {C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3},
    {C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3},
    {C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2},
    {C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3},
    {C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3},
    {C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2},
}

textures.gravel = {
    {C.S2, C.S1, C.S2, C.S1, C.S2, C.S1, C.S2, C.S1},
    {C.S1, C.S2, C.S1, C.S2, C.S1, C.S2, C.S1, C.S2},
    {C.S2, C.S1, C.S1, C.S2, C.S2, C.S1, C.S1, C.S2},
    {C.S1, C.S2, C.S2, C.S1, C.S1, C.S2, C.S2, C.S1},
    {C.S2, C.S1, C.S2, C.S1, C.S2, C.S1, C.S2, C.S1},
    {C.S1, C.S2, C.S1, C.S2, C.S1, C.S2, C.S1, C.S2},
    {C.S2, C.S1, C.S1, C.S2, C.S2, C.S1, C.S1, C.S2},
    {C.S1, C.S2, C.S2, C.S1, C.S1, C.S2, C.S2, C.S1},
}

textures.clay = {
    {C.S2, C.S2, C.S1, C.S2, C.S2, C.S1, C.S2, C.S2},
    {C.S2, C.S1, C.S2, C.S2, C.S1, C.S2, C.S2, C.S1},
    {C.S1, C.S2, C.S2, C.S1, C.S2, C.S2, C.S1, C.S2},
    {C.S2, C.S2, C.S1, C.S2, C.S2, C.S1, C.S2, C.S2},
    {C.S2, C.S1, C.S2, C.S2, C.S1, C.S2, C.S2, C.S1},
    {C.S1, C.S2, C.S2, C.S1, C.S2, C.S2, C.S1, C.S2},
    {C.S2, C.S2, C.S1, C.S2, C.S2, C.S1, C.S2, C.S2},
    {C.S2, C.S1, C.S2, C.S2, C.S1, C.S2, C.S2, C.S1},
}

textures.water = {
    {C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2},
    {C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1},
    {C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2},
    {C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1},
    {C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2},
    {C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1},
    {C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2},
    {C.W2, C.W1, C.W2, C.W1, C.W2, C.W1, C.W2, C.W1},
}

textures.marker_orange = {
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
}

textures.marker_magenta = {
    {C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2},
    {C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1},
    {C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2},
    {C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1},
    {C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2},
    {C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1},
    {C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2},
    {C.O2, C.O1, C.O2, C.O1, C.O2, C.O1, C.O2, C.O1},
}

textures.bedrock = {
    {C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S2, C.S1},
    {C.S2, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S2},
    {C.S1, C.S1, C.S2, C.S2, C.S1, C.S1, C.S2, C.S1},
    {C.S2, C.S1, C.S1, C.S2, C.S2, C.S1, C.S1, C.S2},
    {C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S2, C.S1},
    {C.S2, C.S1, C.S2, C.S1, C.S1, C.S2, C.S1, C.S2},
    {C.S1, C.S1, C.S2, C.S2, C.S1, C.S1, C.S2, C.S1},
    {C.S2, C.S1, C.S1, C.S2, C.S2, C.S1, C.S1, C.S2},
}

textures.ice = {
    {C.W3, C.W2, C.W3, C.W2, C.W3, C.W2, C.W3, C.W2},
    {C.W2, C.W3, C.W2, C.W3, C.W2, C.W3, C.W2, C.W3},
    {C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3},
    {C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3},
    {C.W3, C.W2, C.W3, C.W2, C.W3, C.W2, C.W3, C.W2},
    {C.W2, C.W3, C.W2, C.W3, C.W2, C.W3, C.W2, C.W3},
    {C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3, C.W3},
    {C.W2, C.W3, C.W3, C.W2, C.W3, C.W3, C.W2, C.W3},
}

textures.red_sand = {
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
}

textures.red_sandstone = {
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
    {C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1},
    {C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2, C.WD1, C.WD2},
}



return textures