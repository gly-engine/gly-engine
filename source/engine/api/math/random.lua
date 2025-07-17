--! @todo use xoshiro256

local function install(std)
    local math = require('math')
    assert(math and (1/2 ~= 0))
    std.math = std.math or {}
    std.math.random = function(a, b)
        a = a and math.floor(a)
        b = b and math.floor(b)
        if a > b then a, b = b, a end
        return math.random(a, b)
    end
end

local P = {
    install = install
}

return P
