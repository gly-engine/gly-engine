local util_decorator = require('src/lib/util/decorator')

--! @defgroup std
--! @{
--! @defgroup app
--! @{

--! @hideparam std
--! @hideparam engine
local function reset(std, engine)
    if std.node then
        std.bus.emit('exit')
        std.bus.emit('init')
    else
        engine.root.callbacks.exit(std, engine.root.data)
        engine.root.callbacks.init(std, engine.root.data)
    end
end

--! @hideparam std
local function exit(std)
    std.bus.emit('exit')
    std.bus.emit('quit')
end

--! @hideparam func
local function title(func, window_name)
    if func then
        func(window_name)
    end
end

--! @}
--! @}

--! @cond
local function install(std, engine, config)
    std = std or {}
    config = config or {}
    std.app = std.app or {}

    std.bus.listen('post_quit', function()
        if config.quit then
            config.quit()
        end
    end)

    std.app.title = util_decorator.prefix1(config.set_title, title)
    std.app.exit = util_decorator.prefix1(std, exit)
    std.app.reset = util_decorator.prefix2(std, engine, reset)
    std.app.get_fps = config.get_fps

    return std.app
end
--! @endcond

local P = {
    install=install
}

return P
