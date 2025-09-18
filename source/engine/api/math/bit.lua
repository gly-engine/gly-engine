local bit = require('bit')
local bit32 = require('bit32')
local bit51 = require('source/bit51')
local eval_code = require('source/shared/string/eval/code')

local function install(std)
    local b = bit or bit32
    if not b then
        local protected_sintax = 'local b = {}\n'
        .. 'function b.band(a,b) return a & b end\n'
        .. 'function b.bor(a,b) return a | b end\n'
        .. 'function b.bxor(a,b) return a ~ b end\n'
        .. 'function b.bnot(a) return ~b end\n'
        .. 'function b.lshift(a,n) return a << n end\n'
        .. 'function b.rshift(a,n) return a >> n end\n'
        .. 'function b.arshift(a,n) return a >> n end\n'
        .. 'function b.rol(a,n)\n'
        .. '    n = n % 32\n'
        .. '    return ((a << n) | (a >> (32 - n))) & 0xFFFFFFFF\n'
        .. 'end\n'
        .. 'function b.ror(a,n)\n'
        .. '    n = n % 32\n'
        .. '    return ((a >> n) | (a << (32 - n))) & 0xFFFFFFFF\n'
        .. 'end\n'
        .. 'return b'

        local ok, bit54 = eval_code.script(protected_sintax)
        b = (ok and bit54) or bit51
    end

    if not b then
        error('bitwise is not supported', 0)
    end

    std.math = std.math or {}
    std.math.band = b.band
    std.math.bor = b.bor
    std.math.bxor = b.bxor
    std.math.bnot = b.bnot
    std.math.lshift = b.lshift
    std.math.rshift = b.rshift
    std.math.arshift = b.arshift or b.rshift
    std.math.rol = b.rol
    std.math.ror = b.ror
end

local P = {
    install = install
}

return P
