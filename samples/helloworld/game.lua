local function init( self, std)
   
end

local function loop(std, self)
end

local function draw( std, data)
    std.draw.clear(std.color.black)
    std.draw.color(std.color.white)
    std.text.put(1, 1, 'Hello world!')

end

local function exit(self, std)
end

local P = {
    meta={
        title='Hello world',
        author='RodrigoDornelles',
        description='say hello to the world!',
        version='1.0.0'
    },
    callbacks={
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P;
