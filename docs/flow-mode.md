# Modo `flow` — algoritmo

Modo de scroll para slides 1D (Nx1 ou 1xN) estilo carrossel.
O cursor fica fixo no **slot âncora** e os itens se movem ao redor dele.

---

## Comportamento visual (1x7, 14 itens, âncora = slot1)

```
selected=item1 :  [ ___  ][ item1  ][ item2  ][ item3  ][ item4↓ ][ item5↓ ][ item6↓ ]
selected=item2 :  [ item1↓][ item2  ][ item3  ][ item4  ][ item5↓ ][ item6↓ ][ item7↓ ]
selected=item3 :  [ item2↓][ item3  ][ item4  ][ item5  ][ item6↓ ][ item7↓ ][ item8↓ ]
...
selected=item10:  [ item9↓][ item10 ][ item11 ][ item12 ][ item13  ][ item14 ][ ___   ]
selected=item11:  [ item9↓][ item10 ][ item11 ][ item12 ][ item13  ][ item14 ][ ___   ]
selected=item12:  [ item9↓][ item10 ][ item11 ][ item12 ][ item13  ][ item14 ][ ___   ]
...
selected=item14:  [ item9↓][ item10 ][ item11 ][ item12 ][ item13  ][ item14 ][ ___   ]
```

- `↓` = peek (meio item visível via CSS overflow do container)
- `___` = slot vazio (sem item)
- Borda esquerda: slot0 vazio, item1 na âncora (slot1)
- Borda direita: viewport trava, slot6 vazio, cursor anda da âncora até slot5

---

## Fórmula principal

Para `dir='col'` (Nx1, scroll horizontal):

```
x_start = max(anchor - selected_idx, -(total - N + 1))
```

Para `dir='row'` (1xN, scroll vertical):

```
y_start = max(anchor - selected_idx, -(total - N + 1))
```

Onde:
- `anchor` = slot âncora (default 1)
- `selected_idx` = índice 0-based do item focado = `scroll.index`
- `total` = `#node.childs`
- `N` = `cols` (para dir='col') ou `rows` (para dir='row')

### Verificação

N=7, anchor=1, total=14:

| selected (0-idx) | x_start calculado | slot0    | slot1 (âncora)  | slot6 |
|-----------------|-------------------|----------|------------------|-------|
| 0 (item1)       | max(1, -8) = **1** | _(vazio)_| item1 ✓         | item6↓|
| 1 (item2)       | max(0, -8) = **0** | item1↓   | item2 ✓         | item7↓|
| 8 (item9)       | max(-7,-8) = **-7**| item8↓   | item9 ✓         | item14↓|
| 9 (item10)      | max(-8,-8) = **-8**| item9↓   | item10 ✓        | _(vazio)_|
| 10 (item11)     | max(-9,-8) = **-8**| item9↓   | item10, cursor→slot2 | _(vazio)_|
| 13 (item14)     | max(-12,-8)= **-8**| item9↓   | item10, cursor→slot5 | _(vazio)_|

---

## Diferença para os outros modos

| Campo           | `shift`                     | `page`                     | `flow`                         |
|-----------------|-----------------------------|-----------------------------|-------------------------------|
| `scroll.index`  | offset de linha/coluna      | offset de página            | índice do item focado (0-based)|
| Layout          | `x = -scroll.index`         | `x = -(idx * cols)`         | `x = max(anchor-idx, clamp)`  |
| `ensure_visible`| shift window                | page flip                   | `scroll.index = child_index`  |
| Cursor visual   | anda até a borda, depois scroll | salta página inteira    | sempre na âncora (exceto bordas)|

---

## Mudanças necessárias no código

### 1. `scroll.lua` — `scroll_register`

Adicionar campo `anchor` no registro quando mode='flow':

```lua
self.scroll_registry[node] = {
    mode   = mode,
    index  = 0,
    anchor = options.anchor or 1,   -- <-- novo campo
    ...
}
```

### 2. `scroll.lua` — `ensure_visible`

Para `flow`, simplesmente atualiza `scroll.index` com o índice do filho focado.
O layout cuida de todo o posicionamento e clamping:

```lua
if scroll.mode == 'flow' then
    if scroll.index == child_index then return end
    scroll.index = child_index
    mark(self, slide_node)
    return
end
```

### 3. `layout.lua` — `dom_layout`

Novo branch para `flow` no bloco de offset do slide:

```lua
elseif scroll.mode == 'flow' then
    local total  = node.childs and #node.childs or 0
    local anchor = scroll.anchor or 1
    if dir_val == 'col' then
        x = math.max(anchor - scroll.index, -(total - cols + 1))
    else
        y = math.max(anchor - scroll.index, -(total - rows + 1))
    end
```

> **Nota:** x/y positivos funcionam naturalmente — o item[0] começa em slot `anchor`,
> deixando os slots anteriores visualmente vazios (nenhum item renderizado lá).

### 4. `layout.lua` — `slide_step`

`flow` não usa step para paginação, mas precisa retornar 1 para que
`ensure_visible` funcione caso seja chamado pelo caminho genérico:

```lua
elseif scroll.mode == 'flow' then
    return 1
```

### 5. `jsx.lua`

Passar o atributo `anchor` se presente:

```lua
scroll_mod.scroll_register(engine.dom, grid.node, {
    mode   = attribute.scroll,
    focus  = attribute.focus,
    anchor = attribute.anchor,   -- <-- novo
})
```

---

## Uso no JSX

```lua
-- carrossel horizontal, âncora padrão (slot1)
std.h('slide', {class='7x1', scroll='flow'})

-- âncora no centro (slot3 de 7)
std.h('slide', {class='7x1', scroll='flow', anchor=3})

-- CSS do container para criar o efeito de peek
-- overflow: hidden no elemento pai do slide, e o slide em si fica ligeiramente
-- maior que o pai para os peeks aparecerem nos lados
```

---

## Casos de borda

| Situação | Comportamento |
|----------|--------------|
| `total <= anchor` | x_start sempre positivo, itens começam à direita do slot0 |
| `total <= N` | todos os itens cabem sem scroll, x_start = anchor (não rola) |
| `anchor = 0` | sem peek à esquerda em nenhum momento, comportamento flush-left |
| `total = 2` | com anchor=1: item1 na âncora, item2 à direita; ao navegar para item2, item1 fica como peek |
