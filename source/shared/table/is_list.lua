local function is_list_partial(t)
    if type(t) ~= "table" then
        return false
    end

    local count = 0
    local max_index = 0

    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            return false
        end
        if k > max_index then
            max_index = k
        end
        count = count + 1
    end

    return max_index == count
end

local function is_list_full(tbl)
    local n = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        n = n + 1
    end
    for i = 1, n do
        if tbl[i] == nil then
            return false
        end
    end
    return true
end

return {
    partial = is_list_partial,
    full = is_list_full
}
