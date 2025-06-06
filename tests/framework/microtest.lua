function test(tbl)
    for name, func in pairs(tbl) do
        if type(func) == 'function' and name:match("^test_") then
            func()
        end
    end
end

local P = {
    unit=test
}

return P
