--! @defgroup std
--! @{
--! @defgroup app
--! @{

--! @decorator
local function reset(std, engine)
    if std.node then
        return function()
            std.bus.emit('exit')
            std.bus.emit('init')
        end
    end
    return function()
        engine.root.callbacks.exit(engine.root.data, std)
        engine.root.callbacks.init(engine.root.data, std)
    end
end

--! @decorator
local function exit(std)
    return function()
        std.bus.emit('exit')
        std.bus.emit('quit')
    end
end

--! @decorator
local function title(func)
    return function(window_name)
        if func then
            func(window_name)
        end
    end
end

--! @brief get application version
--! @fakefunc get_version()
--! @renamefunc get_name
--! @brief get application name
--! @decorator
local function get_info(my, info)
    return function()
        return my.root.meta[info]
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

    std.app.title = title(config.set_title)
    std.app.exit = exit(std)
    std.app.reset = reset(std, engine)
    std.app.get_name = get_info(engine, 'title')
    std.app.get_version = get_info(engine, 'version')
    std.app.get_fps = config.get_fps

    return std.app
end
--! @endcond

local P = {
    install=install
}

return P
