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

local function step(self)
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

        self.rgba = {}
        local maxval, stride = self.maxval, self.stride
        local p = 1
    
        for i = 1, self.frame_size, 3 do
            local r = self.frame_data:byte(i)
            local g = self.frame_data:byte(i+1)
            local b = self.frame_data:byte(i+2)

            self.rgba[p]   = (r * 255) / maxval
            self.rgba[p+1] = (g * 255) / maxval
            self.rgba[p+2] = (b * 255) / maxval
            p = p + 3
            if stride >= 4 then
                self.rgba[p+3] = 255
                p = p + 1
            end
        end

        self.done = true
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
    return out
end

local function mensure(self)
    return self.width, self.height
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
