local version=require('src/version')
--
local engine_game=require('src/lib/engine/api/app')
local engine_key=require('src/lib/engine/api/key')
local engine_math=require('src/lib/engine/api/math')
local engine_array=require('src/lib/engine/api/array')
local engine_draw_text=require('src/lib/engine/draw/text')
local engine_draw_poly=require('src/lib/engine/draw/poly')
local engine_raw_memory=require('src/lib/engine/raw/memory')
--
local color=require('src/lib/object/color')
local std=require('src/lib/object/std')
--
local util_lua=require('src/lib/util/lua')
--
local f=function(a,b)end
local engine={keyboard=f}
local application={
    meta={title='', version=''},
    data={width=1280,height=720},
    config={offset_x=0,offset_y=0},
    callbacks={loop=f,draw=f,exit=f,init=f}
}
std.log={fatal=f,error=f,warn=f,info=f,debug=f}
std.bus={emit=f,emit_next=f,listen=f,listen_std_engine=f}
std.i18n={next=f,back=f,get_language=function()return'en-US'end}

local cfg_system={
    exit=native_system_exit,
    reset=native_system_reset,
    title=native_system_title,
    get_fps=native_system_get_fps,
    get_secret=native_system_get_secret,
    get_language=native_system_get_language
}

local cfg_poly={
    repeats={
        native_cfg_poly_repeat_0 or false,
        native_cfg_poly_repeat_1 or false,
        native_cfg_poly_repeat_2 or false
    },
    triangle=native_draw_triangle,
    poly2=native_draw_poly2,
    poly=native_draw_poly,
    line=native_draw_line
}

local cfg_text={
    font_previous=native_text_font_previous
}

function native_callback_loop(dt)
    std.milis, std.delta=std.milis + dt, dt
    application.callbacks.loop(std, application.data)
end

function native_callback_draw()
    native_draw_start()
    application.callbacks.draw(std, application.data)
    native_draw_flush()
end

function native_callback_resize(width, height)
    application.data.width=width
    application.data.height=height
    std.app.width=width
    std.app.height=height
end

function native_callback_keyboard(key, value)
    engine.keyboard(std, engine, key, value)
end

function native_callback_init(width, height, game_lua)
    local ok, script=true, game_lua

    if type(script) == 'string' then
        ok, script=util_lua.eval(script)
    end

    if not script then
        ok, script=pcall(loadfile, 'game.lua')
    end

    if not ok or not script then
        error(script, 0)
    end

    std.app.width=width
    std.app.height=height
    script.data={width=width,height=height}
    script.config=application.config
    application=script
    
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

    engine.root=application
    engine_raw_memory.install(std, engine)
    engine_game.install(std, engine, cfg_system)
    engine_key.install(std, engine, {})
    engine_math.install(std, engine)
    engine_math.wave.install(std, engine)
    engine_math.clib.install(std, engine)
    engine_math.clib_random.install(std, engine)
    engine_array.install(std, engine, nil, 'array')
    engine_draw_text.install(std, engine, cfg_text)
    engine_draw_poly.install(std, engine, cfg_poly)
    color.install(std, engine)

    std.app.title(application.meta.title..' - '..application.meta.version)
    engine.current=application
    application.callbacks.init(std, application.data)
end

local P={
    meta={
        title='gly-engine-micro',
        author='RodrigoDornelles',
        description='shh!',
        version=version
    }
}

return P
