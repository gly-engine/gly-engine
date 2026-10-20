local json = require('source/third_party/rxi_json')
local cli2 = require('source/shared/string/dsl/cli2')

local function normalize(path)
    local prefix = path:sub(1, 1) == '/' and '/' or ''
    local parts = {}
    path:gsub('\\', '/'):gsub('[^/]+', function(part)
        if part == '..' and #parts > 0 and parts[#parts] ~= '..' then
            parts[#parts] = nil
        elseif part ~= '.' then
            parts[#parts + 1] = part
        end
    end)
    return prefix..table.concat(parts, '/')
end

local function dirname(path)
    return path:match('^(.*)/[^/]+$') or '.'
end

--! @c when sees the cli state, environment variables as @c env.NAME
local function context(state)
    return setmetatable({}, {__index = function(_, key)
        local env = type(key) == 'string' and key:match('^env%.(.+)$')
        if env then return os.getenv(env) end
        return state[key]
    end})
end

--! @short files from @c replace and @c delete lists that pass their @c when
--! @return dict of normalized path to replacement path, or false when deleted
local function load(overlay_file, state)
    local file = io.open(overlay_file, 'r')
    if not file then
        return nil, 'overlay not found: '..overlay_file
    end
    local ok, data = pcall(json.decode, file:read('*a'))
    file:close()
    if not ok or type(data) ~= 'table' then
        return nil, 'overlay is not a valid json: '..overlay_file
    end
    if type(data.replace) ~= 'table' and type(data.delete) ~= 'table' then
        return nil, 'overlay must have a "replace" or "delete" list: '..overlay_file
    end

    local base = dirname(normalize(overlay_file))
    local ctx = context(state)
    local files = {}

    local function add(path, with)
        files[normalize(path)] = with
        if type(state.cwd) == 'string' and #state.cwd > 0 then
            files[normalize(state.cwd..'/'..path)] = with
        end
    end

    for index, item in ipairs(data.replace or {}) do
        if type(item) ~= 'table' or type(item.file) ~= 'string' or type(item.with) ~= 'string' then
            return nil, 'overlay replace['..index..'] needs "file" and "with"'
        end
        if item.when == nil or cli2.evaluate_rules(ctx, item.when) then
            add(item.file, normalize(base..'/'..item.with))
        end
    end

    for index, item in ipairs(data.delete or {}) do
        if type(item) == 'string' then
            item = {file = item}
        end
        if type(item) ~= 'table' or type(item.file) ~= 'string' then
            return nil, 'overlay delete['..index..'] needs "file"'
        end
        if item.when == nil or cli2.evaluate_rules(ctx, item.when) then
            add(item.file, false)
        end
    end

    return files
end

--! @short every file read by the cli follows the overlay
local function install(overlay_file, state)
    local files, err = load(overlay_file, state)
    if not files then
        return false, err
    end
    local real_open = io.open
    io.open = function(filename, mode)
        local with = filename and (mode or 'r'):find('r') and files[normalize(filename)]
        if with == false then
            return nil, filename..': removed by overlay'
        end
        return real_open(with or filename, mode)
    end
    return true
end

local P = {
    load = load,
    install = install
}

return P
