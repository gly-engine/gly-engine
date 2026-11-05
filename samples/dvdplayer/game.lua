local function init(self, std)
    self.x = self.width/2
    self.y = self.height/2
    self.size = 80
    self.hspeed = self.width/5000
    self.vspeed = self.height/4000
    self.image = 'icon80x80.png'
    self.delta = 16
end

local function loop(self, std)
    self.x = self.x + (self.hspeed * self.delta)
    self.y = self.y + (self.vspeed * self.delta)
    if self.x <= 1 or self.x >= self.width - self.size then
        self.hspeed = -1 * self.hspeed
    end
    if self.y <= 1 or self.y >= self.height - self.size then
        self.vspeed = -1 * self.vspeed
    end
end

local function draw(self, std)
    std.draw.clear(std.color.black)
    std.image.draw(self.image, self.x, self.y)
end

local function exit(self, std)
end

local P = {
    meta={
        title='DVD Player',
        author='RodrigoDornelles',
        description='a logo bouncing between the corners',
        version='1.0.0'
    },
    assets={
      'assets/icon80x80.png:icon80x80.png'
    },
    callbacks={
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P;
