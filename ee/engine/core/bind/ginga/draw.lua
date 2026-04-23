local math = require('math')

local function color(std, engine)
    return function(tint)
    local c = tint
    local R = math.floor(c/0x1000000)
    local G = math.floor(c/0x10000) - (R * 0x100)
    local B = math.floor(c/0x100) - (R * 0x10000) - (G * 0x100)
    local A = c - (R * 0x1000000) - (G * 0x10000) - (B * 0x100)
    
    local pip = engine.pip
    if pip then
        engine.canvasgly[1]:attrColor(R, G, B, A)
        engine.canvasgly[2]:attrColor(R, G, B, A)
        engine.canvasgly[3]:attrColor(R, G, B, A)
        engine.canvasgly[4]:attrColor(R, G, B, A)
    else
        engine.canvas:attrColor(R, G, B, A)
    end
    end
end

local function clear(std, engine)
    local change_color = color(std, engine)
    return function(tint)
    local x = engine.offset_x
    local y = engine.offset_y
    local width = engine.current.data.width
    local height = engine.current.data.height
    change_color(tint)
    local pip = engine.pip
    if pip then
        engine.canvasgly[1]:drawRect('fill', 0, 0, width, height)
        engine.canvasgly[2]:drawRect('fill', 0, 0, width, height)
        engine.canvasgly[3]:drawRect('fill', 0, 0, width, height)
        engine.canvasgly[4]:drawRect('fill', 0, 0, width, height)
    else
        engine.canvas:drawRect('fill', x, y, width, height)
    end
    end
end

local function rect2(std, engine)
    return function(mode, pos_x, pos_y, width, height, radius)
    local m = mode == 0 and 'fill' or 'frame'
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    local pip = engine.pip
    
    if pip then
        if engine.canvasgly[1]._dump_to_file and engine.canvasgly[1].drawRoundRect then
            engine.canvasgly[1]:drawRoundRect(m, x, y, width, height, radius)
        else
            engine.canvasgly[1]:drawRect(m, x, y, width, height)
        end
        if engine.canvasgly[2]._dump_to_file and engine.canvasgly[2].drawRoundRect then
            engine.canvasgly[2]:drawRoundRect(m, x, y - pip.y, width, height, radius)
        else
            engine.canvasgly[2]:drawRect(m, x, y - pip.y, width, height)
        end
        if engine.canvasgly[3]._dump_to_file and engine.canvasgly[3].drawRoundRect then
            engine.canvasgly[3]:drawRoundRect(m, x - (pip.x + pip.w), y - pip.y, width, height, radius)
        else
            engine.canvasgly[3]:drawRect(m, x - (pip.x + pip.w), y - pip.y, width, height)
        end
        if engine.canvasgly[4]._dump_to_file and engine.canvasgly[4].drawRoundRect then
            engine.canvasgly[4]:drawRoundRect(m, x, y - (pip.y + pip.h), width, height, radius)
        else
            engine.canvasgly[4]:drawRect(m, x, y - (pip.y + pip.h), width, height)
        end
    else
        if engine.canvas._dump_to_file and engine.canvas.drawRoundRect then
            engine.canvas:drawRoundRect(m, x, y, width, height, radius)
        else
            engine.canvas:drawRect(m, x, y, width, height)
        end
    end
    end
end

local function rect(std, engine)
    return function(mode, pos_x, pos_y, width, height, radius)
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    local m = mode == 0 and 'fill' or 'frame'
    local pip = engine.pip
    
    if pip then
        engine.canvasgly[1]:drawRect(m, x, y, width, height)
        engine.canvasgly[2]:drawRect(m, x, y - pip.y, width, height)
        engine.canvasgly[3]:drawRect(m, x - (pip.x + pip.w), y - pip.y, width, height)
        engine.canvasgly[4]:drawRect(m, x, y - (pip.y + pip.h), width, height)
    else
        engine.canvas:drawRect(m, x, y, width, height)
    end
    end
end

local function line(std, engine)
    return function(x1, y1, x2, y2)
    local pip = engine.pip

    if pip then
        engine.canvasgly[1]:drawLine(x1, y1, x2, y2)
        engine.canvasgly[2]:drawLine(x1, y1 - pip.y, x2, y2 - pip.y)
        engine.canvasgly[3]:drawLine(x1 - (pip.x + pip.w), y1 - pip.y, x2 - (pip.x + pip.w), y2 - pip.y)
        engine.canvasgly[4]:drawLine(x1, y1 - (pip.y + pip.h), x2, y2 - (pip.y + pip.h))
    else
        local ox = engine.offset_x
        local oy = engine.offset_y
        local px1 = ox + x1
        local py1 = oy + y1
        local px2 = ox + x2
        local py2 = oy + y2
        engine.canvas:drawLine(px1, py1, px2, py2)
    end
    end
end

local function install(std, engine)
    std.draw.clear = clear(std, engine)
    std.draw.color = color(std, engine)
    std.draw.rect2 = rect2(std, engine)
    std.draw.rect = rect(std, engine)
    std.draw.line = line(std, engine)
end

return {
    install = install
}
