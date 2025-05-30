local version = require('source/version')
local zeebo_module = require('source/shared/module')
--
local engine_encoder = require('source/engine/api/system/encoder')
local engine_game = require('source/engine/api/system/app')
local engine_hash = require('source/engine/api/system/hash')
local engine_http = require('source/engine/api/system/http')
local engine_i18n = require('source/engine/api/system/i18n')
local engine_key = require('source/engine/api/system/key')
local engine_log = require('source/engine/api/system/log')
local engine_math = require('source/engine/api/system/math')
local engine_array = require('source/engine/api/system/array')
local engine_media = require('source/engine/api/system/media')
local engine_api_draw_fps = require('source/engine/api/draw/fps')
local engine_api_draw_text = require('source/engine/api/draw/text')
local engine_api_draw_poly = require('source/engine/api/draw/poly')
local engine_raw_memory = require('source/engine/api/raw/memory')
--
local callback_http = require('src/lib/protocol/http_callback')
--
local util_decorator = require('source/shared/var/object/root')
local color = require('src/lib/object/color')
local std = require('source/shared/var/object/std')
--
local application = application_default
local engine = {
    keyboard = function(a, b, c, d) end,
    current = application_default,
    root = application_default
}

local cfg_system = {
    exit = native_system_exit,
    reset = native_system_reset,
    title = native_system_title,
    get_fps = native_system_get_fps,
    get_secret = native_system_get_secret,
    get_language = native_system_get_language
}

local cfg_media = {
    bootstrap=native_media_bootstrap,
    position=native_media_position,
    resize=native_media_resize,
    resume=native_media_resume,
    source=native_media_source,
    pause=native_media_pause,
    play=native_media_play,
    stop=native_media_stop
}

local cfg_poly = {
    repeats = {
        native_cfg_poly_repeat_0 or false,
        native_cfg_poly_repeat_1 or false,
        native_cfg_poly_repeat_2 or false
    },
    triangle = native_draw_triangle,
    poly2 = native_draw_poly2,
    poly = native_draw_poly,
    line = native_draw_line
}

local cfg_text = {
    font_previous = native_text_font_previous
}

local cfg_http = {
    install = native_http_install,
    handler = native_http_handler,
    has_ssl = native_http_has_ssl,
    has_callback = native_http_has_callback,
    force = native_http_force_protocol
}

local cfg_log = {
    fatal = native_log_fatal,
    error = native_log_error,
    warn = native_log_warn,
    info = native_log_info,
    debug = native_log_debug
}

local cfg_base64 = {
    decode = native_base64_decode,
    encode = native_base64_encode
}

local cfg_json = {
    decode = native_json_decode,
    encode = native_json_encode
}

local cfg_xml = {
    decode = native_xml_decode,
    encode = native_xml_encode
}

function native_callback_loop(dt)
    std.milis = std.milis + dt
    std.delta = dt
    application.callbacks.loop(std, application.data)
end

function native_callback_draw()
    native_draw_start()
    application.callbacks.draw(std, application.data)
    native_draw_flush()
end

function native_callback_resize(width, height)
    application.data.width = width
    application.data.height = height
    std.app.width = width
    std.app.height = height
end

function native_callback_keyboard(key, value)
    engine.keyboard(std, engine, key, value)
end

function native_callback_http(id, key, data)
    if cfg_http.has_callback then
        return callback_http.func(engine['http_requests'][id], key, data)
    end
    return nil
end

function native_callback_init(width, height, game_lua)
    application = zeebo_module.loadgame(game_lua)

    if application then
        application.data.width = width
        application.data.height = height
        std.app.width = width
        std.app.height = height
    end
    
    std.bus = {
        emit=function() end,
        emit_next=function() end,
        listen=function() end,
        listen_std_engine=function() end
    }

    std.draw.color=native_draw_color
    std.draw.font=native_draw_font
    std.draw.rect=native_draw_rect
    std.draw.line=native_draw_line
    std.draw.image=native_image_draw
    std.image.load=native_image_load
    std.image.draw=native_image_draw
    std.text.print=native_text_print
    std.text.mensure=native_text_mensure
    std.text.font_size=native_text_font_size
    std.text.font_name=native_text_font_name
    std.text.font_default=native_text_font_default
    std.draw.clear=function(tint)
        native_draw_clear(tint, 0, 0, application.data.width, application.data.height)
    end

    engine.root = application
    zeebo_module.require(std, application, engine)
        :package('@memory', engine_raw_memory)
        :package('@game', engine_game, cfg_system)
        :package('@math', engine_math)
        :package('@array', engine_array)
        :package('@key', engine_key, {})
        :package('@draw.fps', engine_api_draw_fps)
        :package('@draw.text', engine_api_draw_text, cfg_text)
        :package('@draw.poly', engine_api_draw_poly, cfg_poly)
        :package('@color', color)
        :package('@log', engine_log, cfg_log)
        :package('math', engine_math.clib)
        :package('math.wave', engine_math.wave)
        :package('math.random', engine_math.clib_random)
        :package('http', engine_http, cfg_http)
        :package('base64', engine_encoder, cfg_base64)
        :package('json', engine_encoder, cfg_json)
        :package('xml', engine_encoder, cfg_xml)
        :package('i18n', engine_i18n, cfg_system)
        :package('hash', engine_hash, cfg_system)
        :package('media.video', engine_media, cfg_media)
        :package('mock.video', engine_media)
        :package('mock.audio', engine_media)
        :run()

    application.data.width, std.app.width = width, width
    application.data.height, std.app.height = height, height

    std.app.title(application.meta.title..' - '..application.meta.version)
    engine.current = application

    application.callbacks.init(std, application.data)
end

local P = {
    meta={
        title='gly-engine-lite',
        author='RodrigoDornelles',
        description='native lite',
        version=version
    }
}

return P
