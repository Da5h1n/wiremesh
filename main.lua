local renderer = require("renderer")
local world = require("world")
local m = require("math3d")
local perlin = require("perlin")
local shapes = require("shapes")
local textures = require("textures")

term.clear()
term.setCursorPos(1, 1)
print("--- SEED SELECTOR ---")
print("Enter world seed (leave empty for system time): ")
local inputSeed = read()

if inputSeed and inputSeed ~= "" then
    local numericSeed = tonumber(inputSeed)
    if not numericSeed then
        numericSeed = 0
        for i = 1, #inputSeed do
            numericSeed = numericSeed + inputSeed:byte(i) * (31 ^ (#inputSeed - i))
        end
    end
    perlin.init(numericSeed)
else
    perlin.init() --System time
end

print("Loading seed: " .. tostring(perlin.getSeed()))
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

local cam = {
    x = 560, y = 62, z = 576,
    yaw = 0, pitch = m.deg2rad(-10),
}
local fov = m.deg2rad(70)

local lastTime = os.epoch("utc")
local fpsCounter = 0
local currentFPS = 0

-- Shared context variables for thread syncing
local camChunkX = math.floor(cam.x / world.chunkSize)
local camChunkZ = math.floor(cam.z / world.chunkSize)
local lastGenChunkX = nil
local lastGenChunkZ = nil
local renderRadius = 7


-- 1. Input Processing Loop (High Priority Thread)
local function handleInput()
    while true do
        local e, p1, p2 = os.pullEvent() -- Pull all events openly to clear queue pollution
        
        if e == "key" then
            local key = p1
            if key == keys.left then cam.yaw = cam.yaw - m.deg2rad(5)
            elseif key == keys.right then cam.yaw = cam.yaw + m.deg2rad(5)
            elseif key == keys.up then cam.pitch = cam.pitch + m.deg2rad(3)
            elseif key == keys.down then cam.pitch = cam.pitch - m.deg2rad(3)
            elseif key == keys.w then
                cam.z = cam.z + 1 * math.cos(cam.yaw)
                cam.x = cam.x + 1 * math.sin(cam.yaw)
            elseif key == keys.s then
                cam.z = cam.z - 1 * math.cos(cam.yaw)
                cam.x = cam.x - 1 * math.sin(cam.yaw)
            elseif key == keys.a then
                cam.x = cam.x - 1 * math.cos(cam.yaw)
                cam.z = cam.z + 1 * math.sin(cam.yaw)
            elseif key == keys.d then
                cam.x = cam.x + 1 * math.cos(cam.yaw)
                cam.z = cam.z - 1 * math.sin(cam.yaw)
            elseif key == keys.e then
                cam.y = cam.y + 1
            elseif key == keys.q then
                cam.y = cam.y - 1
                
            -- Teleport Hotkey Block
            elseif key == keys.t then
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
                                    local keyStr = string.format("%d,%d", cx, cz)
                                    
                                    world.advanceChunkTo(cx, cz, "carvers")
                                    local chunk = world.chunks[keyStr]
                                    
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
                term.setGraphicsMode(2)
                
            elseif key == keys.backspace then
                break
            end

            -- Keep coordinate positions updated live
            camChunkX = math.floor(cam.x / world.chunkSize)
            camChunkZ = math.floor(cam.z / world.chunkSize)
        end
    end
end

local function generationThread()
    while true do
        local camChunkX = math.floor(cam.x / world.chunkSize)
        local camChunkZ = math.floor(cam.z / world.chunkSize)

        local maxRender = renderer.renderDist or 5
        local pad = maxRender + 1 -- Keep structural data just 1 chunk ahead of the player

        -- A flag to track if ANY work was completed during this scan cycle
        local workDone = false

        -- =================================================================
        -- PRIORITY 1: FULL VISUAL MESHES (Immediate Player Viewport)
        -- =================================================================
        local fullCount = 0
        for cx = camChunkX - maxRender, camChunkX + maxRender do
            for cz = camChunkZ - maxRender, camChunkZ + maxRender do
                if world.getChunkState(cx, cz) ~= "full" then
                    world.advanceChunkTo(cx, cz, "full")
                    workDone = true
                    fullCount = fullCount + 1
                    
                    -- Process up to 2 heavy visual meshes per cycle before letting the renderer draw
                    if fullCount >= 2 then break end
                end
            end
            if fullCount >= 2 then break end
        end

        -- =================================================================
        -- PRIORITY 2: CARVERS (Caves & Tunnels structural phase)
        -- =================================================================
        if not workDone then
            local carverCount = 0
            for cx = camChunkX - pad, camChunkX + pad do
                for cz = camChunkZ - pad, camChunkZ + pad do
                    local state = world.getChunkState(cx, cz)
                    if state ~= "full" and state ~= "carvers" then
                        world.advanceChunkTo(cx, cz, "carvers")
                        workDone = true
                        carverCount = carverCount + 1
                        if carverCount >= 4 then break end
                    end
                end
                if carverCount >= 4 then break end
            end
        end

        -- =================================================================
        -- PRIORITY 3: SURFACE -> NOISE -> BIOMES (Fast Background Layers)
        -- =================================================================
        -- Since these stages don't build geometry meshes, we can process them
        -- in larger batches without dropping your frame rate.
        if not workDone then
            local geoCount = 0
            for cx = camChunkX - pad, camChunkX + pad do
                for cz = camChunkZ - pad, camChunkZ + pad do
                    local state = world.getChunkState(cx, cz)
                    
                    if state == "surface" then
                        -- Needs promotion to carvers, handled above
                    elseif state == "noise" then
                        world.advanceChunkTo(cx, cz, "surface")
                        workDone, geoCount = true, geoCount + 1
                    elseif state == "biomes" then
                        world.advanceChunkTo(cx, cz, "noise")
                        workDone, geoCount = true, geoCount + 1
                    elseif state == "empty" then
                        world.advanceChunkTo(cx, cz, "biomes")
                        workDone, geoCount = true, geoCount + 1
                    end

                    if geoCount >= 8 then break end
                end
                if geoCount >= 8 then break end
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

-- 3. Render Loop (Sync Framerate Context)
local function renderLoop()
    while true do
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

-- Run all three loops cooperatively side-by-side
parallel.waitForAny(renderLoop, handleInput, generationThread)
term.setGraphicsMode(0)
print("World exit. Seed: " .. tostring(perlin.getSeed()))