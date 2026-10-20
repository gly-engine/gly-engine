--! @file pause.lua
--! @brief Central pause registry. Owns engine.dom.pause_registry.
--! @details
--! INVARIANT: pause_registry[uid] exists only for nodes with active pause state.
--! INVARIANT: is_paused(uid, key) returns false for nodes not in registry.
--! Used by dom.bus() to skip event dispatch and by compile() to skip render.
--! node_pause() and node_resume() walk the subtree (propagate to children).
--! pause.lua does NOT require dom.lua — defines its own local walk to avoid circular dep.

--! @brief Walk a node subtree recursively, calling fn on each node.
local function walk(node, fn)
    fn(node)
    if node.childs then
        for _, child in ipairs(node.childs) do
            walk(child, fn)
        end
    end
end

--! @brief Pause a node subtree for a specific event key, or all events.
--! @param self engine.dom
--! @param node_root table  root of subtree to pause
--! @param key string|nil  nil = pause all events; string = pause specific event
local function node_pause(self, node_root, key)
    walk(node_root, function(node)
        local uid = node.config.uid
        if not uid then return end
        local entry = self.pause_registry[uid]
        if not entry then
            entry = { all = false, keys = nil }
            self.pause_registry[uid] = entry
        end
        if key then
            entry.keys = entry.keys or {}
            entry.keys[key] = true
        else
            entry.all  = true
            entry.keys = nil  -- all paused; individual key overrides irrelevant
        end
    end)
end

--! @brief Resume a node subtree for a specific event key, or all events.
--! @param self engine.dom
--! @param node_root table
--! @param key string|nil  nil = resume all; string = resume specific key
local function node_resume(self, node_root, key)
    local parent_uid = node_root.config.parent
                       and node_root.config.parent.config.uid
    local parent_entry = parent_uid and self.pause_registry[parent_uid]
    local parent_all = parent_entry and parent_entry.all
    -- if parent is globally paused and we are not doing a key-specific resume, bail
    if parent_all and not key then return end

    walk(node_root, function(node)
        local uid   = node.config.uid
        if not uid then return end
        local entry = self.pause_registry[uid]
        if not entry then return end
        if key then
            entry.keys = entry.keys or {}
            entry.keys[key] = false  -- false = explicit resume (overrides all=true for this key)
        else
            self.pause_registry[uid] = nil  -- fully resumed: remove entry
        end
    end)
end

--! @brief Check whether a node should be skipped for a given event key.
--! @param self engine.dom
--! @param uid number  node.config.uid
--! @param key string  event key being dispatched (use '*' for all-pause check)
--! @return boolean  true if node should be skipped
local function is_paused(self, uid, key)
    local entry = self.pause_registry[uid]
    if not entry then return false end
    -- explicit key resume (false) overrides all-pause
    if entry.keys and entry.keys[key] == false then return false end
    if entry.keys and entry.keys[key] == true  then return true  end
    return entry.all
end

local P = {
    node_pause  = node_pause,
    node_resume = node_resume,
    is_paused   = is_paused,
}

return P
