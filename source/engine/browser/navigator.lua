--! @file navigator.lua
--! @brief Focus and spatial navigation. Owns: focus_list, focus_current.
--! @details
--! INVARIANT: focus_list contains only nodes where config.focusable == true.
--! INVARIANT: focus_current is always in focus_list, or nil.
--! set_focus() swaps :focus style variants and fires focus/unfocus callbacks.
--! focus_navigate() dispatches to grid-index navigation or spatial scoring.

local ss        = require('source/engine/browser/stylesheet')
local layout    = require('source/engine/browser/layout')
local lifecycle = require('source/engine/browser/lifecycle')
local dom       = require('source/engine/browser/dom')
local pause     = require('source/engine/browser/pause')

-- ─── Helper functions ───────────────────────────────────────────────────────

--! @brief Check if needle is a descendant of (or equal to) node.
local function is_descendant(node, needle)
    if node == needle then return true end
    if node.childs then
        for _, child in ipairs(node.childs) do
            if is_descendant(child, needle) then return true end
        end
    end
    return false
end

--! @brief Find the first focusable node in a subtree (depth-first).
local function find_focusable(node)
    if node.config.focusable then return node end
    if node.childs then
        for _, child in ipairs(node.childs) do
            local found = find_focusable(child)
            if found then return found end
        end
    end
    return nil
end

--! @brief Find the nearest scroll-enabled grid ancestor of node.
local function find_scroll_parent(self, node)
    local current = node.config.parent
    while current do
        if self.scroll_registry[current] then return current end
        current = current.config.parent
    end
    return nil
end

-- ─── ensure_visible ──────────────────────────────────────────────────────────

--! @brief Adjust the scroll index so that focus_node is within the visible window.
--! @param self engine.dom
--! @param grid_node table  the scroll-enabled grid container
--! @param focus_node table  the newly focused node
local function ensure_visible(self, grid_node, focus_node)
    local scroll = self.scroll_registry[grid_node]
    if not scroll then return end

    local childs = grid_node.childs
    if not childs then return end

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

    -- flow: scroll.index = focused item index, layout handles all positioning
    if scroll.mode == 'peek' then
        if scroll.index == child_index then return end
        scroll.index = child_index
        dom.mark_dirty(self, grid_node)
        return
    end

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
    dom.mark_dirty(self, grid_node)
end

-- ─── set_focus ──────────────────────────────────────────────────────────────

--! @brief Move focus to a new node, swapping :focus styles and firing callbacks.
--! @param self engine.dom
--! @param node table  node to receive focus
local function set_focus(self, node)
    if not node then return end
    if pause.is_paused(self, node.config.uid, '*') then return end
    local old = self.focus_current
    if old == node then return end

    local std = self.std

    -- remove :focus styles from old node and fire unfocus callback
    if old then
        for name, focus_func in pairs(old.config.style_focus or {}) do
            ss.css_del(self, focus_func, old)
            local base_func = self.stylesheet_func[name]
            if base_func then ss.css_add(self, base_func, old) end
        end
        lifecycle.unfocus(self, old)
    end

    self.focus_current = node

    -- record as last focus for all ancestor containers
    local ancestor = node.config.parent
    while ancestor do
        self.focus_memory[ancestor] = node
        ancestor = ancestor.config.parent
    end

    -- apply :focus styles to new node and fire focus callback
    for name, focus_func in pairs(node.config.style_focus or {}) do
        local base_func = self.stylesheet_func[name]
        if base_func then ss.css_del(self, base_func, node) end
        ss.css_add(self, focus_func, node)
    end
    lifecycle.focus(self, node)

    -- ensure all scroll ancestors reveal this node (inner → outer)
    local scroll_parent = find_scroll_parent(self, node)
    while scroll_parent do
        ensure_visible(self, scroll_parent, node)
        scroll_parent = find_scroll_parent(self, scroll_parent)
    end
end

-- ─── Spatial navigation ─────────────────────────────────────────────────────

--! @brief Find best focus candidate in a given direction using position scoring.
--! @param self engine.dom
--! @param current table  currently focused node
--! @param direction string  'up'|'down'|'left'|'right'
local function focus_navigate_spatial(self, current, direction)
    local cx = current.config.offset_x + current.data.width  / 2
    local cy = current.config.offset_y + current.data.height / 2
    local c_left   = current.config.offset_x
    local c_right  = current.config.offset_x + current.data.width
    local c_top    = current.config.offset_y
    local c_bottom = current.config.offset_y + current.data.height

    local best_node  = nil
    local best_score = math.huge

    for i = 1, #self.focus_list do
        local candidate = self.focus_list[i]
        if candidate ~= current
           and candidate.config.visible ~= false
           and not candidate.config._scroll_clipped
           and candidate.config.focusable
           and not pause.is_paused(self, candidate.config.uid, '*') then

            local px = candidate.config.offset_x + candidate.data.width  / 2
            local py = candidate.config.offset_y + candidate.data.height / 2
            local dx, dy = px - cx, py - cy

            -- require no overlap on the navigation axis so same-row/col items
            -- are never picked when pressing up/down or left/right
            local valid = false
            local score = 0

            local p_left   = candidate.config.offset_x
            local p_right  = p_left + candidate.data.width
            local p_top    = candidate.config.offset_y
            local p_bottom = p_top  + candidate.data.height
            local y_overlap = p_top < c_bottom and p_bottom > c_top

            -- left/right: no X overlap + must share the same Y band
            -- up/down:    no Y overlap (any X is fine, score handles proximity)
            if direction == 'right' and p_left >= c_right and y_overlap then
                valid = true; score = dx + math.abs(dy) * 3
            elseif direction == 'left' and p_right <= c_left and y_overlap then
                valid = true; score = -dx + math.abs(dy) * 3
            elseif direction == 'down' and p_top >= c_bottom then
                valid = true; score = dy + math.abs(dx) * 3
            elseif direction == 'up' and p_bottom <= c_top then
                valid = true; score = -dy + math.abs(dx) * 3
            end

            if valid and score < best_score then
                best_score = score
                best_node  = candidate
            end
        end
    end

    if best_node then set_focus(self, best_node) end
end

-- ─── Index navigation (inside scroll grid) ──────────────────────────────────

--! @brief Navigate focus within a scroll grid using logical child index.
--! @param self engine.dom
--! @param grid_node table  the scroll-enabled grid container
--! @param current table  currently focused node
--! @param direction string  'up'|'down'|'left'|'right'
--! @return table|nil  next focusable node, or nil if at boundary
local function focus_navigate_grid(self, grid_node, current, direction)
    local cfg    = grid_node.config
    local childs = grid_node.childs
    if not childs then return nil end

    local cols = cfg.cols
    local rows = cfg.rows
    local dir  = cfg.dir

    -- find current child index (1-based)
    local idx = 0
    for i, child in ipairs(childs) do
        if child == current or is_descendant(child, current) then
            idx = i; break
        end
    end
    if idx == 0 then return nil end

    local next_idx = idx
    local total    = #childs

    local scroll_state = self.scroll_registry[grid_node]
    local mode = scroll_state and scroll_state.mode or 'shift'

    if dir == 'col' then
        -- col-major (horizontal list): left/right are the primary axis
        -- up/down escape to spatial — single row has nothing above or below
        if rows == 1 and (direction == 'down' or direction == 'up') then
            return nil
        end
        local current_row = (idx - 1) % rows
        if direction == 'down' then
            if mode == 'page' and current_row == rows - 1 then return nil end
            next_idx = idx + 1
        elseif direction == 'up' then
            if mode == 'page' and current_row == 0 then return nil end
            next_idx = idx - 1
        elseif direction == 'right' then next_idx = idx + rows
        elseif direction == 'left'  then next_idx = idx - rows
        end
    else  -- 'row'
        -- row-major (vertical list): up/down are the primary axis
        -- left/right escape to spatial — single column has nothing beside it
        if cols == 1 and (direction == 'left' or direction == 'right') then
            return nil
        end
        local current_col = (idx - 1) % cols
        if direction == 'right' then
            if mode == 'page' and current_col == cols - 1 then return nil end
            next_idx = idx + 1
        elseif direction == 'left' then
            if mode == 'page' and current_col == 0 then return nil end
            next_idx = idx - 1
        elseif direction == 'down'  then next_idx = idx + cols
        elseif direction == 'up'    then next_idx = idx - cols
        end
    end

    if cfg.focus_mode == 'wrap' then
        if next_idx < 1     then next_idx = total end
        if next_idx > total then next_idx = 1     end
    end

    if next_idx < 1 or next_idx > total then return nil end
    local target = childs[next_idx]
    local remembered = self.focus_memory[target]
    if remembered and remembered.config.focusable and remembered.config.parent then
        return remembered
    end
    return find_focusable(target)
end

-- ─── Top-level navigation dispatch ──────────────────────────────────────────

--! @brief Dispatch a directional navigation event to the appropriate handler.
--! @param self engine.dom
--! @param direction string  'up'|'down'|'left'|'right'
local function focus_navigate(self, direction)
    local current = self.focus_current
    if not current then return end

    -- walk scroll parents from nearest to farthest: each off-axis nil bubbles
    -- up to the next outer grid until one handles it or spatial takes over.
    local scroll_parent = find_scroll_parent(self, current)
    while scroll_parent do
        local next_node = focus_navigate_grid(self, scroll_parent, current, direction)
        if next_node then
            set_focus(self, next_node)
            return
        end
        scroll_parent = find_scroll_parent(self, scroll_parent)
    end

    focus_navigate_spatial(self, current, direction)
end

-- ─── Public interface ────────────────────────────────────────────────────────

--! @brief Check whether a node is currently focused.
--! @param self engine.dom
--! @param node table
--! @return boolean
local function is_focused(self, node)
    return self.focus_current == node
end

--! @brief Trigger click callback on the currently focused node.
--! @param self engine.dom
local function press(self)
    local node = self.focus_current
    if node and not pause.is_paused(self, node.config.uid, '*') and node.callbacks.click then
        local prev = self.current_node
        self.current_node = node
        if self.std then
            node.callbacks.click(node.data, self.std)
        end
        self.current_node = prev
    end
end

local P = {
    set_focus              = set_focus,
    focus_navigate         = focus_navigate,
    focus_navigate_spatial = focus_navigate_spatial,
    focus_navigate_grid    = focus_navigate_grid,
    find_scroll_parent     = find_scroll_parent,
    find_focusable         = find_focusable,
    is_descendant          = is_descendant,
    is_focused             = is_focused,
    press                  = press,
}

return P
