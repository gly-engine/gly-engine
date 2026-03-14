--! @file slide.lua
--! @brief std.ui.slide() component. Mirrors std.ui.grid() API.
--! @details
--!   Rewrite of the old slide.lua. Removes :next(), :back(), :apply().
--!   Scroll behaviour is handled by the scroll registry and dom_layout.
--!   Layout string is 'COLSxROWS' — first number cols, second rows.
--!   e.g. '5x1' = 5 columns, 1 row (horizontal). '1x5' = 1 column, 5 rows (vertical).

local dom            = require('source/engine/browser/dom')
local grid           = require('source/engine/browser/grid')
local scroll         = require('source/engine/browser/scroll')
local util_decorator = require('source/shared/functional/decorator')

--! @brief Set the fill direction of the slide.
--! @param mode string  'row' or 'col'
local function dir(self, mode)
    if mode then
        self.node.config.dir = mode
    end
    return self
end

--! @brief Create a slide component and register it in the DOM.
--! @details Layout string is 'COLSxROWS'.
--!   Auto-detects dir: Nx1 (single row) → 'col', 1xN (single col) → 'row'.
--! @param std table
--! @param engine table
--! @param layout string  'COLSxROWS', e.g. '5x1', '1x5'
--! @return table  slide object with :add, :add_items, :dir, .node
local function component(std, engine, layout)
    local cols, rows = layout:match('(%d+)x(%d+)')

    local node = std.node.load({})
    dom.node_add(engine.dom, node, { parent = engine.current })
    node.config.type = 'slide'
    node.config.cols = tonumber(cols)
    node.config.rows = tonumber(rows)

    if node.config.rows == 1 and node.config.cols > 1 then
        node.config.dir = 'col'
    elseif node.config.cols == 1 and node.config.rows > 1 then
        node.config.dir = 'row'
    else
        node.config.dir = 'row'
    end

    scroll.scroll_register(engine.dom, node)

    return {
        node      = node,
        add       = util_decorator.prefix2(std, engine, grid.add),
        add_items = util_decorator.prefix2(std, engine, grid.add_items),
        get_items = grid.get_items,
        get_item  = grid.get_item,
        dir       = dir,
    }
end

local P = {
    component = component,
}

return P
