local util_decorator = require('source/shared/functional/decorator')

local modes = {
    [0] = 'fill',
    [1] = 'line'
}

local function color(std, engine, tint)
    local R = bit.band(bit.rshift(tint, 24), 0xFF)/255
    local G = bit.band(bit.rshift(tint, 16), 0xFF)/255
    local B = bit.band(bit.rshift(tint, 8), 0xFF)/255
    local A = bit.band(bit.rshift(tint, 0), 0xFF)/255
    love.graphics.setColor(R, G, B, A)
end

local function clear(std, engine, tint)
    color(nil, nil, tint)
    local x = engine.offset_x
    local y = engine.offset_y
    local width = engine.current.data.width
    local height = engine.current.data.height
    love.graphics.rectangle(modes[0], x, y, width, height)
end

local function rect2(std, engine, mode, pos_x, pos_y, width, height, radius)
    local r = radius and radius/2 or nil
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    love.graphics.rectangle(modes[mode], x, y, width, height, r, r)
end

local function rect(std, engine, mode, pos_x, pos_y, width, height)
    rect2(std, engine, mode, pos_x, pos_y, width, height)
end

local function line(std, engine, x1, y1, x2, y2)
    local ox = engine.offset_x 
    local oy = engine.offset_y
    local px1 = ox + x1
    local py1 = oy + y1
    local px2 = ox + x2
    local py2 = oy + y2
    love.graphics.line(px1, py1, px2, py2)
end

local function triangle(mode, x1, y1, x2, y2, x3, y3)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.line(x2, y2, x3, y3)
    if mode <= 1 then
        love.graphics.line(x1, y1, x3, y3)
    end
end

local function image_load(std, engine, src)
    return std.mem.cache('image'..src, function()
        return love.graphics.newImage(src)
    end)
end

local function image_draw(std, engine, src, pos_x, pos_y)
    local r, g, b, a = love.graphics.getColor()
    local image = image_load(std, engine, src)
    local x = engine.offset_x + (pos_x or 0)
    local y = engine.offset_y + (pos_y or 0)
    love.graphics.setColor(0xFF, 0xFF, 0xFF, 0xFF)
    love.graphics.draw(image, x, y)
    love.graphics.setColor(r, g, b, a) 
end

local function image_mensure(std, engine, src)
    local image = image_load(std, engine, src)
    if image then
        local w, h = image:getWidth(), image:getHeight()
        return w, h
    end
    return nil
end

local function install(std, engine)
    std.image.load = util_decorator.prefix2(std, engine, image_load)
    std.image.draw = util_decorator.prefix2(std, engine, image_draw)
    std.image.mensure = util_decorator.prefix2(std, engine, image_mensure)
    std.draw.clear = util_decorator.prefix2(std, engine, clear)
    std.draw.color = util_decorator.prefix2(std, engine, color)
    std.draw.rect2 = util_decorator.prefix2(std, engine, rect2)
    std.draw.rect = util_decorator.prefix2(std, engine, rect)
    std.draw.line = util_decorator.prefix2(std, engine, line)
end

local P = {
    install = install,
    triangle = triangle
}

return P
