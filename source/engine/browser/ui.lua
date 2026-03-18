--! @file ui.lua
--! @brief Browser UI installer. Owns std.ui namespace installation.
--! @details Delegates layout to grid.lua and style.lua.
--! Delegates navigation to navigator.lua and query to query.lua.
--! Does NOT duplicate layout logic.

local nav      = require('source/engine/browser/navigator')
local query    = require('source/engine/browser/query')
local ui_grid  = require('source/engine/browser/grid')
local ui_style = require('source/engine/api/draw/ui/style')
local util_decorator = require('source/shared/functional/decorator')

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
            nav.set_focus(dom_obj, target)
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
