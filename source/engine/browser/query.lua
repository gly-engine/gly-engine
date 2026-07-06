--! @file query.lua
--! @brief Selector API. Reads: index_id (owned by dom.lua), node.config.style_names.
--! @details Does NOT modify any engine state — pure read operations only.
--! query_one() returns a single wrapped node or nil.
--! query() returns an array of wrapped nodes.
--! wrap() returns a chainable handle ({dom=, node=} + shared Query metatable)
--! with focus, count, addStyle, etc. — methods are colon-called.
--! Selector '.name' matches nodes that have stylesheet 'name' applied (config.style_names),
--! NOT options.class — see [[feedback-class-vs-style]].

local ss  = require('source/engine/browser/stylesheet')
local nav = require('source/engine/browser/navigator')

-- ─── Query wrapper ────────────────────────────────────────────────────────────
-- Methods live in a shared metatable (Query); wrap() only allocates a small
-- {dom=, node=} handle instead of rebuilding a table of closures per call.
-- Methods are colon-called (w:focus()), matching the TSTL output for the
-- GlyQueryResult interface (no @noSelf) in npm/gly-types/index.d.ts.

local Query = {}
Query.__index = Query

--! Focus this node directly, or focus a child by index.
--! @param index number|nil  child index (1-based), or nil for direct focus
function Query:focus(index)
    if not index then
        nav.set_focus(self.dom, self.node)
    elseif type(index) == 'number' then
        local child = self.node.childs and self.node.childs[index]
        if child then
            local focusable = nav.find_focusable(child)
            if focusable then nav.set_focus(self.dom, focusable) end
        end
    end
    return self
end

--! Return the number of direct children.
function Query:count()
    return self.node.childs and #self.node.childs or 0
end

--! Apply a named stylesheet to this node.
--! @param name string  stylesheet class name
function Query:addStyle(name)
    local func = ss.stylesheet(self.dom, name)
    ss.css_add(self.dom, func, self.node, name)
    return self
end

--! Remove a named stylesheet from this node.
--! @param name string  stylesheet class name
function Query:delStyle(name)
    local func = self.dom.stylesheet_func and self.dom.stylesheet_func[name]
    if func then ss.css_del(self.dom, func, self.node, name) end
    return self
end

--! Set a data attribute on this node.
function Query:setAttr(key, value)
    self.node.data[key] = value
    return self
end

--! Get a data attribute from this node.
function Query:getAttr(key)
    return self.node.data[key]
end

--! Return the node's id (config.id), or nil.
function Query:getId()
    return self.node.config.id
end

--! Return whether this node is visible (not explicitly hidden).
function Query:isVisible()
    return self.node.config.visible ~= false
end

--! @brief Wrap a node with chainable query methods.
--! @param self engine.dom
--! @param node table
--! @return table  {dom=, node=} handle with Query as metatable
local function wrap(self, node)
    return setmetatable({ dom = self, node = node }, Query)
end

--! @brief Find all raw nodes that have stylesheet `name` applied.
--! @details Skips dead nodes (cfg.parent==nil and not root) — those linger
--!   in node_list until the next bus() rebuild after node_del.
--! @param self engine.dom
--! @param name string  stylesheet name (without '.')
--! @return table  array of raw nodes (may be empty)
local function nodes_by_style(self, name)
    local result = {}
    local nodes  = self.node_list
    local root   = self.root
    for i = 1, #nodes do
        local node = nodes[i]
        if node == root or node.config.parent ~= nil then
            local styles = node.config.style_names
            if styles then
                for j = 1, #styles do
                    if styles[j] == name then
                        result[#result + 1] = node
                        break
                    end
                end
            end
        end
    end
    return result
end

--! @brief Look up a single node by '#id' or '.style' selector.
--! @param self engine.dom
--! @param selector string  '#id', '.style-name', 'focused', or 'self'
--!   ('self' resolves to the node whose callback is currently running)
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
    elseif selector == 'self' then
        node = self.current_node
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
