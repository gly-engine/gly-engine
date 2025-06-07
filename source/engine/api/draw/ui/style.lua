local style = {
    list = {},
    dict = {}
}

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

local function decorate_style(namespace, attribute)
    return function(self, value)
        self.pipeline[#self.pipeline + 1] = function(std, node, parent, root)
            local is_func = type(value) == 'function'
            node[namespace][attribute] =  is_func and value(std, node, parent, root) or value
        end
        return self
    end
end

local function component(std, engine, classname)
    local self = style.dict[classname]

    if not self then
        self = {
            pipeline = {},
            width = decorate_style('data', 'width'),
            height = decorate_style('data', 'height'),
            pos_y = decorate_style('config', 'offset_y'),
            pos_x = decorate_style('config', 'offset_x')
        }

        style.list[#style.list] = classname
        style.dict[classname] = self
    end

    return self
end

local P = {
    component = component
}

return P
