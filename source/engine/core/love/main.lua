local os = require('os')
--
local zeebo_module = require('src/lib/common/module')
--
local core_text = require('src/engine/core/love/text')
local core_draw = require('src/engine/core/love/draw')
local core_loop = require('src/engine/core/love/loop')
local lib_api_encoder = require('src/lib/engine/api/encoder')
local lib_api_game = require('src/lib/engine/api/app')
local lib_api_hash = require('src/lib/engine/api/hash')
local lib_api_http = require('src/lib/engine/api/http')
local lib_api_i18n = require('src/lib/engine/api/i18n')
local lib_api_key = require('src/lib/engine/api/key')
local engine_log = require('src/lib/engine/api/log')
local lib_api_math = require('src/lib/engine/api/math')
local lib_api_media = require('src/lib/engine/api/media')
local lib_api_array = require('src/lib/engine/api/array')
local lib_draw_fps = require('src/lib/engine/draw/fps')
local lib_draw_text = require('src/lib/engine/draw/text')
local lib_draw_poly = require('src/lib/engine/draw/poly')
local lib_draw_ui = require('src/lib/engine/draw/ui')
local lib_raw_bus = require('src/lib/engine/raw/bus')
local lib_raw_memory = require('src/lib/engine/raw/memory')
local lib_raw_node = require('src/lib/engine/raw/node')
--
local cfg_json_rxi = require('source/third_party/rxi_json')
local cfg_http_love = require('src/lib/protocol/http_love')
local cfg_logsystem = require('src/lib/protocol/logsystem_print')
--
local util_arg = require('src/lib/common/args')
local util_envruntime = require('src/lib/util/env_runtime')
--
local color = require('src/lib/object/color')
local std = require('src/lib/object/std')

local cfg_poly = {
    triangle=core_draw.triangle,
    poly=love.graphics.polygon,
    modes={'fill', 'line', 'line'}
}

local cfg_keys = {
    ['escape']='menu',
    ['return']='a',
    up='up',
    left='left',
    right='right',
    down='down',
    z='a',
    x='b',
    c='c',
    v='d'
}

local cfg_system = {
    get_language = util_envruntime.get_sys_lang,
    set_fullscreen = love.window.setFullscreen,
    get_fullscreen = love.window.getFullscreen,
    set_title = love.window.setTitle,
    get_fps = love.timer.getFPS,
    quit = love.event.quit
}

local cfg_text = {
    font_previous = core_text.font_previous
}

function love.load(args)
    local screen = util_arg.get(args, 'screen')
    local fullscreen = util_arg.has(args, 'fullscreen')
    local game_title = util_arg.param(arg, {'screen'}, 2)
    local application = zeebo_module.loadgame(game_title)
    local engine = {offset_x=0,offset_y=0}
    
    if screen then
        local w, h = screen:match('(%d+)x(%d+)')
        application.data.width = tonumber(w)
        application.data.height = tonumber(h)
    end

    if application then
        std.app.width = application.data.width
        std.app.height = application.data.height
        love.window.setMode(std.app.width, std.app.height, {
            fullscreen=fullscreen,
            resizable=true
        })
    end

    zeebo_module.require(std, application, engine)
        :package('@bus', lib_raw_bus)
        :package('@node', lib_raw_node)
        :package('@memory', lib_raw_memory)
        :package('@game', lib_api_game, cfg_system)
        :package('@math', lib_api_math)
        :package('@array', lib_api_array)
        :package('@key', lib_api_key, cfg_keys)
        :package('@draw.text', core_text)
        :package('@draw.text2', lib_draw_text, cfg_text)
        :package('@draw.poly', lib_draw_poly, cfg_poly)
        :package('@draw.fps', lib_draw_fps)
        :package('@draw.ui', lib_draw_ui)
        :package('@draw', core_draw)
        :package('@loop', core_loop)
        :package('@color', color)
        :package('@log', engine_log, cfg_logsystem)
        :package('math', lib_api_math.clib)
        :package('math.wave', lib_api_math.wave)
        :package('math.random', lib_api_math.clib_random)
        :package('mock.video', lib_api_media)
        :package('mock.music', lib_api_media)
        :package('http', lib_api_http, cfg_http_love)
        :package('json', lib_api_encoder, cfg_json_rxi)
        :package('i18n', lib_api_i18n, cfg_system)
        :package('hash', lib_api_hash, cfg_system)
        :run()

    std.node.spawn(application)

    engine.root = application
    engine.current = application

    std.app.title(application.meta.title..' - '..application.meta.version)

    love.update = std.bus.trigger('loop')
    love.resize = std.bus.trigger('resize')
    love.draw = std.bus.trigger('draw')
    love.keypressed = std.bus.trigger('rkey1')
    love.keyreleased = std.bus.trigger('rkey0')
    
    std.bus.emit_next('load')
    std.bus.emit_next('init')
end
