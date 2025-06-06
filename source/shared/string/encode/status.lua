local function is_ok(status)
    return (status and 200 <= status and status < 300) or false
end

local P = {
    is_ok = is_ok
}

return P
