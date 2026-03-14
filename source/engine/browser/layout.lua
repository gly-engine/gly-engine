--! @file layout.lua
--! @brief Grid/slide layout computation. No external browser dependencies.
--! @details
--! Owns: cells(), parse_span(), slide_step(), dom_layout().
--! All functions are pure or receive engine.dom as explicit 'self'.
--! Required by dom.lua and scroll.lua — must NOT require any other browser/ module
--! to avoid circular dependencies.

-- ─── Cell geometry ───────────────────────────────────────────────────────────

--! @brief Compute cell dimensions for a grid or slide node.
--! @details COLSxROWS convention: cfg.cols divides width, cfg.rows divides height.
--! @param node table
--! @return number cell_w, number cell_h
local function cells(node)
    local cfg = node.config
    local dat = node.data
    if cfg.type == 'grid' or cfg.type == 'slide' then
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
--! @param scroll table  scroll_state from scroll_registry
--! @return number
local function slide_step(scroll)
    if scroll.mode == 'page' then
        return scroll.cols * scroll.rows
    elseif scroll.dir == 'row' then
        return scroll.cols
    else
        return scroll.rows
    end
end

-- ─── Layout engine ───────────────────────────────────────────────────────────

--! @brief Recursively compute layout for a node and its children.
--! @details Writes cfg.offset_x/y and dat.width/height for every node in the subtree.
--!   grid/slide: lays out children into cells respecting dir, span, offset, after.
--!   slide:      applies scroll index so pre-offset items are placed off-screen.
--! @param self engine.dom  (read-only: scroll_registry)
--! @param node table
--! @param parent_x number
--! @param parent_y number
--! @param parent_w number
--! @param parent_h number
local function dom_layout(self, node, parent_x, parent_y, parent_w, parent_h)
    local cfg = node.config
    local dat = node.data

    cfg.offset_x = parent_x
    cfg.offset_y = parent_y
    dat.width    = parent_w
    dat.height   = parent_h

    if cfg.type == 'grid' or cfg.type == 'slide' then
        local cols    = cfg.cols
        local rows    = cfg.rows
        local dir_val = cfg.dir
        local cell_w, cell_h = cells(node)
        local x, y = 0, 0

        -- slide: shift accumulator so items before scroll.index are off-screen
        if cfg.type == 'slide' then
            local scroll = self.scroll_registry[node]
            if scroll then
                if scroll.mode == 'page' then
                    if dir_val == 'col' then
                        x = -(scroll.index * scroll.cols)
                    else
                        y = -(scroll.index * scroll.rows)
                    end
                else
                    if dir_val == 'col' then
                        x = -scroll.index
                    else
                        y = -scroll.index
                    end
                end
            end
        end

        if node.childs then
            for _, child in ipairs(node.childs) do
                local cc         = child.config
                local offset_val = cc.offset or 0
                local after_val  = cc.after  or 0
                local span_x, span_y = parse_span(cc.size or 1)

                local cx, cy, w, h
                if dir_val == 'col' then
                    cx = parent_x + cell_w * x
                    cy = parent_y + cell_h * (y + offset_val)
                    w  = span_x * cell_w
                    h  = span_y * cell_h
                else  -- 'row' default
                    cx = parent_x + cell_w * (x + offset_val)
                    cy = parent_y + cell_h * y
                    w  = span_x * cell_w
                    h  = span_y * cell_h
                end

                for _, css_fn in ipairs(cc.css) do
                    cx, cy, w, h = css_fn(cx, cy, w, h)
                end
                dom_layout(self, child, cx, cy, w, h)

                if dir_val == 'col' then
                    y = y + span_y + offset_val + after_val
                    if y >= rows then y = 0; x = x + span_x end
                else
                    x = x + span_x + offset_val + after_val
                    if x >= cols then x = 0; y = y + span_y end
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
