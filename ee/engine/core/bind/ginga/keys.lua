local key_bindings={
    BACK='menu',
    BACKSPACE='menu',
    CURSOR_UP='up',
    CURSOR_DOWN='down',
    CURSOR_LEFT='left',
    CURSOR_RIGHT='right',
    RED='a',
    GREEN='b',
    YELLOW='c',
    BLUE='d',
    z='a',
    x='b',
    c='c',
    v='d',
    ENTER='a'
}

local unseen = {}
local deferred = {}

local function event_ginga(std, evt)
    if evt.class ~= 'key' then return end
    if not key_bindings[evt.key] then return end

    local pressed = evt.type == 'press'
    local raw_key = evt.key
    local gly_key = key_bindings[evt.key]
    local is_back = raw_key == 'BACK'
    local is_back_or_red = is_back or raw_key == 'RED'

    if is_back then
        event.post('out', {
            class = 'ncl',
            type = 'edit',
            command = 'setPropertyValue',
            nodeId = 'settings',
            propertyId = 'service.currentKeyMaster',
            value = 'application'
        })
    end

    --! @li https://github.com/TeleMidia/ginga/issues/190
    if canvas._dump_to_memory then pressed = not pressed end

    if pressed then
        unseen[gly_key] = true
        deferred[gly_key] = nil -- novo press antes do release adiado: continua pressionada
        std.bus.emit('rkey', gly_key, true)
    elseif unseen[gly_key] then
        deferred[gly_key] = true
    else
        std.bus.emit('rkey', gly_key, false)
    end
end

local function flush_releases(std)
    for key in pairs(deferred) do
        deferred[key] = nil
        std.bus.emit('rkey', key, false)
    end
    unseen = {}
end

local function install(std)
    std.bus.listen_std('ginga', event_ginga)
    std.bus.listen_std('post_loop', flush_releases)
end

local P = {
    install=install
}

return P
