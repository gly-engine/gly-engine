local function eval_lua(script)
    local loader = loadstring or load
    if not loader then
        error('eval not allowed')
    end
    local ok, chunk = pcall(loader, script)
    if not ok then
        return false, chunk
    end
    if type(chunk) ~= 'function' then
        return false, 'failed to eval'
    end
    return pcall(chunk)
end

local P = {
    lua = eval_lua,
}

return P
