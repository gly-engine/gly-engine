local App = {
    meta = {
        title = 'Peek Carousel',
        version = '0.3.0'
    }
}

local PAD  = 8
local CARD = 120

--! @code
--! const Card = (props, std) => <node draw={() => {}}/>
--! @endcode
local Card = function(props, std)
    return std.h('node', {
        draw = function(self)
            local bg = std.ui.isFocused() and 0xFFFFFFFF or props.color
            local fg = std.ui.isFocused() and props.color or 0xFFFFFFFF
            local oy = std.ui.isFocused() and 0 or 20
            std.draw.color(bg)
            std.draw.rect(1, PAD, oy + PAD, self.width - PAD * 2, CARD - PAD * 2)
            std.draw.color(fg)
            std.text.print(PAD * 2, oy + PAD + 16, props.label)
            std.text.print(PAD * 2, oy + PAD + 36, '#' .. props.idx)
        end,
        click = function()
            print('pressed', props.idx)
        end
    })
end

--! @code
--! <grid class="7x1" scroll="peek">
--!    <Card/>
--!    <Card/>
--! </grid>
--! @endcode
function App.load(self, std)
    std.h('grid', {class='7x1', scroll='peek'},
        std.h(Card, {label='Noticias',   color=0x1A6FD4FF, idx=1}),
        std.h(Card, {label='Esportes',   color=0xCC2222FF, idx=2}),
        std.h(Card, {label='Filmes',     color=0x7722CCFF, idx=3}),
        std.h(Card, {label='Musica',     color=0x22AA55FF, idx=4}),
        std.h(Card, {label='Infantil',   color=0xDD8800FF, idx=5}),
        std.h(Card, {label='Series',     color=0x2299AAFF, idx=6}),
        std.h(Card, {label='Ao Vivo',    color=0xAA3311FF, idx=7}),
        std.h(Card, {label='Noticias 2', color=0x1A6FD4FF, idx=8}),
        std.h(Card, {label='Esportes 2', color=0xCC2222FF, idx=9}),
        std.h(Card, {label='Filmes 2',   color=0x7722CCFF, idx=10}),
        std.h(Card, {label='Musica 2',   color=0x22AA55FF, idx=11}),
        std.h(Card, {label='Series 2',   color=0x2299AAFF, idx=12})
    )
end

function App.key(self, std)
    if std.key.press.right then
        std.ui.focus('right')
    elseif std.key.press.left then 
        std.ui.focus('left')
    elseif std.key.press.a then
        std.ui.press()
    end
end

function App.draw(self, std)
end

return App
