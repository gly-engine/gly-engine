local App = {
    meta = { title = 'Primeflix', version = '0.1.0' }
}

local PAD    = 10
local CARD_H = 90

local Tab = function(props, std)
    return std.h('node', {
        draw = function(self)
            local on = std.ui.isFocused()
            std.draw.color(on and 0xFFFFFFFF or 0x888888FF)
            std.text.print(PAD, 14, props.label)
            if on then
                std.draw.color(0x00BBFFFF)
                std.draw.rect(1, 0, self.height - 3, self.width, 3)
            end
        end,
        click = function() std.ui.press() end
    })
end

local Banner = function(props, std)
    return std.h('node', {
        draw = function(self)
            std.draw.color(props.color)
            std.draw.rect(1, 0, 0, self.width, self.height)
            std.draw.color(0x000000CC)
            std.draw.rect(1, 0, self.height - 54, self.width / 2, 54)
            std.draw.color(0xFFFFFFFF)
            std.text.print(PAD, self.height - 34, props.title)
            std.draw.color(0xCCCCCCFF)
            std.text.print(PAD, self.height - 16, props.sub)
        end
    })
end

local Card = function(props, std)
    return std.h('node', {
        draw = function(self)
            local on = std.ui.isFocused()
            local lift = on and -6 or 0
            std.draw.color(props.color)
            std.draw.rect(1, 0, lift, self.width - PAD, self.height - PAD)
            std.draw.color(on and 0xFFFFFFFF or 0xCCCCCCFF)
            std.text.print(PAD, self.height / 2 - 6 + lift, props.title)
        end,
        click = function() end
    })
end

function App.load(self, std)
    std.h('style', { class = 'overflow', width = '120vw' })

    std.h('grid', { class='1x12' },
        std.h('grid', { class='5x1'},
            std.h(Tab, { label='Inicio'   }),
            std.h(Tab, { label='Series'   }),
            std.h(Tab, { label='Filmes'   }),
            std.h(Tab, { label='Esportes' }),
            std.h(Tab, { label='Infantil' })
        ),
        std.h('item', { span = 5 },
            std.h(Banner, {
                title = 'O Senhor dos Aneis de Cebola',
                sub   = 'Fantasia - 2001 - 5 estrelas',
                color = 0x1A3A6AFF
            })
        ),
        std.h('grid', { class='1x2', scroll='shift', span = 6},
            std.h('grid', { class='6x1', scroll='flow', style = 'overflow'  },
                std.h(Card, { title='Cozinhando Mal',  color=0x1A3060FF }),
                std.h(Card, { title='Os Caras',        color=0x601A1AFF }),
                std.h(Card, { title='Alcancador',      color=0x1A6030FF }),
                std.h(Card, { title='Caiu Tudo',       color=0x60501AFF }),
                std.h(Card, { title='Fortaleza',       color=0x3A1A60FF }),
                std.h(Card, { title='Joao Ryan',       color=0x1A5060FF })
            ),
            std.h('grid', { class='6x1', scroll='flow', style = 'overflow' },
                std.h(Card, { title='Areia',           color=0x50401AFF }),
                std.h(Card, { title='Openheimer',      color=0x1A1A50FF }),
                std.h(Card, { title='Avatarao 2',      color=0x1A5050FF }),
                std.h(Card, { title='Aviazinho',       color=0x1A2060FF }),
                std.h(Card, { title='Bonecao',         color=0x601A40FF }),
                std.h(Card, { title='Nops',            color=0x401A20FF })
            ),
            std.h('grid', { class='6x1', scroll='flow', style = 'overflow' },
                std.h(Card, { title='O Fio',           color=0x2A1A50FF }),
                std.h(Card, { title='Sucessao',        color=0x501A2AFF }),
                std.h(Card, { title='Pedra Amarela',   color=0x1A4020FF }),
                std.h(Card, { title='Rescisao',        color=0x401A40FF }),
                std.h(Card, { title='Euforiasso',      color=0x1A3050FF }),
                std.h(Card, { title='Ando',            color=0x203A20FF })
            ),
            std.h('grid', { class='6x1', scroll='flow', style = 'overflow' },
                std.h(Card, { title='Encantasso',      color=0x60401AFF }),
                std.h(Card, { title='Lucao',           color=0x1A6050FF }),
                std.h(Card, { title='Moanassa',        color=0x1A4060FF }),
                std.h(Card, { title='Alminha',         color=0x1A1A60FF }),
                std.h(Card, { title='Raiassa',         color=0x501A1AFF }),
                std.h(Card, { title='Virando Vermelha',color=0x601A1AFF })
            )
        )
    )
end

function App.key(self, std)
    if     std.key.press.right then std.ui.focus('right')
    elseif std.key.press.left  then std.ui.focus('left')
    elseif std.key.press.down  then std.ui.focus('down')
    elseif std.key.press.up    then std.ui.focus('up')
    elseif std.key.press.a     then std.ui.press()
    end
end

function App.draw(self, std)
end

return App
