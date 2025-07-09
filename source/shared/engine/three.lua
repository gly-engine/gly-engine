local function node_begin(node, width, height)
    local self = {}
    self.width = width
    self.height = height
    self.root = node
    self.node_list = { node }
    self.flag_reorder = false
    self.flag_reposition = true
    node.config.type = 'root'
    return self
end

local function node_add(self, node, options)
    local parent = options.parent
    local cfg = node.config
    if not cfg.parent then
        self.node_list[#self.node_list + 1] = node
    end
    cfg.parent = parent
    cfg.size = options.size or 1
    self.flag_reposition = true
end

local function node_pause(self, node, key)

end

local function node_resume(self, node, key)

end

local function resize(self, width, height)
    self.width = width
    self.height = height
    self.flag_reposition = true
end

local function rebuild_tree_from_parents(self)
    for _, node in ipairs(self.node_list) do
        node.childs = {}
    end
    for _, node in ipairs(self.node_list) do
        local parent = node.config.parent
        if parent then
            parent.childs[#parent.childs + 1] = node
        end
    end
    self.flag_reposition = false
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
        local cell_w = math.floor(dat.width / rows)
        local cell_h = math.floor(dat.height / cols)

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
    else 
        for _, child in ipairs(node.childs) do
            dom(child, parent_x, parent_y, parent_w, parent_h)
        end
    end
end

local function bus(self, handler_func)
    if self.flag_reposition then
        rebuild_tree_from_parents(self)
        dom(self.root, 0, 0, self.width, self.height)
    end
    do
        local index = 1
        while index <= #self.node_list do
            local node = self.node_list[index]
            handler_func(node)
            index = index + 1
        end
    end
end

local P = {
    node_begin = node_begin,
    node_add = node_add,
    resize = resize,
    bus = bus
}

return P
