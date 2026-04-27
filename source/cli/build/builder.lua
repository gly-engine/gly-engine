local str_fs = require('source/shared/string/schema/fs')
local json = require('source/third_party/rxi_json')

local function file_exists(path)
    local f = io.open(path, 'r')
    if not f then return false end
    f:close()
    return true
end

local function read_file(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    return content
end

local function dir_of(filepath)
    return (filepath:match('^(.*[/\\])') or ''):gsub('\\', '/')
end

local function ensure_slash(p)
    p = p:gsub('\\', '/')
    if #p > 0 and p:sub(-1) ~= '/' then
        return p..'/'
    end
    return p
end

local function build_candidates(base_path)
    return {
        base_path..'.lua',
        base_path..'/index.lua',
        base_path..'/init.lua',
        base_path..'/main.lua'
    }
end

local function pkg_entry(pkg_dir)
    local text = read_file(pkg_dir..'package.json')
    if not text then return nil end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' then return nil end
    -- prefer types: strip .d.ts and resolve the .lua counterpart
    if type(data.types) == 'string' then
        local from_types = data.types:gsub('%.d%.ts$', ''):gsub('\\', '/')
        if file_exists(pkg_dir..from_types..'.lua') then
            return from_types
        end
    end
    if type(data.main) == 'string' then
        return data.main:gsub('%.js$', ''):gsub('%.lua$', ''):gsub('\\', '/')
    end
    return nil
end

local function node_candidates(pkg_dir, subpath)
    local result = {}
    if subpath and #subpath > 0 then
        for _, candidate in ipairs(build_candidates(pkg_dir..subpath)) do
            result[#result+1] = candidate
        end
        return result
    end
    local entry = pkg_entry(pkg_dir)
    if entry then result[#result+1] = pkg_dir..entry..'.lua' end
    result[#result+1] = pkg_dir..'init.lua'
    result[#result+1] = pkg_dir..'index.lua'
    result[#result+1] = pkg_dir..'main.lua'
    return result
end

-- Resolve a require() path to { dep, module_path, use_prefix }
--   dep:         path added to the build queue
--   module_path: normalized path used to build the require alias (no .lua)
--   use_prefix:  whether options.prefix is applied to the alias
local function resolve_require(raw, parent_dir, src_dir, cwd, node_root)
    local lua_path = raw
        :gsub('^%./', ''):gsub('^%.\\', '')
        :gsub('%.lua$', '')
        :gsub('%.', '/')

    -- 1. Relative to parent file's directory (who made the require)
    if #parent_dir > 0 then
        for _, full in ipairs(build_candidates(parent_dir..lua_path)) do
            if file_exists(full) then
                local mp = full
                if mp:sub(1, #cwd) == cwd then mp = mp:sub(#cwd + 1) end
                mp = mp:gsub('%.lua$', '')
                return { dep=mp..'.lua', module_path=mp, use_prefix=true }
            end
        end
    end

    -- 2. Relative to cwd (entrypoint); if path starts with node_modules/ also try lua_modules/
    local candidates_cwd = { lua_path }
    local alt = lua_path:gsub('^node_modules/', 'lua_modules/')
    if alt ~= lua_path then candidates_cwd[2] = alt end
    for _, p in ipairs(candidates_cwd) do
        for _, full in ipairs(build_candidates(cwd..p)) do
            if file_exists(full) then
                local mp = full:gsub('^'..cwd, ''):gsub('%.lua$', '')
                return { dep=mp..'.lua', module_path=mp, use_prefix=true }
            end
        end
    end

    -- 3. Relative to current file's directory (src_dir)
    if #src_dir > 0 then
        for _, full in ipairs(build_candidates(src_dir..lua_path)) do
            if file_exists(full) then
                local mp = full
                if mp:sub(1, #cwd) == cwd then mp = mp:sub(#cwd + 1) end
                mp = mp:gsub('%.lua$', '')
                return { dep=mp..'.lua', module_path=mp, use_prefix=true }
            end
        end
    end

    -- 4. node_modules (only for non-relative, non-absolute paths)
    if raw:sub(1,1) ~= '.' and raw:sub(1,1) ~= '/' then
        local pkg, subpath
        if raw:sub(1,1) == '@' then
            pkg, subpath = raw:match('^(@[^/]+/[^/]+)(.*)')
        else
            pkg, subpath = raw:match('^([^/@][^/]*)(.*)')
        end
        if pkg then
            subpath = (subpath or ''):gsub('^/', '')
            local pkg_dir = node_root..pkg..'/'
            local node_candidates_list = node_candidates(pkg_dir, subpath)
            local i = 1
            while i <= #node_candidates_list do
                if file_exists(node_candidates_list[i]) then
                    local mp = node_candidates_list[i]:gsub('%.lua$', '')
                    return { dep=node_candidates_list[i], module_path=mp, use_prefix=true }
                end
                i = i + 1
            end
        end
    end

    -- Not found: treat as system/external library (no prefix, no dep processing)
    return { dep=nil, module_path=lua_path, use_prefix=false }
end

local function move(src_filename, out_filename, options)
    local deps = {}
    local imported = {}
    local content = ''
    local prefix = options.prefix
    local cwd = ensure_slash(str_fs.path(options.cwd).get_fullfilepath())
    local node_root = ensure_slash(options.node_modules or 'node_modules')

    -- Try cwd-relative first, fall back to path as-is (e.g. node_modules deps)
    local full_src = cwd..src_filename
    if not file_exists(full_src) then full_src = src_filename end
    local src_dir = dir_of(full_src)

    local src_file = io.open(full_src, 'r')
    local out_file = src_file and io.open(out_filename, 'w')
    local pattern_require = "local ([%w_%-]+)%s*=%s*require%(['\"]([%w%.@_/-]+)['\"]%)"
    local pattern_gameload = "std%.node%.load%(['\"](.-)['\"]\\%)"
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
                content = content..line:gsub(pattern_gameload, 'std.node.load('..var_name..')')..'\\n'
            elseif line_require and #line_require > 0 and not is_comment then
                local var_name = line_require[1]
                local resolved = resolve_require(line_require[2], src_dir, src_dir, cwd, node_root)
                local module_prefix = resolved.use_prefix and prefix or ''
                local module_alias = module_prefix..resolved.module_path:gsub('/', '_'):gsub('\\', '_')
                if resolved.dep then
                    deps[#deps + 1] = resolved.dep
                end
                content = content..'local '..var_name..' = require(\''..module_alias..'\')\n'
            else
                content = content..line..'\n'
            end
        end
    end

    if src_file then src_file:close() end
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
            local new_deps = move(srcfile, outfile, options)
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
    move = move,
    build = build
}

return P
