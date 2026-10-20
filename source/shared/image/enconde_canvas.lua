local convert = require('source/shared/image/convert_color')

local function make_reader(read, stride, convert)
    if stride == 1 then
        return function(buf, i)
            return convert(read(buf, i))
        end
    elseif stride == 2 then
        return function(buf, i)
            return convert(read(buf, i), read(buf, i+1))
        end
    elseif stride == 3 then
        return function(buf, i)
            return convert(read(buf, i), read(buf, i+1), read(buf, i+2))
        end
    elseif stride == 4 then
        return function(buf, i)
            return convert(read(buf, i), read(buf, i+1), read(buf, i+2), read(buf, i+3))
        end
    end
end

local function push(self, data)
    if self.done then return end

    if not self.read then
        if type(data) == "string" then
            self.read = function(buf, i) return buf:byte(i) end
            self.buffer = ""
        elseif type(data) == "table" then
            self.read = function(buf, i) return buf[i] end
            self.buffer = {}
        else
            error("buffer must be string or table")
        end

        self.reader = make_reader(self.read, self.in_stride, self.convert)
    end

    if self.read == nil then return end

    if self.read_string then
        self.buffer = self.buffer .. data
    else
        local buf = self.buffer
        local n = #buf
        for i = 1, #data do
            n = n + 1
            buf[n] = data[i]
        end
    end
end

local function is_done(self)
    return self.done
end

local function step(self, lines_per_tick)
    if self:is_done() then return true end

    lines_per_tick = lines_per_tick or 1

    if not self.canvas then
        self.canvas = self.ops.start(self.w, self.h)
    end

    local w, h = self.w, self.h
    local stride = self.in_stride
    local reader = self.reader
    local pixel = self.ops.pixel
    local colorf = self.ops.color
    local canvas = self.canvas
    local buf = self.buffer

    local y = self.y
    local buf_i = self.buf_i
    local processed = 0

    local run = self.run
    local run_x = self.run_x
    local lc1, lc2, lc3, lc4 = self.last_c1, self.last_c2, self.last_c3, self.last_c4

    while y < h and processed < lines_per_tick do
        if (#buf - buf_i + 1) < (w * stride) then
            break
        end

        for x = 0, w - 1 do
            local c1, c2, c3, c4 = reader(buf, buf_i)
            buf_i = buf_i + stride

            if lc1 == c1 and lc2 == c2 and lc3 == c3 and lc4 == c4 then
                if run == 0 then run_x = x end
                run = run + 1
            else
                if run > 0 then
                    pixel(canvas, run_x, y, run, 1, lc1, lc2, lc3, lc4)
                end
                colorf(canvas, c1, c2, c3, c4)
                lc1, lc2, lc3, lc4 = c1, c2, c3, c4
                run_x = x
                run = 1
            end
        end

        if run > 0 then
            pixel(canvas, run_x, y, run, 1, lc1, lc2, lc3, lc4)
            run = 0
        end

        y = y + 1
        processed = processed + 1
    end

    self.buf_i = buf_i
    self.y = y
    self.run = run
    self.run_x = run_x
    self.last_c1, self.last_c2, self.last_c3, self.last_c4 = lc1, lc2, lc3, lc4

    if y >= h then
        self.done = true
    end

    return self:is_done()
end

local function close(self)
    local out = nil

    if self.canvas then
        out = self.ops.finish(self.canvas)
    end

    self.buffer = nil
    self.buf_i = 1
    self.y = 0
    self.canvas = nil
    self.done = false
    self.run = 0
    self.run_x = 0

    self.read = nil
    self.reader = nil

    self.last_c1 = nil
    self.last_c2 = nil
    self.last_c3 = nil
    self.last_c4 = nil

    return out
end

local function mensure(self)
    return self.w, self.h
end

--! @param[in] w width
--! @param[in] h height
--! @param[in] mode must be integer (stride) or string (format)
--! @param[in, out] operators
--! @li .new = function(w, h) return canvas end
--! @li .color = function(canvas, c1, ...) end
--! @li .pixel = function(canvas, x, y, w, h, c1, ...) end
--! @li .finish = function(canvas) return canvas end
local function new(w, h, mode, ops)
    local convert_fn
    local in_stride = 1

    if type(mode) == "string" then
        convert_fn = convert[mode]
        if not convert_fn then
            error("color converter not found")
        end
        in_stride = #({convert_fn(255, 255, 255, 255)})
    elseif type(mode) == "number" then
        in_stride = mode
        convert_fn = function(...) return ... end
    end

    ops = ops or {}

    if not ops.color then ops.color = function() end end
    if not ops.start then ops.start = function() return {} end end
    if not ops.finish then ops.finish = function(c) return c end end

    local self = {
        w = w,
        h = h,
        ops = ops,

        convert = convert_fn,
        in_stride = in_stride,

        push = push,
        step = step,
        close = close,
        mensure = mensure,
        is_done = is_done,
    }

    self:close()

    return self
end

return {
    new = new
}
