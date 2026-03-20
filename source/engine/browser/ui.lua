--! @file ui.lua
--! @brief Browser UI installer. Owns std.ui namespace installation.
--! @details Delegates layout to grid.lua and style.lua.
--! Delegates navigation to navigator.lua and query to query.lua.
--! Does NOT duplicate layout logic.

local nav      = require('source/engine/browser/navigator')
local query    = require('source/engine/browser/query')
local dom_mod  = require('source/engine/browser/dom')
local ui_grid  = require('source/engine/browser/grid')
local ui_style = require('source/engine/api/draw/ui/style')
local util_decorator = require('source/shared/functional/decorator')

-- ─── Node resolution ──────────────────────────────────────────────────────────

--! @brief Resolve a target (nil / '#id' / node / grid-object) to a raw node.
--! @param dom_obj engine.dom
--! @param target nil|string|table
--! @return table|nil  raw node
local function resolve_node(dom_obj, target)
    if target == nil then
        return dom_obj.current_node
    elseif type(target) == 'string' and target:sub(1, 1) == '#' then
        return dom_obj.index_id[target:sub(2)]
    elseif type(target) == 'table' then
        -- raw node (has .config) or grid/slide object (has .node)
        return target.config and target or target.node
    end
end

--! @brief Install std.ui.* methods onto std.
--! @param std table
--! @param engine table  expects engine.dom to be initialized
local function install(std, engine)
    std.ui = std.ui or {}

    -- store std reference in dom for navigator callbacks
    engine.dom.std = std

    -- layout components
    std.ui.grid  = util_decorator.prefix2(std, engine, ui_grid.component)
    std.ui.style = util_decorator.prefix1(engine, ui_style.component)

    -- focus and navigation
    std.ui.focus = function(target)
        local dom_obj = engine.dom
        if not target then
            target = dom_obj.current_node
        elseif type(target) == 'string' then
            if target == 'right' or target == 'left'
            or target == 'up'   or target == 'down' then
                nav.focus_navigate(dom_obj, target)
                return
            end
            if target:sub(1, 1) == '#' then
                target = dom_obj.index_id[target:sub(2)]
            end
        end
        if target then
            -- if the target is not directly focusable (e.g. a grid), descend
            -- into its subtree; if still nothing found, walk up one level so
            -- siblings (e.g. the cards row next to a title row) are also searched
            if type(target) == 'table' and not target.config.focusable then
                local found = nav.find_focusable(target)
                if not found and target.config.parent then
                    found = nav.find_focusable(target.config.parent)
                end
                target = found
            end
            if target then
                nav.set_focus(dom_obj, target)
            end
        end
    end

    std.ui.press = function()
        nav.press(engine.dom)
    end

    std.ui.isFocused = function(target)
        local dom_obj = engine.dom
        if not target then
            target = dom_obj.current_node
        end
        return nav.is_focused(dom_obj, target)
    end

    -- span / layout mutation
    std.ui.span = function(span_value, target)
        local node = resolve_node(engine.dom, target)
        if not node then return end
        node.config.size = span_value
        local parent = node.config.parent
        if parent then
            dom_mod.mark_dirty(engine.dom, parent)
        end
    end

    std.ui.class = function(layout, target)
        local node = resolve_node(engine.dom, target)
        if not node then return end
        -- if target is not a grid, try its parent grid
        if node.config.type ~= 'grid' then
            local p = node.config.parent
            if p and p.config.type == 'grid' then
                node = p
            else
                return
            end
        end
        local cols, rows = layout:match('(%d+)x(%d+)')
        if not cols then return end
        node.config.cols = tonumber(cols)
        node.config.rows = tonumber(rows)
        -- keep scroll_registry in sync when present
        local scroll = engine.dom.scroll_registry[node]
        if scroll then
            scroll.cols = node.config.cols
            scroll.rows = node.config.rows
        end
        dom_mod.mark_dirty(engine.dom, node)
    end

    -- selector API
    std.ui.queryOne = function(selector)
        return query.query_one(engine.dom, selector)
    end

    std.ui.query = function(selector)
        return query.query(engine.dom, selector)
    end
end

local P = {
    install = install,
}

return P
