local function load_backend()
    local profile = require('source/third_party/2dengine_profile')
    return profile
end

local excludes = {
    'source/engine/',
    'source/shared/',
    'source/cli/',
    'source/third_party/',
    'ee/engine/',
}

local cols = { 3, 29, 11, 24, 32 }

local function clean_src(src)
    return tostring(src or '')
        :gsub('\\', '/')
        :gsub('^@', '')
        :gsub('^%./', '')
end

local function has_path(src, path)
    return src:sub(1, #path) == path or src:find('/'..path, 1, true) ~= nil
end

local function should_capture_src(src)
    src = clean_src(src)

    if src == '' or src == '[C]' then
        return false
    end

    for _, path in ipairs(excludes) do
        if has_path(src, path) then
            return false
        end
    end

    return true
end

local function should_capture_info(info)
    return info and info.what == 'Lua' and should_capture_src(info.source or info.short_src)
end

local function pad(value, size)
    local str = tostring(value)
    local len = str:len()

    if len < size then
        return str..(' '):rep(size - len)
    end

    if len > size then
        return str:sub(len - size + 1, len)
    end

    return str
end

local function format_rows(rows, limit)
    local out = {}
    local count = 0

    for _, row in ipairs(rows) do
        if should_capture_src(row[5]) then
            count = count + 1
            if not limit or count <= limit then
                out[#out + 1] = table.concat({
                    pad(count, cols[1]),
                    pad(row[2], cols[2]),
                    pad(row[3], cols[3]),
                    pad(row[4], cols[4]),
                    pad(row[5], cols[5]),
                }, ' | ')
            end
        end
    end

    local line = ' +-----+-------------------------------+-------------+--------------------------+----------------------------------+ \n'
    local head = ' | #   | Function                      | Calls       | Time                     | Code                             | \n'
    local report = '\n'..line..head..line

    if #out > 0 then
        report = report..' | '..table.concat(out, ' | \n | ')..' | \n'
    end

    return report..line
end

local function write(value)
    if print then
        print(value)
    end
end

local function noop()
end

local function make_stub(reason)
    local stub = {
        enabled = false,
        calls = 0,
        depth = 0,
        reason = reason or 'disabled',
    }

    stub.start = noop
    stub.stop = noop
    stub.report = noop
    stub.call = function(label, func)
        return func()
    end
    stub.status = function()
        return 'profile disabled: '..stub.reason
    end

    return stub
end

local function make_real(backend, options)
    options = options or {}

    local self = {
        enabled = true,
        calls = 0,
        depth = 0,
        last = nil,
        reported = false,
        original_hooker = backend.hooker,
    }

    backend.hooker = function(event, line, info)
        info = info or debug.getinfo(2, 'fnS')
        if should_capture_info(info) then
            self.original_hooker(event, line, info)
        end
    end

    backend.reset()

    self.start = function(label)
        if self.reported then
            return
        end

        self.calls = self.calls + 1
        self.depth = self.depth + 1
        self.last = label

        if self.depth == 1 then
            backend.start()
        end
    end

    self.stop = function(label)
        if self.depth <= 0 then
            return
        end

        self.depth = self.depth - 1

        if self.depth == 0 then
            backend.stop()
        end
    end

    self.call = function(label, func)
        self.start(label)
        local ok, a, b, c, d = pcall(func)
        self.stop(label)

        if not ok then
            error(a, 0)
        end

        return a, b, c, d
    end

    self.status = function()
        return 'profile enabled: '..tostring(self.calls)..' scoped calls'
    end

    self.report = function(limit)
        if self.reported then
            return
        end

        self.reported = true

        while self.depth > 0 do
            self.stop('report')
        end

        backend.hooker = self.original_hooker
        write('[profile] '..self.status())
        write(format_rows(backend.query(limit or options.limit or 100)))
    end

    return self
end

local function is_enabled(...)
    local values = {...}

    for _, value in ipairs(values) do
        if value == true or value == 1 then
            return true
        end

        if type(value) == 'string' then
            value = value:lower()
            if value == '1' or value == 'true' or value == 'yes' or value == '--profile' or value == 'profile' then
                return true
            end
        elseif type(value) == 'table' then
            if value.profile or value['--profile'] then
                return true
            end
            for _, item in ipairs(value) do
                if item == '--profile' or item == 'profile' then
                    return true
                end
            end
        end
    end

    return false
end

local function start(options)
    options = options or {}

    if not debug or not debug.sethook or not debug.getinfo or not os or not os.clock then
        return make_stub('debug hooks unavailable')
    end

    local ok, backend = pcall(load_backend)
    if not ok or not backend then
        return make_stub('backend unavailable')
    end

    return make_real(backend, options)
end

local function install(engine, enabled, options)
    engine = engine or {}

    if engine.profile then
        engine.profile.report()
    end

    engine.profile = enabled and start(options) or make_stub()
    return engine.profile
end

local function report(engine)
    if engine and engine.profile then
        engine.profile.report()
    end
end

local function scoped(engine, label, func)
    local profile = engine and engine.profile
    if profile then
        return profile.call(label, func)
    end
    return func()
end

local P = {
    install = install,
    is_enabled = is_enabled,
    report = report,
    scoped = scoped,
    start = start,
    stub = make_stub,
    should_capture_src = should_capture_src,
}

return P
