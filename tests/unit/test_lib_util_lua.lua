local test = require('src/lib/util/test')
local lua_util = require('source/shared/string/parse/lua')

function test_no_support_utf8()
    jit = nil
    _VERSION = 'Lua 5.1'

    assert(lua_util.has_support_utf8() == false)
end

function test_lua_jit_support_utf8()
    jit = true
    _VERSION = 'Lua 5.1'

    assert(lua_util.has_support_utf8() == true)
end

function test_lua_5_3_support_utf8()
    jit = nil
    _VERSION = 'Lua 5.3'

    assert(lua_util.has_support_utf8() == true)
end

test.unit(_G)
