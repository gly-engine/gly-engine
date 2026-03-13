--! @file grid.lua
--! @brief std.ui.grid() component.
--! @details Grid layout container. Layout string is 'ROWSxCOLS'.
--!   Auto-detects dir: 1xN → 'col', Nx1 → 'row', NxN → 'row'.
--!   Nested grids are supported via re-parenting in dom.node_add.

local dom            = require('source/engine/browser/dom')
local util_decorator = require('source/shared/functional/decorator')

-- ─── Child management (shared with slide.lua) ───────────────────────────────

--! @brief Add a child node or data table to a grid/slide container.
--! @param std table
--! @param engine table
--! @param self grid/slide object
--! @param application table  data table, node, or nested grid/slide object
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

--! @brief Add a list of children to a grid/slide container.
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
--! @param std table
--! @param engine table
--! @param layout string  'COLSxROWS', e.g. '6x2', '1x5'
--! @return table  grid object with :add, :add_items, :dir, .node
local function component(std, engine, layout)
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
    component = component,
    -- exported for slide.lua reuse
    add       = add,
    add_items = add_items,
    get_item  = get_item,
    get_items = get_items,
}

return P
