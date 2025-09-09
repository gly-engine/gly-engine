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

local fixture_196_key = ''
local pressed_196_red = false
local pressed_196_back = false
local fixture_196_looped = false

local function event_ginga(std, evt)
    if evt.class ~= 'key' then return end
    if not key_bindings[evt.key] then return end

    local raw_key = evt.key
    local is_red = raw_key == 'RED'
    local is_back = raw_key == 'BACK'
    local pressed = evt.type == 'press'

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

    --! @li @li https://github.com/gly-engine/gly-engine/issues/196
    --! Fix ensures at least syncing a loop when the button is pressed.
    if pressed and is_red then pressed_196_red = true end
    if pressed and is_back then pressed_196_back = true end
    if not pressed and is_red and pressed_196_red then fixture_196_key = 'a' return end
    if not pressed and is_back and pressed_196_back then fixture_196_key = 'menu' return end

    --! @li https://github.com/TeleMidia/ginga/issues/190
    --! this condtional is inverse in ---dev building flag.
    std.bus.emit('rkey', key_bindings[evt.key], evt.type == 'press')
end

local function event_fixed(std)
    if #fixture_196_key > 0 then
        if not fixture_196_looped then
            fixture_196_looped = true
        else
            std.bus.emit('rkey', fixture_196_key, 0)
            fixture_196_looped = false
            fixture_196_key = ''
        end
    end
end

local function install(std)
    std.bus.listen_std('ginga', event_ginga)
    std.bus.listen_std('loop', event_fixed)
end

local P = {
    install=install
}

return P
