local tree = require('source/shared/engine/tree')

--! @defgroup std
--! @{
--! @defgroup ui
--! @{

--! @hideparam std
--! @hideparam engine
--! @hideparam self
--! @todo in future, dont suport @c options as number
--! @param [in,out] application new column
--! @param [in] size column width in blocks
local function add(std, engine, self, application, options)
    if not application then return self end
    local node = application.node or std.node.load(application)
    local size = (type(options) == 'number' and options) or (options or {}).span
    local offset = options ~= size and (options or {}).offset
    tree.node_add(engine.dom, node, {
        parent = self.node,
        offset = offset,
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
    return self.node.childs[id]
end

local function get_items(self)
    return self.node.childs
end

--! @}
--! @}

local P = {
    add=add,
    get_item=get_item,
    get_items=get_items,
    add_items=add_items,
}

return P
