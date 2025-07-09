local three = require('source/shared/engine/three')

--! @defgroup std
--! @{
--! @defgroup ui
--! @{

--! @hideparam std
--! @hideparam engine
--! @hideparam self
--! @param [in,out] application new column
--! @param [in] size column width in blocks
local function add(std, engine, self, application, size)
    if not application then return self end
    local node = application.node or std.node.load(application)
    three.node_add(engine.dom, node, {
        parent = self.node,
        size = size
    })
    return self
end

--! @hideparam std
--! @hideparam engine
--! @hideparam self
--! @param [in,out] list of application columns
local function add_items(std, engine, self, applications)
    local index = 1
    while applications and index <= #applications do
        add(std, engine, self, applications[index])
        index = index + 1
    end
    return self
end

--! @hideparam self
--! @param [in] id item index
--! @return node
local function get_item(self, id)
    return self.items_node[id]
end

--! @hideparam classkey
--! @hideparam self
local function style(classkey, self, classlist)
    self[classkey] = classlist
    return self
end

--! @}
--! @}

local P = {
    add=add,
    style=style,
    get_item=get_item,
    add_items=add_items,
}

return P
