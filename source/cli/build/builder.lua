local str_fs = require('source/shared/string/schema/fs')

--! @todo rewrite all the move() and build() 
local function move(src_filename, out_filename, options, args)
    local deps = {}
    local imported = {}
    local content = ''
    local prefix = options.prefix
    local cwd = str_fs.path(options.cwd).get_fullfilepath()
    local src_file = io.open(cwd..src_filename, 'r')
    local out_file = src_file and io.open(out_filename, 'w')
    local pattern_require = 'local ([%w_%-]+)%s*=%s*require%([\'"]([%w%._/-]+)[\'"]%)'
    local pattern_gameload = 'std%.node%.load%([\'"](.-)[\'"]%)'
    local pattern_comment = '%-%-'

    if src_file and out_file then
        for line in src_file:lines() do
            local pos_comment = line:find(pattern_comment)
            local pos_require = line:find(pattern_require) or line:find(pattern_gameload)
            local is_comment = pos_comment and pos_require and pos_comment < pos_require
            local line_require = { line:match(pattern_require) }
            local node_require = { line:match(pattern_gameload) }
            
            if node_require and #node_require > 0 and not is_comment then     
                local mod = str_fs.file(node_require[1])
                local module_path = (mod.get_unix_path()..mod.get_filename()):gsub('%./', '')
                local var_name = 'node_'..module_path:gsub('/', '_')
                local var_import = prefix..module_path:gsub('/', '_')
                if not imported[var_name..var_import] then
                    content = 'local '..var_name..' = require(\''..var_import..'\')\n'..content
                    imported[var_name..var_import] = true
                end
                deps[#deps + 1] = module_path..'.lua'
                content = content..line:gsub(pattern_gameload, 'std.node.load('..var_name..')')..'\n'
            elseif line_require and #line_require > 0 and not is_comment then
                local file_require = str_fs.lua(cwd..line_require[2]).get_fullfilepath()
                local module_path = str_fs.lua(line_require[2]).get_fullfilepath():gsub('%.lua$', '')
                local exist_as_file = io.open(file_require, 'r')
                local var_name = line_require[1]
                local module_prefix = exist_as_file and prefix or ''
                local module_alias = module_prefix..module_path:gsub('/', '_'):gsub('\\', '_')
                deps[#deps + 1] = module_path..'.lua'
                content = content..'local '..var_name..' = require(\''..module_alias..'\')\n'
                if exist_as_file then
                    exist_as_file:close()
                end
            else
                content = content..line..'\n'
            end
        end
    end

    if src_file then
        src_file:close()
    end
    if out_file then
        out_file:write(content)
        out_file:close()
    end

    return deps
end

local function build(path_in, src_in, path_out, src_out, options, args)
    local main = true
    local prefix = options.prefix
    local deps = {}
    local deps_builded = {}

    local src = str_fs.path(path_in, src_in)

    repeat
        if src then
            local index = 1
            local index_deps = #deps
            local out = src_out
            if not main then
                out = src.get_file()
                out = prefix..src.get_unix_path():gsub('%./', ''):gsub('/', '_')..out
            end
            local srcfile = src.get_fullfilepath()
            local outfile = str_fs.path(path_out, out).get_fullfilepath()
            local new_deps = move(srcfile, outfile, options, args)
            while index <= #new_deps do
                deps[index_deps + index] = new_deps[index]
                index = index + 1
            end
        end

        main = false
        src = nil

        do
            local index = 1
            while index <= #deps and not src do
                local dep = deps[index]
                if not deps_builded[dep] then
                    deps_builded[dep] = true
                    src = str_fs.file(dep)
                end
                index = index + 1
            end
        end
    until not src

    return true
end

local P = {
    move=move,
    build=build
}

return P
