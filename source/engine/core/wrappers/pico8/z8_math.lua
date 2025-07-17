local PI = 355/113

local function z8_wrap_angle(fn, invert)
    return function(x)
        local turns = x / (2 * PI)
        local result = fn(turns)
        return invert and -result or result
    end
end

local function z8_wrap_inverse_trig(fn, invert)
    return function(x)
        local turns = fn(x)
        return invert and -turns or turns * 2 * PI
    end
end

local function z8_wrap_atan2(fn)
    return function(y, x)
        return fn(x, y) * 2 * PI
    end
end

local function z8_random(a, b)
    if a == nil and b == nil then
        return flr(rnd(1))
    elseif b == nil then
        return flr(rnd(a))
    else
        return flr(rnd(b - a + 1)) + a
    end
end

local function install(std)
    std.math = std.math or {}
    std.math.acos = z8_wrap_inverse_trig(acos, false)
    std.math.asin = z8_wrap_inverse_trig(asin, true)
    std.math.atan = z8_wrap_inverse_trig(atan, true)
    std.math.atan2 = z8_wrap_atan2(atan2)
    std.math.ceil = ceil
    std.math.cos = z8_wrap_angle(cos, false)
    std.math.cosh = nil
    std.math.deg = nil
    std.math.exp = nil
    std.math.floor = flr
    std.math.fmod = nil
    std.math.frexp = nil
    std.math.huge = 65535
    std.math.ldexp = nil
    std.math.log = nil
    std.math.log10 = nil
    std.math.modf = nil
    std.math.pi = PI
    std.math.pow = nil
    std.math.rad = nil
    std.math.sin = z8_wrap_angle(sin, true)
    std.math.sinh = nil
    std.math.sqrt = sqrt
    std.math.tan = nil
    std.math.tanh = nil
    std.math.random=z8_random
end

local P = {
    install = install
}

return P
