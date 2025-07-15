local started = false
local current_color = 12
local font_size, font_previous = 5, 5
local delta, last = 0, time()
local keypress = {}

local keymap = {
    'up', 'down', 'left', 'right', 'a', 'b', 'c', 'd'
}

local colormap = {
    [0x000000] = 0,
    [0x1A1C2C] = 0,
    [0xFF00FF] = 1,
    [0xFF6DC2] = 1,
    [0xC87AFF] = 1,
    [0x701F7E] = 1,
    [0x873CBE] = 1,
    [0x5D275D] = 1,
    [0xFF0000] = 2,
    [0xE62937] = 2,
    [0xBE2137] = 2,
    [0xB13E53] = 2,
    [0xFFA100] = 3,
    [0xFFCB00] = 3,
    [0xEF7D57] = 3,
    [0xFDF900] = 4,
    [0xFFCD75] = 4,
    [0x00E430] = 5,
    [0xA7F070] = 5,
    [0x009E2F] = 6,
    [0x00752C] = 7,
    [0x38B764] = 7,
    [0x0052AC] = 8,
    [0x29366F] = 8,
    [0x0000FF] = 9,
    [0x3B5DC9] = 9,
    [0x0079F1] = 10,
    [0x41A6F6] = 10,
    [0x66BFFF] = 11,
    [0x73EFF7] = 11,
    [0xFFFFFF] = 12,
    [0xF4F4F4] = 12,
    [0xC8CCCC] = 13,
    [0x94B0C2] = 13,
    [0xD3B083] = 13,
    [0x828282] = 14,
    [0x566C86] = 14,
    [0x7F6A4F] = 14,
    [0x505050] = 15,
    [0x333C57] = 15,
    [0x4C3F2F] = 15
}

local function colorid(c)
    local colornew = colormap[c>>8]
    if not colornew then
        local r,g,b = (c>>24) & 255, (c>>16) & 255, (c>>8) & 255
        local best,d = nil, math.huge
        for k,v in pairs(colormap) do
            local kr,kg,kb = (k>>16)&255, (k>>8)&255, k&255
            local dist = ((r-kr)^2 + (g-kg)^2 + (b-kb)^2)
            if dist < d then d,best = dist,v end
        end
        colornew = best
    end
    return colornew
end

function native_draw_start()
end

function native_draw_flush()
end

function native_draw_clear(c)
    cls(colorid(c))
end

function native_draw_color(c)
    current_color = colorid(c)
end

function native_draw_line(x1, y1, x2, y2)
    line(x1, y1, x2, y2, current_color)
end

function native_draw_rect(mode, x, y, w, h)
    if mode == 0 then 
        rect(x, y, w, h, current_color)
    else
        local x2, y2 = x + w, y + h
        line(x, y, x2, y, current_color)
        line(x2 , y, x2, y2, current_color)
        line(x , y2, x2, y2, current_color)
        line(x , y, x, y2, current_color)
    end
end

function native_text_font_previous()
    font_size, font_previous = font_previous, font_size
end

function native_text_font_default()
end

function native_text_font_name()
end

function native_text_font_size(n)
    font_previous = font_size
    font_size = math.ceil(n/5)
    if font_size < 1 then
        font_size = 1
    end
end

function native_text_mensure(text)
    local s = font_size * 5
    local t = tostring(text)
    local a = #t > 1 and 1 or 0
    return #t * (a + s), s
end

function native_text_print(x, y, t)
    print(tostring(t), x, y, current_color, true, font_size)
end

native_cfg_poly_repeat_0 = true
native_cfg_poly_repeat_1 = true
tic80engine = tic80engine()
tic80game = tic80game()

function TIC()
    if not started then
        started = true
        if tic80engine and type(tic80engine) == 'table' and tic80engine.meta and tic80engine.meta.title then
            trace('engine: '..tic80engine.meta.title..' '..tostring(tic80engine.meta.version))
        end
        if tic80game and type(tic80game) == 'table' and tic80game.meta and tic80game.meta.title then
            trace('game: '..tic80game.meta.title..' '..tostring(tic80game.meta.version))
        end
        native_callback_init(240, 136, tic80game)
    else
        do
            local now = time()
            delta = now - last
            last = now
        end
        do
            local index = 1
            while index <= #keymap do
                local keyname = keymap[index]
                local pressed = btn(index - 1)
                if not keypress[index] and pressed then
                    keypress[index] = true
                    native_callback_keyboard(keyname, pressed)
                elseif keypress[index] and not pressed then
                    keypress[index] = false
                    native_callback_keyboard(keyname, pressed)
                end
                index = index + 1
            end
        end
        native_callback_loop(delta)
        native_callback_draw()
    end
end