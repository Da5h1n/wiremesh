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
renderer.renderDist = 5

local vCache = {}
local clearList = {}
local clearCount = 0


local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_cos = math.cos
local math_sin = math.sin
local math_tan = math.tan
local math_abs = math.abs
local chunkRadius = 12


local nativeColourIndices = {}
local function addNativeColour(col, idx)
    if col then nativeColourIndices[col] = idx end
end
addNativeColour(colours.white, 0)
addNativeColour(colours.orange, 1)
addNativeColour(colours.magenta, 2)
addNativeColour(colours.lightBlue, 3)
addNativeColour(colours.yellow, 4)
addNativeColour(colours.lime, 5)
addNativeColour(colours.pink, 6)
addNativeColour(colours.grey or colours.gray, 7)
addNativeColour(colours.lightGrey or colours.lightGray, 8)
addNativeColour(colours.cyan, 9)
addNativeColour(colours.purple, 10)
addNativeColour(colours.blue, 11)
addNativeColour(colours.brown, 12)
addNativeColour(colours.green, 13)
addNativeColour(colours.red, 14)
addNativeColour(colours.black, 15)

-- Convert CC color bitmask → palette index
local function colorToIndex(col)
    if type(col) ~= "number" then return 15 end
    return nativeColourIndices[col] or col
end

-- Refactored helper to get camera-space coordinates explicitly for sorting
local function getCameraSpace(px, py, pz, cam)
    local x, y, z = px - cam.x, py - cam.y, pz - cam.z
    x, y, z = m.rotateY(x, y, z, cam.yaw)
    return m.rotateX(x, y, z, cam.pitch)
end

-- Project a 3D point into screen space
local function projectPoint(px, py, pz, cam, fov)

    local x = px - cam.x
    local y = py - cam.y
    local z = pz - cam.z

    -- Yaw rotation
    local cy, sy = math_cos(cam.yaw), math_sin(cam.yaw)
    local x1 = x * cy - z * sy
    local z1 = x * sy + z * cy

    -- Pitch rotation
    local cp, sp  = math_cos(cam.pitch), math_sin(cam.pitch)
    local y2 = y * cp - z1 * sp
    local z2 = y * sp + z1 * cp

    if z2 <= 0.1 then return nil end

    local scale = hW / math_tan(fov / 2)
    return math_floor((x1 * scale / z2) + hW), math_floor(hH - (y2 * scale / z2)), z2
end

-- Rasterizer
local function rasterizeTriangle(p1x, p1y, p2x, p2y, p3x, p3y, avgZ, colourIdx, tex, z1, z2, z3, u1, v1, u2, v2, u3, v3, transparent)

        -- Reject triangles with invalid coordinates
    if not (p1x and p1y and p2x and p2y and p3x and p3y) then
        return
    end


    local minX = math_max(0, math_floor(math_min(p1x, p2x, p3x)) - 1)
    local maxX = math_min(w - 1, math_floor(math_max(p1x, p2x, p3x)) + 1)
    local minY = math_max(0, math_floor(math_min(p1y, p2y, p3y)) - 1)
    local maxY = math_min(h - 1, math_floor(math_max(p1y, p2y, p3y)) + 1)

    if minX > maxX or minY > maxY then return end

    -- Barycentric area calc factor
    local denominator = ((p2y - p3y) * (p1x - p3x) + (p3x - p2x) * (p1y - p3y))
    if denominator == 0 then return end
    local invArea = 1.0 / denominator

    local buf = buffer
    local zBuf = zBuffer

    -- Substitute your existing "if not tex" loop block with this geometric edge stepper:
    if not tex then
        for scanY = minY, maxY do
            local startX = maxX
            local endX = minX

            -- Compute precise x intercepts using edge vectors rather than checking every single pixel
            if p1y ~= p2y and scanY >= math_min(p1y, p2y) and scanY <= math_max(p1y, p2y) then
                local x = p1x + (scanY - p1y) * (p2x - p1x) / (p2y - p1y)
                if x < startX then startX = x end
                if x > endX then endX = x end
            end
            if p2y ~= p3y and scanY >= math_min(p2y, p3y) and scanY <= math_max(p2y, p3y) then
                local x = p2x + (scanY - p2y) * (p3x - p2x) / (p3y - p2y)
                if x < startX then startX = x end
                if x > endX then endX = x end
            end
            if p3y ~= p1y and scanY >= math_min(p3y, p1y) and scanY <= math_max(p3y, p1y) then
                local x = p3x + (scanY - p3y) * (p1x - p3x) / (p1y - p3y)
                if x < startX then startX = x end
                if x > endX then endX = x end
            end

            startX = math_max(minX, math_floor(startX))
            endX = math_min(maxX, math_floor(endX))

            local targetRow = buf[scanY]
            local targetZRow = zBuf[scanY]

            -- Ultra fast raw horizontal line draw
            for x = startX, endX do
                if targetZRow and targetZRow[x] and avgZ < targetZRow[x] then
                    targetZRow[x] = avgZ
                    targetRow[x] = colourIdx
                end
            end
        end
        return
    end

    z1, z2, z3 = z1 or avgZ, z2 or avgZ, z3 or avgZ
    u1, v1 = u1 or 0, v1 or 0
    u2, v2 = u2 or 1, v2 or 0
    u3, v3 = u3 or 0, v3 or 1

    local tex_h = #tex
    local tex_w = #tex[1]
    local b1_dx = (p2y - p3y) * invArea
    local b2_dx = (p3y - p1y) * invArea
    local z_dx = b1_dx * (z1 - z3) + b2_dx * (z2 - z3)
    local u_dx = b1_dx * (u1 - u3) + b2_dx * (u2 - u3)
    local v_dx = b1_dx * (v1 - v3) + b2_dx * (v2 - v3)

    for scanY = minY, maxY do
        local targetRow = buf[scanY]
        local targetZRow = zBuf[scanY]

        local b1 = ((p2y - p3y) * (minX - p3x) + (p3x - p2x) * (scanY - p3y)) * invArea
        local b2 = ((p3y - p1y) * (minX - p3x) + (p1x - p3x) * (scanY - p3y)) * invArea
        local b3 = 1.0 - b1 - b2
        local pixelZ = b1 * z1 + b2 * z2 + b3 * z3
        local u = b1 * u1 + b2 * u2 + b3 * u3
        local v = b1 * v1 + b2 * v2 + b3 * v3

        for x = minX, maxX do
            if b1 >= -0.001 and b2 >= -0.001 and b3 >= -0.001 then
                if targetZRow and targetZRow[x] and pixelZ < targetZRow[x] then
                    local tx = math_floor(u * (tex_w - 1)) + 1
                    local ty = math_floor(v * (tex_h - 1)) + 1

                    if u < 0 or u > 1 then tx = math_floor((u % 1) * tex_w) + 1 end
                    if v < 0 or v > 1 then ty = math_floor((v % 1) * tex_h) + 1 end
                    if tx < 1 then tx = 1 elseif tx > tex_w then tx = tex_w end
                    if ty < 1 then ty = 1 elseif ty > tex_h then ty = tex_h end

                    targetZRow[x] = pixelZ
                    targetRow[x] = tex[ty][tx]
                end
            end
            b1 = b1 + b1_dx
            b2 = b2 + b2_dx
            b3 = 1.0 - b1 - b2
            pixelZ = pixelZ + z_dx
            u = u + u_dx
            v = v + v_dx
        end
    end
end

local cleanColourRow = {}
local cleanZRow = {}
for x = 0, w - 1 do
    cleanColourRow[x] = colorToIndex(colours.lightBlue)
    cleanZRow[x] = math.huge
end

-- Clear buffers
function renderer.clear()
    for y = 0, h - 1 do
        local colourRow = buffer[y]
        local depthRow = zBuffer[y]
        if not colourRow then
            colourRow = {}
            buffer[y] = colourRow
        end
        if not depthRow then
            depthRow = {}
            zBuffer[y] = depthRow
        end

        for x = 0, w - 1 do
            colourRow[x] = cleanColourRow[x]
            depthRow[x] = cleanZRow[x]
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
                local pixelColor = buffer[y][x] or 15
                row[#row+1] = string.char(pixelColor)
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
                if colIdx < 0 or colIdx > 15 then colIdx = 15 end
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
        local sx, sy, sz = projectPoint(v[1] + pos.x, v[2] + pos.y, v[3] + pos.z, cam, fov)
        projected[i] = sx and {sx, sy, sz} or nil
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
                    table.insert(tris, {
                        p1 = p1,
                        p2 = p2,
                        p3 = p3,
                        z = (p1[3] + p2[3] + p3[3]) / 3,
                        tex = f.tex,
                        color = f.color or 14,
                    })
                end
            end
        end
    end

    table.sort(tris, function(a,b) return a.z > b.z end)

    for _, t in ipairs(tris) do
        rasterizeTriangle(
            t.p1[1], t.p1[2],
            t.p2[1], t.p2[2],
            t.p3[1], t.p3[2],
            t.z, t.color, t.tex,
            t.p1[3], t.p2[3], t.p3[3]
        )
    end
end

local c1, c2, c3, c4
local s1x, s1y, s1z
local s2x, s2y, s2z
local s3x, s3y, s3z
local s4x, s4y, s4z

-- World renderer
function renderer.draw(cam, fov)
    local renderDist = renderer.renderDist or 5
    local camChunkX = math.floor(cam.x / world.chunkSize)
    local camChunkZ = math.floor(cam.z / world.chunkSize)

    -- Precompute trigonometric angles
    local cosYaw, sinYaw = math_cos(cam.yaw), math_sin(cam.yaw)
    local cosPitch, sinPitch = math_cos(cam.pitch), math_sin(cam.pitch)
    local tanHalfFov = math_tan(fov / 2)
    local scale = hW / tanHalfFov

    local renderDistSq = (renderDist + 0.75) * (renderDist + 0.75)

    -- Ultra-fast zero-allocation cache wipe from previous frame
    for i = 1, clearCount do
        local tbl = clearList[i]
        tbl[1], tbl[2], tbl[3] = nil, nil, nil
    end
    clearCount = 0

    for cx = camChunkX - renderDist, camChunkX + renderDist do
        local xRow = world.chunks[cx]
        if xRow then
            local chunkDx = cx - camChunkX
            for cz = camChunkZ - renderDist, camChunkZ + renderDist do
                local chunkDz = cz - camChunkZ
                local chunk = nil
                if chunkDx * chunkDx + chunkDz * chunkDz <= renderDistSq then
                    chunk = xRow[cz]
                end

                if chunk and (chunk.mesh or chunk.transparentMesh) then
                    local chunkCenterX = (cx * 16) + 8
                    local chunkCenterZ = (cz * 16) + 8
                    local tX = chunkCenterX - cam.x
                    local tZ = chunkCenterZ - cam.z
                    local rotX = tX * cosYaw - tZ * sinYaw
                    local rotZ = tX * sinYaw + tZ * cosYaw

                    if rotZ > -chunkRadius and math_abs(rotX) <= (math_max(rotZ, 0) * tanHalfFov + chunkRadius) then
                        local meshLayers = { chunk.mesh, chunk.transparentMesh }
                        for layerIndex = 1, #meshLayers do
                            local mesh = meshLayers[layerIndex]
                            for i = 1, mesh and #mesh or 0 do
                                local face = mesh[i]

                                c1 = face.c1
                                c2, c3, c4 = face.c2, face.c3, face.c4
                                local vx = ((c1[1] + c2[1] + c3[1] + c4[1]) * 0.25) - cam.x
                                local vy = ((c1[2] + c2[2] + c3[2] + c4[2]) * 0.25) - cam.y
                                local vz = ((c1[3] + c2[3] + c3[3] + c4[3]) * 0.25) - cam.z
                                local norm = face.normal

                                if (vx * norm[1] + vy * norm[2] + vz * norm[3]) <= 0 then
                                    local validFace = true

                                -- Manual unrolled loop for the 4 corners to optimize register tracking
                                -- CORNER 1
                                local cx1, cy1, cz1 = c1[1], c1[2], c1[3]
                                local xTable = vCache[cx1]; if not xTable then xTable = {}; vCache[cx1] = xTable end
                                local yTable = xTable[cy1]; if not yTable then yTable = {}; xTable[cy1] = yTable end
                                local cv1 = yTable[cz1]

                                if cv1 and cv1[3] then
                                    s1x, s1y, s1z = cv1[1], cv1[2], cv1[3]
                                else
                                    local rx = cx1 - cam.x
                                    local rz = cz1 - cam.z
                                    local rX1 = rx * cosYaw - rz * sinYaw
                                    local rZ1 = rx * sinYaw + rz * cosYaw
                                    local finalY = (cy1 - cam.y) * cosPitch - rZ1 * sinPitch
                                    local finalZ = (cy1 - cam.y) * sinPitch + rZ1 * cosPitch

                                    if finalZ <= 0.1 then
                                        validFace = false
                                    else
                                        s1x = math_floor((rX1 * scale / finalZ) + hW)
                                        s1y = math_floor(hH - (finalY * scale / finalZ))
                                        s1z = finalZ

                                        if not cv1 then
                                            cv1 = {}
                                            yTable[cz1] = cv1
                                        end
                                        cv1[1], cv1[2], cv1[3] = s1x, s1y, s1z
                                        clearCount = clearCount + 1
                                        clearList[clearCount] = cv1
                                    end
                                end


                                -- CORNER 2
                                local cx2, cy2, cz2 = c2[1], c2[2], c2[3]
                                local xTable = vCache[cx2]; if not xTable then xTable = {}; vCache[cx2] = xTable end
                                local yTable = xTable[cy2]; if not yTable then yTable = {}; xTable[cy2] = yTable end
                                local cv2 = yTable[cz2]

                                if cv2 and cv2[3] then
                                    s2x, s2y, s2z = cv2[1], cv2[2], cv2[3]
                                else
                                    local rx = cx2 - cam.x
                                    local rz = cz2 - cam.z
                                    local rX1 = rx * cosYaw - rz * sinYaw
                                    local rZ1 = rx * sinYaw + rz * cosYaw
                                    local finalY = (cy2 - cam.y) * cosPitch - rZ1 * sinPitch
                                    local finalZ = (cy2 - cam.y) * sinPitch + rZ1 * cosPitch

                                    if finalZ <= 0.1 then
                                        validFace = false
                                    else
                                        s2x = math_floor((rX1 * scale / finalZ) + hW)
                                        s2y = math_floor(hH - (finalY * scale / finalZ))
                                        s2z = finalZ

                                        if not cv2 then
                                            cv2 = {}
                                            yTable[cz2] = cv2
                                        end
                                        cv2[1], cv2[2], cv2[3] = s2x, s2y, s2z
                                        clearCount = clearCount + 1
                                        clearList[clearCount] = cv2
                                    end
                                end


                                -- CORNER 3
                                local cx3, cy3, cz3 = c3[1], c3[2], c3[3]
                                local xTable = vCache[cx3]; if not xTable then xTable = {}; vCache[cx3] = xTable end
                                local yTable = xTable[cy3]; if not yTable then yTable = {}; xTable[cy3] = yTable end
                                local cv3 = yTable[cz3]

                                if cv3 and cv3[3] then
                                    s3x, s3y, s3z = cv3[1], cv3[2], cv3[3]
                                else
                                    local rx = cx3 - cam.x
                                    local rz = cz3 - cam.z
                                    local rX1 = rx * cosYaw - rz * sinYaw
                                    local rZ1 = rx * sinYaw + rz * cosYaw
                                    local finalY = (cy3 - cam.y) * cosPitch - rZ1 * sinPitch
                                    local finalZ = (cy3 - cam.y) * sinPitch + rZ1 * cosPitch

                                    if finalZ <= 0.1 then
                                        validFace = false
                                    else
                                        s3x = math_floor((rX1 * scale / finalZ) + hW)
                                        s3y = math_floor(hH - (finalY * scale / finalZ))
                                        s3z = finalZ

                                        if not cv3 then
                                            cv3 = {}
                                            yTable[cz3] = cv3
                                        end
                                        cv3[1], cv3[2], cv3[3] = s3x, s3y, s3z
                                        clearCount = clearCount + 1
                                        clearList[clearCount] = cv3
                                    end
                                end


                                -- CORNER 4
                                local cx4, cy4, cz4 = c4[1], c4[2], c4[3]
                                local xTable = vCache[cx4]; if not xTable then xTable = {}; vCache[cx4] = xTable end
                                local yTable = xTable[cy4]; if not yTable then yTable = {}; xTable[cy4] = yTable end
                                local cv4 = yTable[cz4]

                                if cv4 and cv4[3] then
                                    s4x, s4y, s4z = cv4[1], cv4[2], cv4[3]
                                else
                                    local rx = cx4 - cam.x
                                    local rz = cz4 - cam.z
                                    local rX1 = rx * cosYaw - rz * sinYaw
                                    local rZ1 = rx * sinYaw + rz * cosYaw
                                    local finalY = (cy4 - cam.y) * cosPitch - rZ1 * sinPitch
                                    local finalZ = (cy4 - cam.y) * sinPitch + rZ1 * cosPitch

                                    if finalZ <= 0.1 then
                                        validFace = false
                                    else
                                        s4x = math_floor((rX1 * scale / finalZ) + hW)
                                        s4y = math_floor(hH - (finalY * scale / finalZ))
                                        s4z = finalZ

                                        if not cv4 then
                                            cv4 = {}
                                            yTable[cz4] = cv4
                                        end
                                        cv4[1], cv4[2], cv4[3] = s4x, s4y, s4z
                                        clearCount = clearCount + 1
                                        clearList[clearCount] = cv4
                                    end
                                end


                                -- coarse screen frustum bound culling
                                if validFace then
                                    if (s1x < 0 and s2x < 0 and s3x < 0 and s4x < 0) or
                                       (s1x >= w and s2x >= w and s3x >= w and s4x >= w) or
                                       (s1y < 0 and s2y < 0 and s3y < 0 and s4y < 0) or
                                       (s1y >= h and s2y >= h and s3y >= h and s4y >= h) then
                                        validFace = false
                                    end
                                end

                                if validFace then
                                    local avgZ = (s1z + s2z + s3z + s4z) * 0.25
                                    rasterizeTriangle(
                                        s1x, s1y,
                                        s2x, s2y,
                                        s3x, s3y,
                                        avgZ, face.color or 14, face.tex,
                                        s1z, s2z, s3z,
                                        0, 0, face.uMax or 1, 0, face.uMax or 1, face.vMax or 1,
                                        face.layer == "transparent"
                                    )
                                    rasterizeTriangle(
                                        s1x, s1y,
                                        s3x, s3y,
                                        s4x, s4y,
                                        avgZ, face.color or 14, face.tex,
                                        s1z, s3z, s4z,
                                        0, 0, face.uMax or 1, face.vMax or 1, 0, face.vMax or 1,
                                        face.layer == "transparent"
                                    )
                                end
                                end
                            end
                        end
                    end
                end

            end
        end
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
    local xRow = world.chunks[cx]
    local chunk = xRow and xRow[cz]

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
