local math = require('math')
local util_decorator = require('source/shared/functional/decorator')

local function color(std, engine, canvas, tint)
    local c = tint
    local R = math.floor(c/0x1000000)
    local G = math.floor(c/0x10000) - (R * 0x100)
    local B = math.floor(c/0x100) - (R * 0x10000) - (G * 0x100)
    local A = c - (R * 0x1000000) - (G * 0x10000) - (B * 0x100)
    canvas:attrColor(R, G, B, A)
end

local function clear(std, engine, canvas, tint)
    color(std, engine, canvas, tint)
    local x = engine.offset_x
    local y = engine.offset_y
    local width = engine.current.data.width
    local height = engine.current.data.height
    canvas:drawRect('fill', x, y, width, height)
end

local function rect(std, engine, canvas, mode, pos_x, pos_y, width, height)
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    canvas:drawRect(mode == 0 and 'fill' or 'frame', x, y, width, height)
end

local function line(std, engine, canvas, x1, y1, x2, y2)
    local ox = engine.offset_x 
    local oy = engine.offset_y
    local px1 = ox + x1
    local py1 = oy + y1
    local px2 = ox + x2
    local py2 = oy + y2
    canvas:drawLine(px1, py1, px2, py2)
end

local function image_load(std, engine, canvas, src)
    return std.mem.cache('image'..src, function()
        local file = io.open(src, 'rb')
        if not file then return nil end
        file:close()
        return canvas:new(src)
    end)
end

local function image_draw(std, engine, canvas, src, pos_x, pos_y)
    local image = image_load(std, engine, canvas, src)
    if image then
        local x = engine.offset_x + (pos_x or 0)
        local y = engine.offset_y + (pos_y or 0)
        canvas:compose(x, y, image)
    end
end

local function image_mensure(std, engine, canvas, src)
    local image = image_load(std, engine, canvas, src)
    if image then
        local w, h = image:attrSize()
        return w, h
    end
    return nil
end

local function install(std, engine)
    std.image.load = util_decorator.prefix3(std, engine, engine.canvas, image_load)
    std.image.draw = util_decorator.prefix3(std, engine, engine.canvas, image_draw)
    std.image.mensure = util_decorator.prefix3(std, engine, engine.canvas, image_mensure)
    std.draw.clear = util_decorator.prefix3(std, engine, engine.canvas, clear)
    std.draw.color = util_decorator.prefix3(std, engine, engine.canvas, color)
    std.draw.rect = util_decorator.prefix3(std, engine, engine.canvas, rect)
    std.draw.line = util_decorator.prefix3(std, engine, engine.canvas, line)
end

local P = {
    install = install
}

return P
