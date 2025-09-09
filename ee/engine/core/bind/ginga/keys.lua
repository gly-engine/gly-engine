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
local pressed_196_key = ''
local fixture_196_looped = false

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

    --! @li @li https://github.com/gly-engine/gly-engine/issues/196
    --! Fix ensures at least syncing a loop when the button is pressed.
    if is_back_or_red and pressed then pressed_196_key = gly_key end
    if is_back_or_red and not pressed and pressed_196_key == gly_key then 
        fixture_196_key = gly_key
        return
    end

    --! @li https://github.com/TeleMidia/ginga/issues/190
    --! this condtional is inverse in ---dev building flag.
    std.bus.emit('rkey', gly_key, pressed)
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
    else
        pressed_196_key = ''
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
