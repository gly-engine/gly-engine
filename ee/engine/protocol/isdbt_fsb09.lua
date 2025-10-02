local x, y, w, h = '0', '0', '1280', '720'

local function ccws_bootstrap()
    return 1
end

local function ccwss_position(channel, pos_x, pos_y, width, height)
    x, y = tostring(pos_x), tostring(pos_y)
    if width and height then
        w, h = tostring(width), tostring(height)
    end
end

local function ccws_command(_cmd)
    return function()
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

local function install(std, engine)
    local perfil_b = tostring(engine.envs.ginga_fsb_09)
    if perfil_b ~= 'true' and perfil_b ~= '' then
        error('old device!')
    end
end

local P = {
    install = install,
    play = ccws_command('start'),
    pause = ccws_command('pause'),
    resume = ccws_command('resume'),
    stop = ccws_command('stop'),
    source = function() end,
    position = ccwss_position,
    bootstrap = ccws_bootstrap,
}

return P
