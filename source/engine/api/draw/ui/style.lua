local three = require('source/shared/engine/three')

--! @defgroup std
--! @{
--! @defgroup ui
--! @{
--!
--! @page ui_style Style
--! @details
--! there is a css style componetization style,
--! you define the name of a class and define fixed attributes or you can pass functions.
--!
--! @par Attributes
--!
--! @li @b pos_x
--! @li @b pos_y
--! @li @b width
--! @li @b height
--!
--! @par Example
--! @code{.java}
--! std.ui.style('home')
--!     :height(300)
--!     :pos_y(function(std, node, parent)
--!         return parent.data.height - 300
--!     end)
--! @endcode
--! @code{.java}
--! std.ui.style('center')
--!     :pos_x(function(std, node, parent)
--!         return parent.data.width/2 - node.data.width/2
--!     end)
--! @endcode
--! @code{.java}
--! std.ui.grid('3x1')
--!     :style('center home')
--!     :add(item1)
--!     :add({})
--!     :add(item2)
--! @endcode
--!
--! @}
--! @}

local function add(engine, self, node)
    three.css_add(engine.dom, self.func, node)
    return self
end

local function add_items(engine, self, nodes)
    local index = 1
    while nodes and index <= #nodes do
        add(engine, self, nodes[index])
        index = index + 1
    end
    return self
end

local function remove(engine, self, node)
    three.css_del(engine.dom, self.func, node)
    return self
end

local function component(engine, name, options)
    local self = {
        func = three.stylesheet(engine.dom, name, options),
        add = function(a, b) return add(engine, a, b) end,
        add_items = function(a, b) return add_items(engine, a, b) end,
        remove = function(a, b) return remove(engine, a, b) end
    }
    return self
end

local P = {
    component = component
}

return P
