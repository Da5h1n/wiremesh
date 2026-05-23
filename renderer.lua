local m = require("math3d")
local blocks = require("blocks")
local world = require("world")
local text = require("text_renderer")

local renderer = {}

-- Global screen size
local w, h = term.getSize(true)
local hW, hH = w / 2, h / 2

-- Buffers
local buffer = {}
local zBuffer = {}

renderer.buffer = buffer
renderer.zBuffer = zBuffer

local vCache = {}
local clearList = {}
local clearCount = 0

local visibleFaces = {}

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
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_abs = math.abs

local function rasterizeTriangle(p1x, p1y, p2x, p2y, p3x, p3y, avgZ, tex)

    if p1y > p2y then p1x, p1y, p2x, p2y = p2x, p2y, p1x, p1y end
    if p1y > p3y then p1x, p1y, p3x, p3y = p3x, p3y, p1x, p1y end
    if p2y > p3y then p2x, p2y, p3x, p3y = p3x, p3y, p2x, p2y end

    if p1y == p3y then return end

    local texW, texH = 1, 1
    if tex then
        texH = #tex
        texW = #tex[1]
    end

    local area = (p3x - p1x) * (p2y - p1y) - (p3y - p1y) * (p2x - p1x)
    if math_abs(area) < 0.0001 then return end
    local invArea = 1.0 / area

    local function drawScanLine(scanY, xStart, xEnd)
        if scanY < 0 or scanY >= h then return end

        local startX = math_max(0, math_floor(math_min(xStart, xEnd)))
        local endX = math_min(w - 1, math_floor(math_max(xStart, xEnd)))

        local targetBuffer = buffer[scanY]
        local targetZBuffer = zBuffer[scanY]

        for x = startX, endX do

            if avgZ < targetZBuffer[x] then
                targetZBuffer[x] = avgZ

                if tex then

                    local b2 = ((x - p3x) * (p1y - p3y) - (scanY - p3y) * (p1x - p3x)) * invArea
                    local b3 = ((x - p1x) * (p2y - p1y) - (scanY - p1y) * (p2x - p1x)) * invArea

                    local tx = math_floor(b2 * (texW - 1)) + 1
                    if tx < 1 then tx = 1 elseif tx > texW then tx = texW end

                    local ty = math_floor(b3 * (texH - 1)) + 1
                    if ty < 1 then ty = 1 elseif ty > texH then ty = texH end

                    targetBuffer[x] = colorToIndex(tex[ty][tx])
                else
                    targetBuffer[x] = 15
                end
            end
        end
    end

    local totalHeight = p3y - p1y

    for y = math_max(0, math_floor(p1y)), math_min(h - 1, math_floor(p3y)) do
        local isTopHalf = y < p2y
        local segmentHeight = isTopHalf and (p2y - p1y) or (p3y - p2y)
        if segmentHeight > 0 then
            local alpha = (y - p1y) / totalHeight
            local beta = isTopHalf and ((y - p1y) / segmentHeight) or ((y - p2y) / segmentHeight)

            local xA = p1x + (p3x - p1x) * alpha
            local xB = isTopHalf and (p1x + (p2x - p1x) * beta) or (p2x + (p3x - p2x) * beta)

            drawScanLine(y, xA, xB)
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

local hexMap = "012345678abcdef"
local isCraftOSPC = (term.setGraphicsMode ~= nil)

function renderer.present()
    if isCraftOSPC then
        local out = {}
        for y = 0, h - 1 do
            local row = {}
            for x = 0, w - 1 do
                row[#row+1] = string.char(buffer[y][x])
            end
            out[y+1] = table.concat(row)
        end
        term.drawPixels(0, 0, out)
    else
        for y = 0, h - 1 do
            local textRow = {}
            local colorRow = {}
            for x = 0, w - 1 do
                textRow[#textRow+1] = " "
                local colIdx = buffer[y][x] or 15
                local hexChar = string.sub(hexMap, colIdx + 1, colIdx + 1)
                colorRow[#colorRow+1] = hexChar
            end

            term.setCursorPos(1, y + 1)
            term.blit(table.concat(textRow), table.concat(colorRow), table.concat(colorRow))
        end
    end
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
    local renderDist = 5
    local camChunkX = math.floor(cam.x / world.chunkSize)
    local camChunkZ = math.floor(cam.z / world.chunkSize)

    -- Precompute trigonometric angles
    local cosYaw, sinYaw = math.cos(cam.yaw), math.sin(cam.yaw)
    local cosPitch, sinPitch = math.cos(cam.pitch), math.sin(cam.pitch)
    local scale = hW / math.tan(fov / 2)

    local faceCount = 0

    -- Ultra-fast zero-allocation cache wipe from previous frame
    for i = 1, clearCount do
        local tbl = clearList[i]
        tbl[1], tbl[2], tbl[3] = nil, nil, nil
    end
    clearCount = 0

    for cx = camChunkX - renderDist, camChunkX + renderDist do
        for cz = camChunkZ - renderDist, camChunkZ + renderDist do
            local key = string.format("%d,%d", cx, cz) -- Kept out of inner-most loops
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
                        
                        if (vx * norm[1] + vy * norm[2] + vz * norm[3]) <= 0 then
                            local corners = {face.c1, face.c2, face.c3, face.c4}
                            local validFace = true
                            local sx, sy, sz = {}, {}, {}

                            for j = 1, 4 do
                                local c = corners[j]
                                local cx, cy, cz = c[1], c[2], c[3]
                                
                                -- 3D Nested Array Cache (Zero strings allocated!)
                                local xTable = vCache[cx]
                                if not xTable then xTable = {}; vCache[cx] = xTable end
                                local yTable = xTable[cy]
                                if not yTable then yTable = {}; xTable[cy] = yTable end
                                local cachedVert = yTable[cz]

                                if cachedVert and cachedVert[3] then
                                    sx[j] = cachedVert[1]
                                    sy[j] = cachedVert[2]
                                    sz[j] = cachedVert[3]
                                else
                                    -- Coordinate Transformation
                                    local rx = cx - cam.x
                                    local ry = cy - cam.y
                                    local rz = cz - cam.z

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

                                    -- Store in structural cache table
                                    if not cachedVert then cachedVert = {}; yTable[cz] = cachedVert end
                                    cachedVert[1] = screenX
                                    cachedVert[2] = screenY
                                    cachedVert[3] = finalZ

                                    -- Queue up this table structure to be unlinked next frame
                                    clearCount = clearCount + 1
                                    clearList[clearCount] = cachedVert

                                    sx[j], sy[j], sz[j] = screenX, screenY, finalZ
                                end
                            end

                            if validFace then
                                if  (sx[1] < 0 and sx[2] < 0 and sx[3] < 0 and sx[4] < 0) or
                                    (sx[1] >= w and sx[2] >= w and sx[3] >= w and sx[4] >= w) or
                                    (sy[1] < 0 and sy[2] < 0 and sy[3] < 0 and sy[4] < 0) or
                                    (sy[1] >= h and sy[2] >= h and sy[3] >= h and sy[4] >= h) then
                                    validFace = false
                                end
                            end

                            if validFace then
                                local avgZ = (sz[1] + sz[2] + sz[3] + sz[4]) / 4
                                faceCount = faceCount + 1
                                local slot = visibleFaces[faceCount] or {}
                                slot.s1x, slot.s1y = sx[1], sy[1]
                                slot.slot2x, slot.s2y = sx[2], sy[2]
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
        rasterizeTriangle(f.s1x, f.s1y, f.slot2x, f.s2y, f.s3x, f.s3y, f.z, f.tex)
        rasterizeTriangle(f.s1x, f.s1y, f.s3x, f.s3y, f.s4x, f.s4y, f.z, f.tex)
    end
end

function renderer.drawHUD(cam, fps)

    -- HUD always draws on top
    local function hudPlot(x, y, color)
        if x >= 0 and x < w and y >= 0 and y < h then
            buffer[y][x] = color
            zBuffer[y][x] = -math.huge   -- absolute top layer
        end
    end

    -- Format first line (Performance & Position)
    local fpsStr = string.format("FPS: %d", fps or 0)
    local xyzStr = string.format("XYZ: %.2f / %.2f / %.2f", cam.x, cam.y, cam.z)

    -- Initialize environmental default strings
    local biomeName = "UNKNOWN"
    local envStr = "E: T:0.00 H:0.00 C:0.00 E:0.00 W:0.00"
    local depthStr = "DEPTH: 0"

    local cx = math.floor(cam.x / world.chunkSize)
    local cz = math.floor(cam.z / world.chunkSize)
    local chunk = world.chunks[string.format("%d,%d", cx, cz)]

    if chunk and chunk.biomes then
        local cs = world.chunkSize
        local lx = math.floor(cam.x) - (cx * cs)
        local lz = math.floor(cam.z) - (cz * cs)
        lx = math.max(0, math.min(cs - 1, lx))
        lz = math.max(0, math.min(cs - 1, lz))

        local info = chunk.biomes[lx] and chunk.biomes[lx][lz]
        if info then
            -- Fetch the biome profile using your 6D noise lookup
            local currentBiome = world.getBiome6D(info.t, info.h, info.c, info.e, info.w, 0.0)
            if currentBiome then
                biomeName = currentBiome.name
            end
            
            -- Format the raw noise parameters line (Minecraft Style)
            envStr = string.format("E: T:%.2f H:%.2f C:%.2f E:%.2f W:%.2f", 
                info.t, info.h, info.c, info.e, info.w)
        end
    end

    -- Calculate Depth: Assumes sea level or surface baseline is around Y=62. 
    -- If your noise generator uses a distinct surface height, replace info.e/baseline here.
    local surfaceBaseline = 62
    local currentDepth = math.floor(surfaceBaseline - cam.y)
    if currentDepth < 0 then
        depthStr = string.format("DEPTH: 0 (ABOVE GROUND Y:%d)", math.floor(cam.y))
    else
        depthStr = string.format("DEPTH: %d", currentDepth)
    end

    local biomeStr = "BIOME: " .. biomeName

    -- Render text lines onto the screen buffer
    local scale = 2
    local y = 4
    y = text.drawString(buffer, zBuffer, w, h, fpsStr,   4, y, 11, scale, 14)
    y = text.drawString(buffer, zBuffer, w, h, xyzStr,   4, y, 11, scale, 14)
    y = text.drawString(buffer, zBuffer, w, h, biomeStr, 4, y, 11, scale, 14)
    
    -- New Lines: Environmental Noise Matrix & Depth Metrics
    y = text.drawString(buffer, zBuffer, w, h, envStr,   4, y, 14, scale, 14) -- Gray/White color index
    y = text.drawString(buffer, zBuffer, w, h, depthStr, 4, y, 13, scale, 14) -- Greenish accent color index

end


return renderer