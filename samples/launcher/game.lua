local function load(std, data)
    data._menu = 1
    data._msg = 'loading...'
    std.http.get('http://games.gamely.com.br/games.json')
        :error(function()
            data._msg = std.http.error
        end)
        :failed(function()
            data._msg = tostring(std.http.status)
        end)
        :success(function()
            data._list = std.json.decode(std.http.body)
            data._msg = nil
        end)
        :run()
end

local function keys(std, data)
    if data._game then return end
    if not data._list then return end

    data._menu = std.math.clamp2(data._menu + std.key.axis.y, 1, #data._list)

    if std.key.press.a then
        data._game = {}
        std.http.get(data._list[data._menu].raw_url)
            :success(function()
                std.app.title(data._list[data._menu].title)
                data._game = std.node.load(std.http.body)
                std.node.spawn(data._game)
                std.bus.emit('init')
                std.bus.emit('i18n')
            end)
            :run()
    end
end

local function draw(std, data)
    if data._game then return end
    std.draw.clear(0x333333FF)
    std.draw.color(std.color.white)
    if data._msg then 
        std.text.put(1, 1, data._msg)
        return
    end
    local index = 1
    while index <= #data._list do
        std.text.put(3, index, data._list[index].title)
        std.text.put(32, index, data._list[index].version)
        std.text.put(40, index, data._list[index].author)
        index = index + 1
    end
    std.draw.color(std.color.red)
    std.text.put(1, data._menu, '>')
end

local function quit(std, data)
    std.bus.abort()
    std.node.kill(data._game)
    data._game = nil
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
