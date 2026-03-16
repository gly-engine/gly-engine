# Análise de Problemas: `<slide/>` com layout NxM (ex: `2x5`)

## Contexto

O componente `<slide class="2x5"/>` cria um grid 2 colunas × 5 linhas com scroll.
Arquivos analisados: `browser/slide.lua`, `browser/scroll.lua`, `browser/layout.lua`, `browser/navigator.lua`, `browser/jsx.lua`

---

## BUG PRINCIPAL (raiz de tudo)

### `layout.lua` usa o step como linhas, `ensure_visible` usa como itens — unidades diferentes

**Arquivos:** `layout.lua:87` e `scroll.lua:68`
**Gravidade:** Crítica — foco vai para item invisível, scroll não atualiza

#### Trace exato para `2x5` (cols=2, rows=5, dir='row', mode='shift')

`slide_step` retorna `cols = 2` para dir='row'.

**layout.lua:87:**
```lua
local offset = scroll.index * slide_step(scroll)  -- scroll.index * 2
y = -offset  -- y começa em -(scroll.index * 2) LINHAS acima
```

O acumulador `y` está em unidades de **linhas** (incrementa por 1 a cada linha completa).
Logo, para `scroll.index=1`: `y_start = -2` pula **2 linhas**, não 2 itens.

Layout resultante com `scroll.index=1`:
```
items 0,1  → row -2  (OFF-SCREEN acima)
items 2,3  → row -1  (OFF-SCREEN acima)
items 4,5  → row  0  ← primeiro visível real
...
items 12,13 → row 4  ← último visível real
items 14+   → row 5+ (OFF-SCREEN abaixo)
```
**Viewport real: items 4–13**

**scroll.lua:68** — `ensure_visible` com `scroll.index=1`:
```lua
first_visible = scroll.index * step = 1 * 2 = 2   -- pensa que item 2 é o primeiro visível
last_visible  = 2 + 10 - 1 = 11                   -- pensa que item 11 é o último visível
```
**Viewport imaginário: items 2–11**

#### Como o bug se manifesta na prática

Usuário navega `down` do item 9 → focus vai para item 11 → `ensure_visible` seta `scroll.index=2`.

Com `scroll.index=2`:
- Layout real mostra: items **8–17**
- ensure_visible pensa que mostra: items **4–13**

Agora usuário pressiona `up` a partir do item 9 (visível em row 0 do viewport):
```
navigator: next_idx = 10 - 2 = 8 → childs[8] → child_index = 7
ensure_visible: child_index=7, first_visible=4, last_visible=13
7 está em [4..13] → "already visible" → return SEM AJUSTAR SCROLL
```

Mas no layout com `y_start = -(2*2) = -4`:
```
item 7 → row floor(7/2) = 3
y_actual = -4 + 3 = -1  →  OFF-SCREEN (1 linha acima do container)
```

**Resultado:** foco move para item 7 que está **invisível acima do container**.
O scroll não atualiza porque `ensure_visible` acha que o item já está visível.
O indicador de foco aparece fora da área — "perdido" — e o scroll só muda
quando a próxima ação força um recalculo além do intervalo [4..13]. Exatamente o
comportamento reportado: *"eu já to num item que estaria em outra página, porém o
scroll permanece, só depois ele muda."*

#### Causa raiz

`slide_step` retorna `cols` (para dir='row'), usado em dois lugares com **unidades diferentes**:

| Arquivo | Uso | Unidade esperada | O que acontece |
|---------|-----|-----------------|----------------|
| `layout.lua:87` | `y = -(scroll.index * step)` | linhas | pula `index × cols` linhas |
| `scroll.lua:68` | `first_visible = scroll.index * step` | itens | acha que pula `index × cols` itens |

`index × cols` linhas = `index × cols²` itens (pois cada linha tem `cols` itens).
Mas `ensure_visible` assume `index × cols` itens. **Off by factor `cols`.**

O bug não aparece em `1xN` (cols=1) porque `cols² = cols = 1`.

#### Fix para `layout.lua:83-94`

Separar o cálculo de offset por modo — o acumulador `y/x` deve ser em linhas/colunas,
não em itens:

```lua
if cfg.type == 'slide' then
    local scroll = self.scroll_registry[node]
    if scroll then
        if scroll.mode == 'page' then
            -- page flip: pula scroll.index páginas inteiras
            if dir_val == 'col' then
                x = -(scroll.index * scroll.cols)
            else
                y = -(scroll.index * scroll.rows)
            end
        else
            -- shift: pula 1 linha (ou 1 coluna) por unidade de index
            if dir_val == 'col' then
                x = -scroll.index
            else
                y = -scroll.index
            end
        end
    end
end
```

Verificação após o fix:

| Caso | scroll.index | y_start | Primeiro visível (real) | ensure_visible first_visible | Match? |
|------|-------------|---------|------------------------|------------------------------|--------|
| 2x5 shift, idx=1 | 1 | -1 | items 2,3 (row 1) | 1×2=2 | ✓ |
| 2x5 shift, idx=2 | 2 | -2 | items 4,5 (row 2) | 2×2=4 | ✓ |
| 2x5 page,  idx=1 | 1 | -5 | items 10,11 (row 5) | 1×10=10 | ✓ |
| 1x5 shift, idx=1 | 1 | -1 | item 1 (row 1) | 1×1=1 | ✓ |
| 5x1 shift, idx=1 | 1 | -1 | item 1 (col 1) | 1×1=1 | ✓ |

---

## Problemas Secundários

---

### 1. `ensure_visible` em mode='shift' não alinha ao grid para NxM

**Arquivo:** `scroll.lua:81`
**Gravidade:** Média — comportamento confuso mesmo após o fix principal

Com o fix acima, quando o foco sai do último item visível (ex: item 9 → item 11):

```lua
scroll.index = child_index - visible_count + 1 = 11 - 10 + 1 = 2
-- first_visible = 2 * 2 = 4  →  viewport mostra rows 2–6, não rows 5–9
```

O viewport começa no meio da página anterior. Para grids a sensação natural é page-flip.
Sugestão: default `mode='page'` quando cols > 1 e rows > 1.

---

### 2. Offset de layout sem clipping

**Arquivo:** `layout.lua:87-93`
**Gravidade:** Média — itens off-screen podem aparecer fora do bounds do slide

Com o fix acima aplicado, itens antes do scroll ficam com y negativo (acima do parent).
Se a engine de renderização não faz scissoring no bounds do container `slide`,
esses itens aparecem sobrepostos ao conteúdo acima do slide.

---

### 3. Wrap lateral indesejado em `dir='row'`

**Arquivo:** `navigator.lua:199`
**Gravidade:** Média — comportamento confuso ao navegar

Para `2x5` (dir='row'), apertar `right` no último item de uma linha move para o
primeiro item da linha seguinte (trata o array como lista linear):

```lua
if direction == 'right' then next_idx = idx + 1  -- sem checagem de limite de coluna
```

Fix: checar boundary de coluna:
```lua
local current_col = (idx - 1) % cols
if direction == 'right' and current_col == cols - 1 then return nil end
if direction == 'left'  and current_col == 0         then return nil end
```

---

### 4. `left`/`right` não travados em slides de scroll vertical

**Arquivo:** `navigator.lua:198-203`
**Gravidade:** Baixa-Média

Em `dir='row'` (scroll vertical), left/right ainda navigam lateralmente dentro da linha.
Para um slide vertical (`2x5`), o eixo "livre" deveria ser só vertical. O fix do ponto 3
(boundary de coluna) resolveria parcialmente isso: left/right param na borda da coluna,
não circulam para a próxima linha.

---

### 5. `scroll_register` chamado duas vezes no JSX

**Arquivo:** `jsx.lua:80` chama `std.ui.slide()` que internamente chama `scroll_register` em `slide.lua:50`, depois `jsx.lua:85` chama `scroll_register` novamente.
**Gravidade:** Baixa — redundante, o segundo sobrescreve o primeiro corretamente.

---

### 6. `ensure_visible` só ajusta o slide mais próximo

**Arquivo:** `navigator.lua:100-104`
**Gravidade:** Baixa-Média — bug em slides aninhados

Só chama `ensure_visible` no ancestral slide mais próximo. Se houver slides aninhados,
o slide externo não é ajustado se o interno estiver fora de vista.

---

## Resumo

| # | Problema | Arquivo | Gravidade |
|---|----------|---------|-----------|
| ROOT | `layout.lua` usa step em linhas, `ensure_visible` em itens | `layout.lua:87` | **Crítica** |
| 1 | `ensure_visible` shift não alinha ao grid em NxM | `scroll.lua:81` | Média |
| 2 | Offset sem clipping — itens off-screen visíveis | `layout.lua:87` | Média |
| 3 | Wrap lateral: `right` na col 1 pula para próxima linha | `navigator.lua:199` | Média |
| 4 | left/right não travados em slide vertical | `navigator.lua:198` | Baixa-Média |
| 5 | `scroll_register` chamado duas vezes no JSX | `jsx.lua:85` | Baixa |
| 6 | `ensure_visible` não ajusta slides ancestrais | `navigator.lua:101` | Baixa-Média |

## Sugestão arquitetural: defaults por forma

```
1xN  → dir='row', mode='shift'   (lista vertical — shift de 1 item por vez)
Nx1  → dir='col', mode='shift'   (lista horizontal — shift de 1 item por vez)
NxM  → dir='row', mode='page'    (grade — vira página inteira, sem sobreposição)
```

`mode='page'` com o fix no layout resolve os problemas ROOT, 1 e 4 de uma vez para grids.
