local function init(self, std)
    self.exclamation = '!'
    if std.storage then
        std.storage.get('message'):as('exclamation'):default('!!')
            :callback(function() std.storage.set('message', ' back!'):run() end)
            :run()
    end
end

local function loop(self, std)
end

local function draw(self, std)
    std.draw.clear(std.color.blue)
    std.draw.color(std.color.white)
    std.text.font_size(16)
    std.text.print(std.text.print_ex(8, 8, 'Wellcome') + 8, 8, tostring(self.exclamation))
end

local function exit(self, std)
end

local P = {
    meta={
        title='Wellcome!',
        author='RodrigoDornelles',
        description='say -Wellcome!- in firsty entry and -Wellcome Back- for returning visitors.',
        version='1.0.0'
    },
    config={
        require='storage? json'
    },
    callbacks={
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P;
