local function install(std)
    local math = require('math')
    assert(math and (1/2 ~= 0))
    std.math = std.math or {}
    std.math.acos=math.acos
    std.math.asin=math.asin
    std.math.atan=math.atan
    std.math.atan2=math.atan2
    std.math.ceil=math.ceil
    std.math.cos=math.cos
    std.math.cosh=math.cosh
    std.math.deg=math.deg
    std.math.exp=math.exp
    std.math.floor=math.floor
    std.math.fmod=math.fmod
    std.math.frexp=math.frexp
    std.math.huge=math.huge
    std.math.ldexp=math.ldexp
    std.math.log=math.log
    std.math.log10=math.log10
    std.math.modf=math.modf
    std.math.pi=math.pi
    std.math.pow=math.pow
    std.math.rad=math.rad
    std.math.sin=math.sin
    std.math.sinh=math.sinh
    std.math.sqrt=math.sqrt
    std.math.tan=math.tan
    std.math.tanh=math.tanh
end

local P = {
    install = install
}

return P
