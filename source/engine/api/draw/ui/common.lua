--! @defgroup std
--! @{
--! @defgroup ui
--! @{

--! @hideparam self
local function gap(self, space_between_items)
    self.px_gap = space_between_items
    return self
end

--! @hideparam self
local function margin(self, space_container)
    self.px_margin = space_container
    return self
end

--! @hideparam std
--! @hideparam engine
--! @hideparam self
--! @param [in,out] application new column
--! @param [in] size column width in blocks
local function add(std, engine, self, application, size)
    if not application then return self end
    local index = #self.items_node + 1
    local node = application.node or std.node.load(application.node or application)

    std.node.spawn(node)
    node.config.parent = self.node

    self.items_node[index] = node
    self.items_size[index] = size or 1
    
    if application.node then
        self.items_ui[application.node] = application
    end

    return self
end

--! @hideparam std
--! @hideparam engine
--! @hideparam self
--! @param [in,out] list of application columns
local function add_items(std, engine, self, applications)
    local index = 1
    while applications and index < #applications do
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
    gap=gap,
    margin=margin,
    style=style,
    get_item=get_item,
    add_items=add_items,
}

return P
