local deafult_font_name = 'Tiresias'
local previous_font_name = deafult_font_name
local previous_font_size = 9
local current_font_name = deafult_font_name
local current_font_size = 8

local function apply_font()
    previous_font_name = current_font_name
    previous_font_size = current_font_size
    canvas:attrFont(current_font_name, current_font_size/1.59)
end

local function text_print(std, engine, canvas)
    return function(pos_x, pos_y, text)
    if previous_font_name ~= current_font_name or previous_font_size ~= current_font_size then
        apply_font()
    end

    local x = engine.offset_x + pos_x
    local y = engine.offset_y + pos_y
    canvas:drawText(x, y, text)
    end
end

local function text_mensure(canvas)
    return function(text)
    apply_font()
    local w, h = canvas:measureText(text)
    return w, h
    end
end

local function font_size(size)
    current_font_size = size
end

local function font_name( name)
    current_font_name = name
end

local function font_default(_font_id)
    current_font_name = deafult_font_name
end

local function font_previous()
    current_font_name, previous_font_size = previous_font_name, current_font_name
end

local function install(std, engine)
    std.text = std.text or {}
    std.text.font_size = font_size
    std.text.font_name = font_name
    std.text.font_default = font_default
    std.text.print = text_print(std, engine, engine.canvas)
    std.text.mensure = text_mensure(canvas)
    --@ todo remove
    std.text.mensure_width = function(v) return select(1, std.text.mensure(v)) end
    std.text.mensure_height = function(v) return select(2, std.text.mensure(v)) end
end

return {
    install=install,
    font_previous=font_previous
}
