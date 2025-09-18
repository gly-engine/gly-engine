local function init(std, self)
    self.p = 0
    self.px = 2
    self.py = 0
    self.s = 0
    self.f = 0
end

local function loop(std, self)
    if std.key.left then self.px = self.px - 0.03 end
    if std.key.right then self.px = self.px + 0.03 end
    if std.key.up then self.s = self.s - self.f - 0.03 end

    self.s = self.s + 0.1
    self.py = self.py + self.s
    self.f = self.f * 0.7
    self.p = self.p + 1
end

local function draw(std, self)
    std.draw.clear(std.color.black)
    std.draw.color(std.color.white)
    std.text.put(3, 3, self.p)

    local max_y = self.height - 2
    local base_y = std.math.floor(self.height * 0.88)

    for y = 1, max_y do
        local z = std.math.floor((200 / y + self.p / 20))
        local x = z * 200

        x = std.math.bxor(x, std.math.lshift(x,13))
        x = std.math.bxor(x, std.math.rshift(x,17))
        x = std.math.bxor(x, std.math.lshift(x,1))
        x = std.math.bxor(x, std.math.lshift(x,13))
        x = std.math.bxor(x, std.math.rshift(x,17))
        x = std.math.bxor(x, std.math.lshift(x,1))
        x = std.math.bxor(x, std.math.lshift(x,13))
        x = std.math.bxor(x, std.math.rshift(x,17))
        x = std.math.bxor(x, std.math.lshift(x,1))
        x = std.math.bxor(x, std.math.lshift(x,13))
        x = std.math.bxor(x, std.math.rshift(x,17))
        x = std.math.band(x,3) / 2 - self.px

        local w = 6 / z^0.5
        std.draw.color(std.color.green)
        std.draw.rect(0, base_y + y * x, y, y * w, y / 9, 1)
        std.draw.color(std.color.blue)
        std.draw.rect(0, base_y + y * x, y, y * w, 1, 1)

        if y == base_y and self.py > 0 then
            if x + w < 0 or x > 0 then
                return
            end
            self.py = 0
            self.s = 0
            self.f = 0.8
        end
    end
end

local function exit(std, self)
end

local P = {
    meta = {
        title = 'Skip Ahead 3D',
        author = 'exoticorn',
        description = 'unnoficial port of exoticorn game made in 256 bytes for lovebyte 2021',
        version = '1.0.0'
    },
    config = {
        require='math math.bit'
    },
    callbacks = {
        init = init,
        loop = loop,
        draw = draw,
        exit = exit
    }
}

return P
