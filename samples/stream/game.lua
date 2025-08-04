local function init(self, std)
    self.menu = 1
    self.msg = 'loading...'
    self.time = std.milis
    self.wmax = 1
    std.http.get('http://t.gamely.com.br/medias.json'):json()
        :error(function()
            self.msg = std.http.error
        end)
        :failed(function()
            self.msg = tostring(std.http.status)
        end)
        :success(function()
            self.list = std.http.body
            self.msg = nil
        end)
        :run()
end

local function loop(self, std)
    if not self.list or #self.list == 0 then return end
    if self.time + 300 < std.milis and std.key.press.any then
        self.menu = std.math.clamp2(self.menu + std.key.axis.y, 1, #self.list)
        self.time = std.milis
        if std.key.press.a then
            std.media.video():src(self.list[self.menu]):play()
        end
        if std.key.press.b then
            std.media.video():resume()
        end
        if std.key.press.c then
            std.media.video():pause()
        end
        if std.key.press.d then
            std.media.video():stop()
        end
        if std.key.press.left then
            std.media.video():resize(640, 320)
        end
        if std.key.press.right then
            std.media.video():resize(self.width, self.height)
        end
    end
end

local function draw(self, std)
    if self.msg then
        std.text.put(1, 1, self.msg)
    end
    if self.list and #self.list > 0 then
        local font_size = 12
        local w, h = self.width/6, self.height/4
        local w2, h2, index = self.width - self.wmax, h*2, 1
        local h3 = (#self.list + 1) * font_size
        local color = std.media.video():get_error() and std.color.red or std.color.blue
        std.draw.color(std.media.video():in_mutex() and std.color.green or color)
        std.draw.rect(0, w2 - 16, h, self.wmax + 32, h3 + font_size)
        std.draw.color(std.color.skyblue)
        std.text.font_size(font_size)
        std.draw.rect(0, w2 - 16, (self.menu * font_size) + h, self.wmax + 16, font_size)
        std.draw.color(std.color.white)
        std.draw.rect(1, w2 - 16, h, self.wmax + 32, h3 + font_size)
        while index <= #self.list do
            self.wmax = std.math.max(self.wmax, std.text.print_ex(self.width - 8, (index * font_size) + h, self.list[index], -1))
            index = index + 1
        end
    end
end

local function exit(self, std)
end

local P = {
    meta={
        title='Streamming',
        description='play videos online!',
        author='Rodrigo Dornelles',
        version='1.0.0'
    },
    config={
        require='http json media.video'
    },
    callbacks={
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P
