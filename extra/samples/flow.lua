-- flow mode test: carrossel horizontal estilo netflix
-- slide 7x1, scroll='flow', 14 itens
-- item[1] e item[14] sao peeks permanentes (nao focaveis, nunca navegaveis)
-- cursor fica fixo no slot ancora (slot1) ate bater na borda direita
-- na borda direita a ancora se move: cursor anda do slot1 ate slot5

local App = {
    meta = {
        title       = 'Flow Carousel',
        description = 'Test: slide 7x1 scroll=flow — peek permanente, ancora, borda',
        version     = '0.2.0',
    }
}

local ITEMS = {
    { label = 'Peek L',     color = 0x333333FF },  -- [1]  peek esquerda, nao focavel
    { label = 'Noticias',   color = 0x1A6FD4FF },  -- [2]  primeiro focavel
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
    { label = 'Peek R',     color = 0x333333FF },  -- [14] peek direita, nao focavel
}

local CARD_H   = 120
local CARD_PAD = 8

local focused_label = ITEMS[2].label
local focused_color = ITEMS[2].color
local focused_idx   = 2

-- peek: sem callbacks focus/unfocus → nao entra na focus_list → nunca focavel
local function make_peek(item, idx)
    return {
        label      = item.label,
        base_color = item.color,
        idx        = idx,

        draw = function(self, std)
            std.draw.color(0x222222FF)
            std.draw.rect(1, CARD_PAD, CARD_PAD, self.width - CARD_PAD * 2, CARD_H - CARD_PAD * 2)
            std.draw.color(0x555555FF)
            std.text.print(CARD_PAD * 2, CARD_PAD + 16, self.label)
        end,
    }
end

-- card normal: com focus/unfocus → entra na focus_list → focavel
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
    -- ancora default = slot1 (segundo slot)
    -- item[1] e item[14] sao peeks: make_peek sem callbacks focus/unfocus
    local s = std.ui.slide('7x1', { scroll = 'flow' })
    for i, item in ipairs(ITEMS) do
        if i == 1 or i == #ITEMS then
            s:add(make_peek(item, i))
        else
            s:add(make_card(item, i))
        end
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
    std.text.print(16, 36, 'item ' .. focused_idx .. ' de ' .. (#ITEMS - 2) .. ' (focaveis)')

    -- rodape
    std.draw.color(0x444444FF)
    std.text.print(16, self.height - 24, '<< >>: navegar | peeks[1] e [' .. #ITEMS .. '] nunca focaveis')
end

function App.error(self, std, msg)
    print(msg)
end

return App
