local math = require('math')

local function color(std, engine, canvas)
    return function(tint)
    local c = tint
    local R = math.floor(c/0x1000000)
    local G = math.floor(c/0x10000) - (R * 0x100)
    local B = math.floor(c/0x100) - (R * 0x10000) - (G * 0x100)
    local A = c - (R * 0x1000000) - (G * 0x10000) - (B * 0x100)
    canvas:attrColor(R, G, B, A)
    end
end

local function clear(std, engine, canvas)
    local change_color = color(std, engine, canvas)
    return function(tint)
    local x = engine.offset_x
    local y = engine.offset_y
    local width = engine.current.data.width
    local height = engine.current.data.height
    change_color(tint)
    canvas:drawRect('fill', x, y, width, height)
    end
end

local function rect2(std, engine, canvas)
    return function(mode, pos_x, pos_y, width, height, radius)
    local m = mode == 0 and 'fill' or 'frame'
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    -- only currenty supported by telemedia
    if canvas._dump_to_file and canvas.drawRoundRect then
        canvas:drawRoundRect(m, x, y, width, height, radius)
    else
        canvas:drawRect(m, x, y, width, height)
    end
    end
end

local function rect(std, engine, canvas)
    return function(mode, pos_x, pos_y, width, height, radius)
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    canvas:drawRect(mode == 0 and 'fill' or 'frame', x, y, width, height)
    end
end

local function line(std, engine, canvas)
    return function(x1, y1, x2, y2)
    local ox = engine.offset_x 
    local oy = engine.offset_y
    local px1 = ox + x1
    local py1 = oy + y1
    local px2 = ox + x2
    local py2 = oy + y2
    canvas:drawLine(px1, py1, px2, py2)
    end
end

local function install(std, engine)
    std.draw.clear = clear(std, engine, engine.canvas)
    std.draw.color = color(std, engine, engine.canvas)
    std.draw.rect2 = rect2(std, engine, engine.canvas)
    std.draw.rect = rect(std, engine, engine.canvas)
    std.draw.line = line(std, engine, engine.canvas)
end

return {
    install = install
}
