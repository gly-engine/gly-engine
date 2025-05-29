local function eval(script)
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
    eval = eval,
}

return P
