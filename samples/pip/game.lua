local App = {
    title = 'PIP Grid',
    version = '1.0.0',
    assets = {
        "samples/pip/lines.png:assets/lines.png"
    },
    screens = {
        {left=20, top=482, width=388, height=218},
        {left=700, top=13, width=388, height=218},
    },
    require = "media.tv?"
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
    if self.pip_image then
        std.image.draw(self.pip_image, 0, 0)
    end
end

function App.key(self, std)
    if std.key.press.up then
        std.media.pip(700, 13, 388, 218)
        if std.media.tv then
            std.media.tv():position(700, 13, 388, 218):resume()
        end
    elseif std.key.press.down then
        self.pip_image = "assets/lines.png"
        std.media.pip(20, 482, 388, 218)
        if std.media.tv then
            std.media.tv():position(20, 482, 388, 218):resume()
        end
    end
end

return App
