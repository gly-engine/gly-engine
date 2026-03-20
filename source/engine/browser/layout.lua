--! @file layout.lua
--! @brief Grid layout computation. No external browser dependencies.
--! @details
--! Owns: cells(), parse_span(), slide_step(), dom_layout().
--! All functions are pure or receive engine.dom as explicit 'self'.
--! Required by dom.lua and grid.lua — must NOT require any other browser/ module
--! to avoid circular dependencies.
--! Scroll offset is applied when engine.dom.scroll_registry[node] is set.

-- ─── Cell geometry ───────────────────────────────────────────────────────────

--! @brief Compute cell dimensions for a grid node.
--! @details COLSxROWS convention: cfg.cols divides width, cfg.rows divides height.
--! @param node table
--! @return number cell_w, number cell_h
local function cells(node)
    local cfg = node.config
    local dat = node.data
    if cfg.type == 'grid' then
        return dat.width / cfg.cols, dat.height / cfg.rows
    end
    return dat.width, dat.height
end

--! @brief Parse a span value into (span_cols, span_rows).
--! @param span number|string  e.g. 1, 2, '2x2', '1x3'
--! @return number span_cols, number span_rows
local function parse_span(span)
    if type(span) == 'number' then
        return span, 1
    end
    if type(span) == 'string' then
        local c, r = span:match('^(%d+)x(%d+)$')
        if c then return tonumber(c), tonumber(r) end
        local n = tonumber(span)
        if n then return n, 1 end
    end
    return 1, 1
end

-- ─── Scroll step ─────────────────────────────────────────────────────────────

--! @brief Compute the number of items to skip per scroll step.
--! @param scroll table  scroll state from scroll_registry
--! @return number
local function slide_step(scroll)
    if scroll.mode == 'page' then
        return scroll.cols * scroll.rows
    elseif scroll.mode == 'peek' then
        return 1
    elseif scroll.dir == 'row' then
        return scroll.cols
    else
        return scroll.rows
    end
end

-- ─── Scroll clip depth ───────────────────────────────────────────────────────
-- Tracks how many clipped scroll-grid ancestors the current recursion is inside.
-- Incremented before recursing into an out-of-bounds child, decremented after.
local _clip = 0

-- ─── Span-hidden depth ───────────────────────────────────────────────────────
-- Tracks how many span=0 ancestors the current recursion is inside.
-- Incremented before recursing into a span=0 child, decremented after.
local _hide = 0

-- ─── Layout engine ───────────────────────────────────────────────────────────

--! @brief Recursively compute layout for a node and its children.
--! @details Writes cfg.offset_x/y and dat.width/height for every node in the subtree.
--!   grid: lays out children into cells respecting dir, span, offset, after.
--!   grid with scroll_registry entry: applies scroll index so pre-offset items
--!   are placed off-screen.
--! @param self engine.dom  (read-only: scroll_registry)
--! @param node table
--! @param parent_x number
--! @param parent_y number
--! @param parent_w number
--! @param parent_h number
local function dom_layout(self, node, parent_x, parent_y, parent_w, parent_h)
    local cfg = node.config
    local dat = node.data

    -- inherit scroll-clip / span-hidden state from parent's decision
    cfg._scroll_clipped = _clip > 0 or nil
    cfg._span_hidden    = _hide > 0 or nil

    cfg.offset_x = parent_x
    cfg.offset_y = parent_y
    dat.width    = parent_w
    dat.height   = parent_h

    if cfg.type == 'grid' then
        local cols    = cfg.cols
        local rows    = cfg.rows
        local dir_val = cfg.dir
        local cell_w, cell_h = cells(node)
        local x, y = 0, 0

        -- scroll: shift accumulator so items before scroll.index are off-screen
        local scroll = self.scroll_registry[node]
        if scroll then
            if scroll.mode == 'page' then
                if dir_val == 'col' then
                    x = -(scroll.index * scroll.cols)
                else
                    y = -(scroll.index * scroll.rows)
                end
            elseif scroll.mode == 'peek' then
                -- focused item sits at slot [anchor] (0-based).
                -- anchor=0: focused item always at slot 0; last item shows empty slots after.
                -- anchor>0: view clamps at end so no empty slots after last item.
                local total  = node.childs and #node.childs or 0
                local anchor = scroll.anchor or 1
                if dir_val == 'col' then
                    local lo = anchor == 0 and -(total - 1) or -(total - cols + anchor)
                    x = math.max(math.min(anchor - scroll.index, anchor), lo)
                else
                    local lo = anchor == 0 and -(total - 1) or -(total - rows + anchor)
                    y = math.max(math.min(anchor - scroll.index, anchor), lo)
                end
            else
                if dir_val == 'col' then
                    x = -scroll.index
                else
                    y = -scroll.index
                end
            end
        end

        if node.childs then
            for _, child in ipairs(node.childs) do
                local cc = child.config

                -- span=0: hidden — takes no grid space, draw() never called
                if cc.size == 0 then
                    _hide = _hide + 1
                    dom_layout(self, child, parent_x, parent_y, 0, 0)
                    _hide = _hide - 1
                    -- cursor NOT advanced

                else
                    local offset_val = cc.offset or 0
                    local after_val  = cc.after  or 0
                    local span_x, span_y = parse_span(cc.size or 1)
                    if dir_val == 'row' and type(cc.size) == 'number' then
                        span_x, span_y = 1, span_x
                    end

                    if dir_val == 'col' then
                        y = y + offset_val
                        if y >= rows then
                            local wrap = math.floor(y / rows)
                            y = y % rows
                            x = x + wrap
                        end
                    else
                        x = x + offset_val
                        if x >= cols then
                            local wrap = math.floor(x / cols)
                            x = x % cols
                            y = y + wrap
                        end
                    end

                    local cx = parent_x + cell_w * x
                    local cy = parent_y + cell_h * y
                    local w  = span_x * cell_w
                    local h  = span_y * cell_h

                    for _, css_fn in ipairs(cc.css) do
                        cx, cy, w, h = css_fn(cx, cy, w, h)
                    end

                    -- clip children that fall fully outside a scroll grid viewport
                    local outside = scroll
                        and (cx + w <= parent_x or cx >= parent_x + parent_w
                          or cy + h <= parent_y or cy >= parent_y + parent_h)
                    if outside then _clip = _clip + 1 end
                    dom_layout(self, child, cx, cy, w, h)
                    if outside then _clip = _clip - 1 end

                    if dir_val == 'col' then
                        y = y + span_y + after_val
                        if y >= rows then
                            local wrap = math.floor(y / rows)
                            y = y % rows
                            x = x + span_x + (wrap - 1)
                        end
                    else
                        x = x + span_x + after_val
                        if x >= cols then
                            local wrap = math.floor(x / cols)
                            x = x % cols
                            y = y + span_y + (wrap - 1)
                        end
                    end
                end
            end
        end

    elseif node.childs then
        for _, child in ipairs(node.childs) do
            local cx, cy, w, h = parent_x, parent_y, parent_w, parent_h
            for _, css_fn in ipairs(child.config.css) do
                cx, cy, w, h = css_fn(cx, cy, w, h)
            end
            dom_layout(self, child, cx, cy, w, h)
        end
    end
end

local P = {
    cells      = cells,
    parse_span = parse_span,
    slide_step = slide_step,
    dom_layout = dom_layout,
}

return P
