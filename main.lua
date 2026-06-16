local renderer = require("renderer")
local world = require("world")
local m = require("math3d")
local perlin = require("perlin")
local shapes = require("shapes")
local textures = require("textures")
local blocks = require("blocks")

local APP_VERSION = "0.3.1"
local runningProgram = shell and shell.getRunningProgram and shell.getRunningProgram() or "main.lua"
local PROGRAM_DIR = fs.getDir(runningProgram)
if PROGRAM_DIR == "" then
    PROGRAM_DIR = "."
end
local WORLD_DIR = fs.combine(PROGRAM_DIR, "worlds")
local GLOBAL_SETTINGS_FILE = fs.combine(PROGRAM_DIR, "settings.wmesh")
local PROPERTIES_FILE = "world.wmesh"
local LEGACY_PROPERTIES_FILE = "properties.lua"

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

local function loadGlobalSettings()
    if fs.exists(GLOBAL_SETTINGS_FILE) then
        local file = fs.open(GLOBAL_SETTINGS_FILE, "r")
        if file then
            local info = unserializeTable(file.readAll())
            file.close()
            if type(info) == "table" then
                info.renderDistance = tonumber(info.renderDistance) or 5
                return info
            end
        end
    end
    return { version = APP_VERSION, renderDistance = 5 }
end

local function saveGlobalSettings(settings)
    local file = fs.open(GLOBAL_SETTINGS_FILE, "w")
    if not file then return false end
    settings.version = APP_VERSION
    file.write(serializeTable(settings))
    file.close()
    return true
end

local globalSettings = loadGlobalSettings()

local function parseSeed(inputSeed)
    if not inputSeed or inputSeed == "" then
        return nil
    end

    local numericSeed = tonumber(inputSeed)
    if numericSeed then
        return numericSeed
    end

    numericSeed = 0
    for i = 1, #inputSeed do
        numericSeed = numericSeed + inputSeed:byte(i) * (31 ^ (#inputSeed - i))
    end
    return numericSeed
end

local function safeWorldId(name)
    local id = (name or ""):lower():gsub("[^%w%-_ ]", ""):gsub("%s+", "_")
    if id == "" then
        id = "world_" .. tostring(os.epoch("utc"))
    end
    return id
end

local function ensureWorldDir()
    if not fs.exists(WORLD_DIR) then
        fs.makeDir(WORLD_DIR)
    end
end

local function worldFolder(id)
    return fs.combine(WORLD_DIR, id)
end

local function worldPropertiesPath(id)
    return fs.combine(worldFolder(id), PROPERTIES_FILE)
end

local function worldChunksPath(id)
    return fs.combine(worldFolder(id), "chunks")
end

local function ensureWorldFolder(id)
    ensureWorldDir()
    local folder = worldFolder(id)
    if not fs.exists(folder) then
        fs.makeDir(folder)
    end
    local chunks = worldChunksPath(id)
    if not fs.exists(chunks) then
        fs.makeDir(chunks)
    end
end

local function saveWorldInfo(info)
    ensureWorldFolder(info.id)
    info.version = APP_VERSION
    info.saveFormat = "wmesh-world"
    info.chunkFormat = world.chunkSaveFormat
    info.updated = os.epoch("utc")
    info.settings = info.settings or {}
    info.settings.seed = info.seed

    local file = fs.open(worldPropertiesPath(info.id), "w")
    if not file then
        return false
    end
    file.write(serializeTable(info))
    file.close()
    return true
end

local function migrateWorldInfo(info)
    if type(info) ~= "table" then
        return nil
    end

    info.id = info.id or safeWorldId(info.name)
    info.name = info.name or info.id or "World"
    info.seed = info.seed or (info.settings and info.settings.seed) or os.epoch("utc")
    info.created = info.created or os.epoch("utc")
    info.settings = info.settings or {}
    info.settings.seed = info.seed
    info.settings.renderDistance = tonumber(info.settings.renderDistance) or tonumber(globalSettings.renderDistance) or 5
    info.settings.gamemode = info.settings.gamemode or info.gamemode or "creative"
    info.gamemode = info.settings.gamemode
    info.player = info.player or {}
    info.player.x = info.player.x or 560
    info.player.y = info.player.y or 62
    info.player.z = info.player.z or 576
    info.player.yaw = info.player.yaw or 0
    info.player.pitch = info.player.pitch or m.deg2rad(-10)
    info.inventory = info.inventory or {}
    info.saveFormat = "wmesh-world"
    info.version = info.version or "legacy"

    return info
end

local function loadWorldInfo(path)
    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    if not file then
        return nil
    end
    local contents = file.readAll()
    file.close()

    local info = unserializeTable(contents)
    if type(info) ~= "table" then
        return nil
    end
    return migrateWorldInfo(info)
end

local function listWorlds()
    ensureWorldDir()
    local worlds = {}
    local seen = {}
    local indexes = {}
    for _, fileName in ipairs(fs.list(WORLD_DIR)) do
        local path = fs.combine(WORLD_DIR, fileName)
        if fs.isDir(path) then
            local info = loadWorldInfo(fs.combine(path, PROPERTIES_FILE))
            if not info then
                info = loadWorldInfo(fs.combine(path, LEGACY_PROPERTIES_FILE))
            end
            if info and info.id and info.seed then
                if seen[info.id] then
                    worlds[indexes[info.id]] = info
                else
                    seen[info.id] = true
                    indexes[info.id] = #worlds + 1
                    worlds[#worlds + 1] = info
                end
            end
        else
            local info = loadWorldInfo(path)
            if info and info.id and info.seed and not seen[info.id] then
                seen[info.id] = true
                indexes[info.id] = #worlds + 1
                worlds[#worlds + 1] = info
            end
        end
    end

    table.sort(worlds, function(a, b)
        return (a.name or a.id):lower() < (b.name or b.id):lower()
    end)

    return worlds
end

local function resetTerminal()
    if term.setGraphicsMode then
        term.setGraphicsMode(0)
    end
    term.setBackgroundColor(colours.black)
    term.setTextColor(colours.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function drawButton(x, y, width, label, active)
    term.setCursorPos(x, y)
    term.setBackgroundColor(active and colours.lightBlue or colours.grey)
    term.setTextColor(colours.white)
    term.write(string.rep(" ", width))
    term.setCursorPos(x + math.floor((width - #label) / 2), y)
    term.write(label)
    term.setBackgroundColor(colours.black)
    term.setTextColor(colours.white)

    return { x = x, y = y, width = width, label = label }
end

local function clicked(button, x, y)
    return y == button.y and x >= button.x and x < button.x + button.width
end

local function waitForButton(buttons)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "mouse_click" then
            local x, y = p2, p3
            for i = 1, #buttons do
                if clicked(buttons[i], x, y) then
                    return buttons[i].label
                end
            end
        elseif event == "key" then
            if p1 == keys.one and buttons[1] then return buttons[1].label end
            if p1 == keys.two and buttons[2] then return buttons[2].label end
            if p1 == keys.three and buttons[3] then return buttons[3].label end
            if p1 == keys.four and buttons[4] then return buttons[4].label end
            if p1 == keys.five and buttons[5] then return buttons[5].label end
            if p1 == keys.six and buttons[6] then return buttons[6].label end
            if p1 == keys.enter and buttons[1] then return buttons[1].label end
        end
    end
end

local function readField(label, y, default)
    term.setCursorPos(4, y)
    term.setTextColor(colours.lightGrey)
    if default and default ~= "" then
        term.write(label .. " [" .. tostring(default) .. "]")
    else
        term.write(label)
    end
    term.setTextColor(colours.white)
    term.setCursorPos(4, y + 1)
    term.write("> ")
    local value = read()
    if value == "" and default then
        return default
    end
    return value
end

local function drawTitle(subtitle)
    resetTerminal()
    term.setCursorPos(4, 2)
    term.setTextColor(colours.cyan)
    term.write("WIREMESH")
    term.setTextColor(colours.lightGrey)
    term.setCursorPos(4, 3)
    term.write(subtitle)
    term.setCursorPos(4, 4)
    term.write("Version " .. APP_VERSION)
    term.setTextColor(colours.white)
end

local function createWorldMenu()
    while true do
        drawTitle("Create a new world")
        local name = readField("World name", 6, "New World")
        local seedInput = readField("Seed (blank = system time)", 9, "")
        term.setCursorPos(4, 12)
        term.setTextColor(colours.lightGrey)
        term.write("Gamemode")
        local buttons = {
            drawButton(4, 14, 18, "Creative", true),
            drawButton(24, 14, 18, "Survival", false),
            drawButton(4, 17, 18, "Back", false),
        }

        local choice = waitForButton(buttons)
        if choice == "Back" then
            return nil
        end
        local gamemode = choice:lower()

        local seed = parseSeed(seedInput)
        perlin.init(seed)

        local info = {
            id = safeWorldId(name),
            name = name ~= "" and name or "New World",
            version = APP_VERSION,
            seed = perlin.getSeed(),
            created = os.epoch("utc"),
            updated = os.epoch("utc"),
            settings = {
                seed = perlin.getSeed(),
                gamemode = gamemode,
                renderDistance = tonumber(globalSettings.renderDistance) or 5,
            },
            gamemode = gamemode,
            player = {
                x = 560,
                y = 62,
                z = 576,
                yaw = 0,
                pitch = m.deg2rad(-10),
            },
            inventory = {},
        }

        saveWorldInfo(info)
        return info
    end
end

local function loadWorldMenu()
    while true do
        local worlds = listWorlds()
        drawTitle("Load a previous world")

        if #worlds == 0 then
            term.setCursorPos(4, 6)
            term.write("No saved worlds yet.")
            local buttons = { drawButton(4, 9, 18, "Back", true) }
            waitForButton(buttons)
            return nil
        end

        local maxItems = math.min(#worlds, 8)
        for i = 1, maxItems do
            local info = worlds[i]
            term.setCursorPos(4, 5 + i)
            term.setTextColor(colours.yellow)
            term.write(tostring(i) .. ". ")
            term.setTextColor(colours.white)
            term.write(info.name or info.id)
            term.setTextColor(colours.lightGrey)
            term.write("  seed: " .. tostring(info.seed) .. "  " .. tostring(info.gamemode or "creative") .. "  v" .. tostring(info.version or "legacy"))
        end

        term.setTextColor(colours.lightGrey)
        term.setCursorPos(4, 15)
        term.write("Type a number, or leave blank to go back.")
        term.setCursorPos(4, 16)
        term.write("> ")
        local input = read()
        local index = tonumber(input)
        if not index then
            return nil
        end
        if worlds[index] then
            return worlds[index]
        end
    end
end

local function globalSettingsMenu()
    while true do
        drawTitle("Global settings")
        term.setCursorPos(4, 7)
        term.setTextColor(colours.white)
        term.write("Default render distance: " .. tostring(globalSettings.renderDistance or 5))
        local buttons = {
            drawButton(4, 10, 18, "Render -", false),
            drawButton(24, 10, 18, "Render +", true),
            drawButton(4, 14, 18, "Back", false),
        }

        local choice = waitForButton(buttons)
        if choice == "Back" then
            saveGlobalSettings(globalSettings)
            return
        elseif choice == "Render -" or choice == "Render +" then
            local delta = (choice == "Render +") and 1 or -1
            globalSettings.renderDistance = math.max(2, math.min(10, (tonumber(globalSettings.renderDistance) or 5) + delta))
            saveGlobalSettings(globalSettings)
        end
    end
end

local function mainMenu()
    while true do
        drawTitle("Main menu")
        local buttons = {
            drawButton(4, 6, 22, "New World", true),
            drawButton(4, 9, 22, "Load World", false),
            drawButton(4, 12, 22, "Settings", false),
            drawButton(4, 15, 22, "Quit", false),
        }
        term.setCursorPos(4, 18)
        term.setTextColor(colours.lightGrey)
        term.write("Click a button or press 1, 2, 3, or 4.")
        term.setTextColor(colours.white)

        local choice = waitForButton(buttons)
        if choice == "New World" then
            local info = createWorldMenu()
            if info then return info end
        elseif choice == "Load World" then
            local info = loadWorldMenu()
            if info then return info end
        elseif choice == "Settings" then
            globalSettingsMenu()
        elseif choice == "Quit" then
            resetTerminal()
            return nil
        end
    end
end

local selectedWorld = mainMenu()
if not selectedWorld then
    print("Goodbye.")
    return
end

selectedWorld = migrateWorldInfo(selectedWorld)
if selectedWorld.version ~= APP_VERSION or selectedWorld.saveFormat ~= "wmesh-world" then
    saveWorldInfo(selectedWorld)
end

perlin.init(selectedWorld.seed)
world.setSaveDirectory(worldChunksPath(selectedWorld.id))

resetTerminal()
print("Loading world: " .. tostring(selectedWorld.name or selectedWorld.id))
print("Seed: " .. tostring(perlin.getSeed()))
print("Version: " .. tostring(selectedWorld.version))
print("Gamemode: " .. tostring(selectedWorld.gamemode or "creative"))
os.sleep(1)

world.generateArea(-10, 10, -10, 10)

local isCraftOSPC = (term.setGraphicsMode ~= nil)

if isCraftOSPC then
    term.setGraphicsMode(2)
    textures.initPalette()
else
    term.setTextScale(0.5)
    term.setBackgroundColor(colours.black)
    term.clear()
end


local w, h = term.getSize(true) -- Pass true to get true pixel dimensions

local savedPlayer = selectedWorld.player or {}
local cam = {
    x = savedPlayer.x or 560,
    y = savedPlayer.y or 62,
    z = savedPlayer.z or 576,
    yaw = savedPlayer.yaw or 0,
    pitch = savedPlayer.pitch or m.deg2rad(-10),
}
local fov = m.deg2rad(70)
local gamePaused = false
local currentGamemode = selectedWorld.gamemode or (selectedWorld.settings and selectedWorld.settings.gamemode) or "creative"
local verticalVelocity = 0
local onGround = false
local keysDown = {}

local lastTime = os.epoch("utc")
local fpsCounter = 0
local currentFPS = 0

-- Shared context variables for thread syncing
local camChunkX = math.floor(cam.x / world.chunkSize)
local camChunkZ = math.floor(cam.z / world.chunkSize)
local lastGenChunkX = nil
local lastGenChunkZ = nil
local renderRadius = 7
local spiralCache = {}

local function getSpiralOffsets(radius)
    if spiralCache[radius] then
        return spiralCache[radius]
    end

    local offsets = {}
    for dx = -radius, radius do
        for dz = -radius, radius do
            if dx * dx + dz * dz <= radius * radius then
                offsets[#offsets + 1] = { dx = dx, dz = dz, dist = dx * dx + dz * dz }
            end
        end
    end

    table.sort(offsets, function(a, b)
        if a.dist == b.dist then
            if a.dz == b.dz then
                return a.dx < b.dx
            end
            return a.dz < b.dz
        end
        return a.dist < b.dist
    end)

    spiralCache[radius] = offsets
    return offsets
end

renderer.renderDist = tonumber(selectedWorld.settings and selectedWorld.settings.renderDistance) or tonumber(globalSettings.renderDistance) or renderer.renderDist or 5

local function isWaterAt(x, y, z)
    return world.getBlock(math.floor(x), math.floor(y), math.floor(z)) == blocks.water
end

local function isSolidAt(x, y, z)
    local id = world.getBlock(math.floor(x), math.floor(y), math.floor(z))
    local def = id and blocks.list[id]
    return def and def.opaque
end

local function moveCamera(dx, dz)
    cam.x = cam.x + dx
    cam.z = cam.z + dz
end

local function updateMovement(dt)
    if gamePaused then
        return
    end

    local speed = currentGamemode == "creative" and 12 or 5.5
    local forward = (keysDown[keys.w] and 1 or 0) - (keysDown[keys.s] and 1 or 0)
    local strafe = (keysDown[keys.d] and 1 or 0) - (keysDown[keys.a] and 1 or 0)

    if forward ~= 0 or strafe ~= 0 then
        local length = math.sqrt(forward * forward + strafe * strafe)
        forward = forward / length
        strafe = strafe / length

        local dx = (forward * math.sin(cam.yaw) + strafe * math.cos(cam.yaw)) * speed * dt
        local dz = (forward * math.cos(cam.yaw) - strafe * math.sin(cam.yaw)) * speed * dt
        moveCamera(dx, dz)
    end

    if currentGamemode == "creative" then
        local vertical = (keysDown[keys.e] and 1 or 0) - (keysDown[keys.q] and 1 or 0)
        if vertical ~= 0 then
            cam.y = cam.y + vertical * speed * dt
        end
    end

    camChunkX = math.floor(cam.x / world.chunkSize)
    camChunkZ = math.floor(cam.z / world.chunkSize)
end

local function restoreGameScreen()
    if isCraftOSPC then
        term.setGraphicsMode(2)
        textures.initPalette()
    else
        term.setTextScale(0.5)
        term.setBackgroundColor(colours.black)
        term.clear()
    end
end

local function saveCurrentWorld()
    selectedWorld.seed = perlin.getSeed()
    selectedWorld.version = APP_VERSION
    selectedWorld.settings = selectedWorld.settings or {}
    selectedWorld.settings.seed = selectedWorld.seed
    selectedWorld.settings.gamemode = currentGamemode
    selectedWorld.settings.renderDistance = renderer.renderDist or 5
    selectedWorld.gamemode = currentGamemode
    selectedWorld.player = selectedWorld.player or {}
    selectedWorld.player.x = cam.x
    selectedWorld.player.y = cam.y
    selectedWorld.player.z = cam.z
    selectedWorld.player.yaw = cam.yaw
    selectedWorld.player.pitch = cam.pitch
    selectedWorld.inventory = selectedWorld.inventory or {}

    local savedChunks = world.saveAllChunksToDisk()
    saveWorldInfo(selectedWorld)
    return savedChunks
end

local function escapeMenu()
    gamePaused = true
    resetTerminal()
    term.setCursorPos(4, 2)
    term.setTextColor(colours.cyan)
    term.write("WIREMESH")
    term.setTextColor(colours.lightGrey)
    term.setCursorPos(4, 3)
    term.write("Escape menu")
    term.setCursorPos(4, 4)
    term.write("Version " .. APP_VERSION)
    term.setTextColor(colours.white)
    term.setCursorPos(4, 6)
    term.write("World: " .. tostring(selectedWorld.name or selectedWorld.id))
    term.setCursorPos(4, 7)
    term.write("Seed: " .. tostring(perlin.getSeed()))
    term.setCursorPos(4, 8)
    term.write("Gamemode: " .. tostring(currentGamemode))
    term.setCursorPos(4, 9)
    term.write("Render distance: " .. tostring(renderer.renderDist or 5))

    local buttons = {
        drawButton(4, 11, 22, "Resume", true),
        drawButton(4, 14, 22, "Save World", false),
        drawButton(4, 17, 22, "Switch Mode", false),
        drawButton(28, 11, 18, "Render -", false),
        drawButton(28, 14, 18, "Render +", false),
        drawButton(28, 17, 18, "Save & Quit", false),
    }

    while true do
        local choice = waitForButton(buttons)
        if choice == "Resume" then
            restoreGameScreen()
            gamePaused = false
            return false
        elseif choice == "Save World" then
            local savedChunks = saveCurrentWorld()
            term.setCursorPos(4, 22)
            term.setBackgroundColor(colours.black)
            term.setTextColor(colours.lime)
            term.write("Saved " .. tostring(savedChunks) .. " chunks.      ")
            term.setTextColor(colours.white)
        elseif choice == "Switch Mode" then
            currentGamemode = (currentGamemode == "creative") and "survival" or "creative"
            selectedWorld.gamemode = currentGamemode
            selectedWorld.settings = selectedWorld.settings or {}
            selectedWorld.settings.gamemode = currentGamemode
            verticalVelocity = 0
            term.setCursorPos(4, 8)
            term.setBackgroundColor(colours.black)
            term.setTextColor(colours.white)
        elseif choice == "Render -" or choice == "Render +" then
            local delta = (choice == "Render +") and 1 or -1
            renderer.renderDist = math.max(2, math.min(10, (renderer.renderDist or 5) + delta))
            selectedWorld.settings = selectedWorld.settings or {}
            selectedWorld.settings.renderDistance = renderer.renderDist
            term.setCursorPos(4, 9)
            term.setBackgroundColor(colours.black)
            term.setTextColor(colours.white)
            term.write("Render distance: " .. tostring(renderer.renderDist) .. "      ")
            term.setCursorPos(4, 22)
            term.setTextColor(colours.lime)
            term.write("Render distance changed. Save to keep it.      ")
            term.setTextColor(colours.white)
            term.write("Gamemode: " .. tostring(currentGamemode) .. "      ")
            term.setCursorPos(4, 22)
            term.setTextColor(colours.lime)
            term.write("Mode switched. Save to keep it.      ")
            term.setTextColor(colours.white)
        elseif choice == "Save & Quit" then
            saveCurrentWorld()
            gamePaused = false
            return true
        end
    end
end


-- 1. Input Processing Loop (High Priority Thread)
local function handleInput()
    while true do
        local e, p1, p2 = os.pullEvent() -- Pull all events openly to clear queue pollution

        if e == "key_up" then
            keysDown[p1] = nil
        elseif e == "key" then
            local key = p1
            keysDown[key] = true
            if key == keys.left then cam.yaw = cam.yaw - m.deg2rad(5)
            elseif key == keys.right then cam.yaw = cam.yaw + m.deg2rad(5)
            elseif key == keys.up then cam.pitch = cam.pitch + m.deg2rad(3)
            elseif key == keys.down then cam.pitch = cam.pitch - m.deg2rad(3)
            elseif key == keys.space and currentGamemode == "survival" then
                if isWaterAt(cam.x, cam.y - 1, cam.z) or isWaterAt(cam.x, cam.y - 2, cam.z) then
                    verticalVelocity = 0.22
                elseif onGround then
                    verticalVelocity = 0.85
                    onGround = false
                end
            elseif key == keys.backspace then
                if escapeMenu() then
                    break
                end
                
            -- Teleport Hotkey Block
            elseif key == keys.t then
                gamePaused = true
                term.setGraphicsMode(0)
                term.clear()
                term.setCursorPos(1, 1)
                
                print("--- BIOME TELEPORTER ---")
                print("Enter target biome name (e.g., MOUNTAINS):")
                local target = read()
                
                if target and target ~= "" then
                    target = target:upper()
                    print("Searching for " .. target .. "...")
                    
                    local found = false
                    local currentX = math.floor(cam.x / world.chunkSize)
                    local currentZ = math.floor(cam.z / world.chunkSize)
                    
                    for radius = 0, 50 do
                        for cx = currentX - radius, currentX + radius do
                            for cz = currentZ - radius, currentZ + radius do
                                if math.abs(cx - currentX) == radius or math.abs(cz - currentZ) == radius then
                                    world.advanceChunkTo(cx, cz, "carvers")
                                    local chunk = world.chunks[cx] and world.chunks[cx][cz]

                                    if chunk and chunk.biomes then
                                        local half = math.floor(world.chunkSize / 2)
                                        local info = chunk.biomes[half] and chunk.biomes[half][half]
                                        if info then
                                            local bProfile = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, 0.0)
                                            if bProfile and bProfile.name:upper() == target then
                                                cam.x = (cx * world.chunkSize) + half
                                                cam.z = (cz * world.chunkSize) + half
                                                cam.y = 65
                                                found = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if found then break end
                        end
                        if found then break end
                        os.queueEvent("fake") -- Allow the OS engine to breathe during long loops
                        os.pullEvent("fake")
                    end
                    
                    if found then
                        print("Biome found! Teleporting...")
                    else
                        print("Could not find biome '" .. target .. "' within 50 chunks.")
                        os.sleep(1.5)
                    end
                end
                restoreGameScreen()
                gamePaused = false
                
            end

            -- Keep coordinate positions updated live
            camChunkX = math.floor(cam.x / world.chunkSize)
            camChunkZ = math.floor(cam.z / world.chunkSize)
        end
    end
end

local function movementThread()
    local lastMove = os.epoch("utc")
    while true do
        local now = os.epoch("utc")
        local dt = math.min((now - lastMove) / 1000, 0.12)
        lastMove = now
        updateMovement(dt)
        os.sleep(0.02)
    end
end

local function physicsThread()
    local lastPhysics = os.epoch("utc")
    while true do
        if gamePaused or currentGamemode ~= "survival" then
            lastPhysics = os.epoch("utc")
            os.sleep(0.05)
        else
            local now = os.epoch("utc")
            local dt = math.min((now - lastPhysics) / 1000, 0.12)
            lastPhysics = now
            local inWater = isWaterAt(cam.x, cam.y - 1, cam.z) or isWaterAt(cam.x, cam.y - 2, cam.z)
            local gravity = inWater and 3.0 or 24.0
            local terminalVelocity = inWater and -3.6 or -24.0
            verticalVelocity = math.max(verticalVelocity - gravity * dt, terminalVelocity)

            local nextY = cam.y + verticalVelocity * dt
            local footY = nextY - 1.7

            if verticalVelocity <= 0 and isSolidAt(cam.x, footY, cam.z) then
                local groundY = math.floor(footY) + 1
                cam.y = groundY + 1.7
                verticalVelocity = 0
                onGround = true
            else
                cam.y = nextY
                onGround = false
            end

            os.sleep(0.05)
        end
    end
end

local function generationThread()
    while true do
        if gamePaused then
            os.sleep(0.1)
        else
        local camChunkX = math.floor(cam.x / world.chunkSize)
        local camChunkZ = math.floor(cam.z / world.chunkSize)

        local maxRender = renderer.renderDist or 5
        local pad = maxRender + 1 -- Keep structural data just 1 chunk ahead of the player
        local renderOffsets = getSpiralOffsets(maxRender)
        local padOffsets = getSpiralOffsets(pad)

        -- A flag to track if ANY work was completed during this scan cycle
        local workDone = false

        -- =================================================================
        -- PRIORITY 1: FULL VISUAL MESHES (Immediate Player Viewport)
        -- =================================================================
        local fullCount = 0
        for i = 1, #renderOffsets do
            local offset = renderOffsets[i]
            local cx = camChunkX + offset.dx
            local cz = camChunkZ + offset.dz
            if world.getChunkState(cx, cz) == "carvers" then
                world.advanceChunkTo(cx, cz, "full")
                workDone = true
                fullCount = fullCount + 1

                -- Mesh builds are expensive; keep this to one chunk per scheduler slice.
                if fullCount >= 1 then break end
            end
        end

        -- =================================================================
        -- PRIORITY 2: CARVERS (Caves & Tunnels structural phase)
        -- =================================================================
        if not workDone then
            local carverCount = 0
            for i = 1, #padOffsets do
                local offset = padOffsets[i]
                local cx = camChunkX + offset.dx
                local cz = camChunkZ + offset.dz
                local state = world.getChunkState(cx, cz)
                if state == "surface" then
                    world.advanceChunkTo(cx, cz, "carvers")
                    workDone = true
                    carverCount = carverCount + 1
                    if carverCount >= 1 then break end
                end
            end
        end

        -- =================================================================
        -- PRIORITY 3: SURFACE -> NOISE -> BIOMES (Fast Background Layers)
        -- =================================================================
        -- Since these stages don't build geometry meshes, we can process them
        -- in larger batches without dropping your frame rate.
        if not workDone then
            local geoCount = 0
            for i = 1, #padOffsets do
                local offset = padOffsets[i]
                local cx = camChunkX + offset.dx
                local cz = camChunkZ + offset.dz
                local state = world.getChunkState(cx, cz)

                if state == "noise" then
                    world.advanceChunkTo(cx, cz, "surface")
                    workDone, geoCount = true, geoCount + 1
                elseif state == "biomes" then
                    world.advanceChunkTo(cx, cz, "noise")
                    workDone, geoCount = true, geoCount + 1
                elseif state == "empty" then
                    world.advanceChunkTo(cx, cz, "biomes")
                    workDone, geoCount = true, geoCount + 1
                end

                if geoCount >= 6 then break end
            end
        end

        -- =================================================================
        -- THREAD FLUIDITY AND RESOURCE CONTROL
        -- =================================================================
        if workDone then
            -- We processed chunks! Yield for exactly one frame step so the 
            -- camera/renderer thread gets an immediate turn to update.
            os.sleep(0.05)
        else
            -- EVERYTHING IS COMPLETELY LOADED. 
            -- Put the background thread to sleep for half a second so it consumes 0% CPU.
            os.sleep(0.5)
        end
        end
    end
end

-- 3. Render Loop (Sync Framerate Context)
local function renderLoop()
    while true do
        if gamePaused then
            os.sleep(0.1)
        else
        renderer.clear()
        renderer.draw(cam, fov)

        local now = os.epoch("utc")
        fpsCounter = fpsCounter + 1
        if now - lastTime >= 1000 then
            currentFPS = fpsCounter
            fpsCounter = 0
            lastTime = now
        end

        renderer.drawHUD(cam, currentFPS)
        renderer.present()

        os.queueEvent("fake")
        os.pullEvent("fake") -- Filter directly to your fake event to stay performant
        end
    end
end

-- Run all three loops cooperatively side-by-side
parallel.waitForAny(renderLoop, handleInput, generationThread, physicsThread, movementThread)
term.setGraphicsMode(0)
print("World exit. Seed: " .. tostring(perlin.getSeed()))
