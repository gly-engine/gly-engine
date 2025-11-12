local function deep_merge(t1, t2)
    if not t1 and not t2 then return nil end
    if not t1 or not t2 then return t1 or t2 end
    for k, v in pairs(t2) do
        if type(v) == 'table' and type(t1[k]) == 'table' then
            deep_merge(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

return {
    ['table'] = deep_merge
}
