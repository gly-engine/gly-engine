local App = {
    meta = { title = 'Flow Carousel', version = '0.3.0' }
}

local ITEMS = {
    { label = 'Noticias',   color = 0x1A6FD4FF },
    { label = 'Esportes',   color = 0xCC2222FF },
    { label = 'Filmes',     color = 0x7722CCFF },
    { label = 'Musica',     color = 0x22AA55FF },
    { label = 'Infantil',   color = 0xDD8800FF },
    { label = 'Series',     color = 0x2299AAFF },
    { label = 'Ao Vivo',    color = 0xAA3311FF },
    { label = 'Noticias 2', color = 0x1A6FD4FF },
    { label = 'Esportes 2', color = 0xCC2222FF },
    { label = 'Filmes 2',   color = 0x7722CCFF },
    { label = 'Musica 2',   color = 0x22AA55FF },
    { label = 'Series 2',   color = 0x2299AAFF },
}

local PAD  = 8
local CARD = 120

local focused = { label = ITEMS[1].label, color = ITEMS[1].color, idx = 1 }

local function make_card(item, idx)
    return {
        label = item.label, color = item.color, idx = idx, focused = false,

        draw = function(self, std)
            local bg = self.focused and 0xFFFFFFFF or self.color
            local fg = self.focused and self.color   or 0xFFFFFFFF
            local oy = self.focused and 0 or 20
            std.draw.color(bg)
            std.draw.rect(1, PAD, oy + PAD, self.width - PAD * 2, CARD - PAD * 2)
            std.draw.color(fg)
            std.text.print(PAD * 2, oy + PAD + 16, self.label)
            std.text.print(PAD * 2, oy + PAD + 36, '#' .. self.idx)
        end,

        focus   = function(self) self.focused = true;  focused = { label = self.label, color = self.color, idx = self.idx } end,
        unfocus = function(self) self.focused = false end,
    }
end

function App.load(self, std)
    std.ui.style('carousel', { top = 80, height = CARD })
    local s = std.ui.slide('7x1', { scroll = 'flow' })
    std.ui.style('carousel'):add(s.node)
    for i, item in ipairs(ITEMS) do s:add(make_card(item, i)) end
end

function App.key(self, std)
    if std.key.press.left  then std.ui.focus('left')  end
    if std.key.press.right then std.ui.focus('right') end
    if std.key.press.a     then std.ui.press()        end
end

function App.draw(self, std)
    std.draw.color(0x111111FF)
    std.draw.rect(1, 0, 0, self.width, self.height)
    std.draw.color(focused.color)
    std.draw.rect(1, 0, 0, self.width, 4)
    std.draw.color(0xEEEEEEFF)
    std.text.print(16, 16, focused.label)
    std.draw.color(0x666666FF)
    std.text.print(16, 40, 'item ' .. focused.idx .. ' de ' .. #ITEMS)
end

function App.error(self, std, msg) print(msg) end

return App
