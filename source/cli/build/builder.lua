local util_fs = require('src/lib/util/fs')

local function optmizer(content, srcname, args)
    if args.dev and srcname == 'eeenginecoregingakeyslua' then
        content = content:gsub('evt%.type == \'press\'', 'evt.type ~= \'press\'')
    end
    if args.dev and srcname == 'eeenginecoregingamainlua' then
        content = content:gsub('pcall%(draw%)', 'draw()')
        content = content:gsub('pcall%(loop%)', 'loop()')
        content = content:gsub('event%.register%(%s*function%b()%s*.-end%s*%)', 'event.register(std.bus.trigger(\'ginga\'))')
    end
    if args.bundler and srcname == 'eeenginecoregingamainlua' then
        content = content:gsub('_ENV=nil', '')
    end

    return content:split('\n')
end

local function move(src_filename, out_filename, prefix, args)
    local deps = {}
    local content = ''
    local src_file = io.open(src_filename, 'r')
    local out_file = src_file and io.open(out_filename, 'w')
    local pattern_require = 'local ([%w_%-]+) = require%([\'"]([%w_/-]+)[\'"]%)'
    local pattern_gameload = 'std%.node%.load%([\'"](.-)[\'"]%)'
    local pattern_comment = '%-%-'

    if src_file and out_file then
        local file_content = src_file:read('*a')
        local lines = optmizer(file_content, src_filename:gsub('[^%a]', ''), args)
        
        local index = 1
        while index <= #lines do
            local line = lines[index]
            local pos_comment = line:find(pattern_comment)
            local pos_require = line:find(pattern_require) or line:find(pattern_gameload)
            local is_comment = pos_comment and pos_require and pos_comment < pos_require
            local line_require = { line:match(pattern_require) }
            local node_require = { line:match(pattern_gameload) }
            
            if node_require and #node_require > 0 and not is_comment then     
                local mod = util_fs.file(node_require[1])
                local module_path = (mod.get_unix_path()..mod.get_filename()):gsub('%./', '')
                local var_name = 'node_'..module_path:gsub('/', '_')
                deps[#deps + 1] = module_path..'.lua'
                content = 'local '..var_name..' = require(\''..prefix..module_path:gsub('/', '_')..'\')\n'..content
                content = content..line:gsub(pattern_gameload, 'std.node.load('..var_name..')')..'\n'
            elseif line_require and #line_require > 0 and not is_comment then
                local exist_as_file = io.open(line_require[2]..'.lua', 'r')
                local var_name = line_require[1]
                local module_path = line_require[2]
                local module_prefix = exist_as_file and prefix or ''
                deps[#deps + 1] = module_path..'.lua'
                content = content..'local '..var_name..' = require(\''..module_prefix..module_path:gsub('/', '_')..'\')\n'
                if exist_as_file then
                    exist_as_file:close()
                end
            else
                content = content..line..'\n'
            end
            index = index + 1
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

local function build(path_in, src_in, path_out, src_out, prefix, args)
    local main = true
    local deps = {}
    local deps_builded = {}

    local src = util_fs.path(path_in, src_in)

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
            local outfile = util_fs.path(path_out, out).get_fullfilepath()
            local new_deps = move(srcfile, outfile, prefix, args)
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
                    src = util_fs.file(dep)
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
