local shapes = {}

function shapes.createCylinder(segments, radius, height, texture)
    local vertices = {}
    local faces = {}

    for i = 0, segments - 1 do
        local angle = (i / segments) * math.pi * 2
        local cx = math.cos(angle) * radius
        local cz = math.sin(angle) * radius

        table.insert(vertices, {cx, -height/2, cz})

        table.insert(vertices, {cx, height/2, cz})
    end

    for i = 0, segments - 1 do
        local b1 = i * 2 + 1
        local t1 = i * 2 + 2
        local b2 = ((i + 1) % segments) * 2 + 1
        local t2 = ((i + 1) % segments) * 2 + 2

        table.insert(faces, { b1, t1, b2, tex = texture })

        table.insert(faces, { t1, t2, b2, tex = texture })
    end

    return vertices, faces
end

return shapes