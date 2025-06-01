local test = require('tests/framework/microtest')
local util_decorator = require('source/shared/functional/decorator')

local function dummy_func3(zig, zag, zom, a, b, c, d, e, f)
    return zig, zag, zom, a, b, c, d, e, f
end

local function dummy_func2(zig, zag, a, b, c, d, e, f)
    return zig, zag, a, b, c, d, e, f
end 

local function dummy_func1(zig, a, b, c, d, e, f)
    return zig, a, b, c, d, e, f
end 

local function dummy_func_offset_xy2(a, x , y, d, e, f)
    return a, x, y, d, e, f
end

local function dummy_func_offset_xyxy1(x1, y1, x2, y2, e, f)
    return x1, y1, x2, y2, e, f
end
local function list_assertion(result, data)
    for i, d in pairs(data) do 
        assert(result[i] == d) -- common assertion can't be made with full lists
    end
end



function test_decorator_prefix3()
    local decorated_func = util_decorator.prefix3(1, 2, 3, dummy_func3)
    local result = {decorated_func(4, 5, 6, 7, 8, 9)}
    list_assertion(result, {1, 2, 3, 4, 5, 6, 7, 8, 9})
end


function test_decorator_prefix2()
    local decorated_func = util_decorator.prefix2(1, 2, dummy_func2)
    local result = {decorated_func(3, 4, 5, 6, 7, 8)}
    list_assertion(result, {1, 2, 3, 4, 5, 6, 7, 8})
end

function test_decorator_prefix1()
    local decorated_func = util_decorator.prefix1(1, dummy_func1)
    local result = {decorated_func(2, 3, 4, 5, 6, 7)}
    list_assertion(result, {1, 2, 3, 4, 5, 6, 7})
end

function test_decorator_offset_xy2()
    local object = {offset_x = 10, offset_y = 20}
    local decorated_func = util_decorator.offset_xy2(object, dummy_func_offset_xy2)
    local result = {decorated_func(1, 2, 3, 4, 5, 6)}
    list_assertion(result, {1, 12, 23, 4, 5, 6})
end

function test_decorator_offset_xyxy1()
    local object = {offset_x = 10, offset_y = 20}
    local decorated_func = util_decorator.offset_xyxy1(object, dummy_func_offset_xyxy1)
    local result = {decorated_func(1, 2, 3, 4, 5, 6)}
    list_assertion(result, {11, 22, 13, 24, 5, 6})
end

local function dummy_func_offset_xy1(x, y, c, d, e, f)
    return x, y, c, d, e, f
end

function test_decorator_offset_xy1()
    local object = {offset_x = 10, offset_y = 20}
    local decorated_func = util_decorator.offset_xy1(object, dummy_func_offset_xy1)
    local result = {decorated_func(1, 2, 3, 4, 5, 6)}
    list_assertion(result, {11, 22, 3, 4, 5, 6})
end

test.unit(_G)
