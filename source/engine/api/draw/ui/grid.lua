local ui_common = require('src/lib/engine/draw/ui/common')
local util_decorator = require('src/lib/util/decorator')

--! @defgroup std
--! @{
--! @defgroup ui
--! @{
--!
--! @details
--! @page ui_grid Grid System
--!
--! The grid system is very versatile, and adjusts itself with the resolution and can be used by nesting one grid inside another,
--! the best of all is that in frameworks that limit you to thinking in 12 or 24 columns like
--! [bootstrap](https://getbootstrap.com/docs/5.0/layout/grid/)
--! you must define how many columns yourself.
--!
--! @par Example
--! @code{.java}
--! local function init(std, data)
--!     std.ui.grid('4x8 full6x8 ultra8x8')
--!         :add_items(list_of_widgets)
--! end
--! @endcode
--!
--! @par Breakpoints
--! @todo comming soon breakpoints
--!
--! |        | 1seg | SD 480 | HD 720  | FULL HD 1080 | QUAD HD 1440 |
--! | :----- |      | :----: | :-----: | :----------: | :----------: |
--! | prefix |      | sd     | hd      | full         | quad         |
--! | width  | >0px | >479px | >719px  | >1079px      | >1439px      |
--! 
--! @par Offset
--! To create blank columns, simply add an empty table @c {} to represent an empty node.
--! You can also specify the size of these whitespace columns as needed.
--! @startsalt
--! {+
--!   . | . | [btn0] 
--!   [btn1] | [btn2] | [btn3]
--! }
--! @endsalt
--! @code{.java}
--! std.ui.grid('3x2')
--!     :add({}, 2)
--!     :add(btn0)
--!     :add(btn1)
--!     :add(btn2)
--!     :add(btn3)
--!     :apply()
--! @endcode
--!
--! @par Columns
--!
--! You can add several different items to your grid: classes, nodes, offsets, entire applications and even another grid.
--!
--! @li @b media
--! @code{.java}
--! std.ui.grid('1x1'):add(std.media.video(1))
--! @endcode
--!
--! @li @b class
--! @code{.java}
--! local btn = {
--!     draw=function(std, data)end
--! }
--! std.ui.grid('1x1'):add(btn)
--! @endcode
--!
--! @li @b node
--! @code{.java}
--! local btn_node = std.node.load(btn)
--! std.ui.grid('1x1'):add(node_btn)
--! @endcode
--!
--! @li @b offset
--! @code{.java}
--! std.ui.grid('1x1'):add({})
--! @endcode
--!
--! @li @b application
--! @code{.java}
--! local game = {
--!     meta={
--!        title='pong'
--!     },
--!     callbacks={
--!         init=function() end,
--!         loop=function() end,
--!         draw=function() end,
--!         exit=function() end
--!     }
--! }
--! std.ui.grid('1x1'):add(game)
--! @endcode
--! 
--! @li @b grid
--! @code{.java}
--! std.ui.grid('1x1')
--!      :add(std.ui.grid('1x1')
--!         :add(btn)
--!      )
--!     :apply()
--! @endcode
--! @}
--! @}

--! @hideparam std
--! @hideparam engine
--! @hideparam self
--! @param mode direction items
--! @li @c 0 left to right / up to down
--! @li @c 1 up to down / left to right
local function dir(std, engine, self, mode)
    self.direction = mode
    return self
end

--! @hideparam std
--! @hideparam engine
--! @hideparam self
local function apply(std, engine, self)
    local index = 1
    local x, y = 0, 0

    local index2 = 1
    local pipeline = std.ui.style(self.classlist).pipeline

    while index2 <= #pipeline do
        pipeline[index2](std, self.node, self.node.config.parent, engine.root)
        index2 = index2 + 1
    end
    
    local gap_x, gap_y = self.px_gap, self.px_gap
    local offset_x, offset_y = (self.px_margin/2) + (gap_x/2), (self.px_margin/2) + (gap_y/2)
    local width = self.node.data.width - self.px_margin
    local height = self.node.data.height - self.px_margin
    local hem = (width / self.rows) - gap_x
    local vem = (height / self.cols) - gap_y

    while self.direction == 1 and index <= #self.items_node do
        local node = self.items_node[index]
        local size = self.items_size[index]
        local ui = self.items_ui[node]
    
        node.config.offset_x = offset_x + (x * (hem + gap_x))
        node.config.offset_y = offset_y + (y * (vem + gap_y))
        node.data.width = hem
        node.data.height = size * vem
    
        y = y + size
        if y >= self.cols then
            x = x + 1
            y = 0
        end
    
        if ui then
            ui:apply()
        end
    
        index = index + 1
    end    

    while self.direction == 0 and index <= #self.items_node do
        local node = self.items_node[index]
        local size = self.items_size[index]
        local ui = self.items_ui[node]

        node.config.offset_x = offset_x + (x * (hem + gap_x))
        node.config.offset_y = offset_y + (y * (vem + gap_y))
        node.data.width = size * hem
        node.data.height = vem

        x = x + size
        if x >= self.rows then
            y = y + 1
            x = 0
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
    local node = std.node.load({
        width = engine.current.data.width,
        height = engine.current.data.height
    })
    
    local self = {
        direction=0,
        rows=tonumber(rows),
        cols=tonumber(cols),
        items_node = {},
        items_size = {},
        items_ui = {},
        node=node,
        px_gap=0,
        px_margin=0,
        classlist='',
        gap=ui_common.gap,
        margin=ui_common.margin,
        dir=util_decorator.prefix2(std, engine, dir),
        add=util_decorator.prefix2(std, engine, ui_common.add),
        add_items=util_decorator.prefix2(std, engine, ui_common.add_items),
        style=ui_common.style,
        apply=util_decorator.prefix2(std, engine, apply),
        get_item=ui_common.get_item
    }

    if self.rows == 1 and self.cols > 1 then
        self.direction = 1
    end

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
    node.config.depth = engine.current.depht
    return self
end

local P = {
    component = component
}

return P
