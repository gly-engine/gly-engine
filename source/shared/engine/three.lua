local function cells(node)
    local cfg = node.config
    local dat = node.data

    if cfg.type == 'grid' then
        local cols, rows = cfg.cols, cfg.rows
        local w = dat.width / rows
        local h = dat.height / cols
        return w, h
    end
    return dat.width, dat.height
end

local function walk(node, fn)
    fn(node)
    if node.childs then
        for _, child in ipairs(node.childs) do
            walk(child, fn)
        end
    end
end

local function node_begin(node, width, height)
    local self = {}
    self.width = width
    self.height = height
    self.root = node
    self.node_list = { node }
    self.flag_reparent = false
    self.flag_reposition = true
    self.flag_to_delete = {}
    node.config.type = 'root'
    return self
end

local function node_add(self, node, options)
    local parent = options.parent
    local dat = node.data
    local cfg = node.config
    if not parent.childs then
        parent.childs = {}
    end
    if not cfg.parent then
        self.node_list[#self.node_list + 1] = node
    end
    dat.width, dat.height = cells(parent)
    cfg.pause_key = {}
    cfg.pause_all = false
    cfg.parent = parent
    cfg.size = options.size or 1
    parent.childs[#parent.childs + 1] = node
    self.flag_relist = false
    self.flag_reparent = true
    self.flag_reposition = true
end

local function node_del(self, node_root)
    walk(node_root, function(node)
        node.config.parent = nil
    end)
    self.flag_relist = true
    self.flag_reparent = true
    self.flag_reposition = true
end

local function node_pause(self, node_root, key)
    walk(node_root, function(node)
        if key then
            node.config.pause_key[key] = true
        else
            node.config.pause_all = true
        end
    end)
end

local function node_resume(self, node_root, key)
    walk(node_root, function(node)
        if key then
            node.config.pause_key[key] = false
        else
            node.config.pause_key = {}
            node.config.pause_all = false
        end
    end)
end

local function resize(self, width, height)
    self.width = width
    self.height = height
    self.flag_reposition = true
end

local function rebuild_list(self)
    local index, new_node_list = 2, { self.root }
    while index <= #self.node_list do
        if self.node_list[index].config.parent then
            new_node_list[#new_node_list + 1] = self.node_list[index]
        end
        index = index + 1
    end
    self.node_list = new_node_list
end

local function rebuild_tree_from_parents(self)
    local index = 1
    while index <= #self.node_list do
        local node = self.node_list[index]
        node.childs = {}
        index = index + 1
    end
    index = 1
    while index <= #self.node_list do
        local node = self.node_list[index]
        local parent = node.config.parent
        if parent then
            parent.childs[#parent.childs + 1] = node
        end
        index = index + 1
    end
end

local function dom(node, parent_x, parent_y, parent_w, parent_h)
    local cfg = node.config
    local dat = node.data

    cfg.offset_x = parent_x
    cfg.offset_y = parent_y
    dat.width = parent_w
    dat.height = parent_h

    if cfg.type == "grid" then
        local cols, rows, dir = cfg.cols, cfg.rows, cfg.dir
        local cell_w, cell_h = cells(node)
        local x, y = 0, 0

        for _, child in ipairs(node.childs) do
            local size = child.config.size or 1
            local cx, cy = parent_x + x * cell_w, parent_y + y * cell_h
            local w = (dir == 0) and (size * cell_w) or cell_w
            local h = (dir == 1) and (size * cell_h) or cell_h

            dom(child, cx, cy, w, h)

            if dir == 1 then
                y = y + size
                if y >= cols then y, x = 0, x + 1 end
            else
                x = x + size
                if x >= rows then x, y = 0, y + 1 end
            end
        end
    elseif node.childs then
        for _, child in ipairs(node.childs) do
            dom(child, parent_x, parent_y, parent_w, parent_h)
        end
    end
end

local function bus(self, key, handler_func)
    if self.flag_relist then
        rebuild_list(self)
        self.flag_relist = false
    end
    if self.flag_reparent then
        rebuild_tree_from_parents(self)
        self.flag_reparent = false
    end
    if self.flag_reposition then
        dom(self.root, 0, 0, self.width, self.height)
        self.flag_reposition = false
    end
    do
        local index = 1
        while index <= #self.node_list do
            local node = self.node_list[index]
            if index == 1 or (not node.config.pause_key[key] and not node.config.pause_all) then
                handler_func(node)
            end
            index = index + 1
        end
    end
end

local P = {
    node_begin = node_begin,
    node_add = node_add,
    node_del = node_del,
    node_resume = node_resume,
    node_pause = node_pause,
    resize = resize,
    bus = bus
}

return P
