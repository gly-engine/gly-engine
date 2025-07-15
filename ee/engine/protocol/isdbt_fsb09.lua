local x, y, w, h = '0', '0', '1280', '720'

local function ccws_bootstrap()
    return 1
end

local function ccwss_position(channel, pos_x, pos_y, width, height)
    x, y = tostring(pos_x), tostring(pos_y)
    if w and h then
        w, h = tostring(width), tostring(height)
    end
end

local function ccwss_resize(channel, width, height)
    ccwss_position(channel, x, y, width, height)
end

local function ccws_command()
    return function(_cmd)
        event.post('out', {
            class = 'ncl',
            type = 'edit',
            command = 'setPropertyValue',
            nodeId = 'application',
            propertyId = 'screen_'..x..'_'..y..'_'..w..'_'..h,
            value = '1'
        })
    end
end

local P = {
    play = ccws_command('start'),
    pause = ccws_command('pause'),
    resume = ccws_command('resume'),
    stop = ccws_command('stop'),
    source = function() end,
    resize = ccwss_resize,
    position = ccwss_position,
    bootstrap = ccws_bootstrap,
}

return P
