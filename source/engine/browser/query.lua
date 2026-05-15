--! @file query.lua
--! @brief Selector API. Reads: index_id (owned by dom.lua), node.config.style_names.
--! @details Does NOT modify any engine state — pure read operations only.
--! query_one() returns a single wrapped node or nil.
--! query() returns an array of wrapped nodes.
--! wrap() returns a chainable object with setScroll, getScroll, focus, count, etc.
--! Selector '.name' matches nodes that have stylesheet 'name' applied (config.style_names),
--! NOT options.class — see [[feedback-class-vs-style]].

local ss  = require('source/engine/browser/stylesheet')
local nav = require('source/engine/browser/navigator')
local dom = require('source/engine/browser/dom')

--! @brief Wrap a node with chainable query methods.
--! @param self engine.dom
--! @param node table
--! @return table  object with chainable methods
local function wrap(self, node)
    local w = {}

    --! Set the scroll index of a slide node.
    --! @param value number|string  absolute index, 'end', '+N', '-N'
    w.setScroll = function(value)
        local scroll_state = self.scroll_registry[node]
        if not scroll_state then return w end
        if value == 'end' then
            scroll_state.index = math.max(0, scroll_state.total - scroll_state.cols * scroll_state.rows)
        elseif type(value) == 'string' and value:sub(1, 1) == '+' then
            scroll_state.index = scroll_state.index + tonumber(value:sub(2))
        elseif type(value) == 'string' and value:sub(1, 1) == '-' then
            scroll_state.index = scroll_state.index - tonumber(value:sub(2))
        else
            scroll_state.index = value
        end
        scroll_state.index = math.max(0, math.min(scroll_state.index, math.max(0, scroll_state.total - 1)))
        dom.mark_dirty(self, node)
        return w
    end

    --! Get the current scroll state as a descriptor table.
    w.getScroll = function()
        local scroll_state = self.scroll_registry[node]
        if not scroll_state then return nil end
        local visible_count = scroll_state.cols * scroll_state.rows
        return {
            index    = scroll_state.index,
            progress = scroll_state.index / math.max(1, scroll_state.total - visible_count),
            visible  = { scroll_state.index, scroll_state.index + visible_count - 1 },
        }
    end

    --! Focus this node directly, or focus a child by index.
    --! @param index number|nil  child index (1-based), or nil for direct focus
    w.focus = function(index)
        if not index then
            nav.set_focus(self, node)
        elseif type(index) == 'number' then
            local child = node.childs and node.childs[index]
            if child then
                local focusable = nav.find_focusable(child)
                if focusable then nav.set_focus(self, focusable) end
            end
        end
        return w
    end

    --! Return the number of direct children.
    w.count = function()
        return node.childs and #node.childs or 0
    end

    --! Apply a named stylesheet to this node.
    --! @param name string  stylesheet class name
    w.addStyle = function(name)
        local func = ss.stylesheet(self, name)
        ss.css_add(self, func, node)
        return w
    end

    --! Remove a named stylesheet from this node.
    --! @param name string  stylesheet class name
    w.delStyle = function(name)
        local func = self.stylesheet_func and self.stylesheet_func[name]
        if func then ss.css_del(self, func, node) end
        return w
    end

    --! Set a data attribute on this node.
    w.setAttr = function(key, value)
        node.data[key] = value
        return w
    end

    --! Get a data attribute from this node.
    w.getAttr = function(key)
        return node.data[key]
    end

    --! Return the node's id (config.id), or nil.
    w.getId = function()
        return node.config.id
    end

    --! Return whether this node is visible (not explicitly hidden).
    w.isVisible = function()
        return node.config.visible ~= false
    end

    return w
end

--! @brief Find all raw nodes that have stylesheet `name` applied.
--! @param self engine.dom
--! @param name string  stylesheet name (without '.')
--! @return table  array of raw nodes (may be empty)
local function nodes_by_style(self, name)
    local result = {}
    local nodes  = self.node_list
    for i = 1, #nodes do
        local styles = nodes[i].config.style_names
        if styles then
            for j = 1, #styles do
                if styles[j] == name then
                    result[#result + 1] = nodes[i]
                    break
                end
            end
        end
    end
    return result
end

--! @brief Look up a single node by '#id' or '.style' selector.
--! @param self engine.dom
--! @param selector string  '#id', '.style-name', or 'focused'
--! @return table|nil  wrapped node or nil
local function query_one(self, selector)
    local prefix = selector:sub(1, 1)
    local name   = selector:sub(2)

    local node
    if prefix == '#' then
        node = self.index_id[name]
    elseif prefix == '.' then
        node = nodes_by_style(self, name)[1]
    elseif selector == 'focused' then
        node = self.focus_current
    end

    if not node then return nil end
    return wrap(self, node)
end

--! @brief Look up all nodes matching a '.style' selector.
--! @param self engine.dom
--! @param selector string  '.style-name'
--! @return table  array of wrapped nodes (may be empty)
local function query(self, selector)
    local prefix = selector:sub(1, 1)
    local name   = selector:sub(2)

    if prefix == '.' then
        local list   = nodes_by_style(self, name)
        local result = {}
        for i = 1, #list do
            result[i] = wrap(self, list[i])
        end
        return result
    end

    -- fallback: single-node selectors
    local node = query_one(self, selector)
    return node and { node } or {}
end

local P = {
    query_one      = query_one,
    query          = query,
    wrap           = wrap,
    nodes_by_style = nodes_by_style,
}

return P
