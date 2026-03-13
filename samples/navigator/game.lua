local App = {
    meta = {
        title       = 'Navigator',
        description = 'Focus navigation with std.ui.slide()',
        author      = 'RodrigoDornelles',
        version     = '1.0.0',
    }
}

-- ─── Channel card data ───────────────────────────────────────────────────────

local CHANNELS = {
    { label = 'Canal Noticias', color = 0x1A6FD4FF },
    { label = 'Canal Esportes', color = 0xCC2222FF },
    { label = 'Canal Filmes',   color = 0x7722CCFF },
    { label = 'Canal Musica',   color = 0x22AA55FF },
    { label = 'Canal Infantil', color = 0xDD8800FF },
}

local function make_channel(label, base_color)
    return {
        label      = label,
        base_color = base_color,
        focused    = false,
        clicks     = 0,

        draw = function(self, std)
            local bg = self.focused and std.color.white or self.base_color
            local fg = self.focused and self.base_color or std.color.white

            -- background
            std.draw.color(bg)
            std.draw.rect(1, 2, 2, self.width - 4, self.height - 4)

            -- label
            std.draw.color(fg)
            std.text.print(10, 12, self.label)

            -- press counter
            if self.clicks > 0 then
                std.text.print(10, 30, 'selecionado: ' .. self.clicks .. 'x')
            end

            -- focus indicator
            if self.focused then
                std.text.print(self.width - 30, 12, '◀')
            end
        end,

        focus = function(self, std)
            print('focu')
            self.focused = true
        end,

        unfocus = function(self, std)
            self.focused = false
        end,

        click = function(self, std)
            self.clicks = self.clicks + 1
        end,
    }
end

-- ─── App root callbacks ──────────────────────────────────────────────────────

function App.load(self, std)
    local s = std.ui.slide('1x5')
    for _, ch in ipairs(CHANNELS) do
        s:add(make_channel(ch.label, ch.color))
    end
end

function App.key(self, std)
    if std.key.press.up    then std.ui.focus('up')    end
    if std.key.press.down  then std.ui.focus('down')  end
    if std.key.press.left  then std.ui.focus('left')  end
    if std.key.press.right then std.ui.focus('right') end
    if std.key.press.a     then std.ui.press()        end
end

function App.draw(self, std)
    -- dark background
    std.draw.color(0x111111FF)
    std.draw.rect(1, 0, 0, self.width, self.height)

    -- instructions
    std.draw.color(0x666666FF)
    std.text.print(10, self.height - 20, 'UP/DOWN: navegar   SETAS: navegar   Z/A: selecionar')
end

function App.error(self, std, msg)
    print(msg)
end

return App
