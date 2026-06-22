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
local overlay_rows = 8
local sample_ms = 1000
local reset_ms = 300000

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

    local line = ' +_____+_______________________________+_____________+__________________________+__________________________________+ \n'
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

local function short_src(src)
    src = clean_src(src)
    return src:match('([^/]+%.lua:%d+)$') or src
end

local function trim(value, size)
    value = tostring(value)
    if value:len() <= size then
        return value
    end
    return value:sub(1, size - 1)..'…'
end

local function memory_kb()
    return collectgarbage('count')
end

local function row_key(row)
    return tostring(row[2])..'|'..tostring(row[5])
end

local function rows_by_key(rows)
    local dict = {}

    for _, row in ipairs(rows) do
        if should_capture_src(row[5]) then
            dict[row_key(row)] = {
                label = row[2],
                calls = row[3],
                time = row[4],
                src = row[5],
            }
        end
    end

    return dict
end

local function sort_rows(rows)
    table.sort(rows, function(a, b)
        if a.time == b.time then
            return a.calls > b.calls
        end
        return a.time > b.time
    end)
    return rows
end

local function diff_rows(previous, current)
    local rows = {}

    for key, row in pairs(current) do
        local prev = previous[key]
        local calls = row.calls - (prev and prev.calls or 0)
        local time = row.time - (prev and prev.time or 0)

        if calls > 0 or time > 0 then
            rows[#rows + 1] = {
                label = row.label,
                calls = calls,
                time = time,
                src = row.src,
            }
        end
    end

    return sort_rows(rows)
end

local function snapshot(self, now)
    local current = rows_by_key(self.backend.query(self.sample_limit))
    local rows = diff_rows(self.previous, current)
    local calls = self.calls - self.previous_calls

    self.previous = current
    self.previous_calls = self.calls
    self.sample = {
        at = now,
        calls = calls,
        mem_kb = memory_kb(),
        rows = rows,
    }
end

local function tick(self, now)
    if self.reported then
        return
    end

    if not self.last_sample then
        self.last_sample = now
        self.reset_at = now
        snapshot(self, now)
        return
    end

    if now - self.last_sample >= self.sample_ms then
        self.last_sample = now
        snapshot(self, now)
    end

    if now - self.reset_at >= self.reset_ms then
        write(('[profile] reset window lua_gc_kb=%.3f'):format(memory_kb()))
        self.backend.reset()
        self.previous = {}
        self.previous_calls = self.calls
        self.reset_at = now
    end
end

local function draw_overlay(self, engine, std)
    local sample = self.sample
    local rows = sample.rows
    local x = 40
    local y = 32
    local w = 700
    local line_h = 18
    local padding = 8
    local count = math.min(#rows, self.overlay_rows)
    local h = ((count + 3) * line_h) + padding
    local old_current = engine.current
    local old_x = engine.offset_x
    local old_y = engine.offset_y

    engine.current = engine.root
    engine.offset_x = 0
    engine.offset_y = 0

    std.draw.color(0x101010D0)
    std.draw.rect(0, x, y, w, h)
    std.draw.color(0x66FF66FF)
    std.text.font_default(1)
    std.text.font_size(14)
    std.text.print(x + 6, y + 4, ('profile 1s | lua gc %.1f kb | scopes/s %d'):format(sample.mem_kb, sample.calls))
    std.text.print(x + 6, y + 4 + line_h, 'rank | ms | calls | function')
    std.draw.color(0xFFFFFFFF)

    for i = 1, count do
        local row = rows[i]
        local label = row.label ~= '?' and row.label or short_src(row.src)
        local line = ('%02d | %7.3f | %5d | %s'):format(i, row.time * 1000, row.calls, trim(label..' @ '..short_src(row.src), 76))
        std.text.print(x + 6, y + 4 + ((i + 1) * line_h), line)
    end

    if count == 0 then
        std.text.print(x + 6, y + 4 + (2 * line_h), 'waiting for application samples')
    end

    engine.current = old_current
    engine.offset_x = old_x
    engine.offset_y = old_y
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
    stub.frame = noop
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
        backend = backend,
        previous = {},
        previous_calls = 0,
        sample = {at = 0, calls = 0, mem_kb = memory_kb(), rows = {}},
        sample_limit = options.sample_limit or 200,
        sample_ms = options.sample_ms or sample_ms,
        reset_ms = options.reset_ms or reset_ms,
        overlay_rows = options.overlay_rows or overlay_rows,
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

    self.frame = function(engine, std, now)
        tick(self, now or std.milis)
        draw_overlay(self, engine, std)
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
            if value == '1' or value == 'true' or value == 'yes' or value == ('-' .. '-profile') or value == 'profile' then
                return true
            end
        elseif type(value) == 'table' then
            if value.profile or value[('-' .. '-profile')] then
                return true
            end
            for _, item in ipairs(value) do
                if item == ('-' .. '-profile') or item == 'profile' then
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

local function frame(engine, std, now)
    engine.profile.frame(engine, std, now)
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
    frame = frame,
    report = report,
    scoped = scoped,
    start = start,
    stub = make_stub,
    should_capture_src = should_capture_src,
}

return P
