--! @defgroup std
--! @{

--! @short JSX element factory
--! @brief Core function that interprets @ref jsx and integrate with @ref ui "std.ui"
--! @hideparam std
--! @hideparam engine
--! @param element (string|function|table) The element tag name, a component function, or a raw node.
--! @param attribute (table) Element attributes (e.g., class, margin, gap).
--! @param ... Child elements or nested content.
--! @throw error when element is invalid type
--! @return node, list of nodes, or nil.
local function h(std, engine, element, attribute, ...)
    local childs = {...}
    local el_type = type(element)

    if element == std then
        return error
    elseif element == std.h then
        return nil
    elseif element == std.ui then
        return childs
    elseif element == 'node' then
        return std.node.spawn(std.node.load(attribute))
    elseif element == 'grid' then
        return std.ui.grid(attribute.class):margin(attribute.margin):gap(attribute.gap):add_items(childs):apply().node
    elseif el_type == 'function' then
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
