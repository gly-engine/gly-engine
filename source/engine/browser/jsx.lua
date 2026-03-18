--! @file jsx.lua
--! @brief JSX element factory. Installs std.h as a closure with std/engine upvalues.
--! @details
--! create_h(std, engine) returns h(element, attribute, childs).
--! Handles: 'node', 'grid', 'item', 'style', function, table elements.
--! Anonymous <style> generates implicit name from sorted attribute keys.
--! <grid scroll=...> enables scroll behaviour and validates no 2D span.

--! @brief Add one or more named stylesheet classes to a node.
--! @param std table
--! @param node table
--! @param stylesheet_str string  space-separated class names
local function add_style(std, node, stylesheet_str)
    for style in stylesheet_str:gmatch('%S+') do
        std.ui.style(style):add(node)
    end
end

--! @brief Create the h() JSX factory as a closure capturing std and engine.
--! @param std table
--! @param engine table
--! @return function h(element, attribute, childs)
local function create_h(std, engine)
    local function h(element, attribute, ...)
        local el_type = type(element)
        attribute = attribute or {}
        local childs = {...}

        if element == std then
            return error

        elseif element == std.h then
            for i = 1, #childs do
                std.node.spawn(std.node.load(childs[i]))
            end
            return childs

        elseif element == std.ui then
            return childs

        elseif element == 'node' then
            local parent = std.node.spawn(std.node.load(attribute))
            for i = 1, #childs do
                local c = childs[i]
                if c.node then
                    local is_invalid = (c.span or 1) > 1 or c.offset or c.after
                    if is_invalid then
                        error('[error] JSX forbidden attributes in \'node\' child')
                    end
                    std.node.spawn(c.node, parent)
                    if c.style then add_style(std, c.node, c.style) end
                else
                    std.node.spawn(c, parent)
                end
            end
            return parent

        elseif element == 'grid' then
            local has_scroll = attribute.scroll or attribute.focus or attribute.anchor
            local scroll_opts = has_scroll and {
                scroll = attribute.scroll,
                focus  = attribute.focus,
                anchor = attribute.anchor,
            } or nil
            local grid = std.ui.grid(attribute.class, scroll_opts)
            if attribute.dir then grid:dir(attribute.dir) end
            if attribute.style then add_style(std, grid.node, attribute.style) end
            for i = 1, #childs do
                local item = childs[i]
                -- validate: no 2D span when scroll is enabled
                if has_scroll and item.span and type(item.span) == 'string' then
                    error('[error] scrollable grid does not support 2D span, use number')
                end
                if item.node then
                    grid:add(item.node, {span=item.span, offset=item.offset, after=item.after})
                    if item.style then add_style(std, grid:get_item(i), item.style) end
                else
                    grid:add(item)
                end
            end
            grid.span   = attribute.span
            grid.after  = attribute.after
            grid.style  = attribute.style
            grid.offset = attribute.offset
            return grid

        elseif element == 'item' then
            return {
                type   = 'item',
                node   = childs[1],
                span   = attribute.span,
                after  = attribute.after,
                style  = attribute.style,
                offset = attribute.offset,
            }

        elseif element == 'style' then
            local name = attribute.class
            if not name then
                -- anonymous style: build implicit name from sorted attribute keys
                local keys = {}
                for k in pairs(attribute) do
                    if k ~= 'children' then
                        keys[#keys + 1] = k
                    end
                end
                table.sort(keys)
                local parts = {}
                for _, k in ipairs(keys) do
                    parts[#parts + 1] = k .. '=' .. tostring(attribute[k])
                end
                name = table.concat(parts)
            end

            if childs and #childs > 0 then
                -- anonymous or named-with-child: register and apply directly to child
                local style_obj = std.ui.style(name, attribute)
                local child = childs[1]
                local target = child.node or child
                style_obj:add(target)
                return child
            else
                -- named: register in stylesheet dict only
                return std.ui.style(name, attribute)
            end

        elseif el_type == 'function' then
            attribute.children = (#childs > 1) and childs or childs[1]
            return element(attribute, std)

        elseif el_type == 'table' then
            return element

        else
            error('[error] JSX invalid element type: ' .. el_type)
        end
    end

    return h
end

--! @brief Install std.h using std/engine closure.
--! @param std table
--! @param engine table
local function install(std, engine)
    std.h = create_h(std, engine)
end

local P = {
    create_h = create_h,
    install  = install,
}

return P
