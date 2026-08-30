local str_fs = require('source/shared/string/schema/fs')

local pattern_require = 'require%s*%(%s*([\'"])([^\'"]+)%1%s*%)'

local function normalize(path)
    local prefix = path:sub(1, 1) == '/' and '/' or ''
    local parts = {}
    path:gsub('[^/]+', function(part)
        if part == '..' then
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

local function exists(path)
    local file = io.open(path, 'r')
    if file then
        file:close()
        return true
    end
    return false
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
    if not spec:match('%.js$') and not spec:match('%.json$') then
        spec = spec..'.js'
    end
    local target = normalize(dirname(from_path)..'/'..spec)
    if exists(target) then
        return target
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
            if exists(candidates[index]) then
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

local function rewrite(path, content, enqueue)
    local rewritten = content:gsub(pattern_require, function(quote, spec)
        local target
        if spec:sub(1, 1) == '.' then
            target = resolve_relative(path, spec)
        else
            target = resolve_package(path, spec)
        end
        if not target then
            return nil
        end
        enqueue(target)
        return '__require(\''..target..'\')'
    end)
    return rewritten
end

local function build(src, dest, global_name)
    local src_path = str_fs.file(src)
    local dest_path = str_fs.file(dest)

    if not src_path then
        return false, 'src is required'
    end

    if not dest_path then
        return false, 'dest is required'
    end

    local entry = normalize(src_path.get_unixfilepath())
    local modules = {}
    local order = {}
    local queue = {entry}
    local index = 1

    while index <= #queue do
        local id = queue[index]
        index = index + 1
        if not modules[id] then
            local content = read_file(id)
            if not content then
                return false, 'cannot open '..id
            end
            if id:match('%.json$') then
                modules[id] = 'module.exports = '..content..';'
            else
                modules[id] = rewrite(id, content, function(target)
                    queue[#queue + 1] = target
                end)
            end
            order[#order + 1] = id
        end
    end

    local header = 'module.exports = (function() {'

    if global_name then
        header = 'window.'..global_name..' = (function() {'
    end

    local out = {
        header,
        'const __modules = {};',
        'const __cache = {};',
        'const __require = function(id) {',
        'if (!__modules[id]) {',
        'return require(id);',
        '}',
        'if (!__cache[id]) {',
        'const module = {exports: {}};',
        '__cache[id] = module;',
        '__modules[id](module, module.exports);',
        '}',
        'return __cache[id].exports;',
        '};'
    }

    do
        local order_index = 1
        while order_index <= #order do
            local id = order[order_index]
            out[#out + 1] = '__modules[\''..id..'\'] = function(module, exports) {'
            out[#out + 1] = modules[id]
            out[#out + 1] = '};'
            order_index = order_index + 1
        end
    end

    out[#out + 1] = 'return __require(\''..entry..'\');'
    out[#out + 1] = '})();'

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
