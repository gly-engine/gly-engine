function support()
    local file = io.open('README.md')
    local content = file:read('*a')
    local title1 = '## Engine Platform Support'
    local title2 = '### Execution Environments'
    local begin_pos = content:find(title1)
    local end_pos = #content --content:find('\n%-%-%-\n')
    content = content:sub(begin_pos + #title1, end_pos)
    content = content:gsub(':ok:', 'yes')
    content = content:gsub(':x:', 'no')
    file:close()
    return title2..content
end

function commands()
    local name = 'source/cli/main.lua'
    local file = io.open(name)
    local src = file:read('*a')
    local content = ''
    local next_cmd = src:gmatch('%.add_subcommand%(\'([%w%-]+)\'')
    repeat
        local cmd = next_cmd()
        if cmd then
            local pid = io.popen('lua '..name..' help '..cmd)
            local usage = pid:read('*a')
            local tutorial = usage:gsub('usage: ', ''):gsub(name, 'gly-cli')
            content = content..'@code{.sql}\n'..tutorial..'\n@endcode\n'
            pid:close()
        end
    until not cmd
    file:close()
    return content
end

function hardcore()
    
end

function gingaenvs()
    local content, index1, index2 = '', 1, 1
    local obj_ncl = require('source/shared/var/build/ncl')

    while index1 <= #obj_ncl.settings do
        content = content..'| '..obj_ncl.settings[index1].env..' |'
        while index2 <= #obj_ncl.settings[index1].ginga do
            content = content..' @c '..obj_ncl.settings[index1].ginga[index2]
            index2 = index2 + 1
        end
        content = content..'\n'
        index1 = index1 + 1
        index2 = 1
    end

    return content
end

function listlibmath()
    local content = ''
    local started = false
    for line in io.lines('source/engine/api/system/math.lua') do
        if line:find('std.math.acos') then
            started = true
        end
        local func = line:match('std%.math%.(%w+)')
        if started and func then
            content = content..'//! @c std.math.'..func..'\n'
        else
            started = false
        end
    end
    return content
end

local color_css = [[
//! <style>
//! element  {
//!     HorizontalAlignment center
//!     MinimumWidth 100
//!     RoundCorner 0
//!     LineThickness 3
//!     FontSize 18
//! }
//! agent {
//!     FontColor white
//! }
//! </style>
]]

function divcpp()
    return '*/\n/**\n*\n'
end

function color()
    local content = color_css

    local function is_dark(hex)
        if hex <= 0 then return false end
        return (0.2126 * ((hex >> 24) & 0xFF) + 0.7152 * ((hex >> 16) & 0xFF) + 0.0722 * ((hex >> 8) & 0xFF)) < 128
    end
    
    for line in io.lines('source/engine/api/system/color.lua') do
        local var, hex = line:match("std.color.([%w_]+)%s*=%s*(0x[0-9A-Fa-f]+)")
        if var and hex then
            local hex_value = tonumber(hex)
            local prefix = is_dark(hex_value) and "agent" or "rectangle"
            content = content..string.format('//! %s "%s" #%08X\n', prefix, var, hex_value)
        end
    end

    return '//! @startuml\n'..content..'//! @enduml'
end

local in_code = false
function code()
    in_code = true
    return '//! @code{.java}'
end

function endcode()
    in_code = false
    return '//! @endcode'
end

function ginga()
    return '@warning <strong>ginga is an enterprise part</strong>, using it in production requires a commercial license for the engine.'
end

local function source(file_name)
    local content = ''
    local file = io.open(file_name, 'r')
    repeat
        local line = file:read('*l')
        if line and not line:find('^%-%-%!') then
            content = content..line..'\n'
        end
    until not line
    file:close()
    return content
end

local function group(a, b, c)
    return '//! @defgroup '..a..'\n//! @{\n//! @defgroup '..b..' '..c..'\n//! @{\n'
end

local function game_requires(game)
    local content = ''
    local libraries = game.config and game.config.require or ''
    local next_library = libraries:gmatch('%S+')
    repeat
        local library = next_library()
        if library then
            content = content..' @c '..library
        end
    until not library
    if #content > 0 then
        content = '//! @pre require '..content..'\n'
    end
    return content
end

function main()
    local file = io.open(arg[1], 'r')
    if not file then
        return
    end

    local is_txt = arg[1]:sub(#arg[1] - 3) == '.txt'
    local is_lua = arg[1]:sub(#arg[1] - 3) == '.lua'
    local is_game = arg[1]:sub(#arg[1] - 7):find('%w%w%w%w%.lua') and arg[1]:find('samples')
    local renamefunc_pattern = '@renamefunc ([%w_]+)'
    local fake_func_pattern = '@fakefunc ([%w_]+%b())'
    local hideparam_pattern = '@hideparam ([%w_]+)'
    local include_pattern = '^local [%w_%-]+ = require%(\'(.-)\'%)'
    local function_pattern = '^local function ([%w_]+%b())'
    local classfunc_pattern = '^function ([%w_%.]+%b())'
    local literal_pattern = '^local ([%w_%-]+) = ([%d%w\'"-_]+)'
    local command_pattern = '@call (%w+)'
    local doxygen_pattern = '%-%-%!'

    if is_txt then
        io.write('/**\n')
    end

    if is_lua then
        io.write('//! @file '..arg[1]..'\n')
    end

    if is_game then
        local game = dofile(arg[1])
        local game_name = arg[1]:match('([%w_]+)/%w%w%w%w.lua$')
        local game_link = game_name == 'two_games' and '2games' or game_name 
        if not game.meta then
            game.meta, game.require = game, game.require
        end
        if game_link == 'stream' then
            game_link = 'fakestream.gamely.com.br @n https://videostream'
        end
        io.write(group('Examples', game_name, game.meta.title))
        io.write('//! @short @c \\@'..game_name..' @brief https://'..game_link..'.gamely.com.br\n')
        io.write(game_requires(game))
        if game.meta.author and #game.meta.author > 0 then
            io.write('//! @author '..game.meta.author..'\n')
        end
        io.write('//! @version '..game.meta.version..'\n')
        if game.meta.description then
            io.write('//! @par Brief \n//! @details '..game.meta.description..'\n')
        end
        game_src = source(arg[1])
    end

    local rename_function = false
    local params_hiden = {}
    local is_decorator_func = false

    repeat
        local line = file:read('*l')

        if line then
            local breakline = true
            local command = line:match(command_pattern)
            local doxygen = line:match(doxygen_pattern)
            local include = line:match(include_pattern)
            local clojure = line:match(function_pattern)
            local classfunc = line:match(classfunc_pattern)
            local hideparam = line:match(hideparam_pattern)
            local fake_func = line:match(fake_func_pattern)
            local rename_func = line:match(renamefunc_pattern)
            local variable, literal = line:match(literal_pattern)

            if is_lua and doxygen then
                line = line:gsub(doxygen_pattern, '//!')
                if line:match('@decorator') then
                    is_decorator_func = true
                end
            end

            if classfunc then
                clojure = classfunc:gsub('%.', '_')
            end

            if fake_func then
                clojure = fake_func
            end

            if rename_function and clojure then
                clojure = clojure:gsub('^([%w_]+)', rename_function)
                rename_function = false
            end

            if clojure and is_decorator_func then
                local func_name = clojure:match('^([%w_]+)')
                if func_name then
                    local next_line
                    repeat
                        next_line = file:read('*l')
                        if next_line then
                            local params = next_line:match('^%s*return%s+function%s*(%b())')
                            if params then
                                clojure = func_name .. params
                                break
                            end
                        end
                    until not next_line or next_line:find('^%s*end%s*$')
                end
                is_decorator_func = false
            end

            if #params_hiden > 0 and clojure then
                local index = 1
                while index <= #params_hiden do
                    clojure = clojure:gsub(params_hiden[index]..'[,]?', '')
                    index = index + 1
                end
                params_hiden = {}
                clojure = clojure:gsub(',%s*%)', ')')
            end

            if rename_func then
                rename_function = rename_func
            elseif hideparam then
                params_hiden[#params_hiden + 1] = hideparam
            elseif in_code then
                io.write(command == 'endcode' and _G[command]() or '//! '..line)
            elseif include then
                io.write('#include "'..include..'.lua"')
            elseif is_game and not doxygen then
                breakline = false
            elseif clojure and fake_func and is_txt then
                io.write('*/\nlocal function-'..clojure..';\n/**')
            elseif clojure and not is_txt then
                io.write('local function-'..clojure..';')
            elseif variable and literal and not is_txt then
                io.write('local '..variable..' = '..literal..';')
            elseif command and _G[command] then
                io.write(_G[command](line))
            elseif doxygen then
                io.write(line)
            elseif is_txt then
                io.write(line)
            elseif line:find('%S') then
                breakline = false
            end
            
            if breakline then
                io.write('\n')
            end
        end
    until not line

    if is_txt then
        io.write(' */\n')
    end

    if is_game then
        io.write('//! @par Source Code \n//! @code{.java}\n'..source(arg[1])..'\n//! @endcode\n')
        io.write('//! @} @}\n')
    end
end

main()
