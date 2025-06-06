--! @defgroup std
--! @{
--! @defgroup app
--! @{

--! @renamefunc fps_show 
--! @hideparam std
--! @hideparam engine
--! @hideparam pos_x
--! @hideparam pos_y
--! @pre the <b>mode 3</b> require @c math
--! 
--! @param show @c integer
--! @li mode 1: FPS
--! @li mode 2: FPS / FPS Limit
--! @li mode 3: FPS Real Time / FPS / FPS Limit
local function draw_fps(std, engine, show, pos_x, pos_y)
    if show < 1 then return end

    local x = engine.current.config.offset_x + pos_x
    local y = engine.current.config.offset_y + pos_y
    local s = 4

    std.draw.color(0xFFFF00FF)

    if show >= 1 then
        std.draw.rect(0, x, y, 40, 24)
    end
    if show >= 2 then
        std.draw.rect(0, x + 48, y, 40, 24)
    end
    if show >= 3 then
        std.draw.rect(0, x + 96, y, 40, 24)
    end
    std.draw.color(0x000000FF)
    std.text.font_size(16)
    if show >= 3 then
        local floor = std.math.floor or math.floor or function() return 'XX' end
        local fps =  floor((1/std.delta) * 1000)
        std.text.print(x + s, y, fps)
        s = s + 46
    end
    if show >= 1 then
        std.text.print(x + s, y, engine.fps)
        s = s + 46
    end
    if show >= 2 then
        std.text.print(x + s, y, engine.root.config.fps_max)
        s = s + 46
    end
end

--! @}
--! @}

local function event_bus(std, engine)
    std.bus.listen('post_draw', function()
        engine.current = engine.root
        draw_fps(std, engine, engine.root.config.fps_show, 8, 8)
    end)
end

local function install(std, engine)
    std.app = std.app or {}
    std.app.fps_show = function(show)
        engine.root.config.fps_show = show
    end
end

local P = {
    event_bus=event_bus,
    install=install
}

return P
