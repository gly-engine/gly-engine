---@ todo remove all its not @c x oy @c y from std.key.axis

local function real_key(std, engine, rkey, rvalue)
    local value = (rvalue == 1 or rvalue == true) or false
    local key = engine.key_bindings[rkey] or (std.key.axis[rkey] and rkey)
    local key_media = std.key.media and std.key.media[rkey] ~= nil and rkey

    if key_media then
        std.key.media[key_media] = value
        std.bus.emit('key_media')
    end

    if key then
        std.key.axis[key] = value and 1 or 0
        std.key.press[key] = value

        if key == 'right' or key == 'left' then
            std.key.axis.x = std.key.axis.right - std.key.axis.left
        end
        
        if key == 'down' or key == 'up' then
            std.key.axis.y = std.key.axis.down - std.key.axis.up
        end
        
        std.bus.emit('key')
    end

    local a = std.key.axis
    std.key.press.any = (a.left + a.right + a.down + a.up + a.a + a.b + a.c + a.d + a.menu) > 0
end

local function real_keydown(std, engine, key)
    real_key(std, engine, key, 1)
end

local function real_keyup(std, engine, key)
    real_key(std, engine, key, 0)
end

local function install(std, engine, config)
    engine.key_bindings = config.bindings or {}
    engine.keyboard = real_key
    
    if config.has_media then
        std.key.media = {
            ch_up = false,
            ch_down = false,
            vol_up = false,
            vol_down = false
        }
    end

    std.bus.listen_std_engine('rkey', real_key)
    std.bus.listen_std_engine('rkey1', real_keydown)
    std.bus.listen_std_engine('rkey0', real_keyup)
end

return {
    install = install
}
