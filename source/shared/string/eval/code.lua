local function script(src)
    local loader = loadstring or load
    if not loader then
        error('eval not allowed')
    end
    local ok, chunk = pcall(loader, src)
    if not ok then
        return false, chunk
    end
    if type(chunk) ~= 'function' then
        return false, 'failed to eval code'
    end
    return pcall(chunk)
end

local P = {
    script = script,
}

return P
