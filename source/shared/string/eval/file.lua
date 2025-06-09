local function script(src)
    local ok, app = false, nil
    if require then
        ok, app = pcall(require, src:gsub('%.lua$', ''))
    end
    if not ok and dofile then
        ok, app =  pcall(dofile, src)
    end
    if not ok and loadfile then
        ok, app = pcall(loadfile, src)
    end

    if type(chunk) == 'function' then
        ok, app = pcall(chunk)
    end

    if not ok then
        return false, 'failed to eval file'
    end

    return ok, app
end

local P = {
    script = script,
}

return P
