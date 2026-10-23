local function real_key(std, engine, rkey, rvalue)
    local value = (rvalue == 1 or rvalue == true) or false
    local key = engine.key_bindings[rkey] or rkey

    if std.key.press[key] ~= nil or not engine.keyboard_lock then
        std.key.press[key] = value

        if key == 'right' or key == 'left' then
            std.key.axis.x = (std.key.press['right'] and 1 or 0) - (std.key.press['left'] and 1 or 0) 
        end
        
        if key == 'down' or key == 'up' then
            std.key.axis.y = (std.key.press['down'] and 1 or 0) - (std.key.press['up'] and 1 or 0)
        end
        
        std.key.any = false
        for _, value in pairs(std.key.press) do
            if value then std.key.any = true end
        end

        if std.bus and std.bus.emit and engine.keyboard_lock then
            std.bus.emit('key', key, value)
        end
    end
end

local function real_keydown(std, engine, key)
    real_key(std, engine, key, 1)
end

local function real_keyup(std, engine, key)
    real_key(std, engine, key, 0)
end

local function install(std, engine, config)
    config = config or {}
    engine.key_bindings = config.bindings or {}
    engine.keyboard = real_key

    for _, key in pairs(engine.key_bindings) do
        real_key(std, engine, key, false)
    end

    if std.bus.listen_std_engine then
        std.bus.listen('load', function() engine.keyboard_lock = true end)
        std.bus.listen_std_engine('rkey', real_key)
        std.bus.listen_std_engine('rkey1', real_keydown)
        std.bus.listen_std_engine('rkey0', real_keyup)
    end
end

return {
    install = install
}
