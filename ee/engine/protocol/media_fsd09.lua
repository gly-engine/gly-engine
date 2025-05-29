local http_util = require('src/lib/util/http')
local base_url = 'http://localhost:44642/dtv/mediaplayers/1'
local pos_x, pos_y, width, height = 0, 0, 1280, 720
local mutex = 0
local some_error = ''
local source = ''
local action_play = '{"url":"%s","action":"%s","pos":{"x":%d,"y":%d,"w":%d,"h":%d}}'
local action_stop = '{"action":"unload"}'

local function ccws_bootstrap()
    return 1
end

local function ccws_mutex()
    return mutex ~= 0
end

local function ccws_error()
    return #some_error > 0 and some_error
end

local function ccws_command(action)
    return function()
        if ccws_mutex() then return end
        if not source or #source == 0 then return end
        local headers = {['User-Agent'] = http_util.get_user_agent()}
        local session = tonumber(tostring(headers):match("0x(%x+)$"), 16)
        local body = string.format(action_play, source, action, pos_x, pos_y, width, height)

        mutex = session

        event.post({
            class = 'http',
            type = 'request',
            method = 'post',
            uri = base_url,
            body = body,
            headers = headers,
            session = session
        })
    end
end

local function ccws_source(channel, src)
    source = src
end

local function ccwss_position(channel, x, y, w, h)
    pos_x, pos_y = x, y
    if w and h then
        width, height = w, h
    end
end

local function ccwss_resize(channel, w, h)
    width, height = w, h
end

local function ccws_stop()
    if ccws_mutex() then some_error = 'abort' end
    local headers = {['User-Agent'] = http_util.get_user_agent()}
    local session = tonumber(tostring(headers):match("0x(%x+)$"), 16)
    pos_x, pos_y, width, height = 0, 0, 1280, 720
    source = ''

    mutex = session

    event.post({
        class = 'http',
        type = 'request',
        method = 'post',
        uri = base_url,
        body = action_stop,
        headers = headers,
        session = session
    })
end

local function callback(std, engine, evt)
    if evt.class ~= 'http' or not evt.session then return end
    if evt.session == mutex then
        some_error = ''
        mutex = 0
        if evt.error and #evt.error > 0 and (not evt.body or not evt.code) then
            some_error = evt.error
        end
        if evt.code and evt.code ~= 200 then
            some_error = evt.body
        end
    end
end

local function install(std)
    std.bus.listen_std_engine('ginga', callback)
end

local P = {
    install = install,
    play = ccws_command('start'),
    pause = ccws_command('pause'),
    resume = ccws_command('resume'),
    mutex = ccws_mutex,
    error = ccws_error,
    stop = ccws_stop,
    source = ccws_source,
    resize = ccwss_resize,
    position = ccwss_position,
    bootstrap = ccws_bootstrap,
}

return P
