local function load(self, std)
    self._menu = 1
    self._msg = 'loading...'
    std.http.get('http://games.gamely.com.br/games.json')
        :error(function()
            self._msg = std.http.error
        end)
        :failed(function()
            self._msg = tostring(std.http.status)
        end)
        :success(function()
            self._list = std.json.decode(std.http.body)
            self._msg = nil
        end)
        :run()
end

local function keys(self, std)
    if self._game then return end
    if not self._list then return end

    self._menu = std.math.clamp2(self._menu + std.key.axis.y, 1, #self._list)

    if std.key.press.a then
        self._game = {}
        std.http.get(self._list[self._menu].raw_url)
            :success(function()
                std.app.title(self._list[self._menu].title)
                self._game = std.node.load(std.http.body)
                std.node.spawn(self._game)
                std.bus.emit('init')
                std.bus.emit('i18n')
            end)
            :run()
    end
end

local function draw(self, std)
    if self._game then return end
    std.draw.clear(0x333333FF)
    std.draw.color(std.color.white)
    if self._msg then 
        std.text.put(1, 1, self._msg)
        return
    end
    local index = 1
    while index <= #self._list do
        std.text.put(3, index, self._list[index].title)
        std.text.put(32, index, self._list[index].version)
        std.text.put(40, index, self._list[index].author)
        index = index + 1
    end
    std.draw.color(std.color.red)
    std.text.put(1, self._menu, '>')
end

local function quit(self, std)
    std.bus.abort()
    std.node.kill(self._game)
    self._game = nil
end

local P = {
    meta={
        title='Launcher Games',
        description='online multi game list',
        author='Rodrigo Dornelles',
        version='1.0.0'
    },
    config={
        require='http json *'
    },
    callbacks={
        load=load,
        key=keys,
        draw=draw,
        quit=quit
    }
}

return P
