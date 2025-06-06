local enable = false
local speed = 2
local frameskip = 0
local keybindings = false

local function loop(std, game, application, dt)
    if enable then
        frameskip = frameskip + 1
        if frameskip < speed then
            std.bus.emit('loop', dt)
        else
            frameskip = 0
        end
    end
end

local function real_key(std, game, application, rkey, rvalue)
    local index = 2
    local value = rvalue == 1 or rvalue == true
    if rkey == keybindings[1] then
        enable = value
    end
    if rkey == keybindings[11] and value then
        enable = not enable
    end
    while index < #keybindings do
        if rkey == keybindings[index] and value then
            if index <= 5 then
                speed = index
            else
                speed = 10 * (index - 5)
            end
        end
        index = index + 1
    end
end

local function real_keydown(std, game, application, key)
    real_key(std, game, application, key, 1)
end

local function real_keyup(std, game, application, key)
    real_key(std, game, application, key, 0)
end

local function event_bus(std, game)
    std.bus.listen_std('loop', loop)
    std.bus.listen_std('rkey', real_key)
    std.bus.listen_std('rkey1', real_keydown)
    std.bus.listen_std('rkey0', real_keyup)
end

local function install(std, game, application, key_binding)
    keybindings = key_binding
end

local P = {
    event_bus = event_bus,
    install = install
}

return P
