local App = {
    title = 'PIP Grid',
    version = '1.0.0'
}

local makeColorLine = function(color)
    return {
        draw = function(self, std)
            std.draw.color(color)
            std.draw.rect(0, 1, 1, self.width - 2, self.height - 2)
        end
    }
end

function App.load(self, std)
    std.ui.grid('1x10')
        :add(makeColorLine(std.color.red))
        :add(makeColorLine(std.color.yellow))
        :add(makeColorLine(std.color.green))
        :add(makeColorLine(std.color.purple))
        :add(makeColorLine(std.color.blue))
        :add(makeColorLine(std.color.magenta))
        :add(makeColorLine(std.color.white))
        :add(makeColorLine(std.color.gray))
        :add(makeColorLine(std.color.brown))
        :add(makeColorLine(std.color.orange))
end

function App.draw(self, std)
    std.image.draw('assets/lines.png', 0, 0)
end

function App.key(self, std)
    if std.key.press.up or std.key.press.left or std.key.press.right or std.key.press.down then
        std.media.pip(500, 13, 387, 218)
    end
end

return App
