--! @file dom.lua
--! @brief Core DOM engine. Owns: node_list, render_list, dirty_queue, index maps.
--! @details
--! INVARIANT: node_list[1] is always root.
--! INVARIANT: All nodes in node_list have config.parent set (except root).
--! INVARIANT: dirty_queue is empty after flush_dirty() returns.
--! Replaces source/shared/engine/tree.lua.
--! Grid layout computation lives in layout.lua.

local ss        = require('source/engine/browser/stylesheet')
local pause     = require('source/engine/browser/pause')
local layout    = require('source/engine/browser/layout')
local lifecycle = require('source/engine/browser/lifecycle')

--! @brief Module-level UID counter. Incremented on every node_add.
local uid_counter = 0

local walk
local mark_dirty

--! @brief Walk a node subtree recursively, calling fn on each node.
--! @param node table
--! @param fn function(node)
walk = function(node, fn)
    fn(node)
    if node.childs then
        for _, child in ipairs(node.childs) do
            walk(child, fn)
        end
    end
end

--! @brief Enqueue a node for layout recomputation.
--! @details No per-node dirty flag — presence in dirty_queue IS the dirty state.
--! @param self engine.dom
--! @param node table
mark_dirty = function(self, node)
    self.dirty_queue[#self.dirty_queue + 1] = node
end

-- ─── Dirty queue ─────────────────────────────────────────────────────────────

--! @brief Process all pending dirty nodes, recomputing layout only where needed.
--! @details Fast path: if root is in queue, do a full recompute and clear.
--!   Otherwise: process each node once (dedup by uid) and clear descendants.
--! @param self engine.dom
local function flush_dirty(self)
    local queue = self.dirty_queue
    if #queue == 0 then return end

    -- fast path: root in queue → full recompute
    for i = 1, #queue do
        if queue[i] == self.root then
            layout.dom_layout(self, self.root, 0, 0, self.width, self.height)
            for j = #queue, 1, -1 do queue[j] = nil end
            return
        end
    end

    -- partial: process each dirty node once, skip descendants of already-processed nodes
    local processed = {}
    for i = 1, #queue do
        local node = queue[i]
        local uid  = node.config.uid
        if uid and not processed[uid] then
            layout.dom_layout(self, node, node.config.offset_x, node.config.offset_y,
                node.data.width, node.data.height)
            walk(node, function(n)
                if n.config.uid then
                    processed[n.config.uid] = true
                end
            end)
        end
    end
    for i = #queue, 1, -1 do queue[i] = nil end
end

-- ─── Compile ─────────────────────────────────────────────────────────────────

--! @brief Compile DOM into flat render list with screen-culling.
--! @details Reuses entry tables from previous frame (pool) to avoid GC pressure.
--!   Nodes with pause_registry all=true are excluded.
--! @param self engine.dom
local function compile(self)
    local list  = self.render_list
    local index = 0
    local sw, sh = self.width, self.height

    for i = 1, #self.node_list do
        local node = self.node_list[i]
        local cfg  = node.config

        -- skip globally-paused nodes
        local paused_all = pause.is_paused(self, cfg.uid, '*')

        local visible = cfg.visible ~= false
            and not paused_all
            and not cfg._scroll_clipped
            and cfg.offset_x + node.data.width  > 0
            and cfg.offset_x < sw
            and cfg.offset_y + node.data.height > 0
            and cfg.offset_y < sh

        if visible then
            index = index + 1
            local entry = list[index]
            if not entry then
                entry = {}
                list[index] = entry
            end
            entry.uid  = cfg.uid
            entry.x    = cfg.offset_x
            entry.y    = cfg.offset_y
            entry.w    = node.data.width
            entry.h    = node.data.height
            entry.node = node
        end
    end

    -- clear leftover entries from previous frame
    for i = index + 1, #list do
        list[i] = nil
    end
end

-- ─── Tree rebuild ─────────────────────────────────────────────────────────────

--! @brief Rebuild the flat node_list from parent references (drops deleted nodes).
local function rebuild_list(self)
    local new_list = { self.root }
    for i = 2, #self.node_list do
        if self.node_list[i].config.parent then
            new_list[#new_list + 1] = self.node_list[i]
        end
    end
    self.node_list = new_list
end

--! @brief Rebuild childs arrays from parent references (called when tree topology changes).
local function rebuild_tree_from_parents(self)
    for i = 1, #self.node_list do
        self.node_list[i].childs = {}
    end
    for i = 1, #self.node_list do
        local node   = self.node_list[i]
        local parent = node.config.parent
        if parent then
            parent.childs[#parent.childs + 1] = node
        end
    end
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

--! @brief Initialize the engine.dom state object.
--! @param node table  root application node
--! @param width number  initial viewport width
--! @param height number  initial viewport height
--! @return table  engine.dom
local function node_begin(node, width, height, self, std)
    self = self or {}
    self.width  = width
    self.height = height
    self.root   = node
    self.std    = std or self.std

    -- node list
    self.node_list = { node }

    -- render list (pooled)
    self.render_list = self.render_list or {}

    -- dirty queue
    self.dirty_queue = self.dirty_queue or {}

    -- index maps
    self.index_uid   = {}
    self.index_id    = {}
    self.index_class = {}

    -- scroll registry (weak keys so GC'd grid nodes auto-clean)
    self.scroll_registry = setmetatable(self.scroll_registry or {}, { __mode = 'k' })

    -- pause registry
    self.pause_registry = self.pause_registry or {}

    -- focus
    self.focus_list    = {}
    self.focus_current = nil

    -- bus context
    self.current_node = nil

    -- stylesheet storage
    self.stylesheet_dict = self.stylesheet_dict or {}
    self.stylesheet_func = self.stylesheet_func or {}
    self.stylesheet_key  = self.stylesheet_key or {}

    -- tree rebuild flags (kept for compatibility)
    self.flag_relist   = false
    self.flag_reparent = false

    -- configure root node
    node.config.css  = {}
    node.config.type = 'root'
    node.config.uid  = 0  -- root gets uid=0
    self.index_uid[0] = node

    -- inject mark_dirty into stylesheet module
    ss.init(mark_dirty)

    return self
end

--! @brief Register a node as a child of options.parent in the DOM.
--! @details Assigns uid, registers in index maps, detects focusable state.
--!   If node already has a parent (e.g. a grid/slide created then nested inside
--!   another grid), it is re-parented: removed from old parent's childs and
--!   attached to the new parent without touching uid or focus state.
--! @param self engine.dom
--! @param node table
--! @param options table  {parent, size, offset, after, id, class, focusable}
local function node_add(self, node, options)
    local parent = options.parent
    local dat    = node.data
    local cfg    = node.config

    if not parent.childs then
        parent.childs = {}
    end

    -- re-parent path: node was already registered (e.g. nested grid/slide)
    if cfg.parent then
        local old = cfg.parent
        if old.childs then
            for i = #old.childs, 1, -1 do
                if old.childs[i] == node then
                    table.remove(old.childs, i)
                    break
                end
            end
        end
        parent.childs[#parent.childs + 1] = node
        cfg.parent = parent
        cfg.size   = options.size   or cfg.size   or 1
        cfg.after  = options.after  or cfg.after  or 0
        cfg.offset = options.offset or cfg.offset or 0
        self.flag_reparent = true
        mark_dirty(self, parent)
        return
    end

    -- new node path

    -- assign unique id
    uid_counter = uid_counter + 1
    cfg.uid = uid_counter
    self.index_uid[uid_counter] = node

    -- id index
    if options.id then
        cfg.id = options.id
        self.index_id[options.id] = node
    end

    -- class index
    if options.class then
        cfg.class = type(options.class) == 'table' and options.class or { options.class }
        for _, name in ipairs(cfg.class) do
            if not self.index_class[name] then
                self.index_class[name] = {}
            end
            local list = self.index_class[name]
            list[#list + 1] = node
        end
    end

    -- add to flat list
    self.node_list[#self.node_list + 1] = node

    -- initialise layout from parent cell size
    dat.width, dat.height = layout.cells(parent)

    -- attach to parent
    parent.childs[#parent.childs + 1] = node
    cfg.css    = {}
    cfg.parent = parent
    cfg.size   = options.size   or 1
    cfg.after  = options.after  or 0
    cfg.offset = options.offset or 0

    -- lifecycle: init
    lifecycle.spawn(self, node)

    -- focusable detection
    local has_handler = node.callbacks.focus   or node.callbacks.unfocus
                     or node.callbacks.click   or node.callbacks.hover
    local focusable = options.focusable
    if focusable == nil then
        focusable = has_handler ~= nil
    end

    if focusable then
        cfg.focusable = true
        self.focus_list[#self.focus_list + 1] = node
        if not self.focus_current then
            self.focus_current = node
            lifecycle.focus(self, node)
        end
    end

    -- mark dirty
    self.flag_relist   = false
    self.flag_reparent = true
    mark_dirty(self, parent)
end

--! @brief Remove a node subtree from the DOM, cleaning all registries.
--! @param self engine.dom
--! @param node_root table  root of subtree to remove
local function node_del(self, node_root)
    walk(node_root, function(node)
        -- lifecycle: exit
        lifecycle.kill(self, node)

        local uid = node.config.uid
        if uid then
            self.index_uid[uid] = nil
            if node.config.id then
                self.index_id[node.config.id] = nil
            end
            if node.config.class then
                for _, cls in ipairs(node.config.class) do
                    local list = self.index_class[cls]
                    if list then
                        for i = #list, 1, -1 do
                            if list[i] == node then
                                table.remove(list, i)
                                break
                            end
                        end
                    end
                end
            end
            self.pause_registry[uid] = nil
        end

        -- clean focus list
        if node.config.focusable then
            for i = #self.focus_list, 1, -1 do
                if self.focus_list[i] == node then
                    table.remove(self.focus_list, i)
                    break
                end
            end
            if self.focus_current == node then
                self.focus_current = nil
            end
        end

        -- clean scroll registry
        self.scroll_registry[node] = nil

        -- clear node state
        node.data          = {}
        node.config.css    = {}
        node.config.parent = nil
    end)

    self.flag_relist   = true
    self.flag_reparent = true
    mark_dirty(self, self.root)
end

--! @brief Mark the viewport as resized, triggering full layout recompute.
--! @param self engine.dom
--! @param width number
--! @param height number
local function resize(self, width, height)
    self.width  = width
    self.height = height
    mark_dirty(self, self.root)
end

-- ─── Bus ─────────────────────────────────────────────────────────────────────

--! @brief Dispatch an event key to all non-paused nodes in node_list.
--! @details Rebuilds tree/list if flagged, flushes dirty layout, compiles render list.
--! @param self engine.dom
--! @param key string  event key
--! @param handler_func function(node)  called for each non-skipped node
local function bus(self, key, handler_func)
    if self.flag_relist then
        rebuild_list(self)
        self.flag_relist = false
    end
    if self.flag_reparent then
        rebuild_tree_from_parents(self)
        self.flag_reparent = false
    end

    flush_dirty(self)
    compile(self)

    local i = 1
    while i <= #self.node_list do
        local node = self.node_list[i]
        local skip = i ~= 1 and pause.is_paused(self, node.config.uid, key)
        if not skip then
            self.current_node = node
            handler_func(node)
            self.current_node = nil
        end
        i = i + 1
    end
end

local P = {
    -- core lifecycle
    node_begin  = node_begin,
    node_add    = node_add,
    node_del    = node_del,
    -- layout
    resize      = resize,
    flush_dirty = flush_dirty,
    mark_dirty  = mark_dirty,
    compile     = compile,
    -- bus
    bus         = bus,
    -- utilities (exported for other browser/* modules)
    walk        = walk,
    -- layout utilities forwarded from layout.lua
    cells      = layout.cells,
    parse_span = layout.parse_span,
    slide_step = layout.slide_step,
    dom_layout = layout.dom_layout,
}

return P
