--! @file scroll.lua
--! @brief Scroll registry. Owns: scroll_registry (weak-keyed table).
--! @details
--! INVARIANT: scroll_registry[node] exists iff node.config.type == 'slide'.
--! INVARIANT: scroll_registry keys are weak — entries auto-removed when slide node is GC'd.
--! scroll_register() is called when a slide node is created (from ui/slide.lua or jsx.lua).
--! ensure_visible() is called by navigator when focus moves to an off-screen slide item.

local layout = require('source/engine/browser/layout')
local dom    = require('source/engine/browser/dom')

--! @brief Register a node as a scrollable slide container.
--! @param self engine.dom
--! @param node table  the slide node (config.type must already be 'slide')
--! @param options table  {mode, focus, dir, cols, rows} — all optional, read from node.config
local function scroll_register(self, node, options)
    options = options or {}
    local default_mode = (node.config.cols > 1 and node.config.rows > 1) and 'page' or 'shift'
    self.scroll_registry[node] = {
        mode  = options.mode or default_mode,
        index = 0,
        total = 0,  -- updated as children are added (currently informational)
        cols  = node.config.cols,
        rows  = node.config.rows,
        dir   = node.config.dir,
    }
    if options.focus then
        node.config.focus_mode = options.focus
    end
end

--! @brief Adjust the slide scroll index so that focus_node is within the visible window.
--! @details Called by navigator.set_focus() when the focused node moves out of view.
--! @param self engine.dom
--! @param slide_node table  the slide container
--! @param focus_node table  the newly focused node
--! @param mark_dirty_fn function|nil  optional override; defaults to dom.mark_dirty
local function ensure_visible(self, slide_node, focus_node, mark_dirty_fn)
    local mark = mark_dirty_fn or dom.mark_dirty
    local scroll = self.scroll_registry[slide_node]
    if not scroll then return end

    local childs = slide_node.childs
    if not childs then return end

    -- find 0-based child_index (check direct match or descendant)
    local function is_desc(root, needle)
        if root == needle then return true end
        if root.childs then
            for _, c in ipairs(root.childs) do
                if is_desc(c, needle) then return true end
            end
        end
        return false
    end

    local child_index = -1
    for i, child in ipairs(childs) do
        if is_desc(child, focus_node) then
            child_index = i - 1  -- 0-based
            break
        end
    end

    if child_index < 0 then return end

    local step          = layout.slide_step(scroll)
    local visible_count = scroll.cols * scroll.rows
    local first_visible = scroll.index * step
    local last_visible  = first_visible + visible_count - 1

    if child_index < first_visible then
        if scroll.mode == 'page' then
            scroll.index = math.floor(child_index / step)
        else
            scroll.index = child_index
        end
    elseif child_index > last_visible then
        if scroll.mode == 'page' then
            scroll.index = math.floor(child_index / step)
        else
            scroll.index = child_index - visible_count + 1
        end
    else
        return  -- already visible, no change needed
    end

    if scroll.index < 0 then scroll.index = 0 end
    mark(self, slide_node)
end

local P = {
    scroll_register = scroll_register,
    slide_step      = layout.slide_step,
    ensure_visible  = ensure_visible,
}

return P
