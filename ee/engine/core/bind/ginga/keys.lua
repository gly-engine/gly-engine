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

--! @li https://github.com/TeleMidia/ginga/issues/190
local function event_ginga(std, evt)
    if evt.class ~= 'key' then return end
    if not key_bindings[evt.key] then return end
    if evt.key == 'BACK' then
        event.post('out', {
            class = 'ncl',
            type = 'edit',
            command = 'setPropertyValue',
            nodeId = 'settings',
            propertyId = 'service.currentKeyMaster',
            value = 'application'
        })
    end
    std.bus.emit('rkey', key_bindings[evt.key], evt.type == 'press')

end

local function install(std)
    std.bus.listen_std('ginga', event_ginga)
end

local P = {
    install=install
}

return P
