local test = require('tests/framework/microtest')
local crc32 = require('source/shared/hash/crc32')
local gzip_encode = require('source/shared/archive/gzip/encode')
local gzip_decode = require('source/shared/archive/gzip/decode')

local function roundtrip(body)
    return gzip_decode.decode(gzip_encode.encode(body))
end

function test_gzip_roundtrip_text()
    local body = 'hello world\n'..string.rep('lorem ipsum ', 100)

    assert(roundtrip(body) == body, 'what goes in should come out')
end

function test_gzip_roundtrip_empty()
    assert(roundtrip('') == '', 'an empty body is still a valid stream')
end

function test_gzip_roundtrip_binary()
    local bytes = {}
    for index = 0, 255 do
        bytes[#bytes + 1] = string.char(index)
    end
    local body = table.concat(bytes)

    assert(roundtrip(body) == body, 'every byte value should survive')
end

--! fengari wraps integer arithmetic at 32 bits, so a crc past 2^31 used to
--! come back negative and every package with one failed to open
function test_gzip_checksum_above_2_31()
    local body = 'a'

    assert(crc32.crc32(body) >= 2 ^ 31, 'this body is here for its high bit')
    assert(roundtrip(body) == body, 'a crc past 2^31 must not overflow')
end

function test_gzip_rejects_other_formats()
    local ok, err = pcall(gzip_decode.decode, 'PK\3\4 not a gzip stream at all')

    assert(not ok and err:find('not a gzip stream'), 'should say what it is not')
end

function test_gzip_rejects_corrupted_body()
    local gz = gzip_encode.encode(string.rep('data', 50))
    local broken = gz:sub(1, 20)..string.char((gz:byte(21) + 1) % 256)..gz:sub(22)

    assert(not pcall(gzip_decode.decode, broken), 'a flipped byte should not pass')
end

test.unit(_G)
