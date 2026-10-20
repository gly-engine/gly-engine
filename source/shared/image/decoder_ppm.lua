local function push(self, data)
    self.buffer = self.buffer .. data
end

local function is_done(self)
    return self.done
end

local function parse_header(self, header)
    if header:sub(1,2) ~= "P6" then
        error("invalid ppm header: missing P6 magic")
    end

    local w, h, maxval = header:match("P6%s+(%d+)%s+(%d+)%s+(%d+)")
    self.w = tonumber(w)
    self.h = tonumber(h)
    self.maxval = tonumber(maxval)

    if not self.w or not self.h or not self.maxval then
        error("invalid ppm header: missing width/height/maxval")
    end

    self.frame_size = self.w * self.h * 3
end

local function decode_line(self, y)
    local w = self.w
    local stride = self.stride
    local maxval = self.maxval
    local data = self.frame_data
    local src = y * w * 3 + 1
    local p = y * w * stride + 1

    for x = 0, w - 1 do
        local r = data:byte(src)
        local g = data:byte(src + 1)
        local b = data:byte(src + 2)

        self.rgba[p]   = (r * 255) / maxval
        self.rgba[p+1] = (g * 255) / maxval
        self.rgba[p+2] = (b * 255) / maxval

        if stride == 4 then
            self.rgba[p+3] = 255
        end

        p = p + stride
        src = src + 3
    end
end

local function step(self, lines_per_tick)
    if self.done then return end

    lines_per_tick = lines_per_tick or 1

    if self.state == "header" then
        local s, e = self.buffer:find("^P6%s+%d+%s+%d+%s+%d+%s")
        if not e then return end

        local header = self.buffer:sub(s, e)
        self.buffer = self.buffer:sub(e + 1)

        parse_header(self, header)
        self.state = "frame_data"
    end

    if self.state == "frame_data" then
        if #self.buffer < self.frame_size then return end

        self.frame_data = self.buffer:sub(1, self.frame_size)
        self.buffer = self.buffer:sub(self.frame_size + 1)

        local size = self.w * self.h * self.stride
        self.rgba = {}
        for i = 1, size do
            self.rgba[i] = 0
        end

        self.decode_y = 0
        self.state = "decoding"
    end

    if self.state == "decoding" then
        local processed = 0

        while self.decode_y < self.h and processed < lines_per_tick do
            decode_line(self, self.decode_y)
            self.decode_y = self.decode_y + 1
            processed = processed + 1
        end

        if self.decode_y >= self.h then
            self.done = true
        end

        return self:is_done()
    end

    return self:is_done()
end

local function close(self)
    local out = self.rgba
    self.buffer = ""
    self.state = "header"
    self.done = false
    self.rgba = nil
    self.frame_data = nil
    self.decode_y = 0
    self.w = 0
    self.h = 0
    self.maxval = 0
    self.frame_size = 0
    return out
end

local function mensure(self)
    return self.w, self.h
end

local function new(mode)
    local stride = 4
    if mode == "rgb" then stride = 3 end

    local self = {
        stride = stride,
        push = push,
        step = step,
        close = close,
        is_done = is_done,
        mensure = mensure,
        buffer = "",
        state = "header",
        done = false
    }

    self:close()

    return self
end

return {
    new = new
}
