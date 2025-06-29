local current_color = 7
local font_size, font_previous = 1, 1
local delta, last = 0, t()
local keypress = {}

local keymap = {
    'left', 'right', 'up', 'down', 'a', 'b'
}

function native_draw_start()
end

function native_draw_flush()
end

function native_draw_clear(c)
    current_color = c
    cls(c)
end

function native_draw_color(c)
    current_color = c
end

function native_draw_line(x1, y1, x2, y2)
    line(x1, y1, x2, y2, current_color)
end

function native_draw_rect(mode, x, y, w, h)
    if mode == 0 then 
        rectfill(x, y, x+w, y+h, current_color)
    else
        rect(x, y, x+w, y+h, current_color)
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
    font_size = max(1, flr(n / 5))
end

function native_text_mensure(text)
    local s = font_size * 4
    local t = tostring(text)
    return #t * s, s
end

function native_text_print(x, y, t)
    print(tostring(t), x, y, current_color)
end

native_cfg_poly_repeat_0 = true
native_cfg_poly_repeat_1 = true
pico8engine = pico8engine()
pico8game = pico8game()

function _init()
    if pico8engine and type(pico8engine) == 'table' and pico8engine.meta and pico8engine.meta.title then
        printh('engine: '..pico8engine.meta.title..' '..tostring(pico8engine.meta.version))
    end
    if pico8game and type(pico8game) == 'table' and pico8game.meta and pico8game.meta.title then
        printh('game: '..pico8game.meta.title..' '..tostring(pico8game.meta.version))
    end
    native_callback_init(128, 128, pico8game)
end

function _update60()
    local index = 1
    local now = t()
    delta = now - last
    last = now

    while index <= #keymap do
        local key = keymap[index]
        local pressed = btn(index - 1)
        if not keypress[index] and pressed then
            keypress[index] = true
            native_callback_keyboard(key, true)
        elseif keypress[index] and not pressed then
            keypress[index] = false
            native_callback_keyboard(key, false)
        end
        index = index + 1
    end

    native_callback_loop(delta*1000)
end

function _draw()
    cls()
    native_callback_draw()
end
