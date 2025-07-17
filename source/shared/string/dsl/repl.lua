--! @defgroup Languages
--! @{
--! 
--! @defgroup dsl
--! @{
--! 
--! @defgroup repl REPL
--! @{
--!
--! @par Backus-Naur Form
--! @startebnf
--! line = exit | frame_skip | [frame_skip], variable, ["=", value (* assignment *)];
--! frame_skip = [digit], "!" ;
--! digit = { ? 0 - 9 ? }- ;
--! exit = "?" ;
--! @endebnf
--!
--! @par Usage
--! @code{.sql}
--! lua cli.lua run game.lua --core repl
--! @endcode
--!
--! @}
--! @}
--! @}

local zeebo_module = require('source/shared/module')
--
local engine_encoder = require('source/engine/api/data/encoder')
local engine_game = require('source/engine/api/system/app')
local engine_hash = require('source/engine/api/data/hash')
local engine_http = require('source/engine/api/io/http')
local engine_i18n = require('source/engine/api/data/i18n')
local engine_key = require('source/engine/api/system/key')
local engine_math = require('source/engine/api/system/math')
local engine_array = require('source/engine/api/data/array')
local engine_api_draw_ui = require('source/engine/api/draw/ui')
local engine_raw_bus = require('source/engine/api/raw/bus')
local engine_raw_node = require('source/engine/api/raw/node')
local engine_raw_memory = require('source/engine/api/raw/memory')
--
local application_default = require('source/shared/var/object/root')
local color = require('source/engine/api/system/color')
local std = require('source/shared/var/object/std')
--
local cfg_json_rxi = require('source/third_party/rxi_json')
local cfg_http_curl = require('source/engine/protocol/http_curl')
--
local engine = {
    current = application_default,
    root = application_default,
    offset_x = 0,
    offset_y = 0
}

local function line_skip_frames(line_src)
    local frames, line = line_src:match('(%d+)!(.*)')
    if frames and line then
        return frames, line
    end
    frames, line = line_src:match('(!)(.*)')
    if frames and line then
        return 1, line
    end
    return 0, line_src
end

local function line_assignment(line)
    local variable, assignment = line:match('(.*)=(.*)')
    if variable and assignment then
        return variable, assignment
    end
    return line, ''
end

local function evaluate(var, assign, std, game, application)
    local script = ''

    if assign and #assign > 0 then
        script = 'return function(std, game, application)\n'..var..'=('..assign..')\n return ('..var..')\nend'
    elseif var and #var > 0 then
        script = 'return function(std, game, application)\nreturn ('..var..')\nend'
    end

    if script and #script > 0 then
        local ok, output = pcall(function()
            local func, err = load(script)
            if func then
                local result = func()
                return result(std, game, application)
            else
                error(err)
            end
        end)

        return ok, tostring(output)
    end

    return true, ''
end

local function main()
    local frames = 0
    local variable = ''
    local assignment = ''
    local application = zeebo_module.loadgame(arg[1]) or application_default

    zeebo_module.require(std, application, engine)
        :package('@bus', engine_raw_bus)
        :package('@node', engine_raw_node)
        :package('@memory', engine_raw_memory)
        :package('@game', engine_game, {})
        :package('@math', engine_math)
        :package('@array', engine_array)
        :package('@key', engine_key, {})
        :package('@draw.ui', engine_api_draw_ui)
        :package('@color', color)
        :package('math', engine_math.clib)
        :package('math.random', engine_math.clib_random)
        :package('http', engine_http, cfg_http_curl)
        :package('json', engine_encoder, cfg_json_rxi)
        :package('i18n', engine_i18n, {})
        :package('hash', engine_hash, {})
        :run()

    std.node.spawn(application)

    engine.root = application
    engine.current = application

    std.bus.emit_next('load')
    std.bus.emit_next('init')
    
    while true do
        local index = 1
        local output = ''
        local ok, line = pcall(io.read)

        if not ok or line == nil or line == '?' then
            break
        end

        frames, line = line_skip_frames(line)
        variable, assignment = line_assignment(line)
        frames = tonumber(frames)

        ok, output = evaluate(variable, assignment, std, application.data, application)
        if ok then
            print(output)
        else
            io.stderr:write(output)
            print('\n')
        end

        while index <= frames do
            std.bus.emit('loop')
            std.bus.emit('draw')
            index = index + 1
        end
    end
end

if not package.loaded['modulename'] then
    main()
end
