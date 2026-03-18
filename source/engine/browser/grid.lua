--! @file grid.lua
--! @brief std.ui.grid() component. Optionally scrollable via options.scroll.
--! @details Layout string is 'COLSxROWS'.
--!   Auto-detects dir: 1xN → 'col', Nx1 → 'row', NxN → 'row'.
--!   Nested grids are supported via re-parenting in dom.node_add.
--!   Scroll behaviour (flow/page/shift) is enabled by passing options.scroll;
--!   scroll state lives in engine.dom.scroll_registry — no extra cost when absent.

local dom            = require('source/engine/browser/dom')
local util_decorator = require('source/shared/functional/decorator')

-- ─── Child management ────────────────────────────────────────────────────────

--! @brief Add a child node or data table to a grid container.
--! @param std table
--! @param engine table
--! @param self grid object
--! @param application table  data table, node, or nested grid object
--! @param options number|table|nil  span size or {span, after, offset}
local function add(std, engine, self, application, options)
    if not application then return self end
    local node   = application.node or std.node.load(application)
    local size   = (type(options) == 'number' and options) or (options or {}).span
    local after  = options ~= size and (options or {}).after
    local offset = options ~= size and (options or {}).offset
    dom.node_add(engine.dom, node, {
        parent = self.node,
        offset = offset,
        after  = after,
        size   = size,
    })
    return self
end

--! @brief Add a list of children to a grid container.
local function add_items(std, engine, self, applications)
    local index = 1
    while applications and index <= #applications do
        add(std, engine, self, applications[index])
        index = index + 1
    end
    return self
end

--! @brief Return the nth child node (1-based).
local function get_item(self, id)
    return self.node.childs[id]
end

--! @brief Return the full childs array.
local function get_items(self)
    return self.node.childs
end

-- ─── Scroll registration (only used when options.scroll is present) ──────────

--! @brief Register scroll state for a grid node.
--! @param dom_obj engine.dom
--! @param node table  the grid node (cols/rows/dir already set)
--! @param options table  {scroll, anchor, focus} — all optional
local function scroll_register(dom_obj, node, options)
    options = options or {}
    local cols = node.config.cols
    local rows = node.config.rows
    local default_mode = (cols > 1 and rows > 1) and 'page' or 'shift'
    local mode = options.mode or options.scroll or default_mode
    local default_anchor
    if mode == 'flow' then
        local dim = (rows == 1) and cols or rows
        default_anchor = dim >= 3 and 1 or 0
    end
    dom_obj.scroll_registry[node] = {
        mode   = mode,
        index  = 0,
        anchor = options.anchor or default_anchor,
        total  = 0,
        cols   = cols,
        rows   = rows,
        dir    = node.config.dir,
    }
    if options.focus then
        node.config.focus_mode = options.focus
    end
end

-- ─── Grid component ──────────────────────────────────────────────────────────

--! @brief Set the fill direction.
--! @param mode string  'row' or 'col'
local function dir(self, mode)
    if mode then
        self.node.config.dir = mode
    end
    return self
end

--! @brief Create a grid component and register it in the DOM.
--! @details Layout string is 'COLSxROWS' — first number cols, second rows.
--!   e.g. '6x2' = 6 columns, 2 rows. '1x5' = 1 column, 5 rows.
--!   Pass options.scroll to enable scrollable behaviour (flow/page/shift).
--! @param std table
--! @param engine table
--! @param layout string  'COLSxROWS', e.g. '6x2', '1x5'
--! @param options table|nil  {scroll, anchor, focus} — enables scroll when present
--! @return table  grid object with :add, :add_items, :dir, .node
local function component(std, engine, layout, options)
    local cols, rows = layout:match('(%d+)x(%d+)')

    local node = std.node.load({})
    dom.node_add(engine.dom, node, { parent = engine.current })
    node.config.type = 'grid'
    node.config.cols = tonumber(cols)
    node.config.rows = tonumber(rows)

    if node.config.rows == 1 and node.config.cols > 1 then
        node.config.dir = 'col'
    elseif node.config.cols == 1 and node.config.rows > 1 then
        node.config.dir = 'row'
    else
        node.config.dir = 'row'
    end

    if options then
        scroll_register(engine.dom, node, options)
    end

    return {
        node      = node,
        add       = util_decorator.prefix2(std, engine, add),
        add_items = util_decorator.prefix2(std, engine, add_items),
        get_items = get_items,
        get_item  = get_item,
        dir       = dir,
    }
end

local P = {
    component       = component,
    scroll_register = scroll_register,
    add             = add,
    add_items       = add_items,
    get_item        = get_item,
    get_items       = get_items,
}

return P
