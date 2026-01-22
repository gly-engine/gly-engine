--! @defgroup std
--! @{

local function add_style(std, node, stylesheet)
    for style in stylesheet:gmatch("%S+") do
        std.ui.style(style):add(node)
    end 
end

--! @short JSX element factory
--! @brief Core function that interprets @ref jsx and integrate with @ref ui "std.ui"
--! @hideparam std
--! @hideparam engine
--! @param element (string|function|table) The element tag name, a component function, or a raw node.
--! @param attribute (table) Element attributes (e.g., class, margin, gap).
--! @param ... Child elements or nested content.
--! @throw error when element is invalid type
--! @return node, list of nodes, or nil.
local function h(std, engine, element, attribute, childs)
    local el_type = type(element)
    attribute = attribute or {}

    if element == std then
        return error
    elseif element == std.h then
        for i = 1, #childs do std.node.spawn(std.node.load(childs[i])) end
        return childs
    elseif element == std.ui then
        return childs
    elseif element == 'node' then
        local parent = std.node.spawn(std.node.load(attribute))
        for i = 1, #childs do
            local c = childs[i]
            if c.node then
                local is_invalid = (c.span or 1) > 1 or c.offset or c.after
                if is_invalid then error('[error] JSX forbidden attributes in \'node\' child') end
                if c.style then add_style(std, c.node, c.style) end
                std.node.spawn(c.node, parent)
            else
                std.node.spawn(c, parent)
            end
        end
        return parent
    elseif element == 'grid' then
        local index = 1
        local grid = std.ui.grid(attribute.class):dir(attribute.dir)
        if attribute.style then add_style(std, grid.node, attribute.style) end
        while index <= #childs do
            local item = childs[index]
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
    elseif element == 'item' then
        return {
            type='item',
            node=childs[1],
            span=attribute.span,
            after=attribute.after,
            style=attribute.style,
            offset=attribute.offset
        }
    elseif element == 'style' then
        return std.ui.style(attribute.class, attribute)
    elseif el_type == 'function' then
        attribute.children = (childs and #childs > 1) and childs or childs[1]
        return element(attribute, std)
    elseif el_type == 'table' then
        return element
    else
        error('[error] JSX invalid element type: '..el_type)
    end
end

--! @}

local P = {
    h = h
}

return P
