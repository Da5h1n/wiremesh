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

if not term.setGraphicsMode then
    error("This engine requires CraftOS-PC with Graphics Mode enabled!", 0)
end

term.setGraphicsMode(2)
textures.initPalette()

local w, h = term.getSize(true) -- Pass true to get true pixel dimensions

local cam = {
    x = 0, y = 62, z = 0,
    yaw = 0, pitch = m.deg2rad(-10),
}
local fov = m.deg2rad(70)

-- Generate a stone cylinder model mesh (8 segments, radius 1, height 3)
local cylVerts, cylFaces = shapes.createCylinder(8, 1, 3, textures.stone)
local cylPos = { x = 6, y = 4, z = 6 }

local lastTime = os.epoch("utc")
local fps = 0

local function handleInput()
    while true do
        local e, key = os.pullEvent("key")
        if key == keys.left then cam.yaw = cam.yaw - m.deg2rad(5)
        elseif key == keys.right then cam.yaw = cam.yaw + m.deg2rad(5)
        elseif key == keys.up then cam.pitch = cam.pitch + m.deg2rad(3)
        elseif key == keys.down then cam.pitch = cam.pitch - m.deg2rad(3)
        elseif key == keys.w then
            cam.z = cam.z + 0.5 * math.cos(cam.yaw)
            cam.x = cam.x + 0.5 * math.sin(cam.yaw)
        elseif key == keys.s then
            cam.z = cam.z - 0.5 * math.cos(cam.yaw)
            cam.x = cam.x - 0.5 * math.sin(cam.yaw)
        elseif key == keys.a then
            cam.x = cam.x - 0.5 * math.cos(cam.yaw)
            cam.z = cam.z + 0.5 * math.sin(cam.yaw)
        elseif key == keys.d then
            cam.x = cam.x + 0.5 * math.cos(cam.yaw)
            cam.z = cam.z - 0.5 * math.sin(cam.yaw)
        elseif key == keys.e then
            cam.y = cam.y + 0.5
        elseif key == keys.q then
            cam.y = cam.y - 0.5
        elseif key == keys.backspace then
            break
        end

        local lastCamChunkX = nil
        local lastCamChunkZ = nil

        local camChunkX = math.floor(cam.x / world.chunkSize)
        local camChunkZ = math.floor(cam.z / world.chunkSize)

        local renderRadius = 4

        if camChunkX ~= lastCamChunkX or camChunkZ ~= lastCamChunkZ then
            lastCamChunkX = camChunkX
            lastCamChunkZ = camChunkZ

            local renderRadius = 4
            for cx = camChunkX - renderRadius, camChunkX + renderRadius do
                for cz = camChunkZ - renderRadius, camChunkZ + renderRadius do
                    world.generateChunk(cx, cz)
                end
            end
        end
    end
end

local function renderLoop()
    while true do
        -- 1. Clear text/z-buffers
        renderer.clear()

        -- 2. Render 3D voxel structure meshes
        renderer.draw(cam, fov)

        -- 3. Render HUD/F3 overlay on top of the geometry frame
        renderer.drawHUD(cam)

        -- 4. Flush / render buffer to screen
        renderer.present() 
        
        os.queueEvent("fake")
        os.pullEvent()
    end
end

-- Run both loops side-by-side cleanly
parallel.waitForAny(renderLoop, handleInput)
term.setGraphicsMode(0)
print("World exit. Seed: " .. tostring(perlin.getSeed()))

