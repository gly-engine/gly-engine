local ui_common = require('src/lib/engine/draw/ui/common')
local util_decorator = require('src/lib/util/decorator')

--! @defgroup std
--! @{
--! @defgroup ui
--! @{
--!
--! @page ui_slide Slide System
--! @details
--! also known as carousel, it has similar behavior to grid but with visual selection of items.
--! but it only accepts one-dimensional grids such as @c 1x1 @c 2x1 or @c 1x2 .
--! @par Example
--! @code{.java}
--! std.ui.slide('6x1')
--!     :add_items(my_items)
--!     :apply()
--! @endcode

--! @renamefunc next
--! @hideparam self
--! @hideparam to
--! @pre avaliable only in the @c std.ui.slide
--! @par Example
--! @code{.java}
--! std.ui.slide('6x1'):add_items(items):next(2):apply()
--! @endcode
local function slider_next(self, to)
    local incr = to or 1
    self.index = self.index + incr
    if self.index == 0 then
        self.index = #self.items_node
    end
    if self.index > #self.items_node then
        self.index = 1
    end
    return self
end

--! @renamefunc back
--! @hideparam self
--! @pre avaliable only in the @c std.ui.slide
--! @par Example
--! @code{.java}
--! std.ui.slide('1x6'):add_items(items):back():apply()
--! @endcode
local function slider_back(self)
    return slider_next(self, -1)
end

--! @}
--! @}

--! @hideparam std
--! @hideparam engine
local function apply(std, engine, self)
    local index = 1
    local x, y = 0, 0

    local index2 = 1
    local pipeline = std.ui.style(self.classlist).pipeline

    while index2 <= #pipeline do
        pipeline[index2](std, self.node, self.node.config.parent, engine.root)
        index2 = index2 + 1
    end
    
    local hem = self.node.data.width / self.rows
    local vem = self.node.data.height / self.cols

    while index <= #self.items_node do
        local node = self.items_node[index]
        local size = self.items_size[index]
        local ui = self.items_ui[node]

        node.config.offset_x = x * hem
        node.config.offset_y = y * vem
        node.data.width = size * hem
        node.data.height = vem

        x = x + size
        if x >= self.rows then
            y = y + 1
            x = 0
        end

        if index == self.index then
            local index3 = 1
            local pipeline2 = std.ui.style(self.classlist_selected).pipeline
            while index3 <= #pipeline2 do
                pipeline2[index3](std, node, node.config.parent, engine.root)
                index3 = index3 + 1
            end
        end

        if ui then
            ui:apply()
        end
       
        index = index + 1
    end

    return self
end

local function component(std, engine, layout)
    local rows, cols = layout:match('(%d+)x(%d+)')

    if rows ~= '1' and cols ~= '1' then
        error('invalid grid layout')
    end

    local node = std.node.load({
        width = engine.current.data.width,
        height = engine.current.data.height
    })

    local self = {
        index = 1,
        rows=tonumber(rows),
        cols=tonumber(cols),
        items_node = {},
        items_size = {},
        items_ui = {},
        node=node,
        classlist='',
        classlist_selected='',
        -- methods
        next=slider_next,
        back=slider_back,
        add=util_decorator.prefix2(std, engine, ui_common.add),
        add_items=util_decorator.prefix2(std, engine, ui_common.add_items),
        style_item_select=util_decorator.prefix1('classlist_selected', ui_common.style),
        style=util_decorator.prefix1('classlist', ui_common.style),
        apply=util_decorator.prefix2(std, engine, apply),
        get_item=ui_common.get_item
    }

    if engine.root == engine.current then
        node.callbacks.resize = function()
            if node.config.parent ~= engine.root then
                node.callbacks.resize = nil
                return
            end
            node.data.height = engine.root.data.height
            node.data.width = engine.root.data.width
            self:apply()
        end
    end

    std.node.spawn(node)
    return self
end

local P = {
    component = component
}

return P
