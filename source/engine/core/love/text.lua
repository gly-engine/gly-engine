local util_decorator = require('src/lib/util/decorator')
local old_font = nil

local function text_print(std, engine, pos_x, pos_y, text)
    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    love.graphics.print(text, x, y)
end

local function font_size(std, engine, size)
    size = size < 1 and 1 or size
    old_font = love.graphics.getFont()
    local f = std.mem.cache('font_'..tostring(size), function()
        return love.graphics.newFont(size)
    end)
    love.graphics.setFont(f)
end

local function font_previous()
    love.graphics.setFont(old_font)
end

local function text_mensure(std, engine, text)
    local font = love.graphics.getFont()
    local t = tostring(text)
    local n = select(2, t:gsub('\n', '')) + 1
    local w = font:getWidth(t)
    local h = (font:getHeight('A') * n) + (font:getLineHeight() * n)
    return w, h
end

local function install(std, engine)
    std.text = std.text or {}
    std.text.print = util_decorator.prefix2(std, engine, text_print)
    std.text.font_size = util_decorator.prefix2(std, engine, font_size)
    std.text.font_name = util_decorator.prefix2(std, engine, function() end)
    std.text.font_default = util_decorator.prefix2(std, engine, function() end)
    std.text.mensure = util_decorator.prefix2(std, engine, text_mensure)
end

local P = {
    install = install,
    font_previous = font_previous
}

return P
