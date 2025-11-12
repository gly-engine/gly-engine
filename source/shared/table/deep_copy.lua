local function deep_copy(headers)
    if type(headers) ~= 'table' then
        return {}
    end
    
    local copy = {}
    for key, value in pairs(headers) do
        if type(value) == 'table' then
            copy[key] = deep_copy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

return {
    ['table'] = deep_copy
}
