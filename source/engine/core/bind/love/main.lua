local os = require('os')
--
local loadgame = require('source/shared/engine/loadgame')
local loadcore = require('source/shared/engine/loadcore')
--
local core_text = require('source/engine/core/bind/love/text')
local core_draw = require('source/engine/core/bind/love/draw')
local core_loop = require('source/engine/core/bind/love/loop')
local lib_api_encoder = require('source/engine/api/data/encoder')
local lib_api_game = require('source/engine/api/system/app')
local lib_api_hash = require('source/engine/api/data/hash')
local lib_api_http = require('source/engine/api/io/http')
local lib_api_i18n = require('source/engine/api/data/i18n')
local lib_api_key = require('source/engine/api/system/key')
local engine_log = require('source/engine/api/debug/log')
local engine_math = require('source/engine/api/math/basic')
local engine_math_bit = require('source/engine/api/math/bit')
local engine_math_clib = require('source/engine/api/math/clib')
local engine_math_random = require('source/engine/api/math/random')
local lib_api_media = require('source/engine/api/io/media')
local lib_api_array = require('source/engine/api/data/array')
local lib_draw_fps = require('source/engine/api/draw/fps')
local lib_draw_text = require('source/engine/api/draw/text')
local lib_draw_poly = require('source/engine/api/draw/poly')
local lib_draw_ui = require('source/engine/api/draw/ui')
local lib_raw_bus = require('source/engine/api/raw/bus')
local lib_raw_memory = require('source/engine/api/raw/memory')
local lib_raw_node = require('source/engine/api/raw/node')
--
local cfg_json_rxi = require('source/third_party/rxi_json')
local cfg_http_love = require('source/engine/protocol/http_love')
local cfg_logsystem = require('source/engine/protocol/logsystem_print')
--
local util_arg = require('source/shared/string/parse/args')
local util_envruntime = require('source/shared/var/runtime/lang')
--
local application_default = require('source/shared/var/object/root')
local color = require('source/engine/api/system/color')
local std = require('source/shared/var/object/std')

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
    local application = loadgame.script(game_title, application_default)
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

    loadcore.setup(std, application, engine)
        :package('@bus', lib_raw_bus)
        :package('@node', lib_raw_node)
        :package('@memory', lib_raw_memory)
        :package('@game', lib_api_game, cfg_system)
        :package('@math', engine_math)
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
        :package('math', engine_math_clib)
        :package('math.bit', engine_math_bit)
        :package('math.random', engine_math_random)
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
