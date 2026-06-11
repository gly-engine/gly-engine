local layout = require('source/engine/browser/layout')
local jsx    = require('source/engine/browser/jsx')
local test   = require('tests/framework/microtest')

-- ─── layout: span=0 hides a plain <node> child ───────────────────────────────

function test_node_child_span0_hidden()
    local self = { scroll_registry = {} }
    local hidden = { config = { css = {}, size = 0 }, data = {} }
    local shown  = { config = { css = {}, size = 1 }, data = {} }
    local parent = { config = { css = {}, type = 'node' }, data = {}, childs = { hidden, shown } }
    layout.dom_layout(self, parent, 0, 0, 100, 100)
    assert(hidden.config._span_hidden == true,  'span=0 child must be hidden')
    assert(shown.config._span_hidden  == nil,   'span=1 child must stay visible')
    assert(shown.data.width == 100,             'visible child keeps parent size')
end

function test_node_span0_hides_subtree()
    local self = { scroll_registry = {} }
    local grandchild = { config = { css = {} }, data = {} }
    local hidden = { config = { css = {}, size = 0 }, data = {}, childs = { grandchild } }
    local parent = { config = { css = {}, type = 'node' }, data = {}, childs = { hidden } }
    layout.dom_layout(self, parent, 0, 0, 100, 100)
    assert(hidden.config._span_hidden     == true, 'span=0 node hidden')
    assert(grandchild.config._span_hidden == true, 'subtree inherits hidden')
end

function test_node_child_style_span0_hidden()
    local self = { scroll_registry = {} }
    -- style-provided span (cfg._style_span) overrides cfg.size in effective_span
    local child  = { config = { css = {}, size = 1, _style_span = 0 }, data = {} }
    local parent = { config = { css = {}, type = 'node' }, data = {}, childs = { child } }
    layout.dom_layout(self, parent, 0, 0, 100, 100)
    assert(child.config._span_hidden == true, 'style span=0 must hide')
end

-- ─── layout: grid span=0 regression (cursor not advanced) ────────────────────

function test_grid_child_span0_hidden_no_cell()
    local self = { scroll_registry = {} }
    local a = { config = { css = {}, size = 1 }, data = {} }
    local b = { config = { css = {}, size = 0 }, data = {} }
    local c = { config = { css = {}, size = 1 }, data = {} }
    local grid = { config = { css = {}, type = 'grid', cols = 3, rows = 1, dir = 'col' },
                   data = {}, childs = { a, b, c } }
    layout.dom_layout(self, grid, 0, 0, 300, 100)
    assert(b.config._span_hidden == true,  'grid span=0 hidden')
    assert(a.config.offset_x == 0,         'a in first cell')
    assert(c.config.offset_x == 100,       'c follows a; b took no cell, got ' .. tostring(c.config.offset_x))
end

-- ─── jsx: <item span> propagation into a plain <node> ────────────────────────

local std = { ui = {}, node = {} }
std.node.load  = function(x) return x end
std.node.spawn = function(n) return n end
std.ui.style   = function() return { add = function() end } end
local engine = { dom = { index_id = {} } }
local h = jsx.create_h(std, engine)

function test_jsx_node_child_span0_propagates()
    local child = { config = {} }
    local item  = h('item', { span = 0 }, child)
    h('node', {}, item)
    assert(child.config.size == 0, 'span=0 must propagate to config.size')
end

function test_jsx_node_child_span_gt1_errors()
    local child = { config = {} }
    local item  = h('item', { span = 2 }, child)
    local ok = pcall(function() h('node', {}, item) end)
    assert(ok == false, 'span>1 inside <node> must error')
end

function test_jsx_node_child_no_span_untouched()
    local child = { config = {} }
    local item  = h('item', {}, child)
    h('node', {}, item)
    assert(child.config.size == nil, 'no span attr leaves config.size untouched')
end

test.unit(_G)
