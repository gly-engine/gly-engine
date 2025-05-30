local util_decorator = require('source/shared/functional/decorator')

local deafult_font_name = 'Tiresias'
local previous_font_name = deafult_font_name
local previous_font_size = 9
local current_font_name = deafult_font_name
local current_font_size = 8

local function apply_font()
    previous_font_name = current_font_name
    previous_font_size = current_font_size
    canvas:attrFont(current_font_name, current_font_size/1.34)
end

local function text_print(std, engine, canvas, pos_x, pos_y, text)
    if previous_font_name ~= current_font_name or previous_font_size ~= current_font_size then
        apply_font()
    end

    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    canvas:drawText(x, y, text)
end

local function text_mensure(canvas, text)
    apply_font()
    local w, h = canvas:measureText(text)
    return w, h
end

local function font_size(std, engine, size)
    current_font_size = size
end

local function font_name(std, engine, name)
    current_font_name = name
end

local function font_default(std, engine, font_id)
    current_font_name = deafult_font_name
end

local function font_previous()
    current_font_name, previous_font_size = previous_font_name, current_font_name
end

local function install(std, engine)
    std.text = std.text or {}
    std.text.print = util_decorator.prefix3(std, engine, engine.canvas, text_print)
    std.text.font_size = util_decorator.prefix2(std, engine, font_size)
    std.text.font_name = util_decorator.prefix2(std, engine, font_name)
    std.text.font_default = util_decorator.prefix2(std, engine, font_default)
    std.text.mensure = util_decorator.prefix1(canvas, text_mensure)
end

local P = {
    install=install,
    font_previous=font_previous
}

return P
