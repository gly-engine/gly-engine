local test = require('tests/framework/microtest')
local zip_encode = require('source/shared/archive/zip/encode')
local zip_decode = require('source/shared/archive/zip/decode')

local function u16(buf, pos)
    local a, b = buf:byte(pos, pos + 1)
    return a + b * 256
end

local function u32(buf, pos)
    local a, b, c, d = buf:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 2^24
end

local TEXT = string.rep('gly engine love zip ', 200)

function test_zip_encode_empty()
    local out = zip_encode.encode({})
    assert(#out == 22)
    assert(out:sub(1, 4) == 'PK\5\6')
    assert(#zip_decode.files(out) == 0)
end

function test_zip_encode_roundtrip()
    local members = {
        {name = 'main.lua', body = TEXT},
        {name = 'empty.txt', body = ''},
        {name = 'assets/'},
        {name = 'assets/icon.png', body = '\137PNG\r\n\26\n\0\0\0'},
    }
    local decoded = zip_decode.decode(zip_encode.encode(members))
    assert(#decoded == 4)
    assert(decoded[1].name == 'main.lua' and decoded[1].body == TEXT)
    assert(decoded[2].name == 'empty.txt' and decoded[2].body == '')
    assert(decoded[3].name == 'assets/' and decoded[3].body == '')
    assert(decoded[4].name == 'assets/icon.png' and decoded[4].body == members[4].body)
end

function test_zip_encode_methods()
    local list = zip_decode.files(zip_encode.encode({
        {name = 'deflate.txt', body = TEXT},
        {name = 'small.txt', body = 'ab'},
        {name = 'store.txt', body = TEXT, level = 0},
    }))
    assert(list[1].method == 8 and list[1].compressed_size < #TEXT)
    assert(list[2].method == 0)
    assert(list[3].method == 0 and list[3].compressed_size == #TEXT)
end

function test_zip_encode_level_option()
    local list = zip_decode.files(zip_encode.encode({{name = 'a.txt', body = TEXT}}, {level = 0}))
    assert(list[1].method == 0)
end

function test_zip_encode_local_header()
    local out = zip_encode.encode({{name = 'a.txt', body = 'hi'}})
    assert(out:sub(1, 4) == 'PK\3\4')
    assert(u16(out, 5) == 10)
    assert(u16(out, 9) == 0)
    assert(u16(out, 11) == 0)
    assert(u16(out, 13) == 33)
    assert(u32(out, 15) == 3633523372)
    assert(u32(out, 19) == 2)
    assert(u32(out, 23) == 2)
    assert(u16(out, 27) == 5)
    assert(out:sub(31, 35) == 'a.txt')
    assert(out:sub(36, 37) == 'hi')
end

function test_zip_encode_unix_attributes()
    local out = zip_encode.encode({
        {name = 'run.sh', body = 'x', mode = '755'},
        {name = 'dir/'},
    })
    local central = out:find('PK\1\2', 1, true)
    assert(u16(out, central + 4) == 768 + 20)
    assert(u32(out, central + 38) == tonumber('100755', 8) * 65536)
    central = out:find('PK\1\2', central + 1, true)
    assert(u32(out, central + 38) == tonumber('40755', 8) * 65536 + 16)
end

function test_zip_encode_utf8_flag()
    local out = zip_encode.encode({{name = 'a\195\167\195\163o.txt', body = ''}})
    assert(u16(out, 7) == 2048)
end

function test_zip_encode_deterministic()
    local members = {{name = 'main.lua', body = TEXT}}
    assert(zip_encode.encode(members) == zip_encode.encode(members))
end

function test_zip_decode_with_prefix()
    local out = zip_encode.encode({{name = 'conf.lua', body = TEXT}})
    local fused = 'MZ fake exe PK\3\4 not a zip header'..out
    assert(zip_decode.find(fused, 'conf.lua') == TEXT)
end

function test_zip_encode_invalid_names()
    assert(not pcall(zip_encode.encode, {{name = '', body = ''}}))
    assert(not pcall(zip_encode.encode, {{body = ''}}))
    assert(not pcall(zip_encode.encode, {{name = '/etc/passwd', body = ''}}))
    assert(not pcall(zip_encode.encode, {{name = 'dir\\file', body = ''}}))
end

test.unit(_G)
