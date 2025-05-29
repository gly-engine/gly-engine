local function decorator_prefix3(zig, zag, zom, func)
    return function (a, b, c, d, e, f)
        return func(zig, zag, zom, a, b, c, d, e, f)
    end
end

local function decorator_prefix2(zig, zag, func)
    return function (a, b, c, d, e, f)
        return func(zig, zag, a, b, c, d, e, f)
    end
end

local function decorator_prefix1(zig, func)
    return function (a, b, c, d, e, f)
        return func(zig, a, b, c, d, e, f)
    end
end

local function decorator_offset_xy2(object, func)
    return function(a, b, c, d, e, f)
        local x = object.offset_x + (b or 0)
        local y = object.offset_y + (c or 0)
        return func(a, x, y, d, e, f)
    end
end

local function decorator_offset_xyxy1(object, func)
    return function(a, b, c, d, e, f)
        local x1 = object.offset_x + a
        local y1 = object.offset_y + b
        local x2 = object.offset_x + c
        local y2 = object.offset_y + d
        return func(x1, y1, x2, y2, e, f)
    end
end

local function decorator_offset_xy1(object, func)
    return function(a, b, c, d, e, f)
        local x = object.offset_x + a
        local y = object.offset_y + b
        return func(x, y, c, d, e, f)
    end
end

local function table_prefix1(prefix, fn_table)
    local new_table = {}
    for name, fn in pairs(fn_table) do
        new_table[name] = decorator_prefix1(prefix, fn)
    end
    return new_table
end

local P = {
    offset_xy1 = decorator_offset_xy1,
    offset_xy2 = decorator_offset_xy2,
    offset_xyxy1 = decorator_offset_xyxy1,
    prefix3 = decorator_prefix3,
    prefix2 = decorator_prefix2,
    prefix1 = decorator_prefix1,
    prefix1_t = table_prefix1
}

return P
