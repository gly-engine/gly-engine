local math = require('math')
local convert = require('source/shared/image/convert_color')

local yuv2rgb = convert.yuv2rgb
local floor = math.floor

local CHROMA = {
    ['420']      = { x = 2, y = 2 },
    ['420jpeg']  = { x = 2, y = 2 },
    ['420mpeg2'] = { x = 2, y = 2 },
    ['420paldv'] = { x = 2, y = 2 },
--  ['422']      = { x = 2, y = 1 },
--  ['444']      = { x = 1, y = 1 },
--  ['mono']     = { x = 0, y = 0 },
}

local function push(self, data)
    if self.done then return end
    self.buffer = self.buffer .. data
end

local function is_done(self)
    return self.done
end

local function decode_line(self, y)
    local w = self.w
    local UV_w = self.uv_w
    local Y_size = self.y_size
    local U_size = self.u_size
    local cx = self.chroma_x
    local cy = self.chroma_y
    local has_chroma = self.has_chroma
    local data = self.frame_data
    local y_row = y * w
    local uv_row = has_chroma and (floor(y / cy) * UV_w) or 0
    local p = y * w * self.stride + 1

    for x = 0, w - 1 do
        local Yv = data:byte(y_row + x + 1)
        local Uv, Vv = 0, 0

        if has_chroma then
            local cxi = floor(x / cx)
            Uv = data:byte(Y_size + uv_row + cxi + 1) - 128
            Vv = data:byte(Y_size + U_size + uv_row + cxi + 1) - 128
        end

        local r, g, b = yuv2rgb(Yv, Uv, Vv)

        if r < 0 then r = 0 elseif r > 255 then r = 255 end
        if g < 0 then g = 0 elseif g > 255 then g = 255 end
        if b < 0 then b = 0 elseif b > 255 then b = 255 end

        self.rgba[p]   = r
        self.rgba[p+1] = g
        self.rgba[p+2] = b

        if self.stride == 4 then
            self.rgba[p+3] = 255
        end

        p = p + self.stride
    end
end

local function parse_header(self, header)
    if header:sub(1, 9) ~= 'YUV4MPEG2' then
        error('invalid y4m header: missing YUV4MPEG2 magic')
    end

    self.w = tonumber(header:match(' W(%d+)'))
    self.h = tonumber(header:match(' H(%d+)'))

    if not self.w or not self.h then
        error('invalid y4m header: missing W or H')
    end

    local cs = header:match(' C(%w+)') or '420'
    local chroma = CHROMA[cs]

    if not chroma then
        error('unsupported y4m colorspace: '..cs)
    end

    self.colorspace = cs
    self.framerate = header:match(' F([%d:]+)')
    self.interlace = header:match(' I(%a)')
    self.aspect = header:match(' A([%d:]+)')

    self.y_size = self.w * self.h

    if chroma.x == 0 then
        self.has_chroma = false
        self.chroma_x = 1
        self.chroma_y = 1
        self.uv_w = 0
        self.u_size = 0
        self.frame_size = self.y_size
    else
        self.has_chroma = true
        self.chroma_x = chroma.x
        self.chroma_y = chroma.y
        self.uv_w = floor(self.w / chroma.x)
        self.u_size = self.uv_w * floor(self.h / chroma.y)
        self.frame_size = self.y_size + 2 * self.u_size
    end
end

local function step(self, lines_per_tick)
    if self.done then return end

    lines_per_tick = lines_per_tick or 1

    while true do
        if self.state == "header" then
            local i = self.buffer:find("\n")
            if not i then return end

            local header = self.buffer:sub(1, i - 1)
            self.buffer = self.buffer:sub(i + 1)

            parse_header(self, header)
            self.state = "frame_header"
        end

        if self.state == "frame_header" then
            local i = self.buffer:find("\n")
            if not i then return end

            local line = self.buffer:sub(1, i - 1)
            self.buffer = self.buffer:sub(i + 1)

            if line:sub(1, 5) == "FRAME" then
                self.state = "frame_data"
            end
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

            return is_done(self)
        end
    end

    return is_done(self)
end

local function close(self)
    local out = self.rgba

    self.buffer = ""
    self.state = "header"
    self.w = 0
    self.h = 0
    self.frame_size = 0
    self.frame_data = nil
    self.decode_y = 0
    self.rgba = nil
    self.done = false

    self.y_size = 0
    self.u_size = 0
    self.uv_w = 0
    self.chroma_x = 0
    self.chroma_y = 0
    self.has_chroma = false

    self.colorspace = nil
    self.framerate = nil
    self.interlace = nil
    self.aspect = nil

    return out
end

local function new(mode)
    local stride = 4
    if mode == "rgb" then stride = 3 end

    local self = {
        stride = stride,
        push = push,
        step = step,
        is_done = is_done,
        close = close,
    }

    self:close()

    return self
end

return {
    new = new
}
