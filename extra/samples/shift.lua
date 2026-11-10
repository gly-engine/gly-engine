-- shift mode test: carrossel horizontal classico
-- slide 7x1, scroll='shift' (padrao para 1D), 14 itens
-- todos os itens sao focaveis
-- cursor anda livremente pelos slots visiveis
-- quando bate na borda o viewport desliza: 2→3→4 vira 3→4→5→...

local App = {
    meta = {
        title       = 'Shift Carousel',
        description = 'Test: slide 7x1 scroll=shift — cursor livre, viewport desliza na borda',
        version     = '0.1.0',
    }
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
    { label = 'Infantil 2', color = 0xDD8800FF },
    { label = 'Series 2',   color = 0x2299AAFF },
    { label = 'Ao Vivo 2',  color = 0xAA3311FF },
}

local CARD_H   = 120
local CARD_PAD = 8

local focused_label = ITEMS[1].label
local focused_color = ITEMS[1].color
local focused_idx   = 1

local function make_card(item, idx)
    return {
        label      = item.label,
        base_color = item.color,
        idx        = idx,
        focused    = false,

        draw = function(self, std)
            local bg = self.focused and 0xFFFFFFFF or self.base_color
            local fg = self.focused and self.base_color or 0xFFFFFFFF
            local y  = self.focused and 0 or 20

            std.draw.color(bg)
            std.draw.rect(1, CARD_PAD, y + CARD_PAD, self.width - CARD_PAD * 2, CARD_H - CARD_PAD * 2)

            std.draw.color(fg)
            std.text.print(CARD_PAD * 2, y + CARD_PAD + 16, self.label)
            std.text.print(CARD_PAD * 2, y + CARD_PAD + 36, '#' .. self.idx)
        end,

        focus = function(self, std)
            self.focused  = true
            focused_label = self.label
            focused_color = self.base_color
            focused_idx   = self.idx
        end,

        unfocus = function(self, std)
            self.focused = false
        end,
    }
end

function App.load(self, std)
    -- scroll='shift' e o padrao para slides 1D, mas explicitado aqui para clareza
    local s = std.ui.slide('7x1', { scroll = 'shift' })
    for i, item in ipairs(ITEMS) do
        s:add(make_card(item, i))
    end
end

function App.key(self, std)
    if std.key.press.left  then std.ui.focus('left')  end
    if std.key.press.right then std.ui.focus('right') end
    if std.key.press.a     then std.ui.press()        end
end

function App.draw(self, std)
    std.draw.color(0x111111FF)
    std.draw.rect(1, 0, 0, self.width, self.height)

    -- barra de cor do item focado
    std.draw.color(focused_color)
    std.draw.rect(1, 0, 0, self.width, 4)

    -- header
    std.draw.color(0xEEEEEEFF)
    std.text.print(16, 16, focused_label)
    std.draw.color(0x666666FF)
    std.text.print(16, 36, 'item ' .. focused_idx .. ' de ' .. #ITEMS)

    -- rodape
    std.draw.color(0x444444FF)
    std.text.print(16, self.height - 24, '<< >>: navegar | cursor livre, viewport desliza na borda')
end

function App.error(self, std, msg)
    print(msg)
end

return App
