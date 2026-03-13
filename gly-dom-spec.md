# GlyEngine DOM v2 — Specification

## Overview

This is a pure Lua DOM engine for extremely constrained hardware (TV boxes, retro consoles, embedded systems). The DOM is computed rarely and compiled into a flat render list that is iterated every frame. There is no clipping/scissor — elements outside the screen are simply positioned off-screen with negative or overflow coordinates.

The engine powers a JSX transpiler (TypeScript → Lua) where frontend developers write declarative UI and the engine handles layout, scroll, and focus navigation for TV remote controls.

## Architecture

### File Structure (suggested)

Files MAY be split into modules or kept as a single file — implementer's discretion. If split, suggested boundaries:

```
source/browser/
├── dom.lua          -- core: node lifecycle, tree, layout calc, render list
├── stylesheet.lua   -- css: parse_unit, resolve, stylesheet, css_add/del
├── scroll.lua       -- slide/scroll registry, offset calc, virtualisation
├── navigator.lua    -- focus system, spatial navigation, index navigation
├── query.lua        -- queryOne, query, wrap with chainable methods
└── bus.lua          -- event dispatch, dirty flush, pause/resume
```

If single file: organize with section comments, ~800-900 lines estimated.

Dependencies flow one direction: `bus` → `dom` → `scroll` + `navigator` + `query` → `stylesheet`. Avoid circular requires.

### Node Structure

Each node has three conceptual areas. Current code mixes `data` and `config`. Clarify separation:

```lua
node = {
    data = {},       -- user-defined: draw function, custom attributes, content
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
        layer = 0,
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

```lua
-- BEFORE (confusing/wrong):
local function cells(node)
    local cfg = node.config
    local dat = node.data
    if cfg.type == 'grid' then
        local cols, rows = cfg.cols, cfg.rows
        local w = dat.width / rows    -- divides width by rows??
        local h = dat.height / cols   -- divides height by cols??
        return w, h
    end
    return dat.width, dat.height
end

-- AFTER (clear):
-- cols = number of columns (horizontal divisions)
-- rows = number of rows (vertical divisions)
local function cells(node)
    local cfg = node.config
    local layout = node.layout
    if cfg.type == 'grid' or cfg.type == 'slide' then
        local w = layout.width / cfg.cols
        local h = layout.height / cfg.rows
        return w, h
    end
    return layout.width, layout.height
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

In the `h()` factory, when `element == 'style'` and `childs` has content:
```lua
elseif element == 'style' then
    if childs and #childs > 0 then
        -- anonymous: build css function, apply to child
        local func = build_css(attribute)
        local child = childs[1]
        local target = child.node or child
        css_add(self, func, target)
        return child
    else
        -- named: register in stylesheet dict
        return std.ui.style(attribute.class, attribute)
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

Default: `'row'`

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

A grid that supports scrolling. Separated from `<grid>` for explicit semantics. The `class` defines the **visible window** (e.g. `'1x5'` shows 5 items at a time).

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

### 19. std.ui.focus() — Polymorphic

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

### 20. std.ui.press()

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

### 21. std.ui.isFocused()

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

### 22. queryOne / query

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

### 23. wrap() — Chainable Methods

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

### 24. h() as Closure

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

### 25. node_pause / node_resume (keep existing)

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

1. **Bugfixes** — fix `has_right`, fix `cells()` cols/rows
2. **Node structure** — add `layout` field, uid, id/class indexes
3. **Units** — `parse_unit`, `resolve`, update `stylesheet`
4. **dir='row'|'col'** — string replacement in DOM calc
5. **span 2D** — `parse_span`, update grid layout
6. **Render list** — `compile()` with culling
7. **Dirty tracking** — `mark_dirty`, `flush_dirty`
8. **`<slide>`** — scroll registry, step calc, offset in DOM
9. **Focus system** — focusable implicit, spatial nav, index nav
10. **Focus modes** — wrap/stop/escape
11. **Style :focus** — swap on focus change
12. **Query API** — queryOne, query, wrap
13. **std.ui.focus()** — polymorphic dispatch
14. **Anonymous style** — update h() factory
15. **css_scroll** — render-time offset
16. **h() closure** — optimization pass
