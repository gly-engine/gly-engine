--! @file lifecycle.lua
--! @brief Node lifecycle management. Orchestrates init/exit/focus/hover callbacks.
--! @details
--! Replaces direct callback calls in dom.lua and navigator.lua.

local function call(self, node, key, ...)
    if node and node.callbacks and node.callbacks[key] and self.std then
        node.callbacks[key](node.data, self.std, ...)
    end
end

local function spawn(self, node)
    call(self, node, 'init')
end

local function kill(self, node)
    call(self, node, 'exit')
end

local function focus(self, node)
    call(self, node, 'focus')
end

local function unfocus(self, node)
    call(self, node, 'unfocus')
end

local function hover(self, node)
    call(self, node, 'hover')
end

local function unhover(self, node)
    call(self, node, 'unhover')
end

local P = {
    spawn   = spawn,
    kill    = kill,
    focus   = focus,
    unfocus = unfocus,
    hover   = hover,
    unhover = unhover,
}

return P
