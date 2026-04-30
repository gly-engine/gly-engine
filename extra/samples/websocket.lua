local function event(name)
    return name, function(data) print(name, data) end
end

local function init(self, std)
    std.http.connect('ws://localhost:8080', 'ws')
        :on('open', function(sock)
            print('open!')
            self.sock = sock
        end)
        :on('message', print)
        :on(event('disconect'))
        :on(event('ping'))
        :on(event('error'))
        :run()
end

local function key(self, std, name)
    if self.sock then
        self.sock:send(name)
    end
end

local P = {
    meta={
        title='Hello world',
        author='RodrigoDornelles',
        description='say hello to the world!',
        version='1.0.0'
    },
    config = {
        require='http'
    },
    callbacks={
        init=init,
        key=key
    }
}

return P;
