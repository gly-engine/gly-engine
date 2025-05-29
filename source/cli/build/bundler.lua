local util_fs = require('src/lib/util/fs')

--! @defgroup cli
--! @{
--! @defgroup bundler
--! @{
--!
--! @short unify lua files
--!
--! @details
--! The bundler is for general use and can be used in any lua code in addition to games made for the gly engine.
--!
--! @li optimized recursive search for dependencies in your files.
--! @li minification by removing comments, extrabreaklines and tabulations.
--! @li compatibility with lua distributions that do not expose standard libs in require.
--!
--! @par Downloads
--!
--! @li <https://get.gamely.com.br/bundler.lua>
--! @li <https://get.gamely.com.br/bundler_cli.lua>
--!
--! @par Usage
--! @li gly engine cli
--! @code{.sql}
--! lua cli.lua bundler src/main.lua --dist ./dist
--! @endcode
--! 
--! @li bundler cli
--! @code{.sql}
--! lua bundler_cli.lua src/main.lua dist/main.lua
--! @endcode
--!
--! @par Result
--! @li @b Input
--! - @c lib_common_math.lua
--! @code{.java}
--! local function sum(a, b)
--!     return a + b
--! end
--! 
--! local P = {
--!     sum = sum
--! }
--! 
--! return P
--! @endcode
--! - @c main.lua
--! @code{.java}
--! local os = require('os')
--! local zeebo_math = require('lib_common_math')
--! 
--! print(zeebo_math.sum(1, 2))
--! os.exit(0)
--! @endcode
--! 
--! @li @b Output 
--! - @c main.lua
--! @code{.java}
--! local os = ((function() local x, y = pcall(require, 'os'); return x and y end)()) or _G.os
--! local lib_common_math = nil
--! 
--! local function main()
--!     local zeebo_math = lib_common_math()
--!     print(zeebo_math.sum(1, 2))
--!     os.exit(0)
--! end
--! 
--! lib_common_math = function()
--!     local function sum(a, b)
--!         return a + b
--!     end
--! 
--!     local P = {
--!         sum = sum
--!     }
--!     
--!     return P
--! end
--! 
--! main()
--! @endcode

--! @short bundler library
--! @par Example
--! @code{.java}
--! local bundler = require('bundler')
--! 
--! local ok, msg = bundler.build('src/main.lua', 'dist/main.lua')
--! 
--! if not ok then
--!     error(msg)
--! end
--! @endcode
local function build(src, dest)
    local from = 'main'
    local src_path = util_fs.file(src)
    local dest_path = util_fs.file(dest)
    local relative = src_path and dest_path and src_path.get_unix_path()
    local src_file, src_err = io.open((src_path and src_path.get_fullfilepath()) or '')
    local pattern_identify = '^table: (%w+)$'
    local pattern_require1 = '^%s*require%([\'"](.-)[\'"]%)(.*)'
    local pattern_require2 = '^%s*([%w_%-]+)%s*=%s*require%([\'"](.-)[\'"]%)(.*)'
    local pattern_require3 = '^%s*local%s*([%w_%-]+)%s*=%s*require%([\'"](.-)[\'"]%)(.*)'
    local pattern_require4 = '^%s*require%s*[\'"](.-)[\'"](.*)'
    local pattern_require5 = '^%s*([%w_%-]+)%s*=%s*require%s*[\'"](.-)[\'"](.*)'
    local pattern_require6 = '^%s*local%s*([%w_%-]+)%s*=%s*require%s*[\'"](.-)[\'"](.*)'
    local deps_list = {}
    local deps_dict = {}
    local main_content = ''
    local main_before = ''
    local main_after = ''
    local lib_name = nil

    if not src_file then
        return false, src_err or 'src is required'
    end

    if not dest_path then
        return false, 'dest is required'
    end

    while src_file do
        if from == 'lib' then
            main_before = main_before..'local '..lib_name..' = nil\n'
            main_after = main_after..lib_name..' = function()\n'
        end
        repeat
            local line = src_file and src_file:read()
            local eof = not line

            line = (line or ''):gsub('\n', '')
            line = line:gsub('^%s*', '')
            line = line:gsub('*%s$', '')
            line = line:gsub('^%-%-$', '')
            line = line:gsub('^_ENV = nil$', '')
            line = line:gsub('%s*%-%-([^\'\"%[%]].*)$', '')

            local line_require1 = { line:match(pattern_require1) }
            local line_require2 = { line:match(pattern_require2) }
            local line_require3 = { line:match(pattern_require3) }
            local line_require4 = { line:match(pattern_require4) }
            local line_require5 = { line:match(pattern_require5) }
            local line_require6 = { line:match(pattern_require6) }
            local requires = {line_require2, line_require3, line_require5, line_require6}
            local line_variable = '-'
            local line_package = line_require4[1] or line_require1[1]
            local line_suffix = line_require4[2] or line_require1[2]

            do
                local index = 1
                while index <= #requires and not line_package do
                    line_variable, line_package, line_suffix = requires[index][1], requires[index][2], requires[index][3]
                    index = index + 1
                end
            end

            if line_package then
                if not deps_dict[line_package] then
                    deps_list[#deps_list + 1] = line_package
                    deps_dict[line_package]={line={}, var={}, suffix={}}
                end
                if line_variable == '-' then
                    line = '-'..'- part '
                elseif line:find('local') then
                    line = '-'..'- local '
                else
                    line = '-'..'- global '
                end

                local index = #deps_dict[line_package].line + 1
                local lib_id = tostring(deps_dict[line_package]):gsub('0x', ''):match(pattern_identify)
                local lib_func = line_package:gsub('/', '_'):gsub('%.', '_'):gsub('\\', '_')..'_'..lib_id

                line = line..lib_func..' '..line_variable..' '
                deps_dict[line_package].line[index] = line
                deps_dict[line_package].var[index] = line_variable
                deps_dict[line_package].suffix[index] = line_suffix
                deps_dict[line_package].func = lib_func
            end

            if not eof and line and #line > 0 then
                if from == 'main' then
                    main_content = main_content..line..'\n'
                else
                    main_after = main_after..line..'\n'
                end
            end
        until eof
    
        if from == 'lib' then
            main_after = main_after..'end\n-'..'-\n'
        end

        if src_file then
            src_file:close()
            src_file = nil
        end

        do
            lib_name = nil
            local index = 1
            while index <= #deps_list and not lib_name do
                local lib = deps_list[index]
                if not deps_dict[lib].imported then
                    local file1 = util_fs.lua(lib).get_fullfilepath()
                    local file2 = util_fs.lua(relative..lib).get_fullfilepath()
                    src_file = io.open(file1, 'r') or io.open(file2, 'r')
                    from = src_file and 'lib' or 'system'
                    lib_name = src_file and deps_dict[lib].func
                    deps_dict[lib].imported = from
                end
                index = index + 1
            end
        end
    end

    do
        local index1 = 1
        local index2 = 1
        while index1 <= #deps_list do
            index2 = 1
            local lib = deps_list[index1]
            while index2 <= #deps_dict[lib].line do
                local line = deps_dict[lib].line[index2]..'\n'
                local lib_type = line:match('^-'..'- (%w+)')
                if deps_dict[lib].imported == 'system' then
                    if not deps_dict[lib].header then
                        main_before = 'local '..deps_dict[lib].var[index2]..' = ((function() local x, y = pcall(require, \''..lib
                            ..'\'); return x and y end)()) or _G.'..deps_dict[lib].var[index2]..'\n'..main_before
                        deps_dict[lib].header = true
                    end
                    main_after = main_after:gsub(line, '')
                    main_content = main_content:gsub(line, '')                    
                elseif lib_type == 'part' then
                    local replacer = deps_dict[lib].func..'()'..deps_dict[lib].suffix[index2]
                    line = line:sub(1, #line - 2)..'-'
                    main_after = main_after:gsub(line, replacer)
                    main_content = main_content:gsub(line, replacer)
                else
                    local replacer = deps_dict[lib].var[index2]..' = '..deps_dict[lib].func..'()'..deps_dict[lib].suffix[index2]..'\n'
                    if lib_type == 'local' then
                        replacer = 'local '..replacer
                    end
                    main_after = main_after:gsub(line, replacer)
                    main_content = main_content:gsub(line, replacer)
                end
                index2 = index2 + 1
            end
            index1 = index1 + 1
        end
    end

    if #main_content == 0 and #main_after == 0 and #main_before == 0 then
        return false, 'nothing to do!'
    end

    do
        local id = tostring(deps_dict):gsub('0x', ''):match(pattern_identify)
        main_content = 'local function main_'..id..'()\n'..main_content..'end\n'
        main_content = main_before..main_content..main_after..'return main_'..id..'()\n'
    end

    src_file, src_err = io.open(dest_path.get_fullfilepath(), 'w')
    
    if not src_file then
        return false, src_err or 'cannot write bundle file'
    end

    src_file:write(main_content)
    src_file:close()

    return true
end

--! @}
--! @}

local P = {
    build=build
}

return P
