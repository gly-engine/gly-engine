local str_fs = require('source/shared/string/schema/fs')

local pattern_require = 'require%s*%(%s*([\'"])([^\'"]+)%1%s*%)'

local formats = {
    cjs = {'module.exports = (function() {', '})();'},
    esm = {'export default (function() {', '})();'},
    global = {'window.%s = (function() {', '})();'}
}

local function normalize(path)
    local prefix = path:sub(1, 1) == '/' and '/' or ''
    local parts = {}
    path:gsub('[^/]+', function(part)
        if part == '..' and #parts > 0 and parts[#parts] ~= '..' then
            parts[#parts] = nil
        elseif part ~= '.' then
            parts[#parts + 1] = part
        end
    end)
    return prefix..table.concat(parts, '/')
end

local function dirname(path)
    return path:match('^(.*)/[^/]+$') or ''
end

local function split(path)
    local parts = {}
    path:gsub('[^/]+', function(part) parts[#parts + 1] = part end)
    return parts
end

local function relative(base, path)
    local from, to = split(base), split(path)
    local index = 1
    while index <= #from and from[index] == to[index] do
        index = index + 1
    end
    local parts = {}
    local up = index
    while up <= #from do
        parts[#parts + 1] = '..'
        up = up + 1
    end
    while index <= #to do
        parts[#parts + 1] = to[index]
        index = index + 1
    end
    return table.concat(parts, '/')
end

local function read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return nil
    end
    local content = file:read('*a')
    file:close()
    return content
end

local function resolve_relative(from_path, spec)
    local base = normalize(dirname(from_path)..'/'..spec)
    local candidates = {base, base..'.js', base..'/index.js'}
    local index = 1
    while index <= #candidates do
        local file = candidates[index]
        if (file:match('%.js$') or file:match('%.json$')) and read_file(file) then
            return file
        end
        index = index + 1
    end
    return nil
end

local function resolve_package(from_path, spec)
    local dir = dirname(from_path)
    while true do
        local base = (#dir > 0 and dir..'/' or '')..'node_modules/'..spec
        local pkg = read_file(base..'/package.json')
        local main = pkg and pkg:match('"main"%s*:%s*"([^"]+)"')
        local candidates = {
            main and normalize(base..'/'..main) or base..'/index.js',
            base..'/index.js',
            base..'.js'
        }
        local index = 1
        while index <= #candidates do
            if read_file(candidates[index]) then
                return normalize(candidates[index])
            end
            index = index + 1
        end
        if #dir == 0 then
            return nil
        end
        dir = dirname(dir)
    end
end

--! @param src entry file (CommonJS)
--! @param dest output file
--! @param options @c format (cjs|esm|global) and @c global (window name, implies format global)
local function build(src, dest, options)
    options = options or {}
    local src_path = str_fs.file(src)
    local dest_path = str_fs.file(dest)
    local format = options.format or (options.global and 'global') or 'cjs'

    if not src_path then
        return false, 'src is required'
    end

    if not dest_path then
        return false, 'dest is required'
    end

    if not formats[format] then
        return false, 'unknown format: '..tostring(format)
    end

    if format == 'global' and not options.global then
        return false, 'global name is required'
    end

    local entry = normalize(src_path.get_unixfilepath())
    local root = dirname(entry)
    local modules = {}
    local order = {}
    local queue = {entry}
    local index = 1

    local function id_of(path)
        return relative(root, path)
    end

    while index <= #queue do
        local path = queue[index]
        index = index + 1
        if not modules[path] then
            local content = read_file(path)
            if not content then
                return false, 'cannot open '..path
            end
            if path:match('%.json$') then
                modules[path] = 'module.exports = '..content..';'
            else
                modules[path] = content:gsub(pattern_require, function(quote, spec)
                    local target
                    if spec:sub(1, 1) == '.' then
                        target = resolve_relative(path, spec)
                    else
                        target = resolve_package(path, spec)
                    end
                    if not target then
                        return nil
                    end
                    queue[#queue + 1] = target
                    return '__require(\''..id_of(target)..'\')'
                end)
            end
            order[#order + 1] = path
        end
    end

    local out = {
        formats[format][1]:format(options.global),
        'var __modules = {};',
        'var __cache = {};',
        'var __require = function(id) {',
        'if (!__cache[id]) {',
        'var module = {exports: {}};',
        '__cache[id] = module;',
        '__modules[id](module, module.exports);',
        '}',
        'return __cache[id].exports;',
        '};'
    }

    index = 1
    while index <= #order do
        local path = order[index]
        out[#out + 1] = '__modules[\''..id_of(path)..'\'] = function(module, exports) {'
        out[#out + 1] = modules[path]
        out[#out + 1] = '};'
        index = index + 1
    end

    out[#out + 1] = 'return __require(\''..id_of(entry)..'\');'
    out[#out + 1] = formats[format][2]

    local dest_file, dest_err = io.open(dest_path.get_fullfilepath(), 'w')

    if not dest_file then
        return false, dest_err or 'cannot write bundle file'
    end

    dest_file:write(table.concat(out, '\n'))
    dest_file:close()

    return true
end

local P = {
    build=build
}

return P
