local App = {
    meta = { title = 'Primeflix2', version = '0.1.0' }
}

local PAD    = 10
local CARD_H = 90

local banner_title = 'O Senhor dos Pasteis'
local banner_fobar = 'Destaques'
local banner_color = 0x1A3A6AFF

local unpack = table.unpack or unpack

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
        click = function()
            std.ui.focus('#'..string.lower(props.label))
        end
    })
end

local Banner = function(props, std)
    return std.h('node', {
        draw = function(self)
            std.draw.color(banner_color)
            std.draw.rect(1, 0, 0, self.width, self.height)
            std.draw.color(0x000000CC)
            std.draw.rect(1, 0, self.height - 54, self.width / 2, 54)
            std.draw.color(0xFFFFFFFF)
            std.text.print(PAD, self.height - 34, banner_title)
            std.draw.color(0xCCCCCCFF)
            std.text.print(PAD, self.height - 16, banner_fobar..props.sub)
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
        focus = function()
            banner_title = props.title
            banner_fobar = props.tab
            banner_color = props.color
            if props.tab == 'Destaques' then
                std.ui.class('1x2', '#scroll')
                std.ui.span(6, '#scroll')
                std.ui.span(5, '#banner')
            else
                std.ui.class('1x4', '#scroll')
                std.ui.span(11, '#scroll')
                std.ui.span(0, '#banner')
            end
        end,
        tab = props.tab or 'geral'
    })
end

local Category = function(props, std)
    local title = {
        draw = function()
            std.draw.color(std.color.white)
            std.text.font_size(12)
            std.text.print(0, 0, props.title)
        end
    }

    return std.h('grid', {class='1x6'},
        std.h('grid', { class='6x1', style = 'overflow'}, std.h('item', {offset = 1}, std.h('node', title))),
        std.h('grid', { class='6x1', scroll='peek', id = string.lower(props.title), span = 5, style = 'overflow' }, unpack(props.children))
    )
end

function App.load(self, std)
    std.h('style', { class = 'overflow', width = '120vw' })
    std.h('style', { class = 'top10pct', top = '10%' })

    std.h('grid', { class='1x12' },
        std.h('grid', { class='5x1'},
            std.h(Tab, { label='Destaques'  }),
            std.h(Tab, { label='Seriado'   }),
            std.h(Tab, { label='Filme'     }),
            std.h(Tab, { label='Bola e Luta' }),
            std.h(Tab, { label='Mulecada' })
        ),
        std.h('item', { span = 5, id = 'banner' },
            std.h(Banner, {
                sub   = ' - 2001 - 5 pao de queijo'
            })
        ),
        std.h('grid', { class='1x2', id = 'scroll', scroll='shift', span = 6, style = 'top10pct'},
            std.h(Category, { title = 'Destaques'},
                std.h(Card, { title='Cozinhano Pior',  color=0x1A3060FF, tab = 'Destaques'}),
                std.h(Card, { title='Os Mano',         color=0x601A1AFF, tab = 'Destaques'}),
                std.h(Card, { title='Alcancador 2',    color=0x1A6030FF, tab = 'Destaques'}),
                std.h(Card, { title='Deu Ruim Demais', color=0x60501AFF, tab = 'Destaques'}),
                std.h(Card, { title='Fortal City',     color=0x3A1A60FF, tab = 'Destaques'}),
                std.h(Card, { title='Joao Rambo',      color=0x1A5060FF, tab = 'Destaques'})
            ),
            std.h(Category, { title = 'Seriado' },
                std.h(Card, { title='Areia Mexeno',    color=0x50401AFF, tab = 'Seriado' }),
                std.h(Card, { title='Openheira',       color=0x1A1A50FF, tab = 'Seriado' }),
                std.h(Card, { title='Avatarao 2',      color=0x1A5050FF, tab = 'Seriado' }),
                std.h(Card, { title='Aviaozim',        color=0x1A2060FF, tab = 'Seriado' }),
                std.h(Card, { title='Bonecao doido',   color=0x601A40FF, tab = 'Seriado' }),
                std.h(Card, { title='Nadinha nao',     color=0x401A20FF, tab = 'Seriado' })
            ),
            std.h(Category, { title = 'Filme' },
                std.h(Card, { title='Velozes e Nervoso', color=0x50301AFF, tab = 'Filme' }),
                std.h(Card, { title='Homem Aranhao',     color=0x1A3050FF, tab = 'Filme' }),
                std.h(Card, { title='Batema Trevoso',    color=0x101010FF, tab = 'Filme' }),
                std.h(Card, { title='Senhor dos Pastel', color=0x705020FF, tab = 'Filme' }),
                std.h(Card, { title='Jurassico Parkado', color=0x206020FF, tab = 'Filme' }),
                std.h(Card, { title='Matrixado',         color=0x103030FF, tab = 'Filme' })
            ),
            std.h(Category, { title = 'Bola e Luta' },
                std.h(Card, { title='Encantasso FC',   color=0x60401AFF, tab = 'Bola e Luta' }),
                std.h(Card, { title='Lucao da Massa',  color=0x1A6050FF, tab = 'Bola e Luta' }),
                std.h(Card, { title='Moanada',         color=0x1A4060FF, tab = 'Bola e Luta' }),
                std.h(Card, { title='Alminha Briga',   color=0x1A1A60FF, tab = 'Bola e Luta' }),
                std.h(Card, { title='Raio da Pancada', color=0x501A1AFF, tab = 'Bola e Luta' }),
                std.h(Card, { title='Vermelho Nervoso',color=0x601A1AFF, tab = 'Bola e Luta' })
            ),
            std.h(Category, { title = 'Mulecada' },
                std.h(Card, { title='O Fio 2',         color=0x2A1A50FF, tab = 'Mulecada' }),
                std.h(Card, { title='Sucessao Jr',     color=0x501A2AFF, tab = 'Mulecada' }),
                std.h(Card, { title='Pedra Amarelao',  color=0x1A4020FF, tab = 'Mulecada' }),
                std.h(Card, { title='Rescisao Kids',   color=0x401A40FF, tab = 'Mulecada' }),
                std.h(Card, { title='Euforia Teen',    color=0x1A3050FF, tab = 'Mulecada' }),
                std.h(Card, { title='Andano e Rino',   color=0x203A20FF, tab = 'Mulecada' })
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

return App