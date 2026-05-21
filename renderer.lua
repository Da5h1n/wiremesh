local m = require("math3d")
local blocks = require("blocks")
local world = require("world")

local renderer = {}

-- Global screen size
local w, h = term.getSize(true)
local hW, hH = w / 2, h / 2

-- Buffers
local buffer = {}
local zBuffer = {}

local visibleFaces = {}

local lastTime = os.epoch("utc")
local fpsCounter = 0
local currentFPS = 0
local fpsUpdateTimer = 0

-- Convert CC color bitmask → palette index
local function colorToIndex(col)
    if type(col) ~= "number" then return 15 end
    if col >= 16 then return col end 
    if col <= 15 then return col end
    if col == 0 then return 0 end
    return math.floor(math.log(col, 2))
end

-- Refactored helper to get camera-space coordinates explicitly for sorting
local function getCameraSpace(px, py, pz, cam)
    local x, y, z = px - cam.x, py - cam.y, pz - cam.z
    x, y, z = m.rotateY(x, y, z, cam.yaw)
    return m.rotateX(x, y, z, cam.pitch)
end

-- Project a 3D point into screen space
local function projectPoint(px, py, pz, cam, fov, w, h)
    local x, y, z = px - cam.x, py - cam.y, pz - cam.z
    x, y, z = m.rotateY(x, y, z, cam.yaw)
    x, y, z = m.rotateX(x, y, z, cam.pitch)

    if z <= 0.1 then return nil end

    local scale = (w / 2) / math.tan(fov / 2)
    local sx = (x * scale / z) + w / 2
    local sy = h / 2 - (y * scale / z)

    return math.floor(sx), math.floor(sy)
end

-- Rasterizer
local function rasterizeTriangle(p1x, p1y, p2x, p2y, p3x, p3y, avgZ, tex)
    local minX = math.max(0, math.min(p1x, p2x, p3x))
    local maxX = math.min(w - 1, math.max(p1x, p2x, p3x))
    local minY = math.max(0, math.min(p1y, p2y, p3y))
    local maxY = math.min(h - 1, math.max(p1y, p2y, p3y))

    local area = (p3x - p1x) * (p2y - p1y) - (p3y - p1y) * (p2x - p1x)
    if math.abs(area) < 0.0001 then return end

    local texW, texH = 1, 1
    if tex then
        texH = #tex
        texW = #tex[1]
    end

    for y = minY, maxY do
        for x = minX, maxX do
            local w1 = (x - p2x) * (p3y - p2y) - (y - p2y) * (p3x - p2x)
            local w2 = (x - p3x) * (p1y - p3y) - (y - p3y) * (p1x - p3x)
            local w3 = (x - p1x) * (p2y - p1y) - (y - p1y) * (p2x - p1x)

            if (area > 0 and w1 >= 0 and w2 >= 0 and w3 >= 0) or (area < 0 and w1 <= 0 and w2 <= 0 and w3 <= 0) then
                if avgZ < zBuffer[y][x] then
                    zBuffer[y][x] = avgZ
                    local finalColor = 15
                    if tex then
                        local b2 = w2 / area
                        local b3 = w3 / area
                        local tx = math.max(1, math.min(texW, math.floor(b2 * (texW - 1)) + 1))
                        local ty = math.max(1, math.min(texH, math.floor(b3 * (texH - 1)) + 1))
                        finalColor = colorToIndex(tex[ty][tx])
                    end
                    buffer[y][x] = finalColor
                end
            end
        end
    end
end

-- Clear buffers
function renderer.clear()
    local sky = colorToIndex(colors.lightBlue)
    for y = 0, h - 1 do
        buffer[y] = buffer[y] or {}
        zBuffer[y] = zBuffer[y] or {}
        for x = 0, w - 1 do
            buffer[y][x] = sky
            zBuffer[y][x] = math.huge
        end
    end
end

-- Present frame
function renderer.present()
    local out = {}
    for y = 0, h - 1 do
        local row = {}
        for x = 0, w - 1 do
            row[#row+1] = string.char(buffer[y][x])
        end
        out[y+1] = table.concat(row)
    end
    term.drawPixels(0, 0, out)
end

-- Mesh renderer
function renderer.drawMesh(vertices, faces, pos, cam, fov)
    local projected = {}
    local tris = {}

    for i, v in ipairs(vertices) do
        local sx, sy = projectPoint(v[1] + pos.x, v[2] + pos.y, v[3] + pos.z, cam, fov, w, h)
        projected[i] = sx and {sx, sy} or nil
    end

    for _, f in ipairs(faces) do
        local p1, p2, p3 = projected[f[1]], projected[f[2]], projected[f[3]]
        if p1 and p2 and p3 then
            local winding = (p2[1]-p1[1])*(p3[2]-p1[2]) - (p2[2]-p1[2])*(p3[1]-p1[1])
            if winding < 0 then
                local v1 = vertices[f[1]]
                local fx = v1[1] + pos.x - cam.x
                local fy = v1[2] + pos.y - cam.y
                local fz = v1[3] + pos.z - cam.z
                fx, fy, fz = m.rotateY(fx, fy, fz, cam.yaw)
                fx, fy, fz = m.rotateX(fx, fy, fz, cam.pitch)

                if fz > 0.1 then
                    table.insert(tris, {p1, p2, p3, z=fz, tex=f.tex})
                end
            end
        end
    end

    table.sort(tris, function(a,b) return a.z > b.z end)

    for _, t in ipairs(tris) do
        rasterizeTriangle(t[1], t[2], t[3], t.z, t.tex)
    end
end

-- World renderer
function renderer.draw(cam, fov)
    local renderDist = 2 
    local camChunkX = math.floor(cam.x / world.chunkSize)
    local camChunkZ = math.floor(cam.z / world.chunkSize)

    -- Precompute trigonometric angles
    local cosYaw, sinYaw = math.cos(cam.yaw), math.sin(cam.yaw)
    local cosPitch, sinPitch = math.cos(cam.pitch), math.sin(cam.pitch)
    local scale = hW / math.tan(fov / 2)

    local faceCount = 0

    -- Global cache for the frame - using absolute coordinate keys to prevent cross-talk
    local vCacheX, vCacheY, vCacheZ = {}, {}, {}

    for cx = camChunkX - renderDist, camChunkX + renderDist do
        for cz = camChunkZ - renderDist, camChunkZ + renderDist do
            local key = string.format("%d,%d", cx, cz)
            local chunk = world.chunks[key]
            
            if chunk and chunk.mesh then
                -- Coarse chunk culling
                local chunkCenterX = (cx * 16) + 8
                local chunkCenterZ = (cz * 16) + 8
                local tX = chunkCenterX - cam.x
                local tZ = chunkCenterZ - cam.z
                local rotZ = tX * sinYaw + tZ * cosYaw
                
                if rotZ > -12 then 
                    for i = 1, #chunk.mesh do
                        local face = chunk.mesh[i]

                        -- Backface culling
                        local c1 = face.c1
                        local vx = (c1[1] + 0.5) - cam.x
                        local vy = (c1[2] + 0.5) - cam.y
                        local vz = (c1[3] + 0.5) - cam.z
                        local norm = face.normal
                        
                        if (vx * norm[1] + vy * norm[2] + vz * norm[3]) < 0 then
                            local corners = {face.c1, face.c2, face.c3, face.c4}
                            local validFace = true
                            local sx, sy, sz = {}, {}, {}

                            for j = 1, 4 do
                                local c = corners[j]
                                
                                -- FIX: Use absolute world positions for the key to eliminate chunk collisions
                                local vKey = string.format("%d,%d,%d", c[1], c[2], c[3])

                                if vCacheZ[vKey] then
                                    sx[j] = vCacheX[vKey]
                                    sy[j] = vCacheY[vKey]
                                    sz[j] = vCacheZ[vKey]
                                else
                                    -- Coordinate Transformation
                                    local rx = c[1] - cam.x
                                    local ry = c[2] - cam.y
                                    local rz = c[3] - cam.z

                                    local rX1 = rx * cosYaw - rz * sinYaw
                                    local rZ1 = rx * sinYaw + rz * cosYaw

                                    local finalY = ry * cosPitch - rZ1 * sinPitch
                                    local finalZ = ry * sinPitch + rZ1 * cosPitch

                                    -- Near plane clipping guard boundary
                                    if finalZ <= 0.1 then
                                        validFace = false
                                        break
                                    end

                                    local screenX = math.floor((rX1 * scale / finalZ) + hW)
                                    local screenY = math.floor(hH - (finalY * scale / finalZ))

                                    -- Cache it safely immediately
                                    vCacheX[vKey] = screenX
                                    vCacheY[vKey] = screenY
                                    vCacheZ[vKey] = finalZ

                                    sx[j], sy[j], sz[j] = screenX, screenY, finalZ
                                end
                            end

                            if validFace then
                                local avgZ = (sz[1] + sz[2] + sz[3] + sz[4]) / 4
                                faceCount = faceCount + 1
                                local slot = visibleFaces[faceCount] or {}
                                slot.s1x, slot.s1y = sx[1], sy[1]
                                slot.s2x, slot.s2y = sx[2], sy[2]
                                slot.s3x, slot.s3y = sx[3], sy[3]
                                slot.s4x, slot.s4y = sx[4], sy[4]
                                slot.z = avgZ
                                slot.tex = face.tex
                                visibleFaces[faceCount] = slot
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fast Sort array up to current count
    for i = faceCount + 1, #visibleFaces do visibleFaces[i] = nil end
    table.sort(visibleFaces, function(a, b) return a.z > b.z end)

    for i = 1, faceCount do
        local f = visibleFaces[i]
        rasterizeTriangle(f.s1x, f.s1y, f.s2x, f.s2y, f.s3x, f.s3y, f.z, f.tex)
        rasterizeTriangle(f.s1x, f.s1y, f.s3x, f.s3y, f.s4x, f.s4y, f.z, f.tex)
    end
end

function renderer.drawHUD(cam)
    -- 1. Calculate Delta Time & FPS
    local currentTime = os.epoch("utc")
    local dt = (currentTime - lastTime) / 1000
    lastTime = currentTime

    fpsCounter = fpsCounter + 1
    fpsUpdateTimer = fpsUpdateTimer + dt
    
    -- Update FPS read-out every 0.5 seconds to keep it readable
    if fpsUpdateTimer >= 0.5 then
        currentFPS = math.floor(fpsCounter / fpsUpdateTimer)
        fpsCounter = 0
        fpsUpdateTimer = 0
    end

    -- 2. Query Biome Data from World Location
    local biomeName = "Unknown"
    if world.getBiomeAt then
        -- If you have an explicit coordinate lookup
        local b = world.getBiomeAt(math.floor(cam.x), math.floor(cam.z))
        if b then biomeName = b.name end
    else
        -- Fallback: Use your internal multi-noise generator values if available
        -- Adjust parameters here if your world matching logic requires explicit variables
        local cx = math.floor(cam.x / world.chunkSize)
        local cz = math.floor(cam.z / world.chunkSize)
        local chunk = world.chunks[string.format("%d,%d", cx, cz)]
        if chunk and chunk.biome then
            biomeName = chunk.biome.name
        end
    end

    -- 3. Draw Text Overlay safely in Graphics Mode 2
    -- Save graphics state parameters or use term.nativePaletteColor if needed
    local oldTarget = term.getGraphicsMode and term.setDrawTarget and term.getDrawTarget()
    
    -- Ensure we are drawing text over the current window layer cleanly
    term.setTextColor(colors.yellow)
    term.setBackgroundColor(colors.black) -- Transparent or solid backer strip
    
    -- Setup text positions
    term.setCursorPos(2, 2)
    term.write(string.format("FPS: %d", currentFPS))
    
    term.setCursorPos(2, 3)
    term.write(string.format("XYZ: %.2f / %.2f / %.2f", cam.x, cam.y, cam.z))
    
    term.setCursorPos(2, 4)
    term.write(string.format("Biome: %s", biomeName))
    
    term.setCursorPos(2, 5)
    term.write(string.format("Rendered Faces: %d", #visibleFaces))
end

return renderer