local math = require('math')
local bit51 = {}

local floor = math.floor

local function mask32(x)
    return x % 2^32
end

function bit51.band(a, b)
    local res, bitval = 0, 1
    a = floor(a)
    b = floor(b)
    for i = 0, 31 do
        local abit = a % 2
        local bbit = b % 2
        if abit == 1 and bbit == 1 then
            res = res + bitval
        end
        a = floor(a / 2)
        b = floor(b / 2)
        bitval = bitval * 2
    end
    return res
end

function bit51.bor(a, b)
    local res, bitval = 0, 1
    a = floor(a)
    b = floor(b)
    for i = 0, 31 do
        if (a % 2) + (b % 2) > 0 then
            res = res + bitval
        end
        a = floor(a / 2)
        b = floor(b / 2)
        bitval = bitval * 2
    end
    return res
end

function bit51.bxor(a, b)
    local res, bitval = 0, 1
    a = floor(a)
    b = floor(b)
    for i = 0, 31 do
        if (a % 2 + b % 2) % 2 == 1 then
            res = res + bitval
        end
        a = floor(a / 2)
        b = floor(b / 2)
        bitval = bitval * 2
    end
    return res
end

function bit51.bnot(a)
    return mask32(2^32 - 1 - floor(a))
end

function bit51.lshift(a, n)
    return mask32(floor(a) * 2^n)
end

function bit51.rshift(a, n)
    return floor(floor(a) / 2^n)
end

return floor and bit51
