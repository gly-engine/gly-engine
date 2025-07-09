local App = {
    title = 'Grid System',
    version = '1.0.0',
    require = 'math'
}

local ClimaTV = {
    draw = function(std, data)
        std.draw.color(std.color.red)
        std.draw.rect(1, 1, 1, data.width - 2, data.height - 2)
        local w, h = tostring(std.math.ceil(data.width)), tostring(std.math.ceil(data.height))
        local _, s = std.text.print_ex(2, 2, 'Clima TV')
        std.text.print(2, 2 + s, w..'x'..h)
    end
}

local HoraTv = {
    draw = function(std, data)
        std.draw.color(std.color.green)
        std.draw.rect(1, 1, 1, data.width - 2, data.height - 2)
        local w, h = tostring(std.math.ceil(data.width)), tostring(std.math.ceil(data.height))
        local _, s = std.text.print_ex(2, 2, 'Hora TV')
        std.text.print(2, 2 + s, w..'x'..h)
    end
}

local TestTv = {
    draw = function(std, data)
        std.draw.color(std.color.yellow)
        std.draw.rect(1, 1, 1, data.width - 2, data.height - 2)
        local w, h = tostring(std.math.ceil(data.width)), tostring(std.math.ceil(data.height))
        local _, s = std.text.print_ex(2, 2, 'Test TV')
        std.text.print(2, 2 + s, w..'x'..h)
    end
}

function App.load(std, data)
    std.ui.grid('6x2')
        :add(ClimaTV, 3)
        :add(ClimaTV)
        :add(ClimaTV)
        :add(ClimaTV)
        :add(std.ui.grid('2x2')
            :add(HoraTv)
            :add(HoraTv)
            :add(HoraTv)
            :add(HoraTv),
            2
        )
        :add(TestTv, 3)
        :add(ClimaTV)
end

return App
