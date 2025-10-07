local App = {
    title = 'Fonts System',
    author = 'Joao Vicente',
    version = '1.0.0',
    require = 'math'
}

App.fonts = {
 'Tiresias:https://cdn.jsdelivr.net/gh/alyssonbrito/gingaar@latest/ginga.ar-2.0/tool/ginga/fonts/Tiresias.ttf'
}

function App.draw(self, std)
    std.text.font_name('Tiresias')
    std.draw.clear(std.color.black)
    
    for y = 10, 720, 10 do
        if (y/10) % 2 == 0 then
            std.draw.color(std.color.blue)
        else
            std.draw.color(std.color.red)
        end
        std.draw.rect(0, 0, y, self.width, 1)
    end

    local font_size = 8
    local x = 50

    std.draw.color(std.color.white)
    for i = 1, 12 do
        std.text.font_size(font_size)
        std.text.print_ex(x, 60-font_size, "A",0)
        local w, h = std.text.mensure("A")
        w = std.math.floor(w)
        h = std.math.floor(h)
        std.text.font_size(15)
        if i % 2 == 1 then
            std.text.print_ex(x, 60 + 45, font_size .." - "..w .. "x" .. h,0)
        else
            std.text.print_ex(x, 60 + 25, font_size .." - "..w .. "x" .. h,0)
        end
        x = x + 105
        font_size = font_size + 4
    end

    x = 50
    for i = 1, 12 do
        std.text.font_size(font_size)
        std.text.print_ex(x, 300-font_size, "A",0)
        local w, h = std.text.mensure("A")
        w = std.math.floor(w)
        h = std.math.floor(h)
        std.text.font_size(15)
        if i % 2 == 1 then
            std.text.print_ex(x, 300 + 45, font_size .." - "..w .. "x" .. h,0)
        else
            std.text.print_ex(x, 300 + 25, font_size .." - "..w .. "x" .. h,0)
        end
        x = x + 105
        font_size = font_size + 4
    end

    x = 50
    for i = 1, 12 do
        std.text.font_size(104)
        std.text.print_ex(x, 605-font_size, "A",0)
        local w, h = std.text.mensure("A")
        w = std.math.floor(w)
        h = std.math.floor(h)
        std.text.font_size(15)
        if i % 2 == 1 then
            std.text.print_ex(x, 600 + 45, 104 .." - "..w .. "x" .. h,0)
        else
            std.text.print_ex(x, 600 + 25, 104 .." - "..w .. "x" .. h,0)
        end
        x = x + 105
    end
end

return App