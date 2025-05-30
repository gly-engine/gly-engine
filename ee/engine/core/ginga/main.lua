local zeebo_module = require('source/shared/module')
--
local core_draw = require('ee/engine/core/ginga/draw')
local core_text = require('ee/engine/core/ginga/text')
local core_keys = require('ee/engine/core/ginga/keys')
--
local engine_encoder = require('source/engine/api/system/encoder')
local engine_game = require('source/engine/api/system/app')
local engine_hash = require('source/engine/api/system/hash')
local engine_http = require('source/engine/api/system/http')
local engine_i18n = require('source/engine/api/system/i18n')
local engine_keys = require('source/engine/api/system/key')
local engine_log = require('source/engine/api/system/log')
local engine_math = require('source/engine/api/system/math')
local engine_media = require('source/engine/api/system/media')
local engine_array = require('source/engine/api/system/array')
local engine_getenv = require('source/engine/api/system/getenv')
local engine_storage = require('source/engine/api/system/storage')
local engine_api_draw_ui = require('source/engine/api/draw/ui')
local engine_api_draw_fps = require('source/engine/api/draw/fps')
local engine_api_draw_text = require('source/engine/api/draw/text')
local engine_api_draw_poly = require('source/engine/api/draw/poly')
local engine_bus = require('source/engine/api/raw/bus')
local engine_fps = require('source/engine/api/raw/fps')
local engine_node = require('source/engine/api/raw/node')
local engine_memory = require('source/engine/api/raw/memory')
--
local cfg_json_rxi = require('source/third_party/rxi_json')
local cfg_logsystem = require('src/lib/protocol/logsystem_print')
local cfg_http_ginga = require('ee/lib/protocol/http_fsb09')
local cfg_persistent = require('ee/lib/protocol/storage_fsd09')
local cfg_mediaplayer = require('ee/lib/protocol/media_fsd09')
--local cfg_http_ginga2 = require('ee/lib/protocol/http_fsc09')
--
local util_decorator = require('source/shared/var/object/root')
local color = require('src/lib/object/color')
local std = require('source/shared/var/object/std')
--
local application = application_default

--! @short nclua:canvas
--! @li <http://www.telemidia.puc-rio.br/~francisco/nclua/referencia/canvas.html>
local canvas = canvas

--! @short nclua:event
--! @li <http://www.telemidia.puc-rio.br/~francisco/nclua/referencia/event.html>
local event = event

--! @field canvas <http://www.telemidia.puc-rio.br/~francisco/nclua/referencia/canvas.html>
--! @field event <http://www.telemidia.puc-rio.br/~francisco/nclua/referencia/event.html>
local engine = {
    current = application_default,
    root = application_default,
    canvas = canvas,
    event = event,
    offset_x = 0,
    offset_y = 0,
    delay = 1,
    fps = 0
}

--! @short clear ENV
--! @brief GINGA?
_ENV = nil

local cfg_system = {
    get_language = function() return 'pt-BR' end
}

local cfg_poly = {
    repeats={true, true},
    line=canvas.drawLine,
    object=canvas
}

local cfg_fps_control = {
    list={60, 30, 20, 15, 10},
    time={10, 30, 40, 60, 90},
    uptime=event.uptime
}

local cfg_text = {
    font_previous = core_text.font_previous
}

local function register_event_loop()
    event.register(function(evt) pcall(std.bus.emit, 'ginga', evt) end)
end

local function register_fixed_loop()
    local tick = nil
    local loop = std.bus.trigger('loop')
    local draw = std.bus.trigger('draw')    
    tick = function()
        pcall(loop)
        canvas:attrColor(0, 0, 0, 0)
        canvas:clear()
        pcall(draw)
        canvas:flush()
        event.timer(engine.delay, tick)
    end

    event.timer(engine.delay, tick)
end

local function main(evt, gamefile)
    if evt.class and evt.class ~= 'ncl' or evt.action ~= 'start' and evt.type ~= 'presentation' then return end

    engine.envs = evt
    application = zeebo_module.loadgame(gamefile)

    zeebo_module.require(std, application, engine)
        :package('@bus', engine_bus)
        :package('@node', engine_node)
        :package('@fps', engine_fps, cfg_fps_control)
        :package('@memory', engine_memory)
        :package('@game', engine_game, cfg_system)
        :package('@math', engine_math)
        :package('@array', engine_array)
        :package('@keys1', engine_keys)
        :package('@keys2', core_keys)
        :package('@draw', core_draw)
        :package('@draw.text', core_text)
        :package('@draw.text2', engine_api_draw_text, cfg_text)
        :package('@draw.ui', engine_api_draw_ui)
        :package('@draw.fps', engine_api_draw_fps)
        :package('@draw.poly', engine_api_draw_poly, cfg_poly)
        :package('@color', color)
        :package('@log', engine_log, cfg_logsystem)
        :package('@getenv', engine_getenv, engine)
        :package('math', engine_math.clib)
        :package('math.wave', engine_math.wave)
        :package('math.random', engine_math.clib_random)
        :package('hash', engine_hash, {'ginga'})
        :package('media.video', engine_media, cfg_mediaplayer)
        --:package('media.audio', engine_media, {})
        :package('json', engine_encoder, cfg_json_rxi)
        --:package('http', engine_http, cfg_http_ginga2)
        :package('http', engine_http, cfg_http_ginga)
        :package('storage', engine_storage, cfg_persistent)
        :package('i18n', engine_i18n, cfg_system)
        :run()

    application.data.width, application.data.height = canvas:attrSize()
    std.app.width, std.app.height = application.data.width, application.data.height

    std.node.spawn(application)

    engine.root = application
    engine.current = application

    register_event_loop()
    register_fixed_loop()

    std.bus.emit_next('load')
    std.bus.emit_next('init')

    if evt.class then
        event.unregister(main)
    end
end

--! @defgroup ginga
--! @{ @note for enterprise features contact bizdev@zedia.com.br @}
local ok, crt0 = pcall(require, 'crt0') 
if ok then
    crt0(main, cfg_json_rxi, cfg_http_ginga.str_http)
else
    event.register(main)
end

return main
