# GlyEngine DOM v2 — Specification

## Overview

This is a pure Lua DOM engine for extremely constrained hardware (TV boxes, retro consoles, embedded systems). The DOM is computed rarely and compiled into a flat render list that is iterated every frame. There is no clipping/scissor — elements outside the screen are simply positioned off-screen with negative or overflow coordinates.

The engine powers a JSX transpiler (TypeScript → Lua) where frontend developers write declarative UI and the engine handles layout, scroll, and focus navigation for TV remote controls.

## Architecture

### File Structure

#### CREATE — `source/engine/browser/` (todos novos)

```
source/engine/browser/
├── dom.lua          -- substitui tree.lua: node_begin/add/del/pause/resume, walk, dom(),
│                    --   bus(), resize(), rebuild_list/tree, compile(), flush_dirty(),
│                    --   mark_dirty(), uid_counter, index_uid/id/class, parse_span
├── stylesheet.lua   -- extraído + estendido: parse_unit, resolve, stylesheet(),
│                    --   css_add(), css_del(), css_scroll()
├── scroll.lua       -- novo: scroll_registry, scroll_register(), slide_step(),
│                    --   ensure_visible()
├── navigator.lua    -- novo: set_focus(), focus_navigate(), focus_navigate_spatial(),
│                    --   focus_navigate_slide(), find_slide_parent(), find_focus_group(),
│                    --   is_same_group(), is_descendant(), find_focusable()
├── query.lua        -- novo: queryOne(), query(), wrap() (métodos encadeáveis)
├── jsx.lua          -- MOVIDO de ui/jsx.lua + reescrito como closure via create_h();
│                    --   instala std.h; pode utilizar ui.lua para elementos grid/slide/style
└── ui.lua           -- novo: install(std, engine) instala std.ui.*:
                     --   std.ui.grid, slide, style      ← componentes de layout
                     --   std.ui.focus, press, isFocused ← navegação/foco
                     --   std.ui.queryOne, query         ← seletores
```

Responsabilidades claras:
- `ui.lua`  → resolve `std.ui.*()` (todos os métodos do namespace ui)
- `jsx.lua` → resolve `std.h()` (factory JSX); pode requerer `ui.lua` para delegar
             elementos como `grid`, `slide`, `style` sem duplicar lógica

Ordem de dependência dentro de browser/ (sem require circular):
```
stylesheet.lua
      ↑
   dom.lua ← scroll.lua ← navigator.lua
      ↑                         ↑
   query.lua ───────────────────┘
      ↑
   ui.lua
      ↑
   jsx.lua
```

#### DELETE — código morto

```
source/shared/engine/tree.lua        ← DELETAR após browser/dom.lua +
                                       browser/stylesheet.lua absorverem toda a lógica.
                                       Requerido por 6 arquivos (ver UPDATE abaixo).

source/engine/api/draw/ui/jsx.lua    ← DELETAR após mover lógica para browser/jsx.lua.
```

#### REWRITE — mesmo caminho, conteúdo completamente novo

```
source/engine/api/draw/ui/slide.lua  -- novo std.ui.slide() espelhando a API de grid.lua,
                                     -- integra com browser/scroll + browser/dom.
                                     -- Remove: :next(), :back(), :apply(), classlist_selected.
```

#### UPDATE — mudanças de require + migrações de lógica

```
source/engine/core/vacuum/native/main.lua
  - local tree = require('source/shared/engine/tree')
  + local dom  = require('source/engine/browser/dom')
  - engine.dom = tree.node_begin(...)
  + engine.dom = dom.node_begin(...)

source/engine/core/bind/love/main.lua
  mesma mudança acima

source/engine/api/raw/node.lua
  - local tree = require('source/shared/engine/tree')
  + local dom  = require('source/engine/browser/dom')
  - tree.node_add / node_del / node_pause / node_resume / bus
  + dom.node_add  / node_del / node_pause / node_resume / bus
  - engine.offset_x = node.config.offset_x
  + engine.offset_x = node.layout.x
  - engine.offset_y = node.config.offset_y
  + engine.offset_y = node.layout.y

source/engine/api/draw/ui/common.lua
  - local tree = require('source/shared/engine/tree')
  + local dom  = require('source/engine/browser/dom')
  - tree.node_add → dom.node_add

source/engine/api/draw/ui/grid.lua
  - local tree = require('source/shared/engine/tree')
  + local dom  = require('source/engine/browser/dom')
  - tree.node_add → dom.node_add
  + migrar dir auto-detect de 0/1 para 'row'/'col' (§11)

source/engine/api/draw/ui/style.lua
  - local tree = require('source/shared/engine/tree')
  + local ss   = require('source/engine/browser/stylesheet')
  - tree.css_add / tree.css_del / tree.stylesheet
  + ss.css_add   / ss.css_del   / ss.stylesheet

source/engine/api/draw/ui.lua          ← passa a ser apenas o ponto de entrada
  - local ui_jsx   = require('source/engine/api/draw/ui/jsx')
  - local ui_grid  = require('source/engine/api/draw/ui/grid')
  - local ui_slide = require('source/engine/api/draw/ui/slide')
  - local ui_style = require('source/engine/api/draw/ui/style')
  + local browser_ui  = require('source/engine/browser/ui')
  + local browser_jsx = require('source/engine/browser/jsx')
  dentro de install():
  - (toda a instalação manual de std.h, std.ui.grid, etc.)
  + browser_ui.install(std, engine)    -- instala std.ui.*
  + browser_jsx.install(std, engine)   -- instala std.h
```

#### UNCHANGED — sem modificações

```
source/shared/engine/loadcore.lua
source/shared/engine/loadgame.lua
source/engine/api/draw/ui/common.lua   (apenas mudança de require acima)
source/engine/api/raw/bus.lua
source/engine/api/raw/memory.lua
```

`engine.dom` é inicializado em `source/engine/core/vacuum/native/main.lua`:
```lua
-- atual:
engine.dom = tree.node_begin(application, std.app.width, std.app.height)
-- após migração:
engine.dom = dom.node_begin(application, std.app.width, std.app.height)
```

Dependências fluem em uma direção: `jsx` → `ui` → `navigator` + `query` → `dom` → `stylesheet`. Sem circular requires.

### Node Structure

Each node has three conceptual areas. Current code mixes `data` and `config`. Clarify separation:

> **draw callback convention:** `draw(self, std)` where `self` is `node.data`. Developers read
> `self.width` and `self.height` inside draw. Therefore `node.data.width` / `node.data.height`
> **must remain** as the resolved pixel dimensions after layout. `node.layout` is the engine's
> internal computed output and should not replace `data.width`/`data.height` as the dev-facing API.

```lua
node = {
    data = {},       -- user-defined: draw function, custom attributes, content
                     -- ALSO holds: data.width, data.height (resolved layout, read by draw callback)
    config = {       -- engine input: parent, css list, type, id, class, pause state
        uid = nil,       -- number: internal incremental ID
        id = nil,        -- string: user-defined ID for queryOne('#id')
        class = nil,     -- table: list of class names for query('.class')
        parent = nil,    -- node: parent reference
        type = nil,      -- string: 'root' | 'grid' | 'slide'
        css = {},        -- table: list of css transform functions
        pause_key = {},
        pause_all = false,
        focusable = false,
        on_focus = nil,
        on_blur = nil,
        on_press = nil,
        visible = true,
        layer = 0,       -- reserved, not implemented yet
        -- grid/slide specific:
        cols = nil,
        rows = nil,
        dir = nil,       -- 'row' | 'col'
        scroll_mode = nil, -- 'shift' | 'page'
        focus_mode = nil,  -- 'wrap' | 'stop' | 'escape'
        size = 1,        -- span (number for 1D, or {x,y} for 2D in grid)
        after = 0,
        offset = 0,
        -- style state:
        style_names = {},     -- list of applied style class names
        style_focus = {},     -- map: style_name → focus variant function
    },
    layout = {       -- engine output: computed by dom(), read by render
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        dirty = false,
    },
    childs = nil,    -- table or nil
}
```

> **Note**: The separation into `data`/`config`/`layout` is the ideal structure. If keeping backward compatibility is preferred, at minimum move computed position out of `config` — currently `config.offset_x`/`config.offset_y` are output values stored alongside input values.

---

## Bugfixes (apply to current code)

### BUG 1: `has_right` checks wrong field

In `stylesheet()`, line with `has_right`:

```lua
-- BEFORE (bug):
local css_right, has_right = css.right or 0, css.left ~= nil

-- AFTER (fix):
local css_right, has_right = css.right or 0, css.right ~= nil
```

### BUG 2: `cells()` has cols/rows inverted

**Class string convention: `ROWSxCOLS`** — the first number is rows (vertical count), the second is cols (horizontal count).
Examples: `'3x2'` = 3 rows, 2 columns. `'1x5'` = 1 row, 5 columns. `'5x1'` = 5 rows, 1 column.

The parser in `grid.lua` is correct — first capture → `node.config.rows`, second → `node.config.cols`.
The bug is in `cells()` which then uses them with width/height swapped:

```lua
-- BEFORE (bug):
local function cells(node)
    local cfg = node.config
    local dat = node.data
    if cfg.type == 'grid' then
        local cols, rows = cfg.cols, cfg.rows
        local w = dat.width / rows    -- wrong: divides width by rows
        local h = dat.height / cols   -- wrong: divides height by cols
        return w, h
    end
    return dat.width, dat.height
end

-- AFTER (correct):
-- rows = number of rows (vertical divisions) → divides height
-- cols = number of columns (horizontal divisions) → divides width
local function cells(node)
    local cfg = node.config
    local dat = node.data
    if cfg.type == 'grid' or cfg.type == 'slide' then
        local w = dat.width / cfg.cols
        local h = dat.height / cfg.rows
        return w, h
    end
    return dat.width, dat.height
end
```

---

## Feature Specs

### 1. UID Internal Incremental

Every node gets a unique numeric ID on creation. Used internally for O(1) lookup. Never exposed to the developer API.

```lua
local uid_counter = 0

-- in node_add:
uid_counter = uid_counter + 1
node.config.uid = uid_counter
self.index_uid[uid_counter] = node
```

### 2. ID/Class Index

Maintain hash maps for O(1) query lookup.

```lua
-- state in engine self:
self.index_id = {}      -- string → node
self.index_class = {}   -- string → {node, node, ...}

-- on node_add, if options.id:
self.index_id[options.id] = node

-- on node_add, if options.class (table of strings):
for _, name in ipairs(options.class) do
    if not self.index_class[name] then
        self.index_class[name] = {}
    end
    local list = self.index_class[name]
    list[#list + 1] = node
end

-- on node_del: clean up both indexes
```

### 3. Units: px and %

Parse CSS values that can be number (= px), `"Npx"` string, or `"N%"` string.

```lua
--- @param value number|string
--- @return table {value: number, unit: 'px'|'pct'}
local function parse_unit(value)
    if type(value) == 'number' then
        return { value = value, unit = 'px' }
    end
    local num, unit = value:match('^([%d%.%-]+)(%%?p?x?)$')
    num = tonumber(num)
    if unit == '%' then
        return { value = num / 100, unit = 'pct' }
    end
    return { value = num, unit = 'px' }
end

--- @param parsed table from parse_unit
--- @param parent_size number the parent dimension to resolve % against
--- @return number resolved pixel value
local function resolve(parsed, parent_size)
    if parsed.unit == 'pct' then
        return parsed.value * parent_size
    end
    return parsed.value
end
```

### 4. Units: vw/vh

Viewport units resolve at parse time (screen size rarely changes). On `resize()`, invalidate all stylesheets containing vw/vh and re-parse.

```lua
local function parse_unit(value, screen_w, screen_h)
    -- ... existing px/% logic ...
    if unit == 'vw' then
        return { value = (num / 100) * screen_w, unit = 'px' }
    elseif unit == 'vh' then
        return { value = (num / 100) * screen_h, unit = 'px' }
    end
end
```

### 5. Stylesheet with Units

The `stylesheet()` function parses units once on creation, generates a closure that resolves `%` at layout time. The closure signature remains `function(x, y, w, h) → x, y, w, h`.

**Closure identity / implicit names:** Each unique set of options produces a distinct closure. The closure key (used internally) is the options table serialized with keys in **alphabetical order**:
```lua
-- options {width=500, height=100, top=0}  →  key = "height=100top=0width=500"
```
This same key is used for anonymous style names in JSX (see §7). When `stylesheet()` is called with the same options, it MUST return the same closure (lookup by key). When called with different options, a new closure is created.

Anchor logic (already correct in original, just fix the bug):
- `width` set + `left` + `right` → center between margins
- `width` set + `left` only → anchor left
- `width` set + `right` only → anchor right
- `width` set + neither → center in full space
- Same logic applies vertically with `height`/`top`/`bottom`

```lua
--- @param self engine
--- @param name string class name
--- @param options table|nil {left,right,top,bottom,margin,width,height} values can be number|string
--- @return function css transform function
local function stylesheet(self, name, options)
```

### 6. Style :focus

Each style class can have a `:focus` variant defined separately. When a node gains focus, its base styles are swapped for the `:focus` variants automatically.

**Definition:**
```jsx
<style class='card' width={400} margin={8} />
<style class='card:focus' width={500} margin={4} />
```

**Storage:**
```lua
-- style_name → css function
self.stylesheet_func['card'] = build_css(base_options)
self.stylesheet_func['card:focus'] = build_css(focus_options)
```

**Application in add_style:**
```lua
local function add_style(std, node, stylesheet_name)
    local base_func = self.stylesheet_func[stylesheet_name]
    css_add(self, base_func, node)
    node.config.style_names[#node.config.style_names + 1] = stylesheet_name
    
    -- check for :focus variant
    local focus_name = stylesheet_name .. ':focus'
    if self.stylesheet_func[focus_name] then
        node.config.style_focus[stylesheet_name] = self.stylesheet_func[focus_name]
    end
end
```

**Swap on focus change (in set_focus):**
```lua
local function set_focus(self, node)
    local old = self.focus_current
    if old == node then return end
    
    -- remove :focus styles from old
    if old then
        for name, focus_func in pairs(old.config.style_focus) do
            css_del(self, focus_func, old)
            css_add(self, self.stylesheet_func[name], old)
        end
        if old.config.on_blur then old.config.on_blur() end
    end
    
    self.focus_current = node
    
    -- apply :focus styles to new
    for name, focus_func in pairs(node.config.style_focus) do
        css_del(self, self.stylesheet_func[name], node)
        css_add(self, focus_func, node)
    end
    if node.config.on_focus then node.config.on_focus() end
    
    -- slide follow
    local slide = find_slide_parent(self, node)
    if slide then ensure_visible(self, slide, node) end
    
    self.flag_reposition = true
end
```

### 7. Anonymous Style

`<style>` wrapping a `<node>` applies the style directly to that node without needing a class name.

```jsx
<style width='50%' height={200}>
    <node draw={(w, h) => { ... }} />
</style>
```

**Implicit name generation:** When `class` is absent, serialize the attributes in **alphabetical key order** to produce a stable implicit name:
```
{width='50%', height=200}  →  "height=200width=50%"
```
This implicit name is used as the stylesheet key, so the same anonymous style block always reuses the same closure.

In the `h()` factory, when `element == 'style'`:
```lua
elseif element == 'style' then
    local name = attribute.class
    if not name then
        -- build implicit name from sorted keys
        local keys = {}
        for k in pairs(attribute) do keys[#keys+1] = k end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts+1] = k..'='..tostring(attribute[k]) end
        name = table.concat(parts)
    end
    if childs and #childs > 0 then
        -- anonymous: register and apply directly to child node
        local style_obj = std.ui.style(name, attribute)
        local child = childs[1]
        local target = child.node or child
        style_obj:add(target)
        return child
    else
        -- named: register in stylesheet dict only
        return std.ui.style(name, attribute)
    end
```

### 8. css_scroll

A CSS transform function that offsets children by scroll amount. Applied at render time, not DOM time. The scroll state is external.

```lua
--- @param scroll_state table {offset_x: number, offset_y: number}
--- @return function css transform
local function css_scroll(scroll_state)
    return function(x, y, w, h)
        return x - (scroll_state.offset_x or 0), y - (scroll_state.offset_y or 0), w, h
    end
end
```

### 9. Dirty Tracking Granular

Replace global `flag_reposition` with per-node dirty marking. Only recompute layout for dirty subtrees.

```lua
--- Mark a node and its ancestors as dirty
--- @param node table
local function mark_dirty(node)
    while node do
        if node.layout.dirty then break end  -- ancestors already marked
        node.layout.dirty = true
        node = node.config.parent
    end
end

--- Flush dirty nodes: recompute only dirty subtrees
--- @param self engine
local function flush_dirty(self)
    if self.root.layout.dirty then
        -- root dirty = full recompute (same as before)
        dom(self.root, 0, 0, self.width, self.height)
        walk(self.root, function(n) n.layout.dirty = false end)
    else
        -- partial: find top-level dirty nodes and recompute subtrees
        for i = 1, #self.dirty_queue do
            local node = self.dirty_queue[i]
            if node.layout.dirty then
                dom(node, node.layout.x, node.layout.y, node.layout.width, node.layout.height)
                walk(node, function(n) n.layout.dirty = false end)
            end
        end
    end
    self.dirty_queue = {}
end
```

Use `mark_dirty(node)` instead of `self.flag_reposition = true` in: `css_add`, `css_del`, `stylesheet` (when options change), `node_add`, `resize`.

`resize` still marks root dirty (full recompute).

### 10. Render List (compile)

After layout computation, compile the node tree into a flat ordered list for the render loop. Reuse table entries to avoid GC pressure.

```lua
--- Compile DOM into flat render list with culling
--- @param self engine
local function compile(self)
    local list = self.render_list or {}
    local index = 0
    local sw, sh = self.width, self.height
    
    for i = 1, #self.node_list do
        local node = self.node_list[i]
        local cfg = node.config
        local layout = node.layout
        
        -- culling: skip nodes outside screen bounds
        local visible = cfg.visible ~= false
            and layout.x + layout.width > 0
            and layout.x < sw
            and layout.y + layout.height > 0
            and layout.y < sh
        
        if visible then
            index = index + 1
            local entry = list[index]
            if not entry then
                entry = {}
                list[index] = entry
            end
            entry.uid = cfg.uid
            entry.x = layout.x
            entry.y = layout.y
            entry.w = layout.width
            entry.h = layout.height
            entry.node = node
        end
    end
    
    -- clean leftover entries from previous frame
    for i = index + 1, #list do
        list[i] = nil
    end
    
    self.render_list = list
end
```

### 11. dir = 'row' | 'col'

Replace numeric `dir` (0/1) with string names.

- `'row'` — fill horizontally first (left to right, then next row). Equivalent to old `dir=0`.
- `'col'` — fill vertically first (top to bottom, then next column). Equivalent to old `dir=1`.

**Auto-detect in `grid.lua` (keep existing logic, migrate to strings):**
```lua
-- ROWSxCOLS format: '1x5' = 1 row, 5 cols; '5x1' = 5 rows, 1 col
if node.config.rows == 1 and node.config.cols > 1 then
    node.config.dir = 'col'   -- was: 1
elseif node.config.cols == 1 and node.config.rows > 1 then
    node.config.dir = 'row'   -- was: 0 (default anyway)
else
    node.config.dir = 'row'   -- NxN default
end
```
Explicit `dir` attribute in JSX/API overrides the auto-detect.

In JSX: `<grid class='3x3' dir='row'>` or `<slide class='1x5' dir='col'>`

In DOM layout calc, replace `dir == 0` with `dir == 'row'` and `dir == 1` with `dir == 'col'`.

### 12. span 2D in Grid

Grid elements support `span='2x2'` for multi-cell items. Slide does NOT support 2D span (error if attempted).

```lua
--- @param span number|string  e.g. 1, 2, '2x2', '1x3'
--- @return number span_cols, number span_rows
local function parse_span(span)
    if type(span) == 'number' then
        return span, 1
    end
    local c, r = span:match('^(%d+)x(%d+)$')
    return tonumber(c) or 1, tonumber(r) or 1
end
```

In DOM grid layout, use both span dimensions:
```lua
local span_x, span_y = parse_span(child.config.size)
local w = (dir == 'row') and (span_x * cell_w) or (span_x * cell_w)
local h = (dir == 'col') and (span_y * cell_h) or (span_y * cell_h)

-- advance position respecting 2D span:
if dir == 'col' then
    y = y + span_y + offset + after
    if y >= rows then y = 0; x = x + span_x end
else
    x = x + span_x + offset + after
    if x >= cols then x = 0; y = y + span_y end
end
```

In slide `h()` factory, validate:
```lua
if item.span and type(item.span) == 'string' then
    error('[error] slide does not support 2D span, use number')
end
```

### 13. `<slide>` Element

A grid that supports scrolling. Separated from `<grid>` for explicit semantics. The `class` defines the **visible window** (e.g. `'1x5'` = 1 row, 5 cols visible at a time).

**`slide.lua` is a complete rewrite.** The old `slide.lua` (with `:next()`, `:back()`, `:apply()`, `classlist_selected`) is dead code and must be replaced. The new `std.ui.slide()` API mirrors `std.ui.grid()` — same `:add()`, `:add_items()`, `:dir()` interface — the scroll behavior is handled internally by the scroll registry and DOM layout, not by imperative methods.

**Props:**
```typescript
slide: {
    class: string,             // 'COLSxROWS' visible window
    id?: string,
    span?: number,
    offset?: number,
    after?: number,
    style?: string,
    dir?: 'row' | 'col',      // fill direction; scroll is perpendicular
    scroll?: 'shift' | 'page', // shift=1 row/col at a time, page=full window
    focus?: 'wrap' | 'stop' | 'escape',
    children?: JSX.Element | Array<JSX.Element>
}
```

**Scroll registry:**
```lua
-- state in engine self:
self.scroll_registry = {}  -- node → scroll_state

-- scroll_state:
{
    mode = 'shift',     -- 'shift' | 'page'
    index = 0,          -- current scroll position (in steps)
    total = 0,          -- total number of child items
    cols = 5,           -- from class
    rows = 1,           -- from class
    dir = 'col',        -- fill direction
}
```

**Step calculation:**
```lua
--- @param scroll table scroll_state
--- @return number items to skip per scroll step
local function slide_step(scroll)
    if scroll.mode == 'page' then
        return scroll.cols * scroll.rows
    else
        -- shift: one row or column depending on fill direction
        if scroll.dir == 'row' then
            return scroll.cols   -- one horizontal row
        else
            return scroll.rows   -- one vertical column
        end
    end
end
```

**Offset in DOM layout:**

The slide is a grid where the child list starts at an offset. Children before the offset are positioned off-screen (negative coords). Children after `offset + visible_count` are positioned beyond screen bounds. Culling in render list handles the rest.

```lua
-- in dom() for type == 'slide':
local scroll = self.scroll_registry[node]
local items_offset = scroll.index * slide_step(scroll)

-- skip to the offset child, positioning accumulator starts accordingly
-- children before offset get negative positions (off-screen left/top)
-- children after visible window get overflow positions (off-screen right/bottom)
```

**h() factory:**
```lua
elseif element == 'slide' then
    local index = 1
    local grid = std.ui.grid(attribute.class):dir(attribute.dir)
    grid.node.config.type = 'slide'
    if attribute.style then add_style(std, grid.node, attribute.style) end
    
    local scroll_id = attribute.id
    std.ui.scroll_register(scroll_id, grid.node, {
        mode = attribute.scroll or 'shift',
        focus = attribute.focus,
    })
    
    while index <= #childs do
        local item = childs[index]
        -- validate: no 2D span in slide
        if item.span and type(item.span) == 'string' then
            error('[error] slide does not support 2D span')
        end
        if item.node then
            grid:add(item.node, {span=item.span, offset=item.offset, after=item.after})
            if item.style then add_style(std, grid:get_item(index), item.style) end
        else
            grid:add(item)
        end
        index = index + 1
    end
    grid.span = attribute.span
    grid.after = attribute.after
    grid.offset = attribute.offset
    return grid
```

### 14. Focusable Implicit

Nodes with `onPress`, `onFocus`, or `onBlur` are automatically focusable. Explicit `focusable={false}` overrides.

```lua
-- in node_add:
local has_handler = options.onFocus or options.onBlur or options.onPress
local focusable = options.focusable
if focusable == nil then
    focusable = has_handler ~= nil
end

if focusable then
    node.config.focusable = true
    node.config.on_focus = options.onFocus
    node.config.on_blur = options.onBlur
    node.config.on_press = options.onPress
    self.focus_list[#self.focus_list + 1] = node
    
    if not self.focus_current then
        self.focus_current = node
        if node.config.on_focus then node.config.on_focus() end
    end
end
```

### 15. Focus Modes: wrap / stop / escape

Applied to container nodes (grid, slide). Controls what happens when focus navigation reaches the boundary.

- **wrap**: focus jumps to the opposite end of the container
- **stop**: focus stays on the last/first item (nothing happens)
- **escape**: focus leaves the container and spatial navigation takes over to find the next focusable node outside

### 16. Spatial Navigation (scoring)

For nodes NOT inside a slide, use position-based scoring to find the best candidate in the pressed direction.

```lua
--- @param self engine
--- @param direction string 'up'|'down'|'left'|'right'
local function focus_navigate_spatial(self, current, direction)
    local cx = current.layout.x + current.layout.width / 2
    local cy = current.layout.y + current.layout.height / 2
    
    local best_node = nil
    local best_score = math.huge
    
    for i = 1, #self.focus_list do
        local candidate = self.focus_list[i]
        if candidate ~= current 
           and candidate.config.visible ~= false
           and candidate.config.focusable then
            
            local px = candidate.layout.x + candidate.layout.width / 2
            local py = candidate.layout.y + candidate.layout.height / 2
            local dx, dy = px - cx, py - cy
            
            local valid, score = false, 0
            if direction == 'right' and dx > 0 then
                valid = true; score = dx + math.abs(dy) * 3
            elseif direction == 'left' and dx < 0 then
                valid = true; score = -dx + math.abs(dy) * 3
            elseif direction == 'down' and dy > 0 then
                valid = true; score = dy + math.abs(dx) * 3
            elseif direction == 'up' and dy < 0 then
                valid = true; score = -dy + math.abs(dx) * 3
            end
            
            -- check if blocked by container focus mode
            if valid then
                local group = find_focus_group(self, current)
                if group and not is_same_group(group, candidate) then
                    if group.config.focus_mode == 'stop' then
                        valid = false
                    end
                end
            end
            
            if valid and score < best_score then
                best_score = score
                best_node = candidate
            end
        end
    end
    
    if best_node then set_focus(self, best_node) end
end
```

The multiplier `3` on the perpendicular axis penalizes candidates that are in the right direction but misaligned.

### 17. Index Navigation (inside slide)

Inside a slide, navigation uses logical child index instead of spatial position (because off-screen items have unusable positions).

```lua
--- @param self engine
--- @param slide_node table the slide container
--- @param current table current focused node
--- @param direction string 'up'|'down'|'left'|'right'
--- @return table|nil next focusable node, or nil if at boundary
local function focus_navigate_slide(self, slide_node, current, direction)
    local cfg = slide_node.config
    local childs = slide_node.childs
    local cols, rows = cfg.cols, cfg.rows
    local dir = cfg.dir
    
    -- find current child index
    local idx = 0
    for i, child in ipairs(childs) do
        if child == current or is_descendant(child, current) then
            idx = i; break
        end
    end
    if idx == 0 then return nil end
    
    local next_idx = idx
    local total = #childs
    
    if dir == 'col' then
        if direction == 'down' then next_idx = idx + 1
        elseif direction == 'up' then next_idx = idx - 1
        elseif direction == 'right' then next_idx = idx + rows
        elseif direction == 'left' then next_idx = idx - rows end
    else -- 'row'
        if direction == 'right' then next_idx = idx + 1
        elseif direction == 'left' then next_idx = idx - 1
        elseif direction == 'down' then next_idx = idx + cols
        elseif direction == 'up' then next_idx = idx - cols end
    end
    
    if cfg.focus_mode == 'wrap' then
        if next_idx < 1 then next_idx = total end
        if next_idx > total then next_idx = 1 end
    end
    
    if next_idx < 1 or next_idx > total then return nil end
    return find_focusable(childs[next_idx])
end
```

**Top-level navigation dispatch:**
```lua
local function focus_navigate(self, direction)
    local current = self.focus_current
    if not current then return end
    
    local slide = find_slide_parent(self, current)
    if slide then
        local next = focus_navigate_slide(self, slide, current, direction)
        if next then
            set_focus(self, next)
            return
        end
        if slide.config.focus_mode == 'escape' then
            focus_navigate_spatial(self, current, direction)
        end
        return
    end
    
    focus_navigate_spatial(self, current, direction)
end
```

### 18. Slide Follows Focus

When focus moves to an item outside the visible window, the slide auto-scrolls.

```lua
--- @param self engine
--- @param slide_node table
--- @param focus_node table the newly focused node
local function ensure_visible(self, slide_node, focus_node)
    local scroll = self.scroll_registry[slide_node]
    local childs = slide_node.childs
    
    local child_index = 0
    for i, child in ipairs(childs) do
        if child == focus_node or is_descendant(child, focus_node) then
            child_index = i - 1  -- 0-based
            break
        end
    end
    
    local step = slide_step(scroll)
    local visible_count = scroll.cols * scroll.rows
    local first_visible = scroll.index * step
    local last_visible = first_visible + visible_count - 1
    
    if child_index < first_visible then
        if scroll.mode == 'page' then
            scroll.index = math.floor(child_index / step)
        else
            scroll.index = child_index
        end
    elseif child_index > last_visible then
        if scroll.mode == 'page' then
            scroll.index = math.floor(child_index / step)
        else
            scroll.index = child_index - visible_count + 1
        end
    end
    
    mark_dirty(slide_node)
end
```

### 19. Browser UI — `source/engine/browser/ui.lua`

`ui.lua` é o ponto central que instala todo o namespace `std.ui`. Reúne componentes de layout
(grid, slide, style) e as funções de navegação/query. Aceita node direto ou query selector,
delegando para navigator/query/dom — sem lógica de layout própria.

```lua
-- source/engine/browser/ui.lua
local function install(std, engine)
    std.ui = std.ui or {}
    -- componentes de layout (delegam para ui/grid.lua, ui/slide.lua, ui/style.lua)
    std.ui.grid      = ...   -- §grid
    std.ui.slide     = ...   -- §13
    std.ui.style     = ...   -- §5
    -- navegação e foco
    std.ui.focus     = ...   -- §20
    std.ui.press     = ...   -- §21
    std.ui.isFocused = ...   -- §22
    -- seletores
    std.ui.queryOne  = ...   -- §23
    std.ui.query     = ...   -- §23
end
```

`jsx.lua` instala `std.h` separadamente e pode requerer `ui.lua` para delegar a criação
de elementos `grid`, `slide`, `style` sem duplicar lógica:
```lua
-- source/engine/browser/jsx.lua
local ui = require('source/engine/browser/ui')
local function install(std, engine)
    std.h = create_h(std, engine)  -- closure, std/engine como upvalues
end
```

### 20. std.ui.focus() — Polymorphic

Single function handles all focus operations.

```lua
--- @param target nil|string|table
---   nil         → focus current node (from bus context)
---   'up'|'down'|'left'|'right' → navigate direction
---   '#someid'   → focus node by id
---   node table  → focus directly
function std.ui.focus(target)
    if not target then
        target = self.current_node
    elseif type(target) == 'string' then
        if target == 'right' or target == 'left'
        or target == 'up' or target == 'down' then
            focus_navigate(self, target)
            return
        end
        if target:sub(1, 1) == '#' then
            target = self.index_id[target:sub(2)]
        end
    end
    if target then
        set_focus(self, target)
    end
end
```

**Bus context** — during bus iteration, `self.current_node` is set to the node being processed, so `std.ui.focus()` with no args knows who called it:

```lua
-- in bus:
self.current_node = node
handler_func(node)
self.current_node = nil
```

### 21. std.ui.press()

```lua
function std.ui.press()
    local node = self.focus_current
    if node and node.config.on_press then
        self.current_node = node
        node.config.on_press()
        self.current_node = nil
    end
end
```

### 22. std.ui.isFocused()

```lua
--- @param target table|nil  node to check, or nil for current bus context
--- @return boolean
function std.ui.isFocused(target)
    if not target then
        target = self.current_node
    end
    return self.focus_current == target
end
```

### 23. queryOne / query

```lua
--- @param selector string  '#id' or '.class'
--- @return table|nil wrapped node with chainable methods
function std.ui.queryOne(selector)
    local prefix = selector:sub(1, 1)
    local name = selector:sub(2)
    
    local node
    if prefix == '#' then
        node = self.index_id[name]
    elseif prefix == '.' then
        local list = self.index_class[name]
        node = list and list[1]
    end
    
    if not node then return nil end
    return wrap(self, node)
end

--- @param selector string  '.class'
--- @return table list of wrapped nodes
function std.ui.query(selector)
    local prefix = selector:sub(1, 1)
    local name = selector:sub(2)
    
    if prefix == '.' then
        local list = self.index_class[name] or {}
        local result = {}
        for i = 1, #list do
            result[i] = wrap(self, list[i])
        end
        return result
    end
    
    local node = std.ui.queryOne(selector)
    return node and { node } or {}
end
```

### 24. wrap() — Chainable Methods

```lua
--- @param self engine
--- @param node table
--- @return table object with chainable methods
local function wrap(self, node)
    local w = {}
    
    w.setScroll = function(value)
        local scroll = self.scroll_registry[node]
        if not scroll then return w end
        if value == 'end' then
            scroll.index = math.max(0, scroll.total - scroll.cols * scroll.rows)
        elseif type(value) == 'string' and value:sub(1,1) == '+' then
            scroll.index = scroll.index + tonumber(value:sub(2))
        elseif type(value) == 'string' and value:sub(1,1) == '-' then
            scroll.index = scroll.index - tonumber(value:sub(2))
        else
            scroll.index = value
        end
        scroll.index = math.max(0, math.min(scroll.index, scroll.total - 1))
        mark_dirty(node)
        return w
    end
    
    w.getScroll = function()
        local scroll = self.scroll_registry[node]
        if not scroll then return nil end
        local visible_count = scroll.cols * scroll.rows
        return {
            index = scroll.index,
            progress = scroll.index / math.max(1, scroll.total - visible_count),
            visible = { scroll.index, scroll.index + visible_count - 1 }
        }
    end
    
    w.focus = function(index)
        if not index then
            set_focus(self, node)
        elseif type(index) == 'number' then
            local child = node.childs and node.childs[index]
            if child then
                local focusable = find_focusable(child)
                if focusable then set_focus(self, focusable) end
            end
        end
        return w
    end
    
    w.count = function()
        return node.childs and #node.childs or 0
    end
    
    w.addStyle = function(name)
        local func = stylesheet(self, name)
        css_add(self, func, node)
        return w
    end
    
    w.delStyle = function(name)
        local func = self.stylesheet_func[name]
        if func then css_del(self, func, node) end
        return w
    end
    
    w.setAttr = function(key, value)
        node.data[key] = value
        return w
    end
    
    w.getAttr = function(key)
        return node.data[key]
    end
    
    w.isVisible = function()
        return node.config.visible ~= false
    end
    
    return w
end
```

### 25. h() as Closure

Reduce stack overhead by capturing `std`/`engine` in closure instead of passing every call.

```lua
--- @param std table
--- @param engine table
--- @return function h(element, attribute, childs)
local function create_h(std, engine)
    local function h(element, attribute, childs)
        -- same body as current h(), but std/engine are upvalues
        -- saves 2 stack pushes per h() call
    end
    return h
end
```

### 26. node_pause / node_resume (keep existing)

Keep current `node_pause` and `node_resume` implementation. These use `walk()` to propagate pause state to children. No changes needed for v1.

---

## Helper Functions Referenced

```lua
--- Walk a node tree recursively, calling fn on each node
local function walk(node, fn)
    fn(node)
    if node.childs then
        for _, child in ipairs(node.childs) do
            walk(child, fn)
        end
    end
end

--- Find the nearest slide ancestor of a node
local function find_slide_parent(self, node)
    local current = node.config.parent
    while current do
        if current.config.type == 'slide' then return current end
        current = current.config.parent
    end
    return nil
end

--- Find the nearest container with focus_mode set
local function find_focus_group(self, node)
    local current = node.config.parent
    while current do
        if current.config.focus_mode then return current end
        current = current.config.parent
    end
    return nil
end

--- Check if a node is inside a given container
local function is_same_group(group, node)
    local current = node.config.parent
    while current do
        if current == group then return true end
        current = current.config.parent
    end
    return false
end

--- Check if needle is a descendant of node
local function is_descendant(node, needle)
    if node == needle then return true end
    if node.childs then
        for _, child in ipairs(node.childs) do
            if is_descendant(child, needle) then return true end
        end
    end
    return false
end

--- Find first focusable node in a subtree
local function find_focusable(node)
    if node.config.focusable then return node end
    if node.childs then
        for _, child in ipairs(node.childs) do
            local found = find_focusable(child)
            if found then return found end
        end
    end
    return nil
end
```

---

## JSX TypeScript Typings

```typescript
type CSSUnit = `${number}px` | `${number}%` | `${number}vw` | `${number}vh` | number;

type FocusState = '' | ':focus';

declare namespace JSX {
  const __gly_jsx: unique symbol;
  type Element = {
    readonly [__gly_jsx]: keyof IntrinsicElements;
  };
  interface IntrinsicElements {
    grid: {
      class: string,
      span?: number | `${number}x${number}`,
      offset?: number,
      after?: number,
      style?: string,
      dir?: 'row' | 'col',
      children?: JSX.Element | Array<JSX.Element>
    };
    slide: {
      class: string,
      id?: string,
      span?: number,
      offset?: number,
      after?: number,
      style?: string,
      dir?: 'row' | 'col',
      scroll?: 'shift' | 'page',
      focus?: 'wrap' | 'stop' | 'escape',
      children?: JSX.Element | Array<JSX.Element>
    };
    item: (
      { span?: number | `${number}x${number}` }
      & { offset?: number }
      & { after?: number }
      & { style?: string }
    ) & { children: JSX.Element };
    node: (
      { children?: JSX.Element | Array<JSX.Element> }
      | { [key: string]: Function }
    ) & {
      id?: string,
      class?: string | string[],
      focusable?: boolean,
      onFocus?: () => void,
      onBlur?: () => void,
      onPress?: () => void,
      draw?: (w: number, h: number) => void,
    };
    style: ({
      class?: `${string}${FocusState}`,
      width?: CSSUnit,
      height?: CSSUnit,
      left?: CSSUnit,
      right?: CSSUnit,
      top?: CSSUnit,
      bottom?: CSSUnit,
      margin?: CSSUnit,
      children?: JSX.Element,
    });
  }
  interface ElementChildrenAttribute {
    children: {};
  }
}
```

---

## Implementation Priority

Suggested order (each step builds on the previous):

1. **Bugfixes** — fix `has_right` (§1); fix `cells()` ROWSxCOLS (§2)
2. **dir='row'|'col'** — migrate from 0/1 to strings; update auto-detect in `grid.lua` (§11)
3. **Units** — `parse_unit`, `resolve`, update `stylesheet()` with alphabetical key closure (§3, §4, §5)
4. **Anonymous style + implicit name** — update `h()` factory for `<style>` without class (§7)
5. **span 2D** — `parse_span`, update grid layout in `dom()` (§12)
6. **`<slide>` rewrite** — new `slide.lua` (mirrors grid API), scroll registry, step calc, offset in DOM (§13)
7. **Render list** — `compile()` with culling in `tree.lua` (§10)
8. **Dirty tracking** — `mark_dirty`, `flush_dirty`, replace `flag_reposition` (§9)
9. **UID + ID/class indexes** — `uid_counter`, `index_id`, `index_class` in `node_begin`/`node_add`/`node_del` (§1 features, §2 features)
10. **Focus system** — focusable implicit in `node_add`; spatial nav; index nav inside slide (§14, §16, §17)
11. **Focus modes** — wrap/stop/escape (§15)
12. **Slide follows focus** — `ensure_visible` (§18)
13. **Style :focus** — swap on focus change in `set_focus` (§6)
14. **Query API** — queryOne, query, wrap with chainable methods (§23, §24)
15. **Browser UI** — criar `source/engine/browser/ui.lua` e `browser/jsx.lua`; instalar tudo em `std.ui.*` e `std.h` (§19)
16. **css_scroll** — render-time offset for slide (§8)
17. **TypeScript typings** — update `npm/gly-jsx/index.d.ts` with new types (§JSX Typings)
18. **h() closure** — optimization pass (§25)
