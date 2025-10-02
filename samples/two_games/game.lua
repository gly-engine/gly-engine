--! @see pong
--! @see asteroids

local function load(self, std)
    local game1 = std.node.load('samples/pong/game.lua')
    local game2 = std.node.load('samples/asteroids/game.lua')

    self.toggle = false
    self.ui_split = std.ui.grid('2x1')
        :add(game1)
        :add(game2)

    std.node.pause(self.ui_split:get_item(2), 'loop')
end

local function key(self, std)
    if std.key.press.b then
        local to_pause = self.ui_split:get_item(self.toggle and 2 or 1)
        local to_resume = self.ui_split:get_item(self.toggle and 1 or 2)
        std.node.pause(to_pause, 'loop')
        std.node.resume(to_resume, 'loop')
        self.toggle = not self.toggle
    end
end

local P = {
    meta={
        title='2 Games',
        author='RodrigoDornelles',
        description='play asteroids and pong in the same time',
        version='1.0.0'
    },
    config={
        require='math.random i18n math'
    },
    callbacks={
        load=load,
        key=key
    }
}

return P;
