local three = require('source/shared/engine/three')
local ui_common = require('source/engine/api/draw/ui/common')
local util_decorator = require('source/shared/functional/decorator')

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
--! @par Slide
--! also known as carousel, it has similar behavior to grid but with visual selection of items.
--! but it only accepts one-dimensional grids such as @c 1x1 @c 2x1 or @c 1x2 .
--! @par Example
--! @code{.java}
--! std.ui.slide('6x1')
--!     :add_items(my_items)
--!     :apply()
--! @endcode
--!
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
--! @page ui_nodes Node (UI)
--!
--! You can add several different column types to your grid: classes, nodes, medias, offsets, entire applications and even another grid.
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
--!
--! @li **@ref jsx**
--! @code{.xml}
--! <grid class="1x1"><node/></grid>
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
    --self.direction = mode
    return self
end

local function component(std, engine, layout)
    local rows, cols = layout:match('(%d+)x(%d+)')
    local node = std.node.load({})

    three.node_add(engine.dom, node, {parent=engine.current})
    node.config.type = 'grid'
    node.config.rows = tonumber(rows)
    node.config.cols = tonumber(cols)
    node.config.dir = (node.config.rows == 1 and node.config.cols > 1) and 1 or 0

    local self = {
        node=node,
        apply=function(s) return s end,
        gap=function(s) return s end,
        margin=function(s) return s end,
        dir=util_decorator.prefix2(std, engine, dir),
        add=util_decorator.prefix2(std, engine, ui_common.add),
        add_items=util_decorator.prefix2(std, engine, ui_common.add_items),
        get_item=ui_common.get_item
    }

    return self
end

local P = {
    component = component
}

return P
