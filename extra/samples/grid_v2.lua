local App = {
    title = 'Grid System v2',
    version = '1.0.0',
    require = 'math'
}

local makeCard = function(text, color)
    return {
        draw = function(self, std)
            std.draw.color(color)
            std.draw.rect(1, 1, 1, self.width - 2, self.height - 2)
            local w, h = std.math.ceil(self.width), std.math.ceil(self.height)
            local _, s = std.text.print_ex(w/2, h/2, text, 0, 0)
            std.text.print(2, 2, tostring(w)..'x'..tostring(h))
        end
    }
end

function App.load(self, std)
    std.ui.grid('6x6')
        :add(makeCard('foo', std.color.red), {span='2x2'})
        :add(makeCard('bar', std.color.blue))
        :add(makeCard('bar', std.color.blue))
        :add(makeCard('bar', std.color.blue))
        :add(makeCard('bar', std.color.blue))
        :add(makeCard('baz', std.color.yellow))
        :add(makeCard('baz', std.color.yellow))
        :add(makeCard('baz', std.color.yellow))
        :add(makeCard('baz', std.color.yellow))
        :add(makeCard('zig', std.color.green), {span='6x2'})
        :add(makeCard('zag', std.color.orange), {span='1x2'})
        :add(makeCard('zag', std.color.orange), {span='1x2'})
        :add(makeCard('zip', std.color.white))
        :add(makeCard('zip', std.color.white))
        :add(makeCard('zip', std.color.white))
        :add(makeCard('zip', std.color.white))
end

return App
