local dom  = require('source/engine/browser/dom')
local ss   = require('source/engine/browser/stylesheet')
local ui   = require('source/engine/browser/ui')
local test = require('tests/framework/microtest')

-- ─── fixture: root with 3 horizontal focusable children (A, B[.modal], C) ────

local function make_row()
    local root = { config = {}, data = {} }
    local self = dom.node_begin(root, 300, 100)

    local nodes = {}
    for i, x in ipairs({ 0, 100, 200 }) do
        local node = { config = {}, data = {}, callbacks = {} }
        dom.node_add(self, node, { parent = root, focusable = true })
        node.config.offset_x = x
        node.config.offset_y = 0
        node.data.width  = 100
        node.data.height = 100
        nodes[i] = node
    end

    local a, b, c = nodes[1], nodes[2], nodes[3]
    local modal_func = ss.stylesheet(self, 'modal', {})
    ss.css_add(self, modal_func, b, 'modal')

    local std    = { ui = {} }
    local engine = { dom = self }
    ui.install(std, engine)

    return std, self, a, b, c
end

-- ─── std.ui.focus('right .modal') ────────────────────────────────────────────

function test_focus_right_style_finds_matching_node()
    local std, self, a, b = make_row()
    self.focus_current = a
    local result = std.ui.focus('right .modal')
    assert(result ~= nil, 'expected a match for right .modal')
    assert(result.node == b, 'expected to land on B (the .modal node)')
    assert(self.focus_current == b, 'focus_current must move to B')
end

function test_focus_right_style_skips_non_matching_and_returns_nil()
    local std, self, _, _, c = make_row()
    self.focus_current = c
    -- nothing to the right of C has the style; must be null, not a fallback
    local result = std.ui.focus('right .modal')
    assert(result == nil, 'expected nil when no node to the right matches')
    assert(self.focus_current == c, 'focus must not move on a failed filtered search')
end

function test_focus_left_style_finds_matching_node_from_the_right()
    local std, self, _, b, c = make_row()
    self.focus_current = c
    local result = std.ui.focus('left .modal')
    assert(result ~= nil, 'expected a match for left .modal')
    assert(result.node == b, 'expected to land on B (the .modal node)')
end

-- ─── plain directional focus is unaffected by the filter refactor ───────────

function test_focus_right_plain_still_moves_one_step()
    local std, self, a, b = make_row()
    self.focus_current = a
    local result = std.ui.focus('right')
    assert(result ~= nil, 'expected plain right to move')
    assert(result.node == b, 'plain right must land on the immediate neighbor')
end

function test_focus_right_plain_at_boundary_keeps_current()
    local std, self, _, _, c = make_row()
    self.focus_current = c
    local result = std.ui.focus('right')
    assert(result ~= nil, 'plain directional focus keeps returning current node at a boundary')
    assert(result.node == c, 'must stay on C')
end

test.unit(_G)
