--! @file navigator.lua
--! @brief Focus and spatial navigation. Owns: focus_list, focus_current.
--! @details
--! INVARIANT: focus_list contains only nodes where config.focusable == true.
--! INVARIANT: focus_current is always in focus_list, or nil.
--! set_focus() swaps :focus style variants and fires focus/unfocus callbacks.
--! focus_navigate() dispatches to slide-index navigation or spatial scoring.

local ss        = require('source/engine/browser/stylesheet')
local scroll    = require('source/engine/browser/scroll')
local lifecycle = require('source/engine/browser/lifecycle')

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

--! @brief Find the nearest slide ancestor of node.
local function find_slide_parent(self, node)
    local current = node.config.parent
    while current do
        if current.config.type == 'slide' then return current end
        current = current.config.parent
    end
    return nil
end

--! @brief Find the nearest container ancestor that has focus_mode set.
local function find_focus_group(self, node)
    local current = node.config.parent
    while current do
        if current.config.focus_mode then return current end
        current = current.config.parent
    end
    return nil
end

--! @brief Check if node is inside the given group container.
local function is_same_group(group, node)
    local current = node.config.parent
    while current do
        if current == group then return true end
        current = current.config.parent
    end
    return false
end

-- ─── set_focus ──────────────────────────────────────────────────────────────

--! @brief Move focus to a new node, swapping :focus styles and firing callbacks.
--! @param self engine.dom
--! @param node table  node to receive focus
local function set_focus(self, node)
    if not node then return end
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

    -- apply :focus styles to new node and fire focus callback
    for name, focus_func in pairs(node.config.style_focus or {}) do
        local base_func = self.stylesheet_func[name]
        if base_func then ss.css_del(self, base_func, node) end
        ss.css_add(self, focus_func, node)
    end
    lifecycle.focus(self, node)

    -- ensure slide follows focus
    local slide = find_slide_parent(self, node)
    if slide then
        scroll.ensure_visible(self, slide, node)
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

    local best_node  = nil
    local best_score = math.huge

    for i = 1, #self.focus_list do
        local candidate = self.focus_list[i]
        if candidate ~= current
           and candidate.config.visible ~= false
           and candidate.config.focusable then

            local px = candidate.config.offset_x + candidate.data.width  / 2
            local py = candidate.config.offset_y + candidate.data.height / 2
            local dx, dy = px - cx, py - cy

            local valid = false
            local score = 0

            if direction == 'right' and dx > 0 then
                valid = true; score = dx + math.abs(dy) * 3
            elseif direction == 'left' and dx < 0 then
                valid = true; score = -dx + math.abs(dy) * 3
            elseif direction == 'down' and dy > 0 then
                valid = true; score = dy + math.abs(dx) * 3
            elseif direction == 'up' and dy < 0 then
                valid = true; score = -dy + math.abs(dx) * 3
            end

            -- check container focus_mode constraints
            if valid then
                local group = find_focus_group(self, current)
                if group and not is_same_group(group, candidate) then
                    if group.config.focus_mode == 'stop' then
                        valid = false
                    end
                end
            end

            if valid and score < best_score then
                best_score = score
                best_node  = candidate
            end
        end
    end

    if best_node then set_focus(self, best_node) end
end

-- ─── Index navigation (inside slide) ────────────────────────────────────────

--! @brief Navigate focus within a slide using logical child index.
--! @param self engine.dom
--! @param slide_node table  the slide container
--! @param current table  currently focused node
--! @param direction string  'up'|'down'|'left'|'right'
--! @return table|nil  next focusable node, or nil if at boundary
local function focus_navigate_slide(self, slide_node, current, direction)
    local cfg    = slide_node.config
    local childs = slide_node.childs
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

    if dir == 'col' then
        if direction == 'down'  then next_idx = idx + 1
        elseif direction == 'up'    then next_idx = idx - 1
        elseif direction == 'right' then next_idx = idx + rows
        elseif direction == 'left'  then next_idx = idx - rows
        end
    else  -- 'row'
        if direction == 'right' then next_idx = idx + 1
        elseif direction == 'left'  then next_idx = idx - 1
        elseif direction == 'down'  then next_idx = idx + cols
        elseif direction == 'up'    then next_idx = idx - cols
        end
    end

    if cfg.focus_mode == 'wrap' then
        if next_idx < 1     then next_idx = total end
        if next_idx > total then next_idx = 1     end
    end

    if next_idx < 1 or next_idx > total then return nil end
    return find_focusable(childs[next_idx])
end

-- ─── Top-level navigation dispatch ──────────────────────────────────────────

--! @brief Dispatch a directional navigation event to the appropriate handler.
--! @param self engine.dom
--! @param direction string  'up'|'down'|'left'|'right'
local function focus_navigate(self, direction)
    local current = self.focus_current
    if not current then return end

    local slide = find_slide_parent(self, current)
    if slide then
        local next_node = focus_navigate_slide(self, slide, current, direction)
        if next_node then
            set_focus(self, next_node)
            return
        end
        if slide.config.focus_mode == 'escape' then
            focus_navigate_spatial(self, current, direction)
        end
        return
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
    if node and node.callbacks.click then
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
    focus_navigate_slide   = focus_navigate_slide,
    find_slide_parent      = find_slide_parent,
    find_focus_group       = find_focus_group,
    find_focusable         = find_focusable,
    is_same_group          = is_same_group,
    is_descendant          = is_descendant,
    is_focused             = is_focused,
    press                  = press,
}

return P
