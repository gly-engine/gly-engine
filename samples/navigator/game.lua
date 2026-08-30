local App = {
    meta = {
        title       = 'Navigator',
        description = 'Focus navigation with std.ui.slide()',
        author      = 'RodrigoDornelles',
        version     = '1.0.0',
    }
}

-- ─── Channel data ─────────────────────────────────────────────────────────────

local CHANNELS = {
    { label = 'Noticias',  color = 0x1A6FD4FF },
    { label = 'Esportes',  color = 0xCC2222FF },
    { label = 'Filmes',    color = 0x7722CCFF },
    { label = 'Musica',    color = 0x22AA55FF },
    { label = 'Infantil',  color = 0xDD8800FF },
    { label = 'Noticias2', color = 0x1A6FD4FF },
    { label = 'Esportes2', color = 0xCC2222FF },
    { label = 'Filmes2',   color = 0x7722CCFF },
    { label = 'Musica2',   color = 0x22AA55FF },
    { label = 'Infantil2', color = 0xDD8800FF },
}

-- ─── Shared focus state (read by App.draw) ───────────────────────────────────

local focused_color = CHANNELS[1].color
local focused_label = CHANNELS[1].label
local focused_clicks = 0

-- ─── Card layout constants ───────────────────────────────────────────────────

local HEADER  = 80   -- px reserved at top for chrome
local FOOTER  = 80   -- px reserved at bottom for chrome
local LIFT    = 60   -- extra px unfocused cards are pushed down
local PAD     = 10   -- horizontal padding inside each card

-- ─── Channel card ─────────────────────────────────────────────────────────────

local function make_channel(label, base_color)
    return {
        label      = label,
        base_color = base_color,
        focused    = false,
        clicks     = 0,

        draw = function(self, std)
            local lift = self.focused and 0 or LIFT
            local card_y = HEADER + lift
            local card_h = self.height - HEADER - FOOTER - lift
            local bg     = self.focused and 0xFFFFFFFF or self.base_color
            local fg     = self.focused and self.base_color or 0xFFFFFFFF

            -- card background
            std.draw.color(bg)
            std.draw.rect(1, PAD, card_y, self.width - PAD * 2, card_h)

            -- left accent stripe when unfocused
            if not self.focused then
                std.draw.color(self.base_color)
                std.draw.rect(1, PAD, card_y, 4, card_h)
            end

            -- label
            std.draw.color(fg)
            std.text.print(PAD + 12, card_y + 20, self.label)

            -- click count
            if self.clicks > 0 then
                std.text.print(PAD + 12, card_y + 42, self.clicks .. 'x assistido')
            end
        end,

        focus = function(self, std)
            self.focused     = true
            focused_color    = self.base_color
            focused_label    = self.label
            focused_clicks   = self.clicks
        end,

        unfocus = function(self, std)
            self.focused = false
        end,

        click = function(self, std)
            self.clicks    = self.clicks + 1
            focused_clicks = self.clicks
        end,
    }
end

-- ─── App callbacks ───────────────────────────────────────────────────────────

function App.load(self, std)
    local s = std.ui.slide('4x1')
    for _, ch in ipairs(CHANNELS) do
        s:add(make_channel(ch.label, ch.color))
    end
end

function App.key(self, std)
    if std.key.press.left  then std.ui.focus('left')  end
    if std.key.press.right then std.ui.focus('right') end
    if std.key.press.a     then std.ui.press()        end
end

function App.draw(self, std)
    -- base background
    std.draw.color(0x111111FF)
    std.draw.rect(1, 0, 0, self.width, self.height)

    -- top color strip matching focused channel
    std.draw.color(focused_color)
    std.draw.rect(1, 0, 0, self.width, 4)

    -- focused channel name in header
    std.draw.color(0xEEEEEEFF)
    std.text.print(16, 22, focused_label)

    if focused_clicks > 0 then
        std.draw.color(0x888888FF)
        std.text.print(16, 46, focused_clicks .. 'x assistido')
    end

    -- footer instructions
    std.draw.color(0x444444FF)
    std.text.print(16, self.height - FOOTER + 20, '<< >>: navegar     Z / A: selecionar')
end

function App.error(self, std, msg)
    print(msg)
end

return App
